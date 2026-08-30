#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <stdio.h>
#import <dlfcn.h>

/* 原子读写兼容层。
 * theos 老模板可能是 -std=gnu99，此时 _Atomic 属 C11 扩展，开了 -Werror 会直接失败。
 * 降级到 volatile 也够用：重入只可能发生在同一线程的同步调用里，跨线程并发调用
 * 本来就该各自走完整逻辑，不需要 acquire/release 语义。 */
#if defined(__clang__) && defined(__has_include) && defined(__has_feature)
#if __has_include(<stdatomic.h>) && __has_feature(c_atomic)
#import <stdatomic.h>
#define NC_ATOMIC(T)    _Atomic(T)
#define NC_LOAD(p)      atomic_load(p)
#define NC_STORE(p, v)  atomic_store(p, (v))
#endif
#endif
#ifndef NC_ATOMIC
#define NC_ATOMIC(T)    volatile T
#define NC_LOAD(p)      (*(p))
#define NC_STORE(p, v)  (*(p) = (v))
#endif

/*
 * NC_WCP — 1:1 对齐 WCPulse.dylib 的 bid 伪装 + 刷脸
 *
 * WCPulse 二进制证据（/workspace/work/wcp/WCPulse.dylib，arm64）：
 *   NSBundle @bundleIdentifier             IMP 0x64712c  &orig 0xa220f8  注册点 0x646e54
 *   NSBundle @objectForInfoDictionaryKey:  IMP 0x649b7c  &orig 0xa22100  注册点 0x646f6c
 *   伪装值 "com.tencent.xin"      密文 0x9eb80a，XOR key 860332b2579d4fd79e234681c018ab48，明文 0x9eb81a
 *   拦截 key "CFBundleIdentifier" 密文 0x9eb850，XOR 就地解密，明文 0x9eb870
 *   重入/惰性标志 0xa2211c（ldar/stlr，只写 1、从不写 0，仅在这两个 IMP 内被触及）
 *   刷脸 FaceRecogFlashHandler @initPipeline，IMP 0xa4020，0xa403c 置 0xa21559=1 在 0xa4050（%orig）之前
 *
 * 与 WCRefine 的关键差异：
 *   WCR 只 hook -bundleIdentifier          → WCP 两个都 hook（第二条路绕过前者直读 Info.plist）
 *   WCR 有 initPipeline/dealloc 对称闩锁   → WCP 无功能开关，构造完即无条件生效
 *   WCR 有 callStackReturnAddresses 门控   → WCP 无调用栈门控
 */

#define WC_OFFICIAL_BID  @"com.tencent.xin"
#define WC_BID_INFO_KEY  @"CFBundleIdentifier"

/* 1 = 对齐 WCPulse：无条件常开、无调用栈门控（推荐先试这个）
 * 0 = 退回 WCRefine：DidFinishLaunching 后置开关 + 调用栈门控（覆盖窄，伪装可能漏判）
 * 关于推送：APNs 的 device token 绑定的是代码签名里的 aps-environment / application-identifier
 * entitlement，不是 [NSBundle mainBundle] bundleIdentifier 的运行时返回值，所以伪装本身
 * 不应影响收 token。真正要观察的是微信自己的长连接保活 —— 出问题就切 0 对照。 */
#ifndef NC_WCP_STRICT
#define NC_WCP_STRICT 1
#endif

/* 是否只伪装 mainBundle。
 * WCPulse 二进制里没有这个判断（它对任意 NSBundle 实例都返回官方 bid）。
 * 默认 1：对子 bundle 伪装无收益，还可能影响资源/插件加载；设为 0 即完全等同 WCP。 */
#ifndef NC_MAIN_BUNDLE_ONLY
#define NC_MAIN_BUNDLE_ONLY 1
#endif

#ifndef NC_LOG
#define NC_LOG 0
#endif

#pragma mark - 日志（同步写微信沙盒 Documents/NC_WCP.log）

#if NC_LOG
/* 必须同步写。早期 +initialize 阶段 dispatch_async 传 NULL 队列会直接 EXC_BAD_ACCESS。 */
static FILE *g_logFile = NULL;
static BOOL g_logTried = NO;

static void nc_openLog(void) {
    if (g_logTried) return;
    g_logTried = YES;
    @autoreleasepool {
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [dirs.firstObject stringByAppendingPathComponent:@"NC_WCP.log"];
        g_logFile = fopen(path.UTF8String, "a");
        NSLog(@"[NC_WCP] log path: %@", path);
    }
}

static void nc_log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void nc_log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[NC_WCP] %@", msg);
    nc_openLog();
    if (g_logFile) {
        fprintf(g_logFile, "%s [NC_WCP] %s\n",
                [[[NSDate date] description] UTF8String], [msg UTF8String]);
        fflush(g_logFile);
    }
}
#else
#define nc_log(...) ((void)0)
#endif

#pragma mark - 重入保护（对齐 WCPulse 0xa2211c）

/* WCP 用 ldar/stlr 做 acquire/release。这里用 C11 _Atomic 达到同等语义。
 * 置位期间一律走 %orig：hook 内部取 [NSBundle mainBundle]、打日志都可能再触发被 hook 的方法。 */
static NC_ATOMIC(BOOL) g_inHook = NO;

#pragma mark - 场景标志（对齐 WCPulse 0xa21559）

/* WCP 里该字节"只写不读"：0xa403c / 0xa4090 写 1，全文件 0 处读 —— 对 bid 伪装零影响。
 * 这里照样置位以保持 1:1，仅用于日志诊断。 */
static NC_ATOMIC(BOOL) g_faceScene = NO;

#pragma mark - 开关 + 调用栈判定（仅 NC_WCP_STRICT=0 时生效，对齐 WCRefine 0x159556c）

#if !NC_WCP_STRICT
static NC_ATOMIC(BOOL) g_enabled = NO;

static BOOL nc_callerInMainBundle(void) {
    NSArray *addrs = [NSThread callStackReturnAddresses];
    if (addrs.count <= 2) return NO;
    Dl_info info;
    if (dladdr((void *)[addrs[2] unsignedLongLongValue], &info) == 0 || info.dli_fname == NULL) return NO;
    NSString *caller = [NSString stringWithUTF8String:info.dli_fname];
    NSString *bundle = [[NSBundle mainBundle] bundlePath];
    /* dladdr 返回的路径可能带 /private 前缀，bundlePath 不带，归一化后再比 */
    NSString *c = [caller hasPrefix:@"/private"] ? [caller substringFromIndex:8] : caller;
    NSString *b = [bundle hasPrefix:@"/private"] ? [bundle substringFromIndex:8] : bundle;
    return [c hasPrefix:b];
}
#endif

static BOOL nc_shouldSpoof(id self_) {
#if NC_MAIN_BUNDLE_ONLY
    if (self_ != [NSBundle mainBundle]) return NO;
#else
    (void)self_;
#endif
#if NC_WCP_STRICT
    return YES;                       /* WCPulse：无条件 */
#else
    if (!NC_LOAD(&g_enabled)) return NO;
    return nc_callerInMainBundle();   /* WCRefine：调用者须位于主程序镜像内 */
#endif
}

#pragma mark - NSBundle

%hook NSBundle

/* 对齐 WCPulse IMP 0x64712c：
 *   0x6471d8 ldar [0xa2211c] → 0x647290 cbnz → 0x647790 blr（%orig）→ 0x647810 isEqualToString:
 * WCP 不判 self、不判调用栈。唯一保留的判定是"orig 已是官方 bid 就直接返回"。 */
- (NSString *)bundleIdentifier {
    if (NC_LOAD(&g_inHook)) return %orig;
    NC_STORE(&g_inHook, YES);
    NSString *out = nil;
    @try {
        NSString *real = %orig;
        if ([real isEqualToString:WC_OFFICIAL_BID]) {
            out = real;
        } else if (nc_shouldSpoof(self)) {
            nc_log(@"bundleIdentifier: %@ -> %@", real, WC_OFFICIAL_BID);
            out = WC_OFFICIAL_BID;
        } else {
            out = real;
        }
    } @finally {
        NC_STORE(&g_inHook, NO);
    }
    return out;
}

/* 对齐 WCPulse IMP 0x649b7c：第二条取值路径，绕过 -bundleIdentifier 直读 Info.plist。
 * 这是 WCPulse 有而 WCRefine 没有的，也是"二次启动登录态对不上"最可能的根因。
 * 只拦 CFBundleIdentifier 一个 key（WCP 用 isEqualToString: 精确比对），其余 key 全部透传。 */
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (NC_LOAD(&g_inHook)) return %orig;
    NC_STORE(&g_inHook, YES);
    id out = nil;
    @try {
        id real = %orig;
        if ([key isKindOfClass:[NSString class]] &&
            [key isEqualToString:WC_BID_INFO_KEY] &&
            nc_shouldSpoof(self)) {
            nc_log(@"infoDictionary[%@]: %@ -> %@", key, real, WC_OFFICIAL_BID);
            out = WC_OFFICIAL_BID;
        } else {
            out = real;
        }
    } @finally {
        NC_STORE(&g_inHook, NO);
    }
    return out;
}

%end

#pragma mark - 刷脸（对齐 WCPulse IMP 0xa4020：置位在 orig 之前）

/* 头文件证据：微信/FaceRecogFlashHandler.h:97  - (void)initPipeline;
 * WCP 0xa403c strb w8,[x9,#0x559] 位于 0xa4050 blr（%orig）之前 —— 此处顺序一致。 */
%hook FaceRecogFlashHandler

- (void)initPipeline {
    NC_STORE(&g_faceScene, YES);
    nc_log(@"FaceRecogFlashHandler initPipeline -> faceScene=YES");
    %orig;
}

%end

/* 登录页 hook 已移除：
 * WCPulse 里 0xa4060 那个 hook 的 selector 是 [x8,#0x940] 间接取址，静态未解析；
 * 之前按头文件用 -initView 替代，结果登录页 UI 只剩"注册"按钮，说明该 hook
 * 干扰了视图初始化时序。由于 0xa21559 是只写不读的死标志，对 bid 伪装无影响，
 * 直接删掉即可。刷脸场景由 FaceRecogFlashHandler 单独覆盖。 */

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        %init;
        nc_log(@"loaded strict=%d mainBundleOnly=%d official=%@ key=%@",
               NC_WCP_STRICT, NC_MAIN_BUNDLE_ONLY, WC_OFFICIAL_BID, WC_BID_INFO_KEY);

#if !NC_WCP_STRICT
        /* 保守模式（WCRefine 语义）：启动完成后才开。严格模式不需要 —— WCP 构造完即生效。 */
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        (void)note;
                        NC_STORE(&g_enabled, YES);
                        nc_log(@"DidFinishLaunching -> enabled=YES");
                    }];
#endif
    }
}

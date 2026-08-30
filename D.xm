#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <stdio.h>
#import <dlfcn.h>

/* 原子读写兼容层。
 * theos 老模板可能是 -std=gnu99，此时 _Atomic 属 C11 扩展，开了 -Werror 会直接失败。
 * 降级到 volatile 也够用：这里只在主线程/单次调用链里翻转标志，不需要跨线程同步语义。 */
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
 * NC_WCR —— 1:1 对齐 WCRefine.dylib 的 bid 伪装
 *
 * ============================ 二进制证据链 ============================
 * 目标：/workspace/work/WCRefine.dylib（arm64）
 *
 * [1] 全局开关 gBidOn
 *     地址   0x2203560，位于 __DATA,__bss（0x21fc620..0x2205940）→ 初值 0
 *     读点   0x1582ed8  ldrb w8, [x8, #0x560]        （bundleIdentifier IMP 内，唯一读点）
 *     写点   0x1583050  strb w8, [x9, #0x560]  (w8=1)  ← IMP 0x1583034
 *     写点   0x158308c  strb wzr, [x8, #0x560] (=0)    ← IMP 0x1583074
 *     全二进制仅此 2 处写点。
 *
 * [2] 三个 hook（MSHookMessageEx stub = 0x1ca5328，注册函数 0x1582718 起）
 *     注册点        类名                     selector            IMP          &orig
 *     0x15827f0     NSBundle                bundleIdentifier     0x1582ec0    0x2203458
 *     0x1582820     FaceRecogFlashHandler   initPipeline         0x1583034    0x2203460
 *     0x1582850     FaceRecogFlashHandler   dealloc              0x1583074    0x2203468
 *     （dealloc 的 selector 由 sel_registerName(@"dealloc") 取得，见 0x1582834 bl 0x1ca5d00）
 *
 * [3] bundleIdentifier IMP 0x1582ec0 的控制流
 *     0x1582ed8  ldrb w8,[x8,#0x560]       取开关
 *     0x1582ef4  tbz  w8,#0,→0x1582f70     开关为 0 直接走 %orig
 *     0x1582f04  ldr  x0,[0x2073560]       NSBundle classref（与 0x15956f0 同一引用）
 *     0x1582f10  ldr  x1,[0x204a800]       @mainBundle
 *     0x1582f1c  blr  objc_msgSend         → [NSBundle mainBundle]
 *     0x1582f48  subs x8, x8, x9           self - mainBundle
 *     0x1582f50  b.ne →0x1582f70           不等（非主 bundle）→ 走 %orig
 *     0x1582f58  bl   #0x159556c           调用栈门控，返回 0 也走 %orig
 *     0x1582fa4  ldr  x8,[0x1f60588]
 *     0x1582fac  adrp x0,#0x1f8f000; add x0,x0,#0xe88   → CFString @0x1f8fe88
 *     0x1582ff8  ldr  x8,[0x2203458]; blr  → %orig
 *
 * [4] 伪装值
 *     CFString @0x1f8fe88（__DATA_CONST,__cfstring）：ptr=0x1d9f548, len=15
 *     内容 = "com.tencent.xin"；全二进制仅此一处该字符串。
 *
 * [5] 调用栈门控函数 0x159556c
 *     0x1595584  @callStackReturnAddresses      → [NSThread callStackReturnAddresses]
 *     0x15955a8  @count                          → if (count <= 2) return NO   (0x15955c4/0x15955c8)
 *     0x1595604  @objectAtIndexedSubscript: (idx=2, 见 0x1595610 mov x2,#2)
 *     0x1595644  @unsignedLongLongValue
 *     0x1595664  bl #0x1ca58d4 = _dladdr
 *     0x15956f8  @mainBundle / 0x1595724 @bundlePath / 0x1595768 @length
 *
 * [6] 关键否证（本文件据此删掉了两条路径）
 *     - "CFBundleIdentifier" 在 WCRefine 全二进制出现 0 次
 *       → WCR 没有 objectForInfoDictionaryKey: 这条伪装路径
 *     - objectForInfoDictionaryKey: 只出现在 __objc_methname（普通调用），
 *       未出现在任何 MSHookMessageEx 注册项里
 *     - WCR 没有 __mod_init_func，注册走 __objc_nlclslist 的 16 个 +load 类
 *
 * [7] 第二份 WCRefine.dylib 交叉验证（同机制、地址全变）
 *     目标：/workspace/work/wcr2/WCRefine.dylib
 *           30,819,792 B, md5 b278d947f13bb46116fdc2313a32e74f
 *           （上一份 36,491,920 B, md5 7bfc082a457e014ab62295455bfa0282 —— 确为不同二进制）
 *     ------------------------------------------------------------------
 *     项                            上一份              这一份
 *     ------------------------------------------------------------------
 *     _MSHookMessageEx stub         0x1ca5328           0x1821d70
 *     NSBundle @bundleIdentifier    IMP 0x1582ec0       IMP 0x120a650
 *                                   &orig 0x2203458     &orig 0x1cb9ee8
 *     FaceRecog @initPipeline       IMP 0x1583034       IMP 0x120a7c4
 *                                   &orig 0x2203460     &orig 0x1cb9ef0
 *     FaceRecog @dealloc            IMP 0x1583074       IMP 0x120a804
 *                                   &orig 0x2203468     &orig 0x1cb9ef8
 *     全局开关                      0x2203560           0x1cb9ff0
 *                                                       (__DATA,__bss +0x5c20)
 *     调用栈门控                    0x159556c           0x121d68c
 *     伪装 CFString                 0x1f8fe88           0x1a8ee80
 *     "com.tencent.xin" 字面量      0x1d9f548           0x19729a8
 *     hook 总数                     1788                1557
 *     ------------------------------------------------------------------
 *     这一份同样：CFBundleIdentifier 出现 0 次；com.tencent.xin 出现 1 次；
 *     无 __mod_init_func；__objc_nlclslist 16 个 +load 类，同名同序。
 *     → 两份二进制的 bid hook 机制 100% 一致，本文件无需任何改动。
 *
 * ============================ 与上一版（NC_WCP.txt）的差异 ============================
 *   上一版                                  本版（WCR 事实）
 *   --------------------------------------  --------------------------------------
 *   bid 伪装常开（STRICT=1）                默认关闭，仅 FaceRecog 生命周期内开
 *   hook objectForInfoDictionaryKey:        不 hook（WCR 二进制里 CFBundleIdentifier 出现 0 次）
 *   开关在 DidFinishLaunching 打开          开关在 initPipeline 开 / dealloc 关
 *   FaceRecog 只置"场景标志"                FaceRecog 就是开关本身
 *   无调用栈门控（STRICT=1）                始终有 dladdr 调用栈门控
 *
 *   → 通知坏掉的根因：常开伪装让微信在注册 APNs 期间也拿到伪装 bid，
 *     与系统侧真实 bid 不一致，微信判定环境异常后直接跳过通知注册流程
 *     （表现就是"连权限弹窗都不弹"）。WCR 默认关闭，所以一直正常。
 */

#define WC_OFFICIAL_BID @"com.tencent.xin"

/* 1 = WCRefine 精确语义：开关默认关，只在 FaceRecogFlashHandler 存活期间开（推荐）
 * 0 = WCPulse 语义：常开。已知会破坏通知注册，仅用于 A/B 验证
 *     "多开登录是否真的需要全程伪装" —— 若 1 不能满足登录、0 可以，说明校验点在别处。 */
#ifndef NC_WCR_MODE
#define NC_WCR_MODE 1
#endif

/* 类缺失兜底：目标微信版本若无 FaceRecogFlashHandler，模式 1 下开关将永远为 NO，
 * 伪装彻底失效。默认退回常开，避免"装了等于没装"。设为 0 则保持不伪装。 */
#ifndef NC_FALLBACK_ALWAYS
#define NC_FALLBACK_ALWAYS 1
#endif

#ifndef NC_LOG
#define NC_LOG 0
#endif

#pragma mark - 日志（同步写微信沙盒 Documents/NC_WCR.log）

#if NC_LOG
/* 必须同步写。早期 +load 阶段 dispatch_async 传 NULL 队列会直接 EXC_BAD_ACCESS。 */
static FILE *g_logFile = NULL;
static BOOL g_logTried = NO;

static void nc_openLog(void) {
    if (g_logTried) return;
    g_logTried = YES;
    @autoreleasepool {
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [dirs.firstObject stringByAppendingPathComponent:@"NC_WCR.log"];
        g_logFile = fopen(path.UTF8String, "a");
        NSLog(@"[NC_WCR] log path: %@", path);
    }
}

static void nc_log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void nc_log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSLog(@"[NC_WCR] %@", msg);
    nc_openLog();
    if (g_logFile) {
        fprintf(g_logFile, "%s [NC_WCR] %s\n",
                [[[NSDate date] description] UTF8String], [msg UTF8String]);
        fflush(g_logFile);
    }
}
#else
#define nc_log(...) ((void)0)
#endif

#pragma mark - 开关（对齐 WCRefine 0x2203560，__bss 初值 0）

static NC_ATOMIC(BOOL) g_bidOn = NO;

#pragma mark - 调用栈门控（对齐 WCRefine 0x159556c）

/* 取调用栈第 3 帧（index 2：0=本函数，1=bundleIdentifier 的 hook，2=真实调用者），
 * dladdr 解析其所属镜像，要求落在主 bundle 路径内。
 *
 * 注意这里用的是 -bundlePath 而非 -bundleIdentifier：前者未被 hook，
 * 所以不存在重入问题 —— 这也是 WCR 只 hook 一个方法就能自洽的原因。 */
static BOOL nc_callerInMainBundle(void) {
    NSArray *addrs = [NSThread callStackReturnAddresses];
    if ([addrs count] <= 2) return NO;
    NSNumber *ra = [addrs objectAtIndexedSubscript:2];
    Dl_info info;
    if (dladdr((void *)[ra unsignedLongLongValue], &info) == 0) return NO;
    if (info.dli_fname == NULL) return NO;
    NSString *caller = [NSString stringWithUTF8String:info.dli_fname];
    NSString *bundle = [[NSBundle mainBundle] bundlePath];
    if ([bundle length] == 0) return NO;
    /* dladdr 给的路径常带 /private 前缀，bundlePath 不带，归一化后再比 */
    NSString *c = [caller hasPrefix:@"/private"] ? [caller substringFromIndex:8] : caller;
    NSString *b = [bundle hasPrefix:@"/private"] ? [bundle substringFromIndex:8] : bundle;
    return [c hasPrefix:b];
}

#pragma mark - NSBundle

%group G_Bundle

%hook NSBundle

/* 对齐 WCRefine IMP 0x1582ec0。判定顺序与二进制完全一致：
 *   ① 已是官方 bid → 原样返回
 *   ② 开关未开   → %orig        (0x1582ef4)
 *   ③ 非 mainBundle → %orig     (0x1582f48/0x1582f50)
 *   ④ 调用者不在主程序镜像 → %orig (0x1582f58)
 *   ⑤ 返回 CFString "com.tencent.xin" (0x1f8fe88) */
- (NSString *)bundleIdentifier {
    NSString *real = %orig;
    if ([real isEqualToString:WC_OFFICIAL_BID]) return real;

#if NC_WCR_MODE
    if (!NC_LOAD(&g_bidOn)) return real;
    if (self != [NSBundle mainBundle]) return real;
    if (!nc_callerInMainBundle()) return real;
#else
    /* WCPulse 语义：无开关、无调用栈门控，仅限定主 bundle */
    if (self != [NSBundle mainBundle]) return real;
#endif

    nc_log(@"bundleIdentifier: %@ -> %@", real, WC_OFFICIAL_BID);
    return WC_OFFICIAL_BID;
}

#if !NC_WCR_MODE
/* WCPulse IMP 0x649b7c 的第二条路径。
 * WCRefine 里不存在（"CFBundleIdentifier" 全二进制 0 次出现），
 * 仅在对照模式 0 下编译进来，用于验证"是否必须双路径一致"。 */
- (id)objectForInfoDictionaryKey:(NSString *)key {
    id real = %orig;
    if ([key isKindOfClass:[NSString class]] &&
        [key isEqualToString:@"CFBundleIdentifier"] &&
        self == [NSBundle mainBundle]) {
        NSString *spoofed = [self bundleIdentifier];
        nc_log(@"infoDictionary[CFBundleIdentifier]: %@ -> %@", real, spoofed);
        return spoofed;
    }
    return real;
}
#endif

%end

%end /* G_Bundle */

#pragma mark - 刷脸：开关本身

%group G_FaceRecog

%hook FaceRecogFlashHandler

/* 对齐 WCRefine IMP 0x1583034：
 *   0x1583048 adrp x9,#0x2203000
 *   0x158304c mov  w8,#1
 *   0x1583050 strb w8,[x9,#0x560]      ← 置位
 *   0x1583058 ldr  x8,[x8,#0x460]      ← %orig
 * 置位在 %orig 之前 —— 本文件顺序一致。 */
- (void)initPipeline {
    NC_STORE(&g_bidOn, YES);
    nc_log(@"initPipeline -> bidOn=YES");
    %orig;
}

/* 对齐 WCRefine IMP 0x1583074：
 *   0x1583088 adrp x8,#0x2203000
 *   0x158308c strb wzr,[x8,#0x560]     ← 清零
 *   0x1583094 ldr  x8,[x8,#0x468]      ← %orig
 * 清零同样在 %orig 之前。这是 WCR 能长期不破坏环境的另一半：
 * 刷脸窗口一结束就还原真实 bid，而不是留一个永久后门。 */
- (void)dealloc {
    NC_STORE(&g_bidOn, NO);
    nc_log(@"dealloc -> bidOn=NO");
    %orig;
}

%end

%end /* G_FaceRecog */

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        %init(G_Bundle);

        Class frCls = objc_getClass("FaceRecogFlashHandler");
        if (frCls) {
            %init(G_FaceRecog, FaceRecogFlashHandler = frCls);
        } else {
#if NC_FALLBACK_ALWAYS
            NC_STORE(&g_bidOn, YES);
            nc_log(@"FaceRecogFlashHandler 缺失 -> 兜底常开 bidOn=YES");
#else
            nc_log(@"FaceRecogFlashHandler 缺失 -> 保持不伪装");
#endif
        }

        nc_log(@"loaded mode=%d fallback=%d official=%@ faceRecog=%@",
               NC_WCR_MODE, NC_FALLBACK_ALWAYS, WC_OFFICIAL_BID,
               frCls ? @"YES" : @"NO");
    }
}

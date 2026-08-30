/*
 * Tweak.xm —— NSBundle -bundleIdentifier（严格对齐 WCRefine v4）
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  对齐目标：WCRefine 静态初始化器 0x15826f4（193 个 init 中的第 96 个）
 *  注册的三个 hook，它们共享同一个 flag 字节：
 *
 *   ┌──┬──────────┬────────────────────────────┬──────────────┬──────────┐
 *   │# │ 注册点   │ 目标                        │ 新 IMP       │ 原 IMP 槽│
 *   ├──┼──────────┼────────────────────────────┼──────────────┼──────────┤
 *   │1 │ 0x15827f0│ NSBundle -bundleIdentifier │ 0x1582ec0    │ 0x2203458│
 *   │2 │ 0x1582820│ FaceRecogFlashHandler      │ 0x1583034    │ 0x2203460│
 *   │  │          │   -initPipeline            │              │          │
 *   │3 │ 0x1582850│ FaceRecogFlashHandler      │ 0x1583074    │ 0x2203468│
 *   │  │          │   -dealloc                 │              │          │
 *   └──┴──────────┴────────────────────────────┴──────────────┴──────────┘
 *
 *  WCR 0x1582ec0 的控制流（一步都不能换顺序）：
 *
 *      if (flag == 0)                    goto original;   // 0x1582ed0
 *      if (self != [NSBundle mainBundle]) goto original;  // 0x1582f48
 *      if (!callerIsInsideAppImage())     goto original;  // 0x1582f58
 *      return @"com.tencent.xin";                         // 0x1582fac
 *  original:
 *      return orig(self, _cmd);                           // 0x1583008
 *
 *  WCR 0x1583034 / 0x1583074（窗口开合，就两个字节的事）：
 *
 *      -initPipeline:  flag = 1;  return %orig;
 *      -dealloc:       flag = 0;  return %orig;
 *
 *  WCR 0x159556c（调用者归属）：
 *
 *      NSArray *a = [NSThread callStackReturnAddresses];
 *      if (a.count <= 2) return NO;
 *      Dl_info info = {0};
 *      if (dladdr([a[2] unsignedLongLongValue], &info) == 0) return NO;
 *      if (info.dli_fname == NULL) return NO;
 *      NSString *caller = [NSString stringWithUTF8String:info.dli_fname];
 *      NSString *app    = [[NSBundle mainBundle] bundlePath];
 *      return app.length > 0 && [caller hasPrefix:app];
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  为什么 WCR 没 bug 而你的有 —— 三个关键点
 * ═══════════════════════════════════════════════════════════════════════
 *
 *  【1】flag 短路必须排在第一位，且窗口外零开销
 *       WCR 的 flag==0 分支里，连 self 都不比较、连栈都不取，直接跳原实现。
 *       bundleIdentifier 在微信启动期被调用几千次，任何"先取栈再判断"的写法
 *       都会把主线程拖死 → 启动看门狗 → 登录流程中断。
 *       你的 NC.txt 和我的 v2/v3 都在这一点上吃了亏。
 *
 *  【2】hook 函数体内不能出现任何会反过来读 bundleIdentifier 的调用
 *       NSFileManager / NSSearchPathForDirectoriesInDomains / stringByAppending…
 *       这些都会触发 bundleIdentifier → 递归回自己的 hook。
 *       WCR 的 hook 体里只有 flag 读、指针比较、dladdr、strcmp，全是纯 C。
 *       我的 v2 在里面调了 WCRPrepare()，这就是「直接登录不了」的根因。
 *
 *  【3】窗口必须是 FaceRecogFlashHandler 的生命周期，不是全时段
 *       全时段伪装会让登录、推送上报、数据库路径全部读到 com.tencent.xin，
 *       登录和 APNs 绑定就跟着乱了。WCR 用 initPipeline→dealloc 这个窄窗口，
 *       把影响面限制在人脸流程那几百毫秒内。
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  本实现相对 WCR 的 3 处差异（都是等价优化，语义不变，已逐条标注）
 * ═══════════════════════════════════════════════════════════════════════
 *   D1  flag 用全局 volatile int32，不用实例 +0x560 偏移。
 *       原因：WCR 靠硬编码偏移踩在 FaceRecogFlashHandler 实例内存里，
 *       一旦该类在别的微信版本里成员布局变了就是越界写。全局量行为等价且安全。
 *   D2  bundlePath 在 %ctor 期缓存，不每次调用都取。
 *       原因：App 生命周期内不变，且能避开 hook 内任何 NSBundle 调用。
 *   D3  加了 pthread TLS 重入守卫。
 *       原因：WCR 的 hook 体是纯 C 所以不需要；我们要在里面写日志，
 *       必须防重入。守卫命中时无条件走原实现，不改变任何对外行为。
 *
 * 日志：<App>/Documents/WCRBundleHook.log
 *       <App> = /var/mobile/Containers/Data/Application/<UUID>/
 *       注入 dylib 继承宿主沙盒，/var/mobile/Documents 不可写
 *       —— 这就是 v1 一个字都写不出来的原因。
 *       仅窗口内记录，窗口外不产生任何日志，不产生任何 I/O。
 *       同时 NSLog 一份，可用 macOS 控制台 / idevicesyslog 实时看。
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <pthread.h>
#import <mach-o/dyld.h>
#import <sys/uio.h>
#import <sys/time.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdarg.h>
#import <string.h>
#import <stdlib.h>
#import <limits.h>

/* WCR 0x1582fac 返回的那个常量字符串 */
#define kWCRFakeBid @"com.tencent.xin"

#define kWCRLogName     "WCRBundleHook.log"
#define kWCRLogMaxBytes (1 * 1024 * 1024)
#define kWCRLogMaxLines 5000

/* callStackReturnAddresses 里哪一帧算「真正的调用者」。
 * WCR 硬编码取 index 2（0 = 当前 hook 帧，1 = objc_msgSend 相关，
 * 2 = 发起查询的业务代码）。若日志里 caller 判断总是落在
 * 「outside app image」，把这里改成 1 或 3 再看栈 dump 定位。 */
#define kWCROffsetInStack 2

/* 窗口内命中时，前多少次记完整调用栈 */
#define kHITDetailLimit   20

/* ═══════════════════ 状态 ═══════════════════ */

/* WCR 存在 FaceRecogFlashHandler 实例 +0x560 的那个字节（见 D1） */
static volatile int32_t gFlag = 0;

/* WCR 0x159556c 里每次都取的 [[NSBundle mainBundle] bundlePath]（见 D2） */
static char  *gAppPath  = NULL;
static size_t gAppPathLen = 0;

/* 重入守卫（见 D3） */
static pthread_key_t gReentryKey;
static BOOL          gReentryReady = NO;

/* 日志 */
static int   gLogFD    = -1;
static int   gLogLines = 0;
static char *gLogPath  = NULL;
static int   gHitCount = 0;

/* ═══════════════════ 重入守卫 ═══════════════════ */

static inline BOOL WCRIsReentrant(void) {
    if (!gReentryReady) return YES;
    return pthread_getspecific(gReentryKey) != NULL;
}
static inline void WCREnter(void) { if (gReentryReady) pthread_setspecific(gReentryKey, (void *)1); }
static inline void WCRLeave(void) { if (gReentryReady) pthread_setspecific(gReentryKey, NULL);      }

/* ═══════════════════ 日志：纯 POSIX，零 Foundation ═══════════════════
 * 只在窗口内被调用，窗口外整个日志子系统一次都不会碰。 */

static void WCRLog(const char *fmt, ...) {
    if (gLogFD < 0 || gLogLines >= kWCRLogMaxLines) return;

    char body[1024];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(body, sizeof(body), fmt, ap);
    va_end(ap);
    if (n <= 0) return;
    if (n >= (int)sizeof(body)) n = (int)sizeof(body) - 1;

    struct timeval tv; gettimeofday(&tv, NULL);
    struct tm tmv; localtime_r(&tv.tv_sec, &tmv);
    char hdr[64];
    int hn = snprintf(hdr, sizeof(hdr), "[%02d:%02d:%02d.%03d] ",
                      tmv.tm_hour, tmv.tm_min, tmv.tm_sec, (int)(tv.tv_usec / 1000));

    struct iovec iov[3];
    iov[0].iov_base = hdr;  iov[0].iov_len = (size_t)hn;
    iov[1].iov_base = body; iov[1].iov_len = (size_t)n;
    iov[2].iov_base = "\n"; iov[2].iov_len = 1;
    writev(gLogFD, iov, 3);
    gLogLines++;
}

/* 窗口内额外 dump 前 6 帧，用来看清到底是谁在问 bid */
static void WCRDumpStack(void) {
    if (gLogFD < 0) return;
    NSArray *a = [NSThread callStackReturnAddresses];
    NSUInteger c = [a count];
    NSUInteger n = c > 8 ? 8 : c;
    for (NSUInteger i = 0; i < n; i++) {
        unsigned long long pc = [[a objectAtIndexedSubscript:i] unsignedLongLongValue];
        Dl_info info;
        memset(&info, 0, sizeof(info));
        if (dladdr((const void *)(uintptr_t)pc, &info) == 0 || info.dli_fname == NULL) continue;
        const char *f = strrchr(info.dli_fname, '/');
        f = f ? f + 1 : info.dli_fname;
        WCRLog("        #%lu 0x%llx %s  %s",
               (unsigned long)i, pc, f, info.dli_sname ? info.dli_sname : "");
    }
}

/* ═══════════════════ WCR 0x159556c：调用者归属判定 ═══════════════════
 * 原实现每次都 [[NSBundle mainBundle] bundlePath]，这里用 %ctor 期缓存值，
 * 判定式完全一致：appPath.length > 0 && [callerImage hasPrefix:appPath] */

static BOOL WCRCallerIsInAppImage(unsigned long long pc) {
    if (pc == 0) return NO;

    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr((const void *)(uintptr_t)pc, &info) == 0) return NO;   /* WCR 0x1595670 */
    if (info.dli_fname == NULL) return NO;

    if (gAppPath == NULL || gAppPathLen == 0) return NO;              /* appPath.length > 0 */
    return strncmp(info.dli_fname, gAppPath, gAppPathLen) == 0;       /* hasPrefix: */
}

/* ═══════════════════ 一次性准备：必须在 %init 之前 ═══════════════════
 * 此时一个 hook 都还没装，用 NSFileManager / NSBundle 完全安全。 */

static void WCRPrepareOnce(void) {
    if (pthread_key_create(&gReentryKey, NULL) == 0) gReentryReady = YES;

    @autoreleasepool {
        /* 1) 缓存 App 主镜像路径（对应 WCR 里的 bundlePath）*/
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        if (appPath && [appPath length] > 0) {
            const char *u = [appPath fileSystemRepresentation];
            if (u) { gAppPath = strdup(u); gAppPathLen = strlen(gAppPath); }
        }

        /* 2) 日志文件放 App 自己的 Documents 下 —— 沙盒内唯一稳的地方 */
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                             NSUserDomainMask, YES);
        NSString *doc = ([paths count] > 0)
                      ? [paths objectAtIndex:0]
                      : [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];

        [[NSFileManager defaultManager] createDirectoryAtPath:doc
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:NULL];

        NSString *logPath = [doc stringByAppendingPathComponent:@(kWCRLogName)];
        const char *lp = [logPath fileSystemRepresentation];

        struct stat st;
        if (stat(lp, &st) == 0 && st.st_size > (off_t)kWCRLogMaxBytes) {
            truncate(lp, 0);
        }
        gLogFD = open(lp, O_WRONLY | O_CREAT | O_APPEND, 0644);
        gLogPath = strdup(lp ? lp : "(unknown)");
    }
}

/* ══════════════════════════════════════════════════════════════════════
 *  hook 1 / 3 —— WCR 0x1582ec0：NSBundle -bundleIdentifier
 * ══════════════════════════════════════════════════════════════════════ */
%hook NSBundle

- (NSString *)bundleIdentifier {
    /* ⓿ 重入守卫（D3，WCR 无此步，但语义等价：命中即走原实现）*/
    if (WCRIsReentrant()) return %orig;

    /* ❶ flag 短路 —— WCR 0x1582ed0
     *    窗口外直接跳原实现。不比 self、不取栈、不写日志。
     *    整个 hook 的常驻开销就是这一次 volatile 读 + 一次比较。
     *    这一行是 WCR 敢把 hook 挂在 NSBundle 上的根本原因。 */
    if (gFlag == 0) return %orig;

    WCREnter();

    /* ❷ 只认 mainBundle —— WCR 0x1582f48 */
    if (self != [NSBundle mainBundle]) {
        WCRLog("PASS  self != mainBundle  (0x%x)", (unsigned)(uintptr_t)self);
        WCRLeave();
        return %orig;
    }

    /* ❸ 调用者必须来自 App 主镜像 —— WCR 0x1582f58 → 0x159556c */
    NSArray *addrs = [NSThread callStackReturnAddresses];
    if ([addrs count] <= 2) {                       /* WCR 0x15955c8 */
        WCRLog("PASS  stack too shallow (%lu)", (unsigned long)[addrs count]);
        WCRLeave();
        return %orig;
    }

    unsigned long long pc = [[addrs objectAtIndexedSubscript:kWCROffsetInStack] unsignedLongLongValue];
    BOOL inApp = WCRCallerIsInAppImage(pc);

    if (!inApp) {
        Dl_info miss; memset(&miss, 0, sizeof(miss));
        const char *f = "(?)";
        if (dladdr((const void *)(uintptr_t)pc, &miss) != 0 && miss.dli_fname) {
            const char *s = strrchr(miss.dli_fname, '/');
            f = s ? s + 1 : miss.dli_fname;
        }
        WCRLog("PASS  caller outside app image: 0x%llx %s", pc, f);
        WCRLeave();
        return %orig;
    }

    /* 命中 —— WCR 0x1582fac：直接返回常量串，不调用原实现。
     * 这里额外调一次 %orig 只为写日志，原实现是一次无副作用的读取。
     * 日志限流：前 kHITDetailLimit 次记完整栈，之后只累加计数，
     * 避免人脸流程里高频查询把主线程拖住 —— WCR 本体是不记日志的。 */
    gHitCount++;
    if (gHitCount <= kHITDetailLimit) {
        NSString *origVal = %orig;
        Dl_info hit; memset(&hit, 0, sizeof(hit));
        const char *fn = "(?)";
        if (dladdr((const void *)(uintptr_t)pc, &hit) != 0 && hit.dli_fname) {
            const char *s = strrchr(hit.dli_fname, '/');
            fn = s ? s + 1 : hit.dli_fname;
        }
        WCRLog("HIT   #%d -> com.tencent.xin   (orig=%s, caller=0x%llx %s, tid=%x)",
               gHitCount,
               origVal ? [origVal UTF8String] : "(nil)",
               pc, fn, (unsigned)(uintptr_t)pthread_self());
        WCRDumpStack();
        NSLog(@"[WCR] HIT #%d -> com.tencent.xin  (orig=%@)", gHitCount, origVal);
    } else if (gHitCount == kHITDetailLimit + 1) {
        WCRLog("HIT   ...后续命中不再逐条记录（见 #%d 的栈样本）", kHITDetailLimit);
    }

    WCRLeave();
    return kWCRFakeBid;
}

%end

/* ══════════════════════════════════════════════════════════════════════
 *  hook 2、3 —— WCR 0x15826f4 里和上面一起注册的窗口开合
 *  WCR 的实现就两条指令：flag=1 / flag=0，然后原样转发。
 *
 *  单独成组：类不存在时整组跳过。
 *  对应 WCR 用 MSHookMessageEx 的语义 —— 类不存在时返回 NULL，不崩。
 * ══════════════════════════════════════════════════════════════════════ */
%group FaceRecogGroup

%hook FaceRecogFlashHandler

/* WCR 0x1583034 */
- (id)initPipeline {
    gFlag = 1;
    WCRLog("WINDOW OPEN   self=%p tid=%x", (void *)self, (unsigned)(uintptr_t)pthread_self());
    NSLog(@"[WCR] WINDOW OPEN   self=%p", (void *)self);
    return %orig;
}

/* WCR 0x1583074：先置 0，再转发 */
- (void)dealloc {
    gFlag = 0;
    WCRLog("WINDOW CLOSE  self=%p tid=%x", (void *)self, (unsigned)(uintptr_t)pthread_self());
    NSLog(@"[WCR] WINDOW CLOSE  self=%p", (void *)self);
    %orig;
}

%end
%end

/* ══════════════════════════════════════════════════════════════════════ */
%ctor {
    @autoreleasepool {
        WCRPrepareOnce();          /* 先准备，此时零 hook */

        NSString *realBid = [[NSBundle mainBundle] bundleIdentifier];

        WCRLog("==============================================================");
        WCRLog("WCRBundleHook v4  (aligned to WCRefine 0x15826f4)");
        WCRLog("  real bundle id : %s", realBid ? [realBid UTF8String] : "(nil)");
        WCRLog("  app path       : %s", gAppPath ? gAppPath : "(nil)");
        WCRLog("  log file       : %s", gLogPath ? gLogPath : "(nil)");
        WCRLog("  reentry guard  : %s", gReentryReady ? "OK" : "FAILED");
        WCRLog("==============================================================");

        NSLog(@"[WCR] v4 loaded | bid=%@ | log=%s", realBid, gLogPath ? gLogPath : "(nil)");

        %init;                     /* NSBundle 组 */

        if (objc_getClass("FaceRecogFlashHandler")) {
            %init(FaceRecogGroup);
            WCRLog("FaceRecogFlashHandler found -> window group installed");
            NSLog(@"[WCR] FaceRecogFlashHandler found -> window group installed");
        } else {
            WCRLog("FaceRecogFlashHandler NOT found -> window group skipped");
            WCRLog("  => 窗口永远不会打开，bundleIdentifier 永远走原实现（安全降级）");
            NSLog(@"[WCR] FaceRecogFlashHandler NOT found");
        }
    }
}

/* ══════════════════════════════════════════════════════════════════════
 *  验证步骤
 * ══════════════════════════════════════════════════════════════════════
 *  1) 打包注入，打开微信。此时窗口是关的，日志里只会有 v4 loaded 那一段，
 *     不应该有任何 HIT / PASS 行 —— 有的话说明 flag 短路没生效，检查代码。
 *  2) 确认微信能正常登录、收到横幅推送。这一步必须过，否则说明
 *     还有别的 hook 或别的插件在读 bundleIdentifier。
 *  3) 进一次人脸/刷脸流程，然后退出。日志里应该出现：
 *         WINDOW OPEN   self=0x...
 *         HIT   -> com.tencent.xin   (orig=xxx, caller=0x...)
 *         WINDOW CLOSE  self=0x...
 *     如果只有 WINDOW OPEN 没有 HIT，看 PASS 行是三种里的哪一种：
 *       PASS self != mainBundle        → 查询对象不是主 bundle，正常
 *       PASS caller outside app image  → 调用者在别的镜像里，WCR 也会放行
 *       PASS stack too shallow         → 栈太浅，WCR 也会放行
 *  4) 日志文件在 /var/mobile/Containers/Data/Application/<UUID>/Documents/
 *     WCRBundleHook.log，用 Filza 搜索 WCRBundleHook.log 即可，
 *     不用去猜那个 UUID。
 *
 * ══════════════════════════════════════════════════════════════════════
 *  为什么这个窄窗口不会重演你之前遇到的两个 bug
 * ══════════════════════════════════════════════════════════════════════
 *  · 登录：窗口在 initPipeline 才打开，登录流程早就跑完了，读到的都是真 bid。
 *  · 横幅推送：APNs 的 aps-environment entitlement 来自签名，运行时改不了；
 *    微信上报 token 时窗口是关的，服务端拿到的还是真 bid，绑定关系正常。
 *    反过来，全时段伪装才会让服务端按正式版通道给测试设备下发 → 永远收不到。
 */

/*
 * Tweak.xm —— NSBundle -bundleIdentifier（对齐 WCRefine v5）
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  反汇编来源：WCRefine.dylib，静态初始化器 0x15826f4（193 个中的第 96 个）
 *
 *  ┌──┬──────────┬──────────────────────────┬───────────────┬──────────┐
 *  │# │ 注册点   │ 目标                      │ 新 IMP        │ 原 IMP 槽│
 *  ├──┼──────────┼──────────────────────────┼───────────────┼──────────┤
 *  │1 │ 0x1582764│ UIViewController         │ 0x1582c20     │ 0x2203440│
 *  │  │          │   -viewDidAppear:        │               │          │
 *  │2 │ 0x15827a0│ MMDiskUsageUtil (元类)    │ 0x1582c68     │ 0x2203448│
 *  │  │          │   +movePath:to:          │               │          │
 *  │3 │ 0x15827c0│ MMDiskUsageUtil (元类)    │ 0x1582db0     │ 0x2203450│
 *  │  │          │   +RemoveFile:           │               │          │
 *  │4 │ 0x15827f0│ NSBundle -bundleIdentifier│ 0x1582ec0     │ 0x2203458│
 *  │5 │ 0x1582820│ FaceRecogFlashHandler     │ 0x1583034     │ 0x2203460│
 *  │  │          │   -initPipeline          │               │          │
 *  │6 │ 0x1582850│ FaceRecogFlashHandler     │ 0x1583074     │ 0x2203468│
 *  │  │          │   -dealloc               │               │          │
 *  └──┴──────────┴──────────────────────────┴───────────────┴──────────┘
 *  （7~10 还有 SessionSelectController / ThemeBoxOperateView，与本功能无关）
 *
 * ── flag 的真相（v4 之前理解错了，这里纠正）────────────────────────────
 *  0x1583048:  adrp x9, #0x2203000
 *  0x158304c:  mov  w8, #1
 *  0x1583050:  strb w8, [x9, #0x560]      ; *(BYTE *)0x2203560 = 1
 *
 *  x9 来自 adrp（页对齐基址），所以 0x2203560 是【绝对地址的全局变量】，
 *  不是 FaceRecogFlashHandler 实例的 +0x560 成员偏移。
 *  全局扫描确认：该字节只有 3 处访问 —— 1 读(0x1582ed8) + 2 写(0x1583050/0x158308c)。
 *
 * ── 0x1582ec0 还原后的 C 代码（严格对照每条指令）───────────────────────
 *      BOOL spoof = NO;                                  // 0x1582eec mov w0,#0; str
 *      if (flag & 1) {                                   // 0x1582ed8 ldrb; 0x1582ef4 tbz #0
 *          NSBundle *mb = [NSBundle mainBundle];         // 0x1582f1c blr objc_msgSend
 *          if (self == mb)                               // 0x1582f48 subs; 0x1582f50 b.ne
 *              spoof = callerIsInsideAppImage();         // 0x1582f58 bl 0x159556c
 *      }
 *      // 0x1582f70 收敛点，清理 mb
 *      if (spoof) return @"com.tencent.xin";             // 0x1582fac cfstring 0x1f8fe88
 *      return orig(self, _cmd);                          // 0x1582ffc ldr 0x2203458; blr
 *
 * ── 0x159556c（callerIsInsideAppImage）还原 ─────────────────────────────
 *      NSArray *a = [NSThread callStackReturnAddresses]; // 0x159557c ldr 0x2073670 (NSThread)
 *      if ([a count] <= 2) return NO;                    // 0x15955c4 subs #2; 0x15955c8 b.hi
 *      unsigned long long pc =
 *          [[a objectAtIndexedSubscript:2] unsignedLongLongValue];  // 0x1595610 mov x2,#2
 *      Dl_info info = {0};                               // 0x1595630 movi v0.16b,#0 (清零32字节)
 *      if (dladdr(pc, &info) == 0) return NO;            // 0x1595674 cbz
 *      if (info.dli_fname == NULL) return NO;            // 0x159567c ldur [x29,#-0x50]; cbnz
 *      NSString *caller = [NSString stringWithUTF8String:info.dli_fname]; // 0x15956d0
 *      NSString *app    = [[NSBundle mainBundle] bundlePath];             // 0x1595730
 *      if ([app length] <= 0) return NO;                 // 0x1595788 subs #0; 0x1595790 b.ls
 *      return [caller hasPrefix:app];                    // 0x15957b0 blr
 *
 *  所有 selector 均已逐个核对：callStackReturnAddresses / count /
 *  objectAtIndexedSubscript: / unsignedLongLongValue / stringWithUTF8String: /
 *  mainBundle / bundlePath / length / hasPrefix:
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  v5 修掉了 v4 那个让它【整体静默失效】的 bug
 * ═══════════════════════════════════════════════════════════════════════
 *  v4 在 %ctor 里缓存了 [[NSBundle mainBundle] bundlePath]，还顺手打开了日志文件。
 *  但 %ctor 跑在 dyld 构造期、main() 之前 —— 那时 NSBundle 还没初始化完，
 *  bundlePath 拿到 nil；NSSearchPathForDirectoriesInDomains 也不可靠。
 *  后果：gAppPath == NULL 让调用者判定恒为 NO，hook 完全不生效；
 *        日志文件打不开，于是"一点日志都没有"。
 *
 *  WCR 为什么没事？—— 它的静态初始化器【只注册 hook】，一个多余的调用都没有。
 *  bundlePath 是等到窗口真正打开、App 早已跑起来之后才取的。
 *
 *  v5 的对策：一切推迟到运行时按需初始化（lazy），且失败可重试。
 *
 * 另外两条必须守住（v4 已做对，继续保留）：
 *   · flag 短路排第一：窗口外零开销，不比 self、不取栈
 *   · hook 体内不出现会反查 bundleIdentifier 的调用（用 TLS 守卫兜底）
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>          /* MSHookMessageEx —— 与 WCR 同一套注册方式 */
#import <dlfcn.h>
#import <pthread.h>
#import <dispatch/dispatch.h>
#import <sys/uio.h>
#import <sys/time.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdarg.h>
#import <string.h>
#import <stdlib.h>
#import <limits.h>

/* 0x1582fac 返回的 cfstring @0x1f8fe88，已核实内容为 "com.tencent.xin"(len=15) */
#define kWCRFakeBid @"com.tencent.xin"

#define kWCRLogName     "WCRBundleHook.log"
#define kWCRLogMaxBytes (1 * 1024 * 1024)
#define kWCRLogMaxLines 5000

/* callStackReturnAddresses 里取哪一帧。WCR 硬编码 x2 = 2（0x1595610）。 */
#define kWCROffsetInStack 2

/* 窗口内命中时，前多少次记完整调用栈 */
#define kHITDetailLimit   20

/* ══════════════════════════ 状态 ══════════════════════════ */

/* flag：对齐 WCR 的单字节 + bit0 测试（0x1582ed8 ldrb / 0x1582ef4 tbz #0）*/
static volatile uint8_t gFlag = 0;

/* 重入守卫（WCR 不需要，因为它的 hook 体是纯 C；我们要写日志，必须有）*/
static pthread_key_t gReentryKey;
static BOOL          gReentryReady = NO;

/* ── 下面两项全部【延迟初始化】，绝不在 %ctor 里取 ── */
static char  *gAppPath    = NULL;   /* WCR 每次实时取，这里缓存但保留重试能力 */
static size_t gAppPathLen = 0;

static int   gLogFD     = -1;
static int   gLogLines  = 0;
static BOOL  gLogTried  = NO;       /* 只尝试打开一次，失败就只走 NSLog */
static char  gNewline[] = "\n";     /* 可写数组：ObjC++ 下字面量是 const char[2] */

static int   gHitCount  = 0;
static BOOL  gWindowGroupInstalled = NO;

/* ══════════════════════ 重入守卫 ══════════════════════ */

static inline BOOL WCRIsReentrant(void) {
    if (!gReentryReady) return YES;
    return pthread_getspecific(gReentryKey) != NULL;
}
static inline void WCREnter(void) { if (gReentryReady) pthread_setspecific(gReentryKey, (void *)1); }
static inline void WCRLeave(void) { if (gReentryReady) pthread_setspecific(gReentryKey, NULL);      }

/* ══════════════════════ 日志（纯 POSIX）══════════════════════
 * 只在窗口内被调用；窗口外一行都不产生、一次 I/O 都不做。 */

static void WCRLog(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

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
    iov[0].iov_base = hdr;      iov[0].iov_len = (size_t)hn;
    iov[1].iov_base = body;     iov[1].iov_len = (size_t)n;
    iov[2].iov_base = gNewline; iov[2].iov_len = 1;
    writev(gLogFD, iov, 3);
    gLogLines++;
}

/* 窗口内 dump 前 8 帧，用来确认"到底谁在问 bid"以及帧索引选对没有 */
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
        WCRLog("        #%lu 0x%llx %-24s %s",
               (unsigned long)i, pc, f, info.dli_sname ? info.dli_sname : "");
    }
}

/* ══════════════════════ 延迟初始化 ══════════════════════
 * 第一次真正需要时才执行，此时 App 早已启动，NSBundle 完全可用。
 * 调用点全部在重入守卫之内，所以这里用 NSBundle / NSFileManager 是安全的。 */

static void WCRPrepareLazy(void) {
    /* --- bundlePath：对齐 WCR 的 [[NSBundle mainBundle] bundlePath] ---
     * 取不到就保持 NULL，下次再试 —— 绝不缓存失败结果。 */
    if (gAppPath == NULL) {
        @autoreleasepool {
            NSString *p = [[NSBundle mainBundle] bundlePath];
            if (p && [p length] > 0) {
                const char *u = [p fileSystemRepresentation];
                if (u) {
                    char *dup = strdup(u);
                    if (dup) { gAppPath = dup; gAppPathLen = strlen(gAppPath); }
                }
            }
        }
        if (gAppPath) WCRLog("INIT bundlePath acquired: %s", gAppPath);
        else          WCRLog("INIT bundlePath NOT available yet (will retry)");
    }

    /* --- 日志文件：多路径回退，只试一次 --- */
    if (!gLogTried) {
        gLogTried = YES;
        @autoreleasepool {
            NSMutableArray *cands = [NSMutableArray array];
            NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                                NSUserDomainMask, YES);
            if ([docs count] > 0) {
                [cands addObject:[docs objectAtIndex:0]];
            }
            [cands addObject:NSTemporaryDirectory()];
            [cands addObject:@"/var/mobile/Documents"];

            for (NSString *dir in cands) {
                if (!dir) continue;
                [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                          withIntermediateDirectories:YES
                                                           attributes:nil
                                                                error:NULL];
                NSString *lp = [dir stringByAppendingPathComponent:@(kWCRLogName)];
                const char *u = [lp fileSystemRepresentation];
                if (!u) continue;

                struct stat st;
                if (stat(u, &st) == 0 && st.st_size > (off_t)kWCRLogMaxBytes) truncate(u, 0);

                int fd = open(u, O_WRONLY | O_CREAT | O_APPEND, 0644);
                if (fd >= 0) {
                    gLogFD = fd;
                    NSLog(@"[WCR] log opened: %s", u);
                    WCRLog("INIT log opened: %s", u);
                    break;
                }
            }
            if (gLogFD < 0) {
                NSLog(@"[WCR] WARNING: cannot open any log file, NSLog only");
            }
        }
    }
}

/* ══════════════════════ WCR 0x159556c ══════════════════════ */

static BOOL WCRCallerIsInAppImage(unsigned long long pc) {
    if (pc == 0) return NO;

    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr((const void *)(uintptr_t)pc, &info) == 0) return NO;   /* 0x1595674 cbz   */
    if (info.dli_fname == NULL) return NO;                            /* 0x1595680 cbnz */

    if (gAppPath == NULL || gAppPathLen == 0) return NO;              /* [app length]>0 */
    return strncmp(info.dli_fname, gAppPath, gAppPathLen) == 0;       /* hasPrefix:     */
}

/* ══════════════════════════════════════════════════════════════════════
 *  hook 1/3 —— WCR 0x1582ec0：NSBundle -bundleIdentifier
 * ══════════════════════════════════════════════════════════════════════ */
%hook NSBundle

- (NSString *)bundleIdentifier {
    /* ⓿ 重入：无条件走原实现 */
    if (WCRIsReentrant()) return %orig;

    /* ❶ flag 短路 —— WCR 0x1582ed8 ldrb / 0x1582ef4 tbz #0
     *    窗口外直接跳原实现：不比 self、不取栈、不写日志、不做 I/O。
     *    整个 hook 的常驻开销 = 一次 volatile 字节读 + 一次位测试。 */
    if ((gFlag & 1) == 0) return %orig;

    WCREnter();

    /* 延迟初始化：第一次进窗口时才取 bundlePath、才开日志 */
    WCRPrepareLazy();

    /* ❷ 只认 mainBundle —— WCR 0x1582f1c / 0x1582f48 subs / 0x1582f50 b.ne */
    if (self != [NSBundle mainBundle]) {
        WCRLog("PASS  self != mainBundle");
        WCRLeave();
        return %orig;
    }

    /* ❸ 调用者归属 —— WCR 0x1582f58 bl 0x159556c */
    NSArray *addrs = [NSThread callStackReturnAddresses];
    if ([addrs count] <= 2) {
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
        WCRLog("PASS  caller outside app image: 0x%llx %s  (appPath=%s)",
               pc, f, gAppPath ? gAppPath : "(NULL)");
        WCRLeave();
        return %orig;
    }

    /* 命中 —— WCR 0x1582fac：返回常量串。
     * 这里额外调一次 %orig 只为写日志（原实现是一次无副作用的读取）。 */
    gHitCount++;
    if (gHitCount <= kHITDetailLimit) {
        NSString *origVal = %orig;
        Dl_info hit; memset(&hit, 0, sizeof(hit));
        const char *fn = "(?)";
        if (dladdr((const void *)(uintptr_t)pc, &hit) != 0 && hit.dli_fname) {
            const char *s = strrchr(hit.dli_fname, '/');
            fn = s ? s + 1 : hit.dli_fname;
        }
        WCRLog("HIT   #%d -> com.tencent.xin  (orig=%s, caller=0x%llx %s, tid=0x%llx)",
               gHitCount,
               origVal ? [origVal UTF8String] : "(nil)",
               pc, fn, (unsigned long long)(uintptr_t)pthread_self());
        WCRDumpStack();
        NSLog(@"[WCR] HIT #%d -> com.tencent.xin (orig=%@)", gHitCount, origVal);
    } else if (gHitCount == kHITDetailLimit + 1) {
        WCRLog("HIT   ...后续命中不再逐条记录（见前 %d 条的栈样本）", kHITDetailLimit);
    }

    WCRLeave();
    return kWCRFakeBid;
}

%end

/* ══════════════════════════════════════════════════════════════════════
 *  hook 2/3 —— 窗口开合。WCR 的实现就两条指令：
 *      0x158304c mov w8,#1 ; 0x1583050 strb w8,[x9,#0x560] ; 然后转发
 *      0x158308c strb wzr,[x8,#0x560]                      ; 然后转发
 *
 *  这里【不用 %group / %hook】，改成直接调 MSHookMessageEx，两个原因：
 *   1) 需要在任意时机重复尝试注册（类可能懒加载），而 Logos 禁止对同一个
 *      %group 两次 %init —— 就是这次编译报的 "re-%init" 错误。
 *   2) WCR 本身就是直接调 MSHookMessageEx，而且 dealloc 的 selector 是用
 *      sel_registerName("dealloc") 现拿的（0x1582834）—— 这样写才是一致的。
 * ══════════════════════════════════════════════════════════════════════ */

static IMP gOrigInitPipeline = NULL;
static IMP gOrigDealloc      = NULL;

static id WCRNewInitPipeline(id self, SEL _cmd) {
    gFlag = 1;
    WCRLog("WINDOW OPEN   self=0x%llx tid=0x%llx",
           (unsigned long long)(uintptr_t)self, (unsigned long long)(uintptr_t)pthread_self());
    NSLog(@"[WCR] WINDOW OPEN   self=0x%llx", (unsigned long long)(uintptr_t)self);
    if (!gOrigInitPipeline) return nil;
    return ((id (*)(id, SEL))gOrigInitPipeline)(self, _cmd);
}

static void WCRNewDealloc(id self, SEL _cmd) {
    gFlag = 0;
    WCRLog("WINDOW CLOSE  self=0x%llx tid=0x%llx",
           (unsigned long long)(uintptr_t)self, (unsigned long long)(uintptr_t)pthread_self());
    NSLog(@"[WCR] WINDOW CLOSE  self=0x%llx", (unsigned long long)(uintptr_t)self);
    if (gOrigDealloc) ((void (*)(id, SEL))gOrigDealloc)(self, _cmd);
}

/* 可重入调用：成功返回 YES。类不存在返回 NO，供调用方决定要不要重试。
 * 用 NSClassFromString 而不是 objc_getClass —— 它返回的就是 Class，
 * 省掉一次 ObjC 指针 → Class 的强制转换（那一步在 ARC 下要 __bridge，
 * 在 MRR 下又不需要，容易踩）。两者语义等价，内部实现同为 objc_getClass。 */
static BOOL WCRInstallFaceRecogHooks(void) {
    Class c = NSClassFromString(@"FaceRecogFlashHandler");
    if (!c) return NO;

    MSHookMessageEx(c, @selector(initPipeline),
                    (IMP)WCRNewInitPipeline, &gOrigInitPipeline);
    MSHookMessageEx(c, sel_registerName("dealloc"),
                    (IMP)WCRNewDealloc, &gOrigDealloc);

    return (gOrigInitPipeline != NULL);
}

/* ══════════════════════════════════════════════════════════════════════ */
%ctor {
    /* 这里只做三件事，全部不触碰 NSBundle / NSFileManager。
     * 对齐 WCR：它的静态初始化器同样只注册 hook。 */

    if (pthread_key_create(&gReentryKey, NULL) == 0) gReentryReady = YES;

    %init;                                   /* 默认组，只装 NSBundle 这一个 hook */

    if (WCRInstallFaceRecogHooks()) {
        gWindowGroupInstalled = YES;
        NSLog(@"[WCR] v5 loaded | FaceRecogFlashHandler found -> window hooks installed");
    } else {
        /* 类可能是懒加载的，稍后主线程上再试一次。
         * 手动注册才允许这样重复调用 —— %group 版会触发 Logos 的 re-%init 报错。 */
        NSLog(@"[WCR] v5 loaded | FaceRecogFlashHandler NOT found, will retry in 3s");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            if (!gWindowGroupInstalled && WCRInstallFaceRecogHooks()) {
                gWindowGroupInstalled = YES;
                NSLog(@"[WCR] retry OK -> window hooks installed");
                WCRLog("INIT retry OK -> window hooks installed");
            } else if (!gWindowGroupInstalled) {
                NSLog(@"[WCR] retry FAILED: class still missing");
                WCRLog("INIT retry FAILED: FaceRecogFlashHandler still missing");
            }
        });
    }

    NSLog(@"[WCR] v5 loaded | reentryGuard=%@", gReentryReady ? @"OK" : @"FAILED");
}

/* ══════════════════════════════════════════════════════════════════════
 *  验证
 * ══════════════════════════════════════════════════════════════════════
 *  1) 打开微信。窗口是关的，日志里什么都不该有 —— 有就说明 flag 短路失效。
 *  2) 确认能正常登录、能收横幅推送。这步必须过。
 *  3) 走一次刷脸。预期日志：
 *         INIT bundlePath acquired: /var/containers/Bundle/.../WeChat.app
 *         INIT log opened: /var/mobile/Containers/Data/.../Documents/WCRBundleHook.log
 *         WINDOW OPEN   self=0x...
 *         HIT   #1 -> com.tencent.xin  (orig=xxx, caller=0x... WeChat)
 *         WINDOW CLOSE  self=0x...
 *
 *  排障对照表：
 *   ┌────────────────────────────────┬──────────────────────────────────┐
 *   │ 现象                            │ 原因与处理                        │
 *   ├────────────────────────────────┼──────────────────────────────────┤
 *   │ INIT bundlePath NOT available  │ NSBundle 仍不可用，重试即可；      │
 *   │ (反复出现)                      │ 若一直是这个，说明宿主环境异常    │
 *   │ PASS caller outside app image  │ 帧索引不对，改 kWCROffsetInStack  │
 *   │                                │ 为 1 或 3，对照栈 dump 定位       │
 *   │ PASS stack too shallow         │ 被调用时栈太浅，WCR 同样会放行    │
 *   │ 只有 WINDOW OPEN 没有 HIT      │ 见上面三条 PASS                   │
 *   │ 类 still missing               │ 这个微信版本里没 FaceRecogFlash-  │
 *   │                                │ Handler，窗口开不了，功能不适用   │
 *   └────────────────────────────────┴──────────────────────────────────┘
 *
 *  日志路径回退顺序：<App>/Documents → NSTemporaryDirectory() → /var/mobile/Documents
 *  用 Filza 搜文件名 WCRBundleHook.log 即可，不用去猜 Container 的 UUID。
 *  无论文件能否打开，关键事件都会 NSLog，可用 macOS 控制台 / idevicesyslog 看。
 */

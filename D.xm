// WCPScout.xm — 纯诊断 dylib（不改 bid、不 spoof，只记录登录闸门调用）
//
// 目的：在【证书签名 sideload、无法用 Frida、且通常非越狱】的环境下，把
//       "微信登录时哪个方法在读/比对该 bundle id" 精准记录到沙盒文件，
//       从而定位 WCPulse 真正 hook 的闸门 selector（静态读不出）。
//
// ★ 关键修复（v2）：改用 ObjC 运行时 method swizzling（method_setImplementation），
//   不依赖 Substrate / CydiaSubstrate。上一版用 Logos %hook，%hook 需要 Substrate
//   在场；非越狱 sideload 环境里 Substrate 不存在 → dylib 因找不到 MSHookMessageEx
//   符号直接加载失败 → 沙盒里一个字节日志都没有。改用运行时 swizzle 后，只要 dylib
//   被注入，就会在加载阶段（__attribute__((constructor))）立刻写一条启动标记，
//   日志文件必然生成，从而把"dylib 没注入"和"hook 没命中"区分开。
//
// 原理：
//   1) 本 dylib 注入 IPA 后运行在微信沙盒内，可直接 fopen 写
//      NSHomeDirectory()/Documents/WCPGateLog.txt（沙盒内写文件不受限制）。
//   2) 运行时替换 [NSBundle -bundleIdentifier]：仅当接收者是主 bundle 时记录调用栈，
//      并把 PC 用 ObjC 运行时方法表反查成 (类名 + selector)。发布版微信符号被 strip，
//      backtrace 只有地址，必须在运行时自己符号化。
//   3) 运行时替换 [NSString -isEqualToString:]/[NSString -isEqual:]（含 __NSCFString
//      具体子类）：当任一端包含 "com.tencent.xin" 或 "com.tencent.qy.xin" 时记录
//      调用方 —— 这正是登录闸门做 bid 比对的现场，命中即闸门方法。
//   4) 按 (cls+sel) 去重，日志只保留「不同的调用方」，文件小且直指闸门。
//
// 注意：本 scout 不 spoof，所以注入后登录【仍会被闸门挡住】——这没问题，
//       我们就是要它在被挡的那一刻把闸门方法名记下来。拿到 selector 后
//       再换 WCPulseLite.xm 精准 hook 该方法即可。
//
// 构建（★ 关键：自包含 dylib，不依赖 theos / 不链 Substrate，非越狱 sideload 也能加载）──
//   用 clang 直接把本文件（已是纯 ObjC，无 Logos 指令）编成动态库：
//
//   SDK=$(xcrun -sdk iphoneos --show-sdk-path)
//   clang -dynamiclib -arch arm64 -arch arm64e \
//       -target arm64-apple-ios14.0 -isysroot "$SDK" \
//       -fno-objc-arc -framework Foundation \
//       -install_name @executable_path/WCPScout.dylib \
//       -x objective-c WCPScout.xm -o WCPScout.dylib
//
//   然后把它当普通 dylib 注入 IPA（insert_dylib + 重签）后 sideload，
//   注入方式与你注入 WCPulse 完全一致即可。
//   若你坚持用 theos：tweak 目标会强制链 Substrate，非越狱环境加载会失败——
//   请勿用 theos tweak，改成上面的 clang 直编或 theos 的 library 类型。
//
// 取日志：在 WeChat 的 Info.plist 里加 UIFileSharingEnabled=true，
//         用访达/Finder「文件共享」或任意可访问 App 容器的工具把
//         Documents/WCPGateLog.txt 拖出来即可。
//         若 sideload 后【仍无任何文件】，说明 dylib 根本没被注入（不是 hook 问题），
//         需检查 insert_dylib 是否写入 LC_LOAD_DYLIB 且已随 IPA 重签。

#import <Foundation/Foundation.h>   // 必须放在最前：提供全部 Foundation 类与 NSHomeDirectory
#import <string.h>                  // 保证 strncpy 等 C 函数在模块模式下可见（iOS 26.5 SDK 模块默认开启）
#import <pthread.h>                  // 后台线程建符号表，避免启动卡死
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <execinfo.h>
#import <stdio.h>

// ⚠️ 不要在此文件写 `@class NSString;` / `@class NSBundle;` 之类的手写前向声明：
//   在 iOS 26.5 SDK（模块默认开启）下，前向声明会阻止 Foundation 模块导入且自身不暴露方法，
//   触发 "unknown type name" / "forward declaration" 系列编译错误。需要类声明就靠上面的 Foundation import。

// ── 运行时方法表（用于把 PC 反查成 类+selector）─────────────────────────
typedef struct { void *imp; const char *cls; const char *sel; } MethodRec;
static MethodRec *gMap = NULL;
static int gMapCount = 0;
static NSMutableData *gMapBuf = nil;          // 持有缓冲区，防止 realloc 失效
static BOOL gInited = NO;                      // 日志文件已打开标志
static BOOL gMapReady = NO;                    // 符号表是否已建好（建好前 hook 命中仍记原始 PC）

static int cmp_rec(const void *a, const void *b) {
    uintptr_t ia = (uintptr_t)((MethodRec *)a)->imp;
    uintptr_t ib = (uintptr_t)((MethodRec *)b)->imp;
    return ia < ib ? -1 : (ia > ib ? 1 : 0);
}

static void build_method_map(void) {
    int imgCount = (int)_dyld_image_count();
    gMapBuf = [NSMutableData data];
    for (int i = 0; i < imgCount; i++) {
        const char *img = _dyld_get_image_name(i);
        if (!img) continue;
        // ★ 跳过系统框架（/System/Library、/usr/lib），只扫 App 自己的镜像，
        //   量级砍掉 90%+，避免启动卡死。登录闸门几乎必在 App 自身代码里。
        if (strncmp(img, "/System/Library/", 15) == 0 ||
            strncmp(img, "/usr/lib/", 9) == 0) continue;
        unsigned int clsCount = 0;
        const char **names = objc_copyClassNamesForImage(img, &clsCount);
        if (!names) continue;
        for (unsigned int c = 0; c < clsCount; c++) {
            Class cls = objc_getClass(names[c]);
            if (!cls) continue;
            // 实例方法
            unsigned int mCount = 0;
            Method *ms = class_copyMethodList(cls, &mCount);
            for (unsigned int m = 0; m < mCount; m++) {
                IMP imp = method_getImplementation(ms[m]);
                if (!imp) continue;
                MethodRec r;
                r.imp = (void *)imp;
                r.cls = class_getName(cls);
                r.sel = sel_getName(method_getName(ms[m]));
                [gMapBuf appendBytes:&r length:sizeof(r)];
            }
            free(ms);
            // 类方法（元类）
            Class meta = object_getClass(cls);
            unsigned int cmCount = 0;
            Method *cms = class_copyMethodList(meta, &cmCount);
            for (unsigned int m = 0; m < cmCount; m++) {
                IMP imp = method_getImplementation(cms[m]);
                if (!imp) continue;
                MethodRec r;
                r.imp = (void *)imp;
                r.cls = class_getName(cls);
                r.sel = sel_getName(method_getName(cms[m]));
                [gMapBuf appendBytes:&r length:sizeof(r)];
            }
            free(cms);
        }
        free(names);
    }
    gMap = (MethodRec *)[gMapBuf mutableBytes];
    gMapCount = (int)([gMapBuf length] / sizeof(MethodRec));
    qsort(gMap, gMapCount, sizeof(MethodRec), cmp_rec);
    gMapReady = YES;   // ★ 建表完成才允许符号化
}

// 后台线程建表：不阻塞微信启动（原同步建表会卡几十秒）
static void *map_builder_thread(void *arg) {
    build_method_map();
    NSLog(@"[WCPScout] method map built (%d methods), ready", gMapCount);
    return NULL;
}

// 反查：找到 imp <= pc 且最大者（即包含 pc 的方法，方法间不重叠）
static void resolve_caller(uintptr_t pc, char *outCls, char *outSel, size_t n) {
    outCls[0] = 0; outSel[0] = 0;
    if (!gMap || gMapCount == 0 || pc == 0) return;
    int lo = 0, hi = gMapCount - 1, best = -1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        uintptr_t imp = (uintptr_t)gMap[mid].imp;
        if (imp <= pc) { best = mid; lo = mid + 1; }
        else hi = mid - 1;
    }
    if (best >= 0) {
        strncpy(outCls, gMap[best].cls, n - 1); outCls[n - 1] = 0;
        strncpy(outSel, gMap[best].sel, n - 1); outSel[n - 1] = 0;
    }
}

// ── 日志 ────────────────────────────────────────────────────────────────
static FILE *gLog = NULL;
static int gLogged = 0;
static const int kMaxEntries = 400;
static NSLock *gLogLock = nil;
static NSMutableSet *gSeen = nil;

static void open_log_file(void) {
    if (gLog) return;
    // 优先写沙盒 Documents（可被文件共享取出）
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/WCPGateLog.txt"];
    gLog = fopen([path UTF8String], "a");
    // 把实际尝试的绝对路径 + 成败打到 syslog：设备控制台一眼确认是「没加载」还是「路径/权限问题」
    NSLog(@"[WCPScout] try path=%@ => %s", path, gLog ? "OK" : "FAIL(fopen)");
    // Documents 不可写时的兜底路径（越狱或某些环境下可访问）
    if (!gLog) {
        gLog = fopen("/tmp/WCPGateLog.txt", "a");
        NSLog(@"[WCPScout] fallback /tmp/WCPGateLog.txt => %s", gLog ? "OK" : "FAIL(fopen)");
    }
}

static void ensure_log(void) {
    if (gInited) {
        open_log_file();
        return;
    }
    // ★ 先落启动标记：只要 dylib 被加载，文件必然生成。即使后面 build_method_map
    //   在某些环境异常，也不影响「dylib 有没有加载」的判定。
    open_log_file();
    if (gLog) {
        NSDate *now = [NSDate date];
        fprintf(gLog, "=== WCPScout loaded %s ===\n", [[now description] UTF8String]);
        fflush(gLog);
    }
    // 次要信号：写一行 syslog，设备控制台/日志工具可捕获（作为 Documents 不可见时的兜底）
    NSLog(@"[WCPScout] dylib loaded (substrate-free, runtime-swizzle)");
    // ★ 后台线程建符号表，启动不卡顿；建好前 hook 命中也会照常记原始 PC
    pthread_t t;
    if (pthread_create(&t, NULL, map_builder_thread, NULL) == 0) pthread_detach(t);
    gLogLock = [[NSLock alloc] init];
    gSeen = [[NSMutableSet alloc] init];
    gInited = YES;
}

// 记录一条去重后的调用现场（syms 为 backtrace 文本，可为 NULL）
static void log_gate(const char *tag, uintptr_t pc, NSString *detail, char **syms, int n) {
    if (!gLog || gLogged >= kMaxEntries) return;
    char cls[256], sel[256];
    resolve_caller(pc, cls, sel, sizeof(cls));
    // 符号表未建好时 cls/sel 为空 —— 仍照常记录原始 PC + 比对串，绝不漏掉闸门
    const char *clsS = (cls[0] ? cls : "??");
    const char *selS = (sel[0] ? sel : "??");
    NSString *key;
    if (cls[0] && sel[0]) key = [NSString stringWithFormat:@"%s.%s", cls, sel];
    else key = [NSString stringWithFormat:@"pc=0x%lx", pc];   // 未符号化时按 PC 去重
    [gLogLock lock];
    BOOL seen = [gSeen containsObject:key];
    if (!seen) {
        [gSeen addObject:key];
        fprintf(gLog, "\n[%s] %s\n  callerPC=0x%lx  => -[%s %s]\n",
                tag, [detail UTF8String], pc, clsS, selS);
        if (syms) {
            for (int k = 1; k < n; k++) {
                if (syms[k]) fprintf(gLog, "    %s\n", syms[k]);
            }
        }
        fflush(gLog);
        gLogged++;
    }
    [gLogLock unlock];
}

// ── 运行时 swizzle（不依赖 Substrate）──────────────────────────────────
static void swizzle_set(Class cls, SEL sel, IMP repl, IMP *origStore) {
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    if (origStore) *origStore = method_getImplementation(m);
    method_setImplementation(m, repl);
}

// ── hook 1：bundleIdentifier（聚焦主 bundle 读取）────────────────────────
static NSString *(*gOrigBundleID)(id, SEL) = NULL;
static NSString *wcpscout_bundleIdentifier(id self, SEL _cmd) {
    NSString *real = gOrigBundleID ? gOrigBundleID(self, _cmd) : nil;
    if (self == [NSBundle mainBundle]) {
        ensure_log();
        void *frames[24];
        int n = backtrace(frames, 24);
        uintptr_t pc = (n > 2) ? (uintptr_t)frames[2] : 0;   // frames[2] = bundleIdentifier 的调用方
        char **syms = backtrace_symbols(frames, n);
        log_gate("bundleIdentifier(mainBundle)", pc,
                 [NSString stringWithFormat:@"returned=%@", real], syms, n);
        if (syms) free(syms);
    }
    return real;
}

// ── hook 2/3：NSString 比较（捕获 bid 比对现场）──────────────────────────
static void scout_compare(NSString *aStr, NSString *bStr) {
    const char *a = aStr ? [aStr UTF8String] : NULL;
    const char *b = bStr ? [bStr UTF8String] : NULL;
    if ((a && (strstr(a, "com.tencent.xin") || strstr(a, "com.tencent.qy.xin"))) ||
        (b && (strstr(b, "com.tencent.xin") || strstr(b, "com.tencent.qy.xin")))) {
        ensure_log();
        void *frames[24];
        int n = backtrace(frames, 24);
        uintptr_t pc = (n > 2) ? (uintptr_t)frames[2] : 0;
        char **syms = backtrace_symbols(frames, n);
        log_gate("isEqual(com.tencent)", pc,
                 [NSString stringWithFormat:@"\"%@\" ==? \"%@\"", aStr, bStr], syms, n);
        if (syms) free(syms);
    }
}

// NSString 基类路径（普通 NSString 实例极少，但保留以防）
static BOOL (*gOrigES_NS)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_es_NS(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigES_NS ? gOrigES_NS(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigEq_NS)(id, SEL, id) = NULL;
static BOOL wcpscout_eq_NS(id self, SEL _cmd, id o) {
    BOOL r = gOrigEq_NS ? gOrigEq_NS(self, _cmd, o) : NO;
    if ([o isKindOfClass:[NSString class]]) scout_compare((NSString *)self, (NSString *)o);
    return r;
}

// __NSCFString 具体子类路径（@"..." 字面量实际都是它，主战场）
static BOOL (*gOrigES_CF)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_es_CF(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigES_CF ? gOrigES_CF(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigEq_CF)(id, SEL, id) = NULL;
static BOOL wcpscout_eq_CF(id self, SEL _cmd, id o) {
    BOOL r = gOrigEq_CF ? gOrigEq_CF(self, _cmd, o) : NO;
    if ([o isKindOfClass:[NSString class]]) scout_compare((NSString *)self, (NSString *)o);
    return r;
}

// ── hook 4/5/6：其余 bid 比对方式（compare:/hasPrefix:/rangeOfString:/containsString:）──
//   WCPGateLog 实证：登录闸门对 bid 的比对【没走 isEqualToString】，而是走下面这些之一，
//   所以原版 scout 漏抓了真正的闸门调用方。补齐后，在【登录那一刻】跑即可定位。
static NSComparisonResult (*gOrigCmp_NS)(id, SEL, NSString *) = NULL;
static NSComparisonResult wcpscout_cmp_NS(id self, SEL _cmd, NSString *a) {
    NSComparisonResult r = gOrigCmp_NS ? gOrigCmp_NS(self, _cmd, a) : NSOrderedSame;
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigPre_NS)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_pre_NS(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigPre_NS ? gOrigPre_NS(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}
static NSRange (*gOrigRng_NS)(id, SEL, NSString *) = NULL;
static NSRange wcpscout_rng_NS(id self, SEL _cmd, NSString *a) {
    NSRange r = gOrigRng_NS ? gOrigRng_NS(self, _cmd, a) : (NSRange){NSNotFound,0};
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigCtn_NS)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_ctn_NS(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigCtn_NS ? gOrigCtn_NS(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}

static NSComparisonResult (*gOrigCmp_CF)(id, SEL, NSString *) = NULL;
static NSComparisonResult wcpscout_cmp_CF(id self, SEL _cmd, NSString *a) {
    NSComparisonResult r = gOrigCmp_CF ? gOrigCmp_CF(self, _cmd, a) : NSOrderedSame;
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigPre_CF)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_pre_CF(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigPre_CF ? gOrigPre_CF(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}
static NSRange (*gOrigRng_CF)(id, SEL, NSString *) = NULL;
static NSRange wcpscout_rng_CF(id self, SEL _cmd, NSString *a) {
    NSRange r = gOrigRng_CF ? gOrigRng_CF(self, _cmd, a) : (NSRange){NSNotFound,0};
    scout_compare((NSString *)self, a);
    return r;
}
static BOOL (*gOrigCtn_CF)(id, SEL, NSString *) = NULL;
static BOOL wcpscout_ctn_CF(id self, SEL _cmd, NSString *a) {
    BOOL r = gOrigCtn_CF ? gOrigCtn_CF(self, _cmd, a) : NO;
    scout_compare((NSString *)self, a);
    return r;
}

// ── hook 7：NSArray containsObject:（兜底"allowList 集合校验"型闸门）──
//   WCPGateLog 实证：登录闸门对 bid【没有】字符串比对（isEqualToString/compare/… 全挂了都没抓到）。
//   仅剩的合理客户端形态是集合校验，如 [allowedBundleIDs containsObject: bundleID]。
//   这里只在该对象含 bid 子串时记录【数组内容】，从而直接看到 allowList 里有哪些 id。
static BOOL (*gOrigContains)(id, SEL, id) = NULL;
static BOOL wcpscout_contains(id self, SEL _cmd, id obj) {
    BOOL r = gOrigContains ? gOrigContains(self, _cmd, obj) : NO;
    if ([obj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)obj;
        if ([s rangeOfString:@"com.tencent.xin"].location != NSNotFound ||
            [s rangeOfString:@"com.tencent.qy.xin"].location != NSNotFound) {
            ensure_log();
            void *frames[24];
            int n = backtrace(frames, 24);
            uintptr_t pc = (n > 2) ? (uintptr_t)frames[2] : 0;
            char **syms = backtrace_symbols(frames, n);
            NSString *arrDesc = [self description];
            log_gate("containsObject(com.tencent)", pc,
                     [NSString stringWithFormat:@"array contains \"%@\" ? array=%@", s, arrDesc], syms, n);
            if (syms) free(syms);
        }
    }
    return r;
}

__attribute__((constructor))
static void wcpscout_load(void) {
    ensure_log();   // 立刻写启动标记，证明 dylib 已加载（即使后面没有任何 hook 命中也能看到文件）
    Class b  = objc_getClass("NSBundle");
    Class s  = objc_getClass("NSString");
    Class cf = NSClassFromString(@"__NSCFString");
    swizzle_set(b, @selector(bundleIdentifier), (IMP)wcpscout_bundleIdentifier, (IMP *)&gOrigBundleID);
    swizzle_set(s, @selector(isEqualToString:), (IMP)wcpscout_es_NS, (IMP *)&gOrigES_NS);
    swizzle_set(s, @selector(isEqual:),         (IMP)wcpscout_eq_NS, (IMP *)&gOrigEq_NS);
    // 其余比对方式（抓登录闸门用）
    swizzle_set(s, @selector(compare:),              (IMP)wcpscout_cmp_NS, (IMP *)&gOrigCmp_NS);
    swizzle_set(s, @selector(hasPrefix:),            (IMP)wcpscout_pre_NS, (IMP *)&gOrigPre_NS);
    swizzle_set(s, @selector(rangeOfString:),         (IMP)wcpscout_rng_NS, (IMP *)&gOrigRng_NS);
    swizzle_set(s, @selector(containsString:),        (IMP)wcpscout_ctn_NS, (IMP *)&gOrigCtn_NS);
    if (cf) {
        swizzle_set(cf, @selector(isEqualToString:), (IMP)wcpscout_es_CF, (IMP *)&gOrigES_CF);
        swizzle_set(cf, @selector(isEqual:),         (IMP)wcpscout_eq_CF, (IMP *)&gOrigEq_CF);
        swizzle_set(cf, @selector(compare:),         (IMP)wcpscout_cmp_CF, (IMP *)&gOrigCmp_CF);
        swizzle_set(cf, @selector(hasPrefix:),       (IMP)wcpscout_pre_CF, (IMP *)&gOrigPre_CF);
        swizzle_set(cf, @selector(rangeOfString:),    (IMP)wcpscout_rng_CF, (IMP *)&gOrigRng_CF);
        swizzle_set(cf, @selector(containsString:),   (IMP)wcpscout_ctn_CF, (IMP *)&gOrigCtn_CF);
    }
    // hook 7：NSArray containsObject:（allowList 集合校验型闸门兜底）
    Class arr = objc_getClass("NSArray");
    if (arr) swizzle_set(arr, @selector(containsObject:), (IMP)wcpscout_contains, (IMP *)&gOrigContains);
    // 具体子类（@[] 字面量多为 __NSArrayI，可变数组为 __NSArrayM；抽象 NSArray 版本可能被它们覆盖）
    Class ai = NSClassFromString(@"__NSArrayI");
    if (ai) swizzle_set(ai, @selector(containsObject:), (IMP)wcpscout_contains, (IMP *)&gOrigContains);
    Class am = NSClassFromString(@"__NSArrayM");
    if (am) swizzle_set(am, @selector(containsObject:), (IMP)wcpscout_contains, (IMP *)&gOrigContains);
}

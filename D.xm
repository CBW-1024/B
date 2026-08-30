// WCPScout.xm — 纯诊断 dylib（不改 bid、不 spoof，只记录登录闸门调用）
//
// 目的：在【证书签名 sideload、无法用 Frida】的环境下，把"微信登录时
//       哪个方法在读/比对该 bundle id"精准记录到沙盒文件，从而定位 WCPulse
//       真正 hook 的闸门 selector（之前这个被混淆藏死了，静态读不出）。
//
// 原理：
//   1) 本 dylib 注入 IPA 后运行在微信沙盒内，可直接 fopen 写
//      NSHomeDirectory()/Documents/WCPGateLog.txt（沙盒内写文件不受限制，
//      无需控制台/无需 Frida）。
//   2) hook [NSBundle -bundleIdentifier]：仅当接收者是主 bundle 时记录调用栈，
//      并把返回地址用 ObjC 运行时方法表反查成 (类名 + selector 名) ——
//      因为发布版微信符号被 strip，backtrace 只有地址，必须在运行时自己符号化。
//   3) hook [NSString -isEqualToString:]/[NSString -isEqual:]：当任一端包含
//      "com.tencent.xin" 或 "com.tencent.qy.xin" 时记录调用方 —— 这正是
//      登录闸门做 bid 比对的现场，命中即闸门方法。
//   4) 按 (cls+sel) 去重，日志只保留「不同的调用方」，文件小且直指闸门。
//
// 注意：本 scout 不 spoof，所以注入后登录【仍会被闸门挡住】——这没问题，
//       我们就是要它在被挡的那一刻把闸门方法名记下来。拿到 selector 后
//       再换 WCPulseLite.xm（v6）精准 hook 该方法即可。
//
// 构建（theos）：
//   WCPScout_FILES = WCPScout.xm
//   WCPScout_FRAMEWORKS = Foundation
//   make package
// 然后把它当普通 dylib 注入 IPA（与你注入 WCPulse 同一套流程），重签 sideload。
//
// 取日志：在 WeChat 的 Info.plist 里加 UIFileSharingEnabled=true，
//         用访达/Finder「文件共享」或任意可访问 App 容器的工具把
//         Documents/WCPGateLog.txt 拖出来即可。

#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <execinfo.h>
#import <stdio.h>

// ── 运行时方法表（用于把 PC 反查成 类+selector）─────────────────────────
typedef struct { void *imp; const char *cls; const char *sel; } MethodRec;
static MethodRec *gMap = NULL;
static int gMapCount = 0;
static NSMutableData *gMapBuf = nil;          // 持有缓冲区，防止 realloc 失效
static dispatch_once_t gMapInit = 0;

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

static void ensure_log(void) {
    dispatch_once(&gMapInit, ^{
        build_method_map();
        gLogLock = [[NSLock alloc] init];
        gSeen = [[NSMutableSet alloc] init];
        NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/WCPGateLog.txt"];
        gLog = fopen([path UTF8String], "a");
        if (gLog) {
            NSDate *now = [NSDate date];
            fprintf(gLog, "=== WCPScout start %s ===\n", [[now description] UTF8String]);
            fflush(gLog);
        }
    });
}

// 记录一条去重后的调用现场（syms 为 backtrace 文本，可为 NULL）
static void log_gate(const char *tag, uintptr_t pc, NSString *detail, char **syms, int n) {
    if (!gLog || gLogged >= kMaxEntries) return;
    char cls[256], sel[256];
    resolve_caller(pc, cls, sel, sizeof(cls));
    if (cls[0] == 0 && sel[0] == 0) return;        // 反查不到就不记

    NSString *key = [NSString stringWithFormat:@"%s.%s", cls, sel];
    [gLogLock lock];
    BOOL seen = [gSeen containsObject:key];
    if (!seen) {
        [gSeen addObject:key];
        fprintf(gLog, "\n[%s] %s\n  callerPC=0x%lx  => -[%s %s]\n",
                tag, [detail UTF8String], pc, cls, sel);
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

// ── hook 1：bundleIdentifier（聚焦主 bundle 读取）────────────────────────
%hook NSBundle
- (NSString *)bundleIdentifier {
    NSString *real = %orig;
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
%end

// ── hook 2：NSString 比较（捕获 bid 比对现场）───────────────────────────
%hook NSString
- (BOOL)isEqualToString:(NSString *)aString {
    BOOL r = %orig;
    NSString *selfs = (NSString *)self;
    if ([selfs isKindOfClass:[NSString class]]) {
        const char *a = [selfs UTF8String];
        const char *b = [aString UTF8String];
        if ((a && (strstr(a, "com.tencent.xin") || strstr(a, "com.tencent.qy.xin"))) ||
            (b && (strstr(b, "com.tencent.xin") || strstr(b, "com.tencent.qy.xin")))) {
        ensure_log();
        void *frames[24];
        int n = backtrace(frames, 24);
        uintptr_t pc = (n > 2) ? (uintptr_t)frames[2] : 0;
        char **syms = backtrace_symbols(frames, n);
        log_gate("isEqualToString(com.tencent)", pc,
                 [NSString stringWithFormat:@"\"%@\" ==? \"%@\"", selfs, aString], syms, n);
        if (syms) free(syms);
    }
    return r;
}

- (BOOL)isEqual:(id)object {
    BOOL r = %orig;
    NSString *selfs = (NSString *)self;
    if ([selfs isKindOfClass:[NSString class]] && [object isKindOfClass:[NSString class]]) {
        NSString *o = (NSString *)object;
        const char *a = [selfs UTF8String];
        const char *b = [o UTF8String];
        if ((a && (strstr(a, "com.tencent.xin") || strstr(a, "com.tencent.qy.xin"))) ||
            (b && (strstr(b, "com.tencent.xin") || strstr(b, "com.tencent.qy.xin")))) {
            ensure_log();
            void *frames[24];
            int n = backtrace(frames, 24);
            uintptr_t pc = (n > 2) ? (uintptr_t)frames[2] : 0;
            char **syms = backtrace_symbols(frames, n);
            log_gate("isEqual(com.tencent)", pc,
                     [NSString stringWithFormat:@"\"%@\" ==? \"%@\"", selfs, o], syms, n);
            if (syms) free(syms);
        }
    }
    return r;
}
%end

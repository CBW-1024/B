/**
 *  WCPulseLite.xm  —  v9「安全诊断版」(FIND MODE，零中和，绝不崩)
 *  ─────────────────────────────────────────────────────────────────────────────
 *
 *  【为什么是这个版本】
 *   - v8 把延迟补扫扩到系统类 → 中和关键系统类的 suspendAndReopen → 启动 ~2s 闪退。
 *   - v9(中和版) 即使只中和微信类，在构造函数里中和 suspendAndReopen 仍让 app 启动即崩
 *     （Documents 里连新的 loaded 都来不及写）。说明 suspendAndReopen 是微信启动生命周期里
 *     【真正常用】的方法，纯 return 早返回会破坏启动 → 它是二进制混淆中的诱饵/非目标，
 *     WCPulse 的 0x50a20 做的绝不是盲 no-op。
 *   - WCPGateLog 已实锤：客户端【没有任何】对 bid 的字符串比对闸门
 *     （isEqualToString/compare/hasPrefix/range/contains 全挂了都没抓到拒绝性比对，
 *      唯一 qy.xin==xin 是 PasskeyUtils 功能开关）。
 *   → 真正的绕过点在「登录被拒、弹『该账号尚未获得体验资格』那一下」的【调用方】，
 *     而不是 suspendAndReopen，也不是 bid 字符串比对。
 *
 *  【本版做什么（FIND MODE，安全，不修改任何行为）】
 *   ① 加载即写 Documents/WCPGateLog.txt 的 loaded 标记（证明 dylib 加载，不崩）。
 *   ② hook +[UIAlertController alertControllerWithTitle:message:preferredStyle:]：
 *      当 message 含「体验资格 / 尚未获得 / 体验」时，记录【完整调用栈】——
 *      这就是真正的登录拒绝入口，调用栈最顶层微信方法即闸门方法。
 *   ③ 顺带记录 suspendAndReopen 的「候选微信类」（仅列名，不中和，安全）。
 *   ④ 全程零 Substrate 依赖（运行时 swizzle），非越狱 sideload 可加载。
 *
 *  【构建：自包含 dylib，不用 theos tweak】──
 *   SDK=$(xcrun -sdk iphoneos --show-sdk-path)
 *   clang -dynamiclib -arch arm64 -arch arm64e \
 *       -target arm64-apple-ios14.0 -isysroot "$SDK" \
 *       -fno-objc-arc -framework Foundation -framework UIKit \
 *       -install_name @executable_path/WCPulseLite.dylib \
 *       -x objective-c WCPulseLite.xm -o WCPulseLite.dylib
 *
 *  【用法】本版单独注入（不要和 WCPScout 一起），启动微信 → 触发登录被拒不通过 →
 *         取出 Documents/WCPGateLog.txt，把『[GATE]』那一段的调用栈发我，
 *         我据此做 v10 精准中和真正的闸门方法（带正确签名、调用原实现、只跳拒绝分支）。
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <execinfo.h>
#import <stdio.h>
#import <string.h>

// ── 日志（文件 + syslog 双信号）───────────────────────────────────────
static FILE *gLog = NULL;
static int  gLogged = 0;
static const int kMaxEntries = 600;

static void open_log_file(void) {
    if (gLog) return;
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/WCPGateLog.txt"];
    gLog = fopen([path UTF8String], "a");
    NSLog(@"[WCPulseLite] try path=%@ => %s", path, gLog ? "OK" : "FAIL");
    if (!gLog) { gLog = fopen("/tmp/WCPGateLog.txt", "a"); }
}

static void log_line(const char *tag, NSString *detail, void *frames[], int n) {
    if (!gLog || gLogged >= kMaxEntries) return;
    fprintf(gLog, "\n[%s] %s\n", tag, [detail UTF8String]);
    for (int k = 1; k < n; k++) {
        char **syms = backtrace_symbols(&frames[k], 1);
        if (syms && syms[0]) fprintf(gLog, "    %s\n", syms[0]);
        if (syms) free(syms);
    }
    fflush(gLog);
    gLogged++;
}

static void trace_gate(const char *tag, NSString *detail) {
    void *frames[40];
    int n = backtrace(frames, 40);
    log_line(tag, detail, frames, n);
}

// 判断是否是 Apple 系统框架的类
static BOOL isAppleClass(Class cls) {
    if (!cls) return YES;
    const char *name = class_getName(cls);
    if (!name) return YES;
    static const char *prefixes[] = {
        "NS","UI","CA","WK","OS_","_","AV","MK","CL","PH","WebKit",
        "RB","BS","FB","AX","PK","NE","SP","WF","__","DU","_UI","_WK"
    };
    for (int i = 0; i < (int)(sizeof(prefixes)/sizeof(*prefixes)); i++)
        if (strncmp(name, prefixes[i], strlen(prefixes[i])) == 0) return YES;
    return NO;
}

// ── hook 1：UIAlertController 弹窗（抓真正的登录拒绝入口）────────────────
static UIAlertController *(*gOrigAlert)(id, SEL, NSString *, NSString *, UIAlertControllerStyle) = NULL;
static UIAlertController *wcpl_alert(id self, SEL _cmd, NSString *title, NSString *message, UIAlertControllerStyle style) {
    UIAlertController *ac = gOrigAlert ? gOrigAlert(self, _cmd, title, message, style) : nil;
    if (message && ([message rangeOfString:@"体验资格"].location != NSNotFound ||
                    [message rangeOfString:@"尚未获得"].location != NSNotFound ||
                    [message rangeOfString:@"体验"].location != NSNotFound)) {
        trace_gate("GATE", [NSString stringWithFormat:@"alert message=\"%@\" title=\"%@\"", message, title]);
    }
    return ac;
}

// ── 仅列名：suspendAndReopen 候选（不中和，安全）───────────────────────
static void list_suspend_candidates(void) {
    SEL gate = NSSelectorFromString(@"suspendAndReopen");
    if (!gate) return;
    unsigned int cc = 0;
    Class *classes = objc_copyClassList(&cc);
    if (!classes) return;
    for (unsigned int i = 0; i < cc; i++) {
        Class cls = classes[i];
        if (isAppleClass(cls)) continue;
        unsigned int mc = 0;
        Method *ms = class_copyMethodList(cls, &mc);
        BOOL owns = NO;
        for (unsigned int k = 0; k < mc; k++)
            if (sel_isEqual(method_getName(ms[k]), gate)) { owns = YES; break; }
        free(ms);
        if (owns) {
            NSLog(@"[WCPulseLite] (candidate, NOT neutralized) -[%s suspendAndReopen]", class_getName(cls));
            trace_gate("SUSPEND_CANDIDATE", [NSString stringWithFormat:@"-[%s suspendAndReopen] owns it (no-op would crash; listed only)", class_getName(cls)]);
        }
    }
    free(classes);
}

__attribute__((constructor))
static void wcpl_load(void) {
    open_log_file();
    if (gLog) {
        NSDate *now = [NSDate date];
        fprintf(gLog, "=== WCPulseLite(FIND MODE) loaded %s ===\n", [[now description] UTF8String]);
        fflush(gLog);
    }
    NSLog(@"[WCPulseLite] FIND MODE loaded (no neutralize, safe)");

    // 抓真正的登录拒绝入口
    Class ac = objc_getClass("UIAlertController");
    if (ac) {
        Method m = class_getClassMethod(ac, @selector(alertControllerWithTitle:message:preferredStyle:));
        if (m) {
            gOrigAlert = (typeof(gOrigAlert))method_getImplementation(m);
            method_setImplementation(m, (IMP)wcpl_alert);
            NSLog(@"[WCPulseLite] hooked UIAlertController alertControllerWithTitle:message:preferredStyle:");
        }
    }
    // 列 suspendAndReopen 候选（仅列名，不中和）
    list_suspend_candidates();
    NSLog(@"[WCPulseLite] scan done; trigger login rejection to capture [GATE]");
}

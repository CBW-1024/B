//============================================================================
//  WCPBidSpoof — 微信多开 bid 伪装（单文件 Logos tweak）
//----------------------------------------------------------------------------
//  提取自商业插件 WCP/WCPulse 的 NSBundle 双 hook 方案，1:1 还原其核心逻辑，
//  并按 WCRefine 交叉验证结论修正为「调用方作用域伪装」。
//
//  【证据来源】
//  * 二进制还原：/workspace/WCP_bid_hook取证.md
//      - hook 注册铁证（capstone 还原 0x646e24..0x646f6c）：
//          objc_getClass("NSBundle")                         // 0x9eb801 解密 = "NSBundle"
//          MSHookMessageEx(NSBundle, @bundleIdentifier,
//                          IMP1=0x64712c, &orig=0xa220f8)
//          MSHookMessageEx(NSBundle, @objectForInfoDictionaryKey:,
//                          IMP2=0x649b7c, &orig=0xa22100)
//      - 解密字符串表（OLLM 运行时流式 XOR 还原）：
//          0x9eb81a "com.tencent.xin"      <- 伪装目标 bid
//          0x9eb910 "com.tencent.qy.xin" / 0x9eb932 "com.tencent.wx" / 0x9eb970 "com.tencent.mm.xin"
//      - 门控判定（IMP1 内 isEqualToString: + tbz 0x6478c0）：真实 bid 已是官方则不伪装。
//  * 微信头文件（class-dump，/workspace/wx76/微信/）：
//      - TSEnvironment.h:25   + (id)bundleIdentifier       （微信内部环境探测）
//      - FBSDKAppEventsDeviceInfo.h:17  _bundleIdentifier  （内嵌 FBSDK 随设备信息上报）
//  * WCR 交叉验证（/workspace/work/WCRefine.dylib，1788 个 hook）：
//      - 仅 hook NSBundle @bundleIdentifier（IMP=0x1582ec0, &orig=0x2203458），
//        门控字节 0x2203560；命中返回 CFString 0x1f8fe88 = "com.tencent.xin"（铁证）。
//      - **不 hook objectForInfoDictionaryKey:** —— 与 WCP 派生方案的唯一关键差异。
//      - 仅 hook 通知*点击响应* userNotificationCenter:didReceiveNotificationResponse:
//        （IMP 0x157b0f0 / 0x157b4c4）：先调 orig，再跑全局函数 0x22033d8 做多开路由。
//        不碰注册 / deviceToken / 解密（WCNotificationEncryptionUtils 全程未 hook）。
//
//  【v1.0.4 设计修正：调用方作用域伪装（修复 UI 移位 + 推送丢失）】
//  全局把 bundleIdentifier 改成 com.tencent.xin 会破坏两件事：
//    (a) APNs topic 不匹配：苹果用 app【真实】bundle id 加密 device token，微信把
//        [NSBundle mainBundle] bundleIdentifier] 当作 topic 上报服务器。伪装成官方 id
//        后上报 topic 与 token 加密主题不符 → 苹果静默丢弃推送。
//    (b) UI 资源/feature flag 错位：部分 UI 代码读 bundleIdentifier 选资源/布局分支，
//        拿到官方 id 走到不存在的分支 → UI 移位。
//  修正：对【推送/通知/UI 子系统】的调用返回【真实】bid（保推送 topic + UI），
//        只对【反篡改/风控】调用方伪装成 com.tencent.xin。
//        判定靠调用栈类名/方法名子串匹配（ObjC 调用栈即便 stripped 也会打印 [Class method]）。
//
//  【日志（v1.0.1+，v1.0.4 修正路径）】
//  * 无条件在 %ctor 开日志，写到【app 文件沙盒 Documents】：
//      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
//      → /var/mobile/Containers/Data/Application/<UUID>/Documents/wcpbidspoof.log
//    （rootful / rootless 越狱下都正确，不受 /var/jb 重定向影响；绝不写 /tmp 等非沙盒目录）
//  * 文件打不开则走 NSLog 兜底（设备 syslog / 控制台搜 [WCPBidSpoof] 可见）。
//  * 行数上限 WCP_LOG_MAX_LINES，防止热路径写爆。
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION             "1.0.4"
#define SPOOF_ENABLED           1   // 总开关：0 = 完全不改写任何返回值（用于对照实验）
#define HOOK_BUNDLE_IDENTIFIER 1   // 关掉可测试是否 -bundleIdentifier 引起 UI/推送问题
#define HOOK_OBJECT_FOR_INFO_DICT 0 // ⚠️ WCR 验证：WCRefine.dylib 完全不 hook 此方法。
                                    //    开启会把微信 UI/推送子系统内部读的 CFBundleIdentifier 也改成官方 bid，
                                    //    实测导致 UI 移位 + 推送丢失。默认关闭，对齐 WCR。
#define ENABLE_LOGGING         1   // 沙盒文件日志（打不开则走 NSLog 兜底）
#define CALLER_SCOPED          1   // 1 = 仅对「非推送/通知/UI 子系统」伪装（修复 UI+推送）
                                    // 0 = 全局伪装（旧行为，会破坏推送，仅用于对照）
#define LOG_VERBOSE            1   // 1 = 采样打印每次调用（诊断用）；0 = 仅打印豁免(返回真实)的调用
#define WCP_LOG_MAX_LINES      8000

// 伪装目标 bid：WCP 解密串 0x9eb81a = "com.tencent.xin"
static NSString *const kWCPTargetBundleID = @"com.tencent.xin";

// 返回【真实】bid 的调用方标记（子串匹配 ObjC 调用栈的 [Class method]）。
// 这些子系统一旦吃到伪装值就会：推送 topic 错位（丢推送）/ UI 资源选错（移位）。
static const char *kWCPRealIdMarkers[] = {
    // —— 推送 / 通知 / APNs ——
    "Push", "Notif", "RemoteNotif",
    "registerForRemote", "didRegisterForRemote",
    "UNUserNotif", "MicroMessengerAppDelegate",
    "NotificationActionsMgr", "WCNotificationEncryption",
    "handleReceiveRemote", "receiveRemoteNotification",
    "processRemoteNotification", "apnsToken", "APNS", "apns",
    "MMPush", "PushManager", "PushUtil", "WCNotification",
    // —— UI / 资源 / 布局 ——
    "ViewController", "View", "Layout", "Storyboard",
    "Theme", "Skin", "ResManager", "MMResource", "AppSetting",
    NULL
};

//------------------------------ 日志子系统 -----------------------------------
static FILE        *gWCPLog = NULL;
static volatile int gWCPLogging = 0;     // 重入保护（日志内部若触发 hook 直接丢弃）
static long         gWCPLogLines = 0;
static volatile int gWCPInHook  = 0;     // hook 内部重入保护
static long         gWCPCallCount = 0;
static char         gWCPLogPath[2048] = {0};  // 软件文件沙盒 Documents 路径（%ctor 解析）

// 只写到 app 的【文件沙盒 Documents】：/var/mobile/Containers/Data/Application/<UUID>/Documents
// 取径方式用 NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)，
// 在 rootful / rootless 越狱下都返回正确的 app 容器路径（不受 /var/jb 重定向影响）。
// 若连沙盒路径都打不开，不写文件、不散落到 /tmp 等非沙盒目录，改走 NSLog 兜底（syslog 可见）。
static void WCPLogOpen(void) {
    if (gWCPLog) return;
    if (!gWCPLogPath[0]) return;         // 路径未就绪（%ctor 未设置），交给 NSLog
    gWCPLog = fopen(gWCPLogPath, "a");
    if (gWCPLog) {
        fprintf(gWCPLog, "=== WCPBidSpoof log opened @ %s (uid=%d HOME=%s) ===\n",
                gWCPLogPath, getuid(), getenv("HOME") ?: "(null)");
        fflush(gWCPLog);
    }
}

// 先把格式串展开成 C 串（va_list 仅消费一次），再写文件 / NSLog。
static void WCPLogV(const char *fmt, va_list ap) {
#if !ENABLE_LOGGING
    (void)fmt; (void)ap;
    return;
#else
    if (gWCPLogging) return;
    gWCPLogging = 1;
    char body[2048];
    vsnprintf(body, sizeof(body), fmt, ap);
    if (gWCPLog) {
        if (gWCPLogLines < WCP_LOG_MAX_LINES) {
            time_t t = time(NULL);
            struct tm tm_now; localtime_r(&t, &tm_now);
            fprintf(gWCPLog, "[%04d-%02d-%02d %02d:%02d:%02d] %s\n",
                    tm_now.tm_year + 1900, tm_now.tm_mon + 1, tm_now.tm_mday,
                    tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, body);
            fflush(gWCPLog);
            gWCPLogLines++;
        }
    } else {
        // 文件未开：兜底走 NSLog（设备 syslog / 控制台可见）
        NSLog(@"[WCPBidSpoof] %s", body);
    }
    gWCPLogging = 0;
#endif
}

// 变参 C 壳：把 C 格式串 + 变参正确打包成 va_list 再交给 WCPLogV。
// 注意：不能直接 WCPLogV("%s", charPtr) —— WCPLogV 第 2 形参是 va_list，
// 直接塞 const char* 既编不过（arm64 上 va_list==char*，丢 const 限定符），
// 运行时也会让 vsnprintf 读到野指针崩溃。必须经变参函数生成合法 va_list。
static void WCPLogC(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    WCPLogV(fmt, ap);
    va_end(ap);
}

static void WCPLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    WCPLogC("%s", [body UTF8String]);
}

//------------------------------ 判定逻辑 -------------------------------------
static BOOL IsMainBundle(NSBundle *self) {
    return self == [NSBundle mainBundle];
}

// 调用栈里是否含「应返回真实 bid」的标记（推送/通知/UI 子系统）。
static BOOL WCPCallerWantsRealId(NSArray<NSString *> *syms, NSArray<NSString *> *markers) {
#if CALLER_SCOPED
    for (NSString *s in syms) {
        for (NSString *m in markers) {
            if ([s containsString:m]) return YES;
        }
    }
#endif
    return NO;
}

%group WCPBidSpoof

%hook NSBundle

// 证据：WCP MSHookMessageEx(NSBundle, @bundleIdentifier, IMP1=0x64712c, &orig=0xa220f8)
- (NSString *)bundleIdentifier {
#if HOOK_BUNDLE_IDENTIFIER
    if (gWCPInHook) return %orig;          // 重入保护
    gWCPInHook = 1;

    NSString *orig = %orig;
    NSString *ret  = orig;

    if (IsMainBundle(self) && orig.length > 0 &&
        ![orig isEqualToString:kWCPTargetBundleID]) {
        // 收集调用栈（即便 stripped，ObjC 帧也会打印 [Class method]）
        NSArray<NSString *> *syms = [NSThread callStackSymbols];
        static NSArray<NSString *> *markers = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSMutableArray *a = [NSMutableArray array];
            for (const char **m = kWCPRealIdMarkers; *m; m++)
                [a addObject:[NSString stringWithUTF8String:*m]];
            markers = a;
        });

        BOOL safeCaller = WCPCallerWantsRealId(syms, markers);
        // 仅对非推送/通知/UI 子系统伪装；官方版(safeCaller 无关)也走这里但 orig 已是官方 id
        BOOL spoof = !safeCaller;
        ret = spoof ? kWCPTargetBundleID : orig;

#if LOG_VERBOSE
        gWCPCallCount++;
        BOOL wantLog = (gWCPCallCount <= 400) || safeCaller;  // 前 400 次全打 + 之后只打豁免
        if (wantLog) {
            WCPLog(@"bundleIdentifier | orig=%@ spoof=%d safeCaller=%d #%ld",
                   orig, spoof, safeCaller, gWCPCallCount);
            if (safeCaller) {
                NSUInteger take = MIN(syms.count, 6);
                WCPLog(@"   stack: %@", [syms subarrayWithRange:NSMakeRange(0, take)]);
            }
        }
#else
        if (safeCaller)
            WCPLog(@"bundleIdentifier RETURN-REAL | orig=%@ (push/ui caller)", orig);
#endif
    }

    gWCPInHook = 0;
    return ret;
#else
    return %orig;
#endif
}

// 证据：WCP MSHookMessageEx(NSBundle, @objectForInfoDictionaryKey:, IMP2=0x649b7c, &orig=0xa22100)
// ⚠️ WCR 验证：WCRefine.dylib 不 hook 此方法。默认关闭（见顶部开关注释）。
//    保留用于调试：开启后观察微信是否经此路径识别多开（配合 ENABLE_LOGGING）。
- (id)objectForInfoDictionaryKey:(NSString *)key {
#if HOOK_OBJECT_FOR_INFO_DICT
    if (IsMainBundle(self) && [key isEqualToString:@"CFBundleIdentifier"]) {
        NSString *orig = %orig;
        BOOL spoof = (orig.length > 0 && ![orig isEqualToString:kWCPTargetBundleID]);
        WCPLog(@"objectForInfoDictionaryKey | key=CFBundleIdentifier orig=%@ spoof=%d ret=%@",
               orig, spoof, spoof ? kWCPTargetBundleID : orig);
        return spoof ? kWCPTargetBundleID : orig;
    }
#endif
    return %orig;
}

%end

%end

%ctor {
    @autoreleasepool {
        // 先解析 app 文件沙盒 Documents 路径（此时 hook 尚未安装，调用原生方法安全）
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES).firstObject;
        if (!doc) {
            const char *home = getenv("HOME");
            if (home && *home) doc = [NSString stringWithFormat:@"%s/Documents", home];
        }
        if (doc) snprintf(gWCPLogPath, sizeof(gWCPLogPath),
                          "%s/wcpbidspoof.log", doc.UTF8String);
        WCPLogOpen();   // 无条件开日志，保证能在沙盒里找到文件
        NSString *exe = [[NSBundle mainBundle] executablePath];
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ bid=%@ SPOOF=%d BID=%d OFI=%d SCOPED=%d ===",
               WCP_VERSION, getuid(), exe, bid,
               SPOOF_ENABLED, HOOK_BUNDLE_IDENTIFIER, HOOK_OBJECT_FOR_INFO_DICT, CALLER_SCOPED);
        // 始终在微信进程内安装 hook；是否伪装在每次调用时按真实 bid + 调用方判定。
        // 官方版（com.tencent.xin）调用会落到 orig，行为无变化。
        if (exe && [exe containsString:@"WeChat"]) {
            %init(WCPBidSpoof);
            WCPLog(@"init: hooks installed");
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

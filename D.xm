//============================================================================
//  WCPBidSpoof — 微信多开 bid 伪装（单文件 Logos tweak）
//----------------------------------------------------------------------------
//  提取自商业插件 WCP/WCPulse 的 NSBundle 双 hook 方案，1:1 还原其核心逻辑。
//
//  【证据来源】
//  * 二进制还原：/workspace/WCP_bid_hook取证.md
//      - hook 注册铁证（capstone 还原 0x646e24..0x646f6c）：
//          objc_getClass("NSBundle")                         // 0x9eb801 解密 = "NSBundle"
//          MSHookMessageEx(NSBundle, @bundleIdentifier,
//                          IMP1=0x64712c, &orig=0xa220f8)   // 0xa220f8 = orig 槽
//          MSHookMessageEx(NSBundle, @objectForInfoDictionaryKey:,
//                          IMP2=0x649b7c, &orig=0xa22100)   // 0xa22100 = orig 槽
//      - 解密字符串表（OLLM 运行时流式 XOR 还原）：
//          0x9eb81a "com.tencent.xin"      <- 伪装目标 bid
//          0x9eb910 "com.tencent.qy.xin"   <- 多开真实 bid 候选
//          0x9eb932 "com.tencent.wx"       <- 多开真实 bid 候选
//          0x9eb970 "com.tencent.mm.xin"   <- 多开真实 bid 候选
//      - 门控判定（IMP1 内 isEqualToString: + tbz 0x6478c0）：
//          若真实 bid 已是官方 com.tencent.xin 则不伪装，仅多开伪装。
//  * 微信头文件（class-dump，/workspace/wx76/微信/）：
//      - TSEnvironment.h:25   + (id)bundleIdentifier       （微信内部环境探测，转调 mainBundle）
//      - FBSDKAppEventsDeviceInfo.h:17  _bundleIdentifier  （内嵌 FBSDK 随设备信息上报）
//        证明微信内部确实通过 NSBundle 读取 bundleID，hook 在正确层级。
//  * WCR 交叉验证（/workspace/work/WCRefine.dylib，1788 个 hook，hooks_inventory.txt）：
//      - 仅 hook NSBundle @bundleIdentifier（IMP=0x1582ec0, &orig=0x2203458），
//        门控字节 0x2203560；命中返回 CFString 0x1f8fe88 = "com.tencent.xin"（铁证）。
//      - **不 hook objectForInfoDictionaryKey:**（grep 零命中）—— 这正是与 WCP 派生方案的唯一关键差异。
//      - 仅 hook 通知*点击响应* MicroMessengerAppDelegate / NotificationActionsMgr 的
//        userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:
//        （IMP 0x157b0f0 / 0x157b4c4）：先调 orig，再跑全局函数 0x22033d8 做多开路由。
//        不碰注册 / deviceToken / 解密（WCNotificationEncryptionUtils 全程未 hook）。
//      ⇒ 结论：WCR 的可用方案 = 只 spoof bundleIdentifier，绝不 spoof CFBundleIdentifier。
//
//  【APNs 隔离（关键设计，勿动）】
//  上一轮已核实 WCP 仅 hook 上述两个 NSBundle 方法，绝不碰：
//      MicroMessengerAppDelegate（推送/deviceToken 在 wcp_hooks.txt L203/255-257
//        仅 hook 前后台生命周期，非推送链路）
//      NotificationActionsMgr（wcp_hooks.txt 无该类推送方法 hook）
//      WCNotificationEncryptionUtils（连字符串都未引用）
//  device token 由系统固件层用真实 entitlements+bundle 签发，与微信内
//  bundleIdentifier 返回值无关；放过整条推送链路即可保 APNs 不坏。
//  —— 但注意：hook 在 NSBundle 层是「全局」的，上述类内部若自行调用
//     [NSBundle mainBundle] bundleIdentifier，会吃到伪装值。UI 移位 / 推送
//     丢失的最常见诱因，是额外 hook 了 objectForInfoDictionaryKey:（见下方开关默认值，
//     已按 WCR 验证结论默认关闭）。
//
//  【调试开关 / 日志（v1.0.1 新增）】
//  * 沙盒文件日志：写入 $HOME/Documents/wcpbidspoof.log（同时 NSLog）
//    —— 用 getenv("HOME") 取沙盒根，纯 C 实现，避免触发被 hook 的 ObjC 方法造成重入。
//  * HOOK_BUNDLE_IDENTIFIER / HOOK_OBJECT_FOR_INFO_DICT：可分别关掉两个 hook，
//    用来隔离「UI 移位 / 推送丢失」到底是哪个 hook 引起的。
//  * LOG_CALLSTACK：打印调用方返回地址（需配合二进制方法列表反查是哪个微信方法触发）。
//  * 日志行数上限 WCP_LOG_MAX_LINES，防止热路径（bundleIdentifier 调用极频繁）写爆。
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>

//------------------------------ 配置开关 -------------------------------------
#define SPOOF_ENABLED               1   // 总开关：0 = 完全不改写任何返回值
#define HOOK_BUNDLE_IDENTIFIER     1   // 关掉可测试是否 -bundleIdentifier 引起 UI/推送问题
#define HOOK_OBJECT_FOR_INFO_DICT  0   // ⚠️ WCR 验证：WCRefine.dylib(1788 hook) 完全不 hook 此方法。
                                        //    开启会把微信 UI/推送子系统内部读的 CFBundleIdentifier 也改成官方 bid，
                                        //    实测导致 UI 移位 + 推送丢失。默认关闭，对齐 WCR 的可用方案。
                                        //    如需调试再临时改 1，并配合 ENABLE_LOGGING 看是哪次调用触发问题。
#define ENABLE_LOGGING             1   // 沙盒文件日志
#define LOG_CALLSTACK              0   // 1 = 打印调用方返回地址（调试 UI 移位/推送丢失用）
#define WCP_LOG_MAX_LINES          4000

// 伪装目标 bid：WCP 解密串 0x9eb81a = "com.tencent.xin"
static NSString *const kWCPTargetBundleID = @"com.tencent.xin";

// 多开真实 bid 候选（WCP 白名单函数 0x650fdc 引用）。
// 仅当真实 bid 命中其中之一（即处于多开容器）时才启用伪装，官方版零影响。
static NSString *const kMultiOpenBIDs[] = {
    @"com.tencent.qy.xin",
    @"com.tencent.wx",
    @"com.tencent.mm.xin",
};

//------------------------------ 日志子系统 -----------------------------------
static FILE        *gWCPLog = NULL;
static volatile int gWCPLogging = 0;     // 重入保护
static long         gWCPLogLines = 0;

static const char *WCPLogPath(void) {
    // 用 getenv("HOME") 拿沙盒根，纯 C，不触发任何被 hook 的 ObjC 方法
    static char buf[1024];
    const char *home = getenv("HOME");
    if (!home || !*home) home = "/var/mobile";
    snprintf(buf, sizeof(buf), "%s/Documents/wcpbidspoof.log", home);
    return buf;
}

static void WCPLogV(const char *fmt, va_list ap) {
#if !ENABLE_LOGGING
    (void)fmt; (void)ap;
    return;
#else
    if (gWCPLogging) return;             // 重入保护：日志内部若间接触发 hook，直接丢弃
    gWCPLogging = 1;

    if (!gWCPLog) {
        gWCPLog = fopen(WCPLogPath(), "a");
        if (gWCPLog) {
            fprintf(gWCPLog, "=== WCPBidSpoof log open @ %s ===\n", WCPLogPath());
            fflush(gWCPLog);
        }
    }

    if (gWCPLog && gWCPLogLines < WCP_LOG_MAX_LINES) {
        time_t t = time(NULL);
        struct tm tm_now;
        localtime_r(&t, &tm_now);
        fprintf(gWCPLog, "[%04d-%02d-%02d %02d:%02d:%02d] ",
                tm_now.tm_year + 1900, tm_now.tm_mon + 1, tm_now.tm_mday,
                tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec);
        vfprintf(gWCPLog, fmt, ap);
#if LOG_CALLSTACK
        void *frames[6];
        int n = backtrace(frames, 6);
        if (n > 2)
            fprintf(gWCPLog, "    bt: %p %p %p", frames[2], frames[3], frames[4]);
#endif
        fprintf(gWCPLog, "\n");
        fflush(gWCPLog);
        gWCPLogLines++;
        if (gWCPLogLines == WCP_LOG_MAX_LINES)
            fprintf(gWCPLog, "=== log line cap reached, stop writing ===\n");
    }
    gWCPLogging = 0;
#endif
}

// 变参 C 壳：把 C 格式串 + 变参正确打包成 va_list 再交给 WCPLogV。
// 注意：不能直接 WCPLogV("%s", charPtr) —— WCPLogV 的第 2 个形参是 va_list，
// 直接塞一个 const char* 既编不过（arm64 上 va_list == char*，丢 const 限定符），
// 运行时也会让 vfprintf 读到野指针崩溃。必须经变参函数生成合法 va_list。
static void WCPLogC(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    WCPLogV(fmt, ap);
    va_end(ap);
}

static void WCPLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    // 先把 NSString 格式化展开，再交给 C 日志层（避免日志体里出现非 C 字符串）
    NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    WCPLogC("%s", [body UTF8String]);
}

//------------------------------ 判定逻辑 -------------------------------------
static BOOL IsMainBundle(NSBundle *self) {
    return self == [NSBundle mainBundle];
}

static BOOL ShouldSpoof(NSString *realBid) {
#if !SPOOF_ENABLED
    return NO;
#else
    if (realBid == nil) return NO;
    if ([realBid isEqualToString:kWCPTargetBundleID]) return NO; // 官方版不伪装
    for (size_t i = 0; i < sizeof(kMultiOpenBIDs) / sizeof(kMultiOpenBIDs[0]); i++) {
        if ([realBid isEqualToString:kMultiOpenBIDs[i]]) return YES;
    }
    return NO;
#endif
}

%group WCPBidSpoof

%hook NSBundle

// 证据：WCP MSHookMessageEx(NSBundle, @bundleIdentifier, IMP1=0x64712c, &orig=0xa220f8)
- (NSString *)bundleIdentifier {
#if HOOK_BUNDLE_IDENTIFIER
    NSString *orig = %orig;
    BOOL main = IsMainBundle(self);
    BOOL spoof = main && ShouldSpoof(orig);
    WCPLog(@"bundleIdentifier | isMain=%d orig=%@ spoof=%d ret=%@",
           main, orig, spoof, spoof ? kWCPTargetBundleID : orig);
    return spoof ? kWCPTargetBundleID : orig;
#else
    return %orig;
#endif
}

// 证据：WCP MSHookMessageEx(NSBundle, @objectForInfoDictionaryKey:, IMP2=0x649b7c, &orig=0xa22100)
// 部分微信代码走 [mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"]
// 而非 -bundleIdentifier。
// ⚠️ WCR 验证：WCRefine.dylib 不 hook 此方法，开启反而导致 UI 移位 + 推送丢失。
//    故 HOOK_OBJECT_FOR_INFO_DICT 默认 0。如需研究微信如何经此路径识别多开，
//    临时改 1 并配合 ENABLE_LOGGING 观察调用方（必要时再上 LOG_CALLSTACK）。
- (id)objectForInfoDictionaryKey:(NSString *)key {
#if HOOK_OBJECT_FOR_INFO_DICT
    if (IsMainBundle(self) && [key isEqualToString:@"CFBundleIdentifier"]) {
        NSString *orig = %orig;
        BOOL spoof = ShouldSpoof(orig);
        WCPLog(@"objectForInfoDictionaryKey | key=CFBundleIdentifier isMain=1 orig=%@ spoof=%d ret=%@",
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
        // 二次保险：仅在微信主二进制（官方或任意多开变体）内初始化。
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        BOOL go = ShouldSpoof(bid);
        WCPLog(@"init | realBid=%@ go=%d HOOK_BID=%d HOOK_OFI=%d SPOOF=%d",
               bid, go, HOOK_BUNDLE_IDENTIFIER, HOOK_OBJECT_FOR_INFO_DICT, SPOOF_ENABLED);
        if (go) %init(WCPBidSpoof);
    }
}

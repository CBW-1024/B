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
//
//  【APNs 隔离（关键设计，勿动）】
//  上一轮已核实 WCP 仅 hook 上述两个 NSBundle 方法，绝不碰：
//      MicroMessengerAppDelegate（推送/deviceToken 在 wcp_hooks.txt L203/255-257
//        仅 hook 前后台生命周期，非推送链路）
//      NotificationActionsMgr（wcp_hooks.txt 无该类推送方法 hook）
//      WCNotificationEncryptionUtils（连字符串都未引用）
//  device token 由系统固件层用真实 entitlements+bundle 签发，与微信内
//  bundleIdentifier 返回什么无关；放过整条推送链路即可保 APNs 不坏。
//============================================================================

#import <Foundation/Foundation.h>

// 伪装目标 bid：WCP 解密串 0x9eb81a = "com.tencent.xin"
static NSString *const kWCPTargetBundleID = @"com.tencent.xin";

// 多开真实 bid 候选（WCP 白名单函数 0x650fdc 引用）。
// 仅当真实 bid 命中其中之一（即处于多开容器）时才启用伪装，官方版零影响。
static NSString *const kMultiOpenBIDs[] = {
    @"com.tencent.qy.xin",
    @"com.tencent.wx",
    @"com.tencent.mm.xin",
};

// 编译期总开关。设为 0 可整体关停伪装（保留插件加载但不改写任何返回值）。
#ifndef SPOOF_ENABLED
#define SPOOF_ENABLED 1
#endif

static BOOL IsMainBundle(NSBundle *self) {
    return self == [NSBundle mainBundle];
}

static BOOL ShouldSpoof(NSString *realBid) {
#if !SPOOF_ENABLED
    return NO;
#else
    if (realBid == nil) return NO;
    // 官方版本身已是目标 bid，无需伪装（对齐 WCP isEqualToString: 门控）。
    if ([realBid isEqualToString:kWCPTargetBundleID]) return NO;
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
    NSString *orig = %orig;
    if (IsMainBundle(self) && ShouldSpoof(orig)) {
        return kWCPTargetBundleID;
    }
    return orig;
}

// 证据：WCP MSHookMessageEx(NSBundle, @objectForInfoDictionaryKey:, IMP2=0x649b7c, &orig=0xa22100)
// 部分微信代码走 [mainBundle objectForInfoDictionaryKey:@"CFBundleIdentifier"]
// 而非 -bundleIdentifier，必须同步伪装，否则被风控按真实 bid 识破。
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (IsMainBundle(self) && [key isEqualToString:@"CFBundleIdentifier"]) {
        NSString *orig = %orig;
        if (ShouldSpoof(orig)) {
            return kWCPTargetBundleID;
        }
        return orig;
    }
    return %orig;
}

%end

%end

%ctor {
    @autoreleasepool {
        // 二次保险：仅在微信主二进制（官方或任意多开变体）内初始化。
        // plist 已按 Executable "WeChat" 过滤，此处再按真实 bid 收敛到多开场景，
        // 避免把伪装逻辑意外注入到同名执行文件的非微信进程。
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (ShouldSpoof(bid)) {
            %init(WCPBidSpoof);
        }
    }
}

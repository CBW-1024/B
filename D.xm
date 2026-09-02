// WCBetaUnlock — 对齐 WCR 内部版的内测资格绕过 tweak
//
// 原理（已用本次微信头文件 dump + WCR 二进制反汇编双向坐实）：
//   1. 微信登录请求体 ManualAuthAesReqData.bundleId (ManualAuthAesReqData.h:22)
//      与 AutoAuthAesReqData.bundleId (AutoAuthAesReqData.h:20) 携带包名上送服务器；
//      写入源头是 WCAccountManualAuthControlLogic.genManualAuthRequest:
//      (WCAccountManualAuthControlLogic.h:32-33) 里的
//      [[NSBundle mainBundle] bundleIdentifier]。
//   2. 服务器识别到内测/测试版 bid（om.tencent.qy.xin / com.tencent.wx /
//      com.tencent.mm.xin）会查账号内测白名单，不在名单则
//      AuthSectResp.applyBetaUrl (AuthSectResp.h:34) 返回非空，
//      客户端弹“该账号尚未获得体验资格…”。
//   3. WCR 内部版的做法是擒贼先擒王：用 MSHookMessageEx 只 hook 了
//      NSBundle 的 mainBundle / bundleIdentifier，让主 bundle 一律返回
//      官方包名 com.tencent.xin（其二进制 0x1582fac 处 return @"com.tencent.xin"）。
//      上游被伪装后，下游所有读取点（登录请求、TSEnvironment.bundleIdentifier、
//      NewLifeClientVersionInfo.bundleId…）拿到的都是官方值，服务器不入内测分支。
//
// 本 tweak 严格对齐 WCR：只 hook NSBundle 最上游入口。
// WC_HOOK_AUTH_DATA 为可选的“双保险”，直接钉死登录请求里的 bundleId 字段
// （锚定 ManualAuthAesReqData.h:22 / AutoAuthAesReqData.h:20），即便有路径绕过
// NSBundle 也能兜底。默认开启，可置 0 还原为纯 WCR 行为。

#define WC_OFFICIAL_BID @"com.tencent.xin"
#define WC_HOOK_AUTH_DATA 1

%hook NSBundle

- (NSString *)bundleIdentifier {
    // 仅对“主 bundle”（即微信 App 本体）伪装，框架/插件保持真实 bid，避免副作用
    if (self == [NSBundle mainBundle]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}

%end

#if WC_HOOK_AUTH_DATA
// 双保险：直接把登录鉴权请求体里的 bundleId 钉成官方包名。
// 不依赖 NSBundle 上游是否已被完全覆盖。这两个类的属性名来自本次 dump 头文件。
%hook ManualAuthAesReqData
- (void)setBundleId:(NSString *)bundleId {
    %orig(WC_OFFICIAL_BID);
}
%end

%hook AutoAuthAesReqData
- (void)setBundleId:(NSString *)bundleId {
    %orig(WC_OFFICIAL_BID);
}
%end
#endif

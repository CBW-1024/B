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
// 本 tweak 严格对齐 WCR：仅 hook -[NSBundle bundleIdentifier]，
// 对主 bundle 返回官方包名，框架/插件 bundle 保持真实值以免副作用。
// （WCR 二进制已确认只 hook NSBundle，setBundleId: 等 selector 出现次数为 0，
//  故本 tweak 不引入任何 WCR 之外的 hook。）

#define WC_OFFICIAL_BID @"com.tencent.xin"

%hook NSBundle

- (NSString *)bundleIdentifier {
    if (self == [NSBundle mainBundle]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}

%end

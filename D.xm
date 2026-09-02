#import <Foundation/Foundation.h>

// WCBetaUnlock
// 让微信内测 / 测试版以官方正式版(com.tencent.xin)身份通过登录与人脸核身。
// 原理：在登录、人脸核身流程期间，把主 bundle 的 bundleIdentifier 伪装成
// 官方包名；流程之外保持真实包名，避免污染推送与 UI。官方正式版自身包名
// 已是 com.tencent.xin，本插件对其完全不生效。

#define WC_OFFICIAL_BID @"com.tencent.xin"

// 真实主 bundle 包名，于 %ctor 阶段读取（此时窗口未开，读到的是原始值）。
// 用于判断当前是否运行在内测版：官方版此项等于 WC_OFFICIAL_BID，插件整体不生效。
static NSString *WC_REAL_BID = nil;

// 伪装窗口标志：为 YES 时主 bundle 的 bundleIdentifier 返回官方包名。
static BOOL g_masking = NO;

// 直接开 / 关窗口（人脸这类长窗口钩子使用）。
static inline void WCBSetMasking(BOOL on) { g_masking = on; }

// 包裹式开 / 关：保存旧状态并开窗，返回旧状态；%orig 后仅当自己开的窗才收口，
// 避免嵌套钩子里层退出时提前收掉外层窗（人脸长窗口与登录重连相互嵌套）。
static inline BOOL WCBBeginMasking(void) {
    BOOL prev = g_masking;
    g_masking = YES;
    return prev;
}
static inline void WCBEndMasking(BOOL prev) {
    if (!prev) g_masking = NO;
}

// 核心伪装点：登录 / 人脸流程期间，主 bundle 返回官方包名。
// 微信登录请求、风控上报、人脸核身公共包头都从这里读 bundle id，故只改这一处即可。
// 官方版(WC_REAL_BID == WC_OFFICIAL_BID)下条件恒假，伪装不触发。
%hook NSBundle
- (NSString *)bundleIdentifier {
    if (g_masking && self == [NSBundle mainBundle] && ![WC_REAL_BID isEqualToString:WC_OFFICIAL_BID]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}
%end

// 手动登录请求体构造入口：开窗包裹整个构造，使请求体内部所有读 bundle id 处拿到官方包名。
%hook WCAccountManualAuthControlLogic
- (id)genManualAuthRequest:(BOOL)arg {
    BOOL prev = WCBBeginMasking();
    id r = %orig;
    WCBEndMasking(prev);
    return r;
}
- (id)genManualAuthRequest {
    BOOL prev = WCBBeginMasking();
    id r = %orig;
    WCBEndMasking(prev);
    return r;
}
%end

// 自动登录入口：开窗覆盖自动登录请求构造时的包名读取。
%hook WCAccountAutoLoginControlLogic
- (BOOL)startAutoAuth:(id)arg {
    BOOL prev = WCBBeginMasking();
    BOOL r = %orig;
    WCBEndMasking(prev);
    return r;
}
%end

// 账号管理器的手动重登与前台 / 超时重连入口：开窗覆盖这些重连路径下的包名读取。
%hook WCAccountControlMgr
- (void)startManualAuth {
    BOOL prev = WCBBeginMasking();
    %orig;
    WCBEndMasking(prev);
}
- (void)makeAutoAuth {
    BOOL prev = WCBBeginMasking();
    %orig;
    WCBEndMasking(prev);
}
%end

// 前后台生命周期：回到前台时微信触发自动重连，开窗覆盖重连的包名读取。
// 仅做包裹式开关，不额外强制收口；人脸窗口由 FaceRecogBaseHandler 自行收口。
%hook MicroMessengerAppDelegate
- (void)applicationDidBecomeActive:(id)arg {
    BOOL prev = WCBBeginMasking();
    %orig;
    WCBEndMasking(prev);
}
- (void)applicationWillEnterForeground:(id)arg {
    BOOL prev = WCBBeginMasking();
    %orig;
    WCBEndMasking(prev);
}
%end

// 人脸核身：微信各人脸流程(支付实名 / 绑卡 / 重置支付密码 / 新设备登录 / 第三方核身)
// 最终都经 FaceRecogBaseHandler。startFaceRecog 是共同入口，onRealFinish /
// faceRecogDidCancel / dealloc 是共同终态，开窗与收口都落在这一个类。
// 人脸 CGI 不带 bundleId 字段，bid 取自统一公共包头(即 NSBundle.bundleIdentifier)，
// 故只需控制主 bundle 的包名即可覆盖全部人脸场景。
%hook FaceRecogBaseHandler
- (void)startFaceRecog {
    WCBSetMasking(YES);
    %orig;
}
- (void)onRealFinish {
    %orig;
    WCBSetMasking(NO);
}
- (void)faceRecogDidCancel {
    %orig;
    WCBSetMasking(NO);
}
- (void)dealloc {
    WCBSetMasking(NO);
    %orig;
}
%end

// 启动缓存真实包名，决定插件是否对当前安装生效。
%ctor {
    WC_REAL_BID = [[NSBundle mainBundle] bundleIdentifier];
}

#import <Foundation/Foundation.h>

// WCBetaUnlock
// 让微信内测/测试版包名（如 om.tencent.qy.xin / com.tencent.wx /
// com.tencent.mm.xin）能够正常登录并通过人脸核身。原理：在登录与
// 人脸核身流程期间，把主 bundle 的 bundleIdentifier 伪装成官方正式版
// 包名 com.tencent.xin，使服务器不按内测白名单拒绝，也不按测试版
// bid 拒绝人脸。流程之外保持真实 bundle id，避免污染推送与 UI。

#define WC_OFFICIAL_BID @"com.tencent.xin"

// 鉴权/人脸窗口标志：为 YES 时，主 bundle 的 bundleIdentifier 返回官方包名
static BOOL g_inAuthChain = NO;

// Hook 1: NSBundle -bundleIdentifier
// 核心伪装点。当处于登录或人脸窗口（g_inAuthChain 为 YES）且是主
// bundle 时，返回官方包名 com.tencent.xin；其余情况返回真实值。
// 微信的登录请求、风控上报、人脸核身公共包头都从这里读取 bundle id，
// 因此只改这一处即可覆盖所有这些上送路径。
%hook NSBundle
- (NSString *)bundleIdentifier {
    if (g_inAuthChain && self == [NSBundle mainBundle]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}
%end

// Hook 2: WCAccountManualAuthControlLogic -genManualAuthRequest: / -genManualAuthRequest
// 手动登录请求体的构造入口。打开鉴权窗口包裹整个构造过程，使请求体
// 内外所有读取 bundle id 的地方（含风控、版本上报）一并拿到官方包名。
%hook WCAccountManualAuthControlLogic
- (id)genManualAuthRequest:(BOOL)arg {
    g_inAuthChain = YES;
    id r = %orig;
    g_inAuthChain = NO;
    return r;
}
- (id)genManualAuthRequest {
    g_inAuthChain = YES;
    id r = %orig;
    g_inAuthChain = NO;
    return r;
}
%end

// Hook 3: WCAccountAutoLoginControlLogic -startAutoAuth:
// 自动登录入口。打开鉴权窗口，覆盖自动登录请求构造时的包名读取。
%hook WCAccountAutoLoginControlLogic
- (BOOL)startAutoAuth:(id)arg {
    g_inAuthChain = YES;
    BOOL r = %orig;
    g_inAuthChain = NO;
    return r;
}
%end

// Hook 4: WCAccountControlMgr -startManualAuth / -makeAutoAuth
// 账号控制管理器的手动重登与回到前台/超时重连入口。打开鉴权窗口，
// 覆盖这些重连路径下的包名读取。实测 startManualAuth 在重新登录时
// 会触发一次，makeAutoAuth 在前台重连时频繁触发。
%hook WCAccountControlMgr
- (void)startManualAuth {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
- (void)makeAutoAuth {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
%end

// Hook 5: MicroMessengerAppDelegate 前后台生命周期
// 划掉后台再打开时，微信在这两个回调期间触发自动重连，因此打开
// 鉴权窗口覆盖前台重连的包名读取。applicationDidEnterBackground 作为
// 安全网：无论登录或人脸因异常未正常关闭窗口，进后台都强制关闭，
// 防止 g_inAuthChain 卡在 YES 而污染后续 UI/推送。
%hook MicroMessengerAppDelegate
- (void)applicationDidBecomeActive:(id)arg {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
- (void)applicationWillEnterForeground:(id)arg {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
- (void)applicationDidEnterBackground:(id)arg {
    g_inAuthChain = NO;
    %orig;
}
%end

// Hook 6: FaceRecogFlashHandler 人脸核身窗口
// 人脸核身的活体检测与上报处理器。人脸 CGI 不带 bundleId 字段，其
// bid 来自微信统一公共包头（即 NSBundle.bundleIdentifier）。原窗口只
// 覆盖登录/重连链路，人脸不在其中，故公共包头带真实测试版 bid 导致
// 服务器拒绝。此处：start 进入即打开窗口（不在 start 内关闭，覆盖
// 整个人脸会话期），流水线与结果回调结束时关闭窗口。对齐 WCPulse
// 对 FaceRecogFlashHandler 整类宽松伪装的实质，且进后台安全网会强制
// 关闭，避免卡死。
%hook FaceRecogFlashHandler
- (void)start {
    g_inAuthChain = YES;
    %orig;
}
- (void)onPipelineFinishWithSuccess:(BOOL)arg {
    %orig;
    g_inAuthChain = NO;
}
- (void)callbackFlashWithData:(id)arg1 error:(id)arg2 {
    %orig;
    g_inAuthChain = NO;
}
%end

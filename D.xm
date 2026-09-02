#import <Foundation/Foundation.h>

// WCBetaUnlock
// 让微信内测/测试版包名（如 om.tencent.qy.xin / com.tencent.wx /
// com.tencent.mm.xin）能够正常登录并通过人脸核身。原理：在登录与
// 人脸核身流程期间，把主 bundle 的 bundleIdentifier 伪装成官方正式版
// 包名 com.tencent.xin，使服务器不按内测白名单拒绝，也不按测试版
// bid 拒绝人脸。流程之外保持真实 bundle id，避免污染推送与 UI。
//
// 日志：写入微信沙盒 Documents/WCBetaUnlock.log（未越狱也能取）。
// 每条格式 [+秒.毫秒] HIT/FLAG。窗口翻转时会带上本窗口内
// officialBidHits（返回官方包名的次数），用于确认伪造是否真的生效。
// 注意 NSBundle -bundleIdentifier 调用极其频繁，故该处不逐条打日志，
// 只累计命中次数，避免日志刷屏与影响性能；其余 hook 都记录命中，
// 便于排查哪些 hook 从未触发（死钩子）。
// 日志超过 1.5MB 自动覆盖重写，不会无限增长。

#define WC_OFFICIAL_BID @"com.tencent.xin"

// 鉴权/人脸窗口标志：为 YES 时，主 bundle 的 bundleIdentifier 返回官方包名
static BOOL g_inAuthChain = NO;

// 当前窗口内返回官方包名的次数
static int g_bidHit = 0;

static NSString *WCBLogPath(void) {
    static NSString *path = nil;
    if (!path) {
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        path = [[dirs firstObject] stringByAppendingPathComponent:@"WCBetaUnlock.log"];
    }
    return path;
}

static NSTimeInterval WCBElapsed(void) {
    static NSTimeInterval t0 = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (t0 == 0) t0 = now;
    return now - t0;
}

static void WCBWriteLog(NSString *line) {
    NSString *full = [NSString stringWithFormat:@"[+%8.3f] %@\n", WCBElapsed(), line];
    NSData *data = [full dataUsingEncoding:NSUTF8StringEncoding];
    NSString *p = WCBLogPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:p]) {
        [fm createFileAtPath:p contents:nil attributes:nil];
    } else {
        NSDictionary *attr = [fm attributesOfItemAtPath:p error:nil];
        if (attr && [attr fileSize] > 1500000) {
            [data writeToFile:p atomically:YES];
            return;
        }
    }
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    [fh seekToEndOfFile];
    [fh writeData:data];
    [fh closeFile];
}

static void WCBLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    @synchronized (WCBLogPath()) {
        WCBWriteLog(msg);
    }
}

// 窗口开关：仅在状态真正翻转时记录。
// 关闭时顺带输出本窗口内官方包名命中次数，为零说明伪造没生效。
//
// 嵌套安全：登录/前后台类钩子是"包裹式"（进入开窗、%orig 后关窗），
// 而人脸流程是"长窗口"。两者会互相嵌套——实测日志里人脸进行中
// applicationDidBecomeActive: 触发并直接把人脸窗口关掉，
// makeAutoAuth 内部又嵌套 startAutoAuth:。若包裹式钩子无条件置 NO，
// 内层退出时会提前收掉外层的窗。因此这类钩子统一采用
// "保存旧值 → 开窗 → %orig → 仅在自己开窗时才收口"的模式，
// 由 WCBFlagBegin/WCBFlagEnd 成对使用。
static inline BOOL WCBFlagBegin(const char *where) {
    BOOL prev = g_inAuthChain;
    WCBSetFlag(YES, where);
    return prev;
}

static inline void WCBFlagEnd(BOOL prev, const char *where) {
    if (!prev) WCBSetFlag(NO, where);
}

static void WCBSetFlag(BOOL on, const char *where) {
    @synchronized (WCBLogPath()) {
        if (g_inAuthChain == on) return;
        if (!on) {
            WCBWriteLog([NSString stringWithFormat:@"FLAG OFF @ %s (officialBidHits=%d)", where, g_bidHit]);
            g_bidHit = 0;
        } else {
            WCBWriteLog([NSString stringWithFormat:@"FLAG  ON @ %s", where]);
        }
        g_inAuthChain = on;
    }
}

static void WCBHit(const char *where) {
    WCBLog(@"HIT  %s", where);
}

// Hook 1: NSBundle -bundleIdentifier
// 核心伪装点。当处于登录或人脸窗口（g_inAuthChain 为 YES）且是主
// bundle 时，返回官方包名 com.tencent.xin；其余情况返回真实值。
// 微信的登录请求、风控上报、人脸核身公共包头都从这里读取 bundle id，
// 因此只改这一处即可覆盖所有这些上送路径。
// 此处不打逐条日志，只累计命中次数（窗口关闭时统一输出）。
%hook NSBundle
- (NSString *)bundleIdentifier {
    if (g_inAuthChain && self == [NSBundle mainBundle]) {
        g_bidHit++;
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
    WCBHit("WCAccountManualAuthControlLogic -genManualAuthRequest:");
    BOOL prev = WCBFlagBegin("WCAccountManualAuthControlLogic.genManualAuthRequest:");
    id r = %orig;
    WCBFlagEnd(prev, "WCAccountManualAuthControlLogic.genManualAuthRequest:");
    return r;
}
- (id)genManualAuthRequest {
    WCBHit("WCAccountManualAuthControlLogic -genManualAuthRequest");
    BOOL prev = WCBFlagBegin("WCAccountManualAuthControlLogic.genManualAuthRequest");
    id r = %orig;
    WCBFlagEnd(prev, "WCAccountManualAuthControlLogic.genManualAuthRequest");
    return r;
}
%end

// Hook 3: WCAccountAutoLoginControlLogic -startAutoAuth:
// 自动登录入口。打开鉴权窗口，覆盖自动登录请求构造时的包名读取。
%hook WCAccountAutoLoginControlLogic
- (BOOL)startAutoAuth:(id)arg {
    WCBHit("WCAccountAutoLoginControlLogic -startAutoAuth:");
    BOOL prev = WCBFlagBegin("WCAccountAutoLoginControlLogic.startAutoAuth:");
    BOOL r = %orig;
    WCBFlagEnd(prev, "WCAccountAutoLoginControlLogic.startAutoAuth:");
    return r;
}
%end

// Hook 4: WCAccountControlMgr -startManualAuth / -makeAutoAuth
// 账号控制管理器的手动重登与回到前台/超时重连入口。打开鉴权窗口，
// 覆盖这些重连路径下的包名读取。实测 startManualAuth 在重新登录时
// 会触发一次，makeAutoAuth 在前台重连时频繁触发。
%hook WCAccountControlMgr
- (void)startManualAuth {
    WCBHit("WCAccountControlMgr -startManualAuth");
    BOOL prev = WCBFlagBegin("WCAccountControlMgr.startManualAuth");
    %orig;
    WCBFlagEnd(prev, "WCAccountControlMgr.startManualAuth");
}
- (void)makeAutoAuth {
    WCBHit("WCAccountControlMgr -makeAutoAuth");
    BOOL prev = WCBFlagBegin("WCAccountControlMgr.makeAutoAuth");
    %orig;
    WCBFlagEnd(prev, "WCAccountControlMgr.makeAutoAuth");
}
%end

// Hook 5: MicroMessengerAppDelegate 前后台生命周期
// 划掉后台再打开时，微信在这两个回调期间触发自动重连，因此打开
// 鉴权窗口覆盖前台重连的包名读取。applicationDidEnterBackground 作为
// 安全网：无论登录或人脸因异常未正常关闭窗口，进后台都强制关闭，
// 防止 g_inAuthChain 卡在 YES 而污染后续 UI/推送。
%hook MicroMessengerAppDelegate
- (void)applicationDidBecomeActive:(id)arg {
    WCBHit("MicroMessengerAppDelegate -applicationDidBecomeActive:");
    BOOL prev = WCBFlagBegin("MicroMessengerAppDelegate.applicationDidBecomeActive:");
    %orig;
    WCBFlagEnd(prev, "MicroMessengerAppDelegate.applicationDidBecomeActive:");
}
- (void)applicationWillEnterForeground:(id)arg {
    WCBHit("MicroMessengerAppDelegate -applicationWillEnterForeground:");
    BOOL prev = WCBFlagBegin("MicroMessengerAppDelegate.applicationWillEnterForeground:");
    %orig;
    WCBFlagEnd(prev, "MicroMessengerAppDelegate.applicationWillEnterForeground:");
}
- (void)applicationDidEnterBackground:(id)arg {
    WCBHit("MicroMessengerAppDelegate -applicationDidEnterBackground:");
    WCBSetFlag(NO, "MicroMessengerAppDelegate.applicationDidEnterBackground:");
    %orig;
}
%end

// Hook 6: FaceRecogBaseHandler -startFaceRecog（全部人脸流程的共同入口）
// 人脸 CGI 不带 bundleId 字段，bid 取自微信统一公共包头
// （即 NSBundle.bundleIdentifier），所以只需控制住主 bundle 的
// bundleIdentifier，无需逐个 hook 发包方法。
//
// 为什么只 hook 这一个点就够——微信四条人脸流程的继承/持有关系：
//   FaceRecogBaseHandler
//     └─ FaceRecogInternelHandler（持有 FaceRecogFlashHandler）
//          └─ FaceRecog3rdVerifyHandler（第三方核身）
//   WebviewJSEventHandler_internelWxFaceVerify 持有 InternelHandler
//     （新设备登录验证走这条）
//   FaceRecogPayHandler : NSObject（支付，唯一不是 BaseHandler 子类的）
// 前三条直接继承或持有 BaseHandler；支付那条虽然是独立 NSObject，
// 但实测日志显示它内部启动的活体处理器同样走到
// FaceRecogBaseHandler -startFaceRecog（+48.378，在其自身 startFace:
// 之后约 3 秒）。因此 startFaceRecog 是四条路的共同入口，在此开窗
// 即可一次性覆盖支付实名、绑卡、重置支付密码、新设备登录验证、
// 第三方核身等全部人脸场景。
//
// 实测病根：officialBidHits=76 说明伪造生效，活体回调 err=(null)
// 说明本地检测成功，但窗口在第一次 callbackFlashWithData: 时就被
// 关掉了，后续提交服务器的请求带着真实测试版 bid。因此这里开窗后
// 不再设任何中间收口点——窗口是全局时间区间，首尾卡准即覆盖全程；
// 钩得越密反而越多"提前收口"的机会，这正是旧版失效的原因。
%hook FaceRecogBaseHandler
- (void)startFaceRecog {
    WCBHit("FaceRecogBaseHandler -startFaceRecog");
    WCBSetFlag(YES, "FaceRecogBaseHandler.startFaceRecog");
    %orig;
}
%end

// Hook 7: FaceRecogBaseViewController 收口（人脸界面的共同终点）
// 所有人脸流程的结果最终都经 VC 呈现：成功走 procedureDidFinish，
// 失败走 procedureDidFailed:errorTips:canRetry:（"系统繁忙，请重试"
// 就由它渲染）。二者是跨场景的统一收口点，此处仅透传并打印服务端
// 提示，不做阻断。
// 若异常路径下二者都没触发，进后台安全网（Hook 5）会强制收口。
%hook FaceRecogBaseViewController
- (void)procedureDidFinish {
    WCBHit("FaceRecogBaseViewController -procedureDidFinish");
    %orig;
    WCBSetFlag(NO, "FaceRecogBaseViewController.procedureDidFinish");
}
- (void)procedureDidFailed:(id)arg1 errorTips:(id)arg2 canRetry:(BOOL)arg3 {
    WCBLog(@"HIT  FaceRecogBaseViewController -procedureDidFailed  tips=%@ canRetry=%d", arg2, arg3);
    %orig;
    WCBSetFlag(NO, "FaceRecogBaseViewController.procedureDidFailed");
}
%end

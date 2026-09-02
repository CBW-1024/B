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

// Hook 6: 人脸核身窗口（从引导页出现一路放宽到会话结束）
// 人脸 CGI 不带 bundleId 字段，bid 取自微信统一公共包头
// （即 NSBundle.bundleIdentifier）。实测现象：刷脸引导页能正常弹出，
// 点击"验证"后立刻"系统繁忙，请重试"、摄像头都没进——说明流程本身
// 已启动，是服务器在最早的配置 CGI 上按内测 bid 拒绝了。而配置请求
// （FaceRecogConfigLogic.startGetBioConfig）是在
// FaceRecogBaseHandler.startFaceRecog → initConfigLogic 阶段、
// FaceRecogFlashHandler.start 之前就发出的，窗口开晚了必然漏掉。
// 因此这里按"最宽"处理：从人脸 VC 出现（viewDidLoad/viewWillAppear/
// viewDidAppear，即引导页渲染时刻）就打开窗口，再叠加 handler 根入口
// 与配置发包方法作为纵深，确保无论请求在会话内哪一刻发出都带官方
// bid；只在流程真正结束或取消时关闭。所有入口一律"只开不关"，
// 避免短包裹错过异步发包时刻、也避免把主窗口提前关掉。
// procedureDidFailed:errorTips:canRetry: 就是"系统繁忙"的渲染入口，
// 此处仅透传并打印服务端提示，不做阻断。进后台安全网（Hook 5）最终
// 强制关闭。
%hook FaceRecogBaseViewController
- (void)viewDidLoad {
    WCBHit("FaceRecogBaseViewController -viewDidLoad");
    WCBSetFlag(YES, "FaceRecogBaseViewController.viewDidLoad");
    %orig;
}
- (void)viewWillAppear:(BOOL)arg {
    WCBHit("FaceRecogBaseViewController -viewWillAppear:");
    WCBSetFlag(YES, "FaceRecogBaseViewController.viewWillAppear:");
    %orig;
}
- (void)viewDidAppear:(BOOL)arg {
    WCBHit("FaceRecogBaseViewController -viewDidAppear:");
    WCBSetFlag(YES, "FaceRecogBaseViewController.viewDidAppear:");
    %orig;
}
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

// Hook 7: FaceRecog3rdVerifyConfirmViewController 第三方核身确认页
// 图1"刷脸验证"引导页的另一条载体，onStartFaceReco 即"验证"按钮的
// 点击入口。在进入确认页与点击验证时都打开窗口，取消时关闭。
%hook FaceRecog3rdVerifyConfirmViewController
- (void)viewDidLoad {
    WCBHit("FaceRecog3rdVerifyConfirmViewController -viewDidLoad");
    WCBSetFlag(YES, "FaceRecog3rdVerifyConfirmViewController.viewDidLoad");
    %orig;
}
- (void)onStartFaceReco {
    WCBHit("FaceRecog3rdVerifyConfirmViewController -onStartFaceReco");
    WCBSetFlag(YES, "FaceRecog3rdVerifyConfirmViewController.onStartFaceReco");
    %orig;
}
- (void)onCancel {
    WCBHit("FaceRecog3rdVerifyConfirmViewController -onCancel");
    %orig;
    WCBSetFlag(NO, "FaceRecog3rdVerifyConfirmViewController.onCancel");
}
%end

// Hook 8: FaceRecogBaseHandler -startFaceRecog
// 人脸 handler 的根入口，initConfigLogic（发起 getBioConfig 配置请求）
// 在其内部执行。在此打开窗口可覆盖最早期那次配置发包，这是本次
// 修复"点验证即系统繁忙"的关键提前量。
%hook FaceRecogBaseHandler
- (void)startFaceRecog {
    WCBHit("FaceRecogBaseHandler -startFaceRecog");
    WCBSetFlag(YES, "FaceRecogBaseHandler.startFaceRecog");
    %orig;
}
%end

// Hook 9: FaceRecogConfigLogic 配置发包与回包
// 直接兜住发包点：无论谁发起配置请求，进入这些方法时都确保窗口
// 处于打开状态。MessageReturn:Event: 与 handleGetBioConfig: 仅用于
// 记录服务端回包类型与事件号，便于判断是网络/协议错误还是按 bid
// 拒绝，不改变任何行为。
%hook FaceRecogConfigLogic
- (BOOL)startGetBioConfigForType:(unsigned int)arg1 atScene:(unsigned int)arg2 {
    WCBHit("FaceRecogConfigLogic -startGetBioConfigForType:atScene:");
    WCBSetFlag(YES, "FaceRecogConfigLogic.startGetBioConfigForType:atScene:");
    return %orig;
}
- (BOOL)startGetBioConfigForType:(unsigned int)arg1 atScene:(unsigned int)arg2 userTicket:(id)arg3 isRsa:(BOOL)arg4 {
    WCBHit("FaceRecogConfigLogic -startGetBioConfigForType:atScene:userTicket:isRsa:");
    WCBSetFlag(YES, "FaceRecogConfigLogic.startGetBioConfigForType:atScene:userTicket:isRsa:");
    return %orig;
}
- (BOOL)startRsaGetBioConfigForType:(unsigned int)arg1 atScene:(unsigned int)arg2 userTicket:(id)arg3 {
    WCBHit("FaceRecogConfigLogic -startRsaGetBioConfigForType:atScene:userTicket:");
    WCBSetFlag(YES, "FaceRecogConfigLogic.startRsaGetBioConfigForType:atScene:userTicket:");
    return %orig;
}
- (void)MessageReturn:(id)arg1 Event:(unsigned int)arg2 {
    WCBLog(@"HIT  FaceRecogConfigLogic -MessageReturn  resp=%@ event=%u", [arg1 class], arg2);
    %orig;
}
- (void)handleGetBioConfig:(id)arg {
    WCBLog(@"HIT  FaceRecogConfigLogic -handleGetBioConfig  resp=%@", [arg class]);
    %orig;
}
%end

// Hook 10: FaceRecogInternelHandler 内测/实名核身主流程
// 弹起摄像头前后的入口与完成/取消收口。窗口由更早的 VC 与
// startFaceRecog 打开，这里仅作纵深并在结束时关闭。
%hook FaceRecogInternelHandler
- (void)startFace {
    WCBHit("FaceRecogInternelHandler -startFace");
    WCBSetFlag(YES, "FaceRecogInternelHandler.startFace");
    %orig;
}
- (void)startWithHasCheckBrightness:(BOOL)arg {
    WCBHit("FaceRecogInternelHandler -startWithHasCheckBrightness:");
    WCBSetFlag(YES, "FaceRecogInternelHandler.startWithHasCheckBrightness:");
    %orig;
}
- (void)faceRecogHandlerDidFinish:(id)arg {
    WCBHit("FaceRecogInternelHandler -faceRecogHandlerDidFinish:");
    %orig;
    WCBSetFlag(NO, "FaceRecogInternelHandler.faceRecogHandlerDidFinish:");
}
- (void)faceRecogHandlerDidCancel:(id)arg {
    WCBHit("FaceRecogInternelHandler -faceRecogHandlerDidCancel:");
    %orig;
    WCBSetFlag(NO, "FaceRecogInternelHandler.faceRecogHandlerDidCancel:");
}
%end

// Hook 11: FaceRecogPayHandler 支付核身流程
// 支付场景是独立 NSObject（非 BaseHandler 子类），有自己的
// startFace:/onStartFaceRecog/startRealFaceRecog 入口与
// onGetFaceCheckResult: 结果回调，需单独覆盖。
%hook FaceRecogPayHandler
- (void)startFace:(unsigned int)arg {
    WCBHit("FaceRecogPayHandler -startFace:");
    WCBSetFlag(YES, "FaceRecogPayHandler.startFace:");
    %orig;
}
- (void)onStartFaceRecog {
    WCBHit("FaceRecogPayHandler -onStartFaceRecog");
    WCBSetFlag(YES, "FaceRecogPayHandler.onStartFaceRecog");
    %orig;
}
- (void)startRealFaceRecog {
    WCBHit("FaceRecogPayHandler -startRealFaceRecog");
    WCBSetFlag(YES, "FaceRecogPayHandler.startRealFaceRecog");
    %orig;
}
- (void)faceRecogHandlerDidFinish:(id)arg {
    WCBHit("FaceRecogPayHandler -faceRecogHandlerDidFinish:");
    %orig;
    WCBSetFlag(NO, "FaceRecogPayHandler.faceRecogHandlerDidFinish:");
}
- (void)faceRecogHandlerDidCancel:(id)arg {
    WCBHit("FaceRecogPayHandler -faceRecogHandlerDidCancel:");
    %orig;
    WCBSetFlag(NO, "FaceRecogPayHandler.faceRecogHandlerDidCancel:");
}
- (void)onGetFaceCheckResult:(id)arg {
    WCBLog(@"HIT  FaceRecogPayHandler -onGetFaceCheckResult  resp=%@", [arg class]);
    %orig;
    WCBSetFlag(NO, "FaceRecogPayHandler.onGetFaceCheckResult:");
}
%end

// Hook 12: FaceRecogPrivateVerifyHandler 第三方代 verify 流程
// 另一条独立入口（MMObject），内部持有真 handler，doStartFaceReco
// 与 start 处打开窗口，完成/取消处关闭。
%hook FaceRecogPrivateVerifyHandler
- (void)doStartFaceReco {
    WCBHit("FaceRecogPrivateVerifyHandler -doStartFaceReco");
    WCBSetFlag(YES, "FaceRecogPrivateVerifyHandler.doStartFaceReco");
    %orig;
}
- (void)start {
    WCBHit("FaceRecogPrivateVerifyHandler -start");
    WCBSetFlag(YES, "FaceRecogPrivateVerifyHandler.start");
    %orig;
}
- (void)faceRecogHandlerDidFinish:(id)arg {
    WCBHit("FaceRecogPrivateVerifyHandler -faceRecogHandlerDidFinish:");
    %orig;
    WCBSetFlag(NO, "FaceRecogPrivateVerifyHandler.faceRecogHandlerDidFinish:");
}
- (void)faceRecogHandlerDidCancel:(id)arg {
    WCBHit("FaceRecogPrivateVerifyHandler -faceRecogHandlerDidCancel:");
    %orig;
    WCBSetFlag(NO, "FaceRecogPrivateVerifyHandler.faceRecogHandlerDidCancel:");
}
%end

// Hook 13: FaceRecogFlashHandler 活体检测与上传
// 真正的活体检测与数据上传处理器。
// 重要教训（实测日志得出）：callbackFlashWithData:error: 在一次人脸
// 会话里会被调用多次（本次实测 4 次，间隔数秒，err 均为 null），
// 它贯穿"活体检测完成 → 数据提交服务器"的全过程。早期版本在第一次
// 回调就把窗口关掉，导致后面几次真正提交给服务器的请求带着真实
// 测试版 bid，服务器据此拒绝，最终 procedureDidFailed。日志表现为
// officialBidHits=76 之后再无命中。因此这两个回调一律改为"只开不关"：
// 每次进入都确保窗口打开，绝不提前收口。窗口的最终关闭交给
// FaceRecogPayHandler 的 faceRecogHandlerDidFinish:/DidCancel: 与
// FaceRecogBaseViewController 的 procedureDidFinish/procedureDidFailed。
%hook FaceRecogFlashHandler
- (void)start {
    WCBHit("FaceRecogFlashHandler -start");
    WCBSetFlag(YES, "FaceRecogFlashHandler.start");
    %orig;
}
- (void)onPipelineFinishWithSuccess:(BOOL)arg {
    WCBLog(@"HIT  FaceRecogFlashHandler -onPipelineFinishWithSuccess: success=%d", arg);
    WCBSetFlag(YES, "FaceRecogFlashHandler.onPipelineFinishWithSuccess:");
    %orig;
}
- (void)callbackFlashWithData:(id)arg1 error:(id)arg2 {
    WCBLog(@"HIT  FaceRecogFlashHandler -callbackFlashWithData:error: err=%@", arg2);
    WCBSetFlag(YES, "FaceRecogFlashHandler.callbackFlashWithData:error:");
    %orig;
}
%end

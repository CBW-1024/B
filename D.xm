#import <Foundation/Foundation.h>

// ============================================================
// WCBetaUnlock — 对齐 WCR 内部版的内测资格绕过 tweak
// 机制：在登录/重连鉴权调用链内把主 bundle 的 bundleIdentifier
//       伪装成官方包名 com.tencent.xin，使服务器不触发内测白名单
//       校验（AuthSectResp.applyBetaUrl 不返回）。
//       用 g_inAuthChain 标志位把伪装限定在鉴权链路窗口内，
//       链外仍返回真实 bundle id，避免污染推送/UI。
//       保留 hook：NSBundle.bundleIdentifier、genManualAuthRequest:*、
//       startAutoAuth:、WCAccountControlMgr.startManualAuth/makeAutoAuth、
//       MicroMessengerAppDelegate 前后台。死代码 startAutoAuth/
//       makeAutoAuthForUpdateInfo/请求类 setBundleId 已据日志删除。
// 日志：编译时设 WC_LOG=1 会在微信沙盒 Documents/WCBetaUnlock.log
//       记录每个 hook 的触发情况，便于排查是否有多余 hook。
// ============================================================

#define WC_OFFICIAL_BID @"com.tencent.xin"
#define WC_LOG 1

// 鉴权链路标志位：YES 时 NSBundle.bundleIdentifier 对主 bundle 返回官方包名
static BOOL g_inAuthChain = NO;

// ---- 日志工具：写入微信沙盒 Documents/WCBetaUnlock.log ----
static void WCLog(NSString *fmt, ...) {
#if WC_LOG
    if (!fmt) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    // 用标准 API 取沙盒 Documents 目录（不依赖微信私有类头文件）
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = docs.firstObject;
    if (!dir) return;

    NSString *logPath = [dir stringByAppendingPathComponent:@"WCBetaUnlock.log"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:logPath]) {
        [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    // 限制日志体积，超过 256KB 时截断前半部分
    NSDictionary *attr = [fm attributesOfItemAtPath:logPath error:nil];
    if (attr && [attr fileSize] > 256 * 1024) {
        [fm removeItemAtPath:logPath error:nil];
        [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MM-dd HH:mm:ss.SSS"];
    NSString *ts = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", ts, msg];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
#else
    (void)fmt;
#endif
}

// ============================================================
// Hook 0: NSBundle -bundleIdentifier
// 核心伪装点。仅当处于鉴权链路(g_inAuthChain)且为主 bundle 时
// 返回官方包名；其余情况走原值，保证推送/UI/风控读到真实 id。
// ============================================================
%hook NSBundle
- (NSString *)bundleIdentifier {
    if (g_inAuthChain && self == [NSBundle mainBundle]) {
        WCLog(@"NSBundle.bundleIdentifier -> 伪装为 %@", WC_OFFICIAL_BID);
        return WC_OFFICIAL_BID;
    }
    return %orig;
}
%end

// ============================================================
// Hook 1: WCAccountManualAuthControlLogic -genManualAuthRequest:
//         WCAccountManualAuthControlLogic -genManualAuthRequest
// 手动登录请求构造入口。打开标志位包裹整个请求体构造，
// 使内部所有读 NSBundle.bundleIdentifier 的地方(含风控/版本上报)
// 一并拿到官方包名。
// 锚定: WCAccountManualAuthControlLogic.h:32-33
// ============================================================
%hook WCAccountManualAuthControlLogic
- (id)genManualAuthRequest:(BOOL)arg {
    g_inAuthChain = YES;
    WCLog(@"genManualAuthRequest: 进入鉴权链");
    id r = %orig;
    g_inAuthChain = NO;
    WCLog(@"genManualAuthRequest: 退出鉴权链");
    return r;
}
- (id)genManualAuthRequest {
    g_inAuthChain = YES;
    WCLog(@"genManualAuthRequest 进入鉴权链");
    id r = %orig;
    g_inAuthChain = NO;
    WCLog(@"genManualAuthRequest 退出鉴权链");
    return r;
}
%end

// ============================================================
// Hook 2: WCAccountAutoLoginControlLogic -startAutoAuth:
// 自动登录入口。包裹标志位，覆盖自动登录请求构造时的包名读取。
// 锚定: WCAccountAutoLoginControlLogic.h:32
// ============================================================
%hook WCAccountAutoLoginControlLogic
- (BOOL)startAutoAuth:(id)arg {
    g_inAuthChain = YES;
    WCLog(@"startAutoAuth: 进入鉴权链");
    BOOL r = %orig;
    g_inAuthChain = NO;
    WCLog(@"startAutoAuth: 退出鉴权链");
    return r;
}
%end

// ============================================================
// Hook 3: WCAccountControlMgr 重连/手动登录入口
// makeAutoAuth 是回到前台或会话超时触发的自动重连入口，必须包裹
// 标志位；startManualAuth 是手动重登路径(实测重登时触发 1 次)，
// 同样需要覆盖。日志实测 startAutoAuth / makeAutoAuthForUpdateInfo
// 从未走到，已移除；setBundleId 双保险 setter 也从未被调用，已移除。
// 锚定: WCAccountControlMgr.h:31/49
// ============================================================
%hook WCAccountControlMgr
- (void)startManualAuth {
    g_inAuthChain = YES;
    WCLog(@"startManualAuth 进入鉴权链");
    %orig;
    g_inAuthChain = NO;
    WCLog(@"startManualAuth 退出鉴权链");
}
- (void)makeAutoAuth {
    g_inAuthChain = YES;
    WCLog(@"makeAutoAuth 进入鉴权链");
    %orig;
    g_inAuthChain = NO;
    WCLog(@"makeAutoAuth 退出鉴权链");
}
%end

// ============================================================
// Hook 4: MicroMessengerAppDelegate 前后台生命周期
// 划掉后台再打开时微信在 applicationWillEnterForeground /
// applicationDidBecomeActive 期间触发自动重连。WCR 内部版也 hook
// 了这两个方法。包裹标志位，使前台重连的包名读取被伪装。
// 锚定: MicroMessengerAppDelegate.h:134/136
// ============================================================
%hook MicroMessengerAppDelegate
- (void)applicationDidBecomeActive:(id)arg {
    g_inAuthChain = YES;
    WCLog(@"applicationDidBecomeActive 进入鉴权链");
    %orig;
    g_inAuthChain = NO;
    WCLog(@"applicationDidBecomeActive 退出鉴权链");
}
- (void)applicationWillEnterForeground:(id)arg {
    g_inAuthChain = YES;
    WCLog(@"applicationWillEnterForeground 进入鉴权链");
    %orig;
    g_inAuthChain = NO;
    WCLog(@"applicationWillEnterForeground 退出鉴权链");
}
%end

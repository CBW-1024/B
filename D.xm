//============================================================================
//  WCPBidSpoof — 微信多开 bid 处理（单文件 Logos tweak）v5.0
//----------------------------------------------------------------------------
//  方向修正（用户指出 + WCR 反汇编实锤）：全局把 bundleIdentifier 改 com.tencent.xin
//  在「签名不等于官方 id」的克隆体上会让运行时 id 与代码签名失配，启动期直接 SIGABRT。
//  所以本地 bundle id【绝不全局改】，只在外发网络请求里替换。
//
//  WCR 实锤的登录模型（hooks_inventory.txt）：
//    835  WCAccountLoginControlLogic  startLogic            0x5267a4
//    836  WCAccountLoginControlLogic  startIPadLoginLogic   0x526818
//    838  WCAccountControlMgr         setM_isLogin:         0x526b10
//    网络层 NSURLSession.dataTaskWithRequest: 0x72e77c 把请求里真实 bid 替换成 com.tencent.xin
//    bundleIdentifier 0x1582ec0 平时返回真实 id（仅刷脸窗口吐官方 id，与登录无关）
//  => 登录 = WCAccountLoginControlLogic 设登录窗口 + 网络层在窗口内替换 bid
//
//  v5.0 架构（1:1 对齐 WCR 登录模型）：
//    ① 本地 bundle id 始终真实（不 hook NSBundle 的 bid 读取，避免启动期崩溃）
//    ② WCAccountLoginControlLogic.startLogic/startIPhoneLoginLogic/
//       startIPadLoginLogic/startRegisterLogic  → 设 gWCPLoginActive=YES（登录窗口开）
//       WCAccountControlMgr.setM_isLogin:        → 清 gWCPLoginActive=NO（登录窗口关）
//    ③ 网络层（NSURL.URLWithString: / NSURLSession.dataTaskWithRequest:）
//       【仅在 gWCPLoginActive 窗口内】把请求 URL（及可选 body）里的真实 bid
//       替换成 com.tencent.xin —— 过登录/风控，且本地 id 不失配、不崩
//    ④ 刷脸：本版不处理（用户自管 FaceRecogFlashHandler）
//
//  运行时开关（app 沙盒 Documents，与日志同目录）：
//    wcp_disable_net → 关网络层（= 纯本地，便于二分定位网络层是否仍崩）
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION                "5.0.0"
#define HOOK_LOGIN_LOGIC          1   // WCAccountLoginControlLogic 各入口 → 开登录窗口
#define HOOK_LOGIN_MGR            1   // WCAccountControlMgr.setM_isLogin: → 关登录窗口
#define HOOK_NETWORK_SPOOF        1   // 网络层 bid 替换（仅在登录窗口内）
#define HOOK_NSURL_REQUEST        1   // NSURL URLWithString: 替换
#define HOOK_NSURLSESSION         1   // NSURLSession dataTaskWithRequest: 替换 URL
#define HOOK_NSURLSESSION_BODY    0   // HTTPBody 替换（默认关：微信 body 多为 protobuf 二进制，字符串替换可能破坏 wire 长度；若仅 URL 级替换登录仍不过，置 1 开启——二进制 body 转 NSString 失败会自动跳过）
#define ENABLE_LOGGING            1
#define LOG_VERBOSE               1
#define WCP_LOG_MAX_LINES         8000

//------------------------------ 日志子系统 -----------------------------------
static FILE        *gWCPLog = NULL;
static volatile int gWCPLogging = 0;
static long         gWCPLogLines = 0;
static volatile int gWCPInHook  = 0;
static char         gWCPLogPath[2048] = {0};
static NSString    *gWCPRealBid = nil;          // 真实 bundle id（%ctor 读取，ARC 下 strong 持有）
static NSString    *gWCPTargetBid = @"com.tencent.xin";
static BOOL         gWCPLoginActive = NO;        // 登录窗口标志（对齐 WCR 0x5267a4/0x526b10）
static BOOL         gWCPNetOff   = NO;           // 运行时降级：网络层关（wcp_disable_net 存在）

// 纯 C 落地异常，绝不经过 Objective-C 格式化，避免在已崩溃路径上二次崩溃
static void WCPLogCatch(const char *where, const char *what) {
    if (!gWCPLog) return;
    time_t t = time(NULL);
    struct tm tm_now; localtime_r(&t, &tm_now);
    fprintf(gWCPLog, "[%04d-%02d-%02d %02d:%02d:%02d] [CATCH] %s -> %s\n",
            tm_now.tm_year+1900, tm_now.tm_mon+1, tm_now.tm_mday,
            tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, where, what ? what : "?");
    fflush(gWCPLog);
}

static void WCPLogOpen(void) {
    if (gWCPLog) return;
    if (!gWCPLogPath[0]) return;
    gWCPLog = fopen(gWCPLogPath, "a");
    if (gWCPLog) {
        fprintf(gWCPLog, "=== WCPBidSpoof log opened @ %s (uid=%d HOME=%s) ===\n",
                gWCPLogPath, getuid(), getenv("HOME") ?: "(null)");
        fflush(gWCPLog);
    }
}

static void WCPLogV(const char *fmt, va_list ap) {
#if !ENABLE_LOGGING
    (void)fmt; (void)ap; return;
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
                    tm_now.tm_year+1900, tm_now.tm_mon+1, tm_now.tm_mday,
                    tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, body);
            fflush(gWCPLog);
            gWCPLogLines++;
        }
    } else {
        NSLog(@"[WCPBidSpoof] %s", body);
    }
    gWCPLogging = 0;
#endif
}

static void WCPLogC(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt); WCPLogV(fmt, ap); va_end(ap);
}

static void WCPLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    WCPLogC("%s", [body UTF8String]);
}

// 把字符串里的真实 bid 替换为官方 bid（返回新字符串，若无需替换返回 nil）
static NSString *WCPReplaceBid(NSString *s) {
    if (!gWCPRealBid || gWCPRealBid.length == 0) return nil;
    if (![s isKindOfClass:[NSString class]] || s.length == 0) return nil;
    if ([s rangeOfString:gWCPRealBid].location == NSNotFound) return nil;
    return [s stringByReplacingOccurrencesOfString:gWCPRealBid withString:gWCPTargetBid];
}

// 开关文件存在=关闭该层（免编译降级）。只在 app 沙盒 Documents 下查，与日志同目录。
static BOOL WCPSwitchOff(NSString *name) {
    if (!gWCPLogPath[0]) return NO;
    NSString *dir = [[NSString stringWithUTF8String:gWCPLogPath]
                     stringByDeletingLastPathComponent];
    NSString *p = [dir stringByAppendingPathComponent:name];
    return [[NSFileManager defaultManager] fileExistsAtPath:p];
}

%group WCPBidSpoof

// ============================ 登录窗口门控（对齐 WCR 0x5267a4 / 0x526b10）============================
#if HOOK_LOGIN_LOGIC
%hook WCAccountLoginControlLogic

- (void)startLogic {
    gWCPLoginActive = YES;
    WCPLog(@"login: startLogic -> gWCPLoginActive=YES (net spoof window OPEN)");
    %orig;
}
- (void)startIPhoneLoginLogic {
    gWCPLoginActive = YES;
    WCPLog(@"login: startIPhoneLoginLogic -> gWCPLoginActive=YES");
    %orig;
}
- (void)startIPadLoginLogic {
    gWCPLoginActive = YES;
    WCPLog(@"login: startIPadLoginLogic -> gWCPLoginActive=YES");
    %orig;
}
- (void)startRegisterLogic {
    gWCPLoginActive = YES;
    WCPLog(@"login: startRegisterLogic -> gWCPLoginActive=YES");
    %orig;
}

%end
#endif // HOOK_LOGIN_LOGIC

#if HOOK_LOGIN_MGR
%hook WCAccountControlMgr

- (void)setM_isLogin:(BOOL)arg1 {
    %orig;
    if (gWCPLoginActive) {
        gWCPLoginActive = NO;
        WCPLog(@"login: setM_isLogin:%d -> gWCPLoginActive=NO (net spoof window CLOSED)", arg1);
    }
}

%end
#endif // HOOK_LOGIN_MGR

// ============================ 网络层替换（仅在登录窗口内，对齐 WCR 0x72e77c）============================
#if HOOK_NETWORK_SPOOF

#if HOOK_NSURL_REQUEST
// 覆盖微信内部 [NSURL URLWithString:] 构造的含 bid 的 URL（仅在登录窗口内）
%hook NSURL

+ (NSURL *)URLWithString:(NSString *)URLString {
    @try {
        if (gWCPInHook) return %orig;
        if (gWCPNetOff || !gWCPLoginActive) return %orig;   // 网络层关 / 非登录窗口 → 纯透传
        if (!URLString) return %orig;                       // 入口判空：nil 直接透传
        gWCPInHook = 1;
        NSString *repl = WCPReplaceBid(URLString);
        NSURL *u;
        if (repl) {
            u = %orig(repl);                               // repl 已不含真实 bid，不会再次进入替换分支
            WCPLog(@"NSURL | spoof %@ -> %@", URLString, repl);
        } else {
            u = %orig(URLString);                          // 不含真实 bid → 原样发（FIXED: 旧版误写 %orig 无参会崩）
        }
        gWCPInHook = 0;
        return u;
    }
    @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSURL.URLWithString", [[e name] UTF8String]);
        return %orig(URLString);
    }
}

%end
#endif // HOOK_NSURL_REQUEST

#if HOOK_NSURLSESSION
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    @try {
        if (gWCPInHook) return %orig;
        if (gWCPNetOff || !gWCPLoginActive) return %orig;  // 网络层关 / 非登录窗口 → 纯透传
        if (!request) return %orig;
        gWCPInHook = 1;

        NSURL *origURL = request.URL;
        NSString *abs = origURL.absoluteString;
        NSString *newAbs = WCPReplaceBid(abs);

        NSURLSessionDataTask *t;
        if (newAbs) {
            NSMutableURLRequest *mreq = [request mutableCopy];
            mreq.URL = [NSURL URLWithString:newAbs];        // 触发 NSURL hook（已 guard）
#if HOOK_NSURLSESSION_BODY
            NSData *body = request.HTTPBody;
            if (body) {
                NSString *bodyStr = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
                NSString *newBody = WCPReplaceBid(bodyStr);
                if (newBody) {
                    mreq.HTTPBody = [newBody dataUsingEncoding:NSUTF8StringEncoding];
                    WCPLog(@"NSURLSession | spoof body too");
                }
            }
#endif
            WCPLog(@"NSURLSession | spoof %@ -> %@", abs, newAbs);
            t = %orig(mreq, completionHandler);
        } else {
            t = %orig;
        }
        gWCPInHook = 0;
        return t;
    }
    @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSURLSession.dataTaskWithRequest", [[e name] UTF8String]);
        return %orig(request, completionHandler);
    }
}

%end
#endif // HOOK_NSURLSESSION

#endif // HOOK_NETWORK_SPOOF

%end // WCPBidSpoof

%ctor {
    @autoreleasepool {
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES).firstObject;
        if (!doc) {
            const char *home = getenv("HOME");
            if (home && *home) doc = [NSString stringWithFormat:@"%s/Documents", home];
        }
        if (doc) snprintf(gWCPLogPath, sizeof(gWCPLogPath), "%s/wcpbidspoof.log", doc.UTF8String);
        WCPLogOpen();

        // 在 hook 安装前读取真实 bundle id（此时 hook 未生效，拿到系统原始值）
        gWCPRealBid = [[NSBundle mainBundle] bundleIdentifier];

        NSString *exe = [[NSBundle mainBundle] executablePath];

        // 运行时降级开关（app 沙盒 Documents 下的空文件，与日志同目录）
        gWCPNetOff = WCPSwitchOff(@"wcp_disable_net");

        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ realBid=%@ LOGIN_GATE=%d NET=%d(off=%d) ===",
               WCP_VERSION, getuid(), exe, gWCPRealBid,
               (HOOK_LOGIN_LOGIC || HOOK_LOGIN_MGR), HOOK_NETWORK_SPOOF, gWCPNetOff);

        if (exe && [exe containsString:@"WeChat"]) {
            %init(WCPBidSpoof);   // 登录窗口门控 + 网络层（窗口内）替换；本地 bundle id 始终真实
            WCPLog(@"init: hooks installed (WCR login-model: local bid REAL, net spoof only in login window)");
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

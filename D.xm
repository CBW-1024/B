//============================================================================
//  WCPBidSpoof — 微信多开 bid 处理（单文件 Logos tweak）v3.1
//----------------------------------------------------------------------------
//  相对 v3.0 的唯一改动：把"启动即闪退"修掉。
//    * 每个业务 hook 用 @try/@catch 兜底，异常时回退 %orig —— 微信【必能打开】，
//      且异常名会被纯 C 写进 wcpbidspoof.log（[CATCH] 行），便于定位真凶。
//    * NSURL hook 入口判空，避免对 nil 做字符串处理。
//    * 新增运行时降级开关（app 沙盒 Documents 下建空文件即可，无需重编译）：
//        wcp_disable_net  → 关闭网络层（NSURL/NSURLSession）伪装，只保留本地透传
//        wcp_disable_face → 关闭刷脸 NSString 层伪装
//  策略不变（对齐 WCR）：
//    ① 登录/风控 = 网络层（NSURL/NSURLSession 把请求里的真实 bid 换成 com.tencent.xin）
//    ② 人脸核身 = NSString 层（仅 FaceRecogFlashHandler 窗口内，self==NSString）
//    本地 bundleIdentifier 始终透传真实 id（保 APNs topic + UI 资源）
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION                "3.1.0"
#define HOOK_BUNDLE_IDENTIFIER    1   // bundleIdentifier 返回真实 id（透传，打日志）
#define HOOK_NETWORK_SPOOF        1   // 网络层 bid 伪装（对齐 WCR：登录/风控所需）
#define HOOK_NSURL_REQUEST        1   // NSURL URLWithString: 替换
#define HOOK_NSURLSESSION         1   // NSURLSession dataTaskWithRequest: 替换 URL
#define HOOK_NSURLSESSION_BODY    0   // ⚠️ HTTPBody 替换（默认关：body 多为 protobuf 二进制）
#define HOOK_FACE_SPOOF           1   // 刷脸 NSString 级 bid 伪装（仅刷脸窗口内，self==NSString）
#define ENABLE_LOGGING            1
#define LOG_VERBOSE               1   // 1=打印每次调用；0=仅异常/替换
#define WCP_LOG_MAX_LINES         8000

//------------------------------ 日志子系统 -----------------------------------
static FILE        *gWCPLog = NULL;
static volatile int gWCPLogging = 0;
static long         gWCPLogLines = 0;
static volatile int gWCPInHook  = 0;
static long         gWCPCallCount = 0;
static char         gWCPLogPath[2048] = {0};
static NSString    *gWCPRealBid = nil;          // 真实 bundle id（%ctor 读取，ARC 下 strong 持有）
static NSString    *gWCPTargetBid = @"com.tencent.xin";
static BOOL         gWCPNetOff  = NO;            // 运行时降级：网络层关（wcp_disable_net 存在）
static BOOL         gWCPFaceOff = NO;            // 运行时降级：刷脸层关（wcp_disable_face 存在）

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

// 开关文件存在=关闭该层（免编译降级）。只在 app 沙盒 Documents 下查，
// 与日志同目录，无需越狱文件管理器也能操作。
static BOOL WCPSwitchOff(NSString *name) {
    if (!gWCPLogPath[0]) return NO;
    NSString *dir = [[NSString stringWithUTF8String:gWCPLogPath]
                     stringByDeletingLastPathComponent];
    NSString *p = [dir stringByAppendingPathComponent:name];
    return [[NSFileManager defaultManager] fileExistsAtPath:p];
}

%group WCPBidSpoof

// ============================ 本地 bundle id：透传真实 id ============================
%hook NSBundle

- (NSString *)bundleIdentifier {
#if !HOOK_BUNDLE_IDENTIFIER
    return %orig;
#else
    if (gWCPInHook) return %orig;
    gWCPInHook = 1;
    NSString *orig = %orig;
    gWCPCallCount++;
#if LOG_VERBOSE
    if (self == [NSBundle mainBundle])
        WCPLog(@"bundleIdentifier | MAIN orig=%@ (passthrough, WCR-aligned) #%ld", orig, gWCPCallCount);
#endif
    gWCPInHook = 0;
    return orig;
#endif
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (gWCPInHook) return %orig;
    if (self == [NSBundle mainBundle] && [key isEqualToString:@"CFBundleIdentifier"]) {
        gWCPInHook = 1;
        id orig = %orig;
#if LOG_VERBOSE
        WCPLog(@"objectForInfoDictionaryKey | key=CFBundleIdentifier orig=%@ (passthrough) #%ld", orig, gWCPCallCount);
#endif
        gWCPInHook = 0;
        return orig;
    }
    return %orig;
}

%end

// ============================ 网络层伪装（对齐 WCR：登录/风控）============================
#if HOOK_NETWORK_SPOOF

#if HOOK_NSURL_REQUEST
%hook NSURL

+ (NSURL *)URLWithString:(NSString *)URLString {
    @try {
        if (gWCPInHook) return %orig;
        if (gWCPNetOff) return %orig;            // 运行时降级：网络层关，纯透传
        if (!URLString) return %orig;            // 入口判空：nil 直接透传
        gWCPInHook = 1;
        NSString *repl = WCPReplaceBid(URLString);
        NSURL *u;
        if (repl) {
            u = %orig(repl);   // repl 已不含真实 bid，不会再次进入替换分支
            WCPLog(@"NSURL | spoof %@ -> %@", URLString, repl);
        } else {
            u = %orig;
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
        if (gWCPNetOff) return %orig;            // 运行时降级：网络层关，纯透传
        if (!request) return %orig;
        gWCPInHook = 1;

        NSURL *origURL = request.URL;
        NSString *abs = origURL.absoluteString;
        NSString *newAbs = WCPReplaceBid(abs);

        NSURLSessionDataTask *t;
        if (newAbs) {
            NSMutableURLRequest *mreq = [request mutableCopy];
            mreq.URL = [NSURL URLWithString:newAbs];   // 触发 NSURL hook（已 guard）
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

// ============================ 刷脸层：NSString 级伪装（仅刷脸窗口内）============================
#if HOOK_FACE_SPOOF
static BOOL gWCPFaceActive = NO;

%group WCPFace

%hook FaceRecogFlashHandler
- (void)initPipeline {
    gWCPFaceActive = YES;   // 在 %orig 之前置位，保证刷脸全程窗口已开
    WCPLog(@"face: initPipeline -> gWCPFaceActive=YES");
    %orig;
}
- (void)dealloc {
    gWCPFaceActive = NO;    // 在 %orig 之前清零，刷脸结束立即关窗
    WCPLog(@"face: dealloc -> gWCPFaceActive=NO");
    %orig;
}
%end

%hook NSString
// 刷脸 SDK 通常经 NSString 类方法构造 bid 字符串。门控：self==[NSString class] 且处于刷脸窗口。
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString {
    @try {
        if (!(gWCPFaceActive && self == [NSString class] && !gWCPInHook)) return %orig;
        gWCPInHook = 1;
        NSString *orig = %orig;
        NSString *repl = WCPReplaceBid(orig);
        if (repl) WCPLog(@"NSString|face utf8 spoof %@ -> %@", orig, repl);
        gWCPInHook = 0;
        return repl ?: orig;
    }
    @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSString.stringWithUTF8String", [[e name] UTF8String]);
        return %orig;
    }
}
+ (instancetype)stringWithCString:(const char *)cString encoding:(NSStringEncoding)enc {
    @try {
        if (!(gWCPFaceActive && self == [NSString class] && !gWCPInHook)) return %orig;
        gWCPInHook = 1;
        NSString *orig = %orig;
        NSString *repl = WCPReplaceBid(orig);
        if (repl) WCPLog(@"NSString|face cstr spoof %@ -> %@", orig, repl);
        gWCPInHook = 0;
        return repl ?: orig;
    }
    @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSString.stringWithCString:encoding:", [[e name] UTF8String]);
        return %orig;
    }
}
+ (instancetype)stringWithFormat:(NSString *)format, ... {
    @try {
        if (!(gWCPFaceActive && self == [NSString class] && !gWCPInHook)) return %orig;
        gWCPInHook = 1;
        va_list ap; va_start(ap, format);
        NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
        va_end(ap);
        NSString *repl = WCPReplaceBid(s);
        if (repl) WCPLog(@"NSString|face fmt spoof -> %@", repl);
        gWCPInHook = 0;
        return repl ?: s;
    }
    @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSString.stringWithFormat:", [[e name] UTF8String]);
        return %orig;
    }
}
%end

%end // WCPFace
#endif // HOOK_FACE_SPOOF

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

        // 运行时降级开关（app 沙盒 Documents 下的空文件）
        gWCPNetOff  = WCPSwitchOff(@"wcp_disable_net");
        gWCPFaceOff = WCPSwitchOff(@"wcp_disable_face");

        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ realBid=%@ NETSPOOF=%d URL=%d SESS=%d BODY=%d FACE=%d netOff=%d faceOff=%d ===",
               WCP_VERSION, getuid(), exe, gWCPRealBid,
               HOOK_NETWORK_SPOOF, HOOK_NSURL_REQUEST, HOOK_NSURLSESSION, HOOK_NSURLSESSION_BODY,
               HOOK_FACE_SPOOF, gWCPNetOff, gWCPFaceOff);

        if (exe && [exe containsString:@"WeChat"]) {
            // NSBundle 透传始终装（与 v1.0.6 一样安全，无副作用）；网络层 hook 也装，
            // 但 netOff 时其内部直接 %orig 透传。face 层按开关决定。
            %init(WCPBidSpoof);
            if (HOOK_FACE_SPOOF && !gWCPFaceOff) {
                %init(WCPFace);
                WCPLog(@"init: hooks installed (net=%d face=%d, WCR-aligned)", (HOOK_NETWORK_SPOOF && !gWCPNetOff), YES);
            } else {
                WCPLog(@"init: hooks installed (net=%d face=OFF, WCR-aligned)", (HOOK_NETWORK_SPOOF && !gWCPNetOff));
            }
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

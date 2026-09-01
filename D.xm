//============================================================================
//  WCPBidSpoof — 微信多开 bid 处理（单文件 Logos tweak）v3.0
//----------------------------------------------------------------------------
//  策略：对齐商业插件 WCRefine (WCR) / WCPulse (WCP) 的【已验证】bid 伪装机制，
//        分两层处理，互不干扰：
//
//  ┌───────────────┬──────────────────────────────────────────────────────────┐
//  │ 场景          │ 伪装位置（对齐商业插件）                                    │
//  ├───────────────┼──────────────────────────────────────────────────────────┤
//  │ ① 登录/风控   │ 【网络层】NSURL / NSURLSession —— 把发出去的请求 URL/body │
//  │               │   里的真实 bid 替换成 com.tencent.xin。本地 bundleIdentifier│
//  │               │   保持真实（保 APNs topic + UI 资源）。                    │
//  │               │   WCR 铁证：NSURL URLWithString: IMP=0x3a6fa8、            │
//  │               │   NSURLSession dataTaskWithRequest: IMP=0x72e77c，        │
//  │               │   修改函数 0x734d40 引用 URL/absoluteString/HTTPBody。     │
//  ├───────────────┼──────────────────────────────────────────────────────────┤
//  │ ② 人脸核身    │ 【NSString 层】刷脸 SDK 把 bid 当 NSString 流转，         │
//  │               │   self == [NSString class] 语境（即“self == NSString”），  │
//  │               │   仅在【刷脸窗口】内才替换。窗口由                         │
//  │               │   FaceRecogFlashHandler -initPipeline 置位、              │
//  │               │   -dealloc 清零（WCR hooks_inventory.txt:                 │
//  │               │   FaceRecogFlashHandler initPipeline IMP=0x1582820）。     │
//  │               │   → 平时绝不碰 NSString，刷脸时才改写 bid 字符串。         │
//  └───────────────┴──────────────────────────────────────────────────────────┘
//
//  【本地 bundleIdentifier / objectForInfoDictionaryKey:】
//    始终返回【真实 id】(透传 %orig)，仅记日志。这是 WCR 的做法：
//    本地订阅/UI/APNs topic 全部基于真实 bid，无任何副作用。
//
//  【刷脸 NSString 伪装为什么用 self == [NSString class] 门控】
//    商业插件的 gencode 模板是“if (self == NSString) 才吐 com.tencent.xin”，
//    在 bundleIdentifier 里 self 是 NSBundle → 永假 → 死代码（故本地不伪装）；
//    但在刷脸路径里 bid 是以 NSString 类方法（stringWithUTF8String:/stringWithFormat:…）
//    构造的，self 正是 [NSString class] → 门控成活。我们用 gWCPFaceActive
//    （initPipeline 置 1 / dealloc 置 0）保证只在刷脸窗口内开启该门控。
//
//  【日志】写到 app 文件沙盒 Documents（NSSearchPathForDirectoriesInDomains），
//    文件名 wcpbidspoof.log；打不开走 NSLog 兜底（syslog 搜 [WCPBidSpoof]）。
//
//  【如何验证】
//    * 登录：日志应出现 NSURL | spoof / NSURLSession | spoof（服务端收到官方 bid）
//    * 刷脸：日志应成对出现 face: initPipeline -> gWCPFaceActive=YES /
//            face: dealloc -> gWCPFaceActive=NO，中间夹 NSString|face ... spoof
//    * 推送/UI：本地仍是真实 bid，应正常。
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION                "3.0.0"
#define HOOK_BUNDLE_IDENTIFIER    1   // bundleIdentifier 返回真实 id（透传，打日志）
#define HOOK_NETWORK_SPOOF        1   // 网络层 bid 伪装（对齐 WCR：登录/风控所需）
#define HOOK_NSURL_REQUEST        1   // NSURL URLWithString: 替换
#define HOOK_NSURLSESSION         1   // NSURLSession dataTaskWithRequest: 替换 URL
#define HOOK_NSURLSESSION_BODY    0   // ⚠️ HTTPBody 替换（默认关：body 多为 protobuf 二进制，
                                      //    字符串替换有破坏风险；如 URL 层不够可谨慎开启）
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
static NSString    *gWCPRealBid = nil;          // 真实 bundle id（%ctor 读取）
static NSString    *gWCPTargetBid = @"com.tencent.xin";

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
    if (gWCPInHook) return %orig;
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

%end
#endif // HOOK_NSURL_REQUEST

#if HOOK_NSURLSESSION
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (gWCPInHook) return %orig;
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
            // 仅在 body 是 UTF-8 文本且含真实 bid 时才替换；否则原样保留，避免破坏 protobuf
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

%end
#endif // HOOK_NSURLSESSION

#endif // HOOK_NETWORK_SPOOF

%end // WCPBidSpoof

// ============================ 刷脸层：NSString 级伪装（仅刷脸窗口内）============================
// 商业插件（WCR/WCP）的刷脸伪装：在 FaceRecogFlashHandler 生命周期内（initPipeline→dealloc）
// 把流转中的 bid 字符串（self == NSString 语境）替换成 com.tencent.xin。
// 证据：WCR hooks_inventory.txt FaceRecogFlashHandler initPipeline IMP=0x1582820(&orig 0x2203460)；
//       WCP 深度报告 §6 同样 hook initPipeline（IMP 0xa4020），刷脸窗口内才置位门控。
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
// 刷脸 SDK 通常经 NSString 类方法构造 bid 字符串（如 stringWithUTF8String:/stringWithFormat:）。
// 门控：self == [NSString class]（类方法语境，即“self == NSString”）且处于刷脸窗口。
+ (instancetype)stringWithUTF8String:(const char *)nullTerminatedCString {
    if (gWCPFaceActive && self == [NSString class] && !gWCPInHook) {
        gWCPInHook = 1;
        NSString *orig = %orig;
        NSString *repl = WCPReplaceBid(orig);
        if (repl) WCPLog(@"NSString|face utf8 spoof %@ -> %@", orig, repl);
        gWCPInHook = 0;
        return repl ?: orig;
    }
    return %orig;
}
+ (instancetype)stringWithCString:(const char *)cString encoding:(NSStringEncoding)enc {
    if (gWCPFaceActive && self == [NSString class] && !gWCPInHook) {
        gWCPInHook = 1;
        NSString *orig = %orig;
        NSString *repl = WCPReplaceBid(orig);
        if (repl) WCPLog(@"NSString|face cstr spoof %@ -> %@", orig, repl);
        gWCPInHook = 0;
        return repl ?: orig;
    }
    return %orig;
}
+ (instancetype)stringWithFormat:(NSString *)format, ... {
    if (gWCPFaceActive && self == [NSString class] && !gWCPInHook) {
        gWCPInHook = 1;
        va_list ap; va_start(ap, format);
        NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
        va_end(ap);
        NSString *repl = WCPReplaceBid(s);
        if (repl) WCPLog(@"NSString|face fmt spoof -> %@", repl);
        gWCPInHook = 0;
        return repl ?: s;
    }
    return %orig;
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
        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ realBid=%@ NETSPOOF=%d URL=%d SESS=%d BODY=%d FACE=%d ===",
               WCP_VERSION, getuid(), exe, gWCPRealBid,
               HOOK_NETWORK_SPOOF, HOOK_NSURL_REQUEST, HOOK_NSURLSESSION, HOOK_NSURLSESSION_BODY,
               HOOK_FACE_SPOOF);

        if (exe && [exe containsString:@"WeChat"]) {
            %init(WCPBidSpoof);
#if HOOK_FACE_SPOOF
            %init(WCPFace);
#endif
            WCPLog(@"init: hooks installed (network-layer login spoof + NSString face spoof, WCR-aligned)");
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

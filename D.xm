//============================================================================
//  WCPBidSpoof — 微信多开 bid 处理（单文件 Logos tweak）v4.0
//----------------------------------------------------------------------------
//  本版改为「WCP 式」——已用 capstone 反汇编 WCPulse 正式版 dylib 坐实：
//    · bundleIdentifier (imp 0x64712c) 与 objectForInfoDictionaryKey: (imp 0x649b7c)
//      都是 OLLVM 扁平化 + 算术混淆，但门控结构一致：读 0xa2211c（解密锁/防重入，
//      【不是功能开关】）→ cbnz 直接跳回吐 @"com.tencent.xin" 的分支。
//      => WCP 对两条读取路径【无条件】本地 spoof 成官方 id。
//    · WCP 全量 304 条 hook 里【没有】任何 NSURL/dataTask 网络层 hook——
//      它靠「源头改 id」让微信自己用官方 id 拼出请求，自然过登录，无需碰网络层。
//    · WCP 有推送：APNs 按代码签名的 bundle id 路由 device token，根本不读运行时
//      bundleIdentifier 返回值；我们全量扫描确认 WCP 三个推送处理器函数体内
//      【零处】引用 com.tencent.xin(0x9eb000)/bundleIdentifier(0x997000) 页
//      => 推送处理器与 spoof 无关，是 WCP 其它功能。
//
//  为什么「本地双路径无条件 spoof」比 WCR 网络层式更稳（反汇编证据支撑）：
//    ① 登录态二次校验很可能走 objectForInfoDictionaryKey:CFBundleIdentifier 这条
//       本地路径（不经 bundleIdentifier 方法）——WCP 堵两条路，故「划后台重开」不踢；
//       只 spoof bundleIdentifier 的版本会出现「首次能登、重开被踢」。
//    ② APNs 投递与运行时 bundle id 正交，本地全改不坏推送（WCP 实证）。
//    ③ 无全局 NSString hook（WCP 也不 hook）——启动不崩（v3.0/v3.1 闪退根因已根除）。
//
//  v4.0 架构（对齐 WCP，网络层作兜底）：
//    ① 本地双路径：bundleIdentifier          -> 无条件 com.tencent.xin
//                  objectForInfoDictionaryKey:CFBundleIdentifier -> 无条件 com.tencent.xin
//                  （其余 key / 其它 Bundle 透传，不影响 Info.plist 其它读取）
//    ② 网络层兜底：NSURL.URLWithString: / NSURLSession.dataTaskWithRequest:
//       仍把请求 URL 里真实 bid 替换成官方 id（覆盖微信用网络请求携带 bid 的场景）
//    ③ 刷脸窗口（initPipeline/dealloc）：仅作可观测日志，本地 spoof 已无条件覆盖刷脸
//
//  运行时开关（app 沙盒 Documents，与日志同目录，无需越狱文件管理器）：
//    wcp_disable_local → 关本地双路径 spoof（= 纯网络层模式 / 基线，便于二分定位）
//    wcp_disable_net   → 关网络层兜底（= 纯本地 spoof 模式）
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION                "4.0.0"
#define HOOK_BUNDLE_IDENTIFIER    1   // bundleIdentifier：无条件回吐 com.tencent.xin（WCP 式）
#define HOOK_OBJECT_KEY            1   // objectForInfoDictionaryKey:CFBundleIdentifier：无条件回吐 com.tencent.xin（WCP 式双路径）
#define HOOK_NETWORK_SPOOF        1   // 网络层 bid 伪装（WCP 无此层；作为兜底保留）
#define HOOK_NSURL_REQUEST        1   // NSURL URLWithString: 替换
#define HOOK_NSURLSESSION         1   // NSURLSession dataTaskWithRequest: 替换 URL
#define HOOK_NSURLSESSION_BODY    0   // HTTPBody 替换（默认关：微信 body 多为 protobuf 二进制，字符串替换可能破坏 wire 长度；若仅本地+URL 级替换登录仍不过，置 1 开启——二进制 body 转 NSString 失败会自动跳过）
#define HOOK_FACE_SPOOF           1   // 刷脸窗口（initPipeline/dealloc）：仅日志可观测，不影响 spoof
#define ENABLE_LOGGING            1
#define LOG_VERBOSE               1   // 1=详细；0=仅替换/异常。bundleIdentifier 调用极多，已做抽样日志避免刷屏
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
static BOOL         gWCPFaceActive = NO;         // 刷脸窗口标志（仅日志可观测，对齐 WCR 0x2203560）
static BOOL         gWCPNetOff  = NO;            // 运行时降级：网络层关（wcp_disable_net 存在）
static BOOL         gWCPLocalOff = NO;           // 运行时降级：本地 spoof 关（wcp_disable_local 存在）

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
//   wcp_disable_local -> 关本地双路径 spoof（= 纯网络层模式 / 基线）
//   wcp_disable_net   -> 关网络层兜底（= 纯本地 spoof 模式）
static BOOL WCPSwitchOff(NSString *name) {
    if (!gWCPLogPath[0]) return NO;
    NSString *dir = [[NSString stringWithUTF8String:gWCPLogPath]
                     stringByDeletingLastPathComponent];
    NSString *p = [dir stringByAppendingPathComponent:name];
    return [[NSFileManager defaultManager] fileExistsAtPath:p];
}

%group WCPBidSpoof

// ============================ 本地双路径无条件 spoof（对齐 WCP 0x64712c / 0x649b7c）============================
%hook NSBundle

- (NSString *)bundleIdentifier {
#if !HOOK_BUNDLE_IDENTIFIER
    return %orig;
#else
    if (gWCPInHook) return %orig;
    @try {
        gWCPInHook = 1;
        gWCPCallCount++;
        if (!gWCPLocalOff) {
            // WCP 式：无条件本地 spoof。抽样日志，避免启动期海量调用刷屏。
            if (LOG_VERBOSE && (gWCPCallCount % 200 == 0 || gWCPFaceActive)) {
                WCPLog(@"bundleIdentifier | LOCAL SPOOF -> com.tencent.xin (real=%@) #%ld", gWCPRealBid, gWCPCallCount);
            }
            gWCPInHook = 0;
            return gWCPTargetBid;
        }
        NSString *orig = %orig;
        gWCPInHook = 0;
        return orig;
    } @catch (NSException *e) {
        gWCPInHook = 0;
        WCPLogCatch("NSBundle.bundleIdentifier", [[e name] UTF8String]);
        return %orig;
    }
#endif
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
#if !HOOK_OBJECT_KEY
    return %orig;
#else
    if (gWCPInHook) return %orig;
    if (!gWCPLocalOff && [key isEqualToString:@"CFBundleIdentifier"]) {
        @try {
            gWCPInHook = 1;
            id orig = %orig;
            gWCPInHook = 0;
            WCPLog(@"objectForInfoDictionaryKey | LOCAL SPOOF key=CFBundleIdentifier -> com.tencent.xin (orig=%@)", orig);
            return gWCPTargetBid;
        } @catch (NSException *e) {
            gWCPInHook = 0;
            WCPLogCatch("NSBundle.objectForInfoDictionaryKey", [[e name] UTF8String]);
            return %orig(key);
        }
    }
    return %orig;
#endif
}

%end

// ============================ 网络层兜底（WCP 无此层；作为补充保留）============================
#if HOOK_NETWORK_SPOOF

#if HOOK_NSURL_REQUEST
// 补充层：覆盖微信内部 [NSURL URLWithString:] 构造的含 bid 的 URL
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

// ============================ 刷脸窗口：initPipeline/dealloc（仅日志可观测，不影响 spoof）============================
// WCP 式本地 spoof 已无条件覆盖刷脸（刷脸核身读 bundleIdentifier，已被无条件 spoof）。
// 此层仅 hook initPipeline/dealloc 记录刷脸起止，便于确认刷脸路径；绝不 hook NSString 方法。
#if HOOK_FACE_SPOOF
%group WCPFace

%hook FaceRecogFlashHandler
- (void)initPipeline {
    gWCPFaceActive = YES;   // 刷脸开始（仅日志标记）
    WCPLog(@"face: initPipeline -> gWCPFaceActive=YES (local spoof already covers it)");
    %orig;
}
- (void)dealloc {
    gWCPFaceActive = NO;    // 刷脸结束
    WCPLog(@"face: dealloc -> gWCPFaceActive=NO");
    %orig;
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

        // 运行时开关（app 沙盒 Documents 下的空文件，与日志同目录）
        gWCPNetOff   = WCPSwitchOff(@"wcp_disable_net");
        gWCPLocalOff = WCPSwitchOff(@"wcp_disable_local");

        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ realBid=%@ LOCAL=%d(off=%d) NET=%d(off=%d) ===",
               WCP_VERSION, getuid(), exe, gWCPRealBid,
               HOOK_BUNDLE_IDENTIFIER, gWCPLocalOff, HOOK_NETWORK_SPOOF, gWCPNetOff);

        if (exe && [exe containsString:@"WeChat"]) {
            %init(WCPBidSpoof);   // 本地双路径 spoof + 网络层兜底（netOff 时内部透传）
            if (HOOK_FACE_SPOOF) {
                %init(WCPFace);   // 仅 initPipeline/dealloc 日志，绝不 hook NSString
            }
            WCPLog(@"init: hooks installed (WCP-style: local double-path spoof ON=%d, net fallback=%d)",
                   !gWCPLocalOff, (HOOK_NETWORK_SPOOF && !gWCPNetOff));
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

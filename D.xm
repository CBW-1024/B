#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>

// 微信官方 bundle id，多开时伪装成它
#define WC_OFFICIAL_BID @"com.tencent.xin"

// 诊断日志：同时写微信沙盒 Documents/NC_bid.log 与 NSLog
static dispatch_queue_t g_ncLogQueue;
static FILE *g_ncLogFile;

static void nc_log_init(void) {
    if (g_ncLogQueue && g_ncLogFile) return;
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = paths.firstObject;
    NSString *path = [dir stringByAppendingPathComponent:@"NC_bid.log"];
    if (!g_ncLogQueue) {
        g_ncLogQueue = dispatch_queue_create("nc.bid.log", DISPATCH_QUEUE_SERIAL);
    }
    if (!g_ncLogFile) {
        g_ncLogFile = fopen(path.UTF8String, "a");
    }
    NSLog(@"[NC] log file: %@", path);
}

static void nc_log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@ [NC] %@", [NSDate date], msg];
    nc_log_init();   // 必须在 dispatch_async 之前同步初始化，避免 dispatch 到 NULL 队列崩溃
    dispatch_queue_t q = g_ncLogQueue;
    if (q && g_ncLogFile) {
        dispatch_async(q, ^{
            fprintf(g_ncLogFile, "%s\n", line.UTF8String);
            fflush(g_ncLogFile);
        });
    }
    NSLog(@"[NC] %@", msg);
}

// 伪装总开关。启动/launch 阶段保持 OFF（微信按 bid 派生沙盒路径/keychain，
// 过早伪装会打不开数据容器而闪退）；登录开始时开启，登录结束后关闭。
static BOOL g_wcBidEnabled = NO;

#pragma mark - 调用栈判定

// 判断发起 bundleIdentifier 调用的代码是否位于主程序包目录内
static BOOL wc_callerInMainBundle(void) {
    NSArray<NSNumber *> *addrs = [NSThread callStackReturnAddresses];
    if (addrs.count <= 2) {
        nc_log(@"callerInMainBundle: stack too shallow -> NO");
        return NO;
    }
    uintptr_t pc = addrs[2].unsignedLongLongValue;
    Dl_info info;
    if (dladdr((void *)pc, &info) == 0 || info.dli_fname == NULL) {
        nc_log(@"callerInMainBundle: dladdr failed -> NO");
        return NO;
    }
    NSString *callerImage = [NSString stringWithUTF8String:info.dli_fname];
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    // 统一归一化 /private 前缀：dladdr 路径可能带 /private，bundlePath 不带
    NSString *callerNorm = [callerImage hasPrefix:@"/private"] ? [callerImage substringFromIndex:8] : callerImage;
    NSString *bundleNorm = [bundlePath hasPrefix:@"/private"] ? [bundlePath substringFromIndex:8] : bundlePath;
    BOOL hit = [callerNorm hasPrefix:bundleNorm];
    nc_log(@"callerInMainBundle: caller=%@ bundle=%@ hit=%d", callerImage, bundlePath, hit);
    return hit;
}

#pragma mark - bundleIdentifier 伪装

// 仅对主包、且调用者在主程序包内时伪装成官方 bid；其余一律返回真实 bid（保住推送）
%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *real = %orig;

    // 官方包直接原样返回
    if ([real isEqualToString:WC_OFFICIAL_BID]) {
        return real;
    }
    // 开关未开 → 真实 bid
    if (!g_wcBidEnabled) {
        nc_log(@"bundleIdentifier: real=%@ switch=OFF -> return real", real);
        return real;
    }
    // 非主包 → 真实 bid
    if (self != [NSBundle mainBundle]) {
        nc_log(@"bundleIdentifier: real=%@ not mainBundle -> return real", real);
        return real;
    }
    // 调用者位于主程序包内（登录/鉴权多在此）→ 伪装成官方 bid
    if (wc_callerInMainBundle()) {
        nc_log(@"bundleIdentifier: real=%@ -> spoof to %@", real, WC_OFFICIAL_BID);
        return WC_OFFICIAL_BID;
    }
    // 其余（推送注册等浅栈路径）→ 真实 bid，保住 APNs
    nc_log(@"bundleIdentifier: real=%@ caller not in main bundle -> return real", real);
    return real;
}

%end

#pragma mark - 伪装开关生命周期

// 用 FaceRecogFlashHandler 的初始化/销毁驱动伪装开关
%hook FaceRecogFlashHandler

- (void)initPipeline {
    nc_log(@"FaceRecogFlashHandler initPipeline -> switch=YES");
    g_wcBidEnabled = YES;
    %orig;
}

- (void)dealloc {
    nc_log(@"FaceRecogFlashHandler dealloc -> switch=NO");
    g_wcBidEnabled = NO;
    %orig;
}

%end

#pragma mark - 登录流程触发：登录期间开启 bid 伪装

// WCR 同样 hook 了 WCAccountLoginControlLogic。登录校验早于 FaceRecog 初始化，
// 故用登录控制逻辑本身开启/关闭伪装开关，把窗口限制在登录流程内，launch 阶段不受影响。
%hook WCAccountLoginControlLogic

- (void)startLogic {
    nc_log(@"startLogic -> switch=YES");
    g_wcBidEnabled = YES;
    %orig;
}

- (void)startIPadLoginLogic {
    nc_log(@"startIPadLoginLogic -> switch=YES");
    g_wcBidEnabled = YES;
    %orig;
}

- (void)stopLogic {
    nc_log(@"stopLogic -> switch=NO");
    g_wcBidEnabled = NO;
    %orig;
}

%end

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        %init;
    }
}

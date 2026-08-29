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
    if (g_ncLogFile) return;
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = paths.firstObject;
    NSString *path = [dir stringByAppendingPathComponent:@"NC_bid.log"];
    g_ncLogFile = fopen(path.UTF8String, "a");
    g_ncLogQueue = dispatch_queue_create("nc.bid.log", DISPATCH_QUEUE_SERIAL);
    NSLog(@"[NC] log file: %@", path);
}

static void nc_log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@ [NC] %@", [NSDate date], msg];
    dispatch_async(g_ncLogQueue, ^{
        nc_log_init();
        if (g_ncLogFile) {
            fprintf(g_ncLogFile, "%s\n", line.UTF8String);
            fflush(g_ncLogFile);
        }
    });
    NSLog(@"[NC] %@", msg);
}

// 伪装总开关。WCR 在 initPipeline 时置 1、dealloc 时置 0；但登录弹窗发生在
// FaceRecog 初始化之前，故默认开启，靠 callerInMainBundle 过滤推送等浅栈调用。
static BOOL g_wcBidEnabled = YES;

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

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        %init;
    }
}

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

// 微信官方 bundle id，多开时伪装成它
#define WC_OFFICIAL_BID @"com.tencent.xin"

// 诊断日志：同步写微信沙盒 Documents/NC_bid.log（同时 NSLog）。
// 注意：必须同步、绝不用 dispatch_async —— 早期 +initialize 阶段传 NULL 队列会直接崩。
static FILE *g_ncLogFile = NULL;
static BOOL g_ncLogTried = NO;

static void nc_log_open(void) {
    if (g_ncLogTried) return;   // 只尝试一次，避免重复 fopen
    g_ncLogTried = YES;
    @autoreleasepool {
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = [paths.firstObject stringByAppendingPathComponent:@"NC_bid.log"];
        g_ncLogFile = fopen(path.UTF8String, "a");
        NSLog(@"[NC] log file: %@", path);
    }
}

static void nc_log(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"%@ [NC] %@", [NSDate date], msg];
    NSLog(@"[NC] %@", msg);
    nc_log_open();
    if (g_ncLogFile) {
        fprintf(g_ncLogFile, "%s\n", line.UTF8String);
        fflush(g_ncLogFile);   // 即时落盘，方便随时提出
    }
}

// 伪装开关：launch 阶段保持 OFF（微信按真实 bid 派生沙盒/keychain 等）；
// 完成启动后由 UIApplicationDidFinishLaunching 通知置 ON，之后常开。
// 推送/keychain 等系统框架发起的调用，经 wc_callerInMainBundle 判定为“非主程序镜像”
// → 返回真实 bid，保住 APNs。
static BOOL g_wcBidEnabled = NO;

#pragma mark - 调用栈判定

// 判断发起 bundleIdentifier 调用的代码是否位于主程序包目录内（对齐 WCR 0x159556c 的 hasPrefix:bundlePath）
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
    nc_log(@"callerInMainBundle: caller=%@ hit=%d", callerImage, hit);
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
    // 启动阶段（launch 未结束）→ 真实 bid
    if (!g_wcBidEnabled) {
        return real;
    }
    // 非主包 → 真实 bid
    if (self != [NSBundle mainBundle]) {
        return real;
    }
    // 调用者位于主程序包内（登录/鉴权多在此）→ 伪装成官方 bid
    if (wc_callerInMainBundle()) {
        nc_log(@"bundleIdentifier: real=%@ -> spoof to %@", real, WC_OFFICIAL_BID);
        return WC_OFFICIAL_BID;
    }
    // 框架发起的调用（推送注册/keychain 等）→ 真实 bid，保住 APNs
    return real;
}

%end

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        %init;
        // 用 UIApplication 启动完成通知开启伪装开关：版本无关、稳定，不依赖猜测微信内部登录类。
        // WCR 用 FaceRecogFlashHandler initPipeline/dealloc 驱动同一开关；本机 8.0.75 该类/方法
        // 未命中日志（从未触发），故改用启动通知，语义等价：launch 阶段 OFF，之后常开。
        // 冷启动/划后台重开都是全新进程，DidFinishLaunching 必触发 → 重登也能正常伪装。
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidFinishLaunchingNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        g_wcBidEnabled = YES;
                        nc_log(@"UIApplicationDidFinishLaunching -> switch=YES");
                    }];
    }
}

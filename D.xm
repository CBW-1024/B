#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

// 微信官方 bundle id，多开时伪装成它
#define WC_OFFICIAL_BID @"com.tencent.xin"

// 伪装总开关：默认关闭（返回真实 bid），由 FaceRecogFlashHandler 在 initPipeline/dealloc 切换
static BOOL g_wcBidEnabled = NO;

#pragma mark - 调用栈判定

// 判断发起 bundleIdentifier 调用的代码是否位于主程序包目录内
static BOOL wc_callerInMainBundle(void) {
    NSArray<NSNumber *> *addrs = [NSThread callStackReturnAddresses];
    if (addrs.count <= 2) return NO;
    uintptr_t pc = addrs[2].unsignedLongLongValue;
    Dl_info info;
    if (dladdr((void *)pc, &info) == 0 || info.dli_fname == NULL) return NO;
    NSString *callerImage = [NSString stringWithUTF8String:info.dli_fname];
    NSString *bundlePath = [NSBundle mainBundle].bundlePath;
    return [callerImage hasPrefix:bundlePath];
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
        return real;
    }
    // 非主包 → 真实 bid
    if (self != [NSBundle mainBundle]) {
        return real;
    }
    // 调用者位于主程序包内（登录/鉴权多在此）→ 伪装成官方 bid
    if (wc_callerInMainBundle()) {
        return WC_OFFICIAL_BID;
    }
    // 其余（推送注册等浅栈路径）→ 真实 bid，保住 APNs
    return real;
}

%end

#pragma mark - 伪装开关生命周期

// 用 FaceRecogFlashHandler 的初始化/销毁驱动伪装开关：
// 启动期关闭（推送注册拿到真实 bid），运行期开启（登录/鉴权伪装官方 bid）
%hook FaceRecogFlashHandler

- (void)initPipeline {
    g_wcBidEnabled = YES;
    %orig;
}

- (void)dealloc {
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

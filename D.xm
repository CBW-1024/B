/*
 * Tweak.xm —— NSBundle hook 诊断版
 *
 * 说明:
 *   - 伪装判断链保持你原有的逻辑,未做增强
 *   - flag 时间窗(即 WCR 的 initPipeline/dealloc 开关)未实现,日志中会标记为 WINDOW=OFF
 *   - 本版只做:编译修复 / 空指针防护 / 路径缓存 / 日志可观测
 *
 * 日志路径: /var/mobile/Documents/WCRBundleHook.log   (Filza 可直接查看)
 * 开关文件: /var/mobile/Documents/WCRBundleHook.enabled (存在即开启,删除即关闭)
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <pthread.h>
#import <sys/stat.h>

static NSString *const kOfficialBundleID = @"com.tencent.xin";
static NSString *const kLogPath          = @"/var/mobile/Documents/WCRBundleHook.log";
static NSString *const kEnableFlagPath   = @"/var/mobile/Documents/WCRBundleHook.enabled";

// 限流参数:超出后按采样率记录,避免高频调用把进程拖垮
static const NSUInteger kLogFullHead   = 300;   // 前 300 条全量记录
static const NSUInteger kLogMaxLines   = 3000;  // 总条数上限
static const NSUInteger kLogSampleRate = 200;   // 之后每 200 次记 1 条

static pthread_mutex_t  gLogMutex   = PTHREAD_MUTEX_INITIALIZER;
static NSUInteger       gLogSeen    = 0;
static NSUInteger       gLogWritten = 0;
static NSFileHandle    *gLogHandle  = nil;

static void WCRLog(NSString *line) {
    static BOOL inited = NO;
    static BOOL enabled = NO;
    if (!inited) {
        inited = YES;
        enabled = [[NSFileManager defaultManager] fileExistsAtPath:kEnableFlagPath];
        if (enabled) {
            [[NSFileManager defaultManager] createFileAtPath:kLogPath
                                                   contents:nil
                                                 attributes:nil];
            gLogHandle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
            [gLogHandle seekToEndOfFile];
        }
    }
    if (!enabled || !gLogHandle) return;

    NSUInteger seen = __sync_fetch_and_add(&gLogSeen, 1);
    if (seen >= kLogFullHead) {
        if (seen % kLogSampleRate != 0) return;   // 采样降频
    }
    if (gLogWritten >= kLogMaxLines) return;

    NSString *out = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], line];
    NSData *d = [out dataUsingEncoding:NSUTF8StringEncoding];

    pthread_mutex_lock(&gLogMutex);
    @try { [gLogHandle writeData:d]; gLogWritten++; }
    @catch (NSException *e) { /* 写失败不因日志崩进程 */ }
    pthread_mutex_unlock(&gLogMutex);
}

// 主程序 bundlePath 缓存(避免每次重复取)
static NSString *WCRMainPath(void) {
    static NSString *p = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        p = [[NSBundle mainBundle] bundlePath] ?: @"";
    });
    return p;
}

#pragma mark - 私有类前置声明
// 注意:initPipeline 的真实签名请用 class-dump 核对微信头文件后调整
@interface FaceRecogFlashHandler : NSObject
- (void)initPipeline;
@end


#pragma mark - NSBundle hook

%group BundleGroup

%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *origVal = %orig;

    // ① 仅干预主 bundle
    if (self != [NSBundle mainBundle]) {
        WCRLog(@"SKIP not-main-bundle");
        return origVal;
    }

    // ② 原值已是官方 bid,无需处理
    if ([origVal isEqualToString:kOfficialBundleID]) {
        WCRLog(@"SKIP already-official");
        return origVal;
    }

    // ③ 栈回溯取调用者
    NSArray *stack = [NSThread callStackReturnAddresses];
    if (stack.count < 3) {
        WCRLog([NSString stringWithFormat:@"SKIP stack-short depth=%lu orig=%@",
                (unsigned long)stack.count, origVal]);
        return origVal;
    }

    unsigned long long frameAddr =
        [[stack objectAtIndexedSubscript:2] unsignedLongLongValue];

    Dl_info info;
    memset(&info, 0, sizeof(info));
    // ④ dladdr 解析,同时对 dli_fname 显式判空
    if (dladdr((const void *)(uintptr_t)frameAddr, &info) == 0 || !info.dli_fname) {
        WCRLog([NSString stringWithFormat:@"SKIP dladdr-fail addr=0x%llx orig=%@",
                frameAddr, origVal]);
        return origVal;
    }

    NSString *frameName = [NSString stringWithUTF8String:info.dli_fname];
    NSString *mainPath  = WCRMainPath();
    BOOL fromMain = (mainPath.length > 0 && [frameName hasPrefix:mainPath]);

    // WINDOW=OFF 表示当前没有 flag 时间窗门控(全时段生效)
    WCRLog([NSString stringWithFormat:
            @"DECIDE WINDOW=OFF(always-on) orig=%@ caller=%@ mainPath=%@ fromMain=%d -> %@",
            origVal, frameName, mainPath, fromMain,
            fromMain ? kOfficialBundleID : origVal]);

    return fromMain ? kOfficialBundleID : origVal;
}

%end

%end


#pragma mark - 人脸识别处理器(当前为空转透传,仅记录生命周期)

%group FaceRecogGroup

%hook FaceRecogFlashHandler

- (void)initPipeline {
    WCRLog(@"LIFECYCLE FaceRecogFlashHandler initPipeline (no flag set)");
    %orig;
}

%end

%end


#pragma mark - 构造

%ctor {
    @autoreleasepool {
        // 系统类必定存在,直接注册
        %init(BundleGroup);

        // 私有类做存在性探测,缺失时跳过,避免 %orig 打到 nil 崩溃
        if (objc_getClass("FaceRecogFlashHandler")) {
            %init(FaceRecogGroup);
        } else {
            WCRLog(@"WARN FaceRecogFlashHandler not found, group skipped");
        }
    }
}

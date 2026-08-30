/*
 * Tweak.xm —— NSBundle hook 诊断版 v2
 *
 * 相对 v1 的修正:
 *   1. 日志路径改为 App 自身 Documents(沙盒内可写),并同时 NSLog 兜底
 *   2. 开关文件同样移到 App Documents,不再用 /var/mobile/Documents
 *   3. 新增 SPOOF 开关:不存在时「只记录不伪装」,用于隔离 bug 来源
 *   4. 新增调用者判定缓存:同一返回地址只解析一次 dladdr,消除高频开销
 *
 * 日志:    <App>/Documents/WCRBundleHook.log
 * 日志开关: <App>/Documents/WCRBundleHook.enabled   存在=开启日志,删除=完全静默
 * 伪装开关: <App>/Documents/WCRBundleHook.spoof     存在=真正替换返回值,删除=只记日志不改值
 *   <App> = /var/mobile/Containers/Data/Application/<UUID>/
 * 另外所有日志同步 NSLog,可用 macOS 控制台 / idevicesyslog 实时看
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <pthread.h>

static NSString *const kOfficialBundleID = @"com.tencent.xin";

static const NSUInteger kLogFullHead   = 300;
static const NSUInteger kLogMaxLines   = 3000;
static const NSUInteger kLogSampleRate = 200;

static pthread_mutex_t  gLogMutex   = PTHREAD_MUTEX_INITIALIZER;
static NSUInteger       gLogSeen    = 0;
static NSUInteger       gLogWritten = 0;
static NSFileHandle    *gLogHandle  = nil;

static BOOL      gReady   = NO;
static BOOL      gEnabled = NO;
static BOOL      gSpoof   = NO;
static NSString *gLogPath = nil;
static NSString *gDocDir  = nil;

// 调用者判定缓存:返回地址 -> 是否来自主程序镜像
static NSCache *gCallerCache = nil;

#pragma mark - 路径与开关

static NSString *WCRDocDir(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES);
        gDocDir = [dirs firstObject] ?: @"";
    });
    return gDocDir;
}

static void WCRPrepare(void) {
    if (gReady) return;
    gReady = YES;

    NSString *doc = WCRDocDir();
    if (doc.length == 0) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    gLogPath = [doc stringByAppendingPathComponent:@"WCRBundleHook.log"];
    NSString *enableFlag = [doc stringByAppendingPathComponent:@"WCRBundleHook.enabled"];
    NSString *spoofFlag  = [doc stringByAppendingPathComponent:@"WCRBundleHook.spoof"];

    gEnabled = [fm fileExistsAtPath:enableFlag];
    gSpoof   = [fm fileExistsAtPath:spoofFlag];

    if (gEnabled) {
        if (![fm fileExistsAtPath:gLogPath]) {
            [fm createFileAtPath:gLogPath contents:nil attributes:nil];
        }
        gLogHandle = [NSFileHandle fileHandleForWritingAtPath:gLogPath];
        [gLogHandle seekToEndOfFile];
        gCallerCache = [[NSCache alloc] init];
        gCallerCache.countLimit = 2048;
    }
}

static void WCRLog(NSString *line) {
    NSLog(@"[WCRBundleHook] %@", line);        // 实时兜底,不依赖文件是否可写
    if (!gEnabled || !gLogHandle) return;

    NSUInteger seen = __sync_fetch_and_add(&gLogSeen, 1);
    if (seen >= kLogFullHead && (seen % kLogSampleRate) != 0) return;
    if (gLogWritten >= kLogMaxLines) return;

    NSString *out = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], line];
    NSData *d = [out dataUsingEncoding:NSUTF8StringEncoding];
    if (!d) return;

    pthread_mutex_lock(&gLogMutex);
    @try { [gLogHandle writeData:d]; gLogWritten++; }
    @catch (NSException *e) { }
    pthread_mutex_unlock(&gLogMutex);
}

static NSString *WCRMainPath(void) {
    static NSString *p = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ p = [[NSBundle mainBundle] bundlePath] ?: @""; });
    return p;
}

// 带缓存的调用者判定,避免每次 dladdr
static BOOL WCRCallerIsInApp(unsigned long long addr) {
    NSNumber *key = @(addr);
    NSNumber *hit = [gCallerCache objectForKey:key];
    if (hit) return hit.boolValue;

    BOOL result = NO;
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr((const void *)(uintptr_t)addr, &info) != 0 && info.dli_fname) {
        NSString *caller = [NSString stringWithUTF8String:info.dli_fname];
        NSString *mainPath = WCRMainPath();
        result = (mainPath.length > 0 && [caller hasPrefix:mainPath]);
    }
    if (gCallerCache) [gCallerCache setObject:@(result) forKey:key];
    return result;
}

#pragma mark - 私有类声明(请用 class-dump 核对签名)

@interface FaceRecogFlashHandler : NSObject
- (void)initPipeline;
@end


#pragma mark - NSBundle hook

%group BundleGroup

%hook NSBundle

- (NSString *)bundleIdentifier {
    WCRPrepare();
    NSString *origVal = %orig;

    if (!gEnabled) return origVal;                 // 未开日志:零开销直通

    if (self != [NSBundle mainBundle]) return origVal;
    if ([origVal isEqualToString:kOfficialBundleID]) return origVal;

    NSArray *stack = [NSThread callStackReturnAddresses];
    if (stack.count < 3) {
        WCRLog([NSString stringWithFormat:@"SKIP stack-short depth=%lu",
                (unsigned long)stack.count]);
        return origVal;
    }

    unsigned long long frameAddr =
        [[stack objectAtIndexedSubscript:2] unsignedLongLongValue];
    BOOL fromMain = WCRCallerIsInApp(frameAddr);

    // SPOOF=OFF 时只记录、不改返回值,用于确认 bug 是否由伪装本身引起
    NSString *finalVal = (gSpoof && fromMain) ? kOfficialBundleID : origVal;
    WCRLog([NSString stringWithFormat:
            @"DECIDE SPOOF=%@ orig=%@ addr=0x%llx fromMain=%d -> %@",
            gSpoof ? @"ON" : @"OFF", origVal, frameAddr, fromMain, finalVal]);
    return finalVal;
}

%end

%end


#pragma mark - 人脸识别处理器(空转透传)

%group FaceRecogGroup

%hook FaceRecogFlashHandler

- (void)initPipeline {
    WCRLog(@"LIFECYCLE initPipeline (no flag set)");
    %orig;
}

%end

%end


#pragma mark - 构造

%ctor {
    @autoreleasepool {
        %init(BundleGroup);
        if (objc_getClass("FaceRecogFlashHandler")) {
            %init(FaceRecogGroup);
        }
    }
}

// VCAM — 微信相机画面与麦克风声音的虚拟替换（Theos / Logos）
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <dlfcn.h>
#include "fishhook.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>
#include <stdarg.h>

#pragma mark - 开关配置
// 开关配置：全局运行状态。g_isReplace 总开关（无素材时透传真实摄像头，导入后自动开）；g_isLoop 素材播完是否回卷；g_loopStopRound 记录“冻结在哪一轮”用于循环停止判定。
static BOOL g_isReplace      = NO;   // 总开关：无素材时透传真实摄像头，导入后自动开
static BOOL g_isLoop         = YES;  // 素材读完是否回卷重播
static long long g_loopStopRound = -1;
static BOOL g_frozen         = NO;   // 冻结锁存：当前轮播完后锁死，不因开关抖动漏冻
static BOOL g_isSound        = YES;  // 是否替换麦克风采集

// 抑制位（g_videoSuppress = (g_suppressMask != 0) 为真时 = 透传真实画面）：
//   kSuppressPhotoMode = 1<<0 : 进相机/未录制期间（拍照态）真实预览 + 真实成片
//   kSuppressWriting   = 1<<1 : 预留（录制活动标记）
typedef NS_ENUM(NSUInteger, VCamSuppressReason) {
    kSuppressPhotoMode = 1 << 0,   // 拍照模式位：进相机/拍照态时置位，预览与成片均透传真实相机
    kSuppressWriting   = 1 << 1,   // 正在写文件（AVAssetWriter 活动中），预留
};
static NSUInteger g_suppressMask = 0;
static BOOL g_videoSuppress = NO;  // 派生值：g_suppressMask != 0

// 拍照/录像判别不再依赖相机内部控件：当前微信版本下 SightShootingModeSwitchView 在你的相机入口不存在
// （shootingModeSwitchView 恒为 nil，取不到 currentShootingMode），改为事件驱动——进相机即真实、
// 开始录制时切换为素材替换（见下方 MMSightCameraViewController / AVAssetWriter 钩子）。

static void vcm_suppressSet(VCamSuppressReason mask, BOOL on) {
    NSUInteger old = g_suppressMask;
    if (on) g_suppressMask |=  mask;
    else    g_suppressMask &= ~mask;
    if (old != g_suppressMask) g_videoSuppress = (g_suppressMask != 0);
}

static int g_rotation = 0;  // 0/90/180/270，额外旋转微调（方向对齐会自动补 90°）

#pragma mark - reader 重建标记
// reader 重建标记：素材切换或 reader 失效时置位，下次访问重建 AVAssetReader，避免读到旧/空 reader。
static BOOL g_videoReload = NO;
static BOOL g_audioReload = NO;

#pragma mark - 沙箱路径
// 沙箱路径：素材视频目录、临时音频解码路径、当前选中视频路径，均位于 App 沙盒内。
static NSString *g_videoDir       = nil;
static NSString *g_tempAudioPath  = nil;
static NSString *g_videoPath      = nil;

#pragma mark - 运行时状态
// 运行时状态：文件管理器、媒体锁（reader/缓冲并发保护）、CoreImage 上下文（像素合成用）。
static NSFileManager *g_fileManager = nil;
static NSLock        *g_mediaLock   = nil;
static CIContext     *g_ciContext   = nil;

static AVAssetReader            *g_videoReader = nil;
static AVAssetReaderTrackOutput *g_videoOutput = nil;
static AVAssetReader            *g_audioReader = nil;
static AVAssetReaderTrackOutput *g_audioOutput = nil;

static CVPixelBufferRef g_lastVideoPixel = NULL;  // 最近一帧，reader 读完后冻结复用防闪回

#pragma mark - 统一会话时钟（音画同步）
// 统一会话时钟：以显示层首帧时间为锚点，视频与音频都按此时钟定位读取，保证音画同步。
static CFTimeInterval g_clockAnchor = 0;
static BOOL           g_clockReady  = NO;

static double  g_srcFps      = 30.0;  // 素材帧率（time-to-frame 用）
static double  g_srcDuration = 0.0;   // 素材时长，循环回卷用
static int64_t g_srcFrameIdx = -1;    // 素材已推进到的帧号；-1 = 待锚定
static CGSize  g_srcSize     = {0,0}; // 素材原生分辨率

static const long long kVCamMaxCatchUp = 4;  // 一次回调最多补的帧数，防正反馈卡死

#pragma mark - AudioUnit 链路（按时钟定位预解码 PCM）
// AudioUnit 链路：麦克风被替换时，按统一时钟在预解码 PCM 缓冲里定位对应样本喂给上行。
static double g_pcmBytesPerSec  = 0.0;
static size_t g_audioFrameBytes = 1;   // 一个采样帧字节数（帧边界对齐防爆音）

#pragma mark - AVCapture 音频链路（按时钟追平）
// AVCapture 音频链路：把采集端采样率/字节率换算成“按帧追平”参数，使替换音频与时钟对齐。
static double g_captureSampleRate       = 0.0;
static double g_audioCaptureBytesPerSec  = 0.0;
static double g_audioSrcDuration        = 0.0;
static double g_audioConsumedBytes      = 0.0;

static void vcm_resetClock(void) {
    g_clockReady         = NO;
    g_srcFrameIdx        = -1;
    g_audioConsumedBytes = 0.0;
    g_loopStopRound      = -1;
    g_frozen             = NO;
}

// 清掉素材目录下某前缀的所有残留文件（扩展名随导入文件变化）
static void vcm_clearMaterialFiles(NSString *prefix) {
    for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
        if ([old hasPrefix:prefix]) {
            [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
        }
    }
}

static CFTimeInterval vcm_elapsed(void) {
    CFTimeInterval now = CACurrentMediaTime();
    if (!g_clockReady) { g_clockAnchor = now; g_clockReady = YES; }
    return now - g_clockAnchor;
}

#pragma mark - 预览显示层
// 预览显示层：用 AVSampleBufferDisplayLayer + CADisplayLink 把替换画面叠加到相机预览上。
static AVSampleBufferDisplayLayer *g_displayLayer     = nil;
static CADisplayLink              *g_displayLink      = nil;
static AVCaptureVideoOrientation   g_videoOrientation = AVCaptureVideoOrientationPortrait;
static BOOL                        g_sessionRunning   = NO;  // 采集回调/显示层心跳的硬护栏
static BOOL                        g_dbgFirstFrame    = YES; // 诊断：每会话首帧打印一次取流路径

// 诊断日志缓冲区：菜单「导出诊断」按钮可导出，供无 syslog 权限的侧载环境定位问题
static NSMutableArray *g_diagLog = nil;
static const NSUInteger kVCamDiagMaxLines = 2000;
static void vcm_dbg(NSString *fmt, ...) {
    if (!fmt) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (!g_diagLog) g_diagLog = [NSMutableArray array];
    [g_diagLog addObject:[NSString stringWithFormat:@"%@ %@", [NSDate date], msg]];
    if (g_diagLog.count > kVCamDiagMaxLines) [g_diagLog removeObjectAtIndex:0];
    NSLog(@"[VCAM][dbg] %@", msg);
}

#pragma mark - 像素缓冲池
// 像素缓冲池：复用 CVPixelBuffer，避免每帧 new/释放带来的卡顿与内存抖动。
static CVPixelBufferPoolRef g_pbPool = NULL;
static size_t               g_poolW  = 0;
static size_t               g_poolH  = 0;
static OSType               g_poolFmt = 0;

#pragma mark - 音频预解码缓冲（整段预解码进内存 + 按时钟定位读取）
// 音频预解码缓冲：整段素材音频一次解码进内存（g_audioPCM），按统一时钟用游标顺序读取，连续不爆音。
// 视频不整段解码——整段解码内存代价约大千倍，不可行。
static uint8_t       *g_audioPCM      = NULL;
static size_t         g_audioPCMLen   = 0;
static size_t         g_audioPCMRead  = 0;   // 读取游标，顺序推进保证样本连续
static os_unfair_lock g_audioPCMLock  = OS_UNFAIR_LOCK_INIT;
static BOOL           g_audioPCMReady = NO;
static AudioStreamBasicDescription g_audioPCMFormat = {0};
static NSUInteger     g_audioDecodeGen = 0;   // 解码代次：换素材/ASBD 变更时自增，作废在途结果
static BOOL           g_audioFeederRunning = NO;
static BOOL           g_audioFeederStop    = NO;
static int            g_decodeFailCount  = 0;
static NSTimeInterval g_decodeNextRetry  = 0;
static const size_t   kAudioPCMMaxBytes = 64u * 1024u * 1024u;  // 64MB 上限防 OOM

// 作废已解码 PCM：自增代次 + 停解码线程 + 释放缓冲
static void vcm_invalidatePCM(void) {
    g_audioDecodeGen++;
    g_audioFeederStop = YES;
    os_unfair_lock_lock(&g_audioPCMLock);
    if (g_audioPCM) { free(g_audioPCM); g_audioPCM = NULL; }
    g_audioPCMLen   = 0;
    g_audioPCMRead  = 0;
    g_audioPCMReady = NO;
    os_unfair_lock_unlock(&g_audioPCMLock);
}

// 只比较影响字节布局的字段，否则同一格式会被误判成变更 → 反复作废重解码
static BOOL vcm_asbdMatches(AudioStreamBasicDescription a, AudioStreamBasicDescription b) {
    return a.mSampleRate       == b.mSampleRate
        && a.mChannelsPerFrame == b.mChannelsPerFrame
        && a.mBitsPerChannel   == b.mBitsPerChannel
        && (((a.mFormatFlags ^ b.mFormatFlags)
             & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved)) == 0);
}

#pragma mark - AudioUnit 采集状态
// AudioUnit 采集状态：首次回调先探测麦克风真实 ASBD（即解码目标格式），后续按此格式拉 PCM。
static BOOL                        g_hasProbedASBD = NO;
static AudioStreamBasicDescription g_targetASBD    = {0};  // 麦克风真实 ASBD，即解码目标格式

static OSStatus (*g_origAudioUnitRender)(
    AudioUnit                   inUnit,
    AudioUnitRenderActionFlags  *ioActionFlags,
    const AudioTimeStamp       *inTimeStamp,
    UInt32                      inOutputBusNumber,
    UInt32                      inNumberFrames,
    AudioBufferList             *ioData
) = NULL;

#pragma mark - 路径辅助
// 路径辅助：沙盒目录与素材/临时文件绝对路径的取路径小工具。
static NSString *vcm_documentPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}
static NSString *vcm_videoPath(void) { return g_videoPath; }

// 循环关闭后是否该冻结（画面停末帧 + 声音静音）。用整数轮次判定：
// 关闭时记下当前 round，进入下一轮（round 变大）才冻结，避免一点「关」立刻冻结。
static BOOL vcm_loopShouldFreeze(double elapsed) {
    if (g_isLoop) {
        if (g_loopStopRound >= 0 || g_frozen) { g_loopStopRound = -1; g_frozen = NO; }
        return NO;
    }
    if (g_frozen) return YES;
    if (g_srcDuration <= 0.1) { if (!g_frozen) g_frozen = YES; return YES; }
    long long round = (long long)floor(elapsed / g_srcDuration);
    if (g_loopStopRound < 0) { g_loopStopRound = round; return NO; }
    if (round > g_loopStopRound) { g_frozen = YES; return YES; }
    return NO;
}

// 收尾时立即清除写文件位（stopRunning 调用）。拍照/录像的替换切换统一见 AVAssetWriter 钩子。
static void vcm_finishWritingNow(void) {
    vcm_suppressSet(kSuppressWriting, NO);
}

// 拍照/录像判别说明：不再依赖 MMSightCameraViewController.cameraMode（实测恒为 6，非判别信号），
// 也不再依赖 SightShootingModeSwitchView（当前入口下 shootingModeSwitchView 恒为 nil）。
// 改为：进相机即真实预览，开始录制切换为素材替换。

static void vcm_saveSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:g_isReplace   forKey:@"vcam_replace"];
    [d setBool:g_isLoop      forKey:@"vcam_loop"];
    [d setBool:g_isSound     forKey:@"vcam_sound"];
    [d setInteger:g_rotation forKey:@"vcam_rotation"];
    if (g_videoPath) [d setObject:g_videoPath forKey:@"vcam_video_path"];
    else             [d removeObjectForKey:@"vcam_video_path"];
    if (g_tempAudioPath) [d setObject:g_tempAudioPath forKey:@"vcam_audio_path"];
    else                 [d removeObjectForKey:@"vcam_audio_path"];
    [d synchronize];
}

static void vcm_loadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"vcam_replace"])  g_isReplace = [d boolForKey:@"vcam_replace"];
    if ([d objectForKey:@"vcam_loop"])     g_isLoop    = [d boolForKey:@"vcam_loop"];
    if ([d objectForKey:@"vcam_sound"])    g_isSound   = [d boolForKey:@"vcam_sound"];
    if ([d objectForKey:@"vcam_rotation"]) g_rotation  = (int)[d integerForKey:@"vcam_rotation"];
    else                                   g_rotation  = 0;
    // 一次性纠正旧存档：旧版默认 90 与自动判断叠加 → 实际 180°，升级后自动纠正
    if (![d boolForKey:@"vcam_rotation_default_fixed"]) {
        if (g_rotation == 90) g_rotation = 0;
        [d setBool:YES forKey:@"vcam_rotation_default_fixed"];
    }
    NSString *savedVideo = [d stringForKey:@"vcam_video_path"];
    if (savedVideo.length > 0) g_videoPath = [savedVideo copy];
    NSString *savedAudio = [d stringForKey:@"vcam_audio_path"];
    if (savedAudio.length > 0) g_tempAudioPath = [savedAudio copy];
    // 拍照模式判别已改为事件驱动，不再从 vcam_photo_mode 恢复
}

#pragma mark - 停止 reader 与重置
// 停止 reader 与重置：取消并释放视频/音频 AVAssetReader，复位缓冲与时钟，供素材切换或退出时调用。
static void vcm_stopReaders(void) {
    [g_mediaLock lock];
    if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
    if (g_audioReader) { [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil; }
    if (g_lastVideoPixel) { CVPixelBufferRelease(g_lastVideoPixel); g_lastVideoPixel = NULL; }
    [g_mediaLock unlock];
    g_srcFrameIdx = -1;
}

// 换素材/会话重启时让两条链路从头来过；关键是清 g_hasProbedASBD 否则新素材音频进不了麦克风
static void vcm_reloadReaders(void) {
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
    vcm_resetClock();
    g_decodeFailCount = 0;
    g_decodeNextRetry = 0;
    vcm_invalidatePCM();
}

static void vcm_resetSettings(void) {
    g_isReplace   = NO;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_rotation    = 0;

    vcm_stopReaders();
    vcm_reloadReaders();

    vcm_clearMaterialFiles(@"bear_vcam_audio.");
    vcm_clearMaterialFiles(@"bear_vcam_temp.");
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    vcm_saveSettings();
}

#pragma mark - 视图控制器查找
// 视图控制器查找：从 keyWindow 层级里找出当前最上层 UIViewController，用于弹菜单。
static UIViewController *vcm_topViewController(void) {
    UIWindow *key = nil;
    for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) { key = w; break; }
        }
        if (!key) key = scene.windows.firstObject;
        break;
    }
    if (!key) return nil;
    UIViewController *vc = key.rootViewController;
    while (vc) {
        if (vc.presentedViewController) { vc = vc.presentedViewController; continue; }
        if ([vc isKindOfClass:[UINavigationController class]]) { vc = [(UINavigationController *)vc topViewController]; continue; }
        if ([vc isKindOfClass:[UITabBarController class]])     { vc = [(UITabBarController *)vc selectedViewController]; continue; }
        break;
    }
    return vc;
}

// 拍照/录像抑制：进相机即真实预览，开始录制（AVAssetWriter.startWriting）时切换为素材替换，
// 结束录制恢复真实。不再依赖 SightShootingModeSwitchView.currentShootingMode（该控件在当前入口不存在）。
// 具体置位逻辑见下方 MMSightCameraViewController.viewWillAppear 与 AVAssetWriter 钩子。

#pragma mark - 像素缓冲池（替代每帧 CVPixelBufferCreate）
// 像素缓冲池构建：按宽高/格式创建 CVPixelBufferPool，尺寸或格式变化时重建。
static void vcm_createPool(size_t w, size_t h, OSType pfmt) {
    if (g_pbPool) { CVPixelBufferPoolRelease(g_pbPool); g_pbPool = NULL; }
    NSDictionary *attrs = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferWidthKey:  @(w),
        (id)kCVPixelBufferHeightKey: @(h),
        (id)kCVPixelBufferPixelFormatTypeKey: @(pfmt),
        (id)kCVPixelBufferPoolMinimumBufferCountKey: @(8),
    };
    if (CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
                                (__bridge CFDictionaryRef)attrs, &g_pbPool) != kCVReturnSuccess || !g_pbPool) {
        g_pbPool = NULL;
        return;
    }
    g_poolW = w; g_poolH = h; g_poolFmt = pfmt;
}

static CVPixelBufferRef vcm_pooledPixelBuffer(size_t w, size_t h, OSType pfmt) {
    NSDictionary *iosurf = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    if (g_pbPool && (g_poolW != w || g_poolH != h || g_poolFmt != pfmt)) vcm_createPool(w, h, pfmt);
    for (int attempt = 0; attempt < 2; attempt++) {
        if (!g_pbPool) break;
        CVPixelBufferRef pb = NULL;
        if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, g_pbPool, &pb) == kCVReturnSuccess && pb) return pb;
        if (pb) { CVPixelBufferRelease(pb); pb = NULL; }
        vcm_createPool(w, h, pfmt);
    }
    CVPixelBufferRef pb = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, pfmt, (__bridge CFDictionaryRef)iosurf, &pb);
    return pb;
}

#pragma mark - VCamMediaManager
// VCamMediaManager：素材媒体读取中枢，懒初始化视频/音频 AVAssetReader，对外提供按帧/按位置的样本。
@interface VCamMediaManager : NSObject
+ (void)setupVideoReaderIfNeeded;
+ (void)setupAudioReaderIfNeeded;
+ (CVPixelBufferRef)nextSourcePixelAt:(CFTimeInterval)elapsed;
+ (CIImage *)composedImageForTarget:(CGSize)target atTime:(CFTimeInterval)elapsed;
+ (CIImage *)blackImageForTarget:(CGSize)target;
+ (CMSampleBufferRef)makeSampleFromImage:(CIImage *)img
                                   width:(size_t)w height:(size_t)h
                                  format:(OSType)pfmt
                               timingSrc:(CMSampleBufferRef)src;
+ (CMSampleBufferRef)getVideoFrame:(CMSampleBufferRef)origSample;
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample atTime:(CFTimeInterval)elapsed;
+ (void)decodeAudioToMemory;
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length atTime:(CFTimeInterval)elapsed;
+ (void)cleanup;
@end

@implementation VCamMediaManager
+ (void)setupVideoReaderIfNeeded {
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (!g_videoReload && g_videoReader &&
                g_videoReader.status != AVAssetReaderStatusCompleted) return;
            if (!g_isLoop && g_videoReader &&
                g_videoReader.status == AVAssetReaderStatusCompleted) return;

            if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
            NSString *path = vcm_videoPath();
            if (![g_fileManager fileExistsAtPath:path]) return;
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
            g_videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            if (track) {
                double fps = track.nominalFrameRate;
                if (!(fps > 1.0)) fps = 30.0;
                if (fps > 120.0) fps = 120.0;
                g_srcFps = fps;

                CGSize ns = track.naturalSize;
                if (ns.width > 0 && ns.height > 0 && isfinite(ns.width) && isfinite(ns.height))
                    g_srcSize = ns;
                else
                    g_srcSize = CGSizeZero;

                double dur = CMTimeGetSeconds(track.timeRange.duration);
                g_srcDuration = (dur > 0.0 && isfinite(dur)) ? dur : 0.0;

                NSDictionary *settings = @{
                    (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                };
                g_videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                [g_videoReader addOutput:g_videoOutput];
                if ([g_videoReader startReading]) g_srcFrameIdx = -1;  // reader 回素材头，帧索引重锚定
            }
        }
    } @catch (NSException *e) {
    } @finally {
        g_videoReload = NO;
        [g_mediaLock unlock];
    }
}

+ (void)setupAudioReaderIfNeeded {
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (!g_audioReload && g_audioReader &&
                g_audioReader.status != AVAssetReaderStatusCompleted) return;
            if (!g_isLoop && g_audioReader &&
                g_audioReader.status == AVAssetReaderStatusCompleted) return;

            if (g_audioReader) {
                [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil;
            }
            NSString *path = g_tempAudioPath;
            if (![g_fileManager fileExistsAtPath:path]) path = vcm_videoPath();
            if (![g_fileManager fileExistsAtPath:path]) return;
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
            if (track) {
                g_audioReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];

                // 解码输出采样率必须对齐采集端，否则被下游按采集时钟消费 → 音频整体变速
                NSMutableDictionary *settings = [NSMutableDictionary dictionary];
                settings[AVFormatIDKey] = @(kAudioFormatLinearPCM);
                if (g_captureSampleRate > 0) settings[AVSampleRateKey] = @(g_captureSampleRate);

                g_audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                g_audioOutput.alwaysCopiesSampleData = NO;
                [g_audioReader addOutput:g_audioOutput];
                if ([g_audioReader startReading]) {
                    double dur = CMTimeGetSeconds(track.timeRange.duration);
                    g_audioSrcDuration   = (dur > 0.0 && isfinite(dur)) ? dur : 0.0;
                    g_audioConsumedBytes = 0.0;
                }
            }
        }
        if (g_hasProbedASBD) [self decodeAudioToMemory];  // ASBD 探明后触发整段预解码（幂等）
    } @catch (NSException *e) {
    } @finally {
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 整段预解码：一次性把素材音频全部解码成目标格式 PCM 存进内存，消费端按时钟定位读取。
// 触发时机（幂等）：① 首次探测到 ASBD；② 换素材；③ ASBD 变更。
+ (void)decodeAudioToMemory {
    if (!g_hasProbedASBD)     return;
    if (g_audioPCMReady)      return;
    if (g_audioFeederRunning) return;
    if ([[NSDate date] timeIntervalSince1970] < g_decodeNextRetry) return;  // 退避期内不重启
    g_audioFeederStop   = NO;
    g_audioFeederRunning = YES;
    NSUInteger myGen = g_audioDecodeGen;

    // 低优先级后台跑：整段预解码是耗时任务，跑在 HIGH 会跟采集回调抢 CPU 导致掉帧
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @try {
            @autoreleasepool {
                NSString *path = g_tempAudioPath;
                BOOL usedVideoFallback = ![g_fileManager fileExistsAtPath:path];  // 双素材：优先独立声音文件
                if (usedVideoFallback) path = vcm_videoPath();

                int waitRetry = 0;
                while (!g_audioFeederStop && ![g_fileManager fileExistsAtPath:path]) {
                    [NSThread sleepForTimeInterval:0.2];
                    if (++waitRetry > 150) return;  // 30s 超时放弃
                }
                if (g_audioFeederStop || ![g_fileManager fileExistsAtPath:path]) return;

                AudioStreamBasicDescription t = g_targetASBD;
                double rate    = (t.mSampleRate > 0)        ? t.mSampleRate       : 48000.0;
                UInt32 ch      = (t.mChannelsPerFrame > 0)  ? t.mChannelsPerFrame : 1;
                BOOL   isFloat = (t.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
                UInt32 bits    = (t.mBitsPerChannel > 0)    ? t.mBitsPerChannel   : (isFloat ? 32 : 16);
                BOOL   isNonInt= (t.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;

                NSURL *url = [NSURL fileURLWithPath:path];
                AVAsset *asset = [AVAsset assetWithURL:url];
                AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
                AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
                if (!track) return;

                NSDictionary *outSettings = @{
                    AVFormatIDKey: @(kAudioFormatLinearPCM),
                    AVSampleRateKey: @(rate),
                    AVNumberOfChannelsKey: @(ch),
                    AVLinearPCMIsFloatKey: @(isFloat),
                    AVLinearPCMBitDepthKey: @(bits),
                    AVLinearPCMIsBigEndianKey: @NO,
                    AVLinearPCMIsNonInterleavedKey: @(isNonInt),
                };
                AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:outSettings];
                out.alwaysCopiesSampleData = NO;
                [reader addOutput:out];
                if (![reader startReading]) return;

                NSMutableData *acc = [NSMutableData data];
                while (reader.status == AVAssetReaderStatusReading && !g_audioFeederStop) {
                    if (myGen != g_audioDecodeGen) return;  // 代次变更，作废本轮
                    CMSampleBufferRef s = [out copyNextSampleBuffer];
                    if (!s) break;
                    @try {
                        CMBlockBufferRef blk = CMSampleBufferGetDataBuffer(s);
                        if (!blk) continue;
                        size_t len = 0; char *ptr = NULL;
                        if (CMBlockBufferGetDataPointer(blk, 0, NULL, &len, &ptr) != noErr || len == 0) continue;
                        if (acc.length + len > kAudioPCMMaxBytes) { [acc appendBytes:ptr length:len]; break; }
                        [acc appendBytes:ptr length:len];
                    } @finally {
                        CFRelease(s);
                    }
                }

                if (myGen != g_audioDecodeGen) return;
                if (g_audioFeederStop || acc.length == 0) {
                    if (acc.length == 0 && !g_audioFeederStop) {  // 无产出计入退避，避免每帧重启拖垮实时线程
                        g_decodeFailCount++;
                        g_decodeNextRetry = [[NSDate date] timeIntervalSince1970]
                                          + ((0.5 * g_decodeFailCount > 5.0) ? 5.0 : 0.5 * g_decodeFailCount);
                    }
                    return;
                }

                size_t   total = acc.length;
                uint8_t *buf   = (uint8_t *)malloc(total);
                if (!buf) return;
                memcpy(buf, acc.bytes, total);

                size_t frameBytes = (size_t)((bits / 8) * (ch > 0 ? ch : 1));
                if (frameBytes == 0) frameBytes = 1;
                double bytesPerSec = rate * (double)frameBytes;

                os_unfair_lock_lock(&g_audioPCMLock);
                if (g_audioPCM) free(g_audioPCM);
                g_audioPCM       = buf;
                g_audioPCMLen    = total;
                g_audioPCMRead   = 0;
                g_audioPCMReady  = YES;
                g_audioPCMFormat = t;
                g_pcmBytesPerSec  = bytesPerSec;
                g_audioFrameBytes = frameBytes;
                os_unfair_lock_unlock(&g_audioPCMLock);
                g_decodeFailCount = 0;
                g_decodeNextRetry = 0;
            }
        } @catch (NSException *e) {
            g_decodeFailCount++;
            g_decodeNextRetry = [[NSDate date] timeIntervalSince1970]
                              + ((0.5 * g_decodeFailCount > 5.0) ? 5.0 : 0.5 * g_decodeFailCount);
        } @finally {
            g_audioFeederRunning = NO;
        }
    });
}

// 消费者：从预解码 PCM 取 length 字节。以读游标顺序推进为主保证样本连续，
// elapsed 仅用于大偏差（>0.5s）校正，吸收换素材/切采样率等累计误差。只读不写，PCM 恒定。
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length atTime:(CFTimeInterval)elapsed {
    if (!outData || length == 0) return;
    if (length > 0x100000) { memset(outData, 0, length); return; }
    if (!g_audioPCMReady || !g_audioPCM || g_audioPCMLen == 0) { memset(outData, 0, length); return; }
    memset(outData, 0, length);

    os_unfair_lock_lock(&g_audioPCMLock);
    size_t len    = g_audioPCMLen;
    size_t frameB = (g_audioFrameBytes > 0) ? g_audioFrameBytes : 1;

    if (g_pcmBytesPerSec > 0 && len > 0) {
        double want = elapsed * g_pcmBytesPerSec;
        BOOL freeze = vcm_loopShouldFreeze(elapsed);
        want = fmod(want, (double)len);
        if (freeze) {  // 当前轮已播完：保持静音，不要再把游标拉回 0 造成重播怪音
            os_unfair_lock_unlock(&g_audioPCMLock);
            memset(outData, 0, length);
            return;
        }
        if (fabs(want - (double)g_audioPCMRead) > g_pcmBytesPerSec * 0.5) {
            size_t aligned = (size_t)(want / (double)frameB) * frameB;  // 对齐到帧边界防相位翻转
            g_audioPCMRead = (aligned < len) ? aligned : (g_isLoop ? 0 : len);
        }
    }

    if (g_audioPCMRead >= len) {
        if (g_isLoop) g_audioPCMRead = 0;
        else { os_unfair_lock_unlock(&g_audioPCMLock); memset(outData, 0, length); return; }
    }

    size_t written = 0;
    while (written < length) {
        if (g_audioPCMRead >= len) {
            if (!g_isLoop) break;
            g_audioPCMRead = 0;
        }
        size_t avail = len - g_audioPCMRead;
        size_t n = (length - written < avail) ? (length - written) : avail;
        memcpy(outData + written, g_audioPCM + g_audioPCMRead, n);
        g_audioPCMRead += n;
        written += n;
    }
    os_unfair_lock_unlock(&g_audioPCMLock);

    if (written < length) memset(outData + written, 0, length - written);
}

// 探测采集端音频格式：采样率变化必须重建 reader，否则解码与采集时钟不同率 → 变速
static void vcm_probeCaptureAudioFormat(CMSampleBufferRef s) {
    if (!s) return;
    CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(s);
    if (!fmt) return;
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    if (!asbd) return;
    double rate = asbd->mSampleRate;
    if (rate <= 0) return;

    if (fabs(rate - g_captureSampleRate) > 0.5) {
        g_captureSampleRate = rate;
        g_audioReload = YES;
    }
    UInt32 ch   = asbd->mChannelsPerFrame > 0 ? asbd->mChannelsPerFrame : 1;
    UInt32 bits = asbd->mBitsPerChannel   > 0 ? asbd->mBitsPerChannel   : 16;
    g_audioCaptureBytesPerSec = rate * (double)((bits / 8) * ch);
}

// 从音频 reader 取一帧，套用采集帧时序后返回（调用方负责 CFRelease）
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample atTime:(CFTimeInterval)elapsed {
    if (!origSample) return NULL;

    vcm_probeCaptureAudioFormat(origSample);

    double t = elapsed;
    if (g_audioSrcDuration > 0.1) t = fmod(t, g_audioSrcDuration);
    double wantBytes = (g_audioCaptureBytesPerSec > 0) ? (t * g_audioCaptureBytesPerSec) : -1.0;
    if (vcm_loopShouldFreeze(elapsed)) wantBytes = -1.0;

    // 循环回卷：已投递满一整段就重建 reader 回到素材头，与画面侧 fmod 回卷对齐
    if (g_isLoop && g_audioSrcDuration > 0.1 && g_audioCaptureBytesPerSec > 0 &&
        g_audioConsumedBytes >= g_audioSrcDuration * g_audioCaptureBytesPerSec) {
        g_audioReload = YES;
    }
    if (g_audioReload) [self setupAudioReaderIfNeeded];

    CMSampleBufferRef s = NULL;
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (g_audioOutput) {
                int guard = 0;
                while (guard++ < 32) {
                    BOOL caughtUp = (wantBytes > 0.0) && (g_audioConsumedBytes >= wantBytes);
                    if (caughtUp && s) break;
                    CMSampleBufferRef tmp = [g_audioOutput copyNextSampleBuffer];
                    if (!tmp) { g_audioReload = YES; break; }
                    if (s) CFRelease(s);
                    s = tmp;
                    CMBlockBufferRef blk = CMSampleBufferGetDataBuffer(s);
                    if (blk) g_audioConsumedBytes += (double)CMBlockBufferGetDataLength(blk);
                    if (wantBytes <= 0.0) break;
                }
            }
        }
    } @catch (NSException *e) {
    } @finally {
        [g_mediaLock unlock];
    }

    if (!s) { g_audioReload = YES; return NULL; }

    CMSampleBufferRef out = NULL;
    @try {
        // PTS 用采集帧的（与视频同一时钟），duration 用素材自身的（防素材每帧样本数不同导致变速）
        CMTime capTime = kCMTimeInvalid, capDur = kCMTimeInvalid;
        if (origSample) {
            CMSampleTimingInfo cap = kCMTimingInfoInvalid;
            if (CMSampleBufferGetSampleTimingInfo(origSample, 0, &cap) == noErr) {
                capTime = cap.presentationTimeStamp;
                capDur  = cap.duration;
            }
        }
        CMTime srcDur = CMSampleBufferGetDuration(s);

        CMSampleTimingInfo timing;
        timing.duration              = CMTIME_IS_VALID(srcDur) ? srcDur : capDur;
        timing.presentationTimeStamp = CMTIME_IS_VALID(capTime) ? capTime : CMSampleBufferGetPresentationTimeStamp(s);
        timing.decodeTimeStamp       = kCMTimeInvalid;

        CMSampleBufferRef tmp = NULL;
        if (CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, s, 1, &timing, &tmp) == noErr && tmp) {
            out = tmp;
        }
    } @catch (NSException *e) {
        CFRelease(s);
        return NULL;
    }
    if (out) CFRelease(s); else out = s;
    return out;
}

static CVPixelBufferRef vcm_pullVideoFrame(void) {
    CVPixelBufferRef frame = NULL;
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (!g_videoOutput) return NULL;
            CMSampleBufferRef s = [g_videoOutput copyNextSampleBuffer];
            if (s) {
                CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(s);
                if (pb) frame = (CVPixelBufferRef)CVPixelBufferRetain(pb);
                CFRelease(s);
            }
        }
    } @catch (NSException *e) {
    } @finally {
        [g_mediaLock unlock];
    }
    return frame;
}

// 按「会话已过秒数」定位素材帧（time-to-frame）：want = floor(elapsed * 素材fps)，一次补齐落后帧
+ (CVPixelBufferRef)nextSourcePixelAt:(CFTimeInterval)elapsed {
    double fps = (g_srcFps > 1.0) ? g_srcFps : 30.0;
    BOOL freeze = vcm_loopShouldFreeze(elapsed);
    double t   = elapsed;
    if (g_srcDuration > 0.1) t = fmod(t, g_srcDuration);  // 轮内定位，关闭循环靠 freeze 冻而非 t 越界

    if (freeze) {
        [g_mediaLock lock];
        CVPixelBufferRef f = g_lastVideoPixel ? CVPixelBufferRetain(g_lastVideoPixel) : NULL;
        [g_mediaLock unlock];
        if (f) return f;
    }

    if (g_videoReload) [self setupVideoReaderIfNeeded];

    long long want = (long long)floor(t * fps);
    long long need;
    if (g_srcFrameIdx < 0) {
        need = 1;                       // reader 刚重建：先取一帧把索引锚到 want
    } else {
        need = want - g_srcFrameIdx;
        if (need < 0) {                 // 时钟回卷到素材头：重建 reader 重新锚定
            [self setupVideoReaderIfNeeded];
            g_srcFrameIdx = -1;
            need = 1;
        } else if (need == 0) {         // 已追平：复用上一帧，不倒退
            [g_mediaLock lock];
            CVPixelBufferRef f = g_lastVideoPixel
                               ? (CVPixelBufferRef)CVPixelBufferRetain(g_lastVideoPixel) : NULL;
            [g_mediaLock unlock];
            return f;
        } else if (need > kVCamMaxCatchUp) {
            need = kVCamMaxCatchUp;     // 掉帧太多跳帧，不一次性补完防卡死
        }
    }

    CVPixelBufferRef frame = NULL;
    for (long long i = 0; i < need; i++) {
        CVPixelBufferRef f = vcm_pullVideoFrame();
        if (!f) { g_videoReload = YES; break; }
        if (frame) CVPixelBufferRelease(frame);
        frame = f;
    }
    g_srcFrameIdx = want;

    [g_mediaLock lock];
    if (frame) {
        if (g_lastVideoPixel) CVPixelBufferRelease(g_lastVideoPixel);
        g_lastVideoPixel = (CVPixelBufferRef)CVPixelBufferRetain(frame);
    } else if (g_lastVideoPixel) {
        frame = (CVPixelBufferRef)CVPixelBufferRetain(g_lastVideoPixel);
    }
    [g_mediaLock unlock];
    return frame;
}

// 旋转 + 等比居中 + 黑底合成
+ (CIImage *)composedImageForTarget:(CGSize)target atTime:(CFTimeInterval)elapsed {
    CGFloat targetW = target.width, targetH = target.height;
    if (targetW <= 0 || targetH <= 0) return nil;

    CVPixelBufferRef pix = [self nextSourcePixelAt:elapsed];
    if (!pix) return nil;
    CIImage *img = [CIImage imageWithCVPixelBuffer:pix options:nil];
    CVPixelBufferRelease(pix);
    if (!img) return nil;

    // 方向不一致（一方竖屏一方横屏）补 90° 对齐，g_rotation 叠加在自动判断之上
    NSInteger rot = g_rotation;
    CGRect srcExtent = img.extent;
    BOOL srcPortrait = srcExtent.size.height > srcExtent.size.width;
    BOOL dstPortrait = targetH > targetW;
    if (srcPortrait != dstPortrait) rot = (rot + 90) % 360;

    NSInteger orient = 1;
    if      (rot == 90)  orient = 8;
    else if (rot == 180) orient = 3;
    else if (rot == 270) orient = 6;
    img = [img imageByApplyingOrientation:(CGImagePropertyOrientation)orient];

    CGRect e = img.extent;
    if (e.size.width <= 0 || e.size.height <= 0) return nil;

    // 固定铺满（scale=MAX）：等比放大到铺满再裁掉溢出，对端最清晰
    CGFloat scale = MAX(targetW / e.size.width, targetH / e.size.height);
    if (!(scale > 0) || !isfinite(scale)) return nil;

    CIImage *scaled = img;
    if (fabs(scale - 1.0) > 0.002) {
        // CILanczosScaleTransform 3-lobe sinc 重采样，避免双线性放大糊边
        CIFilter *f = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        [f setValue:img forKey:kCIInputImageKey];
        [f setValue:@(scale) forKey:kCIInputScaleKey];
        [f setValue:@(1.0) forKey:kCIInputAspectRatioKey];
        CIImage *out = f.outputImage;
        scaled = out ?: [img imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    }

    CGRect r = scaled.extent;
    CGFloat tx = (targetW - r.size.width)  / 2.0 - r.origin.x;
    CGFloat ty = (targetH - r.size.height) / 2.0 - r.origin.y;
    scaled = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];

    CIImage *canvas = [scaled imageByCroppingToRect:CGRectMake(0, 0, targetW, targetH)];
    if (r.size.width + 0.5 >= targetW && r.size.height + 0.5 >= targetH) {
        img = canvas;  // 铺满模式必覆盖画布，跳过黑底合成省一次 GPU pass
    } else {
        img = [canvas imageByCompositingOverImage:[self blackImageForTarget:target]];
    }
    return img;
}

+ (CIImage *)blackImageForTarget:(CGSize)target {
    return [[CIImage imageWithColor:[CIColor blackColor]]
            imageByCroppingToRect:CGRectMake(0, 0, target.width, target.height)];
}

// 渲染成新的 CMSampleBuffer，沿用采集帧时序与 Exif/TIFF 附件
+ (CMSampleBufferRef)makeSampleFromImage:(CIImage *)img
                                   width:(size_t)w height:(size_t)h
                                  format:(OSType)pfmt
                               timingSrc:(CMSampleBufferRef)src {
    if (!img || w == 0 || h == 0) return NULL;

    CVPixelBufferRef pb = vcm_pooledPixelBuffer(w, h, pfmt);
    if (!pb) return NULL;

    [g_ciContext render:img toCVPixelBuffer:pb
                 bounds:CGRectMake(0, 0, (CGFloat)w, (CGFloat)h) colorSpace:nil];

    CMVideoFormatDescriptionRef fmtDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &fmtDesc);
    CMSampleBufferRef out = NULL;
    if (fmtDesc) {
        CMSampleTimingInfo timing;
        timing.duration              = kCMTimeInvalid;
        timing.presentationTimeStamp = kCMTimeInvalid;
        timing.decodeTimeStamp       = kCMTimeInvalid;
        if (src) CMSampleBufferGetSampleTimingInfo(src, 0, &timing);
        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pb, YES,
                                           NULL, NULL, fmtDesc, &timing, &out);
        if (out && src) {
            CFStringRef keys[2] = { kCGImagePropertyExifDictionary, kCGImagePropertyTIFFDictionary };
            for (int i = 0; i < 2; i++) {
                CFTypeRef v = CMGetAttachment(src, keys[i], NULL);
                if (v) CMSetAttachment(out, keys[i], v, kCMAttachmentMode_ShouldPropagate);
            }
        }
        CFRelease(fmtDesc);
    }
    CVPixelBufferRelease(pb);
    return out;
}

// 画布恒等于采集帧尺寸，旋转只作用于源画面
+ (CMSampleBufferRef)getVideoFrame:(CMSampleBufferRef)origSample {
    if (!origSample) return NULL;
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;  // 没素材原样透传
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    CFTimeInterval elapsed = vcm_elapsed();

    CMSampleBufferRef out = NULL;
    @try {
        @autoreleasepool {
            CIImage *img = [self composedImageForTarget:target atTime:elapsed];
            if (!img) {
                static BOOL sBlack = NO;
                if (!sBlack) { sBlack = YES; vcm_dbg(@"getVideoFrame BLACK fallback (source nil)"); }
                img = [self blackImageForTarget:target];
            }
            out = [self makeSampleFromImage:img
                                      width:(size_t)target.width
                                     height:(size_t)target.height
                                     format:pfmt
                                  timingSrc:origSample];
        }
    } @catch (NSException *e) {
        if (out) { CFRelease(out); out = NULL; }  // 合成/渲染异常本帧透传真实摄像头
    }
    return out;
}

+ (void)cleanup {
    vcm_invalidatePCM();
    vcm_stopReaders();
    vcm_resetClock();
    if (g_pbPool) { CVPixelBufferPoolRelease(g_pbPool); g_pbPool = NULL; }
}
@end

#pragma mark - AudioUnitRender Hook（麦克风采集替换）
// AudioUnitRender 钩子：截获麦克风渲染回调，把上行音频替换为预解码 PCM（仅 bus=1 麦克风上行，播放总线不动）。
// 这是“替换麦克风声音”的核心落点。
// 麦克风走裸 PCM：先按 bus=1 探测目标 ASBD，之后按 ioData 尺寸拉 PCM 再 memcpy，不做格式转换
static OSStatus hooked_AudioUnitRender(
    AudioUnit                   inUnit,
    AudioUnitRenderActionFlags  *ioActionFlags,
    const AudioTimeStamp       *inTimeStamp,
    UInt32                      inOutputBusNumber,
    UInt32                      inNumberFrames,
    AudioBufferList             *ioData
) {
    OSStatus status = g_origAudioUnitRender(inUnit, ioActionFlags, inTimeStamp,
                                           inOutputBusNumber, inNumberFrames, ioData);
    if (status != noErr)                    return status;
    if (!g_isReplace || !g_isSound)         return status;
    if (!ioData)                            return status;
    if (inOutputBusNumber != 1)             return status;  // 严格只处理麦克风上行总线

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        OSStatus perr = AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, inOutputBusNumber,
                                 &g_targetASBD, &propSize);
        if (perr == noErr && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            if (g_audioPCMReady && !vcm_asbdMatches(g_audioPCMFormat, g_targetASBD)) vcm_invalidatePCM();
            if (!g_audioFeederRunning) [VCamMediaManager decodeAudioToMemory];
        }
    }
    if (!g_hasProbedASBD) return status;

    // 每帧轻量校验 ASBD 是否变化（通话初期 bus=1 真实格式往往晚于首次回调才落定）；变化则重探+重解
    {
        AudioStreamBasicDescription live = {0};
        UInt32 ps = sizeof(live);
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                kAudioUnitScope_Output, inOutputBusNumber, &live, &ps) == noErr
                && live.mSampleRate > 0
                && !vcm_asbdMatches(live, g_targetASBD)) {
            g_hasProbedASBD = NO;
            vcm_invalidatePCM();
        }
    }

    // 自愈：每帧兜底触发解码，decodeAudioToMemory 幂等零开销
    if (!g_audioFeederRunning && !g_audioPCMReady) {
        [VCamMediaManager decodeAudioToMemory];
    }

    UInt32 nBuf = ioData->mNumberBuffers;
    if (nBuf == 0) return status;
    size_t need = 0;
    for (UInt32 i = 0; i < nBuf; i++) {
        if (ioData->mBuffers[i].mDataByteSize > 0x100000) return status;
        need += ioData->mBuffers[i].mDataByteSize;
    }
    if (need == 0 || need > 0x100000) return status;

    uint8_t *temp = (uint8_t *)calloc(1, need);
    if (!temp) return status;
    @try {
        [VCamMediaManager pullAudioData:temp length:(UInt32)need atTime:vcm_elapsed()];
        size_t off = 0;
        for (UInt32 i = 0; i < nBuf; i++) {
            AudioBuffer *b = &ioData->mBuffers[i];
            if (b->mData && b->mDataByteSize > 0 && off + b->mDataByteSize <= need) {
                memcpy(b->mData, temp + off, b->mDataByteSize);
                off += b->mDataByteSize;
            }
        }
    } @catch (NSException *e) {
    }
    free(temp);
    return noErr;
}

#pragma mark - VCamVideoProxy（相机采集替换）
// VCamVideoProxy：接管 AVCaptureVideoDataOutput 的采样回调代理，把真实画面换成素材视频帧。
@interface VCamVideoProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation VCamVideoProxy {
    __weak id _originalDelegate;
}
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue { _originalDelegate = delegate; }

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    g_videoOrientation = connection.videoOrientation;
    CMSampleBufferRef newSample = NULL;
    if (g_isReplace && !g_videoSuppress) {   // 替换开启且未被抑制：把真实帧换成素材帧
        @try {
            newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
            if (newSample && g_displayLayer) {
                if (!g_displayLayer.isReadyForMoreMediaData) [g_displayLayer flush];
                [g_displayLayer enqueueSampleBuffer:newSample];
            }
        } @catch (NSException *e) {
            newSample = NULL;
        }
    }

    // 成片是否替换取决于这一步：素材帧必须交给微信原始 delegate 才会被写进文件
    BOOL hasOrig = (_originalDelegate &&
                    [_originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]);
    if (g_dbgFirstFrame) {
        g_dbgFirstFrame = NO;
        vcm_dbg(@"proxy firstFrame isReplace=%d suppress=%d replacing=%d origDelegate=%d",
                g_isReplace, g_videoSuppress, (newSample != NULL), (hasOrig ? 1 : 0));
    }

    if (hasOrig) {
        [_originalDelegate captureOutput:output
                    didOutputSampleBuffer:(newSample ?: sampleBuffer)
                           fromConnection:connection];
    }
    if (newSample) CFRelease(newSample);
}
@end
static char kVCamVideoProxyKey;   // 关联对象 key：每个 AVCaptureVideoDataOutput 独立持有自己的 proxy

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    // 每个 output 独立持有 proxy：微信可能同时存在预览与录制两个 video data output，
    // 共用单例会让 _originalDelegate 互相覆盖，素材帧转发错对象、导致成片不被替换
    VCamVideoProxy *p = objc_getAssociatedObject(self, &kVCamVideoProxyKey);
    if (delegate == nil) {
        %orig(nil, nil);  // detach 时原样透传，避免在已停 session 上塞入 proxy 导致闪退
        [p setOriginalDelegate:nil queue:nil];
        return;
    }
    if (!p) {
        p = [[VCamVideoProxy alloc] init];
        objc_setAssociatedObject(self, &kVCamVideoProxyKey, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [p setOriginalDelegate:delegate queue:queue];
    vcm_dbg(@"setSampleBufferDelegate delegate=%@", NSStringFromClass([delegate class]));
    %orig(p, queue);
}
%end

#pragma mark - VCamAudioProxy（AVCapture 音频采集替换）
// VCamAudioProxy：接管 AVCaptureAudioDataOutput 的采样回调代理，把真实麦克风换成素材音频。
@interface VCamAudioProxy : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation VCamAudioProxy {
    __weak id _origDelegate;
}
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue { _origDelegate = delegate; }

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    CMSampleBufferRef outBuf = sampleBuffer;
    if (g_isReplace && g_isSound) {
        @try {
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer atTime:vcm_elapsed()];
            if (rep) outBuf = rep;
        } @catch (NSException *e) {
            outBuf = sampleBuffer;
        }
    }

    if (_origDelegate &&
        [_origDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [_origDelegate captureOutput:output didOutputSampleBuffer:outBuf fromConnection:connection];
    }
    if (outBuf != sampleBuffer) CFRelease(outBuf);
}
@end
static VCamAudioProxy *g_audioProxy = nil;

%hook AVCaptureAudioDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    if (delegate == nil) {
        %orig(nil, nil);
        if (g_audioProxy) [g_audioProxy setOriginalDelegate:nil queue:nil];
        return;
    }
    if (!g_audioProxy) g_audioProxy = [[VCamAudioProxy alloc] init];
    [g_audioProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_audioProxy, queue);
}
%end

#pragma mark - AVCaptureSession（会话起停）
// AVCaptureSession 钩子：监听会话起停。
// 注：原先用 session 是否挂 AVCaptureStillImageOutput 判断拍照模式、并据此抑制视频替换，
// 但实测微信所有相机 session 都挂该 output，信号恒真，反而把替换永久关死并导致黑屏，故已弃用该判定。
// AVCaptureStillImageOutput 自 iOS 10 deprecated，-Werror 下只能以字符串取类。
static Class vcm_stillImageClass(void) { return NSClassFromString(@"AVCaptureStillImageOutput"); }

// 按 session 实际 outputs 判定是否拍照模式（比事件可靠，微信常 stop 后复用 session 不 removeOutput）
static BOOL vcm_sessionHasStillOutput(AVCaptureSession *session) {
    if (!session) return NO;
    Class c = vcm_stillImageClass();
    for (AVCaptureOutput *o in session.outputs)
        if (c && [o isKindOfClass:c]) return YES;
    return NO;
}
%hook AVCaptureSession
- (void)startRunning {
    vcm_reloadReaders();
    if (g_isReplace) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    %orig;
    g_sessionRunning = YES;
    if (g_displayLink) g_displayLink.paused = NO;
    g_dbgFirstFrame = YES;
    NSMutableString *outs = [NSMutableString string];
    for (AVCaptureOutput *o in self.outputs) [outs appendFormat:@"%@ ", NSStringFromClass([o class])];
    vcm_dbg(@"startRunning isReplace=%d hasStill=%d suppress=%d file=%d reader=%@ outputs=[%@]",
            g_isReplace, vcm_sessionHasStillOutput(self), g_videoSuppress,
            [g_fileManager fileExistsAtPath:vcm_videoPath()], g_videoReader, outs);
}
- (void)stopRunning {
    %orig;
    g_sessionRunning = NO;
    vcm_finishWritingNow();           // 兜底只清写文件位（会话停止≠退出拍照模式）
    if (g_displayLink) g_displayLink.paused = YES;
    vcm_invalidatePCM();
    vcm_resetClock();
}
%end

#pragma mark - 微信相机控制器：进相机即真实预览
// 微信所有相机（聊天/朋友/朋友圈）统一走 MMSightCameraViewController。拍照/录像不再靠内部控件判别：
// 进相机默认真实预览，开始录制时由 AVAssetWriter.startWriting 切换为素材替换。
%hook MMSightCameraViewController
- (void)viewWillAppear:(_Bool)arg1 {
    %orig;
    // 进相机即真实预览（拍照态）：不再依赖 shotMode 切换控件（当前入口下不存在），由录制事件切换到替换
    vcm_suppressSet(kSuppressPhotoMode, YES);
    vcm_suppressSet(kSuppressWriting, NO);
    vcm_dbg(@"MMSightCamera viewWillAppear[b20260908c] suppressing=%d", g_videoSuppress);
}
- (void)viewWillDisappear:(_Bool)arg1 {
    %orig;
    vcm_suppressSet(kSuppressPhotoMode, NO);  // 离开相机复位，避免影响下次会话
}
%end

#pragma mark - 录制期间切换为素材替换
// 开始录制即进入替换态（预览显示素材 + 成片替换）；结束/取消录制回到真实预览。
// 录制文件统一走 AVAssetWriter，故从这里切入切换。
%hook AVAssetWriter
- (BOOL)startWriting {
    BOOL ok = %orig;
    vcm_suppressSet(kSuppressPhotoMode, NO);  // 录像：素材替换（预览素材 + 成片假）
    vcm_suppressSet(kSuppressWriting, NO);
    return ok;
}
- (void)finishWritingWithCompletionHandler:(void (^)(void))handler {
    // block 先赋局部变量再传 %orig，避免 Logos 解析嵌套大括号报 “missing closing parenthesis”
    void (^wrapped)(void) = ^{
        vcm_suppressSet(kSuppressPhotoMode, YES);  // 录完回到真实预览
        vcm_suppressSet(kSuppressWriting, NO);
        if (handler) handler();
    };
    %orig(wrapped);
}
- (void)cancelWriting {
    %orig;
    vcm_suppressSet(kSuppressPhotoMode, YES);
    vcm_suppressSet(kSuppressWriting, NO);
}
%end

// 拍照/录像切换与快门确认曾依赖 SightShootingModeSwitchView / 快门 API 反推模式，
// 但在当前微信版本下该切换控件为 nil、无法可靠判模式，已改为“进相机真实 + 录制切换替换”的事件驱动，
// 故相关钩子（ShortVideoToolbar.onShootingModeChanged、AVCapturePhotoOutput、AVCaptureStillImageOutput）已移除。

#pragma mark - AVCaptureVideoPreviewLayer（叠加预览显示层）
// AVCaptureVideoPreviewLayer 钩子：在相机预览层上叠加我们的显示层，并把素材方向对齐到预览方向。
@protocol VCamSync <NSObject>
- (void)vcm_syncDisplayLayer;
@end

// CADisplayLink 强引用 target，加一层弱引用代理转发避免 preview layer 泄漏
@interface VCamLinkProxy : NSObject
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *layer;
@end
@implementation VCamLinkProxy
- (void)step:(CADisplayLink *)link { [(id<VCamSync>)self.layer vcm_syncDisplayLayer]; }
@end
static VCamLinkProxy *g_linkProxy = nil;

%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer {
    %orig;

    if (!g_displayLink) {
        g_linkProxy = [VCamLinkProxy new];
        g_linkProxy.layer = self;
        g_displayLink = [CADisplayLink displayLinkWithTarget:g_linkProxy selector:@selector(step:)];
        [g_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
    if (![[self sublayers] containsObject:g_displayLayer]) {
        g_displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        [self insertSublayer:g_displayLayer above:layer];
    }
}

// 每帧同步显示层的可见性、填充模式、位置和旋转（取帧由采集回调驱动）
%new
- (void)vcm_syncDisplayLayer {
    if (!g_displayLayer) return;

    // 拍照/录像由进相机与录制事件驱动，无需逐帧轮询模式，故此处不再调用模式判定

    // 拍照/拍摄模式（g_videoSuppress）下代理不再往 g_displayLayer 塞帧，必须隐藏上层露出真实相机，否则空层盖成黑屏
    BOOL show = g_isReplace && [g_fileManager fileExistsAtPath:vcm_videoPath()] && !g_videoSuppress;
    [g_displayLayer setOpacity:(show ? 1.0f : 0.0f)];
    if (!show) return;

    [g_displayLayer setVideoGravity:[self videoGravity]];
    [g_displayLayer setFrame:self.bounds];

    switch (g_videoOrientation) {
        case AVCaptureVideoOrientationLandscapeRight:
            g_displayLayer.transform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            g_displayLayer.transform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
            break;
        default:
            g_displayLayer.transform = CATransform3DIdentity;
            break;
    }
}
%end

#pragma mark - VCamMenuVC（控制菜单）
// VCamMenuVC：悬浮控制菜单，集中所有交互入口（开关、旋转、循环、素材选择等）。
@interface VCamMenuVC : UIViewController
    <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>
@end

@implementation VCamMenuVC {
    UIView   *_panelView;
    UIView   *_contentView;
    UILabel  *_statusLabel;
    UIButton *_btnRotate;
    UIButton *_btnLoop;
    UIButton *_btnSound;
    UIButton *_btnReplace;
}

#pragma mark - 生命周期
// 生命周期：菜单视图加载与销毁时的初始化/清理。
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupBackground];
    [self setupPanel];
    [self setupNavBar];
    [self setupContent];
    [self setupButtons];
    [self updateStatusUI];
}

#pragma mark - UI 构建
// UI 构建：菜单背景、面板容器与按钮网格的搭建。
- (void)setupBackground { self.view.backgroundColor = [UIColor clearColor]; }

- (void)setupPanel {
    _panelView = [[UIView alloc] init];
    _panelView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _panelView.layer.cornerRadius = 16;
    _panelView.layer.masksToBounds = YES;
    _panelView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_panelView];
    [NSLayoutConstraint activateConstraints:@[
        [_panelView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_panelView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_panelView.widthAnchor    constraintEqualToConstant:320],
    ]];
}

- (void)setupNavBar {
    UIView *navBar = [[UIView alloc] init];
    navBar.backgroundColor = [UIColor systemGray5Color];
    navBar.translatesAutoresizingMaskIntoConstraints = NO;
    [_panelView addSubview:navBar];
    [NSLayoutConstraint activateConstraints:@[
        [navBar.topAnchor      constraintEqualToAnchor:_panelView.topAnchor],
        [navBar.leadingAnchor  constraintEqualToAnchor:_panelView.leadingAnchor],
        [navBar.trailingAnchor constraintEqualToAnchor:_panelView.trailingAnchor],
        [navBar.heightAnchor   constraintEqualToConstant:44],
    ]];
    UILabel *title = [[UILabel alloc] init];
    title.text = @"VCAM";
    title.font = [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [navBar addSubview:title];
    [title.centerXAnchor constraintEqualToAnchor:navBar.centerXAnchor].active = YES;
    [title.centerYAnchor constraintEqualToAnchor:navBar.centerYAnchor].active = YES;
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"关闭" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [navBar addSubview:close];
    [close.trailingAnchor constraintEqualToAnchor:navBar.trailingAnchor constant:-16].active = YES;
    [close.centerYAnchor  constraintEqualToAnchor:navBar.centerYAnchor].active = YES;
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"重置" forState:UIControlStateNormal];
    reset.titleLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
    [reset addTarget:self action:@selector(actionReset) forControlEvents:UIControlEventTouchUpInside];
    reset.translatesAutoresizingMaskIntoConstraints = NO;
    [navBar addSubview:reset];
    [reset.leadingAnchor constraintEqualToAnchor:navBar.leadingAnchor constant:16].active = YES;
    [reset.centerYAnchor  constraintEqualToAnchor:navBar.centerYAnchor].active = YES;
}

- (void)setupContent {
    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_panelView addSubview:_contentView];
    [NSLayoutConstraint activateConstraints:@[
        [_contentView.topAnchor      constraintEqualToAnchor:_panelView.topAnchor constant:56],
        [_contentView.leadingAnchor  constraintEqualToAnchor:_panelView.leadingAnchor constant:16],
        [_contentView.trailingAnchor constraintEqualToAnchor:_panelView.trailingAnchor constant:-16],
        [_contentView.bottomAnchor   constraintEqualToAnchor:_panelView.bottomAnchor constant:-16],
    ]];
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont systemFontOfSize:13];
    _statusLabel.textColor = [UIColor secondaryLabelColor];
    _statusLabel.numberOfLines = 0;
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_statusLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_statusLabel.topAnchor      constraintEqualToAnchor:_contentView.topAnchor],
        [_statusLabel.leadingAnchor  constraintEqualToAnchor:_contentView.leadingAnchor],
        [_statusLabel.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor],
    ]];
}

- (UIButton *)addGridButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h action:(SEL)action {
    UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
    config.baseBackgroundColor = [UIColor systemGray5Color];
    config.baseForegroundColor   = [UIColor labelColor];
    config.contentInsets = NSDirectionalEdgeInsetsMake(8, 0, 8, 0);
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightMedium]}];
    UIButton *btn = [UIButton buttonWithConfiguration:config primaryAction:nil];
    btn.layer.cornerRadius = 8;
    btn.layer.masksToBounds = YES;
    btn.frame = CGRectMake(x, y, w, h);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:btn];
    return btn;
}

- (void)setupButtons {
    CGFloat btnW = 140, btnH = 40, gap = 8;
    CGFloat y = 28;

    [self addGridButton:@"相册选择" x:0 y:y w:btnW h:btnH action:@selector(actionSelectAlbum)];
    [self addGridButton:@"文件选择" x:btnW + gap y:y w:btnW h:btnH action:@selector(actionSelectFile)];
    y += btnH + gap;

    _btnRotate = [self addGridButton:[NSString stringWithFormat:@"旋转 (%d°)", g_rotation] x:0 y:y w:btnW h:btnH action:@selector(toggleRotate)];
    _btnLoop   = [self addGridButton:g_isLoop ? @"循环: 开" : @"循环: 关" x:btnW + gap y:y w:btnW h:btnH action:@selector(toggleLoop)];
    y += btnH + gap;

    _btnSound  = [self addGridButton:g_isSound ? @"声音: 开" : @"声音: 关" x:0 y:y w:btnW h:btnH action:@selector(toggleSound)];
    _btnReplace = [self addGridButton:g_isReplace ? @"替换: 开" : @"替换: 关"
                   x:btnW + gap y:y w:btnW h:btnH action:@selector(toggleReplace)];
    y += btnH + gap;

    [self addGridButton:@"导出诊断" x:0 y:y w:btnW h:btnH action:@selector(actionExportDiag)];
    y += btnH + gap;

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作
// 按钮动作：各开关/旋转/循环/重置按钮的点击事件处理。
- (void)toggleRotate  { g_rotation   = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop    { g_isLoop = !g_isLoop; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound   { g_isSound    = !g_isSound;    vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleReplace { g_isReplace  = !g_isReplace;  vcm_saveSettings(); [self refreshGridButtons]; }
- (void)actionReset   { vcm_resetSettings(); [self refreshGridButtons]; }
- (void)actionExportDiag {
    NSString *log = g_diagLog ? [g_diagLog componentsJoinedByString:@"\n"] : @"";
    if (!log.length) log = @"(暂无诊断日志，请先复现问题)";
    NSString *path = [vcm_documentPath() stringByAppendingPathComponent:@"VCAM_diag.txt"];
    [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    UIActivityViewController *avc = [[UIActivityViewController alloc]
        initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    if (avc.popoverPresentationController) avc.popoverPresentationController.sourceView = self.view;
    [self presentViewController:avc animated:YES completion:nil];
}

#pragma mark - 面板刷新
// 面板刷新：根据当前运行状态刷新按钮标题与高亮样式。
- (void)applyTitle:(NSString *)title toButton:(UIButton *)btn withFont:(UIFont *)font {
    if (!btn) return;
    UIButtonConfiguration *config = btn.configuration;
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
        attributes:@{NSFontAttributeName: font}];
    btn.configuration = config;
}
- (void)refreshGridButtons {
    UIFont *font = [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightMedium];
    [self applyTitle:[NSString stringWithFormat:@"旋转 (%d°)", g_rotation] toButton:_btnRotate withFont:font];
    [self applyTitle:(g_isLoop     ? @"循环: 开" : @"循环: 关") toButton:_btnLoop    withFont:font];
    [self applyTitle:(g_isSound    ? @"声音: 开" : @"声音: 关") toButton:_btnSound   withFont:font];
    [self applyTitle:(g_isReplace  ? @"替换: 开" : @"替换: 关") toButton:_btnReplace withFont:font];
    [self updateStatusUI];
}
- (void)updateStatusUI {
    BOOL hasVideo = [g_fileManager fileExistsAtPath:vcm_videoPath()];
    BOOL hasAudio = [g_fileManager fileExistsAtPath:g_tempAudioPath];
    NSString *vStat = hasVideo ? @"已加载" : @"未选择";
    NSMutableString *s = [NSMutableString stringWithFormat:@"视频: %@", vStat];
    if (hasAudio)       [s appendString:@"   声音: 已加载自定义"];
    else if (hasVideo)  [s appendString:@"   声音: 已加载"];
    else                [s appendString:@"   声音: 未加载"];
    _statusLabel.text = s;
}
- (void)closeMenu { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - 文件选择
// 文件选择：从相册/文件 App 选取素材视频并加载。
- (void)actionSelectAlbum {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.movie"];
    picker.delegate = (id)self;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)actionSelectFile {
    NSArray *contentTypes = @[UTTypeMovie, UTTypeAudio];
    UIDocumentPickerViewController *picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:contentTypes asCopy:YES];
    picker.delegate = (id)self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)processSelectedVideoURL:(NSURL *)url {
    if (!url) return;
    NSString *src = [url.path stringByResolvingSymlinksInPath];
    if (!src || ![g_fileManager fileExistsAtPath:src]) return;
    AVAsset *asset  = [AVAsset assetWithURL:url];
    BOOL hasVideo = [[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0;
    BOOL hasAudio  = [[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0;

    vcm_reloadReaders();
    NSError *copyErr = nil;
    if (hasVideo) {
        vcm_clearMaterialFiles(@"bear_vcam_temp.");
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"mov";
        NSString *dst = [g_videoDir stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"bear_vcam_temp.%@", ext]];
        if (![g_fileManager copyItemAtPath:src toPath:dst error:&copyErr]) { [self updateStatusUI]; return; }
        g_videoPath = [dst copy];
        vcm_stopReaders();
        g_isReplace = YES;
        vcm_saveSettings();
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        vcm_clearMaterialFiles(@"bear_vcam_audio.");
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"m4a";
        NSString *dst = [g_videoDir stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"bear_vcam_audio.%@", ext]];
        if (![g_fileManager copyItemAtPath:src toPath:dst error:&copyErr]) { [self updateStatusUI]; return; }
        g_tempAudioPath = [dst copy];
        g_isReplace = YES;  // 自动开启替换（用户意图就是替换麦克风声音）
        vcm_saveSettings();
        vcm_stopReaders();
        [self updateStatusUI];
    }
    vcm_resetClock();
    [self refreshGridButtons];
}

#pragma mark - UIImagePickerControllerDelegate
// UIImagePickerController 回调：相册选完/取消后的处理。
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSURL *url = info[UIImagePickerControllerMediaURL];
    if (url) { [self processSelectedVideoURL:url]; return; }
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - UIDocumentPickerDelegate
// UIDocumentPickerDelegate 回调：文件 App 选完视频后的处理。
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [controller dismissViewControllerAnimated:YES completion:nil];
    if (urls.count > 0) [self processSelectedVideoURL:urls.firstObject];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    [controller dismissViewControllerAnimated:YES completion:nil];
    [self processSelectedVideoURL:url];
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller { [controller dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - UIWindow 手势触发
// UIWindow 手势触发：给 keyWindow 挂双击手势唤起菜单；becomeKeyWindow 会反复触发，需判重防叠加。
static void vcm_installTapGesture(UIWindow *win) {
    // becomeKeyWindow 会反复调用，不判重会一层层叠加手势 → 一次双击弹 N 个面板
    static char kVCamTapKey;
    if (objc_getAssociatedObject(win, &kVCamTapKey)) return;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:win action:@selector(vcm_presentMenu)];
    tap.numberOfTapsRequired    = 2;
    tap.numberOfTouchesRequired = 2;
    tap.cancelsTouchesInView    = NO;
    [win addGestureRecognizer:tap];
    objc_setAssociatedObject(win, &kVCamTapKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@interface UIWindow (VCam)
- (void)vcm_presentMenu;
@end
@implementation UIWindow (VCam)
- (void)vcm_presentMenu {
    static BOOL menuVisible = NO;
    if (menuVisible) return;
    menuVisible = YES;
    UIViewController *topVC = vcm_topViewController();
    if (!topVC) { menuVisible = NO; return; }
    VCamMenuVC *vc = [VCamMenuVC new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;
    [topVC presentViewController:vc animated:YES completion:^{ menuVisible = NO; }];
}
@end
%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{ vcm_installTapGesture(self); });
}
%end

#pragma mark - 构造 / 析构
// 构造/析构：%ctor 初始化全部状态、挂好各钩子、安装手势；%dtor 释放显示层等。
%ctor {
    g_fileManager = [NSFileManager defaultManager];
    g_mediaLock   = [[NSLock alloc] init];
    g_ciContext = [CIContext contextWithOptions:@{
        kCIContextWorkingColorSpace: [NSNull null],
    }];
    g_videoDir = [[vcm_documentPath() stringByAppendingPathComponent:@"VCAM"] copy];
    [g_fileManager createDirectoryAtPath:g_videoDir withIntermediateDirectories:YES attributes:nil error:nil];
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    vcm_loadSettings();
    g_srcFrameIdx = -1;

    if ([g_fileManager fileExistsAtPath:vcm_videoPath()]) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }

    // fishhook 重定向 AudioUnitRender：改写 WeChat 的间接符号指针拦截麦克风上行，
    // 比内联钩子对共享缓存里的框架函数更稳（MSHookFunction 在此环境会静默失效）
    dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_NOW);
    struct rebinding reb = {
        "AudioUnitRender",
        (void *)hooked_AudioUnitRender,
        (void **)&g_origAudioUnitRender,
    };
    rebind_symbols(&reb, 1);

    // 旧式快门 API 钩子已移除：拍照/录像判别改为进相机真实 + 录制切换替换的事件驱动。
}

%dtor {
    [g_displayLink invalidate];
    g_displayLink  = nil;
    g_displayLayer = nil;
    g_linkProxy    = nil;
    [VCamMediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

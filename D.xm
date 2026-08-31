// VCAM — 全平台相机/麦克风虚拟替换插件（Theos / Logos）
//
// 将任意 App 的相机画面与麦克风声音，替换为用户导入的本地视频/音频素材。
// 双指双击任意窗口弹出控制面板，导入素材并开关各项替换。
// 框架级 hook，覆盖微信 / 相机 App / 任意走标准采集管线的 App。
//
// 按采集通道分三条链路拦截（框架级 hook，覆盖微信/相机/任意走标准管线的 App）：
//   · AVCaptureVideoDataOutput  画面采集回调
//   · AVCaptureAudioDataOutput  音频采集回调
//   · AudioUnitRender           视频通话的麦克风采集（裸 PCM）
//
// 前两条投递 CMSampleBuffer，第三条是裸 PCM 字节流，故音频有两套实现：
//   AVCapture 链路按帧取用（AVFoundation reader）；
//   AudioUnit 链路用 AVFoundation（AVAssetReader 解码 + AudioToolbox 的 AudioConverter 重采样）流式产出目标格式 PCM，实时写入环形缓冲。
//
// 画面流向：素材 → AVAssetReader 取帧 → 旋转/镜像/等比居中 →
// CIContext 渲染到与采集帧同尺寸同格式的 CVPixelBuffer → 套用采集帧时序 → 新的 CMSampleBuffer。
//
// 容错约定：帧构建与音频拉取均跑在实时线程，任一步抛异常仅本帧降级
// （返回 NULL / 透传真实音视频 / 静音填充），下帧自动重试；不置全局标志、不关总开关。
// g_mediaLock 为不可重入 NSLock，持锁函数内部不得再调用任何会加锁的函数；
// 含 return 的 @try 必须用 @finally 解锁，否则异常路径会漏解锁后卡死。
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#include <dlfcn.h>
// fishhook：C 级符号重定向。fishhook.h 自身已带 #ifdef __cplusplus extern "C" 守卫，
// 故此处直接 include 即可（不可再包一层 extern "C"，否则头内的 <stdint.h> 模块导入会落在
// extern "C" 上下文内，ObjC++ 模块模式下报 -Wmodule-import-in-extern-c 致命错误）。
#include "fishhook.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>

// 音频解码后端：纯 AVFoundation（AVAssetReader 按真实 ASBD 直出解码，无 AudioConverter 重采样层），不依赖 FFmpeg。
// 仅用系统框架，Theos 直接编译即可，无需额外静态库或 CI 交叉编译。

#pragma mark - 配置开关
static BOOL g_isReplace  = YES;     // YES=替换画面，NO=透传真实摄像头
static BOOL g_isLoop     = YES;     // 素材读完后是否回卷重播
static BOOL g_isSound    = YES;     // 是否替换麦克风采集
static BOOL g_isMirrored = YES;     // 是否对源画面左右镜像
static int  g_rotation   = 90;      // 0 / 90 / 180 / 270（非开关，循环取值）

#pragma mark - reader 重建标记
// 置位后由下一帧开头重建对应 reader；不在取帧失败的同帧重建（刚 startReading 的 reader 首帧必取不到）。
static BOOL g_videoReload = NO;
static BOOL g_audioReload = NO;

#pragma mark - 沙箱路径
static NSString *g_videoDir      = nil;
static NSString *g_tempAudioPath = nil;

#pragma mark - 运行时状态
static NSFileManager *g_fileManager = nil;
static NSLock        *g_mediaLock   = nil;
static CIContext     *g_ciContext   = nil;

static AVAssetReader            *g_videoReader = nil;
static AVAssetReaderTrackOutput *g_videoOutput = nil;
static AVAssetReader            *g_audioReader = nil;
static AVAssetReaderTrackOutput *g_audioOutput = nil;

// 最近一帧源画面。reader 读完后冻结复用，避免画面闪回真实摄像头。
static CVPixelBufferRef g_lastVideoPixel = NULL;

#pragma mark - 预览显示层
static AVSampleBufferDisplayLayer *g_displayLayer     = nil;
static CADisplayLink              *g_displayLink      = nil;
static AVCaptureVideoOrientation   g_videoOrientation = AVCaptureVideoOrientationPortrait;

#pragma mark - 音频环形缓冲（流式解码，对标 VCAM4 的 VCamAudioRingBuffer）
// 解码线程把 PCM 持续推入环形缓冲；AudioUnitRender 回调实时从环形缓冲拉取。
// 取代原“整段解码成 NSData 再按偏移切片”模型：长通话 / 换素材不卡、不在边界回卷爆音。
static uint8_t       *g_audioRing     = NULL;  // 环形缓冲本体
static size_t         g_audioRingCap  = 0;     // 容量（字节）
static size_t         g_audioRingHead = 0;     // 写指针
static size_t         g_audioRingTail = 0;     // 读指针
static size_t         g_audioRingFill = 0;     // 已填充字节数
static os_unfair_lock g_audioRingLock = OS_UNFAIR_LOCK_INIT;
static BOOL           g_audioFeederRunning = NO;  // 解码线程是否在跑
static BOOL           g_audioFeederStop    = NO;  // 通知解码线程退出
// 解码上下文全部在 feeder 线程内局部持有，线程退出时统一释放；不存全局，避免 cleanup 与 feeder 竞争释放。

#pragma mark - AudioUnit 采集状态
static BOOL                        g_hasProbedASBD = NO;
static BOOL                        g_didLogProbe    = NO;  // 「探测成功」一次会话只打一次（reload 时清回）
static BOOL                        g_didLogFeedStart= NO;  // 「feeder 启动」一次会话只打一次
static BOOL                        g_didLogUnavail  = NO;  // 「素材暂不可用」一次会话只打一次
static AudioStreamBasicDescription g_targetASBD    = {0};
// 已探测的麦克风 ASBD 即音频解码的目标格式：AudioConverter 把素材重采样/重排到该格式，
// 输出统一为交错（interleaved）PCM，直接 memcpy 进麦克风 buffer。

#pragma mark - 诊断日志（面板“导出日志”按钮会读取 g_diagLog 收集的内容）
// vcam_log 同时做两件事：NSLog 打到系统日志（[VCAM-D] 前缀），并追加进 g_diagLog 供面板导出。
// 后台解码/渲染线程都会写，故用 os_unfair_lock 保护；超过上限循环截断，避免常驻内存膨胀。
static NSMutableString *g_diagLog     = nil;
static os_unfair_lock   g_diagLock    = OS_UNFAIR_LOCK_INIT;
static void vcam_log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void vcam_log(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *full = [NSString stringWithFormat:@"[VCAM-D] %@", msg];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], full];
    NSLog(@"%@", full);
    os_unfair_lock_lock(&g_diagLock);
    if (!g_diagLog) g_diagLog = [NSMutableString new];
    if (g_diagLog.length > 64000) {
        [g_diagLog deleteCharactersInRange:NSMakeRange(0, g_diagLog.length - 64000)];
    }
    [g_diagLog appendString:line];
    os_unfair_lock_unlock(&g_diagLock);
}

// 容错：单帧失败仅降级透传，下帧重试，不置全局标志、不关替换总开关。
static OSStatus (*g_origAudioUnitRender)(
    AudioUnit                   inUnit,
    AudioUnitRenderActionFlags  *ioActionFlags,
    const AudioTimeStamp       *inTimeStamp,
    UInt32                      inOutputBusNumber,
    UInt32                      inNumberFrames,
    AudioBufferList             *ioData
) = NULL;

#pragma mark - 路径辅助
static NSString *vcm_documentPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}
static NSString *vcm_videoPath(void) {
    return [g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"];
}

#pragma mark - 配置存取
static void vcm_saveSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:g_isReplace      forKey:@"vcam_replace"];
    [d setBool:g_isLoop         forKey:@"vcam_loop"];
    [d setBool:g_isSound        forKey:@"vcam_sound"];
    [d setBool:g_isMirrored     forKey:@"vcam_mirror"];
    [d setInteger:g_rotation    forKey:@"vcam_rotation"];
    [d synchronize];
}
static void vcm_loadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"vcam_replace"])  g_isReplace   = [d boolForKey:@"vcam_replace"];
    if ([d objectForKey:@"vcam_loop"])     g_isLoop      = [d boolForKey:@"vcam_loop"];
    if ([d objectForKey:@"vcam_sound"])    g_isSound     = [d boolForKey:@"vcam_sound"];
    if ([d objectForKey:@"vcam_mirror"])   g_isMirrored  = [d boolForKey:@"vcam_mirror"];
    else                                   g_isMirrored  = YES;
    if ([d objectForKey:@"vcam_rotation"]) g_rotation    = (int)[d integerForKey:@"vcam_rotation"];
    else                                   g_rotation    = 90;
}

#pragma mark - 停止 reader 与重置
// 丢弃冻结的末帧（切换素材时调用，避免新旧素材串帧）
static void vcm_stopReaders(void) {
    [g_mediaLock lock];
    if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
    if (g_audioReader) { [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil; }
    if (g_lastVideoPixel) { CVPixelBufferRelease(g_lastVideoPixel); g_lastVideoPixel = NULL; }
    [g_mediaLock unlock];
}
// 换素材 / 会话重启时让两条链路都从头来过。关键是清 g_hasProbedASBD：
// 不清则麦克风链路认为格式已探测完，既不重新探测新会话 ASBD 也不重新解码，新素材音频进不了麦克风。
static void vcm_reloadReaders(void) {
    // 留痕：reload 会杀 feeder 并清 ASBD，是「feeder 反复重启」时序的直接解释者
    vcam_log(@"reloadReaders：清 ASBD、停 feeder、重置环形缓冲");
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
    g_didLogProbe = g_didLogFeedStart = g_didLogUnavail = NO;  // 会话级一次性日志守卫一并清回
    // 让正在跑的解码线程退出，并把环形缓冲读/写指针归零；新会话重新探测 ASBD 后会重建并重启 feeder。
    os_unfair_lock_lock(&g_audioRingLock);
    g_audioFeederStop = YES;
    g_audioRingHead = g_audioRingTail = g_audioRingFill = 0;
    os_unfair_lock_unlock(&g_audioRingLock);
}
// 恢复默认设置，清空已选素材与解码缓存
static void vcm_resetSettings(void) {
    g_isReplace   = NO;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_isMirrored  = YES;
    g_rotation    = 90;
    vcm_saveSettings();

    vcm_stopReaders();
    vcm_reloadReaders();

    if (g_tempAudioPath) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
    [g_fileManager removeItemAtPath:vcm_videoPath() error:nil];
}

#pragma mark - 视图控制器查找
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
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

#pragma mark - VCamMediaManager
@interface VCamMediaManager : NSObject
+ (void)setupVideoReaderIfNeeded;
+ (void)setupAudioReaderIfNeeded;
+ (CVPixelBufferRef)nextSourcePixel;
+ (CIImage *)composedImageForTarget:(CGSize)target;
+ (CIImage *)blackImageForTarget:(CGSize)target;
+ (CMSampleBufferRef)makeSampleFromImage:(CIImage *)img
                                   width:(size_t)w height:(size_t)h
                                  format:(OSType)pfmt
                               timingSrc:(CMSampleBufferRef)src;
+ (CMSampleBufferRef)getVideoFrame:(CMSampleBufferRef)origSample;
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample;
+ (void)startAudioFeeder;
+ (void)ringWrite:(const uint8_t *)src length:(size_t)len;
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length;
+ (void)cleanup;
@end

#pragma mark - 音频解码（对齐 VCAM4：解码器直出目标 PCM，无 AudioConverter 重采样层）
// VCAM4 反汇编确认：其 feeder 直接按真实 ASBD 解码产出，hooked_AudioUnitRender 仅做逐 buffer 零变换 memcpy，
// 全程不经过任何 AudioConverter。我们照搬此结构：由 AVAssetReader 的 outputSettings 在解码器内部完成
// 重采样/重排到微信真实 ASBD 格式，彻底消除 C 级 AudioConverter 的 srcDesc/dstDesc 误配导致的加速/失真。

@implementation VCamMediaManager
+ (void)setupVideoReaderIfNeeded {
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            // 没标重建且 reader 还没读完 → 保持现状；缺这道门禁会每帧重建，画面永远停在第一帧。
            if (!g_videoReload && g_videoReader &&
                g_videoReader.status != AVAssetReaderStatusCompleted) return;
            // 循环关闭 + reader 已读完 → 冻结末帧，不重建；循环开启时此处必须放行，否则播完就再也不动。
            if (!g_isLoop && g_videoReader &&
                g_videoReader.status == AVAssetReaderStatusCompleted) return;
            g_videoReload = NO;

            if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
            NSString *path = vcm_videoPath();
            if (![g_fileManager fileExistsAtPath:path]) return;
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
            g_videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            // 这里不清冻结的末帧，否则循环重建 reader 失败时会闪黑帧
            if (track) {
                NSDictionary *settings = @{
                    (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                };
                g_videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                [g_videoReader addOutput:g_videoOutput];
                // 首例留痕：循环模式下 reader 每遍素材都会重建，只记第一次失败，避免刷屏
                if (![g_videoReader startReading]) {
                    static BOOL didLogVS = NO;
                    if (!didLogVS) { vcam_log(@"视频 reader startReading 失败：%@", g_videoReader.error.localizedDescription); didLogVS = YES; }
                }
            } else {
                static BOOL didLogVT = NO;
                if (!didLogVT) { vcam_log(@"视频 reader：素材无视频轨道"); didLogVT = YES; }
            }
        }
    } @catch (NSException *e) {
        vcam_log(@"setupVideoReader 异常：%@ — %@", e.name, e.reason);
    } @finally {
        // 必须是 @finally：@try/@catch 里的 return 不执行块后语句，unlock 写在块后会漏解锁，下一帧直接卡死。
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
            g_audioReload = NO;

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
                NSDictionary *settings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM) };
                g_audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                g_audioOutput.alwaysCopiesSampleData = NO;
                [g_audioReader addOutput:g_audioOutput];
                // 首例留痕：此 reader 服务 AVCapture 音频链路（getAudioFrame），失败会让该链路一直透传真实麦克风
                if (![g_audioReader startReading]) {
                    static BOOL didLogAS = NO;
                    if (!didLogAS) { vcam_log(@"AVCapture 音频 reader startReading 失败：%@", g_audioReader.error.localizedDescription); didLogAS = YES; }
                }
            } else {
                static BOOL didLogAT = NO;
                if (!didLogAT) { vcam_log(@"AVCapture 音频 reader：素材无音频轨道"); didLogAT = YES; }
            }
        }
        // ASBD 探明后 AudioUnit 链路才需要喂数据：启动流式解码线程（幂等，已在跑则忽略）。
        if (g_hasProbedASBD) [self startAudioFeeder];
    } @catch (NSException *e) {
        vcam_log(@"setupAudioReader 异常：%@ — %@", e.name, e.reason);
    } @finally {
        // 早期 return 也要保证解锁
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 流式解码线程（对齐 VCAM4）：AVAssetReader 按探测到的真实 ASBD 把素材音频【直出】为该格式 PCM
// （解码器内部完成重采样/重排），无需外部 AudioConverter 层，直接写入环形缓冲。
// 到末尾按 g_isLoop 重建 reader 回卷重播，或停喂（环形缓冲排空后静音透传）。
// 解码上下文在线程内局部持有，@finally 统一释放，不与 cleanup 竞争。
+ (void)startAudioFeeder {
    if (!g_hasProbedASBD)     return;
    if (g_audioFeederRunning) return;   // 幂等：已在跑则忽略
    g_audioFeederStop   = NO;
    g_audioFeederRunning = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            @autoreleasepool {
                NSString *path = g_tempAudioPath;
                if (![g_fileManager fileExistsAtPath:path]) path = vcm_videoPath();

                // 对齐 VCAM4：素材尚未拷贝完成时，feeder 内部轮询等待而非退出。
                // 旧逻辑「素材不可用就清 g_hasProbedASBD 并 return」依赖后续 AudioUnitRender(bus=1)
                // 重新探测来重启；但微信在换素材/通话切换窗口常暂时停止麦克风上行回调，
                // bus=1 不再被调用 → 探测永远重不起来 → 整通电话静音。改为 feeder 进程存活、
                // 最多轮询等待 30s，素材到位即解码，无需外部重探测，也不清 g_hasProbedASBD。
                int waitRetry = 0;
                while (!g_audioFeederStop && ![g_fileManager fileExistsAtPath:path]) {
                    if (waitRetry == 0 && !g_didLogUnavail) { vcam_log(@"素材尚未就绪，feeder 轮询等待…"); g_didLogUnavail = YES; }
                    [NSThread sleepForTimeInterval:0.2];
                    if (++waitRetry > 150) { vcam_log(@"素材等待超时(30s)，feeder 退出"); return; }
                }
                if (g_audioFeederStop) return;
                if (![g_fileManager fileExistsAtPath:path]) { vcam_log(@"素材暂不可用，feeder 退出"); return; }
                if (!g_didLogFeedStart) { vcam_log(@"feeder 启动，素材=%@ (tempAudio=%@)", path, g_tempAudioPath); g_didLogFeedStart = YES; }
                NSURL *url = [NSURL fileURLWithPath:path];

                // 对齐 VCAM4：不写死 48000/1，直接用探测到的真实 ASBD 作为解码目标格式。
                // AVAssetReader 在解码器内部把素材重采样/重排成该格式，无需外部 AudioConverter 层
                // —— 这正是 VCAM4「无重采样层、直出解码」的精髓，彻底消除 srcDesc/dstDesc 误配导致的加速/失真。
                AudioStreamBasicDescription t = g_targetASBD;
                double rate    = (t.mSampleRate > 0)        ? t.mSampleRate       : 48000.0;
                UInt32 ch      = (t.mChannelsPerFrame > 0)  ? t.mChannelsPerFrame : 1;
                BOOL   isFloat = (t.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
                UInt32 bits    = (t.mBitsPerChannel > 0)    ? t.mBitsPerChannel   : (isFloat ? 32 : 16);
                BOOL   isNonInt= (t.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;

                void (^decodeOnce)(void) = ^{
                    AVAsset *asset = [AVAsset assetWithURL:url];
                    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
                    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
                    if (!track) { vcam_log(@"feeder：%@ 无音频轨道（AVAssetReader 取不到轨道）", path); return; }
                    // 解码目标格式严格跟随真实 ASBD（rate/ch/bits/float/non-interleaved），不再写死 48000/1。
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
                    // startReading 失败必须带 error 打日志：这是“feeder 启动后静默死亡”的头号嫌疑点。
                    if (![reader startReading]) {
                        vcam_log(@"startReading 失败：%@ (status=%ld)", reader.error.localizedDescription, (long)reader.status);
                        return;
                    }

                    static BOOL didLogConv = NO;
                    if (!didLogConv) {
                        vcam_log(@"解码直出目标格式：%.0fHz/%uch %@%@ （对齐 VCAM4 无重采样层）",
                                 rate, (unsigned)ch, isFloat ? @"float" : @"int", isNonInt ? @" non-interleaved" : @" interleaved");
                        didLogConv = YES;
                    }

                    UInt64 samplesGot = 0;   // 本遍累计读到的样本帧数（诊断用）
                    while (reader.status == AVAssetReaderStatusReading && !g_audioFeederStop) {
                        CMSampleBufferRef s = [out copyNextSampleBuffer];
                        if (!s) break;
                        @try {
                            CMBlockBufferRef blk = CMSampleBufferGetDataBuffer(s);
                            if (!blk) continue;
                            // 新版 SDK 下 CMBlockBufferGetDataPointer 第 5 参为 char* _Nullable*，故用 char* 承接
                            size_t len = 0; char *ptr = NULL;
                            if (CMBlockBufferGetDataPointer(blk, 0, NULL, &len, &ptr) != noErr || len == 0) continue;
                            UInt32 numFrames = (UInt32)CMSampleBufferGetNumSamples(s);
                            if (numFrames == 0) continue;
                            samplesGot += numFrames;
                            static BOOL didLogWrite = NO;
                            if (!didLogWrite) { vcam_log(@"feeder 首次写出 %zu 字节到环形缓冲", len); didLogWrite = YES; }
                            // 直出：解码产物即目标格式 PCM，按字节原样写入环形缓冲（无 AudioConverter）。
                            // 消费端按 ioData->mBuffers 顺序逐块 memcpy，零变换，对齐 VCAM4。
                            [self ringWrite:(const uint8_t *)ptr length:(UInt32)len];
                        } @finally {
                            CFRelease(s);
                        }
                    }
                    // 本遍结束留痕：reader.status 为 AVAssetReaderStatus（0=Unknown 1=Reading 2=Completed成功 3=Failed 4=Cancelled）；
                    // err 仅在 Failed 时给出描述，其余为「无」。samplesGot=0 说明一个样本都没读到（reader 层问题）。
                    static BOOL didLogPass = NO;
                    if (!didLogPass) {
                        vcam_log(@"本遍读完：status=%ld samples=%llu stop=%d err=%@ (AVAssetReader: 2=Completed成功 3=Failed)",
                                 (long)reader.status, samplesGot, (int)g_audioFeederStop,
                                 (reader.status == AVAssetReaderStatusFailed) ? reader.error.localizedDescription : @"无");
                        didLogPass = YES;
                    }
                };

                // 外层：按 g_isLoop 回卷重播或停喂
                while (!g_audioFeederStop) {
                    decodeOnce();
                    if (!g_isLoop) { vcam_log(@"外层退出：循环播放关闭，feeder 结束"); break; }
                    if (g_audioFeederStop) break;
                    [NSThread sleepForTimeInterval:0.05];   // 稍等避免空转，下一轮重建 reader 从头读
                }
            }
        } @catch (NSException *e) {
            vcam_log(@"feeder 线程异常退出：%@ — %@", e.name, e.reason);
        } @finally {
            g_audioFeederRunning = NO;
        }
    });
}

// 生产者：把解码出的 PCM 写入环形缓冲。缓冲满则丢弃最旧数据，保证实时性优先于完整性。
+ (void)ringWrite:(const uint8_t *)src length:(size_t)len {
    if (!src || len == 0 || !g_audioRing) return;
    os_unfair_lock_lock(&g_audioRingLock);
    for (size_t i = 0; i < len; i++) {
        g_audioRing[g_audioRingHead] = src[i];
        g_audioRingHead = (g_audioRingHead + 1) % g_audioRingCap;
        if (g_audioRingFill < g_audioRingCap) g_audioRingFill++;
        else g_audioRingTail = (g_audioRingTail + 1) % g_audioRingCap;  // 满则丢最旧
    }
    os_unfair_lock_unlock(&g_audioRingLock);
}

// 消费者（实时安全）：从环形缓冲读出 length 字节填入 outData；不足部分补 0（静音）。
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    if (!outData || length == 0) return;
    // 超大请求多半是参数异常，直接静音处理
    if (length > 0x100000) { memset(outData, 0, length); return; }
    os_unfair_lock_lock(&g_audioRingLock);
    size_t avail = g_audioRingFill;
    size_t written = 0;
    while (written < length && avail > 0) {
        outData[written++] = g_audioRing[g_audioRingTail];
        g_audioRingTail = (g_audioRingTail + 1) % g_audioRingCap;
        g_audioRingFill--; avail--;
    }
    os_unfair_lock_unlock(&g_audioRingLock);
    if (written < length) {
        // 首例留痕：环里数据不够、本帧部分补零。偶发于启动瞬间属正常；持续出现说明 feeder 供给不足/未跑。
        static BOOL didLogStarve = NO;
        if (!didLogStarve) {
            vcam_log(@"环数据不足：请求 %zu 字节仅取到 %zu（余下补零静音）", length, written);
            didLogStarve = YES;
        }
        memset(outData + written, 0, length - written);
    }
}

// 从音频 reader 取一帧，套用采集帧的时序后返回（调用方负责 CFRelease）。
// setupAudioReaderIfNeeded 内部也会加 g_mediaLock，而 NSLock 不可重入，因此重建动作必须在加锁之前完成。
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample {
    // 取帧失败（含异常）即返回 NULL → 调用方透传真实麦克风
    if (g_audioReload) [self setupAudioReaderIfNeeded];

    CMSampleBufferRef s = NULL;
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (g_audioOutput) s = [g_audioOutput copyNextSampleBuffer];
        }
    } @catch (NSException *e) {
        vcam_log(@"getAudioFrame 取帧异常：%@ — %@", e.name, e.reason);
    } @finally {
        [g_mediaLock unlock];
    }

    // 取不到帧就标重建，留给下一帧开头处理
    if (!s) {
        static BOOL didLogAF = NO;
        if (!didLogAF) { vcam_log(@"getAudioFrame 取不到帧（AVCapture 音频链路无数据，标重建重试）"); didLogAF = YES; }
        g_audioReload = YES;
    }
    if (!s) return NULL;

    CMSampleBufferRef out = NULL;
    @try {
        // 先用 kCMTimingInfoInvalid 兜底，原帧时序取不到时不至于拿栈上垃圾值构造输出帧
        CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        if (origSample && CMSampleBufferGetSampleTimingInfo(origSample, 0, &timing) == noErr) {
            CMSampleBufferRef tmp = NULL;
            if (CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, s, 1, &timing, &tmp) == noErr && tmp) {
                out = tmp;
            }
        }
    } @catch (NSException *e) {
        vcam_log(@"getAudioFrame 套时序异常：%@ — %@", e.name, e.reason);
        CFRelease(s);
        return NULL;
    }
    if (out) CFRelease(s); else out = s;
    return out;
}

// 从当前 video reader 取一帧，返回 +1 引用。不做墙钟节流：一帧采集对应一帧源；
// 预览由采集回调 enqueue 到显示层，不存在两条链路叠加消费同一批帧的问题。
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
        vcam_log(@"取视频帧异常：%@ — %@", e.name, e.reason);
    } @finally {
        [g_mediaLock unlock];
    }
    return frame;
}

// 取下一帧源视频：读完时按 g_isLoop 决定回卷重播还是冻结末帧，返回 +1 引用
+ (CVPixelBufferRef)nextSourcePixel {
    // 取帧失败即返回 NULL，交给调用方透传真实摄像头
    if (g_videoReload) [self setupVideoReaderIfNeeded];

    CVPixelBufferRef frame = vcm_pullVideoFrame();
    // 取不到帧就标重建，由下一帧开头处理。不拿 reader.status 判定「读完」——
    // status 何时变 Completed 无时序保证，依赖它会让循环永远触发不了，画面一直冻结在末帧。
    if (!frame) g_videoReload = YES;

    [g_mediaLock lock];
    if (frame) {
        if (g_lastVideoPixel) CVPixelBufferRelease(g_lastVideoPixel);
        g_lastVideoPixel = (CVPixelBufferRef)CVPixelBufferRetain(frame);
    } else if (g_lastVideoPixel) {
        // 刚重建 reader 还没出图、或循环关闭：冻结在最后一帧，避免闪回真实摄像头
        frame = (CVPixelBufferRef)CVPixelBufferRetain(g_lastVideoPixel);
    }
    [g_mediaLock unlock];
    return frame;
}

// 旋转 + 等比居中 + 黑底合成，返回 extent 严格为 (0,0,target) 的 CIImage
+ (CIImage *)composedImageForTarget:(CGSize)target {
    CGFloat targetW = target.width, targetH = target.height;
    if (targetW <= 0 || targetH <= 0) return nil;

    CVPixelBufferRef pix = [self nextSourcePixel];
    if (!pix) return nil;
    CIImage *img = [CIImage imageWithCVPixelBuffer:pix options:nil];
    CVPixelBufferRelease(pix);
    if (!img) return nil;

    NSInteger orient = 1;
    if      (g_rotation == 90)  orient = 6;
    else if (g_rotation == 180) orient = 3;
    else if (g_rotation == 270) orient = 8;
    img = [img imageByApplyingOrientation:(CGImagePropertyOrientation)orient];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (g_isMirrored) img = [img imageByApplyingCGOrientation:kCGImagePropertyOrientationUpMirrored];
#pragma clang diagnostic pop

    CGRect e = img.extent;
    if (e.size.width <= 0 || e.size.height <= 0) return nil;

    CGFloat scale = MIN(targetW / e.size.width, targetH / e.size.height);
    img = [img imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];

    CGFloat tx = (targetW - e.size.width  * scale) / 2.0;
    CGFloat ty = (targetH - e.size.height * scale) / 2.0;
    img = [img imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];

    return [img imageByCompositingOverImage:[self blackImageForTarget:target]];
}

+ (CIImage *)blackImageForTarget:(CGSize)target {
    return [[CIImage imageWithColor:[CIColor blackColor]]
            imageByCroppingToRect:CGRectMake(0, 0, target.width, target.height)];
}

// 渲染成新的 CMSampleBuffer，沿用采集帧的时序与 {Exif}/{TIFF} 附件
+ (CMSampleBufferRef)makeSampleFromImage:(CIImage *)img
                                   width:(size_t)w height:(size_t)h
                                  format:(OSType)pfmt
                               timingSrc:(CMSampleBufferRef)src {
    if (!img || w == 0 || h == 0) return NULL;
    NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    CVPixelBufferRef pb = NULL;
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, pfmt,
                            (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess || !pb) return NULL;

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
    // 没选素材就原样透传，不输出黑帧；素材存在但取帧失败才走黑帧兜底。
    // 取帧/合成失败即返回 NULL 让调用方透传真实摄像头，不能走黑帧兜底——那会令画面变全黑。
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    CMSampleBufferRef out = NULL;
    // 合成或渲染抛异常时本帧返回 NULL（透传真实摄像头），不关替换。帧构建跑在采集回调线程上，
    // 异常不拦会沿采集调用栈上抛，最坏直接崩掉宿主 App。
    @try {
        @autoreleasepool {
            CIImage *img = [self composedImageForTarget:target];
            if (!img) img = [self blackImageForTarget:target];
            out = [self makeSampleFromImage:img
                                      width:(size_t)target.width
                                     height:(size_t)target.height
                                     format:pfmt
                                  timingSrc:origSample];
        }
    } @catch (NSException *e) {
        if (out) { CFRelease(out); out = NULL; }
        vcam_log(@"视频合成/渲染异常：%@ — %@", e.name, e.reason);
    }
    return out;
}

+ (void)cleanup {
    g_audioFeederStop = YES;            // 通知解码线程退出
    vcm_stopReaders();
    os_unfair_lock_lock(&g_audioRingLock);
    if (g_audioRing) { free(g_audioRing); g_audioRing = NULL; }
    g_audioRingCap = g_audioRingHead = g_audioRingTail = g_audioRingFill = 0;
    os_unfair_lock_unlock(&g_audioRingLock);
}
@end

#pragma mark - AudioUnitRender Hook（麦克风采集替换）
// 麦克风采集走裸 PCM：先按当前渲染总线号探测一次目标 ASBD，之后按 ioData 的 buffer 尺寸拉 PCM 再 memcpy。
// 全程不做格式转换——解码时按 ASBD 对齐好了。
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
    // 对齐 VCAM4：严格只处理麦克风上行总线 bus==1（与 VCAM 反汇编 13ce4 的 `inOutputBusNumber==1` 门禁一致）。
    // 微信其它总线的 AudioUnitRender（如扬声器回放）若也在此探测，会把错误 ASBD 缓存进 g_targetASBD，
    // 导致后续解码/喂数据全部按错误采样率进行 → 听感"加快 + 不清晰"。
    if (inOutputBusNumber != 1) return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        OSStatus perr = AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, inOutputBusNumber,
                                 &g_targetASBD, &propSize);
        if (perr == noErr && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            if (!g_didLogProbe) {
                vcam_log(@"探测成功 bus=%u rate=%.0f ch=%u bits=%u flags=0x%x",
                      inOutputBusNumber, g_targetASBD.mSampleRate, g_targetASBD.mChannelsPerFrame,
                      g_targetASBD.mBitsPerChannel, g_targetASBD.mFormatFlags);
                g_didLogProbe = YES;
            }
            // 按 ASBD 分配环形缓冲（约 2 秒容量），并启动流式解码线程；不再整段解码，也不重建 AVCapture 的 reader。
            @try {
                UInt32 bps = (g_targetASBD.mBitsPerChannel ?: 16) / 8;
                size_t cap = (size_t)(g_targetASBD.mSampleRate * g_targetASBD.mChannelsPerFrame * bps * 2.0);
                if (cap > 0 && cap != g_audioRingCap) {
                    os_unfair_lock_lock(&g_audioRingLock);
                    if (g_audioRing) free(g_audioRing);
                    g_audioRing = (uint8_t *)malloc(cap);
                    g_audioRingCap = g_audioRing ? cap : 0;
                    g_audioRingHead = g_audioRingTail = g_audioRingFill = 0;
                    os_unfair_lock_unlock(&g_audioRingLock);
                    vcam_log(@"环形缓冲重建：cap=%zu 字节（约 2 秒）%@", g_audioRingCap, g_audioRing ? @"" : @"，malloc 失败！");
                }
                // 注意：此处不能用 !g_audioFeederStop 做门禁——vcm_reloadReaders（startRunning / 换素材时）
                // 会把 g_audioFeederStop 置 YES 来停掉旧解码线程；若不把它清回 NO，新会话的 feeder 永远起不来，
                // 环形缓冲为空 → 麦克风一路始终静音。是否已在跑只需由 g_audioFeederRunning 一个标志把关，
                // startAudioFeeder 内部会在真正启动前把 g_audioFeederStop 清回 NO。
                if (!g_audioFeederRunning) [VCamMediaManager startAudioFeeder];
            } @catch (NSException *e) {
                // 探测阶段出问题还没污染输出，吞掉异常让下帧重试即可，不关替换
                vcam_log(@"探测后启动 feeder 抛异常：%@", e);
            }
        } else {
            vcam_log(@"探测失败 bus=%u perr=%d rate=%.0f", inOutputBusNumber, (int)perr, g_targetASBD.mSampleRate);
        }
    }
    if (!g_hasProbedASBD) return status;

    // 对齐 VCAM4：每帧轻量校验 ASBD 是否较已缓存的变化（微信通话建立初期 bus=1 的真实格式
    // 往往晚于首次 AudioUnitRender 才落定）。若变化则清 g_hasProbedASBD 并停旧 feeder，
    // 强迫下一帧重新探测+重建 ring+重启 feeder，避免「首帧定死占位格式→永久按错格式解码→还是不清晰」。
    // VCAM4 反汇编确认其 GetProperty 在每次替换分支都重新执行（13f28-13f48，无缓存守卫）。
    {
        AudioStreamBasicDescription live = {0};
        UInt32 ps = sizeof(live);
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                kAudioUnitScope_Output, inOutputBusNumber, &live, &ps) == noErr
                && live.mSampleRate > 0
                && (live.mSampleRate        != g_targetASBD.mSampleRate
                    || live.mChannelsPerFrame  != g_targetASBD.mChannelsPerFrame
                    || live.mBitsPerChannel    != g_targetASBD.mBitsPerChannel
                    // 仅比较影响解码字节布局的语义位（float / non-interleaved），
                    // 忽略 PACKED/SIGNED 等位——它们不改变字节排布，避免无关位波动误触发清 ASBD→静音。
                    || ((live.mFormatFlags ^ g_targetASBD.mFormatFlags)
                        & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved)))) {
            vcam_log(@"ASBD 变更：%.0f/%u/%u/0x%x → %.0f/%u/%u/0x%x，触发重探测",
                  g_targetASBD.mSampleRate, (unsigned)g_targetASBD.mChannelsPerFrame, g_targetASBD.mBitsPerChannel, g_targetASBD.mFormatFlags,
                  live.mSampleRate, (unsigned)live.mChannelsPerFrame, live.mBitsPerChannel, live.mFormatFlags);
            g_hasProbedASBD = NO;  // 下一帧重新走探测+重建
            if (g_audioFeederRunning) g_audioFeederStop = YES;  // 停旧 feeder，迫使其用新 ASBD 重启
        }
    }

    // 自愈：feeder 必须每帧兜底确保“按需启动”，不能只依赖首帧探测块内的启动。
    // 换素材时 vcm_reloadReaders 会停掉正在跑的 feeder(g_audioFeederStop=YES) 并清 g_hasProbedASBD；
    // 若下一帧重探测成功、把 g_hasProbedASBD 重新置 YES 的那一瞬间，旧 feeder 的 @finally 还没把
    // g_audioFeederRunning 清回 NO，则探测块内的启动调用被 startAudioFeeder 的幂等守卫挡掉，
    // 而 g_hasProbedASBD 已为 YES 使探测块不再执行 → feeder 永远起不来、环恒空、永久静音。
    // 把“确保 feeder 运行”移到探测块之外，每帧兜底重启即可彻底消除该竞态（startAudioFeeder 内部幂等，
    // 且对 g_audioFeederRunning 为 YES 时直接 return，每帧调用零开销）。
    //
    // 严格一次性播放（g_isLoop==NO）：加上 g_isLoop 门控后，本块仅在循环开时兜底重启；
    // 循环关时 feeder 播完一遍自然退场(g_audioFeederRunning→NO)，本块不再拉起 → 真静音。
    // 首次/换素材后的那一次播放仍由探测块内 D.xm:842 无条件启动，保证“一次性”也能响。
    if (!g_audioFeederRunning && g_isLoop) {
        [VCamMediaManager startAudioFeeder];
    }

    UInt32 size = ioData->mBuffers[0].mDataByteSize;
    if (size == 0 || size > 0x100000) return status;

    // 对齐 VCAM4：环形缓冲内 PCM 的字节布局 = 微信 ioData->mBuffers[0..n] 的"顺序拼接"
    // （feeder 已按真实 ASBD 直出解码：non-interleaved 即 ch0段+ch1段+…，interleaved 即单段）。
    // 故这里只需按 mBuffers 顺序、每段 mDataByteSize 逐块 memcpy（对齐 VCAM 反汇编 14094-14114 拷贝循环），
    // 不做任何反交错/重排 —— VCAM4 正是靠"零变换直拷"规避交错错乱导致的失真。
    UInt32 nBuf = ioData->mNumberBuffers;
    if (nBuf == 0) return status;
    size_t need = 0;
    for (UInt32 i = 0; i < nBuf; i++) {
        if (ioData->mBuffers[i].mDataByteSize > 0x100000) return status;
        need += ioData->mBuffers[i].mDataByteSize;
    }
    if (need == 0 || need > 0x100000) return status;

    // 消费心跳：节流每 3 秒打一次，直接印环 fill，作为「消费者确实在取数」的铁证。
    // 一次性门禁会因启动瞬间 fill=0 提前触发、之后永久静默，反而掩盖了 feeder 喂上后的正常取数；
    // 改成周期采样后，只要出现「环fill=NNN/cap=64000 →有数据」即证明替换音频已流入麦克风。
    {
        static NSTimeInterval s_lastConsumeLog = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - s_lastConsumeLog >= 3.0) {
            os_unfair_lock_lock(&g_audioRingLock);
            size_t fill = g_audioRingFill;
            os_unfair_lock_unlock(&g_audioRingLock);
            vcam_log(@"消费心跳：bus=%u frames=%u need=%zu 环fill=%zu/cap=%zu %s",
                     inOutputBusNumber, (unsigned)inNumberFrames, need, fill, g_audioRingCap,
                     (fill > 0) ? "→有数据" : "→仍空(静音)");
            s_lastConsumeLog = now;
        }
    }

    uint8_t *temp = (uint8_t *)calloc(1, need);
    if (!temp) return status;
    @try {
        [VCamMediaManager pullAudioData:temp length:(UInt32)need];
        // 逐 buffer 顺序直拷：off 按 mBuffers 顺序累加，与 feeder 直出的布局严格对应（零变换，对齐 VCAM4）
        size_t off = 0;
        for (UInt32 i = 0; i < nBuf; i++) {
            AudioBuffer *b = &ioData->mBuffers[i];
            if (b->mData && b->mDataByteSize > 0 && off + b->mDataByteSize <= need) {
                memcpy(b->mData, temp + off, b->mDataByteSize);
                off += b->mDataByteSize;
            }
        }
        // 替换能量检测（每 3 秒一次）：直接扫描本帧写入 ioData 的替换音频，统计非零字节占比。
        // 占比≈0% → 环里是静音（feeder/转换器产出零，属数据源问题）；
        // 占比显著却仍无声 → 真实音频已写入 ioData 但通话不上传它，说明该 AudioUnitRender 的 ioData
        //   并非微信实际上传麦克风路径（交付/微信版本音频路径变更问题），需换 hook 点。
        {
            static NSTimeInterval s_lastEnergy = 0;
            NSTimeInterval t = [[NSDate date] timeIntervalSince1970];
            if (t - s_lastEnergy >= 3.0 && ioData && ioData->mBuffers[0].mData && size > 0) {
                uint8_t *p = (uint8_t *)ioData->mBuffers[0].mData;
                size_t nz = 0;
                for (UInt32 k = 0; k < size; k++) if (p[k] != 0) nz++;
                vcam_log(@"替换能量：bus=%u 写入%u字节 非零%zu字节(占比%.1f%%) %s",
                         inOutputBusNumber, size, nz, size ? (double)nz / size * 100.0 : 0.0,
                         nz * 100 >= size * 5 ? "→真实音频已写入ioData" : "→疑似静音(全零)");
                s_lastEnergy = t;
            }
        }
    } @catch (NSException *e) {
        // memcpy 阶段抛异常（极少见）时本帧已不可信，free 后返回 noErr 让 ioData 维持原样（真实麦克风），下帧重试。
        vcam_log(@"消费端 memcpy 异常：%@ — %@", e.name, e.reason);
    }
    free(temp);
    return noErr;
}

#pragma mark - VCamVideoProxy（相机采集替换）
@interface VCamVideoProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation VCamVideoProxy {
    __weak id _originalDelegate;
}
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue { _originalDelegate = delegate; }

// 采集回调里取替换帧 → 塞进预览显示层 → 再转发给原 delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    g_videoOrientation = connection.videoOrientation;
    {
        // 链路激活留痕：确认宿主 App 走的是 AVCaptureVideoDataOutput（画面）链路
        static BOOL didLogVA = NO;
        if (!didLogVA) { vcam_log(@"视频采集链路激活（AVCaptureVideoDataOutput 回调已触发）"); didLogVA = YES; }
    }

    CMSampleBufferRef newSample = NULL;
    if (g_isReplace) {
        @try {
            newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
            // 有替换帧且显示层就绪 → flush 丢掉未显示的旧帧保证低延迟 → 入队
            if (newSample && g_displayLayer && g_displayLayer.isReadyForMoreMediaData) {
                [g_displayLayer flush];
                [g_displayLayer enqueueSampleBuffer:newSample];
            }
        } @catch (NSException *e) {
            // 取帧/合成异常时本帧透传真实摄像头，下帧重试，不关替换
            vcam_log(@"视频代理异常：%@ — %@", e.name, e.reason);
            newSample     = NULL;
        }
    }

    if (_originalDelegate &&
        [_originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [_originalDelegate captureOutput:output
                    didOutputSampleBuffer:(newSample ?: sampleBuffer)
                           fromConnection:connection];
    }
    if (newSample) CFRelease(newSample);
}
@end
static VCamVideoProxy *g_videoProxy = nil;

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    if (!g_videoProxy) g_videoProxy = [[VCamVideoProxy alloc] init];
    [g_videoProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_videoProxy, queue);
}
%end

#pragma mark - VCamAudioProxy（AVCapture 音频采集替换）
@interface VCamAudioProxy : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation VCamAudioProxy {
    __weak id _origDelegate;
}
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue { _origDelegate = delegate; }

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    {
        // 链路激活留痕：若出现此日志，说明该 App 的音频走了 AVCaptureAudioDataOutput（CMSampleBuffer）链路
        // 而非 AudioUnitRender——两条链路都要替换才能覆盖所有 App；这也是诊断“该走哪条”的直接证据。
        static BOOL didLogAA = NO;
        if (!didLogAA) { vcam_log(@"AVCapture 音频链路激活（AVCaptureAudioDataOutput 回调已触发）"); didLogAA = YES; }
    }
    CMSampleBufferRef outBuf = sampleBuffer;

    if (g_isReplace && g_isSound) {
        // 取帧/异常时透传真实麦克风（outBuf 维持原样），下帧重试，不关替换
        @try {
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer];
            if (rep) outBuf = rep;
        } @catch (NSException *e) {
            vcam_log(@"音频代理异常：%@ — %@", e.name, e.reason);
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
    if (!g_audioProxy) g_audioProxy = [[VCamAudioProxy alloc] init];
    [g_audioProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_audioProxy, queue);
}
%end


#pragma mark - AVCaptureSession（会话起停）
%hook AVCaptureSession
- (void)startRunning {
    // 新会话的麦克风格式可能是另一套（采样率/位深随通话类型变），不把旧的 g_targetASBD 清掉会沿用上一通格式去解码。
    vcam_log(@"AVCaptureSession startRunning（会话重启，将 reloadReaders）");
    vcm_reloadReaders();
    if (g_isReplace) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    %orig;
}
- (void)stopRunning {
    // 这里只清标志、不 reload。stopRunning 后链路可能还在收尾取帧，此时清 reader 会打断它；
    // 内存 PCM 留着，等下次 startRunning 再清。
    %orig;
}
%end

#pragma mark - AVCaptureVideoPreviewLayer（叠加预览显示层）
// 预览叠加层用 AVSampleBufferDisplayLayer 而非普通 CALayer：帧由采集回调 enqueue，播放节奏由素材自身 PTS 决定。
%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer {
    %orig;

    // displayLink 只建一次，target 就是当前 preview layer
    if (!g_displayLink) {
        g_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(vcm_step:)];
        [g_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
    if (![[self sublayers] containsObject:g_displayLayer]) {
        g_displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        [self insertSublayer:g_displayLayer above:layer];
        dispatch_async(dispatch_get_main_queue(), ^{ g_displayLayer.frame = self.bounds; });
    }
}

// 每帧同步显示层的可见性、填充模式、位置和旋转。不在这里取帧——取帧由采集回调驱动，这里只负责把显示层跟采集层状态对齐。
%new
- (void)vcm_step:(CADisplayLink *)link {
    if (!g_displayLayer) return;

    // 素材不存在或不替换时把显示层透明掉，露出真实摄像头
    BOOL show = g_isReplace && [g_fileManager fileExistsAtPath:vcm_videoPath()];
    [g_displayLayer setOpacity:(show ? 1.0f : 0.0f)];
    if (!show) return;

    [g_displayLayer setVideoGravity:[self videoGravity]];
    [g_displayLayer setFrame:self.bounds];

    // AVSampleBufferDisplayLayer 不会像 AVCaptureVideoPreviewLayer 那样自动跟随连接方向，必须按 videoOrientation 手动补偿。
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

#pragma mark - VCamMenuVC（控制菜单界面）
@interface VCamMenuVC : UIViewController
    <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>
@end

@implementation VCamMenuVC {
    UIView   *_panelView;      // 面板容器
    UIView   *_contentView;    // 面板内的内容区（状态栏 + 按钮网格）
    UILabel  *_statusLabel;    // 素材状态文案
    UIButton *_btnRotate;      // 旋转（循环取值，非开关）
    UIButton *_btnLoop;        // g_isLoop
    UIButton *_btnSound;       // g_isSound
    UIButton *_btnMirror;      // g_isMirrored
    UIButton *_btnReplace;     // g_isReplace
    UIButton *_btnReset;
    UIButton *_btnExport;       // 导出诊断日志       // 重置
}

#pragma mark - 生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupBackground];
    [self setupPanel];
    [self setupNavBar];
    [self setupContent];
    [self setupButtons];
    [self updateStatusUI];
}

#pragma mark - UI 构建（透明背景 + 深色面板，透明背景下天然形成边界对比）
- (void)setupBackground {
    self.view.backgroundColor = [UIColor clearColor];
}
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
    _btnMirror = [self addGridButton:g_isMirrored ? @"镜像: 开" : @"镜像: 关"
                                  x:btnW + gap y:y w:btnW h:btnH action:@selector(toggleMirror)];
    y += btnH + gap;

    _btnReplace = [self addGridButton:g_isReplace ? @"替换: 开" : @"替换: 关"
                   x:0 y:y w:btnW h:btnH action:@selector(toggleReplace)];
    _btnReset  = [self addGridButton:@"重置" x:btnW + gap y:y w:btnW h:btnH action:@selector(actionReset)];
    y += btnH + gap;

    // 导出日志：占满整行（两列总宽），点击把 g_diagLog 经系统分享面板导出
    _btnExport = [self addGridButton:@"导出日志" x:0 y:y w:(btnW * 2 + gap) h:btnH action:@selector(actionExportLog)];
    y += btnH + gap;

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作（开关统一 toggleXxx，动作统一 actionXxx）
- (void)toggleRotate  { g_rotation   = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop    { g_isLoop     = !g_isLoop;     vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound   { g_isSound    = !g_isSound;    vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleMirror  { g_isMirrored = !g_isMirrored; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleReplace { g_isReplace  = !g_isReplace;  vcm_saveSettings(); [self refreshGridButtons]; }
- (void)actionReset   { vcm_resetSettings(); [self refreshGridButtons]; }

#pragma mark - 诊断日志导出
// 面板“导出日志”按钮：把 g_diagLog（带时间戳）写成临时文件，经 UIActivityViewController 分享出去
// （隔空投送 / 存储到文件 / 微信自己都行），免得再连 Xcode 抓系统日志。
- (void)actionExportLog {
    os_unfair_lock_lock(&g_diagLock);
    NSString *content = g_diagLog ? [g_diagLog copy] : @"";
    os_unfair_lock_unlock(&g_diagLock);
    if (content.length == 0) {
        [self flashStatus:@"暂无诊断日志：请先发起一次视频通话，再回来导出"];
        return;
    }
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"VCAM-D-diag.log"];
    NSError *err = nil;
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        [self flashStatus:[NSString stringWithFormat:@"写日志失败：%@", err.localizedDescription]];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *avc =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        avc.popoverPresentationController.sourceView = _btnExport;
        avc.popoverPresentationController.sourceRect = _btnExport.bounds;
    }
    [self presentViewController:avc animated:YES completion:nil];
}
// 临时改写状态文案，3 秒后自动恢复素材状态
- (void)flashStatus:(NSString *)msg {
    if (!_statusLabel) return;
    _statusLabel.text = msg;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self updateStatusUI]; });
}

#pragma mark - 面板刷新
// UIButtonConfiguration 取出来是副本，改完必须整体赋值回写
- (void)applyTitle:(NSString *)title toButton:(UIButton *)btn withFont:(UIFont *)font {
    if (!btn) return;
    UIButtonConfiguration *config = btn.configuration;
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
        attributes:@{NSFontAttributeName: font}];
    btn.configuration = config;
}
// 刷新顺序与面板网格一致：旋转 → 循环 → 声音 → 镜像 → 替换
- (void)refreshGridButtons {
    UIFont *font = [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightMedium];
    [self applyTitle:[NSString stringWithFormat:@"旋转 (%d°)", g_rotation]
            toButton:_btnRotate withFont:font];
    [self applyTitle:(g_isLoop     ? @"循环: 开" : @"循环: 关") toButton:_btnLoop    withFont:font];
    [self applyTitle:(g_isSound    ? @"声音: 开" : @"声音: 关") toButton:_btnSound   withFont:font];
    [self applyTitle:(g_isMirrored ? @"镜像: 开" : @"镜像: 关") toButton:_btnMirror  withFont:font];
    [self applyTitle:(g_isReplace  ? @"替换: 开" : @"替换: 关") toButton:_btnReplace withFont:font];
    [self updateStatusUI];
}
- (void)updateStatusUI {
    NSString *vStat = [g_fileManager fileExistsAtPath:vcm_videoPath()] ? @"已加载" : @"未选择";
    _statusLabel.text = [NSString stringWithFormat:@"视频: %@", vStat];
}
- (void)closeMenu { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - 文件选择
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
    if (!src || ![g_fileManager fileExistsAtPath:src]) { vcam_log(@"导入失败：源文件不存在 %@", url.path); return; }
    AVAsset *asset  = [AVAsset assetWithURL:url];
    BOOL hasVideo = [[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0;
    BOOL hasAudio  = [[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0;
    // 素材音轨详情留痕：采样率/编码 FourCC——出现「startReading 失败/无音轨」时第一时间能对照格式找原因
    AVAssetTrack *aTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    if (aTrack) {
        double sampleRate = 0; NSString *fourCC = @"未知";
        CMFormatDescriptionRef fd = (__bridge CMFormatDescriptionRef)aTrack.formatDescriptions.firstObject;
        if (fd) {
            FourCharCode sub = CMFormatDescriptionGetMediaSubType(fd);
            char cc[5] = { (char)(sub >> 24), (char)(sub >> 16), (char)(sub >> 8), (char)sub, 0 };
            fourCC = [NSString stringWithUTF8String:cc] ?: @"未知";
            const AudioStreamBasicDescription *asd = CMAudioFormatDescriptionGetStreamBasicDescription(fd);
            if (asd) sampleRate = asd->mSampleRate;
        }
        vcam_log(@"导入素材：hasVideo=%d hasAudio=%d 时长=%.1fs 音轨率=%.0fHz 编码=%@",
                 (int)hasVideo, (int)hasAudio,
                 aTrack.timeRange.duration.value / (double)aTrack.timeRange.duration.timescale,
                 sampleRate, fourCC);
    } else {
        vcam_log(@"导入素材：hasVideo=%d hasAudio=0（无音轨）", (int)hasVideo);
    }
    // reloadReaders 会清掉 g_hasProbedASBD，迫使下一帧重新探测 ASBD 并重新解码，否则新素材音频不生效。
    vcm_reloadReaders();
    NSError *copyErr = nil;
    if (hasVideo) {
        NSString *dest = vcm_videoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        BOOL copied = [g_fileManager copyItemAtPath:src toPath:dest error:&copyErr];
        vcam_log(@"素材拷贝%@", copied ? @"成功" : [NSString stringWithFormat:@"失败：%@", copyErr.localizedDescription]);
        if (!copied) return;
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭、且旧 reader 已读完，setup 里的 loop 门禁会把重建挡掉，新素材就永远不生效。
        vcm_stopReaders();
        g_isReplace = YES;
        vcm_saveSettings();
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        if ([g_fileManager fileExistsAtPath:g_tempAudioPath]) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
        BOOL copied = [g_fileManager copyItemAtPath:src toPath:g_tempAudioPath error:&copyErr];
        vcam_log(@"音频拷贝%@", copied ? @"成功" : [NSString stringWithFormat:@"失败：%@", copyErr.localizedDescription]);
        if (!copied) return;
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    [self refreshGridButtons];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];

    NSURL *url = info[UIImagePickerControllerMediaURL];
    if (url) { [self processSelectedVideoURL:url]; return; }
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - UIDocumentPickerDelegate
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
static void vcm_installTapGesture(UIWindow *win) {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:win action:@selector(vcm_presentMenu)];
    tap.numberOfTapsRequired    = 2;
    tap.numberOfTouchesRequired = 2;
    tap.cancelsTouchesInView    = NO;
    [win addGestureRecognizer:tap];
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
// 初始化全局状态、沙箱目录、音视频 reader
%ctor {
    g_fileManager = [NSFileManager defaultManager];
    g_mediaLock   = [[NSLock alloc] init];
    vcm_loadSettings();
    g_ciContext = [CIContext contextWithOptions:@{
        kCIContextWorkingColorSpace: [NSNull null],
    }];
    g_videoDir = [vcm_documentPath() stringByAppendingPathComponent:@"VCAM"];
    [g_fileManager createDirectoryAtPath:g_videoDir withIntermediateDirectories:YES attributes:nil error:nil];
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];

    if ([g_fileManager fileExistsAtPath:vcm_videoPath()]) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    // 改用 fishhook 的 rebind_symbols 重定向 AudioUnitRender（原版 VCAM.dylib 即此方案）。
    // 与 MSHookFunction((void*)AudioUnitRender,...) 不同：fishhook 通过 dyld 遍历“已加载 + 后续加载”的
    // 镜像、直接改写 __DATA/__DATA_CONST 里的间接符号指针，不依赖构造时取址；即使构造期 AudioToolbox
    // 尚未 bound、或 hooking 库（substrate/ellekit/libhooker）注入顺序异常，也能在对应镜像就绪后正确接管，
    // 从根上消除“MSHookFunction 静默失败 → hook=0 → 整条音频链路不触发”的问题。
    dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_NOW);
    struct rebinding reb = {
        "AudioUnitRender",
        (void *)hooked_AudioUnitRender,
        (void **)&g_origAudioUnitRender,
    };
    int rc = rebind_symbols(&reb, 1);
    if (rc != 0 || g_origAudioUnitRender == NULL) {
        // rebind_symbols 失败或 AudioUnitRender 未在任意已加载镜像中导出：原始函数指针未回填，
        // hooked_AudioUnitRender 永不触发。常见根因：hooking 库（substrate/ellekit/libhooker）未正确
        // 初始化、或注入顺序异常；需 respring / iCleaner 重启后重装确认。
        void *at = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_NOLOAD);
        vcam_log(@"警告：rebind_symbols(AudioUnitRender) 未生效 g_origAudioUnitRender=%p rc=%d（音频替换全链路不触发） AudioToolbox=%@",
                 (void *)g_origAudioUnitRender, rc, (at ? @"已加载" : @"未加载"));
        if (at) dlclose(at);
    }
    // 初始化完成日志延迟 2s 输出：让 AudioToolbox 真正就绪、dyld 回调完成重定向后再判定 hook 状态，
    // 避免构造期镜像未加载导致的 hook=0 假阴性（fishhook 会在镜像加载后异步补上重定向）。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        vcam_log(@"初始化完成：目录=%@ 素材=%@ tempAudio=%@ 替换=%d 声音=%d 循环=%d hook=%d",
                 g_videoDir, @([g_fileManager fileExistsAtPath:vcm_videoPath()]),
                 @([g_fileManager fileExistsAtPath:g_tempAudioPath]),
                 (int)g_isReplace, (int)g_isSound, (int)g_isLoop,
                 (int)(g_origAudioUnitRender != NULL));
    });
}

%dtor {
    [VCamMediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

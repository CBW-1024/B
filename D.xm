// VCAM — 相机画面与麦克风声音的虚拟替换插件（Theos / Logos）
//
// 功能：把任意 App（微信 / 相机 / 任意走标准采集管线的 App）的相机画面与麦克风声音，
// 替换成用户从相册或文件导入的本地视频 / 音频素材。
// 双指双击任意窗口弹出控制面板，导入素材并开关各项替换。
//
// 素材模型为「视频 + 声音」双层：
//   · 导入视频 → 画面用视频，音频默认用视频自带音轨；
//   · 再导入声音文件 → 音频改用声音文件（画面仍由视频提供）；
//   · 只导入声音 → 仅替换麦克风声音，无画面。
//
// 拦截三条采集通道（均为框架级 hook，覆盖所有标准采集 App）：
//   ① AVCaptureVideoDataOutput  画面采集回调
//   ② AVCaptureAudioDataOutput  音频采集回调
//   ③ AudioUnitRender           视频通话的麦克风采集（裸 PCM 字节流）
// 前两条投递 CMSampleBuffer，第三条是裸 PCM，故音频有两套实现；
// 其中 AudioUnit 链路采用「整段预解码进内存 + 只读游标顺序推进」的方式，
// 音频在播放前一次性解码完毕，消费期间 PCM 恒定不变、永不被覆盖，从根本上保证清晰度。
//
// 画面流向：素材 → AVAssetReader 取帧 → 旋转 / 等比居中 → 合成到与采集帧同尺寸黑底 →
// CIContext 渲染成同格式 CVPixelBuffer → 套用采集帧时序 → 新的 CMSampleBuffer。
//
// 容错约定：取帧 / 合成 / 音频拉取均运行在实时线程，单帧失败仅本帧降级
// （返回 NULL / 透传真实音视频 / 补零静音），下帧自动重试，不置全局标志、不关总开关。
// g_mediaLock 为不可重入 NSLock，持锁函数内不得再调用会加锁的函数；
// 含提前 return 的函数必须用 @finally 解锁，否则异常路径会漏解锁导致后续卡死。
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
// fishhook：C 级符号重定向，通过 dyld 改写间接符号指针实现 hook。
#include "fishhook.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>

#pragma mark - 配置开关
static BOOL g_isReplace  = NO;      // 默认关：无素材时透传真实摄像头/麦克风；导入素材后自动开启
static BOOL g_isLoop     = YES;     // 素材读完后是否回卷重播
static BOOL g_isSound    = YES;     // 是否替换麦克风采集
static int  g_rotation   = 90;      // 0 / 90 / 180 / 270（点击旋转按钮循环取值）

#pragma mark - reader 重建标记
// 置位后由下一帧开头重建对应 reader；不在取帧失败的同帧重建（刚 startReading 的 reader 首帧必取不到）。
static BOOL g_videoReload = NO;
static BOOL g_audioReload = NO;

#pragma mark - 沙箱路径
static NSString *g_videoDir       = nil;
static NSString *g_tempAudioPath  = nil;   // 独立声音文件（扩展名随导入文件动态变化）
static NSString *g_videoPath      = nil;   // 视频素材（扩展名随导入文件动态变化）

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

#pragma mark - 音频预解码缓冲（整段预解码进内存 + 顺序游标回卷）
// 整段音频一次性解码进内存，消费端按读游标顺序取用、到尾按 g_isLoop 回卷，期间零写入。
// 因解码在播放前完成、消费期间 PCM 不被任何写入覆盖，从架构上保证连续性，是清晰度的根本保证。
static uint8_t       *g_audioPCM      = NULL;  // 整段预解码 PCM
static size_t         g_audioPCMLen   = 0;     // PCM 总字节数
static size_t         g_audioPCMRead  = 0;     // 读游标（顺序推进；g_isLoop 时到尾回卷 0）
static os_unfair_lock g_audioPCMLock  = OS_UNFAIR_LOCK_INIT;
static BOOL           g_audioPCMReady = NO;    // 预解码完成才取数；未就绪则补零静音
static AudioStreamBasicDescription g_audioPCMFormat = {0};  // 预解码所用 ASBD（变更即需重解码）
static NSUInteger     g_audioDecodeGen = 0;    // 解码代次：换素材/ASBD 变更时自增，作废在途解码结果
static BOOL           g_audioFeederRunning = NO;  // 预解码线程是否在跑
static BOOL           g_audioFeederStop    = NO;  // 通知预解码线程取消
// 解码失败退避：自愈块每帧都会检查「PCM 未就绪」并重启解码。若解码必然失败（素材损坏 / outputSettings 非法），
// 会变成每帧拉起一个解码线程拖垮实时音频线程，故按 0.5s×次数（上限 5s）退避。
static int            g_decodeFailCount  = 0;
static NSTimeInterval g_decodeNextRetry  = 0;
static const size_t   kAudioPCMMaxBytes = 64u * 1024u * 1024u;  // 64MB 上限，防极端长素材 OOM

#pragma mark - AudioUnit 采集状态
static BOOL                        g_hasProbedASBD = NO;
static AudioStreamBasicDescription g_targetASBD    = {0};  // 麦克风真实 ASBD，即音频解码的目标格式

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
    return g_videoPath;
}

#pragma mark - 配置存取
static void vcm_saveSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:g_isReplace   forKey:@"vcam_replace"];
    [d setBool:g_isLoop      forKey:@"vcam_loop"];
    [d setBool:g_isSound     forKey:@"vcam_sound"];
    [d setInteger:g_rotation forKey:@"vcam_rotation"];
    // 音视频素材路径持久化：扩展名随导入文件动态变化，不存盘则重启后找不到文件。
    if (g_videoPath) [d setObject:g_videoPath forKey:@"vcam_video_path"];
    else             [d removeObjectForKey:@"vcam_video_path"];
    [d setObject:g_tempAudioPath forKey:@"vcam_audio_path"];
    [d synchronize];
}
static void vcm_loadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"vcam_replace"])  g_isReplace = [d boolForKey:@"vcam_replace"];
    if ([d objectForKey:@"vcam_loop"])     g_isLoop    = [d boolForKey:@"vcam_loop"];
    if ([d objectForKey:@"vcam_sound"])    g_isSound   = [d boolForKey:@"vcam_sound"];
    if ([d objectForKey:@"vcam_rotation"]) g_rotation  = (int)[d integerForKey:@"vcam_rotation"];
    else                                   g_rotation  = 90;
    // 恢复素材路径：存在则用持久化路径（动态扩展名），否则回退默认名（由 %ctor 在 loadSettings 前给定）。
    NSString *savedVideo = [d stringForKey:@"vcam_video_path"];
    if (savedVideo.length > 0) g_videoPath = [savedVideo copy];
    NSString *savedAudio = [d stringForKey:@"vcam_audio_path"];
    if (savedAudio.length > 0) g_tempAudioPath = [savedAudio copy];
}

#pragma mark - 停止 reader 与重置
static void vcm_stopReaders(void) {
    [g_mediaLock lock];
    if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
    if (g_audioReader) { [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil; }
    if (g_lastVideoPixel) { CVPixelBufferRelease(g_lastVideoPixel); g_lastVideoPixel = NULL; }
    [g_mediaLock unlock];
}
// 换素材 / 会话重启时让两条链路从头来过。关键是清 g_hasProbedASBD：
// 不清则麦克风链路认为格式已探测完，既不重新探测新会话 ASBD 也不重新解码，新素材音频进不了麦克风。
static void vcm_reloadReaders(void) {
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
    // 自增代次作废在途解码结果，释放旧 PCM 并取消解码线程（持锁释放，避免与消费端竞争）。
    g_audioDecodeGen++;
    g_decodeFailCount = 0;
    g_decodeNextRetry = 0;
    os_unfair_lock_lock(&g_audioPCMLock);
    g_audioFeederStop = YES;
    if (g_audioPCM) { free(g_audioPCM); g_audioPCM = NULL; }
    g_audioPCMLen   = 0;
    g_audioPCMRead  = 0;
    g_audioPCMReady = NO;
    os_unfair_lock_unlock(&g_audioPCMLock);
}
// 恢复默认设置，清空已选素材与解码缓存
static void vcm_resetSettings(void) {
    g_isReplace   = NO;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_rotation    = 90;
    vcm_saveSettings();

    vcm_stopReaders();
    vcm_reloadReaders();

    if (g_tempAudioPath) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
    // 删掉所有 bear_vcam_audio.* 残留（动态扩展名后可能不止 .m4a）
    for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
        if ([old hasPrefix:@"bear_vcam_audio."]) {
            [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
        }
    }
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    // 删掉所有 bear_vcam_temp.* 残留（动态扩展名后可能不止 .mov）
    for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
        if ([old hasPrefix:@"bear_vcam_temp."]) {
            [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
        }
    }
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
+ (void)decodeAudioToMemory;   // 整段音频一次性预解码进内存（非流式）
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length;  // 顺序推进读游标 + 到尾按 g_isLoop 回卷
+ (void)cleanup;
@end

#pragma mark - 音频解码
// 解码直接按真实 ASBD 产出，由 AVAssetReader 的 outputSettings 在解码器内部完成
// 重采样 / 重排到微信真实 ASBD 格式，全程不经过任何外部 AudioConverter 重采样层。
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
                [g_videoReader startReading];
            }
        }
    } @catch (NSException *e) {
        // 取帧失败仅降级，下帧重试；不可在此上抛异常，否则会沿采集栈崩溃宿主 App。
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
                [g_audioReader startReading];
            }
        }
        // ASBD 探明后 AudioUnit 链路才需要数据：触发整段预解码（幂等，已在跑或已就绪则忽略）。
        if (g_hasProbedASBD) [self decodeAudioToMemory];
    } @catch (NSException *e) {
    } @finally {
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 整段预解码：一次性把素材音频全部解码成目标格式 PCM 存进内存，之后消费端只读游标推进、期间零写入。
// 触发时机（幂等，重复调用无副作用）：
//   ① 首次探测到 ASBD；② 换素材（reloadReaders 作废 PCM）；③ ASBD 变更（格式不符需按新格式重解码）。
+ (void)decodeAudioToMemory {
    if (!g_hasProbedASBD)     return;
    if (g_audioPCMReady)      return;   // 已解码且素材/格式未变，无需重来
    if (g_audioFeederRunning) return;   // 幂等：解码线程已在跑
    if ([[NSDate date] timeIntervalSince1970] < g_decodeNextRetry) return;  // 退避期内不重启
    g_audioFeederStop   = NO;
    g_audioFeederRunning = YES;
    NSUInteger myGen = g_audioDecodeGen;   // 代次快照：期间若换素材/ASBD 变更，本轮结果作废

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            @autoreleasepool {
                NSString *path = g_tempAudioPath;
                // 双素材语义：独立声音文件优先，否则回退到视频自带音轨。
                BOOL usedVideoFallback = ![g_fileManager fileExistsAtPath:path];
                if (usedVideoFallback) path = vcm_videoPath();

                // 换素材窗口可能旧文件已删、新文件未就位，轮询等待而非退出（避免静音）。
                int waitRetry = 0;
                while (!g_audioFeederStop && ![g_fileManager fileExistsAtPath:path]) {
                    [NSThread sleepForTimeInterval:0.2];
                    if (++waitRetry > 150) return;  // 30s 超时放弃
                }
                if (g_audioFeederStop) return;
                if (![g_fileManager fileExistsAtPath:path]) return;

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

                // 解码目标格式严格跟随真实 ASBD（rate/ch/bits/float/non-interleaved）。
                // AVSampleRateKey 必须设置：素材原生率≠目标率时由解码器内部完成重采样，
                // 不写则该键会按素材原采样率直出，被塞进目标率 buffer 后语速/音调全乱。
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

                // 一次性读完，累积进 NSMutableData（超过 64MB 上限截断，防 OOM）。
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

                // 落地前再校验一次代次；无产出则计入退避，避免每帧重启拖垮实时线程。
                if (myGen != g_audioDecodeGen) return;
                if (g_audioFeederStop || acc.length == 0) {
                    if (acc.length == 0 && !g_audioFeederStop) {
                        g_decodeFailCount++;
                        g_decodeNextRetry = [[NSDate date] timeIntervalSince1970]
                                          + ((0.5 * g_decodeFailCount > 5.0) ? 5.0 : 0.5 * g_decodeFailCount);
                    }
                    return;
                }

                // 落地：分配并拷贝整段 PCM，读游标归零，标记就绪（消费端自此开始顺序读取）。
                size_t   total = acc.length;
                uint8_t *buf   = (uint8_t *)malloc(total);
                if (!buf) return;
                memcpy(buf, acc.bytes, total);

                os_unfair_lock_lock(&g_audioPCMLock);
                if (g_audioPCM) free(g_audioPCM);
                g_audioPCM       = buf;
                g_audioPCMLen    = total;
                g_audioPCMRead   = 0;
                g_audioPCMReady  = YES;
                g_audioPCMFormat = t;
                os_unfair_lock_unlock(&g_audioPCMLock);
                g_decodeFailCount = 0;
                g_decodeNextRetry = 0;
            }
        } @catch (NSException *e) {
            // 异常多半是素材不可解析，重试同样失败，计入退避避免每帧重启。
            g_decodeFailCount++;
            g_decodeNextRetry = [[NSDate date] timeIntervalSince1970]
                              + ((0.5 * g_decodeFailCount > 5.0) ? 5.0 : 0.5 * g_decodeFailCount);
        } @finally {
            g_audioFeederRunning = NO;
        }
    });
}

// 消费者（实时安全）：从预解码 PCM 按读游标顺序取 length 字节；
// 游标到尾时按 g_isLoop 回卷重播，否则补零静音（严格一次性播放）。
// 本函数只读、不修改 PCM，且写入方就绪后不再写入 → 消费期间 PCM 恒定不变、相邻取数严格连续。
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    if (!outData || length == 0) return;
    if (length > 0x100000) { memset(outData, 0, length); return; }  // 超大请求直接静音
    if (!g_audioPCMReady || !g_audioPCM || g_audioPCMLen == 0) { memset(outData, 0, length); return; }

    os_unfair_lock_lock(&g_audioPCMLock);
    size_t written = 0;
    while (written < length) {
        size_t avail = (g_audioPCMLen > g_audioPCMRead) ? (g_audioPCMLen - g_audioPCMRead) : 0;
        if (avail == 0) {
            if (g_isLoop) { g_audioPCMRead = 0; continue; }  // 回卷重播
            break;  // 一次性播放：余下补零静音
        }
        size_t n = (length - written < avail) ? (length - written) : avail;
        memcpy(outData + written, g_audioPCM + g_audioPCMRead, n);
        g_audioPCMRead += n;
        written += n;
    }
    os_unfair_lock_unlock(&g_audioPCMLock);

    if (written < length) memset(outData + written, 0, length - written);
}

// 从音频 reader 取一帧，套用采集帧的时序后返回（调用方负责 CFRelease）。
// setupAudioReaderIfNeeded 内部也会加 g_mediaLock，而 NSLock 不可重入，故重建动作须在此之前完成。
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample {
    if (g_audioReload) [self setupAudioReaderIfNeeded];

    CMSampleBufferRef s = NULL;
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (g_audioOutput) s = [g_audioOutput copyNextSampleBuffer];
        }
    } @catch (NSException *e) {
    } @finally {
        [g_mediaLock unlock];
    }

    if (!s) { g_audioReload = YES; return NULL; }  // 取不到帧就标重建，留给下一帧

    CMSampleBufferRef out = NULL;
    @try {
        CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        if (origSample && CMSampleBufferGetSampleTimingInfo(origSample, 0, &timing) == noErr) {
            CMSampleBufferRef tmp = NULL;
            if (CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, s, 1, &timing, &tmp) == noErr && tmp) {
                out = tmp;
            }
        }
    } @catch (NSException *e) {
        CFRelease(s);
        return NULL;
    }
    if (out) CFRelease(s); else out = s;
    return out;
}

// 取下一帧源视频：读完时按 g_isLoop 决定回卷重播还是冻结末帧，返回 +1 引用
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

+ (CVPixelBufferRef)nextSourcePixel {
    if (g_videoReload) [self setupVideoReaderIfNeeded];

    CVPixelBufferRef frame = vcm_pullVideoFrame();
    if (!frame) g_videoReload = YES;  // 取不到帧就标重建，由下一帧处理

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

    // 旋转映射：对无 EXIF 元数据的相机帧，屏幕观感与 orientation 数值相反，故 90↔270 对调，
    // 使点「旋转」时屏幕转向与直觉一致（90°=顺时针、270°=逆时针）。
    NSInteger orient = 1;
    if      (g_rotation == 90)  orient = 8;
    else if (g_rotation == 180) orient = 3;
    else if (g_rotation == 270) orient = 6;
    img = [img imageByApplyingOrientation:(CGImagePropertyOrientation)orient];

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

// 渲染成新的 CMSampleBuffer，沿用采集帧的时序与 Exif/TIFF 附件
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
    // 没选素材就原样透传；素材存在但取帧失败才走黑帧兜底。
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    CMSampleBufferRef out = NULL;
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
        if (out) { CFRelease(out); out = NULL; }  // 合成/渲染异常本帧透传真实摄像头
    }
    return out;
}

+ (void)cleanup {
    g_audioDecodeGen++;                 // 作废在途预解码结果
    g_audioFeederStop = YES;            // 通知预解码线程取消
    vcm_stopReaders();
    os_unfair_lock_lock(&g_audioPCMLock);
    if (g_audioPCM) { free(g_audioPCM); g_audioPCM = NULL; }
    g_audioPCMLen   = 0;
    g_audioPCMRead  = 0;
    g_audioPCMReady = NO;
    os_unfair_lock_unlock(&g_audioPCMLock);
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
    // 严格只处理麦克风上行总线 bus==1。其它总线（如扬声器回放）若也在此探测，
    // 会把错误 ASBD 缓存进 g_targetASBD，导致解码/喂数据按错误采样率进行 → 变速失真。
    if (inOutputBusNumber != 1) return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        OSStatus perr = AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, inOutputBusNumber,
                                 &g_targetASBD, &propSize);
        if (perr == noErr && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            // ASBD 探明后即触发「整段预解码进内存」。若已解码但 PCM 格式与当前 ASBD 不符
            // （换通话类型/格式切换），先作废旧 PCM 再按新格式重解码，否则字节布局错配 → 失真/变速。
            @try {
                if (g_audioPCMReady &&
                    (g_audioPCMFormat.mSampleRate       != g_targetASBD.mSampleRate
                     || g_audioPCMFormat.mChannelsPerFrame != g_targetASBD.mChannelsPerFrame
                     || g_audioPCMFormat.mBitsPerChannel   != g_targetASBD.mBitsPerChannel
                     || ((g_audioPCMFormat.mFormatFlags ^ g_targetASBD.mFormatFlags)
                         & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved)))) {
                    g_audioDecodeGen++;
                    os_unfair_lock_lock(&g_audioPCMLock);
                    if (g_audioPCM) { free(g_audioPCM); g_audioPCM = NULL; }
                    g_audioPCMLen   = 0;
                    g_audioPCMRead  = 0;
                    g_audioPCMReady = NO;
                    os_unfair_lock_unlock(&g_audioPCMLock);
                }
                if (!g_audioFeederRunning) [VCamMediaManager decodeAudioToMemory];
            } @catch (NSException *e) {
            }
        }
    }
    if (!g_hasProbedASBD) return status;

    // 每帧轻量校验 ASBD 是否较已缓存的变化（微信通话初期 bus=1 真实格式往往晚于首次回调才落定）。
    // 若变化则清 g_hasProbedASBD、作废 PCM 并停旧解码线程，强迫下一帧重新探测 + 重解码。
    // 仅比较影响解码字节布局的语义位（float / non-interleaved），忽略 PACKED/SIGNED 等不改变排布的位。
    {
        AudioStreamBasicDescription live = {0};
        UInt32 ps = sizeof(live);
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                kAudioUnitScope_Output, inOutputBusNumber, &live, &ps) == noErr
                && live.mSampleRate > 0
                && (live.mSampleRate        != g_targetASBD.mSampleRate
                    || live.mChannelsPerFrame  != g_targetASBD.mChannelsPerFrame
                    || live.mBitsPerChannel    != g_targetASBD.mBitsPerChannel
                    || ((live.mFormatFlags ^ g_targetASBD.mFormatFlags)
                        & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved)))) {
            g_hasProbedASBD = NO;  // 下一帧重新走探测+重建
            g_audioDecodeGen++;
            os_unfair_lock_lock(&g_audioPCMLock);
            if (g_audioPCM) { free(g_audioPCM); g_audioPCM = NULL; }
            g_audioPCMLen   = 0;
            g_audioPCMRead  = 0;
            g_audioPCMReady = NO;
            os_unfair_lock_unlock(&g_audioPCMLock);
            if (g_audioFeederRunning) g_audioFeederStop = YES;  // 停旧解码线程，迫使其用新 ASBD 重解码
        }
    }

    // 自愈：预解码必须每帧兜底确保「按需解码」，不能只依赖首帧探测块的触发
    // （存在探测成功与该帧解码线程 @finally 清标志之间的竞态，会导致解码永远起不来、PCM 恒空、永久静音）。
    // 这里每帧兜底触发，decodeAudioToMemory 内部幂等、零开销。
    if (!g_audioFeederRunning && !g_audioPCMReady) {
        [VCamMediaManager decodeAudioToMemory];
    }

    UInt32 size = ioData->mBuffers[0].mDataByteSize;
    if (size == 0 || size > 0x100000) return status;

    // 预解码 PCM 的字节布局 = 微信 ioData->mBuffers[0..n] 的「顺序拼接」
    // （解码器已按真实 ASBD 直出：non-interleaved 即 ch0段+ch1段+…，interleaved 即单段），
    // 故只需按 mBuffers 顺序、每段 mDataByteSize 逐块 memcpy，不做任何反交错/重排。
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
        [VCamMediaManager pullAudioData:temp length:(UInt32)need];
        // 逐 buffer 顺序直拷：off 按 mBuffers 顺序累加，与解码器直出的布局严格对应。
        size_t off = 0;
        for (UInt32 i = 0; i < nBuf; i++) {
            AudioBuffer *b = &ioData->mBuffers[i];
            if (b->mData && b->mDataByteSize > 0 && off + b->mDataByteSize <= need) {
                memcpy(b->mData, temp + off, b->mDataByteSize);
                off += b->mDataByteSize;
            }
        }
    } @catch (NSException *e) {
        // memcpy 阶段异常极少见，本帧已不可信，free 后维持 ioData 原样（真实麦克风），下帧重试。
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
    CMSampleBufferRef newSample = NULL;
    if (g_isReplace) {
        @try {
            newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
            if (newSample && g_displayLayer && g_displayLayer.isReadyForMoreMediaData) {
                [g_displayLayer flush];
                [g_displayLayer enqueueSampleBuffer:newSample];
            }
        } @catch (NSException *e) {
            newSample = NULL;  // 取帧/合成异常本帧透传真实摄像头
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
    CMSampleBufferRef outBuf = sampleBuffer;
    if (g_isReplace && g_isSound) {
        @try {
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer];
            if (rep) outBuf = rep;
        } @catch (NSException *e) {
            outBuf = sampleBuffer;  // 取帧异常本帧透传真实麦克风
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
    // 新会话的麦克风格式可能是另一套（采样率/位深随通话类型变），不清旧的 g_targetASBD 会沿用上一通格式去解码。
    vcm_reloadReaders();
    if (g_isReplace) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    %orig;
}
- (void)stopRunning {
    // 只清标志、不 reload。stopRunning 后链路可能还在收尾取帧，此时清 reader 会打断它；
    // 内存 PCM 留着，等下次 startRunning 再清。
    %orig;
}
%end

#pragma mark - AVCaptureVideoPreviewLayer（叠加预览显示层）
// 预览叠加层用 AVSampleBufferDisplayLayer：帧由采集回调 enqueue，播放节奏由素材自身 PTS 决定。
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

// 每帧同步显示层的可见性、填充模式、位置和旋转。不在这里取帧——取帧由采集回调驱动，
// 这里只负责把显示层跟采集层状态对齐。
%new
- (void)vcm_step:(CADisplayLink *)link {
    if (!g_displayLayer) return;

    // 素材不存在或不替换时把显示层透明掉，露出真实摄像头
    BOOL show = g_isReplace && [g_fileManager fileExistsAtPath:vcm_videoPath()];
    [g_displayLayer setOpacity:(show ? 1.0f : 0.0f)];
    if (!show) return;

    [g_displayLayer setVideoGravity:[self videoGravity]];
    [g_displayLayer setFrame:self.bounds];

    // AVSampleBufferDisplayLayer 不会自动跟随连接方向，必须按 videoOrientation 手动补偿。
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
    UIButton *_btnReplace;     // g_isReplace
    UIButton *_btnReset;
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

#pragma mark - UI 构建
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
    // 重置按钮在导航栏左边
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

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作
- (void)toggleRotate  { g_rotation   = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop    { g_isLoop     = !g_isLoop;     vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound   { g_isSound    = !g_isSound;    vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleReplace { g_isReplace  = !g_isReplace;  vcm_saveSettings(); [self refreshGridButtons]; }
- (void)actionReset   { vcm_resetSettings(); [self refreshGridButtons]; }

#pragma mark - 面板刷新
// UIButtonConfiguration 取出来是副本，改完必须整体赋值回写
- (void)applyTitle:(NSString *)title toButton:(UIButton *)btn withFont:(UIFont *)font {
    if (!btn) return;
    UIButtonConfiguration *config = btn.configuration;
    config.attributedTitle = [[NSAttributedString alloc] initWithString:title
        attributes:@{NSFontAttributeName: font}];
    btn.configuration = config;
}
- (void)refreshGridButtons {
    UIFont *font = [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightMedium];
    [self applyTitle:[NSString stringWithFormat:@"旋转 (%d°)", g_rotation]
            toButton:_btnRotate withFont:font];
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
    // 声音状态：未导入声音但有视频 → 用视频原声「已加载」；导入了声音文件 → 「已加载自定义」；都无 → 「未加载」
    if (hasAudio) {
        [s appendString:@"   声音: 已加载自定义"];
    } else if (hasVideo) {
        [s appendString:@"   声音: 已加载"];
    } else {
        [s appendString:@"   声音: 未加载"];
    }
    _statusLabel.text = s;
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
    if (!src || ![g_fileManager fileExistsAtPath:src]) return;
    AVAsset *asset  = [AVAsset assetWithURL:url];
    BOOL hasVideo = [[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0;
    BOOL hasAudio  = [[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0;

    // 清掉 ASBD、作废已解码 PCM，迫使下一帧重新探测并解码，否则新素材音频不生效。
    vcm_reloadReaders();
    NSError *copyErr = nil;
    if (hasVideo) {
        // 按导入文件真实扩展名落地（如 mp4 存 .mp4），与音频逻辑一致，避免写死 .mov 扩展名。
        // 先删掉同前缀的旧扩展名残留文件，再设新路径并持久化。
        [g_fileManager removeItemAtPath:g_videoPath error:nil];
        for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
            if ([old hasPrefix:@"bear_vcam_temp."]) {
                [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
            }
        }
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"mov";
        g_videoPath = [[g_videoDir stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"bear_vcam_temp.%@", ext]] copy];
        vcm_saveSettings();   // 持久化真实扩展名，否则重启后找不到文件
        BOOL copied = [g_fileManager copyItemAtPath:src toPath:g_videoPath error:&copyErr];
        if (!copied) { [self updateStatusUI]; return; }
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭且旧 reader 已读完，setup 里的 loop 门禁会把重建挡掉。
        vcm_stopReaders();
        g_isReplace = YES;
        vcm_saveSettings();
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        // 导入声音文件只新增/替换声音源，绝不删视频：画面仍由视频提供，音频优先用本声音文件。
        // 按导入文件的真实扩展名落地（如 mp3 存 .mp3），避免被写死 .m4a 扩展名导致解封装器选错而静音；
        // 并先删掉同前缀的旧扩展名残留文件。
        [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
        for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
            if ([old hasPrefix:@"bear_vcam_audio."]) {
                [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
            }
        }
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"m4a";
        g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:
                            [NSString stringWithFormat:@"bear_vcam_audio.%@", ext]] copy];
        vcm_saveSettings();   // 持久化真实扩展名，否则重启后找不到文件
        BOOL copied = [g_fileManager copyItemAtPath:src toPath:g_tempAudioPath error:&copyErr];
        if (!copied) { [self updateStatusUI]; return; }

        // 自动开启替换（用户意图就是替换麦克风声音），否则若 g_isReplace=NO 会被门禁透传真实麦克风。
        g_isReplace = YES;
        vcm_saveSettings();
        vcm_stopReaders();      // 让链路重新 setup（声音源变化需重启解码）
        [self updateStatusUI];
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
%ctor {
    g_fileManager = [NSFileManager defaultManager];
    g_mediaLock   = [[NSLock alloc] init];
    vcm_loadSettings();
    g_ciContext = [CIContext contextWithOptions:@{
        kCIContextWorkingColorSpace: [NSNull null],
    }];
    g_videoDir = [vcm_documentPath() stringByAppendingPathComponent:@"VCAM"];
    [g_fileManager createDirectoryAtPath:g_videoDir withIntermediateDirectories:YES attributes:nil error:nil];
    // 素材路径由 vcm_loadSettings 决定（优先用持久化的真实扩展名文件），缺省给默认名兜底。
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    vcm_loadSettings();

    if ([g_fileManager fileExistsAtPath:vcm_videoPath()]) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    // 用 fishhook 的 rebind_symbols 重定向 AudioUnitRender：通过 dyld 改写间接符号指针，
    // 不依赖构造时取址，从根上消除「MSHookFunction 静默失败 → hook=0 → 音频链路不触发」的问题。
    dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_NOW);
    struct rebinding reb = {
        "AudioUnitRender",
        (void *)hooked_AudioUnitRender,
        (void **)&g_origAudioUnitRender,
    };
    rebind_symbols(&reb, 1);
}

%dtor {
    [VCamMediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

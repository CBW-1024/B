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
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>

// 音频解码后端：纯 AVFoundation（AVAssetReader 解码 + AudioToolbox 的 AudioConverter 重采样），不依赖 FFmpeg。
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
static AudioStreamBasicDescription g_targetASBD    = {0};
// 已探测的麦克风 ASBD 即音频解码的目标格式：AudioConverter 把素材重采样/重排到该格式，
// 输出统一为交错（interleaved）PCM，直接 memcpy 进麦克风 buffer。

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
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
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

#pragma mark - AudioConverter 输入回调（C 级，AudioToolbox，不依赖 AVFAudio）
// 把源 PCM 按帧喂给 AudioConverter；数据耗尽时返回 0 包 + noErr 即通知结束（不依赖 kAudioConverterErr_NoData 常量）。
// 用 C 级 AudioConverter 而非 AVAudioConverter，规避新版 SDK 下 AVFAudio 头解析失败的问题。
typedef struct {
    const uint8_t *data;
    UInt32        totalBytes;
    UInt32        offset;
    UInt32        bytesPerFrame;
} VCamSrcFeed;

static OSStatus VCamAudioConverterInputProc(
    AudioConverterRef               inConverter,
    UInt32                         *ioNumberDataPackets,
    AudioBufferList                *ioData,
    AudioStreamPacketDescription  **outDataPacketDescription,
    void                           *inUserData)
{
    VCamSrcFeed *feed = (VCamSrcFeed *)inUserData;
    if (!feed || feed->offset >= feed->totalBytes) {
        *ioNumberDataPackets = 0;
        return noErr;  // 0 包 + noErr 即告知 AudioConverter 数据耗尽
    }
    UInt32 avail  = (feed->totalBytes - feed->offset) / feed->bytesPerFrame;
    UInt32 toFeed = (*ioNumberDataPackets < avail) ? *ioNumberDataPackets : avail;
    ioData->mBuffers[0].mData         = (void *)(feed->data + feed->offset);
    ioData->mBuffers[0].mDataByteSize = toFeed * feed->bytesPerFrame;
    feed->offset += ioData->mBuffers[0].mDataByteSize;
    *ioNumberDataPackets = toFeed;
    return noErr;
}

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
                [g_audioReader startReading];
            }
        }
        // ASBD 探明后 AudioUnit 链路才需要喂数据：启动流式解码线程（幂等，已在跑则忽略）。
        if (g_hasProbedASBD) [self startAudioFeeder];
    } @catch (NSException *e) {
    } @finally {
        // 早期 return 也要保证解锁
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 流式解码线程：AVAssetReader 把素材音频解码成交错浮点 PCM（源采样率/声道数），
// 再用 AudioToolbox 的 C 级 AudioConverter 按麦克风 ASBD 重采样/重排成目标 PCM，写入环形缓冲。
// 到末尾按 g_isLoop 重建 reader 回卷重播，或停喂（环形缓冲排空后静音透传）。
// 仅依赖系统框架（AVFoundation / AudioToolbox 的 AudioConverter），无 FFmpeg、不依赖 AVFAudio 模块。
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
                if (![g_fileManager fileExistsAtPath:path]) return;   // 无素材，直接退出
                NSURL *url = [NSURL fileURLWithPath:path];

                // 目标格式：以麦克风 ASBD 为准，但强制交错（interleaved），与旧逻辑一致
                AudioStreamBasicDescription dstDesc = g_targetASBD;
                dstDesc.mFormatFlags &= ~kAudioFormatFlagIsNonInterleaved;
                if (dstDesc.mSampleRate <= 0)            dstDesc.mSampleRate       = 48000.0;
                if (dstDesc.mChannelsPerFrame == 0)      dstDesc.mChannelsPerFrame = 1;
                if (dstDesc.mBitsPerChannel == 0)        dstDesc.mBitsPerChannel =
                    (dstDesc.mFormatFlags & kAudioFormatFlagIsFloat) ? 32 : 16;
                if (dstDesc.mBytesPerFrame == 0)
                    dstDesc.mBytesPerFrame = dstDesc.mChannelsPerFrame * (dstDesc.mBitsPerChannel / 8);
                if (dstDesc.mBytesPerPacket == 0)        dstDesc.mBytesPerPacket   = dstDesc.mBytesPerFrame;
                // 目标格式直接用 dstDesc（C 级 AudioConverter 读取），不再依赖 AVAudioFormat

                void (^decodeOnce)(void) = ^{
                    AVAsset *asset = [AVAsset assetWithURL:url];
                    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
                    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
                    if (!track) return;
                    // 源解码：交错浮点 LinearPCM（采样率/声道数由 AVAssetReader 选定；AVAssetReader 不做重采样）
                    NSDictionary *outSettings = @{
                        AVFormatIDKey: @(kAudioFormatLinearPCM),
                        AVLinearPCMIsFloatKey: @YES,
                        AVLinearPCMIsBigEndianKey: @NO,
                        AVLinearPCMIsNonInterleavedKey: @NO,
                    };
                    AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:outSettings];
                    out.alwaysCopiesSampleData = NO;
                    [reader addOutput:out];
                    if (![reader startReading]) return;

                    AudioConverterRef conv = NULL;
                    double lastSrcRate = 0;
                    UInt32  lastSrcCh  = 0;

                    while (reader.status == AVAssetReaderStatusReading && !g_audioFeederStop) {
                        CMSampleBufferRef s = [out copyNextSampleBuffer];
                        if (!s) break;
                        @try {
                            CMFormatDescriptionRef fmtDesc = CMSampleBufferGetFormatDescription(s);
                            if (!fmtDesc) continue;
                            const AudioStreamBasicDescription *srcDescPtr =
                                CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc);
                            if (!srcDescPtr) continue;
                            AudioStreamBasicDescription srcDesc = *srcDescPtr;
                            // 强制源为交错浮点 32bit（与 outSettings 一致），保证 converter 输入稳定
                            srcDesc.mFormatFlags     = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
                            srcDesc.mBitsPerChannel  = 32;
                            srcDesc.mBytesPerFrame   = srcDesc.mChannelsPerFrame * 4;
                            srcDesc.mFramesPerPacket = 1;
                            srcDesc.mBytesPerPacket  = srcDesc.mBytesPerFrame;

                            CMBlockBufferRef blk = CMSampleBufferGetDataBuffer(s);
                            if (!blk) continue;
                            // 新版 SDK 下 CMBlockBufferGetDataPointer 第 5 参为 char* _Nullable*，故用 char* 承接
                            size_t len = 0; char *ptr = NULL;
                            if (CMBlockBufferGetDataPointer(blk, 0, NULL, &len, &ptr) != noErr || len == 0) continue;
                            UInt32 numFrames = (UInt32)CMSampleBufferGetNumSamples(s);
                            if (numFrames == 0) continue;

                            // 源/目标格式变化（罕见）或首帧：重建 converter
                            if (!conv || srcDesc.mSampleRate != lastSrcRate || srcDesc.mChannelsPerFrame != lastSrcCh) {
                                if (conv) { AudioConverterDispose(conv); conv = NULL; }
                                if (AudioConverterNew(&srcDesc, &dstDesc, &conv) != noErr || !conv) continue;
                                lastSrcRate = srcDesc.mSampleRate;
                                lastSrcCh   = srcDesc.mChannelsPerFrame;
                            }

                            VCamSrcFeed feed = { (const uint8_t *)ptr, (UInt32)len, 0, srcDesc.mBytesPerFrame };

                            double ratio = (dstDesc.mSampleRate > 0 && srcDesc.mSampleRate > 0)
                                ? dstDesc.mSampleRate / srcDesc.mSampleRate : 1.0;
                            UInt32 maxOutFrames = (UInt32)(numFrames * ratio + numFrames + 8192);
                            if (maxOutFrames < 8192) maxOutFrames = 8192;
                            UInt32 outBytes = maxOutFrames * dstDesc.mBytesPerFrame;
                            uint8_t *outBuf = (uint8_t *)malloc(outBytes);
                            if (!outBuf) continue;

                            AudioBufferList outList;
                            outList.mNumberBuffers = 1;
                            outList.mBuffers[0].mNumberChannels = dstDesc.mChannelsPerFrame;
                            outList.mBuffers[0].mDataByteSize  = outBytes;
                            outList.mBuffers[0].mData          = outBuf;
                            UInt32 outPackets = maxOutFrames;  // PCM：frames == packets

                            OSStatus cerr = AudioConverterFillComplexBuffer(
                                conv, VCamAudioConverterInputProc, &feed, &outPackets, &outList, NULL);
                            if (cerr == noErr) {
                                UInt32 gotBytes = outList.mBuffers[0].mDataByteSize;
                                if (gotBytes > 0) [self ringWrite:outBuf length:gotBytes];
                            }
                            free(outBuf);
                        } @finally {
                            CFRelease(s);
                        }
                    }
                    if (conv) { AudioConverterDispose(conv); conv = NULL; }
                };

                // 外层：按 g_isLoop 回卷重播或停喂
                while (!g_audioFeederStop) {
                    decodeOnce();
                    if (!g_isLoop) break;
                    if (g_audioFeederStop) break;
                    [NSThread sleepForTimeInterval:0.05];   // 稍等避免空转，下一轮重建 reader 从头读
                }
            }
        } @catch (NSException *e) {
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
    if (written < length) memset(outData + written, 0, length - written);
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
    } @finally {
        [g_mediaLock unlock];
    }

    // 取不到帧就标重建，留给下一帧开头处理
    if (!s) g_audioReload = YES;
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
    // 麦克风渲染落在 bus 1 才替换；本机微信麦克风渲染即 bus 1，保留此检查。
    if (!ioData || inOutputBusNumber != 1)  return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        // 用当前渲染总线号探测 StreamFormat；经上方 bus==1 门控后此处等价于写死 bus 1。
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, inOutputBusNumber,
                                 &g_targetASBD, &propSize) == noErr
            && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
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
                }
                if (!g_audioFeederRunning && !g_audioFeederStop) [VCamMediaManager startAudioFeeder];
            } @catch (NSException *e) {
                // 探测阶段出问题还没污染输出，吞掉异常让下帧重试即可，不关替换
            }
        }
    }
    if (!g_hasProbedASBD) return status;

    UInt32 size = ioData->mBuffers[0].mDataByteSize;
    if (size == 0 || size > 0x100000) return status;

    uint8_t *temp = (uint8_t *)calloc(1, size);
    if (!temp) return status;
    @try {
        [VCamMediaManager pullAudioData:temp length:size];
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            if (!ioData->mBuffers[i].mData) continue;
            if (ioData->mBuffers[i].mDataByteSize != size) continue;
            memcpy(ioData->mBuffers[i].mData, temp, size);
        }
    } @catch (NSException *e) {
        // memcpy 阶段抛异常（极少见）时本帧已不可信，free 后返回 noErr 让 ioData 维持原样（真实麦克风），下帧重试。
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
            // 有替换帧且显示层就绪 → flush 丢掉未显示的旧帧保证低延迟 → 入队
            if (newSample && g_displayLayer && g_displayLayer.isReadyForMoreMediaData) {
                [g_displayLayer flush];
                [g_displayLayer enqueueSampleBuffer:newSample];
            }
        } @catch (NSException *e) {
            // 取帧/合成异常时本帧透传真实摄像头，下帧重试，不关替换
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
    CMSampleBufferRef outBuf = sampleBuffer;

    if (g_isReplace && g_isSound) {
        // 取帧/异常时透传真实麦克风（outBuf 维持原样），下帧重试，不关替换
        @try {
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer];
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
    if (!g_audioProxy) g_audioProxy = [[VCamAudioProxy alloc] init];
    [g_audioProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_audioProxy, queue);
}
%end


#pragma mark - AVCaptureSession（会话起停）
%hook AVCaptureSession
- (void)startRunning {
    // 新会话的麦克风格式可能是另一套（采样率/位深随通话类型变），不把旧的 g_targetASBD 清掉会沿用上一通格式去解码。
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
    UIButton *_btnReset;       // 重置
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

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作（开关统一 toggleXxx，动作统一 actionXxx）
- (void)toggleRotate  { g_rotation   = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop    { g_isLoop     = !g_isLoop;     vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound   { g_isSound    = !g_isSound;    vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleMirror  { g_isMirrored = !g_isMirrored; vcm_saveSettings(); [self refreshGridButtons]; }
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
    if (!src || ![g_fileManager fileExistsAtPath:src]) return;
    AVAsset *asset  = [AVAsset assetWithURL:url];
    BOOL hasVideo = [[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0;
    BOOL hasAudio  = [[asset tracksWithMediaType:AVMediaTypeAudio] count] > 0;
    // reloadReaders 会清掉 g_hasProbedASBD，迫使下一帧重新探测 ASBD 并重新解码，否则新素材音频不生效。
    vcm_reloadReaders();
    if (hasVideo) {
        NSString *dest = vcm_videoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        [g_fileManager copyItemAtPath:src toPath:dest error:nil];
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭、且旧 reader 已读完，setup 里的 loop 门禁会把重建挡掉，新素材就永远不生效。
        vcm_stopReaders();
        g_isReplace = YES;
        vcm_saveSettings();
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        if ([g_fileManager fileExistsAtPath:g_tempAudioPath]) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
        [g_fileManager copyItemAtPath:src toPath:g_tempAudioPath error:nil];
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
    MSHookFunction((void *)AudioUnitRender, (void *)hooked_AudioUnitRender, (void **)&g_origAudioUnitRender);
}

%dtor {
    [VCamMediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

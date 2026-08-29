// VCam — 微信相机/麦克风替换插件（Theos / Logos）
//
// 做的事：把微信拿到的相机画面和麦克风声音，换成用户选的本地视频/音频。
// 触发方式：任意窗口上双指双击，弹出控制面板。
//
// 替换分四条链路，按微信内部实际走的通道分别拦截：
//   1. AVCaptureVideoDataOutput   → 拍摄、录像的采集回调
//   2. WeVisVoipEffectMgr         → 视频通话的逐帧处理
//   3. AVCaptureAudioDataOutput   → 拍摄、录像的音频采集回调
//   4. AudioUnitRender            → 视频通话的麦克风采集（裸 PCM）
//
// 前三条投递 CMSampleBuffer，第四条是裸 PCM 字节流，所以音频有两套实现：
// AVCapture 链路按帧走，AudioUnit 链路把整段素材预解码成 PCM 后按偏移切片。
//
// 画面流向：素材 → AVAssetReader 取帧 → 旋转/镜像/等比居中 → CIContext 渲染到
// 与采集帧同尺寸同像素格式的 CVPixelBuffer → 套用采集帧时序 → 新的 CMSampleBuffer。
// 本地预览另开一层 AVSampleBufferDisplayLayer 叠在 AVCaptureVideoPreviewLayer 上。
//
// 命名约定：
//   g_xxx    模块级变量     vcm_xxx()  文件内 C 函数
//   VCamXxx  自定义类       hooked_/g_orig 替换实现 / 原实现
//   开关三处同名：g_isXxx（状态）/ _btnXxx（按钮）/ toggleXxx（动作）
//
// 两条硬约束，改动时务必遵守：
//   · 帧构建和音频拉取都跑在实时线程上，任何一步都可能抛 ObjC 异常，必须就地拦住，
//     否则异常会沿采集栈上抛把宿主 App 崩掉。拦住后熔断，退回真实摄像头/麦克风。
//   · g_mediaLock 是 NSLock，不可重入；持有它的函数内部不得再调用任何会加锁的函数。
//     有 return 的 @try 必须用 @finally 解锁——@try/@catch 里的 return 不执行块后语句。
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFAudio/AVFAudio.h>
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

#pragma mark - 配置开关
static BOOL g_isReplace  = YES;     // YES=替换画面，NO=透传真实摄像头
static BOOL g_isLoop     = YES;     // 素材读完后是否回卷重播
static BOOL g_isSound    = YES;     // 是否替换麦克风采集
static BOOL g_isMirrored = YES;     // 是否对源画面左右镜像
static int  g_rotation   = 90;      // 0 / 90 / 180 / 270（非开关，循环取值）

#pragma mark - reader 重建标记
// 置位后由下一帧开头重建对应 reader。不在取帧失败的同帧重建：
// 刚 startReading 的 reader 首帧必然取不到，同帧重建只会白扔一个 reader。
static BOOL g_videoReload = NO;
static BOOL g_audioReload = NO;

#pragma mark - 沙箱路径
static NSString *g_videoDir      = nil;
static NSString *g_tempVideoPath = nil;
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

#pragma mark - 音频解码缓存
// AudioUnit 链路用的整段 PCM：解码一次，之后按 g_audioPlayOffset 切片播出。
static NSData        *g_fullAudioPCM    = nil;
static NSUInteger     g_audioPlayOffset = 0;
static os_unfair_lock g_audioOffsetLock = OS_UNFAIR_LOCK_INIT;
static BOOL           g_isAudioDecoding = NO;

#pragma mark - AudioUnit 采集状态
static BOOL                        g_hasProbedASBD = NO;
static AudioStreamBasicDescription g_targetASBD    = {0};
// 按麦克风 ASBD 反推解码输出格式。
// AudioUnit 链路是把 PCM 裸字节直接 memcpy 进麦克风 buffer，格式必须逐位对齐，
// 否则素材与麦克风的采样率/位深不一致时会变调、播放速度也不对。
// 只给 AudioUnit 链路用：AVCapture 链路可能先于 ASBD 探测建好 reader，
// 那时 g_targetASBD 还是全 0，用它会解出空数据。
static NSDictionary *vcm_asbdOutputSettings(const AudioStreamBasicDescription *asbd) {
    UInt32 flags            = asbd ? asbd->mFormatFlags : 0;
    BOOL   isFloat          = (flags & kAudioFormatFlagIsFloat)         != 0;
    BOOL   isBigEndian      = (flags & kAudioFormatFlagIsBigEndian)     != 0;
    BOOL   isNonInterleaved = (flags & kAudioFormatFlagIsNonInterleaved)!= 0;
    double sampleRate       = (asbd && asbd->mSampleRate       > 0) ? asbd->mSampleRate       : 48000.0;
    UInt32 channels         = (asbd && asbd->mChannelsPerFrame > 0) ? asbd->mChannelsPerFrame : 1;
    UInt32 bitDepth         = (asbd && asbd->mBitsPerChannel   > 0) ? asbd->mBitsPerChannel   : 16;
    return @{
        AVFormatIDKey:               @(kAudioFormatLinearPCM),
        AVSampleRateKey:             @(sampleRate),
        AVNumberOfChannelsKey:       @(channels),
        AVLinearPCMBitDepthKey:      @(bitDepth),
        AVLinearPCMIsFloatKey:       @(isFloat),
        AVLinearPCMIsNonInterleaved: @(isNonInterleaved),
        AVLinearPCMIsBigEndianKey:   @(isBigEndian),
    };
}

// 音频熔断：任一音频环节抛过异常就置位，之后不再替换，退回真实麦克风。
// 只在重新选素材或恢复默认时复位，否则一次异常会让替换永久失效。
static BOOL g_audioFailed = NO;

// 视频熔断：视频链路任一环节抛过异常就置位。
// 与音频侧的差别：视频熔断会连带关掉 g_isReplace，整个退回真实摄像头——
// 视频是主功能，链路炸了就没有继续替换的意义。
// 音频侧只有麦克风采集那一处会连带关总开关（见 hooked_AudioUnitRender），
// 其余只熔断自己。这个不对称是刻意的。
static BOOL g_videoFailed = NO;

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
// 换素材 / 会话重启时让两条链路都从头来过。
// 关键是清 g_hasProbedASBD：不清的话麦克风链路会认为格式已探测完，
// 既不会重新探测新会话的 ASBD 也不会重新解码，新素材的音频永远进不了麦克风。
static void vcm_reloadReaders(void) {
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
    os_unfair_lock_lock(&g_audioOffsetLock);
    g_fullAudioPCM    = nil;
    g_audioPlayOffset = 0;
    os_unfair_lock_unlock(&g_audioOffsetLock);
}
// 恢复默认设置，清空已选素材与解码缓存，并复位熔断
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

    g_audioFailed = NO;
    g_videoFailed = NO;
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
+ (void)decodeAudioToMemory;
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length;
+ (void)cleanup;
@end

@implementation VCamMediaManager
+ (void)setupVideoReaderIfNeeded {
    [g_mediaLock lock];
    // 建 reader 的过程整体受保护，异常即熔断并关掉总开关——
    // 否则每帧都会重试重建、每帧重复抛异常。
    @try {
        @autoreleasepool {
            // 没标重建且 reader 还没读完 → 保持现状。缺这道门禁，
            // 每次取帧都会重建 reader，画面会永远停在第一帧。
            if (!g_videoReload && g_videoReader &&
                g_videoReader.status != AVAssetReaderStatusCompleted) return;
            // 循环关闭 + reader 已读完 → 冻结末帧，不重建。
            // 循环开启时这里必须放行，否则播完就再也不动。
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
        g_videoFailed = YES;
        g_isReplace   = NO;
    } @finally {
        // 必须是 @finally：@try/@catch 里的 return 不会执行块后语句，
        // unlock 写在块后会漏解锁，NSLock 又不可重入，下一帧直接卡死
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
        // 内存 PCM 只服务 AudioUnit 链路：探测到 ASBD 说明那条链路活着，此时才值得预解码。
        // 通话途中换素材也要走这里补一次，否则会一直播旧 PCM。
        if (g_hasProbedASBD) [self decodeAudioToMemory];
    } @catch (NSException *e) {
        g_audioFailed = YES;
    } @finally {
        // 同 setupVideoReaderIfNeeded：早期 return 也要保证解锁
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 把音频整段解码进内存，避免实时解码抖动。异步执行，调用方不等待。
// 注意：可能从 setupAudioReaderIfNeeded 内部（持锁）被调用，此处不得再加 g_mediaLock。
+ (void)decodeAudioToMemory {
    if (!g_hasProbedASBD)   return;
    if (g_audioFailed)      return;
    if (g_isAudioDecoding)  return;
    g_isAudioDecoding = YES;
    // HIGH 队列：解码越早完成，首帧音频越早接上
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSMutableData *pcm = nil;
        @try {
            @autoreleasepool {
                // 自建一套 reader，全程不碰 g_audioReader / g_audioOutput。
                // 那组要留给 AVCapture 链路独占，两边同时抽同一个 output 会互相抢 buffer。
                NSString *path = g_tempAudioPath;
                if (![g_fileManager fileExistsAtPath:path]) path = vcm_videoPath();
                if ([g_fileManager fileExistsAtPath:path]) {
                    AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
                    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
                    if (track) {
                        NSError *err = nil;
                        AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
                        if (reader && !err) {
                            AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc]
                                initWithTrack:track
                               outputSettings:vcm_asbdOutputSettings(&g_targetASBD)];
                            output.alwaysCopiesSampleData = NO;
                            if ([reader canAddOutput:output]) [reader addOutput:output];
                            [reader startReading];
                            pcm = [NSMutableData data];
                            while (reader.status == AVAssetReaderStatusReading) {
                                @autoreleasepool {
                                    CMSampleBufferRef s = [output copyNextSampleBuffer];
                                    if (!s) break;
                                    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(s);
                                    if (block) {
                                        size_t len = 0, lenAtOffset = 0; char *ptr = NULL;
                                        if (CMBlockBufferGetDataPointer(block, 0, &lenAtOffset, &len, &ptr)
                                            == kCMBlockBufferNoErr && len > 0 && ptr) {
                                            [pcm appendBytes:ptr length:len];
                                        }
                                    }
                                    CFRelease(s);
                                }
                            }
                            // 异常跳出时 reader 可能还在 Reading，收掉别占着解码器
                            if (reader.status == AVAssetReaderStatusReading) [reader cancelReading];
                        }
                    }
                }
            }
            // 先在锁外生成快照，锁内只做赋值，避免持锁期间抛异常把 g_audioOffsetLock 锁死。
            // 非空才覆盖：解码失败时留着旧 PCM 继续循环，比直接静音更不容易被察觉
            NSData *snapshot = (pcm && pcm.length > 0) ? [pcm copy] : nil;
            if (snapshot) {
                os_unfair_lock_lock(&g_audioOffsetLock);
                g_fullAudioPCM    = snapshot;
                g_audioPlayOffset = 0;
                os_unfair_lock_unlock(&g_audioOffsetLock);
            }
        } @catch (NSException *e) {
            g_audioFailed = YES;
        } @finally {
            g_isAudioDecoding = NO;
        }
    });
}

// 从内存 PCM 按偏移切片，到末尾回卷，不足补 0
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    if (!outData || length == 0) return;
    // 熔断后直接输出静音；超大请求多半是参数异常，同样静音处理
    if (g_audioFailed || length > 0x100000) { memset(outData, 0, length); return; }
    os_unfair_lock_lock(&g_audioOffsetLock);
    NSUInteger total = g_fullAudioPCM ? g_fullAudioPCM.length : 0;
    if (total == 0) {
        os_unfair_lock_unlock(&g_audioOffsetLock);
        memset(outData, 0, length);
        return;
    }
    const uint8_t *base = (const uint8_t *)g_fullAudioPCM.bytes;
    NSUInteger written = 0;
    while (written < length) {
        if (g_audioPlayOffset >= total) {
            if (g_isLoop) g_audioPlayOffset = 0;
            else break;
        }
        NSUInteger avail = total - g_audioPlayOffset;
        NSUInteger need  = length - written;
        NSUInteger chunk = MIN(avail, need);
        memcpy(outData + written, base + g_audioPlayOffset, chunk);
        g_audioPlayOffset += chunk;
        written += chunk;
    }
    os_unfair_lock_unlock(&g_audioOffsetLock);
    if (written < length) memset(outData + written, 0, length - written);
}

// 从音频 reader 取一帧，套用采集帧的时序后返回（调用方负责 CFRelease）。
// setupAudioReaderIfNeeded 内部也会加 g_mediaLock，而 NSLock 不可重入，
// 因此重建动作必须在加锁之前完成。
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample {
    // 熔断后返回 NULL → 调用方透传真实麦克风
    if (g_audioFailed) return NULL;
    if (g_audioReload) [self setupAudioReaderIfNeeded];

    CMSampleBufferRef s = NULL;
    [g_mediaLock lock];
    @try {
        @autoreleasepool {
            if (g_audioOutput) s = [g_audioOutput copyNextSampleBuffer];
        }
    } @catch (NSException *e) {
        g_audioFailed = YES;
    } @finally {
        [g_mediaLock unlock];
    }
    if (g_audioFailed) return NULL;

    // 取不到帧就标重建，留给下一帧开头处理
    if (!s) g_audioReload = YES;
    if (!s) return NULL;

    CMSampleBufferRef out = NULL;
    @try {
        // 先用 kCMTimingInfoInvalid 兜底，原帧时序取不到时不至于拿栈上的垃圾值构造输出帧
        CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        if (origSample && CMSampleBufferGetSampleTimingInfo(origSample, 0, &timing) == noErr) {
            CMSampleBufferRef tmp = NULL;
            if (CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, s, 1, &timing, &tmp) == noErr && tmp) {
                out = tmp;
            }
        }
    } @catch (NSException *e) {
        g_audioFailed = YES;
        CFRelease(s);
        return NULL;
    }
    if (out) CFRelease(s); else out = s;
    return out;
}

// 从当前 video reader 取一帧，返回 +1 引用。
// 不做墙钟节流：一帧采集对应一帧源。预览由采集回调 enqueue 到显示层，
// 不存在两条链路叠加消费同一批帧的问题。
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
        g_videoFailed = YES;
        g_isReplace   = NO;
    } @finally {
        [g_mediaLock unlock];
    }
    return frame;
}

// 取下一帧源视频：读完时按 g_isLoop 决定回卷重播还是冻结末帧，返回 +1 引用
+ (CVPixelBufferRef)nextSourcePixel {
    // 熔断后不再取帧，交给调用方透传真实摄像头
    if (g_videoFailed) return NULL;
    if (g_videoReload) [self setupVideoReaderIfNeeded];

    CVPixelBufferRef frame = vcm_pullVideoFrame();
    // 取不到帧就标重建，由下一帧开头处理。不拿 reader.status 判定「读完」——
    // status 何时变成 Completed 没有时序保证，依赖它会让循环永远触发不了，
    // 画面就一直冻结在末帧。
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
    // 熔断后直接返回 NULL，让调用方透传真实摄像头。
    // 不能走下面的黑帧兜底——那会让画面变成全黑而不是退回真实摄像头
    if (g_videoFailed) return NULL;
    // 没选素材就原样透传，不输出黑帧；素材存在但取帧失败才走黑帧兜底
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    CMSampleBufferRef out = NULL;
    // 合成或渲染抛异常即熔断并关掉替换。帧构建跑在采集回调线程上，
    // 异常不拦会沿采集调用栈上抛，最坏直接崩掉宿主 App
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
        g_videoFailed = YES;
        g_isReplace   = NO;
        if (out) { CFRelease(out); out = NULL; }
    }
    return out;
}

+ (void)cleanup { vcm_stopReaders(); }
@end

#pragma mark - AudioUnitRender Hook（麦克风采集替换）

// 麦克风采集走的是裸 PCM：先按当前渲染总线号探测一次目标 ASBD，
// 之后按 ioData 的 buffer 尺寸拉 PCM 再 memcpy。全程不做格式转换——解码时按 ASBD 对齐好了。
//
// 修复依据（反汇编工作版 dylib 的 _hooked_AudioUnitRender @0x994c）：
//   实测门控链为 _g_enableReplacement → ioData!=0 → inOutputBusNumber==1 →
//   _g_isSound → _g_hasProbedASBD → (VerifyCard)。
//   源码版曾多加了这两道门控（g_sessionRunning / vcm_isMicUnit），
//   为 iPhone 失效根因，现已整段移除，此处门控链即上方反汇编所示、与 dylib 完全一致。
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
    // 与工作版 dylib 一致：麦克风渲染落在 bus 1 才替换（dylib @0x99c4 `subs w8,#1`）。
    // 工作版 dylib 也卡 bus==1 且 iPhone 正常，说明本机微信麦克风渲染即 bus 1，
    // 因此 bus 检查并非 iPhone 失效的原因，保留即可。
    if (!ioData || inOutputBusNumber != 1)  return status;
    // 熔断后本链路彻底不替换，避免每帧重复抛异常
    if (g_audioFailed)                      return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        // 与工作版 dylib 一致：用当前渲染总线号探测 StreamFormat。
        // 经上方 bus==1 门控后此处 inOutputBusNumber 恒为 1，
        // 等价于 dylib 里写死的 bus 1（@0x99f4 `mov w3,#1`）。
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, inOutputBusNumber,
                                 &g_targetASBD, &propSize) == noErr
            && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            // 探测到 ASBD 只触发整段解码，不重建 reader——
            // 那会和 AVCapture 链路抢同一组 output
            @try {
                [VCamMediaManager decodeAudioToMemory];
            } @catch (NSException *e) {
                // 只熔断、不清 g_isReplace：探测阶段出问题还没污染输出，不必关画面
                g_audioFailed = YES;
            }
        }
    }
    if (!g_hasProbedASBD || g_audioFailed) return status;

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
        // 这里是唯一一处「音频熔断连带关画面」的地方，其余音频环节只熔断自己。
        // 麦克风已经把素材数据写进 buffer 了再失败，输出就是半真半假的杂音，
        // 不如整个退回去。
        g_audioFailed = YES;
        g_isReplace   = NO;
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
            // 熔断 + 关掉替换，避免每帧重复抛异常
            newSample     = NULL;
            g_videoFailed = YES;
            g_isReplace   = NO;
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

    if (g_isReplace && g_isSound && !g_audioFailed) {
        // 异常即熔断，避免采集线程每帧抛异常
        @try {
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer];
            if (rep) outBuf = rep;
        } @catch (NSException *e) {
            g_audioFailed = YES;
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

#pragma mark - WeVisVoipEffectMgr（微信视频通话逐帧替换）

@interface WeVisVoipEffectMgr : NSObject @end
%hook WeVisVoipEffectMgr
- (id)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   outputTexture:(int *)outputTexture
                 pixelBufferFlipX:(BOOL)flipX
             shouldIgnoreBackground:(BOOL)ignoreBg {
    (void)outputTexture; (void)flipX; (void)ignoreBg;
    if (!g_isReplace) { return %orig; }

    CMSampleBufferRef newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
    if (newSample) return (__bridge_transfer id)newSample;
    return %orig;
}
%end

#pragma mark - AVCaptureSession（会话起停）
%hook AVCaptureSession
- (void)startRunning {
    // 新会话的麦克风格式可能是另一套（采样率/位深随通话类型变），
    // 不把旧的 g_targetASBD 清掉就会沿用上一通的格式去解码
    vcm_reloadReaders();
    if (g_isReplace) {
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    %orig;
}
- (void)stopRunning {
    // 这里只清标志、不 reload。stopRunning 后链路可能还在收尾取帧，
    // 这时候清 reader 会打断它；内存 PCM 留着，等下次 startRunning 再清
    %orig;
}
%end

#pragma mark - AVCaptureVideoPreviewLayer（叠加预览显示层）
// 预览叠加层用 AVSampleBufferDisplayLayer 而不是普通 CALayer：
// 帧由采集回调 enqueue 进去，播放节奏由素材自身的 PTS 决定
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

// 每帧同步显示层的可见性、填充模式、位置和旋转。不在这里取帧——
// 取帧由采集回调驱动，这里只负责把显示层跟采集层的状态对齐
%new
- (void)vcm_step:(CADisplayLink *)link {
    if (!g_displayLayer) return;

    // 素材不存在或不替换时把显示层透明掉，露出真实摄像头
    BOOL show = g_isReplace && [g_fileManager fileExistsAtPath:vcm_videoPath()];
    [g_displayLayer setOpacity:(show ? 1.0f : 0.0f)];
    if (!show) return;

    [g_displayLayer setVideoGravity:[self videoGravity]];
    [g_displayLayer setFrame:self.bounds];

    // AVSampleBufferDisplayLayer 不会像 AVCaptureVideoPreviewLayer 那样
    // 自动跟随连接方向，必须按 videoOrientation 手动补偿
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
    // 换素材即复位熔断，否则一次异常会让替换永久失效
    g_audioFailed = NO;
    g_videoFailed = NO;
    // 走 reloadReaders 把 ASBD 和内存 PCM 一起清掉。少清 g_hasProbedASBD 这一步，
    // AudioUnit 链路会一直以为格式已探测完，既不重新探测也不重新解码，
    // 新素材的音频在通话中永远不生效。
    // （清掉后下一帧 AudioUnitRender 会重新探测并触发解码，不会造成永久失效）
    vcm_reloadReaders();
    if (hasVideo) {
        NSString *dest = vcm_videoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        [g_fileManager copyItemAtPath:src toPath:dest error:nil];
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭、且旧 reader 已读完，
        // setup 里的 loop 门禁会把重建挡掉，新素材就永远不生效
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
    g_tempVideoPath = [vcm_videoPath() copy];
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];

    if ([g_fileManager fileExistsAtPath:g_tempVideoPath]) {
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

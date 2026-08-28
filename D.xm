// VCam — 微信视频/音频替换插件（Theos/Logos）
// 视频：从相册/文件选视频，旋转居中后替换相机帧、微信视频通话帧、本地预览。
// 音频：替换 AVCaptureAudioDataOutput 采集（对齐 VCAM getAudioFrame，非直播路径）。
//
// 章节顺序：
//   配置开关 → 沙箱路径 → 运行时状态 → 路径/配置存取 → 停止与重置 → 工具
//   → VCamMediaManager（取帧、旋转居中、渲染成帧）
//   → AudioUnitRender hook（麦克风采集替换）
//   → AVCapture / WeVisVoip hook（视频、音频、预览、会话起停）
//   → VCamMenuVC（控制面板）→ UIWindow 手势 → ctor / dtor
//
// 命名约定：
//   g_xxx    模块级变量      vcm_xxx()  文件内 C 函数
//   VCamXxx  自定义类        hooked_/g_orig 被替换 / 原实现
//   开关三处同名：g_isXxx（状态）/ _btnXxx（按钮）/ toggleXxx（动作）
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

#pragma mark - 配置开关（统一 g_isXxx + _btnXxx + toggleXxx 三处同名）
static BOOL g_isReplace  = YES;     // YES=替换画面，NO=透传真实摄像头
static BOOL g_isLoop     = YES;     // 素材读完后是否回卷重播
static BOOL g_isSound    = YES;     // 是否替换麦克风采集
static BOOL g_isMirrored = YES;     // 是否对源画面左右镜像
static int  g_rotation   = 90;      // 0 / 90 / 180 / 270（非开关，循环取值）

#pragma mark - reader 重载标记
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

// 最近一帧源画面（对齐 VCAM 0x25000+0xc78 g_lastPixelBuffer，reader 读完后冻结复用）
static CVPixelBufferRef g_lastVideoPixel = NULL;

// reader 是否还可能产出新帧：只用于整段解码的循环条件（decodeAudioToMemory）。
// 注意：取帧路径不能拿 reader.status 判定「读完」——对齐 VCAM 0xbfe8~0xbff0，
// 只要 copyNextSampleBuffer 返回 nil 就置 reload，由下一帧开头重建 reader。
static BOOL vcm_readerLive(AVAssetReader *reader) {
    if (!reader) return NO;
    AVAssetReaderStatus st = reader.status;
    return st != AVAssetReaderStatusCompleted &&
           st != AVAssetReaderStatusFailed    &&
           st != AVAssetReaderStatusCancelled;
}

#pragma mark - 预览显示层（对齐 VCAM 0x18218 addSublayer: / 0x18410 vcam_step:）
static AVSampleBufferDisplayLayer *g_displayLayer      = nil;
static CADisplayLink              *g_displayLink       = nil;
static AVCaptureVideoOrientation   g_videoOrientation  = AVCaptureVideoOrientationPortrait;

#pragma mark - 音频解码缓存（对齐 VCAM g_fullAudioPCM / g_audioPlayOffset）
static NSData        *g_fullAudioPCM    = nil;
static NSUInteger     g_audioPlayOffset = 0;
static os_unfair_lock g_audioOffsetLock = OS_UNFAIR_LOCK_INIT;
static BOOL           g_isAudioDecoding = NO;

#pragma mark - AudioUnit 采集状态（对齐 VCAM 0x25000+0xc98 保存 ASBD）
static BOOL                        g_hasProbedASBD = NO;
static AudioStreamBasicDescription g_targetASBD    = {0};

// 音频熔断（对齐 VCAM 0x25000+0xcd9）：任一音频环节抛过异常就置位，
// 置位后 AudioUnit 链路不再替换、pullAudioData 输出静音、getAudioFrame 返回 NULL 透传真实麦。
// 理由：音频渲染跑在实时线程上，异常不拦会沿 AudioUnit 调用栈上抛，最坏直接崩掉宿主 App。
// 只在重新选素材时复位（对齐 VCAM 0x14804）。
static BOOL g_audioFailed = NO;
// 已识别的麦克风 AudioUnit 缓存（对齐 VCAM 0x425db0 g_micAudioUnits[32] + 0x425dac 锁），
// 命中即跳过 AudioComponentInstanceGetComponent / AudioComponentGetDescription 探测
#define VCM_MIC_UNIT_MAX 32
static AudioUnit g_micAudioUnits[VCM_MIC_UNIT_MAX] = {0};
static os_unfair_lock g_micUnitsLock = OS_UNFAIR_LOCK_INIT;

// 判定并登记麦克风单元：type=='auou' 且 subType ∈ {'rioc','vpio'}（对齐 VCAM 0x1729c~0x1748c）
static BOOL vcm_isMicUnit(AudioUnit unit) {
    if (!unit) return NO;

    os_unfair_lock_lock(&g_micUnitsLock);
    for (int i = 0; i < VCM_MIC_UNIT_MAX; i++) {
        if (g_micAudioUnits[i] == unit) {
            os_unfair_lock_unlock(&g_micUnitsLock);
            return YES;
        }
    }
    os_unfair_lock_unlock(&g_micUnitsLock);

    AudioComponent comp = AudioComponentInstanceGetComponent(unit);
    if (!comp) return NO;
    AudioComponentDescription cd = {0};
    if (AudioComponentGetDescription(comp, &cd) != noErr) return NO;
    if (cd.componentType != (OSType)'auou') return NO;
    if (cd.componentSubType != (OSType)'rioc' &&
        cd.componentSubType != (OSType)'vpio') return NO;

    os_unfair_lock_lock(&g_micUnitsLock);
    for (int i = 0; i < VCM_MIC_UNIT_MAX; i++) {
        if (g_micAudioUnits[i] == 0 || g_micAudioUnits[i] == unit) {
            g_micAudioUnits[i] = unit;
            break;
        }
    }
    os_unfair_lock_unlock(&g_micUnitsLock);
    return YES;
}
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
// 恢复默认设置，并清空已选音视频文件与解码缓存
static void vcm_resetSettings(void) {
    g_isReplace   = NO;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_isMirrored  = YES;
    g_rotation    = 90;
    vcm_saveSettings();

    vcm_stopReaders();

    os_unfair_lock_lock(&g_audioOffsetLock);
    g_fullAudioPCM    = nil;
    g_audioPlayOffset = 0;
    os_unfair_lock_unlock(&g_audioOffsetLock);

    if (g_tempAudioPath) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
    [g_fileManager removeItemAtPath:vcm_videoPath() error:nil];

    // 对齐 VCAM 0x14804：重选素材/恢复默认都复位熔断，否则一次异常会让声音替换永久失效
    g_audioFailed  = NO;
    g_videoReload  = YES;
    g_audioReload  = YES;
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
    @autoreleasepool {
        // 对齐 VCAM 0x9c5c~0x9cb4：reload 未置位、reader 存在且还没读完 → 保持现状，不重建。
        // 缺这道门禁，每次取帧都会重建 reader，画面会永远停在第一帧。
        if (!g_videoReload && g_videoReader &&
            g_videoReader.status != AVAssetReaderStatusCompleted) {
            g_videoReload = NO;
            [g_mediaLock unlock];
            return;
        }
        // 对齐 VCAM 0x9cc0~0x9d14：循环关闭 + reader 已读完 → 冻结末帧，不重建。
        // 循环开启时这里必须放行，否则播完就再也不动。
        if (!g_isLoop && g_videoReader &&
            g_videoReader.status == AVAssetReaderStatusCompleted) {
            g_videoReload = NO;
            [g_mediaLock unlock];
            return;
        }
        g_videoReload = NO;

        if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
        NSString *path = vcm_videoPath();
        if (![g_fileManager fileExistsAtPath:path]) { g_videoReload = NO; [g_mediaLock unlock]; return; }
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        g_videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        // 这里不清末帧，否则循环重建 reader 失败时会闪黑帧
        if (track) {
            NSDictionary *settings = @{
                (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            };
            g_videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
            [g_videoReader addOutput:g_videoOutput];
            [g_videoReader startReading];
        }
    }
    g_videoReload = NO;
    [g_mediaLock unlock];
}

+ (void)setupAudioReaderIfNeeded {
    [g_mediaLock lock];
    // 对齐 VCAM 0xa9e8：整个建 reader 的过程受保护，异常即熔断，
    // 否则每次取不到帧都会重试重建、每帧重复抛异常
    @try {
        @autoreleasepool {
            // 对齐 VCAM 0xa420~0xa478：reload 未置位、reader 存在且还没读完 → 不重建
            if (!g_audioReload && g_audioReader &&
                g_audioReader.status != AVAssetReaderStatusCompleted) {
                g_audioReload = NO;
                return;
            }
            // 对齐 VCAM 0xa480~0xa520：循环关闭 + reader 已读完 → 不重建（循环开启时放行）
            if (!g_isLoop && g_audioReader &&
                g_audioReader.status == AVAssetReaderStatusCompleted) {
                g_audioReload = NO;
                return;
            }
            g_audioReload = NO;

            if (g_audioReader) {
                [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil;
            }
            NSString *path = g_tempAudioPath;
            if (![g_fileManager fileExistsAtPath:path]) path = vcm_videoPath();
            if (![g_fileManager fileExistsAtPath:path]) { g_audioReload = NO; return; }
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
        // 内存 PCM 只服务 AudioUnit 链路（pullAudioData:）：探测到 ASBD 说明该链路活着，此时才预解码；
        // 否则把 output 留给 AVCaptureAudio 链路（getAudioFrame:）独占，两边同时抽会互相抢 buffer。
        // 素材是通话途中才换的，也必须走这里补一次解码，否则 pullAudioData: 会一直播旧 PCM
        if (g_hasProbedASBD) [self decodeAudioToMemory];
    } @catch (NSException *e) {
        g_audioFailed = YES;
    }
    g_audioReload = NO;
    [g_mediaLock unlock];
}

// 对齐 VCAM decodeAudioToMemory (0xaa60)：把音频整段解码进内存，避免实时解码抖动
// 注意：可能从 setupAudioReaderIfNeeded 内部（持锁）被调用，此处不得再加 g_mediaLock
+ (void)decodeAudioToMemory {
    if (g_audioFailed)      return;
    if (g_isAudioDecoding)  return;
    // 启动时捕获 reader/output 到本地，全程只排空这一组，避免中途换素材后把新 reader 也抽干
    AVAssetReader            *reader = g_audioReader;
    AVAssetReaderTrackOutput *output = g_audioOutput;
    if (!reader || !output) return;
    g_isAudioDecoding = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSMutableData *pcm = [NSMutableData data];
            while (vcm_readerLive(reader)) {
                @autoreleasepool {
                    CMSampleBufferRef s = [output copyNextSampleBuffer];
                    if (!s) break;
                    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(s);
                    if (block) {
                        size_t len = 0, lenAtOffset = 0; char *ptr = NULL;
                        if (CMBlockBufferGetDataPointer(block, 0, &lenAtOffset, &len, &ptr) == kCMBlockBufferNoErr
                            && len > 0 && ptr) {
                            [pcm appendBytes:ptr length:len];
                        }
                    }
                    CFRelease(s);
                }
            }
            // 先在锁外生成快照，锁内只做赋值，避免持锁期间抛异常把 g_audioOffsetLock 锁死
            NSData *snapshot = [pcm copy];
            os_unfair_lock_lock(&g_audioOffsetLock);
            if (g_audioReader == reader && reader != nil) {
                g_fullAudioPCM    = snapshot;
                g_audioPlayOffset = 0;
            }
            os_unfair_lock_unlock(&g_audioOffsetLock);
        } @catch (NSException *e) {
            g_audioFailed = YES;
        } @finally {
            g_isAudioDecoding = NO;
        }
        // 解码期间换了素材：刚才那次会被身份校验丢弃，补解码一次，否则新音频永远进不了内存
        if (!g_audioFailed && g_audioReader != reader) [self decodeAudioToMemory];
    });
}

// 对齐 VCAM pullAudioData:length: (0xdc5c)：从内存 PCM 按偏移切片，到末尾回卷，不足补 0
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    if (!outData || length == 0) return;
    // 对齐 VCAM 0xdbe8：熔断后直接输出静音
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

// 对齐 VCAM 0xe198：从音频 reader 取一帧，套用采集帧的时序后返回（调用方负责 CFRelease）
// setupAudioReaderIfNeeded 内部同样会加 g_mediaLock，而 NSLock 不可重入，
// 因此所有重建动作都必须在锁外完成
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample {
    // 对齐 VCAM 0xe208：熔断后返回 NULL → 调用方透传真实麦克风
    if (g_audioFailed) return NULL;
    if (g_audioReload) [self setupAudioReaderIfNeeded];

    CMSampleBufferRef s = NULL;
    [g_mediaLock lock];
    // 对齐 VCAM 0xe334：抽帧异常即熔断，@finally 保证锁一定释放（NSLock 不可重入）
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

    // 对齐 VCAM：取不到帧就置 reload，留给下一帧开头重建，理由同 nextSourcePixel
    if (!s) g_audioReload = YES;
    if (!s) return NULL;

    CMSampleBufferRef out = NULL;
    // 对齐 VCAM 0xe424：改时序异常同样熔断，并退回透传真实麦
    @try {
        CMSampleTimingInfo timing;
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

// 从当前 video reader 取一帧，返回 +1 引用；取帧结果通过 outState 回传。
// 对齐 VCAM 0xc090~0xc104：不做墙钟节流，一帧采集对应一帧源；
// 预览由采集回调 enqueue 到 AVSampleBufferDisplayLayer，不存在两条链路叠加消费
static CVPixelBufferRef vcm_pullVideoFrame(void) {
    CVPixelBufferRef frame = NULL;
    [g_mediaLock lock];
    @autoreleasepool {
        if (!g_videoOutput) { [g_mediaLock unlock]; return NULL; }
        CMSampleBufferRef s = [g_videoOutput copyNextSampleBuffer];
        if (s) {
            CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(s);
            if (pb) frame = (CVPixelBufferRef)CVPixelBufferRetain(pb);
            CFRelease(s);
        }
    }
    [g_mediaLock unlock];
    return frame;
}

// 取下一帧源视频：读完时按 g_isLoop 决定回卷重播还是冻结末帧，返回 +1 引用
+ (CVPixelBufferRef)nextSourcePixel {
    if (g_videoReload) [self setupVideoReaderIfNeeded];

    CVPixelBufferRef frame = vcm_pullVideoFrame();
    // 对齐 VCAM 0xbfe8~0xbff0：取不到帧就置 reload，由下一帧开头重建 reader。
    // 不再拿 reader.status 判定「读完」——status 何时变 Completed 没有时序保证，
    // 依赖它会让循环永远触发不了，画面就一直冻结在末帧。
    // 另外不在这里同帧重建：刚 startReading 的 reader 首帧必然取不到，
    // 同帧重建会白扔一个 reader，必须留给下一帧。
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

// 旋转 + contain 等比居中 + 黑底合成，返回 extent 严格为 (0,0,target) 的 CIImage
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

// 全黑底图（对齐 VCAM createBlackFrame: 0xb554）
+ (CIImage *)blackImageForTarget:(CGSize)target {
    return [[CIImage imageWithColor:[CIColor blackColor]]
            imageByCroppingToRect:CGRectMake(0, 0, target.width, target.height)];
}

// 渲染成新的 CMSampleBuffer，沿用采集帧时序与 {Exif}/{TIFF} 附件（对齐 VCAM 0xc7c0~0xc9c0）
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

// 对齐 VCAM getVideoFrame: 0xbf94：画布恒等于采集帧尺寸，旋转只作用于源画面
+ (CMSampleBufferRef)getVideoFrame:(CMSampleBufferRef)origSample {
    if (!origSample) return NULL;
    // 没选素材就原样透传，不输出黑帧；素材存在但取帧失败才走黑帧兜底
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    CIImage *img = [self composedImageForTarget:target];
    if (!img) img = [self blackImageForTarget:target];
    return [self makeSampleFromImage:img
                               width:(size_t)target.width
                              height:(size_t)target.height
                              format:pfmt
                           timingSrc:origSample];
}

// 释放视频/音频 reader
+ (void)cleanup { vcm_stopReaders(); }
@end

#pragma mark - AudioUnitRender Hook（麦克风采集替换）

// 对齐 VCAM hooked_AudioUnitRender (0x172d0)：
//   type=='auou' 且 subtype=='rioc'/'vpio'、bus==1、scope=Output 探测 ASBD，
//   按 ioData buffer 尺寸拉 PCM 后 memcpy，不做格式转换
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
    if (!ioData || inOutputBusNumber != 1)  return status;
    // 对齐 VCAM 0x1759c：熔断后本链路彻底不替换，避免每帧重复抛异常
    if (g_audioFailed)                      return status;
    if (!vcm_isMicUnit(inUnit))             return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, 1,
                                 &g_targetASBD, &propSize) == noErr
            && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            // 对齐 VCAM 0x17534：探测到 ASBD 只触发整段解码（decodeAudioToMemory 自带
            // g_hasProbedASBD 门禁）。这里不再重建 reader，避免和 AVCapture 链路抢 output。
            @try {
                [VCamMediaManager decodeAudioToMemory];
            } @catch (NSException *e) {
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
        // 对齐 VCAM 0x177e8：异常即熔断。宁可静音也不把异常抛到实时音频线程上
        g_audioFailed = YES;
    }
    free(temp);
    return noErr;
}

#pragma mark - VCamVideoProxy（视频替换）
@interface VCamVideoProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue;
@end

@implementation VCamVideoProxy {
    __weak id _originalDelegate;
}
- (void)setOriginalDelegate:(id)delegate queue:(dispatch_queue_t)queue { _originalDelegate = delegate; }

// 对齐 VCAM 0x1aae0：采集回调里取帧 → 塞进显示层 → 再转发给原 delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    // 对齐 VCAM 0x1ab8c~0x1aba0：g_videoOrientation = [connection videoOrientation]
    g_videoOrientation = connection.videoOrientation;

    CMSampleBufferRef newSample = NULL;
    if (g_isReplace) {
        @try {
            newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
            // 对齐 VCAM 0x1abe8~0x1ac48：newSample && 显示层 && isReadyForMoreMediaData
            // → flush（丢掉未显示的旧帧，保证低延迟）→ enqueueSampleBuffer:
            if (newSample && g_displayLayer && g_displayLayer.isReadyForMoreMediaData) {
                [g_displayLayer flush];
                [g_displayLayer enqueueSampleBuffer:newSample];
            }
        } @catch (NSException *e) {
            // 对齐 VCAM 0x1ac90~0x1ac9c：解码异常就直接关掉替换，避免每帧抛异常
            newSample    = NULL;
            g_isReplace  = NO;
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

#pragma mark - VCamAudioProxy（AVCaptureAudio 采集替换）
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
        // 对齐 VCAM 0x1ae40：异常即熔断，避免采集线程每帧抛异常
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

#pragma mark - AVCaptureSession（会话起停时重载 reader，对齐 VCAM 0x187e4 / 0x18888）
%hook AVCaptureSession
- (void)startRunning {
    if (g_isReplace) {
        g_videoReload = YES;
        g_audioReload = YES;
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    }
    %orig;
}
- (void)stopRunning {
    g_videoReload = YES;
    g_audioReload = YES;
    %orig;
}
%end

#pragma mark - AVCaptureVideoPreviewLayer（叠加 AVSampleBufferDisplayLayer，对齐 VCAM 0x18218）
// VCAM 的预览叠加层是 AVSampleBufferDisplayLayer（全局 0x25c10，类引用 0x25848 已确认），
// 不是普通 CALayer + contents：帧由采集回调 enqueue 进去，节奏由素材自身的 PTS 决定
%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer {
    %orig;

    // displayLink 只建一次，target 就是当前 preview layer
    // （对齐 VCAM 0x18270~0x182f8：displayLinkWithTarget:selector: → addToRunLoop:forMode:）
    if (!g_displayLink) {
        g_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(vcm_step:)];
        [g_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
    // 对齐 VCAM 0x18308~0x18390：containsObject 判重 → alloc/init → insertSublayer:above:
    if (![[self sublayers] containsObject:g_displayLayer]) {
        g_displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        [self insertSublayer:g_displayLayer above:layer];
        dispatch_async(dispatch_get_main_queue(), ^{ g_displayLayer.frame = self.bounds; });
    }
}

// 对齐 VCAM vcam_step: (0x18410)：只同步 opacity / videoGravity / frame / transform，
// 不在这里取帧（VCAM 那句 getVideoFrame:nil 是死代码，getVideoFrame: 对 nil 直接 return NULL）
%new
- (void)vcm_step:(CADisplayLink *)link {
    if (!g_displayLayer) return;

    // 对齐 VCAM 0x184ac~0x18560：素材不存在就把显示层透明掉，露出真实摄像头
    BOOL show = g_isReplace && [g_fileManager fileExistsAtPath:vcm_videoPath()];
    [g_displayLayer setOpacity:(show ? 1.0f : 0.0f)];
    if (!show) return;

    [g_displayLayer setVideoGravity:[self videoGravity]];
    [g_displayLayer setFrame:self.bounds];

    // 对齐 VCAM 0x18600~0x1874c：AVSampleBufferDisplayLayer 不会像 AVCaptureVideoPreviewLayer
    // 那样自动跟随连接方向，必须按 videoOrientation 手动补偿
    // （常量 0x1c998 = +π/2，0x1c9a0 = -π/2）
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

#pragma mark - UI 构建（透明背景 + 深色面板 + systemGray5 导航/按钮，透明背景下天然形成边界对比）
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
    // 对齐 VCAM 0x14804：换素材即复位熔断
    g_audioFailed = NO;
    if (hasVideo) {
        NSString *dest = vcm_videoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        [g_fileManager copyItemAtPath:src toPath:dest error:nil];
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭、且旧 reader 已读完，
        // setup 里的 loop 门禁会把重建挡掉，新素材就永远不生效
        vcm_stopReaders();
        g_isReplace    = YES;
        g_videoReload  = YES;
        g_audioReload  = YES;
        vcm_saveSettings();
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        if ([g_fileManager fileExistsAtPath:g_tempAudioPath]) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
        [g_fileManager copyItemAtPath:src toPath:g_tempAudioPath error:nil];
        g_audioReload = YES;
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

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
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFAudio/AVFAudio.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>

#pragma mark - 配置开关
static int  g_replaceMode = 1;      // 1=替换，0=透传真实画面
static BOOL g_isLoop      = YES;
static BOOL g_isSound     = YES;
static int  g_rotation    = 90;     // 0 / 90 / 180 / 270
static BOOL g_isMirrored  = YES;

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

#pragma mark - 音频解码缓存（对齐 VCAM g_fullAudioPCM / g_audioPlayOffset）
static NSMutableData *g_fullAudioPCM    = nil;
static NSUInteger     g_audioPlayOffset = 0;
static os_unfair_lock g_audioOffsetLock = OS_UNFAIR_LOCK_INIT;
static BOOL           g_isAudioDecoding = NO;

#pragma mark - AudioUnit 采集状态（对齐 VCAM 0x25000+0xc98 保存 ASBD）
static BOOL                        g_hasProbedASBD = NO;
static AudioStreamBasicDescription g_targetASBD    = {0};
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
    [d setInteger:g_rotation    forKey:@"vcam_rotation"];
    [d setBool:g_isLoop         forKey:@"vcam_loop"];
    [d setBool:g_isSound        forKey:@"vcam_sound"];
    [d setInteger:g_replaceMode forKey:@"vcam_mode"];
    [d setBool:g_isMirrored     forKey:@"vcam_mirror"];
    [d synchronize];
}
static void vcm_loadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"vcam_rotation"]) g_rotation   = (int)[d integerForKey:@"vcam_rotation"];
    else                                   g_rotation   = 90;
    if ([d objectForKey:@"vcam_loop"])     g_isLoop      = [d boolForKey:@"vcam_loop"];
    if ([d objectForKey:@"vcam_sound"])    g_isSound     = [d boolForKey:@"vcam_sound"];
    if ([d objectForKey:@"vcam_mode"])     g_replaceMode = (int)[d integerForKey:@"vcam_mode"];
    if ([d objectForKey:@"vcam_mirror"])   g_isMirrored  = [d boolForKey:@"vcam_mirror"];
    else                                   g_isMirrored  = YES;
}

#pragma mark - 停止 reader 与重置
static void vcm_stopReaders(void) {
    [g_mediaLock lock];
    if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
    if (g_audioReader) { [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil; }
    if (g_lastVideoPixel) { CVPixelBufferRelease(g_lastVideoPixel); g_lastVideoPixel = NULL; }
    [g_mediaLock unlock];
}
// 恢复默认设置，并清空已选音视频文件与解码缓存
static void vcm_resetSettings(void) {
    g_rotation    = 90;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_isMirrored  = YES;
    g_replaceMode = 0;
    vcm_saveSettings();

    vcm_stopReaders();

    os_unfair_lock_lock(&g_audioOffsetLock);
    g_fullAudioPCM    = nil;
    g_audioPlayOffset = 0;
    os_unfair_lock_unlock(&g_audioOffsetLock);

    if (g_tempAudioPath) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
    [g_fileManager removeItemAtPath:vcm_videoPath() error:nil];

    g_videoReload = YES;
    g_audioReload = YES;
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
        if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
        NSString *path = vcm_videoPath();
        if (![g_fileManager fileExistsAtPath:path]) { g_videoReload = NO; [g_mediaLock unlock]; return; }
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        g_videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (g_lastVideoPixel) { CVPixelBufferRelease(g_lastVideoPixel); g_lastVideoPixel = NULL; }
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
    @autoreleasepool {
        if (g_audioReader) {
            [g_audioReader cancelReading]; g_audioReader = nil; g_audioOutput = nil;
        }
        NSString *path = g_tempAudioPath;
        if (![g_fileManager fileExistsAtPath:path]) path = vcm_videoPath();
        if (![g_fileManager fileExistsAtPath:path]) { g_audioReload = NO; [g_mediaLock unlock]; return; }
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (track) {
            g_audioReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            NSDictionary *settings = @{ AVFormatIDKey: @(kAudioFormatLinearPCM) };
            g_audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
            g_audioOutput.alwaysCopiesSampleData = NO;
            [g_audioReader addOutput:g_audioOutput];
            [g_audioReader startReading];
            [self decodeAudioToMemory];
        }
    }
    g_audioReload = NO;
    [g_mediaLock unlock];
}

// 对齐 VCAM decodeAudioToMemory (0xab80)：把音频整段解码进内存，避免实时解码抖动
+ (void)decodeAudioToMemory {
    if (g_isAudioDecoding) return;
    if (!g_audioReader || !g_audioOutput) return;
    AVAssetReader *reader = g_audioReader;
    g_isAudioDecoding = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableData *pcm = [NSMutableData data];
        while (g_audioReader && g_audioOutput) {
            @autoreleasepool {
                CMSampleBufferRef s = [g_audioOutput copyNextSampleBuffer];
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
        os_unfair_lock_lock(&g_audioOffsetLock);
        if (g_audioReader == reader && reader != nil) {
            g_fullAudioPCM    = [pcm copy];
            g_audioPlayOffset = 0;
        }
        os_unfair_lock_unlock(&g_audioOffsetLock);
        g_isAudioDecoding = NO;
    });
}

// 对齐 VCAM pullAudioData:length: (0xdc5c)：从内存 PCM 按偏移切片，到末尾回卷，不足补 0
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    if (!outData || length == 0) return;
    if (length > 0x100000) { memset(outData, 0, length); return; }
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
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample {
    [g_mediaLock lock];
    CMSampleBufferRef out = NULL;
    @autoreleasepool {
        if (g_audioReload) [self setupAudioReaderIfNeeded];
        if (g_audioOutput) {
            CMSampleBufferRef s = [g_audioOutput copyNextSampleBuffer];
            if (!s && g_isLoop) {
                [self setupAudioReaderIfNeeded];
                s = [g_audioOutput copyNextSampleBuffer];
            }
            if (s) {
                CMSampleTimingInfo timing;
                if (origSample && CMSampleBufferGetSampleTimingInfo(origSample, 0, &timing) == noErr) {
                    CMSampleBufferRef tmp = NULL;
                    if (CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, s, 1, &timing, &tmp) == noErr && tmp) {
                        out = tmp;
                    }
                }
                if (out) CFRelease(s); else out = s;
            }
        }
    }
    [g_mediaLock unlock];
    return out;
}

// 取下一帧源视频，reader 读完则复用上一帧（对齐 VCAM 0xc1e4 g_lastPixelBuffer），返回 +1 引用
+ (CVPixelBufferRef)nextSourcePixel {
    if (g_videoReload) [self setupVideoReaderIfNeeded];
    CVPixelBufferRef frame = NULL;

    [g_mediaLock lock];
    @autoreleasepool {
        if (g_videoOutput) {
            CMSampleBufferRef s = [g_videoOutput copyNextSampleBuffer];
            if (s) {
                CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(s);
                if (pb) frame = (CVPixelBufferRef)CVPixelBufferRetain(pb);
                CFRelease(s);
            }
        }
        if (frame) {
            if (g_lastVideoPixel) CVPixelBufferRelease(g_lastVideoPixel);
            g_lastVideoPixel = (CVPixelBufferRef)CVPixelBufferRetain(frame);
        } else if (g_lastVideoPixel) {
            frame = (CVPixelBufferRef)CVPixelBufferRetain(g_lastVideoPixel);
        }
    }
    [g_mediaLock unlock];

    if (!frame && g_isLoop) {
        [self setupVideoReaderIfNeeded];
        [g_mediaLock lock];
        @autoreleasepool {
            if (g_videoOutput) {
                CMSampleBufferRef s = [g_videoOutput copyNextSampleBuffer];
                if (s) {
                    CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(s);
                    if (pb) frame = (CVPixelBufferRef)CVPixelBufferRetain(pb);
                    CFRelease(s);
                }
            }
            if (frame) {
                if (g_lastVideoPixel) CVPixelBufferRelease(g_lastVideoPixel);
                g_lastVideoPixel = (CVPixelBufferRef)CVPixelBufferRetain(frame);
            }
        }
        [g_mediaLock unlock];
    }
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
    if (g_replaceMode == 0 || !g_isSound)   return status;
    if (!ioData || inOutputBusNumber != 1)  return status;

    AudioComponent comp = AudioComponentInstanceGetComponent(inUnit);
    if (!comp) return status;
    AudioComponentDescription cd = {0};
    if (AudioComponentGetDescription(comp, &cd) != noErr) return status;
    if (cd.componentType != 'auou') return status;
    if (cd.componentSubType != 'rioc' && cd.componentSubType != 'vpio') return status;

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        if (AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output, 1,
                                 &g_targetASBD, &propSize) == noErr
            && g_targetASBD.mSampleRate > 0) {
            g_hasProbedASBD = YES;
            [VCamMediaManager setupAudioReaderIfNeeded];
            [VCamMediaManager decodeAudioToMemory];
        }
    }
    if (!g_hasProbedASBD) return status;

    UInt32 size = ioData->mBuffers[0].mDataByteSize;
    if (size == 0 || size > 0x100000) return status;

    uint8_t *temp = (uint8_t *)calloc(1, size);
    if (!temp) return status;
    [VCamMediaManager pullAudioData:temp length:size];
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        if (!ioData->mBuffers[i].mData) continue;
        if (ioData->mBuffers[i].mDataByteSize != size) continue;
        memcpy(ioData->mBuffers[i].mData, temp, size);
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

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
     fromConnection:(AVCaptureConnection *)connection {
    if (g_replaceMode == 1) {
        CMSampleBufferRef newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
        if (newSample) {
            if (_originalDelegate &&
                [_originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
                [_originalDelegate captureOutput:output didOutputSampleBuffer:newSample fromConnection:connection];
            }
            CFRelease(newSample);
            return;
        }
    }
    if (_originalDelegate &&
        [_originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
        [_originalDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
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

    if (g_replaceMode == 1 && g_isSound) {
        CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer];
        if (rep) outBuf = rep;
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
    if (g_replaceMode == 0) { return %orig; }

    CMSampleBufferRef newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
    if (newSample) return (__bridge_transfer id)newSample;
    return %orig;
}
%end

#pragma mark - AVCaptureSession（会话起停时重载 reader，对齐 VCAM 0x187e4 / 0x18888）
%hook AVCaptureSession
- (void)startRunning {
    if (g_replaceMode == 1) {
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

#pragma mark - AVCaptureVideoPreviewLayer（本地预览叠加假画面，对齐 VCAM 0x18130）
static char kVCamOverlayTag;
@interface VCamPreviewPump : NSObject
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, strong) NSHashTable   *overlays;
+ (instancetype)shared;
- (void)addOverlay:(CALayer *)layer;
- (void)tick;
@end
@implementation VCamPreviewPump
+ (instancetype)shared {
    static VCamPreviewPump *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [self new]; s.overlays = [NSHashTable weakObjectsHashTable]; });
    return s;
}
- (void)addOverlay:(CALayer *)layer {
    if (!layer) return;
    @synchronized(self) { [self.overlays addObject:layer]; }
    if (!self.link) {
        self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
        [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}
- (void)tick {
    if (g_replaceMode != 1) return;
    @synchronized(self) {
        for (CALayer *ov in self.overlays) {
            if (!ov) continue;
            CGSize sz = ov.bounds.size;
            if (sz.width <= 0 || sz.height <= 0) sz = CGSizeMake(720, 1280);
            CIImage *img = [VCamMediaManager composedImageForTarget:sz];
            if (!img) { ov.contents = nil; continue; }
            CGImageRef cg = [g_ciContext createCGImage:img fromRect:img.extent];
            if (cg) { ov.contents = (__bridge id)cg; CGImageRelease(cg); }
        }
    }
}
@end

%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer {
    if (layer && objc_getAssociatedObject(layer, &kVCamOverlayTag)) { %orig; return; }
    %orig;
    if (g_replaceMode == 1) {
        CALayer *ov = [CALayer layer];
        objc_setAssociatedObject(ov, &kVCamOverlayTag, @(YES), OBJC_ASSOCIATION_RETAIN);
        ov.frame = self.bounds;
        ov.opacity = 1.0;
        [self addSublayer:ov];
        [[VCamPreviewPump shared] addOverlay:ov];
    }
}
%end

#pragma mark - VCamMenuVC（控制菜单界面）
@interface VCamMenuVC : UIViewController
    <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>
@end

@implementation VCamMenuVC {
    UIView   *_panelView;
    UILabel  *_statusLbl;
    UIButton *_btnLoop;
    UIButton *_btnSound;
    UIButton *_btnRotate;
    UIButton *_btnEnable;
    UIButton *_btnMirror;
    UIButton *_btnReset;
    UIView   *_contentView;
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
    _statusLbl = [[UILabel alloc] init];
    _statusLbl.font = [UIFont systemFontOfSize:13];
    _statusLbl.textColor = [UIColor secondaryLabelColor];
    _statusLbl.numberOfLines = 0;
    _statusLbl.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_statusLbl];
    [NSLayoutConstraint activateConstraints:@[
        [_statusLbl.topAnchor      constraintEqualToAnchor:_contentView.topAnchor],
        [_statusLbl.leadingAnchor  constraintEqualToAnchor:_contentView.leadingAnchor],
        [_statusLbl.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor],
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

    _btnEnable = [self addGridButton:g_replaceMode == 1 ? @"替换: 开" : @"替换: 关"
                  x:0 y:y w:btnW h:btnH action:@selector(toggleReplace)];
    _btnReset  = [self addGridButton:@"重置" x:btnW + gap y:y w:btnW h:btnH action:@selector(actionReset)];
    y += btnH + gap;

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作
- (void)toggleRotate { g_rotation = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop   { g_isLoop = !g_isLoop; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound  { g_isSound = !g_isSound; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleReplace{ g_replaceMode = (g_replaceMode == 1) ? 0 : 1; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleMirror { g_isMirrored = !g_isMirrored; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)actionReset  { vcm_resetSettings(); [self refreshGridButtons]; }

- (void)refreshGridButtons {
    UIFont *font = [UIFont systemFontOfSize:[UIFont systemFontSize] weight:UIFontWeightMedium];
    UIButtonConfiguration *configRotate = _btnRotate.configuration;
    configRotate.attributedTitle = [[NSAttributedString alloc] initWithString:
        [NSString stringWithFormat:@"旋转 (%d°)", g_rotation] attributes:@{NSFontAttributeName: font}];
    _btnRotate.configuration = configRotate;
    UIButtonConfiguration *configLoop = _btnLoop.configuration;
    configLoop.attributedTitle = [[NSAttributedString alloc] initWithString:
        (g_isLoop ? @"循环: 开" : @"循环: 关") attributes:@{NSFontAttributeName: font}];
    _btnLoop.configuration = configLoop;
    UIButtonConfiguration *configSound = _btnSound.configuration;
    configSound.attributedTitle = [[NSAttributedString alloc] initWithString:
        (g_isSound ? @"声音: 开" : @"声音: 关") attributes:@{NSFontAttributeName: font}];
    _btnSound.configuration = configSound;
    UIButtonConfiguration *configEnable = _btnEnable.configuration;
    configEnable.attributedTitle = [[NSAttributedString alloc] initWithString:
        (g_replaceMode == 1 ? @"替换: 开" : @"替换: 关") attributes:@{NSFontAttributeName: font}];
    _btnEnable.configuration = configEnable;

    UIButtonConfiguration *configMirror = _btnMirror.configuration;
    configMirror.attributedTitle = [[NSAttributedString alloc] initWithString:
        (g_isMirrored ? @"镜像: 开" : @"镜像: 关") attributes:@{NSFontAttributeName: font}];
    _btnMirror.configuration = configMirror;

    [self updateStatusUI];
}
- (void)updateStatusUI {
    NSString *vStat = [g_fileManager fileExistsAtPath:vcm_videoPath()] ? @"已加载" : @"未选择";
    _statusLbl.text = [NSString stringWithFormat:@"视频: %@", vStat];
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

    NSArray *contentTypes = @[UTTypeMovie, UTTypeAudio, UTTypeImage];
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
    if (hasVideo) {
        NSString *dest = vcm_videoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        [g_fileManager copyItemAtPath:src toPath:dest error:nil];
        g_replaceMode  = 1;
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVFAudio/AVFAudio.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#pragma mark - 全局变量
static NSFileManager *g_fileManager = nil;
static NSLock       *g_mediaLock    = nil;
static CIContext    *g_ciContext    = nil;

static AVAssetReader            *videoReader = nil;
static AVAssetReaderTrackOutput *videoOutput = nil;

static AVAssetReader            *audioReader = nil;
static AVAssetReaderTrackOutput *audioOutput = nil;
static NSMutableData            *g_audioFIFO = nil;

static BOOL                         g_hasProbedASBD = NO;
static AudioStreamBasicDescription  g_targetASBD    = {0};

static int  g_sourceChannels = 2;

static BOOL g_enableReplacement = YES;
static BOOL g_isLoop             = YES;
static BOOL g_isSound            = YES;
static int  g_rotation           = 90;

static BOOL g_isMirrored = NO;

static BOOL g_enablePhotoReplacement = NO;

static UIImage *g_currentPhotoImg = nil;

static BOOL g_videoReload = NO;
static BOOL g_audioReload = NO;

static OSStatus (*orig_AudioUnitRender)(
    AudioUnit                  inUnit,
    AudioUnitRenderActionFlags *ioActionFlags,
    const AudioTimeStamp       *inTimeStamp,
    UInt32                     inOutputBusNumber,
    UInt32                     inNumberFrames,
    AudioBufferList            *ioData
) = NULL;

static NSString *g_videoDir      = nil;
static NSString *g_tempVideoPath = nil;
static NSString *g_tempAudioPath = nil;

static NSString *g_photoPath     = nil;

#pragma mark - 配置持久化
static void SaveSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:g_rotation        forKey:@"vcam_rotation"];
    [d setBool:g_isLoop             forKey:@"vcam_loop"];
    [d setBool:g_isSound            forKey:@"vcam_sound"];
    [d setBool:g_enableReplacement  forKey:@"vcam_enable"];
    [d setBool:g_isMirrored         forKey:@"vcam_mirror"];             
    [d setBool:g_enablePhotoReplacement forKey:@"vcam_photoreplace"];  
    [d synchronize];
}
static void LoadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:@"vcam_rotation"]) g_rotation         = (int)[d integerForKey:@"vcam_rotation"];
    else                                   g_rotation         = 90;
    if ([d objectForKey:@"vcam_loop"])     g_isLoop            = [d boolForKey:@"vcam_loop"];
    if ([d objectForKey:@"vcam_sound"])    g_isSound           = [d boolForKey:@"vcam_sound"];
    if ([d objectForKey:@"vcam_enable"])   g_enableReplacement = [d boolForKey:@"vcam_enable"];
    if ([d objectForKey:@"vcam_mirror"])         g_isMirrored         = [d boolForKey:@"vcam_mirror"];          
    if ([d objectForKey:@"vcam_photoreplace"])    g_enablePhotoReplacement = [d boolForKey:@"vcam_photoreplace"]; 
}

#pragma mark - 文件路径辅助
static NSString *GetDocumentPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}
static NSString *getSandboxVideoPath(void) {
    return [g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"];
}

#pragma mark - 视图控制器查找
static UIViewController *bear_getTopVC(void) {
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

#pragma mark - [FIX] int16 源 → 目标 ASBD 转换

static void vcam_convert_int16_to_asbd(const int16_t *src, int srcChannels,
                                       const AudioStreamBasicDescription *asbd,
                                       AudioBufferList *ioData, UInt32 frames) {
    if (!src || !asbd || !ioData || frames == 0) return;
    BOOL isFloat = (asbd->mFormatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL nonInt  = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    int  dstCh   = asbd->mChannelsPerFrame;
    if (dstCh <= 0) dstCh = 1;
    int  bits    = asbd->mBitsPerChannel;
    if (bits < 1) bits = isFloat ? 32 : 16;
    if (srcChannels <= 0) srcChannels = 1;

    for (UInt32 i = 0; i < frames; i++) {
        for (int c = 0; c < dstCh; c++) {
            int16_t s = 0;
            int idx = (srcChannels >= dstCh) ? c : 0;   
            s = src[i * srcChannels + idx];

            if (isFloat) {
                float f = s / 32768.0f;
                if (nonInt) {
                    float *d = (float *)ioData->mBuffers[c].mData;
                    if (d) d[i] = f;
                } else {
                    float *d = (float *)ioData->mBuffers[0].mData;
                    if (d) d[i * dstCh + c] = f;
                }
            } else if (bits == 32) {
                
                int32_t v = (int32_t)s;
                if (asbd->mFormatFlags & kAudioFormatFlagIsAlignedHigh) v = (int32_t)s << 16;
                if (nonInt) {
                    int32_t *d = (int32_t *)ioData->mBuffers[c].mData;
                    if (d) d[i] = v;
                } else {
                    int32_t *d = (int32_t *)ioData->mBuffers[0].mData;
                    if (d) d[i * dstCh + c] = v;
                }
            } else {
                
                int16_t v = s;
                if (nonInt) {
                    int16_t *d = (int16_t *)ioData->mBuffers[c].mData;
                    if (d) d[i] = v;
                } else {
                    int16_t *d = (int16_t *)ioData->mBuffers[0].mData;
                    if (d) d[i * dstCh + c] = v;
                }
            }
        }
    }
}

#pragma mark - MediaManager
@interface MediaManager : NSObject
+ (void)setupVideoReaderIfNeeded;
+ (void)setupAudioReaderIfNeeded;
+ (CIImage *)getVideoFrame:(CGSize)targetSize;
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length;
+ (void)cleanup;

+ (CIImage *)vcam_fitImage:(CIImage *)img toSize:(CGSize)targetSize;

+ (CIImage *)vcam_mirrorImage:(CIImage *)img;
@end

@implementation MediaManager
+ (void)setupVideoReaderIfNeeded {
    [g_mediaLock lock];
    @autoreleasepool {
        if (videoReader) { [videoReader cancelReading]; videoReader = nil; videoOutput = nil; }
        NSString *path = getSandboxVideoPath();
        if (![g_fileManager fileExistsAtPath:path]) { g_videoReload = NO; [g_mediaLock unlock]; return; }
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (track) {
            NSDictionary *settings = @{
                (id)kCVPixelBufferPixelFormatTypeKey:    @(kCVPixelFormatType_32BGRA),
                (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
            };
            videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
            videoOutput.alwaysCopiesSampleData = NO;
            [videoReader addOutput:videoOutput];
            [videoReader startReading];
        }
    }
    g_videoReload = NO;
    [g_mediaLock unlock];
}

+ (void)setupAudioReaderIfNeeded {
    [g_mediaLock lock];
    @autoreleasepool {
        if (audioReader) {
            [audioReader cancelReading]; audioReader = nil; audioOutput = nil;
            g_audioFIFO = nil;   
        }
        NSString *path = g_tempAudioPath;
        if (![g_fileManager fileExistsAtPath:path]) path = getSandboxVideoPath();
        if (![g_fileManager fileExistsAtPath:path]) { g_audioReload = NO; [g_mediaLock unlock]; return; }
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (track) {
            
            CMAudioFormatDescriptionRef desc = (__bridge CMAudioFormatDescriptionRef)track.formatDescriptions.firstObject;
            if (desc) {
                const AudioStreamBasicDescription *t = CMAudioFormatDescriptionGetStreamBasicDescription(desc);
                if (t && t->mChannelsPerFrame > 0) g_sourceChannels = t->mChannelsPerFrame;
            }
            if (g_sourceChannels <= 0) g_sourceChannels = 2;

            audioReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:@{
                AVFormatIDKey:               @(kAudioFormatLinearPCM),
                AVLinearPCMBitDepthKey:      @16,
                AVLinearPCMIsFloatKey:       @NO,
                AVLinearPCMIsBigEndianKey:   @NO,
                AVLinearPCMIsNonInterleaved: @NO,
            }];
            
            if (g_hasProbedASBD && g_targetASBD.mSampleRate > 0) {
                settings[AVSampleRateKey] = @(g_targetASBD.mSampleRate);
            }
            audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
            audioOutput.alwaysCopiesSampleData = NO;
            [audioReader addOutput:audioOutput];
            [audioReader startReading];
        }
    }
    g_audioReload = NO;
    [g_mediaLock unlock];
}

+ (CIImage *)vcam_fitImage:(CIImage *)img toSize:(CGSize)targetSize {
    if (!img) return nil;
    CGRect e = img.extent;
    if (e.origin.x != 0 || e.origin.y != 0)
        img = [img imageByApplyingTransform:CGAffineTransformMakeTranslation(-e.origin.x, -e.origin.y)];
    e = img.extent;
    CGFloat scale = MAX(targetSize.width / e.size.width, targetSize.height / e.size.height);
    CIImage *scaled = [img imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    CGRect se = scaled.extent;
    CGFloat ox = (se.size.width - targetSize.width) / 2.0;
    CGFloat oy = (se.size.height - targetSize.height) / 2.0;
    CIImage *crop = [scaled imageByCroppingToRect:CGRectMake(ox, oy, targetSize.width, targetSize.height)];
    CGRect ce = crop.extent;
    if (ce.origin.x != 0 || ce.origin.y != 0)
        crop = [crop imageByApplyingTransform:CGAffineTransformMakeTranslation(-ce.origin.x, -ce.origin.y)];
    return crop;
}

+ (CIImage *)vcam_mirrorImage:(CIImage *)img {
    if (!img) return nil;
    CGRect e = img.extent;
    CGAffineTransform t = CGAffineTransformMakeTranslation(e.size.width, 0);
    t = CGAffineTransformScale(t, -1, 1);
    CIImage *m = [img imageByApplyingTransform:t];
    CGRect me = m.extent;
    if (me.origin.x != 0 || me.origin.y != 0)
        m = [m imageByApplyingTransform:CGAffineTransformMakeTranslation(-me.origin.x, -me.origin.y)];
    return m;
}

+ (CIImage *)getVideoFrame:(CGSize)targetSize {
    
    if (g_enablePhotoReplacement && g_currentPhotoImg) {
        CIImage *photo = [CIImage imageWithCGImage:g_currentPhotoImg.CGImage];
        if (photo) {
            CIImage *fitted = [self vcam_fitImage:photo toSize:targetSize];
            if (g_isMirrored) fitted = [self vcam_mirrorImage:fitted];
            return fitted;
        }
    }

    if (g_videoReload) [self setupVideoReaderIfNeeded];
    [g_mediaLock lock];
    CIImage *result = nil;
    @autoreleasepool {
        CMSampleBufferRef sample = [videoOutput copyNextSampleBuffer];
        if (!sample && g_isLoop) {
            [g_mediaLock unlock];
            [self setupVideoReaderIfNeeded];
            [g_mediaLock lock];
            sample = [videoOutput copyNextSampleBuffer];
        }
        if (sample) {
            CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sample);
            if (pix) {
                CIImage *img = [CIImage imageWithCVPixelBuffer:pix options:nil];
                if (img) {
                    CIImage *rotated = img;
                    if (g_rotation != 0) {
                        CGRect extent = img.extent;
                        CGAffineTransform t = CGAffineTransformIdentity;
                        if (g_rotation == 90) {
                            t = CGAffineTransformMakeTranslation(extent.size.height, 0);
                            t = CGAffineTransformRotate(t, M_PI_2);
                        } else if (g_rotation == 180) {
                            t = CGAffineTransformMakeTranslation(extent.size.width, extent.size.height);
                            t = CGAffineTransformRotate(t, M_PI);
                        } else if (g_rotation == 270) {
                            t = CGAffineTransformMakeTranslation(0, extent.size.width);
                            t = CGAffineTransformRotate(t, 3 * M_PI_2);
                        }
                        rotated = [img imageByApplyingTransform:t];
                    }
                    CGRect rotatedExtent = rotated.extent;
                    if (rotatedExtent.origin.x != 0 || rotatedExtent.origin.y != 0) {
                        CGAffineTransform translate = CGAffineTransformMakeTranslation(-rotatedExtent.origin.x,
                                                                                      -rotatedExtent.origin.y);
                        rotated = [rotated imageByApplyingTransform:translate];
                    }
                    CGRect normalizedExtent = rotated.extent;
                    CGFloat scale = MAX(targetSize.width / normalizedExtent.size.width,
                                        targetSize.height / normalizedExtent.size.height);
                    CIImage *scaled = [rotated imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
                    CGRect scaledExtent = scaled.extent;
                    CGFloat offsetX = (scaledExtent.size.width - targetSize.width) / 2.0;
                    CGFloat offsetY = (scaledExtent.size.height - targetSize.height) / 2.0;
                    CGRect cropRect = CGRectMake(offsetX, offsetY, targetSize.width, targetSize.height);
                    result = [scaled imageByCroppingToRect:cropRect];
                    CGRect resultExtent = result.extent;
                    if (resultExtent.origin.x != 0 || resultExtent.origin.y != 0) {
                        CGAffineTransform translateBack = CGAffineTransformMakeTranslation(-resultExtent.origin.x,
                                                                                           -resultExtent.origin.y);
                        result = [result imageByApplyingTransform:translateBack];
                    }
                }
            }
            CFRelease(sample);
        }
    }
    
    if (g_isMirrored && result) result = [self vcam_mirrorImage:result];
    [g_mediaLock unlock];
    return result;
}

+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length {
    [g_mediaLock lock];
    @autoreleasepool {
        if (!g_audioFIFO) g_audioFIFO = [NSMutableData dataWithCapacity:length * 4];
        while (g_audioFIFO.length < length) {
            if (g_audioReload) [self setupAudioReaderIfNeeded];
            CMSampleBufferRef sample = [audioOutput copyNextSampleBuffer];
            if (!sample) {
                if (g_isLoop) {
                    [self setupAudioReaderIfNeeded];
                    sample = [audioOutput copyNextSampleBuffer];
                }
                if (!sample) break;
            }
            if (sample) {
                CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sample);
                if (block) {
                    size_t totalLen = 0;
                    char  *dataPtr = NULL;
                    size_t lenAtOffset = 0;
                    OSStatus s = CMBlockBufferGetDataPointer(block, 0, &lenAtOffset, &totalLen, &dataPtr);
                    if (s == kCMBlockBufferNoErr && totalLen > 0 && dataPtr) {
                        [g_audioFIFO appendBytes:dataPtr length:totalLen];
                    }
                }
                CFRelease(sample);
            }
        }
        NSUInteger copyLen = MIN(length, g_audioFIFO.length);
        if (copyLen > 0) {
            memcpy(outData, g_audioFIFO.bytes, copyLen);
            [g_audioFIFO replaceBytesInRange:NSMakeRange(0, copyLen) withBytes:NULL length:0];
        }
        if (copyLen < length)
            memset(outData + copyLen, 0, length - copyLen);
    }
    [g_mediaLock unlock];
}

+ (void)cleanup {
    [g_mediaLock lock];
    if (videoReader) { [videoReader cancelReading]; videoReader = nil; videoOutput = nil; }
    if (audioReader) { [audioReader cancelReading]; audioReader = nil; audioOutput = nil; }
    g_audioFIFO = nil;
    g_hasProbedASBD = NO;
    [g_mediaLock unlock];
}
@end

#pragma mark - AudioUnitRender Hook（音频替换）
static OSStatus hooked_AudioUnitRender(
    AudioUnit                   inUnit,
    AudioUnitRenderActionFlags  *ioActionFlags,
    const AudioTimeStamp       *inTimeStamp,
    UInt32                      inOutputBusNumber,
    UInt32                      inNumberFrames,
    AudioBufferList             *ioData
) {
    OSStatus status = orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp,
                                           inOutputBusNumber, inNumberFrames, ioData);
    if (status != noErr)                     return status;
    if (!g_enableReplacement || !g_isSound)  return status;

    AudioComponentDescription cd = {0};
    AudioComponent comp = AudioComponentInstanceGetComponent(inUnit);
    if (comp && AudioComponentGetDescription(comp, &cd) == noErr) {
        OSType sub = cd.componentSubType;
        BOOL isMic = (sub == 'rioc') || (sub == 'vpio') || (sub == 'auou');
        if (!isMic) return status;
    }

    if (!g_hasProbedASBD) {
        UInt32 propSize = sizeof(g_targetASBD);
        AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Output, inOutputBusNumber,
                             &g_targetASBD, &propSize);
        g_hasProbedASBD = YES;
        
        [MediaManager setupAudioReaderIfNeeded];
    }
    if (g_targetASBD.mChannelsPerFrame == 0) g_targetASBD.mChannelsPerFrame = 1;

    int srcCh = g_sourceChannels ?: 2;
    
    NSUInteger needBytes = inNumberFrames * srcCh * 2;
    uint8_t *raw = (uint8_t *)malloc(needBytes);
    if (!raw) return noErr;
    [MediaManager pullAudioData:raw length:needBytes];
    vcam_convert_int16_to_asbd((const int16_t *)raw, srcCh, &g_targetASBD, ioData, inNumberFrames);
    free(raw);
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
    if (g_enableReplacement) {
        CVPixelBufferRef origPixel = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (origPixel) {
            size_t  tw   = CVPixelBufferGetWidth(origPixel);
            size_t  th   = CVPixelBufferGetHeight(origPixel);
            OSType  pfmt = CVPixelBufferGetPixelFormatType(origPixel);
            CIImage *img = [MediaManager getVideoFrame:CGSizeMake(tw, th)];
            if (img) {
                NSDictionary *pbAttrs = @{
                    (id)kCVPixelBufferPixelFormatTypeKey:    @(pfmt),
                    (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
                };
                CVPixelBufferRef newPixel = NULL;
                CVPixelBufferCreate(kCFAllocatorDefault, tw, th, pfmt, (__bridge CFDictionaryRef)pbAttrs, &newPixel);
                if (newPixel) {
                    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
                    [g_ciContext render:img toCVPixelBuffer:newPixel bounds:CGRectMake(0, 0, tw, th) colorSpace:cs];
                    CGColorSpaceRelease(cs);
                    CMVideoFormatDescriptionRef fmtDesc = NULL;
                    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, newPixel, &fmtDesc);
                    CMSampleTimingInfo timing;
                    OSStatus timingStatus = CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing);
                    CMSampleBufferRef newSample = NULL;
                    if (timingStatus == noErr) {
                        CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, newPixel, YES,
                                                           NULL, NULL, fmtDesc, &timing, &newSample);
                    }
                    if (fmtDesc) CFRelease(fmtDesc);
                    CVPixelBufferRelease(newPixel);
                    if (newSample) {
                        if (_originalDelegate &&
                            [_originalDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
                            [_originalDelegate captureOutput:output didOutputSampleBuffer:newSample fromConnection:connection];
                        }
                        CFRelease(newSample);
                        return;
                    }
                }
            }
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

#pragma mark - [FIX] VCamAudioProxy（音频采集替换：覆盖 AVFoundation 麦克风路径）
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

    if (g_enableReplacement && g_isSound) {
        CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
        const AudioStreamBasicDescription *asbd = fmt ? CMAudioFormatDescriptionGetStreamBasicDescription(fmt) : NULL;
        if (asbd && asbd->mFormatID == kAudioFormatLinearPCM) {
            UInt32 frames = (UInt32)CMSampleBufferGetNumSamples(sampleBuffer);
            int dstCh = asbd->mChannelsPerFrame;
            if (dstCh <= 0) dstCh = 1;
            int bytesPerSamp = asbd->mBitsPerChannel / 8;
            if (bytesPerSamp < 1) bytesPerSamp = (asbd->mFormatFlags & kAudioFormatFlagIsFloat) ? 4 : 2;
            BOOL nonInt = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
            UInt32 totalBytes = frames * bytesPerSamp * (nonInt ? dstCh : 1);

            uint8_t *data = (uint8_t *)calloc(totalBytes, 1);
            if (data) {
                AudioBufferList abl;
                abl.mNumberBuffers = nonInt ? dstCh : 1;
                for (int c = 0; c < (int)abl.mNumberBuffers; c++) {
                    abl.mBuffers[c].mNumberChannels = nonInt ? 1 : dstCh;
                    abl.mBuffers[c].mDataByteSize    = frames * bytesPerSamp;
                    abl.mBuffers[c].mData            = data + (nonInt ? c * frames * bytesPerSamp : 0);
                }
                int srcCh = g_sourceChannels ?: 2;
                NSUInteger need = frames * srcCh * 2;
                uint8_t *raw = (uint8_t *)malloc(need);
                if (raw) {
                    [MediaManager pullAudioData:raw length:need];
                    vcam_convert_int16_to_asbd((const int16_t *)raw, srcCh, asbd, &abl, frames);
                    free(raw);

                    CMBlockBufferRef block = NULL;
                    
                    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, data, totalBytes,
                                                       kCFAllocatorDefault, NULL, 0, totalBytes, 0, &block);
                    if (block) {
                        AudioChannelLayoutTag tag = (dstCh == 1) ? kAudioChannelLayoutTag_Mono
                                                                : kAudioChannelLayoutTag_Stereo;
                        AudioChannelLayout layout = {0}; layout.mChannelLayoutTag = tag;
                        CMAudioFormatDescriptionRef newFmt = NULL;
                        CMAudioFormatDescriptionCreate(kCFAllocatorDefault, asbd,
                                                       sizeof(layout), &layout, 0, NULL, NULL, &newFmt);
                        CMSampleTimingInfo timing;
                        if (newFmt && CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timing) == noErr) {
                            CMSampleBufferRef newS = NULL;
                            
                            CMSampleBufferCreate(kCFAllocatorDefault, block, YES, NULL, NULL,
                                                 newFmt, frames, 1, &timing, 0, NULL, &newS);
                            if (newS) outBuf = newS;
                        }
                        if (newFmt) CFRelease(newFmt);
                        CFRelease(block);
                    } else {
                        free(data);   
                    }
                } else {
                    free(data);
                }
            }
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

#pragma mark - LittleBearMenuVC（控制菜单界面）
@interface LittleBearMenuVC : UIViewController
    <UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate>
@end

@implementation LittleBearMenuVC {
    UIView   *_panelView;
    UIView   *_blurView;
    UILabel  *_statusLbl;
    UIButton *_btnLoop;
    UIButton *_btnSound;
    UIButton *_btnRotate;
    UIButton *_btnEnable;
    UIButton *_btnMirror;   
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

#pragma mark - UI 构建
- (void)setupBackground {
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _blurView.frame = self.view.bounds;
    _blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_blurView];
}
- (void)setupPanel {
    _panelView = [[UIView alloc] init];
    _panelView.backgroundColor = [UIColor systemBackgroundColor];
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
    navBar.backgroundColor = [UIColor systemGray6Color];
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
    
    [self addGridButton:g_enablePhotoReplacement ? @"拍替: 开" : @"拍替: 关"
                  x:0 y:y w:btnW h:btnH action:@selector(togglePhotoReplacement)];
    _btnEnable = [self addGridButton:g_enableReplacement ? @"替换: 开" : @"替换: 关"
                  x:btnW + gap y:y w:btnW h:btnH action:@selector(actionRestore)];
    y += btnH + gap;
    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作
- (void)toggleRotate { g_rotation = (g_rotation + 90) % 360; SaveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop   { g_isLoop = !g_isLoop; SaveSettings(); [self refreshGridButtons]; }
- (void)toggleSound  { g_isSound = !g_isSound; SaveSettings(); [self refreshGridButtons]; }
- (void)actionRestore{ g_enableReplacement = !g_enableReplacement; SaveSettings(); [self refreshGridButtons]; }

- (void)toggleMirror { g_isMirrored = !g_isMirrored; SaveSettings(); [self refreshGridButtons]; }

- (void)togglePhotoReplacement { g_enablePhotoReplacement = !g_enablePhotoReplacement; SaveSettings(); [self refreshGridButtons]; }

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
        (g_enableReplacement ? @"替换: 开" : @"替换: 关") attributes:@{NSFontAttributeName: font}];
    _btnEnable.configuration = configEnable;
    
    UIButtonConfiguration *configMirror = _btnMirror.configuration;
    configMirror.attributedTitle = [[NSAttributedString alloc] initWithString:
        (g_isMirrored ? @"镜像: 开" : @"镜像: 关") attributes:@{NSFontAttributeName: font}];
    _btnMirror.configuration = configMirror;
    [self updateStatusUI];
}
- (void)updateStatusUI {
    NSString *vStat = [g_fileManager fileExistsAtPath:getSandboxVideoPath()] ? @"已加载" : @"未选择";
    NSString *pStat = (g_enablePhotoReplacement && g_currentPhotoImg) ? @"已选" : @"未选";  
    _statusLbl.text = [NSString stringWithFormat:@"视频: %@  照片: %@", vStat, pStat];
}
- (void)closeMenu { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - 文件选择
- (void)actionSelectAlbum {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    picker.mediaTypes = @[@"public.movie", @"public.image"];
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
        NSString *dest = getSandboxVideoPath();
        if ([g_fileManager fileExistsAtPath:dest]) [g_fileManager removeItemAtPath:dest error:nil];
        [g_fileManager copyItemAtPath:src toPath:dest error:nil];
        g_videoReload = YES;
        g_audioReload = YES;
        [MediaManager setupVideoReaderIfNeeded];
        [MediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        if ([g_fileManager fileExistsAtPath:g_tempAudioPath]) [g_fileManager removeItemAtPath:g_tempAudioPath error:nil];
        [g_fileManager copyItemAtPath:src toPath:g_tempAudioPath error:nil];
        g_audioReload = YES;
        [MediaManager setupAudioReaderIfNeeded];
    } else {
        
        NSData *data = [NSData dataWithContentsOfFile:src];
        UIImage *img = data ? [UIImage imageWithData:data] : nil;
        if (img) [self savePhoto:img];
    }
    [self refreshGridButtons];
}

- (void)savePhoto:(UIImage *)img {
    if (!img) return;
    
    if (img.imageOrientation != UIImageOrientationUp) {
        UIGraphicsBeginImageContextWithOptions(img.size, NO, img.scale);
        [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
        UIImage *norm = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (norm) img = norm;
    }
    NSData *data = UIImageJPEGRepresentation(img, 0.9);
    if (!data) data = UIImagePNGRepresentation(img);
    if (data) {
        [data writeToFile:g_photoPath atomically:YES];
        g_currentPhotoImg = [UIImage imageWithData:data];
    }
    [self refreshGridButtons];
}

#pragma mark - UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSURL *url = info[UIImagePickerControllerMediaURL];
    if (url) { [self processSelectedVideoURL:url]; return; }
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) [self savePhoto:img];
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
static void AddTapGestureToWindow(UIWindow *win) {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:win action:@selector(bear_tp)];
    tap.numberOfTapsRequired    = 2;
    tap.numberOfTouchesRequired = 2;
    tap.cancelsTouchesInView    = NO;
    [win addGestureRecognizer:tap];
}
@interface UIWindow (VCam)
- (void)bear_tp;
@end
@implementation UIWindow (VCam)
- (void)bear_tp {
    static BOOL menuVisible = NO;
    if (menuVisible) return;
    menuVisible = YES;
    UIViewController *topVC = bear_getTopVC();
    if (!topVC) { menuVisible = NO; return; }
    LittleBearMenuVC *vc = [LittleBearMenuVC new];
    vc.modalPresentationStyle = UIModalPresentationOverFullScreen;
    vc.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;
    [topVC presentViewController:vc animated:YES completion:^{ menuVisible = NO; }];
}
@end
%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{ AddTapGestureToWindow(self); });
}
%end

#pragma mark - 构造 / 析构
%ctor {
    g_fileManager = [NSFileManager defaultManager];
    g_mediaLock   = [[NSLock alloc] init];
    g_audioFIFO   = [NSMutableData data];
    LoadSettings();
    g_ciContext = [CIContext contextWithOptions:@{
        kCIContextWorkingColorSpace: (__bridge id)CGColorSpaceCreateDeviceRGB(),
    }];
    g_videoDir = [GetDocumentPath() stringByAppendingPathComponent:@"VCAM"];
    [g_fileManager createDirectoryAtPath:g_videoDir withIntermediateDirectories:YES attributes:nil error:nil];
    g_tempVideoPath = [getSandboxVideoPath() copy];
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_photoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_photo.jpg"] copy];  
    
    if ([g_fileManager fileExistsAtPath:g_photoPath]) {
        g_currentPhotoImg = [UIImage imageWithContentsOfFile:g_photoPath];
    }
    if ([g_fileManager fileExistsAtPath:g_tempVideoPath]) {
        [MediaManager setupVideoReaderIfNeeded];
        [MediaManager setupAudioReaderIfNeeded];
    }
    MSHookFunction((void *)AudioUnitRender, (void *)hooked_AudioUnitRender, (void **)&orig_AudioUnitRender);
}
%dtor {
    [MediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

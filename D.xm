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
// 其中 AudioUnit 链路采用「整段预解码进内存 + 按时钟定位读取」的方式，
// 音频在播放前一次性解码完毕，消费期间 PCM 恒定不变、永不被覆盖，从根本上保证清晰度。
//
// 音画同步：画面与声音共用同一个会话时钟 CACurrentMediaTime()，都按「会话已过多少秒」
// 定位素材位置（time-to-frame / time-to-sample），不随采集帧率漂移：
//   · 画面  want = floor(elapsed * 素材fps)，一次补齐落后帧（上限 kVCamMaxCatchUp）
//   · 声音  pos  = fmod(elapsed * 每秒字节数, PCM总长)，按字节定位、天然循环
//   · AVCapture 音频按 elapsed 追平已投递字节，且保留素材自身 duration
// 采集被压帧时画面会「跳帧」但速度恒定 —— 速度正确优先于流畅。
//
// 画面流向：素材 → AVAssetReader 取帧 → 旋转 / 等比居中 → 合成到与采集帧同尺寸黑底 →
// CIContext 渲染成同格式 CVPixelBuffer → 套用采集帧时序 → 新的 CMSampleBuffer。
//
// 容错约定：取帧 / 合成 / 音频拉取均运行在实时线程，单帧失败仅本帧降级
// （返回 NULL / 透传真实音视频 / 补零静音），下帧自动重试，不置全局标志、不关总开关。
// g_mediaLock 为不可重入 NSLock，持锁函数内不得再调用会加锁的函数；
// 含提前 return 的函数必须用 @finally 解锁，否则异常路径会漏解锁导致后续卡死。
// UIKit 已包含 Foundation / CoreGraphics / CoreAnimation，不重复引入。
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <ImageIO/ImageIO.h>          // kCGImagePropertyExifDictionary / TIFFDictionary
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>             // objc_getAssociatedObject（手势去重）
#import <substrate.h>
#include <dlfcn.h>                   // dlopen：确保 AudioToolbox 已加载再 rebind
// fishhook：C 级符号重定向，通过 dyld 改写间接符号指针实现 hook。
#include "fishhook.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/lock.h>

#pragma mark - 配置开关
static BOOL g_isReplace  = NO;      // 默认关：无素材时透传真实摄像头/麦克风；导入素材后自动开启
static BOOL g_isLoop     = YES;     // 素材读完后是否回卷重播
static BOOL g_isSound    = YES;     // 是否替换麦克风采集
// 拍照 / 拍摄（录制）期间临时置位：此时视频透传真实摄像头画面（拍出来才是真实场景），
// 拍完 / 录完清位恢复替换。仅作用于视频，声音不受此标志影响。
static BOOL g_videoSuppress = NO;
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

#pragma mark - 统一会话时钟（音画同步的地基）
// 一次会话（startRunning 或换素材）内，画面与声音共用同一个 elapsed：
//   elapsed = CACurrentMediaTime() - anchor
// anchor 采用惰性建立：第一次真正取帧/取数时才锚定，天然对齐首帧，
// 不受 startRunning 到首帧之间的启动延迟影响。
static CFTimeInterval g_clockAnchor = 0;
static BOOL           g_clockReady  = NO;

// 素材属性（建 reader 时从 AVAssetTrack 读取，用于 time-to-frame）
static double  g_srcFps      = 30.0;  // 素材帧率（track.nominalFrameRate，读不到时取 30）
static double  g_srcDuration = 0.0;   // 素材时长（秒），循环回卷用
static int64_t g_srcFrameIdx = -1;    // 素材已推进到的帧号；-1 = reader 刚重建待锚定
static CGSize  g_srcSize     = {0,0}; // 素材原生分辨率（track.naturalSize）；0,0 = 未知

// 诊断日志：观测微信实际请求的帧尺寸 / 格式，以及我们最终输出的画布尺寸。
// 仅当「尺寸或格式变化」时才追加，且为内存环形缓冲，不每帧写盘，避免拖慢采集回调。
// 设置面板「日志:导出」一键通过系统分享面板导出（存文件 / AirDrop）。
static NSMutableArray<NSString *> *g_diagLog     = nil;
static NSLock        *g_diagLock   = nil;
static const NSUInteger kVCamDiagMaxLines = 600;   // 环形上限，超出丢弃最旧
static CGSize  g_diagLastReqSize = {0,0};  // 上次记录的微信请求帧尺寸（去重用）
static OSType  g_diagLastReqFmt  = 0;     // 上次记录的微信请求像素格式
static CGSize  g_diagLastOutSize = {0,0}; // 上次记录的输出画布尺寸
static BOOL    g_diagFirstFrame  = YES;    // 首帧必定记一条完整诊断
static NSString *g_diagFilePath   = nil;   // 落盘路径（沙箱 Documents/VCAM/VCAM_diag.log）：微信重启也不丢历史日志

// 前向声明：日志函数定义在文件后方，供前面的时钟 / 同步逻辑调用。
static void vcm_log(NSString *fmt, ...);
static NSString *vcm_pixFmtName(OSType t);

// 掉帧追赶上限：一次回调最多补这么多帧。超过说明卡顿严重，直接跳位置而不是疯狂解码，
// 否则回调耗时进一步变长 → 更容易丢帧 → 正反馈卡死。
static const long long kVCamMaxCatchUp = 4;

// AudioUnit 链路：预解码 PCM 的字节速率与帧字节数，用于按时钟定位
static double g_pcmBytesPerSec  = 0.0;
static size_t g_audioFrameBytes = 1;   // 一个采样帧的字节数（帧边界对齐，防半个采样点起播爆音）

// AVCapture 音频链路：采集端格式与素材时长，用于按时钟追平
static double g_captureSampleRate      = 0.0;   // 麦克风真实采样率（从采集帧 ASBD 探测）
static double g_audioCaptureBytesPerSec = 0.0;  // 采集端每秒字节数
static double g_audioSrcDuration       = 0.0;   // 音频素材时长（秒），循环回卷用
static double g_audioConsumedBytes     = 0.0;   // 已投递给下游的音频字节数

static void vcm_resetClock(void) {
    g_clockReady         = NO;   // 下一帧重新锚定
    g_srcFrameIdx        = -1;   // 强迫画面从素材头重新锚定
    g_audioConsumedBytes = 0.0;
}
// 清掉素材目录下某个前缀的所有残留文件（扩展名随导入文件变化，不能只删固定的那一个）。
static void vcm_clearMaterialFiles(NSString *prefix) {
    for (NSString *old in [g_fileManager contentsOfDirectoryAtPath:g_videoDir error:nil]) {
        if ([old hasPrefix:prefix]) {
            [g_fileManager removeItemAtPath:[g_videoDir stringByAppendingPathComponent:old] error:nil];
        }
    }
}
static CFTimeInterval vcm_elapsed(void) {
    CFTimeInterval now = CACurrentMediaTime();
    if (!g_clockReady) {
        g_clockAnchor = now; g_clockReady = YES;
        // 时钟锚定：音画同步的地基。每次新会话首帧在此对齐，避免一上来跳到素材中段。
        vcm_log(@"[clock] 会话时钟锚定 t=%.3f", now);
    }
    return now - g_clockAnchor;
}

#pragma mark - 预览显示层
static AVSampleBufferDisplayLayer *g_displayLayer     = nil;
static CADisplayLink              *g_displayLink      = nil;
static AVCaptureVideoOrientation   g_videoOrientation = AVCaptureVideoOrientationPortrait;
// 会话是否处于 running：stopRunning（如拍照关相机）后置 NO，作为采集回调 / 显示层心跳的硬护栏，
// 杜绝在已停 session 上操作显示层或后台解码线程继续跑 → 访问已释放资源闪退。
static BOOL                        g_sessionRunning    = NO;

#pragma mark - 像素缓冲池
// 旧实现每帧 CVPixelBufferCreate：分配 + IOSurface 建/拆把采集回调拖长，
// 回调一慢就触发 alwaysDiscardsLateVideoFrames 丢帧 → 画面更慢（正反馈）。
// 改用按 (w,h,fmt) 缓存的 CVPixelBufferPool；外部仍持有旧 buffer 时 pool 会自动新建，安全。
static CVPixelBufferPoolRef g_pbPool = NULL;
static size_t               g_poolW  = 0;
static size_t               g_poolH  = 0;
static OSType               g_poolFmt = 0;

#pragma mark - 音频预解码缓冲（整段预解码进内存 + 按时钟定位读取）
// 整段音频一次性解码进内存，消费端按「会话已过秒数」换算字节偏移直接定位，期间零写入。
// 因解码在播放前完成、消费期间 PCM 不被任何写入覆盖，从架构上保证连续性，是清晰度的根本保证。
static uint8_t       *g_audioPCM      = NULL;  // 整段预解码 PCM
static size_t         g_audioPCMLen   = 0;     // PCM 总字节数
static size_t         g_audioPCMRead  = 0;     // 读取游标（顺序推进，保证样本严格连续）
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

// 作废已解码 PCM：自增代次让在途解码结果失效、停掉解码线程、持锁释放缓冲区并复位长度。
// 换素材 / ASBD 变更 / 析构三个场景语义完全一致，统一走这里。
// 必须定义在上面这批 PCM 变量之后，否则 C 语言「先声明后使用」报 undeclared identifier。
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
// 只比较影响字节布局的字段：采样率 / 声道数 / 位深 / float / non-interleaved。
// PACKED、SIGNED 等不改变排布的位必须忽略，否则同一格式会被误判成变更 → 反复作废重解码。
static BOOL vcm_asbdMatches(AudioStreamBasicDescription a, AudioStreamBasicDescription b) {
    return a.mSampleRate       == b.mSampleRate
        && a.mChannelsPerFrame == b.mChannelsPerFrame
        && a.mBitsPerChannel   == b.mBitsPerChannel
        && (((a.mFormatFlags ^ b.mFormatFlags)
             & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved)) == 0);
}

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

#pragma mark - 诊断日志
// 像素格式可读名（四字符码 → 简称），仅用于日志展示。
static NSString *vcm_pixFmtName(OSType t) {
    switch (t) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return @"420v";
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:   return @"420f";
        case kCVPixelFormatType_422YpCbCr8:                    return @"422";
        case kCVPixelFormatType_32BGRA:                        return @"BGRA";
        case kCVPixelFormatType_32ARGB:                        return @"ARGB";
        case kCVPixelFormatType_4444YpCbCrA8:                  return @"4444";
        default: return [NSString stringWithFormat:@"0x%X", (unsigned)t];
    }
}
// 追加一条带时间戳的诊断行（线程安全，环形截断）。
static void vcm_log(NSString *fmt, ...) {
    if (!fmt) return;
    static NSMutableArray<NSString *> *s_log = nil;
    static NSLock *s_lock = nil;
    static NSDateFormatter *s_fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s_log = [NSMutableArray arrayWithCapacity:64];
        s_lock = [[NSLock alloc] init];
        s_fmt = [[NSDateFormatter alloc] init];
        s_fmt.dateFormat = @"HH:mm:ss.SSS";
        g_diagLog  = s_log;   // 暴露给导出读取
        g_diagLock = s_lock;
        // 启动恢复：从落盘文件读回历史，微信重启也不丢（并回写裁剪后的内容，避免文件无限增长）
        if (g_diagFilePath) {
            NSString *hist = [NSString stringWithContentsOfFile:g_diagFilePath
                                                       encoding:NSUTF8StringEncoding error:nil];
            if (hist.length) {
                for (NSString *ln in [hist componentsSeparatedByString:@"\n"]) {
                    if (ln.length) [s_log addObject:ln];
                }
                while (s_log.count > kVCamDiagMaxLines) [s_log removeObjectAtIndex:0];
                [[s_log componentsJoinedByString:@"\n"] writeToFile:g_diagFilePath
                                                          atomically:NO encoding:NSUTF8StringEncoding error:nil];
            }
        }
    });
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    if (!msg) return;
    NSString *line = [NSString stringWithFormat:@"%@  %@",
                      [s_fmt stringFromDate:[NSDate date]], msg];
    [s_lock lock];
    [s_log addObject:line];
    if (s_log.count > kVCamDiagMaxLines) [s_log removeObjectAtIndex:0];
    [s_lock unlock];
    // 落盘追加一行（仅尺寸/格式变化或首帧/异常才记，量很小）；微信重启后仍可查看。
    if (g_diagFilePath) {
        FILE *f = fopen([g_diagFilePath UTF8String], "a");
        if (f) { fprintf(f, "%s\n", [line UTF8String]); fclose(f); }
    }
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
    // setObject:forKey: 传 nil 会直接抛异常，两条路径都做空值防御。
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
    g_srcFrameIdx = -1;   // reader 已废，画面下次必须重新锚定
}
// 换素材 / 会话重启时让两条链路从头来过。关键是清 g_hasProbedASBD：
// 不清则麦克风链路认为格式已探测完，既不重新探测新会话 ASBD 也不重新解码，新素材音频进不了麦克风。
static void vcm_reloadReaders(void) {
    // 音视频共用同一个时钟：换素材 / 新会话必须重新锚定，否则 elapsed 带着旧会话的
    // 时间继续推进 → 一上来就按「已播 N 秒」定位，画面与声音瞬间跳到素材中段。
    vcm_log(@"[reload] 换素材/新会话：作废 PCM + 重置时钟 + 标记重建 reader");
    g_videoReload   = YES;
    g_audioReload   = YES;
    g_hasProbedASBD = NO;
    // 音视频共用同一个时钟：换素材 / 新会话必须重新锚定，否则 elapsed 带着旧会话的
    // 时间继续推进 → 一上来就按「已播 N 秒」定位，画面与声音瞬间跳到素材中段。
    vcm_resetClock();
    g_decodeFailCount = 0;
    g_decodeNextRetry = 0;
    vcm_invalidatePCM();
}
// 恢复默认设置，清空已选素材与解码缓存
static void vcm_resetSettings(void) {
    g_isReplace   = NO;
    g_isLoop      = YES;
    g_isSound     = YES;
    g_rotation    = 90;

    vcm_stopReaders();
    vcm_reloadReaders();

    // 删掉所有 bear_vcam_audio.* / bear_vcam_temp.* 残留（动态扩展名后可能不止 .m4a / .mov）
    vcm_clearMaterialFiles(@"bear_vcam_audio.");
    vcm_clearMaterialFiles(@"bear_vcam_temp.");
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    // 必须在路径回退到默认值之后再存盘，否则存档里留的是刚被删掉的旧素材路径，重启即失效。
    vcm_saveSettings();

    // 重置诊断去重状态：下次会话重新抓首帧完整诊断（尺寸可能不变但想看一遍）。
    g_diagFirstFrame = YES;
    g_diagLastReqSize = CGSizeZero; g_diagLastReqFmt = 0; g_diagLastOutSize = CGSizeZero;
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

#pragma mark - 像素缓冲池（替代每帧 CVPixelBufferCreate）
static void vcm_createPool(size_t w, size_t h, OSType pfmt) {
    if (g_pbPool) { CVPixelBufferPoolRelease(g_pbPool); g_pbPool = NULL; }
    NSDictionary *attrs = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{},
        (id)kCVPixelBufferWidthKey:  @(w),
        (id)kCVPixelBufferHeightKey: @(h),
        (id)kCVPixelBufferPixelFormatTypeKey: @(pfmt),
        // 多备几块：下游（显示层 / 编码器）还会持有若干帧，避免立刻复用正在显示的 buffer
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

    // 尺寸/格式不符，或 pool 已损坏取不出 buffer → 重建后再试一次；仍不行就退回直接创建。
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
@interface VCamMediaManager : NSObject
+ (void)setupVideoReaderIfNeeded;
+ (void)setupAudioReaderIfNeeded;
+ (CVPixelBufferRef)nextSourcePixelAt:(CFTimeInterval)elapsed;   // 按会话时钟定位素材帧
+ (CIImage *)composedImageForTarget:(CGSize)target atTime:(CFTimeInterval)elapsed;
+ (CIImage *)blackImageForTarget:(CGSize)target;
+ (CMSampleBufferRef)makeSampleFromImage:(CIImage *)img
                                   width:(size_t)w height:(size_t)h
                                  format:(OSType)pfmt
                               timingSrc:(CMSampleBufferRef)src;
+ (CMSampleBufferRef)getVideoFrame:(CMSampleBufferRef)origSample;
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample atTime:(CFTimeInterval)elapsed;
+ (void)decodeAudioToMemory;   // 整段音频一次性预解码进内存（非流式）
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length atTime:(CFTimeInterval)elapsed;
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
            // 标记统一在 @finally 里清零（异常路径也要清，否则每帧重建）

            if (g_videoReader) { [g_videoReader cancelReading]; g_videoReader = nil; g_videoOutput = nil; }
            NSString *path = vcm_videoPath();
            if (![g_fileManager fileExistsAtPath:path]) return;
            AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
            g_videoReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            // 这里不清冻结的末帧，否则循环重建 reader 失败时会闪黑帧
            if (track) {
                // time-to-frame 的两个基准：素材帧率与素材时长。
                // 缺帧率就只能退回「帧到帧」，画面又会随采集帧率漂移，故读不到时取 30 并夹到合理区间。
                double fps = track.nominalFrameRate;
                if (!(fps > 1.0)) fps = 30.0;
                if (fps > 120.0) fps = 120.0;
                g_srcFps = fps;

                // 原生分辨率：输出始终按此尺寸（见 getVideoFrame），不放大到采集尺寸，对面最清晰。
                CGSize ns = track.naturalSize;
                if (ns.width > 0 && ns.height > 0 && isfinite(ns.width) && isfinite(ns.height))
                    g_srcSize = ns;
                else
                    g_srcSize = CGSizeZero;

                double dur = CMTimeGetSeconds(track.timeRange.duration);
                g_srcDuration = (dur > 0.0 && isfinite(dur)) ? dur : 0.0;

                // 诊断：素材信息变化即记一条（换素材 / reader 重建时触发），用于对照微信请求尺寸。
                vcm_log(@"[src] 素材 naturalSize=%.0fx%.0f  fps=%.2f  duration=%.2fs",
                        g_srcSize.width, g_srcSize.height, g_srcFps, g_srcDuration);

                NSDictionary *settings = @{
                    (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                };
                g_videoOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                [g_videoReader addOutput:g_videoOutput];
                if ([g_videoReader startReading]) {
                    // reader 回到素材头，帧索引必须重新锚定，否则循环回卷后
                    // want 变小而 idx 仍是旧的大值 → 判定「已超前」→ 永久冻结在末帧。
                    g_srcFrameIdx = -1;
                }
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
            // 标记统一在 @finally 里清零（异常路径也要清，否则每帧重建）

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

                // 必须把解码输出采样率对齐到采集端。旧实现只给 AVFormatIDKey，解码器按素材
                // 原生采样率直出（常见 44.1k），却被下游按 48k 的采集时钟消费 → 音频整体变速。
                // 这是「画面比声音慢」最容易被忽略的一半原因。
                NSMutableDictionary *settings = [NSMutableDictionary dictionary];
                settings[AVFormatIDKey] = @(kAudioFormatLinearPCM);
                if (g_captureSampleRate > 0) settings[AVSampleRateKey] = @(g_captureSampleRate);

                g_audioOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:settings];
                g_audioOutput.alwaysCopiesSampleData = NO;
                [g_audioReader addOutput:g_audioOutput];
                if ([g_audioReader startReading]) {
                    double dur = CMTimeGetSeconds(track.timeRange.duration);
                    g_audioSrcDuration   = (dur > 0.0 && isfinite(dur)) ? dur : 0.0;
                    g_audioConsumedBytes = 0.0;   // reader 回到素材头，已投递字节数同步归零
                }
            }
        }
        // ASBD 探明后 AudioUnit 链路才需要数据：触发整段预解码（幂等，已在跑或已就绪则忽略）。
        if (g_hasProbedASBD) {
            vcm_log(@"[audio] ASBD 已探测 (rate=%.0f ch=%u)，触发整段预解码",
                    g_targetASBD.mSampleRate, g_targetASBD.mChannelsPerFrame);
            [self decodeAudioToMemory];
        }
    } @catch (NSException *e) {
    } @finally {
        g_audioReload = NO;
        [g_mediaLock unlock];
    }
}

// 整段预解码：一次性把素材音频全部解码成目标格式 PCM 存进内存，之后消费端按时钟定位读取、期间零写入。
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

                // 落地：分配并拷贝整段 PCM，标记就绪（消费端自此按时钟定位读取）。
                size_t   total = acc.length;
                uint8_t *buf   = (uint8_t *)malloc(total);
                if (!buf) return;
                memcpy(buf, acc.bytes, total);

                // 字节速率与帧字节数：时钟定位的换算基准。
                // 字节速率必须按「解码实际使用的 ASBD」算，不能用素材原始采样率，
                // 否则 elapsed→字节偏移换算错比例，音频会整体快/慢一档。
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
            // 异常多半是素材不可解析，重试同样失败，计入退避避免每帧重启。
            g_decodeFailCount++;
            g_decodeNextRetry = [[NSDate date] timeIntervalSince1970]
                              + ((0.5 * g_decodeFailCount > 5.0) ? 5.0 : 0.5 * g_decodeFailCount);
        } @finally {
            g_audioFeederRunning = NO;
        }
    });
}

// 消费者（实时安全）：从预解码 PCM 取 length 字节。
// 以「读游标顺序推进」为主 —— 样本严格连续，接缝处不会出现跳读/重读导致的咔哒声。
// 音频本来就由硬件时钟驱动（下游按 inNumberFrames 消费），本身不会像画面那样被压帧拖慢，
// 所以不需要每帧按时钟重定位；每帧重定位反而会因为时钟抖动在接缝处跳掉或重复几个字节。
// elapsed 只用于「大偏差校正」：偏差超过半秒才把游标拉回时钟位置，吸收长时间累计误差
// （换素材、通话中切采样率、系统时钟跳变等）。
// 本函数只读、不修改 PCM，且写入方就绪后不再写入 → 消费期间 PCM 恒定不变。
+ (void)pullAudioData:(uint8_t *)outData length:(NSUInteger)length atTime:(CFTimeInterval)elapsed {
    if (!outData || length == 0) return;
    if (length > 0x100000) { memset(outData, 0, length); return; }  // 超大请求直接静音
    if (!g_audioPCMReady || !g_audioPCM || g_audioPCMLen == 0) { memset(outData, 0, length); return; }
    memset(outData, 0, length);   // 先清零：素材播完后的剩余字节必须是静音，而非未初始化脏数据

    os_unfair_lock_lock(&g_audioPCMLock);
    size_t len    = g_audioPCMLen;
    size_t frameB = (g_audioFrameBytes > 0) ? g_audioFrameBytes : 1;

    if (g_pcmBytesPerSec > 0 && len > 0) {
        double want = elapsed * g_pcmBytesPerSec;
        if (g_isLoop) want = fmod(want, (double)len);
        // loop off 且已过素材末尾：保持静音即可，不要再校正——
        // 否则会把游标反复拉回 0 造成「重播 + 每帧刷日志」的怪音/卡顿（关闭循环时声音异常的根因）。
        if (!g_isLoop && want >= (double)len) {
            os_unfair_lock_unlock(&g_audioPCMLock);
            memset(outData, 0, length);
            return;
        }
        if (fabs(want - (double)g_audioPCMRead) > g_pcmBytesPerSec * 0.5) {
            // 偏差过大才对齐一次，并对齐到帧边界，避免从半个采样点起播导致声道相位翻转
            size_t oldRead = g_audioPCMRead;
            size_t aligned = (size_t)(want / (double)frameB) * frameB;
            // loop off 时偏差若越界则停在末尾(len)保持静音；loop on 则回卷到 0
            g_audioPCMRead = (aligned < len) ? aligned : (g_isLoop ? 0 : len);
            vcm_log(@"[audio] 时钟偏差 %.3fs，游标 %zu→%zu / %zu",
                    (want - (double)oldRead) / g_pcmBytesPerSec, oldRead, g_audioPCMRead, len);
        }
    }

    if (g_audioPCMRead >= len) {
        if (g_isLoop) g_audioPCMRead = 0;                       // 回卷重播
        else {                                                   // 一次性播放：播完静音
            os_unfair_lock_unlock(&g_audioPCMLock);
            memset(outData, 0, length);
            return;
        }
    }

    size_t written = 0;
    while (written < length) {
        if (g_audioPCMRead >= len) {
            if (!g_isLoop) break;                                // 余下补零静音
            g_audioPCMRead = 0;                                  // 回卷重播
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

// 探测采集端音频格式：采样率变化必须重建 reader，否则解码输出与采集时钟不同率 → 变速；
// 同时算出采集端每秒字节数，供按时钟追平使用。
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
        g_audioReload = YES;   // 采样率变了 → 按新采样率重解码
    }
    UInt32 ch   = asbd->mChannelsPerFrame > 0 ? asbd->mChannelsPerFrame : 1;
    UInt32 bits = asbd->mBitsPerChannel   > 0 ? asbd->mBitsPerChannel   : 16;
    g_audioCaptureBytesPerSec = rate * (double)((bits / 8) * ch);
}

// 从音频 reader 取一帧，套用采集帧的时序后返回（调用方负责 CFRelease）。
// setupAudioReaderIfNeeded 内部也会加 g_mediaLock，而 NSLock 不可重入，故重建动作须在此之前完成。
+ (CMSampleBufferRef)getAudioFrame:(CMSampleBufferRef)origSample atTime:(CFTimeInterval)elapsed {
    if (!origSample) return NULL;

    vcm_probeCaptureAudioFormat(origSample);

    // 时钟追平：本次回调应把素材消费到 elapsed * 采集字节率 的位置。
    // 采集端来一次回调就取一帧的旧写法，在丢帧/重建时会掉队且永不补齐 → 音频落后于画面。
    double t = elapsed;
    if (g_isLoop && g_audioSrcDuration > 0.1) t = fmod(t, g_audioSrcDuration);
    double wantBytes = (g_audioCaptureBytesPerSec > 0) ? (t * g_audioCaptureBytesPerSec) : -1.0;
    if (!g_isLoop && g_audioSrcDuration > 0.1 && elapsed > g_audioSrcDuration) wantBytes = -1.0;

    // 循环回卷：已投递满一整段就重建 reader 回到素材头，与画面侧 fmod 回卷对齐。
    // 不重建的话 reader 会继续顺序播到尾才回卷，音频比画面晚整整一个素材长度。
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
                    if (caughtUp && s) break;   // 已追平且手上有一帧 → 不再超前消费
                    CMSampleBufferRef tmp = [g_audioOutput copyNextSampleBuffer];
                    if (!tmp) { g_audioReload = YES; break; }
                    if (s) CFRelease(s);
                    s = tmp;
                    CMBlockBufferRef blk = CMSampleBufferGetDataBuffer(s);
                    if (blk) g_audioConsumedBytes += (double)CMBlockBufferGetDataLength(blk);
                    if (wantBytes <= 0.0) break;  // 未知字节率：退回帧到帧，不空转
                }
            }
        }
    } @catch (NSException *e) {
    } @finally {
        [g_mediaLock unlock];
    }

    if (!s) { g_audioReload = YES; return NULL; }  // 取不到帧就标重建，留给下一帧

    CMSampleBufferRef out = NULL;
    @try {
        // 时序：PTS 用采集帧的（保证与视频同一时钟、下游排序正确），
        // duration 必须用素材自身的 —— 旧代码整条 timing 都用采集帧的，
        // 素材每帧样本数与采集不同的话，音频就被整体变速（常见 8%~12%）。
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

// 取下一帧源视频：返回 +1 引用
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

// 按「会话已过秒数」定位素材帧（time-to-frame）。
// 旧实现 nextSourcePixel 是「一个采集帧吐一个素材帧」：采集被压到 15~20fps、
// 或回调里 CI 渲染耗时触发丢帧时，素材消费速度就永久落后于真实时间 → 画面慢放并持续漂移。
// 现在：want = floor(elapsed * 素材fps)，一次补齐落后的帧；落后太多时直接跳位置而不是狂解码。
+ (CVPixelBufferRef)nextSourcePixelAt:(CFTimeInterval)elapsed {
    double fps = (g_srcFps > 1.0) ? g_srcFps : 30.0;
    double t   = elapsed;
    if (g_isLoop && g_srcDuration > 0.1) t = fmod(t, g_srcDuration);

    // loop 关：素材播完即冻结在末帧，不再重建回卷（与音频静音对齐）。
    // 否则 want 单调增长到超过素材长度后，reader 末尾 pullVideoFrame 返回 NULL 会置 g_videoReload，
    // 触发下次重建从头读 → 视频反复从头播放（用户反馈「循环关了视频还在继续播」）。
    if (!g_isLoop && g_srcDuration > 0.1 && elapsed >= g_srcDuration) {
        [g_mediaLock lock];
        CVPixelBufferRef f = g_lastVideoPixel ? CVPixelBufferRetain(g_lastVideoPixel) : NULL;
        [g_mediaLock unlock];
        if (f) return f;                 // 已出过图 → 冻结末帧
        // 尚未锚定（极少见）：降级到下面正常取一帧
    }

    if (g_videoReload) [self setupVideoReaderIfNeeded];

    long long want = (long long)floor(t * fps);
    long long need;
    if (g_srcFrameIdx < 0) {
        need = 1;                       // reader 刚重建：先取一帧把索引锚到 want
        vcm_log(@"[video] reader 重建后首帧锚定 want=%lld (fps=%.2f)", want, fps);
    } else {
        need = want - g_srcFrameIdx;
        if (need < 0) {
            // 时钟已回卷到素材头（循环）：reader 还停在上一轮的尾部位置，
            // 不重建的话会一直判定「超前」而冻结在末帧，直到旧 reader 读完为止。
            [self setupVideoReaderIfNeeded];
            g_srcFrameIdx = -1;
            need = 1;
            vcm_log(@"[video] 循环回卷：重建 reader 重新锚定");
        } else if (need == 0) {
            // 已追平：复用上一帧，不倒退
            [g_mediaLock lock];
            CVPixelBufferRef f = g_lastVideoPixel
                               ? (CVPixelBufferRef)CVPixelBufferRetain(g_lastVideoPixel) : NULL;
            [g_mediaLock unlock];
            return f;
        } else if (need > kVCamMaxCatchUp) {
            vcm_log(@"[video] 落后 %lld 帧，跳帧到 %lld（防正反馈卡死）",
                    need, (long long)kVCamMaxCatchUp);
            need = kVCamMaxCatchUp;  // 掉帧太多 → 跳帧，不一次性补完
        }
    }

    CVPixelBufferRef frame = NULL;
    for (long long i = 0; i < need; i++) {
        CVPixelBufferRef f = vcm_pullVideoFrame();
        if (!f) { g_videoReload = YES; break; }
        if (frame) CVPixelBufferRelease(frame);
        frame = f;   // 只保留这批里的最后一帧
    }
    // 位置对齐到时钟：没取到的帧直接跳过，避免下次继续堆积 need
    g_srcFrameIdx = want;

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
+ (CIImage *)composedImageForTarget:(CGSize)target atTime:(CFTimeInterval)elapsed {
    CGFloat targetW = target.width, targetH = target.height;
    if (targetW <= 0 || targetH <= 0) return nil;

    CVPixelBufferRef pix = [self nextSourcePixelAt:elapsed];
    if (!pix) return nil;
    CIImage *img = [CIImage imageWithCVPixelBuffer:pix options:nil];
    CVPixelBufferRelease(pix);
    if (!img) return nil;

    // 自动对齐方向：素材与微信帧「一方竖屏一方横屏」时，补一个 90° 让长宽边一致，
    // 否则竖屏素材(720x1280)进横屏画布(1280x720)会被拉伸/挤压得严重放大失真（即「填充放很大」）。
    // g_rotation 作为额外手动微调叠加在自动判断之上。
    NSInteger rot = g_rotation;
    CGRect srcExtent = img.extent;
    BOOL srcPortrait = srcExtent.size.height > srcExtent.size.width;
    BOOL dstPortrait = targetH > targetW;
    if (srcPortrait != dstPortrait) rot = (rot + 90) % 360;   // 方向不一致 → 补 90° 对齐

    NSInteger orient = 1;
    if      (rot == 90)  orient = 8;
    else if (rot == 180) orient = 3;
    else if (rot == 270) orient = 6;
    img = [img imageByApplyingOrientation:(CGImagePropertyOrientation)orient];

    CGRect e = img.extent;
    if (e.size.width <= 0 || e.size.height <= 0) return nil;

    // 固定铺满（scale=MAX）：等比放大到铺满再裁掉溢出，有效像素最大化 → 对端最清晰。
    // （原「适应」模式会留黑边、有效像素少且编码后偏糊，已移除切换开关。）
    CGFloat scale = MAX(targetW / e.size.width, targetH / e.size.height);
    if (!(scale > 0) || !isfinite(scale)) return nil;

    CIImage *scaled = img;
    if (fabs(scale - 1.0) > 0.002) {
        // CILanczosScaleTransform：3-lobe sinc 重采样。
        // imageByApplyingTransform 走的是默认双线性，放大时边缘被抹平 —— 这就是「有点糊」的主因。
        // 爱锋 dylib 里没有任何 CIFilter 符号、也没设 CGContextSetInterpolationQuality，
        // 所以它是同样的双线性，糊在同一个地方。
        CIFilter *f = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        [f setValue:img forKey:kCIInputImageKey];
        [f setValue:@(scale) forKey:kCIInputScaleKey];
        [f setValue:@(1.0) forKey:kCIInputAspectRatioKey];
        CIImage *out = f.outputImage;
        scaled = out ?: [img imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    }

    // 居中：按缩放后真实 extent 算（旋转后 origin 未必是 0，用预估尺寸会偏）
    CGRect r = scaled.extent;
    CGFloat tx = (targetW - r.size.width)  / 2.0 - r.origin.x;
    CGFloat ty = (targetH - r.size.height) / 2.0 - r.origin.y;
    scaled = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation(tx, ty)];

    // 裁到画布尺寸（铺满时裁掉溢出）；crop 不重采样，无损。黑底仅兜底，铺满时不可见。
    CIImage *canvas = [scaled imageByCroppingToRect:CGRectMake(0, 0, targetW, targetH)];
    img = [canvas imageByCompositingOverImage:[self blackImageForTarget:target]];

    return img;
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

    // 走像素缓冲池：每帧 CVPixelBufferCreate 的分配 + IOSurface 建拆是采集回调的主要耗时，
    // 回调一慢就更容易被 alwaysDiscardsLateVideoFrames 丢帧 → 画面更慢（正反馈）。
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
    // 没选素材就原样透传；素材存在但取帧失败才走黑帧兜底。
    if (![g_fileManager fileExistsAtPath:vcm_videoPath()]) return NULL;
    CVPixelBufferRef camPix = CMSampleBufferGetImageBuffer(origSample);
    if (!camPix) return NULL;

    CGSize target = CGSizeMake((CGFloat)CVPixelBufferGetWidth(camPix),
                               (CGFloat)CVPixelBufferGetHeight(camPix));
    OSType pfmt = CVPixelBufferGetPixelFormatType(camPix);

    // 诊断：微信实际请求的帧（来自虚拟设备的真实采集缓冲）。尺寸/格式变化或首帧才记，避免刷屏。
    {
        BOOL changed = (target.width  != g_diagLastReqSize.width)
                    || (target.height != g_diagLastReqSize.height)
                    || (pfmt           != g_diagLastReqFmt);
        if (g_diagFirstFrame || changed) {
            g_diagLastReqSize = target; g_diagLastReqFmt = pfmt;
            vcm_log(@"[req] 微信请求帧 %dx%d  fmt=%@ (0x%X)%@",
                    (int)target.width, (int)target.height,
                    vcm_pixFmtName(pfmt), (unsigned)pfmt,
                    g_diagFirstFrame ? @"  [首帧]" : @"");
        }
    }

    // 关键：输出尺寸必须严格等于微信请求的采集帧尺寸(camPix)，不能强行用素材原生尺寸。
    // 微信编码器/采样管线按 camPix 协商，我们控制不了它要多大。强行输出 720x1280 却喂进
    // 1280x720 的管线 → 被拉伸/裁剪得「放大失真」，且拍照重建采集管线时因尺寸不符直接闪退。
    // 素材通过 composedImageForTarget: 自动旋转 + 等比缩放映射到该画布，清晰度保持原生(1:1 像素)。
    // （原「短边下限」保护不再需要：camPix 本身是微信合法尺寸，强行改尺寸才会触发问题。）

    // 诊断：输出画布（恒等于微信请求尺寸）。srcSize 供对照原生素材尺寸。
    {
        BOOL changed = (target.width  != g_diagLastOutSize.width)
                    || (target.height != g_diagLastOutSize.height);
        if (g_diagFirstFrame || changed) {
            g_diagLastOutSize = target;
            vcm_log(@"[out] 输出画布 %dx%d（=微信请求尺寸，铺满裁切）  srcSize=%.0fx%.0f",
                    (int)target.width, (int)target.height,
                    g_srcSize.width, g_srcSize.height);
        }
        if (g_diagFirstFrame) g_diagFirstFrame = NO;   // 首帧诊断已发，后续仅记录变化
    }

    // 画面位置由会话时钟决定，与音频共用同一个 elapsed
    CFTimeInterval elapsed = vcm_elapsed();

    CMSampleBufferRef out = NULL;
    @try {
        @autoreleasepool {
            CIImage *img = [self composedImageForTarget:target atTime:elapsed];
            if (!img) { vcm_log(@"[warn] composedImageForTarget 返回 nil → 黑帧兜底"); img = [self blackImageForTarget:target]; }
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
    vcm_invalidatePCM();                // 含自增代次 + 停解码线程 + 释放 PCM
    vcm_stopReaders();
    vcm_resetClock();
    if (g_pbPool) { CVPixelBufferPoolRelease(g_pbPool); g_pbPool = NULL; }
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
            // PCM 若是按旧格式解码的，字节布局与当前 ASBD 错配 → 失真/变速，必须作废后重解。
            if (g_audioPCMReady && !vcm_asbdMatches(g_audioPCMFormat, g_targetASBD)) vcm_invalidatePCM();
            if (!g_audioFeederRunning) [VCamMediaManager decodeAudioToMemory];
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
                && !vcm_asbdMatches(live, g_targetASBD)) {
            g_hasProbedASBD = NO;   // 下一帧重新走探测 + 重建
            vcm_invalidatePCM();    // 含停旧解码线程，迫使其用新 ASBD 重解码
        }
    }

    // 自愈：预解码必须每帧兜底确保「按需解码」，不能只依赖首帧探测块的触发
    // （存在探测成功与该帧解码线程 @finally 清标志之间的竞态，会导致解码永远起不来、PCM 恒空、永久静音）。
    // 这里每帧兜底触发，decodeAudioToMemory 内部幂等、零开销。
    if (!g_audioFeederRunning && !g_audioPCMReady) {
        [VCamMediaManager decodeAudioToMemory];
    }

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
        // 与画面共用同一个会话时钟定位音频位置
        [VCamMediaManager pullAudioData:temp length:(UInt32)need atTime:vcm_elapsed()];
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
    if (g_isReplace && !g_videoSuppress) {   // 拍照/拍摄期间 g_videoSuppress 置位 → 视频透传真实画面
        @try {
            newSample = [VCamMediaManager getVideoFrame:sampleBuffer];
            if (newSample && g_displayLayer) {
                // 旧实现每帧 flush：清空解码队列等于丢弃所有待显示帧，预览会明显发涩。
                // 只在显示层真的满了（来不及消费）时才 flush 腾位置。
                if (!g_displayLayer.isReadyForMoreMediaData) [g_displayLayer flush];
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
    if (delegate == nil) {
        // 与音频 hook 同理：微信 detach（nil）时原样透传，避免在 session 已停时塞入非 nil 的 proxy 导致闪退。
        %orig(nil, nil);
        if (g_videoProxy) [g_videoProxy setOriginalDelegate:nil queue:nil];
        vcm_log(@"[hook] 视频 delegate=nil(detach) → 透传；session=%@",
                g_sessionRunning ? @"running" : @"stopped");
        return;
    }
    if (!g_videoProxy) g_videoProxy = [[VCamVideoProxy alloc] init];
    [g_videoProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_videoProxy, queue);
    vcm_log(@"[hook] 视频 delegate 已替换为 proxy；session=%@",
            g_sessionRunning ? @"running" : @"stopped");
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
            CMSampleBufferRef rep = [VCamMediaManager getAudioFrame:sampleBuffer atTime:vcm_elapsed()];
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
    if (delegate == nil) {
        // 关相机/销毁会话时微信把 delegate 设为 nil（detach）。原样透传，绝不替换为 proxy——
        // 否则非 nil 的 proxy 在 session 已停时被喂给 AVFoundation，触发
        // 「Session is not running」异常 → SIGABRT（崩溃栈：- [AVCaptureAudioDataOutput sampleBufferDelegate]）
        %orig(nil, nil);
        if (g_audioProxy) [g_audioProxy setOriginalDelegate:nil queue:nil];
        vcm_log(@"[hook] 音频 delegate=nil(detach) → 透传；session=%@",
                g_sessionRunning ? @"running" : @"stopped");
        return;
    }
    if (!g_audioProxy) g_audioProxy = [[VCamAudioProxy alloc] init];
    [g_audioProxy setOriginalDelegate:delegate queue:queue];
    %orig(g_audioProxy, queue);
    vcm_log(@"[hook] 音频 delegate 已替换为 proxy；session=%@",
            g_sessionRunning ? @"running" : @"stopped");
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
    // 会话真正启动后再标记 running 并恢复显示层心跳。stopRunning 时已暂停心跳 + 停解码线程，
    // 这里统一恢复：避免关相机（拍照）后显示层仍被主线程每帧操作 → 闪退。
    g_sessionRunning = YES;
    if (g_displayLink) g_displayLink.paused = NO;
    vcm_log(@"[session] startRunning  replace=%@  video=%@ audio=%@",
            g_isReplace ? @"YES" : @"NO",
            [g_fileManager fileExistsAtPath:vcm_videoPath()]  ? @"有" : @"无",
            [g_fileManager fileExistsAtPath:g_tempAudioPath] ? @"有" : @"无");
}
- (void)stopRunning {
    // 先让微信真正停掉相机（释放底层采集资源），再清我们这侧。
    %orig;
    // 关相机（拍照）时若不暂停显示层心跳、不停解码线程，主线程仍每帧操作已停 session 的层、
    // 后台解码线程仍在跑 → 访问已释放资源闪退。统一：停心跳 + 停解码线程 + 清 PCM + 时钟作废。
    // 状态机简化：stop 即清理、start 即重建，去掉「留 PCM 等下次 start」的微妙特例。
    g_sessionRunning = NO;
    g_videoSuppress = NO;   // 保险：若拍照/录制 proxy 未回调恢复，下次会话不会卡在透传真实画面
    if (g_displayLink) g_displayLink.paused = YES;
    vcm_invalidatePCM();          // 含停解码线程 + 代次失效，关相机后不再有后台解码
    vcm_resetClock();             // 会话结束 → 时钟作废，下次 startRunning 重新锚定
    vcm_log(@"[session] stopRunning（相机已停，显示层心跳与解码线程已暂停）");
}
%end

#pragma mark - 拍照 / 拍摄期间暂停视频替换
// 拍照片 / 录视频时微信从当前 session 取帧，若继续替换会拍出素材而非真实场景。
// 故在拍照 / 录制入口置 g_videoSuppress=YES，使视频 captureOutput 透传真实画面；
// 拍完 / 录完由 proxy delegate / stopRecording 清位恢复（stopRunning 也有兜底清位）。
// 仅作用于视频，声音替换不受影响——用户只要求「视频」真实。
@interface VCamPhotoDelegateProxy : NSObject
- (instancetype)initWithOriginal:(id)orig;
@end
@implementation VCamPhotoDelegateProxy {
    __weak id _orig;
}
- (instancetype)initWithOriginal:(id)orig {
    if (self = [super init]) _orig = orig;
    return self;
}
// 不实现任何具体 delegate 方法：所有回调原样转发给微信原 delegate，仅对「拍照完成」两个 selector 插桩恢复视频替换。
// 原因：AVCapturePhotoCaptureDelegate 是 informal protocol（方法声明在 NSObject category 而非正式协议），
// 具体实现会导致编译器报 expected a type（AVCaptureResolvedSettings 未声明）/ no known instance method。
// 故改用消息转发，方法体里不出现任何具体 delegate 类型名。
- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_orig respondsToSelector:aSelector];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [_orig methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL sel = invocation.selector;
    if (sel == @selector(capturePhoto:didFinishProcessingPhoto:error:) ||
        sel == @selector(capturePhoto:didFinishCaptureForResolvedSettings:error:)) {
        g_videoSuppress = NO;   // 拍完：恢复视频替换
        vcm_log(@"[capture] 拍照完成：视频替换恢复");
    }
    [invocation invokeWithTarget:_orig];
}
@end

%hook AVCapturePhotoOutput
- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings
                        delegate:(id<AVCapturePhotoCaptureDelegate>)delegate {
    g_videoSuppress = YES;   // 拍照期间：视频透传真实画面
    vcm_log(@"[capture] 拍照开始：视频替换暂停（拍真实画面）");
    VCamPhotoDelegateProxy *p = [[VCamPhotoDelegateProxy alloc] initWithOriginal:delegate];
    %orig(settings, (id<AVCapturePhotoCaptureDelegate>)p);
}
%end

%hook AVCaptureMovieFileOutput
- (void)startRecordingToOutputFileURL:(NSURL *)url
                     recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)delegate {
    g_videoSuppress = YES;   // 录制期间：视频透传真实画面
    vcm_log(@"[capture] 开始录制：视频替换暂停");
    %orig(url, delegate);
}
- (void)stopRecording {
    %orig;
    g_videoSuppress = NO;   // 录完：恢复视频替换
    vcm_log(@"[capture] 结束录制：视频替换恢复");
}
%end

#pragma mark - AVCaptureVideoPreviewLayer（叠加预览显示层）
// 预览叠加层用 AVSampleBufferDisplayLayer：帧由采集回调 enqueue，素材位置由会话时钟决定。
// 用协议而不是 category 声明：category 声明而无 @implementation 会触发 -Wincomplete-implementation，
// 这里的方法实际由 Logos 的 %new 注入，编译器看不见。
@protocol VCamSync <NSObject>
- (void)vcm_syncDisplayLayer;
@end

// CADisplayLink 强引用 target，直接拿 preview layer 当 target 会让它被 runloop 永久持有而泄漏。
// 加一层弱引用代理转发：layer 释放后 proxy.target 自动置 nil，回调变成空转。
@interface VCamLinkProxy : NSObject
// 属性不带协议限定：带限定的话 g_linkProxy.layer = self 会因 protocol-qualified 指针不兼容报 -Werror
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *layer;
@end
@implementation VCamLinkProxy
- (void)step:(CADisplayLink *)link { [(id<VCamSync>)self.layer vcm_syncDisplayLayer]; }
@end
static VCamLinkProxy *g_linkProxy = nil;

%hook AVCaptureVideoPreviewLayer
- (void)addSublayer:(CALayer *)layer {
    %orig;

    // displayLink 只建一次；frame / videoGravity / 旋转由 vcm_syncDisplayLayer 每帧对齐
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

// 每帧同步显示层的可见性、填充模式、位置和旋转。不在这里取帧——取帧由采集回调驱动，
// 这里只负责把显示层跟采集层状态对齐。
%new
- (void)vcm_syncDisplayLayer {
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
    UIButton *_btnLog;         // 诊断日志：导出（系统分享面板）
    UIButton *_btnClear;       // 诊断日志：清空缓冲
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

    y += btnH + gap;

    _btnLog = [self addGridButton:@"日志:导出" x:0 y:y w:btnW h:btnH action:@selector(actionExportLog)];
    _btnClear = [self addGridButton:@"日志:清空" x:btnW + gap y:y w:btnW h:btnH action:@selector(actionClearLog)];
    y += btnH + gap;

    [_panelView.heightAnchor constraintEqualToConstant:y + 56 + 16].active = YES;
}

#pragma mark - 按钮动作
- (void)toggleRotate  { g_rotation   = (g_rotation + 90) % 360; vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleLoop    { g_isLoop     = !g_isLoop;     vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleSound   { g_isSound    = !g_isSound;    vcm_saveSettings(); [self refreshGridButtons]; }
- (void)toggleReplace { g_isReplace  = !g_isReplace;  vcm_saveSettings(); [self refreshGridButtons]; }
- (void)actionReset   { vcm_resetSettings(); [self refreshGridButtons]; }

#pragma mark - 诊断日志导出 / 清空
// 导出：环形缓冲拼成文本 → 落盘到临时目录 → 系统分享面板（存文件 / AirDrop / 转发）。
// 用文件 URL 而非纯文本，分享面板能直接「存储到文件」拿到 .log。
- (void)actionExportLog {
    if (!g_diagLog)  g_diagLog  = [NSMutableArray array];
    if (!g_diagLock) g_diagLock = [[NSLock alloc] init];
    NSString *text;
    [g_diagLock lock];
    text = g_diagLog.count ? [g_diagLog componentsJoinedByString:@"\n"]
                           : @"(暂无日志——进一次视频通话 / 视频号，产生帧请求后才有记录)";
    [g_diagLock unlock];

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"VCAM_diag.log"];
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *url = [NSURL fileURLWithPath:path];

    UIActivityViewController *avc =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if ([avc respondsToSelector:@selector(popoverPresentationController)]) {
        avc.popoverPresentationController.sourceView = _btnLog;
        avc.popoverPresentationController.sourceRect = _btnLog.bounds;
    }
    [self presentViewController:avc animated:YES completion:nil];
}
- (void)actionClearLog {
    [g_diagLock lock]; [g_diagLog removeAllObjects]; [g_diagLock unlock];
    if (g_diagFilePath) [[NSData data] writeToFile:g_diagFilePath atomically:NO];  // 落盘同步清空
    vcm_log(@"[sys] 日志已清空");
    [self updateStatusUI];
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
        vcm_clearMaterialFiles(@"bear_vcam_temp.");
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"mov";
        NSString *dst = [g_videoDir stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"bear_vcam_temp.%@", ext]];
        // 先落盘再换全局路径：拷贝失败时 g_videoPath 仍指向旧素材，不会写进一条不存在的存档。
        if (![g_fileManager copyItemAtPath:src toPath:dst error:&copyErr]) { [self updateStatusUI]; return; }
        g_videoPath = [dst copy];
        // 停掉 reader 而不只是清冻结帧：换素材时若循环关闭且旧 reader 已读完，setup 里的 loop 门禁会把重建挡掉。
        vcm_stopReaders();
        g_isReplace = YES;
        vcm_saveSettings();   // 扩展名随导入文件变化，必须持久化，否则重启后找不到文件
        [VCamMediaManager setupVideoReaderIfNeeded];
        [VCamMediaManager setupAudioReaderIfNeeded];
    } else if (hasAudio) {
        // 导入声音文件只新增/替换声音源，绝不删视频：画面仍由视频提供，音频优先用本声音文件。
        // 按导入文件的真实扩展名落地（如 mp3 存 .mp3），避免被写死 .m4a 扩展名导致解封装器选错而静音；
        // 并先删掉同前缀的旧扩展名残留文件。
        vcm_clearMaterialFiles(@"bear_vcam_audio.");
        NSString *ext = [src pathExtension].lowercaseString;
        if (ext.length == 0) ext = @"m4a";
        NSString *dst = [g_videoDir stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"bear_vcam_audio.%@", ext]];
        if (![g_fileManager copyItemAtPath:src toPath:dst error:&copyErr]) { [self updateStatusUI]; return; }
        g_tempAudioPath = [dst copy];

        // 自动开启替换（用户意图就是替换麦克风声音），否则若 g_isReplace=NO 会被门禁透传真实麦克风。
        g_isReplace = YES;
        vcm_saveSettings();   // 扩展名随导入文件变化，必须持久化，否则重启后找不到文件
        vcm_stopReaders();      // 让链路重新 setup（声音源变化需重启解码）
        [self updateStatusUI];
    }
    // 换素材后按新素材重新锚定时钟（vcm_reloadReaders 已 reset 过，这里再补一次以防中途又出了几帧）
    vcm_resetClock();
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
    // becomeKeyWindow 会被反复调用（切前后台、弹窗），不判重会一层层叠加手势 → 一次双击弹 N 个面板。
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
%ctor {
    g_fileManager = [NSFileManager defaultManager];
    g_mediaLock   = [[NSLock alloc] init];
    g_ciContext = [CIContext contextWithOptions:@{
        kCIContextWorkingColorSpace: [NSNull null],
    }];
    g_videoDir = [[vcm_documentPath() stringByAppendingPathComponent:@"VCAM"] copy];
    [g_fileManager createDirectoryAtPath:g_videoDir withIntermediateDirectories:YES attributes:nil error:nil];
    g_diagFilePath = [[g_videoDir stringByAppendingPathComponent:@"VCAM_diag.log"] copy];  // 日志落盘：重启不丢
    // 先给默认名兜底，再由 vcm_loadSettings 用持久化的真实扩展名覆盖（无存档则保持默认）。
    g_tempAudioPath = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_audio.m4a"] copy];
    g_videoPath     = [[g_videoDir stringByAppendingPathComponent:@"bear_vcam_temp.mov"] copy];
    vcm_loadSettings();
    g_srcFrameIdx = -1;   // 尚未锚定

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
    [g_displayLink invalidate];   // 不放进 runloop 的引用会一直回调到已释放的 layer
    g_displayLink  = nil;
    g_displayLayer = nil;
    g_linkProxy    = nil;
    [VCamMediaManager cleanup];
    g_fileManager = nil;
    g_ciContext   = nil;
}

//  DD语音助手 —— 微信媒体互转（Theos/Logos 单文件插件）
//
//  长按消息 → 原生长按菜单追加转换按钮 → 点击转换并发送到当前聊天：
//    视频 / 文件消息 →「转语音」→ SILK 语音消息
//    语音消息       →「转文件」→ m4a 文件消息
//  未下载的媒体先触发微信自动下载，下载完成后再转换。
//
//  方法签名锚定微信 8.0.79 头文件 dump。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include <string.h>

#pragma mark - 微信类声明（锚定 8.0.79 头文件 dump）

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)a2 title:(id)a3 rightValue:(id)a4;
@end

@interface MMMenuItem : NSObject
- (id)initWithTitle:(id)a0 svgName:(id)a1 target:(id)a2 action:(SEL)a3;   // MMMenuItem.h:18
- (id)userInfo;                                                          // MMMenuItem.h:29
- (void)setUserInfo:(id)a0;                                              // MMMenuItem.h:49
@end

@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
- (id)initWithMsgType:(long long)arg1;
+ (BOOL)isSenderFromMsgWrap:(id)arg1;
- (BOOL)IsVideoMsg;                                 // CMessageWrap.h:155
- (id)m_extendInfoWithMsgType;                      // CMessageWrap.h:382
- (void)setM_extendInfoWithMsgType:(id)arg1;        // CMessageWrap.h:637
- (void)setM_uiMessageType:(unsigned int)arg1;
- (void)setM_uiCreateTime:(unsigned int)arg1;
- (void)setM_uiStatus:(unsigned int)arg1;
- (void)setM_nsToUsr:(NSString *)arg1;
- (void)setM_nsFromUsr:(NSString *)arg1;
- (id)m_nsContent;                                  // CMessageWrap.h:402
- (void)setM_nsContent:(id)arg1;                    // CMessageWrap.h:676
- (unsigned int)m_uiDownloadStatus;                 // CMessageWrap.h:513
- (void)setM_uiDownloadStatus:(unsigned int)arg1;   // CMessageWrap.h:711
- (void)setM_bForward:(BOOL)arg1;                   // CMessageWrap.h:590
- (id)getVoicePath;                                 // CMessageWrap.h:362
- (void)setM_nsVoicePath:(NSString *)arg1;          // 语音规范路径，ResendVoiceMsg 据此定位 SILK（运行时存在，dump 未导出）
+ (void)GetPathOfAppDataByUserName:(id)usr andMessageWrap:(id)wrap retStrPath:(void *)pp;  // CMessageWrap.h:108
@end

@interface CExtendInfoOfAPP : NSObject
@property(nonatomic) unsigned int m_uiAppMsgInnerType;      // 6 = 文件
@property(retain, nonatomic) NSString *m_nsAppFileName;
@property(retain, nonatomic) NSString *m_nsAppFileExt;
@property(nonatomic) unsigned long long m_uiAppDataSize;
- (id)init;
- (void)setM_nsTitle:(id)arg1;
- (void)setM_bAppAttachExistInSvr:(BOOL)arg1;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
- (void)setM_dtVoice:(id)arg1;                      // :27
- (void)setM_refMessageWrap:(id)arg1;               // :28
- (void)setM_uiVoiceEndFlag:(unsigned int)arg1;     // :30
- (void)setM_uiVoiceFormat:(unsigned int)arg1;      // :31
- (void)setM_uiVoiceTime:(unsigned int)arg1;        // :33
@end

@interface CUtility : NSObject
+ (id)GetDocPath;                                   // CUtility.h:49
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;   // CUtility.h:82
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;   // AudioSender.h:62
@end

@interface CMessageMgr : NSObject
- (void)StartDownloadVideo:(id)a0 MsgWrap:(id)a1 Priority:(BOOL)a2 Silent:(BOOL)a3;   // :269
- (BOOL)StartDownloadAppAttach:(id)a0 MsgWrap:(id)a1 Silent:(BOOL)a2;                  // :32
- (void)AddAppMsg:(id)a0 MsgWrap:(id)a1 DataPath:(id)a2 Scene:(unsigned int)a3;        // :187
- (void)StartUploadAppMsg:(id)a0 MsgWrap:(id)a1 Scene:(unsigned int)a2;                // :273
- (void)AddLocalMsg:(id)a0 MsgWrap:(id)a1;                                             // :191
- (BOOL)SaveMesVoice:(id)a0 MsgWrap:(id)a1;                                            // :29
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

@interface MJSilkCodec : NSObject
+ (id)decodeToPCMFromSilkData:(id)a0;               // MJSilkCodec.h:4
+ (id)encodeToSilkFromPCMData:(id)a0;               // MJSilkCodec.h:5
@end

@interface BaseMessageViewModel : NSObject
- (id)messageWrap;                                  // BaseMessageViewModel.h:49
@end
@interface VideoMessageViewModel : BaseMessageViewModel
- (id)videoPath;                                    // VideoMessageViewModel.h:24
@end
@interface BaseChatCellView : NSObject
@property (readonly, nonatomic) id viewModel;       // BaseChatCellView.h:17
@end
@interface BaseMessageCellView : BaseChatCellView
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;   // BaseMessageCellView.h:11
@end
@interface VideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // VideoMessageCellView.h:12
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end
@interface AppFileMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // AppFileMessageCellView.h:17
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end
@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // VoiceMessageCellView.h:34
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

#pragma mark - 配置与常量

static NSString *const kDDMCPluginName = @"DD语音助手";

#define kDDMCVideoToVoice @"kDDMCVideoToVoice"
#define kDDMCFileToVoice  @"kDDMCFileToVoice"
#define kDDMCVoiceToFile  @"kDDMCVoiceToFile"

#define kDDMCVoiceMsgType 34          // 语音
#define kDDMCAppMsgType   49          // app/文件
#define kDDMCAppInnerFile 6           // 文件 innerType
#define kDDMCVoiceFormat  4           // SILK
#define kDDMCVoiceEndFlag 1
#define kDDMCStatusSending 1
#define kDDMCVoiceSampleRate 16000    // 16kHz 单声道 16bit
#define kDDMCDownloadTimeout 90.0

@interface DDMediaConvertConfig : NSObject
+ (instancetype)shared;
@property (assign, nonatomic) BOOL videoToVoiceEnabled;
@property (assign, nonatomic) BOOL fileToVoiceEnabled;
@property (assign, nonatomic) BOOL voiceToFileEnabled;
@end

@implementation DDMediaConvertConfig
+ (instancetype)shared {
    static DDMediaConvertConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDMediaConvertConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDMediaConvertConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDMCVideoToVoice: @NO, kDDMCFileToVoice: @NO,
        kDDMCVoiceToFile: @NO,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _videoToVoiceEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVideoToVoice];
        _fileToVoiceEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCFileToVoice];
        _voiceToFileEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVoiceToFile];
    }
    return self;
}
- (void)setVideoToVoiceEnabled:(BOOL)v { _videoToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVideoToVoice]; }
- (void)setFileToVoiceEnabled:(BOOL)v { _fileToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCFileToVoice]; }
- (void)setVoiceToFileEnabled:(BOOL)v { _voiceToFileEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVoiceToFile]; }
@end

// 编解码非线程安全，所有媒体转换统一走此串行队列。
static dispatch_queue_t dd_convert_queue;

#pragma mark - 通用工具

static BOOL dd_file_exists(NSString *path) {
    return path.length && [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_current_usr_name(void) { return [objc_getClass("SettingUtil") getCurUsrName]; }
static id dd_mm_service(NSString *name) {
    MMContext *ctx = (MMContext *)[objc_getClass("MMContext") currentContext];
    return [ctx getService:objc_getClass([name UTF8String])];
}
static NSString *dd_chat_usr_of_msg(CMessageWrap *msg) {
    Class wrapCls = objc_getClass("CMessageWrap");
    return [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
}
// 判定对象是否为 CMessageWrap。
static BOOL dd_is_msg_wrap(id obj) {
    return obj && [obj isKindOfClass:objc_getClass("CMessageWrap")];
}
// 取 cell 对应的消息对象。
static CMessageWrap *dd_msg_of_cell(id cell) {
    return [[cell viewModel] messageWrap];
}
// 微信发送走异步后台队列，保活 wrap 防止其在回调前被 ARC 释放。
static void dd_retain_wrap(id wrap) {
    if (!wrap) return;
    static NSMutableArray *pool = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ pool = [NSMutableArray array]; });
    @synchronized (pool) { [pool addObject:wrap]; }
}

#pragma mark - 路径解析

// 含音轨 / 可复用容器白名单。视频路径解析与文件菜单准入共用。
// 音频视频容器可由 AVAssetReader 抽音轨再编 SILK；图片/文档无音轨，一律排除；
// aud/silk 是微信语音终态容器，直接复用，不二次编码。
static NSSet *dd_media_ext_set(void) {
    static NSSet *s; static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [NSSet setWithObjects:
             // 音频容器
             @"mp3", @"wav", @"m4a", @"aac", @"flac", @"ogg", @"oga", @"opus",
             @"caf", @"aiff", @"aif", @"m4r", @"amr", @"wma", @"ape", @"au",
             // 视频容器（含音轨，可抽取）
             @"mp4", @"mov", @"m4v", @"avi", @"mkv", @"flv", @"webm", @"3gp", @"wmv", @"mpg", @"mpeg",
             // SILK 终态容器（原样复用，不二次编码）
             @"aud", @"silk", nil];
    });
    return s;
}
// 视频消息本地路径：VideoMessageViewModel.videoPath（指向 Video/<usr>/<localID>.mp4）。
// 扩展名需命中白名单；未下载完也返回路径，供下载轮询。
static NSString *dd_video_path_of_cell(id cell) {
    id msg = dd_msg_of_cell(cell);
    if (msg && ![msg IsVideoMsg]) return nil;
    NSString *p = [(VideoMessageViewModel *)[cell viewModel] videoPath];
    if (![p isKindOfClass:[NSString class]] || p.length == 0) return nil;
    if (![dd_media_ext_set() containsObject:p.pathExtension.lowercaseString]) return nil;
    return p;
}
// 文件消息本地路径。GetPathOfAppDataByUserName:...retStrPath: 是 void* 出参，
// 微信向 *pp 写入 autorelease(+0) 字符串，ARC 不感知其所有权；必须用 __unsafe_unretained
// 接住出参再赋给 __strong，否则出作用域时 ARC 多 release 一次导致 over-release 崩溃。
// 未下载完也返回路径，供下载轮询。
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
    NSString * __unsafe_unretained raw = nil;
    [objc_getClass("CMessageWrap") GetPathOfAppDataByUserName:dd_current_usr_name()
                                          andMessageWrap:msg retStrPath:(void *)&raw];
    NSString *p = raw;   // __strong：ARC 在此 retain，与出作用域时的 release 配平
    if ([p isKindOfClass:[NSString class]] && p.length) return p;
    return nil;
}
// 语音消息本地路径：getVoicePath（Audio/<usr>/<localID>.aud）。
static NSString *dd_voice_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *p = (NSString *)[msg getVoicePath];
    if (![p isKindOfClass:[NSString class]] || p.length == 0) return nil;
    return p;
}

#pragma mark - 自动下载

// 触发视频下载。
static void dd_trigger_video_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr StartDownloadVideo:nil MsgWrap:msg Priority:YES Silent:YES];
}
// 触发文件附件下载。
static BOOL dd_trigger_file_download(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return NO;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if (!mgr) return NO;
    return [mgr StartDownloadAppAttach:nil MsgWrap:msg Silent:YES];
}
// 轮询等待文件就绪：连续两轮大小一致才返回（半下载文件会让编码产出损坏数据）。
static NSString *dd_wait_local_path(NSString *(^pathBlock)(void), NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    long long prevSize = -1;
    while ([deadline timeIntervalSinceNow] > 0) {
        NSString *p = pathBlock();
        if (dd_file_exists(p)) {
            NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
            long long sz = a ? [a[NSFileSize] longLongValue] : -1;
            if (sz > 0 && sz == prevSize) return p;
            prevSize = sz;
        }
        [NSThread sleepForTimeInterval:0.5];
    }
    return nil;
}

#pragma mark - SILK 容器

// 微信 .aud 头部为 \x02#!SILK_V3（10 字节）；MJSilkCodec 仅吐 9 字节 #!SILK_V3，须补前导 0x02。
static BOOL dd_silk_has_magic9(NSData *d) {
    return d.length >= 9 && memcmp(d.bytes, "#!SILK_V3", 9) == 0;
}
static BOOL dd_silk_has_magic10(NSData *d) {
    return d.length >= 10 && ((const unsigned char *)d.bytes)[0] == 0x02
           && memcmp((const unsigned char *)d.bytes + 1, "#!SILK_V3", 9) == 0;
}
// 帧链校验：容器后为「[2字节小端帧长][帧数据]」重复序列。
static BOOL dd_silk_frames_valid(NSData *d) {
    if (!dd_silk_has_magic10(d) && !dd_silk_has_magic9(d)) return NO;
    const unsigned char *b = (const unsigned char *)d.bytes;
    NSUInteger len = d.length, pos = dd_silk_has_magic10(d) ? 10 : 9;
    while (pos + 2 <= len) {
        NSUInteger frameLen = (NSUInteger)b[pos] | ((NSUInteger)b[pos + 1] << 8);
        pos += 2;
        if (frameLen == 0 || frameLen > 0x1000 || pos + frameLen > len) return NO;
        pos += frameLen;
        if (pos == len) return YES;
    }
    return NO;
}
static NSData *dd_silk_normalize(NSData *d) {
    if (dd_silk_has_magic10(d)) return d;
    if (dd_silk_has_magic9(d)) {
        NSMutableData *m = [NSMutableData dataWithCapacity:d.length + 1];
        const unsigned char lead = 0x02;
        [m appendBytes:&lead length:1];
        [m appendData:d];
        return m;
    }
    return nil;
}
// PCM → SILK。产物补前导 0x02 并校验帧链。
static NSData *dd_encode_pcm_to_silk(NSData *pcm) {
    if (pcm.length == 0) return nil;
    NSData *raw = [objc_getClass("MJSilkCodec") encodeToSilkFromPCMData:pcm];
    if (raw.length == 0) return nil;
    NSData *silk = dd_silk_normalize(raw) ?: raw;
    if (!dd_silk_frames_valid(silk)) return nil;
    return silk;
}
// SILK → PCM。校验帧链后喂解码器。
static NSData *dd_decode_silk_to_pcm(NSData *fileData) {
    if (fileData.length < 12) return nil;
    if (!dd_silk_has_magic10(fileData)) return nil;
    if (!dd_silk_frames_valid(fileData)) return nil;
    NSData *pcm = [objc_getClass("MJSilkCodec") decodeToPCMFromSilkData:fileData];
    return pcm.length ? pcm : nil;
}

#pragma mark - 媒体 → 语音

// 构造语音扩展信息并挂到 wrap。
static id dd_voiceExtendInfo(id wrap) {
    id nv = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
// 填充语音消息扩展信息与 voicemsg XML 正文。
// 不写正文则微信重启重建消息时拿到空正文 → 当作未完成语音自动重发。
static void dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap);
    [ext setM_uiVoiceFormat:kDDMCVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDMCVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    [ext setM_dtVoice:voiceData];
    NSString *xml = [NSString stringWithFormat:
        @"<msg><voicemsg voicelength=\"%u\" voiceformat=\"4\" forwardflag=\"0\" /></msg>", duration];
    [wrap setM_nsContent:xml];
}
// 把音频数据写入微信语音规范路径（CUtility.GetPathOfMesAudio）。
static NSString *dd_install_audio_file(CMessageWrap *wrap, NSString *src) {
    NSString *p = nil;
    if (wrap.m_uiMesLocalID != 0) {
        p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:dd_chat_usr_of_msg(wrap)
                                                            LocalID:wrap.m_uiMesLocalID
                                                            DocPath:[objc_getClass("CUtility") GetDocPath]];
    }
    if (!p.length) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent]
  withIntermediateDirectories:YES attributes:nil error:nil];
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    [fm copyItemAtPath:src toPath:p error:nil];
    return p;
}
// 发送语音到会话：AddLocalMsg 分配 localID → 写 SILK 到规范路径 → SaveMesVoice → ResendVoiceMsg。
// 必须显式 setM_nsVoicePath，否则 ResendVoiceMsg 回退按 localID 重算路径易读坏文件。
// SaveMesVoice 首参传 nil（实际两参，传 NSData 会被当路径）。
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    NSData *data = [NSData dataWithContentsOfFile:audPath];
    if (data.length == 0 || !dd_silk_frames_valid(data)) return NO;
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if (!sender) return NO;
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCVoiceMsgType];
    [wrap setM_uiMessageType:kDDMCVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    [wrap setM_uiCreateTime:[(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime]];
    [wrap setM_uiStatus:kDDMCStatusSending];
    [wrap setM_uiDownloadStatus:9];    // 标记已下载
    [wrap setM_bForward:1];
    dd_retain_wrap(wrap);
    dd_configureVoiceMsg(wrap, data, duration);

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddLocalMsg:usr MsgWrap:wrap];
    NSString *voicePath = dd_install_audio_file(wrap, audPath);
    if (voicePath.length) [wrap setM_nsVoicePath:voicePath];
    [mgr SaveMesVoice:nil MsgWrap:wrap];
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return YES;
}
// 抽取音轨为 16bit / 单声道 / 16000Hz PCM。
static NSData *dd_extract_pcm(NSString *mediaPath, double *outDuration) {
    if (!dd_file_exists(mediaPath)) return nil;
    NSDictionary *opts = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:mediaPath] options:opts];
    double dur = CMTimeGetSeconds(asset.duration);
    if (outDuration && isfinite(dur) && dur > 0) *outDuration = dur;
    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (err) return nil;
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) return nil;
    NSDictionary *outSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(kDDMCVoiceSampleRate),
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsNonInterleaved: @NO,
    };
    AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:outSettings];
    [reader addOutput:out];
    if (![reader startReading]) return nil;
    NSMutableData *pcm = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sb = [out copyNextSampleBuffer];
        if (!sb) break;
        CMBlockBufferRef bb = CMSampleBufferGetDataBuffer(sb);
        size_t len = 0; char *ptr = NULL;
        if (bb && CMBlockBufferGetDataPointer(bb, 0, NULL, &len, &ptr) == kCMBlockBufferNoErr && ptr && len)
            [pcm appendBytes:ptr length:len];
        CFRelease(sb);
    }
    return reader.status == AVAssetReaderStatusCompleted ? pcm : nil;
}

// 媒体 → 语音：确保已下载 → 抽音轨/复用 SILK → 编码 → 发送。
// 路径解析与下载触发必须在后台队列内直接调用（GetPathOfAppDataByUserName 主线程调用会崩）。
static void dd_media_to_voice(NSString *tag, CMessageWrap *msg, NSString *(^pathBlock)(void), void(^downloadBlock)(void)) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    dispatch_async(dd_convert_queue, ^{
        NSString *path = pathBlock();
        if (!dd_file_exists(path)) {
            if (downloadBlock) downloadBlock();
            path = dd_wait_local_path(pathBlock, kDDMCDownloadTimeout);
        }
        if (!dd_file_exists(path)) return;
        double duration = 0;
        NSData *aud = nil;
        NSString *ext = path.pathExtension.lowercaseString;
        // 源是微信 SILK 容器（aud/silk）→ 原样复用，不二次编码；帧链不自洽直接放弃。
        if ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"]) {
            NSData *raw = [NSData dataWithContentsOfFile:path];
            if (!dd_silk_frames_valid(raw)) return;
            aud = raw;
            NSData *pcm = dd_decode_silk_to_pcm(raw);   // SILK 容器头不写时长，靠解回 PCM 反推
            duration = (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2);
        } else {
            NSData *pcm = dd_extract_pcm(path, &duration);
            if (pcm.length == 0) return;
            duration = (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2);   // 按真实 PCM 长度算
            aud = dd_encode_pcm_to_silk(pcm);
            if (aud.length == 0) return;
        }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
        [aud writeToFile:tmp atomically:YES];
        unsigned int ms = (unsigned int)(duration * 1000);
        if (ms == 0) ms = 1000;
        if (ms > 60000) ms = 60000;   // 微信语音上限 60s
        dispatch_async(dispatch_get_main_queue(), ^{
            dd_send_voice(usr, tmp, ms);
        });
    });
}

#pragma mark - 语音 → 文件

// PCM → WAV（44 字节 RIFF 头，16bit / 单声道 / 16000Hz）。
static NSData *dd_wav_of_pcm(NSData *pcm) {
    if (pcm.length == 0) return nil;
    const uint32_t sampleRate = (uint32_t)kDDMCVoiceSampleRate;
    const uint16_t channels = 1, bits = 16;
    unsigned char hdr[44] = {0};
    uint32_t riffSize = (uint32_t)(36 + pcm.length);
    uint32_t fmtSize = 16, byteRate = sampleRate * channels * bits / 8;
    uint16_t audioFmt = 1, blockAlign = channels * bits / 8, bitsVal = bits;
    uint32_t dataSize = (uint32_t)pcm.length;
    memcpy(hdr + 0,  "RIFF", 4);  memcpy(hdr + 4,  &riffSize, 4);
    memcpy(hdr + 8,  "WAVE", 4);  memcpy(hdr + 12, "fmt ", 4);
    memcpy(hdr + 16, &fmtSize, 4); memcpy(hdr + 20, &audioFmt, 2);
    memcpy(hdr + 22, &channels, 2); memcpy(hdr + 24, &sampleRate, 4);
    memcpy(hdr + 28, &byteRate, 4); memcpy(hdr + 32, &blockAlign, 2);
    memcpy(hdr + 34, &bitsVal, 2);  memcpy(hdr + 36, "data", 4);
    memcpy(hdr + 40, &dataSize, 4);
    NSMutableData *wav = [NSMutableData dataWithCapacity:pcm.length + 44];
    [wav appendBytes:hdr length:44];
    [wav appendData:pcm];
    return wav;
}
// PCM → m4a：先转 WAV，再经 AVAssetExportSession 导出 AppleM4A。
static NSString *dd_write_m4a(NSData *pcm) {
    if (pcm.length == 0) return nil;
    NSString *wavPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"wav"]];
    if (![dd_wav_of_pcm(pcm) writeToFile:wavPath atomically:YES]) return nil;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:wavPath] options:nil];
    AVAssetExportSession *ex = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!ex) return nil;
    ex.outputFileType = AVFileTypeAppleM4A;
    ex.outputURL = [NSURL fileURLWithPath:path];
    __block BOOL done = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [ex exportAsynchronouslyWithCompletionHandler:^{ done = YES; dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
    [[NSFileManager defaultManager] removeItemAtPath:wavPath error:nil];
    BOOL ok = done && dd_file_exists(path) && ex.status == AVAssetExportSessionStatusCompleted;
    return ok ? path : nil;
}
// SILK → m4a 文件。
static NSString *dd_decode_silk_to_audio(NSData *fileData) {
    NSData *pcm = dd_decode_silk_to_pcm(fileData);
    if (pcm.length == 0) return nil;
    return dd_write_m4a(pcm);
}
// 拷入微信持久沙盒再发送（临时目录会被系统清空，指向死路径 → 消息打不开）。
static NSString *dd_persist_copy(NSString *src) {
    if (!dd_file_exists(src)) return nil;
    NSString *dir = (NSString *)[objc_getClass("CUtility") GetDocPath];
    if (![dir isKindOfClass:[NSString class]] || dir.length == 0) return nil;
    NSString *dst = [dir stringByAppendingPathComponent:
        [NSString stringWithFormat:@"ddmc_voice_%@.m4a", [[NSUUID UUID] UUIDString]]];
    return [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil] ? dst : nil;
}
// 发送 m4a 文件消息：AddAppMsg 本地落库 → StartUploadAppMsg 触发上传。
static BOOL dd_send_file_to_chat(NSString *usr, NSString *m4aPath, NSString *fileName) {
    NSString *persistPath = dd_persist_copy(m4aPath);
    if (persistPath.length) m4aPath = persistPath;
    if (!dd_file_exists(m4aPath) || !usr.length) return NO;
    NSData *fdata = [NSData dataWithContentsOfFile:m4aPath];
    if (fdata.length == 0) return NO;
    unsigned long long fsize = fdata.length;

    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCAppMsgType];
    [wrap setM_uiMessageType:kDDMCAppMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    [wrap setM_uiCreateTime:[(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime]];
    [wrap setM_uiStatus:kDDMCStatusSending];

    CExtendInfoOfAPP *app = [[objc_getClass("CExtendInfoOfAPP") alloc] init];
    [app setM_uiAppMsgInnerType:kDDMCAppInnerFile];
    [app setM_nsAppFileName:fileName];
    [app setM_nsAppFileExt:@"m4a"];
    [app setM_uiAppDataSize:fsize];
    [app setM_nsTitle:fileName];
    [app setM_bAppAttachExistInSvr:YES];
    [wrap setM_extendInfoWithMsgType:app];

    // 消息正文 appmsg XML（type=6 文件）。不写则微信重启重建消息时正文为空 → 判不出文件名/附件。
    [wrap setM_nsContent:[NSString stringWithFormat:
        @"<msg><appmsg appid=\"\" sdkver=\"0\"><title>%@</title><des></des><type>6</type>"
         "<appattach><totallen>%llu</totallen><attachid></attachid><fileext>%@</fileext>"
         "<filename>%@</filename></appattach></appmsg></msg>", fileName, fsize, @"m4a", fileName]];
    dd_retain_wrap(wrap);

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddAppMsg:usr MsgWrap:wrap DataPath:m4aPath Scene:0];
    [mgr StartUploadAppMsg:usr MsgWrap:wrap Scene:0];
    return YES;
}
// 语音消息 → 文件消息。
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    NSString *fn  = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    dispatch_async(dd_convert_queue, ^{
        NSString *p = dd_voice_path_of_msg(msg);
        if (!dd_file_exists(p)) return;
        NSData *silk = [NSData dataWithContentsOfFile:p];
        if (silk.length < 12) return;
        NSString *m4a = dd_decode_silk_to_audio(silk);
        if (!m4a.length) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            dd_send_file_to_chat(usr, m4a, fn);
        });
    });
}

#pragma mark - 菜单注入

// 文件消息「转语音」准入：扩展名需命中白名单。菜单构建阶段只判消息自带字段，不解析路径。
static BOOL dd_file_has_audio(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return NO;
    id app = [msg m_extendInfoWithMsgType];
    if (!app) return NO;
    NSString *ext = [(CExtendInfoOfAPP *)app m_nsAppFileExt];
    if (![ext isKindOfClass:[NSString class]] || ext.length == 0)
        ext = ((NSString *)[(CExtendInfoOfAPP *)app m_nsAppFileName]).pathExtension;
    if (![ext isKindOfClass:[NSString class]] || ext.length == 0) return NO;
    return [dd_media_ext_set() containsObject:ext.lowercaseString];
}
// 用 userInfo 标记去重（MMMenuItem 无 title/action getter）。
static NSString *dd_menu_token(SEL action) {
    return [@"ddmc:" stringByAppendingString:NSStringFromSelector(action)];
}
// 注入菜单项（svg 图标 + 标题，一级平铺项）。已注入则跳过。
static NSArray *dd_inject_items(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    if (!enabled) return original;
    NSString *token = dd_menu_token(action);
    for (MMMenuItem *it in original) {
        id ui = [it userInfo];
        if ([ui isKindOfClass:[NSString class]] && [(NSString *)ui isEqualToString:token]) return original;
    }
    Class cls = objc_getClass("MMMenuItem");
    MMMenuItem *item = [[cls alloc] initWithTitle:title
                                          svgName:@"icon_filled_record_voice"
                                           target:cell
                                           action:action];
    if (!item) return original;
    [item setUserInfo:token];
    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];
    return items;
}

#pragma mark - Hook：视频 / 文件消息 → 转语音

%hook VideoMessageCellView
- (NSArray *)operationMenuItems {
    return dd_inject_items(self, %orig, [DDMediaConvertConfig shared].videoToVoiceEnabled,
                           @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) && [DDMediaConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(@"视频", msg, ^NSString *{ return dd_video_path_of_cell(self); },
                          ^{ dd_trigger_video_download(msg); });
}
%end

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    // 菜单阶段准入：开关 + 文件类型（只读消息字段）。
    if (!dd_file_has_audio(dd_msg_of_cell(self))) return %orig;
    return dd_inject_items(self, %orig, [DDMediaConvertConfig shared].fileToVoiceEnabled,
                           @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:))
        return [DDMediaConvertConfig shared].fileToVoiceEnabled && dd_file_has_audio(dd_msg_of_cell(self));
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(@"文件", msg, ^NSString *{ return dd_file_path_of_msg(msg); },
                          ^{ dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：语音消息 → 转文件

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    return dd_inject_items(self, %orig, [DDMediaConvertConfig shared].voiceToFileEnabled,
                           @"转文件", @selector(dd_voiceToFile:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_voiceToFile:) && [DDMediaConvertConfig shared].voiceToFileEnabled) return YES;
    return %orig;
}
%new
- (void)dd_voiceToFile:(id)sender {
    dd_voice_to_file(dd_msg_of_cell(self));
}
%end

#pragma mark - 设置页

@interface DDMediaConvertSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end
@implementation DDMediaConvertSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (self.tableViewManager) return;
    // 表格容器由 manager 自建（整屏 frame），再靠系统按导航栏/安全区自动补 inset。
    self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                              initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kDDMCPluginName;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    [self ensureTableViewMgr];
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;   // 自动按导航栏/安全区算 inset
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
- (void)buildTable {
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    DDMediaConvertConfig *cfg = [DDMediaConvertConfig shared];
    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"转换开关"];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleVideoToVoice:) target:self title:@"视频转语音" on:cfg.videoToVoiceEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleFileToVoice:)  target:self title:@"文件转语音" on:cfg.fileToVoiceEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleVoiceToFile:)  target:self title:@"语音转文件" on:cfg.voiceToFileEnabled]];
    [self.tableViewManager addSection:sec];
}
- (void)toggleVideoToVoice:(UISwitch *)s { [DDMediaConvertConfig shared].videoToVoiceEnabled = s.on; }
- (void)toggleFileToVoice:(UISwitch *)s  { [DDMediaConvertConfig shared].fileToVoiceEnabled = s.on; }
- (void)toggleVoiceToFile:(UISwitch *)s  { [DDMediaConvertConfig shared].voiceToFileEnabled = s.on; }

// 转发给微信原生 delegate，保留其选中/高亮/高度逻辑。
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        dd_convert_queue = dispatch_queue_create("com.ddmedia.convert", DISPATCH_QUEUE_SERIAL);
        [[%c(WCPluginsMgr) sharedInstance] registerControllerWithTitle:@"DD语音助手"
                                                              version:@"1.0.0"
                                                           controller:@"DDMediaConvertSettingsViewController"];
    }
}

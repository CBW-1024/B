//  DD语音助手 v1.0.1  —— 媒体互转  (WeChat Tweak, Theos/Logos 单文件)
//  长按消息 → 按消息类型在原生长按悬浮菜单追加转换按钮 → 点击转换并发送到当前聊天：
//    视频消息 / 文件消息 → 「转语音」→ 转换成语音消息，发到当前聊天
//    语音消息          → 「转文件」→ 转换成 m4a 文件消息，发到当前聊天
//  未下载的视频 / 文件：先自动下载，下载完成后再转换（WCR 同款思路）。
//
//  调试日志（自签证书/未越狱看不到 syslog，故日志留在 App 内部）：
//    · DDLogStore 同时写内存环形缓冲 + 微信沙盒 Documents/DDVoiceAssistantLogs/ddvoice_debug.log
//    · 设置页「调试日志」分组：导出日志（生成 txt → 系统分享面板，可存「文件」App / 隔空投送 / 收藏）
//                            清空日志、日志开关
//    · 关键链路（菜单注入 / 路径解析 / 下载 / 抽音轨 / SILK 编解码 / 发送）全部用 dd_log() 埋点
//
//  v1.0.1 真机实测修复（依据日志 DD语音助手_日志_20260922_224753.txt）：
//    ① 文件识别失败 / 菜单没按钮 → 路径改走 CMessageWrap 权威接口；扩展名改成 ZDY 式多 key 兜底
//    ② 视频转语音没声音        → SILK 魔数写错 + 采样率不匹配，改实例编码 + 解码器回环自校验
//    ③ 语音转文件闪退          → 剥头逻辑把 #!SILK_V3 剥坏致解码越界，改多候选 + 后台线程
//    ④ 菜单按钮没图标          → svg 名多候选自动选取，全部落空则借原生菜单图标
//
//  锚定证据（微信头文件 dump / WCRefine 加载态 dump）：
//   · 文件数据路径 —— CMessageWrap +GetPathOfAppData:msgWrap            (CMessageWrap.h:26)
//                     +GetPathOfAppData:LocalID:FileExt:retStrPath:      (CMessageWrap.h:106)
//                     +GetPathOfAppDataByUserName:andMessageWrap:…       (CMessageWrap.h:108)
//   · 语音文件落地 —— CMessageWrap -getVoicePath                        (CMessageWrap.h:362)
//                     +getPathOfAudio:msgWrap                           (CMessageWrap.h:66)
//                     CUtility +GetPathOfMesAudio:LocalID:DocPath:      (CUtility.h:82)
//   · 菜单图标   —— MMMenuItem -initWithTitle:svgName:target:action:   (MMMenuItem.h:18)
//   · 视频路径   —— 普通视频 VideoMessageViewModel.videoPath (VideoMessageViewModel.h:5)；
//                  应用视频/视频号 AppVideoMessageViewModel 无路径属性（继承 BizAppBaseMessageViewModel），
//                  路径在 msgWrap.m_oAppDataItem，与文件同取路径通道 (AppVideoMessageViewModel.h:3)
//   · SILK 编解码 —— MJSilkCodec +encodeToSilkFromPCMData: /
//                    +decodeToPCMFromSilkData: / +decodeToAudioDataFromSilkData:
//                                                            (MJSilkCodec.h:5 / :4 / :3)
//   · 语音路径   —— CUtility GetPathOfMesAudio: / AudioSender getAudioFileName:
//   · 视频下载   —— CMessageMgr -StartDownloadVideo:MsgWrap:Priority:Silent: (CMessageMgr.h:213)
//   · 文件下载   —— CMessageMgr -StartDownloadAppAttach:MsgWrap:Silent:  (CMessageMgr.h:252)
//   · 发文件消息 —— CMessageMgr -AddAppMsg:MsgWrap:DataPath:Scene:       (CMessageMgr.h:248)
//   · 文件 data  —— CExtendInfoOfAPP (m_uiAppMsgInnerType=6 文件 / m_nsAppFileName /
//                    m_nsAppFileExt / m_uiAppDataSize)                 (CExtendInfoOfAPP.h)
//   · 菜单落点   —— 各 cell 的 operationMenuItems + canPerformAction:withSender:
//   · 注册/设置  —— WCPluginsMgr / WCTableViewManager / WCTableViewSectionManager
//   · WCR 参考   —— WCRefine 加载态 dump 中 Video/AppFile/Voice 三个 cell 的
//                   WCRefine_onLongPressMediaToVoice: / WCRefine_onLongPressVoiceToFile:
//                   / WCRefine_sendVoiceFileToCurrentChat: 即为同一思路（本插件独立复刻）

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Photos/Photos.h>
#import <substrate.h>
#include <string.h>   // memcmp / memcpy（SILK_V3 魔数校验）
#include <limits.h>   // LLONG_MAX（SILK 回环自校验打分）
#include <math.h>     // isfinite（AVAsset 时长可能是 indeterminate 的 NaN）

// CI（Xcode 26 / iOS 26.5 SDK）开了 -Werror，以下两类警告会直接变成 error：
//   · -Wdeprecated-declarations：AVFoundation / UIKit 部分老 API
//   · -Wobjc-multiple-method-names：微信类与系统类同名 selector（已尽量用显式类型转换规避，此处兜底）
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"

#pragma mark - 微信类声明（均锚定头文件 dump）

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
- (void)tableView:(id)arg1 didSelectRowAtIndexPath:(id)arg2;   // WCTableViewManager.h:64
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

// WCTableViewCellManager.h —— 开关 cell (:38) / 普通 cell (:17 :25 :30) / 居中 cell (:4)
@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightValue:(id)a4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightView:(id)a4;
+ (id)centerCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3;
@end

// 菜单项：继承 UIMenuItem，原生支持直接吃 svg 资源名（微信内部渲染，无需自行转 UIImage）。
//   MMMenuItem.h:18 —— -initWithTitle:svgName:target:action:
// v1.0.1 补齐：图标检测/回退要用到的三个选择器，之前只声明了 svgName 构造器，
// CI 报 "no visible @interface for 'MMMenuItem' declares the selector 'iconImage'"
@interface MMMenuItem : UIMenuItem
- (id)initWithTitle:(id)a0 svgName:(id)a1 target:(id)a2 action:(SEL)a3;  // MMMenuItem.h:18
- (id)initWithTitle:(id)a0 target:(id)a1 action:(SEL)a2;                 // MMMenuItem.h:19  无 svg 的降级构造器
- (id)iconImage;                                                          // MMMenuItem.h:12  读图标（判 svg 名是否真解析出图）
- (void)setIconImage:(id)a0;                                              // MMMenuItem.h:38  兜底塞图标
@end

@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiAppMsgInnerType;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
- (id)initWithMsgType:(long long)arg1;
+ (BOOL)isSenderFromMsgWrap:(id)arg1;
- (id)m_oAppDataItem;
// 以下按头文件补齐（Xcode 26 SDK + ARC 下 id 接收者必须有可见声明，否则报 no known method）
+ (id)getPathOfMsgImg:(id)arg1;                     // CMessageWrap.h:72（小写 g，无大写 G 版本）
- (BOOL)IsVideoMsg;                                 // CMessageWrap.h:155
- (BOOL)IsFileMsg;                                  // CMessageWrap.h:128
- (BOOL)IsVoiceMsg;                                 // CMessageWrap.h:156
- (id)m_extendInfoWithMsgType;                      // CMessageWrap.h:382
- (void)setM_extendInfoWithMsgType:(id)arg1;        // CMessageWrap.h:637
// 路径接口（v1.0.1 修正：原实现只靠 KVC 猜 m_oAppDataItem 的键名，
// 文件消息（含“识别失败”文件）本地路径取不到 → 追加以下权威类方法，按头件行号锚定）
- (id)getVoicePath;                                 // CMessageWrap.h:362  语音文件本地路径（实例方法，无需拼 usr/localID）
+ (id)getPathOfAudio:(id)arg1;                      // CMessageWrap.h:66   语音路径（单参 msgWrap）
+ (id)GetPathOfAppData:(id)arg1;                    // CMessageWrap.h:26   文件/附件数据路径（单参 msgWrap）
+ (void)GetPathOfAppData:(id)a0 LocalID:(unsigned int)lid FileExt:(id)ext retStrPath:(void *)pp;  // :106
+ (void)GetPathOfAppDataByUserName:(id)usr andMessageWrap:(id)wrap retStrPath:(void *)pp;         // :108
@end

@interface CExtendInfoOfAPP : NSObject   // 文件/app 消息的数据项（CExtendInfoOfAPP.h）
@property(nonatomic) unsigned int m_uiAppMsgInnerType;   // 6 = 文件
@property(retain, nonatomic) NSString *m_nsAppFileName;
@property(retain, nonatomic) NSString *m_nsAppFileExt;
@property(nonatomic) unsigned long long m_uiAppDataSize;
@property(retain, nonatomic) NSString *m_nsAppMediaUrl;
@property(retain, nonatomic) NSString *m_nsAppAttachID;
- (id)init;
- (id)getFileExt;                                   // CExtendInfoOfAPP.h:44
@end

// 语音消息的扩展信息（CExtendInfoOfVoiceMsg.h）
@interface CExtendInfoOfVoiceMsg : NSObject
- (id)m_dtVoice;                                    // :12
- (id)m_refMessageWrap;                             // :13
- (unsigned int)m_uiVoiceEndFlag;                   // :17
- (unsigned int)m_uiVoiceFormat;                    // :18
- (unsigned int)m_uiVoiceTime;                      // :20
- (void)setM_dtVoice:(id)arg1;                      // :27
- (void)setM_refMessageWrap:(id)arg1;               // :28
- (void)setM_uiVoiceEndFlag:(unsigned int)arg1;     // :30
- (void)setM_uiVoiceFormat:(unsigned int)arg1;      // :31
- (void)setM_uiVoiceTime:(unsigned int)arg1;        // :33
@end

@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CUtility : NSObject
+ (id)GetDocPath;
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;
- (_Bool)addMessageToDB:(id)arg1;
- (id)getAudioFileName:(id)arg1 LocalID:(unsigned int)arg2;
@end

@interface CMessageMgr : NSObject
- (void)StartDownloadVideo:(id)a0 MsgWrap:(id)a1 Priority:(BOOL)a2 Silent:(BOOL)a3;   // CMessageMgr.h:213
- (BOOL)StartDownloadAppAttach:(id)a0 MsgWrap:(id)a1 Silent:(BOOL)a2;                  // CMessageMgr.h:252
- (BOOL)IsVideoMsgdDownloadIng:(id)a0;                                                // CMessageMgr.h:90
- (void)AddAppMsg:(id)a0 MsgWrap:(id)a1 DataPath:(id)a2 Scene:(unsigned int)a3;       // CMessageMgr.h:248
- (_Bool)addMessageToDB:(id)a0;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

@interface BaseMsgContentViewController : UIViewController
- (id)getCurrentChatName;
@end

// SILK 编解码（微信自带，无需内嵌 FFmpeg；锚定 MJSilkCodec.h:1-15）
@interface MJSilkCodec : NSObject
+ (id)decodeToAudioDataFromSilkData:(id)a0;   // MJSilkCodec.h:3  SILK → 音频数据
+ (id)decodeToPCMFromSilkData:(id)a0;         // MJSilkCodec.h:4  SILK → PCM
+ (id)encodeToSilkFromPCMData:(id)a0;         // MJSilkCodec.h:5  PCM → SILK
// v1.0.1 关键：类方法 encodeToSilkFromPCMData: 用的是 MJSilkCodec 内部默认采样率，
// 与 8kHz PCM 不匹配时编出来能写文件但播出来没声/变调 ← 「视频转语音没声音」根因之一。
// 头文件同时暴露了实例侧 API，可显式指定采样率后再编码：
- (BOOL)initEncoderWithSampleRate:(long long)rate;  // MJSilkCodec.h:7
- (id)encodeFromPCMData:(id)a0;                     // MJSilkCodec.h:10
- (BOOL)uninitEncoder;                              // MJSilkCodec.h:8
- (void)setSampleRate:(long long)rate;              // MJSilkCodec.h:14
- (long long)sampleRate;                            // MJSilkCodec.h:11
@end

// viewModel 层级（cell.viewModel 返回 id，ARC 下需有可见声明才能直接调 selector）
@interface BaseMessageViewModel : NSObject
- (id)messageWrap;                                  // BaseMessageViewModel.h:49
@end
@interface VideoMessageViewModel : BaseMessageViewModel
- (id)videoPath;                                    // VideoMessageViewModel.h:24
@end
@interface AppVideoMessageViewModel : BaseMessageViewModel
- (BOOL)isWSVideo;                                  // AppVideoMessageViewModel.h:5
@end

// cell 层级：BaseMessageCellView 须先于子类声明
@interface BaseMessageCellView : NSObject
@property (readonly, nonatomic) id viewModel;
@end

@interface VideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface AppVideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface AppFileMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

#pragma mark - 配置（三个开关 + 发送模式）

#define kDDMCVideoToVoice @"kDDMCVideoToVoice"
#define kDDMCFileToVoice @"kDDMCFileToVoice"
#define kDDMCVoiceToFile @"kDDMCVoiceToFile"
#define kDDMCLogEnabled   @"kDDMCLogEnabled"

#define kDDMCVoiceMsgType 34          // 语音消息 m_uiMessageType (0x22)
#define kDDMCAppMsgType  49          // app/文件消息 m_uiMessageType (0x31)
#define kDDMVideoMsgType  43          // 视频消息 m_uiMessageType (0x2B)
#define kDDMShortVideoMsgType 62      // 小视频 m_uiMessageType (0x3E)
// 视频消息共三类（用户约束仅识别这 3 种）：
//   · 普通视频(43) + 小视频(62) → VideoMessageCellView（dd_video_path_of_cell 经 IsVideoMsg 校验）
//   · 视频号：AppVideoMessageCellView，AppVideoMessageViewModel.isWSVideo 为真（m_uiMessageType=49）
#define kDDMCAppInnerFile 6          // 文件 innerType
#define kDDMCVoiceFormat 4            // SILK
#define kDDMCVoiceEndFlag 1
#define kDDMCStatusSending 1
#define kDDMCVoiceSampleRate 8000     // 微信语音 8kHz 单声道 16bit
#define kDDMCDownloadTimeout 90.0    // 自动下载等待上限（秒）

@interface DDMediaConvertConfig : NSObject
+ (instancetype)shared;
@property (assign, nonatomic) BOOL videoToVoiceEnabled;
@property (assign, nonatomic) BOOL fileToVoiceEnabled;
@property (assign, nonatomic) BOOL voiceToFileEnabled;
@property (assign, nonatomic) BOOL logEnabled;
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
        kDDMCVideoToVoice: @NO,
        kDDMCFileToVoice: @NO,
        kDDMCVoiceToFile: @NO,
        kDDMCLogEnabled: @YES,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _videoToVoiceEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVideoToVoice];
        _fileToVoiceEnabled   = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCFileToVoice];
        _voiceToFileEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVoiceToFile];
        _logEnabled           = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCLogEnabled];
    }
    return self;
}
- (void)setVideoToVoiceEnabled:(BOOL)v { _videoToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVideoToVoice]; }
- (void)setFileToVoiceEnabled:(BOOL)v { _fileToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCFileToVoice]; }
- (void)setVoiceToFileEnabled:(BOOL)v { _voiceToFileEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVoiceToFile]; }
- (void)setLogEnabled:(BOOL)v { _logEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCLogEnabled]; }
@end

#pragma mark - 调试日志（设置页导出 / 清空）

#define kDDLogMaxLines   3000                      // 内存缓冲上限，超出丢最早的 1/4
#define kDDLogDirName    @"DDVoiceAssistantLogs"
#define kDDLogFileName   @"ddvoice_debug.log"
#define kDDPluginName    @"DD语音助手"
#define kDDPluginVersion @"1.0.1"

@interface DDLogStore : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy)   NSString *logDir;
@property (nonatomic, copy)   NSString *logPath;
@property (nonatomic, strong) NSMutableArray<NSString *> *lines;
- (void)append:(NSString *)line;
- (void)flushSync;
- (void)clearAll;
- (NSUInteger)lineCount;
- (unsigned long long)fileSize;
@end

@implementation DDLogStore {
    NSFileHandle *_handle;
    dispatch_queue_t _q;
}
+ (instancetype)shared {
    static DDLogStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [DDLogStore new]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) {
        _q = dispatch_queue_create("com.ddvoice.log", DISPATCH_QUEUE_SERIAL);
        _lines = [NSMutableArray array];
        _enabled = YES;
        NSArray<NSString *> *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *doc = dirs.firstObject.length ? dirs.firstObject : NSTemporaryDirectory();
        _logDir  = [doc stringByAppendingPathComponent:kDDLogDirName];
        _logPath = [_logDir stringByAppendingPathComponent:kDDLogFileName];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:_logDir withIntermediateDirectories:YES attributes:nil error:nil];
        if (![fm fileExistsAtPath:_logPath]) [fm createFileAtPath:_logPath contents:nil attributes:nil];
        _handle = [NSFileHandle fileHandleForWritingAtPath:_logPath];
        @try { [_handle seekToEndOfFile]; } @catch (...) { _handle = nil; }
    }
    return self;
}
- (void)append:(NSString *)line {
    if (!line.length) return;
    dispatch_async(_q, ^{
        if (self->_lines.count >= kDDLogMaxLines)
            [self->_lines removeObjectsInRange:NSMakeRange(0, kDDLogMaxLines / 4)];
        [self->_lines addObject:line];
        NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        @try { [self->_handle writeData:d]; } @catch (...) {}
        NSLog(@"[%@] %@", kDDPluginName, line);
    });
}
- (void)flushSync { dispatch_sync(_q, ^{ @try { [_handle synchronizeFile]; } @catch (...) {} }); }
- (NSUInteger)lineCount { __block NSUInteger n = 0; dispatch_sync(_q, ^{ n = _lines.count; }); return n; }
- (unsigned long long)fileSize {
    __block unsigned long long sz = 0;
    dispatch_sync(_q, ^{
        sz = [[[NSFileManager defaultManager] attributesOfItemAtPath:_logPath error:nil][NSFileSize] unsignedLongLongValue];
    });
    return sz;
}
- (void)clearAll {
    dispatch_sync(_q, ^{
        [_lines removeAllObjects];
        @try { [_handle closeFile]; } @catch (...) {}
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:_logPath error:nil];
        [fm createFileAtPath:_logPath contents:nil attributes:nil];
        _handle = [NSFileHandle fileHandleForWritingAtPath:_logPath];
        @try { [_handle seekToEndOfFile]; } @catch (...) {}
    });
}
@end

static NSString *dd_log_stamp(void) {
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ df = [NSDateFormatter new]; df.dateFormat = @"MM-dd HH:mm:ss.SSS"; });
    return [df stringFromDate:[NSDate date]];
}
static void dd_log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void dd_log(NSString *fmt, ...) {
    DDLogStore *s = [DDLogStore shared];
    if (!s.enabled) return;
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [s append:[NSString stringWithFormat:@"%@ %@", dd_log_stamp(), msg]];
}

// 导出：flush → 拼头部信息 → 另存为带时间戳的 txt，返回路径
static NSString *dd_log_export_path(void) {
    DDLogStore *s = [DDLogStore shared];
    [s flushSync];
    NSData *d = [NSData dataWithContentsOfFile:s.logPath];
    NSString *body = [[NSString alloc] initWithData:(d ?: [NSData data]) encoding:NSUTF8StringEncoding];
    if (!body.length) body = @"（暂无日志，可能未触发任何转换流程或日志已清空）\n";
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *wxVer   = info[@"CFBundleShortVersionString"] ?: @"-";
    NSString *wxBuild = info[@"CFBundleVersion"] ?: @"-";
    static NSDateFormatter *fdf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fdf = [NSDateFormatter new]; fdf.dateFormat = @"yyyyMMdd_HHmmss"; });
    NSString *stamp = [fdf stringFromDate:[NSDate date]];
    NSString *text = [NSString stringWithFormat:
        @"%@ %@ 调试日志\n"
        @"设备: %@  系统: %@\n微信: %@ (%@)\n导出时间: %@\n日志条数: %lu  文件大小: %llu 字节\n"
        @"----------------------------------------\n%@",
        kDDPluginName, kDDPluginVersion,
        [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion,
        wxVer, wxBuild, [NSDate date],
        (unsigned long)[s lineCount], [s fileSize], body];
    NSString *dst = [s.logDir stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@_日志_%@.txt", kDDPluginName, stamp]];
    [[text dataUsingEncoding:NSUTF8StringEncoding] writeToFile:dst atomically:YES];
    dd_log(@"导出日志 → %@", dst);
    return dst;
}

#pragma mark - 通用工具

static BOOL dd_file_exists(NSString *path) {
    return path.length && [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_current_usr_name(void) { return [objc_getClass("SettingUtil") getCurUsrName]; }
static id dd_mm_service(NSString *name) {
    MMContext *ctx = (MMContext *)[objc_getClass("MMContext") currentContext];
    return [ctx getService:objc_getClass([name UTF8String])];
}
// 当前聊天对象（消息所属会话；WCR 用 sendToCurrentChat 同理取消息所在会话）
static NSString *dd_chat_usr_of_msg(CMessageWrap *msg) {
    Class wrapCls = objc_getClass("CMessageWrap");
    BOOL isSender = [wrapCls isSenderFromMsgWrap:msg];
    return isSender ? msg.m_nsToUsr : msg.m_nsFromUsr;
}

#pragma mark - 自动下载（未下载的视频/文件先下载再转）

// 取 cell 对应消息
static CMessageWrap *dd_msg_of_cell(id cell) {
    id vm = [cell viewModel];
    if ([vm respondsToSelector:@selector(messageWrap)]) {
        CMessageWrap *m = [vm messageWrap];
        dd_log(@"[msg] cell=%@ vm=%@ → msg type=%u localID=%u",
              NSStringFromClass([cell class]), NSStringFromClass([vm class]),
              m ? m.m_uiMessageType : 0, m ? m.m_uiMesLocalID : 0);
        return m;
    }
    dd_log(@"[msg] cell=%@ vm=%@ 无 messageWrap", NSStringFromClass([cell class]), NSStringFromClass([vm class]));
    return nil;
}

// 普通视频本地路径（VideoMessageCellView，承载 m_uiMessageType=43 视频 与 62 小视频，二者共用此类）
// 证据：VideoMessageViewModel.videoPath（VideoMessageViewModel.h:5）；
//       CMessageWrap IsVideoMsg/IsPureVideoMsg（CMessageWrap.h:854-855）；
//       CMessageMgr AddVideoMsg:43 / AddShortVideoMsg:62（CMessageMgr.h:203-204）
static NSString *dd_video_path_of_cell(id cell) {
    id msg = dd_msg_of_cell(cell);
    // 视频消息含 43（视频）与 62（小视频），IsVideoMsg 对两者均返回 YES，做一道显式类型识别
    if (msg && [msg respondsToSelector:@selector(IsVideoMsg)] && ![msg IsVideoMsg]) {
        dd_log(@"[path.video] type=%u 非视频消息，跳过", msg ? ((CMessageWrap *)msg).m_uiMessageType : 0);
        return nil;
    }
    id vm = [cell viewModel];
    if ([vm respondsToSelector:@selector(videoPath)]) {
        NSString *p = [vm videoPath];
        dd_log(@"[path.video] videoPath=%@ 存在=%d", p ?: @"(nil)", dd_file_exists(p));
        if (dd_file_exists(p)) return p;
    } else {
        dd_log(@"[path.video] vm=%@ 无 videoPath", NSStringFromClass([vm class]));
    }
    return nil;
}

// 应用视频 / 视频号视频本地路径（AppVideoMessageCellView，m_uiMessageType=49 的 app 视频）
// 前向声明：下面会复用 dd_file_path_of_msg 的权威路径通道（两者定义在文件靠后处）
static id dd_app_item_of_msg(CMessageWrap *msg);
static NSString *dd_file_path_of_msg(CMessageWrap *msg);
// 证据：AppVideoMessageViewModel 无自己的视频路径属性（AppVideoMessageViewModel.h 仅
//       coverImgUrl/isWSVideo/titleText 等），视频文件落在消息数据项里，与文件消息同通道。
static NSString *dd_appvideo_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    // v1.0.1：与文件消息同通道，先走 CMessageWrap 权威接口（dd_file_path_of_msg 内部也是这套）
    NSString *authoritative = dd_file_path_of_msg(msg);
    if (authoritative.length) {
        dd_log(@"[path.appvideo] 走 GetPathOfAppData 通道命中 → %@", authoritative);
        return authoritative;
    }
    id appItem = dd_app_item_of_msg(msg);
    if (!appItem) return nil;
    NSArray *keys = @[@"m_nsDataPath", @"videoPath", @"m_nsVideoPath",
                      @"m_nsFilePath", @"dataPath", @"localPath", @"m_nsAppMediaUrl"];
    dd_log(@"[path.appvideo] appItem=%@", NSStringFromClass([appItem class]));
    for (NSString *k in keys) {
        @try {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && dd_file_exists(v)) {
                dd_log(@"[path.appvideo] 命中 key=%@ → %@", k, v);
                return v;
            }
        } @catch (...) {}
    }
    dd_log(@"[path.appvideo] 未命中任何路径键（可能需要真机校键名 / 视频未下载）");
    return nil;
}

// 文件消息的 m_oAppDataItem（可能 nil —— “识别失败”的文件就是这种）
static id dd_app_item_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    id appItem = nil;
    @try {
        if ([msg respondsToSelector:@selector(m_oAppDataItem)]) appItem = [msg m_oAppDataItem];
    } @catch (...) { appItem = nil; }
    if (!appItem) @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
    return appItem;
}
// 扩展名字段全空的兜底路径（只走权威接口，避免与 dd_file_path_of_msg 互相递归打日志）
static NSString *dd_file_path_quick(CMessageWrap *msg) {
    Class wrapCls = objc_getClass("CMessageWrap");
    @try {
        NSString *p = (NSString *)[wrapCls GetPathOfAppData:msg];
        if ([p isKindOfClass:[NSString class]] && dd_file_exists(p)) return p;
    } @catch (...) {}
    return nil;
}
// 按 ZDY 逆向实证的取扩展名骨架改：多 key KVC 兜底 + `pathExtension` 补 + 强制小写
// （见 ZDY_文件类型识别逆向分析.md §1；大写扩展名如 .MP3 会被白名单漏判）
static NSString *dd_file_ext_of_msg(CMessageWrap *msg) {
    id appItem = dd_app_item_of_msg(msg);
    NSArray<NSString *> *keys = @[@"m_nsAppFileExt", @"m_nsFileExt", @"m_fileExt", @"fileExt", @"fileext",
                                  @"m_nsAttachFileExt", @"m_nsDownloadFileExt", @"m_nsAppFileName"];
    NSString *ext = nil;
    for (NSString *k in keys) {
        @try {
            id v = [appItem valueForKey:k];
            if (![v isKindOfClass:[NSString class]] || ((NSString *)v).length == 0) continue;
            NSString *raw = (NSString *)v;
            NSString *e = raw.pathExtension.length ? raw.pathExtension : raw;   // "song.mp3" 或 "mp3" 都吃
            if (e.length) { ext = e; break; }
        } @catch (...) {}
    }
    if (!ext.length) {   // 扩展名字段全空 → 从真实文件路径补（ZDY/锤子都这么做）
        NSString *p = dd_file_path_quick(msg);
        if (p.length) ext = p.pathExtension;
    }
    ext = ext.lowercaseString;
    unsigned int innerType = ([appItem respondsToSelector:@selector(m_uiAppMsgInnerType)])
        ? [(CExtendInfoOfAPP *)appItem m_uiAppMsgInnerType] : 0;
    dd_log(@"[ext.file] appItem=%@ ext=%@ innerType=%u",
          appItem ? NSStringFromClass([appItem class]) : @"(nil)", ext ?: @"(nil)", innerType);
    return ext;
}
// 仅 mp3 / m4a / wav / aac / amr / flac / caf 参与“文件转语音”（比原来只认 mp3/m4a 更实用）
static BOOL dd_file_is_audio(CMessageWrap *msg) {
    NSString *ext = dd_file_ext_of_msg(msg);
    static NSSet *audioExts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        audioExts = [NSSet setWithObjects:@"mp3", @"m4a", @"wav", @"aac", @"amr", @"flac", @"caf", @"aiff", nil];
    });
    BOOL ok = ext.length && [audioExts containsObject:ext];
    dd_log(@"[ext.file] 是否音频文件=%d (ext=%@)", ok, ext ?: @"(nil)");
    return ok;
}

// 文件消息本地路径（v1.0.1 重写：v1.0.0 只靠 KVC 猜 m_oAppDataItem 的键名，
// “识别失败”的文件 m_oAppDataItem 为 nil → 路径永远拿不到 → 转语音必然失败。
// 改用微信权威接口 CMessageWrap.GetPathOfAppData: 系列打头）
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    NSMutableArray<NSString *> *cands = [NSMutableArray array];

    // 1) +GetPathOfAppData:msgWrap —— CMessageWrap.h:26（单参，权威）
    @try {
        NSString *p = (NSString *)[wrapCls GetPathOfAppData:msg];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[path.file] GetPathOfAppData: 异常 %@", e.reason); }

    // 2) +GetPathOfAppDataByUserName:andMessageWrap:retStrPath: —— CMessageWrap.h:108
    @try {
        NSString *p = nil;
        [wrapCls GetPathOfAppDataByUserName:dd_current_usr_name() andMessageWrap:msg retStrPath:&p];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[path.file] GetPathOfAppDataByUserName: 异常 %@", e.reason); }

    // 3) m_oAppDataItem KVC 多键名兜底（覆盖不同版本的字段命名）
    id appItem = dd_app_item_of_msg(msg);
    for (NSString *k in @[@"m_nsFilePath", @"filePath", @"dataPath", @"m_nsDataPath", @"localPath", @"m_nsAppMediaUrl"]) {
        @try {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length) [cands addObject:v];
        } @catch (...) {}
    }
    dd_log(@"[path.file] appItem=%@ 候选路径=%lu 条",
          appItem ? NSStringFromClass([appItem class]) : @"(nil)", (unsigned long)cands.count);
    NSUInteger idx = 0;
    for (NSString *p in cands) {
        if (dd_file_exists(p)) {
            dd_log(@"[path.file] 命中候选#%lu → %@ (ext=%@)", (unsigned long)idx, p, p.pathExtension);
            return p;
        }
        idx++;
    }
    if (cands.count) {   // 还没下载完也要把路径交出去，好让上层触发下载并轮询
        dd_log(@"[path.file] 无命中，返回候选#0 供下载轮询: %@", cands.firstObject);
        return cands.firstObject;
    }
    dd_log(@"[path.file] 完全取不到文件路径（appItem 与 GetPathOfAppData 均失败）");
    return nil;
}

// 触发视频下载（微信 CMessageMgr.StartDownloadVideo:MsgWrap:Priority:Silent:）
static void dd_trigger_video_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(StartDownloadVideo:MsgWrap:Priority:Silent:)]) {
        [mgr StartDownloadVideo:nil MsgWrap:msg Priority:YES Silent:YES];
        dd_log(@"[download.video] 已触发 StartDownloadVideo (localID=%u)", msg.m_uiMesLocalID);
    } else {
        dd_log(@"[download.video] CMessageMgr 无 StartDownloadVideo:MsgWrap:Priority:Silent:");
    }
}
// 触发文件/附件下载（CMessageMgr.StartDownloadAppAttach:MsgWrap:Silent:）
static void dd_trigger_file_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(StartDownloadAppAttach:MsgWrap:Silent:)]) {
        [mgr StartDownloadAppAttach:nil MsgWrap:msg Silent:YES];
        dd_log(@"[download.file] 已触发 StartDownloadAppAttach (localID=%u)", msg.m_uiMesLocalID);
    } else {
        dd_log(@"[download.file] CMessageMgr 无 StartDownloadAppAttach:MsgWrap:Silent:");
    }
}

// 轮询等待本地文件出现（自动下载是异步的，WCR 用 downloadMgr + completion 回调，此处用路径轮询兜底）
static NSString *dd_wait_local_path(NSString *(^pathBlock)(void), NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSUInteger rounds = 0;
    while ([deadline timeIntervalSinceNow] > 0) {
        NSString *p = pathBlock();
        if (dd_file_exists(p)) {
            dd_log(@"[download.wait] 第 %lu 轮轮询命中 → %@", (unsigned long)rounds, p);
            return p;
        }
        rounds++;
        [NSThread sleepForTimeInterval:0.5];
    }
    dd_log(@"[download.wait] 超时 %.0fs 仍未出现本地文件（共轮询 %lu 轮）", timeout, (unsigned long)rounds);
    return nil;
}

#pragma mark - 转换：媒体 → 语音（抽取音轨 → PCM → SILK → 发送语音消息到当前聊天）

// 语音扩展信息
static id dd_voiceExtendInfo(id wrap, BOOL create) {
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    if (!create) return nil;
    id nv = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDMCVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDMCVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    [ext setM_dtVoice:voiceData];
    return YES;
}
// 把音频数据落到微信语音标准落地路径。
// 优先用权威音频路径接口 CUtility.GetPathOfMesAudio:LocalID:DocPath:（CUtility.h:82），
// 它按 m_uiMesLocalID 直接给出语音文件落点，比字符串替换更稳。
// 兜底：最新头文件里只有 +getPathOfMsgImg:（小写 g，CMessageWrap.h:72，无大写 G 版本），
//       旧代码误用大写 G 的 GetPathOfMsgImg: 选择器（不存在）会触发 doesNotRecognizeSelector 崩溃，
//       此处改用小写并在 GetPathOfMesAudio 不可用时才走字符串换算。
static NSString *dd_install_audio_file(CMessageWrap *wrap, NSString *src) {
    dd_log(@"[voice.install] src=%@ 存在=%d localID=%u", src ?: @"(nil)", dd_file_exists(src), wrap.m_uiMesLocalID);
    NSString *p = nil;
    unsigned int localID = wrap.m_uiMesLocalID;
    NSString *usr = dd_chat_usr_of_msg(wrap);
    if (localID != 0) {
        p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:usr
                                                                LocalID:localID
                                                                DocPath:[objc_getClass("CUtility") GetDocPath]];
    }
    if (!p.length) {
        p = [[(NSString *)[objc_getClass("CMessageWrap") getPathOfMsgImg:wrap]
              stringByReplacingOccurrencesOfString:@"Img" withString:@"Audio"]
             stringByReplacingOccurrencesOfString:@".pic" withString:@".aud"];
    }
    if (!p.length) { dd_log(@"[voice.install] 无法解析语音落地路径（GetPathOfMesAudio 与 getPathOfMsgImg 均失败）"); return nil; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent]
    withIntermediateDirectories:YES attributes:nil error:nil];
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    NSError *cpErr = nil;
    [fm copyItemAtPath:src toPath:p error:&cpErr];
    dd_log(@"[voice.install] 目标=%@ 复制结果=%d 错误=%@", p, dd_file_exists(p), cpErr.localizedDescription ?: @"无");
    return p;
}

// 发送语音消息到指定会话（复用 DD语音助手 的发送链路：addMessageToDB + ResendVoiceMsg）
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    NSData *data = [NSData dataWithContentsOfFile:audPath];
    dd_log(@"[voice.send] usr=%@ aud=%@ data=%lu 字节 duration=%ums",
          usr ?: @"(nil)", audPath ?: @"(nil)", (unsigned long)data.length, duration);
    if (data.length == 0) { dd_log(@"[voice.send] 语音数据为空，放弃发送"); return NO; }
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if (!sender) { dd_log(@"[voice.send] 取不到 AudioSender 服务"); return NO; }
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCVoiceMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDMCVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMCStatusSending];
    dd_configureVoiceMsg(wrap, data, duration);
    BOOL added = NO;
    if ([sender respondsToSelector:@selector(addMessageToDB:)]) added = [sender addMessageToDB:wrap];
    dd_log(@"[voice.send] addMessageToDB=%d localID=%u", added, wrap.m_uiMesLocalID);
    dd_install_audio_file(wrap, audPath);
    if ([sender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
        [sender ResendVoiceMsg:usr MsgWrap:wrap];
        dd_log(@"[voice.send] 已调用 ResendVoiceMsg，会话=%@", usr ?: @"(nil)");
    } else {
        dd_log(@"[voice.send] AudioSender 无 ResendVoiceMsg:MsgWrap:");
    }
    return YES;
}

// AVFoundation 抽取音轨为 16bit 单声道 PCM
static NSData *dd_extract_pcm(NSString *mediaPath, double *outDuration) {
    if (!dd_file_exists(mediaPath)) return nil;
    NSURL *url = [NSURL fileURLWithPath:mediaPath];
    // WCRefine 同款：带 AVURLAssetPreferPreciseDurationAndTimingKey 建 asset
    // （WCR_三转换功能_逆向分析.md:108），否则长视频的 duration 会不准，语音时长会算错
    NSDictionary *opts = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:opts];
    double dur = CMTimeGetSeconds(asset.duration);
    if (!isfinite(dur) || dur <= 0) dur = 0;
    if (outDuration) *outDuration = dur;
    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (err) { dd_log(@"[pcm] AVAssetReader 创建失败: %@", err.localizedDescription); return nil; }
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) { dd_log(@"[pcm] 素材无音轨（纯视频/无音频）: %@", mediaPath); return nil; }
    dd_log(@"[pcm] 素材=%@ 时长=%.3fs 音轨=%@", mediaPath, (outDuration ? *outDuration : 0), track);
    NSDictionary *outSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(kDDMCVoiceSampleRate),
        AVNumberOfChannelsKey: @1,
        AVLinearPCMBitDepthKey: @16,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsFloatKey: @NO,
    };
    AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                                                   outputSettings:outSettings];
    [reader addOutput:out];
    if (![reader startReading]) { dd_log(@"[pcm] startReading 失败: %@", reader.error.localizedDescription ?: @"无"); return nil; }
    NSMutableData *pcm = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sb = [out copyNextSampleBuffer];
        if (!sb) break;   // v1.0.1：原实现用 continue，某些素材上会空转成死循环卡住主线程
        CMBlockBufferRef bb = CMSampleBufferGetDataBuffer(sb);
        size_t len = 0; char *ptr = NULL;
        if (bb && CMBlockBufferGetDataPointer(bb, 0, NULL, &len, &ptr) == kCMBlockBufferNoErr
            && ptr && len) {
            [pcm appendBytes:ptr length:len];
        }
        CFRelease(sb);
    }
    BOOL ok = (reader.status == AVAssetReaderStatusCompleted);
    dd_log(@"[pcm] 抽取结果=%d PCM=%lu 字节 readerStatus=%ld 错误=%@",
          ok, (unsigned long)pcm.length, (long)reader.status, reader.error.localizedDescription ?: @"无");
    return ok ? pcm : nil;
}

#pragma mark - SILK 容器处理（v1.0.1 重写：魔数修正 + 回环自校验）

// ── 现场取证结论 ────────────────────────────────────────────────────────────
// v1.0.0 把微信 .aud 当成「[4 字节小端长度 N][N 字节 SILK 流]」自行拼接/剥离，
// 并把 SILK 魔数写错成 "!SILK_V3\0"（正确是 SILK SDK 标准的 "#!SILK_V3"，9 字节，
// 最后一字节是 '3' 而不是 '\0'，少了开头的 '#'）。后果：
//   · 发送侧：给 MJSilkCodec 的编码结果又补了一个错魔数 → 微信播放器解不出 →「视频转语音没声音」
//   · 读取侧：原生 .aud 明明以 #!SILK_V3 开头，却误判为带 4 字节长度头，
//     把 "#!SI" 剥掉后送进解码器 → 「语音转文件闪退」（MJSilkCodec 越界解） 
//   · 日志实证：2026-09-22 22:47:38 localID=6 读到 9212 字节后进程重启（ctor 重新触发）
// 修正原则：**不再自创容器格式**。
//   · 发送侧：编码结果直接就是 .aud 内容（与 DD语音助手 一致——它把 .aud 全文
//     一股脑塞进 m_dtVoice 再 ResendVoiceMsg，语音是有声的，这条链路已被验证）
//   · 读取侧：按魔数做多候选，逐个让微信自己的解码器试，取第一个解得动的
// ──────────────────────────────────────────────────────────────────────────

// 十六进制 dump（诊断用：下一轮日志能直接看出 .aud 到底是什么格式）
static NSString *dd_hex_head(NSData *d, NSUInteger n) {
    if (!d.length) return @"(空)";
    NSMutableString *s = [NSMutableString string];
    const unsigned char *b = (const unsigned char *)d.bytes;
    for (NSUInteger i = 0; i < MIN(d.length, n); i++)
        [s appendFormat:@"%02x ", (unsigned)b[i]];
    return s;
}
// SILK_V3 容器魔数（SILK SDK 标准：'#!SILK_V3'，9 字节）
static BOOL dd_silk_has_magic(NSData *d) {
    return d.length >= 9 && memcmp(d.bytes, "#!SILK_V3", 9) == 0;
}
static NSData *dd_silk_with_magic(NSData *d) {
    if (!d.length || dd_silk_has_magic(d)) return d;
    NSMutableData *m = [NSMutableData dataWithCapacity:d.length + 9];
    [m appendBytes:"#!SILK_V3" length:9];
    [m appendData:d];
    return m;
}
// 回环自校验：拿微信自己的解码器反解候选，解不动的不要；
// 采样率一致时解出的 PCM 长度应逼近原始 PCM 长度 → 用它给候选打分，顺带排掉变调的编法
static long long dd_silk_roundtrip_score(NSData *cand, NSUInteger pcmLen) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) return -2;
    NSData *back = nil;
    @try { back = [codec decodeToPCMFromSilkData:cand]; } @catch (NSException *e) { return -2; }
    if (back.length == 0) return -1;
    long long diff = (long long)labs((long)back.length - (long)pcmLen);
    return LLONG_MAX - diff;   // 越大越好（先保证解得动，再挑长度最接近的）
}
// PCM → SILK：多策略编码 + 回环自校验，挑微信自己认账的那个结果
static NSData *dd_encode_pcm_to_silk(NSData *pcm) {
    if (pcm.length == 0) return nil;
    Class codec = objc_getClass("MJSilkCodec");
    NSMutableArray<NSData *> *raws = [NSMutableArray array];
    NSMutableArray<NSString *> *rawTags = [NSMutableArray array];

    // 策略一：实例 API，显式 initEncoderWithSampleRate: 后再 encodeFromPCMData:
    //          （MJSilkCodec.h:7 + :10）— 保证编码器采样率与 PCM 一致，避免变调/听不清
    if ([codec instancesRespondToSelector:@selector(initEncoderWithSampleRate:)] &&
        [codec instancesRespondToSelector:@selector(encodeFromPCMData:)]) {
        long long rates[] = {kDDMCVoiceSampleRate, 16000, 24000};
        for (int i = 0; i < 3; i++) {
            @try {
                id inst = [[codec alloc] init];
                if ([inst initEncoderWithSampleRate:rates[i]]) {
                    NSData *s = [inst encodeFromPCMData:pcm];
                    if (s.length) {
                        dd_log(@"[silk.enc] 实例 API @%lldHz → %lu 字节 (魔数=%d)",
                              rates[i], (unsigned long)s.length, dd_silk_has_magic(s));
                        [raws addObject:s];
                        [rawTags addObject:[NSString stringWithFormat:@"实例@%lldHz", rates[i]]];
                    }
                    if ([inst respondsToSelector:@selector(uninitEncoder)]) [inst uninitEncoder];
                }
            } @catch (NSException *e) {
                dd_log(@"[silk.enc] 实例 API @%lldHz 异常: %@", rates[i], e.reason);
            }
        }
    }
    // 策略二：类方法兜底（MJSilkCodec.h:5）
    @try {
        NSData *s = [codec encodeToSilkFromPCMData:pcm];
        if (s.length) {
            dd_log(@"[silk.enc] 类方法 → %lu 字节 (魔数=%d)", (unsigned long)s.length, dd_silk_has_magic(s));
            [raws addObject:s];
            [rawTags addObject:@"类方法"];
        }
    } @catch (NSException *e) {
        dd_log(@"[silk.enc] 类方法异常: %@", e.reason);
    }
    if (raws.count == 0) { dd_log(@"[silk.enc] 所有编码策略均失败"); return nil; }

    NSData *best = nil; NSString *bestTag = nil; long long bestScore = LLONG_MIN;
    for (NSUInteger i = 0; i < raws.count; i++) {
        NSData *raw = raws[i];
        NSArray<NSData *> *wrapped = dd_silk_has_magic(raw) ? @[raw] : @[raw, dd_silk_with_magic(raw)];
        for (NSUInteger w = 0; w < wrapped.count; w++) {
            NSData *cand = wrapped[w];
            NSString *tag = [NSString stringWithFormat:@"%@/%@", rawTags[i], w == 0 ? @"无头" : @"补魔数"];
            // 只把格式自洽（以 #!SILK_V3 开头）的候选喂给回环校验：
            // 校验本身也要跑解码器，喂进去格局不对的数据反而会把它弄崩，得不偿失
            if (!dd_silk_has_magic(cand)) {
                dd_log(@"[silk.verify] %@ 长度=%lu 跳过回环（无合法容器头）", tag, (unsigned long)cand.length);
                continue;
            }
            long long sc = dd_silk_roundtrip_score(cand, pcm.length);
            dd_log(@"[silk.verify] %@ 长度=%lu 打分=%lld %@", tag, (unsigned long)cand.length, sc,
                  sc == -2 ? @"（回环解码失败）" : (sc == -1 ? @"（回环解出 0 字节）" : @"（回环 OK）"));
            if (sc > bestScore) { bestScore = sc; best = cand; bestTag = tag; }
        }
    }
    if (!best) best = dd_silk_with_magic(raws.firstObject);   // 全部回环失败时的最后兜底
    dd_log(@"[silk.enc] 选定=%@ 输出=%lu 字节 魔数=%d 头16=%@",
          bestTag ?: @"(兜底)", (unsigned long)best.length, dd_silk_has_magic(best), dd_hex_head(best, 16));
    return best;
}
// SILK（.aud 全文）→ PCM：按容器变体做候选，只把解得动的结果交出来（越界就闪退，所以必须过滤）
static NSData *dd_decode_silk_to_pcm(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) { dd_log(@"[silk.dec] 无解码接口"); return nil; }
    dd_log(@"[silk.dec] 输入=%lu 字节 头16=%@", (unsigned long)fileData.length, dd_hex_head(fileData, 16));

    NSMutableArray<NSData *> *cands = [NSMutableArray array];
    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    if (dd_silk_has_magic(fileData)) {
        [cands addObject:fileData]; [tags addObject:@"原样(带#!SILK_V3)"];
    } else if (fileData.length > 12) {
        NSData *d4 = [fileData subdataWithRange:NSMakeRange(4, fileData.length - 4)];
        NSData *d1 = [fileData subdataWithRange:NSMakeRange(1, fileData.length - 1)];
        if (dd_silk_has_magic(d4)) { [cands addObject:d4]; [tags addObject:@"剥4字节头"]; }
        if (dd_silk_has_magic(d1)) { [cands addObject:d1]; [tags addObject:@"剥1字节头"]; }
        [cands addObject:dd_silk_with_magic(fileData)]; [tags addObject:@"补#!SILK_V3"];
        // ⚠ 故意不试「原封不动的裸流」：v1.0.0 就是这么把损坏数据喂进解码器才闪退的
        //   （日志实证 localID=6 读到 9212 字节后进程直接重启）。若 .aud 真是无魔数裸帧，
        //   这里会明确记录失败并把前 32 字节打出来，按证据再补，而不是拿用户微信的稳定性冒险。
        dd_log(@"[silk.dec] 数据无 #!SILK_V3 容器头，候选=%@ 前32字节=%@",
              tags, dd_hex_head(fileData, 32));
    } else {
        dd_log(@"[silk.dec] 数据过小(<12字节)，不是有效语音"); return nil;
    }

    NSData *best = nil; NSString *bestTag = nil;
    for (NSUInteger i = 0; i < cands.count; i++) {
        NSData *pcm = nil;
        @try { pcm = [codec decodeToPCMFromSilkData:cands[i]]; }
        @catch (NSException *e) { dd_log(@"[silk.dec] 候选「%@」异常: %@", tags[i], e.reason); continue; }
        dd_log(@"[silk.dec] 候选「%@」→ PCM %lu 字节", tags[i], (unsigned long)pcm.length);
        if (pcm.length > best.length) { best = pcm; bestTag = tags[i]; }
    }
    if (!best.length) { dd_log(@"[silk.dec] 所有候选均解不出 PCM，放弃"); return nil; }
    dd_log(@"[silk.dec] 命中候选=%@ PCM=%lu 字节", bestTag, (unsigned long)best.length);
    return best;
}

// 媒体 → 语音：先确保已下载，再抽音轨→SILK→发送语音消息到当前聊天
// pathBlock 由调用方按消息类型给出（普通视频取 videoPath；应用视频/文件取 appDataItem 路径）
// downloadBlock 由调用方按消息类型给出（普通视频用 StartDownloadVideo；应用视频/文件用 StartDownloadAppAttach）
static void dd_media_to_voice(CMessageWrap *msg, NSString *(^pathBlock)(void), void(^downloadBlock)(void)) {
    if (!msg) { dd_log(@"[media→voice] msg 为空，放弃"); return; }
    dd_log(@"[media→voice] ==== 开始 ==== type=%u localID=%u chat=%@",
          msg.m_uiMessageType, msg.m_uiMesLocalID, dd_chat_usr_of_msg(msg) ?: @"(nil)");
    NSString *usr = dd_chat_usr_of_msg(msg);
    // v1.0.1：抽音轨 + SILK 编码 + 回环自校验都不轻，挪到全局队列，避免长按菜单点击后
    //         主线程卡顿被 watchdog 杀；只有最后的发送回到主线程。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSString *path = pathBlock();
            if (!dd_file_exists(path)) {
                dd_log(@"[media→voice] 本地文件不存在，触发自动下载");
                if (downloadBlock) downloadBlock();
                path = dd_wait_local_path(pathBlock, kDDMCDownloadTimeout);
            }
            if (!dd_file_exists(path)) { dd_log(@"[media→voice] 下载失败/超时，放弃转换"); return; }
            double duration = 0;
            NSData *pcm = dd_extract_pcm(path, &duration);
            if (pcm.length == 0) { dd_log(@"[media→voice] PCM 为空（无音轨或格式不支持），放弃"); return; }
            NSData *aud = dd_encode_pcm_to_silk(pcm);
            if (aud.length == 0) { dd_log(@"[media→voice] SILK 编码失败，放弃"); return; }
            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [aud writeToFile:tmp atomically:YES];
            unsigned int ms = (unsigned int)(duration * 1000);
            if (ms == 0) ms = 1000;
            if (ms > 60000) { dd_log(@"[media→voice] 原始时长=%ums 超过微信语音 60s 上限，按 60s 发送", ms); ms = 60000; }
            dd_log(@"[media→voice] 时长=%ums → 发送语音 (aud=%lu 字节 魔数=%d)",
                  ms, (unsigned long)aud.length, dd_silk_has_magic(aud));
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL sent = dd_send_voice(usr, tmp, ms);
                dd_log(@"[media→voice] ==== 结束 ==== 发送结果=%d", sent);
            });
        } @catch (NSException *e) {
            dd_log(@"[media→voice] 异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
        }
    });
}

#pragma mark - 转换：语音 → 文件（SILK → 音频/m4a → 作为文件消息发到当前聊天）

// 语音消息本地路径（v1.0.1：优先实例方法 -getVoicePath（CMessageWrap.h:362）。
// 它直接给出语音落点，不需要拼 usr/localID，也就绕开了
// "isSenderFromMsgWrap: 判错 → 拼出对方的 .aud 路径" 这个隐患）
static NSString *dd_voice_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    @try {   // 1) 实例方法，最权威
        NSString *p = (NSString *)[msg getVoicePath];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] getVoicePath 异常 %@", e.reason); }
    @try {   // 2) +getPathOfAudio:msgWrap（CMessageWrap.h:66）
        NSString *p = (NSString *)[wrapCls getPathOfAudio:msg];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] getPathOfAudio: 异常 %@", e.reason); }
    @try {   // 3) CUtility.GetPathOfMesAudio:LocalID:DocPath:（CUtility.h:82）
        NSString *usr = [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
        NSString *p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:usr
                                                                        LocalID:msg.m_uiMesLocalID
                                                                        DocPath:[objc_getClass("CUtility") GetDocPath]];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] GetPathOfMesAudio: 异常 %@", e.reason); }
    @try {   // 4) AudioSender.getAudioFileName:LocalID:（AudioSender.h）
        NSString *usr = [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
        AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
        if ([sender respondsToSelector:@selector(getAudioFileName:LocalID:)]) {
            NSString *p = [sender getAudioFileName:usr LocalID:msg.m_uiMesLocalID];
            if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
        }
    } @catch (NSException *e) { dd_log(@"[voice.path] getAudioFileName: 异常 %@", e.reason); }

    NSUInteger idx = 0;
    for (NSString *p in cands) {
        dd_log(@"[voice.path] 候选#%lu %@ 存在=%d", (unsigned long)idx, p, dd_file_exists(p));
        if (dd_file_exists(p)) return p;
        idx++;
    }
    // 5) 文件系统里还没有 → 从 m_dtVoice 兜底导出（未下载完/路径接口失效）
    @try {
        NSData *d = (NSData *)((CExtendInfoOfVoiceMsg *)[msg m_extendInfoWithMsgType]).m_dtVoice;
        if (d.length) {
            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [d writeToFile:tmp atomically:YES];
            dd_log(@"[voice.path] 回退 m_dtVoice → %@ (%lu 字节)", tmp, (unsigned long)d.length);
            return tmp;
        }
    } @catch (...) {}
    dd_log(@"[voice.path] 取不到语音文件（未下载或路径接口失效）");
    return nil;
}
// 读出 .aud 全文（v1.0.1：不再剥任何前缀，容器识别交给 dd_decode_silk_to_pcm 按魔数判断）
static NSData *dd_silk_data_of_msg(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[silk] msg 为空"); return nil; }
    NSString *p = dd_voice_path_of_msg(msg);
    if (!dd_file_exists(p)) { dd_log(@"[silk] 取不到语音文件 localID=%u", msg.m_uiMesLocalID); return nil; }
    NSData *d = [NSData dataWithContentsOfFile:p];
    dd_log(@"[silk] 文件=%@ %lu 字节 头16=%@", p.lastPathComponent, (unsigned long)d.length, dd_hex_head(d, 16));
    if (d.length < 12) { dd_log(@"[silk] 语音数据过小，放弃"); return nil; }
    return d;
}

// PCM → WAV：手写 44 字节 RIFF 头（16bit / 单声道 / 8kHz），纯字节拼装，无第三方依赖
static NSData *dd_wav_of_pcm(NSData *pcm) {
    if (pcm.length == 0) return nil;
    const uint32_t sampleRate = (uint32_t)kDDMCVoiceSampleRate;
    const uint16_t channels = 1, bits = 16;
    unsigned char hdr[44] = {0};
    memcpy(hdr + 0,  "RIFF", 4);
    uint32_t riffSize = (uint32_t)(36 + pcm.length); memcpy(hdr + 4,  &riffSize, 4);
    memcpy(hdr + 8,  "WAVE", 4);
    memcpy(hdr + 12, "fmt ", 4);
    uint32_t fmtSize = 16;                            memcpy(hdr + 16, &fmtSize, 4);
    uint16_t audioFmt = 1;                            memcpy(hdr + 20, &audioFmt, 2);   // 1 = PCM
    memcpy(hdr + 22, &channels, 2);
    memcpy(hdr + 24, &sampleRate, 4);
    uint32_t byteRate = sampleRate * channels * bits / 8; memcpy(hdr + 28, &byteRate, 4);
    uint16_t blockAlign = channels * bits / 8;        memcpy(hdr + 32, &blockAlign, 2);
    memcpy(hdr + 34, &bits, 2);
    memcpy(hdr + 36, "data", 4);
    uint32_t dataSize = (uint32_t)pcm.length;         memcpy(hdr + 40, &dataSize, 4);
    NSMutableData *wav = [NSMutableData dataWithCapacity:pcm.length + 44];
    [wav appendBytes:hdr length:44];
    [wav appendData:pcm];
    return wav;
}
// PCM → m4a（v1.0.1 重写）
// v1.0.0 用 AVAssetWriter + CMBlockBufferCreateWithMemoryBlock 直接借用 NSData.bytes，
// 且 memoryBlock 生命周期不受控；SILK 解码出来的 PCM 一旦不规整就会被 CMSampleBuffer 判定越界 → 闪退。
// 改为 WCRefine 验证过的路线：PCM → WAV 文件 → AVAssetExportSession(AVAssetExportPresetAppleM4A)
// （WCR_三转换功能_逆向分析.md:110 中关于 AVAssetExportSession / AVAssetExportPresetAppleM4A 的实证）
static NSString *dd_write_m4a(NSData *pcm) {
    if (pcm.length == 0) { dd_log(@"[m4a] PCM 为空"); return nil; }
    NSString *wavPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"wav"]];
    NSData *wav = dd_wav_of_pcm(pcm);
    if (![wav writeToFile:wavPath atomically:YES]) { dd_log(@"[m4a] WAV 写盘失败"); return nil; }
    dd_log(@"[m4a] WAV=%@ (%lu 字节, PCM=%lu, 约%.2fs)",
          wavPath.lastPathComponent, (unsigned long)wav.length, (unsigned long)pcm.length,
          pcm.length / (double)(kDDMCVoiceSampleRate * 2));

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:wavPath] options:nil];
    AVAssetExportSession *ex = [AVAssetExportSession exportSessionWithAsset:asset
                                                                presetName:AVAssetExportPresetAppleM4A];
    if (!ex) { dd_log(@"[m4a] 创建 AVAssetExportSession 失败"); return nil; }
    ex.outputFileType = AVFileTypeAppleM4A;
    ex.outputURL = [NSURL fileURLWithPath:path];
    // done 区分「回调正常返回」和「20s 超时没等到回调」——超时时 status 可能还没落终态，不能算成功
    __block BOOL done = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [ex exportAsynchronouslyWithCompletionHandler:^{ done = YES; dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
    BOOL ok = done && dd_file_exists(path) && ex.status == AVAssetExportSessionStatusCompleted;
    dd_log(@"[m4a] 导出结果=%d 状态=%ld 回调已返回=%d 错误=%@",
          ok, (long)ex.status, done, ex.error.localizedDescription ?: @"无");
    [[NSFileManager defaultManager] removeItemAtPath:wavPath error:nil];
    if (!ok) return nil;
    unsigned long long sz = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    dd_log(@"[m4a] 产物=%@ (%llu 字节)", path.lastPathComponent, sz);
    return path;
}

// 把 m4a 作为文件消息发到当前聊天（CExtendInfoOfAPP innerType=6 + CMessageMgr.AddAppMsg）
//  ⚠ 真机校验点：文件消息构造 + 本地文件上传发送在不同微信版本差异较大，需对照真机微调。
static BOOL dd_send_file_to_chat(NSString *usr, NSString *m4aPath, NSString *fileName) {
    if (!dd_file_exists(m4aPath) || !usr.length) {
        dd_log(@"[file.send] 参数不合法: path=%@ usr=%@", m4aPath ?: @"(nil)", usr ?: @"(nil)");
        return NO;
    }
    NSData *fdata = [NSData dataWithContentsOfFile:m4aPath];
    if (fdata.length == 0) { dd_log(@"[file.send] m4a 数据为空"); return NO; }
    dd_log(@"[file.send] usr=%@ file=%@ size=%lu", usr, m4aPath, (unsigned long)fdata.length);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attr = [fm attributesOfItemAtPath:m4aPath error:nil];
    unsigned long long fsize = attr ? [attr[NSFileSize] unsignedLongLongValue] : fdata.length;

    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCAppMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDMCAppMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMCStatusSending];

    CExtendInfoOfAPP *app = [[objc_getClass("CExtendInfoOfAPP") alloc] init];
    [app setM_uiAppMsgInnerType:kDDMCAppInnerFile];
    [app setM_nsAppFileName:fileName];
    [app setM_nsAppFileExt:@"m4a"];
    [app setM_uiAppDataSize:fsize];
    @try { [wrap setValue:app forKey:@"m_oAppDataItem"]; } @catch (...) {}

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(AddAppMsg:MsgWrap:DataPath:Scene:)]) {
        [mgr AddAppMsg:usr MsgWrap:wrap DataPath:m4aPath Scene:0];
        dd_log(@"[file.send] 已调用 AddAppMsg:MsgWrap:DataPath:Scene:");
        return YES;
    }
    dd_log(@"[file.send] CMessageMgr 无 AddAppMsg，回退 addMessageToDB");
    if ([mgr respondsToSelector:@selector(addMessageToDB:)]) {
        [mgr addMessageToDB:wrap];
        return YES;
    }
    dd_log(@"[file.send] 无任何可用发送接口");
    return NO;
}

// SILK → m4a 文件：优先走直出音频接口 decodeToAudioDataFromSilkData:（MJSilkCodec.h:3），
// 若其返回 m4a/mp4 容器（'ftyp' box）则直接落盘，省去 PCM→AAC 重编码；否则回退 PCM→AAC。
static NSString *dd_decode_silk_to_audio(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    // 主路径：多候选 → PCM（经 dd_decode_silk_to_pcm 过滤掉会让解码器越界的容器变体）
    NSData *pcm = dd_decode_silk_to_pcm(fileData);
    if (pcm.length) {
        NSString *m4a = dd_write_m4a(pcm);
        if (m4a.length) return m4a;
        dd_log(@"[decode] PCM→m4a 失败，继续尝试直出通道");
    }
    // 备选：decodeToAudioDataFromSilkData:（MJSilkCodec.h:3）直出音频。
    // 实测 v1.0.0 它对我们送进去的数据返回 0 字节（容器不对），故排在 PCM 之后。
    if (![codec respondsToSelector:@selector(decodeToAudioDataFromSilkData:)]) {
        dd_log(@"[decode] 无 decodeToAudioDataFromSilkData:"); return nil;
    }
    NSArray<NSData *> *tries = dd_silk_has_magic(fileData)
        ? @[fileData, dd_silk_with_magic(fileData)] : @[dd_silk_with_magic(fileData), fileData];
    for (NSData *cand in tries) {
        NSData *audio = nil;
        @try { audio = [codec decodeToAudioDataFromSilkData:cand]; }
        @catch (NSException *e) { dd_log(@"[decode] 直出异常: %@", e.reason); continue; }
        dd_log(@"[decode] decodeToAudioDataFromSilkData → %lu 字节 头16=%@",
              (unsigned long)audio.length, dd_hex_head(audio, 16));
        if (audio.length < 32) continue;
        const unsigned char *b = (const unsigned char *)audio.bytes;
        BOOL isFtyp = (b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p');
        BOOL isID3  = (b[0]=='I' && b[1]=='D' && b[2]=='3');
        BOOL isFmt  = (b[0]=='R' && b[1]=='I' && b[2]=='F' && b[3]=='F');
        if (isFtyp || isID3) {   // m4a/mp4 容器或 mp3(ID3) → 可直接落盘，无需重编码
            NSString *ext = isFtyp ? @"m4a" : @"mp3";
            NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:
                [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:ext]];
            if ([audio writeToFile:p atomically:YES] && dd_file_exists(p)) {
                dd_log(@"[decode] 直出音频落盘(%@) → %@", ext, p.lastPathComponent);
                return p;
            }
        }
        if (isFmt && audio.length > 44) {   // WAV 容器 → 剥 44 字节头拿 PCM 再走统一封装
            NSData *raw = [audio subdataWithRange:NSMakeRange(44, audio.length - 44)];
            NSString *m4a = dd_write_m4a(raw);
            if (m4a.length) { dd_log(@"[decode] 直出 WAV → 转封装 m4a"); return m4a; }
        }
    }
    dd_log(@"[decode] 直出通道也没出结果");
    return nil;
}

// 语音消息 → 文件消息（"语音转文件"开关）：取 SILK → m4a → 作为文件消息发到当前聊天。
// v1.0.1：整条链路挪到全局队列跑。v1.0.0 在主线程上做 SILK 解码 + 音频编码，
// 长语音会把主线程堵住（微信被 watchdog 判无响应直接杀进程，表现为“闪退”）；
// 微信的消息发送 API 仍回主线程调用。
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[voice→file] msg 为空，放弃"); return; }
    NSString *usr = dd_chat_usr_of_msg(msg);
    NSString *fn  = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    unsigned int localID = msg.m_uiMesLocalID;
    dd_log(@"[voice→file] ==== 开始 ==== localID=%u chat=%@", localID, usr ?: @"(nil)");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSData *silk = dd_silk_data_of_msg(msg);
            if (silk.length == 0) { dd_log(@"[voice→file] 取不到语音数据，放弃"); return; }
            NSString *m4a = dd_decode_silk_to_audio(silk);
            if (!m4a.length) { dd_log(@"[voice→file] 解码/封装失败，放弃"); return; }
            dispatch_async(dispatch_get_main_queue(), ^{
                BOOL sent = dd_send_file_to_chat(usr, m4a, fn);
                dd_log(@"[voice→file] ==== 结束 ==== 发送结果=%d", sent);
            });
        } @catch (NSException *e) {
            // 兜底：解码/封装/发送任何异常都吞掉并留证据，避免把微信带崩
            dd_log(@"[voice→file] 异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
        }
    });
}

#pragma mark - 菜单图标（MMMenuItem 直接吃 svg 资源名：MMMenuItem.h:18）

// 微信各版本的 svg 命名不统一，写死一个名字在部分机型/版本上会退化成「只有文字、没有图标」
// （用户实测现象：视频「转语音」有图标、语音「转文件」没图标 → 同一个名字在两处表现不一致）。
// 解法：候选名逐个试，取第一个真能解出 iconImage 的；全都不行就借原生菜单项自带的图标。
static NSArray<NSString *> *dd_icon_candidates(void) {
    return @[@"voice_record_filled",             // 旧版锚定的语音图标（DDMediaConvert_语音转文件_头文件锚定.md:27）
             @"icon_filled_record_voice",        // v1.0.0 用的名字
             @"icons_filled_voice_record",
             @"icons_filled_record_voice",
             @"voice_record",
             @"record_voice"];
}
static MMMenuItem *dd_convertMenuItem(NSString *title, id target, SEL action, NSArray *original) {
    MMMenuItem *fallbackItem = nil;
    for (NSString *svg in dd_icon_candidates()) {
        @try {
            MMMenuItem *it = [[%c(MMMenuItem) alloc] initWithTitle:title
                                                           svgName:svg
                                                            target:target
                                                            action:action];
            if (!it) continue;
            if (!fallbackItem) fallbackItem = it;
            UIImage *img = nil;
            if ([it respondsToSelector:@selector(iconImage)]) img = (UIImage *)[it iconImage];
            dd_log(@"[menu.icon] svg=%@ → iconImage=%@", svg, img ? @"有" : @"无");
            if (img) return it;   // 确认能出图，直接用它
        } @catch (NSException *e) {
            dd_log(@"[menu.icon] svg=%@ 异常: %@", svg, e.reason);
        }
    }
    if (!fallbackItem) {   // svg 构造器整体不可用 → 退回纯文字版
        @try { fallbackItem = [[%c(MMMenuItem) alloc] initWithTitle:title target:target action:action]; }
        @catch (NSException *e) { dd_log(@"[menu.icon] 落 pure-title 构造异常: %@", e.reason); return nil; }
    }
    // 兜底：从原生菜单项借一张图标，保证菜单里一定看得见图（不再出现“没图标”的按钮）
    @try {
        if (![fallbackItem respondsToSelector:@selector(iconImage)] || ![fallbackItem iconImage]) {
            for (MMMenuItem *src in original) {
                UIImage *borrowed = [src respondsToSelector:@selector(iconImage)] ? (UIImage *)[src iconImage] : nil;
                if (borrowed) {
                    [fallbackItem setIconImage:borrowed];
                    dd_log(@"[menu.icon] svg 全落空，借用原生菜单图标：%@", NSStringFromClass([src class]));
                    break;
                }
            }
        }
    } @catch (...) {}
    return fallbackItem;
}

// 统一注入：取原生菜单数组，按开关追加对应按钮
static NSArray *dd_inject_items(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    dd_log(@"[menu] cell=%@ 注入「%@」enabled=%d 原生菜单数=%lu",
          NSStringFromClass([cell class]), title, enabled, (unsigned long)original.count);
    if (!enabled) { dd_log(@"[menu] 开关关闭/类型不匹配，不注入「%@」", title); return original; }
    MMMenuItem *item = dd_convertMenuItem(title, cell, action, original);
    if (!item) { dd_log(@"[menu] MMMenuItem 构造失败"); return original; }
    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];   // 追加到菜单末尾（与 WCR 行为一致）
    dd_log(@"[menu] 已追加「%@」→ 菜单数=%lu", title, (unsigned long)items.count);
    return items;
}

#pragma mark - Hook：视频消息 → 转语音

%hook VideoMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].videoToVoiceEnabled;
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(视频消息)");
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(msg, ^NSString *{ return dd_video_path_of_cell(self); },
                          ^{ dd_trigger_video_download(msg); });
}
%end

%hook AppVideoMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    // 仅视频号（AppVideoMessageViewModel.isWSVideo）注入“转语音”，其他 app 视频不处理
    id vm = [self viewModel];
    if (![vm respondsToSelector:@selector(isWSVideo)] || ![vm isWSVideo]) {
        dd_log(@"[menu.appvideo] 非视频号（isWSVideo 缺失或为 NO），不注入");
        return original;
    }
    BOOL on = [DDMediaConvertConfig shared].videoToVoiceEnabled;
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(应用视频/视频号)");
    // 仅视频号参与转换（isWSVideo）；非视频号 app 视频不处理
    id vm = [self viewModel];
    if ([vm respondsToSelector:@selector(isWSVideo)] && ![vm isWSVideo]) {
        dd_log(@"[action] 非视频号 app 视频，忽略");
        return;
    }
    CMessageWrap *msg = dd_msg_of_cell(self);
    // 视频号：type=49 app 视频，路径在 m_oAppDataItem，下载走 StartDownloadAppAttach（与文件同通道）
    dd_media_to_voice(msg, ^NSString *{ return dd_appvideo_path_of_msg(msg); },
                          ^{ dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：文件消息 → 转语音

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].fileToVoiceEnabled;
    if (on) {
        // 文件消息一律注入——包括 m_oAppDataItem 为 nil 的「识别失败」文件
        // （v1.0.0 日志实证：这类文件 ext=(nil) → 旧版把它挡在门外，菜单里根本看不到按钮）。
        // 是否真的能转，交给点击时的路径解析判断：拿不到本地文件会触发下载，
        // 下载后仍抽不出音轨则在 dd_media_to_voice 里优雅放弃，不崩溃。
        CMessageWrap *msg = dd_msg_of_cell(self);
        dd_file_is_audio(msg);                      // 仅诊断：记录 ext / innerType
        dd_log(@"[menu.file] localID=%u 本地路径=%@",
              msg.m_uiMesLocalID, dd_file_path_of_msg(msg) ?: @"(未取到，需下载)");
    }
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].fileToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(文件消息)");
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(msg, ^NSString *{ return dd_file_path_of_msg(msg); },
                          ^{ dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：语音消息 → 转文件

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].voiceToFileEnabled;
    return dd_inject_items(self, original, on, @"转文件", @selector(dd_voiceToFile:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_voiceToFile:) &&
        [DDMediaConvertConfig shared].voiceToFileEnabled) return YES;
    return %orig;
}
%new
- (void)dd_voiceToFile:(id)sender {
    dd_log(@"[action] 点击「转文件」(语音消息)");
    dd_voice_to_file(dd_msg_of_cell(self));
}
%end

#pragma mark - 设置页（参考 DD语音助手；新增「调试日志」分组：导出 / 清空 / 开关）

@interface DDMediaConvertSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end
@implementation DDMediaConvertSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (self.tableViewManager) return;
    self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                              initWithFrame:[UIScreen mainScreen].bounds
                                      style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) [self ensureTableViewMgr];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kDDPluginName;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    [self ensureTableViewMgr];
    if (!self.tableViewManager) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
    dd_log(@"[settings] 设置页已加载（插件 %@ v%@）", kDDPluginName, kDDPluginVersion);
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];   // 回到页面时刷新日志条数 / 大小
}
- (void)buildTable {
    if (!self.tableViewManager) return;
    [self.tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    // 分组一：转换开关（sectionWithHeader: 不可用则回退 defaultSection，与 DD语音助手一致）
    WCTableViewSectionManager *sec = [secMgr respondsToSelector:@selector(sectionWithHeader:)]
        ? [secMgr sectionWithHeader:@"转换开关"] : [secMgr defaultSection];
    if (sec) {
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleVideoToVoice:)
                                        target:self
                                         title:@"视频转语音"
                                            on:[DDMediaConvertConfig shared].videoToVoiceEnabled]];
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleFileToVoice:)
                                        target:self
                                         title:@"文件转语音"
                                            on:[DDMediaConvertConfig shared].fileToVoiceEnabled]];
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleVoiceToFile:)
                                        target:self
                                         title:@"语音转文件"
                                            on:[DDMediaConvertConfig shared].voiceToFileEnabled]];
        [self.tableViewManager addSection:sec];
    }

    // 分组二：调试日志（未越狱/自签证书看不到 syslog，日志在这里导出）
    WCTableViewSectionManager *logSec = [secMgr respondsToSelector:@selector(sectionWithHeader:)]
        ? [secMgr sectionWithHeader:@"调试日志"] : [secMgr defaultSection];
    if (logSec) {
        [logSec addCell:[cellMgr switchCellForSel:@selector(toggleLog:)
                                           target:self
                                            title:@"记录调试日志"
                                               on:[DDMediaConvertConfig shared].logEnabled]];
        DDLogStore *store = [DDLogStore shared];
        NSString *cnt = [NSString stringWithFormat:@"%lu 条 / %.0f KB",
                         (unsigned long)[store lineCount], [store fileSize] / 1024.0];
        // 点击由 WCTableViewManager 内部按 cellInfo 的 sel+target 自动派发（与 DD语音助手机制一致）
        [logSec addCell:[cellMgr normalCellForSel:@selector(ddExportLog:)
                                           target:self
                                            title:@"导出日志"
                                       rightValue:cnt]];
        [logSec addCell:[cellMgr normalCellForSel:nil
                                           target:nil
                                            title:@"插件版本"
                                       rightValue:kDDPluginVersion]];
        [logSec addCell:[cellMgr normalCellForSel:@selector(ddClearLog:)
                                           target:self
                                            title:@"清空日志"
                                       rightValue:@""]];
        [self.tableViewManager addSection:logSec];
    }
    [self.tableViewManager reloadTableView];
}
- (void)toggleVideoToVoice:(UISwitch *)s {
    [DDMediaConvertConfig shared].videoToVoiceEnabled = s.on;
    dd_log(@"[settings] 视频转语音 = %d", s.on);
}
- (void)toggleFileToVoice:(UISwitch *)s {
    [DDMediaConvertConfig shared].fileToVoiceEnabled = s.on;
    dd_log(@"[settings] 文件转语音 = %d", s.on);
}
- (void)toggleVoiceToFile:(UISwitch *)s {
    [DDMediaConvertConfig shared].voiceToFileEnabled = s.on;
    dd_log(@"[settings] 语音转文件 = %d", s.on);
}
- (void)toggleLog:(UISwitch *)s {
    [DDMediaConvertConfig shared].logEnabled = s.on;
    [DDLogStore shared].enabled = s.on;
    dd_log(@"[settings] 记录调试日志 = %d", s.on);
}

#pragma mark 日志导出 / 清空（点击由 WCTableViewManager 内部按 cellInfo 的 sel 派发，无需自己处理）

- (void)ddExportLog:(id)sender {
    NSString *path = dd_log_export_path();
    NSUInteger n = [[DDLogStore shared] lineCount];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"日志已导出"
                         message:[NSString stringWithFormat:@"%@\n共 %lu 条\n\n可用「分享/存储」保存到文件 App 或隔空投送。",
                                  path.lastPathComponent, (unsigned long)n]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"分享/存储"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSURL *url = [NSURL fileURLWithPath:path];
        UIActivityViewController *av = [[UIActivityViewController alloc]
                                        initWithActivityItems:@[url] applicationActivities:nil];
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [self presentViewController:av animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制全文"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *text = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
        [UIPasteboard generalPasteboard].string = text ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制路径"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = path ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)ddClearLog:(id)sender {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"清空日志"
                         message:@"将清空内存缓冲与日志文件，确定？"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[DDLogStore shared] clearAll];
        dd_log(@"[settings] 日志已清空，重新开始记录");
        [self buildTable];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark 点击事件转发微信原 delegate（与 DD语音助手一致：cellInfo 的 sel 由 WCTableViewManager 内部派发）

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 微信 cell 的样式/分隔线由原 delegate 绘制，必须转发（与 DD语音助手一致）
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
@end

#pragma mark - 注册入口（参考 DD语音助手）

%ctor {
    @autoreleasepool {
        // 日志开关在启动时同步一次（用户上次可能关闭过）
        [DDLogStore shared].enabled = [DDMediaConvertConfig shared].logEnabled;
        dd_log(@"[ctor] %@ v%@ 已加载", kDDPluginName, kDDPluginVersion);
        [[objc_getClass("WCPluginsMgr") sharedInstance]
            registerControllerWithTitle:kDDPluginName
                                version:kDDPluginVersion
                             controller:@"DDMediaConvertSettingsViewController"];
        dd_log(@"[ctor] 注册入口完成：%@ v%@", kDDPluginName, kDDPluginVersion);
    }
}
ccc
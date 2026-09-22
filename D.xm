//  DD语音助手 v1.0.2  —— 媒体互转  (WeChat Tweak, Theos/Logos 单文件)
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
//  v1.0.2 逐条反汇编 WCRefine.dylib 取证后的修复（用户原话：视频转语音还是没声音 / 长按文件直接闪退 /
//         语音转文件没有反应）。本版所有改动都对着指令地址，不再靠猜：
//    ① 视频转语音没声音
//       · 采样率错：我写的是 8000Hz，WCR sub_0x8f1bc8 在 0x8f1f68 用的是 mov w2,#0x3e80 == 16000
//       · 容器头错：微信 .aud 正规头是 **10 字节 \x02#!SILK_V3**，v1.0.1 只补了 9 字节 #!SILK_V3，
//         少了开头那个 0x02 → 微信解不出 → 静音。证据 WCR sub_0x8f18d8:
//           0x8f19ac b[0]==0x02 且 memcmp(b+1,"#!SILK_V3",9) → 原样返回
//           0x8f1a90 dataWithCapacity:len+1 → appendBytes(0x02,1) → appendData:
//       · 编码顺序反：WCR sub_0x8f2804 主路径是类方法 +encodeToSilkFromPCMData:，
//         实例 API 只在 respondsToSelector: 失败时才兜底且写死 16000Hz；v1.0.1 正好反过来还试了 8000/24000
//    ② 长按文件直接闪退（v1.0.1 引入的回归）
//       我在 AppFileMessageCellView -operationMenuItems 里同步调了 dd_file_path_of_msg()。
//       反汇编 WCR WCRefineAppendVoiceToolsMediaMenuItems(0x8dd96c) + 三个子追加器
//       (0x8ddae4/0x8dde20/0x8de1f8)：建菜单阶段只读开关、判 cell 类名、去重、造 item，
//       **一次都不碰文件路径** → 路径解析全部推迟到点击之后；另加 dd_is_msg_wrap 类型守卫，
//       防止 dd_msg_of_cell 交回来的非 CMessageWrap 对象被塞进 GetPathOfAppData: 而越界。
//    ③ 语音转文件没反应
//       dd_decode_silk_to_pcm 旧的「剥 4 字节/剥 1 字节」候选逻辑认不出 10 字节的 \x02#!SILK_V3 头，
//       直接 return nil 静默退出 → 改成先认容器（含 0x02 变体），
//       并且候选必须先过 dd_silk_frames_valid（WCR sub_0x8f15f4 同款帧链遍历）再喂解码器。
//    ④ 顺带补上 AVLinearPCMIsNonInterleaved（WCR 的 PCM 输出字典是 7 个键：0x8f2134 mov x4,#7）
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
// v1.0.2 更正：之前怀疑类方法 encodeToSilkFromPCMData: 用了“未知内部默认采样率”，
// 于是把实例 API 提到主路径 —— 这个判断是错的。
// 反汇编 WCRefine sub_0x8f2804 看清了它的真实取舍：
//   0x8f2890 先取 SEL 'encodeToSilkFromPCMData:'，
//   0x8f28b0 再问 'respondsToSelector:'，只有为 0 才 tbz 跳到 0x8f2a54 的实例 API 兜底。
// 也就是说 **类方法才是 WCR 的主路径**，实例侧只是保险丝。
// 真正的病根是两个别的：① PCM 采样率写成了 8000（WCR 是 16000）；
// ② 编码器产物少了容器头第一个字节 0x02（见下方 SILK 段落的取证说明）。
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
#define kDDMCVoiceSampleRate 16000    // 微信语音 PCM：16kHz / 单声道 / 16bit / 小端整型
                                      // ← 实测反汇编 WCRefine.dylib 取证，不是猜的：
                                      //   WCRefineVoiceDataFromMediaPath (0x8de548) → sub_0x8f1bc8(pcm 抽取)
                                      //   在 0x8f1f68 用 [NSNumber numberWithUnsignedInt:16000]，
                                      //   0x8f1fb4 用 numberWithUnsignedShort:1（单声道），
                                      //   0x8f2000 用 numberWithUnsignedShort:16（位深），
                                      //   7 个键一起交给 NSDictionary dictionaryWithObjects:forKeys:count:7 (0x8f2134)。
                                      //   v1.0.0/v1.0.1 这里写的 8000 —— 与 WCR 实测不符，是「转语音没声音」的主因之一。
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
#define kDDPluginVersion @"1.0.2"

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
// 类型守卫：dd_msg_of_cell 走的是通用的 [viewModel messageWrap]，不同 cell 的 vm
// 交出来的不一定是 CMessageWrap。把它原样塞进 CMessageWrap 的类方法（GetPathOfAppData: 等）
// 会直接在微信内部越界 → SIGSEGV。凡是要调 wrap 专属接口的地方，先过这一关。
static BOOL dd_is_msg_wrap(id obj) {
    if (!obj) return NO;
    if ([obj isKindOfClass:objc_getClass("CMessageWrap")]) return YES;
    // 没有类型信息时退而求其次：至少要有 CMessageWrap 的标志性字段
    return [obj respondsToSelector:@selector(m_uiMesLocalID)] &&
           [obj respondsToSelector:@selector(m_uiMessageType)];
}

static id dd_app_item_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    if (!dd_is_msg_wrap(msg)) {
        dd_log(@"[ext.file] msg 不是 CMessageWrap(%@)，不碰它的字段", NSStringFromClass([msg class]));
        return nil;
    }
    id appItem = nil;
    @try {
        if ([msg respondsToSelector:@selector(m_oAppDataItem)]) appItem = [msg m_oAppDataItem];
    } @catch (...) { appItem = nil; }
    if (!appItem) @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
    return appItem;
}
// 扩展名字段全空的兜底路径（只走权威接口，避免与 dd_file_path_of_msg 互相递归打日志）
static NSString *dd_file_path_quick(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
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
    // v1.0.2：先过类型守卫。dd_msg_of_cell 对某些 cell 交回来的不是 CMessageWrap，
    // 直接丢给 GetPathOfAppData: 会在微信内部越界崩 —— 「长按文件直接闪退」的真凶之一。
    if (!dd_is_msg_wrap(msg)) {
        dd_log(@"[path.file] msg 类型非 CMessageWrap(%@)，拒绝调用 CMessageWrap 类方法",
              NSStringFromClass([msg class]));
        return nil;
    }
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
    // WCRefine sub_0x8f1bc8 还原的 7 键输出设置（0x8f1ef0~0x8f2138）；
    // count 是 mov x4,#7 —— 正好对应下面这 7 个键，多一个少一个都不是 WCR 那套。
    NSDictionary *outSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),   // 0x8f1ef4 got 槽（numberWithUnsignedInt: 构造）
        AVSampleRateKey: @(kDDMCVoiceSampleRate),  // 0x8f1f68 mov w2,#0x3e80 == 16000
        AVNumberOfChannelsKey: @1,                 // 0x8f1fb4 mov w2,#1      == 单声道
        AVLinearPCMBitDepthKey: @16,               // 0x8f2000 mov w2,#0x10   == 16bit
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsNonInterleaved: @NO,
    };
    dd_log(@"[pcm] 输出设置 16000Hz/单声道/16bit/整型/小端/交织 (7 键，对齐 WCR sub_0x8f1bc8)");
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

#pragma mark - SILK 容器处理（v1.0.2：逐条对齐 WCRefine 反汇编，不再自创格式）

// ══════════════════════════════════════════════════════════════════════════
// 取证来源：反汇编 /workspace/wcr_analysis/WCRefine.dylib（不是推测，是逐条指令读出来的）
//
// ① WCRefine SILK 头归一化 —— sub_0x8f18d8
//   0x8f19ac: ldrb w8,[x8] ; subs w8,w8,#2        → 看第 0 字节是不是 0x02
//   0x8f19c4: add x1,x1,#0x389 (0x2324389='#!SILK_V3') ; mov x2,#9 ; memcmp
//   0x8f19e4: 命中「\x02 + #!SILK_V3」→ 原样返回 data
//   0x8f1a3c: 退一步 memcmp(bytes,"#!SILK_V3",9)
//   0x8f1a90: NSMutableData dataWithCapacity:len+1
//   0x8f1ac8: mov w8,#2 ; sturb → appendBytes(&0x02,1)
//   0x8f1af4: appendData:data                       → 补上 0x02 再返回
//   0x8f1b6c: 两种魔数都没有 → 返回 nil（WCR 直接判废，不硬喂解码器）
//   ⇒ 结论：微信 .aud 正规容器头是 **10 字节 \x02#!SILK_V3**；
//           MJSilkCodec 吐出来的常常只有 9 字节 #!SILK_V3，必须补 0x02。
//     v1.0.1 只补了 9 字节魔数、漏了开头那个 0x02 —— 容器头就是错的 → 播放端解不出 →「没声音」。
//
// ② WCRefine SILK 合法性探测 —— sub_0x8f15f4（遍历帧）
//   0x8f16d4: b[0]==0x02 && len>=10 && memcmp(b+1,"#!SILK_V3",9) → pos=10
//   0x8f1734: 否则 memcmp(b,"#!SILK_V3",9)          → pos=9
//   0x8f179c: u16 帧长 = b[pos] | b[pos+1]<<8（小端），pos+=2
//   0x8f17d8: 无 0x02 前缀时，帧长==0xFFFF 判为终止帧不合规则
//   0x8f17f4: 帧长==0 或 >0x1000 → 判废
//   0x8f180c: pos+帧长 > len → 判废
//   ⇒ 结论：容器后面是「[2 字节小端帧长][帧数据]」重复序列。
//
// ③ WCRefine 编码优先级 —— sub_0x8f2804
//   0x8f2890: SELREF → 'encodeToSilkFromPCMData:'（类方法）
//   0x8f28b0: 'respondsToSelector:' → tbz 失败才跳 0x8f2a54
//   0x8f2a58: 'initEncoderWithSampleRate:'  0x8f2b00: mov x2,#0x3e80 == 16000
//   0x8f2b28: 'encodeFromPCMData:'
//   0x8f2994 / 0x8f2be4: 两条路径的结果都过一遍 sub_0x8f18d8（①）再返回
//   ⇒ 结论：类方法是主路径，实例 API 只是兜底，且兜底采样率写死 16000。
//     v1.0.1 把顺序搞反了（实例优先、类方法兜底），还去试 8000/24000。
//
// ④ WCRefine 媒体→语音总入口 —— WCRefineVoiceDataFromMediaPath (0x8de548)
//   0x8de648: NSData dataWithContentsOfFile:path
//   0x8de678: path.pathExtension.lowercaseString
//   0x8de7d4/0x8de808/0x8de83c: 等于 "aud"/"silk"/"slk" 时
//   0x8de85c: 过 sub_0x8f15f4，合法就 **原样返回 fileData**（已经是语音数据，不必再编）
//   0x8deb70: 否则 sub_0x8f1bc8(path, &ms) 抽 PCM → 0x8dec18 sub_0x8f2804 编码
//   ⇒ 结论：文件本身就是 .aud/.silk 时复用原文，不要二次编码。
//
// ⑤ WCRefine 长按菜单 —— WCRefineAppendVoiceToolsMediaMenuItems (0x8dd96c)
//   整条链（sub_0x8ddae4 / sub_0x8dde20 / sub_0x8de1f8）在「建菜单」阶段
//   只做：读开关 → cell 类名 isEqualToString:/rangeOfString: → 按 identifier 去重 → 造 item。
//   **一次都不解析文件路径**。
//   ⇒ 结论：v1.0.1 我在 AppFileMessageCellView 的 operationMenuItems 里同步调
//     dd_file_path_of_msg()（内部会打 CMessageWrap +GetPathOfAppData: 等未经真机验证的接口），
//     这就是「长按文件直接闪退」的回归点 —— 路径解析必须挪到点击以后。
// ══════════════════════════════════════════════════════════════════════════

// 十六进制 dump（诊断用：下一轮日志能直接看出 .aud 到底是什么格式）
static NSString *dd_hex_head(NSData *d, NSUInteger n) {
    if (!d.length) return @"(空)";
    NSMutableString *s = [NSMutableString string];
    const unsigned char *b = (const unsigned char *)d.bytes;
    for (NSUInteger i = 0; i < MIN(d.length, n); i++)
        [s appendFormat:@"%02x ", (unsigned)b[i]];
    return s;
}

// 「裸魔数」判定：以 "#!SILK_V3" 这 9 字节开头（不管前面有没有 0x02）
static BOOL dd_silk_has_magic9(NSData *d) {
    return d.length >= 9 && memcmp(d.bytes, "#!SILK_V3", 9) == 0;
}
// 「带 0x02 前缀的完整容器头」判定（WCR sub_0x8f18d8 的第一分支）
static BOOL dd_silk_has_magic10(NSData *d) {
    return d.length >= 10 && ((const unsigned char *)d.bytes)[0] == 0x02
           && memcmp((const unsigned char *)d.bytes + 1, "#!SILK_V3", 9) == 0;
}
// 是否认得出这是 SILK 容器（两种魔数任一）
static BOOL dd_silk_is_container(NSData *d) {
    return dd_silk_has_magic10(d) || dd_silk_has_magic9(d);
}

// WCR sub_0x8f18d8 的等价实现：把编码器输出归一化成微信认的 \x02#!SILK_V3 容器。
// 返回 nil = 编码器给的根本不是 SILK（按 WCR 的做法直接判废，不硬喂播放器/解码器）。
static NSData *dd_silk_normalize(NSData *d) {
    if (d.length == 0) return nil;
    if (dd_silk_has_magic10(d)) {
        dd_log(@"[silk.norm] 已是 %@ 容器(%lu 字节)，原样返回", @"\\x02#!SILK_V3", (unsigned long)d.length);
        return d;
    }
    if (dd_silk_has_magic9(d)) {
        NSMutableData *m = [NSMutableData dataWithCapacity:d.length + 1];
        const unsigned char lead = 0x02;
        [m appendBytes:&lead length:1];
        [m appendData:d];
        dd_log(@"[silk.norm] %lu→%lu 字节：补 0x02 前缀（缺了它微信解不出，就是「没声音」）",
              (unsigned long)d.length, (unsigned long)m.length);
        return m;
    }
    dd_log(@"[silk.norm] 编码器输出无 SILK 魔数(%lu 字节 头16=%@)，按 WCR 判废",
          (unsigned long)d.length, dd_hex_head(d, 16));
    return nil;
}

// 剥掉开头那一众可能的私有前缀，露出 SILK 本体（读取侧候选生成用）
static NSData *dd_silk_body_from(NSData *d) {
    if (dd_silk_has_magic10(d)) return d;                                  // 已是标准头
    if (dd_silk_has_magic9(d))   return d;                                 // 已是裸魔数
    if (d.length > 10) {
        NSData *sub = [d subdataWithRange:NSMakeRange(1, d.length - 1)];   // 剥 1 字节
        if (dd_silk_has_magic10(sub) || dd_silk_has_magic9(sub)) return sub;
    }
    if (d.length > 13) {
        NSData *sub = [d subdataWithRange:NSMakeRange(4, d.length - 4)];   // 剥 4 字节长度头
        if (dd_silk_has_magic10(sub) || dd_silk_has_magic9(sub)) return sub;
    }
    return nil;
}
// WCR sub_0x8f15f4 的等价实现：按「帧长/帧内容」走一遍，确认容器没被写坏
static BOOL dd_silk_frames_valid(NSData *d) {
    if (!dd_silk_is_container(d)) return NO;
    const unsigned char *b = (const unsigned char *)d.bytes;
    NSUInteger len = d.length;
    BOOL has02 = dd_silk_has_magic10(d);
    NSUInteger pos = has02 ? 10 : 9;
    NSUInteger frames = 0;
    while (pos + 2 <= len) {
        NSUInteger frameLen = (NSUInteger)b[pos] | ((NSUInteger)b[pos + 1] << 8);
        pos += 2;
        if (!has02 && frameLen == 0xFFFF) return NO;   // 裸魔数变体里这是非法帧长
        if (frameLen == 0 || frameLen > 0x1000) {
            dd_log(@"[silk.frame] 第%lu帧 长度=%lu 越界，容器损坏", (unsigned long)frames + 1, (unsigned long)frameLen);
            return NO;
        }
        if (pos + frameLen > len) {
            dd_log(@"[silk.frame] 第%lu帧 长度=%lu 超出文件尾部(pos=%lu len=%lu)，容器损坏",
                  (unsigned long)frames + 1, (unsigned long)frameLen, (unsigned long)pos, (unsigned long)len);
            return NO;
        }
        pos += frameLen;
        frames++;
        if (pos == len) {
            dd_log(@"[silk.frame] 走完 %lu 帧，容器自洽(len=%lu)", (unsigned long)frames, (unsigned long)len);
            return YES;
        }
    }
    dd_log(@"[silk.frame] 尾部不足 2 字节帧长头(pos=%lu len=%lu)，容器损坏", (unsigned long)pos, (unsigned long)len);
    return NO;
}
// 回环自校验：拿微信自己的解码器反解候选，解不动的不要（只用来自查，不参与最终挑选逻辑）
static long long dd_silk_roundtrip_score(NSData *cand, NSUInteger pcmLen) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) return -2;
    NSData *back = nil;
    @try { back = [codec decodeToPCMFromSilkData:cand]; } @catch (NSException *e) { return -2; }
    if (back.length == 0) return -1;
    long long diff = (long long)labs((long)back.length - (long)pcmLen);
    return LLONG_MAX - diff;   // 越大越好（先保证解得动，再挑长度最接近的）
}

// PCM → SILK：严格按 WCR sub_0x8f2804（0x8f2804~0x8f2d18）的顺序与参数
//   主路径 类方法 +encodeToSilkFromPCMData:（MJSilkCodec.h:5）
//   兜底   实例 -initEncoderWithSampleRate:16000 + -encodeFromPCMData:（MJSilkCodec.h:7/:10）
//   两条路的产物都过 dd_silk_normalize（WCR sub_0x8f18d8）补齐 \x02 容器头
static NSData *dd_encode_pcm_to_silk(NSData *pcm) {
    if (pcm.length == 0) { dd_log(@"[silk.enc] PCM 为空"); return nil; }
    Class codec = objc_getClass("MJSilkCodec");
    if (!codec) { dd_log(@"[silk.enc] 找不到 MJSilkCodec 类"); return nil; }
    dd_log(@"[silk.enc] 输入 PCM=%lu 字节（%.2fs @16000Hz/单声道/16bit）",
          (unsigned long)pcm.length, pcm.length / (double)(kDDMCVoiceSampleRate * 2));

    // ── 主路径：类方法（WCR 0x8f2890 取的就是这个 SEL，tbz 只在 respondsToSelector: 失败时才跳兜底）
    NSData *primary = nil;
    if ([codec respondsToSelector:@selector(encodeToSilkFromPCMData:)]) {
        @try {
            NSData *raw = [codec encodeToSilkFromPCMData:pcm];
            dd_log(@"[silk.enc] 类方法 → %lu 字节 头16=%@", (unsigned long)raw.length, dd_hex_head(raw, 16));
            primary = dd_silk_normalize(raw);
            if (!primary.length) dd_log(@"[silk.enc] 类方法产物不是 SILK 容器");
        } @catch (NSException *e) {
            dd_log(@"[silk.enc] 类方法异常: %@", e.reason);
        }
    } else {
        dd_log(@"[silk.enc] MJSilkCodec 无类方法 encodeToSilkFromPCMData:");
    }
    if (primary.length) {
        dd_silk_frames_valid(primary);   // 只记日志：帧不自洽也照样发（微信自己会兜），但日志要留证据
        long long sc = dd_silk_roundtrip_score(primary, pcm.length);
        dd_log(@"[silk.enc] 类方法产物回环打分=%lld %@", sc,
              sc == -2 ? @"（回环解码失败）" : (sc == -1 ? @"（回环解出0字节）" : @"（回环OK）"));
        if (sc >= 0) {
            dd_log(@"[silk.enc] 选定=类方法 输出=%lu 字节 标准头=%d",
                  (unsigned long)primary.length, dd_silk_has_magic10(primary));
            return primary;
        }
        // 解得动才算数；解不动就往下试试实例兜底，两条路都不行也还有 primary 兜着
        dd_log(@"[silk.enc] 类方法产物自己解不回来，再试实例兜底对比");
    }

    // ── 兜底：实例 API，采样率写死 16000（WCR 0x8f2b00 mov x2,#0x3e80）
    if ([codec instancesRespondToSelector:@selector(initEncoderWithSampleRate:)] &&
        [codec instancesRespondToSelector:@selector(encodeFromPCMData:)]) {
        @try {
            id inst = [[codec alloc] init];
            BOOL okUnit = NO;
            NSData *raw = nil;
            if ([inst initEncoderWithSampleRate:(long long)kDDMCVoiceSampleRate]) {
                okUnit = YES;
                raw = [inst encodeFromPCMData:pcm];
                dd_log(@"[silk.enc] 实例 API @%dHz → %lu 字节 头16=%@",
                      (int)kDDMCVoiceSampleRate, (unsigned long)raw.length, dd_hex_head(raw, 16));
            } else {
                dd_log(@"[silk.enc] initEncoderWithSampleRate:%d 返回 NO", (int)kDDMCVoiceSampleRate);
            }
            if ([inst respondsToSelector:@selector(uninitEncoder)]) [inst uninitEncoder];
            NSData *silk = dd_silk_normalize(raw);
            if (silk.length) {
                dd_silk_frames_valid(silk);
                dd_log(@"[silk.enc] 选定=实例API 输出=%lu 字节 标准头=%d",
                      (unsigned long)silk.length, dd_silk_has_magic10(silk));
                return silk;
            }
            if (okUnit) dd_log(@"[silk.enc] 实例 API 产物不是 SILK 容器");
        } @catch (NSException *e) {
            dd_log(@"[silk.enc] 实例 API 异常: %@", e.reason);
        }
    }
    // 走到这里说明实例兜底也拿不到可解产物；宁可把类方法产物交出去（微信端也许能播），
    // 也不返回 nil 让用户看到「点了没反应」——日志里已经留下完整证据可供下一轮定位。
    if (primary.length) {
        dd_log(@"[silk.enc] 兜底无果，退回类方法产物(%lu 字节)尝试发送", (unsigned long)primary.length);
        return primary;
    }
    dd_log(@"[silk.enc] 类方法与实例 API 全部失败，放弃编码");
    return nil;
}
// SILK（.aud 全文）→ PCM
// WCR 的做法（0x8de7d4 起）：后缀是 aud/silk/slk 且 sub_0x8f15f4 判合格时，
// 直接把文件原文当语音数据用 ——— 因为它本来就是语音数据，压根不必解码。
// 我们这一步要把 .aud 解成 PCM（为了导出成 m4a 文件消息），所以必须解码；
// 候选顺序就照 WCR 那套容器认知排，优先级最高的是 \x02#!SILK_V3 原文。
static NSData *dd_decode_silk_to_pcm(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) {
        dd_log(@"[silk.dec] MJSilkCodec 无 decodeToPCMFromSilkData:"); return nil;
    }
    if (fileData.length < 12) { dd_log(@"[silk.dec] 数据过小(%lu 字节)，放弃", (unsigned long)fileData.length); return nil; }
    dd_log(@"[silk.dec] 输入=%lu 字节 头16=%@", (unsigned long)fileData.length, dd_hex_head(fileData, 16));

    // 候选①：文件原文（标准 \x02#!SILK_V3 容器时它就是正解）
    // 候选②：剥掉可能的私有前缀后露出的 SILK 本体
    // 候选③：给裸魔数补 0x02 后的标准容器（兜中奖多在编码结果而不是原生 .aud 上）
    NSMutableArray<NSData *> *cands = [NSMutableArray array];
    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    NSData *body = dd_silk_body_from(fileData);
    if (dd_silk_has_magic10(fileData)) {
        [cands addObject:fileData]; [tags addObject:@"原文(\\x02#!SILK_V3)"];
    } else if (dd_silk_has_magic9(fileData)) {
        [cands addObject:fileData]; [tags addObject:@"原文(#!SILK_V3)"];
        NSData *full = dd_silk_normalize(fileData);
        if (full) { [cands addObject:full]; [tags addObject:@"补0x02成标准头"]; }
    } else if (body) {
        [cands addObject:body]; [tags addObject:@"剥前缀后本体"];
        NSData *full = dd_silk_normalize(body);
        if (full) { [cands addObject:full]; [tags addObject:@"本体+补0x02"]; }
    } else {
        dd_log(@"[silk.dec] 认不出 SILK 容器头，前32字节=%@", dd_hex_head(fileData, 32));
        return nil;
    }

    NSData *best = nil; NSString *bestTag = nil;
    for (NSUInteger i = 0; i < cands.count; i++) {
        NSData *cand = cands[i];
        // 容器帧链必须先自洽，绝不能把内容不明的数据丢进解码器 —— v1.0.0 就是这么 SIGSEGV 的
        if (!dd_silk_frames_valid(cand)) {
            dd_log(@"[silk.dec] 候选「%@」帧链不自洽，跳过（不喂解码器，避免越界崩）", tags[i]);
            continue;
        }
        NSData *pcm = nil;
        @try { pcm = [codec decodeToPCMFromSilkData:cand]; }
        @catch (NSException *e) { dd_log(@"[silk.dec] 候选「%@」异常: %@", tags[i], e.reason); continue; }
        dd_log(@"[silk.dec] 候选「%@」→ PCM %lu 字节", tags[i], (unsigned long)pcm.length);
        if (pcm.length > best.length) { best = pcm; bestTag = tags[i]; }
    }
    if (!best.length) { dd_log(@"[silk.dec] 所有候选均解不出 PCM，放弃"); return nil; }
    dd_log(@"[silk.dec] 命中候选=%@ PCM=%lu 字节（约%.2fs）", bestTag, (unsigned long)best.length,
          best.length / (double)(kDDMCVoiceSampleRate * 2));
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

            // WCRefineVoiceDataFromMediaPath (0x8de548) 的原样逻辑：
            //   NSData dataWithContentsOfFile:path → [[path pathExtension] lowercaseString]
            //   后缀命中 aud/silk/slk 且 sub_0x8f15f4 判合格 → **直接把文件原文当语音数据**，
            //   不再走「抽 PCM → 重编码」这条既慢又有损的路。（发送语音文件本身就是 .aud 的情况）
            NSData *fileData = [NSData dataWithContentsOfFile:path];
            NSString *ext = [[path pathExtension] lowercaseString];
            NSData *aud = nil;
            double duration = 0;

            BOOL alreadySilk = fileData.length > 0 &&
                               ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"] ||
                                [ext isEqualToString:@"slk"]) &&
                               dd_silk_frames_valid(fileData);
            if (alreadySilk) {
                aud = fileData;
                // 注意：SILK 是压缩流，**不能**拿压缩后的字节数当成 16bit PCM 去估时长
                // （那样会把时长放大好几倍，语音条显示全是错的）。解一遍拿真实 PCM 长度才算得准，
                // 这里的解码只读不算重编码，产物仍然复用原文 fileData。
                NSData *pcm = dd_decode_silk_to_pcm(fileData);
                duration = pcm.length ? (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2) : 0;
                dd_log(@"[media→voice] 源文件已是合法 SILK(%@, %lu 字节)，按 WCR 原样复用不二次编码，"
                       "解出 PCM=%lu 字节 → 时长 %.2fs",
                      ext, (unsigned long)fileData.length, (unsigned long)pcm.length, duration);
            } else {
                NSData *pcm = dd_extract_pcm(path, &duration);
                if (pcm.length == 0) { dd_log(@"[media→voice] PCM 为空（无音轨或格式不支持），放弃"); return; }
                aud = dd_encode_pcm_to_silk(pcm);
                if (aud.length == 0) { dd_log(@"[media→voice] SILK 编码失败，放弃"); return; }
            }

            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [aud writeToFile:tmp atomically:YES];
            unsigned int ms = (unsigned int)(duration * 1000);
            if (ms == 0) ms = 1000;
            if (ms > 60000) { dd_log(@"[media→voice] 原始时长=%ums 超过微信语音 60s 上限，按 60s 发送", ms); ms = 60000; }
            dd_log(@"[media→voice] 时长=%ums → 发送语音 (aud=%lu 字节 标准容器头=%d)",
                  ms, (unsigned long)aud.length, dd_silk_has_magic10(aud));
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

// PCM → WAV：手写 44 字节 RIFF 头（16bit / 单声道 / 16000Hz），纯字节拼装，无第三方依赖
// 采样率必须跟 dd_extract_pcm 的输出设置一致（同取自 kDDMCVoiceSampleRate=16000），
// 否则 m4a 会整体变调。
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
    NSData *stdCand = dd_silk_normalize(fileData);
    NSArray<NSData *> *tries = stdCand ? @[stdCand, fileData] : @[fileData];
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
    // 按 action 去重（UIMenuItem.action 公开可读）
    // 依据 WCR：它在基类 BaseMessageCellView 统一 hook operationMenuItems（BaseMessageCellView.h:65），
    // 四个子类各自也 hook（VideoMessageCellView.h:12 / AppVideoMessageCellView.h:7 /
    // AppFileMessageCellView.h:17 / VoiceMessageCellView.h:33）。两层 hook 叠加时同一个 action
    // 会被注入两次，菜单里就会出现两个同名按钮 —— 追加前先查一轮，命中就跳过。
    for (MMMenuItem *it in original) {
        if ([it respondsToSelector:@selector(action)] && it.action == action) {
            dd_log(@"[menu] 「%@」已存在（基类或其他 hook 已注入），跳过重复追加", title);
            return original;
        }
    }
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
    // ⚠ 这里一行都不要碰文件路径。
    // v1.0.2 修复：v1.0.1 在这一步同步调了 dd_file_path_of_msg()，它内部会打
    // CMessageWrap +GetPathOfAppData: / +GetPathOfAppDataByUserName:andMessageWrap:retStrPath:
    // 这类从未在真机上验证过参数契约的权威接口 → 长按文件消息时直接 SIGSEGV（用户实测「长按文件直接闪退」）。
    // 反汇编证据：WCRefine 的 WCRefineAppendVoiceToolsMediaMenuItems (0x8dd96c) 及其三个子追加器
    // sub_0x8ddae4 / sub_0x8dde20 / sub_0x8de1f8 在建菜单阶段只做四件事：
    //   读开关 → cell 类名判定 → 按 identifier 去重 → 造 MMMenuItem，
    // 一次都不解析路径。路径一律推迟到「点击」那一刻（本 hook 的 dd_mediaToVoice:）才去取。
    // 所以这里顶多留一条不含路径的诊断日志。
    if (on) {
        CMessageWrap *msg = dd_msg_of_cell(self);
        dd_log(@"[menu.file] localID=%u 注入「转语音」（路径延迟到点击时解析）",
              msg ? msg.m_uiMesLocalID : 0);
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
    // 扩展名诊断放在「点击」之后 —— 这里崩也是崩在一次明确的用户操作上，
    // 而不是像 v1.0.1 那样在长按弹菜单的过程中把整个微信带崩。
    // 注意：拿不到扩展名（那些「文件识别失败」的）也照样往下转，
    // dd_extract_pcm 会用 AVFoundation 自己判断素材能不能抽音轨。
    NSString *ext = dd_file_ext_of_msg(msg);
    BOOL audio = dd_file_is_audio(msg);
    dd_log(@"[action] 文件消息 ext=%@ 疑似音频=%d —— 无论如何都尝试抽音轨",
          ext ?: @"(nil)", audio);
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

//  DD语音助手 v1.0.0  —— 媒体互转  (WeChat Tweak, Theos/Logos 单文件)
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
//  锚定证据（微信头文件 dump / WCRefine 加载态 dump）：
//   · 菜单图标   —— MMMenuItem -initWithTitle:svgName:target:action:   (MMMenuItem.h:29)
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
//   MMMenuItem.h:29 —— -initWithTitle:svgName:target:action:
@interface MMMenuItem : UIMenuItem
- (id)initWithTitle:(id)a0 svgName:(id)a1 target:(id)a2 action:(SEL)a3;
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

// SILK 编解码（微信自带，无需内嵌 FFmpeg；锚定 MJSilkCodec.h:1-14）
@interface MJSilkCodec : NSObject
+ (id)decodeToAudioDataFromSilkData:(id)a0;   // MJSilkCodec.h:3  SILK → 音频数据（直出，省去 PCM→AAC 重编码）
+ (id)decodeToPCMFromSilkData:(id)a0;         // MJSilkCodec.h:4  SILK → PCM
+ (id)encodeToSilkFromPCMData:(id)a0;         // MJSilkCodec.h:5  PCM → SILK
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
#define kDDMCVoiceLocalIDBase 10000
#define kDDMCVoiceLocalIDRange 0x15f90
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
#define kDDPluginVersion @"1.0.0"

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
// 证据：AppVideoMessageViewModel 继承 BizAppBaseMessageViewModel，自身无任何视频路径属性
//       （AppVideoMessageViewModel.h:3 父类；仅暴露 coverImgUrl/isWSVideo 等），
//       视频文件落在消息的 m_oAppDataItem 中，与普通文件消息同一条取路径通道。
//       best-effort 按常见键名读取，键名需真机校验（WCR 经 GetDataPath 取 app 视频/文件落地路径）。
static NSString *dd_appvideo_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    id appItem = nil;
    if ([msg respondsToSelector:@selector(m_oAppDataItem)]) appItem = [msg m_oAppDataItem];
    if (!appItem) @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
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

// 文件消息本地路径（best-effort：经 app 数据项按常见键名读取，需真机校验键名）
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    id appItem = nil;
    if ([msg respondsToSelector:@selector(m_oAppDataItem)]) appItem = [msg m_oAppDataItem];
    if (!appItem) @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
    NSArray *keys = @[@"m_nsFilePath", @"filePath", @"dataPath", @"m_nsDataPath", @"localPath", @"m_nsAppMediaUrl"];
    dd_log(@"[path.file] appItem=%@", appItem ? NSStringFromClass([appItem class]) : @"(nil)");
    for (NSString *k in keys) {
        @try {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && dd_file_exists(v)) {
                dd_log(@"[path.file] 命中 key=%@ → %@", k, v);
                return v;
            }
        } @catch (...) {}
    }
    dd_log(@"[path.file] 未命中任何路径键（文件可能未下载）");
    return nil;
}

// 文件消息扩展名（app 文件消息的 m_oAppDataItem 为 CExtendInfoOfAPP，
// 扩展名见 m_nsAppFileExt / -getFileExt）
// 证据：CExtendInfoOfAPP.m_nsAppFileExt（CExtendInfoOfAPP.h:30）、-getFileExt（L233）
static NSString *dd_file_ext_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    id appItem = nil;
    if ([msg respondsToSelector:@selector(m_oAppDataItem)]) appItem = [msg m_oAppDataItem];
    if (!appItem) @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
    if (!appItem) return nil;
    NSString *ext = nil;
    if ([appItem respondsToSelector:@selector(getFileExt)]) ext = [appItem getFileExt];
    if (!ext && [appItem respondsToSelector:@selector(m_nsAppFileExt)]) ext = [appItem m_nsAppFileExt];
    ext = [ext lowercaseString];
    unsigned int innerType = ([appItem respondsToSelector:@selector(m_uiAppMsgInnerType)])
        ? [(CExtendInfoOfAPP *)appItem m_uiAppMsgInnerType] : 0;
    dd_log(@"[ext.file] ext=%@ (innerType=%u)", ext ?: @"(nil)", innerType);
    return ext;
}

// 仅 mp3 / m4a 参与“文件转语音”（用户约束：文件消息只识别这两种格式）
static BOOL dd_file_is_audio(CMessageWrap *msg) {
    NSString *ext = dd_file_ext_of_msg(msg);
    BOOL ok = ext && ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"m4a"]);
    dd_log(@"[ext.file] 是否音频文件=%d (ext=%@)", ok, ext ?: @"(nil)");
    return ok;
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
static unsigned int dd_new_voice_local_id(void) {
    return kDDMCVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDMCVoiceLocalIDRange);
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
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (outDuration) *outDuration = CMTimeGetSeconds(asset.duration);
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
    if (![reader startReading]) return nil;
    NSMutableData *pcm = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sb = [out copyNextSampleBuffer];
        if (!sb) continue;
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

// 媒体 → 语音：先确保已下载，再抽音轨→SILK→发送语音消息到当前聊天
// pathBlock 由调用方按消息类型给出（普通视频取 videoPath；应用视频/文件取 appDataItem 路径）
// downloadBlock 由调用方按消息类型给出（普通视频用 StartDownloadVideo；应用视频/文件用 StartDownloadAppAttach）
static void dd_media_to_voice(CMessageWrap *msg, NSString *(^pathBlock)(void), void(^downloadBlock)(void)) {
    if (!msg) { dd_log(@"[media→voice] msg 为空，放弃"); return; }
    dd_log(@"[media→voice] ==== 开始 ==== type=%u localID=%u chat=%@",
          msg.m_uiMessageType, msg.m_uiMesLocalID, dd_chat_usr_of_msg(msg) ?: @"(nil)");
    NSString *path = pathBlock();
    if (!dd_file_exists(path)) {
        // 未下载：先自动下载，再等待本地文件出现
        dd_log(@"[media→voice] 本地文件不存在，触发自动下载");
        if (downloadBlock) downloadBlock();
        path = dd_wait_local_path(pathBlock, kDDMCDownloadTimeout);
    }
    if (!dd_file_exists(path)) { dd_log(@"[media→voice] 下载失败/超时，放弃转换"); return; }
    double duration = 0;
    NSData *pcm = dd_extract_pcm(path, &duration);
    if (pcm.length == 0) { dd_log(@"[media→voice] PCM 为空，放弃"); return; }
    NSData *silk = [objc_getClass("MJSilkCodec") encodeToSilkFromPCMData:pcm];
    dd_log(@"[media→voice] SILK 编码结果=%lu 字节 (PCM=%lu)", (unsigned long)silk.length, (unsigned long)pcm.length);
    if (silk.length == 0) { dd_log(@"[media→voice] SILK 编码失败，放弃"); return; }
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
    [silk writeToFile:tmp atomically:YES];
    unsigned int ms = (unsigned int)(duration * 1000);
    if (ms == 0) ms = 1000;
    if (ms > 60000) ms = 60000;
    dd_log(@"[media→voice] 时长=%ums → 发送语音", ms);
    dd_send_voice(dd_chat_usr_of_msg(msg), tmp, ms);
    dd_log(@"[media→voice] ==== 结束 ====");
}

#pragma mark - 转换：语音 → 文件（SILK → 音频/m4a → 作为文件消息发到当前聊天）

static NSData *dd_silk_data_of_msg(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[silk] msg 为空"); return nil; }
    unsigned int localID = msg.m_uiMesLocalID;
    Class wrapCls = objc_getClass("CMessageWrap");
    NSString *usr = [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
    NSString *p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:usr
                                                                    LocalID:localID
                                                                    DocPath:[objc_getClass("CUtility") GetDocPath]];
    dd_log(@"[silk] 主路径(CUtility)=%@ 存在=%d", p ?: @"(nil)", dd_file_exists(p));
    if (dd_file_exists(p)) {
        NSData *d = [NSData dataWithContentsOfFile:p];
        dd_log(@"[silk] 读到 %lu 字节", (unsigned long)d.length);
        return d;
    }
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if ([sender respondsToSelector:@selector(getAudioFileName:LocalID:)]) {
        NSString *p2 = [sender getAudioFileName:usr LocalID:localID];
        dd_log(@"[silk] 兜底(AudioSender)=%@ 存在=%d", p2 ?: @"(nil)", dd_file_exists(p2));
        if (dd_file_exists(p2)) return [NSData dataWithContentsOfFile:p2];
    } else {
        dd_log(@"[silk] AudioSender 无 getAudioFileName:LocalID:");
    }
    dd_log(@"[silk] 未取到 SILK 数据（语音文件可能未下载或路径接口失效）");
    return nil;
}

// PCM → m4a（AAC），按帧切片构造带时间戳的 PCM CMSampleBuffer 交给 AVAssetWriter 编码
static NSString *dd_write_m4a(NSData *pcm) {
    if (pcm.length == 0) return nil;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *err = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:url
                                                     fileType:AVFileTypeMPEG4
                                                        error:&err];
    if (err) return nil;
    AudioChannelLayout layout = {0};
    layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(kDDMCVoiceSampleRate),
        AVNumberOfChannelsKey: @1,
        AVChannelLayoutKey: [NSData dataWithBytes:&layout length:sizeof(layout)],
        AVEncoderBitRateKey: @(32000),
    };
    AVAssetWriterInput *input = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                              outputSettings:settings];
    [writer addInput:input];
    if (![writer startWriting]) return nil;
    [writer startSessionAtSourceTime:kCMTimeZero];

    CMFormatDescriptionRef fmt = NULL;
    AudioStreamBasicDescription asbd = {0};
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbd.mSampleRate = kDDMCVoiceSampleRate;
    asbd.mChannelsPerFrame = 1;
    asbd.mBitsPerChannel = 16;
    asbd.mBytesPerPacket = 2;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 2;
    if (CMAudioFormatDescriptionCreate(NULL, &asbd, 0, NULL, 0, NULL, NULL, &fmt) != noErr || !fmt)
        return nil;

    const unsigned int bytesPerFrame = 2;
    const unsigned int framesPerBuf = 4096;
    const unsigned int bytesPerBuf = framesPerBuf * bytesPerFrame;
    const uint8_t *base = (const uint8_t *)pcm.bytes;   // NSData.bytes 是 const void*，先转 uint8_t* 才能做指针算术
    unsigned int offset = 0;
    int64_t presented = 0;
    while (offset + bytesPerBuf <= pcm.length) {
        CMBlockBufferRef buf = NULL;
        CMBlockBufferCreateWithMemoryBlock(NULL, (void *)(base + offset), bytesPerBuf,
                                          NULL, NULL, 0, bytesPerBuf, 0, &buf);
        if (!buf) break;
        CMSampleTimingInfo timing = { CMTimeMake(1, kDDMCVoiceSampleRate),
                                      CMTimeMake(presented, kDDMCVoiceSampleRate),
                                      kCMTimeInvalid };
        CMSampleBufferRef sb = NULL;
        CMSampleBufferCreate(NULL, buf, TRUE, NULL, NULL, fmt, framesPerBuf, 1, &timing, 0, NULL, &sb);
        if (sb && input.readyForMoreMediaData) [input appendSampleBuffer:sb];
        if (sb) CFRelease(sb);
        CFRelease(buf);
        offset += bytesPerBuf;
        presented += framesPerBuf;
    }
    unsigned int remain = (unsigned int)(pcm.length - offset);
    if (remain > 0) {
        CMBlockBufferRef buf = NULL;
        CMBlockBufferCreateWithMemoryBlock(NULL, (void *)(base + offset), remain,
                                          NULL, NULL, 0, remain, 0, &buf);
        if (buf) {
            unsigned int rframes = remain / bytesPerFrame;
            CMSampleTimingInfo timing = { CMTimeMake(1, kDDMCVoiceSampleRate),
                                          CMTimeMake(presented, kDDMCVoiceSampleRate),
                                          kCMTimeInvalid };
            CMSampleBufferRef sb = NULL;
            CMSampleBufferCreate(NULL, buf, TRUE, NULL, NULL, fmt, rframes, 1, &timing, 0, NULL, &sb);
            if (sb && input.readyForMoreMediaData) [input appendSampleBuffer:sb];
            if (sb) CFRelease(sb);
            CFRelease(buf);
        }
    }
    [input markAsFinished];
    // -finishWriting 自 iOS 6 起被标记为 deprecated，CI 开了 -Werror 会直接报错 →
    // 改用 finishWritingWithCompletionHandler: 并用信号量同步等待（最多 10s）
    __block BOOL finished = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{
        finished = (writer.status == AVAssetWriterStatusCompleted);
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)));
    if (fmt) CFRelease(fmt);
    BOOL ok = dd_file_exists(path) && finished;
    dd_log(@"[m4a] AVAssetWriter 结果=%d 路径=%@ 状态=%ld 完成回调=%d 错误=%@",
          ok, path ?: @"(nil)", (long)writer.status, finished, writer.error.localizedDescription ?: @"无");
    return ok ? path : nil;
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
static NSString *dd_decode_silk_to_audio(NSData *silk) {
    Class codec = objc_getClass("MJSilkCodec");
    if ([codec respondsToSelector:@selector(decodeToAudioDataFromSilkData:)]) {
        NSData *audio = [codec decodeToAudioDataFromSilkData:silk];
        dd_log(@"[decode] decodeToAudioDataFromSilkData → %lu 字节", (unsigned long)audio.length);
        if (audio.length >= 12) {
            const unsigned char *b = (const unsigned char *)audio.bytes;   // NSData.bytes 是 const void*，需显式转换
            BOOL isFtyp = (b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p');
            // %02x 需要 unsigned int：可变参数会把 unsigned char 提升成 int，必须显式转换
            dd_log(@"[decode] 容器嗅探 ftyp=%d (前8字节: %02x%02x%02x%02x%02x%02x%02x%02x)",
                  isFtyp,
                  (unsigned)b[0], (unsigned)b[1], (unsigned)b[2], (unsigned)b[3],
                  (unsigned)b[4], (unsigned)b[5], (unsigned)b[6], (unsigned)b[7]);
            if (isFtyp) {   // 'ftyp' → m4a/mp4 容器，直出无需重编码
                NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:
                    [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]];
                if ([audio writeToFile:p atomically:YES] && dd_file_exists(p)) {
                    dd_log(@"[decode] 直出音频落盘 → %@", p);
                    return p;
                }
            }
        }
    } else {
        dd_log(@"[decode] MJSilkCodec 无 decodeToAudioDataFromSilkData:");
    }
    NSData *pcm = [codec decodeToPCMFromSilkData:silk];   // 兜底：SILK → PCM（MJSilkCodec.h:4）
    dd_log(@"[decode] 回退 PCM → %lu 字节", (unsigned long)pcm.length);
    if (pcm.length == 0) return nil;
    return dd_write_m4a(pcm);                              // PCM → m4a（AVAssetWriter, AAC）
}

// 语音消息 → 文件消息（"语音转文件"开关）：取 SILK → m4a → 作为文件消息发到当前聊天
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[voice→file] msg 为空，放弃"); return; }
    dd_log(@"[voice→file] ==== 开始 ==== localID=%u chat=%@",
          msg.m_uiMesLocalID, dd_chat_usr_of_msg(msg) ?: @"(nil)");
    NSData *silk = dd_silk_data_of_msg(msg);
    if (silk.length == 0) { dd_log(@"[voice→file] 取不到 SILK，放弃"); return; }
    NSString *m4a = dd_decode_silk_to_audio(silk);
    if (!m4a.length) { dd_log(@"[voice→file] 解码/封装失败，放弃"); return; }
    NSString *fn = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    BOOL sent = dd_send_file_to_chat(dd_chat_usr_of_msg(msg), m4a, fn);
    dd_log(@"[voice→file] ==== 结束 ==== 发送结果=%d", sent);
}

#pragma mark - 菜单图标（参考 DD小丑助手：MMMenuItem 直接吃 svg 资源名）

static MMMenuItem *dd_convertMenuItem(NSString *title, NSString *svgName, id target, SEL action) {
    id item = [%c(MMMenuItem) alloc];
    return [item initWithTitle:title
                       svgName:svgName
                        target:target
                        action:action];
}

// 统一注入：取原生菜单数组，按开关追加对应按钮
static NSArray *dd_inject_items(id cell, NSArray *original, BOOL enabled, NSString *title,
                                NSString *svgName, SEL action) {
    dd_log(@"[menu] cell=%@ 注入「%@」enabled=%d 原生菜单数=%lu",
          NSStringFromClass([cell class]), title, enabled, (unsigned long)original.count);
    if (!enabled) { dd_log(@"[menu] 开关关闭/类型不匹配，不注入「%@」", title); return original; }
    MMMenuItem *item = dd_convertMenuItem(title, svgName, cell, action);
    if (!item) { dd_log(@"[menu] MMMenuItem 构造失败（svg=%@）", svgName); return original; }
    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];   // 追加到菜单末尾（与 WCR 行为一致）
    dd_log(@"[menu] 已追加「%@」→ 菜单数=%lu", title, (unsigned long)items.count);
    return items;
}

#pragma mark - Hook：视频消息 → 转语音（icon_filled_record_voice.svg）

%hook VideoMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].videoToVoiceEnabled;
    return dd_inject_items(self, original, on, @"转语音",
                           @"icon_filled_record_voice", @selector(dd_mediaToVoice:));
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
    return dd_inject_items(self, original, on, @"转语音",
                           @"icon_filled_record_voice", @selector(dd_mediaToVoice:));
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

#pragma mark - Hook：文件消息 → 转语音（icon_filled_record_voice.svg）

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].fileToVoiceEnabled;
    if (on) {
        CMessageWrap *msg = dd_msg_of_cell(self);
        on = dd_file_is_audio(msg);   // 文件消息只识别 mp3 / m4a
    }
    return dd_inject_items(self, original, on, @"转语音",
                           @"icon_filled_record_voice", @selector(dd_mediaToVoice:));
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

#pragma mark - Hook：语音消息 → 转文件（voice_record_filled.svg）

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].voiceToFileEnabled;
    return dd_inject_items(self, original, on, @"转文件",
                           @"voice_record_filled", @selector(dd_voiceToFile:));
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

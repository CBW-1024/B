//  DD语音助手 —— 微信媒体互转（Theos/Logos 单文件）
//  长按消息 → 原生长按菜单追加转换按钮 → 点击转换并发送到当前聊天：
//    视频 / 文件消息 → 「转语音」→ SILK 语音消息
//    语音消息        → 「转文件」→ m4a 文件消息
//  未下载的媒体先触发微信自动下载，下载完成后再转换。
//
//  本文件所有微信类/方法签名锚定微信 8.0.79 头文件 dump + WCRefine.dylib 反汇编。
//  调试日志：设置页「调试日志」分组导出 / 清空（自签证书看不到 syslog，故落 App 沙盒）。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Photos/Photos.h>
#import <substrate.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <execinfo.h>

// CI（Xcode 26 / iOS 26 SDK）开 -Werror，这两类警告会变 error
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"

#pragma mark - 微信类声明（锚定 8.0.79 头文件 dump）

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
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightValue:(id)a4;
@end

// MMMenuItem.h:1 —— 父类是 NSObject（不是 UIMenuItem）；无 title/action getter，去重靠 userInfo
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
- (id)m_nsContent;                                  // CMessageWrap.h:402  消息正文（语音/appmsg XML）
- (void)setM_nsContent:(id)arg1;                    // CMessageWrap.h:676
- (unsigned int)m_uiDownloadStatus;                 // CMessageWrap.h:513
- (void)setM_uiDownloadStatus:(unsigned int)arg1;   // CMessageWrap.h:711
- (void)setM_bForward:(BOOL)arg1;                   // CMessageWrap.h:590
- (id)getVoicePath;                                 // CMessageWrap.h:362
- (void)setM_nsVoicePath:(NSString *)arg1;          // WCR 0x8dfec0（dump 未导出，运行时存在；语音规范路径，ResendVoiceMsg 据此定位 SILK）
+ (id)getPathOfAudio:(id)arg1;                      // CMessageWrap.h:66
+ (void)GetPathOfAppDataByUserName:(id)usr andMessageWrap:(id)wrap retStrPath:(void *)pp;  // CMessageWrap.h:108
@end

@interface WCLanDeviceServiceUtil : NSObject
+ (id)filePathFromMsgWrap:(id)arg1;                 // WCLanDeviceServiceUtil.h:7
@end

@interface CExtendInfoOfAPP : NSObject
@property(nonatomic) unsigned int m_uiAppMsgInnerType;      // 6 = 文件
@property(retain, nonatomic) NSString *m_nsAppFileName;
@property(retain, nonatomic) NSString *m_nsAppFileExt;
@property(nonatomic) unsigned long long m_uiAppDataSize;
@property(retain, nonatomic) NSString *m_nsAppMediaUrl;
@property(retain, nonatomic) NSString *m_nsAppAttachID;
- (id)init;
- (void)setM_nsTitle:(id)arg1;
- (void)setM_bAppAttachExistInSvr:(BOOL)arg1;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
- (id)m_dtVoice;                                    // :12
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
- (BOOL)StartDownloadAppAttach:(id)a0 MsgWrap:(id)a1 Silent:(BOOL)a2 autoDownload:(BOOL)a3;          // :33
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
#define kDDMCLogEnabled   @"kDDMCLogEnabled"

#define kDDMCVoiceMsgType 34          // 语音 (0x22)
#define kDDMCAppMsgType   49          // app/文件 (0x31)
#define kDDMCAppInnerFile 6           // 文件 innerType
#define kDDMCVoiceFormat  4           // SILK
#define kDDMCVoiceEndFlag 1
#define kDDMCStatusSending 1
// 微信语音 PCM 参数（WCRefine sub_0x8f1bc8 @0x8f1f68 mov w2,#0x3e80 == 16000；单声道；16bit）
#define kDDMCVoiceSampleRate 16000
#define kDDMCDownloadTimeout 90.0

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
        kDDMCVideoToVoice: @NO, kDDMCFileToVoice: @NO,
        kDDMCVoiceToFile: @NO, kDDMCLogEnabled: @YES,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _videoToVoiceEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVideoToVoice];
        _fileToVoiceEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCFileToVoice];
        _voiceToFileEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVoiceToFile];
        _logEnabled          = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCLogEnabled];
    }
    return self;
}
- (void)setVideoToVoiceEnabled:(BOOL)v { _videoToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVideoToVoice]; }
- (void)setFileToVoiceEnabled:(BOOL)v { _fileToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCFileToVoice]; }
- (void)setVoiceToFileEnabled:(BOOL)v { _voiceToFileEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVoiceToFile]; }
- (void)setLogEnabled:(BOOL)v { _logEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCLogEnabled]; }
@end

#pragma mark - 调试日志

// MJSilkCodec 的编解码类方法内部带全局编码器上下文、非线程安全（并发调用 → 堆损坏 →
// 后台 GCD 队列 autorelease pool pop 时 SIGSEGV）。所有媒体转换收敛到此串行队列。
static dispatch_queue_t dd_convert_queue;

@interface DDLogStore : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy)   NSString *logDir;
@property (nonatomic, copy)   NSString *logPath;
- (void)append:(NSString *)line;
- (void)flushSync;
- (void)clearAll;
- (NSUInteger)lineCount;
- (unsigned long long)fileSize;
@end

// 崩溃信号处理器只能用 async-signal-safe 的 open/write，不能走 Objective-C，
// 故在此缓存日志文件的 C 路径（init 时写入一次，之后只读）。
static char dd_log_c_path[PATH_MAX] = {0};

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
        _enabled = YES;
        // 日志落 Library/Preferences/DDMediaConvertLogs：Documents/下载缓存会被微信清理，重启即丢。
        NSArray<NSString *> *libDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *lib = libDirs.firstObject.length ? libDirs.firstObject : NSHomeDirectory();
        NSString *pref = [lib stringByAppendingPathComponent:@"Preferences"];
        _logDir  = [pref stringByAppendingPathComponent:@"DDMediaConvertLogs"];
        _logPath = [_logDir stringByAppendingPathComponent:@"ddvoice_debug.log"];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:_logDir withIntermediateDirectories:YES attributes:nil error:nil];
        if (![fm fileExistsAtPath:_logPath]) [fm createFileAtPath:_logPath contents:nil attributes:nil];
        _handle = [NSFileHandle fileHandleForWritingAtPath:_logPath];
        [_handle seekToEndOfFile];
        strlcpy(dd_log_c_path, _logPath.fileSystemRepresentation, sizeof(dd_log_c_path));
    }
    return self;
}
- (void)append:(NSString *)line {
    if (!line.length) return;
    // 同步写 + 每条 fsync：崩溃瞬间的日志也必须落盘（异步写会在闪退时丢日志，无法定位问题）
    dispatch_sync(_q, ^{
        NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        [self->_handle seekToEndOfFile];
        [self->_handle writeData:d];
        [self->_handle synchronizeFile];
        NSLog(@"[%@] %@", kDDMCPluginName, line);
    });
}
- (void)flushSync { dispatch_sync(_q, ^{ [self->_handle synchronizeFile]; }); }
// 行数按磁盘文件统计：闪退重启后内存计数归零（导出头部出现过「日志条数: 0 文件大小: 4685」），
// 只有文件行数才与实际导出的正文一致。
- (NSUInteger)lineCount {
    __block NSUInteger n = 0;
    dispatch_sync(_q, ^{
        NSString *s = [NSString stringWithContentsOfFile:self->_logPath encoding:NSUTF8StringEncoding error:nil];
        NSUInteger c = s.length ? [s componentsSeparatedByString:@"\n"].count : 0;
        n = c > 1 ? c - 1 : 0;
    });
    return n;
}
- (unsigned long long)fileSize {
    __block unsigned long long sz = 0;
    dispatch_sync(_q, ^{
        sz = [[[NSFileManager defaultManager] attributesOfItemAtPath:self->_logPath error:nil][NSFileSize] unsignedLongLongValue];
    });
    return sz;
}
- (void)clearAll {
    dispatch_sync(_q, ^{
        [self->_handle closeFile];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:self->_logPath error:nil];
        [fm createFileAtPath:self->_logPath contents:nil attributes:nil];
        self->_handle = [NSFileHandle fileHandleForWritingAtPath:self->_logPath];
        [self->_handle seekToEndOfFile];
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

// 导出：flush → 拼头部信息 → 另存带时间戳 txt，返回路径
static NSString *dd_log_export_path(void) {
    DDLogStore *s = [DDLogStore shared];
    [s flushSync];
    NSData *d = [NSData dataWithContentsOfFile:s.logPath];
    NSString *body = [[NSString alloc] initWithData:(d ?: [NSData data]) encoding:NSUTF8StringEncoding];
    if (!body.length) body = @"（暂无日志）\n";
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    static NSDateFormatter *fdf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fdf = [NSDateFormatter new]; fdf.dateFormat = @"yyyyMMdd_HHmmss"; });
    NSString *stamp = [fdf stringFromDate:[NSDate date]];
    NSString *text = [NSString stringWithFormat:
        @"%@ 调试日志\n设备: %@  系统: %@\n微信: %@ (%@)\n导出时间: %@\n日志条数: %lu  文件大小: %llu 字节\n"
        @"----------------------------------------\n%@",
        kDDMCPluginName,
        [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion,
        info[@"CFBundleShortVersionString"] ?: @"-", info[@"CFBundleVersion"] ?: @"-",
        [NSDate date], (unsigned long)[s lineCount], [s fileSize], body];
    NSString *dst = [s.logDir stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@_日志_%@.txt", kDDMCPluginName, stamp]];
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
static NSString *dd_chat_usr_of_msg(CMessageWrap *msg) {
    Class wrapCls = objc_getClass("CMessageWrap");
    return [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
}
// 类型守卫：非 CMessageWrap 塞进 wrap 类方法会在微信内部越界崩
static BOOL dd_is_msg_wrap(id obj) {
    if (!obj) return NO;
    if ([obj isKindOfClass:objc_getClass("CMessageWrap")]) return YES;
    return [obj respondsToSelector:@selector(m_uiMesLocalID)] &&
           [obj respondsToSelector:@selector(m_uiMessageType)];
}
static CMessageWrap *dd_msg_of_cell(id cell) {
    id vm = [cell viewModel];
    if ([vm respondsToSelector:@selector(messageWrap)]) return [vm messageWrap];
    dd_log(@"[msg] cell=%@ vm=%@ 无 messageWrap", NSStringFromClass([cell class]), NSStringFromClass([vm class]));
    return nil;
}
// 把待发送 wrap 放进静态数组保活：微信发送是异步的（上传在后台队列），ARC 在我们 block
// 返回后释放 wrap 会让后台链路踩空（后台队列 autorelease pool pop 时 SIGSEGV）。
static void dd_retain_wrap(id wrap) {
    if (!wrap) return;
    static NSMutableArray *pool = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ pool = [NSMutableArray array]; });
    @synchronized (pool) { [pool addObject:wrap]; }
}

#pragma mark - 路径解析

// 普通视频本地路径（VideoMessageCellView，覆盖 m_uiMessageType=43 视频 / 62 小视频）
static NSSet *dd_video_ext_set(void) {
    static NSSet *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSSet setWithObjects:@"mp4", @"mov", @"m4v", nil]; });
    return s;
}
// 路径可能是文件也可能是目录：目录时扫首个白名单视频文件
static NSString *dd_first_video_file_under_path(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) return nil;
    if (!isDir) return [dd_video_ext_set() containsObject:path.pathExtension.lowercaseString] ? path : nil;
    for (NSString *name in [fm contentsOfDirectoryAtPath:path error:nil]) {
        if (![dd_video_ext_set() containsObject:name.pathExtension.lowercaseString]) continue;
        NSString *sub = [path stringByAppendingPathComponent:name];
        BOOL subDir = NO;
        if ([fm fileExistsAtPath:sub isDirectory:&subDir] && !subDir) return sub;
    }
    return nil;
}
static NSString *dd_video_path_of_cell(id cell) {
    id msg = dd_msg_of_cell(cell);
    if (msg && [msg respondsToSelector:@selector(IsVideoMsg)] && ![msg IsVideoMsg]) return nil;
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    // ① VideoMessageViewModel.videoPath（VideoMessageViewModel.h:24）
    id vm = [cell viewModel];
    if ([vm respondsToSelector:@selector(videoPath)]) {
        NSString *p = [vm videoPath];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    }
    // ② WCLanDeviceServiceUtil.filePathFromMsgWrap:（WCLanDeviceServiceUtil.h:7）
    if (dd_is_msg_wrap(msg)) {
        Class lan = objc_getClass("WCLanDeviceServiceUtil");
        if ([lan respondsToSelector:@selector(filePathFromMsgWrap:)]) {
            id p = [lan filePathFromMsgWrap:msg];
            if ([p isKindOfClass:[NSString class]] && ((NSString *)p).length) [cands addObject:p];
        }
    }
    NSUInteger idx = 0;
    for (NSString *p in cands) {
        NSString *f = dd_first_video_file_under_path(p);
        if (f.length) {
            dd_log(@"[path.video] 源#%lu 命中 → %@", (unsigned long)idx, f);
            return f;
        }
        idx++;
    }
    if (cands.count) return cands.firstObject;   // 可能只是目录，下载后再解析
    dd_log(@"[path.video] 取不到视频路径");
    return nil;
}

// 文件消息本地路径（CMessageWrap.h:108）。
// 【实证】本方法能正确返回路径：日志里 2.mp3 / 3.m4r 均解析成功。文件消息的崩溃发生在「发送之后」，
// 不在本方法 —— 曾误判为本方法破坏堆状态，改走 GetPathOfAppData:LocalID:FileExt:retStrPath:（:106）
// / CExtendInfoOfAPP.getFileExt 后，日志显示连「命中」都打不出（004922），崩点被推到更早，已回退。
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
    NSString *p = nil;
    [objc_getClass("CMessageWrap") GetPathOfAppDataByUserName:dd_current_usr_name()
                                          andMessageWrap:msg retStrPath:&p];
    if ([p isKindOfClass:[NSString class]] && p.length) {
        if (dd_file_exists(p)) { dd_log(@"[path.file] 命中 → %@", p); return p; }
        return p;   // 未下载完也返回路径供下载轮询
    }
    return nil;
}
// 语音消息本地路径：getVoicePath（CMessageWrap.h:362）→ getPathOfAudio:（:66）→ m_dtVoice 兜底
static NSString *dd_voice_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    NSString *p1 = (NSString *)[msg getVoicePath];          // CMessageWrap.h:362
    if ([p1 isKindOfClass:[NSString class]] && p1.length) [cands addObject:p1];
    NSString *p2 = (NSString *)[wrapCls getPathOfAudio:msg]; // CMessageWrap.h:66
    if ([p2 isKindOfClass:[NSString class]] && p2.length) [cands addObject:p2];
    dd_log(@"[path.voice] getVoicePath=%@  getPathOfAudio=%@", p1 ?: @"(空)", p2 ?: @"(空)");
    for (NSString *c in cands) if (dd_file_exists(c)) { dd_log(@"[path.voice] 命中 → %@", c); return c; }
    NSData *d = (NSData *)((CExtendInfoOfVoiceMsg *)[msg m_extendInfoWithMsgType]).m_dtVoice;
    if (d.length) {
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
        [d writeToFile:tmp atomically:YES];
        dd_log(@"[path.voice] 内存 m_dtVoice 落临时 → %@", tmp);
        return tmp;
    }
    dd_log(@"[path.voice] 取不到语音路径（可能尚未下载）");
    return nil;
}

#pragma mark - 自动下载

static void dd_trigger_video_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(StartDownloadVideo:MsgWrap:Priority:Silent:)]) {
        [mgr StartDownloadVideo:nil MsgWrap:msg Priority:YES Silent:YES];
        dd_log(@"[download.video] 已触发 StartDownloadVideo localID=%u", msg.m_uiMesLocalID);
    }
}
// 文件消息下载：基础触发 StartDownloadAppAttach:MsgWrap:Silent:（CMessageMgr.h:32）。
// 实测 m_uiDownloadStatus 恒为 0，无「状态=9 误判」场景，故不叠加 attachId 强制重拉。
static BOOL dd_trigger_file_download(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return NO;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if (!mgr) return NO;
    BOOL ok = [mgr respondsToSelector:@selector(StartDownloadAppAttach:MsgWrap:Silent:)] &&
              [mgr StartDownloadAppAttach:nil MsgWrap:msg Silent:YES];
    dd_log(@"[download.file] StartDownloadAppAttach → %@ localID=%u", ok ? @"YES" : @"NO", msg.m_uiMesLocalID);
    if (!ok && [mgr respondsToSelector:@selector(StartDownloadAppAttach:MsgWrap:Silent:autoDownload:)])
        ok = [mgr StartDownloadAppAttach:nil MsgWrap:msg Silent:YES autoDownload:YES];
    return ok;
}
// 轮询等待文件下载/写入完成：连续两轮大小一致才算就绪（半下载文件会让 SILK 编码产出损坏数据，
// 进而使 ResendVoiceMsg 内部 C 层 SIGSEGV —— @try 兜不住）
static NSString *dd_wait_local_path(NSString *(^pathBlock)(void), NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    long long prevSize = -1;
    NSTimeInterval lastLog = 0;
    while ([deadline timeIntervalSinceNow] > 0) {
        NSString *p = pathBlock();
        if (dd_file_exists(p)) {
            NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
            long long sz = a ? [a[NSFileSize] longLongValue] : -1;
            if (sz > 0 && sz == prevSize) { dd_log(@"[download.wait] 大小稳定(%lld) → 就绪 %@", sz, p); return p; }
            prevSize = sz;
        }
        NSTimeInterval now = [NSDate.date timeIntervalSince1970];
        if (now - lastLog >= 3.0) {   // 每 3s 一条，避免刷屏；持久化日志里能看清下载是否推进
            dd_log(@"[download.wait] 轮询中 路径=%@ 存在=%d 大小=%lld",
                   p ?: @"(空)", dd_file_exists(p), prevSize);
            lastLog = now;
        }
        [NSThread sleepForTimeInterval:0.5];
    }
    dd_log(@"[download.wait] 超时 %.0fs 仍未就绪，放弃转换", timeout);
    return nil;
}

#pragma mark - SILK 容器（对齐 WCRefine 反汇编）

// 微信 .aud 正规容器头是 10 字节 \x02#!SILK_V3；MJSilkCodec 常只吐 9 字节 #!SILK_V3，须补 0x02
//   （WCRefine sub_0x8f18d8：0x8f1ac8 mov w8,#2 → appendBytes(&0x02,1)）
static BOOL dd_silk_has_magic9(NSData *d) {
    return d.length >= 9 && memcmp(d.bytes, "#!SILK_V3", 9) == 0;
}
static BOOL dd_silk_has_magic10(NSData *d) {
    return d.length >= 10 && ((const unsigned char *)d.bytes)[0] == 0x02
           && memcmp((const unsigned char *)d.bytes + 1, "#!SILK_V3", 9) == 0;
}
// 帧链校验（WCRefine sub_0x8f15f4）：容器后是「[2字节小端帧长][帧数据]」重复序列
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
// PCM → SILK（WCRefine sub_0x8f2804 @0x8f2890）。
//
// 【崩溃实证 · 勿恢复回环解码验证】原实现编码后调 decodeToPCMFromSilkData: 把产物解回 PCM 做
// 「能不能解回来」的验证。真机日志 + 信号栈证明它就是闪退根因：
//   01:39:23 文件→语音 36s 素材 → 回环一次性解出 PCM 1157120 字节 → 发送结果=1
//   01:39:2x [CRASH] signal=11 SIGSEGV
//            _pthread_wqthread → _dispatch_root_queue_drain → objc_autoreleasePoolPop → objc_release
//   同样链路的 16s 素材（回环 PCM 512640 字节）从不崩溃 —— 一次性解码的堆破坏随 PCM 长度触发，
//   超过约 1MB 即写坏堆，随后 dd_convert_queue 的 autorelease pool 释放任何对象都会炸。
// 该检查同时也从未失败过（每份日志恒为「选中可解码容器」），属纯冗余，故删除。
// 产物校验交由 dd_silk_frames_valid 承担：纯字节扫描帧链，不进解码器、不分配大内存。
static NSData *dd_encode_pcm_to_silk(NSData *pcm) {
    if (pcm.length == 0) return nil;
    Class codec = objc_getClass("MJSilkCodec");
    if (!codec || ![codec respondsToSelector:@selector(encodeToSilkFromPCMData:)]) return nil;
    NSData *raw = [codec encodeToSilkFromPCMData:pcm];
    if (raw.length == 0) { dd_log(@"[silk.enc] 编码为空，放弃"); return nil; }
    NSData *silk = dd_silk_normalize(raw) ?: raw;
    if (!dd_silk_frames_valid(silk)) { dd_log(@"[silk.enc] 帧链校验失败，放弃"); return nil; }
    dd_log(@"[silk.enc] 产物 magic%d 长度=%lu 字节（源 PCM %lu 字节）",
           dd_silk_has_magic10(silk) ? 10 : 9, (unsigned long)silk.length, (unsigned long)pcm.length);
    return silk;
}
// SILK → PCM：候选顺序照 WCR 容器认知（\x02#!SILK_V3 原文优先）；帧链不自洽的不喂解码器
static NSData *dd_decode_silk_to_pcm(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) { dd_log(@"[silk.pcm] MJSilkCodec 不可用"); return nil; }
    if (fileData.length < 12) { dd_log(@"[silk.pcm] 数据过小(<12) 放弃"); return nil; }
    NSMutableArray<NSData *> *cands = [NSMutableArray array];
    if (dd_silk_has_magic10(fileData)) {
        [cands addObject:fileData];
    } else if (dd_silk_has_magic9(fileData)) {
        [cands addObject:fileData];
        NSData *full = dd_silk_normalize(fileData);
        if (full) [cands addObject:full];
    } else {
        dd_log(@"[silk.pcm] 非 SILK 魔数，放弃"); return nil;
    }
    NSData *best = nil;
    NSUInteger idx = 0;
    for (NSData *cand in cands) {
        if (!dd_silk_frames_valid(cand)) { dd_log(@"[silk.pcm] 候选#%lu 帧链无效 跳过", (unsigned long)idx); idx++; continue; }
        NSData *p = [codec decodeToPCMFromSilkData:cand];
        if (p.length > best.length) best = p;
        idx++;
    }
    dd_log(@"[silk.pcm] 解码结果=%lu 字节", (unsigned long)best.length);
    return best.length ? best : nil;
}

#pragma mark - 媒体 → 语音

static id dd_voiceExtendInfo(id wrap) {
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    id nv = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
// 语音消息正文：标准 voicemsg XML（对齐 WCR _WCRefineSendVoiceDataToChat @0x8df464）。
// 不写它，微信重启后会从 DB 的 m_nsContent 重建消息时拿到空正文 → 当「未完成语音」自动重发。
static void dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDMCVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDMCVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    [ext setM_dtVoice:voiceData];
    NSString *xml = [NSString stringWithFormat:
        @"<msg><voicemsg voicelength=\"%u\" voiceformat=\"4\" forwardflag=\"0\" /></msg>", duration];
    [wrap setM_nsContent:xml];
}
// 音频数据落到微信语音规范路径（CUtility.GetPathOfMesAudio:LocalID:DocPath: CUtility.h:82）
static NSString *dd_install_audio_file(CMessageWrap *wrap, NSString *src) {
    NSString *p = nil;
    if (wrap.m_uiMesLocalID != 0) {
        p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:dd_chat_usr_of_msg(wrap)
                                                            LocalID:wrap.m_uiMesLocalID
                                                            DocPath:[objc_getClass("CUtility") GetDocPath]];
    }
    if (!p.length) return nil;   // 仅 GetPathOfMesAudio:LocalID:DocPath: 原生路径（对齐 WCR，不靠字符串替换 hack）
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent]
  withIntermediateDirectories:YES attributes:nil error:nil];
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    [fm copyItemAtPath:src toPath:p error:nil];
    dd_log(@"[voice.install] 目标=%@ 复制结果=%d", p, dd_file_exists(p));
    return p;
}
// 发语音到指定会话。链路对齐 WCR：AddLocalMsg(分配 localID) → 写 SILK 到规范路径 → SaveMesVoice
// → ResendVoiceMsg。不用 AudioSender.addMessageToDB:（8.0.79 下它不分配 m_uiMesLocalID）。
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    NSData *data = [NSData dataWithContentsOfFile:audPath];
    if (data.length == 0 || !dd_silk_frames_valid(data)) {
        dd_log(@"[voice.send] 数据为空或非合法 SILK，放弃（避免 ResendVoiceMsg C 层崩）");
        return NO;
    }
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if (!sender) return NO;
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCVoiceMsgType];
    [wrap setM_uiMessageType:kDDMCVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    [wrap setM_uiCreateTime:t ?: (unsigned int)time(NULL)];
    [wrap setM_uiStatus:kDDMCStatusSending];
    [wrap setM_uiDownloadStatus:9];    // 已下载（WCR 同款，缺失会让发送链路状态自相矛盾）
    [wrap setM_bForward:1];
    dd_retain_wrap(wrap);
    dd_configureVoiceMsg(wrap, data, duration);

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddLocalMsg:usr MsgWrap:wrap];
    dd_log(@"[voice.send] AddLocalMsg → localID=%u", wrap.m_uiMesLocalID);
    NSString *voicePath = dd_install_audio_file(wrap, audPath);   // 写 SILK 到规范路径（GetPathOfMesAudio）
    // WCR 0x8dfec0：必须显式 setM_nsVoicePath。缺则 ResendVoiceMsg 回退按 localID 重算路径，
    // 文件来源(dlStatus=0)读坏文件/状态不一致 → SIGSEGV；视频也设，无害。
    if (voicePath.length && [wrap respondsToSelector:@selector(setM_nsVoicePath:)])
        [wrap setM_nsVoicePath:voicePath];
    // SaveMesVoice 首参必须 nil：WCR 反汇编 SaveMesVoice:MsgWrap: 仅两参，传 SILK NSData 会被当路径 → 崩（1.0.25 教训）
    if ([mgr respondsToSelector:@selector(SaveMesVoice:MsgWrap:)])
        [mgr SaveMesVoice:nil MsgWrap:wrap];
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    dd_log(@"[voice.send] 已发送 voicePath=%@ 会话=%@", voicePath ?: @"(空)", usr ?: @"(nil)");
    return YES;
}
// 抽音轨为 16bit / 单声道 / 16000Hz PCM（输出字典 7 键，对齐 WCRefine sub_0x8f1bc8）
static NSData *dd_extract_pcm(NSString *mediaPath, double *outDuration) {
    dd_log(@"[pcm] 入参 mediaPath=%@ 存在=%d", mediaPath, dd_file_exists(mediaPath));
    if (!dd_file_exists(mediaPath)) return nil;
    NSDictionary *opts = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:mediaPath] options:opts];
    double dur = CMTimeGetSeconds(asset.duration);
    if (outDuration && isfinite(dur) && dur > 0) *outDuration = dur;
    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (err) { dd_log(@"[pcm] AVAssetReader 创建失败: %@", err.localizedDescription); return nil; }
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) { dd_log(@"[pcm] 素材无音轨: %@", mediaPath); return nil; }
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
    if (![reader startReading]) { dd_log(@"[pcm] startReading 失败"); return nil; }
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
    dd_log(@"[pcm] 抽取结果=%d PCM=%lu 字节", reader.status == AVAssetReaderStatusCompleted, (unsigned long)pcm.length);
    return reader.status == AVAssetReaderStatusCompleted ? pcm : nil;
}

// 媒体 → 语音：确保已下载 → 抽音轨 → SILK → 发送到当前聊天
//
// 【线程选择依据：日志实证，勿再改】路径解析（GetPathOfAppDataByUserName / filePathFromMsgWrap /
// StartDownload* 等）必须留在「后台队列」内直接调用，不要搬到主线程：
// v1.0.27 原始实现如此，文件消息能完整跑完发送（发送结果=1，重启后语音送达，即最初报的症状）。
// 之后两版把解析搬到主线程（后台 dispatch_sync(main)，或主线程先解析再入队）反而让文件消息在
// 「路径解析阶段」就崩，连发送都到不了 —— 日志 231315 / 002044 / 004922 三份一致：命中后零输出。
// 结论：GetPathOfAppDataByUserName 在主线程调用立即致命，在后台调用至少能完成发送。
static void dd_media_to_voice(NSString *tag, CMessageWrap *msg, NSString *(^pathBlock)(void), void(^downloadBlock)(void)) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    dd_log(@"[%@→语音] ==== 开始 ==== type=%u localID=%u dlStatus=%u chat=%@",
           tag, msg.m_uiMessageType, msg.m_uiMesLocalID, msg.m_uiDownloadStatus, usr ?: @"(nil)");
    dispatch_async(dd_convert_queue, ^{
        NSString *path = pathBlock();
        if (!dd_file_exists(path)) {
            if (downloadBlock) downloadBlock();
            path = dd_wait_local_path(pathBlock, kDDMCDownloadTimeout);
            dd_log(@"[%@→语音] 下载后解析路径=%@ 存在=%d", tag, path ?: @"(空)", dd_file_exists(path));
        }
        if (!dd_file_exists(path)) { dd_log(@"[%@→语音] 下载失败/超时，放弃", tag); return; }
        NSData *fileData = [NSData dataWithContentsOfFile:path];
        dd_log(@"[%@→语音] 源文件读取 len=%lu ext=%@", tag, (unsigned long)fileData.length, path.pathExtension.lowercaseString);
        NSString *ext = [[path pathExtension] lowercaseString];
        NSData *aud = nil;
        double duration = 0;
        // 源本身就是合法 SILK（.aud/.silk/.slk）→ 按 WCR 原样复用，不二次编码
        BOOL alreadySilk = fileData.length > 0 &&
            ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"] || [ext isEqualToString:@"slk"]) &&
            dd_silk_frames_valid(fileData);
        if (alreadySilk) {
            dd_log(@"[%@→语音] 源已是合法 SILK，原样复用（不二次编码）magic%d",
                   tag, dd_silk_has_magic10(fileData) ? 10 : 9);
            aud = fileData;
            NSData *pcm = dd_decode_silk_to_pcm(fileData);
            duration = pcm.length ? (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2) : 0;
        } else {
            NSData *pcm = dd_extract_pcm(path, &duration);
            if (pcm.length == 0) { dd_log(@"[%@→语音] PCM 为空，放弃", tag); return; }
            // 时长必须按真实 PCM 长度算（asset.duration 是视频时长，可能与音轨不符）
            duration = (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2);
            aud = dd_encode_pcm_to_silk(pcm);
            if (aud.length == 0) { dd_log(@"[%@→语音] SILK 编码失败，放弃", tag); return; }
        }
        NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
        [aud writeToFile:tmp atomically:YES];
        unsigned int ms = (unsigned int)(duration * 1000);
        if (ms == 0) ms = 1000;
        if (ms > 60000) ms = 60000;   // 微信语音上限 60s
        dd_log(@"[%@→语音] 时长=%ums → 发送语音 (aud=%lu 字节)", tag, ms, (unsigned long)aud.length);
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sent = dd_send_voice(usr, tmp, ms);
            dd_log(@"[%@→语音] ==== 结束 ==== 发送结果=%d", tag, sent);
        });
    });
}

#pragma mark - 语音 → 文件

// PCM → WAV（44 字节 RIFF 头，16bit / 单声道 / 16000Hz）
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
// PCM → m4a：PCM→WAV→AVAssetExportSession(AVAssetExportPresetAppleM4A)
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
    dd_log(@"[m4a] 导出结果=%d", ok);
    return ok ? path : nil;
}
// SILK → m4a 文件
static NSString *dd_decode_silk_to_audio(NSData *fileData) {
    dd_log(@"[voice→file] SILK→PCM→m4a 开始 (源=%lu 字节)", (unsigned long)fileData.length);
    NSData *pcm = dd_decode_silk_to_pcm(fileData);
    if (pcm.length == 0) { dd_log(@"[voice→file] 解码 PCM 为空，放弃"); return nil; }
    NSString *m4a = dd_write_m4a(pcm);
    dd_log(@"[voice→file] m4a=%@", m4a ?: @"(空)");
    return m4a;
}
// 把临时产物拷进微信持久沙盒再发送（临时目录会被系统/重启清空，指向死路径 → 消息打不开）
static NSString *dd_persist_copy(NSString *src) {
    if (!dd_file_exists(src)) return nil;
    NSString *dir = nil;
    Class util = objc_getClass("CUtility");
    if ([util respondsToSelector:@selector(GetDocPath)]) {
        NSString *d = (NSString *)[util GetDocPath];
        if ([d isKindOfClass:[NSString class]] && d.length) dir = d;
    }
    if (!dir.length) {
        NSArray<NSString *> *ds = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        dir = ds.count ? ds.firstObject : NSHomeDirectory();
    }
    NSString *dst = [dir stringByAppendingPathComponent:
        [NSString stringWithFormat:@"ddmc_voice_%@.m4a", [[NSUUID UUID] UUIDString]]];
    return [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil] ? dst : nil;
}
// 发文件消息到当前聊天：AddAppMsg(本地落库) → StartUploadAppMsg(触发上传)
static BOOL dd_send_file_to_chat(NSString *usr, NSString *m4aPath, NSString *fileName) {
    NSString *persistPath = dd_persist_copy(m4aPath);
    if (persistPath.length) m4aPath = persistPath;
    if (!dd_file_exists(m4aPath) || !usr.length) return NO;
    NSData *fdata = [NSData dataWithContentsOfFile:m4aPath];
    if (fdata.length == 0) return NO;
    unsigned long long fsize = fdata.length;
    dd_log(@"[file.send] usr=%@ file=%@ size=%llu", usr, m4aPath.lastPathComponent, fsize);

    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCAppMsgType];
    [wrap setM_uiMessageType:kDDMCAppMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    [wrap setM_uiCreateTime:t ?: (unsigned int)time(NULL)];
    [wrap setM_uiStatus:kDDMCStatusSending];

    CExtendInfoOfAPP *app = [[objc_getClass("CExtendInfoOfAPP") alloc] init];
    [app setM_uiAppMsgInnerType:kDDMCAppInnerFile];
    [app setM_nsAppFileName:fileName];
    [app setM_nsAppFileExt:@"m4a"];
    [app setM_uiAppDataSize:fsize];
    [app setM_nsTitle:fileName];
    [app setM_bAppAttachExistInSvr:YES];
    [wrap setM_extendInfoWithMsgType:app];   // CMessageWrap.h:637（m_oAppDataItem 在 8.0.79 已不存在）

    // 消息正文 appmsg XML（type=6 文件）。不写它，微信重启后从 DB 重建消息时正文为空
    // → 判不出文件名/扩展名（退回 .dat）、判不出本地已有附件（0B +「接收文件」）。
    [wrap setM_nsContent:[NSString stringWithFormat:
        @"<msg><appmsg appid=\"\" sdkver=\"0\"><title>%@</title><des></des><type>6</type>"
         "<appattach><totallen>%llu</totallen><attachid></attachid><fileext>%@</fileext>"
         "<filename>%@</filename></appattach></appmsg></msg>", fileName, fsize, @"m4a", fileName]];
    dd_retain_wrap(wrap);

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddAppMsg:usr MsgWrap:wrap DataPath:m4aPath Scene:0];
    dd_log(@"[file.send] AddAppMsg → localID=%u", wrap.m_uiMesLocalID);
    // 只调 AddAppMsg 不上传 → 消息停在 Sending、服务器无记录 → 微信当「未下载」，重启后显示 0B
    if ([mgr respondsToSelector:@selector(StartUploadAppMsg:MsgWrap:Scene:)]) {
        [mgr StartUploadAppMsg:usr MsgWrap:wrap Scene:0];
        dd_log(@"[file.send] 已触发上传");
    }
    return YES;
}
// 语音消息 → 文件消息
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    NSString *fn  = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    dd_log(@"[voice→file] ==== 开始 ==== localID=%u chat=%@", msg.m_uiMesLocalID, usr ?: @"(nil)");
    dispatch_async(dd_convert_queue, ^{
        NSString *p = dd_voice_path_of_msg(msg);
        if (!dd_file_exists(p)) { dd_log(@"[voice→file] 取不到语音文件，放弃"); return; }
        NSData *silk = [NSData dataWithContentsOfFile:p];
        if (silk.length < 12) { dd_log(@"[voice→file] 语音数据过小，放弃"); return; }
        NSString *m4a = dd_decode_silk_to_audio(silk);
        if (!m4a.length) { dd_log(@"[voice→file] 解码/封装失败，放弃"); return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sent = dd_send_file_to_chat(usr, m4a, fn);
            dd_log(@"[voice→file] ==== 结束 ==== 发送结果=%d", sent);
        });
    });
}

#pragma mark - 菜单注入

// 按 userInfo 标记去重（MMMenuItem 无 title/action getter，无法按 action 比对）。
// 基类与四个子类各 hook 一次 operationMenuItems，两层叠加时同一 action 会注入两次。
static NSString *dd_menu_token(SEL action) {
    return [@"ddmc:" stringByAppendingString:NSStringFromSelector(action)];
}
static NSArray *dd_inject_items(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    if (!enabled) return original;
    NSString *token = dd_menu_token(action);
    for (id it in original) {
        if (![it respondsToSelector:@selector(userInfo)]) continue;
        id ui = [(id)it userInfo];
        if ([ui isKindOfClass:[NSString class]] && [(NSString *)ui isEqualToString:token]) return original;
    }
    Class cls = objc_getClass("MMMenuItem");
    // 内置 svg 资源名 icon_filled_record_voice（微信 svg 注册名不带后缀），由微信内部渲染成图标
    MMMenuItem *item = [[cls alloc] initWithTitle:title
                                          svgName:@"icon_filled_record_voice"
                                           target:cell
                                           action:action];
    if (!item) { dd_log(@"[menu] MMMenuItem 构造失败"); return original; }
    [item setUserInfo:token];
    dd_log(@"[menu] 已追加「%@」cell=%@ → 菜单数=%lu",
          title, NSStringFromClass([cell class]), (unsigned long)original.count + 1);
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
    dd_log(@"[action] 点击「转语音」(视频消息)");
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(@"视频", msg, ^NSString *{ return dd_video_path_of_cell(self); },
                          ^{ dd_trigger_video_download(msg); });
}
%end

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    // 建菜单阶段只读开关，绝不解析路径（路径解析在点击后做，见 WCR 0x8dd96c）
    return dd_inject_items(self, %orig, [DDMediaConvertConfig shared].fileToVoiceEnabled,
                           @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) && [DDMediaConvertConfig shared].fileToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(文件消息)");
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
    dd_log(@"[action] 点击「转文件」(语音消息)");
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
    self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                              initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) [self ensureTableViewMgr];
    return self;
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
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
- (void)buildTable {
    [self.tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    DDMediaConvertConfig *cfg = [DDMediaConvertConfig shared];

    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"转换开关"];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleVideoToVoice:) target:self title:@"视频转语音" on:cfg.videoToVoiceEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleFileToVoice:)  target:self title:@"文件转语音" on:cfg.fileToVoiceEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(toggleVoiceToFile:)  target:self title:@"语音转文件" on:cfg.voiceToFileEnabled]];
    [self.tableViewManager addSection:sec];

    WCTableViewSectionManager *logSec = [secMgr sectionWithHeader:@"调试日志"];
    [logSec addCell:[cellMgr switchCellForSel:@selector(toggleLog:) target:self title:@"记录调试日志" on:cfg.logEnabled]];
    DDLogStore *store = [DDLogStore shared];
    NSString *cnt = [NSString stringWithFormat:@"%lu 条 / %.0f KB",
                     (unsigned long)[store lineCount], [store fileSize] / 1024.0];
    [logSec addCell:[cellMgr normalCellForSel:@selector(ddExportLog:) target:self title:@"导出日志" rightValue:cnt]];
    [logSec addCell:[cellMgr normalCellForSel:@selector(ddClearLog:)  target:self title:@"清空日志" rightValue:@""]];
    [self.tableViewManager addSection:logSec];
    [self.tableViewManager reloadTableView];
}
- (void)toggleVideoToVoice:(UISwitch *)s { [DDMediaConvertConfig shared].videoToVoiceEnabled = s.on; }
- (void)toggleFileToVoice:(UISwitch *)s  { [DDMediaConvertConfig shared].fileToVoiceEnabled = s.on; }
- (void)toggleVoiceToFile:(UISwitch *)s  { [DDMediaConvertConfig shared].voiceToFileEnabled = s.on; }
- (void)toggleLog:(UISwitch *)s {
    [DDMediaConvertConfig shared].logEnabled = s.on;
    [DDLogStore shared].enabled = s.on;
}
- (void)ddExportLog:(id)sender {
    NSString *path = dd_log_export_path();
    NSUInteger n = [[DDLogStore shared] lineCount];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"日志已导出"
                         message:[NSString stringWithFormat:@"%@\n共 %lu 条\n\n可用「分享/存储」保存到文件 App。",
                                  path.lastPathComponent, (unsigned long)n]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"分享/存储" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        UIActivityViewController *av = [[UIActivityViewController alloc]
                                        initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [self presentViewController:av animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制全文" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string =
            [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)ddClearLog:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空日志"
                                                                  message:@"将清空内存缓冲与日志文件，确定？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[DDLogStore shared] clearAll];
        [self buildTable];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
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

// 崩溃取证：微信闪退是 ObjC 未捕获异常 → SIGABRT（崩溃报告实证：exception type=objc-exception /
// signal=SIGABRT）。安装全局异常处理，把异常名 + reason + 调用栈同步写进调试日志并 flush，
// 这样每次闪退都能在自己的日志里拿到精确证据，不必去系统「分析数据」翻 .ips。
static NSUncaughtExceptionHandler *dd_prev_exc_handler = NULL;
static void dd_exception_handler(NSException *exc) {
    NSString *reason = exc.reason ?: @"(无 reason)";
    dd_log(@"[CRASH] ===== 未捕获异常 =====");
    dd_log(@"[CRASH] name=%@ reason=%@", exc.name ?: @"(nil)", reason);
    NSArray<NSString *> *syms = exc.callStackSymbols ?: [NSThread callStackSymbols];
    NSUInteger n = syms.count > 40 ? 40 : syms.count;
    for (NSUInteger i = 0; i < n; i++) dd_log(@"[CRASH] #%lu %@", (unsigned long)i, syms[i]);
    [[DDLogStore shared] flushSync];
    if (dd_prev_exc_handler) dd_prev_exc_handler(exc);
}

// 上面一层只覆盖 ObjC 未捕获异常（→ SIGABRT）。日志实证：文件转语音打出「发送结果=1」之后
// 仍然闪退，且日志里没有 [CRASH] 段（导出头部「日志条数: 0」= 导出发生在重启之后），
// 说明崩溃走的是内存破坏路径 SIGSEGV/SIGBUS，压根不经过 NSUncaughtExceptionHandler。
// 故再挂一层 BSD 信号处理器：只写 async-signal-safe 的 open/write，把信号与回溯栈塞进日志文件。
static void dd_signal_handler(int sig) {
    int fd = open(dd_log_c_path, O_WRONLY | O_APPEND | O_CREAT, 0644);
    if (fd < 0) return;
    const char *name = (sig == SIGSEGV) ? "SIGSEGV"
                     : (sig == SIGBUS)  ? "SIGBUS"
                     : (sig == SIGILL)  ? "SIGILL" : "SIGOTHER";
    char b[128];
    int len = snprintf(b, sizeof(b), "\n[CRASH] ===== 信号崩溃 ===== signal=%d %s\n[CRASH] backtrace:\n", sig, name);
    if (len > 0) write(fd, b, (size_t)len);
    void *bt[40];
    int n = backtrace(bt, 40);
    backtrace_symbols_fd(bt, n, fd);
    close(fd);
    signal(sig, SIG_DFL);
    raise(sig);
}

%ctor {
    @autoreleasepool {
        dd_convert_queue = dispatch_queue_create("com.ddmedia.convert", DISPATCH_QUEUE_SERIAL);
        [DDLogStore shared].enabled = [DDMediaConvertConfig shared].logEnabled;
        dd_log(@"[boot] 插件已加载");
        dd_prev_exc_handler = NSGetUncaughtExceptionHandler();
        NSSetUncaughtExceptionHandler(&dd_exception_handler);
        signal(SIGSEGV, &dd_signal_handler);
        signal(SIGBUS,  &dd_signal_handler);
        signal(SIGILL,  &dd_signal_handler);
        [[%c(WCPluginsMgr) sharedInstance] registerControllerWithTitle:@"DD语音助手"
                                                              version:@"1.0.27"
                                                           controller:@"DDMediaConvertSettingsViewController"];
    }
}

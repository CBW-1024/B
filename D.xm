//  DD语音助手 —— 单文件越狱插件（Theos/Logos）
//
//  功能：
//    · 语音转发：收藏语音 / 语音消息一键转发，长按菜单加「转发」
//    · 自定义语音秒数：改写上行语音 PB 时长（1~60s）
//    · 语音转换：视频 / 文件消息 →「转语音」(SILK)，语音消息 →「转文件」(m4a)
//      （未下载的媒体先触发微信自动下载，完成后再转换）
//
//  方法签名锚定微信 8.0.79 头文件 dump。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include <string.h>

#pragma mark - 微信类前向声明

@interface DDDownloadWaiter : NSObject
+ (void)waitMsg:(id)msg task:(id)task pathBlock:(NSString *(^)(void))pathBlock
          token:(NSString *)token then:(void (^)(NSString *path))then;  // 登记等下载完成
+ (void)poke;                         // 下载结束回调：复查等待项，就绪则继续
+ (void)videoDone:(id)msgWrap;        // 视频下载成功回调（按消息命中）
@end

@interface DDProgressHub : NSObject
+ (NSString *)begin;                  // 登记新任务，返回 token（标题显示并发数）
+ (void)complete:(NSString *)token;   // 结束任务（全部结束则收起卡片）
+ (void)waitSendSuccess:(unsigned int)localID token:(NSString *)token;  // 登记“等发送成功”
+ (void)sendSuccess:(unsigned int)localID;   // 微信回调发送成功，按 localID 收起对应任务
@end

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
+ (id)defaultSection;
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightView:(id)a4;
@end

@interface MMMenuItem : NSObject
- (id)initWithTitle:(id)a0 svgName:(id)a1 target:(id)a2 action:(SEL)a3;
- (id)userInfo;
- (void)setUserInfo:(id)a0;
@end

@interface FavoritesItemDataField : NSObject
@property(nonatomic) unsigned int duration;
- (id)GetDataPath;
@end

@interface CMessageWrap : NSObject
+ (BOOL)isSenderFromMsgWrap:(id)arg1;
+ (id)GetPathOfAppData:(id)msgWrap;
- (id)initWithMsgType:(long long)arg1;
- (BOOL)IsVoiceMsg;
- (BOOL)IsVideoMsg;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiDownloadStatus;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) id m_extendInfoWithMsgType;
- (void)setM_extendInfoWithMsgType:(id)arg1;
@property(retain, nonatomic) NSString *m_nsContent;
- (void)setM_nsContent:(NSString *)arg1;
- (void)setM_uiDownloadStatus:(unsigned int)arg1;
- (void)setM_bForward:(BOOL)arg1;
- (id)getVoicePath;
- (void)setM_nsVoicePath:(NSString *)arg1;
// 视频下载落盘路径候选（对齐 DD朋友圈转发的多候选取可用）
- (id)GetCdnDownloadPathOfVideo;
- (id)getFormatVideoPath;
- (id)getTempVideoPath;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(retain, nonatomic) NSData *m_dtVoice;
- (void)setM_dtVoice:(NSData *)arg1;
@property(nonatomic, weak) CMessageWrap *m_refMessageWrap;
- (void)setM_refMessageWrap:(CMessageWrap *)arg1;
- (void)setM_uiVoiceEndFlag:(unsigned int)arg1;
- (void)setM_uiVoiceFormat:(unsigned int)arg1;
- (void)setM_uiVoiceTime:(unsigned int)arg1;
@end

@interface CExtendInfoOfAPP : NSObject
@property(nonatomic) unsigned int m_uiAppMsgInnerType;
@property(retain, nonatomic) NSString *m_nsAppFileName;
@property(retain, nonatomic) NSString *m_nsAppFileExt;
@property(nonatomic) unsigned long long m_uiAppDataSize;
- (id)init;
- (void)setM_nsTitle:(id)arg1;
- (void)setM_bAppAttachExistInSvr:(BOOL)arg1;
@end

@interface UploadVoiceWrap : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@end

@interface CUtility : NSObject
+ (id)GetDocPath;
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface FavoritesMgr : NSObject
- (void)startDownloadFavoritesItem:(id)arg1 IsPriority:(_Bool)arg2;
@end

@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;
- (_Bool)addMessageToDB:(id)arg1;
- (id)getAudioFileName:(id)arg1 LocalID:(unsigned int)arg2;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface ForwardMsgUtil : NSObject
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1;
@end

@interface FavoritesItem : NSObject
@property(nonatomic) int type;
@property(retain, nonatomic) NSArray *dataList;
- (_Bool)needDownLoad;
- (_Bool)canBeForward;
- (id)canBeForwardWithMsg;
- (id)canBeForwardWithMsg:(_Bool)arg1;
@end

@interface FavForwardLogicController : NSObject
- (void)addMsgFromItem:(id)arg1;
@end

@interface ForwardMessageLogicController : NSObject
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3;
@end

@interface BaseMsgContentViewController : NSObject
- (void)OnMsgSendSuccess:(id)msgWrap;
@end

@interface MJSilkCodec : NSObject
+ (id)decodeToPCMFromSilkData:(id)a0;
+ (id)encodeToSilkFromPCMData:(id)a0;
@end

// 微信原生文件下载任务（AppFileMessageCellView 的「下载」同款）。需在主线程发起，filePath 为落盘路径。
@interface MsgFileTransferTask : NSObject
+ (id)taskFromMessageWrap:(id)msgWrap;
- (id)filePath;
- (BOOL)isCompleted;
- (BOOL)isFail;
- (int)progress;
- (void)startTransfer;
@end

@interface CMessageMgr : NSObject
- (void)StartDownloadVideo:(id)a0 MsgWrap:(id)a1 Priority:(BOOL)a2 Silent:(BOOL)a3;
- (void)AddAppMsg:(id)a0 MsgWrap:(id)a1 DataPath:(id)a2 Scene:(unsigned int)a3;
- (void)StartUploadAppMsg:(id)a0 MsgWrap:(id)a1 Scene:(unsigned int)a2;
- (void)AddLocalMsg:(id)a0 MsgWrap:(id)a1;
- (BOOL)SaveMesVoice:(id)a0 MsgWrap:(id)a1;
- (void)updateMsgSourceOnSendSuccess:(id)msgWrap secMsgSource:(id)src svrTime:(unsigned int)t;
@end

// CDN 下载结束回调（文件/app attach 下载完成）。
@interface CdnComMgr : NSObject
- (void)OnDownloadEnd:(id)info;
@end

// 聊天消息媒体下载器（原生视频下载入口，与其完成回调同源）。
@interface MMImgDownloader_Message : NSObject
- (void)startDownloadVideo:(id)msgWrap bHD:(BOOL)hd bSave:(BOOL)save bSilent:(BOOL)silent;
- (void)OnMsgDownloadVideoSuccess:(id)msgWrap;
@end


@interface BaseMessageViewModel : NSObject
- (id)messageWrap;
@end
@interface VideoMessageViewModel : BaseMessageViewModel
- (id)videoPath;
@end
@interface BaseChatCellView : NSObject
@property (readonly, nonatomic) id viewModel;
@end
@interface BaseMessageCellView : BaseChatCellView
- (BOOL)canShowForwardMenuItem;
- (id)forwardMenuItem;
- (void)onForward:(id)arg1;
- (void)doForward;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end
@interface VideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
@end
@interface AppFileMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
@end
@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
@end

#pragma mark - 配置：语音转发 / 自定义秒数（DDVoiceConfig）

#define kDDVoiceEnableFav @"kDDVoiceEnableFav"
#define kDDVoiceEnableMsg @"kDDVoiceEnableMsg"
#define kDDVoiceSecondsEnabled @"kDDVoiceSecondsEnabled"
#define kDDVoiceSeconds @"kDDVoiceSeconds"

#define kDDVoiceMaxSeconds 60
#define kDDVoiceFavItemType 3
#define kDDVoiceMsgType 34
#define kDDVoiceFormat 4
#define kDDVoiceEndFlag 1
#define kDDMsgStatusSending 1
#define kDDDownloadWaitStep 0.25
#define kDDVoiceLocalIDBase 10000
#define kDDVoiceLocalIDRange 0x15f90
static const void *kDDVoiceFavSourceKey = &kDDVoiceFavSourceKey;

@interface DDVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL favEnabled;
@property (assign, nonatomic) BOOL msgEnabled;
@property (assign, nonatomic) BOOL voiceSecondsEnabled;
@property (copy, nonatomic) NSString *voiceSeconds;
@end

@implementation DDVoiceConfig
+ (instancetype)sharedConfig {
    static DDVoiceConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDVoiceConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDVoiceConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDVoiceEnableFav: @NO,
        kDDVoiceEnableMsg: @NO,
        kDDVoiceSecondsEnabled: @NO,
        kDDVoiceSeconds: @"",
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _favEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceEnableFav];
        _msgEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceEnableMsg];
        _voiceSecondsEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceSecondsEnabled];
        _voiceSeconds = [[NSUserDefaults.standardUserDefaults stringForKey:kDDVoiceSeconds] copy] ?: @"";
    }
    return self;
}
- (void)setFavEnabled:(BOOL)v { _favEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableFav]; }
- (void)setMsgEnabled:(BOOL)v { _msgEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableMsg]; }
- (void)setVoiceSecondsEnabled:(BOOL)v { _voiceSecondsEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceSecondsEnabled]; }
- (void)setVoiceSeconds:(NSString *)v { _voiceSeconds = [v copy]; [NSUserDefaults.standardUserDefaults setObject:_voiceSeconds forKey:kDDVoiceSeconds]; }
@end

static BOOL dd_voice_fav_enabled(void) { return [DDVoiceConfig sharedConfig].favEnabled; }
static BOOL dd_voice_msg_enabled(void) { return [DDVoiceConfig sharedConfig].msgEnabled; }
static BOOL dd_voice_forward_enabled(void) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    return c.favEnabled || c.msgEnabled;
}

#pragma mark - 配置：语音转换开关（DDVoiceConvertConfig）

#define kDDVCVideoToVoice @"kDDVCVideoToVoice"
#define kDDVCFileToVoice  @"kDDVCFileToVoice"
#define kDDVCVoiceToFile  @"kDDVCVoiceToFile"

#define kDDVCAppMsgType   49
#define kDDVCAppInnerFile 6
#define kDDVCVoiceSampleRate 16000

@interface DDVoiceConvertConfig : NSObject
+ (instancetype)shared;
@property (assign, nonatomic) BOOL videoToVoiceEnabled;
@property (assign, nonatomic) BOOL fileToVoiceEnabled;
@property (assign, nonatomic) BOOL voiceToFileEnabled;
@end

@implementation DDVoiceConvertConfig
+ (instancetype)shared {
    static DDVoiceConvertConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDVoiceConvertConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDVoiceConvertConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDVCVideoToVoice: @NO, kDDVCFileToVoice: @NO, kDDVCVoiceToFile: @NO,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _videoToVoiceEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVCVideoToVoice];
        _fileToVoiceEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDVCFileToVoice];
        _voiceToFileEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDVCVoiceToFile];
    }
    return self;
}
- (void)setVideoToVoiceEnabled:(BOOL)v { _videoToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVCVideoToVoice]; }
- (void)setFileToVoiceEnabled:(BOOL)v { _fileToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVCFileToVoice]; }
- (void)setVoiceToFileEnabled:(BOOL)v { _voiceToFileEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVCVoiceToFile]; }
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
// 判定对象是否为 CMessageWrap。
static BOOL dd_is_msg_wrap(id obj) {
    return obj && [obj isKindOfClass:objc_getClass("CMessageWrap")];
}
// 取 cell 对应的消息对象。
static CMessageWrap *dd_msg_of_cell(id cell) {
    return [[cell viewModel] messageWrap];
}
// 语音消息归属：群聊/发送方返回 toUsr，否则返回 fromUsr。
static NSString *dd_chat_usr_of_msg(CMessageWrap *msg) {
    return [objc_getClass("CMessageWrap") isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
}

#pragma mark - 语音扩展信息（dd_voice_extend_info）

static id dd_voice_extend_info(id wrap, BOOL create) {
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    if (!create) return nil;
    id nv = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
static NSData *dd_voice_data(id wrap) { return [dd_voice_extend_info(wrap, NO) m_dtVoice]; }
static unsigned int dd_voice_duration(id wrap) { return [dd_voice_extend_info(wrap, NO) m_uiVoiceTime]; }
static BOOL dd_configure_voice_meta(id wrap, unsigned int duration) {
    id ext = dd_voice_extend_info(wrap, YES);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    return YES;
}
static BOOL dd_inject_voice_data(id wrap, NSData *voiceData) {
    [dd_voice_extend_info(wrap, YES) setM_dtVoice:voiceData];
    return YES;
}

#pragma mark - 自定义语音秒数

// 秒 → 毫秒（m_uiVoiceTime 单位为毫秒）。关闭/空/0 → 原样返回；
// 超出 1~60 钳到边界；声明时长超过真实音频时长则回退真实值。
static unsigned int dd_voice_time_ms(unsigned int realMs) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    if (!c.voiceSecondsEnabled) return realMs;
    NSString *s = c.voiceSeconds;
    if ([s length] == 0) return realMs;
    NSInteger sec = [s integerValue];
    if (sec <= 0) return realMs;
    if (sec < 1) sec = 1;
    if (sec > kDDVoiceMaxSeconds) sec = kDDVoiceMaxSeconds;
    unsigned int target = (unsigned int)sec * 1000;
    if (realMs > 0 && target > realMs) return realMs;
    return target;
}

#pragma mark - 语音判定 / 收藏判定

static BOOL dd_is_voice_msg(id msg) { return [(CMessageWrap *)msg IsVoiceMsg]; }
static BOOL dd_is_fav_voice_item(id obj) { return ((FavoritesItem *)obj).type == kDDVoiceFavItemType; }

#pragma mark - 收藏下载工具

static void dd_start_download_fav_item(id item) {
    id mgr = [objc_getClass("MMContext") currentContext];
    mgr = [mgr getService:objc_getClass("FavoritesMgr")];
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}
static void dd_wait_download_finish(id item) {
    while (((FavoritesItem *)item).needDownLoad) {
        [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
    }
}
static void dd_download_fav_item_then(id item, void (^done)(void)) {
    dd_start_download_fav_item(item);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        dd_wait_download_finish(item);
        dispatch_async(dispatch_get_main_queue(), done);
    });
}

#pragma mark - 音频路径（转发取本地语音用）

// 群聊/发送方返回 toUsr，否则 fromUsr（与 dd_chat_usr_of_msg 同向）。
static NSString *dd_owner_user_for_voice(id msg) {
    NSString *to = (NSString *)((CMessageWrap *)msg).m_nsToUsr;
    if ([to containsString:@"@chatroom"]) return to;
    if ([objc_getClass("CMessageWrap") isSenderFromMsgWrap:msg]) return to;
    return (NSString *)((CMessageWrap *)msg).m_nsFromUsr;
}
// 优先 CUtility 路径，其次 AudioSender 路径，兜底导出 m_dtVoice 到临时文件。
static NSString *dd_audio_path_for_msg(id msg) {
    unsigned int localID = ((CMessageWrap *)msg).m_uiMesLocalID;
    NSString *usr = dd_owner_user_for_voice(msg);
    Class cu = objc_getClass("CUtility");
    NSString *cuPath = (NSString *)[cu GetPathOfMesAudio:usr LocalID:localID DocPath:[cu GetDocPath]];
    if (dd_file_exists(cuPath)) return cuPath;
    NSString *p = (NSString *)[dd_mm_service(@"AudioSender") getAudioFileName:usr LocalID:localID];
    if (dd_file_exists(p)) return p;
    NSData *data = dd_voice_data(msg);
    if ([data length] == 0) return nil;
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
    [data writeToFile:tmp atomically:YES];
    return tmp;
}

#pragma mark - 语音发送

// 下列函数在文件后部（语音转换区）定义，供本区 dd_send_voice 调用，先前向声明。
static BOOL dd_silk_frames_valid(NSData *d);
static void dd_configure_voice_msg(id wrap, NSData *voiceData, unsigned int duration);
static NSString *dd_install_audio_file(CMessageWrap *wrap, NSString *src);
static void dd_ensure_fav_voice_data(id msg);

// 给构造出的消息分配非零 localID，否则拿不到音频路径（收藏外壳用）。
static unsigned int dd_new_voice_local_id(void) {
    return kDDVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDVoiceLocalIDRange);
}
// 发送语音到会话：AddLocalMsg 分配 localID → 写 SILK 到规范路径 → SaveMesVoice → ResendVoiceMsg。
// 必须显式 setM_nsVoicePath，否则 ResendVoiceMsg 回退按 localID 重算路径易读坏文件。
// SaveMesVoice 首参传 nil（实际两参，传 NSData 会被当路径）。
// 数据合法性由来源侧保证：媒体转语音在各自上游已校验 SILK（L770/L675）；转发（原生语音、收藏）
// 数据为微信产出，直接信任。故此处不重复帧链校验——收藏语音 m_dtVoice 走临时文件兜底，
// 不含本地 .aud 的完整帧链，会被帧链校验误杀。
// 返回已发出的 wrap（用于等待发送结果），失败返回 nil。
static CMessageWrap *dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    NSData *data = [NSData dataWithContentsOfFile:audPath];
    if (data.length == 0) return nil;
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if (!sender) return nil;
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDVoiceMsgType];
    [wrap setM_uiMessageType:kDDVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    [wrap setM_uiCreateTime:[(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime]];
    [wrap setM_uiStatus:kDDMsgStatusSending];
    [wrap setM_uiDownloadStatus:9];
    [wrap setM_bForward:1];
    dd_configure_voice_msg(wrap, data, duration);

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddLocalMsg:usr MsgWrap:wrap];
    NSString *voicePath = dd_install_audio_file(wrap, audPath);
    if (voicePath.length) [wrap setM_nsVoicePath:voicePath];
    [mgr SaveMesVoice:nil MsgWrap:wrap];
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return wrap;
}
// 收藏外壳：数据未就绪则下载后注入 m_dtVoice 再发送。
static void dd_ensure_fav_voice_data(id msg) {
    if ([dd_voice_data(msg) length] > 0) return;
    id field = [[(FavoritesItem *)objc_getAssociatedObject(msg, kDDVoiceFavSourceKey) dataList] firstObject];
    NSData *d = [NSData dataWithContentsOfFile:(NSString *)[field GetDataPath]
                                       options:NSDataReadingMappedIfSafe error:nil];
    dd_inject_voice_data(msg, d);
}
static BOOL dd_take_over_voice_msg(id msg, id contact) {
    if (!dd_is_voice_msg(msg)) return NO;
    NSString *usr = (NSString *)[(CBaseContact *)contact m_nsUsrName];
    unsigned int duration = dd_voice_time_ms(dd_voice_duration(msg));
    NSString *audPath = dd_audio_path_for_msg(msg);
    if ([audPath length] == 0) {
        id favItem = objc_getAssociatedObject(msg, kDDVoiceFavSourceKey);
        if (favItem) {
            dd_download_fav_item_then(favItem, ^{
                dd_ensure_fav_voice_data(msg);
                dd_send_voice(usr, dd_audio_path_for_msg(msg), duration);
            });
            return YES;
        }
        return dd_send_voice(usr, audPath, duration) != nil;
    }
    return dd_send_voice(usr, audPath, duration) != nil;
}
// 批量转发逐条接管，返回需走原实现的消息。
static NSArray *dd_take_over_voice_list(NSArray *src, id contact) {
    NSMutableArray *rest = [NSMutableArray array];
    for (id m in src) {
        if (dd_is_voice_msg(m)) dd_take_over_voice_msg(m, contact);
        else [rest addObject:m];
    }
    return rest;
}

#pragma mark - 收藏语音消息构造（外壳，不在此发送）

static id dd_msg_wrap_from_fav_data(id favData, id favItem) {
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDVoiceMsgType];
    NSString *me = dd_current_usr_name();
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    [wrap setM_uiMessageType:kDDVoiceMsgType];
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];
    [wrap setM_uiMesLocalID:dd_new_voice_local_id()];
    dd_configure_voice_meta(wrap, dd_voice_time_ms(field.duration));
    if (favItem) objc_setAssociatedObject(wrap, kDDVoiceFavSourceKey, favItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (dd_file_exists((NSString *)[field GetDataPath])) {
        NSData *data = [NSData dataWithContentsOfFile:(NSString *)[field GetDataPath]
                                              options:NSDataReadingMappedIfSafe error:nil];
        if ([data length] > 0) dd_inject_voice_data(wrap, data);
    }
    return wrap;
}
static void dd_append_voice_msg(id favItem, id controller) {
    NSArray *list = ((FavoritesItem *)favItem).dataList;
    if ([list count] == 0) return;
    id wrap = dd_msg_wrap_from_fav_data([list firstObject], favItem);
    Class ctrlCls = objc_getClass("FavForwardLogicController");
    if (ctrlCls && ![[controller class] isSubclassOfClass:ctrlCls]) return;
    Ivar iv = class_getInstanceVariable([controller class], "m_messageWrapList");
    if (!iv) return;
    id store = object_getIvar(controller, iv);
    if (![store isKindOfClass:[NSMutableArray class]]) return;
    [(NSMutableArray *)store addObject:wrap];
}

#pragma mark - 语音转换：路径解析

// 含音轨 / 可复用容器白名单。视频路径解析与文件菜单准入共用。
// 音频视频容器可由 AVAssetReader 抽音轨再编 SILK；图片/文档无音轨，一律排除；
// aud/silk 是微信语音终态容器，直接复用，不二次编码。
static NSSet *dd_media_ext_set(void) {
    static NSSet *s; static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [NSSet setWithObjects:
             @"mp3", @"wav", @"m4a", @"aac", @"flac", @"ogg", @"oga", @"opus",
             @"caf", @"aiff", @"aif", @"m4r", @"amr", @"wma", @"ape", @"au",
             @"mp4", @"mov", @"m4v", @"avi", @"mkv", @"flv", @"webm", @"3gp", @"wmv", @"mpg", @"mpeg",
             @"aud", @"silk", nil];
    });
    return s;
}
// 严格可用性：必须是常规文件且非空（对齐 DD朋友圈转发的 DDFFileUsable，避免把目录/占位当成品）。
static BOOL dd_file_usable(NSString *path) {
    if (path.length == 0) return NO;
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!a) return NO;
    if (![a[NSFileType] isEqual:NSFileTypeRegular]) return NO;
    return [a fileSize] > 0;
}
// 视频消息本地路径（基于 msg）：多候选依次尝试（对齐 DD朋友圈转发），
// 优先取可用且扩展名命中白名单者，否则退回第一个可用文件。
static NSString *dd_video_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    if ([msg respondsToSelector:@selector(IsVideoMsg)] && ![msg IsVideoMsg]) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    NSString *(^add)(id) = ^NSString *(id raw) {
        if ([raw isKindOfClass:[NSString class]] && ((NSString *)raw).length) [cands addObject:raw];
        return nil;
    };
    if ([msg respondsToSelector:@selector(GetCdnDownloadPathOfVideo)]) add([msg GetCdnDownloadPathOfVideo]);
    if ([msg respondsToSelector:@selector(getFormatVideoPath)])      add([msg getFormatVideoPath]);
    if ([msg respondsToSelector:@selector(getTempVideoPath)])        add([msg getTempVideoPath]);
    NSString *fallback = nil;
    for (NSString *p in cands) {
        if (!dd_file_usable(p)) continue;
        if (!fallback) fallback = p;
        if ([dd_media_ext_set() containsObject:p.pathExtension.lowercaseString]) return p;
    }
    return fallback;
}
// 视频消息本地路径（基于 cell）：viewModel.videoPath 优先，未就绪则回落到 msg 多候选。
static NSString *dd_video_path_of_cell(id cell) {
    id msg = dd_msg_of_cell(cell);
    if (msg && [msg respondsToSelector:@selector(IsVideoMsg)] && ![msg IsVideoMsg]) return nil;
    NSString *vp = [(VideoMessageViewModel *)[cell viewModel] videoPath];
    if ([vp isKindOfClass:[NSString class]] && vp.length && dd_file_usable(vp)
        && [dd_media_ext_set() containsObject:vp.pathExtension.lowercaseString]) return vp;
    return dd_video_path_of_msg(msg);
}
// 文件消息本地路径：传消息 wrap 本身给 +[CMessageWrap GetPathOfAppData:(id)]，由微信按该消息算出真实落盘路径。
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
    NSString *p = (NSString *)[objc_getClass("CMessageWrap") GetPathOfAppData:msg];
    if ([p isKindOfClass:[NSString class]] && p.length) return p;
    return nil;
}
// 语音消息本地路径：getVoicePath。
static NSString *dd_voice_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *p = (NSString *)[msg getVoicePath];
    if (![p isKindOfClass:[NSString class]] || p.length == 0) return nil;
    return p;
}

#pragma mark - 语音转换：自动下载

// 原生：MMImgDownloader_Message 是聊天消息媒体下载器，触发与完成回调同源。
static void dd_trigger_video_download(CMessageWrap *msg) {
    if (!msg) return;
    id dl = dd_mm_service(@"MMImgDownloader_Message");
    [dl startDownloadVideo:msg bHD:YES bSave:NO bSilent:YES];
}
// 主线程同步执行（微信下载/状态查询 API 需主线程；convert 队列调用安全，不会死锁）。
static void dd_run_on_main_sync(void(^block)(void)) {
    if ([NSThread isMainThread]) { block(); return; }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{ block(); dispatch_semaphore_signal(sem); });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}
// 触发文件下载：用微信原生文件传输任务发起（AppFileMessageCellView 的「下载」同款）。
// 返回 transfer task（用于读取真实下载进度）；失败返回 nil。
static MsgFileTransferTask *dd_trigger_file_download(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
    __block MsgFileTransferTask *task = nil;
    dd_run_on_main_sync(^{
        task = [objc_getClass("MsgFileTransferTask") taskFromMessageWrap:msg];
        if (task) [task startTransfer];
    });
    return task;
}

#pragma mark - 进度提示（单卡聚合多任务）

static UIWindow *dd_progress_key_window(void) {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if ([s isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *w in ((UIWindowScene *)s).windows) {
                if (w.isKeyWindow) return w;
            }
        }
    }
    return nil;
}

// 全局唯一浮卡：标题统一「正在转换中 (N)」，进度条为来回滚动的 indeterminate 样式（无百分比）。
// 任意线程调用都安全：内部统一切主线程渲染。卡片视觉复刻朋友圈转发的白底圆角 + 绿条。
@implementation DDProgressHub

static const NSInteger kDDHubTag = 0x44444801;

+ (NSMutableDictionary<NSString *, NSNumber *> *)dd_tasks {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}
+ (NSLock *)dd_lock {
    static NSLock *l;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ l = [NSLock new]; });
    return l;
}
// localID → token：已发起发送、等待微信回调“发送成功”的任务。
+ (NSMutableDictionary<NSNumber *, NSString *> *)dd_pending {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}
+ (NSString *)begin {
    NSString *token = [NSUUID UUID].UUIDString;
    [[self dd_lock] lock]; [[self dd_tasks] setObject:@1 forKey:token]; [[self dd_lock] unlock];
    dispatch_async(dispatch_get_main_queue(), ^{ [self dd_render]; });
    return token;
}
+ (void)complete:(NSString *)token {
    if (!token) return;
    [[self dd_lock] lock]; [[self dd_tasks] removeObjectForKey:token]; [[self dd_lock] unlock];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self dd_tasks].count == 0) [self dd_dismiss]; else [self dd_render];
    });
}
+ (void)waitSendSuccess:(unsigned int)localID token:(NSString *)token {
    if (!localID || !token) { if (token) [self complete:token]; return; }
    [[self dd_lock] lock]; [self dd_pending][@(localID)] = token; [[self dd_lock] unlock];
}
+ (void)sendSuccess:(unsigned int)localID {
    if (!localID) return;
    [[self dd_lock] lock];
    NSString *token = [self dd_pending][@(localID)];
    if (token) [[self dd_pending] removeObjectForKey:@(localID)];
    [[self dd_lock] unlock];
    if (token) [self complete:token];
}
+ (UIView *)dd_make_card:(UIWindow *)win {
    CGFloat cardW = win.bounds.size.width - 32.0;
    CGFloat cardH = 56.0;
    CGFloat topInset = 8.0;
    if ([win respondsToSelector:@selector(safeAreaInsets)]) {
        CGFloat sa = win.safeAreaInsets.top;
        if (sa > 0) topInset = sa + 8.0;
    }
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16.0, topInset, cardW, cardH)];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return [UIColor colorWithWhite:tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 1.0 alpha:0.95];
    }];
    card.layer.cornerRadius = 10.0;
    card.clipsToBounds = YES;
    card.tag = kDDHubTag;
    card.alpha = 0.0;
    card.userInteractionEnabled = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowRadius = 6;

    CGFloat padX = 14.0;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(padX, 8, cardW - 2 * padX, 18)];
    title.textColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return [UIColor colorWithWhite:tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.95 : 0.0 alpha:0.9];
    }];
    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

    // 来回滚动的 indeterminate 进度条（无百分比）。barY 与 DD朋友圈转发对齐。
    CGFloat barY = 30.0, barH = 4.0;
    CGFloat barW = cardW - 2 * padX;
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(padX, barY, barW, barH)];
    track.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return [UIColor colorWithWhite:tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 1.0 : 0.0 alpha:tc.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.12 : 0.06];
    }];
    track.layer.cornerRadius = barH / 2.0;
    track.clipsToBounds = YES;

    CGFloat chunkW = barW * 0.3;
    UIView *chunk = [[UIView alloc] initWithFrame:CGRectMake(0, 0, chunkW, barH)];
    chunk.backgroundColor = [UIColor colorWithRed:0.03 green:0.76 blue:0.38 alpha:1.0];
    chunk.layer.cornerRadius = barH / 2.0;
    [track addSubview:chunk];

    [UIView animateWithDuration:1.2 delay:0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                     animations:^{
        chunk.frame = CGRectMake(barW - chunkW, 0, chunkW, barH);
    } completion:nil];

    [card addSubview:title];
    [card addSubview:track];
    objc_setAssociatedObject(card, "ddhTitle", title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [win addSubview:card];
    [UIView animateWithDuration:0.2 animations:^{ card.alpha = 1.0; }];
    return card;
}
+ (void)dd_render {
    UIWindow *win = dd_progress_key_window();
    if (!win) return;
    UIView *card = [win viewWithTag:kDDHubTag] ?: [self dd_make_card:win];
    if (!card) return;
    NSDictionary *tasks = [[self dd_tasks] copy];
    NSInteger n = tasks.count;
    if (n == 0) { [self dd_dismiss]; return; }
    UILabel *title = objc_getAssociatedObject(card, "ddhTitle");
    title.text = [NSString stringWithFormat:@"正在转换中 (%ld)", (long)n];
}
+ (void)dd_dismiss {
    UIWindow *win = dd_progress_key_window();
    UIView *card = win ? [win viewWithTag:kDDHubTag] : nil;
    if (!card) return;
    [UIView animateWithDuration:0.2 animations:^{ card.alpha = 0; }
                     completion:^(BOOL f){ [card removeFromSuperview]; }];
}
@end

#pragma mark - 下载等待（由 CDN 下载结束回调唤醒，不轮询）

// 登记“等下载完成”；下载结束回调触发 poke 时复查各自的真实完成态，就绪才继续。
// 不阻塞 convert 队列：未就绪就一直挂着，就绪/失败才收尾。
@implementation DDDownloadWaiter

+ (NSMutableArray *)dd_waits {
    static NSMutableArray *a;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ a = [NSMutableArray array]; });
    return a;
}
+ (NSLock *)dd_wlock {
    static NSLock *l;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ l = [NSLock new]; });
    return l;
}
// 就绪判定：文件真实落盘，且（有 task 时）task 报告完成；视频无 task，看成功回调标记。
+ (BOOL)dd_ready:(NSDictionary *)w {
    NSString *(^pathBlock)(void) = w[@"pathBlock"];
    NSString *p = pathBlock ? pathBlock() : nil;
    if (!dd_file_exists(p)) return NO;
    NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:p error:nil];
    long long sz = a ? [a[NSFileSize] longLongValue] : 0;
    if (sz <= 0) return NO;
    MsgFileTransferTask *task = w[@"task"];
    if (task) {
        if ([task respondsToSelector:@selector(isCompleted)] && [task isCompleted]) return YES;
        if ([task respondsToSelector:@selector(progress)] && [task progress] >= 100) return YES;
        return NO;
    }
    return [w[@"videoDone"] boolValue];
}
+ (void)waitMsg:(id)msg task:(MsgFileTransferTask *)task
      pathBlock:(NSString *(^)(void))pathBlock token:(NSString *)token
           then:(void (^)(NSString *path))then {
    NSMutableDictionary *w = [NSMutableDictionary dictionary];
    if (msg) w[@"msg"] = msg;
    if (task) w[@"task"] = task;
    if (pathBlock) w[@"pathBlock"] = pathBlock;
    if (token) w[@"token"] = token;
    if (then) w[@"then"] = then;
    // 已就绪（本来就已下载）直接继续，无需等回调。
    if ([self dd_ready:w]) {
        NSString *p = pathBlock ? pathBlock() : nil;
        dispatch_async(dd_convert_queue, ^{ if (then) then(p); });
        return;
    }
    [[self dd_wlock] lock]; [[self dd_waits] addObject:w]; [[self dd_wlock] unlock];
}
+ (void)poke {
    [[self dd_wlock] lock];
    NSArray *snapshot = [[self dd_waits] copy];
    [[self dd_wlock] unlock];
    for (NSDictionary *w in snapshot) {
        if ([self dd_ready:w]) {
            [self dd_remove:w];
            NSString *(^pathBlock)(void) = w[@"pathBlock"];
            void (^then)(NSString *) = w[@"then"];
            NSString *p = pathBlock ? pathBlock() : nil;
            if (then) dispatch_async(dd_convert_queue, ^{ then(p); });
            continue;
        }
        // 下载失败：收起提示，放弃等待，避免永久挂起。
        MsgFileTransferTask *task = w[@"task"];
        if (task && [task respondsToSelector:@selector(isFail)] && [task isFail]) {
            [self dd_remove:w];
            NSString *token = w[@"token"];
            if (token) [DDProgressHub complete:token];
        }
    }
}
+ (void)dd_remove:(NSDictionary *)w {
    [[self dd_wlock] lock]; [[self dd_waits] removeObjectIdenticalTo:w]; [[self dd_wlock] unlock];
}
// 视频下载成功回调：按消息命中标记，再复查。
+ (void)videoDone:(id)msgWrap {
    if (!msgWrap) return;
    [[self dd_wlock] lock];
    for (NSMutableDictionary *w in [self dd_waits]) {
        if (w[@"msg"] == msgWrap && !w[@"task"]) w[@"videoDone"] = @YES;
    }
    [[self dd_wlock] unlock];
    [self poke];
}
@end

#pragma mark - 语音转换：SILK 容器

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

#pragma mark - 语音转换：语音构造与发送

// 填充语音消息扩展信息与 voicemsg XML 正文。
// 不写正文则微信重启重建消息时拿到空正文 → 当作未完成语音自动重发。
static void dd_configure_voice_msg(id wrap, NSData *voiceData, unsigned int duration) {
    id ext = dd_voice_extend_info(wrap, YES);
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
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
        AVSampleRateKey: @(kDDVCVoiceSampleRate),
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
// 媒体 → 语音：未下载则先触发下载，完成后抽音轨 / 复用 SILK，编码成微信语音后发送。
static void dd_media_to_voice(CMessageWrap *msg, NSString *(^pathBlock)(void), MsgFileTransferTask *(^downloadBlock)(void)) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    dispatch_async(dd_convert_queue, ^{
        NSString *token = [DDProgressHub begin];
        // 直接以 transfer task 的真实完成态为准：取得/发起下载任务，再等待真正落盘。
        // 已下完的 task 立即返回，不会误跳过下载，也不会因“猜路径”与真实落盘路径不一致而误判超时。
        MsgFileTransferTask *task = downloadBlock ? downloadBlock() : nil;
        // 事件驱动：下载完成由 CDN 回调唤醒，就绪后才执行后续（不轮询、不阻塞队列）。
        [DDDownloadWaiter waitMsg:msg task:task pathBlock:pathBlock token:token then:^(NSString *path) {
            double duration = 0;
            NSData *aud = nil;
            // 按扩展名路由：aud/silk 为微信 SILK 终态，原样复用；其余抽 PCM 再编码为 SILK。
            NSString *ext = path.pathExtension.lowercaseString;
            if ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"]) {
                NSData *raw = [NSData dataWithContentsOfFile:path];
                if (!dd_silk_frames_valid(raw)) { if (token) [DDProgressHub complete:token]; return; }
                aud = raw;
                NSData *pcm = dd_decode_silk_to_pcm(raw);
                duration = (double)pcm.length / (double)(kDDVCVoiceSampleRate * 2);
            } else {
                NSData *pcm = dd_extract_pcm(path, &duration);
                if (pcm.length == 0) { if (token) [DDProgressHub complete:token]; return; }
                duration = (double)pcm.length / (double)(kDDVCVoiceSampleRate * 2);
                aud = dd_encode_pcm_to_silk(pcm);
                if (aud.length == 0) { if (token) [DDProgressHub complete:token]; return; }
            }
            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [aud writeToFile:tmp atomically:YES];
            unsigned int ms = (unsigned int)(duration * 1000);
            if (ms == 0) ms = 1000;
            if (ms > 60000) ms = 60000;
            dispatch_async(dispatch_get_main_queue(), ^{
                CMessageWrap *sent = dd_send_voice(usr, tmp, ms);   // 发送须在主线程发起
                // 提示持续到微信回调「发送成功」为止（按 localID 命中）；发送未发起则立即收起。
                [DDProgressHub waitSendSuccess:[sent m_uiMesLocalID] token:token];
            });
        }];
    });
}

#pragma mark - 语音转换：语音 → 文件

// PCM → WAV（44 字节 RIFF 头，16bit / 单声道 / 16000Hz）。
static NSData *dd_wav_of_pcm(NSData *pcm) {
    if (pcm.length == 0) return nil;
    const uint32_t sampleRate = (uint32_t)kDDVCVoiceSampleRate;
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
        [NSString stringWithFormat:@"ddvc_voice_%@.m4a", [[NSUUID UUID] UUIDString]]];
    return [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:nil] ? dst : nil;
}
// 发送 m4a 文件消息：AddAppMsg 本地落库 → StartUploadAppMsg 触发上传。
// 返回已发出的 wrap（用于等待发送结果），失败返回 nil。
static CMessageWrap *dd_send_file_to_chat(NSString *usr, NSString *m4aPath, NSString *fileName) {
    NSString *persistPath = dd_persist_copy(m4aPath);
    if (persistPath.length) m4aPath = persistPath;
    if (!dd_file_exists(m4aPath) || !usr.length) return nil;
    NSData *fdata = [NSData dataWithContentsOfFile:m4aPath];
    if (fdata.length == 0) return nil;
    unsigned long long fsize = fdata.length;

    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDVCAppMsgType];
    [wrap setM_uiMessageType:kDDVCAppMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    [wrap setM_uiCreateTime:[(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime]];
    [wrap setM_uiStatus:kDDMsgStatusSending];

    CExtendInfoOfAPP *app = [[objc_getClass("CExtendInfoOfAPP") alloc] init];
    [app setM_uiAppMsgInnerType:kDDVCAppInnerFile];
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

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    [mgr AddAppMsg:usr MsgWrap:wrap DataPath:m4aPath Scene:0];
    [mgr StartUploadAppMsg:usr MsgWrap:wrap Scene:0];
    return wrap;
}
// 语音消息 → 文件消息。
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) return;
    NSString *usr = dd_chat_usr_of_msg(msg);
    NSString *fn  = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    dispatch_async(dd_convert_queue, ^{
        NSString *token = [DDProgressHub begin];
        NSString *p = dd_voice_path_of_msg(msg);
        if (!dd_file_exists(p)) { if (token) [DDProgressHub complete:token]; return; }
        NSData *silk = [NSData dataWithContentsOfFile:p];
        if (silk.length < 12) { if (token) [DDProgressHub complete:token]; return; }
        NSString *m4a = dd_decode_silk_to_audio(silk);
        if (!m4a.length) { if (token) [DDProgressHub complete:token]; return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            CMessageWrap *sent = dd_send_file_to_chat(usr, m4a, fn);   // 发送须在主线程发起
            [DDProgressHub waitSendSuccess:[sent m_uiMesLocalID] token:token];
        });
    });
}

#pragma mark - 语音转换：菜单注入

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
    return [@"ddvc:" stringByAppendingString:NSStringFromSelector(action)];
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

#pragma mark - Hook：发送成功回调（提示的收起点）

// 微信核心消息管理器的真实「发送成功」回调，语音/文件消息通用。
// 按 localID 命中我们登记的待完成任务，收起进度提示。
%hook CMessageMgr
- (void)updateMsgSourceOnSendSuccess:(id)msgWrap secMsgSource:(id)src svrTime:(unsigned int)t {
    %orig;
    if ([msgWrap respondsToSelector:@selector(m_uiMesLocalID)]) {
        [DDProgressHub sendSuccess:[msgWrap m_uiMesLocalID]];
    }
}
%end

// 聊天页的发送成功回调，作为并联兜底信号（与上面幂等：先命中者收起，另一个空转）。
%hook BaseMsgContentViewController
- (void)OnMsgSendSuccess:(id)msgWrap {
    %orig;
    if ([msgWrap respondsToSelector:@selector(m_uiMesLocalID)]) {
        [DDProgressHub sendSuccess:[msgWrap m_uiMesLocalID]];
    }
}
%end

#pragma mark - Hook：下载完成（唤醒等待中的转换）

// CDN 下载结束（文件/app attach）：唤醒所有等待项，各自复查自己的完成态。
%hook CdnComMgr
- (void)OnDownloadEnd:(id)info {
    %orig;
    [DDDownloadWaiter poke];
}
%end

// 视频下载成功（原生回调，与 startDownloadVideo: 同源）：按消息命中标记后再复查。
%hook MMImgDownloader_Message
- (void)OnMsgDownloadVideoSuccess:(id)msgWrap {
    %orig;
    [DDDownloadWaiter videoDone:msgWrap];
}
%end

#pragma mark - Hook：自定义语音秒数上行改写

%hook UploadVoiceWrap
- (void)setM_uiVoiceTime:(unsigned int)v {
    %orig(dd_voice_time_ms(v));
}
%end

#pragma mark - Hook：收藏语音转发闸门

%hook FavoritesItem
- (_Bool)canBeForward {
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return YES;
    return %orig;
}
- (id)canBeForwardWithMsg {
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return nil;
    return %orig;
}
- (id)canBeForwardWithMsg:(_Bool)arg1 {
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return nil;
    return %orig;
}
%end

#pragma mark - Hook：阻止语音被降级为文本

%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    if (dd_voice_forward_enabled() && dd_is_voice_msg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - Hook：收藏语音做成待转发消息

%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (dd_voice_fav_enabled() && dd_is_fav_voice_item(arg1)) dd_append_voice_msg(arg1, self);
    %orig;
}
%end

#pragma mark - Hook：接管语音消息发送（转发）

%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    if (dd_is_voice_msg(arg1)) {
        if (!dd_voice_forward_enabled()) { %orig; return; }
        dd_take_over_voice_msg(arg1, arg2);
        return;
    }
    %orig;
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 {
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3 {
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3 {
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
%end

#pragma mark - Hook：语音消息长按加「转发」

%hook BaseMessageCellView
- (BOOL)canShowForwardMenuItem {
    if (dd_voice_msg_enabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) return YES;
    return %orig;
}
- (void)onForward:(id)arg1 {
    if (dd_voice_msg_enabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        [self doForward];
        return;
    }
    %orig;
}
%end

#pragma mark - Hook：视频消息 → 转语音

%hook VideoMessageCellView
- (NSArray *)operationMenuItems {
    return dd_inject_items(self, %orig, [DDVoiceConvertConfig shared].videoToVoiceEnabled,
                           @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) && [DDVoiceConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(msg, ^NSString *{ return dd_video_path_of_cell(self); },
                          ^MsgFileTransferTask *(void){ dd_trigger_video_download(msg); return nil; });
}
%end

#pragma mark - Hook：文件消息 → 转语音

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    if (!dd_file_has_audio(dd_msg_of_cell(self))) return %orig;
    return dd_inject_items(self, %orig, [DDVoiceConvertConfig shared].fileToVoiceEnabled,
                           @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:))
        return [DDVoiceConvertConfig shared].fileToVoiceEnabled && dd_file_has_audio(dd_msg_of_cell(self));
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(msg, ^NSString *{ return dd_file_path_of_msg(msg); },
                          ^MsgFileTransferTask *(void){ return dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：语音消息 → 转文件 + 转发

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:original.count + 2];
    [items addObjectsFromArray:original];
    // 语音转文件：注入 svg 图标项（带 userInfo 去重）。
    if ([DDVoiceConvertConfig shared].voiceToFileEnabled) {
        NSString *token = dd_menu_token(@selector(dd_voiceToFile:));
        BOOL have = NO;
        for (MMMenuItem *it in items) {
            id ui = [it userInfo];
            if ([ui isKindOfClass:[NSString class]] && [(NSString *)ui isEqualToString:token]) { have = YES; break; }
        }
        if (!have) {
            MMMenuItem *item = [[objc_getClass("MMMenuItem") alloc] initWithTitle:@"转文件"
                                                                          svgName:@"icon_filled_record_voice"
                                                                           target:self
                                                                           action:@selector(dd_voiceToFile:)];
            if (item) {
                [item setUserInfo:token];
                [items addObject:item];
            }
        }
    }
    // 语音消息转发：插入微信自带 forwardMenuItem 到头部。
    if (dd_voice_msg_enabled()) {
        [items insertObject:[self forwardMenuItem] atIndex:0];
    }
    return items;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_voiceToFile:) && [DDVoiceConvertConfig shared].voiceToFileEnabled) return YES;
    if (action == @selector(onForward:) && dd_voice_msg_enabled()) return YES;
    return %orig;
}
%new
- (void)dd_voiceToFile:(id)sender {
    dd_voice_to_file(dd_msg_of_cell(self));
}
%new
- (void)onForward:(id)sender {
    [self doForward];
}
%end

#pragma mark - 设置界面（唯一入口：DDSettingsViewController）

@interface DDSettingsViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *secondsField;
@end

@implementation DDSettingsViewController {
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
    self.title = @"语音助手设置";
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    [self ensureTableViewMgr];
    if (!_tableViewManager) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    // 分组一：语音设置（转发 / 自定义秒数）
    DDVoiceConfig *cfg = [DDVoiceConfig sharedConfig];
    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"语音设置"];
    if (!sec) return;
    [sec addCell:[cellMgr switchCellForSel:@selector(onSecondsSwitch:) target:self title:@"设置语音秒数" on:cfg.voiceSecondsEnabled]];
    if (cfg.voiceSecondsEnabled) {
        self.secondsField = [[UITextField alloc] init];
        self.secondsField.placeholder = @"自定义秒数(1-60)";
        self.secondsField.text = cfg.voiceSeconds;
        self.secondsField.textAlignment = NSTextAlignmentRight;
        self.secondsField.keyboardType = UIKeyboardTypeNumberPad;
        self.secondsField.delegate = self;
        [self.secondsField addTarget:self action:@selector(onSecondsChanged:) forControlEvents:UIControlEventEditingChanged];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳自定义秒数"
                                     rightView:[self inputRowWithField:self.secondsField action:@selector(onSecondsConfirmed:)]]];
    }
    [sec addCell:[cellMgr switchCellForSel:@selector(onFavSwitch:) target:self title:@"收藏语音转发" on:cfg.favEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(onMsgSwitch:) target:self title:@"语音消息转发" on:cfg.msgEnabled]];
    [_tableViewManager addSection:sec];

    // 分组二：转换设置（语音转换）
    DDVoiceConvertConfig *mc = [DDVoiceConvertConfig shared];
    WCTableViewSectionManager *sec2 = [secMgr sectionWithHeader:@"转换设置"];
    if (sec2) {
        [sec2 addCell:[cellMgr switchCellForSel:@selector(onVideoToVoiceSwitch:) target:self title:@"视频转语音" on:mc.videoToVoiceEnabled]];
        [sec2 addCell:[cellMgr switchCellForSel:@selector(onFileToVoiceSwitch:)  target:self title:@"文件转语音" on:mc.fileToVoiceEnabled]];
        [sec2 addCell:[cellMgr switchCellForSel:@selector(onVoiceToFileSwitch:)  target:self title:@"语音转文件" on:mc.voiceToFileEnabled]];
        [_tableViewManager addSection:sec2];
    }

    [_tableViewManager reloadTableView];
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)onFavSwitch:(UISwitch *)s { [DDVoiceConfig sharedConfig].favEnabled = s.on; }
- (void)onMsgSwitch:(UISwitch *)s { [DDVoiceConfig sharedConfig].msgEnabled = s.on; }
- (void)onVideoToVoiceSwitch:(UISwitch *)s { [DDVoiceConvertConfig shared].videoToVoiceEnabled = s.on; }
- (void)onFileToVoiceSwitch:(UISwitch *)s  { [DDVoiceConvertConfig shared].fileToVoiceEnabled = s.on; }
- (void)onVoiceToFileSwitch:(UISwitch *)s  { [DDVoiceConvertConfig shared].voiceToFileEnabled = s.on; }
// 开关切换即重建表格（开启则展开输入框）
- (void)onSecondsSwitch:(UISwitch *)s {
    [DDVoiceConfig sharedConfig].voiceSecondsEnabled = s.isOn;
    [self buildTable];
}
- (void)onSecondsChanged:(UITextField *)field { [DDVoiceConfig sharedConfig].voiceSeconds = field.text; }
- (void)onSecondsConfirmed:(id)sender {
    [DDVoiceConfig sharedConfig].voiceSeconds = self.secondsField.text;
    [self.secondsField resignFirstResponder];
}
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField != self.secondsField) return YES;
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if ([next length] == 0) return YES;
    if ([[next stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] > 0) return NO;
    int v = [next intValue];
    if (v < 1 || v > kDDVoiceMaxSeconds) return NO;
    return YES;
}
// 右侧容器：输入框 + 确认按钮（灰底、圆角、系统默认文字颜色）
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];
    return container;
}
@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        dd_convert_queue = dispatch_queue_create("com.ddvc.convert", DISPATCH_QUEUE_SERIAL);
        [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD语音助手"
                                                                          version:@"1.0.0"
                                                                       controller:@"DDSettingsViewController"];
    }
}

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// 微信类前向声明
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
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightView:(id)arg4;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 accessoryType:(long long)arg4;
@end

@interface FavoritesItemDataField : NSObject
@property(nonatomic) unsigned int duration;
- (id)GetDataPath;
@end

@interface CMessageWrap : NSObject
+ (id)getPathOfMsgImg:(id)arg1;
+ (_Bool)isSenderFromMsgWrap:(id)arg1;
- (id)initWithMsgType:(long long)arg1;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) id m_extendInfoWithMsgType;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(nonatomic, weak) CMessageWrap *m_refMessageWrap;
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
- (_Bool)deleteMessageFromDB:(id)arg1;
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

// 语音 cell 转发生态（BaseMessageCellView 须先于 VoiceMessageCellView 声明）
@interface BaseMessageCellView : NSObject
- (BOOL)canShowForwardMenuItem;
- (id)forwardMenuItem;
- (void)onForward:(id)arg1;
- (void)doForward;
@end

@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

#pragma mark - 配置

#define kDDVoiceEnableFav @"kDDVoiceEnableFav"
#define kDDVoiceEnableMsg @"kDDVoiceEnableMsg"
#define kDDVoiceSecondsEnabled @"kDDVoiceSecondsEnabled"
#define kDDVoiceSeconds @"kDDVoiceSeconds"

// 微信语音最大时长（秒）：录制系统硬上限。
// 头文件证据：MMTapRecordButton.maxSeconds、TingAudioRecordConfiguration.maxTimeInSecond、
// TingAudioRecorder initWithRecordMinTime:recordMaxTime: —— 微信默认即 60 秒。
#define kDDVoiceMaxSeconds 60

static const int kDDVoiceFavItemType = 3;        // 收藏语音 type == 3
static const long long kDDVoiceMsgType = 34;      // 语音消息 m_uiMessageType == 0x22
static const unsigned int kDDVoiceFormat = 4;
static const unsigned int kDDVoiceEndFlag = 1;
static const unsigned int kDDMsgStatusSending = 1;
static const NSTimeInterval kDDDownloadWaitStep = 0.25;
static const unsigned int kDDVoiceLocalIDBase = 10000;
static const unsigned int kDDVoiceLocalIDRange = 0x15f90;
// 把收藏项绑到构造出的语音 wrap 上，供「发送时下载」反查并下载
static const void *kDDVoiceFavSourceKey = &kDDVoiceFavSourceKey;

@interface DDVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL favEnabled;  // 收藏语音转发
@property (assign, nonatomic) BOOL msgEnabled;  // 语音消息转发
@property (assign, nonatomic) BOOL voiceSecondsEnabled;  // 设置语音秒数
@property (copy, nonatomic) NSString *voiceSeconds;      // 自定义秒数（数字文本，空=不覆盖）
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
- (void)setFavEnabled:(BOOL)v {
    _favEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableFav];
}
- (void)setMsgEnabled:(BOOL)v {
    _msgEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableMsg];
}
- (void)setVoiceSecondsEnabled:(BOOL)v {
    _voiceSecondsEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceSecondsEnabled];
}
- (void)setVoiceSeconds:(NSString *)v {
    _voiceSeconds = [v copy];
    [NSUserDefaults.standardUserDefaults setObject:_voiceSeconds forKey:kDDVoiceSeconds];
}
@end

static BOOL dd_voice_fav_enabled(void) { return [DDVoiceConfig sharedConfig].favEnabled; }
static BOOL dd_voice_msg_enabled(void) { return [DDVoiceConfig sharedConfig].msgEnabled; }
// 发送汇点：收藏/语音任一开关开启即接管（收藏语音最终也构造成 type=34 走此路径发出）
static BOOL dd_voice_forward_enabled(void) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    return c.favEnabled || c.msgEnabled;
}

#pragma mark - 工具

static BOOL dd_voice_is_msg(id msg) {
    return ((CMessageWrap *)msg).m_uiMessageType == (unsigned int)kDDVoiceMsgType;
}
static BOOL dd_voice_is_fav_item(id obj) {
    return ((FavoritesItem *)obj).type == kDDVoiceFavItemType;
}
static BOOL dd_file_exists(NSString *path) {
    if ([path length] == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_current_usr_name(void) {
    return [objc_getClass("SettingUtil") getCurUsrName];
}
static id dd_mm_service(NSString *serviceName) {
    Class ctxCls = objc_getClass("MMContext");
    id ctx = [ctxCls currentContext];
    Class svc = objc_getClass([serviceName UTF8String]);
    return [ctx getService:svc];
}
static void dd_start_download_fav_item(id item) {
    Class ctxCls = objc_getClass("MMContext");
    Class mgrCls = objc_getClass("FavoritesMgr");
    id ctx = [ctxCls currentContext];
    id mgr = [ctx getService:mgrCls];
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}
// 轮询 needDownLoad 直至下载完成；不设上限
static void dd_wait_download_finish(id item) {
    while (((FavoritesItem *)item).needDownLoad) {
        [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
    }
}
// 发起下载，后台轮询完成后回主线程回调
static void dd_download_fav_item_then(id item, void (^done)(void)) {
    dd_start_download_fav_item(item);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        dd_wait_download_finish(item);
        dispatch_async(dispatch_get_main_queue(), done);
    });
}

#pragma mark - 语音扩展信息

static id dd_voiceExtendInfo(id wrap, BOOL create) {
    Class vcls = objc_getClass("CExtendInfoOfVoiceMsg");
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    if (!create) return nil;
    id nv = [[vcls alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
static NSData *dd_voiceData(id wrap) {
    return [dd_voiceExtendInfo(wrap, NO) m_dtVoice];
}
static unsigned int dd_voiceDuration(id wrap) {
    return [dd_voiceExtendInfo(wrap, NO) m_uiVoiceTime];
}
static BOOL dd_configureVoiceMeta(id wrap, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    return YES;
}
static BOOL dd_injectVoiceData(id wrap, NSData *voiceData) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_dtVoice:voiceData];
    return YES;
}
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    dd_configureVoiceMeta(wrap, duration);
    return dd_injectVoiceData(wrap, voiceData);
}
// 自定义语音秒数：开关开 + 有效数字 → 用自定义值覆盖真实时长；
// 空字符串或 0 视为不覆盖（等价于关闭），直接返回真实时长
static unsigned int dd_effectiveVoiceDuration(unsigned int realDuration) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    if (!c.voiceSecondsEnabled) return realDuration;
    NSString *s = c.voiceSeconds;
    if ([s length] == 0) return realDuration;
    unsigned int v = (unsigned int)[s integerValue];
    if (v == 0) return realDuration;        // 0（含旧配置残留）视为不覆盖
    return v;                               // 输入层已保证 1~60，直接采用
}

#pragma mark - 音频路径

// 决定语音文件归属哪个用户名（群聊/发送方/接收方）
static NSString *dd_owner_user_for_voice(id msg) {
    NSString *to = (NSString *)((CMessageWrap *)msg).m_nsToUsr;
    if ([to containsString:@"@chatroom"]) return to;
    Class wrapCls = objc_getClass("CMessageWrap");
    if ([wrapCls isSenderFromMsgWrap:msg]) return to;
    return (NSString *)((CMessageWrap *)msg).m_nsFromUsr;
}
// 优先 CUtility 路径，其次 AudioSender 路径，兜底导出 m_dtVoice 到临时文件
static NSString *dd_audio_path_for_msg(id msg) {
    unsigned int localID = ((CMessageWrap *)msg).m_uiMesLocalID;
    NSString *usr = dd_owner_user_for_voice(msg);
    Class cu = objc_getClass("CUtility");
    NSString *cuPath = (NSString *)[cu GetPathOfMesAudio:usr LocalID:localID DocPath:[cu GetDocPath]];
    if (dd_file_exists(cuPath)) return cuPath;
    id sender = dd_mm_service(@"AudioSender");
    NSString *p = (NSString *)[sender getAudioFileName:usr LocalID:localID];
    if (dd_file_exists(p)) return p;
    NSData *data = dd_voiceData(msg);
    if ([data length] == 0) return nil;
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:tmp atomically:YES];
    return tmp;
}
// 把音频落到微信 Audio 目录（本地显示用，不阻断发送）
static NSString *dd_install_audio_file(id wrap, NSString *src) {
    Class wrapCls = objc_getClass("CMessageWrap");
    NSString *p = [[(NSString *)[wrapCls getPathOfMsgImg:wrap] stringByReplacingOccurrencesOfString:@"Img" withString:@"Audio"]
                                       stringByReplacingOccurrencesOfString:@".pic" withString:@".aud"];
    NSString *dir = [p stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    [fm copyItemAtPath:src toPath:p error:nil];
    return p;
}

#pragma mark - 语音发送

// 给构造出来的消息一个非零 localID，否则拿不到音频路径
static unsigned int dd_new_voice_local_id(void) {
    return kDDVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDVoiceLocalIDRange);
}
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    id sender = dd_mm_service(@"AudioSender");
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    id sessionMgr = dd_mm_service(@"MMNewSessionMgr");
    unsigned int t = [sessionMgr GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMsgStatusSending];
    NSData *d = [NSData dataWithContentsOfFile:audPath];
    dd_configureVoiceMsg(wrap, d, duration);
    [sender addMessageToDB:wrap];
    dd_install_audio_file(wrap, audPath);
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return YES;
}
// 收藏外壳：数据未就绪则下载后注入 m_dtVoice 再发送
static void dd_ensure_fav_voice_data(id msg) {
    if ([dd_voiceData(msg) length] > 0) return;
    id favItem = objc_getAssociatedObject(msg, kDDVoiceFavSourceKey);
    NSArray *list = [favItem dataList];
    id field = [list firstObject];
    NSData *d = [NSData dataWithContentsOfFile:(NSString *)[field GetDataPath]
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    dd_injectVoiceData(msg, d);
}

static BOOL dd_take_over_voice_msg(id msg, id contact) {
    if (!dd_voice_is_msg(msg)) return NO;
    NSString *usr = (NSString *)[(CBaseContact *)contact m_nsUsrName];
    unsigned int duration = dd_effectiveVoiceDuration(dd_voiceDuration(msg));
    NSString *audPath = dd_audio_path_for_msg(msg);
    if ([audPath length] == 0) {
        id favItem = objc_getAssociatedObject(msg, kDDVoiceFavSourceKey);
        if (favItem) {
            dd_download_fav_item_then(favItem, ^{
                dd_ensure_fav_voice_data(msg);
                NSString *p = dd_audio_path_for_msg(msg);
                dd_send_voice(usr, p, duration);
            });
            return YES;
        }
        return dd_send_voice(usr, audPath, duration);
    }
    return dd_send_voice(usr, audPath, duration);
}
// 批量转发逐条接管，返回需走原实现的消息
static NSArray *dd_take_over_voice_list(NSArray *src, id contact) {
    NSMutableArray *rest = [NSMutableArray array];
    for (id m in src) {
        if (dd_voice_is_msg(m)) {
            dd_take_over_voice_msg(m, contact);
            continue;
        }
        [rest addObject:m];
    }
    return rest;
}

#pragma mark - 收藏语音消息构造

// 把收藏语音数据构造成待转发语音消息：文件未就绪则构造成"外壳"（含时长/localID），数据留待发送时下载
static id dd_msg_wrap_from_fav_data(id favData, id favItem) {
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    NSString *me = dd_current_usr_name();
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];
    [wrap setM_uiMesLocalID:dd_new_voice_local_id()];
    unsigned int duration = dd_effectiveVoiceDuration(field.duration);
    dd_configureVoiceMeta(wrap, duration);
    if (favItem) objc_setAssociatedObject(wrap, kDDVoiceFavSourceKey, favItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id pathObj = [field GetDataPath];
    if (dd_file_exists((NSString *)pathObj)) {
        NSData *data = [NSData dataWithContentsOfFile:(NSString *)pathObj
                                              options:NSDataReadingMappedIfSafe
                                                error:nil];
        if ([data length] > 0) {
            dd_injectVoiceData(wrap, data);
            return wrap;
        }
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

#pragma mark - 收藏语音转发闸门

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

#pragma mark - 阻止语音被降级为文本

%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    if (dd_voice_forward_enabled() && dd_voice_is_msg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - 把收藏语音做成待转发消息

%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (dd_voice_fav_enabled() && dd_voice_is_fav_item(arg1)) {
        dd_append_voice_msg(arg1, self);
    }
    %orig;
}
%end

#pragma mark - 接管语音消息发送

%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    if (dd_voice_is_msg(arg1)) {
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

#pragma mark - 普通语音消息长按菜单加「转发」

%hook BaseMessageCellView
- (BOOL)canShowForwardMenuItem {
    if (dd_voice_msg_enabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        return YES;
    }
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

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    if (!dd_voice_msg_enabled()) return original;
    id item = [self forwardMenuItem];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[original count] + 1];
    [items addObjectsFromArray:original];
    [items insertObject:item atIndex:0];
    return items;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(onForward:) && dd_voice_msg_enabled()) {
        return YES;
    }
    return %orig;
}
%end

#pragma mark - 设置界面

@interface DDVoiceSettingsViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *secondsField;
@end

@implementation DDVoiceSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (_tableViewManager) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    _tableViewManager = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                               style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) { [self ensureTableViewMgr]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD语音助手";
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
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    WCTableViewSectionManager *sec = [secMgr defaultSection];
    DDVoiceConfig *cfg = [DDVoiceConfig sharedConfig];

    // 设置语音秒数：开关置于「收藏语音转发」之上；开启后展开「自定义秒数」输入框
    [sec addCell:[cellMgr switchCellForSel:@selector(onSecondsSwitch:) target:self title:@"设置语音秒数" on:cfg.voiceSecondsEnabled]];
    if (cfg.voiceSecondsEnabled) {
        self.secondsField = [[UITextField alloc] init];
        self.secondsField.placeholder = @"自定义秒数(1-60)";
        self.secondsField.text = cfg.voiceSeconds;
        self.secondsField.textAlignment = NSTextAlignmentRight;
        self.secondsField.keyboardType = UIKeyboardTypeNumberPad;   // 键盘限制数字
        self.secondsField.delegate = self;                          // 限制：仅数字且 ≤60 秒
        [self.secondsField addTarget:self action:@selector(onSecondsChanged:) forControlEvents:UIControlEventEditingChanged];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳自定义秒数"
                                     rightView:[self inputRowWithField:self.secondsField action:@selector(onSecondsConfirmed:)]]];
    }

    [sec addCell:[cellMgr switchCellForSel:@selector(onFavSwitch:) target:self title:@"收藏语音转发" on:cfg.favEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(onMsgSwitch:) target:self title:@"语音消息转发" on:cfg.msgEnabled]];
    [_tableViewManager addSection:sec];
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
// 设置语音秒数：开关切换即重建表格（开启则展开输入框）
- (void)onSecondsSwitch:(UISwitch *)s {
    [DDVoiceConfig sharedConfig].voiceSecondsEnabled = s.isOn;
    [self buildTable];
}
// 输入即自动生效（空字符串视为不覆盖，等价于关闭）
- (void)onSecondsChanged:(UITextField *)field {
    [DDVoiceConfig sharedConfig].voiceSeconds = field.text;
}
// 确认：收起键盘并确认当前输入
- (void)onSecondsConfirmed:(id)sender {
    [DDVoiceConfig sharedConfig].voiceSeconds = self.secondsField.text;
    [self.secondsField resignFirstResponder];
}
// 限制：仅允许数字、且不超过微信语音上限（60 秒）；空串保留（表示不覆盖/关闭）
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField != self.secondsField) return YES;
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if ([next length] == 0) return YES;                                       // 空 = 不覆盖（关闭）
    if ([[next stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] > 0)
        return NO;                                                            // 非数字字符拒绝
    int v = [next intValue];
    if (v < 1 || v > kDDVoiceMaxSeconds) return NO;                           // 限制：1~60 秒
    return YES;
}
// 右侧容器：输入框 + 确认按钮（尺寸与 DD收款助手一致）
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    field.frame = CGRectMake(0, 0, 150, 30);
    field.borderStyle = UITextBorderStyleRoundedRect;
    [container addSubview:field];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(158, 0, 42, 30);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];
    return container;
}
@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD语音助手"
                                                  version:@"1.0.0"
                                               controller:@"DDVoiceSettingsViewController"];
    }
}

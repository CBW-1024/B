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

#define kDDFVEnableFav @"kDDFV_enableFavVoiceForward"
#define kDDFVEnableMsg @"kDDFV_enableVoiceMsgForward"

static const int kDDFavVoiceItemType = 3;        // 收藏语音 type == 3
static const long long kDDVoiceMsgType = 34;      // 语音消息 m_uiMessageType == 0x22
static const unsigned int kDDVoiceFormat = 4;
static const unsigned int kDDVoiceEndFlag = 1;
static const unsigned int kDDMsgStatusSending = 1;
static const NSTimeInterval kDDDownloadWaitStep = 0.25;
static const unsigned int kDDVoiceLocalIDBase = 10000;
static const unsigned int kDDVoiceLocalIDRange = 0x15f90;
// 把收藏项绑到构造出的语音 wrap 上，供「发送时下载」反查并下载
static const void *kDDFavSourceKey = &kDDFavSourceKey;

@interface DDFavVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL favEnabled;  // 收藏语音转发
@property (assign, nonatomic) BOOL msgEnabled;  // 语音消息转发
@end

@implementation DDFavVoiceConfig
+ (instancetype)sharedConfig {
    static DDFavVoiceConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDFavVoiceConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDFavVoiceConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDFVEnableFav: @NO,
        kDDFVEnableMsg: @NO,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _favEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnableFav];
        _msgEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnableMsg];
    }
    return self;
}
- (void)setFavEnabled:(BOOL)v {
    _favEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnableFav];
}
- (void)setMsgEnabled:(BOOL)v {
    _msgEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnableMsg];
}
@end

static BOOL ddFavVoiceEnabled(void) { return [DDFavVoiceConfig sharedConfig].favEnabled; }
static BOOL ddVoiceMsgEnabled(void) { return [DDFavVoiceConfig sharedConfig].msgEnabled; }
// 发送汇点：收藏/语音任一开关开启即接管（收藏语音最终也构造成 type=34 走此路径发出）
static BOOL ddForwardSendEnabled(void) {
    DDFavVoiceConfig *c = [DDFavVoiceConfig sharedConfig];
    return c.favEnabled || c.msgEnabled;
}

#pragma mark - 工具

static BOOL dd_isVoiceMsg(id msg) {
    return ((CMessageWrap *)msg).m_uiMessageType == (unsigned int)kDDVoiceMsgType;
}
static BOOL dd_isFavVoiceItem(id obj) {
    return ((FavoritesItem *)obj).type == kDDFavVoiceItemType;
}
static BOOL dd_fileExists(NSString *path) {
    if ([path length] == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_currentUsrName(void) {
    return [objc_getClass("SettingUtil") getCurUsrName];
}
static id dd_mmService(NSString *serviceName) {
    Class ctxCls = objc_getClass("MMContext");
    id ctx = [ctxCls currentContext];
    Class svc = objc_getClass([serviceName UTF8String]);
    return [ctx getService:svc];
}
static void dd_startDownloadFavItem(id item) {
    Class ctxCls = objc_getClass("MMContext");
    Class mgrCls = objc_getClass("FavoritesMgr");
    id ctx = [ctxCls currentContext];
    id mgr = [ctx getService:mgrCls];
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}
// 轮询 needDownLoad 直至下载完成；不设上限
static void dd_waitDownloadFinish(id item) {
    while (((FavoritesItem *)item).needDownLoad) {
        [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
    }
}
// 发起下载，后台轮询完成后回主线程回调
static void dd_downloadFavItemThen(id item, void (^done)(void)) {
    dd_startDownloadFavItem(item);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        dd_waitDownloadFinish(item);
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

#pragma mark - 音频路径

// 决定语音文件归属哪个用户名（群聊/发送方/接收方）
static NSString *dd_ownerUserForVoice(id msg) {
    NSString *to = (NSString *)((CMessageWrap *)msg).m_nsToUsr;
    if ([to containsString:@"@chatroom"]) return to;
    Class wrapCls = objc_getClass("CMessageWrap");
    if ([wrapCls isSenderFromMsgWrap:msg]) return to;
    return (NSString *)((CMessageWrap *)msg).m_nsFromUsr;
}
// 优先 CUtility 路径，其次 AudioSender 路径，兜底导出 m_dtVoice 到临时文件
static NSString *dd_audioPathForMsg(id msg) {
    unsigned int localID = ((CMessageWrap *)msg).m_uiMesLocalID;
    NSString *usr = dd_ownerUserForVoice(msg);
    Class cu = objc_getClass("CUtility");
    NSString *cuPath = (NSString *)[cu GetPathOfMesAudio:usr LocalID:localID DocPath:[cu GetDocPath]];
    if (dd_fileExists(cuPath)) return cuPath;
    id sender = dd_mmService(@"AudioSender");
    NSString *p = (NSString *)[sender getAudioFileName:usr LocalID:localID];
    if (dd_fileExists(p)) return p;
    NSData *data = dd_voiceData(msg);
    if ([data length] == 0) return nil;
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:tmp atomically:YES];
    return tmp;
}
// 把音频落到微信 Audio 目录（本地显示用，不阻断发送）
static NSString *dd_installAudioFile(id wrap, NSString *src) {
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
static unsigned int dd_newVoiceLocalID(void) {
    return kDDVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDVoiceLocalIDRange);
}
static BOOL dd_sendVoice(NSString *usr, NSString *audPath, unsigned int duration) {
    id sender = dd_mmService(@"AudioSender");
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDVoiceMsgType];
    [wrap setM_nsFromUsr:dd_currentUsrName()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    id sessionMgr = dd_mmService(@"MMNewSessionMgr");
    unsigned int t = [sessionMgr GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMsgStatusSending];
    NSData *d = [NSData dataWithContentsOfFile:audPath];
    dd_configureVoiceMsg(wrap, d, duration);
    [sender addMessageToDB:wrap];
    dd_installAudioFile(wrap, audPath);
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return YES;
}
// 收藏外壳：数据未就绪则下载后注入 m_dtVoice 再发送
static void dd_ensureFavVoiceData(id msg) {
    if ([dd_voiceData(msg) length] > 0) return;
    id favItem = objc_getAssociatedObject(msg, kDDFavSourceKey);
    NSArray *list = [favItem dataList];
    id field = [list firstObject];
    NSData *d = [NSData dataWithContentsOfFile:(NSString *)[field GetDataPath]
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    dd_injectVoiceData(msg, d);
}

static BOOL dd_takeOverVoiceMsg(id msg, id contact) {
    if (!dd_isVoiceMsg(msg)) return NO;
    NSString *usr = (NSString *)[(CBaseContact *)contact m_nsUsrName];
    unsigned int duration = dd_voiceDuration(msg);
    NSString *audPath = dd_audioPathForMsg(msg);
    if ([audPath length] == 0) {
        id favItem = objc_getAssociatedObject(msg, kDDFavSourceKey);
        if (favItem) {
            dd_downloadFavItemThen(favItem, ^{
                dd_ensureFavVoiceData(msg);
                NSString *p = dd_audioPathForMsg(msg);
                dd_sendVoice(usr, p, duration);
            });
            return YES;
        }
        return dd_sendVoice(usr, audPath, duration);
    }
    return dd_sendVoice(usr, audPath, duration);
}
// 批量转发逐条接管，返回需走原实现的消息
static NSArray *dd_takeOverVoiceList(NSArray *src, id contact) {
    NSMutableArray *rest = [NSMutableArray array];
    for (id m in src) {
        if (dd_isVoiceMsg(m)) {
            dd_takeOverVoiceMsg(m, contact);
            continue;
        }
        [rest addObject:m];
    }
    return rest;
}

#pragma mark - 收藏语音消息构造

// 把收藏语音数据构造成待转发语音消息：文件未就绪则构造成"外壳"（含时长/localID），数据留待发送时下载
static id dd_msgWrapFromFavData(id favData, id favItem) {
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    NSString *me = dd_currentUsrName();
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];
    [wrap setM_uiMesLocalID:dd_newVoiceLocalID()];
    unsigned int duration = field.duration;
    dd_configureVoiceMeta(wrap, duration);
    if (favItem) objc_setAssociatedObject(wrap, kDDFavSourceKey, favItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id pathObj = [field GetDataPath];
    if (dd_fileExists((NSString *)pathObj)) {
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
static void dd_appendVoiceMsg(id favItem, id controller) {
    NSArray *list = ((FavoritesItem *)favItem).dataList;
    if ([list count] == 0) return;
    id wrap = dd_msgWrapFromFavData([list firstObject], favItem);
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
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return YES;
    return %orig;
}
- (id)canBeForwardWithMsg {
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return nil;
    return %orig;
}
- (id)canBeForwardWithMsg:(_Bool)arg1 {
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return nil;
    return %orig;
}
%end

#pragma mark - 阻止语音被降级为文本

%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    if (ddForwardSendEnabled() && dd_isVoiceMsg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - 把收藏语音做成待转发消息

%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1)) {
        dd_appendVoiceMsg(arg1, self);
    }
    %orig;
}
%end

#pragma mark - 接管语音消息发送

%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    if (dd_isVoiceMsg(arg1)) {
        if (!ddForwardSendEnabled()) { %orig; return; }
        dd_takeOverVoiceMsg(arg1, arg2);
        return;
    }
    %orig;
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 {
    if (!ddForwardSendEnabled()) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3 {
    if (!ddForwardSendEnabled()) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3 {
    if (!ddForwardSendEnabled()) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
%end

#pragma mark - 普通语音消息长按菜单加「转发」

%hook BaseMessageCellView
- (BOOL)canShowForwardMenuItem {
    if (ddVoiceMsgEnabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        return YES;
    }
    return %orig;
}
- (void)onForward:(id)arg1 {
    if (ddVoiceMsgEnabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        [self doForward];
        return;
    }
    %orig;
}
%end

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    if (!ddVoiceMsgEnabled()) return original;
    id item = [self forwardMenuItem];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[original count] + 1];
    [items addObjectsFromArray:original];
    [items insertObject:item atIndex:0];
    return items;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(onForward:) && ddVoiceMsgEnabled()) {
        return YES;
    }
    return %orig;
}
%end

#pragma mark - 设置界面

@interface DDFavVoiceSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDFavVoiceSettingsViewController {
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
    self.title = @"DD语音转发";
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
    DDFavVoiceConfig *cfg = [DDFavVoiceConfig sharedConfig];
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
- (void)onFavSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].favEnabled = s.on; }
- (void)onMsgSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].msgEnabled = s.on; }
@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD语音转发"
                                                  version:@"1.0.0"
                                               controller:@"DDFavVoiceSettingsViewController"];
    }
}


#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

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

@interface MMUIViewController : UIViewController
- (void)startLoadingWithText:(id)arg1;
- (void)stopLoading;
@end

// 收藏项数据体 FavoritesItemDataField.h:9 / :192 duration / :245 GetDataPath
@interface FavoritesItemDataField : NSObject
@property(nonatomic) unsigned int duration;
- (id)GetDataPath;
@end

// CMessageWrap.h:437/445/450/452/454/591
@interface CMessageWrap : NSObject
- (id)initWithMsgType:(long long)arg1;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) id m_extendInfoWithMsgType;
@end

// CExtendInfoOfVoiceMsg.h 语音扩展信息
@interface CExtendInfoOfVoiceMsg : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(nonatomic, weak) CMessageWrap *m_refMessageWrap;
@end

// MMContext.h:47 / :100
@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

// FavoritesMgr.h:174
@interface FavoritesMgr : NSObject
- (void)startDownloadFavoritesItem:(id)arg1 IsPriority:(_Bool)arg2;
@end

// SettingUtil.h:37
@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

// 被 hook 类，手写完整 interface
// FavoritesItem.h:153 type / :160 dataList / :171 needDownLoad / :177 canBeForward / :183 canBeForwardWithMsg: / :184 canBeForwardWithMsg
@interface FavoritesItem : NSObject
@property(nonatomic) int type;
@property(retain, nonatomic) NSArray *dataList;
- (_Bool)needDownLoad;
- (_Bool)canBeForward;
- (id)canBeForwardWithMsg;
- (id)canBeForwardWithMsg:(_Bool)arg1;
@end

// MyFavoritesListViewController.h:29
@interface MyFavoritesListViewController : UIViewController
- (void)forwardData:(id)arg1;
@end

// FavForwardLogicController.h  ivar NSMutableArray *m_messageWrapList;  - addMsgFromItem:
@interface FavForwardLogicController : NSObject
- (void)addMsgFromItem:(id)arg1;
@end

#pragma mark - 配置（单开关，默认 OFF）
#define kDDFVEnable @"kDDFV_enableFavVoiceForward"
static const BOOL kDDFVDefaultEnable = NO;

// 锤子二进制硬编码常量（非开关，全部来自反汇编实测）
// 0x78f0d4 canBeForward: bl 0x8e6800(@selector(type)) -> cmp w0,#3
// 0x78f244 forwardData:  bl 0x8e6800 -> cmp w0,#3
// 0x78f4e8 addMsgFromItem: bl 0x8e6800 -> cmp w0,#3
static const int kDDFavVoiceItemType = 3;
// 0x790604 initWithMsgType: mov w2,#0x22
static const long long kDDVoiceMsgType = 34;
// 0x7595d0 setM_uiVoiceFormat: mov w2,#4
static const unsigned int kDDVoiceFormat = 4;
// 0x7595e0 setM_uiVoiceEndFlag: mov w2,#1
static const unsigned int kDDVoiceEndFlag = 1;
// 0x7901b4 轮询上限 0xf0 次，每次 sleep 0.25s
static const int kDDDownloadWaitMax = 240;
static const NSTimeInterval kDDDownloadWaitStep = 0.25;

@interface DDFavVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL enabled;
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
    [NSUserDefaults.standardUserDefaults registerDefaults:@{ kDDFVEnable: @(kDDFVDefaultEnable) }];
}
- (instancetype)init {
    if (self = [super init]) {
        _enabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnable];
    }
    return self;
}
- (void)setEnabled:(BOOL)v {
    _enabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnable];
}
@end

static BOOL ddFavVoiceEnabled(void) {
    return [DDFavVoiceConfig sharedConfig].enabled;
}

#pragma mark - 工具函数

static BOOL dd_isFavVoiceItem(id obj) {
    if (!obj) return NO;
    Class itemCls = objc_getClass("FavoritesItem");
    if (!itemCls) return NO;
    if (![obj isKindOfClass:itemCls]) return NO;
    if (![obj respondsToSelector:@selector(type)]) return NO;
    return ((FavoritesItem *)obj).type == kDDFavVoiceItemType;
}

// 对齐锤子 0x78f3c0 / 0x7903c0：MMContext -> getService:FavoritesMgr -> startDownloadFavoritesItem:IsPriority:
static void dd_startDownloadFavItem(id item) {
    if (!item) return;
    Class ctxCls = objc_getClass("MMContext");
    Class mgrCls = objc_getClass("FavoritesMgr");
    if (!ctxCls || !mgrCls) return;
    if (![ctxCls respondsToSelector:@selector(currentContext)]) return;
    id ctx = [ctxCls currentContext];
    if (!ctx) return;
    if (![ctx respondsToSelector:@selector(getService:)]) return;
    id mgr = [ctx getService:mgrCls];
    if (!mgr) return;
    if (![mgr respondsToSelector:@selector(startDownloadFavoritesItem:IsPriority:)]) return;
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}

// 对齐锤子 0x75909c voiceExtendInfoForMessageWrap:createIfNeeded:
static id dd_voiceExtendInfo(id wrap, BOOL create) {
    if (!wrap) return nil;
    Class vcls = objc_getClass("CExtendInfoOfVoiceMsg");
    if (!vcls) return nil;
    if (![wrap respondsToSelector:@selector(m_extendInfoWithMsgType)]) return nil;
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext && [ext isKindOfClass:vcls]) return ext;
    if (!create) return nil;
    if (![wrap respondsToSelector:@selector(setM_extendInfoWithMsgType:)]) return nil;
    id nv = [[vcls alloc] init];
    if (!nv) return nil;
    if ([nv respondsToSelector:@selector(setM_refMessageWrap:)]) [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}

// 对齐锤子 0x7594d0 configureVoiceMessageWrap:voiceData:duration:
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    if (!wrap || !voiceData) return NO;
    if (duration == 0) return NO;
    if ([voiceData length] == 0) return NO;
    id ext = dd_voiceExtendInfo(wrap, YES);
    if (!ext) return NO;
    if ([ext respondsToSelector:@selector(setM_refMessageWrap:)]) [ext setM_refMessageWrap:wrap];
    if ([ext respondsToSelector:@selector(setM_uiVoiceFormat:)]) [ext setM_uiVoiceFormat:kDDVoiceFormat];
    if ([ext respondsToSelector:@selector(setM_uiVoiceEndFlag:)]) [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    if ([ext respondsToSelector:@selector(setM_uiVoiceTime:)]) [ext setM_uiVoiceTime:duration];
    if ([ext respondsToSelector:@selector(setM_dtVoice:)]) [ext setM_dtVoice:voiceData];
    return YES;
}

// 对齐锤子 0x790570：GetDataPath -> NSData -> initWithMsgType:0x22
static id dd_voiceMsgWrapFromData(id favData) {
    if (!favData) return nil;
    if (![favData respondsToSelector:@selector(GetDataPath)]) return nil;
    id pathObj = [favData GetDataPath];
    if (![pathObj isKindOfClass:[NSString class]]) return nil;
    NSString *path = (NSString *)pathObj;
    if ([path length] == 0) return nil;
    NSData *voiceData = [NSData dataWithContentsOfFile:path];
    if (!voiceData || [voiceData length] == 0) return nil;
    unsigned int duration = 0;
    if ([favData respondsToSelector:@selector(duration)]) duration = [favData duration];
    if (duration == 0) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return nil;
    id raw = [wrapCls alloc];
    if (![raw respondsToSelector:@selector(initWithMsgType:)]) return nil;
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    if (!wrap) return nil;
    Class settingCls = objc_getClass("SettingUtil");
    if (settingCls && [settingCls respondsToSelector:@selector(getCurUsrName)]) {
        id usr = [settingCls getCurUsrName];
        if ([usr isKindOfClass:[NSString class]]) [wrap setM_nsFromUsr:usr];
    }
    [wrap setM_uiCreateTime:(unsigned int)[[NSDate date] timeIntervalSince1970]];
    if (!dd_configureVoiceMsg(wrap, voiceData, duration)) return nil;
    [wrap setM_uiMesLocalID:(unsigned int)([[NSDate date] timeIntervalSince1970] * 1000)];
    return wrap;
}

// 对齐锤子 0x790484/0x7907a8：[[item dataList] firstObject] -> 语音 CMessageWrap
static id dd_voiceMsgWrapFromItem(id item) {
    if (!item) return nil;
    if (![item respondsToSelector:@selector(dataList)]) return nil;
    id dl = [item dataList];
    if (![dl isKindOfClass:[NSArray class]]) return nil;
    NSArray *list = (NSArray *)dl;
    if ([list count] == 0) return nil;
    return dd_voiceMsgWrapFromData([list firstObject]);
}

// 对齐锤子 0x7907ec：把语音消息塞进 m_messageWrapList（用 MSHookIvar，不用 KVC）
static void dd_appendMsgToController(id ctrl, id msg) {
    if (!ctrl || !msg) return;
    if (!class_getInstanceVariable([ctrl class], "m_messageWrapList")) return;
    NSMutableArray *list = MSHookIvar<NSMutableArray *>(ctrl, "m_messageWrapList");
    if (![list isKindOfClass:[NSMutableArray class]]) return;
    if ([list containsObject:msg]) return;
    [list addObject:msg];
}

#pragma mark - 一 收藏项转发闸门
// 锤子 0x78f0d4 / 0x78f14c / 0x78f1c4：type == 3 时放行
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

#pragma mark - 二 收藏列表点转发：未下载则先下载并中断本次
// 锤子 0x78f244：命中后启动下载 + startLoadingWithText:，然后直接返回，不调用原实现
%hook MyFavoritesListViewController
- (void)forwardData:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1)) {
        if ([arg1 respondsToSelector:@selector(needDownLoad)] && ((FavoritesItem *)arg1).needDownLoad) {
            dd_startDownloadFavItem(arg1);
            id vc = self;
            if ([vc respondsToSelector:@selector(startLoadingWithText:)]) {
                [vc startLoadingWithText:@"语音下载中，完成后请重新转发"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if ([vc respondsToSelector:@selector(stopLoading)]) [vc stopLoading];
                });
            }
            return;
        }
    }
    %orig;
}
%end

#pragma mark - 三 转发逻辑：把语音消息补进转发列表
// 锤子 0x78f4e8：命中后额外把语音消息塞进 m_messageWrapList，原实现照常调用
%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1)) {
        BOOL need = NO;
        if ([arg1 respondsToSelector:@selector(needDownLoad)]) {
            need = ((FavoritesItem *)arg1).needDownLoad;
        }
        if (need) {
            // 对齐 0x790320：先下载，后台轮询等待完成后再补消息
            dd_startDownloadFavItem(arg1);
            id item = arg1;
            __weak FavForwardLogicController *weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                for (int i = 0; i < kDDDownloadWaitMax; i++) {
                    [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
                    if (![item respondsToSelector:@selector(needDownLoad)]) break;
                    if (!((FavoritesItem *)item).needDownLoad) break;
                }
                id msg = dd_voiceMsgWrapFromItem(item);
                if (msg) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dd_appendMsgToController(weakSelf, msg);
                    });
                }
            });
        } else {
            // 对齐 0x790484：已下载，直接构造语音消息并追加
            id msg = dd_voiceMsgWrapFromItem(arg1);
            dd_appendMsgToController(self, msg);
        }
    }
    %orig;
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
    self.title = @"DD收藏语音转发";
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
    [sec addCell:[cellMgr switchCellForSel:@selector(onEnableSwitch:) target:self title:@"启用收藏语音转发" on:[DDFavVoiceConfig sharedConfig].enabled]];
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
- (void)onEnableSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].enabled = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD收藏语音转发"
                                                      version:@"1.0.0"
                                                   controller:@"DDFavVoiceSettingsViewController"];
        }
    }
}

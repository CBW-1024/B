// ============================================================================
//  DDFoldTop.xm —— 「启用折叠的群聊置顶选项」 v3.0.0
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  功能：把聊天列表里的「折叠的群聊」这一栏置顶（排到列表最顶端）
//
//  原理（关键）：微信内部把「折叠的群聊」实现为 **ChatBox**（见 ChatBoxMgr /
//  ChatBoxUtil / ChatBoxSessionListViewController / chatroom_session_box）。
//  它在会话列表中的位置由 ChatBoxMgr.indexOfChatBoxSession 决定，
//  位置下限由 MainSessionMgr.chatBoxMinIndex / updateChatBoxEntryMinIndex: 控制。
//  本插件通过把该索引强制为 0（即列表首位），实现「折叠的群聊」置顶。
//
//  所有 hook 点均依据微信 8.0.79 头文件逐字核对：
//
//    ChatBoxMgr.h         : indexOfChatBoxSession / isChatBoxEnable
//                           getChatBoxSession / chatBoxSessionCount
//                           updateChatBoxSession / updateChatBoxSessionWithSortTime:
//                           isContactInChatBox: / onMainFrameBeginReload
//    ChatBoxUtil.h        : isChatBox:
//    MainSessionMgr.h     : chatBoxMinIndex / setChatBoxMinIndex:
//                           updateChatBoxEntryMinIndex: / updateMainSessionList
//    MainSessionReporter.h: chatBoxMinIndex / updateChatBoxEntryMinIndex:
// ============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明（8.0.79 头文件核对）

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

@interface ChatBoxMgr : NSObject
- (BOOL)isChatBoxEnable;
- (BOOL)isContactInChatBox:(id)arg1;
- (id)getChatBoxSession;
- (id)chatBoxSession;
- (long long)indexOfChatBoxSession;
- (long long)chatBoxSessionCount;
- (void)updateChatBoxSession;
- (void)updateChatBoxSessionWithSortTime:(unsigned int)arg1;
- (void)setIsChatBoxEnable:(BOOL)arg1;
@end

@interface ChatBoxUtil : NSObject
+ (BOOL)isChatBox:(id)arg1;
+ (void)pushChatBoxListFrom:(id)arg1 complete:(id)arg2;
@end

@interface MainSessionMgr : NSObject
- (long long)chatBoxMinIndex;
- (void)setChatBoxMinIndex:(long long)arg1;
- (void)updateChatBoxEntryMinIndex:(long long)arg1;
- (void)updateMainSessionList;
@end

@interface MainSessionReporter : NSObject
- (long long)chatBoxMinIndex;
- (void)updateChatBoxEntryMinIndex:(long long)arg1;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(NSInteger)style;
- (void)clearAllSection;
- (id)getTableView;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)centerCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@property (nonatomic, retain) id userInfo;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置

static NSString *const kDDFoldEnabled = @"DDFoldTopEnabled";      // 主开关
static NSString *const kDDFoldForceEnable = @"DDFoldTopForceEnable"; // 强制启用折叠栏
static NSString *const kDDFoldSortTop = @"DDFoldTopSortTop";      // 置顶时拉高排序时间
static NSString *const kDDFoldAutoRefresh = @"DDFoldTopAutoRefresh";

@interface DDFoldConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;      // 主开关：折叠的群聊置顶
@property (nonatomic) BOOL forceEnable;  // 确保 ChatBox 处于启用态
@property (nonatomic) BOOL sortTop;      // 置顶同时拉高排序时间（防止被新消息挤下去）
@property (nonatomic) BOOL autoRefresh;  // 置顶后自动刷新列表
@end

@implementation DDFoldConfig

+ (instancetype)shared {
    static DDFoldConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _enabled = [ud objectForKey:kDDFoldEnabled] ? [ud boolForKey:kDDFoldEnabled] : NO;
        [ud setBool:_enabled forKey:kDDFoldEnabled];
        _forceEnable = [ud objectForKey:kDDFoldForceEnable] ? [ud boolForKey:kDDFoldForceEnable] : YES;
        [ud setBool:_forceEnable forKey:kDDFoldForceEnable];
        _sortTop = [ud objectForKey:kDDFoldSortTop] ? [ud boolForKey:kDDFoldSortTop] : YES;
        [ud setBool:_sortTop forKey:kDDFoldSortTop];
        _autoRefresh = [ud objectForKey:kDDFoldAutoRefresh] ? [ud boolForKey:kDDFoldAutoRefresh] : YES;
        [ud setBool:_autoRefresh forKey:kDDFoldAutoRefresh];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v {
    _enabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setForceEnable:(BOOL)v {
    _forceEnable = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldForceEnable];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setSortTop:(BOOL)v {
    _sortTop = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldSortTop];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setAutoRefresh:(BOOL)v {
    _autoRefresh = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldAutoRefresh];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 辅助

static id DD_GetService(NSString *className) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return nil;
    return [ctx getService:NSClassFromString(className)];
}

// 置顶后刷新，让新位置立即生效
static void DD_RefreshMainFrame(void) {
    if (![DDFoldConfig shared].autoRefresh) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            id mgr = DD_GetService(@"MainSessionMgr");
            if (mgr && [mgr respondsToSelector:@selector(updateMainSessionList)]) {
                [mgr performSelector:@selector(updateMainSessionList)];
            }
            id box = DD_GetService(@"ChatBoxMgr");
            if (box && [box respondsToSelector:@selector(updateChatBoxSession)]) {
                [box performSelector:@selector(updateChatBoxSession)];
            }
        } @catch (__unused NSException *e) {}
    });
}

#pragma mark - 设置界面

@interface DDFoldSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDFoldSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    WCTableViewManager *mgr = [mgrCls alloc];
    _tableViewMgr = [mgr initWithFrame:[UIScreen mainScreen].bounds
                                 style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) {
        [self ensureTableViewMgr];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"折叠置顶设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewMgr.delegate;
    self.tableViewMgr.delegate = self;
}

- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls = objc_getClass("WCTableViewSectionManager");
    if (!_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    WCTableViewSectionManager *section = [secCls defaultSection];

    [section addCell:[cellCls switchCellForSel:@selector(enabledSwitchChanged:)
                                      target:self
                                       title:@"启用折叠的群聊置顶"
                                          on:[DDFoldConfig shared].enabled]];

    if ([DDFoldConfig shared].enabled) {
        [section addCell:[cellCls switchCellForSel:@selector(forceEnableSwitchChanged:)
                                          target:self
                                           title:@"↳强制启用折叠栏"
                                              on:[DDFoldConfig shared].forceEnable]];

        [section addCell:[cellCls switchCellForSel:@selector(sortTopSwitchChanged:)
                                          target:self
                                           title:@"↳锁住排序时间防下沉"
                                              on:[DDFoldConfig shared].sortTop]];

        [section addCell:[cellCls switchCellForSel:@selector(autoRefreshSwitchChanged:)
                                          target:self
                                           title:@"↳改动后自动刷新"
                                              on:[DDFoldConfig shared].autoRefresh]];

        [section addCell:[cellCls normalCellForSel:@selector(refreshTapped:)
                                          target:self
                                           title:@"↳立即刷新列表"
                                       rightValue:@""]];
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

- (void)enabledSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].enabled = sender.isOn;
    [self buildTable];
    DD_RefreshMainFrame();
}
- (void)forceEnableSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].forceEnable = sender.isOn;
    [self buildTable];
    DD_RefreshMainFrame();
}
- (void)sortTopSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].sortTop = sender.isOn;
    [self buildTable];
    DD_RefreshMainFrame();
}
- (void)autoRefreshSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].autoRefresh = sender.isOn;
    [self buildTable];
}
- (void)refreshTapped:(id)sender {
    BOOL keep = [DDFoldConfig shared].autoRefresh;
    [DDFoldConfig shared].autoRefresh = YES;
    DD_RefreshMainFrame();
    [DDFoldConfig shared].autoRefresh = keep;
}

#pragma mark - UITableViewDelegate 转发

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

@end

#pragma mark - Hook：ChatBoxMgr（折叠栏本体，置顶核心）

%hook ChatBoxMgr

// 确保「折叠的群聊」处于启用态（未启用时置顶无意义）
- (BOOL)isChatBoxEnable {
    if ([DDFoldConfig shared].enabled && [DDFoldConfig shared].forceEnable) return YES;
    return %orig;
}

// 置顶核心：把折叠栏在会话列表中的索引强制为 0（列表首位）
- (long long)indexOfChatBoxSession {
    if ([DDFoldConfig shared].enabled) return 0;
    return %orig;
}

%end

#pragma mark - Hook：MainSessionMgr（折叠栏入口位置下限）

%hook MainSessionMgr

// 位置下限归零 → 折叠栏入口被允许排到最前
- (long long)chatBoxMinIndex {
    if ([DDFoldConfig shared].enabled) return 0;
    return %orig;
}

// 拦截位置下限的写入，锁死为 0，避免被内部逻辑改回去
- (void)updateChatBoxEntryMinIndex:(long long)index {
    if ([DDFoldConfig shared].enabled) index = 0;
    %orig(index);
}

%end

#pragma mark - Hook：MainSessionReporter（上报口径一致）

%hook MainSessionReporter

- (long long)chatBoxMinIndex {
    if ([DDFoldConfig shared].enabled) return 0;
    return %orig;
}

- (void)updateChatBoxEntryMinIndex:(long long)index {
    if ([DDFoldConfig shared].enabled) index = 0;
    %orig(index);
}

%end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        (void)[DDFoldConfig shared];

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD折叠置顶"
                                                      version:@"3.0.0"
                                                   controller:@"DDFoldSettingsViewController"];
        }
    }
}

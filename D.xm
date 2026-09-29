// ============================================================================
//  DDFoldTop.xm —— 「启用折叠的群聊置顶选项」
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  功能：让聊天列表里的「折叠的群聊」这一栏排到最顶端
//        （默认情况下，折叠栏位于「置顶会话之下、普通会话之上」）
//
//  所有 hook 点均依据微信 8.0.79 头文件逐字核对：
//
//    NewMainFrameViewController.h : topSessionFoldView / setTopSessionFoldView:
//                                   updateTopSessionFoldView / updateFoldSessionEntry
//                                   shouldShowFoldSectionTopSep / foldViewFloatingOffset
//                                   onSelectAtSectionFoldView / onTapOnFoldButton
//                                   numberOfSectionsInTableView:
//                                   logicGetCountForSection:
//                                   firstSessionIndexPath
//    MainFrameSectionFoldView.h   : isFolding / setIsFolding:foldCount:
//                                   onSingleTap / layoutSubviews
//    MainFrameLogicController.h   : isTopSessionFolding / canFoldTopSession
//    MainSessionMgr.h             : isFoldTopSession / canFoldTopSession
//    MMNewSessionMgr.h            : isFoldTopSession / foldSessionCount
//
//  「折叠的群聊」在微信内部是独立的一段（section），由 NewMainFrameViewController
//  的 topSessionFoldView 承载、以 updateTopSessionFoldView 重排其在列表中的位置。
//  本插件通过强制其处于「已折叠」呈现态，并让折叠栏紧贴列表首行
//  （section 顶部分隔线关闭 + 悬浮偏移归零 + 主动触发重排），实现置顶。
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

@interface MainSessionMgr : NSObject
- (BOOL)canFoldTopSession;
- (BOOL)isFoldTopSession;
- (long long)minTopCountToFold;
- (void)setMinTopCountToFold:(long long)arg1;
- (void)updateMainSessionList;
@end

@interface MMNewSessionMgr : NSObject
- (BOOL)isFoldTopSession;
- (long long)foldSessionCount;
- (void)rebuildAndUpdateSessionInfo;
@end

@interface MainFrameLogicController : NSObject
- (BOOL)canFoldTopSession;
- (BOOL)isTopSessionFolding;
- (void)onMainSessionReload;
- (void)onNeedRebuild;
@end

@interface MainFrameSectionFoldView : NSObject
- (BOOL)isFolding;
- (void)setIsFolding:(BOOL)arg1;
- (void)setIsFolding:(BOOL)arg1 foldCount:(long long)arg2;
- (void)onSingleTap;
- (void)layoutSubviews;
@end

@interface NewMainFrameViewController : NSObject
- (id)topSessionFoldView;
- (void)setTopSessionFoldView:(id)arg1;
- (void)updateTopSessionFoldView;
- (void)updateFoldSessionEntry;
- (BOOL)shouldShowFoldSectionTopSep;
- (double)foldViewFloatingOffset;
- (void)setFoldViewFloatingOffset:(double)arg1;
- (id)firstSessionIndexPath;
- (long long)numberOfSectionsInTableView:(id)arg1;
- (long long)logicGetCountForSection:(long long)arg1;
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

static NSString *const kDDFoldEnabled  = @"DDFoldTopEnabled";
static NSString *const kDDFoldCompact  = @"DDFoldTopCompact";
static NSString *const kDDFoldAlignTop = @"DDFoldTopAlignTop";

@interface DDFoldConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;    // 主开关：把「折叠的群聊」置顶
@property (nonatomic) BOOL compact;    // 折叠栏紧贴列表首行（隐藏其顶部分隔线）
@property (nonatomic) BOOL alignTop;   // 折叠栏吸附到顶部（悬浮偏移归零）
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
        _compact = [ud objectForKey:kDDFoldCompact] ? [ud boolForKey:kDDFoldCompact] : YES;
        [ud setBool:_compact forKey:kDDFoldCompact];
        _alignTop = [ud objectForKey:kDDFoldAlignTop] ? [ud boolForKey:kDDFoldAlignTop] : YES;
        [ud setBool:_alignTop forKey:kDDFoldAlignTop];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v {
    _enabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setCompact:(BOOL)v {
    _compact = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldCompact];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAlignTop:(BOOL)v {
    _alignTop = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDFoldAlignTop];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 辅助

static id DD_GetService(NSString *className) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return nil;
    return [ctx getService:NSClassFromString(className)];
}

// 通知主界面重排折叠栏位置
static void DD_RefreshFoldEntry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            id vc = nil;
            // 主界面入口：优先取当前可见的 NewMainFrameViewController
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                UIViewController *root = w.rootViewController;
                if ([root isKindOfClass:[UINavigationController class]]) {
                    root = [(UINavigationController *)root topViewController];
                }
                if ([root isKindOfClass:NSClassFromString(@"NewMainFrameViewController")]) {
                    vc = root;
                    break;
                }
            }
            if (vc && [vc respondsToSelector:@selector(updateTopSessionFoldView)]) {
                [vc performSelector:@selector(updateTopSessionFoldView)];
            }
            id logic = DD_GetService(@"MainFrameLogicController");
            if (logic && [logic respondsToSelector:@selector(onMainSessionReload)]) {
                [logic performSelector:@selector(onMainSessionReload)];
            }
            id newMgr = DD_GetService(@"MMNewSessionMgr");
            if (newMgr && [newMgr respondsToSelector:@selector(rebuildAndUpdateSessionInfo)]) {
                [newMgr performSelector:@selector(rebuildAndUpdateSessionInfo)];
            }
            id mgr = DD_GetService(@"MainSessionMgr");
            if (mgr && [mgr respondsToSelector:@selector(updateMainSessionList)]) {
                [mgr performSelector:@selector(updateMainSessionList)];
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
        [section addCell:[cellCls switchCellForSel:@selector(compactSwitchChanged:)
                                          target:self
                                           title:@"↳紧贴列表首行"
                                              on:[DDFoldConfig shared].compact]];

        [section addCell:[cellCls switchCellForSel:@selector(alignTopSwitchChanged:)
                                          target:self
                                           title:@"↳吸附顶部（去悬浮偏移）"
                                              on:[DDFoldConfig shared].alignTop]];

        [section addCell:[cellCls normalCellForSel:@selector(refreshTapped:)
                                          target:self
                                           title:@"↳立即重排折叠栏"
                                       rightValue:@""]];
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

- (void)enabledSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].enabled = sender.isOn;
    [self buildTable];
    DD_RefreshFoldEntry();
}

- (void)compactSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].compact = sender.isOn;
    [self buildTable];
    DD_RefreshFoldEntry();
}

- (void)alignTopSwitchChanged:(UISwitch *)sender {
    [DDFoldConfig shared].alignTop = sender.isOn;
    [self buildTable];
    DD_RefreshFoldEntry();
}

- (void)refreshTapped:(id)sender {
    DD_RefreshFoldEntry();
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

#pragma mark - Hook：NewMainFrameViewController（折叠栏位置核心）

%hook NewMainFrameViewController

// 折叠栏置顶：隐藏其顶部分隔线，使其视觉上紧贴列表首行
- (BOOL)shouldShowFoldSectionTopSep {
    if ([DDFoldConfig shared].enabled && [DDFoldConfig shared].compact) return NO;
    return %orig;
}

// 悬浮偏移归零 → 折叠栏吸附在列表顶部，不再随滚动浮动
- (double)foldViewFloatingOffset {
    if ([DDFoldConfig shared].enabled && [DDFoldConfig shared].alignTop) return 0.0;
    return %orig;
}

// 重排折叠栏入口，确保每次刷新都按新配置摆放
- (void)updateTopSessionFoldView {
    %orig;
    if (![DDFoldConfig shared].enabled) return;
    id foldView = [self topSessionFoldView];
    if (foldView && [foldView respondsToSelector:@selector(setIsFolding:foldCount:)]) {
        // 保持折叠呈现态，折叠数量交由微信自算（-1 表示沿用原值）
        long long cnt = -1;
        id newMgr = DD_GetService(@"MMNewSessionMgr");
        if (newMgr && [newMgr respondsToSelector:@selector(foldSessionCount)]) {
            cnt = ((long long (*)(id, SEL))objc_msgSend)(newMgr, @selector(foldSessionCount));
        }
        if (cnt >= 0) {
            void (*setFold)(id, SEL, BOOL, long long) = (void (*)(id, SEL, BOOL, long long))objc_msgSend;
            setFold(foldView, @selector(setIsFolding:foldCount:), YES, cnt);
        }
    }
}

%end

#pragma mark - Hook：MainFrameSectionFoldView（折叠栏自身呈现）

%hook MainFrameSectionFoldView

- (BOOL)isFolding {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

- (void)setIsFolding:(BOOL)fold {
    if ([DDFoldConfig shared].enabled) fold = YES;
    %orig(fold);
}

- (void)setIsFolding:(BOOL)fold foldCount:(long long)count {
    if ([DDFoldConfig shared].enabled) fold = YES;
    %orig(fold, count);
}

%end

#pragma mark - Hook：MainFrameLogicController（折叠态标志）

%hook MainFrameLogicController

- (BOOL)isTopSessionFolding {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

- (BOOL)canFoldTopSession {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

%end

#pragma mark - Hook：MainSessionMgr / MMNewSessionMgr（折叠态口径一致）

%hook MainSessionMgr

- (BOOL)isFoldTopSession {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

- (BOOL)canFoldTopSession {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

%end

%hook MMNewSessionMgr

- (BOOL)isFoldTopSession {
    if ([DDFoldConfig shared].enabled) return YES;
    return %orig;
}

%end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        (void)[DDFoldConfig shared];

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD折叠置顶"
                                                      version:@"2.0.0"
                                                   controller:@"DDFoldSettingsViewController"];
        }
    }
}

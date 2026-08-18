// DDAdBlockTweak.xm

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ========== 插件管理入口 ==========
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// ========== 配置类（4个独立开关） ==========
static NSString * const kDDAdBlockTimelineKey = @"DDAdBlock_Timeline";
static NSString * const kDDAdBlockBrandKey    = @"DDAdBlock_Brand";
static NSString * const kDDAdBlockFinderKey   = @"DDAdBlock_Finder";
static NSString * const kDDAdBlockMiniAppKey  = @"DDAdBlock_MiniApp";

@interface DDAdBlockConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL blockTimeline;
@property (assign, nonatomic) BOOL blockBrand;
@property (assign, nonatomic) BOOL blockFinder;
@property (assign, nonatomic) BOOL blockMiniApp;
@end

@implementation DDAdBlockConfig

+ (instancetype)sharedConfig {
    static DDAdBlockConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDAdBlockConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        if ([ud objectForKey:kDDAdBlockTimelineKey] == nil) [ud setBool:YES forKey:kDDAdBlockTimelineKey];
        if ([ud objectForKey:kDDAdBlockBrandKey] == nil)    [ud setBool:YES forKey:kDDAdBlockBrandKey];
        if ([ud objectForKey:kDDAdBlockFinderKey] == nil)   [ud setBool:YES forKey:kDDAdBlockFinderKey];
        if ([ud objectForKey:kDDAdBlockMiniAppKey] == nil)  [ud setBool:YES forKey:kDDAdBlockMiniAppKey];
        _blockTimeline = [ud boolForKey:kDDAdBlockTimelineKey];
        _blockBrand    = [ud boolForKey:kDDAdBlockBrandKey];
        _blockFinder   = [ud boolForKey:kDDAdBlockFinderKey];
        _blockMiniApp  = [ud boolForKey:kDDAdBlockMiniAppKey];
    }
    return self;
}

- (void)setBlockTimeline:(BOOL)value {
    _blockTimeline = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockTimelineKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockBrand:(BOOL)value {
    _blockBrand = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockBrandKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockFinder:(BOOL)value {
    _blockFinder = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockFinderKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockMiniApp:(BOOL)value {
    _blockMiniApp = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockMiniAppKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// ========== 核心 Hook ==========

// 1. 朋友圈广告（阻止广告数据存储）
%hook WCAdvertiseStorage
- (void)setOAdvertiseData:(NSData *)oAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)setNsAdvertiseID:(NSString *)nsAdvertiseID {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
%end

// 2. 公众号广告
// 2.1 实验开关强制返回“不显示广告”
%hook BrandTLExptConfig
- (BOOL)isExptNotShowAd {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
%end

// 2.2 阻止广告XML解析
%hook WCAdXmlParser
+ (BOOL)SetAdvertiseInfo:(id)arg1 ByAdInfo:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (BOOL)SetAdvertiseXml:(id)arg1 ByAdXml:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
%end

// 2.3 阻止广告数据存储与读取
%hook WCAdDB
- (id)fetchPullRecordList:(unsigned int)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return @[];
    return %orig;
}
- (void)savePullRecordInfo:(id)arg1 sessionKey:(id)arg2 isAsync:(BOOL)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// 3. 视频号去广告
// 3.1 视频号评论广告
%hook WCFinderComment
- (id)advertisementInfo {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)promotionInfo {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
%end

// 3.2 视频流广告标识
%hook WCFinderDataItem
- (unsigned long long)adFlag {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0;
    return %orig;
}
%end

// 4. 小程序启动广告
%hook WAAppTask
- (void)splashAD_handleShouldShowEvent {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
- (void)splashAD_createSplashADWindow {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook WAJSEventHandler_showSplashAd
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook WAJSEventHandler_showSplashAdMenu
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

// ========== 设置界面 ==========
@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

// 设置视图控制器
@interface DDAdBlockSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDAdBlockSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD广告屏蔽设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    Class managerCls = %c(WCTableViewManager);
    _tableViewManager = [[managerCls alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];
    
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    
    Class sectionCls = %c(WCTableViewSectionManager);
    Class cellCls = %c(WCTableViewCellManager);
    
    WCTableViewSectionManager *section = [sectionCls sectionWithHeader:@""];
    DDAdBlockConfig *cfg = [DDAdBlockConfig sharedConfig];
    
    [section addCell:[cellCls switchCellForSel:@selector(onTimelineSwitch:) target:self title:@"屏蔽朋友圈广告" on:cfg.blockTimeline]];
    [section addCell:[cellCls switchCellForSel:@selector(onBrandSwitch:) target:self title:@"屏蔽公众号广告" on:cfg.blockBrand]];
    [section addCell:[cellCls switchCellForSel:@selector(onFinderSwitch:) target:self title:@"屏蔽视频号广告" on:cfg.blockFinder]];
    [section addCell:[cellCls switchCellForSel:@selector(onMiniAppSwitch:) target:self title:@"屏蔽小程序广告" on:cfg.blockMiniApp]];
    
    [_tableViewManager addSection:section];
    [_tableViewManager reloadTableView];
}

- (void)onTimelineSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockTimeline = sender.isOn;
}
- (void)onBrandSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockBrand = sender.isOn;
}
- (void)onFinderSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockFinder = sender.isOn;
}
- (void)onMiniAppSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockMiniApp = sender.isOn;
}

@end

// ========== 插件注册 ==========
%ctor {
    @autoreleasepool {
        Class mgrClass = NSClassFromString(@"WCPluginsMgr");
        if (mgrClass) {
            id mgr = [mgrClass sharedInstance];
            if ([mgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
                [mgr registerControllerWithTitle:@"DD广告屏蔽"
                                         version:@"1.0.0"
                                      controller:@"DDAdBlockSettingsViewController"];
            }
        }
    }
}
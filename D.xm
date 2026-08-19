// DD添加好友精确时间 v1.0.0 —— 联系人详情页显示好友精确添加时间

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
+ (id)sectionInfoHeader:(NSString *)header;
- (void)addCell:(id)arg1;
@property(retain, nonatomic) NSMutableArray *cells;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
@end

@interface CContact : NSObject
@property(nonatomic) unsigned int m_uiAddCreateTime;
@end

@interface SocialInfomationViewController : UIViewController
@property(retain, nonatomic) CContact *m_contact;
- (void)addContactAddCreateTimeCellAtSection:(id)section;
@end

// 普通 cell 管理器
@interface WCTableViewCellRightConfig : NSObject
@property(copy, nonatomic) NSString *detail;
@end

@interface WCTableViewCellNormalConfig : NSObject
@property(retain, nonatomic) WCTableViewCellRightConfig *rightConfig;
@end

@interface WCTableViewNormalCellManager : NSObject
@property(retain, nonatomic) WCTableViewCellNormalConfig *cellConfig;
@end

#pragma mark - 配置

static NSString * const kDDAddTimeConfigKey = @"DDAddTimeConfig";
static NSString * const kDDAddTimeEnable     = @"enableAddTime";

@interface DDAddTimeConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)enableAddTime;
- (BOOL)hasEnableAddTime;
@end

@implementation DDAddTimeConfig

+ (instancetype)shared {
    static DDAddTimeConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDAddTimeConfig new]; });
    return cfg;
}

- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDAddTimeConfigKey];
    return [cfg isKindOfClass:[NSDictionary class]] ? cfg : @{};
}

- (void)setValue:(id)value forConfigKey:(NSString *)key {
    NSMutableDictionary *cfg = [[self config] mutableCopy];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (value) {
        [cfg setValue:value forKey:key];
    } else {
        [cfg removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDAddTimeConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 默认开启（未设置时视为开启）
- (BOOL)enableAddTime {
    NSNumber *val = [self.config objectForKey:kDDAddTimeEnable];
    return val ? val.boolValue : YES;
}
- (BOOL)hasEnableAddTime { return [self.config objectForKey:kDDAddTimeEnable] != nil; }

@end

#pragma mark - 插件主逻辑

%hook SocialInfomationViewController

- (void)addContactAddCreateTimeCellAtSection:(id)section {
    NSUInteger beforeCount = 0;
    if ([section respondsToSelector:@selector(cells)]) {
        beforeCount = ((WCTableViewSectionManager *)section).cells.count;
    }

    %orig;

    if (!DDAddTimeConfig.shared.enableAddTime) return;

    CContact *contact = self.m_contact;
    if (!contact) return;
    if (![contact respondsToSelector:@selector(m_uiAddCreateTime)]) return;

    unsigned int addTime = contact.m_uiAddCreateTime;
    if (addTime == 0) return;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:addTime];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString *timeString = [formatter stringFromDate:date];

    if (![section respondsToSelector:@selector(cells)]) return;
    WCTableViewSectionManager *sec = (WCTableViewSectionManager *)section;
    NSArray *cells = sec.cells;
    if (cells.count == 0) return;

    Class normalCls = objc_getClass("WCTableViewNormalCellManager");
    NSUInteger startIdx = beforeCount < cells.count ? beforeCount : cells.count;

    for (NSUInteger i = startIdx; i < cells.count; i++) {
        id cell = cells[i];
        if (!normalCls || ![cell isKindOfClass:normalCls]) continue;
        WCTableViewNormalCellManager *normalCell = (WCTableViewNormalCellManager *)cell;

        WCTableViewCellNormalConfig *cellConfig = normalCell.cellConfig;
        if (!cellConfig) continue;
        WCTableViewCellRightConfig *rightConfig = cellConfig.rightConfig;
        if (!rightConfig) continue;

        NSString *detail = rightConfig.detail;
        if (detail.length == 0) continue;

        rightConfig.detail = timeString;
    }
}

%end

#pragma mark - 设置界面

@interface DDAddTimeSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDAddTimeSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    if (!mgrCls) return;
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
    self.title = @"DD添加好友精确时间";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    DDAddTimeConfig *cfg = DDAddTimeConfig.shared;

    WCTableViewSectionManager *sec = [secCls defaultSection];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleAddTime:)
                                     target:self
                                      title:@"显示好友添加时间"
                                         on:cfg.enableAddTime]];
    [self.tableViewMgr addSection:sec];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleAddTime:(UISwitch *)sender {
    [DDAddTimeConfig.shared setValue:sender.isOn ? @(1) : @(0)
                       forConfigKey:kDDAddTimeEnable];
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD添加好友精确时间"
                                                      version:@"1.0.0"
                                                   controller:@"DDAddTimeSettingsViewController"];
        }
    }
}

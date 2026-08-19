// DD显示原始wxid v1.0.0 —— 联系人详情页显示原始 wxid，支持长按复制

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
@property(retain, nonatomic) NSMutableArray *sections;
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface MMTableViewInfo : WCTableViewManager
@end

@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
+ (id)defaultSection;
+ (id)sectionInfoHeader:(NSString *)header;
- (void)addCell:(id)arg1;
- (void)insertCell:(id)arg1 At:(unsigned int)arg2;
- (unsigned long long)getCellCount;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4 canRightValueCopy:(_Bool)arg5;
@end

@interface CContact : NSObject
@property(nonatomic, readonly) NSString *userName;
@end

@interface SocialInfomationViewController : UIViewController
@property(retain, nonatomic) CContact *m_contact;
@property(retain, nonatomic) MMTableViewInfo *m_tableViewInfo;
@end

#pragma mark - 配置

static NSString * const kDDShowWxidConfigKey = @"DDShowWxidConfig";
static NSString * const kDDShowWxidEnable     = @"enableShowWxid";

@interface DDShowWxidConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)enableShowWxid;
- (BOOL)hasEnableShowWxid;
@end

@implementation DDShowWxidConfig

+ (instancetype)shared {
    static DDShowWxidConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDShowWxidConfig new]; });
    return cfg;
}

- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDShowWxidConfigKey];
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
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDShowWxidConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)enableShowWxid {
    NSNumber *val = [self.config objectForKey:kDDShowWxidEnable];
    return val ? val.boolValue : NO;
}
- (BOOL)hasEnableShowWxid { return [self.config objectForKey:kDDShowWxidEnable] != nil; }

@end

#pragma mark - 插件主逻辑

%hook SocialInfomationViewController

- (void)viewDidLoad {
    %orig;

    if (!DDShowWxidConfig.shared.enableShowWxid) return;

    CContact *contact = self.m_contact;
    if (!contact) return;
    if (![contact respondsToSelector:@selector(userName)]) return;

    NSString *wxid = contact.userName;
    if (!wxid || wxid.length == 0) return;

    MMTableViewInfo *tableInfo = self.m_tableViewInfo;
    if (!tableInfo) return;
    if (![tableInfo respondsToSelector:@selector(sections)]) return;

    NSMutableArray *sections = tableInfo.sections;
    if (sections.count == 0) return;

    id section = sections[0];
    if (!section) return;
    Class secCls = objc_getClass("WCTableViewSectionManager");
    if (!secCls || ![section isKindOfClass:secCls]) return;
    if (![section respondsToSelector:@selector(cells)]) return;

    WCTableViewSectionManager *firstSection = (WCTableViewSectionManager *)section;

    id cellCls = objc_getClass("WCTableViewCellManager");
    if (!cellCls) return;

    id cell = [cellCls normalCellForSel:@selector(ddWxidCellTapped:)
                                 target:self
                                  title:@"用户ID："
                             rightValue:wxid
                      canRightValueCopy:YES];
    if (!cell) return;

    if ([firstSection respondsToSelector:@selector(addCell:)]) {
        [firstSection addCell:cell];
    }

    if ([tableInfo respondsToSelector:@selector(reloadTableView)]) {
        [tableInfo reloadTableView];
    }
}

%new
- (void)ddWxidCellTapped:(id)sender {
    // 点击回调，长按复制已由 canRightValueCopy 处理
}

%end

#pragma mark - 设置界面

@interface DDShowWxidSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDShowWxidSettingsViewController

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
    self.title = @"DD显示原始wxid";
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
    DDShowWxidConfig *cfg = DDShowWxidConfig.shared;

    WCTableViewSectionManager *sec = [secCls defaultSection];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleShowWxid:)
                                     target:self
                                      title:@"显示原始wxid"
                                         on:cfg.hasEnableShowWxid]];
    [self.tableViewMgr addSection:sec];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleShowWxid:(UISwitch *)sender {
    [DDShowWxidConfig.shared setValue:sender.isOn ? @(1) : @(0)
                       forConfigKey:kDDShowWxidEnable];
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD显示原始wxid"
                                                      version:@"1.0.0"
                                                   controller:@"DDShowWxidSettingsViewController"];
        }
    }
}

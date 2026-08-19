// DD显示原始wxid v1.0.0 —— 聊天窗口发送指令 /ID 获取当前会话原始 ID
// 支持：单聊联系人、群聊、公众号、服务号

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

// 所有聊天会话（单聊/群聊/公众号/服务号）的公共基类
@interface BaseMsgContentLogicController : NSObject
@property(retain, nonatomic) CBaseContact *m_contact;
- (void)SendTextMessage:(NSString *)text;
@end

// 微信原生确认弹窗
@interface WCUIAlertView : NSObject
+ (id)showAlertWithTitle:(NSString *)title message:(NSString *)message
          cancelBtnTitle:(NSString *)cancel handler:(void (^)(id alert))cancelHandler
                btnTitle:(NSString *)btn handler:(void (^)(id alert))btnHandler;
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

// 判断文本是否等于 /ID（大小写不敏感）
static BOOL ddIsIdCommand(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return NO;
    if ([trimmed caseInsensitiveCompare:@"/ID"] == NSOrderedSame) return YES;
    return NO;
}

%hook BaseMsgContentLogicController

- (void)SendTextMessage:(NSString *)text {
    // 开关关闭则正常发送
    if (!DDShowWxidConfig.shared.enableShowWxid) {
        %orig;
        return;
    }

    // 非 /ID 指令正常发送
    if (!ddIsIdCommand(text)) {
        %orig;
        return;
    }

    // 命中 /ID 指令：不发送，获取当前会话原始 ID 并展示
    CBaseContact *contact = self.m_contact;
    NSString *wxid = nil;
    if (contact && [contact respondsToSelector:@selector(m_nsUsrName)]) {
        wxid = contact.m_nsUsrName;
    }
    if (!wxid || wxid.length == 0) {
        wxid = @"未获取到 ID";
    }

    // 微信原生弹窗展示原始 ID，提供「复制」「取消」两个按钮
    Class alertCls = objc_getClass("WCUIAlertView");
    if (!alertCls) return;
    if (![alertCls respondsToSelector:@selector(showAlertWithTitle:message:cancelBtnTitle:handler:btnTitle:handler:)]) return;

    [alertCls showAlertWithTitle:@"原始ID"
                         message:wxid
                  cancelBtnTitle:@"取消"
                         handler:nil
                        btnTitle:@"复制"
                         handler:^(id alert) {
        [UIPasteboard generalPasteboard].string = wxid;
    }];
}

%end

#pragma mark - 设置界面

@interface WCTableViewManager : NSObject
@property(retain, nonatomic) NSMutableArray *sections;
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
+ (id)defaultSection;
- (void)addCell:(id)arg1;
- (unsigned long long)getCellCount;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
@end

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
                                      title:@"/ID指令"
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

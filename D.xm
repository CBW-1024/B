#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ========== 微信内部类声明 ==========

// 插件管理器
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 消息封装
@interface CMessageWrap : NSObject
@property (retain, nonatomic) NSString *m_nsContent;
@property (assign, nonatomic) unsigned int m_uiMessageType;
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
@end

// 消息管理器
@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end

// WCActionSheet（只声明需要的方法）
@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title;
- (void)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))eventAction;
- (void)showInView:(UIView *)view;
@end

// 设置界面相关
@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
- (UITableView *)getTableView;
- (void)addSection:(id)section;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (instancetype)defaultSection;
- (void)addCell:(id)cell;
@property (copy, nonatomic) NSString *footerTitle;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

// ========== 配置管理 ==========

static NSString * const kDDShowWxidConfigKey = @"DDShowWxidConfig";
static NSString * const kDDShowWxidEnable   = @"enableShowWxid";

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
- (BOOL)hasEnableShowWxid {
    return [self.config objectForKey:kDDShowWxidEnable] != nil;
}

@end

// ========== 工具函数 ==========

// 判断文本是否为 /WXID 指令（忽略大小写，去除首尾空白）
static BOOL ddIsWxidCommand(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return NO;
    return [trimmed caseInsensitiveCompare:@"/WXID"] == NSOrderedSame;
}

// 弹窗展示原始 ID（使用 WCActionSheet，只含「复制」按钮，无取消）
static BOOL ddShowWxidAlert(NSString *title, NSString *message) {
    if (!message.length) message = @"未获取到 ID";
    Class actionSheetCls = NSClassFromString(@"WCActionSheet");
    if (!actionSheetCls) return NO;

    NSString *fullTitle = [NSString stringWithFormat:@"原始ID\n%@", message];
    id sheet = [[actionSheetCls alloc] initWithTitle:fullTitle];
    if (!sheet) return NO;

    [sheet addButtonWithTitle:@"复制" eventAction:^{
        [UIPasteboard generalPasteboard].string = message;
    }];

    // 直接取第一个 window（不判空，用户确认一定存在）
    [sheet showInView:[UIApplication sharedApplication].windows.firstObject];
    return YES;
}

// ========== Hook 消息发送 ==========

%hook CMessageMgr

- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;
    @try {
        if (DDShowWxidConfig.shared.enableShowWxid) {
            // 判断是否为自己发出的文本消息，且内容为 /WXID
            if ([CMessageWrap isSenderFromMsgWrap:wrap] &&
                wrap.m_uiMessageType == 1 &&
                ddIsWxidCommand(wrap.m_nsContent)) {
                // 原始 ID 优先使用 usr 参数（即会话对象），否则取 m_nsToUsr
                NSString *rawId = usr.length ? usr : wrap.m_nsToUsr;
                if (!rawId.length) rawId = @"未获取到 ID";
                ddShowWxidAlert(@"原始ID", rawId);
                shouldSend = NO; // 拦截，不发送
            }
        }
    } @catch (NSException *e) {
        // 异常时放行，不影响正常收发
    }
    if (shouldSend) {
        %orig;
    }
}

%end

// ========== 设置界面 ==========

@interface DDShowWxidSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDShowWxidSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD显示WXID";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    Class mgrCls = NSClassFromString(@"WCTableViewManager");
    if (mgrCls) {
        _tableViewMgr = [[mgrCls alloc] initWithFrame:self.view.bounds
                                                 style:UITableViewStyleInsetGrouped];
        UITableView *tableView = [_tableViewMgr getTableView];
        tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
        [self.view addSubview:tableView];
        [self buildTable];
    }
}

- (void)buildTable {
    if (!_tableViewMgr) return;
    [_tableViewMgr clearAllSection];

    DDShowWxidConfig *cfg = DDShowWxidConfig.shared;
    Class secCls = NSClassFromString(@"WCTableViewSectionManager");
    Class cellCls = NSClassFromString(@"WCTableViewCellManager");

    WCTableViewSectionManager *section = [secCls defaultSection];
    [section addCell:[cellCls switchCellForSel:@selector(toggleShowWxid:)
                                        target:self
                                         title:@"启用指令显示ID"
                                            on:cfg.hasEnableShowWxid]];
    section.footerTitle = @"聊天(联系人/群聊/公众号/服务号)发送指令:/WXID";
    [_tableViewMgr addSection:section];
    [_tableViewMgr reloadTableView];
}

- (void)toggleShowWxid:(UISwitch *)sender {
    [DDShowWxidConfig.shared setValue:sender.isOn ? @(1) : @(0)
                       forConfigKey:kDDShowWxidEnable];
    [self buildTable];
}

@end

// ========== 插件注册 ==========

%ctor {
    @autoreleasepool {
        Class mgrCls = NSClassFromString(@"WCPluginsMgr");
        if (mgrCls && [mgrCls respondsToSelector:@selector(sharedInstance)]) {
            [[mgrCls sharedInstance] registerControllerWithTitle:@"DD显示原始ID"
                                                         version:@"1.0.0"
                                                      controller:@"DDShowWxidSettingsViewController"];
        }
    }
}
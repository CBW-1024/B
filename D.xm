// DD显示原始ID —— 聊天窗口发送 /WXID 获取当前会话原始 ID

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 微信私有接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 消息封装
@interface CMessageWrap : NSObject
@property(retain, nonatomic) NSString *m_nsContent;
@property(nonatomic) unsigned int m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
@end

// 消息管理器（统一出口）
@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end

// 微信原生 ActionSheet（自带取消按钮，无需手动添加）
@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title;
- (long long)addCustomViewWithTitle:(NSString *)title fontSize:(CGFloat)fontSize fontColor:(UIColor *)fontColor
                           WithDesc:(NSString *)desc descFontSize:(CGFloat)descFontSize descFontColor:(UIColor *)descFontColor
                             enable:(BOOL)enable;
- (long long)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))action;
- (void)showInView:(UIView *)view;
@end

// 配置
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

// 判断是否 /WXID 指令
static BOOL ddIsWxidCommand(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return NO;
    return [trimmed caseInsensitiveCompare:@"/WXID"] == NSOrderedSame;
}

// 获取当前前台活跃窗口（iOS 13+ 多场景，避免使用已废弃的 keyWindow）
static UIWindow *ddCurrentKeyWindow(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *winScene = (UIWindowScene *)scene;
            if (winScene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in winScene.windows) {
                if (w.isKeyWindow) { window = w; break; }
            }
            if (window) break;
        }
        // 兜底：取前台场景第一个窗口
        if (!window) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:UIWindowScene.class]) {
                    UIWindowScene *winScene = (UIWindowScene *)scene;
                    if (winScene.activationState != UISceneActivationStateForegroundActive) continue;
                    window = winScene.windows.firstObject;
                    if (window) break;
                }
            }
        }
    }
    return window;
}

// 微信原生 ActionSheet 展示，含「复制」按钮（取消按钮 WCActionSheet 自带）
static BOOL ddShowWxidAlert(NSString *title, NSString *message) {
    if (!message.length) message = @"未获取到 ID";
    Class sheetCls = NSClassFromString(@"WCActionSheet");
    if (!sheetCls) return NO;
    if (![sheetCls instancesRespondToSelector:@selector(initWithTitle:)]) return NO;

    @try {
        id sheet = [[sheetCls alloc] initWithTitle:title];
        if (!sheet) return NO;
        // 展示 ID 内容
        if ([sheet respondsToSelector:@selector(addCustomViewWithTitle:fontSize:fontColor:WithDesc:descFontSize:descFontColor:enable:)]) {
            [sheet addCustomViewWithTitle:message fontSize:16.0 fontColor:[UIColor blackColor]
                                 WithDesc:nil descFontSize:0 descFontColor:nil enable:YES];
        }
        if ([sheet respondsToSelector:@selector(addButtonWithTitle:eventAction:)]) {
            [sheet addButtonWithTitle:@"复制" eventAction:^{
                [UIPasteboard generalPasteboard].string = message;
            }];
        }
        if ([sheet respondsToSelector:@selector(showInView:)]) {
            UIWindow *targetWindow = ddCurrentKeyWindow();
            if (!targetWindow) return NO;
            [sheet showInView:targetWindow];
            return YES;
        }
    } @catch (NSException *e) {
        // 忽略异常
    }
    return NO;
}

%hook CMessageMgr

// 拦截点：命中自己发出的文本 /WXID，弹面板展示原始 ID，不发送
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;
    @try {
        if (DDShowWxidConfig.shared.enableShowWxid) {
            Class wrapCls = objc_getClass("CMessageWrap");
            BOOL isOutgoing = (wrapCls && [wrapCls respondsToSelector:@selector(isSenderFromMsgWrap:)])
                ? (BOOL)[wrapCls isSenderFromMsgWrap:wrap] : NO;
            if (isOutgoing && wrap && wrap.m_uiMessageType == 1 && ddIsWxidCommand(wrap.m_nsContent)) {
                NSString *rawId = usr.length ? usr : wrap.m_nsToUsr;
                if (!rawId.length) rawId = @"未获取到 ID";
                ddShowWxidAlert(@"原始ID", rawId);
                shouldSend = NO;
            }
        }
    } @catch (NSException *e) {
        // 异常不影响正常收发
    }
    if (shouldSend) {
        %orig;
    }
}

%end

// 设置界面
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
@property(copy, nonatomic) NSString *footerTitle;
+ (id)defaultSection;
- (void)addCell:(id)arg1;
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
    self.title = @"DD显示WXID";
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
                                      title:@"启用指令显示ID"
                                         on:cfg.hasEnableShowWxid]];
    if ([sec respondsToSelector:@selector(setFooterTitle:)]) {
        [sec setFooterTitle:@"聊天(联系人/群聊/公众号/服务号)发送指令:/WXID"];
    }
    [self.tableViewMgr addSection:sec];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleShowWxid:(UISwitch *)sender {
    [DDShowWxidConfig.shared setValue:sender.isOn ? @(1) : nil
                       forConfigKey:kDDShowWxidEnable];
    [self buildTable];
}

@end

// 注册入口
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD显示原始ID"
                                                      version:@"1.0.0"
                                                   controller:@"DDShowWxidSettingsViewController"];
        }
    }
}

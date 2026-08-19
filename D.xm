// DD显示原始wxid v1.0.0 —— 聊天窗口发送指令 /WXID 获取当前会话原始 ID
// 支持：单聊联系人、群聊、公众号、服务号
//
// 拦截原理（对齐参考的抖音解析插件）：
//   微信所有消息（单聊/群聊/公众号/服务号）真正入库发送的统一出口是
//   CMessageMgr AddMsg:MsgWrap:。hook 它，命中 /WXID 指令时直接 return
//   不调用 %orig（消息被吞、不发出去），用微信原生面板展示原始 ID。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信消息封装（对齐参考插件的 CMessageWrap 声明）
@interface CMessageWrap : NSObject
@property (retain, nonatomic) NSString *m_nsContent;   // 消息文本内容
@property (nonatomic) unsigned int m_uiMessageType;    // 1 = 文本
@property (retain, nonatomic) NSString *m_nsFromUsr;   // 发送者
@property (retain, nonatomic) NSString *m_nsToUsr;     // 接收者（会话对象）
// 判断该消息是否「自己发出」（对齐参考实现）
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
@end

// 微信消息管理器：所有消息真正入库发送的统一出口
@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end

// 微信原生提示面板 MMTipsViewController（接口对齐真实头文件）
// 构造：initWithTitle:message:btnTitle:handler:(block)，按钮「复制」点击直接写入剪贴板
// 展示：- show（内部自寻顶层 VC present）
@interface MMTipsViewController : UIViewController
- (id)initWithTitle:(NSString *)title message:(NSString *)message btnTitle:(NSString *)btnTitle handler:(id)handler;
- (void)show;
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

// 判断文本是否等于 /WXID（大小写不敏感）
static BOOL ddIsWxidCommand(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return NO;
    if ([trimmed caseInsensitiveCompare:@"/WXID"] == NSOrderedSame) return YES;
    return NO;
}

// 用微信原生 MMTipsViewController 展示原始 ID（唯一路径，无兜底）。
// 返回 YES 表示面板已成功弹出（消息应被拦截）。
static BOOL ddShowWxidAlert(NSString *title, NSString *message) {
    if (!message.length) message = @"未获取到 ID";
    Class tipsCls = NSClassFromString(@"MMTipsViewController");
    if (!tipsCls) return NO;
    if (![tipsCls instancesRespondToSelector:@selector(initWithTitle:message:btnTitle:handler:)]) return NO;

    @try {
        id tips = [[tipsCls alloc] initWithTitle:title message:message btnTitle:@"复制"
            handler:^{ [UIPasteboard generalPasteboard].string = message; }];
        if (!tips) return NO;
        if (![tips respondsToSelector:@selector(show)]) return NO;
        [tips show];
        return YES;
    } @catch (NSException *e) {
        // 不拦截，按正常消息发送（绝不让异常吞掉消息）
        return NO;
    }
}

%hook CMessageMgr

// 真正拦截点：微信所有消息入库发送的统一出口。
// 命中自己发出的文本 /WXID 指令 → 弹面板展示原始 ID，直接 return 不调 %orig（消息被吞、不发出去）
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;   // 默认正常发送
    @try {
        // 开关开启才拦截
        if (DDShowWxidConfig.shared.enableShowWxid) {
            // 只处理自己发出的文本消息（对齐参考：isSenderFromMsgWrap:）
            Class wrapCls = objc_getClass("CMessageWrap");
            BOOL isOutgoing = (wrapCls && [wrapCls respondsToSelector:@selector(isSenderFromMsgWrap:)])
                ? (BOOL)[wrapCls isSenderFromMsgWrap:wrap] : NO;
            if (isOutgoing && wrap && wrap.m_uiMessageType == 1 && ddIsWxidCommand(wrap.m_nsContent)) {
                // 命中 /WXID 指令：拦截消息（不发送），展示当前会话原始 ID。
                // usr 是 AddMsg 的会话对象：单聊=对方原始 wxid，群聊=群 ID，公众号/服务号=对应 ID
                NSString *rawId = usr.length ? usr : wrap.m_nsToUsr;
                if (!rawId.length) rawId = @"未获取到 ID";
                // 用微信原生 MMTipsViewController 展示（唯一路径，无兜底）
                ddShowWxidAlert(@"原始ID", rawId);
                shouldSend = NO;   // 指令绝不发出（不外泄）
            }
        }
    } @catch (NSException *e) {
        // 任何异常都不影响正常收发
    }
    if (shouldSend) {
        %orig;
    }
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
+ (id)normalCellForTitle:(NSString *)title;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
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
                                      title:@"/WXID指令"
                                         on:cfg.hasEnableShowWxid]];
    // 使用说明
    if ([cellCls respondsToSelector:@selector(normalCellForTitle:)]) {
        [sec addCell:[cellCls normalCellForTitle:@"聊天窗口发送指令/WXID"]];
    } else if ([cellCls respondsToSelector:@selector(normalCellForSel:target:title:)]) {
        [sec addCell:[cellCls normalCellForSel:NULL target:self title:@"聊天窗口发送指令/WXID"]];
    }
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

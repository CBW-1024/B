// DDTR - 转账自动收款 + 自动回复

// 延迟收款秒数：点击展开下拉选择（centerCellForSel: 居中、无右侧箭头），4个秒数选项 [x.x秒]；父级行（延迟收款秒数/启用自动回复/自定义回复）
// 自定义回复：输入框 + 确认按钮（rightView，无箭头）
// 回复内容为空时等于不自动回复；全部基于微信76 头文件核对

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

#pragma mark - 微信类声明

@interface WCPayInfoItem : NSObject
@property (retain, nonatomic) NSString *m_c2cNativeUrl;
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (nonatomic) unsigned int m_c2cPayReceiveStatus;
@property (nonatomic) unsigned int m_uiInvalidTime;
@property (retain, nonatomic) NSString *transfer_attach;
@end

@interface CMessageWrap : NSObject
@property (retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@property (retain, nonatomic) NSString *m_nsContent;
@property (retain, nonatomic) NSString *m_nsRealChatUsr;
@property (assign, nonatomic) unsigned int m_uiMessageType;
@property (assign, nonatomic) long long m_n64MesSvrID;
- (id)initWithMsgType:(long long)arg1 nsFromUsr:(id)arg2;
- (void)parseWCPayInfoItemIfNeed;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
- (void)AddMsg:(id)arg1 MsgWrap:(id)arg2;
@end

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
@end

@interface WCPayConfirmTransferRequest : NSObject
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (retain, nonatomic) NSString *m_nsFromUserName;
@property (nonatomic) unsigned long long m_uiInvalidTime;
@property (retain, nonatomic) NSString *group_username;
@property (nonatomic) unsigned int groupType;
@property (retain, nonatomic) NSString *m_nsTransferAttach;
@end

@interface WCPayLogicMgr : NSObject
- (void)ConfirmTransferMoney:(id)arg1;
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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 leftImage:(id)arg3 title:(id)arg4 badge:(id)arg5 rightValue:(id)arg6 rightImage:(id)arg7 withRightRedDot:(BOOL)arg8 selected:(BOOL)arg9;
+ (id)centerCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@property (nonatomic, retain) id userInfo;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置

static NSString *const kDDReceiveEnabled = @"DDTransferAutoReceive";
static NSString *const kDDReceiveDelay   = @"DDTransferAutoReceiveDelay";
static NSString *const kDDReplyEnabled   = @"DDTransferAutoReplyEnabled";
static NSString *const kDDReplyContent   = @"DDTransferAutoReplyContent";

@interface DDTRConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL autoReceiveEnabled;
@property (nonatomic) double autoReceiveDelay;
@property (nonatomic) BOOL autoReplyEnabled;
@property (nonatomic, copy) NSString *autoReplyContent;
@end

@implementation DDTRConfig

+ (instancetype)shared {
    static DDTRConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _autoReceiveEnabled = [ud objectForKey:kDDReceiveEnabled] ? [ud boolForKey:kDDReceiveEnabled] : YES;
        [ud setBool:_autoReceiveEnabled forKey:kDDReceiveEnabled];
        _autoReceiveDelay = [ud objectForKey:kDDReceiveDelay] ? [ud doubleForKey:kDDReceiveDelay] : 0.2;
        [ud setDouble:_autoReceiveDelay forKey:kDDReceiveDelay];
        _autoReplyEnabled = [ud objectForKey:kDDReplyEnabled] ? [ud boolForKey:kDDReplyEnabled] : NO;
        [ud setBool:_autoReplyEnabled forKey:kDDReplyEnabled];
        _autoReplyContent = [ud stringForKey:kDDReplyContent] ?: @"已收款💰，感谢❤️";
        [ud setObject:_autoReplyContent forKey:kDDReplyContent];
        [ud synchronize];
    }
    return self;
}

- (void)setAutoReceiveEnabled:(BOOL)v {
    _autoReceiveEnabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDReceiveEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoReceiveDelay:(double)v {
    _autoReceiveDelay = v < 0 ? 0 : v;
    [[NSUserDefaults standardUserDefaults] setDouble:_autoReceiveDelay forKey:kDDReceiveDelay];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoReplyEnabled:(BOOL)v {
    _autoReplyEnabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDReplyEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoReplyContent:(NSString *)v {
    _autoReplyContent = [v copy];
    [[NSUserDefaults standardUserDefaults] setObject:_autoReplyContent forKey:kDDReplyContent];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 设置界面

@interface DDTRSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic, strong) UITextField *contentField;
@property (nonatomic) BOOL delayExpanded;
@end

@implementation DDTRSettingsViewController {
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
    self.title = @"转账收款设置";
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

// 总开关“启用自动收款”控制整个分组；子开关“启用自动回复”控制回复项。
// 延迟收款秒数为下拉选择；自定义回复为输入框 + 确认按钮。
- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls = objc_getClass("WCTableViewSectionManager");
    if (!_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];

    WCTableViewSectionManager *section = [secCls defaultSection];

    [section addCell:[cellCls switchCellForSel:@selector(switchChanged:)
                                      target:self
                                       title:@"启用自动收款"
                                          on:[DDTRConfig shared].autoReceiveEnabled]];

    if ([DDTRConfig shared].autoReceiveEnabled) {
        // 延迟收款秒数：表头显示当前值，点按展开下拉选项
        [section addCell:[cellCls normalCellForSel:@selector(delayHeaderTapped:)
                                          target:self
                                           title:@"↳延迟秒数"
                                       rightValue:[NSString stringWithFormat:@"[%.1f秒]", [DDTRConfig shared].autoReceiveDelay]]];

        if (self.delayExpanded) {
            NSArray *opts = @[@0.2, @2.0, @5.0, @8.0];
            for (NSNumber *o in opts) {
                double v = o.doubleValue;
                // centerCellForSel: 文字居中、右侧无箭头（参照 WCTableViewCellManager.h:70）
                WCTableViewCellManager *optCell = [cellCls centerCellForSel:@selector(delayOptionTapped:)
                                                                     target:self
                                                                      title:[NSString stringWithFormat:@"[%.1f秒]", v]];
                DD_SetCellOption(optCell, o);
                optCell.userInfo = o;
                [section addCell:optCell];
            }
        }

        [section addCell:[cellCls switchCellForSel:@selector(autoReplySwitchChanged:)
                                          target:self
                                           title:@"↳自动回复"
                                              on:[DDTRConfig shared].autoReplyEnabled]];

        if ([DDTRConfig shared].autoReplyEnabled) {
            // 自定义回复：输入框 + 确认按钮（无箭头）
            self.contentField = [[UITextField alloc] init];
            self.contentField.placeholder = @"请输入回复内容";
            self.contentField.text = [DDTRConfig shared].autoReplyContent;
            self.contentField.textAlignment = NSTextAlignmentRight;
            [self.contentField addTarget:self action:@selector(contentChanged:) forControlEvents:UIControlEventEditingChanged];
            [section addCell:[cellCls normalCellForSel:nil
                                              target:nil
                                               title:@"↳回复内容"
                                            rightView:[self inputRowWithField:self.contentField action:@selector(contentConfirmed:)]]];
        }
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

// 右侧容器：输入框 + 确认按钮，点确认写入并收起键盘
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];

    field.frame = CGRectMake(0, 0, 150, 30);
    field.borderStyle = UITextBorderStyleRoundedRect;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(158, 0, 42, 30);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}

- (void)switchChanged:(UISwitch *)sender {
    [DDTRConfig shared].autoReceiveEnabled = sender.isOn;
    [self buildTable];
}

- (void)autoReplySwitchChanged:(UISwitch *)sender {
    [DDTRConfig shared].autoReplyEnabled = sender.isOn;
    [self buildTable];
}

// 把下拉项对应的值挂到 cell 上，点击时回读
static const void *kDDOptionValue = &kDDOptionValue;
static void DD_SetCellOption(id cell, id value) {
    objc_setAssociatedObject(cell, kDDOptionValue, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static id DD_CellOption(id cell) {
    return objc_getAssociatedObject(cell, kDDOptionValue);
}

- (void)delayHeaderTapped:(id)sender {
    self.delayExpanded = !self.delayExpanded;
    [self buildTable];
}

- (void)delayOptionTapped:(id)sender {
    NSNumber *o = DD_CellOption(sender);
    if (o) [DDTRConfig shared].autoReceiveDelay = o.doubleValue;
    self.delayExpanded = NO;
    [self buildTable];
}

- (void)contentChanged:(UITextField *)field {
    [DDTRConfig shared].autoReplyContent = field.text;
}

- (void)contentConfirmed:(id)sender {
    [DDTRConfig shared].autoReplyContent = self.contentField.text;
    [self.contentField resignFirstResponder];
}

#pragma mark - UITableViewDelegate 转发
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = (WCTableViewCellManager *)[self.tableViewMgr cellInfoAtIndexPath:indexPath];
    if (cellInfo && [cellInfo.userInfo isKindOfClass:[NSNumber class]]) {
        double v = [(NSNumber *)cellInfo.userInfo doubleValue];
        double cur = [DDTRConfig shared].autoReceiveDelay;
        cell.accessoryType = (fabs(v - cur) < 0.001) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
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

#pragma mark - 辅助

static id DD_GetService(NSString *className) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return nil;
    return [ctx getService:NSClassFromString(className)];
}

static NSString *DD_GetSelfUserName(void) {
    CContactMgr *mgr = DD_GetService(@"CContactMgr");
    return mgr.getSelfContact.m_nsUsrName;
}

#pragma mark - 自动回复

static void DD_SendTransferReply(NSString *toUserName) {
    if (!toUserName.length) return;
    if (![DDTRConfig shared].autoReplyEnabled) return;

    NSString *replyText = [DDTRConfig shared].autoReplyContent;
    if (!replyText.length) return; // 回复内容为空等于不自动回复

    CMessageMgr *msgMgr = DD_GetService(@"CMessageMgr");
    if (!msgMgr) return;

    NSString *currentUser = DD_GetSelfUserName();
    if (!currentUser.length) return;

    CMessageWrap *replyMsg = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:1 nsFromUsr:toUserName];
    if (!replyMsg) return;

    replyMsg.m_nsContent = replyText;
    replyMsg.m_nsFromUsr = currentUser;
    replyMsg.m_nsToUsr = toUserName;

    [msgMgr AddMsg:toUserName MsgWrap:replyMsg];
}

#pragma mark - 转账识别

static BOOL DD_IsTransfer(CMessageWrap *msg) {
    if (!msg) return NO;
    [msg parseWCPayInfoItemIfNeed];
    WCPayInfoItem *info = msg.m_oWCPayInfoItem;
    if (!info) return NO;
    if (info.m_nsTransferID.length == 0) return NO;

    NSString *url = info.m_c2cNativeUrl ?: @"";
    if ([url rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
    NSString *content = msg.m_nsContent ?: @"";
    if ([content rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
    return YES;
}

#pragma mark - 去重

static NSCache *DD_ProcessedCache(void) {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 1000;
    });
    return cache;
}

#pragma mark - 自动收款

static void DD_TryAutoReceive(NSString *sessionId, CMessageWrap *wrap) {
    if (![DDTRConfig shared].autoReceiveEnabled) return;
    if (!sessionId.length || !wrap) return;
    if (!DD_IsTransfer(wrap)) return;

    WCPayInfoItem *info = wrap.m_oWCPayInfoItem;
    if (!info.m_nsTransferID.length) return;

    unsigned int status = info.m_c2cPayReceiveStatus;
    if (status == 1 || status == 2) return;

    NSString *key = [NSString stringWithFormat:@"%@|%lld", info.m_nsTransferID, wrap.m_n64MesSvrID];
    NSCache *cache = DD_ProcessedCache();
    if ([cache objectForKey:key]) return;
    [cache setObject:@(YES) forKey:key];

    NSString *selfUser = DD_GetSelfUserName();
    if (!selfUser.length) return;

    BOOL isGroup = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
    NSString *peer = isGroup ? (wrap.m_nsRealChatUsr ?: @"") : (wrap.m_nsFromUsr ?: @"");
    if (!peer.length || [peer isEqualToString:selfUser]) return;

    double delay = [DDTRConfig shared].autoReceiveDelay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![DDTRConfig shared].autoReceiveEnabled) return;

        WCPayLogicMgr *logic = DD_GetService(@"WCPayLogicMgr");
        if (!logic) return;

        WCPayConfirmTransferRequest *req = [[objc_getClass("WCPayConfirmTransferRequest") alloc] init];
        req.m_nsTransferID = info.m_nsTransferID;
        req.m_nsFromUserName = peer;
        req.m_uiInvalidTime = (unsigned long long)info.m_uiInvalidTime;
        if (isGroup) {
            req.group_username = sessionId;
            req.groupType = 1;
        }
        req.m_nsTransferAttach = info.transfer_attach;

        [logic ConfirmTransferMoney:req];
        if ([DDTRConfig shared].autoReplyEnabled) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DD_SendTransferReply(peer);
            });
        }
    });
}

#pragma mark - Hook

%hook CMessageMgr
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    if (wrap.m_uiMessageType == 49 && [msg isKindOfClass:[NSString class]] && msg.length > 0) {
        DD_TryAutoReceive(msg, wrap);
    }
}
%end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD转账收款"
                                                      version:@"1.0.0"
                                                   controller:@"DDTRSettingsViewController"];
        }
    }
}

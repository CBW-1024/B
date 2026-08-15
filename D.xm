// DDTR.xm
// 功能：转账自动收款 + 收款后自动回复（回复内容可自定义）

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

#pragma mark - 微信内部类声明（基于头文件）

// 支付信息
@interface WCPayInfoItem : NSObject
@property (retain, nonatomic) NSString *m_c2cNativeUrl;
@property (retain, nonatomic) NSString *m_nsFeeDesc;
@property (assign, nonatomic) unsigned int m_uiPaySubType;
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (nonatomic) unsigned int m_c2cPayReceiveStatus;
@property (nonatomic) unsigned int m_uiInvalidTime;
@property (retain, nonatomic) NSString *transfer_attach;
@end

// 消息包装
@interface CMessageWrap : NSObject
@property (retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@property (retain, nonatomic) NSString *m_nsContent;
@property (retain, nonatomic) NSString *m_nsRealChatUsr;
@property (assign, nonatomic) unsigned int m_uiMessageType;
@property (assign, nonatomic) long long m_n64MesSvrID;
@property (assign, nonatomic) unsigned int m_uiStatus;
@property (assign, nonatomic) unsigned int m_uiCreateTime;
- (void)parseWCPayInfoItemIfNeed;
@end

// 消息管理器
@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)userName MsgWrap:(CMessageWrap *)wrap;
@end

// 发送消息管理器
@interface SendMessageMgr : NSObject
- (void)AddMsgToSendTable:(NSString *)chatName MsgWrap:(CMessageWrap *)wrap;
- (void)SendMsg;
@end

// 微信上下文
@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

// 联系人
@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
@end

// 转账确认请求
@interface WCPayConfirmTransferRequest : NSObject
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (retain, nonatomic) NSString *m_nsFromUserName;
@property (nonatomic) unsigned long long m_uiInvalidTime;
@property (retain, nonatomic) NSString *group_username;
@property (nonatomic) unsigned int groupType;
@property (retain, nonatomic) NSString *m_nsTransferAttach;
@end

// 转账确认响应
@interface WCPayConfirmTransferResponse : NSObject
@property (nonatomic) long long m_llFee;
@property (retain, nonatomic) NSString *m_nsReceiver;
@end

// 支付逻辑管理器
@interface WCPayLogicMgr : NSObject
- (void)ConfirmTransferMoney:(id)arg1;
- (void)insideCallBackOnConfirmTransferMoneyResponse:(id)arg1 OnRequest:(id)arg2;
@end

// 微信设置页组件
@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(NSInteger)style;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(NSString *)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(NSString *)title rightValue:(NSString *)rightValue;
@end

// 插件注册管理器
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理

@interface DDTRConfig : NSObject
+ (instancetype)shared;
+ (NSString *)defaultReplyContent;
@property (nonatomic) BOOL autoReceiveEnabled;
@property (nonatomic) BOOL autoReplyEnabled;
@property (copy, nonatomic) NSString *replyContent;
@end

@implementation DDTRConfig

static NSString * const kDDDefaultReply = @"本人已开启自动收款";

+ (instancetype)shared {
    static DDTRConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

+ (NSString *)defaultReplyContent {
    return kDDDefaultReply;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _autoReceiveEnabled = [d boolForKey:@"DDTransferAutoReceive"];
        _autoReplyEnabled = [d boolForKey:@"DDTransferAutoReply"];
        _replyContent = [d stringForKey:@"DDTransferReplyContent"] ?: [DDTRConfig defaultReplyContent];
    }
    return self;
}

- (void)setAutoReceiveEnabled:(BOOL)autoReceiveEnabled {
    _autoReceiveEnabled = autoReceiveEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:autoReceiveEnabled forKey:@"DDTransferAutoReceive"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoReplyEnabled:(BOOL)autoReplyEnabled {
    _autoReplyEnabled = autoReplyEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:autoReplyEnabled forKey:@"DDTransferAutoReply"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setReplyContent:(NSString *)replyContent {
    _replyContent = [replyContent copy] ?: [DDTRConfig defaultReplyContent];
    [[NSUserDefaults standardUserDefaults] setObject:_replyContent forKey:@"DDTransferReplyContent"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 设置页面

@interface DDTRSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDTRSettingsViewController

- (instancetype)init {
    if (self = [super init]) {
        _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD转账自动收款";
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)buildTable {
    [self.tableViewMgr clearAllSection];
    DDTRConfig *cfg = [DDTRConfig shared];
    
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") defaultSection];
    
    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onAutoReceiveSwitch:)
                                                                        target:self
                                                                         title:@"启用自动收款"
                                                                            on:cfg.autoReceiveEnabled]];
    
    if (cfg.autoReceiveEnabled) {
        [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onAutoReplySwitch:)
                                                                            target:self
                                                                             title:@"启用自动回复"
                                                                                on:cfg.autoReplyEnabled]];
        if (cfg.autoReplyEnabled) {
            NSString *preview = cfg.replyContent ?: [DDTRConfig defaultReplyContent];
            if (preview.length > 20) preview = [[preview substringToIndex:20] stringByAppendingString:@"…"];
            [section addCell:[objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onEditReplyContent:)
                                                                               target:self
                                                                                title:@"回复内容"
                                                                          rightValue:preview]];
        }
    }
    
    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

- (void)onAutoReceiveSwitch:(UISwitch *)sender {
    [DDTRConfig shared].autoReceiveEnabled = sender.isOn;
    [self buildTable];
}

- (void)onAutoReplySwitch:(UISwitch *)sender {
    [DDTRConfig shared].autoReplyEnabled = sender.isOn;
    [self buildTable];
}

- (void)onEditReplyContent:(id)sender {
    DDTRConfig *cfg = [DDTRConfig shared];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置回复内容"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = cfg.replyContent ?: [DDTRConfig defaultReplyContent];
        textField.placeholder = @"输入收款后自动回复的内容";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (text.length == 0) text = [DDTRConfig defaultReplyContent];
        [DDTRConfig shared].replyContent = text;
        [weakSelf buildTable];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 辅助工具

static id DD_GetService(NSString *className) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return nil;
    return [ctx getService:NSClassFromString(className)];
}

static NSString *DD_GetSelfUserName(void) {
    CContactMgr *mgr = DD_GetService(@"CContactMgr");
    return mgr.getSelfContact.m_nsUsrName;
}

#pragma mark - 转账识别

static BOOL DD_IsTransfer(CMessageWrap *msg) {
    if (!msg) return NO;
    [msg parseWCPayInfoItemIfNeed];
    WCPayInfoItem *info = msg.m_oWCPayInfoItem;
    if (!info) return NO;
    if (info.m_uiPaySubType != 3 && info.m_uiPaySubType != 4) return NO;
    if (info.m_nsTransferID.length == 0) return NO;
    // 排除红包
    NSString *url = info.m_c2cNativeUrl ?: @"";
    if ([url rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
    NSString *content = msg.m_nsContent ?: @"";
    if ([content rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
    return YES;
}

#pragma mark - 去重与待回复缓存

static NSCache *DD_ProcessedCache(void) {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 1000;
    });
    return cache;
}

static NSMutableDictionary *DD_PendingReplyMap(void) {
    static NSMutableDictionary *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ map = [NSMutableDictionary dictionary]; });
    return map;
}

#pragma mark - 发送文本消息（修复版）

static void DD_SendTextMessage(NSString *toUser, NSString *text) {
    if (!toUser.length || !text.length) return;
    NSString *selfUser = DD_GetSelfUserName();
    if (!selfUser.length) return;
    
    @try {
        // 创建消息对象
        CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] init];
        if (!wrap) return;
        
        // 基础属性
        wrap.m_uiMessageType = 1; // 文本消息
        wrap.m_nsContent = text;
        wrap.m_nsFromUsr = selfUser;
        wrap.m_nsToUsr = toUser;
        wrap.m_nsRealChatUsr = toUser; // 群聊或单聊均设置为目标
        wrap.m_uiCreateTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
        wrap.m_uiStatus = 0; // 0 = 未发送（确保进入发送队列）

        // 1. 添加到本地数据库（显示在聊天界面）
        CMessageMgr *msgMgr = DD_GetService(@"CMessageMgr");
        if ([msgMgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) {
            [msgMgr AddMsg:toUser MsgWrap:wrap];
        } else {
            return; // 若无法添加，则放弃
        }

        // 2. 加入发送队列并触发发送
        SendMessageMgr *sendMgr = DD_GetService(@"SendMessageMgr");
        if ([sendMgr respondsToSelector:@selector(AddMsgToSendTable:MsgWrap:)]) {
            [sendMgr AddMsgToSendTable:toUser MsgWrap:wrap];
        }
        if ([sendMgr respondsToSelector:@selector(SendMsg)]) {
            [sendMgr SendMsg];
        }
    } @catch (NSException *e) {
        // 静默失败
    }
}

#pragma mark - 核心逻辑

static void DD_TryAutoReceive(NSString *sessionId, CMessageWrap *wrap) {
    if (![DDTRConfig shared].autoReceiveEnabled) return;
    if (!sessionId.length || !wrap) return;
    if (!DD_IsTransfer(wrap)) return;

    WCPayInfoItem *info = wrap.m_oWCPayInfoItem;
    if (!info.m_nsTransferID.length) return;

    unsigned int status = info.m_c2cPayReceiveStatus;
    if (status == 1 || status == 2) return; // 已收款

    NSString *key = [NSString stringWithFormat:@"%@|%lld", info.m_nsTransferID, wrap.m_n64MesSvrID];
    NSCache *cache = DD_ProcessedCache();
    if ([cache objectForKey:key]) return;
    [cache setObject:@(YES) forKey:key];

    NSString *selfUser = DD_GetSelfUserName();
    if (!selfUser.length) return;

    BOOL isGroup = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
    NSString *peer = isGroup ? (wrap.m_nsRealChatUsr ?: @"") : (wrap.m_nsFromUsr ?: @"");
    if (!peer.length || [peer isEqualToString:selfUser]) return;

    // 缓存回复所需信息
    if ([DDTRConfig shared].autoReplyEnabled) {
        @synchronized (DD_PendingReplyMap()) {
            DD_PendingReplyMap()[info.m_nsTransferID] = @{
                @"peer": peer,
                @"sessionId": sessionId ?: peer,
                @"isGroup": @(isGroup)
            };
        }
    }

    // 延迟0.5秒发起收款请求
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![DDTRConfig shared].autoReceiveEnabled) return;
        WCPayLogicMgr *logic = DD_GetService(@"WCPayLogicMgr");
        if (!logic || ![logic respondsToSelector:@selector(ConfirmTransferMoney:)]) return;
        WCPayConfirmTransferRequest *req = [[objc_getClass("WCPayConfirmTransferRequest") alloc] init];
        req.m_nsTransferID = info.m_nsTransferID;
        req.m_nsFromUserName = peer;
        req.m_uiInvalidTime = (unsigned long long)info.m_uiInvalidTime;
        if (isGroup) {
            req.group_username = sessionId;
            req.groupType = 1;
        }
        req.m_nsTransferAttach = info.transfer_attach;
        @try {
            [logic ConfirmTransferMoney:req];
        } @catch (NSException *e) {}
    });
}

#pragma mark - Hook 确认回调（用于自动回复）

%hook WCPayLogicMgr

- (void)insideCallBackOnConfirmTransferMoneyResponse:(id)response OnRequest:(id)request {
    %orig;

    if (![DDTRConfig shared].autoReplyEnabled) return;

    @try {
        NSString *transferId = nil;
        if ([request isKindOfClass:objc_getClass("WCPayConfirmTransferRequest")]) {
            transferId = [(WCPayConfirmTransferRequest *)request m_nsTransferID];
        }
        if (!transferId.length) return;
        // 响应对象非空即视为成功（可根据需要进一步检查response是否为WCPayConfirmTransferResponse及其属性）
        if (!response) return;

        NSDictionary *cached = nil;
        @synchronized (DD_PendingReplyMap()) {
            cached = DD_PendingReplyMap()[transferId];
            if (cached) [DD_PendingReplyMap() removeObjectForKey:transferId];
        }
        if (!cached) return;

        NSString *peer = cached[@"peer"];
        NSString *sessionId = cached[@"sessionId"];
        BOOL isGroup = [cached[@"isGroup"] boolValue];

        NSString *target = isGroup ? sessionId : peer;
        if (!target.length) return;

        NSString *replyText = [DDTRConfig shared].replyContent ?: [DDTRConfig defaultReplyContent];

        // 延迟1秒后发送回复（确保收款状态已同步）
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DD_SendTextMessage(target, replyText);
        });
    } @catch (NSException *e) {}
}

%end

#pragma mark - Hook 收消息

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    if (wrap.m_uiMessageType == 49 && [msg isKindOfClass:[NSString class]] && msg.length > 0) {
        DD_TryAutoReceive(msg, wrap);
    }
}

%end

#pragma mark - 插件入口

%ctor {
    @autoreleasepool {
        [DDTRConfig shared];
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD转账自动收款"
                                                                               version:@"1.0.0"
                                                                            controller:@"DDTRSettingsViewController"];
        }
    }
}
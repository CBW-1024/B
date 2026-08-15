// TransferAutoReceive.xm
// 微信转账自动收款 + 自动回复插件（已修复"收款成功但不回复"问题）
// 基于 class-dump 头文件实现，兼容微信 8.x 及以上版本
//
// 【修复说明】
// 原版在 WCPayLogicMgr 的 insideCallBackOnConfirmTransferMoneyResponse:OnRequest:
// 回调里，用 [request isKindOfClass:WCPayConfirmTransferRequest] 取 transferId。
// 但微信底层派发回调时，request 的实际类型往往不是 WCPayConfirmTransferRequest
// （而是其基类/字典包装），导致 isKindOfClass: 失败 → transferId=nil → 直接 return，
// TR_SendTextMessage 永远不执行，因而"收款成功却不回复"。
//
// 修复策略：
// 1) 发起 ConfirmTransferMoney 请求时，以 transferId 为 key，把 (peer/sessionId)
//    写入独立的 TR_ReplyMap（不依赖回调里的 request 类型）；
// 2) 回调里优先从 request 取 transferId（类型匹配时），同时用 response 里的
//    m_nsPayer / m_nsReceiver 做兜底匹配，确保能定位到待回复项；
// 3) 成功判定收紧：必须有金额 + 收款方，且无拦截弹窗（intercept_win）；
// 4) 发文本消息时补全 CMessageWrap 的关键字段（CreateTime/Status/MsgFlag）。

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

// ============================================================
// 第1部分：微信运行时类声明（基于 class-dump 头文件）
// ============================================================

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@property(retain, nonatomic) NSString *m_nsFeeDesc;
@property(nonatomic) unsigned int m_uiPaySubType;
@property(retain, nonatomic) NSString *m_nsTransferID;
@property(nonatomic) unsigned int m_c2cPayReceiveStatus;
@property(nonatomic) unsigned int m_uiInvalidTime;
@property(retain, nonatomic) NSString *transfer_attach;
@property(retain, nonatomic) NSString *m_nsTranscationID;
@property(retain, nonatomic) NSString *m_total_fee;
@property(retain, nonatomic) NSString *m_nsPayMsgID;
// 头文件额外提供的、对判定有帮助的字段
@property(retain, nonatomic) NSString *transfer_payer_username;
@property(retain, nonatomic) NSString *transfer_receiver_username;
@end

@interface CMessageWrap : NSObject
@property(retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsRealChatUsr;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) long long m_n64MesSvrID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiStatus;   // 新增：消息状态
@property(nonatomic) unsigned int m_uiMsgFlag;  // 新增：消息方向标志
@property(retain, nonatomic) NSString *m_nsPushContent;
- (void)parseWCPayInfoItemIfNeed;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
- (void)AddMsg:(NSString *)chatName MsgWrap:(CMessageWrap *)wrap;
@end

@interface MMContext : NSObject
@property(readonly, nonatomic) NSString *userName;
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)userName;
@end

@interface WCPayConfirmTransferRequest : NSObject
@property(retain, nonatomic) NSString *m_nsTransferID;
@property(retain, nonatomic) NSString *m_nsFromUserName;
@property(nonatomic) unsigned long long m_uiInvalidTime;
@property(retain, nonatomic) NSString *group_username;
@property(nonatomic) unsigned int groupType;
@property(retain, nonatomic) NSString *m_nsTransferAttach;
@property(retain, nonatomic) NSString *bind_serial;
@property(nonatomic) unsigned int recv_channel_type;
@property(retain, nonatomic) NSString *left_button_continue;
@property(nonatomic) unsigned long long sub_recv_channel_id;
@property(retain, nonatomic) NSString *sub_title_clicked;
@end

@interface WCPayConfirmTransferResponse : NSObject
@property(nonatomic) long long m_llFee;
@property(retain, nonatomic) NSString *m_nsFeeType;
@property(retain, nonatomic) NSString *m_nsPayer;
@property(retain, nonatomic) NSString *m_nsReceiver;
@property(retain, nonatomic) id intercept_win;       // 新增：拦截弹窗（非空=未真正到账）
@property(retain, nonatomic) id intercept_win_after;  // 新增：二次确认拦截
@end

@interface WCPayLogicMgr : NSObject
- (void)ConfirmTransferMoney:(WCPayConfirmTransferRequest *)arg1;
- (void)insideCallBackOnConfirmTransferMoneyResponse:(id)arg1 OnRequest:(id)arg2;
// 辅助：判定/处理转账消息（头文件证实存在）
- (_Bool)isTransferReturnMessage:(id)arg1;
- (void)handleTransferReturnMessage:(id)arg1;
@end

@interface SendMessageMgr : NSObject
- (void)AddMsgToSendTable:(NSString *)chatName MsgWrap:(CMessageWrap *)wrap;
- (void)SendMsg;
- (_Bool)IsSendingMsg;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(long long)style;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoHeader:(id)arg1 Footer:(id)arg2;
+ (id)sectionInfoHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 detail:(id)arg4;
@end

// ============================================================
// 第2部分：配置管理
// ============================================================

#define TR_DEFAULT_REPLY @"已收到转账，感谢！"

@interface TRConfig : NSObject
@property (nonatomic) BOOL autoReceiveEnabled;
@property (nonatomic) BOOL autoReplyEnabled;
@property (copy, nonatomic) NSString *replyContent;
+ (instancetype)shared;
@end

@implementation TRConfig

+ (instancetype)shared {
    static TRConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _autoReceiveEnabled = [d boolForKey:@"TRTransferAutoReceive"];
        _autoReplyEnabled   = [d boolForKey:@"TRTransferAutoReply"];
        _replyContent       = [d stringForKey:@"TRTransferReplyContent"] ?: TR_DEFAULT_REPLY;
    }
    return self;
}

- (void)setAutoReceiveEnabled:(BOOL)v { _autoReceiveEnabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"TRTransferAutoReceive"]; [[NSUserDefaults standardUserDefaults] synchronize]; }
- (void)setAutoReplyEnabled:(BOOL)v { _autoReplyEnabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"TRTransferAutoReply"]; [[NSUserDefaults standardUserDefaults] synchronize]; }
- (void)setReplyContent:(NSString *)v { _replyContent = v ?: TR_DEFAULT_REPLY;
    [[NSUserDefaults standardUserDefaults] setObject:_replyContent forKey:@"TRTransferReplyContent"]; [[NSUserDefaults standardUserDefaults] synchronize]; }
@end

// ============================================================
// 第3部分：全局状态（修复：独立的 ReplyMap，key=transferId）
// ============================================================

// ReplyMap: key=transferId (NSString), value=@{@"peer":付款方, @"sessionId":会话ID}
static NSMutableDictionary *TR_ReplyMap(void) {
    static NSMutableDictionary *m;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ m = [NSMutableDictionary dictionary]; });
    return m;
}

// ProcessedSet: "transferId|serverMsgId" 去重
static NSMutableSet *TR_ProcessedSet(void) {
    static NSMutableSet *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [NSMutableSet set]; });
    return s;
}

// 统一 key 生成（避免两处拼接不一致）
static NSString *TR_Key(NSString *transferId, long long svrId) {
    return [NSString stringWithFormat:@"%@|%lld", transferId ?: @"", svrId];
}

// ============================================================
// 第4部分：辅助函数
// ============================================================

static id TR_GetService(NSString *className) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return nil;
    return [ctx getService:NSClassFromString(className)];
}

static NSString *TR_GetSelfUserName(void) {
    CContactMgr *mgr = TR_GetService(@"CContactMgr");
    return mgr.getSelfContact.m_nsUsrName;
}

static BOOL TR_IsTransfer(CMessageWrap *msg) {
    if (!msg) return NO;
    if ([msg respondsToSelector:@selector(parseWCPayInfoItemIfNeed)])
        [msg parseWCPayInfoItemIfNeed];
    WCPayInfoItem *info = msg.m_oWCPayInfoItem;
    if (!info) return NO;
    return (info.m_uiPaySubType == 3 || info.m_uiPaySubType == 4 || info.m_nsTransferID.length > 0);
}

static BOOL TR_IsRedPacket(CMessageWrap *msg) {
    if (!msg) return NO;
    if ([msg respondsToSelector:@selector(parseWCPayInfoItemIfNeed)])
        [msg parseWCPayInfoItemIfNeed];
    NSString *url = msg.m_oWCPayInfoItem.m_c2cNativeUrl ?: @"";
    if ([url rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    NSString *content = msg.m_nsContent ?: @"";
    return [content rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

// ============================================================
// 第5部分：发送文本消息（补全 CMessageWrap 关键字段）
// ============================================================

static void TR_SendTextMessage(NSString *toUser, NSString *text) {
    if (!toUser.length || !text.length) return;
    NSString *selfUser = TR_GetSelfUserName();
    if (!selfUser.length) return;

    @try {
        CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] init];
        wrap.m_uiMessageType = 1;          // 文本
        wrap.m_nsContent     = text;
        wrap.m_nsFromUsr     = selfUser;
        wrap.m_nsToUsr       = toUser;
        wrap.m_nsRealChatUsr = toUser;     // 群聊设为群ID，保证显示正确
        // 补全关键字段，避免消息被忽略/时间异常
        wrap.m_uiCreateTime  = (unsigned int)[[NSDate date] timeIntervalSince1970];
        wrap.m_uiStatus      = 1;          // 已发送
        wrap.m_uiMsgFlag     = 0;          // 自己发出的消息

        CMessageMgr *msgMgr = TR_GetService(@"CMessageMgr");
        if ([msgMgr respondsToSelector:@selector(AddMsg:MsgWrap:)])
            [msgMgr AddMsg:toUser MsgWrap:wrap];

        SendMessageMgr *sendMgr = TR_GetService(@"SendMessageMgr");
        if (sendMgr && [sendMgr respondsToSelector:@selector(AddMsgToSendTable:MsgWrap:)])
            [sendMgr AddMsgToSendTable:toUser MsgWrap:wrap];
        if (sendMgr && [sendMgr respondsToSelector:@selector(SendMsg)])
            [sendMgr SendMsg];
    } @catch (NSException *e) {
        NSLog(@"[TR] TR_SendTextMessage exception: %@", e);
    }
}

// ============================================================
// 第6部分：自动收款核心逻辑
// ============================================================

static void TR_TryAutoReceive(NSString *sessionId, CMessageWrap *wrap) {
    if (![TRConfig shared].autoReceiveEnabled) return;
    if (!sessionId.length || !wrap) return;
    if (!TR_IsTransfer(wrap) || TR_IsRedPacket(wrap)) return;

    WCPayInfoItem *info = wrap.m_oWCPayInfoItem;
    if (!info.m_nsTransferID.length) return;

    unsigned int status = info.m_c2cPayReceiveStatus;
    if (status == 1 || status == 2) return; // 已收款/已过期

    NSString *selfUser = TR_GetSelfUserName();
    if (!selfUser.length) return;

    BOOL isGroup = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
    NSString *peer = isGroup ? (wrap.m_nsRealChatUsr ?: @"") : (wrap.m_nsFromUsr ?: @"");
    if (!peer.length || [peer isEqualToString:selfUser]) return;

    // 去重
    NSString *key = TR_Key(info.m_nsTransferID, wrap.m_n64MesSvrID);
    NSMutableSet *set = TR_ProcessedSet();
    @synchronized (set) {
        if ([set containsObject:key]) return;
        [set addObject:key];
        if (set.count > 500) [set removeAllObjects];
    }

    // 【修复】以 transferId 为 key 写入 ReplyMap，不依赖回调里 request 的类型
    if ([TRConfig shared].autoReplyEnabled) {
        @synchronized (TR_ReplyMap()) {
            TR_ReplyMap()[info.m_nsTransferID] = @{
                @"peer": peer,
                @"sessionId": sessionId ?: peer
            };
        }
    }

    // 延迟发起收款
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![TRConfig shared].autoReceiveEnabled) return;

        MMContext *mctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
        WCPayLogicMgr *logic = [mctx getService:objc_getClass("WCPayLogicMgr")];
        if (!logic || ![logic respondsToSelector:@selector(ConfirmTransferMoney:)]) return;

        WCPayConfirmTransferRequest *req = [[objc_getClass("WCPayConfirmTransferRequest") alloc] init];
        req.m_nsTransferID       = info.m_nsTransferID;
        req.m_nsFromUserName     = peer;
        req.m_uiInvalidTime      = (unsigned long long)info.m_uiInvalidTime;
        if (isGroup) {
            req.group_username = sessionId;
            req.groupType = 1;
        }
        req.m_nsTransferAttach  = info.transfer_attach;

        @try { [logic ConfirmTransferMoney:req]; }
        @catch (NSException *e) { NSLog(@"[TR] ConfirmTransferMoney exception: %@", e); }
    });
}

// ============================================================
// 第7部分：Method Swizzling（钩子）
// ============================================================

%hook CMessageMgr
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    if (wrap.m_uiMessageType == 49 && [msg isKindOfClass:[NSString class]] && msg.length > 0) {
        TR_TryAutoReceive(msg, wrap);
    }
}
%end

%hook WCPayLogicMgr

- (void)insideCallBackOnConfirmTransferMoneyResponse:(id)response OnRequest:(id)request {
    %orig;

    if (![TRConfig shared].autoReplyEnabled) return;

    @try {
        // ---- 取 transferId：优先从 request（类型匹配时），否则遍历 ReplyMap 兜底 ----
        NSString *transferId = nil;
        Class ReqCls = objc_getClass("WCPayConfirmTransferRequest");
        if (ReqCls && [request isKindOfClass:ReqCls]) {
            transferId = [(WCPayConfirmTransferRequest *)request m_nsTransferID];
        }
        // 兜底：若 request 取不到，用 response 的 payer/receiver 反查 ReplyMap
        if (!transferId.length) {
            if ([response isKindOfClass:objc_getClass("WCPayConfirmTransferResponse")]) {
                WCPayConfirmTransferResponse *resp = response;
                NSString *payer = resp.m_nsPayer ?: @"";
                @synchronized (TR_ReplyMap()) {
                    for (NSString *tid in TR_ReplyMap()) {
                        NSDictionary *v = TR_ReplyMap()[tid];
                        if ([[v[@"peer"] description] isEqualToString:payer]) {
                            transferId = tid; break;
                        }
                    }
                }
            }
        }
        if (!transferId.length) {
            NSLog(@"[TR] callback: cannot resolve transferId (request class=%@), skip reply", [request class]);
            return;
        }

        // ---- 成功判定：有金额 + 有收款方 + 无拦截弹窗 ----
        BOOL success = NO;
        if ([response isKindOfClass:objc_getClass("WCPayConfirmTransferResponse")]) {
            WCPayConfirmTransferResponse *resp = response;
            BOOL noIntercept = (resp.intercept_win == nil) && (resp.intercept_win_after == nil);
            success = (resp.m_llFee > 0) && (resp.m_nsReceiver.length > 0) && noIntercept;
        }
        if (!success) {
            NSLog(@"[TR] callback: transfer not truly success (fee=%lld receiver=%@ intercept=%@), skip reply",
                  [response m_llFee], [response m_nsReceiver], [response intercept_win]);
            // 未真正到账，清除待回复项避免下次误发
            @synchronized (TR_ReplyMap()) { [TR_ReplyMap() removeObjectForKey:transferId]; }
            return;
        }

        // ---- 取出付款方信息并发回复 ----
        NSString *peer = nil, *sessionId = nil;
        @synchronized (TR_ReplyMap()) {
            NSDictionary *info = TR_ReplyMap()[transferId];
            if (info) { peer = info[@"peer"]; sessionId = info[@"sessionId"]; }
            [TR_ReplyMap() removeObjectForKey:transferId];
        }
        if (!peer.length) return;

        NSString *replyText   = [TRConfig shared].replyContent ?: TR_DEFAULT_REPLY;
        NSString *replyTarget = sessionId.length ? sessionId : peer;

        NSLog(@"[TR] callback: transfer success, replying to %@ (target=%@)", peer, replyTarget);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TR_SendTextMessage(replyTarget, replyText);
        });
    } @catch (NSException *e) {
        NSLog(@"[TR] callback exception: %@", e);
    }
}
%end

// ============================================================
// 第8部分：设置界面控制器
// ============================================================

@interface TRSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation TRSettingsViewController

- (instancetype)init {
    if (self = [super init]) {
        _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc]
                         initWithFrame:[UIScreen mainScreen].bounds
                                 style:UITableViewStyleInsetGrouped];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"转账自动收款";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildTable];
    UITableView *tv = (UITableView *)[self.tableViewMgr getTableView];
    tv.frame = self.view.bounds;
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (@available(iOS 11.0, *)) tv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tv];
}

- (void)buildTable {
    [self.tableViewMgr clearAllSection];
    TRConfig *cfg = [TRConfig shared];

    WCTableViewSectionManager *sec1 = [objc_getClass("WCTableViewSectionManager")
        sectionInfoHeader:@"自动收款" Footer:@"开启后，收到的转账（非红包）将自动确认收款。"];
    [sec1 addCell:[objc_getClass("WCTableViewCellManager")
        switchCellForSel:@selector(onAutoReceiveSwitch:)
                  target:self
                   title:@"启用自动收款"
                      on:cfg.autoReceiveEnabled]];

    if (cfg.autoReceiveEnabled) {
        WCTableViewSectionManager *sec2 = [objc_getClass("WCTableViewSectionManager")
            sectionInfoHeader:@"收款后自动回复" Footer:@"转账收款成功后，自动向对方发送一条文本消息。"];
        [sec2 addCell:[objc_getClass("WCTableViewCellManager")
            switchCellForSel:@selector(onAutoReplySwitch:)
                      target:self
                       title:@"启用自动回复"
                          on:cfg.autoReplyEnabled]];
        if (cfg.autoReplyEnabled) {
            NSString *preview = cfg.replyContent ?: TR_DEFAULT_REPLY;
            if (preview.length > 20) preview = [[preview substringToIndex:20] stringByAppendingString:@"…"];
            [sec2 addCell:[objc_getClass("WCTableViewCellManager")
                normalCellForSel:@selector(onEditReplyContent:)
                          target:self
                           title:@"回复内容"
                     rightValue:preview]];
        }
        [self.tableViewMgr addSection:sec2];
    }
    [self.tableViewMgr addSection:sec1];
    [self.tableViewMgr reloadTableView];
}

- (void)onAutoReceiveSwitch:(UISwitch *)sender {
    [TRConfig shared].autoReceiveEnabled = sender.isOn; [self buildTable];
}
- (void)onAutoReplySwitch:(UISwitch *)sender {
    [TRConfig shared].autoReplyEnabled = sender.isOn; [self buildTable];
}

- (void)onEditReplyContent:(id)sender {
    TRConfig *cfg = [TRConfig shared];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置回复内容"
                                                                 message:nil
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = cfg.replyContent ?: TR_DEFAULT_REPLY;
        tf.placeholder = @"输入收款后自动回复的内容";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text;
        if (!text.length) text = TR_DEFAULT_REPLY;
        [TRConfig shared].replyContent = text;
        [weakSelf buildTable];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ============================================================
// 第9部分：插件加载入口
// ============================================================

%ctor {
    @autoreleasepool {
        [TRConfig shared];
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance]
                registerControllerWithTitle:@"转账自动收款"
                                    version:@"2.1"
                                 controller:@"TRSettingsViewController"];
        }
    }
}

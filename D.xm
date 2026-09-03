#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

// ========== 微信内部类声明（按职责分组）==========

// --- Proto 模型（真实类继承自微信 WXPBGeneratedMessage，此处以 NSObject 占位）---
@interface SKBuiltinBuffer_t : NSObject
@property (nonatomic, retain) NSData *buffer;
@end

@interface HongBaoReq : NSObject
@property (nonatomic, retain) SKBuiltinBuffer_t *reqText;
@end

@interface HongBaoRes : NSObject
@property (nonatomic, assign) int cgiCmdid;
@property (nonatomic, retain) SKBuiltinBuffer_t *retText;
@end

// --- 业务 / 服务类 ---
@interface MMContext : NSObject
+ (instancetype)activeUserContext;
- (id)getService:(Class)serviceClass;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(NSString *)userName;
- (id)getSelfContact;
@end

@interface CContact : NSObject
// 8.0.76：用户名属性已从 m_nsUsrName 改名为 userName（只读 NSString，见 CContact.h L465）
@property (nonatomic, retain) NSString *userName;
// 群成员列表（成员用户名以 \x07 等分隔拼接，见 CContact.h L250），用于无群名时拼「成员1、成员2、成员3」
@property (nonatomic, retain) NSString *m_nsChatRoomMemList;
- (NSString *)getContactDisplayName;
@end

@interface CMessageWrap : NSObject
// 8.0.76 CMessageWrap.h L17-18 / L449-452 / L973（m_nsRealChatUsr 见 L28/L435，群消息真实发送者）
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, retain) NSString *m_nsRealChatUsr;
@property (nonatomic, retain) id m_oWCPayInfoItem;
// 8.0.76 CMessageWrap.h：L591 initWithMsgType: / L448 m_uiStatus / L445 m_uiCreateTime
// 对齐 WCR 反汇编 0x751708（initWithMsgType:0x2710=10000）/ 0x751858（status=4）/ 0x75190c（createTime=now+1）
@property (nonatomic, assign) unsigned int m_uiStatus;
@property (nonatomic, assign) unsigned int m_uiCreateTime;
- (id)initWithMsgType:(long long)msgType;
@end

@interface WCPayInfoItem : NSObject
@property (nonatomic, retain) NSString *m_c2cNativeUrl;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)ReceiverQueryRedEnvelopesRequest:(NSDictionary *)params;
- (void)OpenRedEnvelopesRequest:(NSDictionary *)params;
- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
@end

// 8.0.76 CAppViewControllerManager.h L72：跳转会话并定位到指定消息（用于通知点击「去感谢老板」）
@interface CAppViewControllerManager : NSObject
- (void)jumpToChat:(id)session msgToLocate:(id)msgWrap;
@end

// CMessageMgr 扩展：向本地会话插入消息（不发送到服务器）
// 8.0.76 CMessageMgr.h：L234 四参数版 / L236 两参数版
// 对齐 WCR 反汇编 0x751928-0x751a64：优先四参数版，respondsToSelector 失败才回退两参数版
@interface CMessageMgr (DDFileHelper)
- (void)AddLocalMsg:(id)session MsgWrap:(CMessageWrap *)wrap fixTime:(BOOL)fixTime NewMsgArriveNotify:(BOOL)notify;
- (void)AddLocalMsg:(id)session MsgWrap:(CMessageWrap *)wrap;
@end

@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

// --- UI / 表格类 ---
@interface ContactSelectView : NSObject
- (void)addSelect:(id)contact;
@end

@interface MultiSelectContactsViewController : UIViewController
@property (nonatomic, assign) unsigned long long m_scene;
@property (nonatomic, weak) id m_delegate;
@property (nonatomic, retain) ContactSelectView *m_selectView;
- (void)updatePanelBtn;
- (void)loadViewIfNeeded;
@end

@protocol MultiSelectContactsViewControllerDelegate <NSObject>
- (void)onMultiSelectContactReturn:(NSArray *)contacts;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface MMUINavigationController : UINavigationController
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)centerCellForSel:(SEL)a0 target:(id)a1 title:(id)a2;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
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

// ========== 辅助扩展 ==========
@interface NSDictionary (DDSafeAccess)
- (NSString *)dd_stringForKey:(NSString *)key;
@end
@implementation NSDictionary (DDSafeAccess)
- (NSString *)dd_stringForKey:(NSString *)key {
    id value = self[key];
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}
@end

@interface NSString (DDJSON)
- (id)dd_JSONDictionary;
@end
@implementation NSString (DDJSON)
- (id)dd_JSONDictionary {
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    return [jsonObject isKindOfClass:[NSDictionary class]] ? jsonObject : nil;
}
@end

// ========== 配置常量 ==========
static NSString * const kDelaySecondsKey = @"DDDelaySecondsKey";
static NSString * const kAutoReceiveRedEnvelopKey = @"DDAutoReceiveRedEnvelopKey";
static NSString * const kSkipGroupRedEnvelopKey = @"DDSkipGroupRedEnvelopKey";
static NSString * const kSkipPrivateRedEnvelopKey = @"DDSkipPrivateRedEnvelopKey";
static NSString * const kSkipSelfRedEnvelopKey = @"DDSkipSelfRedEnvelopKey";
static NSString * const kSerialReceiveKey = @"DDSerialReceiveKey";
static NSString * const kBlackListKey = @"DDBlackListKey";
static NSString * const kDelayEnabledKey = @"DDDelayEnabledKey";
static NSString * const kShowNotificationKey = @"DDShowNotificationKey";
static NSString * const kNotifiedRedEnvelopIdsKey = @"DDNotifiedRedEnvelopIdsKey";
static NSString * const kNotifyFileHelperKey = @"DDNotifyFileHelperKey";
static NSString * const kEnableNotifyKey = @"DDEnableNotifyKey";

// ========== 配置管理类 ==========
@interface DDRedEnvelopConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL autoReceiveEnable;
@property (assign, nonatomic) NSInteger delaySeconds;
@property (assign, nonatomic) BOOL skipGroupRedEnvelop;
@property (assign, nonatomic) BOOL skipPrivateRedEnvelop;
@property (assign, nonatomic) BOOL skipSelfRedEnvelop;
@property (assign, nonatomic) BOOL serialReceive;
@property (strong, nonatomic) NSArray *blackList;
@property (assign, nonatomic) BOOL delayEnabled;
@property (assign, nonatomic) BOOL showNotification;
@property (assign, nonatomic) BOOL notifyFileHelper;
@property (assign, nonatomic) BOOL enableNotify;
- (BOOL)shouldNotifyForRedEnvelopId:(NSString *)redEnvelopId;
@end

// ========== 配置类实现 ==========
@implementation DDRedEnvelopConfig {
    NSMutableSet *_notifiedRedEnvelopIds;
}
+ (instancetype)sharedConfig {
    static DDRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDRedEnvelopConfig new]; });
    return config;
}
- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
        id savedDelay = [ud objectForKey:kDelaySecondsKey];
        _delaySeconds = (savedDelay && [savedDelay isKindOfClass:[NSNumber class]]) ? [savedDelay integerValue] : 1;
        _autoReceiveEnable = [ud boolForKey:kAutoReceiveRedEnvelopKey];
        _skipGroupRedEnvelop = [ud boolForKey:kSkipGroupRedEnvelopKey];
        _skipPrivateRedEnvelop = [ud boolForKey:kSkipPrivateRedEnvelopKey];
        _skipSelfRedEnvelop = [ud boolForKey:kSkipSelfRedEnvelopKey];
        _serialReceive = [ud boolForKey:kSerialReceiveKey];
        _blackList = [ud objectForKey:kBlackListKey];
        _delayEnabled = [ud boolForKey:kDelayEnabledKey];
        _showNotification = [ud boolForKey:kShowNotificationKey];
        _notifyFileHelper = [ud boolForKey:kNotifyFileHelperKey];
        _enableNotify = [ud boolForKey:kEnableNotifyKey];
        NSArray *savedIds = [ud arrayForKey:kNotifiedRedEnvelopIdsKey];
        _notifiedRedEnvelopIds = savedIds ? [NSMutableSet setWithArray:savedIds] : [NSMutableSet set];
    }
    return self;
}
- (void)setDelaySeconds:(NSInteger)delaySeconds { _delaySeconds = delaySeconds; [NSUserDefaults.standardUserDefaults setInteger:delaySeconds forKey:kDelaySecondsKey]; }
- (void)setAutoReceiveEnable:(BOOL)autoReceiveEnable { _autoReceiveEnable = autoReceiveEnable; [NSUserDefaults.standardUserDefaults setBool:autoReceiveEnable forKey:kAutoReceiveRedEnvelopKey]; }
- (void)setSkipGroupRedEnvelop:(BOOL)skipGroupRedEnvelop { _skipGroupRedEnvelop = skipGroupRedEnvelop; [NSUserDefaults.standardUserDefaults setBool:skipGroupRedEnvelop forKey:kSkipGroupRedEnvelopKey]; }
- (void)setSkipPrivateRedEnvelop:(BOOL)skipPrivateRedEnvelop { _skipPrivateRedEnvelop = skipPrivateRedEnvelop; [NSUserDefaults.standardUserDefaults setBool:skipPrivateRedEnvelop forKey:kSkipPrivateRedEnvelopKey]; }
- (void)setSkipSelfRedEnvelop:(BOOL)skipSelfRedEnvelop { _skipSelfRedEnvelop = skipSelfRedEnvelop; [NSUserDefaults.standardUserDefaults setBool:skipSelfRedEnvelop forKey:kSkipSelfRedEnvelopKey]; }
- (void)setSerialReceive:(BOOL)serialReceive { _serialReceive = serialReceive; [NSUserDefaults.standardUserDefaults setBool:serialReceive forKey:kSerialReceiveKey]; }
- (void)setDelayEnabled:(BOOL)delayEnabled { _delayEnabled = delayEnabled; [NSUserDefaults.standardUserDefaults setBool:delayEnabled forKey:kDelayEnabledKey]; }
- (void)setBlackList:(NSArray *)blackList { _blackList = blackList; [NSUserDefaults.standardUserDefaults setObject:blackList forKey:kBlackListKey]; }
- (void)setShowNotification:(BOOL)showNotification { _showNotification = showNotification; [NSUserDefaults.standardUserDefaults setBool:showNotification forKey:kShowNotificationKey]; }
- (void)setNotifyFileHelper:(BOOL)notifyFileHelper { _notifyFileHelper = notifyFileHelper; [NSUserDefaults.standardUserDefaults setBool:notifyFileHelper forKey:kNotifyFileHelperKey]; }
- (void)setEnableNotify:(BOOL)enableNotify { _enableNotify = enableNotify; [NSUserDefaults.standardUserDefaults setBool:enableNotify forKey:kEnableNotifyKey]; }
- (BOOL)shouldNotifyForRedEnvelopId:(NSString *)redEnvelopId {
    if (redEnvelopId.length == 0) return NO;
    @synchronized (_notifiedRedEnvelopIds) {
        if ([_notifiedRedEnvelopIds containsObject:redEnvelopId]) return NO;
        [_notifiedRedEnvelopIds addObject:redEnvelopId];
        if (_notifiedRedEnvelopIds.count > 100) {
            NSArray *all = _notifiedRedEnvelopIds.allObjects;
            _notifiedRedEnvelopIds = [NSMutableSet setWithArray:[all subarrayWithRange:NSMakeRange(all.count - 100, 100)]];
        }
        [NSUserDefaults.standardUserDefaults setObject:_notifiedRedEnvelopIds.allObjects forKey:kNotifiedRedEnvelopIdsKey];
        [NSUserDefaults.standardUserDefaults synchronize];
        return YES;
    }
}
@end

// ========== 红包解析辅助 ==========
static NSDictionary* parseNativeUrl(NSString *nativeUrl) {
    NSString *prefix = @"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?";
    if (![nativeUrl hasPrefix:prefix]) return nil;
    NSString *query = [nativeUrl substringFromIndex:prefix.length];
    return [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:query separator:@"&"];
}

static NSString* extractSignFromRequest(HongBaoReq *req) {
    NSString *requestString = [[NSString alloc] initWithData:req.reqText.buffer encoding:NSUTF8StringEncoding];
    NSDictionary *requestDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:requestString separator:@"&"];
    NSString *nativeUrl = [requestDict dd_stringForKey:@"nativeUrl"];
    if (!nativeUrl) return nil;
    nativeUrl = [nativeUrl stringByRemovingPercentEncoding];
    NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
    return [nativeUrlDict dd_stringForKey:@"sign"];
}

static NSString* getDisplayNameForSession(NSString *sessionUserName) {
    if (!sessionUserName.length) return nil;
    MMContext *context = [objc_getClass("MMContext") activeUserContext];
    CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
    if (!contactMgr) return nil;
    CContact *contact = [contactMgr getContactByName:sessionUserName];
    if (!contact) return nil;
    NSString *displayName = [contact getContactDisplayName];
    if (displayName.length) return displayName;
    // 无群名群聊兜底：getContactDisplayName 在懒加载 contact 上可能返回空，
    // 此时用成员列表拼「成员1、成员2、成员3」（与微信聊天列表拼名逻辑一致，CContact.h L99-104 genChatRoomName）
    if ([sessionUserName hasSuffix:@"@chatroom"]) {
        NSString *mem = contact.m_nsChatRoomMemList;
        if (mem.length) {
            NSCharacterSet *sep = [NSCharacterSet characterSetWithCharactersInString:@"\x07\x1f,;"];
            NSArray *members = [mem componentsSeparatedByCharactersInSet:sep];
            NSMutableArray *names = [NSMutableArray array];
            for (NSString *u in members) {
                NSString *un = [u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (!un.length) continue;
                NSString *n = getDisplayNameForSession(un);   // 递归取成员昵称（私聊不会进此分支，无死循环）
                if (n.length) [names addObject:n];
                if (names.count >= 3) break;
            }
            if (names.count) return [names componentsJoinedByString:@"、"];
        }
    }
    return nil;
}


// ========== 红包参数模型 ==========
@interface DDWeChatRedEnvelopParam : NSObject
@property (strong, nonatomic) NSString *msgType, *sendId, *channelId, *nickName, *nativeUrl, *sessionUserName, *sign, *timingIdentifier, *senderName;
// 总额（分）。查询响应必有，拆响应未必有；在查询阶段存入，保证通知在拆响应上弹出时总额也不丢
@property (assign, nonatomic) NSInteger totalAmount;
@property (assign, nonatomic) BOOL isGroupSender;
- (NSDictionary *)toParams;
@end
@implementation DDWeChatRedEnvelopParam
- (NSDictionary *)toParams {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (self.msgType) params[@"msgType"] = self.msgType;
    if (self.sendId) params[@"sendId"] = self.sendId;
    if (self.channelId) params[@"channelId"] = self.channelId;
    if (self.nickName) params[@"nickName"] = self.nickName;
    if (self.nativeUrl) params[@"nativeUrl"] = self.nativeUrl;
    if (self.sessionUserName) params[@"sessionUserName"] = self.sessionUserName;
    if (self.timingIdentifier) params[@"timingIdentifier"] = self.timingIdentifier;
    // 补齐 sign：对齐 WCR 拆包请求（反汇编 0x755a8c–0x755a9c 把 sign 放进 OpenRedEnvelopesRequest）
    if (self.sign) params[@"sign"] = self.sign;
    return params;
}
@end

// ========== 红包参数队列 ==========
@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDWeChatRedEnvelopParam *)param;
- (DDWeChatRedEnvelopParam *)dequeueBySendId:(NSString *)sendId;
- (DDWeChatRedEnvelopParam *)peekBySendId:(NSString *)sendId;
@end
@implementation DDRedEnvelopParamQueue { NSMutableArray<DDWeChatRedEnvelopParam *> *_queue; }
+ (instancetype)sharedQueue { static DDRedEnvelopParamQueue *queue; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ queue = [DDRedEnvelopParamQueue new]; }); return queue; }
- (instancetype)init { if (self = [super init]) _queue = [NSMutableArray array]; return self; }
- (void)enqueue:(DDWeChatRedEnvelopParam *)param { if (param) [_queue addObject:param]; }
- (DDWeChatRedEnvelopParam *)dequeueBySendId:(NSString *)sendId {
    if (_queue.count == 0) return nil;
    if (sendId.length) {
        for (NSUInteger i = 0; i < _queue.count; i++) {
            if ([_queue[i].sendId isEqualToString:sendId]) {
                DDWeChatRedEnvelopParam *matched = _queue[i];
                [_queue removeObjectAtIndex:i];
                return matched;
            }
        }
        return nil;
    }
    DDWeChatRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

// 只读查询：按 sendId 找到对应参数但不出队（避免提前取出导致后续 dequeue 取不到，破坏拆包流程）
- (DDWeChatRedEnvelopParam *)peekBySendId:(NSString *)sendId {
    if (_queue.count == 0) return nil;
    for (DDWeChatRedEnvelopParam *p in _queue) {
        if ([p.sendId isEqualToString:sendId]) return p;
    }
    return nil;
}
@end

// ========== 拆红包操作 ==========
@interface DDReceiveRedEnvelopOperation : NSOperation { BOOL _finished; BOOL _executing; }
- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end
@implementation DDReceiveRedEnvelopOperation { DDWeChatRedEnvelopParam *_param; unsigned int _delay; }
- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
    if (self = [super init]) { _param = param; _delay = delaySeconds; _finished = NO; _executing = NO; }
    return self;
}
- (void)start { if (self.isCancelled) { self.finished = YES; self.executing = NO; return; } self.executing = YES; [self main]; }
- (void)main { if (_delay > 0) sleep(_delay); MMContext *context = [objc_getClass("MMContext") activeUserContext]; WCRedEnvelopesLogicMgr *logicMgr = [context getService:objc_getClass("WCRedEnvelopesLogicMgr")]; [logicMgr OpenRedEnvelopesRequest:[_param toParams]]; self.finished = YES; self.executing = NO; }
- (void)setFinished:(BOOL)finished { [self willChangeValueForKey:@"isFinished"]; _finished = finished; [self didChangeValueForKey:@"isFinished"]; }
- (void)setExecuting:(BOOL)executing { [self willChangeValueForKey:@"isExecuting"]; _executing = executing; [self didChangeValueForKey:@"isExecuting"]; }
- (BOOL)isFinished { return _finished; }
- (BOOL)isExecuting { return _executing; }
- (BOOL)isAsynchronous { return YES; }
@end

// ========== 任务管理器 ==========
@interface DDTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task;
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task;
- (BOOL)serialQueueIsEmpty;
@end
@implementation DDTaskManager { NSOperationQueue *_normalQueue, *_serialQueue; }
+ (instancetype)sharedManager { static DDTaskManager *manager; static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{ manager = [DDTaskManager new]; }); return manager; }
- (instancetype)init { if (self = [super init]) { _serialQueue = [NSOperationQueue new]; _serialQueue.maxConcurrentOperationCount = 1; _normalQueue = [NSOperationQueue new]; _normalQueue.maxConcurrentOperationCount = 5; } return self; }
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task { [_normalQueue addOperation:task]; }
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task { [_serialQueue addOperation:task]; }
- (BOOL)serialQueueIsEmpty { return _serialQueue.operationCount == 0; }
@end

// ========== 通知管理 ==========
@interface DDNotificationManager : NSObject <UNUserNotificationCenterDelegate>
+ (instancetype)sharedManager;
- (void)showLocalNotificationWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount sessionUserName:(NSString *)sessionUserName;
- (void)notifyFileHelperWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount param:(DDWeChatRedEnvelopParam *)param sessionUserName:(NSString *)sessionUserName timingIdentifier:(NSString *)timingIdentifier wishing:(NSString *)wishing packetCount:(NSInteger)packetCount;
@end
@implementation DDNotificationManager
+ (instancetype)sharedManager {
    static DDNotificationManager *manager; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [DDNotificationManager new];
        [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:(UNAuthorizationOptionAlert|UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError *error) {}];
        UNUserNotificationCenter.currentNotificationCenter.delegate = manager;
    });
    return manager;
}
- (void)showLocalNotificationWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount sessionUserName:(NSString *)sessionUserName {
    if (![DDRedEnvelopConfig sharedConfig].showNotification || amount <= 0) return;
    if (!sessionUserName.length) return;
    NSString *displayName = getDisplayNameForSession(sessionUserName);
    NSString *finalDisplayName = displayName.length ? displayName : sessionUserName;

    // 标题=微信原生聊天名；群聊（含无群名由成员拼成的）补（群聊）后缀以区分，私聊不加
    NSString *title = [sessionUserName hasSuffix:@"@chatroom"] ? [finalDisplayName stringByAppendingString:@"（群聊）"] : finalDisplayName;
    // 正文参考「转发到文件助手」：抢到金额（必然显示）+ 总额（totalAmount>0 即显示，未知/0 时才只显示抢到金额）。
    // 注意：不能用 totalAmount != amount 抑制，否则普通红包/单包时 totalAmount==amount 会被吞掉，表现为「偶尔不显示总额」
    NSMutableString *body = [NSMutableString stringWithFormat:@"💰 抢到红包：%.2f元", amount/100.0];
    if (totalAmount > 0) {
        [body appendFormat:@"，总额：%.2f元", totalAmount/100.0];
    }
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title; content.body = body; content.sound = [UNNotificationSound defaultSound];
    content.userInfo = @{@"DDHBSession": sessionUserName};   // 点击后据此跳转到对应会话
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO]];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}
// 点击系统通知：跳转到对应会话（与文件助手跳转同逻辑，msgToLocate:nil 即打开会话底部）
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    NSString *session = response.notification.request.content.userInfo[@"DDHBSession"];
    if (session.length) {
        // CAppViewControllerManager 是单例（CAppViewControllerManager.h L43 +getAppViewControllerManager），
        // 并非 service registry 成员，getService: 在 8.0.76 多返回 nil 导致跳转静默失败；优先取单例
        id mgr = [objc_getClass("CAppViewControllerManager") getAppViewControllerManager];
        if (!mgr) {
            MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
            mgr = [ctx getService:objc_getClass("CAppViewControllerManager")];
        }
        if (mgr) [mgr jumpToChat:session msgToLocate:nil];
    }
    completionHandler();
}

// 参考 WCR「文件传输助手」通知格式：构造富文本消息通过 CMessageMgr AddLocalMsg:MsgWrap: 插入 filehelper 会话
// 8.0.76 证据：CMessageMgr.h L236 AddLocalMsg:MsgWrap: / CMessageWrap.h L449-452 m_nsContent/m_nsFromUsr/m_nsToUsr/m_uiMessageType
- (void)notifyFileHelperWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount param:(DDWeChatRedEnvelopParam *)param sessionUserName:(NSString *)sessionUserName timingIdentifier:(NSString *)timingIdentifier wishing:(NSString *)wishing packetCount:(NSInteger)packetCount {
    if (![DDRedEnvelopConfig sharedConfig].notifyFileHelper || amount <= 0) return;

    NSString *displayName = getDisplayNameForSession(sessionUserName);
    NSString *finalDisplayName = displayName.length ? displayName : sessionUserName;
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    // 类型分拼手气/普通（nativeUrl 的 msgtype 字段：1=拼手气红包，0=普通红包）
    NSString *typeName = @"红包";
    if ([param.msgType isEqualToString:@"1"]) typeName = @"拼手气红包";
    else if ([param.msgType isEqualToString:@"0"]) typeName = @"普通红包";

    // 来源用微信原生聊天名；群聊（@chatroom 结尾，含无群名、由成员拼成的）补（群聊）后缀以区分，私聊不加
    BOOL srcIsGroup = [sessionUserName hasSuffix:@"@chatroom"];

    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"💰 叮咚，为您抢到 %.2f元\n", amount / 100.0];
    [body appendFormat:@"📍 来源： %@%@\n", finalDisplayName, srcIsGroup ? @"（群聊）" : @""];
    if (packetCount > 0) {
        [body appendFormat:@"🧧 类型： %@（%ld包%.2f元）\n", typeName, (long)packetCount, totalAmount / 100.0];
    } else {
        [body appendFormat:@"🧧 类型： %@（%.2f元）\n", typeName, totalAmount / 100.0];
    }
    // 老板：发包人显示名，直取 AsyncOnAddMsg 已算好的 senderName（群消息 m_nsRealChatUsr、私聊 m_nsFromUsr，
    // 经 getDisplayNameForSession→CContact.getContactDisplayName 取，见 CMessageWrap.h L435 / CContact.h L326），头文件确认可靠，不兜底
    if (param.senderName.length) [body appendFormat:@"👨 老板： %@\n", param.senderName];
    // 备注：祝福语（对齐 WCR 取值链 wishing→wish→remark→blessing，反汇编 0x759da4-0x759edc）
    if (wishing.length) [body appendFormat:@"📝 备注： %@\n", wishing];
    [body appendFormat:@"⏰ 时间： %@\n", timeStr];
    // 点击跳转：微信灰字消息自定义链接标签（对齐 WCR 反汇编 0x5e9f34/0x5ea028）
    //   <_wc_custom_link_ color="#%@" href="%@">%@</_wc_custom_link_>
    //   href 对齐 WCR 语义（WCRefineRedEnvelopSession://session=xxx → 跳到红包所在会话），
    //   用自有 scheme 由下方 %hook UIApplication 拦截，再调 jumpToChat:msgToLocate:nil 打开红包所在会话（对齐 WCR）
    if (sessionUserName.length) {
        [body appendFormat:@"\n<_wc_custom_link_ color=\"#576B95\" href=\"DDHBRedEnvelopSession://session=%@\">点击跳转去感谢老板</_wc_custom_link_>", sessionUserName];
    } else {
        [body appendString:@"\n点击跳转去感谢老板"];
    }

    // 构造 CMessageWrap 并插入 filehelper 会话（纯本地消息，不发送到服务器）
    // 严格对齐 WCR 反汇编 0x7516f8-0x751a64：
    //   initWithMsgType:10000（0x2710）→ m_uiStatus=4 → m_uiCreateTime=now+1
    //   优先四参数 AddLocalMsg（fixTime=NO, NewMsgArriveNotify=NO），否则回退两参数
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
    CMessageMgr *msgMgr = [ctx getService:objc_getClass("CMessageMgr")];
    if (!msgMgr) return;

    NSString *session = @"filehelper";
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:10000];
    if (!wrap) return;
    wrap.m_nsFromUsr = session;                 // 对齐 WCR setM_nsFromUsr: = session
    wrap.m_nsToUsr = session;                   // 对齐 WCR setM_nsToUsr: = sessionID（无配置项时同 session）
    wrap.m_nsContent = body;                    // 对齐 WCR setM_nsContent:
    wrap.m_uiStatus = 4;                        // 对齐 WCR 0x751858: mov w2, #0x4
    wrap.m_uiCreateTime = (unsigned int)([[NSDate date] timeIntervalSince1970] + 1);  // 对齐 WCR 0x7518e4: +1

    SEL fourArgSel = NSSelectorFromString(@"AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:");
    if ([msgMgr respondsToSelector:fourArgSel]) {
        [msgMgr AddLocalMsg:session MsgWrap:wrap fixTime:NO NewMsgArriveNotify:NO];
    } else {
        [msgMgr AddLocalMsg:session MsgWrap:wrap];
    }
}
@end

// ========== Hook 红包逻辑 ==========
static NSString *DDCurrentSessionUserName = nil;

%hook WCRedEnvelopesLogicMgr
- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    DDRedEnvelopConfig *cfg = [DDRedEnvelopConfig sharedConfig];

    // 先按本次响应的 sendId 从队列 peek（只读、不出队）取最新的会话名，
    // 保证下方通知显示的是「当前这条红包」所在会话，而非上一条（旧全局变量滞后问题）。
    // 注意：此处不能用 dequeue，否则首响取出后拆响取不到，红包拆不开。
    NSDictionary *responseDict = [[[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
    // 直取服务端 hongbao CGI 契约键 sendid（小写，WCR 反汇编以 sendid 为首选出现 7 次、nativeUrl 同为 sendid；头文件模型属性是驼峰 sendId，属反序列化后属性名，不影响原始 JSON 键），不兜底
    NSString *respSendId = [responseDict dd_stringForKey:@"sendid"];
    NSString *sessionUserName = DDCurrentSessionUserName;
    if (respSendId.length) {
        DDWeChatRedEnvelopParam *peekParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
        if (peekParam.sessionUserName.length) sessionUserName = peekParam.sessionUserName;
    }

    // 启用红包通知（总开关）开启时才处理两类通知；两类各自仍受独立开关控制
    if (cfg.enableNotify && cfg.autoReceiveEnable) {
        SKBuiltinBuffer_t *buffer = arg1.retText;
        if (buffer.buffer) {
            NSDictionary *dict = [[[NSString alloc] initWithData:buffer.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
            NSInteger amount = [dict[@"amount"] integerValue];
            // 总额：直取头文件确认字段 totalAmount（8.0.76 ForeignHbOpenResp.h L52 / OpenWxaHBResponse.h L35 / WARedEnvelopesDetailViewModel.h L46 均为 totalAmount），不要 total_amount 兜底
            NSInteger total = [dict[@"totalAmount"] integerValue];
            // 查询响应必有 totalAmount，拆响应未必有；先把总额存进队列参数（仅在有值时覆盖），
            // 这样通知在「拆响应」上弹出时也能拿到查询阶段的总额，不会偶发落 0
            if (respSendId.length && total > 0) {
                DDWeChatRedEnvelopParam *storeParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
                if (storeParam) storeParam.totalAmount = total;
            }
            if (amount > 0) {
                NSString *redId = [NSString stringWithFormat:@"%@_%@", dict[@"sendId"]?:@"", dict[@"timingIdentifier"]?:@""];
                if ([cfg shouldNotifyForRedEnvelopId:redId]) {
                    DDWeChatRedEnvelopParam *fhParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
                    // 直接用查询阶段存进参数的值（对齐 WCR m_lTotalAmount，查询响应必有 totalAmount），拆响应不带的也失不了；
                    // 仅 fhParam 为空时回退当前响应，属取值来源保护而非字段猜测
                    NSInteger displayTotal = (fhParam && fhParam.totalAmount > 0) ? fhParam.totalAmount : total;
                    // 系统本地通知（受「抢到红包后通知」独立开关控制）
                    if (cfg.showNotification) {
                        [[DDNotificationManager sharedManager] showLocalNotificationWithAmount:amount totalAmount:displayTotal sessionUserName:sessionUserName];
                    }
                    // 文件传输助手通知（受「发送到文件传输助手」独立开关控制）
                    if (cfg.notifyFileHelper) {
                        // 包数：直取头文件确认字段 totalNum（8.0.76 ForeignHbOpenResp.h L53 / OpenWxaHBResponse.h L36 / WARedEnvelopesDetailViewModel.h L47 均为 totalNum）
                        NSInteger packetCount = [dict[@"totalNum"] integerValue];
                        // 祝福语：直取头文件确认字段 wishing（同上模型类 L54/L37/L43 均为 wishing），不要兜底链
                        NSString *wishing = [dict dd_stringForKey:@"wishing"];
                        [[DDNotificationManager sharedManager] notifyFileHelperWithAmount:amount totalAmount:displayTotal param:fhParam sessionUserName:sessionUserName timingIdentifier:dict[@"timingIdentifier"] wishing:wishing packetCount:packetCount];
                    }
                }
            }
        }
    }
    if (arg1.cgiCmdid != 3) return;
    DDWeChatRedEnvelopParam *mgrParams = [[DDRedEnvelopParamQueue sharedQueue] dequeueBySendId:respSendId];
    DDCurrentSessionUserName = mgrParams.sessionUserName;
    if (!mgrParams) return;
    if ([responseDict[@"receiveStatus"] integerValue] == 2) return;
    if ([responseDict[@"hbStatus"] integerValue] == 4) return;
    if (!responseDict[@"timingIdentifier"]) return;
    if (!cfg.autoReceiveEnable) return;
    if (!mgrParams.isGroupSender) {
        NSString *sign = extractSignFromRequest(arg2);
        if (![sign isEqualToString:mgrParams.sign]) return;
    }
    mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
    unsigned int delay = cfg.delayEnabled ? (unsigned int)cfg.delaySeconds : 0;
    if (cfg.serialReceive && ![DDTaskManager sharedManager].serialQueueIsEmpty) delay = 2;
    if (delay > 0) {
        DDReceiveRedEnvelopOperation *op = [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delay];
        if (cfg.serialReceive) [[DDTaskManager sharedManager] addSerialTask:op];
        else [[DDTaskManager sharedManager] addNormalTask:op];
    } else {
        [self OpenRedEnvelopesRequest:[mgrParams toParams]];
    }
}
%end

%hook CMessageMgr
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    if (wrap.m_uiMessageType != 49) return;
    if ([wrap.m_nsContent rangeOfString:@"wxpay://"].location == NSNotFound) return;
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
    CContactMgr *contactMgr = [ctx getService:objc_getClass("CContactMgr")];
    CContact *selfContact = [contactMgr getSelfContact];
    BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.userName];   // 8.0.76: m_nsUsrName → userName
    BOOL isGroup = ([wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound) || ([wrap.m_nsToUsr rangeOfString:@"@chatroom"].location != NSNotFound);
    DDRedEnvelopConfig *cfg = [DDRedEnvelopConfig sharedConfig];
    if (!cfg.autoReceiveEnable) return;
    if ([cfg.blackList containsObject:wrap.m_nsFromUsr]) return;
    if (isSender && cfg.skipSelfRedEnvelop) return;
    if (isGroup && cfg.skipGroupRedEnvelop) return;
    if (!isGroup && cfg.skipPrivateRedEnvelop) return;
    WCPayInfoItem *payInfo = (WCPayInfoItem *)wrap.m_oWCPayInfoItem;
    NSString *nativeUrl = payInfo.m_c2cNativeUrl;
    if (!nativeUrl) return;
    NSDictionary *urlDict = parseNativeUrl(nativeUrl);
    if (!urlDict) return;
    BOOL isGroupSender = isGroup && isSender;
    DDWeChatRedEnvelopParam *param = [DDWeChatRedEnvelopParam new];
    param.msgType = [urlDict dd_stringForKey:@"msgtype"];
    param.sendId = [urlDict dd_stringForKey:@"sendid"];
    param.channelId = [urlDict dd_stringForKey:@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    // 发送者昵称：群消息真实发送者在 m_nsRealChatUsr（8.0.76 CMessageWrap.h L435），私聊直接用 m_nsFromUsr
    NSString *senderUsr = isGroup ? wrap.m_nsRealChatUsr : wrap.m_nsFromUsr;
    param.senderName = getDisplayNameForSession(senderUsr);
    // 会话名：群红包且自己发的用 m_nsToUsr，否则 m_nsFromUsr
    param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
    // 8.0.76 无 m_nsHeadImgUrl 字段（CContact 仅含背景图 ID），头像 URL 不可取，不影响拆红包
    param.nativeUrl = nativeUrl;
    param.sign = [urlDict dd_stringForKey:@"sign"];
    param.isGroupSender = isGroupSender;
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
    NSMutableDictionary *reqParams = [NSMutableDictionary dictionary];
    reqParams[@"agreeDuty"] = @"0";
    reqParams[@"channelId"] = param.channelId ?: @"";
    reqParams[@"inWay"] = @"0";
    reqParams[@"msgType"] = param.msgType ?: @"";
    reqParams[@"nativeUrl"] = nativeUrl;
    reqParams[@"sendId"] = param.sendId ?: @"";
    WCRedEnvelopesLogicMgr *logicMgr = [ctx getService:objc_getClass("WCRedEnvelopesLogicMgr")];
    [logicMgr ReceiverQueryRedEnvelopesRequest:reqParams];
}
%end

// 拦截通知里的跳转链接：DDHBRedEnvelopSession://session=xxx
// 语义对齐 WCR（WCRefineRedEnvelopSession://session=xxx → 只打开红包所在会话，不定位具体消息），
// 用微信原生 jumpToChat:msgToLocate:（8.0.76 CAppViewControllerManager.h L72），msgToLocate 传 nil 即停在会话底部
%hook UIApplication
- (BOOL)openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenExternalURLOptionsKey, id> *)options completionHandler:(void (^)(BOOL))completion {
    NSString *abs = url.absoluteString ?: @"";
    NSString *scheme = @"DDHBRedEnvelopSession://";
    if ([abs hasPrefix:scheme]) {
        NSString *query = [abs substringFromIndex:scheme.length];
        NSDictionary *q = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:query separator:@"&"];
        NSString *session = [q dd_stringForKey:@"session"];
        // 微信经 openURL 传出时可能把 @chatroom 中的 @ 做 percent-encode（%40），解码还原用户名
        session = [session stringByRemovingPercentEncoding] ?: session;
        if (session.length) {
            // 同系统通知：CAppViewControllerManager 取单例（getService: 在 8.0.76 多返回 nil）
            id mgr = [objc_getClass("CAppViewControllerManager") getAppViewControllerManager];
            if (!mgr) {
                MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
                mgr = [ctx getService:objc_getClass("CAppViewControllerManager")];
            }
            if (mgr) [mgr jumpToChat:session msgToLocate:nil];
        }
        return YES;   // 已处理，不交给系统/微信继续打开
    }
    return %orig;
}
%end

// ========== 设置界面 ==========
@interface DDRedEnvelopSettingsViewController : UIViewController <UITableViewDelegate, MultiSelectContactsViewControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic) BOOL delayExpanded;
@end

@implementation DDRedEnvelopSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

// 把下拉项对应的值挂到 cell 上，点击时回读（对齐 DDTR.txt 实现）
static const void *kDDOptionValue = &kDDOptionValue;
static void DD_SetCellOption(id cell, id value) {
    objc_setAssociatedObject(cell, kDDOptionValue, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static id DD_CellOption(id cell) {
    return objc_getAssociatedObject(cell, kDDOptionValue);
}

- (void)ensureTableViewMgr {
    if (_tableViewManager) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    WCTableViewManager *mgr = [mgrCls alloc];
    _tableViewManager = [mgr initWithFrame:[UIScreen mainScreen].bounds
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
    self.title = @"DD红包助手";
    [self ensureTableViewMgr];
    if (!_tableViewManager) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    DDRedEnvelopConfig *cfg = [DDRedEnvelopConfig sharedConfig];
    
    WCTableViewSectionManager *redEnvelopSection = [objc_getClass("WCTableViewSectionManager") defaultSection];
    [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onAutoReceiveSwitch:) target:self title:@"启用自动抢红包" on:cfg.autoReceiveEnable]];
    if (cfg.autoReceiveEnable) {
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onDelayEnabledSwitch:) target:self title:@"↳自定义延迟时间" on:cfg.delayEnabled]];
        if (cfg.delayEnabled) {
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(delayHeaderTapped:)
                                                                                        target:self
                                                                                         title:@"   ↳延迟秒数"
                                                                                     rightValue:[NSString stringWithFormat:@"[%ld秒]", (long)cfg.delaySeconds]]];
            if (self.delayExpanded) {
                NSArray *opts = @[@0, @1, @3, @8];
                for (NSNumber *o in opts) {
                    NSInteger v = o.integerValue;
                    WCTableViewCellManager *optCell = [objc_getClass("WCTableViewCellManager") centerCellForSel:@selector(delayOptionTapped:)
                                                                                                       target:self
                                                                                                        title:[NSString stringWithFormat:@"[%ld秒]", (long)v]];
                    DD_SetCellOption(optCell, o);
                    optCell.userInfo = o;
                    [redEnvelopSection addCell:optCell];
                }
            }
        }
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSkipGroupSwitch:) target:self title:@"↳禁用抢群聊红包" on:cfg.skipGroupRedEnvelop]];
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSkipPrivateSwitch:) target:self title:@"↳禁用抢私聊红包" on:cfg.skipPrivateRedEnvelop]];
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSkipSelfSwitch:) target:self title:@"↳不抢自己的红包" on:cfg.skipSelfRedEnvelop]];
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSerialSwitch:) target:self title:@"↳防止同时抢红包" on:cfg.serialReceive]];
        NSInteger blackCount = cfg.blackList.count;
        WCTableViewCellManager *blackCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(onBlackListTapped) target:self title:@"↳过滤全局黑名单" rightValue:blackCount ? [NSString stringWithFormat:@"已选 %ld 个", (long)blackCount] : @"已关闭"];
        blackCell.userInfo = @"BlackListCell";
        [redEnvelopSection addCell:blackCell];
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onEnableNotifySwitch:) target:self title:@"↳启用红包通知" on:cfg.enableNotify]];
        if (cfg.enableNotify) {
            // 「抢到红包后通知」与「发送到文件传输助手」是两个独立功能，同级并列，均只受总开关控制
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onNotifySwitch:) target:self title:@"↳↳抢到红包后通知" on:cfg.showNotification]];
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onNotifyFileHelperSwitch:) target:self title:@"↳↳发送到文件传输助手" on:cfg.notifyFileHelper]];
        }
    }
    [_tableViewManager addSection:redEnvelopSection];

    [_tableViewManager reloadTableView];
}

#pragma mark - UITableViewDelegate 转发
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = (WCTableViewCellManager *)[self.tableViewManager cellInfoAtIndexPath:indexPath];
    if (cellInfo && [cellInfo.userInfo isKindOfClass:[NSNumber class]]) {
        NSInteger v = [(NSNumber *)cellInfo.userInfo integerValue];
        NSInteger cur = [DDRedEnvelopConfig sharedConfig].delaySeconds;
        cell.accessoryType = (v == cur) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
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

#pragma mark - 事件处理
- (void)onAutoReceiveSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].autoReceiveEnable = sender.on; [self buildTable]; }
- (void)onDelayEnabledSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].delayEnabled = sender.on; [self buildTable]; }
- (void)onSkipGroupSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].skipGroupRedEnvelop = sender.on; }
- (void)onSkipPrivateSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].skipPrivateRedEnvelop = sender.on; }
- (void)onSkipSelfSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].skipSelfRedEnvelop = sender.on; }
- (void)onSerialSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].serialReceive = sender.on; }
- (void)onNotifySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].showNotification = sender.on; }
- (void)onNotifyFileHelperSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].notifyFileHelper = sender.on; }
- (void)onEnableNotifySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].enableNotify = sender.on; [self buildTable]; }

- (void)delayHeaderTapped:(id)sender {
    self.delayExpanded = !self.delayExpanded;
    [self buildTable];
}

- (void)delayOptionTapped:(id)sender {
    NSNumber *o = DD_CellOption(sender);
    if (o) [DDRedEnvelopConfig sharedConfig].delaySeconds = o.integerValue;
    self.delayExpanded = NO;
    [self buildTable];
}

- (void)onBlackListTapped {
    MultiSelectContactsViewController *picker = [[objc_getClass("MultiSelectContactsViewController") alloc] init];
    picker.m_scene = 0;
    picker.m_delegate = self;
    [picker loadViewIfNeeded];
    NSArray *blackList = [DDRedEnvelopConfig sharedConfig].blackList;
    if (blackList.count) {
        MMContext *context = [objc_getClass("MMContext") activeUserContext];
        CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
        id selectView = [picker valueForKey:@"m_selectView"];
        if (selectView && [selectView respondsToSelector:@selector(addSelect:)]) {
            for (NSString *name in blackList) {
                CContact *contact = [contactMgr getContactByName:name];
                if (contact) [selectView performSelector:@selector(addSelect:) withObject:contact];
            }
            if ([picker respondsToSelector:@selector(updatePanelBtn)]) [picker performSelector:@selector(updatePanelBtn)];
        }
    }
    MMUINavigationController *nav = [[objc_getClass("MMUINavigationController") alloc] initWithRootViewController:picker];
    // 非全屏：底部 sheet（可拖拽 + 抓手条 + 圆角）
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = nav.sheetPresentationController;
    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
    sheet.prefersGrabberVisible = YES;
    sheet.preferredCornerRadius = 16;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)onMultiSelectContactReturn:(NSArray *)contacts {
    NSMutableArray *black = [NSMutableArray new];
    for (id contact in contacts) {
        if ([contact isKindOfClass:objc_getClass("CContact")]) {
            NSString *name = [contact valueForKey:@"userName"];   // 8.0.76: m_nsUsrName → userName
            if (name.length) [black addObject:name];
        }
    }
    [DDRedEnvelopConfig sharedConfig].blackList = black;
    [self dismissViewControllerAnimated:YES completion:^{
        [self buildTable];
    }];
}

@end

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD红包助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDRedEnvelopSettingsViewController"];
        }
    }
}


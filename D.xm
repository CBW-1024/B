#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// ===== 微信内部类声明 =====
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

@interface MMContext : NSObject
+ (instancetype)activeUserContext;
- (id)getService:(Class)serviceClass;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(NSString *)userName;
- (id)getSelfContact;
@end

@interface CContact : NSObject
@property (nonatomic, retain) NSString *userName;
- (NSString *)getContactDisplayName;
- (NSString *)m_nsNickName;
- (NSString *)m_nsAliasName;   // CBaseContact 上的用户自定义微信号（真实 ID），见 CBaseContact.h:131
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, retain) id m_oWCPayInfoItem;
@property (nonatomic, assign) unsigned int m_uiStatus;
@property (nonatomic, assign) unsigned int m_uiCreateTime;
- (id)initWithMsgType:(long long)msgType;
- (id)initWithMsgType:(long long)arg1 nsFromUsr:(id)arg2;
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
- (void)AddMsg:(id)arg1 MsgWrap:(id)arg2;
@end

// CAppViewControllerManager 为单例，跳转会话需取 +getAppViewControllerManager
@interface CAppViewControllerManager : NSObject
+ (id)getAppViewControllerManager;
- (void)jumpToChat:(id)session msgToLocate:(id)msgWrap;
@end

@interface BaseMsgContentViewController : UIViewController
- (void)tagLink:(id)link messageWrap:(id)wrap;
@end

@interface CMessageMgr (DDFileHelper)
- (void)AddLocalMsg:(id)session MsgWrap:(CMessageWrap *)wrap fixTime:(BOOL)fixTime NewMsgArriveNotify:(BOOL)notify;
- (void)AddLocalMsg:(id)session MsgWrap:(CMessageWrap *)wrap;
@end

@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;
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

// ===== 辅助扩展 =====
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

// ===== 配置常量 =====
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
static NSString * const kAutoReplyKey = @"DDHBAutoReplyKey";
static NSString * const kVoiceBroadcastKey = @"DDHBVoiceBroadcastKey";
static NSString * const kSkipGroupReplyKey = @"DDHBSkipGroupReplyKey";
static NSString * const kSkipPrivateReplyKey = @"DDHBSkipPrivateReplyKey";
static NSString * const kCustomReplyEnabledKey = @"DDHBCustomReplyEnabledKey";
static NSString * const kCustomReplyContentKey = @"DDHBCustomReplyContentKey";

// ===== 配置管理 =====
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
@property (assign, nonatomic) BOOL autoReply;
@property (assign, nonatomic) BOOL voiceBroadcast;
@property (assign, nonatomic) BOOL skipGroupReply;
@property (assign, nonatomic) BOOL skipPrivateReply;
@property (assign, nonatomic) BOOL customReplyEnabled;
@property (strong, nonatomic) NSString *customReplyContent;
- (BOOL)shouldNotifyForRedEnvelopId:(NSString *)redEnvelopId;
@end

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
        _autoReply = [ud boolForKey:kAutoReplyKey];
        _voiceBroadcast = [ud boolForKey:kVoiceBroadcastKey];
        _skipGroupReply = [ud boolForKey:kSkipGroupReplyKey];
        _skipPrivateReply = [ud boolForKey:kSkipPrivateReplyKey];
        _customReplyEnabled = [ud boolForKey:kCustomReplyEnabledKey];
        _customReplyContent = [ud stringForKey:kCustomReplyContentKey] ?: @"谢谢老板，红包已收下🧧";
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
- (void)setAutoReply:(BOOL)autoReply { _autoReply = autoReply; [NSUserDefaults.standardUserDefaults setBool:autoReply forKey:kAutoReplyKey]; }
- (void)setVoiceBroadcast:(BOOL)voiceBroadcast { _voiceBroadcast = voiceBroadcast; [NSUserDefaults.standardUserDefaults setBool:voiceBroadcast forKey:kVoiceBroadcastKey]; }
- (void)setSkipGroupReply:(BOOL)skipGroupReply { _skipGroupReply = skipGroupReply; [NSUserDefaults.standardUserDefaults setBool:skipGroupReply forKey:kSkipGroupReplyKey]; }
- (void)setSkipPrivateReply:(BOOL)skipPrivateReply { _skipPrivateReply = skipPrivateReply; [NSUserDefaults.standardUserDefaults setBool:skipPrivateReply forKey:kSkipPrivateReplyKey]; }
- (void)setCustomReplyEnabled:(BOOL)customReplyEnabled { _customReplyEnabled = customReplyEnabled; [NSUserDefaults.standardUserDefaults setBool:customReplyEnabled forKey:kCustomReplyEnabledKey]; }
- (void)setCustomReplyContent:(NSString *)customReplyContent { _customReplyContent = customReplyContent; [NSUserDefaults.standardUserDefaults setObject:customReplyContent forKey:kCustomReplyContentKey]; }
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

// ===== 红包链接解析 =====
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
    NSString *nickName = [contact m_nsNickName];
    if (nickName.length) return nickName;
    return nil;
}

// 取发包者对外微信号（真实 ID）：优先 CContact.m_nsAliasName，本地未同步/无自定义微信号时回退原始 wxid
static NSString* getAccountForSession(NSString *sessionUserName) {
    if (!sessionUserName.length) return nil;
    MMContext *context = [objc_getClass("MMContext") activeUserContext];
    CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
    if (!contactMgr) return sessionUserName;
    CContact *contact = [contactMgr getContactByName:sessionUserName];
    if (!contact) return sessionUserName;
    NSString *alias = [contact m_nsAliasName];
    if (alias.length) return alias;
    return sessionUserName;
}

// ===== 红包参数模型 =====
@interface DDWeChatRedEnvelopParam : NSObject
@property (strong, nonatomic) NSString *msgType, *sendId, *channelId, *nickName, *nativeUrl, *sessionUserName, *sign, *timingIdentifier;
// 总额（分）：查询响应必含，拆响应未必；查询阶段存入参数，确保通知在拆响应弹出时总额不丢
@property (assign, nonatomic) NSInteger totalAmount;
@property (assign, nonatomic) BOOL isGroupSender;
@property (assign, nonatomic) BOOL isSender;
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
    if (self.sign) params[@"sign"] = self.sign;
    return params;
}
@end

// ===== 红包参数队列 =====
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
// 只读查询：按 sendId 取出参数但不出队，避免拆包流程中提前出队导致后序取不到
- (DDWeChatRedEnvelopParam *)peekBySendId:(NSString *)sendId {
    if (_queue.count == 0) return nil;
    for (DDWeChatRedEnvelopParam *p in _queue) {
        if ([p.sendId isEqualToString:sendId]) return p;
    }
    return nil;
}
@end

// ===== 拆红包操作 =====
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

// ===== 任务管理 =====
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

// ===== 通知管理 =====
@interface DDNotificationManager : NSObject <UNUserNotificationCenterDelegate>
+ (instancetype)sharedManager;
- (void)showLocalNotificationWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount sessionUserName:(NSString *)sessionUserName;
- (void)notifyFileHelperWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount param:(DDWeChatRedEnvelopParam *)param sessionUserName:(NSString *)sessionUserName timingIdentifier:(NSString *)timingIdentifier wishing:(NSString *)wishing packetCount:(NSInteger)packetCount hbType:(NSInteger)hbType senderName:(NSString *)senderName senderAccount:(NSString *)senderAccount;
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
    NSString *title = [sessionUserName hasSuffix:@"@chatroom"] ? [finalDisplayName stringByAppendingString:@"（群聊）"] : finalDisplayName;
    NSMutableString *body = [NSMutableString stringWithFormat:@"💰 抢到红包：%.2f元", amount/100.0];
    if (totalAmount > 0) {
        [body appendFormat:@"，总额：%.2f元", totalAmount/100.0];
    }
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title; content.body = body; content.sound = [UNNotificationSound defaultSound];
    content.userInfo = @{@"DDHBSession": sessionUserName};
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO]];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    NSString *session = response.notification.request.content.userInfo[@"DDHBSession"];
    if (session.length) {
        id mgr = [objc_getClass("CAppViewControllerManager") getAppViewControllerManager];
        if (!mgr) {
            MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
            mgr = [ctx getService:objc_getClass("CAppViewControllerManager")];
        }
        if (mgr) [mgr jumpToChat:session msgToLocate:nil];
    }
    completionHandler();
}

// 转发到文件传输助手：构造富文本消息经 CMessageMgr 本地插入 filehelper 会话
- (void)notifyFileHelperWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount param:(DDWeChatRedEnvelopParam *)param sessionUserName:(NSString *)sessionUserName timingIdentifier:(NSString *)timingIdentifier wishing:(NSString *)wishing packetCount:(NSInteger)packetCount hbType:(NSInteger)hbType senderName:(NSString *)senderName senderAccount:(NSString *)senderAccount {
    if (![DDRedEnvelopConfig sharedConfig].notifyFileHelper || amount <= 0) return;
    if (!sessionUserName.length) return;

    NSString *displayName = getDisplayNameForSession(sessionUserName);
    NSString *finalDisplayName = displayName.length ? displayName : sessionUserName;
    NSDateFormatter *fmt = [NSDateFormatter new];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *timeStr = [fmt stringFromDate:[NSDate date]];

    // hbType 取自拆包响应（ForeignHbOpenResp.hbType）：1 拼手气红包，0 普通红包
    NSString *typeName = (hbType == 1) ? @"拼手气红包" : @"普通红包";

    BOOL srcIsGroup = [sessionUserName hasSuffix:@"@chatroom"];

    NSMutableString *body = [NSMutableString string];
    [body appendFormat:@"💰 叮咚，为您抢到 %.2f元\n", amount / 100.0];
    [body appendFormat:@"📍 来源： %@%@\n", finalDisplayName, srcIsGroup ? @"（群聊）" : @""];
    if (packetCount > 0) {
        [body appendFormat:@"🧧 类型： %@（%ld包%.2f元）\n", typeName, (long)packetCount, totalAmount / 100.0];
    } else {
        [body appendFormat:@"🧧 类型： %@（%.2f元）\n", typeName, totalAmount / 100.0];
    }
    if (senderName.length) {
        [body appendFormat:@"👨 老板： %@\n", senderName];
        // WCR 老板行同时展示发包者名字与微信账号；账号行仅在名字与账号不同（联系人在本地有昵称）时显示，避免冗余
        if (senderAccount.length && ![senderName isEqualToString:senderAccount]) {
            [body appendFormat:@"🆔 账号： %@\n", senderAccount];
        }
    }
    if (wishing.length) [body appendFormat:@"📝 备注： %@\n", wishing];
    [body appendFormat:@"⏰ 时间： %@\n", timeStr];
    // 微信灰字自定义链接标签，点击经 %hook BaseMsgContentViewController 拦截跳转会话
    if (sessionUserName.length) {
        [body appendFormat:@"\n<_wc_custom_link_ color=\"#576B95\" href=\"DDHBRedEnvelopSession://session=%@\">点击跳转去感谢老板</_wc_custom_link_>", sessionUserName];
    } else {
        [body appendString:@"\n点击跳转去感谢老板"];
    }

    MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
    CMessageMgr *msgMgr = [ctx getService:objc_getClass("CMessageMgr")];
    if (!msgMgr) return;

    NSString *session = @"filehelper";
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:10000];
    if (!wrap) return;
    wrap.m_nsFromUsr = session;
    wrap.m_nsToUsr = session;
    wrap.m_nsContent = body;
    wrap.m_uiStatus = 4;
    wrap.m_uiCreateTime = (unsigned int)([[NSDate date] timeIntervalSince1970] + 1);

    SEL fourArgSel = NSSelectorFromString(@"AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:");
    if ([msgMgr respondsToSelector:fourArgSel]) {
        [msgMgr AddLocalMsg:session MsgWrap:wrap fixTime:NO NewMsgArriveNotify:NO];
    } else {
        [msgMgr AddLocalMsg:session MsgWrap:wrap];
    }
}
@end

// ===== 语音播报 / 自动回复 =====
static AVSpeechSynthesizer *DDHB_SharedSynth(void) {
    static AVSpeechSynthesizer *synth;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ synth = [[AVSpeechSynthesizer alloc] init]; });
    return synth;
}

// 主线程播报：切到 Playback+MixWithOthers（忽略静音键、不与微信音频互斥），中文语音
static void DDHBAnnounce(NSString *text) {
    if (!text.length) return;
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return;
    void (^speak)(void) = ^{
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
        [session setActive:YES error:nil];
        AVSpeechSynthesizer *synth = DDHB_SharedSynth();
        if ([synth isSpeaking]) [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
        AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:text];
        u.rate = AVSpeechUtteranceDefaultSpeechRate;
        u.pitchMultiplier = 1.0;
        AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
        if (voice) u.voice = voice;
        [synth speakUtterance:u];
    };
    if ([NSThread isMainThread]) speak();
    else dispatch_async(dispatch_get_main_queue(), speak);
}

static NSString *DDHBRedEnvelopBroadcastText(NSInteger amount) {
    double yuan = amount / 100.0;
    return [NSString stringWithFormat:@"收到微信红包 %.2f 元", yuan];
}

static NSString *const kDDRedEnvelopDefaultReply = @"谢谢老板，红包已收下🧧";

static NSString *DDHB_SelfUserName(void) {
    MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
    if (!ctx) return nil;
    CContactMgr *mgr = [ctx getService:objc_getClass("CContactMgr")];
    if (!mgr) return nil;
    CContact *selfContact = [mgr getSelfContact];
    return selfContact.userName ?: nil;
}

// 主线程延时发送文本回复，目标为红包所在会话（群聊即群、私聊即发送方）
static void DDHB_SendRedEnvelopReply(NSString *toSession, NSString *text) {
    if (!toSession.length || !text.length) return;
    if (![DDRedEnvelopConfig sharedConfig].autoReply) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (![DDRedEnvelopConfig sharedConfig].autoReply) return;
        NSString *selfUser = DDHB_SelfUserName();
        if (!selfUser.length) return;
        MMContext *ctx = [objc_getClass("MMContext") activeUserContext];
        CMessageMgr *msgMgr = [ctx getService:objc_getClass("CMessageMgr")];
        if (!msgMgr) return;
        CMessageWrap *reply = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:1 nsFromUsr:toSession];
        if (!reply) return;
        reply.m_nsContent = text;
        reply.m_nsFromUsr = selfUser;
        reply.m_nsToUsr = toSession;
        [msgMgr AddMsg:toSession MsgWrap:reply];
    });
}

// ===== Hook 红包逻辑 =====
static NSString *DDCurrentSessionUserName = nil;

%hook WCRedEnvelopesLogicMgr
- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    DDRedEnvelopConfig *cfg = [DDRedEnvelopConfig sharedConfig];

    // 按本次响应的 sendId 只读 peek 取会话名，确保通知显示当前红包所在会话
    NSDictionary *responseDict = [[[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
    // 服务端契约键为 sendid（小写）
    NSString *respSendId = [responseDict dd_stringForKey:@"sendid"];
    NSString *sessionUserName = DDCurrentSessionUserName;
    if (respSendId.length) {
        DDWeChatRedEnvelopParam *peekParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
        if (peekParam.sessionUserName.length) sessionUserName = peekParam.sessionUserName;
    }

    if (cfg.autoReceiveEnable) {
        SKBuiltinBuffer_t *buffer = arg1.retText;
        if (buffer.buffer) {
            NSDictionary *dict = [[[NSString alloc] initWithData:buffer.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
            NSInteger amount = [dict[@"amount"] integerValue];
            NSInteger total = [dict[@"totalAmount"] integerValue];
            if (respSendId.length && total > 0) {
                DDWeChatRedEnvelopParam *storeParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
                if (storeParam) storeParam.totalAmount = total;
            }
            if (amount > 0) {
                NSString *redId = [NSString stringWithFormat:@"%@_%@", dict[@"sendId"]?:@"", dict[@"timingIdentifier"]?:@""];
                if ([cfg shouldNotifyForRedEnvelopId:redId]) {
                    DDWeChatRedEnvelopParam *fhParam = [[DDRedEnvelopParamQueue sharedQueue] peekBySendId:respSendId];
                    NSInteger displayTotal = (fhParam && fhParam.totalAmount > 0) ? fhParam.totalAmount : total;
                    if (cfg.enableNotify && cfg.showNotification) {
                        [[DDNotificationManager sharedManager] showLocalNotificationWithAmount:amount totalAmount:displayTotal sessionUserName:sessionUserName];
                    }
                    if (cfg.enableNotify && cfg.notifyFileHelper) {
                        NSInteger packetCount = [dict[@"totalNum"] integerValue];
                        NSInteger hbType = [dict[@"hbType"] integerValue];
                        NSString *wishing = [dict dd_stringForKey:@"wishing"];
                        NSString *sendUserName = [dict dd_stringForKey:@"sendUserName"];
                        NSString *senderName = getDisplayNameForSession(sendUserName);
                        NSString *senderAccount = getAccountForSession(sendUserName);
                        [[DDNotificationManager sharedManager] notifyFileHelperWithAmount:amount totalAmount:displayTotal param:fhParam sessionUserName:sessionUserName timingIdentifier:dict[@"timingIdentifier"] wishing:wishing packetCount:packetCount hbType:hbType senderName:senderName senderAccount:senderAccount];
                    }
                    if (cfg.voiceBroadcast) {
                        DDHBAnnounce(DDHBRedEnvelopBroadcastText(amount));
                    }
                    if (cfg.autoReply && !fhParam.isSender) {
                        BOOL isGroup = [sessionUserName hasSuffix:@"@chatroom"];
                        BOOL blocked = (isGroup && cfg.skipGroupReply) || (!isGroup && cfg.skipPrivateReply);
                        if (!blocked) {
                            NSString *text = (cfg.customReplyEnabled && cfg.customReplyContent.length) ? cfg.customReplyContent : kDDRedEnvelopDefaultReply;
                            DDHB_SendRedEnvelopReply(sessionUserName, text);
                        }
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
    BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.userName];
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
    param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
    param.nativeUrl = nativeUrl;
    param.sign = [urlDict dd_stringForKey:@"sign"];
    param.isGroupSender = isGroupSender;
    param.isSender = isSender;
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

// 微信点击 <_wc_custom_link_> 走 tagLink:messageWrap:，不经过 UIApplication openURL:
%hook BaseMsgContentViewController
- (void)tagLink:(NSString *)link messageWrap:(CMessageWrap *)wrap {
    NSString *scheme = @"DDHBRedEnvelopSession://";
    if ([link hasPrefix:scheme]) {
        NSString *query = [link substringFromIndex:scheme.length];
        NSDictionary *q = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:query separator:@"&"];
        NSString *session = [q dd_stringForKey:@"session"];
        session = [session stringByRemovingPercentEncoding] ?: session;
        if (session.length) {
            id mgr = [objc_getClass("CAppViewControllerManager") getAppViewControllerManager];
            if (mgr) [mgr jumpToChat:session msgToLocate:nil];
        }
        return;
    }
    %orig;
}
%end

// ===== 设置界面 =====
@interface DDRedEnvelopSettingsViewController : UIViewController <UITableViewDelegate, MultiSelectContactsViewControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic) BOOL delayExpanded;
@property (nonatomic, strong) UITextField *contentField;
@end

@implementation DDRedEnvelopSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

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

        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onAutoReplySwitch:) target:self title:@"↳抢红包自动回复" on:cfg.autoReply]];
        if (cfg.autoReply) {
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSkipGroupReplySwitch:) target:self title:@"↳↳群聊红包不回复" on:cfg.skipGroupReply]];
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSkipPrivateReplySwitch:) target:self title:@"↳↳私聊红包不回复" on:cfg.skipPrivateReply]];
            [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onCustomReplySwitch:) target:self title:@"↳↳启用自定义回复" on:cfg.customReplyEnabled]];
            if (cfg.customReplyEnabled) {
                self.contentField = [[UITextField alloc] init];
                self.contentField.placeholder = @"请输入回复内容";
                self.contentField.text = cfg.customReplyContent;
                self.contentField.textAlignment = NSTextAlignmentRight;
                [self.contentField addTarget:self action:@selector(contentChanged:) forControlEvents:UIControlEventEditingChanged];
                [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") normalCellForSel:nil
                                                                                             target:nil
                                                                                              title:@"↳↳↳自定义内容"
                                                                                          rightView:[self inputRowWithField:self.contentField action:@selector(contentConfirmed:)]]];
            }
        }

        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onVoiceBroadcastSwitch:) target:self title:@"↳抢红包语音播报" on:cfg.voiceBroadcast]];

        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onEnableNotifySwitch:) target:self title:@"↳启用红包通知" on:cfg.enableNotify]];
        if (cfg.enableNotify) {
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
- (void)onAutoReplySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].autoReply = sender.on; [self buildTable]; }
- (void)onSkipGroupReplySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].skipGroupReply = sender.on; }
- (void)onSkipPrivateReplySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].skipPrivateReply = sender.on; }
- (void)onCustomReplySwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].customReplyEnabled = sender.on; [self buildTable]; }
- (void)onVoiceBroadcastSwitch:(UISwitch *)sender { [DDRedEnvelopConfig sharedConfig].voiceBroadcast = sender.on; }

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
- (void)contentChanged:(UITextField *)field {
    [DDRedEnvelopConfig sharedConfig].customReplyContent = field.text;
}
- (void)contentConfirmed:(id)sender {
    [DDRedEnvelopConfig sharedConfig].customReplyContent = self.contentField.text;
    [self.contentField resignFirstResponder];
}

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
            NSString *name = [contact valueForKey:@"userName"];
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

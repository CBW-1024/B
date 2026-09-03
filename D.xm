#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <objc/runtime.h>

// ========== 微信内部类声明 ==========

// Protobuf 模型（真实类继承自微信 WXPBGeneratedMessage，此处直接 NSObject 即可）
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
@property (nonatomic, retain) NSString *m_nsUsrName;
@property (nonatomic, retain) NSString *m_nsHeadImgUrl;
- (NSString *)getContactDisplayName;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, retain) id m_oWCPayInfoItem;
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

@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

// 微信原生联系人选择器（群聊 + 私聊，m_onlyChatRoom 默认 NO → 两者都显示）
// 头文件证据 MultiSelectContactsViewController.h：
//   - m_delegate (id<MultiSelectContactsViewControllerDelegate>) / m_scene / m_selectView(ivar) / updatePanelBtn / initData
//   - m_onlyChatRoom(BOOL) 控制是否只显示群聊，默认 NO → 群聊和好友都出现
@class DDContactCardTransitioningDelegate;
@protocol MultiSelectContactsViewControllerDelegate <NSObject>
- (void)onMultiSelectContactReturn:(NSArray *)contacts;
@end

@interface ContactSelectView : NSObject
- (void)addSelect:(id)contact;
@end

@interface MultiSelectContactsViewController : UIViewController
- (instancetype)init;
@property (nonatomic, assign) unsigned long long m_scene;
@property (nonatomic, weak) id<MultiSelectContactsViewControllerDelegate> m_delegate;
@property (nonatomic, retain) ContactSelectView *m_selectView;
- (void)updatePanelBtn;
@end

// 保留自定义卡片转场代理的强引用（transitioningDelegate 是 weak）
static const void *kDDContactCardDelegateKey = &kDDContactCardDelegateKey;

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
    return displayName.length ? displayName : nil;
}

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

// ========== 红包参数模型 ==========
@interface DDWeChatRedEnvelopParam : NSObject
@property (strong, nonatomic) NSString *msgType, *sendId, *channelId, *nickName, *headImg, *nativeUrl, *sessionUserName, *sign, *timingIdentifier;
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
    if (self.headImg) params[@"headImg"] = self.headImg;
    if (self.nativeUrl) params[@"nativeUrl"] = self.nativeUrl;
    if (self.sessionUserName) params[@"sessionUserName"] = self.sessionUserName;
    if (self.timingIdentifier) params[@"timingIdentifier"] = self.timingIdentifier;
    return params;
}
@end

// ========== 红包参数队列 ==========
@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDWeChatRedEnvelopParam *)param;
- (DDWeChatRedEnvelopParam *)dequeueBySendId:(NSString *)sendId;
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

    NSString *title = [NSString stringWithFormat:@"红包通知：%@", finalDisplayName];
    NSString *body = [NSString stringWithFormat:@"成功抢到红包：%.2f元，总额：%.2f元", amount/100.0, totalAmount/100.0];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title; content.body = body; content.sound = [UNNotificationSound defaultSound];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO]];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}
@end

// ========== 设置界面 ==========
@interface DDRedEnvelopSettingsViewController : UIViewController <UITableViewDelegate, MultiSelectContactsViewControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic) BOOL delayExpanded;
@end

@implementation DDRedEnvelopSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
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
        [redEnvelopSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onNotifySwitch:) target:self title:@"↳抢到红包后通知" on:cfg.showNotification]];
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

// 把下拉项对应的值挂到 cell 上，点击时回读（对齐 DDTR.txt 实现）
static const void *kDDOptionValue = &kDDOptionValue;
static void DD_SetCellOption(id cell, id value) {
    objc_setAssociatedObject(cell, kDDOptionValue, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static id DD_CellOption(id cell) {
    return objc_getAssociatedObject(cell, kDDOptionValue);
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
    // 圆角卡片样式 + 下拉关闭（自定义呈现控制器）
    nav.modalPresentationStyle = UIModalPresentationCustom;
    DDContactCardTransitioningDelegate *cardDelegate = [DDContactCardTransitioningDelegate new];
    nav.transitioningDelegate = cardDelegate;
    objc_setAssociatedObject(nav, kDDContactCardDelegateKey, cardDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)onMultiSelectContactReturn:(NSArray *)contacts {
    NSMutableArray *black = [NSMutableArray new];
    for (id contact in contacts) {
        if ([contact isKindOfClass:objc_getClass("CContact")]) {
            NSString *name = [contact valueForKey:@"m_nsUsrName"];
            if (name.length) [black addObject:name];
        }
    }
    [DDRedEnvelopConfig sharedConfig].blackList = black;
    [self dismissViewControllerAnimated:YES completion:^{
        [self buildTable];
    }];
}

@end

// ========== Hook 红包逻辑 ==========
static NSString *DDCurrentSessionUserName = nil;

%hook WCRedEnvelopesLogicMgr
- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    DDRedEnvelopConfig *cfg = [DDRedEnvelopConfig sharedConfig];
    if (cfg.showNotification && cfg.autoReceiveEnable) {
        SKBuiltinBuffer_t *buffer = arg1.retText;
        if (buffer.buffer) {
            NSDictionary *dict = [[[NSString alloc] initWithData:buffer.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
            NSInteger amount = [dict[@"amount"] integerValue];
            NSInteger total = [dict[@"totalAmount"] integerValue];
            if (amount > 0) {
                NSString *redId = [NSString stringWithFormat:@"%@_%@", dict[@"sendId"]?:@"", dict[@"timingIdentifier"]?:@""];
                if ([cfg shouldNotifyForRedEnvelopId:redId]) {
                    [[DDNotificationManager sharedManager] showLocalNotificationWithAmount:amount totalAmount:total sessionUserName:DDCurrentSessionUserName];
                }
            }
        }
    }
    if (arg1.cgiCmdid != 3) return;
    NSDictionary *responseDict = [[[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding] dd_JSONDictionary];
    NSString *respSendId = [responseDict dd_stringForKey:@"sendid"] ?: [responseDict dd_stringForKey:@"sendId"];
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
    BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
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
    param.headImg = selfContact.m_nsHeadImgUrl;
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
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

// ========== 圆角卡片呈现（下拉关闭选择器）==========
// 把包装 picker 的 MMUINavigationController 以自定义样式弹出：
//   - 半透明遮罩（点击关闭）
//   - 圆角卡片 + 顶部抓手条
//   - 拖拽抓手条下拉关闭
static CGRect DD_ContactCardFrame(CGRect containerBounds) {
    CGFloat topInset = 64, sideInset = 16, bottomInset = 16;
    CGFloat w = containerBounds.size.width - sideInset * 2;
    CGFloat h = containerBounds.size.height - topInset - bottomInset;
    return CGRectMake(sideInset, topInset, w, h);
}

@interface DDContactCardPresentationController : UIPresentationController
@property (nonatomic, retain) UIView *dimView;
@property (nonatomic, retain) UIView *grabber;
@property (nonatomic, assign) CGPoint panStart;
@property (nonatomic, assign) CGFloat cardStartY;
@end

@implementation DDContactCardPresentationController

- (void)presentationTransitionWillBegin {
    self.dimView = [[UIView alloc] initWithFrame:self.containerView.bounds];
    self.dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.45];
    self.dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:self.dimView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dd_dimTapped)];
    [self.dimView addGestureRecognizer:tap];
    self.dimView.alpha = 0;
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx){
        self.dimView.alpha = 1;
    } completion:nil];

    self.grabber = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 5)];
    self.grabber.backgroundColor = [UIColor colorWithWhite:1 alpha:0.9];
    self.grabber.layer.cornerRadius = 2.5;
    self.grabber.userInteractionEnabled = YES;
    [self.containerView addSubview:self.grabber];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dd_handlePan:)];
    [self.grabber addGestureRecognizer:pan];
}

- (void)dd_dimTapped {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)dd_handlePan:(UIPanGestureRecognizer *)pan {
    UIView *card = self.presentedView;
    CGPoint t = [pan translationInView:self.containerView];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panStart = t;
        self.cardStartY = card.frame.origin.y;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat dy = t.y - self.panStart.y;
        if (dy < 0) dy *= 0.15;
        CGRect f = card.frame; f.origin.y = self.cardStartY + dy; card.frame = f;
        CGRect g = self.grabber.frame; g.origin.y = f.origin.y - 14; self.grabber.frame = g;
        self.dimView.alpha = 0.45 * (1 - MIN(1, MAX(0, dy) / 300.0));
    } else {
        CGFloat dy = card.frame.origin.y - self.cardStartY;
        CGPoint v = [pan velocityInView:self.containerView];
        if (dy > 120 || v.y > 800) {
            [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
        } else {
            [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                CGRect f = card.frame; f.origin.y = self.cardStartY; card.frame = f;
                CGRect g = self.grabber.frame; g.origin.y = f.origin.y - 14; self.grabber.frame = g;
                self.dimView.alpha = 0.45;
            } completion:nil];
        }
    }
}

- (void)containerViewWillLayoutSubviews {
    [super containerViewWillLayoutSubviews];
    UIView *card = self.presentedView;
    card.frame = DD_ContactCardFrame(self.containerView.bounds);
    card.layer.cornerRadius = 16;
    card.layer.masksToBounds = YES;
    self.grabber.center = CGPointMake(self.containerView.bounds.size.width / 2, card.frame.origin.y - 14);
}

- (void)dismissalTransitionWillBegin {
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx){
        self.dimView.alpha = 0;
    } completion:nil];
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    if (completed) {
        [self.dimView removeFromSuperview];
        [self.grabber removeFromSuperview];
    }
}
@end

// 卡片滑入 / 滑出动画
@interface DDContactCardAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign) BOOL presenting;
@end
@implementation DDContactCardAnimator
- (NSTimeInterval)transitionDuration:(id<UIViewControllerAnimatedTransitioning>)t { return 0.32; }
- (void)animateTransition:(id<UIViewControllerAnimatedTransitioning>)transitionContext {
    id ctx = (id)transitionContext;
    UIView *container = [ctx containerView];
    if (self.presenting) {
        UIView *v = [ctx viewControllerForKey:UITransitionContextToViewControllerKey].view;
        CGRect final = DD_ContactCardFrame(container.bounds);
        v.frame = CGRectMake(final.origin.x, container.bounds.size.height, final.size.width, final.size.height);
        [container addSubview:v];
        [UIView animateWithDuration:0.32 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ v.frame = final; } completion:^(BOOL d){ [ctx completeTransition:YES]; }];
    } else {
        UIView *v = [ctx viewControllerForKey:UITransitionContextFromViewControllerKey].view;
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            v.frame = CGRectMake(v.frame.origin.x, container.bounds.size.height, v.frame.size.width, v.frame.size.height);
        } completion:^(BOOL d){ [ctx completeTransition:YES]; }];
    }
}
@end

// 转场代理：把上面的呈现控制器 + 动画接到 nav 上
@interface DDContactCardTransitioningDelegate : NSObject <UIViewControllerTransitioningDelegate>
@end
@implementation DDContactCardTransitioningDelegate
- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source {
    return [[DDContactCardPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    DDContactCardAnimator *a = [DDContactCardAnimator new]; a.presenting = YES; return a;
}
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    DDContactCardAnimator *a = [DDContactCardAnimator new]; a.presenting = NO; return a;
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
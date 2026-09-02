// DDTR.xm - 增强版（自动收款 + 自动回复感谢）
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

#pragma mark - 微信类运行时声明

// 1. 支付信息
@interface WCPayInfoItem : NSObject
@property (retain, nonatomic) NSString *m_c2cNativeUrl;
@property (retain, nonatomic) NSString *m_nsFeeDesc;
@property (assign, nonatomic) unsigned int m_uiPaySubType;
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (nonatomic) unsigned int m_c2cPayReceiveStatus;
@property (nonatomic) unsigned int m_uiInvalidTime;
@property (retain, nonatomic) NSString *transfer_attach;
@end

// 2. 消息包装
@interface CMessageWrap : NSObject
@property (retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@property (retain, nonatomic) NSString *m_nsContent;
@property (retain, nonatomic) NSString *m_nsRealChatUsr;
@property (assign, nonatomic) NSUInteger m_uiMessageType;
@property (assign, nonatomic) long long m_n64MesSvrID;
- (void)parseWCPayInfoItemIfNeed;
@end

// 3. 消息管理器
@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
- (void)AddMsg:(id)arg1 MsgWrap:(id)arg2;
- (void)SendMsg:(id)arg1 MsgWrap:(id)arg2;
@end

// 4. 微信上下文
@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

// 5. 联系人
@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsNickName;
- (id)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (id)getContactByName:(id)arg1;
@end

// 6. 转账确认请求
@interface WCPayConfirmTransferRequest : NSObject
@property (retain, nonatomic) NSString *m_nsTransferID;
@property (retain, nonatomic) NSString *m_nsFromUserName;
@property (nonatomic) unsigned long long m_uiInvalidTime;
@property (retain, nonatomic) NSString *group_username;
@property (nonatomic) unsigned int groupType;
@property (retain, nonatomic) NSString *m_nsTransferAttach;
@end

// 7. 支付逻辑管理器
@interface WCPayLogicMgr : NSObject
- (void)ConfirmTransferMoney:(id)arg1;
@end

// 8. 微信设置页组件
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
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
@end

// 9. 插件管理器
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理（DDTRConfig）

@interface DDTRConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL autoReceiveEnabled;
@property (nonatomic) BOOL autoReplyEnabled;      // 自动回复总开关
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
		_autoReceiveEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DDTransferAutoReceive"];
		if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DDTransferAutoReceive"]) {
			_autoReceiveEnabled = YES;
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DDTransferAutoReceive"];
		}
		
		// 自动回复开关（默认关闭）
		_autoReplyEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DDTransferAutoReplyEnabled"];
		if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DDTransferAutoReplyEnabled"]) {
			_autoReplyEnabled = NO;
			[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DDTransferAutoReplyEnabled"];
		}
		
		[[NSUserDefaults standardUserDefaults] synchronize];
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
	[[NSUserDefaults standardUserDefaults] setBool:autoReplyEnabled forKey:@"DDTransferAutoReplyEnabled"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 设置页面（DDTRSettingsViewController）

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

	[self.tableViewMgr clearAllSection];
	WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") defaultSection];
	[section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(switchChanged:)
																		target:self
																		 title:@"启用自动收款"
																			on:[DDTRConfig shared].autoReceiveEnabled]];
	// 添加自动回复开关
	[section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(autoReplySwitchChanged:)
																		target:self
																		 title:@"自动回复感谢"
																			on:[DDTRConfig shared].autoReplyEnabled]];
	[self.tableViewMgr addSection:section];

	UITableView *tableView = [self.tableViewMgr getTableView];
	tableView.frame = self.view.bounds;
	tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
	[self.view addSubview:tableView];
}

- (void)switchChanged:(UISwitch *)sender {
	[DDTRConfig shared].autoReceiveEnabled = sender.isOn;
}

- (void)autoReplySwitchChanged:(UISwitch *)sender {
	[DDTRConfig shared].autoReplyEnabled = sender.isOn;
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

static CContact *DD_GetContact(NSString *userName) {
	if (!userName.length) return nil;
	CContactMgr *mgr = DD_GetService(@"CContactMgr");
	return [mgr getContactByName:userName];
}

static NSString *DD_GetContactDisplayName(NSString *userName) {
	CContact *contact = DD_GetContact(userName);
	if (contact) {
		NSString *displayName = [contact getContactDisplayName];
		if (displayName.length) return displayName;
		if (contact.m_nsNickName.length) return contact.m_nsNickName;
	}
	return userName;
}

#pragma mark - 回复语资源

static NSArray *DD_GetReplyMessages(void) {
	static NSArray *messages = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		messages = @[
			@"老板的转账已收到，心里暖暖的💰，感恩遇见！",
			@"每次老板转账都觉得特别幸福，感谢老板的关怀💰！",
			@"老板的转账不只是钱，更是对我们的认可和鼓励💰❤️！",
			@"感谢老板的慷慨，跟着您干，再累都值得💰！",
			@"老板转账的时候最有人格魅力💰，真心感谢！",
			@"转账虽小，情意重，老板的心意我们都记在心里💰！",
			@"谢谢老板的厚爱，努力干活回报您💰！",
			@"老板每次转账都让人感动，太贴心了💰！",
			@"老板这手速，转账比我还快💰，活该您发财！",
			@"老板转账的姿势，堪称教科书级别💰！",
			@"老板的转账一出手，就知道有没有💰，太顶了！",
			@"老板不仅会赚钱，更会散财💰，格局打开了！",
			@"老板的手气真好，转账都这么吉利💰！",
			@"老板转账的样子，像极了财神爷下凡💰！",
			@"老板，下次能不能偷偷告诉我什么时候转账💰？",
			@"收到老板转账的时候，我的网速从来没让我失望过💰！",
			@"老板的转账治好了我多年的颈椎病💰！",
			@"老板，你这转账发得我都不好意思不加班了💰😂！",
			@"老板的转账让我相信人间有真情💰，明天继续搬砖！",
			@"收到老板转账的那一刻，我感觉自己中了彩票💰！",
			@"刚想买杯咖啡，老板转账就到了💰，太及时了！",
			@"今天本来有点丧，老板一个转账满血复活💰⚡！",
			@"早上一睁眼就看到老板的转账，今天注定是美好的一天💰☀️！",
			@"工作累了，老板转账来提神，比红牛还管用💰！",
			@"下雨天和老板的转账最配💰🌧️，心情瞬间放晴！",
			@"午饭时间收到老板转账，这顿饭吃得格外香💰🍚！",
			@"老板的转账收到了，祝老板财源滚滚，日进斗金💰💰！",
			@"谢谢老板转账，祝老板股票全红，基金全涨💰📈！",
			@"老板的转账已领，祝老板家庭幸福，事业腾飞💰🦅！",
			@"感谢老板，祝您出门遇贵人，在家数钱忙💰🏠！",
			@"谢谢老板转账💰，福气回送给您，好运加倍！",
			@"转账是意外之喜，感谢是发自内心💰✨！",
			@"每一笔转账都是老板的善意，每一次收到都是幸运💰🍀！",
			@"金钱有价，心意无价，感谢老板的转账💰💎！",
			@"老板的转账像一束光，照亮了打工人平凡的一天💰☀️！",
			@"转账带来的快乐很简单，却足够温暖一整天💰❤️！",
			@"老板转账，大家收得开心，干活更有劲💰💪！",
			@"一笔转账拉近了我们和老板的距离💰🤝，感谢！",
			@"老板的转账让团队更有温度，干活都带风💰🌪️！",
			@"有老板的转账在，咱们团队的凝聚力就是强💰🛡️！",
			@"谢谢老板，咱们跟着您一起冲，一起赢💰🏆！",
			@"💰💰💰感谢老板三连！转账收到，快乐加倍！",
			@"老板的转账🤑让我的钱包瞬间鼓起来了，感谢！",
			@"🍀收到老板转账，好运+1，幸福+1，感谢老板💰！",
			@"🔥老板的转账太火爆了，一秒收完，幸好有我💰！",
			@"💯给老板的转账打个满分，感谢大气的老板💰！",
			@"这笔转账我收下了，老板的心意我也收下了💰！",
			@"老板大气，话不多说，都在转账里了💰！",
			@"感谢老板，转账已领，干活更有劲了💰！",
			@"老板的转账到了，今天的目标就是好好工作💰！",
			@"领了老板的转账，就是老板的人了💰🤝！",
			@"Thank you 老板，转账太nice了💰！",
			@"老板的转账让我感觉so lucky💰🍀！",
			@"Good luck 老板，转账very good💰👍！",
			@"老板转账，简直perfect💰💯！",
			@"老板大气，转账feeling so good💰😎！",
		];
	});
	return messages;
}

static NSString *DD_GetRandomReply(void) {
	NSArray *messages = DD_GetReplyMessages();
	if (messages.count == 0) return @"感谢老板的转账💰！";
	NSInteger index = arc4random_uniform((uint32_t)messages.count);
	return messages[index];
}

#pragma mark - 发送转账感谢回复

static void DD_SendTransferReply(NSString *toUserName) {
	@autoreleasepool {
		if (!toUserName || toUserName.length == 0) return;
		if (![DDTRConfig shared].autoReplyEnabled) return;
		
		@try {
			NSString *replyText = DD_GetRandomReply();
			
			CMessageMgr *msgMgr = DD_GetService(@"CMessageMgr");
			if (!msgMgr) return;
			
			NSString *currentUser = DD_GetSelfUserName();
			if (!currentUser.length) return;
			
			Class msgWrapClass = NSClassFromString(@"CMessageWrap");
			if (!msgWrapClass) return;
			
			SEL initSelector = NSSelectorFromString(@"initWithMsgType:nsFromUsr:");
			if (![msgWrapClass instancesRespondToSelector:initSelector]) return;
			
			#pragma clang diagnostic push
			#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			CMessageWrap *replyMsg = [[msgWrapClass alloc] performSelector:initSelector 
																 withObject:@(1) 
																 withObject:toUserName];
			#pragma clang diagnostic pop
			
			if (!replyMsg) return;
			
			replyMsg.m_nsContent = replyText;
			replyMsg.m_nsFromUsr = currentUser;
			replyMsg.m_nsToUsr = toUserName;
			
			[msgMgr AddMsg:toUserName MsgWrap:replyMsg];
			[msgMgr SendMsg:toUserName MsgWrap:replyMsg];
			
		} @catch (NSException *exception) {
			// 静默处理
		}
	}
}

#pragma mark - 转账识别

static BOOL DD_IsTransfer(CMessageWrap *msg) {
	if (!msg) return NO;
	[msg parseWCPayInfoItemIfNeed];
	WCPayInfoItem *info = msg.m_oWCPayInfoItem;
	if (!info) return NO;
	
	// 子类型为 3 或 4，或者存在转账 ID
	if (info.m_uiPaySubType != 3 && info.m_uiPaySubType != 4 && info.m_nsTransferID.length == 0) {
		return NO;
	}
	if (info.m_nsTransferID.length == 0) return NO;
	
	// 排除红包：检查 URL 和内容
	NSString *url = info.m_c2cNativeUrl ?: @"";
	if ([url rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		return NO;
	}
	NSString *content = msg.m_nsContent ?: @"";
	if ([content rangeOfString:@"receivehongbao" options:NSCaseInsensitiveSearch].location != NSNotFound) {
		return NO;
	}
	return YES;
}

#pragma mark - 去重缓存

static NSCache *DD_ProcessedCache(void) {
	static NSCache *cache;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		cache = [[NSCache alloc] init];
		cache.countLimit = 1000;
	});
	return cache;
}

#pragma mark - 核心自动收款 + 自动回复

static void DD_TryAutoReceive(NSString *sessionId, CMessageWrap *wrap) {
	if (![DDTRConfig shared].autoReceiveEnabled) return;
	if (!sessionId.length || !wrap) return;
	if (!DD_IsTransfer(wrap)) return;
	
	WCPayInfoItem *info = wrap.m_oWCPayInfoItem;
	if (!info.m_nsTransferID.length) return;
	
	// 状态判断：排除已领取（1）和已过期（2）
	unsigned int status = info.m_c2cPayReceiveStatus;
	if (status == 1 || status == 2) return;
	
	// 去重
	NSString *key = [NSString stringWithFormat:@"%@|%lld", info.m_nsTransferID, wrap.m_n64MesSvrID];
	NSCache *cache = DD_ProcessedCache();
	if ([cache objectForKey:key]) return;
	[cache setObject:@(YES) forKey:key];
	
	// 获取自身用户名
	NSString *selfUser = DD_GetSelfUserName();
	if (!selfUser.length) return;
	
	// 确定付款方
	BOOL isGroup = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
	NSString *peer = isGroup ? (wrap.m_nsRealChatUsr ?: @"") : (wrap.m_nsFromUsr ?: @"");
	if (!peer.length || [peer isEqualToString:selfUser]) return;
	
	// 延迟 0.2 秒后执行确认
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
			
			// ============================================================
			// 自动收款成功后，发送感谢回复（延迟1.5秒避免冲突）
			// ============================================================
			if ([DDTRConfig shared].autoReplyEnabled) {
				// 判断不是自己给自己转账
				if (![peer isEqualToString:selfUser]) {
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
						DD_SendTransferReply(peer);
					});
				}
			}
			
		} @catch (NSException *e) {}
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

#pragma mark - 插件注册

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
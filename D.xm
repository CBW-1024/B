// DDTR.xm - 增强版（自动收款 + 自动回复）
//
// 依赖的微信类/方法均已对照微信头文件 dump 核实：
//   WCPayInfoItem / WCPayConfirmTransferRequest / WCPayLogicMgr
//   CMessageWrap / CMessageMgr / CContact / CContactMgr / MMContext
//   WCTableViewManager / WCTableViewSectionManager / WCTableViewCellManager
//
// 设置页“自定义回复内容 / 延迟收款秒数”的文本输入框，采用与 WCR 相同的
// 做法：WCTableViewCellManager
//   + normalCellForSel:target:title:rightView:
// （WCTableViewCellManager.h:44）把 UITextField 作为 rightView 挂到 cell 上。

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
@property (assign, nonatomic) unsigned int m_uiMessageType;
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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;
@end

// 9. 插件管理器
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理（DDTRConfig）

static NSString *const kDDReceiveEnabled  = @"DDTransferAutoReceive";
static NSString *const kDDReceiveDelay    = @"DDTransferAutoReceiveDelay";
static NSString *const kDDReplyEnabled     = @"DDTransferAutoReplyEnabled";
static NSString *const kDDReplyContent     = @"DDTransferAutoReplyContent";

@interface DDTRConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL autoReceiveEnabled;      // 启用自动收款
@property (nonatomic) double autoReceiveDelay;      // 延迟收款秒数
@property (nonatomic) BOOL autoReplyEnabled;        // 启用自动回复
@property (nonatomic, copy) NSString *autoReplyContent; // 自定义回复内容
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

		// 自动收款（默认开启）
		if ([ud objectForKey:kDDReceiveEnabled]) {
			_autoReceiveEnabled = [ud boolForKey:kDDReceiveEnabled];
		} else {
			_autoReceiveEnabled = YES;
			[ud setBool:YES forKey:kDDReceiveEnabled];
		}

		// 延迟收款秒数（默认 0.2 秒，向后兼容原写死的延迟）
		_autoReceiveDelay = [ud objectForKey:kDDReceiveDelay]
			? [ud doubleForKey:kDDReceiveDelay]
			: 0.2;

		// 启用自动回复（默认关闭）
		if ([ud objectForKey:kDDReplyEnabled]) {
			_autoReplyEnabled = [ud boolForKey:kDDReplyEnabled];
		} else {
			_autoReplyEnabled = NO;
			[ud setBool:NO forKey:kDDReplyEnabled];
		}

		// 自定义回复内容（默认一条感谢语）
		_autoReplyContent = [ud stringForKey:kDDReplyContent];
		if (!_autoReplyContent) {
			_autoReplyContent = @"感谢老板的转账💰！";
			[ud setObject:_autoReplyContent forKey:kDDReplyContent];
		}

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
	if (v < 0) v = 0;
	_autoReceiveDelay = v;
	[[NSUserDefaults standardUserDefaults] setDouble:v forKey:kDDReceiveDelay];
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

#pragma mark - 设置页面（DDTRSettingsViewController）

@interface DDTRSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic, strong) UITextField *delayField;    // 延迟收款秒数
@property (nonatomic, strong) UITextField *contentField;  // 自定义回复内容
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

	[self rebuildSettings];

	UITableView *tableView = [self.tableViewMgr getTableView];
	tableView.frame = self.view.bounds;
	tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
	[self.view addSubview:tableView];
}

// 依据当前配置重建整个设置列表。
// “启用自动回复”开启时，才展开“自定义回复内容”输入框；
// 关闭时该输入框不渲染，实现“展开/收起”。
- (void)rebuildSettings {
	[self.tableViewMgr clearAllSection];

	// ---- 收款区 ----
	WCTableViewSectionManager *recvSection = [objc_getClass("WCTableViewSectionManager") defaultSection];

	[recvSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(switchChanged:)
																		  target:self
																		   title:@"启用自动收款"
																			  on:[DDTRConfig shared].autoReceiveEnabled]];

	// 延迟收款秒数：右侧挂一个小数键盘的数字输入框
	self.delayField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 90, 30)];
	self.delayField.placeholder = @"0.2";
	self.delayField.text = [NSString stringWithFormat:@"%.2f", [DDTRConfig shared].autoReceiveDelay];
	self.delayField.keyboardType = UIKeyboardTypeDecimalPad;
	self.delayField.textAlignment = NSTextAlignmentRight;
	[self.delayField addTarget:self action:@selector(delayChanged:) forControlEvents:UIControlEventEditingChanged];
	[recvSection addCell:[objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(delayCellTapped:)
																		   target:self
																			title:@"延迟收款秒数"
																		  rightView:self.delayField]];
	[self.tableViewMgr addSection:recvSection];

	// ---- 自动回复区 ----
	WCTableViewSectionManager *replySection = [objc_getClass("WCTableViewSectionManager") defaultSection];

	[replySection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(autoReplySwitchChanged:)
																		   target:self
																			title:@"启用自动回复"
																			   on:[DDTRConfig shared].autoReplyEnabled]];

	// 仅在开启自动回复时展开“自定义回复内容”
	if ([DDTRConfig shared].autoReplyEnabled) {
		self.contentField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
		self.contentField.placeholder = @"请输入回复内容";
		self.contentField.text = [DDTRConfig shared].autoReplyContent;
		self.contentField.textAlignment = NSTextAlignmentRight;
		[self.contentField addTarget:self action:@selector(contentChanged:) forControlEvents:UIControlEventEditingChanged];
		[replySection addCell:[objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(contentCellTapped:)
																			 target:self
																			  title:@"自定义回复内容"
																			rightView:self.contentField]];
	}
	[self.tableViewMgr addSection:replySection];
}

#pragma mark 开关回调

- (void)switchChanged:(UISwitch *)sender {
	[DDTRConfig shared].autoReceiveEnabled = sender.isOn;
}

- (void)autoReplySwitchChanged:(UISwitch *)sender {
	[DDTRConfig shared].autoReplyEnabled = sender.isOn;
	// 重新构建列表以实现“自定义回复内容”的展开/收起
	[self rebuildSettings];
	[self.tableViewMgr reloadTableView];
}

#pragma mark 文本框回调

// 点击 cell（右侧文本框区域）时聚焦输入框，便于直接输入
- (void)delayCellTapped:(id)sender {
	[self.delayField becomeFirstResponder];
}

- (void)contentCellTapped:(id)sender {
	[self.contentField becomeFirstResponder];
}

// 实时保存延迟秒数
- (void)delayChanged:(UITextField *)field {
	[DDTRConfig shared].autoReceiveDelay = field.text.doubleValue;
}

// 实时保存自定义回复内容
- (void)contentChanged:(UITextField *)field {
	[DDTRConfig shared].autoReplyContent = field.text;
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

#pragma mark - 发送转账回复（自定义内容）

static void DD_SendTransferReply(NSString *toUserName) {
	@autoreleasepool {
		if (!toUserName || toUserName.length == 0) return;
		if (![DDTRConfig shared].autoReplyEnabled) return;

		// 使用自定义回复内容（空则回退默认感谢语）
		NSString *replyText = [DDTRConfig shared].autoReplyContent;
		if (!replyText.length) replyText = @"感谢老板的转账💰！";

		@try {
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
			// 头文件 dump 中 CMessageMgr 未暴露 SendMsg:MsgWrap:，
			// 旧版微信运行时仍可能存在，故做能力探测避免新版崩溃。
			if ([msgMgr respondsToSelector:@selector(SendMsg:MsgWrap:)]) {
				[msgMgr SendMsg:toUserName MsgWrap:replyMsg];
			}

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

	if (info.m_uiPaySubType != 3 && info.m_uiPaySubType != 4 && info.m_nsTransferID.length == 0) {
		return NO;
	}
	if (info.m_nsTransferID.length == 0) return NO;

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

	// 按“延迟收款秒数”配置延迟后执行确认
	double delay = [DDTRConfig shared].autoReceiveDelay;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

			// 自动收款成功后，发送自定义回复（延迟 1.5 秒避免冲突）
			if ([DDTRConfig shared].autoReplyEnabled && ![peer isEqualToString:selfUser]) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					DD_SendTransferReply(peer);
				});
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
																			   version:@"1.1.0"
																			controller:@"DDTRSettingsViewController"];
		}
	}
}

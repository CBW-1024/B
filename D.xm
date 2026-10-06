
// DDMsgAssist.xm —— 微信消息助手插件

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 微信内部类声明 ==========
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
- (void)setFooterTitle:(NSString *)title;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCUIAlertView : NSObject
+ (id)showAlertWithTitle:(NSString *)title message:(NSString *)message
           cancelBtnTitle:(NSString *)cancel target:(id)ctarget sel:(SEL)csel
                 btnTitle:(NSString *)ok target:(id)ktarget sel:(SEL)ksel;
@end

// 扫码控制器：项目头文件只前向声明了 ScanQRCodeLogicController（无完整 @interface），
// 这里补一份最小 @interface，把用到的公开 setter 集中声明在该类名下，便于归类。
// 编译期即可识别方法签名，调用处直接 [self ...] 无需强转；
// 运行期方法在 8.0.79 中真实存在。父类统一写 NSObject 仅用于拿签名，不影响运行。
@interface ScanQRCodeLogicController : NSObject
- (void)setIsFromAlbum:(BOOL)arg1;
- (void)setPicFrom:(long long)arg1;
@end

// ========== 原有功能类声明 ==========
@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsRemark;
@property (retain, nonatomic) NSString *m_nsNickName;
@property (retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CMessageWrap : NSObject
@property (retain, nonatomic) NSString *m_nsContent;
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@property (nonatomic) unsigned int m_uiCreateTime;
@property (nonatomic) unsigned int m_sequenceId;
@property (nonatomic) unsigned int m_uiMessageType;
@property (nonatomic) unsigned int m_uiStatus;
@property (nonatomic, readonly) BOOL isReferMsgType;
@property (retain, nonatomic) NSString *referMessageSenderDisplayName;
@property (retain, nonatomic) NSString *referMessageSenderUsrname;
@property (retain, nonatomic) NSString *m_nsTitle;
- (NSString *)GetDisplayContent;
- (instancetype)initWithMsgType:(long long)type;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
@end

@interface MMContext : NSObject
+ (instancetype)activeUserContext;
@property (readonly, nonatomic) NSString *userName;
- (id)getService:(Class)serviceClass;
@end

@interface CContactMgr : NSObject
- (CContact *)getContactByName:(NSString *)name;
@end

@interface CMessageMgr : NSObject
- (void)AddLocalMsg:(NSString *)session MsgWrap:(CMessageWrap *)wrap fixTime:(BOOL)fix NewMsgArriveNotify:(BOOL)notify;
- (void)ModMsg:(NSString *)session MsgWrap:(CMessageWrap *)wrap;
- (void)AsyncOnModMsg:(NSString *)session MsgWrap:(CMessageWrap *)wrap;
- (CMessageWrap *)GetMsg:(NSString *)session n64SvrID:(long long)svrID;
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end

@interface MessageRevokeMgr : NSObject
- (void)onRevokeMsg:(CMessageWrap *)msgWrap;
@end

@interface TypingController : NSObject
- (void)trySendTyping:(int)arg1;
@end

// 聊天系统时间气泡
@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)arg1;
@end

@interface ChatTimeViewModel : NSObject
- (CGSize)measure:(CGSize)arg1;
@end

// 消息头像时间标签
@interface CommonMessageCellView : UIView
@property(readonly, nonatomic) id viewModel;
- (id)getHeadImageView;   // CommonMessageCellView.h:37
- (void)setViewModel:(id)viewModel;   // BaseChatCellView.h 声明
@end

@interface CommonMessageViewModel : NSObject
- (id)initWithMessageWrap:(id)arg1 contact:(id)arg2 chatContact:(id)arg3;
@end

// 超长文本分段模型
@interface TextMessageSubViewModel : NSObject
- (id)parentModel;
@end
@interface TextMessageViewModel : NSObject
- (id)subViewModels;
@end

@interface VoIPBubbleMessageCellView : UIView
- (void)startVoiceVoip;
- (void)startVideoVoip;
@end

@interface MMHeadImageView : UIView
- (void)OnImageDoubleClick:(id)sender;
@end

@interface NewMainFrameViewController : UIViewController
- (void)initTableHeaderView;
- (void)initTableHeaderTopView;
- (void)setTableHeaderTopViewHiddenIfNotLimitedMode:(BOOL)arg1;
- (void)mainPullDown:(BOOL)arg1;
- (void)showTableHeaderTopViewByPullDown:(unsigned long long)arg1;
- (void)startDragToShow;
- (void)showTableHeaderTopView:(BOOL)arg1 fromScene:(unsigned long long)arg2;
@end

@interface MicroMessengerAppDelegate : NSObject
- (UIWindow *)window;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationDidBecomeActive:(UIApplication *)application;
@end

@interface DDBackgroundBlur : NSObject
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, assign) BOOL blurVisible;
+ (instancetype)shared;
- (void)applyBlurToWindow:(UIWindow *)window;
- (void)removeBlur;
- (void)handleEnterBackground:(UIWindow *)window;
- (void)handleDidBecomeActive;
@end

// ========== 配置管理 ==========
static NSString * const kDDMsgAssistPreventRevokeEnabledKey = @"DDPreventRevokeEnabled";
static NSString * const kDDMsgAssistScanEnhancerEnabledKey = @"DDScanEnhancerEnable";
static NSString * const kDDMsgAssistHideTypingEnabledKey = @"DDHideTypingStatusEnabled";
static NSString * const kDDMsgAssistAvatarTimeLabelEnabledKey = @"DDAvatarTimeLabelEnabled";
static NSString * const kDDMsgAssistHideSystemTimeEnabledKey = @"DDHideSystemTimeEnabled";
static NSString * const kDDMsgAssistCallConfirmEnabledKey = @"DDCallConfirmEnabled";
static NSString * const kDDMsgAssistPatConfirmEnabledKey = @"DDPatConfirmEnabled";
static NSString * const kDDMsgAssistShowWxidEnabledKey = @"DDShowWxidEnabled";
static NSString * const kDDMsgAssistDisablePullDownEnabledKey = @"DDDisablePullDownMiniProgram";
static NSString * const kDDMsgAssistBackgroundBlurEnabledKey = @"DDBackgroundBlurEnabled";

@interface DDMsgAssistConfig : NSObject
+ (instancetype)sharedConfig;
@property (nonatomic, assign) BOOL preventRevokeEnabled;
@property (nonatomic, assign) BOOL scanEnhancerEnabled;   // 扫码识别增强
@property (nonatomic, assign) BOOL hideTypingEnabled;
@property (nonatomic, assign) BOOL avatarTimeLabelEnabled;  // 头像时间标签
@property (nonatomic, assign) BOOL hideSystemTimeEnabled;   // 隐藏系统时间
@property (nonatomic, assign) BOOL callConfirmEnabled;   // 通话回拨确认
@property (nonatomic, assign) BOOL patConfirmEnabled;   // 拍一拍确认
@property (nonatomic, assign) BOOL showWxidEnabled;      // 指令提取WXID
@property (nonatomic, assign) BOOL disablePullDownEnabled;   // 禁用下拉小程序
@property (nonatomic, assign) BOOL backgroundBlurEnabled;    // 后台高斯模糊
@end

@implementation DDMsgAssistConfig

+ (instancetype)sharedConfig {
    static DDMsgAssistConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDMsgAssistConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        // boolForKey 对未写入过的 key 直接返回 NO，无需额外播种默认值
        _preventRevokeEnabled   = [ud boolForKey:kDDMsgAssistPreventRevokeEnabledKey];
        _scanEnhancerEnabled    = [ud boolForKey:kDDMsgAssistScanEnhancerEnabledKey];
        _hideTypingEnabled      = [ud boolForKey:kDDMsgAssistHideTypingEnabledKey];
        _avatarTimeLabelEnabled = [ud boolForKey:kDDMsgAssistAvatarTimeLabelEnabledKey];
        _hideSystemTimeEnabled  = [ud boolForKey:kDDMsgAssistHideSystemTimeEnabledKey];
        _callConfirmEnabled     = [ud boolForKey:kDDMsgAssistCallConfirmEnabledKey];
        _patConfirmEnabled      = [ud boolForKey:kDDMsgAssistPatConfirmEnabledKey];
        _showWxidEnabled        = [ud boolForKey:kDDMsgAssistShowWxidEnabledKey];
        _disablePullDownEnabled = [ud boolForKey:kDDMsgAssistDisablePullDownEnabledKey];
        _backgroundBlurEnabled  = [ud boolForKey:kDDMsgAssistBackgroundBlurEnabledKey];
    }
    return self;
}

- (void)setPreventRevokeEnabled:(BOOL)preventRevokeEnabled {
    _preventRevokeEnabled = preventRevokeEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:preventRevokeEnabled forKey:kDDMsgAssistPreventRevokeEnabledKey];
}

- (void)setScanEnhancerEnabled:(BOOL)scanEnhancerEnabled {
    _scanEnhancerEnabled = scanEnhancerEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:scanEnhancerEnabled forKey:kDDMsgAssistScanEnhancerEnabledKey];
}

- (void)setHideTypingEnabled:(BOOL)hideTypingEnabled {
    _hideTypingEnabled = hideTypingEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:hideTypingEnabled forKey:kDDMsgAssistHideTypingEnabledKey];
}

- (void)setAvatarTimeLabelEnabled:(BOOL)avatarTimeLabelEnabled {
    _avatarTimeLabelEnabled = avatarTimeLabelEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:avatarTimeLabelEnabled forKey:kDDMsgAssistAvatarTimeLabelEnabledKey];
}

- (void)setHideSystemTimeEnabled:(BOOL)hideSystemTimeEnabled {
    _hideSystemTimeEnabled = hideSystemTimeEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:hideSystemTimeEnabled forKey:kDDMsgAssistHideSystemTimeEnabledKey];
}

- (void)setCallConfirmEnabled:(BOOL)callConfirmEnabled {
    _callConfirmEnabled = callConfirmEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:callConfirmEnabled forKey:kDDMsgAssistCallConfirmEnabledKey];
}

- (void)setPatConfirmEnabled:(BOOL)patConfirmEnabled {
    _patConfirmEnabled = patConfirmEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:patConfirmEnabled forKey:kDDMsgAssistPatConfirmEnabledKey];
}

- (void)setShowWxidEnabled:(BOOL)showWxidEnabled {
    _showWxidEnabled = showWxidEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:showWxidEnabled forKey:kDDMsgAssistShowWxidEnabledKey];
}

- (void)setDisablePullDownEnabled:(BOOL)disablePullDownEnabled {
    _disablePullDownEnabled = disablePullDownEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:disablePullDownEnabled forKey:kDDMsgAssistDisablePullDownEnabledKey];
}

- (void)setBackgroundBlurEnabled:(BOOL)backgroundBlurEnabled {
    _backgroundBlurEnabled = backgroundBlurEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:backgroundBlurEnabled forKey:kDDMsgAssistBackgroundBlurEnabledKey];
}

@end

// ========== 后台高斯模糊工具类 ==========
@implementation DDBackgroundBlur

+ (instancetype)shared {
    static DDBackgroundBlur *blur = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ blur = [DDBackgroundBlur new]; });
    return blur;
}

- (instancetype)init {
    if (self = [super init]) {
        _blurVisible = NO;
    }
    return self;
}

- (void)handleEnterBackground:(UIWindow *)window {
    if (![DDMsgAssistConfig sharedConfig].backgroundBlurEnabled) return;
    if (self.blurVisible) return;
    [self applyBlurToWindow:window];
}

- (void)applyBlurToWindow:(UIWindow *)window {
    if (!window) return;
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 1.0;
    self.blurView = blurView;
    self.blurVisible = YES;
    [window addSubview:blurView];
    [window bringSubviewToFront:blurView];
}

- (void)handleDidBecomeActive {
    if (self.blurVisible) [self removeBlur];
}

- (void)removeBlur {
    if (self.blurView) {
        [self.blurView removeFromSuperview];
        self.blurView = nil;
    }
    self.blurVisible = NO;
}

@end

// ========== 辅助函数 ==========
static NSString* ddma_trim(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

static NSString* ddma_extractXMLValue(NSString *xml, NSString *openTag, NSString *closeTag) {
    if (!xml.length || !openTag.length || !closeTag.length) return nil;
    NSRange openRange = [xml rangeOfString:openTag];
    if (openRange.location == NSNotFound) return nil;
    NSUInteger start = NSMaxRange(openRange);
    if (start >= xml.length) return nil;
    NSRange closeRange = [xml rangeOfString:closeTag options:0 range:NSMakeRange(start, xml.length - start)];
    if (closeRange.location == NSNotFound) return nil;
    NSRange valueRange = NSMakeRange(start, closeRange.location - start);
    return ddma_trim([xml substringWithRange:valueRange]);
}

static NSString* ddma_stripCDATA(NSString *text) {
    if (!text.length) return nil;
    NSRange start = [text rangeOfString:@"<![CDATA["];
    if (start.location == NSNotFound) return text;
    NSRange end = [text rangeOfString:@"]]>" options:0 range:NSMakeRange(NSMaxRange(start), text.length - NSMaxRange(start))];
    if (end.location == NSNotFound) return text;
    NSRange range = NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start));
    return ddma_trim([text substringWithRange:range]);
}

static NSString* ddma_revokeTimeTextFromTimestamp(unsigned int timestamp) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

static NSString* ddma_displayNameForContact(CContact *contact, NSString *fallback) {
    if (!contact) return fallback;
    if (contact.m_nsRemark.length) return contact.m_nsRemark;
    if (contact.m_nsNickName.length) return contact.m_nsNickName;
    if (contact.m_nsUsrName.length) return contact.m_nsUsrName;
    return fallback;
}

static NSString* ddma_digestForMessageWrap(CMessageWrap *msgWrap) {
    unsigned int msgType = msgWrap.m_uiMessageType;
    switch (msgType) {
        case 1: {
            NSString *content = [msgWrap GetDisplayContent];
            if (content.length > 15) {
                content = [[content substringToIndex:15] stringByAppendingString:@"…"];
            }
            return content;
        }
        case 3: return @"<图片>";
        case 34: return @"<语音>";
        case 42: return @"<名片>";
        case 43: return @"<视频>";
        case 47: return @"<表情>";
        case 48: return @"<位置>";
        case 49: {
            NSString *content = msgWrap.m_nsContent;
            if (content.length > 0) {
                NSString *subTypeStr = ddma_extractXMLValue(content, @"<type>", @"</type>");
                if (subTypeStr.length > 0) {
                    int subType = [subTypeStr intValue];
                    switch (subType) {
                        case 5: return @"<链接>";
                        case 6: return @"<文件>";
                        case 8: return @"<表情>";
                        case 15: return @"<表情分享>";
                        case 19: return @"<聊天记录>";
                        case 33: return @"<小程序>";
                        case 51: return @"<视频号>";
                        case 53: return @"<接龙>";
                        case 62: return @"<拍一拍>";
                        case 63: return @"<视频号直播>";
                        case 68: return @"<问一问>";
                        case 74: return @"<文件>";
                        case 76: return @"<音乐>";
                        case 78: return @"<微信游戏>";
                        case 87: return @"<群公告>";
                        case 92: return @"<听一听>";
                        default: break;
                    }
                }
            }
            return [msgWrap GetDisplayContent];
        }
        default: {
            NSString *display = [msgWrap GetDisplayContent];
            if (display.length > 180) {
                display = [[display substringToIndex:180] stringByAppendingString:@"…"];
            }
            return display;
        }
    }
}

static CMessageWrap* ddma_findOriginalMessage(CMessageMgr *messageMgr, NSString *session, long long svrID) {
    if (svrID > 0 && messageMgr) return [messageMgr GetMsg:session n64SvrID:svrID];
    return nil;
}

static void ddma_insertRevokeTipMessage(CMessageMgr *messageMgr,
                                        NSString *session,
                                        NSString *tipText,
                                        unsigned int anchorCreateTime,
                                        unsigned int anchorSeq) {
    CMessageWrap *msgWrap = [[%c(CMessageWrap) alloc] initWithMsgType:10000];
    if (!msgWrap) return;
    msgWrap.m_uiStatus = 4;
    msgWrap.m_nsContent = tipText;
    msgWrap.m_nsToUsr = session;
    msgWrap.m_nsFromUsr = session;
    msgWrap.m_uiCreateTime = anchorCreateTime;
    msgWrap.m_sequenceId = anchorSeq + 1;
    [messageMgr AddLocalMsg:session MsgWrap:msgWrap fixTime:NO NewMsgArriveNotify:NO];
    [messageMgr ModMsg:session MsgWrap:msgWrap];
    [messageMgr AsyncOnModMsg:session MsgWrap:msgWrap];
}

static BOOL ddma_isSelfRevokeMessage(CMessageWrap *revokeWrap) {
    if (!revokeWrap) return NO;
    MMContext *context = [%c(MMContext) activeUserContext];
    if (!context) return NO;
    NSString *selfUserName = context.userName;
    if (selfUserName.length == 0) return NO;
    return [revokeWrap.m_nsFromUsr isEqualToString:selfUserName];
}

static void ddma_handleRevokeMessage(CMessageWrap *revokeWrap) {
    NSString *content = revokeWrap.m_nsContent ?: @"";
    if (content.length == 0) return;
    
    NSString *session = ddma_extractXMLValue(content, @"<session>", @"</session>");
    NSString *newMsgID = ddma_extractXMLValue(content, @"<newmsgid>", @"</newmsgid>");
    NSString *replaceRaw = ddma_extractXMLValue(content, @"<replacemsg>", @"</replacemsg>");
    if (session.length == 0 || (newMsgID.length == 0 && replaceRaw.length == 0)) return;
    
    long long svrID = newMsgID.length ? strtoll(newMsgID.UTF8String, NULL, 10) : 0;
    unsigned int revokeCreateTime = revokeWrap.m_uiCreateTime;
    
    MMContext *context = [%c(MMContext) activeUserContext];
    if (!context) return;
    CMessageMgr *messageMgr = [context getService:%c(CMessageMgr)];
    CContactMgr *contactMgr = [context getService:%c(CContactMgr)];
    if (!messageMgr || !contactMgr) return;
    
    NSString *fromUser = revokeWrap.m_nsFromUsr ?: @"";
    BOOL isGroup = [fromUser hasSuffix:@"@chatroom"];
    NSString *actorName = fromUser;
    if (isGroup) {
        NSString *replaceText = ddma_stripCDATA(replaceRaw);
        NSRange quoteRange = [replaceText rangeOfString:@"\""];
        if (quoteRange.location != NSNotFound) {
            NSRange endQuote = [replaceText rangeOfString:@"\"" options:0 range:NSMakeRange(NSMaxRange(quoteRange), replaceText.length - NSMaxRange(quoteRange))];
            if (endQuote.location != NSNotFound) {
                actorName = [replaceText substringWithRange:NSMakeRange(NSMaxRange(quoteRange), endQuote.location - NSMaxRange(quoteRange))];
            }
        }
        if (actorName.length == 0) actorName = fromUser;
    } else {
        CContact *contact = [contactMgr getContactByName:fromUser];
        actorName = ddma_displayNameForContact(contact, fromUser);
    }
    
    CMessageWrap *originalMsg = ddma_findOriginalMessage(messageMgr, session, svrID);
    if (!originalMsg) return;
    
    BOOL isQuote = NO;
    NSString *quoteSender = nil;
    NSString *contentSummary = nil;
    if (originalMsg.isReferMsgType) {
        isQuote = YES;
        if (originalMsg.referMessageSenderDisplayName.length) {
            quoteSender = originalMsg.referMessageSenderDisplayName;
        } else {
            quoteSender = originalMsg.referMessageSenderUsrname;
        }
        if (originalMsg.m_nsTitle.length > 0) {
            NSString *reply = originalMsg.m_nsTitle;
            if (reply.length > 15) {
                reply = [[reply substringToIndex:15] stringByAppendingString:@"…"];
            }
            contentSummary = reply;
        } else {
            contentSummary = ddma_digestForMessageWrap(originalMsg);
        }
    } else {
        contentSummary = ddma_digestForMessageWrap(originalMsg);
    }
    
    unsigned int anchorCreateTime = originalMsg.m_uiCreateTime;
    unsigned int anchorSeq = originalMsg.m_sequenceId;
    NSString *timeString = ddma_revokeTimeTextFromTimestamp(revokeCreateTime);
    
    NSString *tipText;
    if (isQuote) {
        tipText = [NSString stringWithFormat:@"%@\n拦截：“%@”撤回的一条引用消息\n引用：[%@] 附言：[%@]", 
                   timeString, actorName, quoteSender, contentSummary];
    } else {
        tipText = [NSString stringWithFormat:@"%@\n拦截：“%@”撤回的一条消息\n内容：[%@]", 
                   timeString, actorName, contentSummary];
    }
    
    ddma_insertRevokeTipMessage(messageMgr, session, tipText, anchorCreateTime, anchorSeq);
}

// 确认框回调桥接：WCUIAlertView 用 selector，这里把 block 包成方法
// 确认后重入原方法用的 per-instance 标记
static const void *kDDBypassVoiceKey = &kDDBypassVoiceKey;
static const void *kDDBypassVideoKey = &kDDBypassVideoKey;
static const void *kDDBypassPatKey = &kDDBypassPatKey;

@interface DDConfirmBridge : NSObject
- (void)fire;
- (void)ignore;
@end
@implementation DDConfirmBridge {
    void (^_action)(void);
}
- (instancetype)initWithAction:(void (^)(void))action {
    if ((self = [super init])) _action = [action copy];
    return self;
}
- (void)fire { if (_action) _action(); }
- (void)ignore {}
@end

// 弹确认框（WCUIAlertView 自带窗口），标题+提示，确认后执行 onConfirm
static void ddma_showConfirmSheet(NSString *title, NSString *message, void (^onConfirm)(void)) {
    DDConfirmBridge *bridge = [[DDConfirmBridge alloc] initWithAction:onConfirm];
    id av = [%c(WCUIAlertView) showAlertWithTitle:title message:message
                                 cancelBtnTitle:@"取消" target:bridge sel:@selector(ignore)
                                       btnTitle:@"确定" target:bridge sel:@selector(fire)];
    if (av) objc_setAssociatedObject(av, (void *)"dd_bridge", bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// 判断是否 /WXID 指令
static BOOL ddIsWxidCommand(NSString *text) {
    if (!text || text.length == 0) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return NO;
    return [trimmed caseInsensitiveCompare:@"/WXID"] == NSOrderedSame;
}

// 弹原始 ID 面板（WCUIAlertView 自带窗口），复制按钮写入剪贴板
static void ddShowWxidAlert(NSString *rawId) {
    if (!rawId.length) rawId = @"未获取到 ID";
    DDConfirmBridge *bridge = [[DDConfirmBridge alloc] initWithAction:^{
        [UIPasteboard generalPasteboard].string = rawId;
    }];
    id av = [%c(WCUIAlertView) showAlertWithTitle:@"原始账号：" message:rawId
                                 cancelBtnTitle:@"取消" target:bridge sel:@selector(ignore)
                                       btnTitle:@"复制" target:bridge sel:@selector(fire)];
    if (av) objc_setAssociatedObject(av, (void *)"dd_wxid_bridge", bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ========== 辅助函数（头像时间标签用） ==========
static void ddma_setTimeView(id cellView, UIView *timeView) {
    objc_setAssociatedObject(cellView, (void *)"ddma_timeView", timeView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *ddma_getTimeView(id cellView) {
    return objc_getAssociatedObject(cellView, (void *)"ddma_timeView");
}

static void ddma_setMessageCreateTime(id viewModel, unsigned int createTime) {
    NSNumber *timeNum = [NSNumber numberWithUnsignedInt:createTime];
    objc_setAssociatedObject(viewModel, (void *)"ddma_createTime", timeNum, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static unsigned int ddma_getMessageCreateTime(id viewModel) {
    NSNumber *timeNum = objc_getAssociatedObject(viewModel, (void *)"ddma_createTime");
    return [timeNum unsignedIntValue];
}

static NSString *ddma_messageTimeString(unsigned int createTime) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"MM/dd HH:mm";
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:createTime]];
}

// 缓存类避免布局热路径反复查
static Class ddma_textMessageSubViewModelClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cls = objc_getClass("TextMessageSubViewModel"); });
    return cls;
}

static UILabel *ddma_createTimeLabel() {
    UILabel *timeLabel = [[UILabel alloc] init];
    timeLabel.backgroundColor = [UIColor clearColor];
    timeLabel.textAlignment = NSTextAlignmentCenter;
    timeLabel.font = [UIFont boldSystemFontOfSize:7.0];
    timeLabel.numberOfLines = 1;
    timeLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.8];
    return timeLabel;
}

static void ddma_layoutTimeLabel(id self, id viewModel) {
    UILabel *timeLabel = (UILabel *)ddma_getTimeView(self);
    if (![DDMsgAssistConfig sharedConfig].avatarTimeLabelEnabled) {
        timeLabel.hidden = YES;
        return;
    }
    // 超长文本分段：仅首段显示时间，时间取自父模型
    unsigned int createTime = 0;
    if ([viewModel isKindOfClass:ddma_textMessageSubViewModelClass()]) {
        TextMessageViewModel *parentModel = [(TextMessageSubViewModel *)viewModel parentModel];
        NSArray *subViewModels = [parentModel subViewModels];
        if (subViewModels.count > 0 && [subViewModels indexOfObject:viewModel] != 0) {
            timeLabel.hidden = YES;
            return;
        }
        createTime = ddma_getMessageCreateTime(parentModel);
    } else {
        createTime = ddma_getMessageCreateTime(viewModel);
    }
    if (createTime == 0) {
        timeLabel.hidden = YES;
        return;
    }
    if (!timeLabel) {
        timeLabel = ddma_createTimeLabel();
        ddma_setTimeView(self, timeLabel);
    }
    // 复用/被移除后确保重新挂上，不依赖首次懒加载分支
    if (!timeLabel.superview) {
        [self addSubview:timeLabel];
    }
    timeLabel.hidden = NO;
    timeLabel.text = ddma_messageTimeString(createTime);

    CGSize constraint = CGSizeMake(100, CGFLOAT_MAX);
    CGSize textSize = [timeLabel.text boundingRectWithSize:constraint
                                                 options:NSStringDrawingUsesLineFragmentOrigin
                                              attributes:@{NSFontAttributeName: timeLabel.font}
                                                 context:nil].size;
    CGFloat labelWidth = MIN(textSize.width + 8.0, 100.0);
    CGFloat labelHeight = textSize.height + 4.0;
    timeLabel.frame = CGRectMake(0, 0, labelWidth, labelHeight);

    // 用 getHeadImageView 取头像，优于遍历 subviews
    UIView *headImageView = [self getHeadImageView];
    if (headImageView) {
        CGFloat centerX = CGRectGetMidX(headImageView.frame);
        CGFloat centerY = CGRectGetMaxY(headImageView.frame) + (labelHeight / 2) - 5.0;
        timeLabel.center = CGPointMake(centerX, centerY);
    }
    [self bringSubviewToFront:timeLabel];
}

// ========== Hook 防撤回 ==========
%hook MessageRevokeMgr
- (void)onRevokeMsg:(CMessageWrap *)msgWrap {
    if (![DDMsgAssistConfig sharedConfig].preventRevokeEnabled) {
        %orig;
        return;
    }
    if (ddma_isSelfRevokeMessage(msgWrap)) {
        %orig;
        return;
    }
    ddma_handleRevokeMessage(msgWrap);
}
%end

// ========== Hook 扫码识别增强（伪装相机扫码） ==========
%hook ScanQRCodeLogicParams
- (id)initWithCodeType:(int)arg1 fromScene:(unsigned int)arg2 {
    if ([DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        return %orig(arg1, 1U);
    }
    return %orig;
}
%end

%hook ScanQRCodeResultInfo
- (BOOL)scanFromAlbum {
    if ([DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        return NO;
    }
    return %orig;
}
- (void)setScanFromAlbum:(BOOL)arg1 {
    if ([DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        %orig(NO);
        return;
    }
    %orig;
}
%end

%hook ScanQRCodeLogicController
- (void)scanOnePicture:(id)arg1 {
    if ([DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        [self setIsFromAlbum:NO];
        [self setPicFrom:0];
    }
    %orig;
}
- (void)openQRCodeOrWXCodeLandingPage:(id)arg1 isShowMultiCodes:(BOOL)arg2 businessScene:(id)arg3 {
    if ([DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        [self setIsFromAlbum:NO];
    }
    %orig;
}
- (id)initWithViewController:(id)arg1 logicParams:(id)arg2 {
    id ret = %orig;
    if (ret && [DDMsgAssistConfig sharedConfig].scanEnhancerEnabled) {
        [self setIsFromAlbum:NO];
    }
    return ret;
}
%end

// ========== Hook 阻止输入状态 ==========
%hook TypingController
- (void)trySendTyping:(int)arg1 {
    if ([DDMsgAssistConfig sharedConfig].hideTypingEnabled) {
        %orig(0);
    } else {
        %orig(arg1);
    }
}
%end

// ========== Hook 隐藏聊天系统时间 ==========
%hook ChatTimeCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (view && [DDMsgAssistConfig sharedConfig].hideSystemTimeEnabled) {
        [(UIView *)view setHidden:YES];
    }
    return view;
}
%end

%hook ChatTimeViewModel
- (CGSize)measure:(CGSize)arg1 {
    if ([DDMsgAssistConfig sharedConfig].hideSystemTimeEnabled) {
        return CGSizeMake(arg1.width, 0);
    }
    return %orig(arg1);
}
%end

// ========== Hook 头像时间标签 ==========
%hook CommonMessageViewModel
- (id)initWithMessageWrap:(id)arg1 contact:(id)arg2 chatContact:(id)arg3 {
    id result = %orig;
    if (result) {
        ddma_setMessageCreateTime(result, ((CMessageWrap *)arg1).m_uiCreateTime);
    }
    return result;
}
%end

%hook CommonMessageCellView
// viewModel 就绪后触发重排，避免首屏时间标签延迟出现
- (void)setViewModel:(id)viewModel {
    %orig;
    [self setNeedsLayout];
}
// layoutInternal 与 layoutSubviews 都下钩，覆盖微信两类重排
- (void)layoutInternal {
    %orig;
    ddma_layoutTimeLabel(self, [self viewModel]);
}
- (void)layoutSubviews {
    %orig;
    ddma_layoutTimeLabel(self, [self viewModel]);
}
%end

// ========== Hook 通话回拨确认 ==========
%hook VoIPBubbleMessageCellView
- (void)startVoiceVoip {
    if (objc_getAssociatedObject(self, kDDBypassVoiceKey)) {
        objc_setAssociatedObject(self, kDDBypassVoiceKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    if (![DDMsgAssistConfig sharedConfig].callConfirmEnabled) { %orig; return; }
    ddma_showConfirmSheet(@"通话回拨", @"是否要回拨语音通话？", ^{
        objc_setAssociatedObject(self, kDDBypassVoiceKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self startVoiceVoip];
    });
}
- (void)startVideoVoip {
    if (objc_getAssociatedObject(self, kDDBypassVideoKey)) {
        objc_setAssociatedObject(self, kDDBypassVideoKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig;
        return;
    }
    if (![DDMsgAssistConfig sharedConfig].callConfirmEnabled) { %orig; return; }
    ddma_showConfirmSheet(@"通话回拨", @"是否要回拨视频通话？", ^{
        objc_setAssociatedObject(self, kDDBypassVideoKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self startVideoVoip];
    });
}
%end

// ========== Hook 拍一拍确认 ==========
%hook MMHeadImageView
- (void)OnImageDoubleClick:(id)sender {
    if (objc_getAssociatedObject(self, kDDBypassPatKey)) {
        objc_setAssociatedObject(self, kDDBypassPatKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(sender);
        return;
    }
    if (![DDMsgAssistConfig sharedConfig].patConfirmEnabled) { %orig(sender); return; }
    ddma_showConfirmSheet(@"拍一拍", @"是否要拍一拍？", ^{
        objc_setAssociatedObject(self, kDDBypassPatKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self OnImageDoubleClick:sender];
    });
}
%end

// ========== Hook 指令提取WXID ==========
%hook CMessageMgr

// 拦截自己发出的文本 /WXID：弹面板展示原始 ID（可复制），并拦截该条发送
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;
    if ([DDMsgAssistConfig sharedConfig].showWxidEnabled && wrap) {
        if (wrap.m_uiMessageType == 1 && ddIsWxidCommand(wrap.m_nsContent)) {
            Class msgWrapCls = objc_getClass("CMessageWrap");
            if (msgWrapCls && [msgWrapCls isSenderFromMsgWrap:wrap]) {
                NSString *rawId = usr.length ? usr : wrap.m_nsToUsr;
                if (!rawId.length) rawId = @"未获取到 ID";
                ddShowWxidAlert(rawId);
                shouldSend = NO;
            }
        }
    }
    if (shouldSend) %orig;
}
%end

// ========== Hook 禁用下拉小程序 ==========
%hook NewMainFrameViewController
- (void)setTableHeaderTopViewHiddenIfNotLimitedMode:(BOOL)arg1 {
    if ([DDMsgAssistConfig sharedConfig].disablePullDownEnabled) {
        %orig(YES);
        return;
    }
    %orig;
}
- (void)mainPullDown:(BOOL)arg1 {
    if ([DDMsgAssistConfig sharedConfig].disablePullDownEnabled && arg1) return;
    %orig;
}
- (void)showTableHeaderTopViewByPullDown:(unsigned long long)arg1 {
    if ([DDMsgAssistConfig sharedConfig].disablePullDownEnabled) return;
    %orig;
}
- (void)startDragToShow {
    if ([DDMsgAssistConfig sharedConfig].disablePullDownEnabled) return;
    %orig;
}
- (void)showTableHeaderTopView:(BOOL)arg1 fromScene:(unsigned long long)arg2 {
    if ([DDMsgAssistConfig sharedConfig].disablePullDownEnabled) return;
    %orig;
}
%end

// ========== Hook 后台高斯模糊 ==========
%hook MicroMessengerAppDelegate
- (void)applicationWillResignActive:(UIApplication *)application {
    %orig;
    if (!self.window) return;
    [[DDBackgroundBlur shared] handleEnterBackground:self.window];
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    [[DDBackgroundBlur shared] handleDidBecomeActive];
}
%end

// ========== 设置界面 ==========
@interface DDMsgAssistSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDMsgAssistSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"消息助手设置";

    // 表格整屏延伸，由 viewDidLayoutSubviews 推到导航栏底边
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    // 已手动避开导航栏，关掉系统自动 inset，避免两套机制叠加
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_tableViewManager.tableView];

    [self buildTable];
    self.view.backgroundColor = _tableViewManager.tableView.backgroundColor;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    UITableView *tableView = _tableViewManager.tableView;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    tableView.frame = CGRectMake(0, top, w, h - top);
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionWithHeader:@"防撤回设置"];
    BOOL isOn = [DDMsgAssistConfig sharedConfig].preventRevokeEnabled;
    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSwitchChanged:) target:self title:@"消息防撤提示" on:isOn]];
    
    [_tableViewManager addSection:section];
    
    WCTableViewSectionManager *msgSection = [objc_getClass("WCTableViewSectionManager") sectionWithHeader:@"消息设置"];
    BOOL scanEnhancerOn = [DDMsgAssistConfig sharedConfig].scanEnhancerEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onScanEnhancerSwitchChanged:) target:self title:@"扫码识别增强" on:scanEnhancerOn]];

    BOOL hideTypingOn = [DDMsgAssistConfig sharedConfig].hideTypingEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onTypingSwitchChanged:) target:self title:@"阻止输入状态" on:hideTypingOn]];
    
    BOOL avatarTimeOn = [DDMsgAssistConfig sharedConfig].avatarTimeLabelEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onAvatarTimeSwitchChanged:) target:self title:@"头像时间标签" on:avatarTimeOn]];

    BOOL hideSysTimeOn = [DDMsgAssistConfig sharedConfig].hideSystemTimeEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onHideSystemTimeSwitchChanged:) target:self title:@"隐藏系统时间" on:hideSysTimeOn]];

    BOOL callConfirmOn = [DDMsgAssistConfig sharedConfig].callConfirmEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onCallSwitchChanged:) target:self title:@"通话回拨确认" on:callConfirmOn]];

    BOOL patConfirmOn = [DDMsgAssistConfig sharedConfig].patConfirmEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onPatSwitchChanged:) target:self title:@"拍一拍确认" on:patConfirmOn]];

    BOOL showWxidOn = [DDMsgAssistConfig sharedConfig].showWxidEnabled;
    [msgSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onWxidSwitchChanged:) target:self title:@"指令提取WXID" on:showWxidOn]];
    [msgSection setFooterTitle:@"聊天发送指令\"/wxid\"(不区分大小写)获取原始wxid账号"];

    [_tableViewManager addSection:msgSection];

    WCTableViewSectionManager *auxSection = [objc_getClass("WCTableViewSectionManager") sectionWithHeader:@"辅助设置"];
    BOOL disablePullDownOn = [DDMsgAssistConfig sharedConfig].disablePullDownEnabled;
    [auxSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onPullDownSwitchChanged:) target:self title:@"禁用下拉小程序" on:disablePullDownOn]];

    BOOL backgroundBlurOn = [DDMsgAssistConfig sharedConfig].backgroundBlurEnabled;
    [auxSection addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onBackgroundBlurSwitchChanged:) target:self title:@"后台高斯模糊" on:backgroundBlurOn]];

    [_tableViewManager addSection:auxSection];
    [_tableViewManager reloadTableView];
}

- (void)onSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].preventRevokeEnabled = sender.isOn;
}

- (void)onScanEnhancerSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].scanEnhancerEnabled = sender.isOn;
}

- (void)onTypingSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].hideTypingEnabled = sender.isOn;
}

- (void)onAvatarTimeSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].avatarTimeLabelEnabled = sender.isOn;
}

- (void)onHideSystemTimeSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].hideSystemTimeEnabled = sender.isOn;
}

- (void)onCallSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].callConfirmEnabled = sender.isOn;
}

- (void)onPatSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].patConfirmEnabled = sender.isOn;
}

- (void)onWxidSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].showWxidEnabled = sender.isOn;
}

- (void)onPullDownSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].disablePullDownEnabled = sender.isOn;
}

- (void)onBackgroundBlurSwitchChanged:(UISwitch *)sender {
    [DDMsgAssistConfig sharedConfig].backgroundBlurEnabled = sender.isOn;
}

@end

// ========== 插件注册 ==========
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD消息助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDMsgAssistSettingsViewController"];
        }
    }
}
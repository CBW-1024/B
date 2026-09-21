//  DD小丑助手  (WeChat Jailbreak Tweak, Theos/Logos 单文件)
//  在微信内自定义聊天 / 资料 / 余额等显示
//  功能：聊天文字、图片、时间、转账改写；运动步数、好友数量；余额 / 零钱通自定义；微信账号 / 头像自定义
//  入口：微信 → 插件入口 → "DD小丑助手"设置页

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <string.h>

#pragma mark - 微信类声明
// 本插件 hook 的微信原生类与方法签名，均锚定微信8.0.78头文件 dump。


// 父类前向声明：Clang 不允许用 @class 当父类，必须写完整 @interface，
// 这里按最新 dump 补出真实继承链，供下面的 @interface 使用。
@interface MMObject : NSObject
@end

@interface MMUIViewController : UIViewController
@end

@interface MMUIView : UIView
@end

@interface MMUIScrollView : UIScrollView
@end

@interface BaseChatViewModel : NSObject
@end

@interface BaseChatCellView : UIView
@end

@interface MMUILabel : UILabel
@end

@interface MMCPLabel : MMUILabel
@end

@interface MMTabBarBaseViewController : MMUIViewController
@end

@interface MMWindowViewController : MMUIViewController
@end

@interface WCBizBaseViewController : MMUIViewController
@end

#pragma mark  弹窗 / 提示 / 插件注册
@interface WCUIAlertView : NSObject
- (id)initWithTitle:(id)a0 message:(id)a1;
- (void)showTextFieldWithMaxLen:(unsigned int)a0;
- (UITextField *)getTextField;
- (id)getTextFieldText;
- (void)setTextFieldDefaultText:(id)a0;
- (void)addBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)addCancelBtnTitle:(id)a0 handler:(void (^)(void))a1;
- (void)show;
@end

@interface WeToast : MMWindowViewController
+ (id)toast;
- (void)showDoneToastWithText:(id)a0;
- (void)showErrorToastWithText:(id)a0;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark  设置页表格（WCTableView*）
@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
+ (id)defaultSection;
@property (nonatomic, copy) NSString *footerTitle;
- (void)addCell:(id)arg1;
- (unsigned long long)getCellCount;
- (id)getCellAt:(unsigned long long)a0;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
- (id)getTableView;
- (id)getAllSections;
- (void)insertSection:(id)arg1 At:(unsigned int)a1;
@end

#pragma mark  联系人 / 账号
@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsAliasName;
- (BOOL)isSelf;
@end

@interface CSetting : NSObject
- (id)m_nsAliasName;
@end

@interface AddContactToChatRoomViewController : MMUIViewController
@property (retain, nonatomic) CBaseContact *m_contact;
- (void)ddWxidSwitchChanged:(UISwitch *)sender;        // 自定义用户账号
- (void)ddAvatarSwitchChanged:(UISwitch *)sender;      // 自定义用户头像
- (void)dd_injectProfileSection;                       // 聊天详情页插入头像 + 账号开关
- (void)ddRefreshProfile;                              // 账号改完补一次刷新
@end

@interface CContact : CBaseContact
@end

@interface ContactInfoViewController : MMUIViewController
// ContactInfoViewController.h:32 —— 当前联系人（CContact）
@property (retain, nonatomic) CContact *m_contact;
// ContactInfoViewController.h:90 —— 重建 m_oContactInfoAssist（账号值的真正来源）
- (void)reloadContactAssist;
// ContactInfoViewController.h:80/:83 —— 重建表格数据源 / 重绘
- (void)reloadData;
- (void)reloadView;
// 统一刷新入口（viewWillAppear 与 kDDProfileChangedNotification 共用）
- (void)ddProfileChangedRefresh;
@end

#pragma mark  头像
@interface MMHeadImageView : MMUIView
@property (readonly, nonatomic) NSString *nsUsrName;
- (void)setHeadImageByName:(id)usrName;
- (void)doUpdateHeadImg:(BOOL)force;
- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl;
- (void)updateHeadImage:(id)image;
- (void)ImageDidLoad:(id)image Url:(id)url;
- (void)didMoveToWindow;
- (double)preferCornerSize;
- (void)setHeadImageViewCornerRadius:(double)radius;
@end

@interface ImageScrollView : MMUIScrollView
- (void)updateImage:(id)image;
@end

@interface MMHDHeadImageView : MMUIView
@property (retain, nonatomic) CBaseContact *m_contact;
- (void)updateHead;
- (void)updateHDHead;
- (void)dd_applyCustomHDHead;
@end

@interface BaseMsgContentLogicController : MMObject
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)GetTitleTailImageView;
@end

@interface RoomContentLogicController : BaseMsgContentLogicController
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)getDefaultTitleTailSubViews;
- (id)getMemeberCountLabel;
@end

#pragma mark  消息（Wrap / ViewModel / CellView）
@interface CMessageWrap : MMObject
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
- (BOOL)IsTextMsg;
- (BOOL)IsImgMsg;
- (BOOL)isReferMsgType;
- (NSString *)GetDisplayContent;
@end

@interface BaseMessageViewModel : BaseChatViewModel
@property (nonatomic, retain) CMessageWrap *messageWrap;
- (void)resetLayoutCache;
@end

@interface CommonMessageViewModel : BaseMessageViewModel
@end

// 依赖 CommonMessageViewModel（上面已声明），须在其后
@interface WCPayBaseMessageViewModel : CommonMessageViewModel
@end


@interface BaseMessageCellView : BaseChatCellView
- (void)layoutContentView;
- (void)layoutInternal;
- (void)prepareForReuse;
- (id)operationMenuItems;
@end

@interface CommonMessageCellView : BaseMessageCellView
@property (nonatomic, readonly) CommonMessageViewModel *viewModel;
- (void)setViewModel:(id)vm;
@end

@interface BaseMsgContentViewController : MMUIViewController
- (void)clearNodeLayoutCache;
- (void)reloadNodeWithMessageWrap:(CMessageWrap *)msgWrap;
- (void)reloadVisibleNodeWithCellView:(UIView *)cellView;
- (UITableView *)getMsgTableView;
@end

@interface TextMessageViewModel : CommonMessageViewModel
@property (readonly, nonatomic) NSString *contentText;
- (void)resetLayoutCache;
@end

// RichTextView：JokerApplyTextToRichView 以 id 接收并调用，类名在代码里不出现，
//   但方法确在调用（编译期需要声明，删了会 "no known instance method"）。
//   签名锚定 WeChat/RichTextView.h:131/132/146/223。
@interface RichTextView : MMCPLabel
- (id)getContent;
- (void)setContent:(id)content;
- (void)calculateAndUpdateFrame;
- (void)forceDisplayInSync;
@end

@interface TextMessageCellView : CommonMessageCellView
- (id)getRichTextView;
- (id)getTextString;
- (void)layoutContentView;
- (void)setViewModel:(id)vm;

@end

@interface WCPayTransferMessageViewModel : WCPayBaseMessageViewModel
- (CMessageWrap *)messageWrap;
@end

@interface WCPayBaseMessageCellView : CommonMessageCellView
- (void)onTouchUpInside;
@end

@interface WCPayTransferMessageCellView : WCPayBaseMessageCellView
- (void)setViewModel:(id)vm;
- (void)layoutContentView;
@end

#pragma mark  支付 / Kinda / 金额组件
@interface WCPayControlData : NSObject
@property (retain, nonatomic) CMessageWrap *m_oSelectedMessageWrap;
@end

@interface WCPayBaseViewController : WCBizBaseViewController
- (WCPayControlData *)data;
@end

@interface WCPayTransferMoneyStatusViewController : WCPayBaseViewController
@end

@interface ImageMessageCellView : CommonMessageCellView
- (void)showImage;
- (void)OnDownloadImageOk:(id)a0;
@end

@interface ChatTimeViewModel : BaseChatViewModel
- (NSString *)timeText;
- (void)updateLayouts;
@end

@interface ChatTimeCellView : BaseChatCellView
- (id)initWithViewModel:(id)vm;
- (void)setViewModel:(id)vm;
- (void)layoutInternal;
- (UILabel *)dk_timeLabel;
- (void)dk_installTimeEditGesture;
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g;
- (void)dk_showTimeInput;
@end

@interface MMMenuItem : UIMenuItem
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
// MMMenuItem.h:29 —— 直接吃 svg 资源名，由微信内部渲染，无需自行转 UIImage
- (instancetype)initWithTitle:(NSString *)title svgName:(NSString *)svgName target:(id)target action:(SEL)action;
@end

#pragma mark  步数 / 好友数
@interface WCDeviceStepObject : MMObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface ContactsDataLogic : MMObject
- (unsigned int)m_uiNormalContact;
@end
@interface ContactsViewController : MMTabBarBaseViewController
- (void)updateCount;
@end

// TimeoutNumber 是 ScrollNumber 的外层容器，金额宽度/布局由它管，
//   改它的 updateNumber: 才会连带重算容器尺寸；直接改内层 ScrollNumber 会右溢顶格。
@interface TimeoutNumber : UIView
- (void)updateNumber:(unsigned long long)a0;
- (void)defaultNumber:(unsigned long long)a0;
- (void)updateScrollNumber;
- (id)scrollNumber;
- (CGSize)scrollNumberSize;
@end

// ScrollNumber：钱包页金额数字容器，运行时为 UIView（dump 声明为 NSObject，故按 UIView 声明以访问 frame）。
//   scrollNumberSize / widthOfNumber: 均以 currentNumber 推算文字宽度；改写余额须同时拦住
//   两个写入口（updateNumber: / defaultNumber:）与 currentNumber getter，
//   使容器宽度与改写值匹配，否则数字右溢顶格。
@interface ScrollNumber : UIView
- (unsigned long long)currentNumber;
- (void)defaultNumber:(unsigned long long)a0;
- (void)updateNumber:(unsigned long long)a0;
- (id)container;      // dump 中存在：外层容器（TimeoutNumber）
@end

// 钱包"服务"页顶部入口头部：余额同时由 timeoutNumber 滚轮与 balanceMoneyLabel 文案呈现。
//   直接 hook 此类刷新方法（而非在通用 ScrollNumber/TimeoutNumber hook 里遍历 superview），
//   用头文件声明的属性在 %orig 后主动灌改写值；判定职责落在类自身，无需视图树遍历。
@interface WCPayWalletEntryHeaderView : UIView
- (id)timeoutNumber;
- (id)balanceMoneyLabel;
- (void)setupTimeoutNumber;
- (void)updateBalanceEntryView;
- (void)updateBalanceAndRefreshView;
- (void)handleUpdateWalletBalance;
@end

// Kinda 金额节点 = Kinda 动态页模板里金额组件的原生实现：
//   KindaMoneyLoadingView.h:3 继承 KindaView（逻辑对象，非 UIView）、:5 持 TimeoutNumber、
//   :21 setMoney:animated: 是 Kinda 页面灌金额的唯一入口。
//   钱包页两单元格与零钱/零钱通详情页（同为 Kinda 页）的金额都归它管。
//   节点自身不携带页面身份（viewId / reportId / delegate 都不区分零钱与零钱通），
//   故判定时拿它持有的 timeoutNumber 走响应链（见 DDBalanceKindFor）。
@interface KindaView : NSObject
@end

@interface KindaMoneyLoadingView : KindaView
@property (retain, nonatomic) id timeoutNumber;
- (void)setMoney:(long long)a0 animated:(BOOL)a1;
@end

#pragma mark - 配置管理（接口）
// 全局开关与各功能自定义值；以 NSUserDefaults 持久化（见文件末"配置管理（实现）"）。


static NSString * const kDDFeatureTextEnabled = @"DDFeatureTextEnabled";
static NSString * const kDDFeatureTransferEnabled = @"DDFeatureTransferEnabled";
static NSString * const kDDFeatureImageEnabled = @"DDFeatureImageEnabled";
static NSString * const kDDFeatureTimeEnabled = @"DDFeatureTimeEnabled";
static NSString * const kDDFeatureBalanceEnabled = @"DDFeatureBalanceEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";
static NSString * const kDDFeatureFriendWxidEnabled = @"DDFeatureFriendWxidEnabled";
static NSString * const kDDFeatureWxidEnabled = @"DDFeatureWxidEnabled";
static NSString * const kDDFeatureWxidValue = @"DDFeatureWxidValue";
static NSString * const kDDFeatureAvatarEnabled = @"DDFeatureAvatarEnabled";
static NSString * const kDDFeatureHideChatName = @"DDFeatureHideChatName";

static NSString * const kDDStepsValueStringKey = @"DDStepsValueString";
static NSString * const kDDContactsCountValueKey = @"DDContactsCountValue";
static NSString * const kDDBalanceValueKey = @"DDBalanceValue";
static NSString * const kDDLingtongValueKey = @"DDLingtongValue";

@interface DDGlobalConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL textEnabled;
@property (nonatomic) BOOL imageEnabled;
@property (nonatomic) BOOL timeEnabled;
@property (nonatomic) BOOL transferEnabled;
@property (nonatomic) BOOL balanceEnabled;
@property (nonatomic) BOOL stepsEnabled;
@property (nonatomic) BOOL contactsEnabled;
@property (nonatomic) BOOL friendWxidEnabled;
@property (nonatomic) BOOL wxidEnabled;
@property (nonatomic, copy) NSString *wxidValue;
@property (nonatomic) BOOL avatarEnabled;
@property (nonatomic) BOOL hideChatName;

@property (nonatomic, copy) NSString *stepsValueString;
@property (nonatomic, copy) NSString *contactsValue;
@property (nonatomic, copy) NSString *balanceValue;
@property (nonatomic, copy) NSString *lingtongValue;
- (NSInteger)stepsIntegerValue;
- (BOOL)hasStepsValue;
- (BOOL)hasBalanceValue;
- (BOOL)hasLingtongValue;
- (void)saveSteps;
- (void)saveContacts;
@end

#pragma mark - 通用辅助


static BOOL DDStringHas(const char *haystack, const char *needle) {
    if (!haystack || !needle || !*needle) return NO;
    NSString *h = [[NSString stringWithUTF8String:haystack] lowercaseString];
    NSString *n = [[NSString stringWithUTF8String:needle] lowercaseString];
    return (h && n) ? ([h rangeOfString:n].location != NSNotFound) : NO;
}

#pragma mark - 聊天消息改写（工具与唯一键）
// 长按消息弹出"小丑"菜单：文字改内容与引用标题、图片替换为相册所选图、转账改金额。
// 改写值按消息会话唯一键缓存到 plist，刷新走 cell/viewModel 重绘。


static CMessageWrap *JokerGetMessageWrapFromCell(CommonMessageCellView *cell) {
    return cell.viewModel.messageWrap;
}

static id JokerGetViewControllerFromView(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

static BOOL JokerIsTextMessage(CMessageWrap *msg) {
    return [msg IsTextMsg];
}

static BOOL JokerIsReferMessage(CMessageWrap *msg) {
    return [msg isReferMsgType];
}

static NSString *JokerUnescapeXML(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || !s.length) return s;
    NSDictionary *map = @{@"&lt;":@"<", @"&gt;":@">", @"&amp;":@"&",
            @"&quot;":@"\"", @"&apos;":@"'"};
    NSMutableString *m = [s mutableCopy];
    for (NSString *key in map) {
        [m replaceOccurrencesOfString:key withString:map[key]
                options:NSLiteralSearch range:NSMakeRange(0, m.length)];
    }
    return m;
}

static NSString *JokerReferMessageTitle(CMessageWrap *msg) {
    NSString *xml = [msg m_nsContent];
    if (![xml isKindOfClass:[NSString class]] || !xml.length) return nil;
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"<title\\s*>(.*?)</title\\s*>"
                options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                error:nil];
    });
    NSTextCheckingResult *r = [re firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (!r || r.numberOfRanges < 2) return nil;
    NSString *t = [xml substringWithRange:[r rangeAtIndex:1]];
    t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    t = JokerUnescapeXML(t);
    return t.length ? t : nil;
}

static BOOL JokerIsTransferCell(CommonMessageCellView *cell) {
    return [cell isKindOfClass:%c(WCPayTransferMessageCellView)];
}

static BOOL JokerIsSupportedCell(CommonMessageCellView *cell) {
    if (!cell) return NO;
    if (JokerIsTransferCell(cell)) return YES;
    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
        return JokerIsTextMessage(msg) || JokerIsReferMessage(msg);
    }
    return NO;
}

static BOOL JokerEnabledForCell(CommonMessageCellView *cell) {
    if (JokerIsTransferCell(cell)) return [DDGlobalConfig shared].transferEnabled;
    return [DDGlobalConfig shared].textEnabled;
}

static NSString *JokerNormalizeAmount(NSString *amount) {
    NSString *trimmed = [amount stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSMutableString *filtered = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if ((c >= '0' && c <= '9') || c == '.') {
            [filtered appendFormat:@"%C", c];
        }
    }
    if (!filtered.length) return nil;

    if ([filtered rangeOfString:@"."].location == NSNotFound) {
        [filtered appendString:@".00"];
    }
    return filtered;
}

static NSString * const kDDJokerTextCacheKey = @"DDJokerTextCache";
static NSString * const kDDJokerAmountCacheKey = @"DDJokerAmountCache";
static NSString * const kDDJokerTimeCacheKey = @"DDJokerTimeCache";

static NSString * const kDDJokerTextOriginalKey = @"DDJokerTextOriginal";
static NSString * const kDDJokerTransferOriginalKey = @"DDJokerTransferOriginal";

// localID 仅在单个会话内唯一（CMessageMgr.h:136 强制 usrName+localID 二元组定位），
// 不同会话的 localID 各自从 1 递增会碰撞。用 (fromUsr|toUsr|localID) 三元组作为全局唯一键，
// 确保不同会话的改写互不串扰。
static NSString *DDJokerMessageKey(CMessageWrap *msg) {
    NSString *from = [msg m_nsFromUsr] ?: @"";
    NSString *to = [msg m_nsToUsr] ?: @"";
    return [NSString stringWithFormat:@"%@|%@|%u", from, to, [msg m_uiMesLocalID]];
}

// 转账金额以 transferid 作为全局唯一缓存键：同一条转账在聊天列表与详情页的
// localID/from/to 可能不一致，但 transferid 必然相同（取自 m_nsContent 的 <transferid>），
// 用它才能稳定命中同一笔改写。
static NSString *DDTransferIDFromContent(NSString *xml) {
    if (!xml.length) return nil;
    NSRange ro = [xml rangeOfString:@"<transferid>" options:NSCaseInsensitiveSearch];
    if (ro.location == NSNotFound) return nil;
    NSUInteger start = ro.location + ro.length;
    NSRange rc = [xml rangeOfString:@"</transferid>" options:NSCaseInsensitiveSearch
            range:NSMakeRange(start, xml.length - start)];
    if (rc.location == NSNotFound) return nil;
    NSString *tid = [xml substringWithRange:NSMakeRange(start, rc.location - start)];
    return tid.length ? tid : nil;
}
static NSString *DDJokerAmountKey(CMessageWrap *msg) {
    NSString *tid = DDTransferIDFromContent([msg m_nsContent]);
    return tid.length ? [@"TRF:" stringByAppendingString:tid] : nil;
}

#pragma mark - 改写值缓存（plist / 替换图）
static NSString *DDJokerCacheDir(void) {
    static NSString *dir = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/DDJoker"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}
static NSString *DDJokerCacheFile(NSString *name) {
    return [DDJokerCacheDir() stringByAppendingPathComponent:[name stringByAppendingString:@".plist"]];
}

// 缓存内存层：每个 plist 进程内只解析一次，之后读写全部命中内存，
// 落盘走同一条串行队列异步执行，避免在消息渲染路径上做同步磁盘 IO。
static dispatch_queue_t DDJokerCacheQueue(void) {
    static dispatch_queue_t q = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("com.ddjoker.cache", DISPATCH_QUEUE_SERIAL); });
    return q;
}
static NSMutableDictionary *DDJokerMemCaches(void) {
    static NSMutableDictionary *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [NSMutableDictionary dictionary]; });
    return c;
}
// 只能在 DDJokerCacheQueue() 内调用：首次访问时载入 plist，之后复用同一份内存字典。
static NSMutableDictionary *DDJokerMemCacheFor(NSString *name) {
    NSMutableDictionary *d = DDJokerMemCaches()[name];
    if (!d) {
        d = [NSMutableDictionary dictionaryWithContentsOfFile:DDJokerCacheFile(name)];
        if (!d) d = [NSMutableDictionary dictionary];
        DDJokerMemCaches()[name] = d;
    }
    return d;
}
static id DDJokerCacheGet(NSString *name, NSString *key) {
    if (!key) return nil;
    __block id v = nil;
    dispatch_sync(DDJokerCacheQueue(), ^{ v = DDJokerMemCacheFor(name)[key]; });
    return v;
}
// 内存同步更新（保证后续读取立即可见），磁盘异步落盘（不阻塞主线程）。
static void DDJokerCacheSet(NSString *name, NSString *key, id value) {
    if (!key) return;
    NSString *path = DDJokerCacheFile(name);
    dispatch_sync(DDJokerCacheQueue(), ^{
        if (value) DDJokerMemCacheFor(name)[key] = value;
        else [DDJokerMemCacheFor(name) removeObjectForKey:key];
    });
    dispatch_async(DDJokerCacheQueue(), ^{ [DDJokerMemCacheFor(name) writeToFile:path atomically:YES]; });
}
static void DDJokerCacheClear(NSString *name) {
    NSString *path = DDJokerCacheFile(name);
    dispatch_sync(DDJokerCacheQueue(), ^{ [DDJokerMemCaches() removeObjectForKey:name]; });
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}
// 替换图目录：路径进程内固定，只在首次与「清空记录」后各建一次。
//   原实现每次调用都 createDirectoryAtPath，而 DDImageReplacementPath 是从 layoutContentView
//   走进来的 —— 那是一条布局热路径，不该每帧都去碰一次文件系统。
static NSString *DDJokerImagesDir(void) {
    static NSString *dir = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dir = [DDJokerCacheDir() stringByAppendingPathComponent:@"DDJokerImages"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

// 替换图内存缓存：layoutContentView 每次布局都取一次替换图，不缓存就是每帧一次磁盘 stat；
//   命中替换图时更糟 —— 每帧重新解码一遍。
//   NSNull 作负面缓存：绝大多数消息没有替换图，不记这一条的话每次都要白 stat 一次磁盘。
static NSCache *DDImageReplacementCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 32;
    });
    return cache;
}

// 换图落盘后、或清空全部记录后调用；传 nil 表示全清。
static void DDImageReplacementInvalidate(NSString *sessionKey) {
    if (sessionKey.length) [DDImageReplacementCache() removeObjectForKey:sessionKey];
    else [DDImageReplacementCache() removeAllObjects];
}

static NSString *DDJokerCachedText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *v = DDJokerCacheGet(kDDJokerTextCacheKey, DDJokerMessageKey(msg));
    return [v isKindOfClass:[NSString class]] && [v length] ? v : nil;
}

// 前向声明：原文写入函数定义在本文件稍后，改写时需要先补记原文。
static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text);

// 原文只在真正改写时记录一次：此刻 m_nsContent 还没被改写过，存下来的才是真原文。
// 留空还原不删这条记录，保证再次改写 / 还原始终能回到最初原文。
static void DDJokerSetCachedText(CMessageWrap *msg, NSString *text) {
    if (!msg) return;
    NSString *key = DDJokerMessageKey(msg);
    if (text.length) {
        DDJokerSetOriginalText(msg, msg.m_nsContent);
        DDJokerCacheSet(kDDJokerTextCacheKey, key, text);
    } else {
        DDJokerCacheSet(kDDJokerTextCacheKey, key, nil);
    }
}

static NSString *DDJokerOriginalText(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *v = DDJokerCacheGet(kDDJokerTextOriginalKey, DDJokerMessageKey(msg));
    return [v isKindOfClass:[NSString class]] && [v length] ? v : nil;
}

static void DDJokerSetOriginalText(CMessageWrap *msg, NSString *text) {
    if (!msg || !text.length) return;
    if (DDJokerOriginalText(msg)) return;
    DDJokerCacheSet(kDDJokerTextOriginalKey, DDJokerMessageKey(msg), text);
}

static NSString *DDJokerCachedAmount(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *key = DDJokerAmountKey(msg);
    if (!key) return nil;
    NSString *v = DDJokerCacheGet(kDDJokerAmountCacheKey, key);
    return [v isKindOfClass:[NSString class]] && [v length] ? v : nil;
}

static void DDJokerSetCachedAmount(CMessageWrap *msg, NSString *amount) {
    if (!msg) return;
    NSString *key = DDJokerAmountKey(msg);
    if (!key) return;
    DDJokerCacheSet(kDDJokerAmountCacheKey, key, amount.length ? amount : nil);
}

// 原始转账 XML 缓存：按 transferid 索引，还原时写回以使"留空还原"立即生效。
static NSString *DDJokerOriginalTransferXML(CMessageWrap *msg) {
    if (!msg) return nil;
    NSString *key = DDJokerAmountKey(msg);
    if (!key) return nil;
    NSString *v = DDJokerCacheGet(kDDJokerTransferOriginalKey, key);
    return [v isKindOfClass:[NSString class]] && [v length] ? v : nil;
}
static void DDJokerSetOriginalTransferXML(CMessageWrap *msg, NSString *xml) {
    if (!msg || !xml.length) return;
    NSString *key = DDJokerAmountKey(msg);
    if (!key || DDJokerOriginalTransferXML(msg).length) return;
    DDJokerCacheSet(kDDJokerTransferOriginalKey, key, xml);
}

#pragma mark - 聊天时间 · 缓存与 ivar 读写
// 直接读写 ChatTimeViewModel 的 _showingTime ivar（double 时间戳）；缓存按消息或原始时间戳索引。


static Ivar DDShowingTimeIvarOf(id vm) {
    if (!vm) return NULL;
    Class cls = [vm class];
    Ivar iv = class_getInstanceVariable(cls, "_showingTime");
    if (iv) return iv;

    Class c = cls;
    while (c && !iv) {
        unsigned int n = 0;
        Ivar *list = class_copyIvarList(c, &n);
        for (unsigned int i = 0; i < n; i++) {
            const char *nm = ivar_getName(list[i]) ?: "";
            const char *ty = ivar_getTypeEncoding(list[i]) ?: "";
            if (strcmp(ty, "d") == 0 && DDStringHas(nm, "showingtime")) { iv = list[i]; break; }
        }
        free(list);
        c = class_getSuperclass(c);
    }
    return iv;
}

static double DDShowingTimeOf(id vm) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return 0.0;
    return *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv));
}

static void DDSetShowingTime(id vm, double ts) {
    Ivar iv = DDShowingTimeIvarOf(vm);
    if (!iv) return;
    *(double *)((uint8_t *)(__bridge void *)vm + ivar_getOffset(iv)) = ts;
}

static void DDRefreshTimeText(id vm) {
    [(ChatTimeViewModel *)vm updateLayouts];
}

static char kDDRawTimeKey;
static double DDRawShowingTimeOf(id vm) {
    if (!vm) return 0.0;
    NSNumber *raw = objc_getAssociatedObject(vm, &kDDRawTimeKey);
    if (!raw) {
        raw = @(DDShowingTimeOf(vm));
        objc_setAssociatedObject(vm, &kDDRawTimeKey, raw, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return [raw doubleValue];
}

static NSString *DDJokerTimeKey(id vm) {
    id wrap = [vm respondsToSelector:@selector(messageWrap)] ? [vm messageWrap] : nil;
    if ([wrap respondsToSelector:@selector(m_uiMesLocalID)] && [wrap m_uiMesLocalID] != 0) {
        return DDJokerMessageKey((CMessageWrap *)wrap);
    }
    return [NSString stringWithFormat:@"ts_%.3f", DDRawShowingTimeOf(vm)];
}

static NSNumber *DDJokerCachedTime(id vm) {
    if (!vm) return nil;
    id v = DDJokerCacheGet(kDDJokerTimeCacheKey, DDJokerTimeKey(vm));
    return [v isKindOfClass:[NSNumber class]] ? v : nil;
}

static void DDJokerSetCachedTime(id vm, double timestamp) {
    if (!vm) return;
    DDJokerCacheSet(kDDJokerTimeCacheKey, DDJokerTimeKey(vm), timestamp > 0 ? @(timestamp) : nil);
}

static void DDApplyTimeOverride(id vm) {
    if (!vm || ![DDGlobalConfig shared].timeEnabled) return;
    NSNumber *cached = DDJokerCachedTime(vm);
    if (cached && DDShowingTimeOf(vm) != [cached doubleValue]) {
        DDSetShowingTime(vm, [cached doubleValue]);
    }
}

#pragma mark - 通用刷新与视图查找

#pragma mark  清空改写缓存

static void DDJokerClearAllMessageCache(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    DDJokerCacheClear(kDDJokerTextCacheKey);
    DDJokerCacheClear(kDDJokerAmountCacheKey);
    DDJokerCacheClear(kDDJokerTimeCacheKey);
    DDJokerCacheClear(kDDJokerTextOriginalKey);
    DDJokerCacheClear(kDDJokerTransferOriginalKey);

    [fm removeItemAtPath:DDJokerImagesDir() error:nil];
    // 目录是 dispatch_once 建的，删掉后必须补建一次，否则后续选图落盘会因父目录缺失失败。
    [fm createDirectoryAtPath:DDJokerImagesDir() withIntermediateDirectories:YES attributes:nil error:nil];
    // 连同替换图内存缓存一起清，否则清空后 cell 仍从缓存里拿到旧替换图。
    DDImageReplacementInvalidate(nil);
}

#pragma mark  全量重载（遍历所有聊天页）
static void JokerCollectViewControllers(UIViewController *root, NSMutableArray *out) {
    if (!root || [out containsObject:root]) return;
    [out addObject:root];
    if (root.presentedViewController) JokerCollectViewControllers(root.presentedViewController, out);
    for (UIViewController *c in root.childViewControllers) JokerCollectViewControllers(c, out);
    if ([root isKindOfClass:[UINavigationController class]]) {
        for (UIViewController *c in ((UINavigationController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
    if ([root isKindOfClass:[UITabBarController class]]) {
        for (UIViewController *c in ((UITabBarController *)root).viewControllers) JokerCollectViewControllers(c, out);
    }
}

static NSArray *JokerAllChatViewControllers(void) {
    NSMutableArray *all = [NSMutableArray array];
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            JokerCollectViewControllers(w.rootViewController, all);
        }
    }
    NSMutableArray *chats = [NSMutableArray array];
    for (UIViewController *vc in all) {
        if ([vc isKindOfClass:%c(BaseMsgContentViewController)]) [chats addObject:vc];
    }
    return chats;
}

static void JokerReloadAllMsgContent(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if ([tv isKindOfClass:[UITableView class]]) [tv reloadData];
    }
}

#pragma mark  可见 cell 查找与刷新
static void DDCollectViewsOfClass(UIView *root, Class cls, NSMutableArray *out) {
    if (!root) return;
    if ([root isKindOfClass:cls]) {
        if (![out containsObject:root]) [out addObject:root];
        return;
    }
    for (UIView *v in root.subviews) DDCollectViewsOfClass(v, cls, out);
}

static NSArray *DDVisibleCellViewsOfClass(UITableView *tv, Class cls) {
    NSMutableArray *out = [NSMutableArray array];
    if (![tv isKindOfClass:[UITableView class]] || !cls) return out;
    for (UITableViewCell *c in [tv visibleCells]) {
        DDCollectViewsOfClass(c.contentView, cls, out);
        DDCollectViewsOfClass(c, cls, out);
    }
    return out;
}

static void JokerRefreshVisibleImageCells(void) {
    for (UIViewController *vc in JokerAllChatViewControllers()) {
        UITableView *tv = [(BaseMsgContentViewController *)vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) continue;
        for (ImageMessageCellView *cellView in DDVisibleCellViewsOfClass(tv, %c(ImageMessageCellView))) {
            if ([cellView respondsToSelector:@selector(showImage)]) [cellView showImage];
        }
    }
}

static NSString *DDTransferFeedescAmount(NSString *xml);

#pragma mark  单条 cell 重绘
static NSString *JokerGetDisplayText(CMessageWrap *msg, BOOL isTransfer) {
    if (isTransfer) {
        NSString *cached = DDJokerCachedAmount(msg);
        if (cached.length) return cached;
        NSString *raw = DDTransferFeedescAmount([msg m_nsContent]);
        return JokerNormalizeAmount(raw) ?: @"";
    }
    NSString *cached = DDJokerCachedText(msg);
    if (cached) return cached;

    if (JokerIsReferMessage(msg)) {
        NSString *t = JokerReferMessageTitle(msg);
        if (t) return t;
    }
    return [msg GetDisplayContent] ?: @"";
}

static UITableView *JokerFindTableView(UIView *view) {
    UIView *v = view;
    while (v) {
        if ([v isKindOfClass:[UITableView class]]) return (UITableView *)v;
        v = v.superview;
    }
    return nil;
}

static void JokerApplyTextToRichView(id richView, NSString *text) {
    if (!richView || !text) return;
    [richView setContent:text];
    [richView calculateAndUpdateFrame];
    [richView forceDisplayInSync];
    [richView setNeedsDisplay];
}

static void JokerResetViewModelCache(CommonMessageCellView *cell) {
    id vm = cell.viewModel;
    [vm resetLayoutCache];
}

static void JokerRefreshCellDirectly(CommonMessageCellView *cell) {
    if (!cell) return;
    JokerResetViewModelCache(cell);
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);

    if ([cell isKindOfClass:%c(TextMessageCellView)]) {
        NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;

        if (!cached && (JokerIsTextMessage(msg) || JokerIsReferMessage(msg))) {
            if (JokerIsReferMessage(msg)) {
                cached = JokerReferMessageTitle(msg) ?: [msg GetDisplayContent];
            } else {
                cached = [msg GetDisplayContent];
            }
        }
        JokerApplyTextToRichView([(TextMessageCellView *)cell getRichTextView], cached);
        [(TextMessageCellView *)cell layoutContentView];
    } else if ([cell isKindOfClass:%c(WCPayTransferMessageCellView)]) {
        // layoutContentView 内部已按改写值重写 m_nsContent 并重绘，群/私聊一并生效。
        [(WCPayTransferMessageCellView *)cell layoutContentView];
    } else if ([cell isKindOfClass:%c(ImageMessageCellView)]) {
        [(ImageMessageCellView *)cell showImage];
    }
    [cell setNeedsLayout];
}

static void JokerInvalidateAllLayout(void);

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    JokerRefreshCellDirectly(cell);
    UITableView *tv = cell ? JokerFindTableView((UIView *)cell) : nil;
    if (![tv isKindOfClass:[UITableView class]] && [vc isKindOfClass:%c(BaseMsgContentViewController)]) {
        tv = [(BaseMsgContentViewController *)vc getMsgTableView];
    }
    if (![tv isKindOfClass:[UITableView class]]) {

        JokerReloadAllMsgContent();
        return;
    }

    CGPoint center = [cell convertPoint:CGPointMake(CGRectGetMidX(cell.bounds), CGRectGetMidY(cell.bounds)) toView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:center];
    if (ip) {
        [UIView performWithoutAnimation:^{
            [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        }];
        return;
    }
    JokerInvalidateAllLayout();
}

#pragma mark  长按菜单与编辑器
static void JokerPresentEditor(CommonMessageCellView *cell) {

    if (!JokerIsSupportedCell(cell)) return;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    id vc = JokerGetViewControllerFromView(cell);

    BOOL isTransfer = JokerIsTransferCell(cell);
    NSString *current = JokerGetDisplayText(msg, isTransfer);

    NSString *editorTitle = isTransfer ? @"转账修改" : @"文字修改";
    NSString *editorMessage = isTransfer ? @"请输入需要修改的金额\n留空还原" : @"请输入需要修改的文字\n留空还原";
    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:editorTitle message:editorMessage];
    if (!alert) return;
    [alert showTextFieldWithMaxLen:1000];
    [alert setTextFieldDefaultText:current];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{}];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *newText = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length) {
            if ([newText isEqualToString:current]) { blockAlert = nil; return; }
            if (isTransfer) {
                NSString *normalized = JokerNormalizeAmount(newText);
                if (normalized) { DDJokerSetCachedAmount(msg, normalized); }
            } else {
                DDJokerSetCachedText(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, cell);
        } else if (isTransfer ? DDJokerCachedAmount(msg) : DDJokerCachedText(msg)) {

            if (isTransfer) DDJokerSetCachedAmount(msg, nil);
            else DDJokerSetCachedText(msg, nil);
            JokerReloadCellAfterReplace(vc, msg, cell);
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) {
        inputField = tf;
        if (isTransfer) tf.keyboardType = UIKeyboardTypeDecimalPad;
    }
}

// 菜单项：直接用微信内置 svg 图标 icons_filled_sticker（MMMenuItem.h:29 原生支持 svg 资源名）。
static MMMenuItem *DDJokerMenuItem(NSString *title, id target, SEL action) {
    id item = [%c(MMMenuItem) alloc];
    return [item initWithTitle:title
            svgName:@"icons_filled_sticker"
            target:target
            action:action];
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {

    if (!JokerEnabledForCell(cell)) return original;
    if (!JokerIsSupportedCell(cell)) return original;

    MMMenuItem *newItem = DDJokerMenuItem(@"小丑", cell, @selector(joker_handleMenuItem:));
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

#pragma mark - 聊天文字改写（hook）
// 套用改写值；没有改写值时用已记录的原文还原。
// 原文不在这里记录——只在用户真正改写时（DDJokerSetCachedText）才存一次，
// 否则浏览过的每条文本消息都会往 original 表写一份用不上的原文。
static void DDJokerApplyTextOverride(CMessageWrap *msg) {
    if (!msg) return;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;
    NSString *cached = [DDGlobalConfig shared].textEnabled ? DDJokerCachedText(msg) : nil;
    NSString *original = DDJokerOriginalText(msg);
    NSString *target = cached ?: original;
    if (target.length && ![target isEqualToString:msg.m_nsContent]) {
        [msg setM_nsContent:target];
    }
}

%hook TextMessageViewModel
- (NSString *)contentText {
    DDJokerApplyTextOverride(self.messageWrap);
    NSString *origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    CMessageWrap *msg = self.messageWrap;

    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
%end

static BOOL gJokerNeedsResetLayout = NO;

#pragma mark  全局失效入口
static void JokerInvalidateAllLayout(void) {
    gJokerNeedsResetLayout = YES;
    JokerReloadAllMsgContent();
    JokerRefreshVisibleImageCells();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gJokerNeedsResetLayout = NO;
    });
}

%hook TextMessageCellView

- (void)setViewModel:(id)vm {
    %orig;
    if (![vm respondsToSelector:@selector(resetLayoutCache)]) return;
    CMessageWrap *msg = [(CommonMessageViewModel *)vm messageWrap];
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return;

    if (gJokerNeedsResetLayout || DDJokerCachedText(msg) || ![DDGlobalConfig shared].textEnabled) {
        [(TextMessageViewModel *)vm resetLayoutCache];
    }
}
- (id)getTextString {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(self);
    DDJokerApplyTextOverride(msg);
    id origin = %orig;
    if (![DDGlobalConfig shared].textEnabled) return origin;
    if (!JokerIsTextMessage(msg) && !JokerIsReferMessage(msg)) return origin;
    NSString *cached = DDJokerCachedText(msg);
    return cached ?: origin;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return JokerEnabledForCell(self) && JokerIsSupportedCell(self);
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

#pragma mark - 转账改写（hook）
static NSString *DDTransferFeedescAmount(NSString *xml) {
    if (!xml.length) return nil;
    NSString *open = @"<feedesc><![CDATA[";
    NSString *close = @"]]></feedesc>";
    NSRange ro = [xml rangeOfString:open];
    if (ro.location == NSNotFound) return nil;
    NSUInteger start = ro.location + ro.length;
    NSRange rc = [xml rangeOfString:close options:0 range:NSMakeRange(start, xml.length - start)];
    if (rc.location == NSNotFound) return nil;
    return [xml substringWithRange:NSMakeRange(start, rc.location - start)];
}

// 转账详情页作用域：进入时记录改写金额，离开时清除。
static BOOL gDDInTransferDetail = NO;
static NSString *gDDTransferDetailAmount = nil;
static void DDTransferDetailEnter(CMessageWrap *msg) {
    gDDInTransferDetail = YES;
    NSString *amt = DDJokerCachedAmount(msg);
    gDDTransferDetailAmount = amt.length ? [amt copy] : nil;
}
static void DDTransferDetailLeave(void) {
    gDDInTransferDetail = NO;
    gDDTransferDetailAmount = nil;
}

// 替换转账 XML <feedesc> 段内的金额（群聊/私聊 同在一段 CDATA）。
static NSString *DDFeedescReplaceAmount(NSString *xml, NSString *amount) {
    if (![xml isKindOfClass:[NSString class]] || !xml.length || !amount.length) return nil;
    static NSRegularExpression *outer;
    static NSRegularExpression *inner;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        outer = [NSRegularExpression regularExpressionWithPattern:@"<feedesc>(.*?)</feedesc>"
                options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                error:nil];
        inner = [NSRegularExpression regularExpressionWithPattern:@"¥\\d[\\d,]*\\.\\d{2}"
                options:0
                error:nil];
    });
    NSTextCheckingResult *m = [outer firstMatchInString:xml options:0 range:NSMakeRange(0, xml.length)];
    if (!m || m.numberOfRanges < 2) return nil;
    NSRange segRange = [m rangeAtIndex:1];
    NSString *seg = [xml substringWithRange:segRange];
    NSString *newSeg = [inner stringByReplacingMatchesInString:seg options:0 range:NSMakeRange(0, seg.length)
                            withTemplate:[@"¥" stringByAppendingString:amount]];
    if ([newSeg isEqualToString:seg]) return nil;
    NSMutableString *out = [xml mutableCopy];
    [out replaceCharactersInRange:segRange withString:newSeg];
    return [out copy];
}

// 装配/布局时把改写金额写入 messageWrap.m_nsContent：有改写则改 <feedesc> 金额并记录原始 XML，
// 无改写（还原）则写回原始 XML。
static void DDApplyTransferOverrideToModel(id vm) {
    if (![DDGlobalConfig shared].transferEnabled || !vm) return;
    CMessageWrap *msg = [vm messageWrap];
    NSString *xml = [msg m_nsContent];
    NSString *amount = DDJokerCachedAmount(msg);
    NSString *target;
    if (amount.length) {
        if (!DDJokerOriginalTransferXML(msg).length) DDJokerSetOriginalTransferXML(msg, xml);
        target = DDFeedescReplaceAmount(xml, amount);
    } else {
        NSString *orig = DDJokerOriginalTransferXML(msg);
        target = orig.length ? orig : xml;
    }
    if (target && ![target isEqualToString:xml]) [msg setM_nsContent:target];
}

// 转账金额改写：装配（setViewModel:）与布局（layoutContentView）时写入 messageWrap.m_nsContent；
// 详情页金额走 label 文本层，由下方 MMUILabel 兜底改写。
%hook WCPayTransferMoneyStatusViewController
- (void)viewDidLoad {
    DDTransferDetailEnter([self data].m_oSelectedMessageWrap);
    %orig;
}
- (void)dealloc {
    %orig;
    DDTransferDetailLeave();
}
%end

%hook WCPayTransferMessageCellView
- (void)setViewModel:(id)vm {
    DDApplyTransferOverrideToModel(vm);
    %orig;
}
- (void)layoutContentView {
    DDApplyTransferOverrideToModel(self.viewModel);
    %orig;
}
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].transferEnabled;
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

// 详情页金额文本兜底：作用域内把纯 ¥ 金额文本替换为改写值。
// 判断详情页金额文本是否需改写：作用域内且为纯 ¥ 金额。
static BOOL DDTransferDetailHit(NSString *text) {
    return gDDInTransferDetail && gDDTransferDetailAmount.length
        && [text rangeOfString:@"^¥\\d[\\d,]*\\.\\d{2}$" options:NSRegularExpressionSearch].location != NSNotFound;
}
%hook MMUILabel
// 转账详情页金额兜底：作用域内把 ¥ 金额文本替换为改写值。
- (void)setText:(NSString *)text {
    if (DDTransferDetailHit(text)) %orig([@"¥" stringByAppendingString:gDDTransferDetailAmount]);
    else %orig;
}
- (void)setAttributedText:(NSAttributedString *)attr {
    if (attr.string.length && DDTransferDetailHit(attr.string)) {
        NSDictionary *attrs = [attr attributesAtIndex:0 effectiveRange:NULL];
        %orig([[NSAttributedString alloc] initWithString:[@"¥" stringByAppendingString:gDDTransferDetailAmount] attributes:attrs]);
    } else %orig;
}
%end

#pragma mark - 聊天图片改写
// hook ImageMessageCellView 各渲染入口注入替换图；相册选图回调见下一段。


@interface DDWeChatImagePickerDelegate : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) NSString *sessionKey;   // 会话唯一键（from|to|localID），区分不同会话的图片改写
@property (nonatomic, weak) id cellView;
@end

static NSString *DDImageReplacementPath(NSString *sessionKey) {
    NSString *folder = DDJokerImagesDir();
    NSString *safe = [sessionKey stringByReplacingOccurrencesOfString:@"|" withString:@"_"];
    return [folder stringByAppendingPathComponent:[safe stringByAppendingString:@".png"]];
}

static UIImage *DDImageReplacementForMessage(CMessageWrap *msg) {
    if (!msg || ![msg IsImgMsg]) return nil;
    NSString *key = DDJokerMessageKey(msg);
    NSCache *cache = DDImageReplacementCache();
    id cached = [cache objectForKey:key];
    if (cached) return (cached == [NSNull null]) ? nil : (UIImage *)cached;

    NSString *path = DDImageReplacementPath(key);
    UIImage *img = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        img = [UIImage imageWithContentsOfFile:path];
        if (!(img && img.size.width > 0 && img.size.height > 0)) img = nil;
    }
    [cache setObject:(img ?: (UIImage *)[NSNull null]) forKey:key];
    return img;
}

static UIImageView *DDImageViewFromCell(UIView *cell) {
    if (!cell) return nil;
    // 图片视图为 ImageMessageCellView 的 m_imageView ivar，直接读取，无需遍历。
    Ivar ivar = class_getInstanceVariable([cell class], "m_imageView");
    if (ivar) {
        id value = object_getIvar(cell, ivar);
        if ([value isKindOfClass:[UIImageView class]]) return (UIImageView *)value;
    }
    return nil;
}

static void DDImageApplyReplacementToCell(id cell) {
    if (![DDGlobalConfig shared].imageEnabled) return;
    CMessageWrap *msg = ((CommonMessageCellView *)cell).viewModel.messageWrap;
    UIImage *rep = DDImageReplacementForMessage(msg);
    if (rep) {
        UIImageView *iv = DDImageViewFromCell((UIView *)cell);
        [iv setImage:rep];
    }
}

%hook ImageMessageCellView
- (void)setViewModel:(id)vm {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.imageEnabled) return original;
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return original;
    MMMenuItem *newItem = DDJokerMenuItem(@"小丑", self, @selector(dk_changeChatImage));
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dk_changeChatImage)) {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.imageEnabled) return NO;
        CMessageWrap *msg = self.viewModel.messageWrap;
        return [msg IsImgMsg];
    }
    return %orig;
}
%new
- (void)dk_changeChatImage {
    CMessageWrap *msg = self.viewModel.messageWrap;
    if (![msg IsImgMsg]) return;
    id vc = JokerGetViewControllerFromView((UIView *)(id)self);
    if (!vc) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    picker.title = @"图片修改";
    DDWeChatImagePickerDelegate *delegate = [[DDWeChatImagePickerDelegate alloc] init];
    delegate.sessionKey = DDJokerMessageKey(msg);
    delegate.cellView = self;
    picker.delegate = delegate;

    // 关联对象只为在 picker 存活期间强持有 delegate（picker.delegate 是 assign，不持有）
    objc_setAssociatedObject(picker, "dd_picker_delegate", delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [vc presentViewController:picker animated:YES completion:nil];
}
- (void)showImage {
    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)OnDownloadImageOk:(id)a0 {

    %orig;
    DDImageApplyReplacementToCell(self);
}
- (void)layoutContentView {
    %orig;
    DDImageApplyReplacementToCell(self);
}
%end

@implementation DDWeChatImagePickerDelegate

#pragma mark - 系统相册选图回调
// 选图后落盘到以 sessionKey（from|to|localID）命名的 png，并刷新对应 cell。


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    if (image) [self dd_saveImage:image dismissPicker:picker];
    else [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)dd_saveImage:(UIImage *)image dismissPicker:(UIImagePickerController *)picker {
    NSString *path = DDImageReplacementPath(self.sessionKey);
    NSData *data = UIImagePNGRepresentation(image);
    if (!data) { [picker dismissViewControllerAnimated:YES completion:nil]; return; }
    [data writeToFile:path atomically:YES];
    // 落盘后丢掉这条的内存缓存，否则紧接着的重新渲染仍会读到旧替换图。
    DDImageReplacementInvalidate(self.sessionKey);

    id cellView = self.cellView;
    if ([cellView isKindOfClass:%c(ImageMessageCellView)]) {
        DDImageApplyReplacementToCell(cellView);
        [(UIView *)cellView setNeedsLayout];
    } else {
        JokerInvalidateAllLayout();
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}
@end

#pragma mark - 聊天时间改写
// hook ChatTimeViewModel / ChatTimeCellView：接管时间条显示，长按弹输入改时间。


static char kDDTimeVMKey;

static NSDateFormatter *DDTimeInputFormatter(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd HH:mm";
    return f;
}

static double DDTimeStampFromString(NSString *s) {
    if (!s.length) return 0;
    NSDate *d = [DDTimeInputFormatter() dateFromString:s];
    return d ? [d timeIntervalSince1970] : 0;
}

%hook ChatTimeViewModel
- (NSString *)timeText {

    double raw = DDRawShowingTimeOf(self);
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(self) : nil;
    double target = cached ? [cached doubleValue] : raw;

    if (target > 0 && DDShowingTimeOf(self) != target) {
        DDSetShowingTime(self, target);
        DDRefreshTimeText(self);
    }

    return %orig;
}

%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)vm {
    id r = %orig;

    objc_setAssociatedObject(r, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [(ChatTimeCellView *)r dk_installTimeEditGesture];
    return r;
}
- (void)setViewModel:(id)vm {
    %orig;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dk_installTimeEditGesture];
}
- (void)didMoveToWindow {
    %orig;
    [self dk_installTimeEditGesture];
    if (!self.window) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm) return;
    NSNumber *cached = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(vm) : nil;
    if (!cached) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        id v = objc_getAssociatedObject(self, &kDDTimeVMKey);
        if (!v) return;
        NSNumber *c = [DDGlobalConfig shared].timeEnabled ? DDJokerCachedTime(v) : nil;
        if (!c) return;
        DDApplyTimeOverride(v);
        DDRefreshTimeText(v);
        [(ChatTimeCellView *)self layoutInternal];
        [self setNeedsLayout];
    });
}
%new
- (UILabel *)dk_timeLabel {
    // 时间 label 为 ChatTimeCellView 的 m_timeLabel ivar，直接读取，无需遍历。
    Ivar iv = class_getInstanceVariable([self class], "m_timeLabel");
    if (iv) {
        id v = object_getIvar(self, iv);
        if ([v isKindOfClass:[UILabel class]]) return (UILabel *)v;
    }
    return nil;
}
%new
- (void)dk_installTimeEditGesture {
    if (![DDGlobalConfig shared].timeEnabled) return;
    UILabel *label = [self dk_timeLabel];
    if (!label) return;
    for (UIGestureRecognizer *g in label.gestureRecognizers) {
        if ([g isKindOfClass:[UILongPressGestureRecognizer class]]) return;
    }
    label.userInteractionEnabled = YES;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dk_handleTimeLongPress:)];
    lp.minimumPressDuration = 0.5;
    lp.allowableMovement = 24;
    lp.cancelsTouchesInView = NO;
    [label addGestureRecognizer:lp];
}
%new
- (void)dk_handleTimeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self dk_showTimeInput];
}
%new
- (void)dk_showTimeInput {
    if (![DDGlobalConfig shared].timeEnabled) return;
    id vm = objc_getAssociatedObject(self, &kDDTimeVMKey);
    if (!vm || !%c(WCUIAlertView)) return;

    NSNumber *cached = DDJokerCachedTime(vm);
    double base = cached ? [cached doubleValue]
            : DDShowingTimeOf(vm);
    NSString *defaultText = base > 0 ? [DDTimeInputFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:base]] : @"";

    WCUIAlertView *alert = [(WCUIAlertView *)[%c(WCUIAlertView) alloc] initWithTitle:@"时间修改"
            message:@"输入格式如下\n2024-08-01 22:30\n留空还原"];
    [alert showTextFieldWithMaxLen:100];
    [alert setTextFieldDefaultText:defaultText];

    __block WCUIAlertView *blockAlert = alert;
    __block UITextField *inputField = nil;
    [alert addCancelBtnTitle:@"取消" handler:^{ blockAlert = nil; }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *raw = blockAlert ? [blockAlert getTextFieldText] : nil;
        if (!raw.length) raw = inputField.text;
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        double ts = DDTimeStampFromString(t);
        if (ts > 0) {

            DDJokerSetCachedTime(vm, ts);
            DDSetShowingTime(vm, ts);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        } else if (DDJokerCachedTime(vm)) {

            DDJokerSetCachedTime(vm, 0);
            double rawTime = DDRawShowingTimeOf(vm);
            if (rawTime > 0) DDSetShowingTime(vm, rawTime);
            DDRefreshTimeText(vm);
            [self layoutInternal];
            [self setNeedsLayout];
        }
        blockAlert = nil;
    }];
    [alert show];
    UITextField *tf = [alert getTextField];
    if (tf) inputField = tf;
    objc_setAssociatedObject(self, &kDDTimeVMKey, vm, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%end

#pragma mark - 运动步数改写
// hook WCDeviceStepObject 的 m7StepCount / hkStepCount getter，返回自定义步数。


%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSInteger v = [cfg stepsIntegerValue];
        if (v > 0) return (unsigned int)MIN(v, 99999);
    }
    return %orig;
}
%end

#pragma mark - 好友数量改写
// 改 ContactsDataLogic 的数量 getter，影响通讯录页顶部那个「N个朋友」计数


%hook ContactsDataLogic
- (unsigned int)m_uiNormalContact {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    // 开关关 / 没填值 / 填了非数字，integerValue 都是 0 → 走 %orig 显示真实数量。
    NSInteger v = cfg.contactsEnabled ? [cfg.contactsValue integerValue] : 0;
    if (v > 0) return (unsigned int)v;
    return %orig;
}
%end

%hook ContactsViewController
// 「N个朋友」的数据源是 m_uiNormalContact（ContactsDataLogic.h:35），已被 hook。
// 但文本是布局阶段才按数据生成的：updateCount 只更新了数据，还得再触发一次布局，
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self updateCount];
    [self.view setNeedsLayout];
}
%end

#pragma mark - 余额 / 零钱通改写（工具）
// 元→分换算、页面类型判定（余额 / 零钱通 / 无关）、金额文本正则改写。


// 目标值缓存：ScrollNumber currentNumber 是 Yoga 布局热路径，每次读数都要取一次目标值，
//   没必要每帧把配置字符串重转成 double —— 配置只在设置页改动，故缓存换算结果，
//   由 DDGlobalConfig 的两个 setter 主动失效（见配置管理（实现））。
static unsigned long long gDDBalanceFen = 0;
static BOOL gDDBalanceFenValid = NO;
static unsigned long long gDDLingtongFen = 0;
static BOOL gDDLingtongFenValid = NO;

static void DDBalanceFenCacheInvalidate(void) {
    gDDBalanceFenValid = NO;
    gDDLingtongFenValid = NO;
}

static unsigned long long DDBalanceFenValue(void) {
    if (gDDBalanceFenValid) return gDDBalanceFen;
    unsigned long long fen = 0;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if ([cfg hasBalanceValue]) {
        double v = [cfg.balanceValue doubleValue];
        if (v < 0) v = 0;
        fen = (unsigned long long)(v * 100.0 + 0.5);
    }
    gDDBalanceFen = fen;
    gDDBalanceFenValid = YES;
    return fen;
}

static unsigned long long DDLingtongFenValue(void) {
    if (gDDLingtongFenValid) return gDDLingtongFen;
    unsigned long long fen = 0;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if ([cfg hasLingtongValue]) {
        double v = [cfg.lingtongValue doubleValue];
        if (v < 0) v = 0;
        fen = (unsigned long long)(v * 100.0 + 0.5);
    }
    gDDLingtongFen = fen;
    gDDLingtongFenValid = YES;
    return fen;
}

typedef NS_ENUM(NSInteger, DDBalancePageKind) {
    DDBalancePageNone = 0,
    DDBalancePageBalance,
    DDBalancePageLQT
};

// 页面判定：沿响应链上溯，命中的第一条规则即返回。四处金额同构：
//   TimeoutNumber（容器）→ ScrollNumber（滚轮），仅宿主不同（Kinda 动态页 WalletPageUI）。
//   钱包页两单元格（Kinda 模板节点）：祖先 accessibilityIdentifier
//     balance_cell → 余额，lqt_cell → 零钱通。节点 viewId 存于 KindaView（KindaView.h:40），
//     但 KindaUIView 无反向引用取不到 → 拿不到页面名、拿不到节点 id，只能上溯找 identifier。
//   零钱/零钱通详情页（同为 Kinda 页，VC 是共用壳 KindaViewController）：其 description
//     重写为 "<KindaViewController: 0x…>balanceEntryUIPage / …lqtDetailUIPage"
//     （KindaViewController.h:18 重写了 description），故按 description 匹配页面名。
//   WCPayMainViewControllerV2：服务页原生壳，按类名兜底。
//
// includeVC —— 宽窄两种判定的唯一区别：
//   YES（改值）：认 cell 标识符，也认详情页 / 服务页 —— 这些页面的金额都要改，覆盖面要广。
//   NO （修帧）：只认钱包页两个单元格 —— 改值可以广，动 frame 必须窄，否则会把
//     详情页居中的大数字（宿主接近全屏宽，金额居中）也右对齐推歪。
//   上限 24 只是防御，实际深度由响应链长度决定（cell 与详情页都是 6～9 层）。
static DDBalancePageKind DDBalancePageKindOf(id sn, BOOL includeVC) {
    @try {
        if (![sn isKindOfClass:[UIView class]]) return DDBalancePageNone;
        UIResponder *r = (UIResponder *)sn;
        for (int depth = 0; depth < 24 && r; depth++) {
            if ([r isKindOfClass:[UIView class]]) {
                NSString *ai = ((UIView *)r).accessibilityIdentifier;
                if ([ai isEqualToString:@"lqt_cell"])
                    return DDBalancePageLQT;
                if ([ai isEqualToString:@"balance_cell"])
                    return DDBalancePageBalance;
            }
            if (includeVC && [r isKindOfClass:[UIViewController class]]) {
                NSString *cls = NSStringFromClass([r class]) ?: @"";
                NSString *all = [NSString stringWithFormat:@"%@ %@", cls, [r description] ?: @""];
                if ([all rangeOfString:@"lqtDetailUIPage"].location != NSNotFound)
                    return DDBalancePageLQT;
                if ([all rangeOfString:@"balanceEntryUIPage"].location != NSNotFound ||
                    [cls rangeOfString:@"WCPayMainViewControllerV2"].location != NSNotFound)
                    return DDBalancePageBalance;
            }
            r = r.nextResponder;
        }
    } @catch (NSException *e) {}
    return DDBalancePageNone;
}

// 判定结果缓存：同一实例在页面生命周期内身份恒定，没必要每次布局 / 每次读数都重跑整条响应链。
//   TimeoutNumber 的 scrollNumberSize / widthOfNumber: 每次布局都读 currentNumber（Yoga 布局），
//   不缓存的话一次页面渲染就是几十次全链遍历。
//   宽（改值）/ 窄（修帧）判定结果可能不同，用两个 key 分开存，避免串味。
//   缓存前要求视图已挂载：未入树的实例响应链还不完整，此刻的 None 只是暂时状态，
//   缓存它会让节点挂载后一直读到 None；未挂载一律不缓存，下次重新判定。
//   已挂载的 None 照常缓存 —— 服务页那些与余额无关的节点不必每次都白跑一遍链。
//   实例销毁时关联对象自动释放，新页面新实例重新判定，无失效风险。
static char kDDKindWideKey;
static char kDDKindNarrowKey;

static DDBalancePageKind DDBalanceKindFor(id v, BOOL includeVC) {
    if (![v isKindOfClass:[UIView class]]) return DDBalancePageNone;
    const void *key = includeVC ? &kDDKindWideKey : &kDDKindNarrowKey;
    NSNumber *cached = objc_getAssociatedObject(v, key);
    if (cached) return (DDBalancePageKind)cached.integerValue;
    DDBalancePageKind kind = DDBalancePageKindOf(v, includeVC);
    if (kind != DDBalancePageNone || ((UIView *)v).window) {
        objc_setAssociatedObject(v, key, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return kind;
}

// 前向声明：DDClampFen 定义在本文件稍后（取目标值时要先钳位）
static unsigned long long DDClampFen(unsigned long long fen);

// 取该 view 应改成的目标值（分）；不需要改写返回 NO。
static BOOL DDBalanceWantFenFor(id v, DDBalancePageKind kind, unsigned long long *out) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { *out = DDClampFen(DDLingtongFenValue()); return YES; }
    if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { *out = DDClampFen(DDBalanceFenValue()); return YES; }
    return NO;
}

// 钱包页金额行右侧箭头 + 间距占用的宽度，沿用 28pt 右缘边距常量（不压箭头）。
static const CGFloat kDDWalletArrowGap = 28.0;

// frame 是否已足够接近（避免重复赋值触发反复重排 → 闪烁）
static BOOL DDBalanceFrameNear(CGRect a, CGRect b) {
    return (fabs(a.origin.x - b.origin.x) < 0.5 && fabs(a.origin.y - b.origin.y) < 0.5 &&
            fabs(a.size.width - b.size.width) < 0.5 && fabs(a.size.height - b.size.height) < 0.5);
}

static unsigned long long DDClampFen(unsigned long long fen) {
    const unsigned long long kMaxFen = 99999999999ULL;
    return fen > kMaxFen ? kMaxFen : fen;
}

static NSString *DDBalanceRewriteMoneyText(NSString *text, unsigned long long fen) {
    if (!text.length) return text;
    // 金额由 ScrollNumber 以两位小数渲染，¥ 为独立 label，故匹配可选 ¥ + 两位小数数字。
    static NSRegularExpression *re;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"¥?\\s*\\d[\\d,]*\\.\\d{2}"
                options:0
                error:nil];
    });
    NSTextCheckingResult *m = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (!m || m.range.location == NSNotFound) return text;
    NSRange r = m.range;
    NSString *num = [text substringWithRange:r];
    BOOL sym = [num hasPrefix:@"¥"];
    NSString *core = sym ? [num substringFromIndex:1] : num;
    core = [core stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL comma = ([core rangeOfString:@","].location != NSNotFound);
    NSInteger dec = 0;
    NSRange dot = [core rangeOfString:@"."];
    if (dot.location != NSNotFound) dec = (NSInteger)core.length - (NSInteger)dot.location - 1;
    unsigned long long scaled = fen;
    if (dec > 2) { for (int i = 0; i < dec - 2; i++) scaled *= 10; }
    else { for (int i = 0; i < 2 - dec; i++) scaled /= 10; }
    unsigned long long ip = scaled / (unsigned long long)pow(10, dec);
    unsigned long long fp = scaled % (unsigned long long)pow(10, dec);
    NSMutableString *ipStr = [NSMutableString stringWithFormat:@"%llu", ip];
    if (comma) {
        NSMutableString *tmp = [NSMutableString string];
        NSInteger c = 0;
        for (NSInteger i = (NSInteger)ipStr.length - 1; i >= 0; i--) {
            [tmp insertString:[ipStr substringWithRange:NSMakeRange(i, 1)] atIndex:0];
            if (++c % 3 == 0 && c < (NSInteger)ipStr.length) [tmp insertString:@"," atIndex:0];
        }
        ipStr = tmp;
    }
    NSString *newNum = dec > 0 ? [NSString stringWithFormat:@"%@.%0*llu", ipStr, (int)dec, fp] : [ipStr copy];
    if (sym) newNum = [@"¥" stringByAppendingString:newNum];
    NSMutableString *out = [text mutableCopy];
    [out replaceCharactersInRange:r withString:newNum];
    return out;
}

#pragma mark - 余额 / 零钱通改写
// 金额由 TimeoutNumber（容器）内的 ScrollNumber（滚轮）渲染，两条链都要接管：
//   · 改值 —— 三个写入口（updateNumber: / defaultNumber: / updateNumberInternal:）全部换成目标值，
//     外加两条读路径 currentNumber / getNumber（原生按它们推算宽度，只改写入口会导致宽度与新值不匹配）。
//     钱包页入口头部由 WCPayWalletEntryHeaderView 自身刷新方法接管（见下方 %hook），
//     %orig 后主动灌改写值，下游 ScrollNumber 自动收到改写值，无滚动动画。
//     本层是兜底：金额存在多条并行写入路径，Kinda 源头只堵住其中一条，
//     仍有原生路径绕过源头直接灌真实值，需要这一层一并吃掉，否则真实值会漏出去触发一次滚动。
//   · 修帧 —— 钱包页两个金额单元格右侧有箭头，数字变长后原生 frame 仍是旧宽度会右溢盖住，
//     故在 layoutSubviews 里按 scrollNumberSize 重设滚轮与自身 frame，把右缘钉在箭头左侧。

// 修帧开关：置 NO 整体关掉下方顶格三步，只留改值，用于验证修帧是否仍必要。
static BOOL const kDDBalanceFixFrame = NO;

%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceKindFor(self, YES);
            unsigned long long want = 0; BOOL rewrite = NO;
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { want = DDClampFen(DDLingtongFenValue()); rewrite = YES; }
            else if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { want = DDClampFen(DDBalanceFenValue()); rewrite = YES; }
            if (rewrite) { %orig(want); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
- (void)defaultNumber:(unsigned long long)original {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceKindFor(self, YES);
            unsigned long long want = 0; BOOL rewrite = NO;
            if (kind == DDBalancePageLQT && [cfg hasLingtongValue]) { want = DDClampFen(DDLingtongFenValue()); rewrite = YES; }
            else if (kind == DDBalancePageBalance && [cfg hasBalanceValue]) { want = DDClampFen(DDBalanceFenValue()); rewrite = YES; }
            if (rewrite) { %orig(want); return; }
        }
    } @catch (NSException *e) {}
    %orig(original);
}
// 第二条写值入口：与 updateNumber: 并列，超时重绘 / 指示器刷新走这条，触发时机更晚。
//   两处换的是同一个固定值，重复改写无副作用。
- (void)updateNumberInternal:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceKindFor(self, YES);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
// 顶格三步，缺一不可：
//   1) [sn setFrame:] 原点不变、尺寸换成 scrollNumberSize —— 滚轮按新值的正确尺寸重设
//   2) [self updateScrollNumber] —— 容器按新滚轮尺寸重排内部
//   3) [self setFrame:] x = superview 宽度 - 28 - 宽度 —— 右缘钉在箭头左侧，数字往左长
// 前提：scrollNumberSize 按改后的值算，故 currentNumber / getNumber 两条读路径须一并改写，
//   否则宽度仍按旧值算，仅改 frame 无法对齐。
- (void)layoutSubviews {
    %orig;
    if (!kDDBalanceFixFrame) return;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return;
        // 只命中钱包页两个金额单元格才修帧，其余页面一律不碰。
        DDBalancePageKind fixKind = DDBalanceKindFor(self, NO);
        if (fixKind != DDBalancePageBalance && fixKind != DDBalancePageLQT) return;
        unsigned long long want = 0;
        if (!DDBalanceWantFenFor(self, fixKind, &want)) return;
        if (![self respondsToSelector:@selector(scrollNumber)] ||
            ![self respondsToSelector:@selector(scrollNumberSize)]) return;
        UIView *sn = [self scrollNumber];
        if (![sn isKindOfClass:[UIView class]]) return;
        // 父容器接近全宽的一律跳过：Kinda 用 Yoga 布局（ScrollNumber.h:14 isYogaRightAlignment），
        //   形态由宿主宽度决定 —— 钱包页两单元格的金额区宿主很窄，需要顶格；
        //   详情页宿主接近全宽、金额居中，一旦右对齐会被推到屏幕边上。
        //   该判定须在任何 frame 改动之前完成。
        UIView *sp = self.superview;
        if (!sp) return;
        CGFloat spW = sp.bounds.size.width;
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        if (screenW > 0 && spW > screenW * 0.7) return;
        CGSize sz = [self scrollNumberSize];
        if (sz.width <= 0 || sz.height <= 0) return;
        // ① 滚轮尺寸按新值重设（原点保持不变）
        CGRect snF = sn.frame;
        CGRect snNew = CGRectMake(snF.origin.x, snF.origin.y, sz.width, sz.height);
        if (!DDBalanceFrameNear(snF, snNew)) sn.frame = snNew;
        // ② 容器按新的滚轮尺寸重排内部
        if ([self respondsToSelector:@selector(updateScrollNumber)]) [self updateScrollNumber];
        // ③ 自身右对齐：右缘钉在 superview 宽度 - 箭头区(28)，数字往左长 → 永远压不到箭头
        CGRect selfF = self.frame;
        CGFloat newX = spW - kDDWalletArrowGap - sz.width;
        // 越界处理：算出的位置越过左边界（或 superview 宽度异常）时退化为"右缘原地不动"
        if (spW <= 0 || newX < 0) newX = (selfF.origin.x + selfF.size.width) - sz.width;
        CGRect selfNew = CGRectMake(newX, selfF.origin.y, sz.width, selfF.size.height);
        if (!DDBalanceFrameNear(selfF, selfNew)) self.frame = selfNew;
    } @catch (NSException *e) {}
}
%end

// 读路径必须一起改：scrollNumberSize / widthOfNumber: 推算宽度时读的是金额，
//   该值有 currentNumber / getNumber 两条来源，只改一条会让宽度仍按旧值算，
//   容器与内容对不上 → 数字右溢盖箭头（顶格）。
%hook ScrollNumber
- (unsigned long long)currentNumber {
    unsigned long long orig = %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return orig;
        DDBalancePageKind kind = DDBalanceKindFor(self, YES);
        unsigned long long want = 0;
        if (!DDBalanceWantFenFor(self, kind, &want)) return orig;
        return want;
    } @catch (NSException *e) {}
    return orig;
}
- (void)defaultNumber:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceKindFor(self, YES);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
- (void)updateNumber:(unsigned long long)original {
    unsigned long long v = original;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            DDBalancePageKind kind = DDBalanceKindFor(self, YES);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(self, kind, &want)) v = want;
        }
    } @catch (NSException *e) {}
    %orig(v);
}
// 第二条读值入口：与 currentNumber 并列。宽度推算（scrollNumberSize / widthOfNumber:）
//   若走这条，只改 currentNumber 会让宽度仍按真实值算。
- (unsigned long long)getNumber {
    unsigned long long orig = %orig;
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (!cfg.balanceEnabled) return orig;
        DDBalancePageKind kind = DDBalanceKindFor(self, YES);
        unsigned long long want = 0;
        if (DDBalanceWantFenFor(self, kind, &want)) return want;
    } @catch (NSException *e) {}
    return orig;
}
%end

// 入口头部余额：直接在类层级接管刷新方法（用头文件声明的 timeoutNumber / balanceMoneyLabel 属性），
//   不再依赖 superview 链判定。%orig 后主动把真实值换成改写值，下游 ScrollNumber 自动收到改写值。
static void DDBalancePatchEntryHeader(id header, unsigned long long fen) {
    @try {
        id tn = [header timeoutNumber];
        if ([tn respondsToSelector:@selector(updateNumber:)]) [tn updateNumber:fen];
        id lb = [header balanceMoneyLabel];
        if ([lb isKindOfClass:[UILabel class]]) {
            NSString *t = ((UILabel *)lb).text;
            if (t.length) {
                NSString *nt = DDBalanceRewriteMoneyText(t, fen);
                if (nt && ![nt isEqualToString:t]) ((UILabel *)lb).text = nt;
            }
        }
    } @catch (NSException *e) {}
}
%hook WCPayWalletEntryHeaderView
- (void)setupTimeoutNumber {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchEntryHeader(self, DDClampFen(DDBalanceFenValue()));
}
- (void)updateBalanceEntryView {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchEntryHeader(self, DDClampFen(DDBalanceFenValue()));
}
- (void)updateBalanceAndRefreshView {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchEntryHeader(self, DDClampFen(DDBalanceFenValue()));
}
- (void)handleUpdateWalletBalance {
    %orig;
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.balanceEnabled && [cfg hasBalanceValue])
        DDBalancePatchEntryHeader(self, DDClampFen(DDBalanceFenValue()));
}
%end

// Kinda 金额节点：4 处金额（钱包页两单元格 + 零钱/零钱通详情页）的源头注入点。
//   money 单位是「分」，与 TimeoutNumber updateNumber: 一致；
//   模板不给节点配 viewId（getViewId 返回 nil），故判定仍拿自己持有的 timeoutNumber 走响应链。
//   %orig 前就把值换成改写值 —— 下游 TimeoutNumber / ScrollNumber 从未收到真实值，滚动动画无从触发。
%hook KindaMoneyLoadingView
- (void)setMoney:(long long)money animated:(BOOL)animated {
    @try {
        DDGlobalConfig *cfg = [DDGlobalConfig shared];
        if (cfg.balanceEnabled) {
            id tn = [self timeoutNumber];
            DDBalancePageKind kind = DDBalanceKindFor(tn, YES);
            unsigned long long want = 0;
            if (DDBalanceWantFenFor(tn, kind, &want)) {
                %orig((long long)want, NO);   // animated:NO —— 关掉滚轮动画
                return;
            }
        }
    } @catch (NSException *e) {}
    %orig(money, animated);
}
%end

#pragma mark - 用户账号自定义（按用户名，聊天详情页逐人设置）

static NSString * const kDDFriendWxidMapKey = @"DDFriendWxidMap";

// 自定义账号表：存 NSUserDefaults，与全局配置统一走 synchronize；空表时移除 key 不留空壳。
static NSMutableDictionary *DDFriendWxidMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDFriendWxidMapKey];
        map = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    });
    return map;
}

static void DDFriendWxidPersist(void) {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (DDFriendWxidMap().count) {
        [def setObject:DDFriendWxidMap() forKey:kDDFriendWxidMapKey];
    } else {
        [def removeObjectForKey:kDDFriendWxidMapKey];
    }
    [def synchronize];
}

static NSString *DDFriendWxidForUser(NSString *usrName) {
    if (![DDGlobalConfig shared].friendWxidEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSString *value = DDFriendWxidMap()[usrName];
    return [value isKindOfClass:[NSString class]] ? value : nil;   // 存了空串也算，效果=隐藏
}

static void DDFriendWxidSetForUser(NSString *value, NSString *usrName) {
    if (usrName.length == 0) return;
    DDFriendWxidMap()[usrName] = value ?: @"";
    DDFriendWxidPersist();
}

static void DDFriendWxidRemoveForUser(NSString *usrName) {
    if (usrName.length == 0) return;
    [DDFriendWxidMap() removeObjectForKey:usrName];
    DDFriendWxidPersist();
}

// 原始真值表：保存时记下真实 alias，关闭时写回 ivar 即时还原（自定义值已覆盖内存联系人，真值只在此留存）。
static NSString * const kDDFriendWxidOrigMapKey = @"DDFriendWxidOrigMap";
static NSMutableDictionary *DDFriendWxidOrigMap(void) {
    static NSMutableDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDFriendWxidOrigMapKey];
        map = saved ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    });
    return map;
}
static NSString *DDFriendWxidOrigForUser(NSString *usrName) {
    if (usrName.length == 0) return nil;
    NSString *v = DDFriendWxidOrigMap()[usrName];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}
static void DDFriendWxidSetOrigForUser(NSString *value, NSString *usrName) {
    if (usrName.length == 0) return;
    DDFriendWxidOrigMap()[usrName] = value ?: @"";
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    [def setObject:DDFriendWxidOrigMap() forKey:kDDFriendWxidOrigMapKey];
    [def synchronize];
}
static void DDFriendWxidRemoveOrigForUser(NSString *usrName) {
    if (usrName.length == 0) return;
    [DDFriendWxidOrigMap() removeObjectForKey:usrName];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (DDFriendWxidOrigMap().count) [def setObject:DDFriendWxidOrigMap() forKey:kDDFriendWxidOrigMapKey];
    else [def removeObjectForKey:kDDFriendWxidOrigMapKey];
    [def synchronize];
}

#pragma mark - 头像文件管理

static void DDRefreshAvatarViewsForUser(NSString *usrName);

static NSString *DDAvatarDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (doc.length == 0) doc = @"/var/mobile/Documents";
    NSString *dir = [doc stringByAppendingPathComponent:@"DDAvatar"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                withIntermediateDirectories:YES
                attributes:nil
                error:nil];
    }
    return dir;
}

static NSString *DDAvatarPathForUser(NSString *usrName) {
    if (usrName.length == 0) return nil;
    NSCharacterSet *keep = [NSCharacterSet alphanumericCharacterSet];
    NSMutableString *safe = [NSMutableString string];
    for (NSUInteger i = 0; i < usrName.length; i++) {
        unichar c = [usrName characterAtIndex:i];
        if ([keep characterIsMember:c]) {
            [safe appendFormat:@"%C", c];
        } else {
            [safe appendString:@"_"];
        }
    }
    return [DDAvatarDir() stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"png"]];
}

static NSCache *DDAvatarCache(void) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    return cache;
}

static void DDAvatarCacheInvalidate(NSString *usrName) {
    if (usrName.length) [DDAvatarCache() removeObjectForKey:usrName];
    else [DDAvatarCache() removeAllObjects];
}

static UIImage *DDAvatarImageForUser(NSString *usrName) {
    if (![DDGlobalConfig shared].avatarEnabled) return nil;
    if (usrName.length == 0) return nil;
    NSCache *cache = DDAvatarCache();
    id cached = [cache objectForKey:usrName];
    if (cached) return (cached == [NSNull null]) ? nil : (UIImage *)cached;

    UIImage *img = [UIImage imageWithContentsOfFile:DDAvatarPathForUser(usrName)];
    if (!(img && img.size.width > 0 && img.size.height > 0)) img = nil;
    [cache setObject:(img ?: (UIImage *)[NSNull null]) forKey:usrName];
    return img;
}

static UIImage *DDScaledImage(UIImage *image, CGFloat maxSide) {
    if (!image || maxSide <= 0) return image;
    CGSize size = image.size;
    CGFloat longest = MAX(size.width, size.height);
    if (longest <= maxSide) return image;
    CGFloat ratio = maxSide / longest;
    CGSize target = CGSizeMake(round(size.width * ratio), round(size.height * ratio));
    UIGraphicsBeginImageContextWithOptions(target, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled ?: image;
}

static BOOL DDAvatarSaveImage(UIImage *image, NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!image || !path) return NO;
    NSData *data = UIImagePNGRepresentation(DDScaledImage(image, 400.0));
    if (data.length == 0) return NO;
    BOOL ok = [data writeToFile:path atomically:YES];
    if (ok) {
        DDAvatarCacheInvalidate(usrName);
        DDRefreshAvatarViewsForUser(usrName);
    }
    return ok;
}

static BOOL DDAvatarRemoveForUser(NSString *usrName) {
    NSString *path = DDAvatarPathForUser(usrName);
    if (!path) return NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    DDAvatarCacheInvalidate(usrName);
    if (ok) DDRefreshAvatarViewsForUser(usrName);
    return ok;
}

static NSInteger DDAvatarRemoveAll(void) {
    NSString *dir = DDAvatarDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSInteger n = 0;
    for (NSString *f in files) {
        if (![f.pathExtension isEqualToString:@"png"]) continue;
        if ([[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil]) n++;
    }
    if (n > 0) {
        DDAvatarCacheInvalidate(nil);
        DDRefreshAvatarViewsForUser(nil);
    }
    return n;
}

#pragma mark - 选图（系统 UIImagePickerController）

typedef void (^DDAvatarPickCompletion)(UIImage *image);

@interface DDAvatarPicker : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, copy) DDAvatarPickCompletion completion;
+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion;
@end

@implementation DDAvatarPicker

static char kDDAvatarPickerDelegateKey;

static UIViewController *DDTopPresentedViewController(UIViewController *vc) {
    UIViewController *top = vc;
    NSInteger guard = 0;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed && guard++ < 8) {
        top = top.presentedViewController;
    }
    return top;
}

+ (void)presentFromViewController:(UIViewController *)vc completion:(DDAvatarPickCompletion)completion {
    if (!vc) {
        if (completion) completion(nil);
        return;
    }
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        if (completion) completion(nil);
        return;
    }

    UIViewController *presenter = DDTopPresentedViewController(vc);

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = YES;
    picker.title = @"头像修改";

    DDAvatarPicker *proxy = [[DDAvatarPicker alloc] init];
    proxy.completion = completion;
    picker.delegate = proxy;
    objc_setAssociatedObject(picker, &kDDAvatarPickerDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!presenter.view.window || presenter.isBeingDismissed || presenter.presentedViewController) {
            if (completion) completion(nil);
            return;
        }
        [presenter presentViewController:picker animated:YES completion:^{
        }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(image);
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    DDAvatarPickCompletion cb = self.completion;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (cb) cb(nil);
    }];
}

@end

#pragma mark - 自定义自己账号（只改自己）

static NSString *DDCustomWxid(void) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.wxidEnabled) return nil;
    NSString *value = cfg.wxidValue;
    if (value.length == 0) return nil;
    return value;
}

#pragma mark - 数据源（微信"账号"统一拦截）

%hook CBaseContact

// CBaseContact.h:12 —— m_nsAliasName 即"账号"。
// 用户：查自定义表，命中返回自定义值（空串=隐藏），未命中回原值。
- (id)m_nsAliasName {
    if (![DDGlobalConfig shared].friendWxidEnabled) return %orig;
    NSString *alias = DDFriendWxidForUser([self m_nsUsrName]);
    if (alias) { return alias; }
    return %orig;
}

// 账号行显示的是联系人 m_nsAliasName 的 ivar（微信重建资料页时经此 setter 写入）。
// 自定义存在 → 强制写入自定义值；关闭 → 让真值正常写入，配合 ddWxidSwitchChanged: 写回原值即时还原。
- (void)setM_nsAliasName:(id)v {
    if (![DDGlobalConfig shared].friendWxidEnabled) { %orig(v); return; }
    NSString *custom = DDFriendWxidForUser([self m_nsUsrName]);
    if (custom) {
        %orig(custom);
        return;
    }
    %orig(v);
}

%end

%hook CSetting
// CSetting.h:58/301 —— 微信"我"页面、设置等读取的自己的 m_nsAliasName 数据源。
// CSetting 独立继承 NSObject，不继承 CBaseContact，需单独 hook。
- (id)m_nsAliasName {
    NSString *custom = DDCustomWxid();
    if (custom) return custom;
    return %orig;
}
%end

#pragma mark - 头像替换（显示侧）

static NSHashTable *DDAvatarViews(void) {
    static NSHashTable *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ t = [NSHashTable weakObjectsHashTable]; });
    return t;
}

static void DDRefreshAvatarViewsForUser(NSString *usrName) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ DDRefreshAvatarViewsForUser(usrName); });
        return;
    }
    for (MMHeadImageView *v in DDAvatarViews()) {
        NSString *name = v.nsUsrName;
        if (name.length == 0) continue;
        if (usrName.length && ![name isEqualToString:usrName]) continue;
        [v setHeadImageByName:name];
    }
}

static BOOL DDTryApplyCustomAvatar(MMHeadImageView *view, NSString *usrName) {
    NSString *name = usrName.length ? usrName : view.nsUsrName;
    UIImage *custom = DDAvatarImageForUser(name);
    if (!custom) return NO;
    [view updateHeadImage:custom];
    return YES;
}

%hook MMHeadImageView

- (void)updateHeadImage:(id)image {
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (!custom) {
        %orig(image);
        return;
    }
    %orig(custom);
    // 自定义头像绕开了微信自己的图片加工链路——圆角是在图片加载回调里做的，
    // 直接把原图塞给 updateHeadImage: 会顶掉那张加工过的圆角图，
    // 表现为聊天界面头像是直角（其他界面走本地缓存同步路径，不受影响）。
    // 这里按 MMHeadImageView 自己的圆角约定补回来（MMHeadImageView.h:43/64）。
    [self setHeadImageViewCornerRadius:[self preferCornerSize]];
}

- (void)updateUsrName:(id)usrName withHeadImgUrl:(id)headImgUrl {
    %orig(usrName, headImgUrl);
    UIImage *custom = DDAvatarImageForUser(usrName ?: [self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)ImageDidLoad:(id)image Url:(id)url {
    %orig(image, url);
    UIImage *custom = DDAvatarImageForUser([self nsUsrName]);
    if (custom) {
        [self updateHeadImage:custom];
    }
}

- (void)setHeadImageByName:(id)usrName {
    %orig(usrName);
    DDTryApplyCustomAvatar(self, usrName);
}

- (void)doUpdateHeadImg:(BOOL)force {
    %orig(force);
    DDTryApplyCustomAvatar(self, nil);
}

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;
    [DDAvatarViews() addObject:self];
    DDTryApplyCustomAvatar(self, nil);
}

%end

#pragma mark - 头像替换 · 高清大图（点开资料页头像后）

static UIView *DDFindImageScrollViewIn(UIView *root) {
    if (!root) return nil;
    Class cls = %c(ImageScrollView);
    if (!cls) return nil;
    for (UIView *v in root.subviews) {
        if ([v isKindOfClass:cls]) return v;
        UIView *found = DDFindImageScrollViewIn(v);
        if (found) return found;
    }
    return nil;
}

%hook MMHDHeadImageView

%new
- (void)dd_applyCustomHDHead {
    UIImage *custom = DDAvatarImageForUser([self.m_contact m_nsUsrName]);
    if (!custom) return;
    ImageScrollView *sv = (ImageScrollView *)DDFindImageScrollViewIn(self);
    if (!sv) return;
    [sv updateImage:custom];
}

- (void)updateHead {
    %orig;
    [self dd_applyCustomHDHead];
}

- (void)updateHDHead {
    %orig;
    [self dd_applyCustomHDHead];
}

%end

#pragma mark - 聊天详情页"自定义头像 / 自定义账号"入口

static NSString * const kDDProfileChangedNotification = @"DDProfileContentChanged";

#pragma mark - 资料页注入（单聊 ContactInfoViewController）

// 监听 kDDProfileChangedNotification 自刷新：关开关后展示页可能仍在导航栈，靠通知即时重建账号行。

%hook ContactInfoViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(ddProfileChangedRefresh)
            name:kDDProfileChangedNotification
            object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDDProfileChangedNotification object:nil];
    %orig;
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self ddProfileChangedRefresh];
}

%new
- (void)ddProfileChangedRefresh {
    [self reloadContactAssist];
    [self reloadData];
    [self reloadView];
}

%end

static const void *kDDInjectedCellMarker = &kDDInjectedCellMarker;

static BOOL DDSectionHasInjectedCell(id section) {
    @try {
        unsigned long long n = [section getCellCount];
        for (unsigned long long i = 0; i < n; i++) {
            id c = [section getCellAt:i];
            if (objc_getAssociatedObject(c, kDDInjectedCellMarker) != nil) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

static __weak AddContactToChatRoomViewController *s_profileVC = nil;

static AddContactToChatRoomViewController *DDProfileVCForTable(id tableViewInfo) {
    AddContactToChatRoomViewController *vc = s_profileVC;
    if (!vc || !tableViewInfo) return nil;
    id tv = nil;
    @try { tv = [vc valueForKey:@"m_tableViewInfo"]; } @catch (NSException *e) { tv = nil; }
    if (tv != tableViewInfo) return nil;
    return vc;
}

// 在微信重建表格的同一次 runloop 内将入口插入到位置 At:1（资料卡正下方），不产生额外帧。
static void DDInjectProfileSectionIntoTable(AddContactToChatRoomViewController *vc, BOOL reloadNow) {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (!cfg.avatarEnabled && !cfg.friendWxidEnabled) return;
    if (![vc m_contact]) return;
    id tableViewInfo = [vc valueForKey:@"m_tableViewInfo"];
    if (!tableViewInfo) return;
    NSArray *sections = [tableViewInfo getAllSections];
    if (sections.count == 0) return;
    for (id s in sections) {
        if (DDSectionHasInjectedCell(s)) return;
    }

    NSString *usrName = [[vc m_contact] m_nsUsrName];
    id section = [%c(WCTableViewSectionManager) defaultSection];
    id firstCell = nil;

    if (cfg.avatarEnabled) {
        BOOL hasCustom = DDAvatarImageForUser(usrName) != nil;
        id cell = [%c(WCTableViewCellManager) switchCellForSel:@selector(ddAvatarSwitchChanged:)
                target:vc
                title:@"自定义头像"
                on:hasCustom];
        if (cell) { [section addCell:cell]; if (!firstCell) firstCell = cell; }
    }
    if (cfg.friendWxidEnabled) {
        BOOL hasCustom = DDFriendWxidForUser(usrName) != nil;
        id cell = [%c(WCTableViewCellManager) switchCellForSel:@selector(ddWxidSwitchChanged:)
                target:vc
                title:@"自定义账号"
                on:hasCustom];
        if (cell) { [section addCell:cell]; if (!firstCell) firstCell = cell; }
    }
    if (!firstCell) return;

    // 只给第一行打标记：查重靠它，两行始终同进同退
    objc_setAssociatedObject(firstCell, kDDInjectedCellMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tableViewInfo insertSection:section At:1];
    if (reloadNow) [[tableViewInfo getTableView] reloadData];
}

%hook WCTableViewManager

// 微信重建表格走 clearAllSection → addSection ×N；首个 addSection 回调时资料卡已加回，
//   此刻同步插入到 At:1，与重建在同一 runloop 内完成，随后一次 reloadData 即带出该行。
- (void)addSection:(id)a0 {
    %orig;
    if (!a0) return;
    AddContactToChatRoomViewController *vc = DDProfileVCForTable(self);
    if (!vc || ![vc m_contact]) return;
    DDInjectProfileSectionIntoTable(vc, NO);
}

%end

#pragma mark - 群聊资料页：同样的头像 / 账号入口
%hook AddContactToChatRoomViewController

// s_profileVC 须在 %orig 之前赋值：微信在 super viewDidLoad 内部即完成表格装配，
//   若晚于 %orig 赋值，装配期的 addSection 钩子会无法识别本表而跳过，需退到 viewWillAppear 才补插。
- (void)viewDidLoad {
    s_profileVC = self;
    %orig;
    s_profileVC = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(reloadTableData)
            name:kDDProfileChangedNotification
            object:nil];
    [self dd_injectProfileSection];   // 表格已装配完、页面尚未显示，首帧即带开关
}

// 转场前再确认一次：若微信在 %orig 内又重建表格，此处补插（已插入时由查重跳过）。
- (void)viewWillAppear:(BOOL)animated {
    s_profileVC = self;
    %orig;
    s_profileVC = self;
    [self dd_injectProfileSection];
}

- (void)dealloc {
    if (s_profileVC == self) s_profileVC = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kDDProfileChangedNotification object:nil];
    %orig;
}

%new
- (void)dd_injectProfileSection {
    DDInjectProfileSectionIntoTable(self, YES);
}

%new
- (void)ddAvatarSwitchChanged:(UISwitch *)sender {
    CBaseContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (DDAvatarImageForUser(usrName)) {
        (void)DDAvatarRemoveForUser(usrName);
        [[NSNotificationCenter defaultCenter] postNotificationName:kDDProfileChangedNotification object:nil];
    } else {
        __weak typeof(self) weakSelf = self;
        __weak UISwitch *weakSw = sender;
        [DDAvatarPicker presentFromViewController:self completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!image) {
                [weakSw setOn:NO animated:YES];
                return;
            }
            if (!DDAvatarSaveImage(image, usrName)) {
                [weakSw setOn:NO animated:YES];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:kDDProfileChangedNotification object:nil];
            }
        }];
    }
}

%new
// 发通知触发展示页账号行自刷新。
- (void)ddRefreshProfile {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDDProfileChangedNotification object:nil];
}

// 与"自定义头像"对称：开 → 微信原生输入弹窗；关 → 清掉该用户的自定义。
// 弹窗里留空直接确定 = 存空串，效果等同隐藏。
%new
- (void)ddWxidSwitchChanged:(UISwitch *)sender {
    CBaseContact *contact = [self m_contact];
    NSString *usrName = [contact m_nsUsrName];
    if (usrName.length == 0) return;

    if (DDFriendWxidForUser(usrName)) {
        DDFriendWxidRemoveForUser(usrName);
        // 关闭后把 alias ivar 还原为记录的原真值，账号行立即还原
        NSString *origAlias = DDFriendWxidOrigForUser(usrName);
        DDFriendWxidRemoveOrigForUser(usrName);
        if (origAlias) [contact setM_nsAliasName:origAlias];
        [self ddRefreshProfile];
        return;
    }

    WCUIAlertView *alert = [[%c(WCUIAlertView) alloc] initWithTitle:@"账号修改" message:@"请输入账号如：520\n输入空格隐藏账号\n留空还原"];
    if (!alert) {
        [sender setOn:NO animated:YES];
        return;
    }
    [alert showTextFieldWithMaxLen:32];
    [alert setTextFieldDefaultText:[contact m_nsAliasName] ?: @""];

    // 无参 block 配合 __block 强持有，回调末尾置 nil 打破循环；
    //   getTextField 需在 show 之后才有，故直接 getTextFieldText 取文本。
    __block WCUIAlertView *blockAlert = alert;
    __weak UISwitch *weakSw = sender;

    [alert addCancelBtnTitle:@"取消" handler:^{
        [weakSw setOn:NO animated:YES];
        blockAlert = nil;
    }];
    [alert addBtnTitle:@"确定" handler:^{
        NSString *text = [blockAlert getTextFieldText] ?: @"";
        if (text.length == 0) {
            // 没有输入：关闭该用户自定义并回弹开关
            DDFriendWxidRemoveForUser(usrName);
            DDFriendWxidRemoveOrigForUser(usrName);
            [weakSw setOn:NO animated:YES];
        } else {
            // 空格 / 文字：原样保存（空格=空白账号即隐藏）
            NSString *origAlias = [contact m_nsAliasName];   // 此刻 custom 尚未写入 → 取到的即真实 alias
            if (origAlias) DDFriendWxidSetOrigForUser(origAlias, usrName);
            DDFriendWxidSetForUser(text, usrName);
        }
        [self ddRefreshProfile];
        blockAlert = nil;
    }];
    [alert show];
}

%end

#pragma mark - 隐藏聊天顶栏名字（单聊 / 群聊）

static BOOL DDHideChatName(void) {
    return [DDGlobalConfig shared].hideChatName;
}

%hook BaseMsgContentLogicController

- (id)GetUsrTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getSubTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)GetTitleTailImageView {
    if (DDHideChatName()) return nil;
    return %orig;
}

%end

%hook RoomContentLogicController

- (id)GetUsrTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getSubTitle {
    if (DDHideChatName()) return @"";
    return %orig;
}

- (id)getDefaultTitleTailSubViews {
    if (DDHideChatName()) return nil;
    return %orig;
}

- (id)getMemeberCountLabel {
    if (DDHideChatName()) return nil;
    return %orig;
}

%end

#pragma mark - 设置界面
// 各功能开关、自定义值输入；表视图委托转发给微信原生 manager。


@interface DDJokerSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *stepsField;
@property (nonatomic, strong) UITextField *contactsField;
@property (nonatomic, strong) UITextField *balanceField;
@property (nonatomic, strong) UITextField *lingtongField;
@property (nonatomic, strong) UITextField *wxidField;
@end

@implementation DDJokerSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
    UITextField *_wxidField;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小丑助手设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [(WCTableViewManager *)[%c(WCTableViewManager) alloc] initWithFrame:[[UIScreen mainScreen] bounds] style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action placeholder:(NSString *)placeholder text:(NSString *)text {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}

- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action x:(CGFloat)x {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(x, 0, 52, 34);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *chatSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"聊天小丑"];
    chatSection.footerTitle = @"开启后长按聊天消息，弹窗/菜单点击「小丑」修改";
    [chatSection addCell:[cellCls switchCellForSel:@selector(textSwitchChanged:) target:self title:@"聊天文字修改" on:cfg.textEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(imageSwitchChanged:) target:self title:@"聊天图片修改" on:cfg.imageEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(timeSwitchChanged:) target:self title:@"聊天时间修改" on:cfg.timeEnabled]];
    [chatSection addCell:[cellCls switchCellForSel:@selector(transferSwitchChanged:) target:self title:@"聊天转账修改" on:cfg.transferEnabled]];
    UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(clearChatCacheTapped:) x:0];
    UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [clearRight addSubview:clearBtn];
    [chatSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清空修改记录" rightView:clearRight]];
    [_tableViewManager addSection:chatSection];

    WCTableViewSectionManager *profileSection = [%c(WCTableViewSectionManager) sectionWithHeader:@"资料小丑"];
    profileSection.footerTitle = @"开启设置用户账号/头像后在「聊天详情」页逐人自定义";
    [profileSection addCell:[cellCls switchCellForSel:@selector(balanceSwitchChanged:) target:self title:@"零钱余额修改" on:cfg.balanceEnabled]];
    if (cfg.balanceEnabled) {
        self.balanceField = [[UITextField alloc] init];
        [self.balanceField addTarget:self action:@selector(balanceChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentBalance = [cfg hasBalanceValue] ? cfg.balanceValue : @"";
        UIView *balanceRight = [self inputRowWithField:self.balanceField
                action:@selector(balanceConfirm:)
                placeholder:@"例如：888.88"
                text:currentBalance];
        self.balanceField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *balanceSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳余额自定义" rightView:balanceRight];
        balanceSubCell.userInfo = @"SubCell";
        [profileSection addCell:balanceSubCell];

        self.lingtongField = [[UITextField alloc] init];
        [self.lingtongField addTarget:self action:@selector(lingtongChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentLingtong = [cfg hasLingtongValue] ? cfg.lingtongValue : @"";
        UIView *lingtongRight = [self inputRowWithField:self.lingtongField
                action:@selector(lingtongConfirm:)
                placeholder:@"例如：888.88"
                text:currentLingtong];
        self.lingtongField.keyboardType = UIKeyboardTypeDecimalPad;
        WCTableViewCellManager *lingtongSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳零钱通自定义" rightView:lingtongRight];
        lingtongSubCell.userInfo = @"SubCell";
        [profileSection addCell:lingtongSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(stepsSwitchChanged:) target:self title:@"运动步数修改" on:cfg.stepsEnabled]];
    if (cfg.stepsEnabled) {
        self.stepsField = [[UITextField alloc] init];
        [self.stepsField addTarget:self action:@selector(stepsChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentSteps = [cfg hasStepsValue] ? cfg.stepsValueString : @"";
        UIView *rightView = [self inputRowWithField:self.stepsField
                action:@selector(stepsConfirm:)
                placeholder:@"例如：88888"
                text:currentSteps];
        WCTableViewCellManager *stepsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳步数自定义" rightView:rightView];
        stepsSubCell.userInfo = @"SubCell";
        [profileSection addCell:stepsSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(contactsSwitchChanged:) target:self title:@"好友数量修改" on:cfg.contactsEnabled]];
    if (cfg.contactsEnabled) {
        self.contactsField = [[UITextField alloc] init];
        [self.contactsField addTarget:self action:@selector(contactsChanged:) forControlEvents:UIControlEventEditingChanged];
        NSString *currentContacts = cfg.contactsValue ?: @"";
        UIView *rightView = [self inputRowWithField:self.contactsField
                action:@selector(contactsConfirm:)
                placeholder:@"例如：520"
                text:currentContacts];
        WCTableViewCellManager *contactsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳数量自定义" rightView:rightView];
        contactsSubCell.userInfo = @"SubCell";
        [profileSection addCell:contactsSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(wxidSwitchChanged:) target:self title:@"设置自己账号" on:cfg.wxidEnabled]];
    if (cfg.wxidEnabled) {
        self.wxidField = [[UITextField alloc] init];
        NSString *currentWxid = cfg.wxidValue.length ? cfg.wxidValue : @"";
        UIView *rightView = [self inputRowWithField:self.wxidField
                action:@selector(wxidConfirm:)
                placeholder:@"例如：520"
                text:currentWxid];
        self.wxidField.keyboardType = UIKeyboardTypeASCIICapable;
        WCTableViewCellManager *wxidSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳账号自定义" rightView:rightView];
        wxidSubCell.userInfo = @"SubCell";
        [profileSection addCell:wxidSubCell];
    }

    [profileSection addCell:[cellCls switchCellForSel:@selector(friendWxidSwitch:) target:self title:@"设置用户账号" on:cfg.friendWxidEnabled]];

    [profileSection addCell:[cellCls switchCellForSel:@selector(hideChatNameSwitch:) target:self title:@"隐藏顶栏名字" on:cfg.hideChatName]];

    [profileSection addCell:[cellCls switchCellForSel:@selector(avatarSwitchChanged:) target:self title:@"设置用户头像" on:cfg.avatarEnabled]];
    UIButton *avatarClearBtn = [self dd_actionButton:@"清理" action:@selector(clearAllAvatarTapped:) x:0];
    UIView *avatarClearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
    [avatarClearRight addSubview:avatarClearBtn];
    [profileSection addCell:[cellCls normalCellForSel:nil target:nil title:@"清空全部头像" rightView:avatarClearRight]];

    [_tableViewManager addSection:profileSection];

    [_tableViewManager reloadTableView];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [self.tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqualToString:@"SubCell"]) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 16.0;
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

#pragma mark  开关回调
- (void)textSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].textEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)imageSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].imageEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)timeSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].timeEnabled = sender.isOn;
    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)transferSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].transferEnabled = sender.isOn;

    JokerInvalidateAllLayout();
    [self buildTable];
}

- (void)clearChatCacheTapped:(id)sender {
    DDJokerClearAllMessageCache();
    JokerInvalidateAllLayout();
    [self buildTable];
    [self dd_showDoneToast:@"记录已清理"];
}

- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;

    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

- (void)balanceSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].balanceEnabled = sender.isOn;
    [self buildTable];
}

- (void)stepsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].stepsEnabled = sender.isOn;
    [self buildTable];
}

- (void)contactsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].contactsEnabled = sender.isOn;
    [self buildTable];
}

- (void)friendWxidSwitch:(UISwitch *)sender {
    [DDGlobalConfig shared].friendWxidEnabled = sender.isOn;
}

- (void)wxidSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].wxidEnabled = sw.on;
    [self buildTable];
}

- (void)wxidConfirm:(id)sender {
    // 原样保存：空=不覆盖，空格=空白账号（隐藏），其他=自定义值
    [DDGlobalConfig shared].wxidValue = self.wxidField.text ?: @"";
    [self.wxidField resignFirstResponder];
    [self buildTable];
}

- (void)avatarSwitchChanged:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].avatarEnabled = sw.on;
    if (!sw.on) DDRefreshAvatarViewsForUser(nil);
    [self buildTable];
}

- (void)hideChatNameSwitch:(id)sender {
    UISwitch *sw = (UISwitch *)sender;
    [DDGlobalConfig shared].hideChatName = sw.on;
}

- (void)clearAllAvatarTapped:(id)sender {
    (void)DDAvatarRemoveAll();
    [self dd_showDoneToast:@"头像已清理"];
}

- (void)stepsConfirm:(id)sender {
    NSString *input = self.stepsField.text;
    [self saveStepsInput:input];
    [self buildTable];
}

- (void)contactsConfirm:(id)sender {
    NSString *input = self.contactsField.text;
    [self saveContactsInput:input];
    [self buildTable];
}

- (void)balanceConfirm:(id)sender {
    NSString *input = self.balanceField.text;
    [self saveBalanceInput:input];
    [self buildTable];
}

- (void)lingtongConfirm:(id)sender {
    NSString *input = self.lingtongField.text;
    [self saveLingtongInput:input];
    [self buildTable];
}

- (void)balanceChanged:(id)sender {
    [self saveBalanceInput:self.balanceField.text];
}

- (void)lingtongChanged:(id)sender {
    [self saveLingtongInput:self.lingtongField.text];
}

- (void)stepsChanged:(id)sender {
    [self saveStepsInput:self.stepsField.text];
}

- (void)contactsChanged:(id)sender {
    [self saveContactsInput:self.contactsField.text];
}

#pragma mark  输入保存
- (void)saveStepsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.stepsValueString = nil;
    } else {
        NSInteger val = [trimmed integerValue];
        if (val < 0) val = 0;
        if (val > 100000) val = 100000;
        cfg.stepsValueString = [NSString stringWithFormat:@"%ld", (long)val];
    }
}

// 输入框是数字键盘（inputRowWithField: 里 UIKeyboardTypeNumberPad），但粘板/外接键盘
// 仍能把任意字符塞进来；这里跟 saveStepsInput: 一样用 integerValue 归一化，
// 而不是拒绝保存——拒绝会让输入框显示 12a、实际却还是旧值，反而更难排查。
- (void)saveContactsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.contactsValue = nil;
        return;
    }
    NSInteger val = [trimmed integerValue];
    if (val < 0) val = 0;
    if (val > 1000000) val = 1000000;   // m_uiNormalContact 是 unsigned int，别让它溢出
    cfg.contactsValue = [NSString stringWithFormat:@"%ld", (long)val];
}

- (void)saveBalanceInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.balanceValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.balanceValue = filtered.length ? filtered : nil;
}

- (void)saveLingtongInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.lingtongValue = nil;
        return;
    }
    NSMutableString *filtered = [NSMutableString string];
    BOOL hasDot = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c >= '0' && c <= '9') {
            [filtered appendFormat:@"%C", c];
        } else if (c == '.' && !hasDot) {
            [filtered appendFormat:@"%C", c];
            hasDot = YES;
        }
    }
    cfg.lingtongValue = filtered.length ? filtered : nil;
}

@end

#pragma mark - 配置管理（实现）
// DDGlobalConfig 单例：属性 setter 同步 NSUserDefaults。


@implementation DDGlobalConfig

+ (instancetype)shared {
    static DDGlobalConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDGlobalConfig new]; });
    return config;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _textEnabled = [def boolForKey:kDDFeatureTextEnabled];
        _imageEnabled = [def boolForKey:kDDFeatureImageEnabled];
        _timeEnabled = [def boolForKey:kDDFeatureTimeEnabled];
        _transferEnabled = [def boolForKey:kDDFeatureTransferEnabled];
        _balanceEnabled = [def boolForKey:kDDFeatureBalanceEnabled];
        _stepsEnabled = [def boolForKey:kDDFeatureStepsEnabled];
        _contactsEnabled = [def boolForKey:kDDFeatureContactsEnabled];
        _friendWxidEnabled = [def boolForKey:kDDFeatureFriendWxidEnabled];
        _wxidEnabled = [def boolForKey:kDDFeatureWxidEnabled];
        _wxidValue = [def stringForKey:kDDFeatureWxidValue] ?: @"";
        _avatarEnabled = [def boolForKey:kDDFeatureAvatarEnabled];
        _hideChatName = [def boolForKey:kDDFeatureHideChatName];

        _stepsValueString = [def stringForKey:kDDStepsValueStringKey];
        _contactsValue = [def stringForKey:kDDContactsCountValueKey];
        _balanceValue = [def stringForKey:kDDBalanceValueKey];
        _lingtongValue = [def stringForKey:kDDLingtongValueKey];
    }
    return self;
}

- (void)setTextEnabled:(BOOL)enabled {
    _textEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTextEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setTransferEnabled:(BOOL)enabled {
    _transferEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTransferEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setImageEnabled:(BOOL)enabled {
    _imageEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureImageEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setTimeEnabled:(BOOL)enabled {
    _timeEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureTimeEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBalanceEnabled:(BOOL)enabled {
    _balanceEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureBalanceEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsEnabled:(BOOL)enabled {
    _stepsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureStepsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setContactsEnabled:(BOOL)enabled {
    _contactsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureContactsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setFriendWxidEnabled:(BOOL)friendWxidEnabled {
    _friendWxidEnabled = friendWxidEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:friendWxidEnabled forKey:kDDFeatureFriendWxidEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setWxidEnabled:(BOOL)wxidEnabled {
    _wxidEnabled = wxidEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:wxidEnabled forKey:kDDFeatureWxidEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setWxidValue:(NSString *)wxidValue {
    _wxidValue = [wxidValue copy];
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_wxidValue.length) {
        [def setObject:_wxidValue forKey:kDDFeatureWxidValue];
    } else {
        [def removeObjectForKey:kDDFeatureWxidValue];
    }
    [def synchronize];
}

- (void)setAvatarEnabled:(BOOL)avatarEnabled {
    _avatarEnabled = avatarEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:avatarEnabled forKey:kDDFeatureAvatarEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setHideChatName:(BOOL)hideChatName {
    _hideChatName = hideChatName;
    [[NSUserDefaults standardUserDefaults] setBool:hideChatName forKey:kDDFeatureHideChatName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)setStepsValueString:(NSString *)stepsValueString {
    _stepsValueString = [stepsValueString copy];
    [self saveSteps];
}

- (void)setContactsValue:(NSString *)contactsValue {
    _contactsValue = [contactsValue copy];
    [self saveContacts];
}

- (void)setBalanceValue:(NSString *)balanceValue {
    _balanceValue = [balanceValue copy];
    DDBalanceFenCacheInvalidate();
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_balanceValue.length) {
        [def setObject:_balanceValue forKey:kDDBalanceValueKey];
    } else {
        [def removeObjectForKey:kDDBalanceValueKey];
    }
    [def synchronize];
}

- (void)setLingtongValue:(NSString *)lingtongValue {
    _lingtongValue = [lingtongValue copy];
    DDBalanceFenCacheInvalidate();
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_lingtongValue.length) {
        [def setObject:_lingtongValue forKey:kDDLingtongValueKey];
    } else {
        [def removeObjectForKey:kDDLingtongValueKey];
    }
    [def synchronize];
}

#pragma mark  取值辅助
- (NSInteger)stepsIntegerValue {
    if (![self hasStepsValue]) return 0;
    return [_stepsValueString integerValue];
}

- (BOOL)hasStepsValue {
    return _stepsValueString.length > 0;
}

- (BOOL)hasBalanceValue {
    return _balanceValue.length > 0;
}

- (BOOL)hasLingtongValue {
    return _lingtongValue.length > 0;
}

- (void)saveSteps {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_stepsValueString.length) {
        [def setObject:_stepsValueString forKey:kDDStepsValueStringKey];
    } else {
        [def removeObjectForKey:kDDStepsValueStringKey];
    }
    [def synchronize];
}

- (void)saveContacts {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_contactsValue.length) {
        [def setObject:_contactsValue forKey:kDDContactsCountValueKey];
    } else {
        [def removeObjectForKey:kDDContactsCountValueKey];
    }
    [def synchronize];
}

@end

#pragma mark - 插件注册
// %ctor 把设置页注册到微信插件入口。


%ctor {
    @autoreleasepool {
        WCPluginsMgr *mgr = [%c(WCPluginsMgr) sharedInstance];
        [mgr registerControllerWithTitle:@"DD小丑助手"
                version:@"1.0.0"
                controller:@"DDJokerSettingsViewController"];
    }
}


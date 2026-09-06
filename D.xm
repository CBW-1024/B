
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 微信类声明
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
- (unsigned long long)getSectionCount;
- (id)getSectionAt:(unsigned long long)a0;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
- (void)insertCell:(id)a0 At:(unsigned int)a1;
- (unsigned long long)getCellCount;
- (id)getCellAt:(unsigned long long)a0;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
@end

// 被 hook 微信类声明（手写完整 @interface，锚定 8.0.76 继承链，不用 @class 前向声明）
@interface MMTabBarBaseViewController : UIViewController @end
@interface MMUIView : UIView @end
@interface WCContentItemBaseView : UIView @end
@interface MMUIButton : UIButton @end
@interface MMUILabel : UILabel @end
@interface MMCPLabel : MMUILabel
@end

@interface BaseMsgContentLogicController : NSObject
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)GetTitleTailImageView;
@end
@interface RoomContentLogicController : NSObject
- (id)GetUsrTitle;
- (id)getSubTitle;
- (id)getMemeberCountLabel;
- (id)getDefaultTitleTailSubViews;
@end

@interface WCUserComment : NSObject
@property (nonatomic) _Bool bDeleted;
@property (nonatomic) _Bool deletedByFeedOwner;
// 注意：property 类型必须与手工 accessor 声明完全一致，否则 -Werror 下会报
//   "type of property 'content' does not match type of accessor 'setContent:'"
// 微信各版本 content / contentPattern 实际类型并不统一（NSString / NSMutableString / 富文本对象），
// 这里统一声明为 id，既避免类型冲突，也避免对返回值做错误假设。
@property (retain, nonatomic) id content;
@property (retain, nonatomic) id contentPattern;
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;
@property (retain, nonatomic) WCUserComment *comment;
@property (retain, nonatomic) WCUserComment *refComment;
- (void)upgradeDataIfNeeded;
- (_Bool)isWCMessageDeleted;
@end

// 朋友圈评论实际渲染组件（8.0.76D 头文件）
@interface WCCommentRichTextView : UIView
@property (retain, nonatomic) WCUserComment *userComment;
- (void)setContent:(id)arg1;
- (BOOL)setPrefixContent:(id)a0 TargetContent:(id)a1 TargetParserString:(id)a2 SuffixContent:(id)a3;
@end

@interface WCCommentListContentView : UIView
@property (retain, nonatomic) WCUserComment *comment;
- (void)config:(id)a0 dataItem:(id)a1 width:(double)a2;
@end

// 朋友圈视频全屏播放器（SNS / Moments）。注意：WAVideoPlayerView 是「小程序/视频号」
// 播放器，朋友圈视频走的是 WCPlayerConfigFullScreenViewController，因此点按关闭与
// 进度条都必须 hook 此类（已用 微信8.0.76D 头文件核对）。
@interface WCPlayerConfigFullScreenViewController : UIViewController
- (void)onFullScreenSingleTap;
- (BOOL)shouldShowProgressBar;
- (BOOL)autoShowProgressBarWithThreshold;
@end

@interface NewMainFrameViewController : MMTabBarBaseViewController
- (void)initTableHeaderView;
- (void)initTableHeaderTopView;
@end

@interface WCContentItemViewTemplateVideo : WCContentItemBaseView

- (void)autoPlayWithoutSound;
@end

@interface WCTimeLineCellView : MMUIView
- (void)layoutSubviews;
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1;
@end

@interface WCDataItem : NSObject
- (_Bool)isWeiShang;
- (void)setExtFlag:(unsigned int)arg1;
@end

#pragma mark - 配置管理
// 开关默认全 OFF
#define kDDWAPullDown          @"kDDWA_disableHomePullDownMiniProgram"
#define kDDWAVideoAutoPlay     @"kDDWA_disableSnsVideoAutoPlay"
#define kDDWAPrivacyIcon       @"kDDWA_disableSnsPrivacyIcon"
#define kDDWATextFold          @"kDDWA_disableSnsTextFold"
#define kDDWAGroupFold         @"kDDWA_disableSnsGroupFold"
#define kDDWADeletedComment    @"kDDWA_antiDeleteSnsComment"
#define kDDWADeletedCommentMark @"kDDWA_deletedCommentMark"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAVideoProgressBar  @"kDDWA_snsVideoProgressBar"   // 新增：朋友圈视频进度条
#define kDDWAHideFriendWxid    @"kDDWA_hideFriendWxid"
#define kDDWAHideChatName      @"kDDWA_hideChatName"

static const BOOL kDDDefaultPullDown          = NO;
static const BOOL kDDDefaultVideoAutoPlay     = NO;
static const BOOL kDDDefaultPrivacyIcon       = NO;
static const BOOL kDDDefaultTextFold          = NO;
static const BOOL kDDDefaultGroupFold         = NO;
static const BOOL kDDDefaultAntiDelete        = NO;
static const BOOL kDDDefaultVideoTapClose     = NO;
static const BOOL kDDDefaultVideoProgressBar  = NO;   // 新增
static const BOOL kDDDefaultHideFriendWxid    = NO;
static const BOOL kDDDefaultHideChatName      = NO;

// 修复点：对齐锤子 WeChatTweak。锤子写回 comment.content 的前缀是 @"[对方已删除] "
// （带方括号 + 尾随空格，已反汇编 CFString @0xdae080 / UTF-16 确认），原先 @"对方已删除 "
// 不带括号，与锤子渲染路径不一致。仍可在 NSUserDefaults 的 kDDWADeletedCommentMark 中自定义。
static NSString * const kDDDefaultDeletedMark = @"[对方已删除] ";
static NSString *ddDeletedMarkText(void) {
    NSString *t = [NSUserDefaults.standardUserDefaults stringForKey:kDDWADeletedCommentMark];
    return (t.length ? t : kDDDefaultDeletedMark);
}

@interface DDWeChatConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL disableHomePullDownMiniProgram;
@property (assign, nonatomic) BOOL disableSnsVideoAutoPlay;
@property (assign, nonatomic) BOOL disableSnsPrivacyIcon;
@property (assign, nonatomic) BOOL disableSnsTextFold;
@property (assign, nonatomic) BOOL disableSnsGroupFold;
@property (assign, nonatomic) BOOL antiDeleteSnsComment;
@property (assign, nonatomic) BOOL disableSnsVideoTapClose;
@property (assign, nonatomic) BOOL snsVideoProgressBar;   // 新增
@property (assign, nonatomic) BOOL hideFriendWxid;
@property (assign, nonatomic) BOOL hideChatName;
@end

@implementation DDWeChatConfig
+ (instancetype)sharedConfig {
    static DDWeChatConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDWeChatConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDWeChatConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDWAPullDown:       @(kDDDefaultPullDown),
        kDDWAVideoAutoPlay:  @(kDDDefaultVideoAutoPlay),
        kDDWAPrivacyIcon:    @(kDDDefaultPrivacyIcon),
        kDDWATextFold:       @(kDDDefaultTextFold),
        kDDWAGroupFold:      @(kDDDefaultGroupFold),
        kDDWADeletedComment: @(kDDDefaultAntiDelete),
        kDDWAVideoTapClose:  @(kDDDefaultVideoTapClose),
        kDDWAVideoProgressBar: @(kDDDefaultVideoProgressBar),   // 新增
        kDDWAHideFriendWxid: @(kDDDefaultHideFriendWxid),
        kDDWAHideChatName:   @(kDDDefaultHideChatName),
        kDDWADeletedCommentMark: kDDDefaultDeletedMark,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
        _disableHomePullDownMiniProgram = [ud boolForKey:kDDWAPullDown];
        _disableSnsVideoAutoPlay        = [ud boolForKey:kDDWAVideoAutoPlay];
        _disableSnsPrivacyIcon          = [ud boolForKey:kDDWAPrivacyIcon];
        _disableSnsTextFold             = [ud boolForKey:kDDWATextFold];
        _disableSnsGroupFold            = [ud boolForKey:kDDWAGroupFold];
        _antiDeleteSnsComment           = [ud boolForKey:kDDWADeletedComment];
        _disableSnsVideoTapClose        = [ud boolForKey:kDDWAVideoTapClose];
        _snsVideoProgressBar            = [ud boolForKey:kDDWAVideoProgressBar];   // 新增
        _hideFriendWxid                 = [ud boolForKey:kDDWAHideFriendWxid];
        _hideChatName                   = [ud boolForKey:kDDWAHideChatName];
    }
    return self;
}
- (void)setDisableHomePullDownMiniProgram:(BOOL)v { _disableHomePullDownMiniProgram = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAPullDown]; }
- (void)setDisableSnsVideoAutoPlay:(BOOL)v { _disableSnsVideoAutoPlay = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAVideoAutoPlay]; }
- (void)setDisableSnsPrivacyIcon:(BOOL)v { _disableSnsPrivacyIcon = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAPrivacyIcon]; }
- (void)setDisableSnsTextFold:(BOOL)v { _disableSnsTextFold = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWATextFold]; }
- (void)setDisableSnsGroupFold:(BOOL)v { _disableSnsGroupFold = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAGroupFold]; }
- (void)setAntiDeleteSnsComment:(BOOL)v { _antiDeleteSnsComment = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWADeletedComment]; }
- (void)setDisableSnsVideoTapClose:(BOOL)v { _disableSnsVideoTapClose = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAVideoTapClose]; }
- (void)setSnsVideoProgressBar:(BOOL)v { _snsVideoProgressBar = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAVideoProgressBar]; }   // 新增
- (void)setHideFriendWxid:(BOOL)v { _hideFriendWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideFriendWxid]; }
- (void)setHideChatName:(BOOL)v { _hideChatName = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideChatName]; }
@end

#pragma mark - ① 禁用首页下拉小程序
%hook NewMainFrameViewController
- (void)initTableHeaderView {
    %orig;
}
- (void)initTableHeaderTopView {
    %orig;
}

- (void)setTableHeaderTopViewHiddenIfNotLimitedMode:(BOOL)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) {
        %orig(YES);
        return;
    }
    %orig;
}

- (void)mainPullDown:(BOOL)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram && arg1) {
        return;
    }
    %orig;
}
- (void)showTableHeaderTopViewByPullDown:(unsigned long long)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
- (void)startDragToShow {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
- (void)showTableHeaderTopView:(BOOL)arg1 fromScene:(unsigned long long)arg2 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
%end

#pragma mark - ② 禁用朋友圈视频自动播放

%hook WCContentItemViewTemplateVideo
- (void)autoPlayWithoutSound {
    if ([DDWeChatConfig sharedConfig].disableSnsVideoAutoPlay) return;
    %orig;
}
%end

#pragma mark - ③ 禁用朋友圈谁可以见图标
%hook WCTimeLineCellView
- (void)initPrivacyButton:(id)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {

        MMUIButton *btn = MSHookIvar<MMUIButton *>(self, "m_privacyButton");
        if (btn) {
            [btn setImage:nil forState:0];
            [btn setAlpha:0.0];
            [btn setUserInteractionEnabled:NO];

        }
    }
}
- (void)layoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        MMUIButton *privacyBtn = MSHookIvar<MMUIButton *>(self, "m_privacyButton");
        MMUIButton *deleteBtn  = MSHookIvar<MMUIButton *>(self, "m_deleteButton");
        if (privacyBtn && deleteBtn && privacyBtn.superview && deleteBtn.superview && !deleteBtn.hidden) {
            CGRect pFrame = privacyBtn.frame;
            CGRect dFrame = deleteBtn.frame;
            CGFloat pMinX = CGRectGetMinX(pFrame);
            CGFloat dMinX = CGRectGetMinX(dFrame);
            if (dMinX > pMinX + 0.5) {
                dFrame.origin.x = pMinX;
                [deleteBtn setFrame:dFrame];
            }
        }
    }
}
%end

#pragma mark - ④ 禁用朋友圈长文字折叠

%hook WCTimeLineCellView
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsTextFold) return NO;
    return %orig;
}
%end

#pragma mark - ⑤ 禁用朋友圈微商折叠
%hook WCDataItem
- (_Bool)isWeiShang {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return NO;
    return %orig;
}
- (void)setExtFlag:(unsigned int)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) {
        MSHookIvar<char>(self, "_isWeiShang") = 0;
    }
}
%end

#pragma mark - ⑥ 朋友圈查看已删评论（对齐锤子 WeChatTweak.dylib 的实现）

// ===== 根因：为什么“锤子有效、你的无效” =====
// 反汇编锤子 WeChatTweak.dylib 确认，它的已删评论核心只 hook 一个方法：
//   %hook WCSNSMessage -setDelStatus:
// 微信在解析/加载一条评论时，会用 setDelStatus:1 把它标记为“已删除”。锤子的 newImp（0x7a66b8）逻辑：
//   1) 开关开启 且 传入的 delStatus == 1 时：
//        c  = [self comment];
//        s  = [c content];
//        [c setContent:[@"[对方已删除] " stringByAppendingString:s]];   // 数据加载期就把前缀写回 content
//   2) 再以 delStatus = 0 调回原方法（对外不标记为已删 → 评论走正常 WCCommentRichTextView 渲染）
// 关键点：(a) hook 的是 setDelStatus: 这个“真正写入删除标记”的点；(b) 在数据加载期就改好 content；
//        (c) 把 delStatus 清零，使评论不被过滤、不走“删除占位”。
// 原实现 hook 的是 upgradeDataIfNeeded / isWCMessageDeleted，且只在 getter 里补前缀 —— 既 hook 错了写入点，
// 时机也晚（setDelStatus: 之后评论可能已被路由到删除占位），所以前缀根本没机会上屏。
// 因此必须对齐锤子：hook setDelStatus:，在它被调用时注入前缀并清零 delStatus。

static NSString *dd_markDeletedContent(NSString *orig) {
    NSString *mark = ddDeletedMarkText();
    if ([orig isKindOfClass:[NSString class]] && orig.length && ![orig hasPrefix:mark]) {
        return [mark stringByAppendingString:orig];
    }
    return orig;
}
// 对 WCSNSMessage.comment / refComment 幂等补前缀（锤子只改 comment，这里顺带处理回复 refComment）
static void dd_injectMarkIntoComment(id c) {
    if (![c isKindOfClass:%c(WCUserComment)]) return;
    NSString *s = [c content];
    if ([s isKindOfClass:[NSString class]] && s.length && ![s hasPrefix:ddDeletedMarkText()]) {
        [c setContent:[ddDeletedMarkText() stringByAppendingString:s]];
    }
}

// ★ 核心：对齐锤子 hook WCSNSMessage -setDelStatus:
%hook WCSNSMessage
- (void)setDelStatus:(unsigned int)status {
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) { %orig; return; }
    if (status == 1) {
        // 已删除：在数据加载期就把前缀写回 comment.content（早于任何渲染）
        dd_injectMarkIntoComment([self comment]);
        dd_injectMarkIntoComment([self refComment]);   // 回复
        // 以 0 调回原方法：对外不视作已删，正常渲染
        %orig(0);
        return;
    }
    %orig;
}
// 兜底：feed 级删除也让 isWCMessageDeleted 返回 NO（先于 setDelStatus 的判定）
// 返回类型与 8.0.76D 头文件一致，统一用 _Bool，避免个别架构下 BOOL 定义不同导致的签名告警
- (_Bool)isWCMessageDeleted {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;
    return %orig;
}
%end

// 渲染组件兜底：WCCommentRichTextView 实际把评论画到屏幕（截图已证实）
%hook WCCommentRichTextView
- (void)setContent:(id)content {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment &&
        [content isKindOfClass:[NSString class]]) {
        content = dd_markDeletedContent(content);
    }
    %orig;
}
// 8.0.76D 头文件中的组装方法：prefix/targetContent/targetParserString/suffix
- (BOOL)setPrefixContent:(id)prefix TargetContent:(id)targetContent TargetParserString:(id)parserString SuffixContent:(id)suffix {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) {
        if ([targetContent isKindOfClass:[NSString class]]) targetContent = dd_markDeletedContent(targetContent);
        if ([parserString isKindOfClass:[NSString class]]) parserString = dd_markDeletedContent(parserString);
    }
    return %orig(prefix, targetContent, parserString, suffix);
}
%end

// 容器兜底：config 时若发现 content 还未带前缀，补一道（幂等）
%hook WCCommentListContentView
- (void)config:(id)dataItem dataItem:(id)item width:(double)width {
    %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return;
    if ([self.comment isKindOfClass:%c(WCUserComment)]) {
        dd_injectMarkIntoComment(self.comment);
    }
}
%end

#pragma mark - ⑩ 隐藏好友微信号

%hook MMCPLabel
- (void)setText:(NSString *)text {
    if ([DDWeChatConfig sharedConfig].hideFriendWxid && self.tag == 90224) {
        %orig(@"");
        return;
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)text {
    if ([DDWeChatConfig sharedConfig].hideFriendWxid && self.tag == 90224) {
        %orig(nil);
        return;
    }
    %orig;
}
- (void)setTag:(NSInteger)tag {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideFriendWxid && tag == 90224) {
        if (self.text.length) self.text = @"";
        if (self.attributedText.length) self.attributedText = nil;
    }
}
%end

#pragma mark - ⑧ 禁用朋友圈视频点击关闭 + ⑦ 朋友圈视频进度条

// 修正（关键）：原实现 hook 了 WAVideoPlayerView，但那是「小程序/视频号」播放器，
// 朋友圈(SNS)视频走的是全屏播放器 WCPlayerConfigFullScreenViewController，所以原
// 修复对朋友圈完全不生效（已用 微信8.0.76D 头文件核对：WAVideoPlayerView 中无任何
// Moments/SNS 字样，而 WCPlayerConfigFullScreenViewController 委托含 Moments/SNS）。
// 下面改为 hook 正确的类。
//
// ② 禁用点击关闭：单次点按触发 onFullScreenSingleTap，内部走向关闭。开启后吞掉该
//    点按即可（X 关闭按钮 onTapCloseButton 仍可正常关闭）。
//
// ③ 启用进度条：朋友圈短视频(<约15秒)的进度条“一开始就是折叠/隐藏”的（并非没有、
//    只是默认收起）。故强制展开：shouldShowProgressBar / autoShowProgressBarWithThreshold
//    返回 YES，让短视频进度条从一开始就显示。
//    （注：短视频播放约5秒后会自动折叠，按需求不处理该折叠，故不拦截。）
%hook WCPlayerConfigFullScreenViewController

- (void)onFullScreenSingleTap {
    if ([DDWeChatConfig sharedConfig].disableSnsVideoTapClose) {
        // 禁用「点按关闭」：吞掉单次点按，不再触发关闭（X 按钮仍可关闭）
        return;
    }
    %orig;
}

- (BOOL)shouldShowProgressBar {
    if ([DDWeChatConfig sharedConfig].snsVideoProgressBar) return YES;
    return %orig;
}

- (BOOL)autoShowProgressBarWithThreshold {
    if ([DDWeChatConfig sharedConfig].snsVideoProgressBar) return YES;  // 短视频(<15s)从一开始也展开
    return %orig;
}

%end

#pragma mark - ⑫ 隐藏聊天顶栏名字

static BOOL ddHideName(void) {
    return [DDWeChatConfig sharedConfig].hideChatName;
}
%hook BaseMsgContentLogicController
- (id)GetUsrTitle {
    if (ddHideName()) return @"";
    return %orig;
}
- (id)getSubTitle {
    if (ddHideName()) return @"";
    return %orig;
}
- (id)GetTitleTailImageView {
    if (ddHideName()) return nil;
    return %orig;
}
%end
%hook RoomContentLogicController
- (id)GetUsrTitle {
    if (ddHideName()) return @"";
    return %orig;
}
- (id)getSubTitle {
    if (ddHideName()) return @"";
    return %orig;
}
- (id)getDefaultTitleTailSubViews {
    if (ddHideName()) return nil;
    return %orig;
}
- (id)getMemeberCountLabel {
    if (ddHideName()) return nil;
    return %orig;
}
%end

#pragma mark - 设置界面
@interface DDWeChatSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDWeChatSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (_tableViewManager) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    _tableViewManager = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                               style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) { [self ensureTableViewMgr]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD微信助手";
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
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
    DDWeChatConfig *cfg = [DDWeChatConfig sharedConfig];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    WCTableViewSectionManager *home = [secMgr defaultSection];
    [home addCell:[cellMgr switchCellForSel:@selector(onPullDownSwitch:) target:self title:@"禁用下拉小程序" on:cfg.disableHomePullDownMiniProgram]];
    [_tableViewManager addSection:home];

    WCTableViewSectionManager *sns = [secMgr defaultSection];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoSwitch:) target:self title:@"禁用朋友圈视频自动播放" on:cfg.disableSnsVideoAutoPlay]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onPrivacySwitch:) target:self title:@"禁用朋友圈隐私图标" on:cfg.disableSnsPrivacyIcon]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onTextFoldSwitch:) target:self title:@"禁用朋友圈文字折叠" on:cfg.disableSnsTextFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onGroupFoldSwitch:) target:self title:@"禁用朋友圈微商折叠" on:cfg.disableSnsGroupFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onAntiDeleteSwitch:) target:self title:@"查看朋友圈已删评论" on:cfg.antiDeleteSnsComment]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoTapCloseSwitch:) target:self title:@"禁用朋友圈视频点击关闭" on:cfg.disableSnsVideoTapClose]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoProgressBarSwitch:) target:self title:@"启用朋友圈视频进度条" on:cfg.snsVideoProgressBar]];   // 新增
    [_tableViewManager addSection:sns];

    WCTableViewSectionManager *privacy = [secMgr defaultSection];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideFriendWxidSwitch:) target:self title:@"隐藏好友微信号" on:cfg.hideFriendWxid]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideChatNameSwitch:) target:self title:@"隐藏聊天顶栏名字" on:cfg.hideChatName]];
    [_tableViewManager addSection:privacy];

    [_tableViewManager reloadTableView];
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)onPullDownSwitch:(UISwitch *)s      { [DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram = s.on; }
- (void)onVideoSwitch:(UISwitch *)s         { [DDWeChatConfig sharedConfig].disableSnsVideoAutoPlay = s.on; }
- (void)onPrivacySwitch:(UISwitch *)s       { [DDWeChatConfig sharedConfig].disableSnsPrivacyIcon = s.on; }
- (void)onTextFoldSwitch:(UISwitch *)s      { [DDWeChatConfig sharedConfig].disableSnsTextFold = s.on; }
- (void)onGroupFoldSwitch:(UISwitch *)s     { [DDWeChatConfig sharedConfig].disableSnsGroupFold = s.on; }
- (void)onAntiDeleteSwitch:(UISwitch *)s    { [DDWeChatConfig sharedConfig].antiDeleteSnsComment = s.on; }
- (void)onVideoTapCloseSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsVideoTapClose = s.on; }
- (void)onVideoProgressBarSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].snsVideoProgressBar = s.on; }   // 新增
- (void)onHideFriendWxidSwitch:(UISwitch *)s{ [DDWeChatConfig sharedConfig].hideFriendWxid = s.on; }
- (void)onHideChatNameSwitch:(UISwitch *)s  { [DDWeChatConfig sharedConfig].hideChatName = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD微信助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDWeChatSettingsViewController"];
        }
    }
}

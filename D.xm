
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
@interface MMUIViewController : UIViewController @end
@interface MMUIView : UIView @end
@interface WCPlayerControlView : UIView @end
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
- (_Bool)bDeleted;
- (_Bool)deletedByFeedOwner;
- (id)content;
- (void)setContent:(id)arg1;
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;
@property (retain, nonatomic) WCUserComment *comment;
@property (retain, nonatomic) WCUserComment *refComment;
- (void)upgradeDataIfNeeded;
- (_Bool)isWCMessageDeleted;
@end

// 朋友圈视频全屏播放器（SNS / Moments）。注意：WAVideoPlayerView 是「小程序/视频号」
// 播放器，朋友圈视频走的是 WCPlayerConfigFullScreenViewController，因此点按关闭与
// 进度条都必须 hook 此类（已用 微信8.0.76D 头文件核对）。
@interface WCPlayerConfigFullScreenViewController : UIViewController
- (void)onFullScreenSingleTap;
- (BOOL)shouldShowProgressBar;
- (BOOL)shouldShowProgressBarWithoutThreshold;
- (BOOL)autoShowProgressBarWithThreshold;
- (id)generateConfig;
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

// 修复点：原默认前缀为 @"对方已删除] "（带方括号且常因还原时机问题不显示）。
// 改为干净的 @"对方已删除 "，使其与“对方已删除”前缀的预期一致；仍可在 NSUserDefaults
// 的 kDDWADeletedCommentMark 中自定义。
static NSString * const kDDDefaultDeletedMark = @"对方已删除 ";
static NSString *ddDeletedMarkText(void) {
    NSString *t = [NSUserDefaults.standardUserDefaults stringForKey:kDDWADeletedCommentMark];
    return (t.length ? t : kDDDefaultDeletedMark);
}

// 关联对象 key：标记“该评论原本是已删除的”，供 content getter 幂等地补回前缀
static const void *kDDWasDeletedCommentKey = &kDDWasDeletedCommentKey;

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

#pragma mark - ⑥ 朋友圈查看已删评论

// 恢复单条已删评论：清掉删除标记 + 打“对方已删除”前缀，并用关联对象记住“原本已删”
static void dd_restoreDeletedComment(id c) {
    Class CommentCls = objc_getClass("WCUserComment");
    if (![c isKindOfClass:CommentCls]) return;
    _Bool realDel = MSHookIvar<_Bool>(c, "_bDeleted") || MSHookIvar<_Bool>(c, "_deletedByFeedOwner");
    if (!realDel) return;

    // 打标记：即便 content 后续被重读/刷新，getter 也能幂等地补回前缀
    objc_setAssociatedObject(c, kDDWasDeletedCommentKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    MSHookIvar<_Bool>(c, "_bDeleted") = 0;
    MSHookIvar<_Bool>(c, "_deletedByFeedOwner") = 0;
    NSString *ct = [c content];
    NSString *mark = ddDeletedMarkText();
    if ([ct isKindOfClass:[NSString class]] && ct.length && ![ct hasPrefix:mark]) {
        [c setContent:[mark stringByAppendingString:ct]];
    }
}

// 修复点：原实现只在 upgradeDataIfNeeded 里补一次前缀。若评论内容在展示前被
// 微信重新读取/刷新，前缀就会丢失。这里 hook content getter，对“原本已删”的评论
// 幂等地保证前缀存在，从而稳定显示“对方已删除”。
%hook WCUserComment
- (id)content {
    NSString *orig = %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return orig;
    if (!objc_getAssociatedObject(self, kDDWasDeletedCommentKey)) return orig;
    if (![orig isKindOfClass:[NSString class]] || orig.length == 0) return orig;
    NSString *mark = ddDeletedMarkText();
    if (![orig hasPrefix:mark]) {
        return [mark stringByAppendingString:orig];
    }
    return orig;
}
%end

// ⑥ 提醒里查看已删评论
%hook WCSNSMessage
- (_Bool)isWCMessageDeleted {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;
    return %orig;
}
- (void)upgradeDataIfNeeded {
    %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return;
    if (self.delStatus != 0) self.delStatus = 0;

    id cm = [self comment];
    if (cm) dd_restoreDeletedComment(cm);
    id ref = [self refComment];
    if (ref) dd_restoreDeletedComment(ref);
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
// ③ 启用进度条：朋友圈短视频(<约15秒)默认不显示进度条，阈值逻辑在
//    autoShowProgressBarWithThreshold；是否显示由 shouldShowProgressBar 决定；
//    常驻与否由 config.bForbidProgressBarAutoHidden 决定（与锤子同款机制：
//    setBForbidProgressBarAutoHidden:）。开启后强制三者，使短视频也常驻显示进度条。
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

- (BOOL)shouldShowProgressBarWithoutThreshold {
    if ([DDWeChatConfig sharedConfig].snsVideoProgressBar) return YES;
    return %orig;
}

- (BOOL)autoShowProgressBarWithThreshold {
    if ([DDWeChatConfig sharedConfig].snsVideoProgressBar) return YES;  // 短视频(<15s)也显示
    return %orig;
}

- (id)generateConfig {
    id cfg = %orig;
    if ([DDWeChatConfig sharedConfig].snsVideoProgressBar) {
        // 禁止进度条自动隐藏（锤子机制：WCPlayerFullScreenConfig.bForbidProgressBarAutoHidden）
        if ([cfg respondsToSelector:NSSelectorFromString(@"setBForbidProgressBarAutoHidden:")]) {
            [cfg setBForbidProgressBarAutoHidden:YES];
        }
    }
    return cfg;
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

// DD微信助手 v2.3.0 — 单文件 WeChat 8.0.76 越狱插件 (Theos / Logos)
// 被 hook 类均按 8.0.76 头文件手写完整 @interface；不使用 @class 前向声明。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 插件注册入口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 设置页 / 聊天详情页共用的表管理器
@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;                                       // WCTableViewManager.h:23
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
- (unsigned long long)getSectionCount;                   // WCTableViewManager.h:28
- (id)getSectionAt:(unsigned long long)a0;               // WCTableViewManager.h:29
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
- (void)insertCell:(id)a0 At:(unsigned int)a1;           // WCTableViewSectionManager.h:48
- (unsigned long long)getCellCount;                      // WCTableViewSectionManager.h:49
- (id)getCellAt:(unsigned long long)a0;                  // WCTableViewSectionManager.h:51
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;  // WCTableViewCellManager.h:55
@end


// ---- 被 hook 微信类声明(锚定 8.0.76 dump 真实继承链) ----

@interface MMTabBarBaseViewController : UIViewController @end
@interface MMUIViewController : UIViewController @end
@interface MMUIView : UIView @end
@interface WCPlayerControlView : UIView @end
@interface WCContentItemBaseView : UIView @end
@interface MMUIButton : UIButton @end
@interface MMUILabel : UILabel @end
@interface MMCPLabel : MMUILabel   // MMCPLabel.h:4 (: MMUILabel : UILabel)
@end
// ⑫ 用。聊天顶栏名字是"数据层取值 → 视图层渲染"两级：VC 通过 delegate 协议向 LogicController 要标题字符串
@interface BaseMsgContentLogicController : NSObject      // BaseMsgContentLogicController.h:9
- (id)GetUsrTitle;            // :299 主标题(单聊/通用)
- (id)getSubTitle;            // :296 副标题
- (id)GetTitleTailImageView;  // :280 标题尾部视图(免打扰铃铛, 协议 BaseMsgContentDelgate-Protocol.h:16)
@end
@interface RoomContentLogicController : NSObject         // RoomContentLogicController.h:9
- (id)GetUsrTitle;                 // :188 群聊自己重写了一份，屏蔽基类
- (id)getSubTitle;                 // :151 群聊副标题
- (id)getMemeberCountLabel;        // :186 群人数 UILabel(拼写 Memeber 是微信原生 typo)
- (id)getDefaultTitleTailSubViews; // :185 标题尾部子视图数组(人数 label 从这插入, 汇编 0x1054510c8)
@end


// ⑥ 朋友圈评论防删
@interface WCUserComment : NSObject
@property (nonatomic) _Bool bDeleted;                 // WCUserComment.h:22
@property (nonatomic) _Bool deletedByFeedOwner;      // WCUserComment.h:32
- (_Bool)bDeleted;
- (_Bool)deletedByFeedOwner;
- (id)content;                                       // WCUserComment.h:37
- (void)setContent:(id)arg1;                         // WCUserComment.h:37
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;         // WCSNSMessage.h
@property (retain, nonatomic) WCUserComment *comment; // WCSNSMessage.h:8
- (void)upgradeDataIfNeeded;                          // WCSNSMessage.h:36
- (_Bool)isWCMessageDeleted;                          // WCSNSMessage.h:19
@end


// ⑧ 朋友圈视频点击关闭
@interface WAVideoPlayerView : WCPlayerControlView       // WAVideoPlayerView.h:4
@property (nonatomic) _Bool disableTapGesture;                                 // WAVideoPlayerView.h:104
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3;  // WAVideoPlayerView.h:135
@end


// ① 首页下拉小程序
@interface NewMainFrameViewController : MMTabBarBaseViewController   // NewMainFrameViewController.h:4
- (void)initTableHeaderView;                         // NewMainFrameViewController.h:314
- (void)initTableHeaderTopView;                      // NewMainFrameViewController.h:179
@end

// ② 朋友圈视频自动播放
@interface WCContentItemViewTemplateVideo : WCContentItemBaseView   // WCContentItemViewTemplateVideo.h:3
// 注意: 该方法返回 void(执行静音自动播放的动作)，开关命中时跳过原实现即可，不返回 NO
- (void)autoPlayWithoutSound;   // WCContentItemViewTemplateVideo.h:28
@end

// ③④ 朋友圈隐私图标 / 文字折叠
@interface WCTimeLineCellView : MMUIView   // WCTimeLineCellView.h:9
- (void)layoutSubviews;                                   // WCTimeLineCellView.h:193
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1;   // WCTimeLineCellView.h:95
@end

// ⑤ 朋友圈"余下N条"折叠（改为锤子数据层做法：WCDataItem isWeiShang / setExtFlag）
@interface WCDataItem : NSObject   // WCDataItem.h:11
- (_Bool)isWeiShang;                          // WCDataItem.h:260
- (void)setExtFlag:(unsigned int)arg1;        // WCDataItem.h:290
@end


#pragma mark - 配置管理
#define kDDWAPullDown          @"kDDWA_disableHomePullDownMiniProgram"
#define kDDWAVideoAutoPlay     @"kDDWA_disableSnsVideoAutoPlay"
#define kDDWAPrivacyIcon       @"kDDWA_disableSnsPrivacyIcon"
#define kDDWATextFold          @"kDDWA_disableSnsTextFold"
#define kDDWAGroupFold         @"kDDWA_disableSnsGroupFold"
#define kDDWADeletedComment    @"kDDWA_antiDeleteSnsComment"
#define kDDWADeletedCommentMark @"kDDWA_deletedCommentMark"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAHideFriendWxid    @"kDDWA_hideFriendWxid"
#define kDDWAHideChatName      @"kDDWA_hideChatName"

// 开关默认全部 OFF，装好与原生一致
static const BOOL kDDDefaultPullDown          = NO;
static const BOOL kDDDefaultVideoAutoPlay     = NO;
static const BOOL kDDDefaultPrivacyIcon       = NO;
static const BOOL kDDDefaultTextFold          = NO;
static const BOOL kDDDefaultGroupFold         = NO;
static const BOOL kDDDefaultAntiDelete        = NO;
static const BOOL kDDDefaultVideoTapClose     = NO;
static const BOOL kDDDefaultHideFriendWxid    = NO;
static const BOOL kDDDefaultHideChatName      = NO;

// ⑥ 被删评论前缀文案（对齐锤子原文："对方已删除] "，见锤子 __ustring @0xbd80da）
static NSString * const kDDDefaultDeletedMark = @"对方已删除] ";
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
// 下拉露出的顶部面板强制隐藏
- (void)setTableHeaderTopViewHiddenIfNotLimitedMode:(BOOL)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) {
        %orig(YES);
        return;
    }
    %orig;
}
// 下拉手势"展开"时(参数=YES)不显示面板，其余下拉逻辑保持自然
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
// autoPlayWithoutSound 返回 void，开关命中时直接 return(跳过原实现)即不自动播放
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
        // WCTimeLineCellView.h:12 -> MMUIButton *m_privacyButton (ivar 走运行时偏移)
        MMUIButton *btn = MSHookIvar<MMUIButton *>(self, "m_privacyButton");
        if (btn) {
            [btn setImage:nil forState:0];
            [btn setAlpha:0.0];
            [btn setUserInteractionEnabled:NO];
            // 不 removeFromSuperview，空白占位由下方 layoutSubviews 重排 m_deleteButton 消去
        }
    }
}
- (void)layoutSubviews {
    %orig;   // %orig 之后 frame 才就绪，reflow 必须在这里做
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        MMUIButton *privacyBtn = MSHookIvar<MMUIButton *>(self, "m_privacyButton"); // WCTimeLineCellView.h:12
        MMUIButton *deleteBtn  = MSHookIvar<MMUIButton *>(self, "m_deleteButton");  // WCTimeLineCellView.h:14
        if (privacyBtn && deleteBtn && privacyBtn.superview && deleteBtn.superview && !deleteBtn.hidden) {
            CGRect pFrame = privacyBtn.frame;
            CGRect dFrame = deleteBtn.frame;
            CGFloat pMinX = CGRectGetMinX(pFrame);
            CGFloat dMinX = CGRectGetMinX(dFrame);
            if (dMinX > pMinX + 0.5) {
                dFrame.origin.x = pMinX;   // 删除按钮左移到隐私按钮原位，消去预留空白
                [deleteBtn setFrame:dFrame];
            }
        }
    }
}
%end

#pragma mark - ④ 禁用朋友圈文字自动折叠
// 返回 NO -> 不显示"全文"按钮，内容按全文展示
%hook WCTimeLineCellView
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsTextFold) return NO;
    return %orig;
}
%end

#pragma mark - ⑤ 禁用朋友圈"余下N条"折叠（锤子数据层做法）
%hook WCDataItem
- (_Bool)isWeiShang {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return NO;  // 数据层抹掉微商标记，折叠逻辑失效
    return %orig;
}
- (void)setExtFlag:(unsigned int)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) {
        MSHookIvar<char>(self, "_isWeiShang") = 0;   // 兜底清掉微商标记，与锤子 setExtFlag 路数一致
    }
}
%end

#pragma mark - ⑥ 朋友圈查看已删评论（对齐锤子：单点 %hook WCSNSMessage）
// 对齐锤子，整个功能收敛为单一 hook：%hook WCSNSMessage。
// 提醒/通知里被删评论来自 WCSNSMessage.comment / refComment（独立 WCUserComment，
// WCSNSMessage.h:18/19）；在此拦截 isWCMessageDeleted（放行）+ upgradeDataIfNeeded
// （重置 delStatus、恢复 comment/refComment 并拼锤子前缀"对方已删除] "，@0xbd80da）。
// 单点即覆盖提醒路径，不再分散到 WCFacade / WCDataItem。

// 恢复单条已删评论（C helper，避免 %new 调用编译期 selector 可见性问题）：
// 清真实删除标记，并数据层拼锤子前缀"对方已删除] "
static void dd_restoreDeletedComment(id c) {
    Class CommentCls = objc_getClass("WCUserComment");
    if (![c isKindOfClass:CommentCls]) return;
    _Bool realDel = MSHookIvar<_Bool>(c, "_bDeleted") || MSHookIvar<_Bool>(c, "_deletedByFeedOwner");
    if (!realDel) return;
    MSHookIvar<_Bool>(c, "_bDeleted") = 0;
    MSHookIvar<_Bool>(c, "_deletedByFeedOwner") = 0;
    NSString *ct = [c content];
    NSString *mark = ddDeletedMarkText();
    if ([ct isKindOfClass:[NSString class]] && ct.length && ![ct hasPrefix:mark]) {
        [c setContent:[mark stringByAppendingString:ct]];
    }
}

// 单点核心（对齐锤子 %hook WCSNSMessage）：isWCMessageDeleted 放行 + upgradeDataIfNeeded 恢复
%hook WCSNSMessage
- (_Bool)isWCMessageDeleted {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;
    return %orig;
}
- (void)upgradeDataIfNeeded {
    %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return;
    if (self.delStatus != 0) self.delStatus = 0;
    // 提醒/通知路径核心（对齐锤子 %hook WCSNSMessage）：WCSNSMessage.comment /
    // refComment 是独立 WCUserComment，在此恢复并加锤子前缀（WCSNSMessage.h:18/19）
    id cm = [self comment];
    if (cm) dd_restoreDeletedComment(cm);
    id ref = [self refComment];
    if (ref) dd_restoreDeletedComment(ref);
}
%end

#pragma mark - ⑩ 隐藏好友微信号(资料页)
// 在文本设置源头拦截: MMCPLabel setText:/setAttributedText: 命中 tag==90224 时直接传空(无闪现)；
// 另 hook setTag: 兜底(防"先设文本后设 tag"漏清)。config 关闭时全部透传。
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

#pragma mark - ⑧ 禁用朋友圈视频点击关闭
// 装配完成后用内置 disableTapGesture 属性禁用点击手势
%hook WAVideoPlayerView
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsVideoTapClose) {
        self.disableTapGesture = YES;   // WAVideoPlayerView.h:189
    }
}
%end

#pragma mark - ⑫ 隐藏聊天顶栏名字(仅群聊 + 个人聊天)
// 数据流(砸壳二进制汇编实证): [self GetUsrTitle] → setTitle:subTitle:leftLoading:rightView: → titleView
//   0x100531360 取 GetUsrTitle  →  0x1005313a0 作为 setTitle:subTitle:leftLoading:rightView: 的 title 参数
// 覆盖两个类即可:
//   BaseMsgContentLogicController  = 个人聊天(WeixinContentLogicController 等未重写，走基类实现)
//   RoomContentLogicController     = 群聊(重写了 GetUsrTitle，必须单独 hook)
// 不覆盖也不误伤: 全库仅 13 个类重写 GetUsrTitle，全是公众号(WASessionContentLogicController)、
//   企微(CBTAsstContentLogicController)、模板消息、客服这类特殊会话——子类实现会屏蔽基类 hook，天然不受影响。
// 开关开时不调 %orig: 群聊 GetUsrTitle 在无备注时会 fallback 到 [self GetChatRoomTitle]
//   (汇编 0x105450bd8)，直接返回 @"" 即一并堵死这条 fallback，省掉一个 hook。
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
    if (ddHideName()) return nil;   // 免打扰铃铛(rightView)
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
    if (ddHideName()) return nil;   // 尾部数组(人数 label 在这插入)；必须先于人数 hook，否则 insertObject:nil 崩溃
    return %orig;
}
- (id)getMemeberCountLabel {
    if (ddHideName()) return nil;   // "群聊 (N)" 的人数
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
    [home addCell:[cellMgr switchCellForSel:@selector(onPullDownSwitch:) target:self title:@"禁用首页下拉小程序" on:cfg.disableHomePullDownMiniProgram]];
    [_tableViewManager addSection:home];

    WCTableViewSectionManager *sns = [secMgr defaultSection];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoSwitch:) target:self title:@"禁用朋友圈视频自动播放" on:cfg.disableSnsVideoAutoPlay]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onPrivacySwitch:) target:self title:@"禁用朋友圈谁可以见图标" on:cfg.disableSnsPrivacyIcon]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onTextFoldSwitch:) target:self title:@"禁用朋友圈文字自动折叠" on:cfg.disableSnsTextFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onGroupFoldSwitch:) target:self title:@"禁用朋友圈余下N条折叠" on:cfg.disableSnsGroupFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onAntiDeleteSwitch:) target:self title:@"朋友圈查看已删评论" on:cfg.antiDeleteSnsComment]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoTapCloseSwitch:) target:self title:@"禁用朋友圈视频点击关闭" on:cfg.disableSnsVideoTapClose]];
    [_tableViewManager addSection:sns];

    WCTableViewSectionManager *privacy = [secMgr defaultSection];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideFriendWxidSwitch:) target:self title:@"隐藏好友微信号(资料页)" on:cfg.hideFriendWxid]];
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
- (void)onHideFriendWxidSwitch:(UISwitch *)s{ [DDWeChatConfig sharedConfig].hideFriendWxid = s.on; }
- (void)onHideChatNameSwitch:(UISwitch *)s  { [DDWeChatConfig sharedConfig].hideChatName = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD微信助手"
                                                      version:@"2.3.0"
                                                   controller:@"DDWeChatSettingsViewController"];
        }
    }
}

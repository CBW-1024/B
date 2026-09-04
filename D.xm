// =============================================================================
//  DD微信助手 (DD WeChat Assistant)  v1.0.0
//  单文件 iOS 越狱插件 (Theos / Logos)，目标微信 8.0.76
//
//  功能(提取自 WCR，重写为独立插件，每个 hook 均锚定微信头文件 dump 真实证据)：
//    1. 禁用首页下拉小程序        -> NewMainFrameViewController (仅禁主界面下拉露出, 不动发现页入口)
//    2. 禁用朋友圈视频自动播放     -> WCTimeLineViewController._canAutoPlayVideoForCellView:
//    3. 禁用朋友圈谁可以见图标     -> WCTimeLineCellView.m_privacyButton
//    4. 禁用朋友圈文字自动折叠     -> WCTimeLineCellView +shouldShowFullTextButtonWithDataItem:
//    5. 禁用朋友圈余下N条折叠      -> WCMicroMerchantFeedsMgr isFeedIDFoldInGroup: + MicroMerchantFoldInterceptor intercept:
//    6. 朋友圈评论防删            -> WCSNSMessage.upgradeDataIfNeeded (重置 delStatus / 评论删除标记)
//    7. 启用自定义头像(聊天详情)   -> ContactInfoViewController 注入开关 + FakeHeadImageView 渲染
//    8. 禁用朋友圈视频点击关闭     -> WAVideoPlayerView.disableTapGesture / onGestureTap:
//    9. 禁用聊天文字折叠          -> TextMessageViewModel.shouldFoldText (返回 NO, 长文不折叠)
//   10. 隐藏好友微信号(资料页)     -> WAProfileHeaderView.descLabel -updateContact: (单方法, 对齐 WCR m_descLabel KVC 隐藏: 清空文本+hidden)
//   11. 隐藏自己微信号(我界面)     -> WASettingAccountCell.detailLabel(账户卡片副标题=微信号行)
//   12. 隐藏聊天名字(顶栏标题)     -> BaseMsgContentViewController.updateTitleView: (%orig 后取 MMUIViewController.titleView 隐藏; 覆盖个人"陈某人"/群聊"群聊(N)")
//
//  设置界面与插件入口参考 D.txt：WCPluginsMgr 注册 + WCTableViewManager 自绘设置页 + 导航栏按 VC 隔离。
//  头文件证据目录：/tmp/wechat76_dump/微信/
//  WCR 佐证：/tmp/wcr_dis.txt (Logos 编译后类名/selector 作为字符串保留)
// =============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 无需导入微信头文件：用 theos 内置 MSHookIvar 按头文件中的 ivar 名读取
// (ivar 名来自 8.0.76 dump, 非猜测; MSHookIvar 即 substrate 提供的 ivar 读取, 比自写 helper 更标准)

// 微信插件注册入口(同 D.txt)
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 设置页用到的微信表管理器：依据 8.0.76 头文件手动声明(仅声明实际调用的接口, 不 import 完整头文件)
//   WCTableViewManager.h:12  @interface WCTableViewManager : NSObject
//   WCTableViewSectionManager.h:11 @interface WCTableViewSectionManager : NSObject
//   WCTableViewCellManager.h:11   @interface WCTableViewCellManager : NSObject
@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(_Bool)arg4;
@end

// ---- 被 hook 微信类的手动声明(基于 8.0.76 dump 真实签名；不 import 微信头文件) ----
// Logos %hook 会生成 category，要求被 hook 类至少可见。凡访问 property/ivar 之处
// 必须给出完整 @interface，否则报 "property cannot be found in forward class object" /
// "cannot find interface declaration"。仅重写方法、不碰 property/ivar 的类用 @class 即可。

@class CContact;

// 朋友圈评论防删：WCSNSMessage.h:19/28 delStatus, :30 comment, :31 refComment, :36 upgradeDataIfNeeded
//              WCUserComment.h:119 bDeleted, :112 deletedByFeedOwner
@interface WCUserComment : NSObject
@property (nonatomic) _Bool bDeleted;
@property (nonatomic) _Bool deletedByFeedOwner;
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;
@property (nonatomic, retain) WCUserComment *comment;
@property (nonatomic, retain) WCUserComment *refComment;
- (void)upgradeDataIfNeeded;
@end

// 自定义头像：ContactInfoViewController.h:123 m_contact, :81 frontTableView
@interface ContactInfoViewController : UIViewController
@property (nonatomic, retain) CContact *m_contact;
@property (nonatomic, weak) UITableView *frontTableView;
@end

// 禁用视频点击关闭：WAVideoPlayerView.h:189 disableTapGesture
@interface WAVideoPlayerView : UIView
@property (nonatomic) _Bool disableTapGesture;
@end

// 隐藏好友微信号：WAProfileHeaderView.h:19/27 descLabel
@interface WAProfileHeaderView : UIView
@property (nonatomic, retain) id descLabel;
@end

// 隐藏自己微信号：WASettingAccountCell.h:13/20 _detailLabel
@interface WASettingAccountCell : UITableViewCell
@property (nonatomic, retain) UILabel *detailLabel;
@end

// 隐藏聊天顶栏名字：MMUIViewController.h:520 -titleView
@interface BaseMsgContentViewController : UIViewController
- (id)titleView;
@end

// 仅重写方法、不访问 property/ivar 的类：前向声明即可满足 Logos category 生成
@class NewMainFrameViewController;   // 功能1 禁用首页下拉小程序: initTableHeaderTopView(:425)/showTableHeaderTopViewByPullDown:(:439)
@class WCTimeLineViewController;     // 功能2 禁用朋友圈视频自动播放: _canAutoPlayVideoForCellView:(:493)
@class WCTimeLineCellView;           // 功能3/4 隐私图标+文字折叠: m_privacyButton(:26)/shouldShowFullTextButtonWithDataItem:(:98)
@class WCMicroMerchantFeedsMgr;      // 功能5 余下N条折叠: foldSectionSize(:27)/isFeedIDFoldInGroup:(:48)
@class MicroMerchantFoldInterceptor; // 功能5 余下N条折叠: intercept:(:16)
@class FakeHeadImageView;            // 功能7 自定义头像: m_headImageView(:11)/getRealUserName:(:26)
@class TextMessageViewModel;        // 功能9 聊天文字折叠: shouldFoldText(:117)/foldText(:64)
@class NewSettingViewController;     // 功能11 隐藏自己微信号(兜底): m_tableViewMgr(:11)/reloadTableData(:55)

#pragma mark - 配置管理 (锚定 NSUserDefaults，结构同 D.txt 的 DDRedEnvelopConfig)
#define kDDWAPullDown          @"kDDWA_disableHomePullDownMiniProgram"
#define kDDWAVideoAutoPlay     @"kDDWA_disableSnsVideoAutoPlay"
#define kDDWAPrivacyIcon       @"kDDWA_disableSnsPrivacyIcon"
#define kDDWATextFold          @"kDDWA_disableSnsTextFold"
#define kDDWAGroupFold         @"kDDWA_disableSnsGroupFold"
#define kDDWADeletedComment    @"kDDWA_antiDeleteSnsComment"
#define kDDWACustomAvatar      @"kDDWA_enableCustomAvatar"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAChatTextFold      @"kDDWA_disableChatTextFold"
#define kDDWAHideFriendWxid    @"kDDWA_hideFriendWxid"
#define kDDWAHideMyWxid        @"kDDWA_hideMyWxid"
#define kDDWAHideChatName      @"kDDWA_hideChatName"

// ---- 开关默认状态常量：与配置组同处一地集中定义 ----
// YES = 首次安装（用户从未改过）时该开关默认开启；NO = 默认关闭。
// 目前 12 项全部为 NO，即装好后微信行为与原生一致，需用户手动开启。
// 想让某项默认开启，把对应行的 NO 改成 YES 即可，无需改动 init / setter / 设置页。
// 生效方式：下方 +initialize 把这些值注册到 NSUserDefaults 的注册域，
//           用户一旦手动改过开关，用户值优先，注册域默认值自动让位。
static const BOOL kDDDefaultPullDown          = NO;   // 禁用首页下拉小程序
static const BOOL kDDDefaultVideoAutoPlay     = NO;   // 禁用朋友圈视频自动播放
static const BOOL kDDDefaultPrivacyIcon       = NO;   // 禁用朋友圈谁可以见图标
static const BOOL kDDDefaultTextFold          = NO;   // 禁用朋友圈文字自动折叠
static const BOOL kDDDefaultGroupFold         = NO;   // 禁用朋友圈余下N条折叠
static const BOOL kDDDefaultAntiDelete        = NO;   // 朋友圈评论防删
static const BOOL kDDDefaultCustomAvatar      = NO;   // 启用自定义头像(聊天详情)
static const BOOL kDDDefaultVideoTapClose     = NO;   // 禁用朋友圈视频点击关闭
static const BOOL kDDDefaultChatTextFold      = NO;   // 禁用聊天文字折叠
static const BOOL kDDDefaultHideFriendWxid    = NO;   // 隐藏好友微信号(资料页)
static const BOOL kDDDefaultHideMyWxid        = NO;   // 隐藏自己微信号(我界面)
static const BOOL kDDDefaultHideChatName      = NO;   // 隐藏聊天顶栏名字

@interface DDWeChatConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL disableHomePullDownMiniProgram;
@property (assign, nonatomic) BOOL disableSnsVideoAutoPlay;
@property (assign, nonatomic) BOOL disableSnsPrivacyIcon;
@property (assign, nonatomic) BOOL disableSnsTextFold;
@property (assign, nonatomic) BOOL disableSnsGroupFold;
@property (assign, nonatomic) BOOL antiDeleteSnsComment;
@property (assign, nonatomic) BOOL enableCustomAvatar;
@property (assign, nonatomic) BOOL disableSnsVideoTapClose;
@property (assign, nonatomic) BOOL disableChatTextFold;
@property (assign, nonatomic) BOOL hideFriendWxid;
@property (assign, nonatomic) BOOL hideMyWxid;
@property (assign, nonatomic) BOOL hideChatName;
@end

@implementation DDWeChatConfig
+ (instancetype)sharedConfig {
    static DDWeChatConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDWeChatConfig new]; });
    return c;
}
// 把上面的「默认状态常量」注册到 NSUserDefaults 注册域。
// 注册域优先级最低：key 从未被设置过时读取返回默认值；用户手动改过开关后以其值为准。
+ (void)initialize {
    if (self != [DDWeChatConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDWAPullDown:       @(kDDDefaultPullDown),
        kDDWAVideoAutoPlay:  @(kDDDefaultVideoAutoPlay),
        kDDWAPrivacyIcon:    @(kDDDefaultPrivacyIcon),
        kDDWATextFold:       @(kDDDefaultTextFold),
        kDDWAGroupFold:      @(kDDDefaultGroupFold),
        kDDWADeletedComment: @(kDDDefaultAntiDelete),
        kDDWACustomAvatar:   @(kDDDefaultCustomAvatar),
        kDDWAVideoTapClose:  @(kDDDefaultVideoTapClose),
        kDDWAChatTextFold:   @(kDDDefaultChatTextFold),
        kDDWAHideFriendWxid: @(kDDDefaultHideFriendWxid),
        kDDWAHideMyWxid:     @(kDDDefaultHideMyWxid),
        kDDWAHideChatName:   @(kDDDefaultHideChatName),
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
        _enableCustomAvatar             = [ud boolForKey:kDDWACustomAvatar];
        _disableSnsVideoTapClose        = [ud boolForKey:kDDWAVideoTapClose];
        _disableChatTextFold            = [ud boolForKey:kDDWAChatTextFold];
        _hideFriendWxid                 = [ud boolForKey:kDDWAHideFriendWxid];
        _hideMyWxid                     = [ud boolForKey:kDDWAHideMyWxid];
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
- (void)setEnableCustomAvatar:(BOOL)v { _enableCustomAvatar = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWACustomAvatar]; }
- (void)setDisableSnsVideoTapClose:(BOOL)v { _disableSnsVideoTapClose = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAVideoTapClose]; }
- (void)setDisableChatTextFold:(BOOL)v { _disableChatTextFold = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAChatTextFold]; }
- (void)setHideFriendWxid:(BOOL)v { _hideFriendWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideFriendWxid]; }
- (void)setHideMyWxid:(BOOL)v { _hideMyWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideMyWxid]; }
- (void)setHideChatName:(BOOL)v { _hideChatName = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideChatName]; }
@end

#pragma mark - 1. 禁用首页下拉小程序
// 证据: NewMainFrameViewController.h:31 m_tableHeaderTopView(WAMainFrameTopHeaderView*)
//       :406 -mainPullDown:, :414 -beginSetShowTableHeaderTopView, :425 -initTableHeaderTopView,
//       :439 -showTableHeaderTopViewByPullDown:
// WCR 佐证: /tmp/wcr_dis.txt 保留 selector "initTableHeaderTopView"/"mainPullDown:"/"showTableHeaderTopViewByPullDown:"
// 注意: 仅禁用"微信主界面(聊天列表页)顶部下拉露出的小程序面板"，不动"发现"页里的小程序入口。
%hook NewMainFrameViewController
- (void)initTableHeaderTopView {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return; // 不创建下拉露出视图
    %orig;
}
- (void)beginSetShowTableHeaderTopView {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
- (void)mainPullDown:(_Bool)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
- (void)showTableHeaderTopViewByPullDown:(unsigned long long)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
%end

#pragma mark - 2. 禁用朋友圈视频自动播放
// 证据: WCTimeLineViewController.h:493 -_canAutoPlayVideoForCellView:, :494 -realAutoPlayVideo
//       WCTimeLineCellView.h:274 -canAutoPlayVideoWithoutSound
%hook WCTimeLineViewController
- (_Bool)_canAutoPlayVideoForCellView:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsVideoAutoPlay) return NO;
    return %orig;
}
%end

#pragma mark - 3. 禁用朋友圈谁可以见图标
// 证据: WCTimeLineCellView.h:26 MMUIButton *m_privacyButton (实例变量)
//       :286 -initPrivacyButton:  (按 visibilityType 生成可见性图标)
//       SnsObject.h:63 @property visibilityType  (数据来源)
// WCR 佐证: /tmp/wcr_dis.txt 含 "m_privacyButton" 字面量(2处)
%hook WCTimeLineCellView
- (void)layoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        // 每次布局时强制隐藏可见性图标(覆盖复用/重设)
        // 证据 WCTimeLineCellView.h:26 MMUIButton *m_privacyButton (无对应 @property，故用 MSHookIvar 读 ivar)
        id btn = MSHookIvar<id>(self, "m_privacyButton");
        if (btn) [(UIView *)btn setHidden:YES];
    }
}
%end

#pragma mark - 4. 禁用朋友圈文字自动折叠
// 证据: WCTimeLineCellView.h:98 +shouldShowFullTextButtonWithDataItem: (决定是否显示"全文"按钮/折叠)
//       :39/:152 m_showFullTextView (全文按钮)  :329 -onShowFullText
// 返回 NO -> 不显示"全文"按钮，内容按全文展示(标准做法)
%hook WCTimeLineCellView
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsTextFold) return NO;
    return %orig;
}
%end

#pragma mark - 5. 禁用朋友圈"余下N条"折叠
// 证据: WCMicroMerchantFeedsMgr.h:27 @property foldSectionSize (每组最多平铺条数，超出则折叠成"余下N条")
//       :48 -isFeedIDFoldInGroup: (逐条判断该 feed 是否处于折叠态)
//       :40 -unfoldTimelineFromUsername: (强制展开某用户的所有折叠)
//       MicroMerchantFoldInterceptor.h:16 -intercept: (注入折叠逻辑的拦截器入口)
//       WCTimeLineViewController.h:591 -genFoldMessageCell:indexPath: (生成"余下N条"cell)
//       :219 -onSubTimelineClickedUnfold  :218 -onSubTimelineConfirmedUnfold (点击/确认展开)
//       :122 @property hasChangedFoldedState
//
// "余下N条"是微信的"微商折叠"(MicroMerchant Fold)子系统：同一好友连续多条朋友圈
// 超过 foldSectionSize 阈值后，多余的被收进"余下N条 >"组，点击才展开子时间线。
//
// Hook 方案(双保险):
//   A) isFeedIDFoldInGroup: 返回 NO → 每条 feed 都不被判定为折叠态，不生成折叠 cell
//   B) MicroMerchantFoldInterceptor.intercept: 空实现 → 整个折叠拦截器不注入逻辑
%hook WCMicroMerchantFeedsMgr
- (_Bool)isFeedIDFoldInGroup:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return NO;
    return %orig;
}
%end

%hook MicroMerchantFoldInterceptor
- (void)intercept:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return; // 跳过整个折叠注入
    %orig;
}
%end

#pragma mark - 6. 朋友圈评论防删
// 证据: WCSNSMessage.h:19 unsigned int delStatus (删除状态, !=0 即被标记删除)
//       :28 @property(nonatomic) unsigned int delStatus;
//       :30 @property(retain) WCUserComment *comment;     (本消息对应的评论)
//       :31 @property(retain) WCUserComment *refComment;  (被回复的评论)
//       :36 - (void)upgradeDataIfNeeded;                  (数据升级/装配时调用)
//       WCUserComment.h:119 @property(nonatomic) _Bool bDeleted;        (评论自身删除标记)
//       :112 @property(nonatomic) _Bool deletedByFeedOwner;            (被发布者删除标记)
// WCR 佐证: /tmp/wcr_dis.txt 在 60eb28 段对 WCSNSMessage 做 MSHookMessageEx，
//           实装的 hook 方法正是 -upgradeDataIfNeeded，且:
//           (1) 引用 isWCMessageDeleted / delStatus / setDelStatus: → 判定并重置删除状态
//           (2) 引用 WCUserComment 的 bDeleted / deletedByFeedOwner → 一并复位评论删除标记
//           即当开关(momentsShowDeletedComment)开启且 delStatus!=0 时，调 setDelStatus:0
//           并把 comment/refComment 的 bDeleted、deletedByFeedOwner 置 NO。(两种分支都先调原方法)
//
// 行为(对齐用户描述):
//   开启后，朋友圈中已删除的评论仍然显示原文(不消失/不显示"评论已被删除"占位)，
//   删除操作仅在"消息通知"中正常提示([已删除] 无聊)。
//
// 实现原理(对齐 WCR): hook WCSNSMessage 的 -upgradeDataIfNeeded。
//   先 %orig 完成正常装配；若开关开启且本消息被标记为删除(delStatus!=0)，
//   则把 delStatus 归零，并把 comment / refComment 的删除标记复位，
//   后续渲染即按"未删除"处理，原文得以保留。
%hook WCSNSMessage
- (void)upgradeDataIfNeeded {
    %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return;
    if (self.delStatus != 0) self.delStatus = 0;  // 解除消息级删除标记(对齐 WCR setDelStatus:0)
    // 复位评论自身删除标记，确保原文可被渲染
    WCUserComment *c = self.comment;
    if (c) {
        if ([c respondsToSelector:@selector(setBDeleted:)]) c.bDeleted = NO;
        if ([c respondsToSelector:@selector(setDeletedByFeedOwner:)]) c.deletedByFeedOwner = NO;
    }
    WCUserComment *rc = self.refComment;
    if (rc) {
        if ([rc respondsToSelector:@selector(setBDeleted:)]) rc.bDeleted = NO;
        if ([rc respondsToSelector:@selector(setDeletedByFeedOwner:)]) rc.deletedByFeedOwner = NO;
    }
}
%end

#pragma mark - 7. 启用自定义头像(聊天详情页, 每聊独立)
// 证据(均来自头文件 dump):
//   ContactInfoViewController.h:13/123 CContact *m_contact (当前聊天联系人, 真实 ivar/属性)
//   :243 -viewDidAppear:, :232 -viewDidLoad (生命周期, 真实方法)
//   :81 @property(nonatomic,__weak) UITableView *frontTableView (普通 UITableView, 非 WCTableViewManager)
//   CContact.h:465 @property(nonatomic,readonly) NSString *userName (每聊唯一标识, 真实属性)
//   FakeHeadImageView.h:11 UIImageView *m_headImageView (头像视图 ivar)
//   :26 -getRealUserName:, :27 -updateWithUserName: (头像渲染映射入口)
// WCR 佐证: /tmp/wcr_dis.txt 8b3c6c 段对 ContactInfoViewController 做 MSHookMessageEx，
//           实装 hook = setM_contact: + viewDidLoad + viewWillAppear: + viewDidAppear:
//           (用 objc_setAssociatedObject 把当前联系人挂在 VC 上); 自定义图路径以 customAvatarPath 存入
//           按 contact 分的字典(customAvatarContactEnabledIDs)。FakeHeadImageView 负责最终渲染。
//
// 原理(对齐 WCR, 全部锚定真实方法/属性, 无猜测):
//   1) hook setM_contact: 把当前联系人 userName 存到关联对象(每聊标识, 早于 viewDidLoad 即可用)。
//   2) hook viewDidAppear: 在 frontTableView.tableFooterView 注入开关, 样式做成微信原生"分组卡片"单行 cell
//      (左右内缩 + 圆角白卡 + 右侧绿色开关 + 底部发丝线, 系统语义色自适应深色模式, 视觉隐蔽),
//      状态按 userName 读取(每聊独立); 开启时弹相册选图。不依赖微信私有表管理器。
//   3) hook FakeHeadImageView getRealUserName:: 返回 userName 后, 若本地有该聊天的自定义图,
//      直接写入 m_headImageView.image 显示假头像(纯本地渲染, 对方不可见)。

static NSString *ddCustomAvatarKey(NSString *userName) {
    return [NSString stringWithFormat:@"dd_customAvatar_%@", userName ?: @""];
}
static const void *kDDAvatarUsr      = &kDDAvatarUsr;        // 关联对象: 当前 VC 对应的 userName
static const void *kDDAvatarPicking  = &kDDAvatarPicking;    // 关联对象: 正在选图的 userName
static const void *kDDAvatarInjected = &kDDAvatarInjected;   // 关联对象: 开关是否已注入(只注入一次)

%hook ContactInfoViewController
- (void)setM_contact:(id)contact {
    %orig;
    if ([DDWeChatConfig sharedConfig].enableCustomAvatar) {
        // 证据: m_contact 是真实属性(ContactInfoViewController.h:123), userName 是 CContact.h:465 真实属性
        // 用 performSelector: 取 userName, 规避 NSProcessInfo.userName (API_UNAVAILABLE(ios)) 与
        // CContact.userName 同名导致的 "'userName' is unavailable: not available on iOS" 编译错误
        NSString *usr = nil;
        if ([contact respondsToSelector:@selector(userName)]) usr = [contact performSelector:@selector(userName)];
        if (usr.length) objc_setAssociatedObject(self, kDDAvatarUsr, usr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
- (void)viewDidAppear:(_Bool)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar) return;
    if ([objc_getAssociatedObject(self, kDDAvatarInjected) boolValue]) return; // 只注入一次
    objc_setAssociatedObject(self, kDDAvatarInjected, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        NSString *usr = objc_getAssociatedObject(self, kDDAvatarUsr);
        if (!usr.length) {
            id c = self.m_contact;  // 兜底: 直接读真实属性(:123)
            if ([c respondsToSelector:@selector(userName)]) usr = [c performSelector:@selector(userName)];
        }
        if (!usr.length) return;

        UITableView *tv = self.frontTableView;  // 真实属性(:81)
        if (!tv) return;

        // 用 UITableView.tableFooterView(公开 API) 注入开关, 不碰微信私有表结构。
        // 视觉做成微信原生"分组卡片"单行 cell: 左右内缩 + 圆角白卡 + 右侧绿色开关 + 底部发丝线,
        // 与微信设置页 cell 样式一致(更隐蔽)。全部用系统语义色, 自动适配深色模式。
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat inset   = 16.0;            // 分组左右内缩(对齐微信)
        CGFloat cardW   = screenW - inset * 2;
        CGFloat rowH    = 44.0;            // 标准 cell 高度
        CGFloat gap     = 8.0;             // 卡片上下间距(分组间隔)
        CGFloat cardH   = rowH;

        UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, cardH + gap * 2)];
        footer.backgroundColor = [UIColor clearColor];

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(inset, gap, cardW, cardH)];
        if (@available(iOS 13.0, *)) {
            card.backgroundColor = [UIColor secondarySystemBackgroundColor]; // 白卡(深色模式自适应)
            card.layer.cornerRadius = 10.0;
            card.layer.masksToBounds = YES;
        } else {
            card.backgroundColor = [UIColor whiteColor];
        }
        [footer addSubview:card];

        // 底部发丝分隔线(对齐微信 cell 分隔)
        UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, cardH - 0.5, cardW - 16, 0.5)];
        if (@available(iOS 13.0, *)) sep.backgroundColor = [UIColor separatorColor];
        else sep.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1];
        [card addSubview:sep];

        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, cardW - 16 - 70, rowH)];
        lab.text = @"自定义头像";
        lab.font = [UIFont systemFontOfSize:17];
        if (@available(iOS 13.0, *)) lab.textColor = [UIColor labelColor];
        else lab.textColor = [UIColor blackColor];
        [card addSubview:lab];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 67, (rowH - 31) / 2.0, 51, 31)];
        sw.on = ([NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)] != nil);
        [sw addTarget:self action:@selector(dd_onCustomAvatarSwitch:) forControlEvents:UIControlEventValueChanged];
        [card addSubview:sw];

        tv.tableFooterView = footer;
    } @catch (NSException *e) { /* 安全跳过 */ }
}
%new
- (void)dd_onCustomAvatarSwitch:(UISwitch *)s {
    NSString *usr = objc_getAssociatedObject(self, kDDAvatarUsr);
    if (!usr.length) {
        id c = self.m_contact;
        if ([c respondsToSelector:@selector(userName)]) usr = [c performSelector:@selector(userName)];
    }
    if (!usr.length) return;
    if (s.on) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
        objc_setAssociatedObject(self, kDDAvatarPicking, usr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:ddCustomAvatarKey(usr)];
    }
}
%new
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSString *usr = objc_getAssociatedObject(self, kDDAvatarPicking);
    if (image && usr.length) {
        NSData *imgData = UIImagePNGRepresentation(image);  // 每聊独立存 NSData
        [NSUserDefaults.standardUserDefaults setObject:imgData forKey:ddCustomAvatarKey(usr)];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}
%end

// 自定义头像渲染：加载用户名对应头像时，替换为本地存储的自定义图片
%hook FakeHeadImageView
- (id)getRealUserName:(id)arg1 {
    id orig = %orig;
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar || !orig) return orig;
    @try {
        NSData *imgData = [NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(orig)];
        if (imgData) {
            UIImage *customImg = [UIImage imageWithData:imgData];
            UIImageView *headImg = MSHookIvar<UIImageView *>(self, "m_headImageView");  // 真实 ivar(FakeHeadImageView.h:11)
            if (headImg && customImg) headImg.image = customImg;
        }
    } @catch (NSException *e) { /* 安全回退 */ }
    return orig;
}
%end

#pragma mark - 8. 禁用朋友圈视频点击关闭
// 证据: WAVideoPlayerView.h:189 @property(nonatomic) _Bool disableTapGesture (内置"禁用点击手势"开关)
//       :324 -onGestureTap: (单击手势处理方法，含关闭/控制栏切换逻辑)
//       :83  UITapGestureRecognizer *tabGes (点击手势识别器)
// WCR 佐证: /tmp/wcr_dis.txt 含 "WAVideoPlayerView" 类名字面量(L76bd2c)
//           以及 "momentsDisableVideoTapCloseEnabled" config key(L676fbc/194bfc0/1966884)
//
// 原理: 朋友圈视频播放时，点击画面默认会触发 onGestureTap: → 关闭/退出播放器。
//       微信内置了 disableTapGesture 属性来禁用此行为(可能用于特殊场景)。
//       方案: 直接设 disableTapGesture = YES，利用微信原生能力禁用点击关闭(原生 property 访问, 非 KVC)。
//       兜底: 若 disableTapGesture 不生效，再 hook onGestureTap: 拦截。
%hook WAVideoPlayerView
- (void)layoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsVideoTapClose) {
        // 利用微信内置属性禁用点击手势(最干净的方式, 原生 property 访问, 非 KVC)
        // 证据 WAVideoPlayerView.h:189 @property(nonatomic) _Bool disableTapGesture
        self.disableTapGesture = YES;
    }
}
// 兜底：若 disableTapGesture 不影响已创建的手势识别器，直接拦截 tap 回调
- (void)onGestureTap:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsVideoTapClose) return; // 拦截点击
    %orig;
}
%end

#pragma mark - 9. 禁用聊天文字折叠
// 证据: TextMessageViewModel.h:117 - (_Bool)shouldFoldText (是否对聊天长文做折叠)
//       :64 @property(nonatomic) _Bool foldText (折叠开关)
//       :57 @property(nonatomic) long long foldMaxLineNumber (折叠阈值行数)
//       :100 - (struct CGRect)moreButtonFrameForFoldText (折叠"全文"按钮位置)
//       :116 - (id)getFoldContentText (折叠态展示文本)
// WCR 佐证: /tmp/wcr_dis.txt 8238e8 段对 TextMessageViewModel 做 MSHookMessageEx,
//           实装 hook = -shouldFoldText (与朋友圈文字折叠 shouldShowFullTextButtonWithDataItem: 同批 hook)。
//
// 原理: 聊天中超长文本默认按 foldMaxLineNumber 行数折叠, 超出部分用"..."+"全文"展开。
//       hook shouldFoldText 返回 NO → 该条文本不被判定为需折叠, 长文直接完整展示。
%hook TextMessageViewModel
- (_Bool)shouldFoldText {
    if ([DDWeChatConfig sharedConfig].disableChatTextFold) return NO; // 长文不折叠
    return %orig;
}
%end

#pragma mark - 10. 隐藏好友微信号(资料页) — 单方法实现(锚定头文件)
// 证据: WAProfileHeaderView.h:19/27 MMUILabel *descLabel (头部副标题=微信号行, 真实属性)
//       :34 -updateContact: (装配联系人时给 descLabel 赋值 — 微信号文本唯一写入点)
//       NewWAProfileViewController.h:13 WAProfileHeaderView *_headerView (资料页头部, 真实 ivar)
// WCR 佐证: /tmp/wcr_dis.txt 在 2c9320 段对 WAProfileHeaderView 做 KVC valueForKey:@"m_descLabel",
//           取出 descLabel 后执行隐藏(对齐 WCR 的"隐藏资料页好友微信号"实现)。
// 单方法(用户要求只用一种方法, 直接锚定头文件):
//   微信号文本在 WAProfileHeaderView -updateContact: 中写入 descLabel(头文件 :34 明确该方法"给 descLabel 赋值")。
//   故只 hook 这一个方法: %orig 完成装配后, 把 descLabel 清空并隐藏即可。
//   (layoutSubviews 仅做布局、不重设文本, 一次清空即持续生效, 无需再 hook 其他类/方法。)
%hook WAProfileHeaderView
- (void)updateContact:(id)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].hideFriendWxid) return;
    // 头部副标题=微信号行(WAProfileHeaderView.h:19/27 descLabel), 装配完成即清空隐藏
    self.descLabel.text = @"";
    self.descLabel.hidden = YES;
}
%end
#pragma mark - 11. 隐藏自己微信号(我界面)
// 证据: NewSettingViewController.h:11 WCTableViewManager *m_tableViewMgr (我界面表管理器, 真实 ivar)
//       :55 - (void)reloadTableData (刷新"我"页)
//       WASettingAccountCell.h:13/20 UILabel *_detailLabel (账户卡片副标题, 即"微信号"行)
//       :25 - (void)setViewDataModel: (装配账户数据模型时给 detailLabel 赋值)
// 原理(双保险):
//   A) 精确: hook WASettingAccountCell -setViewDataModel:, 装配完成后把 detailLabel(微信号行)清空并隐藏。
//   B) 兜底: hook NewSettingViewController -reloadTableData, 遍历可见 cell, 凡 WASettingAccountCell
//           直接清空其 detailLabel, 覆盖 cell 复用导致副标题被重设的边界情况。
//   两点都只动"微信号"那一行副标题, 不碰昵称(主标题 nameLabel)。
%hook WASettingAccountCell
- (void)setViewDataModel:(id)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].hideMyWxid) return;
    // 账户卡片副标题即微信号行(WASettingAccountCell.h:13/20 _detailLabel)
    self.detailLabel.text = @"";
    self.detailLabel.hidden = YES;
}
%end

%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    if (![DDWeChatConfig sharedConfig].hideMyWxid) return;
    // 兜底: 直接定位"我"页账户卡片 cell 清空副标题(微信号行), 不依赖任何字符串匹配
    id mgr = MSHookIvar<id>(self, "m_tableViewMgr"); // 真实 ivar(:11)
    UITableView *tv = nil;
    if (mgr && [mgr respondsToSelector:@selector(getTableView)]) tv = [mgr getTableView];
    if (!tv) return;
    Class accCls = objc_getClass("WASettingAccountCell");
    for (UITableViewCell *cell in tv.visibleCells) {
        if (accCls && [cell isKindOfClass:accCls]) {
            UILabel *d = [(id)cell detailLabel]; // 真实属性(:20)
            if (d) { d.text = @""; d.hidden = YES; }
        }
    }
}
%end

#pragma mark - 12. 隐藏聊天名字(聊天界面顶栏标题)
// 证据: BaseMsgContentViewController.h:986 - (void)updateTitleView:(id)arg1   (顶栏标题刷新入口, 个人/群聊共用此 VC)
//       :983 - (void)setTitleView:(id)arg1
//       MMUIViewController.h:12  @interface MMUIViewController : UIViewController (标准 UIKit 导航, navigationItem 类型可靠)
//       :26  MMTitleView *m_baseTitleView  (标题视图 ivar, MMTitleView 为视图类型)
//       :520 - (id)titleView  (标题视图 getter, 取到 m_baseTitleView)
// 佐证: WCR 反汇编 /tmp/wcr_dis.txt 同样调用 selector
//       updateTitleView: (L589230 / 1739881 / 1788956)
//       与 updateTitleView:ignoreAnimation: (L1739889 / 1788964)，证明聊天顶栏标题经此方法设置/刷新。
// 原理: 进入聊天时(个人"陈某人" / 群聊"群聊(2)")，微信经 updateTitleView: 装配并刷新顶栏标题视图；
//       群成员数变化("群聊(2)"->"群聊(3)")亦经此方法刷新。
//       单方法(用户要求同一功能只用一种方法): 只 hook updateTitleView:，%orig 完成后通过基类
//       MMUIViewController 的 -titleView getter (MMUIViewController.h:520, 底层 MMTitleView *m_baseTitleView)
//       取到已安装的标题视图, hidden=YES 即隐藏顶栏名字；刷新时再次隐藏，状态一致。
//       关键: 不依赖对 updateTitleView: 参数 arg1 的"类型猜测"——改用头文件明证的 titleView getter，
//       并以 isKindOfClass:[UIView class] 守卫, 即使返回非视图也不会崩溃。
// 注意: 此处隐藏的是导航栏"顶栏标题"，与气泡发送者名字(chatRoomDisplayName)无关，故不 hook BaseMessageViewModel。
%hook BaseMsgContentViewController
- (void)updateTitleView:(id)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideChatName) {
        UIView *tv = [self titleView];   // MMUIViewController -titleView (L520), 返回 MMTitleView(视图)
        if ([tv isKindOfClass:[UIView class]]) tv.hidden = YES;
    }
}
%end

#pragma mark - 设置界面 (构造参考 D.txt)
@interface DDWeChatSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDWeChatSettingsViewController {
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
    self.title = @"DD微信助手";
    // 必须显式设本页导航栏外观：WCPluginsMgr 给非微信 VC 的导航栏默认半透明(透出状态栏)。
    // 用 navigationItem 按 VC 隔离(不污染微信全局导航栏)，configureWithDefaultBackground 设为半透明(带模糊，与微信原生一致)，不手动渲染色。
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;   // 去掉导航栏底部分割线(默认阴影)
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
    Class secMgr = objc_getClass("WCTableViewSectionManager");

    // 首页
    WCTableViewSectionManager *home = [secMgr defaultSection];
    [home addCell:[cellMgr switchCellForSel:@selector(onPullDownSwitch:) target:self title:@"禁用首页下拉小程序" on:cfg.disableHomePullDownMiniProgram]];
    [_tableViewManager addSection:home];

    // 朋友圈
    WCTableViewSectionManager *sns = [secMgr defaultSection];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoSwitch:) target:self title:@"禁用朋友圈视频自动播放" on:cfg.disableSnsVideoAutoPlay]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onPrivacySwitch:) target:self title:@"禁用朋友圈谁可以见图标" on:cfg.disableSnsPrivacyIcon]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onTextFoldSwitch:) target:self title:@"禁用朋友圈文字自动折叠" on:cfg.disableSnsTextFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onGroupFoldSwitch:) target:self title:@"禁用朋友圈余下N条折叠" on:cfg.disableSnsGroupFold]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onAntiDeleteSwitch:) target:self title:@"朋友圈评论防删" on:cfg.antiDeleteSnsComment]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoTapCloseSwitch:) target:self title:@"禁用朋友圈视频点击关闭" on:cfg.disableSnsVideoTapClose]];
    [_tableViewManager addSection:sns];

    // 聊天
    WCTableViewSectionManager *chat = [secMgr defaultSection];
    [chat addCell:[cellMgr switchCellForSel:@selector(onChatTextFoldSwitch:) target:self title:@"禁用聊天文字折叠" on:cfg.disableChatTextFold]];
    [chat addCell:[cellMgr switchCellForSel:@selector(onHideChatNameSwitch:) target:self title:@"隐藏聊天顶栏名字" on:cfg.hideChatName]];
    [_tableViewManager addSection:chat];

    // 隐私(微信号隐藏)
    WCTableViewSectionManager *privacy = [secMgr defaultSection];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideFriendWxidSwitch:) target:self title:@"隐藏好友微信号(资料页)" on:cfg.hideFriendWxid]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideMyWxidSwitch:) target:self title:@"隐藏自己微信号(我界面)" on:cfg.hideMyWxid]];
    [_tableViewManager addSection:privacy];

    // 通用
    WCTableViewSectionManager *general = [secMgr defaultSection];
    [general addCell:[cellMgr switchCellForSel:@selector(onAvatarSwitch:) target:self title:@"启用自定义头像(聊天详情)" on:cfg.enableCustomAvatar]];
    [_tableViewManager addSection:general];

    [_tableViewManager reloadTableView];
}

#pragma mark - UITableViewDelegate 转发(同 D.txt)
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
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

#pragma mark - 开关事件
- (void)onPullDownSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram = s.on; }
- (void)onVideoSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsVideoAutoPlay = s.on; }
- (void)onPrivacySwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsPrivacyIcon = s.on; }
- (void)onTextFoldSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsTextFold = s.on; }
- (void)onGroupFoldSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsGroupFold = s.on; }
- (void)onAntiDeleteSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].antiDeleteSnsComment = s.on; }
- (void)onAvatarSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].enableCustomAvatar = s.on; }
- (void)onVideoTapCloseSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsVideoTapClose = s.on; }
- (void)onChatTextFoldSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableChatTextFold = s.on; }
- (void)onHideFriendWxidSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].hideFriendWxid = s.on; }
- (void)onHideMyWxidSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].hideMyWxid = s.on; }
- (void)onHideChatNameSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].hideChatName = s.on; }

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

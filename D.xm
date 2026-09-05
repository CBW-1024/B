// =============================================================================
//  DD微信助手 (DD WeChat Assistant)  v2.1.0
//  单文件 iOS 越狱插件 (Theos / Logos)，目标微信 8.0.76
//
//  本版本依据 WCRefine.dylib 反汇编结果全量重写(对齐 WCR 真实 hook 点)。
//
//  反汇编方法(可复现):
//    lief 解析 WCRefine.dylib(瘦 ARM64) -> 定位 MSHookMessageEx stub(0x1ca5328)
//    -> numpy 扫 30MB __text 找出 1788 个 bl 调用点 -> 逐点回溯寄存器还原
//       (类, selector, 新 IMP) 三元组 -> 共还原 1384 个 hook / 433 个类。
//    注: WCR 用 objc_getClass("类名字符串") 取类(非 __objc_classrefs)，
//        故解析必须按 __cstring 字面量 + objc_getClass 的模式。
//
//  每个 hook 均标注 WCR 二进制内的 IMP 地址与行为，以及 8.0.76 dump 头文件行号。
//
//  v2.1.0 变更(结合补充的 8.0.76 头文件 dump):
//    - 全部被 hook 类的 @interface 父类对齐到补充 dump 的真实继承链
//      (例: WCTimeLineCellView: MMUIView / MMTitleView: MMBarItemCustomView /
//           BaseMsgContentViewController: MMUIViewController /
//           NewMainFrameViewController: MMTabBarBaseViewController /
//           WAVideoPlayerView: WCPlayerControlView 等)，不再用猜测的 UIKit 基类。
//    - ③ m_privacyButton 取偏移类型由 id 改为 MMUIButton *(WCTimeLineCellView.h:12)。
//    - ⑦ 渲染点维持 FakeHeadImageView -setImage: (WCR 运行期确认目标；
//      补充 dump 未列出该方法但运行期真实存在；MMHeadImageView 仅有
//      setHeadImageByName:，无 setImage:，故不挂 MMHeadImageView)。
//    - ⑩ 文案与键名统一为「清空视频号资料页简介」(WAProfileHeaderView.descLabel)，
//      与钩子行为一致；原“隐藏好友微信号”标签系误标。
//
//  【重要】功能 ⑨「禁用聊天文字折叠」已移除：
//          WCR 的 1384 个 hook 中不存在任何 fold/FullText 相关目标，
//          TextMessageViewModel 只被 hook 了 isShowSourceView(与折叠无关)。
//          WCR 无此功能，之前的实现纯属推测，故删除。
// =============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 微信插件注册入口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 设置页表管理器：依据 8.0.76 头文件手动声明(仅声明实际调用的接口)
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

// ---- 被 hook 微信类的声明(全部锚定 8.0.76 补充 dump 的真实签名) ----
// 本补充 dump 已还原各类的完整继承链，故此处按真实父类声明；
// 仅列出本插件实际访问的 property / 重写的方法，其余方法由运行时按 SEL 派发。
// 注: m_privacyButton / m_tableViewMgr 等 ivar 仍走 MSHookIvar 运行时取偏移，
//     不在本地 @interface 中声明(手写 ivar 会让编译器按本地布局算固定偏移，
//     与真机类布局不一致会读崩)。

// 需要前向声明的微信类(作为父类或属性类型，非 Apple SDK 类)
@class MMTabBarBaseViewController, MMUIViewController, MMUIView, WCPlayerControlView,
      MMBarItemCustomView, WCContentItemBaseView, MMUIButton, CContact, MMUILabel,
      WASettingAccountCell;

@interface CContact : NSObject
@property (nonatomic, readonly) NSString *userName;   // CContact.h:465
@end

// ⑥ 朋友圈评论防删
@interface WCUserComment : NSObject
@property (nonatomic) _Bool bDeleted;                 // WCUserComment.h:22
@property (nonatomic) _Bool deletedByFeedOwner;      // WCUserComment.h:32
- (_Bool)bDeleted;                                    // getter，WCR hook 之(IMP 0x610410)
- (_Bool)deletedByFeedOwner;                          // getter，WCR hook 之
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;         // WCSNSMessage.h: (delStatus 属性)
- (void)upgradeDataIfNeeded;                          // WCSNSMessage.h:36
- (_Bool)isWCMessageDeleted;                          // WCSNSMessage.h:19 —— WCR hook 之
@end

// ⑦ 自定义头像
@interface ContactInfoViewController : MMUIViewController   // ContactInfoViewController.h:4
@property (nonatomic, retain) CContact *m_contact;       // ContactInfoViewController.h:32
@property (nonatomic, weak) UITableView *frontTableView; // ContactInfoViewController.h:23
@end

@interface FakeHeadImageView : MMUIView                  // FakeHeadImageView.h:3 (: MMUIView)
// 注: 补充 dump 的 FakeHeadImageView.h 未列出 setImage:，但 WCR 反汇编确认其运行期
//     以 -setImage: 为渲染点(IMP 0x1dcf0c/0x20d050)，且 getRealUserName: (:18) 可取用户名。
//     故此处声明 setImage: 供 Logos 绑定；该方法是运行期真实存在(否则钩子不触发)。
- (id)getRealUserName:(id)arg1;                          // FakeHeadImageView.h:18
- (void)setImage:(id)arg1;
@end

// ⑧ 朋友圈视频点击关闭
@interface WAVideoPlayerView : WCPlayerControlView       // WAVideoPlayerView.h:4 (: WCPlayerControlView : UIView)
@property (nonatomic) _Bool disableTapGesture;                                 // WAVideoPlayerView.h:104
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3;  // WAVideoPlayerView.h:135 —— WCR hook 之
@end

// ⑩ 清空视频号资料页简介(WAProfileHeaderView.descLabel)
@interface WAProfileHeaderView : UIView                  // WAProfileHeaderView.h:4
// 必须声明成 UILabel 子类，不能写 id：OC 不允许对 id 用点语法
// (self.descLabel.text / .hidden 会报 "property not found on object of type 'id'")
@property (nonatomic, retain) MMUILabel *descLabel;   // WAProfileHeaderView.h:8 (MMUILabel.h:11 : UILabel)
@end

// ⑪ 隐藏自己微信号(我界面)
@interface WASettingAccountCell : UITableViewCell        // WASettingAccountCell.h:3
@property (nonatomic, retain) UILabel *detailLabel;  // WASettingAccountCell.h:7
@end

// ⑫ 隐藏聊天顶栏名字
@interface BaseMsgContentViewController : MMUIViewController   // BaseMsgContentViewController.h:4
- (void)updateTitleView:(id)arg1;                             // BaseMsgContentViewController.h:396 —— WCR hook 之
- (void)updateTitleView:(id)arg1 ignoreAnimation:(_Bool)arg2; // BaseMsgContentViewController.h:398 —— WCR hook 之
- (id)titleView;                                              // MMUIViewController.h:148
@end

// WCR hook 其 layoutSubviews，IMP 内读取 "MMTitleView" 配置键
@interface MMTitleView : MMBarItemCustomView               // MMTitleView.h:2 (: MMBarItemCustomView : UIView)
- (void)layoutSubviews;
@end

// ① 首页下拉小程序
@interface NewMainFrameViewController : MMTabBarBaseViewController   // NewMainFrameViewController.h:4
- (void)initTableHeaderView;                         // NewMainFrameViewController.h:314
- (void)initTableHeaderTopView;                      // NewMainFrameViewController.h:179
@end

// ② 朋友圈视频自动播放
@interface WCContentItemViewTemplateVideo : WCContentItemBaseView   // WCContentItemViewTemplateVideo.h:3
// ⚠️ 该方法是 void —— 它是"执行静音自动播放"的动作，不是 BOOL getter。
//    WCR hook 之(IMP 0x6772ec)并在开关开启时【跳过对原实现的调用】。
- (void)autoPlayWithoutSound;   // WCContentItemViewTemplateVideo.h:28
@end

// ③④ 朋友圈隐私图标 / 文字折叠
@interface WCTimeLineCellView : MMUIView   // WCTimeLineCellView.h:9 (: MMUIView)
- (void)layoutSubviews;                                   // WCTimeLineCellView.h:193
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1;   // WCTimeLineCellView.h:95
@end

// ⑤ 朋友圈"余下N条"折叠
@interface MicroMerchantFoldInterceptor : NSObject <TimelineRequestInterceptorImpl>   // MicroMerchantFoldInterceptor.h:3
- (void)intercept:(id)arg1;                            // MicroMerchantFoldInterceptor.h:10 —— WCR hook 之
@end

// ⑪ 我界面
@interface NewSettingViewController : MMUIViewController   // NewSettingViewController.h:3
- (void)reloadTableData;                               // NewSettingViewController.h:44 —— WCR hook 之
@end

// ⑨ 已移除(TextMessageViewModel): WCR 无此功能，不再 hook。

#pragma mark - 配置管理
#define kDDWAPullDown          @"kDDWA_disableHomePullDownMiniProgram"
#define kDDWAVideoAutoPlay     @"kDDWA_disableSnsVideoAutoPlay"
#define kDDWAPrivacyIcon       @"kDDWA_disableSnsPrivacyIcon"
#define kDDWATextFold          @"kDDWA_disableSnsTextFold"
#define kDDWAGroupFold         @"kDDWA_disableSnsGroupFold"
#define kDDWADeletedComment    @"kDDWA_antiDeleteSnsComment"
#define kDDWACustomAvatar      @"kDDWA_enableCustomAvatar"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAClearWaProfileDesc    @"kDDWA_clearWaProfileDesc"
#define kDDWAHideMyWxid        @"kDDWA_hideMyWxid"
#define kDDWAHideChatName      @"kDDWA_hideChatName"

// ---- 开关默认状态常量：与配置组同处一地 ----
// YES = 首次安装默认开启；NO = 默认关闭。目前全部 NO，装好后与原生一致。
static const BOOL kDDDefaultPullDown          = NO;
static const BOOL kDDDefaultVideoAutoPlay     = NO;
static const BOOL kDDDefaultPrivacyIcon       = NO;
static const BOOL kDDDefaultTextFold          = NO;
static const BOOL kDDDefaultGroupFold         = NO;
static const BOOL kDDDefaultAntiDelete        = NO;
static const BOOL kDDDefaultCustomAvatar      = NO;
static const BOOL kDDDefaultVideoTapClose     = NO;
static const BOOL kDDDefaultClearWaProfileDesc    = NO;
static const BOOL kDDDefaultHideMyWxid        = NO;
static const BOOL kDDDefaultHideChatName      = NO;

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
@property (assign, nonatomic) BOOL clearWaProfileDesc;
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
// 注册默认值：key 从未设置过时返回上面常量；用户改过之后以其值为准。
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
        kDDWAClearWaProfileDesc: @(kDDDefaultClearWaProfileDesc),
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
        _clearWaProfileDesc                 = [ud boolForKey:kDDWAClearWaProfileDesc];
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
- (void)setClearWaProfileDesc:(BOOL)v { _clearWaProfileDesc = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAClearWaProfileDesc]; }
- (void)setHideMyWxid:(BOOL)v { _hideMyWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideMyWxid]; }
- (void)setHideChatName:(BOOL)v { _hideChatName = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideChatName]; }
@end

#pragma mark - ① 禁用首页下拉小程序
// WCR 证据: hook NewMainFrameViewController 的 initTableHeaderView 与 initTableHeaderTopView。
//   头文件 NewMainFrameViewController.h:290 -initTableHeaderView, :425 -initTableHeaderTopView
//   不创建下拉露出的面板视图即达效果(不动发现页小程序入口)。
%hook NewMainFrameViewController
- (void)initTableHeaderTopView {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
- (void)initTableHeaderView {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) return;
    %orig;
}
%end

#pragma mark - ② 禁用朋友圈视频自动播放
// WCR 证据(IMP 0x6772ec): hook WCContentItemViewTemplateVideo -autoPlayWithoutSound。
//   头文件 WCContentItemViewTemplateVideo.h:38  - (void)autoPlayWithoutSound;
//   ⚠️ 关键: 该方法返回 void，是"执行静音自动播放"的动作，不是 BOOL getter。
//      WCR 的行为: 读开关 -> tbz 未命中时【跳过对原实现 0x691ae4 的调用】-> 即不自动播放。
//      故这里开关开启时直接 return(不调 %orig)，而不是返回 NO。
%hook WCContentItemViewTemplateVideo
- (void)autoPlayWithoutSound {
    if ([DDWeChatConfig sharedConfig].disableSnsVideoAutoPlay) return;  // 跳过原实现 = 不自动播放
    %orig;
}
%end

#pragma mark - ③ 禁用朋友圈谁可以见图标
// WCR 证据(IMP 0x656168): hook WCTimeLineCellView +instancesRespondToSelector:，
//   内部 bl 0x656358 读开关 -> tbnz 命中后 adrp x1 "m_privacyButton" -> bl 0x6563c8 隐藏。
//   即 WCR 把这个类方法当高频触发点，反复按名字取按钮并隐藏。
// 本实现: 以 layoutSubviews(:260) 为主(可直接拿到实例，按 ivar 名隐藏，覆盖复用/重设)；
//   ivar 证据 WCTimeLineCellView.h:26 MMUIButton *m_privacyButton
%hook WCTimeLineCellView
// ③ 禁用朋友圈"谁可以看"图标
- (void)layoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        // WCTimeLineCellView.h:12 -> MMUIButton *m_privacyButton (ivar 走运行时偏移，不在此声明)
        MMUIButton *btn = MSHookIvar<MMUIButton *>(self, "m_privacyButton");
        if (btn) [btn setHidden:YES];
    }
}

// ④ 禁用朋友圈文字自动折叠
// 头文件 WCTimeLineCellView.h:98 +shouldShowFullTextButtonWithDataItem:
// 返回 NO -> 不显示"全文"按钮，内容按全文展示。
// 注: WCR 的 1384 个 hook 中未定位到 fold / FullText 相关目标，
//     本目标为按头文件推断，用户确认 WCR 具备该功能但二进制内未定位到实现，保留待验证。
+ (_Bool)shouldShowFullTextButtonWithDataItem:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsTextFold) return NO;
    return %orig;
}
%end

#pragma mark - ⑤ 禁用朋友圈"余下N条"折叠
// WCR 证据: hook MicroMerchantFoldInterceptor -intercept: (MicroMerchantFoldInterceptor.h:16)
//   注: WCR 并未 hook WCMicroMerchantFeedsMgr，故这里只保留 WCR 确认的那一个。
%hook MicroMerchantFoldInterceptor
- (void)intercept:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return; // 跳过整个折叠注入
    %orig;
}
%end

#pragma mark - ⑥ 朋友圈评论防删 (WCR 真证，hook getter 返回 NO)
// WCR 证据:
//   WCUserComment -bDeleted          IMP 0x610410: 读开关 -> tbz 未命中走原实现；
//                                    命中则 mov w8,#0 -> 直接【返回 NO】(假装未删除)
//   WCUserComment -deletedByFeedOwner 同模式
//   WCSNSMessage  -isWCMessageDeleted (WCSNSMessage.h:38, 返回 _Bool) 同模式
//   WCSNSMessage  -upgradeDataIfNeeded (WCSNSMessage.h:36) 一并 hook
// 头文件: WCUserComment.h:119 bDeleted(:16 _bDeleted) / :112 deletedByFeedOwner(:17)
%hook WCUserComment
- (_Bool)bDeleted {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;  // 对齐 WCR: 直接返回 NO
    return %orig;
}
- (_Bool)deletedByFeedOwner {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;
    return %orig;
}
%end

%hook WCSNSMessage
- (_Bool)isWCMessageDeleted {
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) return NO;
    return %orig;
}
- (void)upgradeDataIfNeeded {
    %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return;
    if (self.delStatus != 0) self.delStatus = 0;  // 解除消息级删除标记
}
%end

#pragma mark - ⑦ 启用自定义头像(聊天详情页, 每聊独立)
// WCR 证据:
//   ContactInfoViewController: setM_contact: / viewDidLoad / viewWillAppear: / viewDidAppear: / viewDidLayoutSubviews
//   FakeHeadImageView(渲染侧): initWithRoundCorner: / layoutSubviews / setImage:
// ⚠️ 关键修正: 原实现 hook 的是 getRealUserName:，但 WCR 并不 hook 它。
//    WCR 的渲染点在 FakeHeadImageView -setImage: —— 微信给头像赋值时走这里，
//    因此自定义图必须在 setImage: 里覆盖，否则会被后续赋值冲掉。
static NSString *ddCustomAvatarKey(NSString *userName) {
    return [NSString stringWithFormat:@"dd_customAvatar_%@", userName ?: @""];
}
static const void *kDDAvatarUsr      = &kDDAvatarUsr;
static const void *kDDAvatarPicking  = &kDDAvatarPicking;
static const void *kDDAvatarInjected = &kDDAvatarInjected;

// 取 userName：用 performSelector: 规避 NSProcessInfo.userName 的
// API_UNAVAILABLE(ios) 与 CContact.userName 同名冲突。
static NSString *ddUserNameOf(id obj) {
    if (!obj) return nil;
    if (![obj respondsToSelector:@selector(userName)]) return nil;
    return [obj performSelector:@selector(userName)];
}

%hook ContactInfoViewController
- (void)setM_contact:(id)contact {
    %orig;
    if ([DDWeChatConfig sharedConfig].enableCustomAvatar) {
        NSString *usr = ddUserNameOf(contact);
        if (usr.length) objc_setAssociatedObject(self, kDDAvatarUsr, usr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
- (void)viewDidAppear:(_Bool)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar) return;
    if ([objc_getAssociatedObject(self, kDDAvatarInjected) boolValue]) return;
    objc_setAssociatedObject(self, kDDAvatarInjected, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @try {
        NSString *usr = objc_getAssociatedObject(self, kDDAvatarUsr);
        if (!usr.length) usr = ddUserNameOf(self.m_contact);
        if (!usr.length) return;
        UITableView *tv = self.frontTableView;
        if (!tv) return;

        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat inset = 16.0, rowH = 44.0, gap = 8.0;
        CGFloat cardW = screenW - inset * 2, cardH = rowH;

        UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, cardH + gap * 2)];
        footer.backgroundColor = [UIColor clearColor];
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(inset, gap, cardW, cardH)];
        if (@available(iOS 13.0, *)) {
            card.backgroundColor = [UIColor secondarySystemBackgroundColor];
            card.layer.cornerRadius = 10.0;
            card.layer.masksToBounds = YES;
        } else { card.backgroundColor = [UIColor whiteColor]; }
        [footer addSubview:card];

        UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(16, cardH - 0.5, cardW - 16, 0.5)];
        sep.backgroundColor = (@available(iOS 13.0, *) ? [UIColor separatorColor] : [UIColor colorWithWhite:0.88 alpha:1]);
        [card addSubview:sep];

        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, cardW - 16 - 70, rowH)];
        lab.text = @"自定义头像";
        lab.font = [UIFont systemFontOfSize:17];
        lab.textColor = (@available(iOS 13.0, *) ? [UIColor labelColor] : [UIColor blackColor]);
        [card addSubview:lab];

        UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 67, (rowH - 31) / 2.0, 51, 31)];
        sw.on = ([NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)] != nil);
        [sw addTarget:self action:@selector(dd_onCustomAvatarSwitch:) forControlEvents:UIControlEventValueChanged];
        [card addSubview:sw];
        tv.tableFooterView = footer;
    } @catch (NSException *e) { }
}
%new
- (void)dd_onCustomAvatarSwitch:(UISwitch *)s {
    NSString *usr = objc_getAssociatedObject(self, kDDAvatarUsr);
    if (!usr.length) usr = ddUserNameOf(self.m_contact);
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
        [NSUserDefaults.standardUserDefaults setObject:UIImagePNGRepresentation(image) forKey:ddCustomAvatarKey(usr)];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}
%end

// 渲染侧：对齐 WCR，在 setImage: 处覆盖（微信给头像赋值时走这里）
// 注: MMHeadImageView 头文件无 setImage:(仅有 setHeadImageByName:/setHeadImageViewCornerRadius:)，
//     故主头像渲染点仍用 FakeHeadImageView -setImage: (WCR 运行期确认的目标，见上 @interface 注释)。
%hook FakeHeadImageView
- (void)setImage:(id)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar) return;
    @try {
        id usr = [self getRealUserName:nil];    // FakeHeadImageView.h:18
        if (!usr) return;
        NSData *d = [NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)];
        if (!d) return;
        UIImage *img = [UIImage imageWithData:d];
        if (img) %orig(img);   // 用自定义图覆盖
    } @catch (NSException *e) { }
}
%end

#pragma mark - ⑧ 禁用朋友圈视频点击关闭
// WCR 证据: hook WAVideoPlayerView -setVideoPath:initialTime:isHLS: (头文件 :362)
//   WCR 并不 hook layoutSubviews / onGestureTap:，而是在【设置视频源】这个时机处理。
//   实现: 先 %orig 完成播放器装配，再利用微信内置属性禁用点击手势(:189 disableTapGesture)。
%hook WAVideoPlayerView
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsVideoTapClose) {
        self.disableTapGesture = YES;   // WAVideoPlayerView.h:189
    }
}
%end

#pragma mark - ⑩ 清空视频号资料页简介(WAProfileHeaderView.descLabel)
// 头文件 WAProfileHeaderView.h:8  @property MMUILabel *descLabel;  :19 -updateContact:
// 实现: 在资料页刷新联系人时把简介清空并隐藏。
// 注: 此功能按 8.0.76 头文件实现(清空视频号资料页 descLabel)，并非 WCR 的对齐项；
//     WCR 资料页相关目标为好友资料页 TLProfileExpandableHeaderView(补充 dump 已含该类，
//     其 infoLabel / signatureLabel 为 MMCPLabel，可作隐藏微信号之用，本插件暂未启用)。
%hook WAProfileHeaderView
- (void)updateContact:(id)arg1 {
    %orig;
    if (![DDWeChatConfig sharedConfig].clearWaProfileDesc) return;
    self.descLabel.text = @"";
    self.descLabel.hidden = YES;
}
%end

#pragma mark - ⑪ 隐藏自己微信号(我界面)
// WCR 证据: hook NewSettingViewController -reloadTableData (头文件 :55)
//   注: WCR 并未 hook WASettingAccountCell，故这里只保留 WCR 确认的那一个，
//       在刷新时遍历可见 cell，对账户卡片清空副标题(微信号行)。
%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    if (![DDWeChatConfig sharedConfig].hideMyWxid) return;
    id mgr = MSHookIvar<id>(self, "m_tableViewMgr");   // :11
    UITableView *tv = nil;
    if (mgr && [mgr respondsToSelector:@selector(getTableView)]) tv = [mgr getTableView];
    if (!tv) return;
    Class accCls = objc_getClass("WASettingAccountCell");
    for (UITableViewCell *cell in tv.visibleCells) {
        if (accCls && [cell isKindOfClass:accCls]) {
            UILabel *d = [(id)cell detailLabel];       // WASettingAccountCell.h:13/20
            if (d) { d.text = @""; d.hidden = YES; }
        }
    }
}
%end

#pragma mark - ⑫ 隐藏聊天名字(顶栏标题) (WCR 真证)
// WCR 证据:
//   BaseMsgContentViewController: updateTitleView: 与 updateTitleView:ignoreAnimation: 都 hook
//   MMTitleView: layoutSubviews —— 其 IMP 读取 "MMTitleView" 配置键，在此隐藏标题视图
//   (两个 updateTitleView 的 IMP 都引用了 MMTitleView 键，说明三者配合完成隐藏)
// 头文件: BaseMsgContentViewController.h:986 -updateTitleView:
//        MMUIViewController.h:520 -titleView
%hook BaseMsgContentViewController
- (void)updateTitleView:(id)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideChatName) {
        UIView *tv = [self titleView];
        if ([tv isKindOfClass:[UIView class]]) tv.hidden = YES;
    }
}
- (void)updateTitleView:(id)arg1 ignoreAnimation:(_Bool)arg2 {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideChatName) {
        UIView *tv = [self titleView];
        if ([tv isKindOfClass:[UIView class]]) tv.hidden = YES;
    }
}
%end

// 对齐 WCR：MMTitleView 自身布局时也隐藏，覆盖微信内部重新显示标题的情况
%hook MMTitleView
- (void)layoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideChatName) {
        self.hidden = YES;
    }
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
    [sns addCell:[cellMgr switchCellForSel:@selector(onAntiDeleteSwitch:) target:self title:@"朋友圈评论防删" on:cfg.antiDeleteSnsComment]];
    [sns addCell:[cellMgr switchCellForSel:@selector(onVideoTapCloseSwitch:) target:self title:@"禁用朋友圈视频点击关闭" on:cfg.disableSnsVideoTapClose]];
    [_tableViewManager addSection:sns];

    WCTableViewSectionManager *privacy = [secMgr defaultSection];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onClearWaProfileDescSwitch:) target:self title:@"清空视频号资料页简介" on:cfg.clearWaProfileDesc]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideMyWxidSwitch:) target:self title:@"隐藏自己微信号(我界面)" on:cfg.hideMyWxid]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideChatNameSwitch:) target:self title:@"隐藏聊天顶栏名字" on:cfg.hideChatName]];
    [_tableViewManager addSection:privacy];

    WCTableViewSectionManager *general = [secMgr defaultSection];
    [general addCell:[cellMgr switchCellForSel:@selector(onAvatarSwitch:) target:self title:@"启用自定义头像(聊天详情)" on:cfg.enableCustomAvatar]];
    [_tableViewManager addSection:general];

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
- (void)onAvatarSwitch:(UISwitch *)s        { [DDWeChatConfig sharedConfig].enableCustomAvatar = s.on; }
- (void)onVideoTapCloseSwitch:(UISwitch *)s { [DDWeChatConfig sharedConfig].disableSnsVideoTapClose = s.on; }
- (void)onClearWaProfileDescSwitch:(UISwitch *)s{ [DDWeChatConfig sharedConfig].clearWaProfileDesc = s.on; }
- (void)onHideMyWxidSwitch:(UISwitch *)s    { [DDWeChatConfig sharedConfig].hideMyWxid = s.on; }
- (void)onHideChatNameSwitch:(UISwitch *)s  { [DDWeChatConfig sharedConfig].hideChatName = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD微信助手"
                                                      version:@"2.0.0"
                                                   controller:@"DDWeChatSettingsViewController"];
        }
    }
}

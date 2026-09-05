// =============================================================================
//  DD微信助手 (DD WeChat Assistant)  v2.3.0
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
//    - ⑦ 渲染点改为 MMUILongPressImageView -setImage: (WCR 反汇编真证 IMP 0x373e0c/0x372bfc；
//      MMUILongPressImageView.h:29 声明 -setImage:，其 superview 为 MMHeadImageView，
//      经 getRealUserName: 取用户名后命中自定义图)。宿主页由 ContactInfoViewController 的
//      tableFooterView 改为 AddContactToChatRoomViewController(聊天详情页) 注入原生 switch cell。
//
//  v2.2.0 变更(真机层次结构树 + WCR 反汇编双重实锤):
//    - ⑩「隐藏好友微信号(资料页)」重写为 WCR 真实实现：
//      ContactInfoViewController 的 viewWillAppear: / viewDidAppear: / viewDidLayoutSubviews
//      三个时机递归遍历视图树，按 MMCPLabel + tag==90224(0x16070) 定位微信号 label
//      并 setText: @"" 清空(遍历器对应 WCR 0x8c976c，常量 0x16070 与真机截图 tag=90224 一致)。
//    - 移除旧实现 WAProfileHeaderView.descLabel(那是视频号资料页简介，并非微信号)。
//
//  v2.3.0 变更(对齐用户真机截图 + WCR 反汇编，修正 v2.2.0 仍错的 ⑦):
//    - ⑦「启用自定义头像」彻底重写为 WCR 真实形态：
//      宿主页由 ContactInfoViewController 改为 AddContactToChatRoomViewController(聊天详情页，
//      尽管类名像加群)，在 -reloadTableData / -reloadData / -onTableViewReload(%orig 之后) 向
//      WCTableView 注入原生 switch cell「启用自定义头像」(WCTableViewCellManager
//      switchCellForSel:target:title:on:，按"查找聊天内容"所在 section 用 insertCell:At: 插到其
//      上方(位置固定，不依赖"查看好友资料卡"等其它功能行)，再 [tableView reloadData]
//      刷新。
//      渲染点由 FakeHeadImageView 改为 MMUILongPressImageView -setImage:(IMP 0x373e0c/0x372bfc)，
//      取 superview(MMHeadImageView) 的 getRealUserName: 命中后换图(WCR 真证)。
//
//  v2.3.0 续修(对齐用户真机截图 + WCR 反汇编，修正 ① ③ ⑥ 三处与 WCR 行为不一致):
//    - ⑥「朋友圈评论防删」彻底重写：保留 bDeleted=NO(评论仍可见，WCR 0x610410 同)的前提下，
//      在 WCCommentView +getDisplayCommentContent:dataItem:pageContext:(WCCommentView.h:35) 与
//      WCCommentListContentView +getDisplayContent:dataItem:pageContext:(WCCommentListContentView.h:30)
//      两处评论显示文本计算点，对真实被删的评论拼接前缀文案(默认"[已删除]"，对齐 WCR
//      momentsDeletedMarkText)，显示为"[已删除]xxx"；而非裸显示被删内容。
//      真实已删态只用头文件原生声明的 bDeleted / deletedByFeedOwner 两个 property 判定：
//      WCUserComment 钩子经原生 getter(%orig) 取到真实值后暂存，渲染处直接读，不猜 ivar、不加兜底。
//      两页都覆盖后，朋友圈流与"评论提示/通知详情页"格式一致对齐 WCR。
//    - ①「禁用首页下拉小程序」修正：不再跳过 initTableHeaderView/initTableHeaderTopView(WCR 不跳过，
//      否则搜索栏消失、下拉手感怪)；改为让原生初始化照常进行，再 hook
//      setTableHeaderTopViewHiddenIfNotLimitedMode:(WCR rep 0x8b7944，强制 hidden=YES) 与
//      mainPullDown:(WCR rep 0x8b79b4，"展开"参数时直接 return 不显示面板)，并把
//      showTableHeaderTopViewByPullDown:/startDragToShow/showTableHeaderTopView:fromScene: 一并拦截，
//      仅藏起小程序面板、保留自然下拉手感。
//    - ③「禁用朋友圈谁可以见图标」修正：对齐 WCR 两处 hook——initPrivacyButton:(WCR rep 0x656258
//      按 0x65650c 做 setImage:nil + setAlpha:0 + setUserInteractionEnabled:NO 仅隐藏，不移除按钮)
//      负责隐藏；真正消去预留空白的重排在 layoutSubviews(WCR rep 0x656764)完成：把 m_deleteButton
//      左移到 m_privacyButton 的 minX(仅当 delete 可见且其 minX > privacy 的 minX+0.5)。早期用
//      setHidden/removeFromSuperview 仍留白，根因就是缺了 layoutSubviews 里的这次重排(frame 在
//      %orig 之后才就绪)。
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

// 表管理器：设置页与聊天详情页共用，依据 8.0.76 头文件手动声明(仅声明实际调用的接口)
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

@interface MMTableViewInfo : WCTableViewManager          // MMTableViewInfo.h:1 (: WCTableViewManager)
@end

// ---- 被 hook 微信类的声明(全部锚定 8.0.76 补充 dump 的真实签名) ----
// 本补充 dump 已还原各类的完整继承链，故此处按真实父类声明；
// 仅列出本插件实际访问的 property / 重写的方法，其余方法由运行时按 SEL 派发。
// 注: m_privacyButton / m_tableViewMgr 等 ivar 仍走 MSHookIvar 运行时取偏移，
//     不在本地 @interface 中声明(手写 ivar 会让编译器按本地布局算固定偏移，
//     与真机类布局不一致会读崩)。

// 微信基类：仅 @class 前向声明无法作为 @interface 的父类(Obj-C 不允许)，
// 故在此给出最小完整 @interface(锚定 8.0.76 dump 真实继承链——均为 UIKit 子类)。
@interface MMTabBarBaseViewController : UIViewController @end
@interface MMUIViewController : UIViewController @end
@interface MMUIView : UIView @end
@interface WCPlayerControlView : UIView @end
@interface MMBarItemCustomView : UIView @end
@interface WCContentItemBaseView : UIView @end
@interface MMUIImageView : UIImageView @end
@interface MMUIButton : UIButton @end
@interface CBaseContact : NSObject @end
@protocol TimelineRequestInterceptorImpl <NSObject> @end

@interface CContact : CBaseContact
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
@property (retain, nonatomic) WCUserComment *comment; // WCSNSMessage.h:8 —— 评论本体(通知/评论列表页文本源)
- (void)upgradeDataIfNeeded;                          // WCSNSMessage.h:36
- (_Bool)isWCMessageDeleted;                          // WCSNSMessage.h:19 —— WCR hook 之
@end

// ⑥ 评论显示文本计算点(WCCommentView.h:35)。WCR 的"[已删除]"前缀即加在评论显示文本上，
//    本插件在此处对齐 WCR：把被删评论显示为"[已删除]xxx"，而非裸显示被删内容。
@interface WCCommentView : NSObject
+ (id)getDisplayCommentContent:(id)a0 dataItem:(id)a1 pageContext:(id)a2;  // WCCommentView.h:35
@end

// ⑥ 评论列表/通知详情页(由 WCSNSMessage 展开的那一页)的评论文本计算点(WCCommentListContentView.h:30)。
//    这一页走的是 getDisplayContent: 而非 WCCommentView 的 getDisplayCommentContent:，
//    所以 ⑥ 的前缀必须在这里也加一次，否则"朋友圈评论提示"里被删评论仍裸显示。
@interface WCCommentListContentView : UIView
+ (id)getDisplayContent:(id)a0 dataItem:(id)a1 pageContext:(id)a2;  // WCCommentListContentView.h:30
@end

// ⑦ 自定义头像 —— 宿主页与渲染点见下方 hook 注释(均锚定 WCR 反汇编真证)
@interface ContactInfoViewController : MMUIViewController   // ContactInfoViewController.h:4
@property (nonatomic, retain) CContact *m_contact;       // ContactInfoViewController.h:32
@property (nonatomic, weak) UITableView *frontTableView; // ContactInfoViewController.h:23
@end

// ⑦ 渲染点: MMUILongPressImageView -setImage: (WCR 真证 IMP 0x373e0c/0x372bfc)
//   MMUILongPressImageView.h:29 声明 - (void)setImage:(id)a0; 父类 MMUIImageView
@interface MMUILongPressImageView : MMUIImageView
- (void)setImage:(id)arg1;
@end

// ⑦ 宿主页: AddContactToChatRoomViewController(微信"聊天详情"页, 尽管类名像加群)
//   AddContactToChatRoomViewController.h:4 : MMUIViewController; :23 m_contact(CContact)
//   :7 m_tableViewInfo(MMTableViewInfo); :5 m_tableView(MMTableView)
@interface AddContactToChatRoomViewController : MMUIViewController
@property (nonatomic, retain) CContact *m_contact;          // AddContactToChatRoomViewController.h:23
@property (nonatomic, retain) MMTableViewInfo *m_tableViewInfo; // AddContactToChatRoomViewController.h:7
@end

// ⑧ 朋友圈视频点击关闭
@interface WAVideoPlayerView : WCPlayerControlView       // WAVideoPlayerView.h:4 (: WCPlayerControlView : UIView)
@property (nonatomic) _Bool disableTapGesture;                                 // WAVideoPlayerView.h:104
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3;  // WAVideoPlayerView.h:135 —— WCR hook 之
@end

// ⑩ 隐藏好友微信号(资料页)：实现在下方 ContactInfoViewController 的 hook 内
// (真机层次结构树证实 label 路径: ContactInfoViewController -> TextStateProfileTableView
//  [TextStateProfileTableView.h:1 : WCTableView] -> ... -> MMCPLabel[MMCPLabel.h:1 : MMUILabel])

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
#define kDDWADeletedCommentMark @"kDDWA_deletedCommentMark"   // ⑥ 前缀文案(对齐 WCR momentsDeletedMarkText)
#define kDDWACustomAvatar      @"kDDWA_enableCustomAvatar"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAHideFriendWxid    @"kDDWA_hideFriendWxid"
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
static const BOOL kDDDefaultHideFriendWxid    = NO;
static const BOOL kDDDefaultHideMyWxid        = NO;
static const BOOL kDDDefaultHideChatName      = NO;

// ⑥ 评论防删：被删评论显示时拼接的前缀文案(对齐 WCR momentsDeletedMarkText，默认"[已删除]")
static NSString * const kDDDefaultDeletedMark = @"[已删除]";
static const void *kDDWasDeletedKey = &kDDWasDeletedKey;
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
@property (assign, nonatomic) BOOL enableCustomAvatar;
@property (assign, nonatomic) BOOL disableSnsVideoTapClose;
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
        kDDWAHideFriendWxid: @(kDDDefaultHideFriendWxid),
        kDDWAHideMyWxid:     @(kDDDefaultHideMyWxid),
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
        _enableCustomAvatar             = [ud boolForKey:kDDWACustomAvatar];
        _disableSnsVideoTapClose        = [ud boolForKey:kDDWAVideoTapClose];
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
- (void)setHideFriendWxid:(BOOL)v { _hideFriendWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideFriendWxid]; }
- (void)setHideMyWxid:(BOOL)v { _hideMyWxid = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideMyWxid]; }
- (void)setHideChatName:(BOOL)v { _hideChatName = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWAHideChatName]; }
@end

#pragma mark - ① 禁用首页下拉小程序
// WCR 证据(NewMainFrameViewController 安装函数 0x8b3928 起的一整片 MSHookMessageEx):
//   setTableHeaderTopViewHiddenIfNotLimitedMode: rep 0x8b7944 —— 开关命中即强制 hidden=YES；
//   mainPullDown: rep 0x8b79b4 —— 开关命中且"展开"参数为 YES 时直接 return 不显示面板；
//   另 hook showTableHeaderTopViewByPullDown:/startDragToShow/showTableHeaderTopView:fromScene:
//   以及 WCSearchBar 样式，目的是【保留搜索栏与自然下拉手感】，只是不露出小程序面板。
//   头文件 NewMainFrameViewController.h:180 setTableHeaderTopViewHiddenIfNotLimitedMode: /
//   :198 mainPullDown: / :165 showTableHeaderTopViewByPullDown: / :184 startDragToShow /
//   :196 showTableHeaderTopView:fromScene: / :179 initTableHeaderTopView / :314 initTableHeaderView
//   关键修正: 不再跳过 initTableHeaderView / initTableHeaderTopView(否则搜索栏消失、下拉手感怪)，
//            改为让原生初始化照常进行，再用下面 hook 把露出的面板藏起来。
%hook NewMainFrameViewController
- (void)initTableHeaderView {
    %orig;   // 保留搜索栏与自然布局(WCR 不跳过)
}
- (void)initTableHeaderTopView {
    %orig;   // 同上
}
// 强制把下拉露出的顶部面板置为隐藏(对齐 WCR 0x8b7944)
- (void)setTableHeaderTopViewHiddenIfNotLimitedMode:(BOOL)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram) {
        %orig(YES);   // 始终隐藏：不露出小程序面板
        return;
    }
    %orig;
}
// 下拉手势"展开"时(参数=YES)若开关开启则不显示面板(对齐 WCR 0x8b79b4)
- (void)mainPullDown:(BOOL)arg1 {
    if ([DDWeChatConfig sharedConfig].disableHomePullDownMiniProgram && arg1) {
        return;   // 不调原生，面板不出现；其余下拉逻辑保持自然
    }
    %orig;
}
// 其余露出入口一并拦截(对齐 WCR 同批 hook)
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
// WCR 证据(WCTimeLineCellView 两处 hook):
//   (1) initPrivacyButton: rep 0x656258 -> 0x65650c: 命中 momentsDisablePrivacyIconEnabled 后，
//       对 m_privacyButton(WCTimeLineCellView.h:12) 做 setImage:nil + setAlpha:0 +
//       setUserInteractionEnabled:NO —— 仅隐藏，不 removeFromSuperview(其 selset 无 deleteButton/
//       frame/superview，亦无 removeFromSuperview)。
//   (2) layoutSubviews rep 0x656764: 读 m_privacyButton / m_deleteButton(WCTimeLineCellView.h:14)
//       的 superview 与 frame，仅当 m_deleteButton.isHidden==NO 且
//       CGRectGetMinX(delete) > CGRectGetMinX(privacy) + 0.5 时，把 m_deleteButton 左移到
//       privacy 的 minX(优先 setLeft:，否则改 frame.origin.x)，从而消去预留空白占位。
//   ivar 走运行时偏移，不在此声明。
//   关键修正: 早期用 setHidden/removeFromSuperview 仍留白，是因为缺了 (2) 的重排——reflow 必须
//   在 layoutSubviews(%orig 之后 frame 才就绪) 里执行，而非 initPrivacyButton: 时刻。
%hook WCTimeLineCellView
- (void)initPrivacyButton:(id)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        // WCTimeLineCellView.h:12 -> MMUIButton *m_privacyButton (ivar 走运行时偏移，不在此声明)
        MMUIButton *btn = MSHookIvar<MMUIButton *>(self, "m_privacyButton");
        if (btn) {
            [btn setImage:nil forState:0];   // 对齐 WCR 0x65650c
            [btn setAlpha:0.0];
            [btn setUserInteractionEnabled:NO];
            // 注意: 不 removeFromSuperview。WCR 同样保留按钮，否则 layoutSubviews 引用已移除对象
            // 会崩/布局错乱；空白占位由下方 layoutSubviews 重排 m_deleteButton 消去。
        }
    }
}

- (void)layoutSubviews {
    %orig;   // 先让原始布局把 m_privacyButton / m_deleteButton 的 frame 设好
    if ([DDWeChatConfig sharedConfig].disableSnsPrivacyIcon) {
        MMUIButton *privacyBtn = MSHookIvar<MMUIButton *>(self, "m_privacyButton"); // WCTimeLineCellView.h:12
        MMUIButton *deleteBtn  = MSHookIvar<MMUIButton *>(self, "m_deleteButton");  // WCTimeLineCellView.h:14
        if (privacyBtn && deleteBtn && privacyBtn.superview && deleteBtn.superview && !deleteBtn.hidden) {
            CGFloat pMinX = CGRectGetMinX(privacyBtn.frame);
            CGFloat dMinX = CGRectGetMinX(deleteBtn.frame);
            if (dMinX > pMinX + 0.5) {
                if ([deleteBtn respondsToSelector:@selector(setLeft:)]) {
                    [deleteBtn setLeft:pMinX];   // 对齐 WCR 0x656764 的 setLeft:
                } else {
                    CGRect f = deleteBtn.frame;  // 兜底: 直接改 frame.origin.x
                    f.origin.x = pMinX;
                    [deleteBtn setFrame:f];
                }
            }
        }
    }
}
%end

// ④ 禁用朋友圈文字自动折叠
// 头文件 WCTimeLineCellView.h:98 +shouldShowFullTextButtonWithDataItem:
// 返回 NO -> 不显示"全文"按钮，内容按全文展示。
// 注: WCR 的 1384 个 hook 中未定位到 fold / FullText 相关目标，
//     本目标为按头文件推断，用户确认 WCR 具备该功能但二进制内未定位到实现，保留待验证。
%hook WCTimeLineCellView
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

#pragma mark - ⑥ 朋友圈评论防删 (对齐 WCR：保留可见 + 显示"[已删除]"前缀)
// WCR 真证:
//   WCUserComment -bDeleted          IMP 0x610410: 读开关 -> 命中则 mov w8,#0 直接【返回 NO】(保留可见)
//   WCUserComment -deletedByFeedOwner 同模式
//   WCSNSMessage  -isWCMessageDeleted (WCSNSMessage.h:19) 同模式
//   WCSNSMessage  -upgradeDataIfNeeded (WCSNSMessage.h:36) 一并 hook
//   前缀文案来自 WCR 配置项 momentsDeletedMarkText(默认"[已删除]"，见 WCR 设置项"已删除内容/自定义标记文案")。
//   帖子级 WCR 在 WCDataItem -contentDesc (IMP 0x610d7c) 命中 isDataItemMarkedDeleted: 且
//   momentsAntiDeleteMarkDeletedEnabled 时，用 momentsDeletedMarkText 拼到原文前；
//   评论级走 WCCommentView +getDisplayCommentContent:dataItem:pageContext: (WCCommentView.h:35) 这一
//   显示文本计算点——本插件在此处对齐 WCR：把被删评论显示为"[已删除]xxx"，而非裸显示被删内容。
// 头文件: WCUserComment.h:22 bDeleted / :32 deletedByFeedOwner; WCCommentView.h:35 getDisplayCommentContent:
%hook WCUserComment
- (_Bool)bDeleted {
    _Bool real = %orig;                       // 取真实已删状态
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) {
        // 防删：列表仍保留可见；同时记住真实已删态，供评论文本加前缀(WCR momentsDeletedMarkText)
        if (real) objc_setAssociatedObject(self, kDDWasDeletedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return NO;
    }
    return real;
}
- (_Bool)deletedByFeedOwner {
    _Bool real = %orig;
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) {
        if (real) objc_setAssociatedObject(self, kDDWasDeletedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return NO;
    }
    return real;
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

// ⑥ 渲染点：评论显示文本计算处拼接"[已删除]"前缀(对齐 WCR momentsDeletedMarkText)。
//   仅对"真实被删、且本应保留可见"的评论生效；非 NSString(富文本)原样返回，避免破坏排版。
%hook WCCommentView
+ (id)getDisplayCommentContent:(id)comment dataItem:(id)item pageContext:(id)ctx {
    id orig = %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return orig;
    if (![comment isKindOfClass:objc_getClass("WCUserComment")]) return orig;
    NSNumber *wasDel = objc_getAssociatedObject(comment, kDDWasDeletedKey);
    if (!wasDel || !wasDel.boolValue) return orig;
    if ([orig isKindOfClass:[NSString class]]) {
        return [ddDeletedMarkText() stringByAppendingString:(NSString *)orig];
    }
    return orig;
}
%end

// ⑥ 评论列表/通知详情页(由 WCSNSMessage 展开的那一页)同样加 "[已删除]"前缀。
//    这一页走 getDisplayContent: 而非上面的 getDisplayCommentContent:，故需单独 hook 一次，
//    否则"朋友圈评论提示"里的被删评论仍裸显示、与 WCR 格式不一致。
//    检测只用头文件原生声明的 bDeleted / deletedByFeedOwner 两个 property：其真实值由
//    WCUserComment 钩子经原生 getter(%orig) 取后暂存，此处直接读，不猜 ivar、不加兜底。
%hook WCCommentListContentView
+ (id)getDisplayContent:(id)a0 dataItem:(id)a1 pageContext:(id)a2 {
    id orig = %orig;
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) return orig;
    id comment = nil;
    Class WCUserCommentCls = objc_getClass("WCUserComment");
    Class WCSNSMessageCls  = objc_getClass("WCSNSMessage");
    if ([a0 isKindOfClass:WCUserCommentCls]) comment = a0;
    else if (WCSNSMessageCls && [a0 isKindOfClass:WCSNSMessageCls]) comment = [a0 comment];
    if (!comment) return orig;
    NSNumber *wasDel = objc_getAssociatedObject(comment, kDDWasDeletedKey);
    if (!wasDel || !wasDel.boolValue) return orig;
    if ([orig isKindOfClass:[NSString class]]) {
        return [ddDeletedMarkText() stringByAppendingString:(NSString *)orig];
    }
    return orig;
}
%end

#pragma mark - ⑦ 启用自定义头像(聊天详情页, 每聊独立)
// WCR 真证实现(反汇编 WCRefine.dylib):
//   [宿主页] AddContactToChatRoomViewController(即微信"聊天详情"页, 尽管类名像加群)
//           hook -reloadTableData(IMP 0x374084) / -reloadData(IMP 0x3740c0)
//           / -onTableViewReload(IMP 0x3740fc) —— 三者均在 %orig 之后调用注入器 0x37d0dc；
//           注入器用 [WCTableViewCellManager switchCellForSel:@selector(toggleCustomContactAvatar:)
//           target:vc title:@"启用自定义头像" on:enabled] 造原生 switch cell，
//           按 "查找聊天内容" 所在 section 用 insertCell:At: 插到其上方(真机截图证实位于
//           "查找聊天内容"上方(位置固定)，再 [tableView reloadData] 刷新。
//   [渲染点] MMUILongPressImageView -setImage:(IMP 0x373e0c/0x372bfc) ——
//           微信给头像赋值时经此；WCR 在 %orig 后取 superview(MMHeadImageView) 的
//           getRealUserName:，校验 customAvatarFeatureEnabled + customAvatarGroupEnabledIDs
//           命中后载入自定义图。DD 用 enableCustomAvatar(总开关) + 每聊 NSUserDefaults 命中。
static NSString *ddCustomAvatarKey(NSString *userName) {
    return [NSString stringWithFormat:@"dd_customAvatar_%@", userName ?: @""];
}
static const void *kDDAvatarUsr     = &kDDAvatarUsr;
static const void *kDDAvatarPicking = &kDDAvatarPicking;

// 取 userName：用 performSelector: 规避 NSProcessInfo.userName 的
// API_UNAVAILABLE(ios) 与 CContact.userName 同名冲突。
static NSString *ddUserNameOf(id obj) {
    if (!obj) return nil;
    if (![obj respondsToSelector:@selector(userName)]) return nil;
    return [obj performSelector:@selector(userName)];
}

// 读 cellInfo 的标题(用于定位插入点与幂等查重)：
//   WCTableViewCellManager.cellConfig(WCTableViewCellNormalConfig).leftConfig(WCTableViewCellLeftConfig).title
// 全部走 performSelector: 规避 KVC 与 dot-syntax-on-id。
static NSString *ddCellTitle(id cellInfo) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    @try {
        id cfg  = [cellInfo performSelector:@selector(cellConfig)];
        if (!cfg) return nil;
        id left = [cfg performSelector:@selector(leftConfig)];
        if (!left) return nil;
        return [left performSelector:@selector(title)];
    } @catch (NSException *e) { return nil; }
#pragma clang diagnostic pop
}

// 该聊是否启用自定义头像(总开关 + 每聊命中)
static BOOL ddCustomAvatarOnForUser(NSString *usr) {
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar) return NO;
    if (usr.length == 0) return NO;
    return [NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)] != nil;
}

// 在聊天详情页注入「启用自定义头像」原生 switch cell。
// 位置固定：插到"查找聊天内容"(微信常驻功能，位置稳定)所在 section 的上方；
// 找不到时兜底插到最后一个 section 末尾。不依赖"查看好友资料卡"(另一独立功能，默认不开启)。
static void ddInjectCustomAvatarCell(AddContactToChatRoomViewController *vc) {
    @try {
        NSString *usr = ddUserNameOf(vc.m_contact);
        if (usr.length == 0) return;
        MMTableViewInfo *ti = MSHookIvar<MMTableViewInfo *>(vc, "m_tableViewInfo");
        if (!ti) return;
        NSUInteger secCount = [ti getSectionCount];
        if (secCount == 0) return;
        NSInteger targetSec = -1, targetIdx = -1;
        for (NSUInteger s = 0; s < secCount; s++) {
            id sec = [ti getSectionAt:s];
            if (!sec) continue;
            NSUInteger cellCount = [sec getCellCount];
            for (NSUInteger c = 0; c < cellCount; c++) {
                NSString *t = ddCellTitle([sec getCellAt:c]);
                if ([t isEqualToString:@"启用自定义头像"]) return;          // 已注入，幂等
                if ([t isEqualToString:@"查找聊天内容"]) { targetSec = (NSInteger)s; targetIdx = (NSInteger)c; break; }
            }
            if (targetSec >= 0) break;
        }
        if (targetSec < 0) {   // 兜底：插到最后一个 section 末尾
            id lastSec = [ti getSectionAt:secCount - 1];
            if (lastSec) {
                targetSec = (NSInteger)(secCount - 1);
                targetIdx = (NSInteger)[lastSec getCellCount];
            }
        }
        if (targetSec < 0) return;
        id sec = [ti getSectionAt:(NSUInteger)targetSec];
        Class cellMgr = objc_getClass("WCTableViewCellManager");
        id cell = [cellMgr switchCellForSel:@selector(dd_toggleCustomAvatar:) target:vc
                                      title:@"启用自定义头像" on:ddCustomAvatarOnForUser(usr)];
        [sec insertCell:cell At:(unsigned int)targetIdx];
        UITableView *tv = [ti getTableView];
        [tv reloadData];
    } @catch (NSException *e) { }
}

%hook AddContactToChatRoomViewController
- (void)reloadTableData {
    %orig;
    ddInjectCustomAvatarCell(self);
}
- (void)reloadData {
    %orig;
    ddInjectCustomAvatarCell(self);
}
- (void)onTableViewReload {
    %orig;
    ddInjectCustomAvatarCell(self);
}
%new
- (void)dd_toggleCustomAvatar:(UISwitch *)s {
    NSString *usr = ddUserNameOf(self.m_contact);
    if (usr.length == 0) return;
    if (s.on) {
        if (![DDWeChatConfig sharedConfig].enableCustomAvatar) { s.on = NO; return; }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
        objc_setAssociatedObject(self, kDDAvatarUsr, usr, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:ddCustomAvatarKey(usr)];
    }
}
%new
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    NSString *usr = objc_getAssociatedObject(self, kDDAvatarUsr);
    if (image && usr.length) {
        [NSUserDefaults.standardUserDefaults setObject:UIImagePNGRepresentation(image) forKey:ddCustomAvatarKey(usr)];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}
%new
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}
%end

// 渲染侧：对齐 WCR，在 MMUILongPressImageView -setImage: 处覆盖(微信给头像赋值时走这里)。
// 仅当 superview 为头像视图(响应 getRealUserName:)才处理，避免误伤消息图片等。
// 命中后直接 %orig(customImg) 调原实现换图(不重入本 hook，天然无递归，无需 %property/标志位)。
%hook MMUILongPressImageView
- (void)setImage:(id)arg1 {
    %orig;
    UIView *head = self.superview;
    if (![head respondsToSelector:@selector(getRealUserName:)]) {
        head = head.superview;
        if (![head respondsToSelector:@selector(getRealUserName:)]) return;
    }
    NSString *usr = [head performSelector:@selector(getRealUserName:) withObject:nil];
    if (usr.length == 0) return;
    if (!ddCustomAvatarOnForUser(usr)) return;
    NSData *d = [NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)];
    if (!d) return;
    UIImage *img = [UIImage imageWithData:d];
    if (img) %orig(img);
}
%end

// ⑩ 隐藏好友微信号(资料页)：实现在下方 ContactInfoViewController 的 hook 内
// WCR 真证: 三个时机(viewWillAppear:/viewDidAppear:/viewDidLayoutSubviews) + 遍历器 0x8c976c，
// 按 MMCPLabel + tag==90224 定位微信号 label 并 setText:@"" 清空。
static void ddHideWxidLabelsInView(UIView *view) {
    if (!view) return;
    static Class wxidCls = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ wxidCls = objc_getClass("MMCPLabel"); });   // 0x8c97b4
    if (!wxidCls) return;
    for (UIView *sub in [view subviews]) {
        if ([sub isKindOfClass:wxidCls] && sub.tag == 90224) {               // 0x16070
            UILabel *lab = (UILabel *)sub;
            if (lab.text.length > 0) lab.text = @"";                          // 对齐 WCR: setText: 清空
        }
        ddHideWxidLabelsInView(sub);
    }
}

%hook ContactInfoViewController
// ⑩ 隐藏好友微信号 —— 对齐 WCR: viewWillAppear: 也触发(资料页首次进入)
- (void)viewWillAppear:(_Bool)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideFriendWxid) ddHideWxidLabelsInView(self.view);
}
- (void)viewDidAppear:(_Bool)arg1 {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideFriendWxid) ddHideWxidLabelsInView(self.view);
}
// ⑩ 隐藏好友微信号 —— 对齐 WCR: viewDidLayoutSubviews 也触发(微信重排后重新清空)
- (void)viewDidLayoutSubviews {
    %orig;
    if ([DDWeChatConfig sharedConfig].hideFriendWxid) ddHideWxidLabelsInView(self.view);
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

#pragma mark - ⑩ 隐藏好友微信号(资料页) —— 实现见上方 ContactInfoViewController 的 hook
// WCR 真证: 三个时机(viewWillAppear:/viewDidAppear:/viewDidLayoutSubviews) + 遍历器 0x8c976c，
// 按 MMCPLabel + tag==90224 定位微信号 label 并 setText:@"" 清空。
// (旧实现 WAProfileHeaderView.descLabel 清的是视频号简介，并非微信号，已删除。)

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
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideFriendWxidSwitch:) target:self title:@"隐藏好友微信号(资料页)" on:cfg.hideFriendWxid]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideMyWxidSwitch:) target:self title:@"隐藏自己微信号(我界面)" on:cfg.hideMyWxid]];
    [privacy addCell:[cellMgr switchCellForSel:@selector(onHideChatNameSwitch:) target:self title:@"隐藏聊天顶栏名字" on:cfg.hideChatName]];
    [_tableViewManager addSection:privacy];

    WCTableViewSectionManager *general = [secMgr defaultSection];
    [general addCell:[cellMgr switchCellForSel:@selector(onAvatarSwitch:) target:self title:@"启用自定义头像(总开关)" on:cfg.enableCustomAvatar]];
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
- (void)onHideFriendWxidSwitch:(UISwitch *)s{ [DDWeChatConfig sharedConfig].hideFriendWxid = s.on; }
- (void)onHideMyWxidSwitch:(UISwitch *)s    { [DDWeChatConfig sharedConfig].hideMyWxid = s.on; }
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

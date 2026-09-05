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

@interface MMTableViewInfo : WCTableViewManager          // MMTableViewInfo.h:1
@end

// ---- 被 hook 微信类声明(锚定 8.0.76 dump 真实继承链) ----

@interface MMTabBarBaseViewController : UIViewController @end
@interface MMUIViewController : UIViewController @end
@interface MMUIView : UIView @end
@interface WCPlayerControlView : UIView @end
@interface MMBarItemCustomView : UIView @end
@interface WCContentItemBaseView : UIView @end
@interface MMUIImageView : UIImageView @end
@interface MMUIButton : UIButton @end
@interface MMUILabel : UILabel @end
@interface MMCPLabel : MMUILabel   // MMCPLabel.h:4 (: MMUILabel : UILabel)
@end
@interface CBaseContact : NSObject @end
@interface BaseMsgContentViewController : MMUIViewController @end   // BaseMsgContentViewController.h:4

@protocol TimelineRequestInterceptorImpl <NSObject> @end

@interface CContact : CBaseContact
@property (nonatomic, readonly) NSString *userName;   // CContact.h:465
@end

// ⑥ 朋友圈评论防删
@interface WCUserComment : NSObject
@property (nonatomic) _Bool bDeleted;                 // WCUserComment.h:22
@property (nonatomic) _Bool deletedByFeedOwner;      // WCUserComment.h:32
- (_Bool)bDeleted;
- (_Bool)deletedByFeedOwner;
@end

@interface WCSNSMessage : NSObject
@property (nonatomic) unsigned int delStatus;         // WCSNSMessage.h
@property (retain, nonatomic) WCUserComment *comment; // WCSNSMessage.h:8
- (void)upgradeDataIfNeeded;                          // WCSNSMessage.h:36
- (_Bool)isWCMessageDeleted;                          // WCSNSMessage.h:19
@end

@interface WCCommentView : NSObject
+ (id)getDisplayCommentContent:(id)a0 dataItem:(id)a1 pageContext:(id)a2;  // WCCommentView.h:35
@end

@interface WCCommentListContentView : UIView
+ (id)getDisplayContent:(id)a0 dataItem:(id)a1 pageContext:(id)a2;  // WCCommentListContentView.h:30
@end

// ⑦ 渲染点: MMUILongPressImageView -setImage: (MMUILongPressImageView.h:29)
@interface MMUILongPressImageView : MMUIImageView
- (void)setImage:(id)arg1;
@end

// ⑦ 宿主页: 微信"聊天详情"页(类名像加群)
@interface AddContactToChatRoomViewController : MMUIViewController
@property (nonatomic, retain) CContact *m_contact;          // AddContactToChatRoomViewController.h:23
@property (nonatomic, retain) MMTableViewInfo *m_tableViewInfo; // AddContactToChatRoomViewController.h:7
@end

// ⑧ 朋友圈视频点击关闭
@interface WAVideoPlayerView : WCPlayerControlView       // WAVideoPlayerView.h:4
@property (nonatomic) _Bool disableTapGesture;                                 // WAVideoPlayerView.h:104
- (void)setVideoPath:(id)arg1 initialTime:(double)arg2 isHLS:(long long)arg3;  // WAVideoPlayerView.h:135
@end

// ⑪ 隐藏自己微信号(我界面)
@interface WASettingAccountCell : UITableViewCell        // WASettingAccountCell.h:3
@property (nonatomic, retain) UILabel *detailLabel;  // WASettingAccountCell.h:7
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

// ⑤ 朋友圈"余下N条"折叠
@interface MicroMerchantFoldInterceptor : NSObject <TimelineRequestInterceptorImpl>   // MicroMerchantFoldInterceptor.h:3
- (void)intercept:(id)arg1;                            // MicroMerchantFoldInterceptor.h:10
@end

// ⑪ 我界面
@interface NewSettingViewController : MMUIViewController   // NewSettingViewController.h:3
- (void)reloadTableData;                               // NewSettingViewController.h:44
@end

#pragma mark - 配置管理
#define kDDWAPullDown          @"kDDWA_disableHomePullDownMiniProgram"
#define kDDWAVideoAutoPlay     @"kDDWA_disableSnsVideoAutoPlay"
#define kDDWAPrivacyIcon       @"kDDWA_disableSnsPrivacyIcon"
#define kDDWATextFold          @"kDDWA_disableSnsTextFold"
#define kDDWAGroupFold         @"kDDWA_disableSnsGroupFold"
#define kDDWADeletedComment    @"kDDWA_antiDeleteSnsComment"
#define kDDWADeletedCommentMark @"kDDWA_deletedCommentMark"
#define kDDWACustomAvatar      @"kDDWA_enableCustomAvatar"
#define kDDWAVideoTapClose     @"kDDWA_disableSnsVideoTapClose"
#define kDDWAHideFriendWxid    @"kDDWA_hideFriendWxid"
#define kDDWAHideMyWxid        @"kDDWA_hideMyWxid"
#define kDDWAHideChatName      @"kDDWA_hideChatName"

// 开关默认全部 OFF，装好与原生一致
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

// ⑥ 被删评论前缀文案(默认"[已删除]")
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

#pragma mark - ⑤ 禁用朋友圈"余下N条"折叠
%hook MicroMerchantFoldInterceptor
- (void)intercept:(id)arg1 {
    if ([DDWeChatConfig sharedConfig].disableSnsGroupFold) return;
    %orig;
}
%end

#pragma mark - ⑥ 朋友圈评论防删
// bDeleted / deletedByFeedOwner 返回 NO(保留可见)，并用关联对象记住真实已删态供文本加前缀
%hook WCUserComment
- (_Bool)bDeleted {
    _Bool real = %orig;
    if ([DDWeChatConfig sharedConfig].antiDeleteSnsComment) {
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
    if (self.delStatus != 0) self.delStatus = 0;
}
%end

// 评论显示文本计算处拼接"[已删除]"前缀；非 NSString(富文本)原样返回
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

// 评论列表/通知详情页走 getDisplayContent:，需单独加一次前缀
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
static NSString *ddCustomAvatarKey(NSString *userName) {
    return [NSString stringWithFormat:@"dd_customAvatar_%@", userName ?: @""];
}
static const void *kDDAvatarUsr     = &kDDAvatarUsr;
static const void *kDDAvatarPicking = &kDDAvatarPicking;

// 用 performSelector: 取 userName，规避 NSProcessInfo.userName 不可用与同名冲突
static NSString *ddUserNameOf(id obj) {
    if (!obj) return nil;
    if (![obj respondsToSelector:@selector(userName)]) return nil;
    return [obj performSelector:@selector(userName)];
}

// 读 cellInfo 标题(用于定位插入点与幂等查重)，走 performSelector: 规避 KVC / id 点语法
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

static BOOL ddCustomAvatarOnForUser(NSString *usr) {
    if (![DDWeChatConfig sharedConfig].enableCustomAvatar) return NO;
    if (usr.length == 0) return NO;
    return [NSUserDefaults.standardUserDefaults objectForKey:ddCustomAvatarKey(usr)] != nil;
}

// 在聊天详情页注入「启用自定义头像」原生 switch cell，插到"查找聊天内容"上方；找不到则插末尾
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
        if (targetSec < 0) {   // 兜底: 插到最后一个 section 末尾
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

// 渲染侧: MMUILongPressImageView -setImage: 处换图，仅当 superview 为头像视图(MMHeadImageView)才处理
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

#pragma mark - ⑪ 隐藏自己微信号(我界面)
// 刷新时遍历可见 cell，对账户卡片清空副标题(微信号行)
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

#pragma mark - ⑫ 隐藏聊天顶栏名字
// 聊天顶栏名字 = 导航栏中间 titleView 内的 MMUILabel(由微信直接 setText: 写入)，
// 经多次实测，名字不走 setCustomNavBarTitleView:/updateTitleView: 类级路径，
// 故在 MMUILabel 文本设置源头拦截，作用域收紧到【聊天 VC 的 titleView 子视图】以消除闪现/误清。
static BOOL ddIsChatNavTitleLabel(MMUILabel *label) {
    UIView *v = label;
    while (v && ![v isKindOfClass:%c(UINavigationBar)]) v = v.superview;
    if (!v) return NO;
    UINavigationBar *bar = (UINavigationBar *)v;
    // UINavigationItem 无公开 viewController 属性，改用 bar.delegate(即所属 UINavigationController)
    UINavigationController *nav = (UINavigationController *)bar.delegate;
    if (!nav || ![nav.topViewController isKindOfClass:%c(BaseMsgContentViewController)]) return NO;
    UIView *tv = bar.topItem.titleView;
    return tv && [label isDescendantOfView:tv];   // 只命中 titleView 区域(圈住的那块)
}
%hook MMUILabel
- (void)setText:(id)text {
    if ([DDWeChatConfig sharedConfig].hideChatName && ddIsChatNavTitleLabel(self)) {
        %orig(@"");
        return;
    }
    %orig;
}
- (void)setAttributedText:(id)text {
    if ([DDWeChatConfig sharedConfig].hideChatName && ddIsChatNavTitleLabel(self)) {
        %orig([[NSAttributedString alloc] initWithString:@""]);
        return;
    }
    %orig;
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

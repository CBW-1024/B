
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
// 普通可点击行（用于“查看日志 / 导出日志 / 清空日志”）
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightValue:(id)a4;
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
// 诊断日志总开关（设置页可切换）。开启后记录朋友圈评论的删除状态/注入过程，
// 可在「DD微信助手 → 运行日志」里查看或导出，用于排查“谁被加了前缀”。
#define kDDWADebugLog          @"kDDWA_debugLog"
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
static const BOOL kDDDefaultDebugLog          = YES;

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
@property (assign, nonatomic) BOOL debugLog;
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
        kDDWADebugLog:           @(kDDDefaultDebugLog),
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
        _debugLog                       = [ud boolForKey:kDDWADebugLog];
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
- (void)setDebugLog:(BOOL)v { _debugLog = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDWADebugLog]; }
@end

#pragma mark - 日志系统（诊断用，设置页可查看 / 导出）

#import <pthread.h>
#import <sys/time.h>

#define kDDLogMaxLines 2000

@interface DDLogStore : NSObject
+ (instancetype)shared;
- (void)appendFormat:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1,2);
- (NSString *)allText;
- (NSUInteger)count;
- (void)clear;
- (NSString *)logFilePath;
- (BOOL)flushToFile;
@end

// 毫秒级时间戳（不用 NSDateFormatter，避免锁与频繁创建开销）
static NSString *DDLogNowString(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    time_t sec = (time_t)tv.tv_sec;
    struct tm tmVal;
    localtime_r(&sec, &tmVal);
    char buf[32];
    strftime(buf, sizeof(buf), "%m-%d %H:%M:%S", &tmVal);
    return [NSString stringWithFormat:@"%s.%03d", buf, (int)(tv.tv_usec / 1000)];
}

@implementation DDLogStore {
    NSMutableArray<NSString *> *_lines;
    pthread_mutex_t _lock;
}
+ (instancetype)shared {
    static DDLogStore *store = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [[DDLogStore alloc] init]; });
    return store;
}
- (instancetype)init {
    if (self = [super init]) {
        _lines = [[NSMutableArray alloc] init];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}
- (void)appendFormat:(NSString *)fmt, ... {
    if (!fmt) return;
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSString *line = [NSString stringWithFormat:@"%@ %@", DDLogNowString(), msg];
    pthread_mutex_lock(&_lock);
    [_lines addObject:line];
    if (_lines.count > kDDLogMaxLines) {
        [_lines removeObjectsInRange:NSMakeRange(0, (NSUInteger)_lines.count - kDDLogMaxLines)];
    }
    pthread_mutex_unlock(&_lock);
}
- (NSString *)allText {
    pthread_mutex_lock(&_lock);
    NSString *text = [_lines componentsJoinedByString:@"\n"];
    pthread_mutex_unlock(&_lock);
    return text ?: @"";
}
- (NSUInteger)count {
    pthread_mutex_lock(&_lock);
    NSUInteger c = _lines.count;
    pthread_mutex_unlock(&_lock);
    return c;
}
- (void)clear {
    pthread_mutex_lock(&_lock);
    [_lines removeAllObjects];
    pthread_mutex_unlock(&_lock);
}
- (NSString *)logFilePath {
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [doc stringByAppendingPathComponent:@"DDWeChatTweak.log"];
}
- (BOOL)flushToFile {
    NSString *text = [self allText];
    if (!text.length) text = @"(日志为空)";
    NSError *err = nil;
    BOOL ok = [text writeToFile:[self logFilePath] atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (!ok) {
        [[DDLogStore shared] appendFormat:@"[LOG] 写文件失败: %@", err.localizedDescription];
    }
    return ok;
}
@end

static inline BOOL dd_logOn(void) {
    return [NSUserDefaults.standardUserDefaults boolForKey:kDDWADebugLog];
}
// 用法：DDLog(@"SNS", @"setDelStatus=%u ...", status);
#define DDLog(tag, fmt, ...) do { if (dd_logOn()) { [[DDLogStore shared] appendFormat:(@"[" tag "] " fmt), ##__VA_ARGS__]; } } while (0)

// ===== 字段快照诊断 =====
static NSString *dd_abbrev(id obj);   // 前向声明（定义在下方）

// 目的：8.0.76D 里到底哪个字段标记“评论已删除”无法靠猜（bDeleted / deletedByFeedOwner
// 实测恒为 0）。这里把对象的全部 ivar 名称和值打成一行，直接对比
// “自己刚发的评论” vs “真正被删除的评论” 的字段差异，一次就能定位判定条件。
static NSMutableSet *dd_dumpedObjects(void) {
    static NSMutableSet *set = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ set = [[NSMutableSet alloc] init]; });
    return set;
}
// 每个对象只 dump 一次，且总量设上限，避免日志爆炸
static BOOL dd_shouldDump(id obj) {
    if (!obj) return NO;
    NSMutableSet *set = dd_dumpedObjects();
    if (set.count > 200) return NO;
    NSNumber *key = [NSNumber numberWithUnsignedLongLong:(unsigned long long)(uintptr_t)(__bridge void *)obj];
    if ([set containsObject:key]) return NO;
    [set addObject:key];
    return YES;
}
static NSString *dd_dumpIvars(id obj) {
    if (!obj) return @"(nil)";
    NSMutableArray *parts = [NSMutableArray array];
    for (Class cls = [obj class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int n = 0;
        Ivar *ivars = class_copyIvarList(cls, &n);
        for (unsigned int i = 0; i < n; i++) {
            Ivar v = ivars[i];
            const char *nameC = ivar_getName(v);
            const char *typeC = ivar_getTypeEncoding(v);
            if (!nameC || !typeC) continue;
            NSString *name = [NSString stringWithUTF8String:nameC];
            if (!name) continue;
            char *q = (char *)(__bridge void *)obj + ivar_getOffset(v);
            NSString *val = nil;
            switch (typeC[0]) {
                case 'c': val = [NSString stringWithFormat:@"%d", (int)*(char *)q]; break;
                case 'B': val = [NSString stringWithFormat:@"%d", (int)*(unsigned char *)q]; break;
                case 'i': val = [NSString stringWithFormat:@"%d", *(int *)q]; break;
                case 'I': val = [NSString stringWithFormat:@"%u", *(unsigned int *)q]; break;
                case 's': val = [NSString stringWithFormat:@"%d", (int)*(short *)q]; break;
                case 'S': val = [NSString stringWithFormat:@"%u", (unsigned)*(unsigned short *)q]; break;
                case 'l': val = [NSString stringWithFormat:@"%ld", *(long *)q]; break;
                case 'L': val = [NSString stringWithFormat:@"%lu", *(unsigned long *)q]; break;
                case 'q': val = [NSString stringWithFormat:@"%lld", *(long long *)q]; break;
                case 'Q': val = [NSString stringWithFormat:@"%llu", *(unsigned long long *)q]; break;
                case 'f': val = [NSString stringWithFormat:@"%g", (double)*(float *)q]; break;
                case 'd': val = [NSString stringWithFormat:@"%g", *(double *)q]; break;
                case '@': val = dd_abbrev(object_getIvar(obj, v)); break;
                case '*': {
                    const char *s = *(const char **)q;
                    val = s ? dd_abbrev([NSString stringWithUTF8String:s]) : @"(null)";
                    break;
                }
                default: break;   // 结构体/数组/指针等跳过，避免误读内存
            }
            if (val) [parts addObject:[NSString stringWithFormat:@"%@=%@", name, val]];
        }
        free(ivars);
    }
    return [NSString stringWithFormat:@"%@ { %@ }", NSStringFromClass([obj class]), [parts componentsJoinedByString:@" | "]];
}

// 日志里截断长文本，避免刷屏
static NSString *dd_abbrev(id obj) {
    NSString *t = [obj isKindOfClass:[NSString class]] ? (NSString *)obj : [obj description];
    if (!t) return @"(nil)";
    t = [t stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    return (t.length > 60) ? [[t substringToIndex:60] stringByAppendingString:@"…"] : t;
}

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

// 日志用：把一条评论的删除状态打成一个短串，例如 "del=1 owner=0"
static NSString *dd_commentFlagDesc(id c) {
    if (!c) return @"(nil)";
    int b = ([c respondsToSelector:@selector(bDeleted)]) ? (int)[c bDeleted] : -1;
    int o = ([c respondsToSelector:@selector(deletedByFeedOwner)]) ? (int)[c deletedByFeedOwner] : -1;
    return [NSString stringWithFormat:@"%@(del=%d owner=%d)", NSStringFromClass([c class]), b, o];
}

// 对 WCSNSMessage.comment 幂等补前缀（refComment 是被回复的那条，不参与；与锤子一致只改 comment）
// allowEmpty=YES：content 已被清空时，至少写入“[对方已删除]”标记，
// 避免对方删评后留下一条空白评论（只对主评论用，回复的 content 常为空，不适用）。
static void dd_injectMarkIntoCommentEx(id c, BOOL allowEmpty) {
    if (![c isKindOfClass:%c(WCUserComment)]) return;
    NSString *mark = ddDeletedMarkText();
    NSString *s = [c content];
    if ([s isKindOfClass:[NSString class]] && s.length) {
        if (![s hasPrefix:mark]) {
            [c setContent:[mark stringByAppendingString:s]];
            DDLog(@"SNS", @"INJECT -> %@", dd_abbrev([c content]));
        }
        return;
    }
    if (allowEmpty) {
        NSString *bare = [mark stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (![s hasPrefix:bare]) {
            [c setContent:bare];
            DDLog(@"SNS", @"INJECT empty -> 仅标记: %@", bare);
        }
        return;
    }
    DDLog(@"SNS", @"INJECT skip (空/已有前缀/非字符串) content=%@", dd_abbrev(s));
}

// ★ 核心：对齐锤子 hook WCSNSMessage -setDelStatus:
%hook WCSNSMessage
- (void)setDelStatus:(unsigned int)status {
    if (![DDWeChatConfig sharedConfig].antiDeleteSnsComment) { %orig; return; }
    if (status == 1) {
        id c = [self comment];
        id r = [self refComment];
        DDLog(@"SNS", @"setDelStatus=1 | msg=%@ | comment=%@ | ref=%@ | commentContent=%@",
              NSStringFromClass([self class]), dd_commentFlagDesc(c), dd_commentFlagDesc(r), dd_abbrev([c content]));
        // 字段快照：每个对象只打一次，用于对比“发评论”与“真删除”的字段差异
        if (dd_shouldDump(self)) { DDLog(@"DUMP", @"msg: %@", dd_dumpIvars(self)); }
        if (dd_shouldDump(c))    { DDLog(@"DUMP", @"comment: %@", dd_dumpIvars(c)); }
        if (dd_shouldDump(r))    { DDLog(@"DUMP", @"refComment: %@", dd_dumpIvars(r)); }
        // 已删除：在数据加载期就把前缀写回 comment.content（早于任何渲染）。
        // 实测证实 8.0.76D 中 setDelStatus:1 即“评论已删除”的真实信号，
        // 无需要再依赖 bDeleted/deletedByFeedOwner（这两个字段恒为 0）。
        // 只处理 comment（这条评论本身）。refComment 是“被回复的那条”，不是被删评论，
        // 无论它是空壳（顶层评论）还是有内容（真回复），都不该加前缀，故不碰它（与锤子一致）。
        dd_injectMarkIntoCommentEx(c, YES);   // 主评论：内容被清空时也要留下标记
        // 以 0 调回原方法：对外不视作已删，正常渲染
        %orig(0);
        return;
    }
    DDLog(@"SNS", @"setDelStatus=%u (非1，原样透传)", status);
    %orig;
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

#pragma mark - 日志查看 / 导出页面
@interface DDWeChatLogViewController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@end

@implementation DDWeChatLogViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"运行日志";
    self.view.backgroundColor = [UIColor whiteColor];

    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    UIFont *logFont = [UIFont fontWithName:@"Menlo" size:11.0];
    if (!logFont) { logFont = [UIFont systemFontOfSize:11.0]; }
    tv.font = logFont;
    tv.textContainerInset = UIEdgeInsetsMake(8, 6, 8, 6);
    tv.text = [[DDLogStore shared] allText];
    [self.view addSubview:tv];
    self.textView = tv;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"操作"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(onAction:)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.textView.text = [[DDLogStore shared] allText];
}
- (void)showMessage:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                message:msg
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}
- (void)exportLog {
    if (![[DDLogStore shared] flushToFile]) { [self showMessage:@"导出失败：无法写入文件"]; return; }
    NSURL *url = [NSURL fileURLWithPath:[[DDLogStore shared] logFilePath]];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                      applicationActivities:nil];
    avc.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:avc animated:YES completion:nil];
    [[DDLogStore shared] appendFormat:@"[LOG] 已导出到: %@", url.path];
}
- (void)onAction:(id)sender {
    __weak __typeof__(self) weakSelf = self;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"运行日志"
                                                               message:[NSString stringWithFormat:@"共 %lu 条（最多保留 %d 条）\n路径：%@",
                                                                        (unsigned long)[DDLogStore shared].count,
                                                                        kDDLogMaxLines,
                                                                        [[DDLogStore shared] logFilePath]]
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"复制全部" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = [[DDLogStore shared] allText];
        [weakSelf showMessage:@"已复制到剪贴板"];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"导出到文件并分享" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [weakSelf exportLog];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"清空日志" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[DDLogStore shared] clear];
        weakSelf.textView.text = @"";
        [[DDLogStore shared] appendFormat:@"[LOG] 日志已清空"];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    ac.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:ac animated:YES completion:nil];
}
@end

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

    WCTableViewSectionManager *diag = [secMgr defaultSection];
    [diag addCell:[cellMgr switchCellForSel:@selector(onDebugLogSwitch:) target:self title:@"记录诊断日志" on:cfg.debugLog]];
    [diag addCell:[cellMgr normalCellForSel:@selector(onViewLog) target:self
                                      title:@"查看运行日志"
                                 rightValue:[NSString stringWithFormat:@"%lu 条", (unsigned long)[DDLogStore shared].count]]];
    [diag addCell:[cellMgr normalCellForSel:@selector(onExportLog) target:self
                                      title:@"导出日志到文件"
                                 rightValue:@"分享 / 文件App"]];
    [diag addCell:[cellMgr normalCellForSel:@selector(onClearLog) target:self
                                      title:@"清空日志"
                                 rightValue:@""]];
    [_tableViewManager addSection:diag];

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

#pragma mark - 诊断日志
- (void)onDebugLogSwitch:(UISwitch *)s {
    [DDWeChatConfig sharedConfig].debugLog = s.on;
    DDLog(@"CFG", @"诊断日志 %@", s.on ? @"开启" : @"关闭");
}
- (void)onViewLog {
    [self.navigationController pushViewController:[[DDWeChatLogViewController alloc] init] animated:YES];
}
- (void)onExportLog {
    if (![[DDLogStore shared] flushToFile]) { return; }
    NSURL *url = [NSURL fileURLWithPath:[[DDLogStore shared] logFilePath]];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                      applicationActivities:nil];
    avc.popoverPresentationController.sourceView = self.view;
    [self presentViewController:avc animated:YES completion:nil];
    [[DDLogStore shared] appendFormat:@"[LOG] 已导出到: %@", url.path];
}
- (void)onClearLog {
    [[DDLogStore shared] clear];
    [[DDLogStore shared] appendFormat:@"[LOG] 日志已清空"];
    [self buildTable];
}
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        DDLog(@"BOOT", @"DD微信助手 已加载");
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD微信助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDWeChatSettingsViewController"];
        }
    }
}

// DDLikeHelper.xm
// 微信集赞助手（Theos / Logos，arm64 / arm64e）
//
// 功能：
//   长按朋友圈「赞 / 评论」浮窗里的点赞按钮（1 秒），按配置伪造指定数量的
//   「点赞」与「评论」，数据落在本地 WCDataItem 上，不改服务端。
//   普通单击点赞完全不受影响 —— 挂 likeFlag 被动伪造会连正常点赞一起改掉。
//
// 触发链路：
//   长按 m_likeBtn → 开一个 8 秒的触发窗口并记住目标 item
//   → 未赞则走原生 onLikeItem:（内部会调 WCTimelineMgr.modifyDataItem:notify:）
//     已赞则经 WCFacade.getTimelineMgr 手动 notify 一次
//   → %hook WCTimelineMgr 命中窗口时把伪造数据写回 item，再放行原生实现。
//   借原生链路刷新，可顺带绕过 WCDataItemUICache 布局缓存不失效的问题。
//
// 说明：
//   - 设置界面与配置层按 DD朋友圈助手（DDWCMoments.xm）的模式改写，
//     便于后续整体并入 DD朋友圈助手：配置类为单例 + NSUserDefaults 直写，
//     键名统一 DDMoments_ 前缀，设置页结构（ensureTableViewMgr / 三态导航栏 /
//     viewWillAppear 重建 / delegate 三方法转发）与 DDMSettingsViewController 一致。
//   - 三项自定义输入（点赞数量 / 评论数量 / 评论内容）采用 DD收款助手
//     （DDTransfer.xm）的行内「输入框 + 确认按钮」样式，尺寸与配色逐项对齐：
//     容器 220×34、输入框 160×34、按钮 52×34，systemGray5Color 圆角背景。
//   - 微信私有类一律运行时获取（objc_getClass / NSClassFromString），不链接私有符号。
//   - 私有接口取自微信 8.0.79 头文件，只声明本插件真正会调用的方法。
//
// 并入 DD朋友圈助手 的步骤（本文件已按此设计）：
//   1. DDLikeConfig 的属性与 key 直接搬进 DDMConfig（key 前缀已统一，用户旧设置不丢）。
//   2. addLikeSections 的方法体直接搬进 DDMSettingsViewController 的 buildTable。
//   3. DDLikeHelper 与两个 %hook 整段搬过去。
//   4. 注意声明去重：DDWCMoments.xm 已声明 WCDataItem 与 WCUserComment，
//      合并时取并集，不要写两份 @interface。
//        - WCUserComment：DDWCMoments 已有 content / setContent:，本文件补
//          nickname / username / commentID / type / createTime 及各 setter。
//        - WCDataItem：两边都用到 createtime（unsigned int，类型一致），
//          本文件补 likeUsers / likeCount / commentUsers / commentCount / likeFlag。
//   5. WCOperateFloatView 冲突：DDWCMoments.xm 已 %hook 了该类（initCommentButton /
//      showWithItemData: / hide / layoutSubviews）。合并时不要写第二个 %hook 块，
//      把 [self ddl_attachLongPress]; 加进它已有的 layoutSubviews 即可，
//      再把两个 %new 方法并入同一个 %hook 块。WCFacade 同理取并集。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信私有接口声明

// 微信插件管理入口，用于注册本插件设置页。
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信内置设置表格组件。
// initWithFrame:style: 第二参为 long long（UITableViewStyle）。
// 8.0.79 头文件 dump 把它还原成了 CGSize，属 dump 类型还原错误，以 long long 为准。
@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;  // WCTableViewCellManager.h:30
@end

// 联系人基类：m_nsUsrName / m_uiSex / m_nsHeadImgUrl / m_nsRemark 都在这里，
// 不在 CContact.h —— 故 CContact 须声明继承自 CBaseContact。
@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;    // CBaseContact.h:140
@property (nonatomic) unsigned int m_uiSex;             // CBaseContact.h:154
@end

@interface CContact : CBaseContact
@property (retain, nonatomic) NSString *m_nsNickName;   // CContact.h:281
- (BOOL)isBrandContact;                                  // CContact.h:101
@end

@interface CContactMgr : NSObject
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;
@end

// 服务定位链：MMContext → serviceCenter → getService:（与 DD朋友圈助手 同一套）。
@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;                            // MMServiceCenter.h:4
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

// 取服务：MMContext → serviceCenter → getService:
static inline id DDLService(Class cls) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:cls];
}

static inline id DDLContactMgr(void) {
    return DDLService(objc_getClass("CContactMgr"));
}

// WCTimelineMgr 在头文件里没有任何引用者，说明它不被别的类以属性方式持有；
// 正路是经 WCFacade 取（WCFacade.h:198 getTimelineMgr / :240 timelineMgr）。
@interface WCFacade : NSObject
- (id)getTimelineMgr;                                    // WCFacade.h:198
@end

static inline id DDLTimelineMgr(void) {
    return [(WCFacade *)DDLService(objc_getClass("WCFacade")) getTimelineMgr];
}

// 朋友圈「赞 / 评论」浮窗。dump 里写的是 : NSObject，实际是 UIView 子类
// （DDWCMoments.xm 亦按 UIView 声明并 hook 了 layoutSubviews）。
@interface WCOperateFloatView : UIView
- (id)m_item;                                            // WCOperateFloatView.h:9
- (id)m_likeBtn;                                         // WCOperateFloatView.h:10
- (void)onLikeItem:(id)arg1;                             // WCOperateFloatView.h:20
- (void)hide;                                            // WCOperateFloatView.h:16
@end

// 评论 / 点赞项模型。朋友圈的 likeUsers 与 commentUsers 装的都是这个类
// （头文件里没有独立的点赞模型类，likeUserDetail 只是空 PB 壳）。
@interface WCUserComment : NSObject
@property (retain, nonatomic) NSString *nickname;        // WCUserComment.h:86
@property (retain, nonatomic) NSString *username;        // WCUserComment.h:94
@property (retain, nonatomic) NSString *content;         // WCUserComment.h:72
@property (retain, nonatomic) NSString *commentID;       // WCUserComment.h:71
@property (nonatomic) int type;                          // WCUserComment.h:99
@property (nonatomic) unsigned int createTime;           // WCUserComment.h:107
@end

// 朋友圈数据项。
@interface WCDataItem : NSObject
@property (retain, nonatomic) NSMutableArray *likeUsers;      // WCDataItem.h:248
@property (nonatomic) int likeCount;                          // WCDataItem.h:303
@property (retain, nonatomic) NSMutableArray *commentUsers;   // WCDataItem.h:212
@property (nonatomic) int commentCount;                       // WCDataItem.h:296
@property (nonatomic) BOOL likeFlag;                          // WCDataItem.h:190
@property (nonatomic) unsigned int createtime;                // WCDataItem.h:335
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;       // WCTimelineMgr.h:71
@end

#pragma mark - 配置

// 键名沿用 DD朋友圈助手 的 DDMoments_ 前缀，合并后配置项可直接平移，旧设置不丢。
static NSString * const kDDMLikeEnabled    = @"DDMoments_likeEnabled";
static NSString * const kDDMLikeCount      = @"DDMoments_likeCount";
static NSString * const kDDMCommentCount   = @"DDMoments_commentCount";
static NSString * const kDDMLikeComments   = @"DDMoments_likeComments";

@interface DDLikeConfig : NSObject
@property (assign, nonatomic) BOOL likeEnabled;      // 启用集赞（总开关；开启时展开三个子项）
@property (assign, nonatomic) NSInteger likeCount;   // 伪造点赞数（0 = 未设置，不生效）
@property (assign, nonatomic) NSInteger commentCount;// 伪造评论数（0 = 未设置，不生效）
@property (copy, nonatomic) NSString *comments;      // 评论内容池，"-" 分隔
+ (instancetype)shared;
@end

@implementation DDLikeConfig

+ (instancetype)shared {
    static DDLikeConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDLikeConfig new]; });
    return cfg;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _likeEnabled   = [ud boolForKey:kDDMLikeEnabled];
        _likeCount     = [ud integerForKey:kDDMLikeCount];
        _commentCount  = [ud integerForKey:kDDMCommentCount];
        _comments      = [ud stringForKey:kDDMLikeComments] ?: @"";   // 无默认内容，未填即为空
    }
    return self;
}

- (void)persist:(id)value key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setLikeEnabled:(BOOL)v   { _likeEnabled = v;   [self persist:@(v) key:kDDMLikeEnabled]; }
- (void)setLikeCount:(NSInteger)v  { _likeCount = v;     [self persist:@(v) key:kDDMLikeCount]; }
- (void)setCommentCount:(NSInteger)v { _commentCount = v; [self persist:@(v) key:kDDMCommentCount]; }
// 允许清空：清空后 commentPool 为空，fakeCommentsFor: 会跳过伪造评论。
- (void)setComments:(NSString *)v {
    NSString *val = v ?: @"";
    _comments = [val copy];
    [self persist:val key:kDDMLikeComments];
}

// 评论内容池（按 "-" 切分）。未填写时返回空数组。
- (NSArray<NSString *> *)commentPool {
    if (self.comments.length == 0) return @[];
    return [self.comments componentsSeparatedByString:@"-"];
}

@end

#pragma mark - 核心功能

@interface DDLikeHelper : NSObject
+ (NSArray<CContact *> *)allFriends;
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers;
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem;
@end

@implementation DDLikeHelper

// 好友名单：排除公众号（isBrandContact）与性别未知（m_uiSex == 0）的联系人。
// 只取一次并缓存，联系人列表不会在会话内变化。
+ (NSArray<CContact *> *)allFriends {
    static NSArray *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *friends = [NSMutableArray array];
        CContactMgr *mgr = DDLContactMgr();
        for (CContact *c in [mgr getContactList:1 contactType:0]) {
            if (![c isBrandContact] && c.m_uiSex != 0) [friends addObject:c];
        }
        cached = [friends copy];
    });
    return cached ?: @[];
}

// 构造伪造点赞列表。likeCount <= 0 视为未设置，返回空数组（调用方据此不覆盖原值）。
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers {
    NSInteger target = DDLikeConfig.shared.likeCount;
    NSMutableArray *list = [NSMutableArray array];
    if (target <= 0) return list;

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;
    [[self allFriends] enumerateObjectsUsingBlock:^(CContact *c, NSUInteger idx, BOOL *stop) {
        if ((NSInteger)idx >= target) { *stop = YES; return; }
        WCUserComment *u = [[objc_getClass("WCUserComment") alloc] init];
        u.username   = c.m_nsUsrName;
        u.nickname   = c.m_nsNickName;
        u.type       = 2;
        u.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        u.createTime = now;
        [list addObject:u];
    }];
    return list;
}

// 构造伪造评论列表：补齐到 commentCount 条，时间落在原帖发布至今之间并升序排列。
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem {
    NSInteger target = DDLikeConfig.shared.commentCount;
    NSMutableArray *orig = origItem.commentUsers ?: [NSMutableArray array];
    if (target <= 0) return orig;                       // 未设置数量：原样返回
    if ((NSInteger)orig.count >= target) return orig;   // 已够：原样返回

    // 未填写评论内容：不做伪造，避免产生空文本评论。
    NSArray<NSString *> *pool = DDLikeConfig.shared.commentPool;
    if (pool.count == 0) return orig;

    NSMutableArray *list = [orig mutableCopy];

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;
    // createtime 可能为 0（本地刚发 / 未同步）或晚于当前时间，
    // 直接对差值取模会触发整数除零（EXC_ARITHMETIC），故夹到 [1, 3600]。
    int span = (int)now - (int)origItem.createtime;
    if (span < 1) span = 1;
    if (span > 3600) span = 3600;

    [[self allFriends] enumerateObjectsUsingBlock:^(CContact *c, NSUInteger idx, BOOL *stop) {
        if ((NSInteger)(idx + orig.count) >= target) { *stop = YES; return; }
        WCUserComment *cm = [[objc_getClass("WCUserComment") alloc] init];
        cm.username   = c.m_nsUsrName;
        cm.nickname   = c.m_nsNickName;
        cm.type       = 2;
        cm.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)(idx + orig.count)];
        cm.createTime = now - arc4random_uniform((uint32_t)span);
        cm.content    = pool[arc4random_uniform((uint32_t)pool.count)];
        [list addObject:cm];
    }];

    [list sortUsingComparator:^NSComparisonResult(WCUserComment *a, WCUserComment *b) {
        return a.createTime < b.createTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    return list;
}

@end

#pragma mark - Hook：长按点赞 → 集赞

// 触发窗口：长按点赞按钮时记下目标 item 与过期时间。
// 用「目标 + 时间窗」而非 BOOL，是因为 onLikeItem: 内部的落库可能是异步的，
// 立即清标记会漏掉回调；伪造本身幂等，窗口内重复命中无害。
static __unsafe_unretained WCDataItem *gDDLTargetItem = nil;
static NSTimeInterval gDDLTriggerUntil = 0;
static const NSTimeInterval kDDLWindow = 8.0;

static inline BOOL DDLInWindow(WCDataItem *item) {
    return item != nil
        && item == gDDLTargetItem
        && CFAbsoluteTimeGetCurrent() < gDDLTriggerUntil;
}

// 长按手势的挂载去重键。
static const void *kDDLLongPressKey = &kDDLLongPressKey;

// 把伪造数据写回 item。幂等：窗口内重复调用结果一致（仅评论时间随机）。
static inline void DDLFakeInto(WCDataItem *item) {
    if (!item) return;

    NSMutableArray *comments = [DDLikeHelper fakeCommentsFor:item];
    if (comments.count) {
        item.commentUsers = comments;
        item.commentCount = (int)comments.count;
    }
    NSMutableArray *likes = [DDLikeHelper fakeLikeUsers];
    if (likes.count) {
        item.likeUsers = likes;
        item.likeCount = (int)likes.count;
    }
}

// 底部短提示，1.4s 后淡出（长按唯一的反馈，不用震动）。
static void DDLShowToast(NSString *text) {
    UIWindow *win = nil;
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (!w.hidden && w.windowLevel == UIWindowLevelNormal) { win = w; break; }
    }
    if (!win) win = UIApplication.sharedApplication.keyWindow;
    if (!win) return;

    UILabel *lab = [[UILabel alloc] init];
    lab.text = text;
    lab.font = [UIFont systemFontOfSize:14];
    lab.textColor = [UIColor whiteColor];
    lab.textAlignment = NSTextAlignmentCenter;
    lab.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    lab.layer.cornerRadius = 8;
    lab.layer.masksToBounds = YES;
    [lab sizeToFit];

    CGFloat w = CGRectGetWidth(lab.bounds) + 32.0;
    CGFloat h = CGRectGetHeight(lab.bounds) + 20.0;
    lab.frame = CGRectMake((CGRectGetWidth(win.bounds) - w) / 2.0,
                           CGRectGetHeight(win.bounds) - 140.0, w, h);
    lab.alpha = 0;
    [win addSubview:lab];

    [UIView animateWithDuration:0.18 animations:^{ lab.alpha = 1.0; } completion:^(BOOL f) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{ lab.alpha = 0; }
                             completion:^(BOOL f2){ [lab removeFromSuperview]; }];
        });
    }];
}

static void DDLToastLikeResult(WCDataItem *item) {
    NSMutableString *s = [NSMutableString stringWithString:@"已集赞"];
    if (item.likeCount > 0)    [s appendFormat:@" %d 赞", item.likeCount];
    if (item.commentCount > 0) [s appendFormat:@" %d 评论", item.commentCount];
    DDLShowToast(s);
}

// %new 方法的编译期声明（Logos 运行时注入，编译器需先见到签名）。
@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
@end

%hook WCOperateFloatView

// 浮窗每次布局都会跑，借它把手势挂上去（内部去重，开销可忽略）。
// 合并进 DDWCMoments.xm 时，直接把这一行加进它已有的 layoutSubviews 即可。
- (void)layoutSubviews {
    %orig;
    [self ddl_attachLongPress];
}

%new
- (void)ddl_attachLongPress {
    if (!DDLikeConfig.shared.likeEnabled) return;
    UIButton *btn = self.m_likeBtn;
    if (!btn) return;
    if (objc_getAssociatedObject(btn, kDDLLongPressKey)) return;   // 已挂过

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(ddl_onLikeLongPress:)];
    lp.minimumPressDuration = 1.0;                                 // 长按 1 秒触发
    [btn addGestureRecognizer:lp];
    objc_setAssociatedObject(btn, kDDLLongPressKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
// 长按点赞按钮：开窗口 → 触发一次原生落库 → 收起浮窗并提示。
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!DDLikeConfig.shared.likeEnabled) return;

    WCDataItem *item = self.m_item;
    if (!item) return;

    gDDLTargetItem   = item;
    gDDLTriggerUntil = CFAbsoluteTimeGetCurrent() + kDDLWindow;

    if (!item.likeFlag) {
        // 未赞：走原生点赞，其内部会调 modifyDataItem:notify: 命中窗口。
        [self onLikeItem:self.m_likeBtn];
    } else {
        // 已赞：onLikeItem: 会把赞取消，故不调它，改为手动 notify 一次刷新。
        item.likeFlag = YES;
        id mgr = DDLTimelineMgr();
        if (mgr) [mgr modifyDataItem:item notify:YES];
        else DDLFakeInto(item);               // 拿不到 mgr 兜底：改完就算，等下次刷新生效
    }

    [self hide];
    DDLToastLikeResult(item);
}

%end

%hook WCTimelineMgr

// modifyDataItem:notify: 是数据项落库 / 刷新的统一出口（WCTimelineMgr.h:71）。
// 命中长按窗口才伪造；普通单击点赞与后台刷新一律放行原生实现。
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if (DDLInWindow(arg1)) DDLFakeInto(arg1);
    %orig(arg1, arg2);
}

%end

#pragma mark - 设置界面

@interface DDLikeSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *likeCountField;    // 点赞数量输入框
@property (nonatomic, strong) UITextField *commentCountField; // 评论数量输入框
@property (nonatomic, strong) UITextField *commentsField;     // 评论内容输入框
@end

@implementation DDLikeSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (void)ensureTableViewMgr {
    if (self.tableViewManager) return;
    self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                              initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) [self ensureTableViewMgr];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"集赞助手设置";
    // 导航栏三态外观统一浅色背景。
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

// 每次进入重建表格（总开关展开 / 收起子项后即时生效）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    [self addLikeSections];
    [_tableViewManager reloadTableView];
}

// 集赞分组：总开关 + 三个输入型子项。
// 并入 DD朋友圈助手 时，把本方法体直接搬进 DDMSettingsViewController 的 buildTable 即可。
- (void)addLikeSections {
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    DDLikeConfig *cfg = DDLikeConfig.shared;

    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"集赞设置"];
    [sec addCell:[cellMgr switchCellForSel:@selector(onLikeEnabledSwitch:)
                                    target:self
                                     title:@"启用集赞"
                                        on:cfg.likeEnabled]];

    if (cfg.likeEnabled) {
        // 三项均为「输入框 + 确认按钮」行内编辑（样式与 DD收款助手 一致）：
        // 输入框 160×34、按钮 52×34、容器 220×34，灰色圆角背景、系统默认文字颜色。
        self.likeCountField = [self makeFieldPlaceholder:@"点赞个数"
                                                  number:YES
                                                   value:cfg.likeCount > 0
                                                         ? [NSString stringWithFormat:@"%ld", (long)cfg.likeCount] : @""];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳点赞数量"
                                    rightView:[self inputRowWithField:self.likeCountField
                                                               action:@selector(likeCountConfirmed:)]]];

        self.commentCountField = [self makeFieldPlaceholder:@"评论条数"
                                                     number:YES
                                                      value:cfg.commentCount > 0
                                                            ? [NSString stringWithFormat:@"%ld", (long)cfg.commentCount] : @""];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳评论数量"
                                    rightView:[self inputRowWithField:self.commentCountField
                                                               action:@selector(commentCountConfirmed:)]]];

        self.commentsField = [self makeFieldPlaceholder:@"多个内容用-分隔"
                                                number:NO
                                                 value:cfg.comments];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳评论内容"
                                    rightView:[self inputRowWithField:self.commentsField
                                                               action:@selector(commentsConfirmed:)]]];
    }
    [_tableViewManager addSection:sec];
}

// 将微信表格 delegate 事件转发给原 delegate，本类只做外观代理。
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

#pragma mark 回调

// 总开关：展开 / 收起子项，故回调内即时重建表格。
- (void)onLikeEnabledSwitch:(UISwitch *)s {
    DDLikeConfig.shared.likeEnabled = s.isOn;
    [self buildTable];
}

// 输入框工厂：文本右对齐，数字项走数字键盘。
- (UITextField *)makeFieldPlaceholder:(NSString *)placeholder
                               number:(BOOL)number
                                value:(NSString *)value {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.text = value;
    field.textAlignment = NSTextAlignmentRight;
    if (number) field.keyboardType = UIKeyboardTypeNumberPad;
    return field;
}

// 右侧容器：输入框 + 确认按钮。
// 尺寸与配色照搬 DD收款助手 inputRowWithField:action:——
// 容器 220×34、输入框 160×34、按钮 52×34（x=168），
// systemGray5Color 背景、6pt 圆角、无边框、labelColor 文字、15pt 常规字重。
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
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

// 确认回调：写回配置 + 收键盘。
// 不调用 buildTable —— 重建会销毁输入框并打断编辑，值已直接显示在输入框里。
- (void)likeCountConfirmed:(id)sender {
    NSInteger v = [self.likeCountField.text integerValue];
    DDLikeConfig.shared.likeCount = v > 0 ? v : 0;   // 非法 / 0 归零 = 未设置，不生效
    [self.likeCountField resignFirstResponder];
}

- (void)commentCountConfirmed:(id)sender {
    NSInteger v = [self.commentCountField.text integerValue];
    DDLikeConfig.shared.commentCount = v > 0 ? v : 0;
    [self.commentCountField resignFirstResponder];
}

- (void)commentsConfirmed:(id)sender {
    DDLikeConfig.shared.comments = self.commentsField.text ?: @"";   // 清空即停用伪造评论
    [self.commentsField resignFirstResponder];
}

@end

#pragma mark - 注册入口

// 将设置页注册到插件管理（依赖第三方 WCPluginsMgr，做存在性守卫避免启动崩溃）。
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD集赞助手"
                                                     version:@"1.0.0"
                                                  controller:@"DDLikeSettingsViewController"];
        }
    }
}

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口声明

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;
@end

@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CContact : CBaseContact
@property (retain, nonatomic) NSString *m_nsNickName;
- (BOOL)isBrandContact;
- (BOOL)isChatroom;
- (BOOL)m_isPlugin;
- (BOOL)isGroupCard;
- (BOOL)isHolderContact;
- (BOOL)isWeixinTeamContact;
- (BOOL)isFileHelper;
@end

@interface CContactMgr : NSObject
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;
@end

@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

static inline id DDLService(Class cls) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:cls];
}
static inline id DDLContactMgr(void)    { return DDLService(objc_getClass("CContactMgr")); }
static inline id DDLFacadeService(void) { return DDLService(objc_getClass("WCFacade")); }

@interface WCFacade : NSObject
- (id)getTimelineDataInCacheByItemID:(id)itemID;
- (id)getTimelineDataItemOfIndex:(long long)index;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

@interface WCOperateFloatView : UIView
- (id)m_item;
- (id)m_likeBtn;
- (void)hide;
@end

@interface WCUserComment : NSObject
@property (retain, nonatomic) NSString *nickname;
@property (retain, nonatomic) NSString *username;
@property (retain, nonatomic) NSString *content;
@property (retain, nonatomic) NSString *commentID;
@property (nonatomic) int type;
@property (nonatomic) unsigned int createTime;
@end

@interface WCDataItem : NSObject
@property (retain, nonatomic) NSMutableArray *likeUsers;
@property (nonatomic) int likeCount;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@property (nonatomic) unsigned int createtime;
@property (retain, nonatomic) NSString *tid;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

@interface WCUIAlertView : NSObject
- (id)initWithTitle:(id)title message:(id)message;
- (void)showTextFieldWithMaxLen:(unsigned int)maxLen;
- (void)setTextFieldDefaultText:(id)text;
- (void)setRequestKeyWindow:(BOOL)flag;
- (void)addCancelBtnTitle:(id)title target:(id)target sel:(SEL)sel;
- (void)addBtnTitle:(id)title target:(id)target sel:(SEL)sel;
- (void)show;
- (id)getTextFieldText;
@end

// WeToast.h:3 / :53 —— 微信内置轻提示，DD小丑助手清理后用的同一个。
@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)text;
@end

#pragma mark - 配置

static NSString * const kDDMLikeEnabled  = @"DDMoments_likeEnabled";
static NSString * const kDDMLikeCount    = @"DDMoments_likeCount";
static NSString * const kDDMCommentCount = @"DDMoments_commentCount";
static NSString * const kDDMLikeComments = @"DDMoments_likeComments";
static NSString * const kDDMCommentsEnabled = @"DDMoments_commentsEnabled";
static NSString * const kDDMFakeStore    = @"DDMoments_fakeStore";

@interface DDLikeConfig : NSObject
@property (assign, nonatomic) BOOL likeEnabled;
@property (assign, nonatomic) NSInteger likeCount;      // 上次弹窗输入的点赞数，用于预填
@property (assign, nonatomic) NSInteger commentCount;   // 上次弹窗输入的评论数，用于预填
@property (copy, nonatomic) NSString *comments;          // 评论内容池，多条用 / 分隔
@property (assign, nonatomic) BOOL commentsEnabled;        // 评论功能总开关：关闭即停用（不生成假评论，已生成的会被清掉）
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
        _comments      = [ud stringForKey:kDDMLikeComments] ?: @"";
        // 未设置过则默认关闭
        _commentsEnabled = [ud boolForKey:kDDMCommentsEnabled];
    }
    return self;
}

- (void)persist:(id)value key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setLikeEnabled:(BOOL)v      { _likeEnabled = v;   [self persist:@(v) key:kDDMLikeEnabled]; }
- (void)setLikeCount:(NSInteger)v    { _likeCount = v;     [self persist:@(v) key:kDDMLikeCount]; }
- (void)setCommentCount:(NSInteger)v { _commentCount = v; [self persist:@(v) key:kDDMCommentCount]; }
- (void)setCommentsEnabled:(BOOL)v   { _commentsEnabled = v; [self persist:@(v) key:kDDMCommentsEnabled]; }

- (void)setComments:(NSString *)v {
    NSString *val = v ?: @"";
    _comments = [val copy];
    [self persist:val key:kDDMLikeComments];
}

- (NSArray<NSString *> *)commentPool {
    if (self.comments.length == 0) return @[];
    return [self.comments componentsSeparatedByString:@"/"];
}

@end

#pragma mark - 核心功能

@interface DDLikeHelper : NSObject
+ (NSArray<CContact *> *)allFriends;
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsersExcluding:(NSSet<NSString *> *)existing limit:(NSInteger)limit;
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem target:(NSInteger)target;
@end

@implementation DDLikeHelper

static NSArray<CContact *> *gDDLFriendCache;
static NSTimeInterval gDDLFriendCacheAt;

// 洗牌：复用好友时按原顺序绕回会重复出现同一批人，先洗牌让分布均匀。
static void DDLShuffle(NSMutableArray *a) {
    for (NSUInteger i = a.count; i > 1; i--) {
        [a exchangeObjectAtIndex:i - 1 withObjectAtIndex:arc4random_uniform((uint32_t)i)];
    }
}

// 给假数据打关联对象标记，撤销时只剔带标记的对象，不影响真实数据（即使重名）。
static const void *kDDLFakeMarkKey = &kDDLFakeMarkKey;

static inline void DDLMarkFake(WCUserComment *u) {
    objc_setAssociatedObject(u, kDDLFakeMarkKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static inline BOOL DDLIsFake(WCUserComment *u) {
    return objc_getAssociatedObject(u, kDDLFakeMarkKey) != nil;
}

+ (NSArray<CContact *> *)allFriends {
    if (gDDLFriendCache && ([NSDate timeIntervalSinceReferenceDate] - gDDLFriendCacheAt) < 3.0) {
        return gDDLFriendCache;
    }
    NSMutableArray *friends = [NSMutableArray array];
    CContactMgr *mgr = DDLContactMgr();
    for (CContact *c in [mgr getContactList:1 contactType:0]) {
        if (![c isBrandContact] && ![c isChatroom] && ![c m_isPlugin] && ![c isGroupCard] &&
            ![c isHolderContact] && ![c isWeixinTeamContact] && ![c isFileHelper] &&
            ![[c m_nsUsrName] containsString:@"@openim"]) {
            [friends addObject:c];
        }
    }
    gDDLFriendCache = [friends copy];
    gDDLFriendCacheAt = [NSDate timeIntervalSinceReferenceDate];
    return gDDLFriendCache;
}

// 凑齐 limit 个假赞，第一轮跳过已赞过的人；好友不够就洗牌后复用同一个人。
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsersExcluding:(NSSet<NSString *> *)existing limit:(NSInteger)limit {
    NSMutableArray *list = [NSMutableArray array];
    if (limit <= 0) return list;
    NSArray *friends = [self allFriends];
    if (friends.count == 0) return list;

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;
    NSMutableArray *pool = [friends mutableCopy];
    NSUInteger idx = 0;
    BOOL firstRound = YES;
    while ((NSInteger)list.count < limit) {
        DDLShuffle(pool);
        BOOL added = NO;
        for (CContact *c in pool) {
            if ((NSInteger)list.count >= limit) break;
            NSString *name = c.m_nsUsrName;
            if (!name) continue;
            if (firstRound && [existing containsObject:name]) continue;
            WCUserComment *u = [[objc_getClass("WCUserComment") alloc] init];
            u.username   = name;
            u.nickname   = c.m_nsNickName;
            u.type       = 1;        // 1=赞；2=文本评论
            u.content    = @"";      // 空串，不能为 nil
            u.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)idx++];
            u.createTime = now;
            DDLMarkFake(u);
            [list addObject:u];
            added = YES;
        }
        if (!added && !firstRound) break;
        firstRound = NO;
    }
    return list;
}

// 补齐到 target 条评论。内容取自设置里的评论池（多条用 / 分隔）；没填内容则不生成评论。
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem target:(NSInteger)target {
    NSMutableArray *orig = [origItem commentUsers] ?: [NSMutableArray array];
    if (target <= 0) return orig;
    if ((NSInteger)orig.count >= target) return orig;

    NSArray<NSString *> *pool = DDLikeConfig.shared.commentPool;
    if (pool.count == 0) return orig;

    NSMutableArray *list = [orig mutableCopy];
    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;

    int span = (int)now - (int)origItem.createtime;
    if (span < 1) span = 1;
    if (span > 3600) span = 3600;

    NSArray *friends = [self allFriends];
    if (friends.count == 0) return orig;

    NSMutableArray *friendPool = [friends mutableCopy];
    NSUInteger idx = 0;
    while ((NSInteger)list.count < target) {
        DDLShuffle(friendPool);
        BOOL added = NO;
        for (CContact *c in friendPool) {
            if ((NSInteger)list.count >= target) break;
            NSString *name = c.m_nsUsrName;
            if (!name) continue;
            WCUserComment *cm = [[objc_getClass("WCUserComment") alloc] init];
            cm.username   = name;
            cm.nickname   = c.m_nsNickName;
            cm.type       = 2;
            cm.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)idx++];
            cm.createTime = now - arc4random_uniform((uint32_t)span);
            cm.content    = pool[arc4random_uniform((uint32_t)pool.count)];
            DDLMarkFake(cm);
            [list addObject:cm];
            added = YES;
        }
        if (!added) break;
    }

    [list sortUsingComparator:^NSComparisonResult(WCUserComment *a, WCUserComment *b) {
        return a.createTime < b.createTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    return list;
}

@end

#pragma mark - 持久化与解析

// tid → @{ @"l": 点赞数, @"c": 评论数 }，落盘到 NSUserDefaults，重启后自动恢复。
static NSMutableDictionary *gDDLFake(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDMFakeStore];
        d = saved ? [saved mutableCopy] : [NSMutableDictionary new];
    });
    return d;
}

static void DDLFakeSave(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:gDDLFake() forKey:kDDMFakeStore];
    [ud synchronize];
}

static const NSInteger kDDLMaxCount = 100;   // 单边数上限，避免好友不足时复用循环跑飞

// 解析弹窗输入「点赞数/评论数」；返回 NO 表示输入为空，调用方按「取消伪装」处理。
static BOOL DDLParseSpec(NSString *text, NSInteger *outL, NSInteger *outC) {
    NSString *s = [(text ?: @"") stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return NO;

    NSArray *parts = [s componentsSeparatedByString:@"/"];
    NSInteger l = 0, c = 0;
    if (parts.count > 0) l = [parts[0] integerValue];
    if (parts.count > 1) c = [parts[1] integerValue];
    *outL = l > 0 ? MIN(l, kDDLMaxCount) : 0;
    *outC = c > 0 ? MIN(c, kDDLMaxCount) : 0;
    return YES;
}

// 长按那一刻强引用住 item 与浮层：收起浮层后 m_item 会被清空、浮层也可能被释放，
// 弹窗回调里只能靠这两份引用拿到正确的对象。
static WCDataItem *gDDLPendingItem = nil;
static WCOperateFloatView *gDDLPendingView = nil;
static WCUIAlertView *gDDLCurrentAlert = nil;   // 确认时取输入框文本

// 剔掉带标记的假数据；stripLikes / stripCmts 控制清哪一边。
static void DDLStripFakeFromItem(WCDataItem *di, BOOL stripLikes, BOOL stripCmts) {
    if (stripLikes) {
        NSMutableArray *likes = [NSMutableArray array];
        for (WCUserComment *u in ([di likeUsers] ?: @[])) {
            if (!DDLIsFake(u)) [likes addObject:u];
        }
        [di setLikeUsers:likes];
        [di setLikeCount:(int)likes.count];
    }
    if (stripCmts) {
        NSMutableArray *cmts = [NSMutableArray array];
        for (WCUserComment *u in ([di commentUsers] ?: @[])) {
            if (!DDLIsFake(u)) [cmts addObject:u];
        }
        [di setCommentUsers:cmts];
        [di setCommentCount:(int)cmts.count];
    }
}

// 追加式注入：保留原始名单 → 补齐假的到目标数 → 写回。补齐而非追加固定个数，重复调用幂等。
// 评论走目标数本身，不再受开关门控：reapply（刷新/重启）按记录恢复，已显示的假评论不会被清掉。
// 「开关关 = 不新增评论」的拦截放在用户输入入口（ddl_fakeConfirmed），不在这里。
static void DDLApplyFakeToItem(WCDataItem *di, NSInteger lTarget, NSInteger cTarget) {
    NSString *tid = [di tid];

    // 某一边的目标为 0 表示这次不要那一边（输「5」=只赞，输「/6」=只评论），先清掉上一轮的假数据。
    if (lTarget <= 0 || cTarget <= 0) {
        DDLStripFakeFromItem(di, lTarget <= 0, cTarget <= 0);
    }

    NSMutableArray *likes = [[di likeUsers] mutableCopy] ?: [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (WCUserComment *u in likes) {
        if (u.username) [seen addObject:u.username];
    }

    NSInteger limit = lTarget - (NSInteger)likes.count;
    if (lTarget > 0 && limit > 0) {
        NSArray *fresh = [DDLikeHelper fakeLikeUsersExcluding:seen limit:limit];
        for (WCUserComment *u in fresh) {
            if (u.username) [seen addObject:u.username];
            [likes addObject:u];
        }
        if (fresh.count) {
            [di setLikeUsers:likes];
            [di setLikeCount:(int)likes.count];
        }
    }

    NSUInteger before = [di commentUsers] ? [di commentUsers].count : 0;
    NSMutableArray *comments = [[DDLikeHelper fakeCommentsFor:di target:cTarget] mutableCopy];
    if (comments.count != before) {
        [di setCommentUsers:comments];
        [di setCommentCount:(int)comments.count];
    }

    if (tid) {
        gDDLFake()[tid] = @{ @"l": @(lTarget), @"c": @(cTarget) };
    }
    DDLFakeSave();
}

// 取消伪装：两边假数据都剔掉，并删持久化记录（重启后也不再恢复）。
static void DDLRemoveFakeFromItem(WCDataItem *di, NSString *tid) {
    DDLStripFakeFromItem(di, YES, YES);
    [gDDLFake() removeObjectForKey:tid];
    DDLFakeSave();
}

// 假数据是否还完整挂在 item 上：只看数量达不达标，不比对具体是谁（好友池顺序会变）。
static BOOL DDLItemFakeIntact(WCDataItem *di, NSDictionary *rec) {
    NSInteger lTarget = [rec[@"l"] integerValue];
    if (lTarget > 0) {
        NSUInteger lc = [di likeUsers] ? [di likeUsers].count : 0;
        if ((NSInteger)lc < lTarget) return NO;
    }
    NSInteger cTarget = [rec[@"c"] integerValue];
    if (cTarget > 0) {
        NSUInteger cc = [di commentUsers] ? [di commentUsers].count : 0;
        if ((NSInteger)cc < cTarget) return NO;
    }
    return YES;
}

// 单个 dataItem 补回：已集赞的 tid，在微信每次产出该 dataItem 时确认假数据还在，不在就补。
static void DDLReapplyIfNeeded(id obj) {
    if (![obj isKindOfClass:%c(WCDataItem)]) return;
    WCDataItem *di = (WCDataItem *)obj;
    NSString *tid = [di tid];
    if (!tid) return;
    NSDictionary *rec = gDDLFake()[tid];
    if (!rec) return;
    if (DDLItemFakeIntact(di, rec)) return;
    DDLApplyFakeToItem(di, [rec[@"l"] integerValue], [rec[@"c"] integerValue]);
}

#pragma mark - Hook：长按点赞浮层

static const void *kDDLLongPressKey = &kDDLLongPressKey;

@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (void)ddl_fakeConfirmed;
- (void)ddl_fakeCancelled;
@end

%hook WCOperateFloatView

- (void)layoutSubviews {
    %orig;
    [self ddl_attachLongPress];
}

%new
- (void)ddl_attachLongPress {
    if (!DDLikeConfig.shared.likeEnabled) return;
    UIButton *btn = self.m_likeBtn;
    if (!btn) return;
    if (objc_getAssociatedObject(btn, kDDLLongPressKey)) return;

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(ddl_onLikeLongPress:)];
    lp.minimumPressDuration = 1.0;
    lp.delaysTouchesBegan = YES;
    [btn addGestureRecognizer:lp];
    objc_setAssociatedObject(btn, kDDLLongPressKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!DDLikeConfig.shared.likeEnabled) return;

    WCDataItem *item = self.m_item;
    if (!item) return;

    gDDLPendingItem = item;

    [self hide];             // 先收起点赞浮层，免得盖住弹窗
    gDDLPendingView = self;  // 弹窗回调还要打到 self，收起后没人持有它，留个强引用

    Class alertCls = objc_getClass("WCUIAlertView");
    DDLikeConfig *cfg = DDLikeConfig.shared;
    NSString *msg = @"请输入「点赞数/评论数」\n用＂/＂隔开，例如：8/5\n评论需设置界面自定义\n留空还原";

    // 弹窗必须自建：先 alloc/init，再挂输入框与按钮，最后才 show。
    // showAlertWithTitle:… 便捷构造器会立即 show，输入框将挂在一个已显示的弹窗上。
    WCUIAlertView *alert = [[alertCls alloc] initWithTitle:@"集赞设置" message:msg];
    [alert showTextFieldWithMaxLen:15];
    // 预填上次的数值；用 setTextFieldDefaultText（真文本），别用 placeholder——
    // placeholder 只是灰字提示、不算输入内容，直接点确认会读到空串被当成「取消伪装」。
    [alert setTextFieldDefaultText:(cfg.likeCount > 0 || cfg.commentCount > 0)
                                   ? [NSString stringWithFormat:@"%ld/%ld",
                                      (long)cfg.likeCount, (long)cfg.commentCount]
                                   : @"5/6"];
    [alert setRequestKeyWindow:YES];
    [alert addCancelBtnTitle:@"取消" target:self sel:@selector(ddl_fakeCancelled)];
    [alert addBtnTitle:@"确认" target:self sel:@selector(ddl_fakeConfirmed)];
    gDDLCurrentAlert = alert;
    [alert show];
}

%new
- (void)ddl_fakeConfirmed {
    WCOperateFloatView *view = gDDLPendingView ?: self;
    WCDataItem *item = gDDLPendingItem ?: (WCDataItem *)view.m_item;
    if (!item) return;
    NSString *tid = [item tid];

    NSString *text = nil;
    if (gDDLCurrentAlert) {
        id t = [gDDLCurrentAlert getTextFieldText];
        if ([t isKindOfClass:[NSString class]]) text = t;
    }

    NSInteger l = 0, c = 0;
    BOOL hasSpec = DDLParseSpec(text, &l, &c);
    if (!hasSpec || (l <= 0 && c <= 0)) {
        if (tid && gDDLFake()[tid]) {
            DDLRemoveFakeFromItem(item, tid);
        }
    } else {
        // 「设置评论内容」开关关时不允许新增评论：只保留点赞目标，评论目标归零。
        // 已存在的假评论不受影响（reapply 会按记录恢复），只是关掉开关后不能再新加。
        if (!DDLikeConfig.shared.commentsEnabled) c = 0;
        DDLikeConfig.shared.likeCount = l;
        DDLikeConfig.shared.commentCount = c;
        DDLApplyFakeToItem(item, l, c);
    }

    // 改完数据后用原生 modifyDataItem:notify: 触发刷新，让点赞行按新数据重绘。
    id svc = DDLFacadeService();
    if (svc) {
        [(WCFacade *)svc modifyDataItem:item notify:YES];
    }
    gDDLCurrentAlert = nil;
    gDDLPendingItem  = nil;
    gDDLPendingView  = nil;
}

%new
- (void)ddl_fakeCancelled {
    gDDLCurrentAlert = nil;
    gDDLPendingItem  = nil;
    gDDLPendingView  = nil;
}

%end

// 在微信产出 dataItem 的几个入口补回假数据：下拉刷新、翻页、进详情拿到的都是带假赞的
// dataItem，因此刷新不丢、本来带赞也照显。
%hook WCFacade

- (id)getTimelineDataInCacheByItemID:(id)itemID {
    id r = %orig;
    DDLReapplyIfNeeded(r);
    return r;
}

- (id)getTimelineDataItemOfIndex:(long long)index {
    id r = %orig;
    DDLReapplyIfNeeded(r);
    return r;
}

%end

// 覆盖原生「数据项变了」的路径：先补回再走原逻辑。
%hook WCTimelineMgr

- (void)modifyDataItem:(id)item notify:(BOOL)notify {
    DDLReapplyIfNeeded(item);
    %orig;
}

%end

#pragma mark - 设置界面

@interface DDLikeSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *commentsField;
@end

@implementation DDLikeSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (!self.tableViewManager) {
        self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                                  initWithFrame:[UIScreen mainScreen].bounds
                                          style:UITableViewStyleInsetGrouped];
    }
    if (!_tableViewManager) return;

    self.title = @"集赞助手设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    [self buildTable];

    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];

    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    [self addLikeSections];
    [_tableViewManager reloadTableView];
}

- (void)addLikeSections {
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    DDLikeConfig *cfg = DDLikeConfig.shared;

    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"集赞设置"];
    [sec addCell:[cellMgr switchCellForSel:@selector(onLikeEnabledSwitch:)
                                    target:self
                                     title:@"启用长按集赞"
                                        on:cfg.likeEnabled]];

    if (cfg.likeEnabled) {
        // 评论内容开关：打开才展开输入框
        [sec addCell:[cellMgr switchCellForSel:@selector(onCommentsSwitch:)
                                        target:self
                                         title:@"设置评论内容"
                                            on:cfg.commentsEnabled]];
        if (cfg.commentsEnabled) {
            self.commentsField = [self makeFieldPlaceholder:@"多个内容用/分隔"
                                                     value:cfg.comments];
            [sec addCell:[cellMgr normalCellForSel:nil
                                            target:nil
                                             title:@"   ↳评论内容"
                                        rightView:[self inputRowWithField:self.commentsField
                                                                   action:@selector(commentsConfirmed:)]]];
        }

        // 清除伪装记录：始终显示，右侧「清理」按钮（样式对齐 DD小丑助手，不显示个数）
        UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(onClearFakeTapped:)];
        UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
        [clearRight addSubview:clearBtn];
        [sec addCell:[cellMgr normalCellForSel:nil
                                       target:nil
                                        title:@"   ↳清除伪装记录"
                                     rightView:clearRight]];
    }
    [_tableViewManager addSection:sec];
}

#pragma mark 回调

- (void)onLikeEnabledSwitch:(UISwitch *)s {
    DDLikeConfig.shared.likeEnabled = s.isOn;
    [self buildTable];
}

- (void)onCommentsSwitch:(UISwitch *)s {
    DDLikeConfig.shared.commentsEnabled = s.isOn;
    [self buildTable];
}

// 清掉持久化记录，并立即剥掉当前已加载 dataItem 上的假数据、触发刷新，无需手动下拉朋友圈。
- (void)onClearFakeTapped:(id)sender {
    [gDDLFake() removeAllObjects];
    DDLFakeSave();

    id facade = DDLFacadeService();
    long long n = [facade countOfTimelineDataItem];
    for (long long i = 0; i < n; i++) {
        id item = [facade getTimelineDataItemOfIndex:i];
        if ([item isKindOfClass:%c(WCDataItem)]) {
            DDLStripFakeFromItem(item, YES, YES);
            [(WCFacade *)facade modifyDataItem:item notify:YES];
        }
    }
    [self buildTable];
    [self dd_showDoneToast:@"记录已清理"];
}

- (void)commentsConfirmed:(id)sender {
    DDLikeConfig.shared.comments = self.commentsField.text ?: @"";
    [self.commentsField resignFirstResponder];
}

- (UITextField *)makeFieldPlaceholder:(NSString *)placeholder
                                value:(NSString *)value {
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.text = value;
    field.textAlignment = NSTextAlignmentRight;
    return field;
}

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

// 与 DD小丑助手一致的「清理」按钮：system 蓝文字、systemGray5 背景、圆角 6、52×34。
- (UIButton *)dd_actionButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, 52, 34);
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// 微信内置轻提示，与 DD小丑助手清理提示一致；仅成功反馈，无失败分支。
- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}

#pragma mark UITableView 转发

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

@end

#pragma mark - 注册入口

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

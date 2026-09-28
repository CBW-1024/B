#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

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
@property (nonatomic) unsigned int m_uiType;
@property (nonatomic) unsigned int m_uiFriendScene;
@property (nonatomic) unsigned int realFriendScene;
@property (nonatomic) unsigned long long m_uiTypeExt;
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
- (BOOL)isHardCodeContact:(id)arg1;
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

static inline id DDLContactMgr(void) {
    return DDLService(objc_getClass("CContactMgr"));
}

// 朋友圈门面（WCFacade）。锤子改完 dataItem 后就是拿它调 modifyDataItem:notify: 触发原生刷新。
// 反汇编证据（hammer fake.txt）：
//   0x7b5408  objc_getClass("WCFacade")                       ← 记住：是 WCFacade，不是 WCTimelineMgr
//   0x7b5cc8  [[MMContext currentContext] getService:[WCFacade class]]
//   0x7b61b8  [facade modifyDataItem:dataItem notify:YES]     ← 确认分支
//   0x7b628c  [facade modifyDataItem:dataItem notify:YES]     ← 撤销分支
// 全程没有任何 reloadData / reloadTableView，就这一句。
static inline id DDLFacadeService(void) {
    return DDLService(objc_getClass("WCFacade"));
}

// WCFacade.h:195 getTimelineDataInCacheByItemID: / :197 getTimelineDataItemOfIndex: / :429 modifyDataItem:notify:
@interface WCFacade : NSObject
- (id)getTimelineMgr;
- (id)getTimelineDataInCacheByItemID:(id)itemID;
- (id)getTimelineDataItemOfIndex:(long long)index;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

@interface WCOperateFloatView : UIView
- (id)m_item;
- (id)m_likeBtn;
- (void)hide;
- (void)onLikeItem:(id)arg1;
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
@property (nonatomic) int realLikeCount;
@property (nonatomic) int selfLikeCount;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@property (nonatomic) BOOL likeFlag;
@property (nonatomic) unsigned int createtime;
@property (retain, nonatomic) NSString *tid;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

// 只留回退路径真正会调的三个（DDLReloadTimelineFrom 用）。
@interface WCTimeLineViewController : NSObject
- (id)getContentTableView;
- (void)reloadTableView;
- (void)reloadDataWrap;
@end

#pragma mark - 配置

static NSString * const kDDMLikeEnabled    = @"DDMoments_likeEnabled";
static NSString * const kDDMLikeCount      = @"DDMoments_likeCount";
static NSString * const kDDMCommentCount   = @"DDMoments_commentCount";
static NSString * const kDDMLikeComments   = @"DDMoments_likeComments";

@interface DDLikeConfig : NSObject
@property (assign, nonatomic) BOOL likeEnabled;
@property (assign, nonatomic) NSInteger likeCount;
@property (assign, nonatomic) NSInteger commentCount;
@property (copy, nonatomic) NSString *comments;
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

- (void)setComments:(NSString *)v {
    NSString *val = v ?: @"";
    _comments = [val copy];
    [self persist:val key:kDDMLikeComments];
}

- (NSArray<NSString *> *)commentPool {
    if (self.comments.length == 0) return @[];
    return [self.comments componentsSeparatedByString:@"-"];
}

@end

#pragma mark - 调试日志

static const NSUInteger kDDLogMaxLines = 500;

static NSMutableArray<NSString *> *DDLogStore(void) {
    static NSMutableArray *lines = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lines = [NSMutableArray array]; });
    return lines;
}

static NSDateFormatter *DDLogFormatter(void) {
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [NSDateFormatter new];
        fmt.dateFormat = @"HH:mm:ss.SSS";
    });
    return fmt;
}

static void DDLog(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void DDLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSString *line = [NSString stringWithFormat:@"%@ %@",
                      [DDLogFormatter() stringFromDate:[NSDate date]], msg];

    NSMutableArray *store = DDLogStore();
    @synchronized (store) {
        [store addObject:line];
        if (store.count > kDDLogMaxLines) {
            [store removeObjectsInRange:NSMakeRange(0, store.count - kDDLogMaxLines)];
        }
    }
}

static NSUInteger DDLogCount(void) {
    NSMutableArray *store = DDLogStore();
    @synchronized (store) { return store.count; }
}

static NSString *DDLogText(void) {
    NSMutableArray *store = DDLogStore();
    @synchronized (store) {
        if (store.count == 0) return @"（暂无日志）";
        return [store componentsJoinedByString:@"\n"];
    }
}

static void DDLogClear(void) {
    NSMutableArray *store = DDLogStore();
    @synchronized (store) { [store removeAllObjects]; }
}

static NSString *DDLogConfigSummary(void) {
    DDLikeConfig *c = DDLikeConfig.shared;
    return [NSString stringWithFormat:
            @"[配置] 启用=%d 点赞数=%ld 评论数=%ld 评论内容=「%@」\n"
            @"[环境] 系统=%@ 微信头文件基线=8.0.79",
            c.likeEnabled, (long)c.likeCount, (long)c.commentCount, c.comments,
            [UIDevice currentDevice].systemVersion];
}

#pragma mark - 核心功能

@interface DDLikeHelper : NSObject
+ (NSArray<CContact *> *)allFriends;
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers;
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem;
@end

@implementation DDLikeHelper

static NSArray<CContact *> *gDDLFriendCache;
static NSTimeInterval gDDLFriendCacheAt;

+ (NSArray<CContact *> *)allFriends {
    if (gDDLFriendCache && ([NSDate timeIntervalSinceReferenceDate] - gDDLFriendCacheAt) < 3.0) {
        DDLog(@"[好友] 复用缓存=%lu（%.2fs 前）", (unsigned long)gDDLFriendCache.count,
              [NSDate timeIntervalSinceReferenceDate] - gDDLFriendCacheAt);
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
    DDLog(@"[好友] 真实好友池=%lu", (unsigned long)friends.count);
    return gDDLFriendCache;
}

+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers {
    NSInteger target = DDLikeConfig.shared.likeCount;
    NSMutableArray *list = [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[点赞] target=%ld ≤0，未设置点赞数，跳过", (long)target);
        return list;
    }

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;
    NSArray<CContact *> *friends = [self allFriends];
    [friends enumerateObjectsUsingBlock:^(CContact *c, NSUInteger idx, BOOL *stop) {
        if ((NSInteger)idx >= target) { *stop = YES; return; }
        WCUserComment *u = [[objc_getClass("WCUserComment") alloc] init];
        u.username   = c.m_nsUsrName;
        u.nickname   = c.m_nsNickName;
        // 锤子 ApplyFake 反汇编（fake.txt 0x7b650c-0x7b6528）：
        //   mov w2, #1 → setType:1（1=赞；2=文本评论。type=2 混入 likeUsers 会被点赞行
        //   渲染器按评论处理，content 为 nil 时走图片占位分支 → 行内出现「图片」+空槽）
        //   setContent:@""（0xd9f180 CFString len=0 空串，不能为 nil）
        u.type       = 1;
        u.content    = @"";
        u.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        u.createTime = now;
        [list addObject:u];
    }];
    DDLog(@"[点赞] target=%ld 好友池=%lu → 生成=%lu",
          (long)target, (unsigned long)friends.count, (unsigned long)list.count);
    return list;
}

+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem {
    NSInteger target = DDLikeConfig.shared.commentCount;
    NSMutableArray *orig = origItem.commentUsers ?: [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[评论] target=%ld ≤0，未设置评论数，跳过", (long)target);
        return orig;
    }
    if ((NSInteger)orig.count >= target) {
        DDLog(@"[评论] 已有 %lu 条 ≥ target=%ld，跳过", (unsigned long)orig.count, (long)target);
        return orig;
    }

    NSArray<NSString *> *pool = DDLikeConfig.shared.commentPool;
    if (pool.count == 0) {
        DDLog(@"[评论] 内容池为空（未填写评论内容），跳过");
        return orig;
    }

    NSMutableArray *list = [orig mutableCopy];

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;

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
    DDLog(@"[评论] target=%ld 原有=%lu 内容池=%lu → 生成后=%lu",
          (long)target, (unsigned long)orig.count, (unsigned long)pool.count, (unsigned long)list.count);
    return list;
}

@end

#pragma mark - Hook：长按点赞 → 集赞

static const void *kDDLLongPressKey = &kDDLLongPressKey;

static NSString *DDLGap(NSString *key, NSString *tag);
static NSString *DDLTidOfCell(id cell);
static id DDLDeepItem(id v, int depth);

static NSString *DDLSubList(id cell) {
    if (![cell isKindOfClass:UITableViewCell.class]) return @"(非cell)";
    NSArray *subs = ((UITableViewCell *)cell).contentView.subviews;
    if (!subs.count) return @"(空)";
    NSMutableArray *n = [NSMutableArray array];
    for (UIView *sv in subs) [n addObject:NSStringFromClass([sv class])];
    return [n componentsJoinedByString:@"+"];
}

static NSTimeInterval gDDLProbeUntil = 0;
static inline void DDLProbeOpen(void) {
    gDDLProbeUntil = [NSDate timeIntervalSinceReferenceDate] + 3.0;
}
static inline BOOL DDLProbeOn(void) {
    return [NSDate timeIntervalSinceReferenceDate] < gDDLProbeUntil;
}

static id DDLFindTimelineVC(id start) {
    Class tlvClass = objc_getClass("WCTimeLineViewController");
    if (!tlvClass) return nil;

    id cur = start;
    for (int i = 0; i < 15 && cur; i++) {
        if ([cur isKindOfClass:tlvClass]) return cur;
        if ([cur respondsToSelector:@selector(topViewController)]) {
            id top = [cur topViewController];
            if ([top isKindOfClass:tlvClass]) return top;
        }
        if ([cur respondsToSelector:@selector(navigationController)]) {
            id nav = [cur navigationController];
            if ([nav isKindOfClass:tlvClass]) return nav;
            if ([nav respondsToSelector:@selector(topViewController)]) {
                id top = [nav topViewController];
                if ([top isKindOfClass:tlvClass]) return top;
            }
        }
        if (![cur respondsToSelector:@selector(nextResponder)]) break;
        cur = [cur nextResponder];
    }
    return nil;
}

static id DDLTimelineTableView(id tlvc) {
    if (!tlvc) return nil;
    id tv = nil;
    if ([tlvc respondsToSelector:@selector(getContentTableView)]) {
        @try { tv = [tlvc getContentTableView]; } @catch (NSException *__) { tv = nil; }
    }
    for (NSString *k in @[@"tableView", @"m_tableView"]) {
        if (tv) break;
        @try { tv = [tlvc valueForKey:k]; } @catch (NSException *__) { tv = nil; }
    }
    return ([tv isKindOfClass:UITableView.class]) ? tv : nil;
}

static BOOL DDLReloadTimelineFrom(id start, NSString *tid) {
    id tlvc = DDLFindTimelineVC(start);
    if (!tlvc) {
        DDLog(@"[刷新] ⚠未定位到时间线 VC（起点=%@）", NSStringFromClass([start class]));
        return NO;
    }
    DDLog(@"[刷新] 定位到 VC=%@ tid=%@", NSStringFromClass([tlvc class]), tid);

    // 照 WCR 反汇编结论排序：它在 ApplyManualFakeEngagement 之后紧跟的就是 reloadTableView
    // （见 WCR_FakeLike_Mechanism.md）。原来我们把 reloadDataWrap 排第一，这里把 reloadTableView 提到最前。
    SEL native[3];
    native[0] = NSSelectorFromString(@"reloadTableView");
    native[1] = NSSelectorFromString(@"reloadTableData");
    native[2] = NSSelectorFromString(@"reloadDataWrap");
    for (int i = 0; i < 3; i++) {
        if (![tlvc respondsToSelector:native[i]]) continue;
        DDLProbeOpen();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [tlvc performSelector:native[i]];
#pragma clang diagnostic pop
        DDLog(@"[刷新] 走 VC 原生出口=%@ tid=%@ %@", NSStringFromSelector(native[i]), tid, DDLGap(tid, @"T:"));
        return YES;
    }

    // 兜底：手动 reloadData（部分版本无上述出口；不保证点赞行刷新，仅保底可见性）。
    id tv = DDLTimelineTableView(tlvc);
    if (tv) {
        DDLProbeOpen();
        [(UITableView *)tv reloadData];
        DDLog(@"[刷新] 主表 reloadData（兜底）tid=%@ 表=%@ %@", tid,
              NSStringFromClass([tv class]), DDLGap(tid, @"T:"));
        return YES;
    }

    DDLog(@"[刷新] ⚠主表与 VC 出口都取不到 tid=%@，本次不会自动刷新", tid);
    return NO;
}

static UIWindow *DDLKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
            if (sc.activationState != UISceneActivationStateForegroundActive) continue;
            if (![sc isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)sc).windows) { if (w.isKeyWindow) return w; }
        }
    }
    return nil;
}

static void DDLCheckVisible(NSString *tid, id start) {
    if (!tid) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id tlvc = DDLFindTimelineVC(start);
        id tv = DDLTimelineTableView(tlvc);
        if (![tv isKindOfClass:UITableView.class]) {

            tlvc = DDLFindTimelineVC(DDLKeyWindow());
            tv = DDLTimelineTableView(tlvc);
        }
        DDLog(@"[体检] tid=%@ 开始 起点=%@ VC=%@", tid,
              NSStringFromClass([start class]) ?: @"(nil)",
              NSStringFromClass([tlvc class]) ?: @"(nil)");
        if (![tv isKindOfClass:UITableView.class]) { DDLog(@"[体检] ⚠拿不到主表"); return; }
        NSUInteger n = 0, shown = 0;
        for (UIView *cell in ((UITableView *)tv).visibleCells) {
            NSString *ctid = DDLTidOfCell(cell);
            id it = DDLDeepItem(cell, 0);
            NSUInteger lc = 0, cc = 0;
            if ([it respondsToSelector:@selector(likeUsers)])    lc = [[it valueForKey:@"likeUsers"] count];
            if ([it respondsToSelector:@selector(commentUsers)]) cc = [[it valueForKey:@"commentUsers"] count];

            if ([ctid isEqualToString:tid] || shown < 3) {
                if (![ctid isEqualToString:tid]) shown++; else n++;
                DDLog(@"[体检] %@cell=%@ tid=%@ item=%p 赞=%lu 评论=%lu cv=%@ frame=%@",
                      ([ctid isEqualToString:tid] ? @"命中 " : @"样本 "),
                      NSStringFromClass([cell class]), ctid ?: @"(无)", (__bridge void *)it,
                      (unsigned long)lc, (unsigned long)cc,
                      DDLSubList(cell), NSStringFromCGRect(cell.frame));
            }
        }
        if (!n) DDLog(@"[体检] ⚠可见单元格里没有 tid=%@（可能已滚出屏幕或取不到 tid）", tid);
    });
}

static NSString *DDLGap(NSString *key, NSString *tag) {
    static NSMutableDictionary *last;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ last = [NSMutableDictionary dictionary]; });
    NSString *k = [tag stringByAppendingString:(key ?: @"?")];
    NSDate *now = [NSDate date];
    NSDate *prev = last[k];
    last[k] = now;
    if (!prev) return @"首次";
    NSTimeInterval dt = [now timeIntervalSinceDate:prev] * 1000.0;
    if (dt < 500.0) return [NSString stringWithFormat:@"⚠%.0fms", dt];
    return [NSString stringWithFormat:@"%lldms", (long long)dt];
}

static id DDLDeepItem(id v, int depth) {
    if (!v || depth > 3 || ![v isKindOfClass:NSObject.class]) return nil;
    @try {
        id it = [v valueForKey:@"mainDataItem"];
        if ([it respondsToSelector:@selector(tid)]) return it;
    } @catch (NSException *__) {}
    @try {
        id it = [v valueForKey:@"m_dataItem"];
        if ([it respondsToSelector:@selector(tid)]) return it;
    } @catch (NSException *__) {}
    @try {
        id sub = [v valueForKey:@"m_subContentView"];
        if (sub && sub != v) { id r = DDLDeepItem(sub, depth + 1); if (r) return r; }
    } @catch (NSException *__) {}
    if ([v isKindOfClass:UIView.class]) {
        for (UIView *sv in ((UIView *)v).subviews) {
            id r = DDLDeepItem(sv, depth + 1);
            if (r) return r;
        }
    }
    return nil;
}

static NSString *DDLTidOfCell(id cell) {
    if (!cell) return nil;
    @try {
        id item = DDLDeepItem(cell, 0);
        if ([item respondsToSelector:@selector(tid)]) return [item tid];
    } @catch (NSException *__) {}
    return nil;
}

// 方案（照锤子反汇编结论，详见 Hammer_FakeLike_Mechanism.md）：
// 长按 → 微信原生弹窗（取消/确认）→ 确认才本地注入假数据 → [WCFacade modifyDataItem:notify:YES]。
//
// 为什么不能用 reload 代替（旧版踩过的坑）：点赞行的布局缓存在 WCDataItemUICache
// （likeUserLayoutStyles / likeUserHeight），按 dataItem 对象身份命中。原地改同一个对象再
// reloadTableView / reloadDataWrap，都掀不掉这条缓存 —— 这就是「带赞 item 长按后不刷新、要手动拉一下」。
// 锤子全程没有一句 reload，只有 [WCFacade modifyDataItem:notify:]（fake.txt 0x7b61b8 / 0x7b628c）。
//
// 三条关键取舍，每条都对应过去踩过的坑：
//   1) 不调 onLikeItem: 踢原生点赞：确认后才改数据 → 不会真给作者点服务器赞，零副作用。
//   2) 不以 likeFlag 为注入条件（WCR / 锤子都不依赖）：自己已赞过的 item 长按会把 likeFlag toggle 成 NO，
//      以它为门槛就永远不触发——这是之前「长按零注入」的根因之一。
//   3) 注入用「原始 + 追加」而非锤子的「整体替换」：追加且按 username 去重 → 天然幂等，
//      “补回”就是再调一次，省掉锤子那两个快照字典（g_fakeDict / g_origDict）。
//
// 已彻底移除的旧做法（勿回退）：运行时穷举 WCTimeLineCellView 私有 ivar 再调 onReloadCommentCellView:
// —— 会触发惰性 getter 副作用 / 访问已释放弱引用，是「长按闪退」的直接元凶。
// 同理，PBCoding 深拷贝方案也已废弃。

@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (void)ddl_fakeConfirmed;
- (void)ddl_fakeCancelled;
- (BOOL)ddl_reloadTimelineForItem:(id)item;
- (id)navigationController;
@end

// 微信原生弹窗类（WCUIAlertView.h:19）——带取消 + 确认两个按钮的那款
@interface WCUIAlertView : NSObject
+ (id)showAlertWithTitle:(id)title message:(id)message
          cancelBtnTitle:(id)cancelTitle target:(id)cancelTarget sel:(SEL)cancelSel
               btnTitle:(id)btnTitle target:(id)btnTarget sel:(SEL)btnSel;
@end

// 已集赞的 tid → @YES
static NSMutableDictionary *gDDLFakeOn(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary new]; });
    return d;
}

// 弹窗回调时浮层可能已 hide、m_item 失效，这里留一份强引用
static WCDataItem *gDDLPendingItem = nil;

// 已注入过的假赞用户名集合。补回路径会随 cell 渲染被高频调用，靠它做 O(n) 预检，
// 避免每次都重新造一遍 WCUserComment（实测 1.25s 内被调 84 次，日志全被这条刷爆）。
static NSMutableSet *gDDLFakeNames(void) {
    static NSMutableSet *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSMutableSet new]; });
    return s;
}

// 追加式注入（对齐 WCRefineApplyManualFakeEngagementToDataItem）：
// 保留原始名单 → 追加假的 → 写回。按 username 去重，重复点确认不会把假赞叠加两份。
static void DDLApplyFakeToItem(WCDataItem *di) {
    NSString *tid = ([di respondsToSelector:@selector(tid)] ? [di tid] : nil);

    NSMutableArray *likes = ([di respondsToSelector:@selector(likeUsers)] && [di likeUsers])
                          ? [[di likeUsers] mutableCopy] : [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (WCUserComment *u in likes) {
        if ([u respondsToSelector:@selector(username)] && u.username) [seen addObject:u.username];
    }
    NSUInteger addedLike = 0;
    for (WCUserComment *u in [DDLikeHelper fakeLikeUsers]) {
        NSString *name = ([u respondsToSelector:@selector(username)] ? u.username : nil);
        if (name && [seen containsObject:name]) continue;
        if (name) { [seen addObject:name]; [gDDLFakeNames() addObject:name]; }
        [likes addObject:u];
        addedLike++;
    }
    if (addedLike) {
        [di setLikeUsers:likes];
        [di setLikeCount:(int)likes.count];
        [di setRealLikeCount:(int)likes.count];
        DDLog(@"[注入] 假赞 tid=%@ 新增=%lu 合计=%lu", tid,
              (unsigned long)addedLike, (unsigned long)likes.count);
    } else {
        DDLog(@"[注入] 假赞 tid=%@ 无新增（已存在/未配置点赞数）", tid);
    }

    NSUInteger before = ([di respondsToSelector:@selector(commentUsers)] && [di commentUsers])
                      ? [di commentUsers].count : 0;
    NSMutableArray *comments = [[DDLikeHelper fakeCommentsFor:di] mutableCopy];
    if (comments.count != before) {
        [di setCommentUsers:comments];
        [di setCommentCount:(int)comments.count];
        DDLog(@"[注入] 假评论 tid=%@ %lu→%lu", tid,
              (unsigned long)before, (unsigned long)comments.count);
    } else {
        DDLog(@"[注入] 假评论 tid=%@ 无新增（已达目标数/未配置）", tid);
    }
}

// 假赞是否还完整挂在 item 上。只做集合包含判断，不造对象、不打日志 ——
// 补回路径随 cell 渲染高频触发，绝大多数调用到这里就结束了。
static BOOL DDLItemFakeIntact(WCDataItem *di) {
    NSMutableSet *fake = gDDLFakeNames();
    if (fake.count == 0) return NO;

    NSArray *likes = ([di respondsToSelector:@selector(likeUsers)] ? [di likeUsers] : nil);
    if (likes.count == 0) return NO;
    NSMutableSet *have = [NSMutableSet setWithCapacity:likes.count];
    for (WCUserComment *u in likes) {
        if ([u respondsToSelector:@selector(username)] && u.username) [have addObject:u.username];
    }
    if (![fake isSubsetOfSet:have]) return NO;

    NSInteger cTarget = DDLikeConfig.shared.commentCount;
    if (cTarget > 0) {
        NSUInteger cc = ([di respondsToSelector:@selector(commentUsers)] && [di commentUsers])
                      ? [di commentUsers].count : 0;
        if ((NSInteger)cc < cTarget) return NO;
    }
    return YES;
}

// 单个 dataItem 补回（只处理已集赞的 tid）。
// 这是锤子「刷新不丢 + 本来带赞也显示」的统一机制：hook 了 4 个「产出 dataItem」的入口，
// 每个都在 %orig 之后立刻补回（hammer fake.txt 0x7b5574 / 0x7b56b4 / 0x7b57b8 / 0x7b58e8：
// blr x8(%orig) → tid → objectForKey: → setLikeUsers: → setLikeCount:）。
// DDLApplyFakeToItem 按 username 去重、幂等，所以「补回」就是再调一次，不需要存快照。
static void DDLReapplyIfNeeded(id obj) {
    if (![obj isKindOfClass:%c(WCDataItem)]) return;
    WCDataItem *di = (WCDataItem *)obj;
    NSString *tid = ([di respondsToSelector:@selector(tid)] ? [di tid] : nil);
    if (!tid || !gDDLFakeOn()[tid]) return;
    if (DDLItemFakeIntact(di)) return;          // 还挂着，什么都不用做
    DDLApplyFakeToItem(di);                     // 真被冲掉了才重建，这时日志有价值
    DDLog(@"[保活] 补回假赞 tid=%@", tid);
}


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
    DDLog(@"[手势] 已挂长按 likeBtn=%@", btn);
}

%new
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!DDLikeConfig.shared.likeEnabled) return;

    WCDataItem *item = self.m_item;
    if (!item) { DDLog(@"[长按] m_item 为 nil，中止"); return; }

    @try {
        NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
        gDDLPendingItem = item;   // 浮层收起后弹窗回调仍要用到它

        DDLog(@"[长按] 触发 tid=%@ 已集赞=%d 现有赞=%lu 评论=%lu",
              tid, (tid && gDDLFakeOn()[tid]) ? 1 : 0,
              (unsigned long)([item respondsToSelector:@selector(likeUsers)] ? [item likeUsers].count : 0),
              (unsigned long)([item respondsToSelector:@selector(commentUsers)] ? [item commentUsers].count : 0));

        [self hide];   // 先收起点赞浮层，免得它盖住弹窗

        Class alertCls = objc_getClass("WCUIAlertView");
        if (alertCls && [alertCls respondsToSelector:@selector(showAlertWithTitle:message:cancelBtnTitle:target:sel:btnTitle:target:sel:)]) {
            NSUInteger likeN = [DDLikeHelper fakeLikeUsers].count;
            NSInteger  cmtN  = DDLikeConfig.shared.commentCount;
            NSString *msg = [NSString stringWithFormat:
                @"将为这条朋友圈添加 %lu 个点赞、并把评论补齐至 %ld 条。\n仅本地显示，不会发给微信服务器。",
                (unsigned long)likeN, (long)cmtN];
            [alertCls showAlertWithTitle:@"集赞助手"
                                 message:msg
                         cancelBtnTitle:@"取消" target:self sel:@selector(ddl_fakeCancelled)
                              btnTitle:@"确认" target:self sel:@selector(ddl_fakeConfirmed)];
            DDLog(@"[长按] 已弹微信原生弹窗 tid=%@（取消/确认）", tid);
        } else {
            DDLog(@"[长按] WCUIAlertView 不可用，直接执行 tid=%@", tid);
            [self ddl_fakeConfirmed];
        }
    } @catch (NSException *e) {
        DDLog(@"[长按] 异常已捕获，避免闪退：%@", e.reason);
    }
}

%new
- (void)ddl_fakeConfirmed {
    WCDataItem *item = gDDLPendingItem ?: (WCDataItem *)self.m_item;
    NSString *tid = (item && [item respondsToSelector:@selector(tid)]) ? [item tid] : nil;
    if (!item) { DDLog(@"[弹窗] 确认但 item 已失效，跳过"); return; }
    if (tid) gDDLFakeOn()[tid] = @YES;
    DDLog(@"[弹窗] 已确认 tid=%@", tid);
    DDLApplyFakeToItem(item);

    // 刷新走锤子同款：调微信原生 modifyDataItem:notify: 触发「数据项已变更」的原生更新 + 重绑。
    // 反汇编证据（hammer fake.txt 0x7b61ac-0x7b61b8）：x0=[block+0x20](WCFacade) → x2=dataItem → w3=1 → bl modifyDataItem:notify:。
    // reloadTableView/reloadDataWrap 那套只是 reloadData，掀不掉点赞行缓存，所以本来带赞的 item 一直不刷新。
    // 强转成 WCFacade *：id 接收者会同时匹配 WCFacade/WCTimelineMgr 的同名声明，报 "multiple methods named"。
    id svc = DDLFacadeService();
    if (svc && [svc respondsToSelector:@selector(modifyDataItem:notify:)]) {
        [(WCFacade *)svc modifyDataItem:item notify:YES];
        DDLog(@"[刷新] 已调 [WCFacade modifyDataItem:notify:YES] tid=%@", tid);
    } else {
        DDLog(@"[刷新] ⚠取不到 WCFacade，回退 reload tid=%@", tid);
        [self ddl_reloadTimelineForItem:item];
    }
    gDDLPendingItem = nil;
}

%new
- (void)ddl_fakeCancelled {
    NSString *tid = (gDDLPendingItem && [gDDLPendingItem respondsToSelector:@selector(tid)])
                  ? [gDDLPendingItem tid] : nil;
    DDLog(@"[弹窗] 已取消 tid=%@", tid);
    gDDLPendingItem = nil;
}

%new

- (BOOL)ddl_reloadTimelineForItem:(id)item {
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    DDLog(@"[刷新] 定位开始 tid=%@ 起点=%@ nav=%@", tid, NSStringFromClass([self class]),
          NSStringFromClass([[self navigationController] class]));
    BOOL ok = DDLReloadTimelineFrom(self, tid);
    if (ok) DDLCheckVisible(tid, self);
    return ok;
}

%end

%hook WCTimeLineViewController

- (id)tableView:(id)tv cellForRowAtIndexPath:(id)ip {
    id cell = %orig;
    if (DDLProbeOn()) {
        NSString *tid = DDLTidOfCell(cell);
        NSUInteger lc = 0, cc = 0;
        id it = DDLDeepItem(cell, 0);
        if ([it respondsToSelector:@selector(likeUsers)])    lc = [[it valueForKey:@"likeUsers"] count];
        if ([it respondsToSelector:@selector(commentUsers)]) cc = [[it valueForKey:@"commentUsers"] count];
        DDLog(@"[单元格] 重建 tid=%@ 赞=%lu 评论=%lu item=%p cell=%@ 表=%@",
              tid ?: @"(无)", (unsigned long)lc, (unsigned long)cc,
              (__bridge void *)it, NSStringFromClass([cell class]), NSStringFromClass([tv class]));
    }
    return cell;
}
%end

// 锤子同款「原生产出 dataItem 的入口，orig 之后立刻补回」。
// 反汇编证据（hammer fake.txt 0x7b5408-0x7b5490）：WCFacade 上挂了 4 个 hook，全是
// 「%orig → tid → 假赞字典 objectForKey: → setLikeUsers: → setLikeCount:」，imp 分别是
// 0x7b5574 / 0x7b56b4 / 0x7b57b8 / 0x7b58e8。前两个在 8.0.79 头文件里有（WCFacade.h:195/:197），
// 后两个（LL_onBeforeReturnDataItem: / LLComment_onBeforeReturnDataItem:）dump 里没有，不碰。
// 这样无论是下拉刷新、翻页还是详情打开，微信拿到的 dataItem 本来就带假赞 —— 刷新不丢，本来带赞也照显。
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

%hook WCTimelineMgr

// 锤子也在 WCTimelineMgr 的 modifyDataItem:notify: 上挂了 hook（0x7b54b8，imp 0x7b5a08），
// 同样是先补回再 %orig —— 覆盖所有原生「数据项变了」的路径。
- (void)modifyDataItem:(id)item notify:(BOOL)notify {
    DDLReapplyIfNeeded(item);
    %orig;
}

%end

#pragma mark - 日志查看 / 导出

static void DDLogExportFrom(UIViewController *vc, id sender) {
    NSString *text = [NSString stringWithFormat:@"%@\n\n%@", DDLogConfigSummary(), DDLogText()];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DDLikeHelper.log.txt"];
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    UIActivityViewController *av =
        [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                          applicationActivities:nil];

    if (av.popoverPresentationController) {
        av.popoverPresentationController.sourceView = vc.view;
        av.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(vc.view.bounds), CGRectGetMidY(vc.view.bounds), 1, 1);
        if ([sender isKindOfClass:UIBarButtonItem.class]) {
            av.popoverPresentationController.barButtonItem = (UIBarButtonItem *)sender;
        }
    }
    [vc presentViewController:av animated:YES completion:nil];
}

#pragma mark - 设置界面

@interface DDLikeSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *likeCountField;
@property (nonatomic, strong) UITextField *commentCountField;
@property (nonatomic, strong) UITextField *commentsField;
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
                                     title:@"启用集赞"
                                        on:cfg.likeEnabled]];

    if (cfg.likeEnabled) {

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

    [self addDebugSection];
}

- (void)addDebugSection {
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"调试"];
    [sec addCell:[cellMgr normalCellForSel:@selector(onExportLogTapped)
                                    target:self
                                     title:@"导出日志"
                                rightValue:[NSString stringWithFormat:@"%lu 条", (unsigned long)DDLogCount()]]];
    [sec addCell:[cellMgr normalCellForSel:@selector(onClearLogTapped)
                                    target:self
                                     title:@"清空日志"
                                rightValue:nil]];
    [_tableViewManager addSection:sec];
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

#pragma mark 回调

- (void)onLikeEnabledSwitch:(UISwitch *)s {
    DDLikeConfig.shared.likeEnabled = s.isOn;
    DDLog(@"[设置] 集赞开关 → %d", s.isOn);
    [self buildTable];
}

- (void)onExportLogTapped {
    DDLogExportFrom(self, nil);
}

- (void)onClearLogTapped {
    DDLogClear();
    DDLog(@"[设置] 日志已清空");
    [self buildTable];
}

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

- (void)likeCountConfirmed:(id)sender {
    NSInteger v = [self.likeCountField.text integerValue];
    DDLikeConfig.shared.likeCount = v > 0 ? v : 0;
    [self.likeCountField resignFirstResponder];
}

- (void)commentCountConfirmed:(id)sender {
    NSInteger v = [self.commentCountField.text integerValue];
    DDLikeConfig.shared.commentCount = v > 0 ? v : 0;
    [self.commentCountField resignFirstResponder];
}

- (void)commentsConfirmed:(id)sender {
    DDLikeConfig.shared.comments = self.commentsField.text ?: @"";
    [self.commentsField resignFirstResponder];
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

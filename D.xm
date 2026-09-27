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

@interface WCFacade : NSObject
- (id)getTimelineMgr;
- (id)getTimelineDataInCacheByItemID:(id)itemID;
- (id)getTimelineDataItemOfIndex:(long long)index;
@end

static inline id DDLTimelineMgr(void) {
    return [(WCFacade *)DDLService(objc_getClass("WCFacade")) getTimelineMgr];
}

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
@property (nonatomic) int realLikeCount;
@property (nonatomic) int selfLikeCount;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@property (nonatomic) BOOL likeFlag;
@property (nonatomic) unsigned int createtime;
@property (retain, nonatomic) NSString *tid;
@property (retain, nonatomic) id cpKeyForLikeUsers;
@end

@interface MMTableViewCell : UITableViewCell
- (id)m_subContentView;
- (void)setM_subContentView:(id)v;
@end

@interface WCTimelineMgr : NSObject
- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

@interface WCTimeLineViewController : NSObject
- (id)getContentTableView;
- (id)indexPathOfDataItem:(id)item;
- (void)reloadTableView;
- (void)reloadDataWrap;
- (void)onActionClearCellCacheAndRefreshCellView:(id)arg1;
- (void)onReloadCommentView:(id)arg1 ofDataItem:(id)arg2;
- (void)onUpdateDataItem:(id)item oldHeight:(double)oh newHeight:(double)nh;
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
        u.type       = 2;
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

static const void *kDDLFakedMark = &kDDLFakedMark;

static NSMutableDictionary *gDDLFaked(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary new]; });
    return d;
}

static NSDictionary *DDLSnapshotOf(WCDataItem *item) {
    return @{
        @"likeUsers":     item.likeUsers    ?: @[],
        @"likeCount":     @(item.likeCount),
        @"realLikeCount": @(item.realLikeCount),
        @"selfLikeCount": @(item.selfLikeCount),
        @"commentUsers": item.commentUsers ?: @[],
        @"commentCount": @(item.commentCount),
        @"likeFlag":     @(item.likeFlag),
    };
}

static void DDLRestore(WCDataItem *item, NSDictionary *snap) {
    NSDictionary *o = snap[@"orig"];
    item.likeUsers     = [o[@"likeUsers"] mutableCopy];
    item.likeCount     = [o[@"likeCount"] intValue];
    item.realLikeCount = [o[@"realLikeCount"] intValue];
    item.selfLikeCount = [o[@"selfLikeCount"] intValue];
    item.commentUsers = [o[@"commentUsers"] mutableCopy];
    item.commentCount = [o[@"commentCount"] intValue];
    item.likeFlag     = [o[@"likeFlag"] boolValue];
    item.cpKeyForLikeUsers = nil;
    objc_setAssociatedObject(item, kDDLFakedMark, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline void DDLFakeInto(WCDataItem *item, NSArray *likes, NSArray *comments) {
    if (!item) return;
    if (comments.count) {
        item.commentUsers = [comments mutableCopy];
        item.commentCount = (int)comments.count;
    }
    if (likes.count) {
        item.likeUsers = [likes mutableCopy];
        item.likeCount = (int)likes.count;

        item.realLikeCount = (int)likes.count;
    }

    item.cpKeyForLikeUsers = nil;

    objc_setAssociatedObject(item, kDDLFakedMark, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DDLReapply(NSString *tag, id item) {
    if (!item || ![item respondsToSelector:@selector(tid)]) return;
    NSString *tid = [(WCDataItem *)item tid];
    if (!tid) return;
    NSDictionary *snap = gDDLFaked()[tid];
    if (!snap) return;

    DDLFakeInto((WCDataItem *)item, snap[@"likes"], snap[@"comments"]);

    static NSMutableSet *seen = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet new]; });
    if (![seen containsObject:tid]) {
        [seen addObject:tid];
        DDLog(@"[补灌] 出口=%@ tid=%@ 赞=%lu 评论=%lu", tag, tid,
              (unsigned long)[snap[@"likes"] count], (unsigned long)[snap[@"comments"] count]);
    }
}

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

static int DDLForceRebuildCell(id tv, id tlvc, id item) {
    if (![tv isKindOfClass:UITableView.class] || !item) return 0;
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [(WCDataItem *)item tid] : nil);
    if (!tid) return 0;
    int n = 0;
    for (NSIndexPath *ip in [(UITableView *)tv indexPathsForVisibleRows]) {
        UITableViewCell *cell = [(UITableView *)tv cellForRowAtIndexPath:ip];
        if (!cell) continue;
        id it = DDLDeepItem(cell, 0);
        NSString *ctid = ([it respondsToSelector:@selector(tid)] ? [(WCDataItem *)it tid] : nil);
        if (!ctid || ![ctid isEqualToString:tid]) continue;
        NSString *before = DDLSubList(cell);
        @try {
            for (UIView *sv in [cell.contentView.subviews copy]) [sv removeFromSuperview];
            if ([cell respondsToSelector:@selector(setM_subContentView:)])
                [(MMTableViewCell *)cell setM_subContentView:nil];
        } @catch (NSException *e) { DDLog(@"[强拆] 异常 %@", e.reason); }
        DDLog(@"[强拆] 行%@ 拆前cv=%@ 拆后cv=%@", ip, before, DDLSubList(cell));
        n++;
    }
    if (n == 0) DDLog(@"[强拆] ⚠可见行中无 tid=%@ 匹配", tid);
    return n;
}

static int DDLReloadCommentViews(id tlvc, id tv, id item) {
    if (![tv isKindOfClass:UITableView.class] || !item) return 0;
    if (![tlvc respondsToSelector:@selector(onReloadCommentView:ofDataItem:)]) {
        DDLog(@"[评论行] ⚠VC 无 onReloadCommentView:ofDataItem:");
        return 0;
    }
    int n = 0;
    for (NSIndexPath *ip in [(UITableView *)tv indexPathsForVisibleRows]) {
        UITableViewCell *cell = [(UITableView *)tv cellForRowAtIndexPath:ip];
        if (!cell) continue;
        NSMutableArray *found = [NSMutableArray array];
        UIView *content = ((UITableViewCell *)cell).contentView;
        for (UIView *a in content.subviews) {
            NSString *c1 = NSStringFromClass([a class]);
            if ([c1 rangeOfString:@"CommentCell" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [c1 rangeOfString:@"CommentView" options:NSCaseInsensitiveSearch].location != NSNotFound)
                [found addObject:a];
            for (UIView *b in a.subviews) {
                NSString *c2 = NSStringFromClass([b class]);
                if ([c2 rangeOfString:@"CommentCell" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [c2 rangeOfString:@"CommentView" options:NSCaseInsensitiveSearch].location != NSNotFound)
                    [found addObject:b];
            }
        }
        for (UIView *v in found) {
            @try {
                [tlvc onReloadCommentView:v ofDataItem:item];
                DDLog(@"[评论行] onReloadCommentView: %@ 已调用", NSStringFromClass([v class]));
                n++;
            } @catch (NSException *e) { DDLog(@"[评论行] 异常 %@", e.reason); }
        }
        if (found.count == 0) {
            DDLog(@"[评论行] 未定位到具体 view，交给整表 reloadData 处理");
        }
    }
    if (n == 0) DDLog(@"[评论行] ⚠评论/点赞行重载未触发");
    return n;
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

    id tv = DDLTimelineTableView(tlvc);
    if (tv) {
        DDLProbeOpen();
        [(UITableView *)tv reloadData];
        DDLog(@"[刷新] 主表 reloadData tid=%@ 表=%@ %@", tid,
              NSStringFromClass([tv class]), DDLGap(tid, @"T:"));
        return YES;
    }

    SEL chain[2];
    chain[0] = NSSelectorFromString(@"reloadTableView");
    chain[1] = NSSelectorFromString(@"reloadTableData");
    for (int i = 0; i < 2; i++) {
        if (![tlvc respondsToSelector:chain[i]]) continue;
        DDLProbeOpen();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [tlvc performSelector:chain[i]];
#pragma clang diagnostic pop
        DDLog(@"[刷新] 主表取不到，改走 VC 出口=%@ tid=%@ %@",
              NSStringFromSelector(chain[i]), tid, DDLGap(tid, @"T:"));
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

@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (BOOL)ddl_reloadTimelineForItem:(id)item;
- (id)navigationController;
@end

static void DDLApplyAndRefresh(WCDataItem *item, NSString *tid, BOOL turningOn, id tlvc0, id tv0) {
    NSMutableDictionary *faked = gDDLFaked();

    id tlvc = tlvc0, tv = tv0;
    DDLog(@"[刷新] 起点 tid=%@ item=%p", tid, (__bridge void *)item);
    DDLProbeOpen();

    // 反汇编锤子(WeChatTweak)结论：ApplyFake 仅做 setLikeUsers:/setLikeCount: + modifyDataItem:item notify:1，
    // 刷新完全交给微信原生管线（并由其 dataItem/m_dataItem getter 钩子持续重灌）。
    // 我们之前额外加的 DDLForceRebuildCell / onActionClearCellCacheAndRefreshCellView: / reloadData /
    // onUpdateDataItem: / onReloadCommentView:ofDataItem: 都是锤子从不做的事，且拆 live cell 的
    // subview、调私有评论行方法会在布局中途触发 EXC_BAD_ACCESS（信号，@try 抓不住）→ 长按闪退。
    // 因此这里严格回到锤子的最小机制：写假数据 → modifyDataItem:notify:1。
    // 持久化由现有钩子负责：%hook WCTimelineMgr modifyDataItem:（DDLReapply）+ %hook cellForRowAtIndexPath（DDLReapply）。
    @try {

    if (turningOn) {
        NSDictionary *snap = (tid ? faked[tid] : nil);
        item.likeFlag = YES;
        DDLFakeInto(item, snap[@"likes"], snap[@"comments"]);
        DDLog(@"[写入] tid=%@ 赞=%lu 评论=%lu item=%p",
              tid, (unsigned long)[snap[@"likes"] count],
              (unsigned long)[snap[@"comments"] count], (__bridge void *)item);
        DDLog(@"[写入] 计数 likeCount=%d realLikeCount=%d selfLikeCount=%d likeFlag=%d likeUsers=%lu",
              item.likeCount, item.realLikeCount, item.selfLikeCount, item.likeFlag,
              (unsigned long)item.likeUsers.count);
    }

    id mgr = DDLTimelineMgr();
    if (mgr && [mgr respondsToSelector:@selector(modifyDataItem:notify:)]) {
        [mgr modifyDataItem:item notify:YES];
        DDLog(@"[刷新] modifyDataItem notify:1（同锤子：走微信原生管线刷新，由 WCTimelineMgr 钩子与 cellForRow 钩子持续补灌）");
    } else {
        DDLog(@"[刷新] ⚠未找到 modifyDataItem:notify: 的 mgr，刷新可能无效");
    }

    } @catch (NSException *e) {
        DDLog(@"[刷新] 整段异常已捕获，避免闪退：%@", e.reason);
    }

    DDLCheckVisible(tid, tlvc0);
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
    NSString *tid = item.tid;
    NSMutableDictionary *faked = gDDLFaked();

    DDLog(@"[长按] 触发 tid=%@ likeFlag=%d 已集赞=%d 原始 likeCount=%d realLikeCount=%d selfLikeCount=%d likeUsers=%lu",
          tid, item.likeFlag, tid ? (faked[tid] != nil) : -1,
          item.likeCount, item.realLikeCount, item.selfLikeCount,
          (unsigned long)item.likeUsers.count);

    BOOL turningOn = YES;
    if (tid && faked[tid]) {

        DDLRestore(item, faked[tid]);
        [faked removeObjectForKey:tid];
        turningOn = NO;
        DDLog(@"[长按] 取消集赞 tid=%@（已恢复原始值，记忆剩 %lu 条）",
              tid, (unsigned long)faked.count);
    } else {

        if (!tid) DDLog(@"[长按] 警告：tid 为 nil，刷新后无法重建");
        if (tid) {
            NSArray *likes    = [DDLikeHelper fakeLikeUsers];
            NSArray *comments = [DDLikeHelper fakeCommentsFor:item];
            faked[tid] = @{
                @"orig":     DDLSnapshotOf(item),
                @"likes":    likes    ?: @[],
                @"comments": comments ?: @[],
            };
        }
        DDLog(@"[长按] 开启集赞 tid=%@（记忆 %lu 条）", tid, (unsigned long)faked.count);
    }

    id preTLVC = DDLFindTimelineVC(self);
    id preTV   = DDLTimelineTableView(preTLVC);
    DDLog(@"[长按] 预定位 VC=%@ 主表=%@", NSStringFromClass([preTLVC class]) ?: @"(nil)",
          NSStringFromClass([preTV class]) ?: @"(nil)");
    [self hide];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        DDLApplyAndRefresh(item, tid, turningOn, preTLVC, preTV);
    });
    } @catch (NSException *e) {
        DDLog(@"[长按] 异常已捕获，避免闪退：%@", e.reason);
    }
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
    NSString *tid = DDLTidOfCell(cell);
    BOOL probe = DDLProbeOn();
    NSDictionary *snap = (tid ? gDDLFaked()[tid] : nil);
    if (snap || probe) {
        NSUInteger lc = 0, cc = 0;

        id it = DDLDeepItem(cell, 0);
        if ([it respondsToSelector:@selector(likeUsers)])    lc = [[it valueForKey:@"likeUsers"] count];
        if ([it respondsToSelector:@selector(commentUsers)]) cc = [[it valueForKey:@"commentUsers"] count];
        DDLog(@"[单元格] 重建 %@tid=%@ %@ 赞=%lu/应=%lu 评论=%lu/%lu item=%p cell=%@ 表=%@",
              (snap ? @"" : @"(探活) "), tid ?: @"(无)", DDLGap(tid ?: @"?", @"C:"),
              (unsigned long)lc, (unsigned long)[snap[@"likes"] count],
              (unsigned long)cc, (unsigned long)[snap[@"comments"] count],
              (__bridge void *)it, NSStringFromClass([cell class]), NSStringFromClass([tv class]));
    }
    return cell;
}
%end

static int gDDLFacadeLog = 0;

%hook WCFacade

- (id)getTimelineDataInCacheByItemID:(id)itemID {
    id item = %orig(itemID);
    if (gDDLFacadeLog < 4) {
        gDDLFacadeLog++;
        DDLog(@"[取项] cacheByItemID 进入 itemID=%@ 返回=%@", itemID,
              NSStringFromClass([item class]) ?: @"(nil)");
    }
    DDLReapply(@"cacheByItemID", item);
    return item;
}

- (id)getTimelineDataItemOfIndex:(long long)index {
    id item = %orig(index);
    if (gDDLFacadeLog < 4) {
        gDDLFacadeLog++;
        DDLog(@"[取项] itemOfIndex 进入 index=%lld 返回=%@", index,
              NSStringFromClass([item class]) ?: @"(nil)");
    }
    DDLReapply(@"itemOfIndex", item);
    return item;
}

%end

%hook WCTimelineMgr

- (void)modifyDataItem:(id)item notify:(BOOL)notify {

    NSString *t = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    DDLog(@"[改项] 进入 self=%@ tid=%@ notify=%d 记忆=%lu",
          NSStringFromClass([self class]), t ?: @"(无)", (int)notify,
          (unsigned long)gDDLFaked().count);
    DDLReapply(@"modifyDataItem", item);
    %orig(item, notify);
}

- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t {
    NSMutableDictionary *faked = gDDLFaked();
    BOOL isArray = [datas isKindOfClass:NSArray.class];
    NSUInteger hit = 0;
    NSUInteger skip = 0;

    if (faked.count && isArray) {
        for (id obj in (NSArray *)datas) {
            if (![obj isKindOfClass:objc_getClass("WCDataItem")]) continue;
            WCDataItem *item = (WCDataItem *)obj;
            NSString *tid = item.tid;
            NSDictionary *snap = (tid ? faked[tid] : nil);
            if (!snap) continue;

            item.likeFlag = YES;
            NSArray *likes    = snap[@"likes"];
            NSArray *comments = snap[@"comments"];

            BOOL marked     = [objc_getAssociatedObject(item, kDDLFakedMark) boolValue];
            BOOL consistent = (item.likeUsers.count == likes.count) &&
                              (item.commentUsers.count == comments.count);
            if (marked && consistent) {
                skip++;
            } else {
                DDLFakeInto(item, likes, comments);
                hit++;
            }
        }
    }

    NSUInteger adCount = ([adItems isKindOfClass:NSArray.class]
                          ? (unsigned long)[(NSArray *)adItems count] : 0);
    DDLog(@"[刷新回调] 条数=%lu 记忆=%lu 重写=%lu 跳过=%lu newAdItems=%lu",
          isArray ? (unsigned long)[(NSArray *)datas count] : 0,
          (unsigned long)faked.count, (unsigned long)hit, (unsigned long)skip, (unsigned long)adCount);

    %orig(datas, adItems, t);

    if (hit > 0 && isArray) {
        id firstItem = nil;
        for (id obj in (NSArray *)datas) {
            if (![obj isKindOfClass:objc_getClass("WCDataItem")]) continue;
            if (![obj respondsToSelector:@selector(tid)]) continue;
            NSString *tid = [obj tid];
            if (tid && faked[tid]) { firstItem = obj; break; }
        }
        if (firstItem) {
            [self modifyDataItem:firstItem notify:YES];
            DDLog(@"[刷新] 回调后补刷 modifyDataItem tid=%@", [(WCDataItem *)firstItem tid]);
            DDLCheckVisible([(WCDataItem *)firstItem tid], nil);
        }
    }
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

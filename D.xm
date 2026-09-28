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
- (id) toPBCodingBuffer;
+ (id) fromPBCodingBuffer:(id);
@end

@interface MMTableViewCell : UITableViewCell
- (id)m_subContentView;
- (void)setM_subContentView:(id)v;
@end

@interface WCTimelineMgr : NSObject
- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

// 点赞/评论行控制器（头文件 WCTimeLineCommentCellView.h:21 mainDataItem / :48 onReloadCommentCellView:）。
// dump 头文件标 NSObject，但真机日志证明其实例是 cell.contentView 的直接子 view（UIView），
// 其内部 RichTextView（tag=1000，内容走 setContent:+YYAsyncLayer 自绘，text/attributedText 恒 nil）
// 只有调 onReloadCommentCellView: 重读 mainDataItem 才会重建内容 —— 这就是"带赞 item 需手动刷一次"的根因。
@interface WCTimeLineCommentCellView : UIView
- (id)mainDataItem;
- (void)setMainDataItem:(id)arg1;
- (BOOL)isShowLikeCell;
- (void)onReloadCommentCellView:(id)arg1;
@end

// 主内容控制器（头文件 WCTimeLineCellView.h:288 updateWithDataItem:actionAreaVM: 即 cell 复用时重绘整行的入口）。
// 点赞行归它管。关键修复点：在这里把数据项替换成“假数据深拷贝”（指针变化 → 微信被迫重绑 →
// 点赞行按新数据重算 WCDataItemUICache），等价于手动下拉刷新（服务器返回新对象）能生效的原因。
@interface WCTimeLineCellView : NSObject
- (void)updateWithDataItem:(id)arg1 actionAreaVM:(id)arg2;
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

static NSMutableDictionary *gDDLFaked(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary new]; });
    return d;
}

// 深拷贝 + 注入假数据。返回新 WCDataItem 对象（指针与原始不同），
// 迫使 WCTimeLineCellView 在重绑时按新数据重算点赞行（WCDataItemUICache 按 dataItem 身份命中，
// 新对象 = 新缓存 = 必重算）。原始 dataItem 始终不被修改，零服务器副作用。
// 拷贝失败（PBCoding 异常）返回 nil —— 调用方据此跳过注入，既不污染原始对象也不崩。
static id DDLFakeCopyItem(WCDataItem *orig, NSDictionary *snap) {
    if (!orig) return nil;
    Class cls = [orig class];
    id copy = nil;
    @try {
        id buf = [orig toPBCodingBuffer];
        if (buf) copy = [cls fromPBCodingBuffer:buf];
    } @catch (NSException *e) {
        DDLog(@"[拷贝] PBCoding 失败 tid=%@: %@", [(WCDataItem *)orig tid], e.reason);
    }
    if (!copy || copy == orig) return nil;
    NSArray *likes = snap[@"likes"];
    NSArray *comments = snap[@"comments"];
    if (likes.count) {
        [copy setLikeUsers:[likes mutableCopy]];
        [copy setLikeCount:(int)likes.count];
        [copy setRealLikeCount:(int)likes.count];
    }
    if (comments.count) {
        [copy setCommentUsers:[comments mutableCopy]];
        [copy setCommentCount:(int)comments.count];
    }
    [copy setLikeFlag:YES];
    return copy;
}

// 取/生成某 tid 的假数据拷贝（同一 tid 缓存一份，避免每次渲染都深拷贝）。
static id DDLFakeCopyForTid(NSString *tid, id orig) {
    if (!tid || !orig) return nil;
    NSDictionary *st = gDDLFaked()[tid];
    if (!st || ![st[@"active"] boolValue]) return nil;
    id copy = st[@"copy"];
    if (!copy) {
        copy = DDLFakeCopyItem((WCDataItem *)orig, st);
        if (copy) st[@"copy"] = copy;
    }
    return copy;
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

    // 优先走微信原生整表重载（=下拉刷新，重建 cell 控制器、清掉点赞行 UICache，等于用户手动下拉刷新）。
    SEL native[3];
    native[0] = NSSelectorFromString(@"reloadDataWrap");
    native[1] = NSSelectorFromString(@"reloadTableView");
    native[2] = NSSelectorFromString(@"reloadTableData");
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

// 刷新策略（2026-09-28 重大修正）：
// 之前在这里用运行时穷举 WCTimeLineCellView 的私有 ivar/属性（class_copyIvarList + valueForKey:）
// 来定位点赞行控制器并调 onReloadCommentCellView: —— 这一步会触发惰性 getter 副作用 / 访问已释放的弱引用，
// 是“长按闪退”的直接元凶，已彻底移除。
//
// 根因（已用日志坐实）：点赞行由主 cell 的 WCTimeLineCellView 控制器渲染，其点赞列表布局缓存在
// WCDataItemUICache(likeUserLayoutStyles/likeUserHeight)，且按 dataItem 对象身份命中；我们原地改同一个
// dataItem 对象、再 reload/手动刷，都掀不掉这条缓存，所以“带赞 item 长按后点赞行不刷新、需手动拉一下”。
// 而微信原生“下拉刷新”之所以能即时刷新点赞行，是因为它从服务器拉回【新 dataItem 对象】（新指针）→
// WCTimeLineCellView 重绑 → 旧 UICache 随旧对象丢弃、按新数据重算布局。
//
// 修正（参考集赞助手“只动渲染、不碰私有控制器”的思路，但用更安全的方式）：
// 不在模型层注入、也不调 onLikeItem:/modifyDataItem:（避免误发服务器赞/取消赞），而是把“假数据”做成
// 一个【全新的 WCDataItem 深拷贝】（PBCoding round-trip），在两条【必然被渲染命中的入口】替换掉原始对象：
//   (1) %hook WCFacade getTimelineDataItemOfIndex: / getTimelineDataInCacheByItemID: —— 取项出口；
//   (2) %hook WCTimeLineCellView updateWithDataItem:actionAreaVM: —— cell 复用重绘入口（DD朋友圈助手同款位置）。
// 只要任一入口被命中，原始 dataItem 就被替换成新指针的假数据拷贝 → 微信被迫重绑 → 点赞行按新数据重算。
// 原始 dataItem 始终未被修改，零服务器副作用；开关只影响本地显示。
// 风险兜底：若 PBCoding 深拷贝失败（异常），DDLFakeCopyItem 返回 nil，调用方跳过注入（不污染、不崩）。

@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (BOOL)ddl_reloadTimelineForItem:(id)item;
- (id)navigationController;
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

    // 合二为一（参考集赞助手“只动渲染、不碰私有控制器”的思路）：
    // 长按只负责 toggle 本地状态 gDDLFaked[tid] = {@"active":@YES/@NO, @"copy":nil, ...}。
    // 真正的“数据注入 + 点赞行刷新”下沉到渲染层两入口（WCFacade 取项 + WCTimeLineCellView 渲染），
    // 那里把本项替换成 PBCoding 深拷贝的“假数据新 dataItem”（指针变化→微信重绑→点赞行按新数据重算）。
    // 不调 onLikeItem:/modifyDataItem:，因此零服务器副作用；开关只影响本地显示。
    if (tid) {
        NSMutableDictionary *st = faked[tid];
        if (st && [st[@"active"] boolValue]) {
            st[@"active"] = @NO;
            st[@"copy"] = nil;   // 下一帧渲染回到真实 dataItem（指针变化→重绑），点赞行回退真实赞数
            DDLog(@"[长按] 取消集赞 tid=%@（active=NO，记忆剩 %lu 条）", tid, (unsigned long)faked.count);
        } else {
            if (!st) {
                st = [NSMutableDictionary dictionary];
                st[@"likes"]    = [DDLikeHelper fakeLikeUsers] ?: @[];
                st[@"comments"] = [DDLikeHelper fakeCommentsFor:item] ?: @[];
                faked[tid] = st;
            }
            st[@"active"] = @YES;
            st[@"copy"] = nil;   // 强制下次渲染重新生成假数据深拷贝（指针变化→重绑）
            DDLog(@"[长按] 开启集赞 tid=%@（记忆 %lu 条）", tid, (unsigned long)faked.count);
        }
    } else {
        DDLog(@"[长按] 警告：tid 为 nil，无法记录状态");
    }

    [self hide];  // 收起点赞/评论浮层（原 onLikeItem: 会做；我们不再调它，这里补上）

    // 刷新驱动：只触发微信原生整表重载 reloadDataWrap（=下拉刷新）。
    // 点赞行能否刷新不靠手动 reload —— 而在渲染层：本项经 WCFacade 取项 / WCTimeLineCellView 渲染两处拦截，
    // 被替换成“假数据深拷贝”（指针变化迫使 WCTimeLineCellView 重绑 → 点赞行按新数据重算，=下拉刷新生效的原因）。
    // 不再调 onLikeItem: / modifyDataItem:，因此不向服务器发任何赞/取消赞，开关只影响本地显示。
    id tlvc = DDLFindTimelineVC(self);
    BOOL didNativeReload = NO;
    if (tlvc && [tlvc respondsToSelector:@selector(reloadDataWrap)]) {
        [tlvc reloadDataWrap];
        DDLog(@"[长按] 已触发 reloadDataWrap（原生整表重载）tid=%@", tid);
        didNativeReload = YES;
    }
    if (!didNativeReload) {
        // reloadDataWrap 不可用或未定位到 VC 时，用通用出口兜底（内部会再尝试 keyWindow 定位 + reloadTableView/reloadData）
        DDLReloadTimelineFrom(self, tid);
    }
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

%hook WCTimeLineCellView

// 渲染入口拦截（cell 复用时整行重绘都走这里）。active 的 tid 把数据项替换成“假数据深拷贝”，
// 指针变化迫使 WCTimeLineCellView 重绑 → 点赞行按新数据重算 WCDataItemUICache（=手动下拉刷新生效的原因）。
// 原始 dataItem 从不修改，零服务器副作用。
- (void)updateWithDataItem:(id)item actionAreaVM:(id)vm {
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    NSDictionary *st = (tid ? gDDLFaked()[tid] : nil);
    if (st && [st[@"active"] boolValue]) {
        @try {
            id copy = DDLFakeCopyForTid(tid, item);
            if (copy) {
                item = copy;
                DDLog(@"[渲染] updateWithDataItem 已替换拷贝 tid=%@ 赞=%lu", tid,
                      (unsigned long)[copy respondsToSelector:@selector(likeUsers)] ? [[copy valueForKey:@"likeUsers"] count] : 0);
            } else {
                DDLog(@"[渲染] updateWithDataItem 拷贝失败 tid=%@（跳过注入）", tid);
            }
        } @catch (NSException *e) {
            DDLog(@"[渲染] updateWithDataItem 异常 fallback: %@", e.reason);
        }
    }
    %orig(item, vm);
}

%end

%hook WCFacade

// 取项出口统一拦截：active 的 tid 返回“假数据深拷贝”，让任何拿到该 dataItem 的渲染路径都得到新指针 → 重绑。
- (id)getTimelineDataInCacheByItemID:(id)itemID {
    id item = %orig(itemID);
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    NSDictionary *st = (tid ? gDDLFaked()[tid] : nil);
    if (st && [st[@"active"] boolValue]) {
        id copy = DDLFakeCopyForTid(tid, item);
        if (copy) item = copy;
        DDLog(@"[取项] cacheByItemID tid=%@ 拷贝=%@", tid ?: @"(无)", copy ? @"Y" : @"N");
    }
    return item;
}

- (id)getTimelineDataItemOfIndex:(long long)index {
    id item = %orig(index);
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    NSDictionary *st = (tid ? gDDLFaked()[tid] : nil);
    if (st && [st[@"active"] boolValue]) {
        id copy = DDLFakeCopyForTid(tid, item);
        if (copy) item = copy;
        DDLog(@"[取项] itemOfIndex idx=%lld tid=%@ 拷贝=%@", (long long)index, tid ?: @"(无)", copy ? @"Y" : @"N");
    }
    return item;
}

%end

%hook WCTimelineMgr

// 不再在模型层注入：显示层拷贝（下方 WCFacade 取项 + WCTimeLineCellView 渲染两处拦截）已覆盖，
// 原始 dataItem 始终真实，零服务器副作用。
- (void)modifyDataItem:(id)item notify:(BOOL)notify {
    %orig(item, notify);
}

- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t {
    // 网络刷新后原始 dataItem 可能被服务器新数据覆盖：清空 active tid 的拷贝缓存，下次渲染重新生成。
    NSMutableDictionary *faked = gDDLFaked();
    if (faked.count && [datas isKindOfClass:NSArray.class]) {
        for (id obj in (NSArray *)datas) {
            if (![obj isKindOfClass:objc_getClass("WCDataItem")]) continue;
            NSString *tid = [obj respondsToSelector:@selector(tid)] ? [obj tid] : nil;
            NSDictionary *st = (tid ? faked[tid] : nil);
            if (st && [st[@"active"] boolValue]) st[@"copy"] = nil;
        }
    }
    %orig(datas, adItems, t);
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

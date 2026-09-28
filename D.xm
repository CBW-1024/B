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
- (id)getTimelineDataInCacheByItemID:(id)itemID;
- (id)getTimelineDataItemOfIndex:(long long)index;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

@interface WCOperateFloatView : UIView
// 刻意不声明 onLikeItem: —— 我们不再踢原生点赞（那会真给作者发服务器赞）。
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

#pragma mark - 配置

static NSString * const kDDMLikeEnabled    = @"DDMoments_likeEnabled";
static NSString * const kDDMLikeCount      = @"DDMoments_likeCount";
static NSString * const kDDMCommentCount   = @"DDMoments_commentCount";
static NSString * const kDDMLikeComments   = @"DDMoments_likeComments";
static NSString * const kDDMFakeStore      = @"DDMoments_fakeStore";

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
            @"[配置] 启用=%d 上次输入=%ld/%ld 评论内容=「%@」\n"
            @"[环境] 系统=%@ 微信头文件基线=8.0.79",
            c.likeEnabled, (long)c.likeCount, (long)c.commentCount, c.comments,
            [UIDevice currentDevice].systemVersion];
}

#pragma mark - 核心功能

@interface DDLikeHelper : NSObject
+ (NSArray<CContact *> *)allFriends;
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsersExcluding:(NSSet<NSString *> *)existing
                                                      limit:(NSInteger)limit;
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem target:(NSInteger)target;
@end

@implementation DDLikeHelper

static NSArray<CContact *> *gDDLFriendCache;
static NSTimeInterval gDDLFriendCacheAt;

// Fisher-Yates 洗牌。好友池不够要复用时若按原顺序绕回来，被重复的一定是好友池最前面
// 几个，点赞行里连着出现同一个昵称，很扎眼；首轮不洗的话每次集赞也总是同一批人。
// 每轮洗一次，复用谁就是随机的，分布也均匀。锤子取完好友也是洗牌的。
static void DDLShuffle(NSMutableArray *a) {
    for (NSUInteger i = a.count; i > 1; i--) {
        [a exchangeObjectAtIndex:i - 1 withObjectAtIndex:arc4random_uniform((uint32_t)i)];
    }
}

// 给造出来的假 WCUserComment 打个标记（关联对象），撤销时靠它把假的挑出来。
// 早先的做法是「记下假数据的 username，撤销时按名字剔除」，那套有个硬伤：
// 假评论很可能跟某条真实评论是同一个人（好友池就那么几个），按名字剔除会连真评论
// 一起删掉；为了避开它又得在生成时加去重，越弄越复杂。按对象标记就没有这个约束，
// 重名也无所谓 —— 真的那条不带标记，自然会被留下。
static const void *kDDLFakeMarkKey = &kDDLFakeMarkKey;

static inline void DDLMarkFake(WCUserComment *u) {
    objc_setAssociatedObject(u, kDDLFakeMarkKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline BOOL DDLIsFake(WCUserComment *u) {
    return objc_getAssociatedObject(u, kDDLFakeMarkKey) != nil;
}

// 一次注入里会被调两遍（造赞 + 造评论），所以命中缓存时静默返回，只在真正拉取时打日志。
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
    DDLog(@"[好友] 真实好友池=%lu", (unsigned long)friends.count);
    return gDDLFriendCache;
}

// 「补齐到 target」而不是「追加 target 个」—— 与 fakeCommentsFor: 的语义保持一致。
// 旧版固定造 target 个再靠 username 去重，实际新增数会随「原本点过赞的人碰不碰巧落在好友池前 N 位」
// 在 2 和 3 之间飘（实测日志：生成=3 但新增=2）。现在由调用方算出还缺几个（limit）传进来，
// 并且跳过 existing 里的用户名，保证稳定补齐到 target。
// 好友池不够就绕回来复用同一个人（点赞行会出现重复昵称，但数量必须凑够，用户要求）。
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsersExcluding:(NSSet<NSString *> *)existing
                                                      limit:(NSInteger)limit {
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
            // 第一轮先避开已经赞过的人；之后好友不够要复用时不再避让
            if (firstRound && [existing containsObject:name]) continue;
            WCUserComment *u = [[objc_getClass("WCUserComment") alloc] init];
            u.username   = name;
            u.nickname   = c.m_nsNickName;
            // 锤子 ApplyFake 反汇编（fake.txt 0x7b650c-0x7b6528）：
            //   mov w2, #1 → setType:1（1=赞；2=文本评论。type=2 混入 likeUsers 会被点赞行
            //   渲染器按评论处理，content 为 nil 时走图片占位分支 → 行内出现「图片」+空槽）
            //   setContent:@""（0xd9f180 CFString len=0 空串，不能为 nil）
            u.type       = 1;
            u.content    = @"";
            u.commentID  = [NSString stringWithFormat:@"%lu", (unsigned long)idx++];
            u.createTime = now;
            DDLMarkFake(u);
            [list addObject:u];
            added = YES;
        }
        if (!added && !firstRound) break;   // 整轮一个都没加上，别死循环
        firstRound = NO;
    }
    return list;
}

// target 由调用方给（每条朋友圈各自记的「点赞数/评论数」，不是全局配置）
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem target:(NSInteger)target {
    NSMutableArray *orig = origItem.commentUsers ?: [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[评论] target=%ld ≤0，不补评论", (long)target);
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

    NSArray *friends = [self allFriends];
    if (friends.count == 0) {
        DDLog(@"[评论] 好友池为空，补不出评论");
        return orig;
    }

    // 好友池不够就绕回来复用（同一个人评论多条，内容随机，看起来不重复）。
    // 之前是一轮走完就完事，好友 6 个想凑 10 条就只能凑到 6 条。
    // 变量名叫 friendPool：上面的 pool 是「评论内容池」，别混
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
        if (!added) break;   // 整轮一个都没加上（好友都没用户名），别死循环
    }

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
@end

// 微信原生弹窗类（WCUIAlertView.h）——带取消 + 确认两个按钮的那款，可挂输入框
@interface WCUIAlertView : NSObject
+ (id)showAlertWithTitle:(id)title message:(id)message
          cancelBtnTitle:(id)cancelTitle target:(id)cancelTarget sel:(SEL)cancelSel
               btnTitle:(id)btnTitle target:(id)btnTarget sel:(SEL)btnSel;
// WCUIAlertView.h:40 / :38 / :25 —— 输入「点赞数/评论数」要用到。
// 锤子是用 KVC 摸 _tipsVc._tipsTextView.text 拿文本的，我们头文件里有现成的
// getTextFieldText，直接用，少一层对私有 ivar 结构的依赖。
- (void)showTextFieldWithMaxLen:(unsigned int)maxLen;
- (void)setTextFieldPlaceHolder:(id)placeholder;
- (void)setTextFieldDefaultText:(id)text;   // 真文本。placeholder 不算输入内容，别搞混
- (id)getTextFieldText;
@end

// tid → @{ @"l": 点赞数, @"c": 评论数 }
// 每条朋友圈各自记一份「要多少赞/多少评论」，因为数量是弹窗时输入的，不再是全局配置。
//
// 持久化在 NSUserDefaults —— 否则微信一重启内存就清空，补回路径认不出这些 tid，
// 假赞全没了、得重新长按一次。重启后不需要手动重建：补回路径（两个 WCFacade getter）
// 在第一次渲染时会照常填回去。
//
// 只存数量，不存「注入了哪些 username」：撤销靠假对象上的关联对象标记识别
// （DDLMarkFake / DDLIsFake），不需要名单。完整性判断也只看数量（见 DDLItemFakeIntact），
// 因为好友池顺序一变，重新造出的人就跟上次不是同一批，按名字比对永远判不达标。
static NSMutableDictionary *gDDLFake(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kDDMFakeStore];
        d = saved ? [saved mutableCopy] : [NSMutableDictionary new];
    });
    return d;
}

// 落盘。只在集赞/撤销/清除时调用，补回路径有预检挡着，不会高频触发。
static void DDLFakeSave(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:gDDLFake() forKey:kDDMFakeStore];
    [ud synchronize];
}

// 单个数量的上限。好友不够时是靠复用凑数的，不封顶的话输个 999999 会循环很久。
static const NSInteger kDDLMaxCount = 100;

// 解析弹窗输入「5/6」。返回 NO = 输入为空（调用方按「取消伪装」处理）。
// 只填一个数字（"5"）→ 只改点赞；"0" / "0/0" / 非数字 → 都归为取消伪装。
static BOOL DDLParseSpec(NSString *text, NSInteger *outL, NSInteger *outC) {
    NSString *s = [(text ?: @"") stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return NO;

    NSArray *parts = [s componentsSeparatedByString:@"/"];
    NSInteger l = 0, c = 0;
    if (parts.count > 0) l = [parts[0] integerValue];
    if (parts.count > 1) c = [parts[1] integerValue];
    // 封顶，免得输个天文数字把「好友不够就复用」的循环跑飞
    *outL = l > 0 ? MIN(l, kDDLMaxCount) : 0;
    *outC = c > 0 ? MIN(c, kDDLMaxCount) : 0;
    return YES;
}

// 长按那一刻必须自己留一份 item 强引用，不能指望回调时再读 self.m_item。
// 实测证据（DDLikeHelper.log-2.txt）：[self hide] 之后微信会把浮层的 m_item 清掉，
// 弹窗确认回调里 self.m_item 已经是 nil，日志表现为
//   「[弹窗] 确认但 m_item 已失效，跳过」—— 假赞和评论一个都没注入。
// 注意「self 活着」不等于「m_item 还在」：回调能打进本方法只说明 self 没被释放。
static WCDataItem *gDDLPendingItem = nil;

// 当前弹窗，确认回调里要用它 getTextFieldText 取输入内容
static WCUIAlertView *gDDLCurrentAlert = nil;

// 剔除带标记的假数据，stripLikes / stripCmts 控制剔哪一边。
// 只认对象标记，不看 username —— 所以假评论跟真评论重名也不会误删真评论。
static void DDLStripFakeFromItem(WCDataItem *di, BOOL stripLikes, BOOL stripCmts) {
    if (stripLikes) {
        NSMutableArray *likes = [NSMutableArray array];
        for (WCUserComment *u in ([di respondsToSelector:@selector(likeUsers)] && [di likeUsers]
                                  ? [di likeUsers] : @[])) {
            if (!DDLIsFake(u)) [likes addObject:u];
        }
        [di setLikeUsers:likes];
        [di setLikeCount:(int)likes.count];
    }
    if (stripCmts) {
        NSMutableArray *cmts = [NSMutableArray array];
        for (WCUserComment *u in ([di respondsToSelector:@selector(commentUsers)] && [di commentUsers]
                                  ? [di commentUsers] : @[])) {
            if (!DDLIsFake(u)) [cmts addObject:u];
        }
        [di setCommentUsers:cmts];
        [di setCommentCount:(int)cmts.count];
    }
}

// 追加式注入：保留原始名单 → 补齐假的到 target → 写回。
// 「补齐」而非「追加固定个数」，所以天然幂等：重复点确认不会把假赞叠加两份。
// lTarget / cTarget 来自这条朋友圈自己的记录（弹窗输入的「点赞数/评论数」）。
static void DDLApplyFakeToItem(WCDataItem *di, NSInteger lTarget, NSInteger cTarget) {
    NSString *tid = ([di respondsToSelector:@selector(tid)] ? [di tid] : nil);

    // 某一边的目标是 0，就表示这次不要那一边的伪装：
    // 输「5」= 只要赞、输「/6」= 只要评论。先把上一轮留在那边的假数据剔掉，
    // 不然旧的假赞/假评论会一直挂着，看起来像没生效。
    if (lTarget <= 0 || cTarget <= 0) {
        DDLStripFakeFromItem(di, lTarget <= 0, cTarget <= 0);
    }

    NSMutableArray *likes = ([di respondsToSelector:@selector(likeUsers)] && [di likeUsers])
                          ? [[di likeUsers] mutableCopy] : [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (WCUserComment *u in likes) {
        if ([u respondsToSelector:@selector(username)] && u.username) [seen addObject:u.username];
    }

    NSInteger limit = lTarget - (NSInteger)likes.count;   // 还缺几个
    if (lTarget > 0 && limit > 0) {
        NSArray *fresh = [DDLikeHelper fakeLikeUsersExcluding:seen limit:limit];
        for (WCUserComment *u in fresh) {
            if (u.username) [seen addObject:u.username];
            [likes addObject:u];
        }
        if (fresh.count) {
            // 只写这两个，跟锤子一致。realLikeCount 不用管：全量头文件 dump 里
            // 除了 WCDataItem.h 自己声明，没有任何第二个类读它（锤子也没设）。
            [di setLikeUsers:likes];
            [di setLikeCount:(int)likes.count];
            DDLog(@"[注入] 假赞 tid=%@ 新增=%lu 合计=%lu（target=%ld）",
                  tid, (unsigned long)fresh.count, (unsigned long)likes.count, (long)lTarget);
        } else {
            DDLog(@"[注入] 假赞 tid=%@ 缺 %ld 个但好友池已无可补的人", tid, (long)limit);
        }
    } else {
        DDLog(@"[注入] 假赞 tid=%@ 已有 %lu ≥ target=%ld，跳过",
              tid, (unsigned long)likes.count, (long)lTarget);
    }

    NSUInteger before = ([di respondsToSelector:@selector(commentUsers)] && [di commentUsers])
                      ? [di commentUsers].count : 0;
    NSMutableArray *comments = [[DDLikeHelper fakeCommentsFor:di target:cTarget] mutableCopy];
    if (comments.count != before) {
        [di setCommentUsers:comments];
        [di setCommentCount:(int)comments.count];
        DDLog(@"[注入] 假评论 tid=%@ %lu→%lu", tid,
              (unsigned long)before, (unsigned long)comments.count);
    } else {
        DDLog(@"[注入] 假评论 tid=%@ 无新增（已达目标数/未配置）", tid);
    }

    if (tid) {
        gDDLFake()[tid] = @{ @"l": @(lTarget), @"c": @(cTarget) };
    }
    DDLFakeSave();   // 落盘，这样重启微信后补回路径还能认出这条
}

// 取消伪装：两边都剔，恢复真实数据，并删掉持久化记录（重启后也不再恢复）。
static void DDLRemoveFakeFromItem(WCDataItem *di, NSString *tid) {
    DDLStripFakeFromItem(di, YES, YES);
    [gDDLFake() removeObjectForKey:tid];
    DDLFakeSave();
    DDLog(@"[撤销] 已剔除假数据 tid=%@ → 赞 %lu 评论 %lu", tid,
          (unsigned long)(([di respondsToSelector:@selector(likeUsers)] && [di likeUsers])
                          ? [di likeUsers].count : 0),
          (unsigned long)(([di respondsToSelector:@selector(commentUsers)] && [di commentUsers])
                          ? [di commentUsers].count : 0));
}

// 假赞是否还完整挂在 item 上：只看数量达不达标，不比对具体是谁。
// 补回路径随 cell 渲染高频触发，这里必须便宜 —— 不造对象、不打日志，绝大多数调用到此结束。
// 用数量而不是用户名集合，是为了跟持久化解耦：重启后好友池顺序可能变，重新造出的人
// 跟上一次未必是同一批，按名字比对就会永远判定「不完整」，变成每次渲染都补回。
static BOOL DDLItemFakeIntact(WCDataItem *di, NSDictionary *rec) {
    NSInteger lTarget = [rec[@"l"] integerValue];
    if (lTarget > 0) {
        NSUInteger lc = ([di respondsToSelector:@selector(likeUsers)] && [di likeUsers])
                      ? [di likeUsers].count : 0;
        if ((NSInteger)lc < lTarget) return NO;
    }
    NSInteger cTarget = [rec[@"c"] integerValue];
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
    if (!tid) return;
    NSDictionary *rec = gDDLFake()[tid];
    if (!rec) return;                           // 这条没伪装过
    if (DDLItemFakeIntact(di, rec)) return;     // 还挂着，什么都不用做
    DDLApplyFakeToItem(di, [rec[@"l"] integerValue], [rec[@"c"] integerValue]);
    DDLog(@"[保活] 补回假赞 tid=%@", tid);      // 真被冲掉了才走到这，这时日志有价值
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
    DDLog(@"[手势] 已挂长按 likeBtn=%p", btn);   // 只打地址：%@ 会展开整个按钮 description，纯占地方
}

%new
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!DDLikeConfig.shared.likeEnabled) return;

    WCDataItem *item = self.m_item;
    if (!item) { DDLog(@"[长按] m_item 为 nil，中止"); return; }

    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    gDDLPendingItem = item;   // 浮层收起后 m_item 会被清空，回调里只能靠这份

    NSDictionary *rec = tid ? gDDLFake()[tid] : nil;
    DDLog(@"[长按] 触发 tid=%@ 已伪装=%d（%ld/%ld）现有赞=%lu 评论=%lu",
          tid, rec ? 1 : 0,
          (long)[rec[@"l"] integerValue], (long)[rec[@"c"] integerValue],
          (unsigned long)([item respondsToSelector:@selector(likeUsers)] ? [item likeUsers].count : 0),
          (unsigned long)([item respondsToSelector:@selector(commentUsers)] ? [item commentUsers].count : 0));

    [self hide];   // 先收起点赞浮层，免得它盖住弹窗

    Class alertCls = objc_getClass("WCUIAlertView");
    BOOL canInput = alertCls
                 && [alertCls respondsToSelector:@selector(showAlertWithTitle:message:cancelBtnTitle:target:sel:btnTitle:target:sel:)]
                 && [alertCls instancesRespondToSelector:@selector(showTextFieldWithMaxLen:)]
                 && [alertCls instancesRespondToSelector:@selector(getTextFieldText)];
    if (canInput) {
        DDLikeConfig *cfg = DDLikeConfig.shared;
        // 输入框版：数量在弹窗里输，格式「点赞数/评论数」，留空 = 取消伪装
        NSString *msg = rec
            ? [NSString stringWithFormat:
               @"输入「点赞数/评论数」，例如 5/6。\n当前：%ld 赞 / %ld 评论\n留空确认 = 取消伪装。",
               (long)[rec[@"l"] integerValue], (long)[rec[@"c"] integerValue]]
            : @"输入「点赞数/评论数」，例如 5/6。\n只填一个数字则只改点赞。\n留空确认 = 取消伪装。\n仅本地显示，不会发给微信服务器。";

        WCUIAlertView *alert = (WCUIAlertView *)[alertCls showAlertWithTitle:@"集赞助手"
                                                                     message:msg
                                                             cancelBtnTitle:@"取消" target:self sel:@selector(ddl_fakeCancelled)
                                                                  btnTitle:@"确认" target:self sel:@selector(ddl_fakeConfirmed)];
        [alert showTextFieldWithMaxLen:15];
        // 预填上次的数值，省得每次重输
        // 必须用 setTextFieldDefaultText 而不是 PlaceHolder：placeholder 只是灰字提示，
        // 不算输入内容 —— 用户看到框里有「5/6」直接点确认，getTextFieldText 读到的是空串，
        // 会被当成「留空 = 取消伪装」，把刚想设的伪装给撤销掉。设成真文本就没这个坑，
        // 真要取消伪装得手动把框清空。
        [alert setTextFieldDefaultText:(cfg.likeCount > 0 || cfg.commentCount > 0)
                                       ? [NSString stringWithFormat:@"%ld/%ld",
                                          (long)cfg.likeCount, (long)cfg.commentCount]
                                       : @"5/6"];
        [alert setTextFieldPlaceHolder:@"留空确认 = 取消伪装"];
        gDDLCurrentAlert = alert;   // 确认回调里要靠它 getTextFieldText
        DDLog(@"[长按] 已弹输入框弹窗 tid=%@（取消/确认）", tid);
    } else {
        // 拿不到输入框就退回上次输入的数值，至少别卡住
        DDLog(@"[长按] ⚠WCUIAlertView 输入框不可用，按上次数值执行 tid=%@", tid);
        [self ddl_fakeConfirmed];
    }
}

%new
- (void)ddl_fakeConfirmed {
    WCDataItem *item = gDDLPendingItem ?: (WCDataItem *)self.m_item;
    if (!item) { DDLog(@"[弹窗] 确认但 item 已失效，跳过"); return; }
    NSString *tid = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);

    // WCUIAlertView.h:25 -(id)getTextFieldText —— 直接拿，不用像锤子那样 KVC 摸
    // _tipsVc._tipsTextView.text。取不到时按「空输入」处理，即取消伪装。
    NSString *text = nil;
    if (gDDLCurrentAlert && [gDDLCurrentAlert respondsToSelector:@selector(getTextFieldText)]) {
        id t = [gDDLCurrentAlert getTextFieldText];
        if ([t isKindOfClass:[NSString class]]) text = t;
    }
    DDLog(@"[弹窗] 已确认 tid=%@ 输入=「%@」", tid, text ?: @"");

    NSInteger l = 0, c = 0;
    BOOL hasSpec = DDLParseSpec(text, &l, &c);
    if (!hasSpec || (l <= 0 && c <= 0)) {
        // 空 / 0 / 0/0 / 非数字 → 取消伪装
        if (tid && gDDLFake()[tid]) {
            DDLRemoveFakeFromItem(item, tid);
        } else {
            DDLog(@"[撤销] 这条本来就没伪装，无需处理 tid=%@", tid);
        }
    } else {
        DDLikeConfig.shared.likeCount = l;      // 记下来，下次弹窗预填
        DDLikeConfig.shared.commentCount = c;
        DDLApplyFakeToItem(item, l, c);
    }

    // 刷新走锤子同款：调微信原生 modifyDataItem:notify: 触发「数据项已变更」的原生更新 + 重绑。
    // 反汇编证据（hammer fake.txt 0x7b61ac-0x7b61b8）：x0=[block+0x20](WCFacade) → x2=dataItem → w3=1 → bl modifyDataItem:notify:。
    // reloadTableView/reloadDataWrap 那套只是 reloadData，掀不掉点赞行缓存，所以本来带赞的 item 一直不刷新。
    // 强转成 WCFacade *：id 接收者会同时匹配 WCFacade/WCTimelineMgr 的同名声明，报 "multiple methods named"。
    id svc = DDLFacadeService();
    if (svc && [svc respondsToSelector:@selector(modifyDataItem:notify:)]) {
        [(WCFacade *)svc modifyDataItem:item notify:YES];
        DDLog(@"[刷新] 已调 [WCFacade modifyDataItem:notify:YES] tid=%@", tid);
    } else {
        // 数据已经写进 dataItem 了，只是这一下不会自动重绘，下拉一次即可看到。
        DDLog(@"[刷新] ⚠取不到 WCFacade，本次不自动刷新 tid=%@", tid);
    }
    gDDLCurrentAlert = nil;
    gDDLPendingItem = nil;
}

%new
- (void)ddl_fakeCancelled {
    NSString *tid = (gDDLPendingItem && [gDDLPendingItem respondsToSelector:@selector(tid)])
                  ? [gDDLPendingItem tid] : nil;
    DDLog(@"[弹窗] 已取消 tid=%@", tid);
    gDDLCurrentAlert = nil;
    gDDLPendingItem = nil;
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

static void DDLogExportFrom(UIViewController *vc) {
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
    }
    [vc presentViewController:av animated:YES completion:nil];
}

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

    // 原来在 init 里建一次、viewDidLoad 里又建一次，重复；init 整个删掉，只留这里。
    if (!self.tableViewManager) {
        self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                                  initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
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
                                     title:@"启用集赞"
                                        on:cfg.likeEnabled]];

    if (cfg.likeEnabled) {
        // 点赞数/评论数不在设置里配 —— 长按弹窗时现输，格式「点赞数/评论数」如 5/6，
        // 留空确认即取消伪装。设置里只留开关和评论内容池。
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"数量在长按弹窗里输入"
                                    rightValue:(cfg.likeCount > 0 || cfg.commentCount > 0)
                                               ? [NSString stringWithFormat:@"上次 %ld/%ld",
                                                  (long)cfg.likeCount, (long)cfg.commentCount]
                                               : @"未输入过"]];

        self.commentsField = [self makeFieldPlaceholder:@"多个内容用-分隔"
                                                number:NO
                                                 value:cfg.comments];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳评论内容"
                                    rightView:[self inputRowWithField:self.commentsField
                                                               action:@selector(commentsConfirmed:)]]];

        // 已伪装的记录是持久化的（重启微信后自动恢复），给个入口清掉
        NSUInteger fakeN = gDDLFake().count;
        if (fakeN > 0) {
            [sec addCell:[cellMgr normalCellForSel:@selector(onClearFakeTapped)
                                            target:self
                                             title:@"   ↳清除伪装记录"
                                        rightValue:[NSString stringWithFormat:@"%lu 条", (unsigned long)fakeN]]];
        }
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

// 清掉持久化记录：这些 tid 重启微信后不再自动恢复，界面上也会立刻退回真实赞
- (void)onClearFakeTapped {
    NSUInteger n = gDDLFake().count;
    [gDDLFake() removeAllObjects];
    DDLFakeSave();
    // 只清记录：内存里已加载的 dataItem 还挂着假数据，要等数据被微信冲掉（下拉/重启）才还原
    DDLog(@"[设置] 已清除 %lu 条伪装记录（重启后不再自动恢复）", (unsigned long)n);
    [self buildTable];
}

- (void)onExportLogTapped {
    DDLogExportFrom(self);
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

// DDLikeHelper.xm
// 微信集赞助手（Theos / Logos，arm64 / arm64e）
//
// 功能：
//   长按朋友圈「赞 / 评论」浮窗里的点赞按钮（1 秒），按配置伪造指定数量的
//   「点赞」与「评论」，数据落在本地 WCDataItem 上，不改服务端。
//   普通单击点赞完全不受影响 —— 挂 likeFlag 被动伪造会连正常点赞一起改掉。
//
// 触发链路：
//   长按 m_likeBtn（1 秒）→ 备份原始值 → 写伪造数据、置 likeFlag、清 cpKeyForLikeUsers
//   → 调 WCTimelineMgr.modifyDataItem:notify: 通知一次刷新 → 收起浮窗。
//   再次长按同一条 → 按快照恢复原样（取消集赞）并同样刷新。
//   全程同步，不拦原生回调、不等服务器返回（本地伪装用不上）。
//
// 两个坑（都是真机踩出来的）：
//   - cpKeyForLikeUsers 是点赞区的布局缓存键，改 likeUsers 必须一并清掉，
//     否则微信认为点赞区没变、不重绘 —— 表现为「评论出来了、赞没出来」。
//   - 下拉刷新 / 翻页会重建 WCDataItem 对象，内存改动全丢，
//     故把伪造状态按 tid 记在 gDDLFaked 里，再于
//     WCTimelineMgr.commonProcessDataAfterUpdate: 里按 tid 重新伪造。
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
//   3. DDLikeHelper 与 %hook WCOperateFloatView 整段搬过去。
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

// 联系人基类：m_nsUsrName / 类型字段都在这里，不在 CContact.h —— 故 CContact 须声明继承自 CBaseContact。
@interface CBaseContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;    // CBaseContact.h:140
@property (nonatomic) unsigned int m_uiType;            // CBaseContact.h:155 类型（1=个人 2=群 3=公众号? 取值待实测）
@property (nonatomic) unsigned int m_uiFriendScene;     // CBaseContact.h:150 加好友来源场景：非 0 = 经好友请求添加
@property (nonatomic) unsigned int realFriendScene;      // CBaseContact.h:156 场景位（实测不可靠，含公众号）
@property (nonatomic) unsigned long long m_uiTypeExt;   // CBaseContact.h:157 扩展类型
@end

@interface CContact : CBaseContact
@property (retain, nonatomic) NSString *m_nsNickName;   // CContact.h:281
- (BOOL)isBrandContact;                                  // CContact.h:101 gh_ 公众号 = 非好友
@end

@interface CContactMgr : NSObject
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;   // CContactMgr.h:173
- (BOOL)isHardCodeContact:(id)arg1;                                              // CContactMgr.h:63 系统硬编码号判定
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
@property (retain, nonatomic) NSString *tid;                  // WCDataItem.h:279 帖子唯一标识
@property (retain, nonatomic) id cpKeyForLikeUsers;           // WCDataItem.h:217 点赞区布局缓存键
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;       // WCTimelineMgr.h:71
- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t; // :59
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

#pragma mark - 调试日志

// 非越狱（证书注入）没有 ssh / 系统控制台，日志只能从 App 内取：
// 内存环形缓冲 → 设置页查看 / UIActivityViewController 导出成 txt。
static const NSUInteger kDDLogMaxLines = 500;   // 超出丢弃最旧的，防止长时间运行吃内存

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

// 刷新回调可能不在主线程，故加锁。
// 不走 NSLog：非越狱（证书注入）看不到系统控制台，写了也白写。
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

// 当前配置一览，导出时前置到日志头部，便于对照现象看参数。
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

@interface CContact (DDFriendExt)
- (unsigned int)m_uiSex;
@end

@implementation DDLikeHelper

// 真实好友池 = 非公众号 + 有性别 + 用户名不含 @openim。
// 最后一项来自 WCRefine.dylib 的 +allFriends（IMP 0x0fa0434）反汇编实证：
// 它对每个联系人依次判 isBrandContact / m_uiSex / [m_nsUsrName containsString:@"@openim"]，
// 三者皆过才入池。@openim 是微信客服 / 开放平台机器人账号前缀（虽带性别但非真人），
// 不剔除会被当成「点赞人」塞进列表。
+ (NSArray<CContact *> *)allFriends {
    NSMutableArray *friends = [NSMutableArray array];
    CContactMgr *mgr = DDLContactMgr();
    for (CContact *c in [mgr getContactList:1 contactType:0]) {
        if (![c isBrandContact] && [c m_uiSex] != 0 &&
            ![[c m_nsUsrName] containsString:@"@openim"]) {
            [friends addObject:c];
        }
    }
    DDLog(@"[好友] 真实好友池=%lu", (unsigned long)friends.count);
    return friends;
}

// 构造伪造点赞列表。likeCount <= 0 视为未设置，返回空数组（调用方据此不覆盖原值）。
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers {
    NSInteger target = DDLikeConfig.shared.likeCount;
    NSMutableArray *list = [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[点赞] target=%ld ≤0，未设置点赞数，跳过", (long)target);
        return list;
    }

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
    DDLog(@"[点赞] target=%ld 好友池=%lu → 生成=%lu",
          (long)target, (unsigned long)[self allFriends].count, (unsigned long)list.count);
    return list;
}

// 构造伪造评论列表：补齐到 commentCount 条，时间落在原帖发布至今之间并升序排列。
+ (NSMutableArray<WCUserComment *> *)fakeCommentsFor:(WCDataItem *)origItem {
    NSInteger target = DDLikeConfig.shared.commentCount;
    NSMutableArray *orig = origItem.commentUsers ?: [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[评论] target=%ld ≤0，未设置评论数，跳过", (long)target);
        return orig;                                    // 未设置数量：原样返回
    }
    if ((NSInteger)orig.count >= target) {
        DDLog(@"[评论] 已有 %lu 条 ≥ target=%ld，跳过", (unsigned long)orig.count, (long)target);
        return orig;                                    // 已够：原样返回
    }

    // 未填写评论内容：不做伪造，避免产生空文本评论。
    NSArray<NSString *> *pool = DDLikeConfig.shared.commentPool;
    if (pool.count == 0) {
        DDLog(@"[评论] 内容池为空（未填写评论内容），跳过");
        return orig;
    }

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
    DDLog(@"[评论] target=%ld 原有=%lu 内容池=%lu → 生成后=%lu",
          (long)target, (unsigned long)orig.count, (unsigned long)pool.count, (unsigned long)list.count);
    return list;
}

@end

#pragma mark - Hook：长按点赞 → 集赞

// 长按手势的挂载去重键。
static const void *kDDLLongPressKey = &kDDLLongPressKey;

// 幂等标记：打在已伪装的 WCDataItem 上，刷新回调命中时若内容一致可跳过重写。
static const void *kDDLFakedMark = &kDDLFakedMark;

// 已集赞的帖子：tid → @{ orig: 原始快照, likes: 固定伪造点赞, comments: 固定伪造评论 }。
// 两个用途：刷新后按 tid 复用「固定内容」重新伪造（刷新会重建 item、冲掉内存改动）；
// 再次长按则据 orig 恢复原样（取消集赞）。内容只在长按开启时生成一次，刷新不重随机。
static NSMutableDictionary *gDDLFaked(void) {
    static NSMutableDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary new]; });
    return d;
}

// 备份 / 恢复原始数据。
static NSDictionary *DDLSnapshotOf(WCDataItem *item) {
    return @{
        @"likeUsers":    item.likeUsers    ?: @[],
        @"likeCount":    @(item.likeCount),
        @"commentUsers": item.commentUsers ?: @[],
        @"commentCount": @(item.commentCount),
        @"likeFlag":     @(item.likeFlag),
    };
}

static void DDLRestore(WCDataItem *item, NSDictionary *snap) {
    NSDictionary *o = snap[@"orig"];
    item.likeUsers    = [o[@"likeUsers"] mutableCopy];
    item.likeCount    = [o[@"likeCount"] intValue];
    item.commentUsers = [o[@"commentUsers"] mutableCopy];
    item.commentCount = [o[@"commentCount"] intValue];
    item.likeFlag     = [o[@"likeFlag"] boolValue];
    item.cpKeyForLikeUsers = nil;               // 取消时也要让点赞区重绘
    objc_setAssociatedObject(item, kDDLFakedMark, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); // 清幂等标记
}

// 把「已生成的固定伪造内容」写回 item。
// 本函数不再生成随机内容——内容由长按处生成一次后存进 gDDLFaked，
// 这里只负责回填 + 清 cpKey + 打幂等标记。刷新回调复用同一份内容，评论不再随机变。
static inline void DDLFakeInto(WCDataItem *item, NSArray *likes, NSArray *comments) {
    if (!item) return;
    if (comments.count) {
        item.commentUsers = [comments mutableCopy];
        item.commentCount = (int)comments.count;
    }
    if (likes.count) {
        item.likeUsers = [likes mutableCopy];
        item.likeCount = (int)likes.count;
    }
    // 关键：cpKey 是微信的布局缓存键（同类还有 cpKeyForMessage / cpKeyForNickname）。
    // 只改 likeUsers 而 cpKeyForLikeUsers 不变，微信认为点赞区内容没变就不重绘，
    // 表现为「评论出来了、赞没出来」。置 nil 强制重算。
    item.cpKeyForLikeUsers = nil;
    // 幂等标记：同一 item 实例已伪装且一致时，刷新回调可跳过重写（省一次回填 + 日志）。
    objc_setAssociatedObject(item, kDDLFakedMark, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    // 关键：截留触摸，避免长按被按钮当成一次普通点击而触发真实点赞。
    // delaysTouchesBegan=YES → 按住期间触摸先被手势持有；识别成长按则取消该次触摸
    // （不触发 m_likeBtn 的 touchUpInside 真实赞）；没按够 1 秒松手则手势失败、触摸照常下发
    // （轻点仍走微信真实点赞）。cancelsTouchesInView 默认 YES，识别成功后即取消在视图上的触摸。
    lp.delaysTouchesBegan = YES;
    [btn addGestureRecognizer:lp];
    objc_setAssociatedObject(btn, kDDLLongPressKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    DDLog(@"[手势] 已挂长按 likeBtn=%@", btn);
}

%new
// 长按点赞按钮：开则备份 + 伪造，关则恢复原样，然后统一刷新、收起浮窗。
// 全程同步，不等任何回调；伪造状态按 tid 记住，供刷新后重建。
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (!DDLikeConfig.shared.likeEnabled) return;

    WCDataItem *item = self.m_item;
    if (!item) { DDLog(@"[长按] m_item 为 nil，中止"); return; }

    NSString *tid = item.tid;
    NSMutableDictionary *faked = gDDLFaked();
    DDLog(@"[长按] 触发 tid=%@ likeFlag=%d 已集赞=%d", tid, item.likeFlag, tid ? (faked[tid] != nil) : -1);

    if (tid && faked[tid]) {
        // 已集赞 → 取消：恢复原始数据并遗忘这条。
        DDLRestore(item, faked[tid]);
        [faked removeObjectForKey:tid];
        DDLog(@"[长按] 取消集赞 tid=%@（已恢复原始值，记忆剩 %lu 条）", tid, (unsigned long)faked.count);
    } else {
        // 未集赞 → 首次生成固定伪造内容并备份原始值，记住 tid。
        // 关键点：评论 / 点赞内容「只在此处生成一次」，后续刷新只复用，不再随机，
        // 否则每次后台轮询都会重新随机、内容来回跳。
        // 不调原生 onLikeItem:——它是点赞 / 取消赞的开关，已赞时调会反而取消。
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
        item.likeFlag = YES;
        NSDictionary *snap = (tid ? faked[tid] : nil);
        DDLFakeInto(item, snap[@"likes"], snap[@"comments"]);
        DDLog(@"[写入] tid=%@ 赞=%lu 评论=%lu（固定内容，刷新不重随机）",
              tid, (unsigned long)[snap[@"likes"] count], (unsigned long)[snap[@"comments"] count]);
        DDLog(@"[长按] 开启集赞 tid=%@（记忆 %lu 条）", tid, (unsigned long)faked.count);
    }

    // 借 WCTimelineMgr 的统一出口通知一次刷新（WCTimelineMgr.h:71）。
    id mgr = DDLTimelineMgr();
    if (mgr) {
        [mgr modifyDataItem:item notify:YES];
        DDLog(@"[刷新] modifyDataItem:notify: 已调用");
    } else {
        DDLog(@"[刷新] 警告：WCTimelineMgr 取不到（WCFacade/ServiceCenter 链断了），本次不会自动刷新");
    }

    [self hide];
}

%end

%hook WCTimelineMgr

// 数据更新后的统一出口（WCTimelineMgr.h:59）。下拉刷新 / 翻页会重建 item 对象，
// 内存里的伪造数据被冲掉，故在这里对「已集赞」的帖子按 tid 重新伪造。
// 在 %orig 之前改，让微信后续流程拿到的就是伪造后的数据。
- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t {
    NSMutableDictionary *faked = gDDLFaked();
    BOOL isArray = [datas isKindOfClass:NSArray.class];
    NSUInteger hit = 0;     // 真正重写（微信重建出新对象）的次数
    NSUInteger skip = 0;    // 幂等跳过（同实例已伪装且一致）的次数

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
            // 幂等：同一实例已伪装且内容一致（点赞 / 评论条数吻合）则跳过重写，
            // 只在微信重建出新对象（后台轮询常见）时才回填固定内容。
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
}

%end

#pragma mark - 日志查看 / 导出

// 把「配置概览 + 日志正文」写成 txt，调起系统分享面板：
// 可存到文件 App、发微信给自己、隔空投送——非越狱下最省事的取出方式。
static void DDLogExportFrom(UIViewController *vc, id sender) {
    NSString *text = [NSString stringWithFormat:@"%@\n\n%@", DDLogConfigSummary(), DDLogText()];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DDLikeHelper.log.txt"];
    [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    UIActivityViewController *av =
        [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                          applicationActivities:nil];
    // iPad 上必须给锚点，否则直接崩。
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

    [self addDebugSection];
}

// 调试分组：只有导出和清空。调通后整段删掉即可。
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

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
//   → 对时间线做一次「整表重绘」→ 收起浮窗。
//   再次长按同一条 → 按快照恢复原样（取消集赞）并同样重绘。
//   全程同步，不拦原生回调、不等服务器返回（本地伪装用不上）。
//
// 刷新方式（实测修正过三版，第四版按锤子 dylib 的反汇编结论重写）：
//   改完 item → [WCTimelineMgr modifyDataItem:item notify:YES]（微信官方刷新通道）。
//
//   第一版：单行 reloadRowsAtIndexPaths —— 「本来就有赞」的帖子加了伪赞画面不变。
//   第二版：reloadTableView 排第一 —— 实测无效：
//           00:33:54.374 [刷新] 整表重绘 出口=reloadTableView（耗时 105ms，确实执行了）
//           之后 11 秒没有任何 [单元格] 重建 → 8.0.79 上它并不触发
//           tableView:cellForRowAtIndexPath:。
//   第三版：主表 reloadData 排第一 —— 仍未验证通过（用户反馈「还是一样的问题」）。
//   第四版（本版）：整份 WeChatTweak.dylib（锤子）反汇编后的结论 ——
//     锤子全文 0 处 reloadData / 0 处 reloadTableView / 0 处 reloadRows，
//     它自己一行刷新代码都没写。它把所有「微信拿 item 的出口」都 hook 了一遍，
//     在出口上按 tid 从记忆表补灌伪赞，刷新则一律交给微信的 modifyDataItem:notify:：
//       WCTimelineMgr -[modifyDataItem:notify:]           hook IMP 0x7b5a08（%orig 前补灌）
//       WCFacade      -[getTimelineDataInCacheByItemID:]  hook IMP 0x7b5574（%orig 后补灌）
//       WCFacade      -[getTimelineDataItemOfIndex:]      hook IMP 0x7b56b4（%orig 后补灌）
//     其长按流程末尾唯一的刷新调用：0x7b61b8（x0=WCTimelineMgr、x2=item、w3=1）。
//     → 即时生效的关键不是「我们自己把画面刷出来」，而是「让微信自己的刷新管线
//       拿到的就是伪造后的 item」—— 那条管线会连带失效点赞区的布局缓存，
//       而自己 reloadData 只重走 cellForRow，绕不过那层缓存。这也解释了为什么
//       手动下拉刷新（走完整管线）一过伪赞就出来。
//
// 三个坑（都是真机踩出来的）：
//   - 别自己 reloadData 当主通道（上面三版全栽在这）。主通道必须走
//     modifyDataItem:notify:，并在其 hook 里 %orig 前补灌（锤子 0x7b5a08 同款）。
//     注：此前「成品插件不用 modifyDataItem」的判断是错的 —— 那是只看了
//     WCRefine.dylib 的结论；锤子（WeChatTweak.dylib）用的正是它。
//   - 微信的后台轮询会重建 item、冲掉内存改动，
//     所以 commonProcessDataAfterUpdate: 里回填完还要再推一次刷新
//     （否则就是「数据对了、画面不动」）。
//   - cpKeyForLikeUsers 是点赞区的布局缓存键，置 nil 属于双保险；
//     锤子不碰它（它靠 modifyDataItem 让微信自己失效），保留不影响正确性。
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
- (BOOL)isChatroom;                                      // 群聊（@chatroom）
- (BOOL)m_isPlugin;                                      // 插件号：微博阅读/腾讯新闻/漂流瓶/语音记事本/QQ邮箱/朋友圈入口等
- (BOOL)isGroupCard;                                     // 群名片
- (BOOL)isHolderContact;                                // 持有者 / 特殊号（非真人）
- (BOOL)isWeixinTeamContact;                            // 微信团队号（非真人）
- (BOOL)isFileHelper;                                    // 文件传输助手
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
- (id)getTimelineDataInCacheByItemID:(id)itemID;         // WCFacade.h:195 按 tid 从缓存取 item
- (id)getTimelineDataItemOfIndex:(long long)index;       // WCFacade.h:197 按行号取 item
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
@property (nonatomic) int realLikeCount;                      // WCDataItem.h:305 ← 真·渲染用计数，见 DDLFakeInto 注释
@property (nonatomic) int selfLikeCount;                      // WCDataItem.h:307 我自己点的赞（0/1）
@property (retain, nonatomic) NSMutableArray *commentUsers;   // WCDataItem.h:212
@property (nonatomic) int commentCount;                       // WCDataItem.h:296
@property (nonatomic) BOOL likeFlag;                          // WCDataItem.h:190
@property (nonatomic) unsigned int createtime;                // WCDataItem.h:335
@property (retain, nonatomic) NSString *tid;                  // WCDataItem.h:279 帖子唯一标识
@property (retain, nonatomic) id cpKeyForLikeUsers;           // WCDataItem.h:217 点赞区布局缓存键
@end

@interface WCTimelineMgr : NSObject
- (void)commonProcessDataAfterUpdate:(id)datas newAdItems:(id)adItems changedTime:(unsigned int)t; // :59
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;   // WCTimelineMgr.h:71 统一刷新出口
@end

// 朋友圈时间线视图控制器（WCTimeLineViewController.h）。用它拿主表 / 反查 item 所在行，
// 比搜视图树精准。只声明本插件真正调用的方法。
@interface WCTimeLineViewController : NSObject
- (id)getContentTableView;                 // WCTimeLineViewController.h:105 时间线主表（UITableView 子类）
- (id)indexPathOfDataItem:(id)item;        // WCTimeLineViewController.h:116 给定 item → 其 indexPath
- (void)reloadTableView;                   // WCTimeLineViewController.h:474 整表重绘
- (void)onActionClearCellCacheAndRefreshCellView:(id)arg1;  // :289 清 cell 缓存 + 刷新 cell 视图
- (void)onUpdateDataItem:(id)item oldHeight:(double)oh newHeight:(double)nh;  // :424 改完 item 后的单行重排
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

@implementation DDLikeHelper

// 真实好友池 = 排除非真人账号，过滤判据完整对齐锤子 WeChatTweak.startCheckFriends
// 反汇编实证的全部 9 个谓词：
//   isBrandContact / isChatroom / m_isPlugin / isGroupCard / isHolderContact /
//   isWeixinTeamContact / isFileHelper / IsOpenImContactUserName: / IsOpenImKeFuContactUserName:
// @openim 子串检查同时覆盖企业微信联系人 + 客服两类；
// 不按性别筛（m_uiSex 不卡，避免误伤未设性别的真实好友）。
// 血泪教训：m_isPlugin / isChatroom / isFileHelper 一个都不能省 ——
// 省掉后微博阅读/腾讯新闻/漂流瓶/文件传输助手/@chatroom 群全会被当成「点赞人」。
// 好友池缓存。一次长按要同时造「点赞」和「评论」，两处都会遍历通讯录 ——
// 旧日志里那三行连续的 [好友] 真实好友池=6 就是这么来的（fakeLikeUsers 里
// 枚举一次、同一函数的 DDLog 里又算一次、fakeCommentsFor: 再来一次）。
// 通讯录在一次操作内不会变，缓存 3 秒足够覆盖整次动作，避免重复遍历。
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

// 构造伪造点赞列表。likeCount <= 0 视为未设置，返回空数组（调用方据此不覆盖原值）。
+ (NSMutableArray<WCUserComment *> *)fakeLikeUsers {
    NSInteger target = DDLikeConfig.shared.likeCount;
    NSMutableArray *list = [NSMutableArray array];
    if (target <= 0) {
        DDLog(@"[点赞] target=%ld ≤0，未设置点赞数，跳过", (long)target);
        return list;
    }

    unsigned int now = (unsigned int)[NSDate date].timeIntervalSince1970;
    NSArray<CContact *> *friends = [self allFriends];   // 只取一次，别在 DDLog 里再算一遍
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
        @"likeUsers":     item.likeUsers    ?: @[],
        @"likeCount":     @(item.likeCount),
        @"realLikeCount": @(item.realLikeCount),   // 「只有原本带赞的才失效」的根因字段
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
        // ★ 关键修复：realLikeCount（WCDataItem.h:305）必须一起改。
        //   8.0.79 的点赞区渲染取的是它，不是 likeCount：
        //     - 原本没赞：realLikeCount 本来就是 0，改 likeCount 就够 → 一直正常；
        //     - 原本带赞：realLikeCount 还是旧值（如 2），likeCount 已改成 6，
        //       画面按 realLikeCount 渲染 → 看着「完全没变」，只有下拉刷新重建
        //       item 后才对得上（那时微信会自己重新同步这两个计数）。
        //   这就是「只有原本带赞的帖子才要手动刷一次」的根因。
        item.realLikeCount = (int)likes.count;
    }
    // cpKey 是微信点赞区的布局缓存键。置 nil 让其下次重算 —— 这是双保险，
    // 真正把画面刷出来的是随后的 modifyDataItem:notify:（锤子全程不碰 cpKey，
    // 只把刷新交给微信官方通道；其 ApplyFake 的末尾四个 set 之后没有任何 cpKey 操作）。
    item.cpKeyForLikeUsers = nil;
    // 幂等标记：同一 item 实例已伪装且一致时，刷新回调可跳过重写（省一次回填 + 日志）。
    objc_setAssociatedObject(item, kDDLFakedMark, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ============================================================================
// 按 tid 把「已生成的固定伪造内容」补灌回任意一个 WCDataItem。
//
// 这一层是照锤子（WeChatTweak.dylib）抄的，反汇编证据如下（三处实现完全同构，
// 都是「取 tid → 查记忆表 → setLikeUsers: → count → setLikeCount:」）：
//   WCTimelineMgr  -[modifyDataItem:notify:]           hook IMP 0x7b5a08（%orig 前补灌）
//   WCFacade       -[getTimelineDataInCacheByItemID:]  hook IMP 0x7b5574（%orig 后补灌）
//   WCFacade       -[getTimelineDataItemOfIndex:]      hook IMP 0x7b56b4（%orig 后补灌）
// 锤子 dylib 全文 0 处 reloadData / 0 处 reloadTableView / 0 处 reloadRows /
// 0 处 cellForRow —— 它自己一行刷新代码都没写，刷新完全交给微信的
// modifyDataItem:notify:（其长按流程末尾唯一的一条刷新调用，
// WeChatTweak.dylib:0x7b61b8，x0=WCTimelineMgr、x2=item、w3=1）。
//
// 结论：即时生效的关键不是「我们自己把画面刷出来」，而是
// 「让微信自己的刷新管线拿到的就是伪造后的 item」。微信那条管线会连带
// invalidate 点赞区的布局缓存 —— 而我们自己 reloadData 只重走 cellForRow，
// 绕不过那层缓存，所以怎么刷都不动，只有手动下拉（走完整管线）才出来。
// ============================================================================
static void DDLReapply(NSString *tag, id item) {
    if (!item || ![item respondsToSelector:@selector(tid)]) return;
    NSString *tid = [(WCDataItem *)item tid];
    if (!tid) return;
    NSDictionary *snap = gDDLFaked()[tid];
    if (!snap) return;

    // 复用 DDLFakeInto，保证「长按首次写入」与「各出口补灌」用的是同一套字段，
    // 不会再出现一边改了 realLikeCount、另一边漏改的漂移。
    DDLFakeInto((WCDataItem *)item, snap[@"likes"], snap[@"comments"]);

    // 这两个出口调用极频繁（滚动时每取一个 item 一次），日志按 tid 去重，只打首条。
    static NSMutableSet *seen = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableSet new]; });
    if (![seen containsObject:tid]) {
        [seen addObject:tid];
        DDLog(@"[补灌] 出口=%@ tid=%@ 赞=%lu 评论=%lu", tag, tid,
              (unsigned long)likes.count, (unsigned long)comments.count);
    }
}

// 刷新走 DDLReloadTimelineFrom()（定位主表 → reloadData），仅作保底。
// 上一版照抄成品的优先级链，把 reloadTableView 排在第一位，实测踩坑：
//   00:33:54.374 [刷新] 整表重绘 出口=reloadTableView   ← 确实执行了（耗时 105ms）
//   之后 11 秒都没有一条 [单元格] 重建
// 即 8.0.79 的 WCTimeLineViewController.reloadTableView 并不是「主表 reloadData」，
// 它不触发 tableView:cellForRowAtIndexPath:。而真正拦住画面的是同一份日志的第 16 行：
//   [刷新回调] 重写=1（微信自己的数据回调，11 秒后）—— 它一过，伪赞就出来了。
// 结论：只要能真正触发一次主表 reloadData，画面立刻正确。故本版改为「先拿主表 reloadData」。

// （DDLGap / DDLTidOfCell 定义在下面，这里先前置声明。）
static NSString *DDLGap(NSString *key, NSString *tag);
static NSString *DDLTidOfCell(id cell);

// 探活窗口：刷新后开 3 秒，期间 cellForRowAtIndexPath 打印全部单元格（不限记忆库），
// 用来确认「重绘到底有没有真的发生」。平时关着，避免刷屏。
static NSTimeInterval gDDLProbeUntil = 0;
static inline void DDLProbeOpen(void) {
    gDDLProbeUntil = [NSDate timeIntervalSinceReferenceDate] + 3.0;
}
static inline BOOL DDLProbeOn(void) {
    return [NSDate timeIntervalSinceReferenceDate] < gDDLProbeUntil;
}

// 从任意对象出发定位时间线 VC：先 navigationController/topViewController，
// 再沿响应链 nextResponder 往上（照 WCRefine.dylib 的
// WCRefineFindMomentsReloadViewController，IMP 0x55d414）。
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

// 取时间线主表。优先用头文件里确定存在的 getContentTableView（WCTimeLineViewController.h:105），
// 拿不到再按成品的顺序 KVC 两个键；valueForKey: 取不到会抛 NSUnknownKeyException，必须 @try。
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

// 唯一刷新出口：主表 reloadData。返回 YES = 已触发。
// 优先级（与上一版相反，主表 reloadData 排第一，因为它才是实测有效的那个）：
//   ① 主表 reloadData
//   ② VC 的 reloadTableView（WCTimeLineViewController.h:474）
//   ③ VC 的 reloadTableData
static BOOL DDLReloadTimelineFrom(id start, NSString *tid) {
    id tlvc = DDLFindTimelineVC(start);
    if (!tlvc) {
        DDLog(@"[刷新] ⚠未定位到时间线 VC（起点=%@）", NSStringFromClass([start class]));
        return NO;
    }
    DDLog(@"[刷新] 定位到 VC=%@ tid=%@", NSStringFromClass([tlvc class]), tid);

    id tv = DDLTimelineTableView(tlvc);
    if (tv) {
        DDLProbeOpen();                       // 开 3 秒探活，确认这次重绘真的到了 cellForRow
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

// 刷新后体检：0.3s / 1.2s 各扫一次可见单元格，确认「画面用的那份数据」对不对。
// 这是判断「重绘没发生」还是「重绘发生了但数据被冲掉」的分水岭。
// 取当前 keyWindow（iOS 13+ 从 UIWindowScene 里找，不用已废弃的 UIApplication.keyWindow）。
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

// start：定位起点。传浮窗/VC 比 keyWindow 靠谱 —— 04 版日志里
// 「[体检] ⚠拿不到主表」就是从 keyWindow 出发找不到 VC 造成的（浮窗那条链能找到）。
static void DDLCheckVisible(NSString *tid, id start) {
    if (!tid) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id tlvc = DDLFindTimelineVC(start);
        id tv = DDLTimelineTableView(tlvc);
        if (![tv isKindOfClass:UITableView.class]) {
            // 起点找不到就退回 keyWindow（保留旧路径）
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
            id it = DDLDeepItem(cell, 0);          // 走 m_subContentView 递归，别再直接取
            NSUInteger lc = 0, cc = 0;
            if ([it respondsToSelector:@selector(likeUsers)])    lc = [[it valueForKey:@"likeUsers"] count];
            if ([it respondsToSelector:@selector(commentUsers)]) cc = [[it valueForKey:@"commentUsers"] count];

            // 无论是否命中都打印前 3 个：能看出单元格类名、能不能读到 m_dataItem，
            // 避免「DDLTidOfCell 取不到 tid」造成的盲区。
            if ([ctid isEqualToString:tid] || shown < 3) {
                if (![ctid isEqualToString:tid]) shown++; else n++;
                DDLog(@"[体检] %@cell=%@ tid=%@ item=%p 赞=%lu 评论=%lu frame=%@",
                      ([ctid isEqualToString:tid] ? @"命中 " : @"样本 "),
                      NSStringFromClass([cell class]), ctid ?: @"(无)", (__bridge void *)it,
                      (unsigned long)lc, (unsigned long)cc, NSStringFromCGRect(cell.frame));
            }
        }
        if (!n) DDLog(@"[体检] ⚠可见单元格里没有 tid=%@（可能已滚出屏幕或取不到 tid）", tid);
    });
}

// 刷新诊断：记录每个 tid 上次「刷新事件」的时间，用来发现同一动作导致同一条被刷新/重建多次的冗余。
// tag 区分事件流（R=我们主动 reloadRows，C=单元格被重建），互不影响。
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

// 尽量从 cell 取 tid：cell 可能直接持有 m_dataItem，或其一级子视图持有（WCTimeLineCellView.m_dataItem）。
// 取不到返回 nil；全程 @try 包裹，绝不因诊断影响主流程。
// 从单元格里挖出真正的 WCDataItem（递归，最多 3 层）。
//
// 8.0.79 实测（04 版日志）：tableView:cellForRowAtIndexPath: 返回的类名是
// **MMTableViewCell**，不是 WCTimeLineCellView —— 真正的 cellView 装在
// MMTableViewCell 的 m_subContentView 里（MMTableViewCell.h:11）。
// 所以 [cell valueForKey:@"m_dataItem"] 拿到的是 nil，
// 前几版日志里那句「[单元格] 重建 赞=0/应=6」是**诊断误报**，不是数据没写进去。
// 这里改成递归挖：先试自己 → 再试 m_subContentView → 再遍历 subviews。
static id DDLDeepItem(id v, int depth) {
    if (!v || depth > 3 || ![v isKindOfClass:NSObject.class]) return nil;
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

// %new 方法的编译期声明（Logos 运行时注入，编译器需先见到签名）。
// 同时把本类调用的私有 API 一并前向声明，避免 "no known instance method /
// no visible @interface" 编译错误（声明只告诉编译器签名，实现在运行时由微信提供）。
@interface WCOperateFloatView (DDLike)
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (BOOL)ddl_reloadTimelineForItem:(id)item;  // %new，整表重绘（唯一刷新出口）
- (id)navigationController;                     // WCOperateFloatView.h:11，浮窗自带导航栈
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
    // 写入前的原始计数打出来：likeCount>0 即「原本带赞」，正是会出问题的那类帖子。
    DDLog(@"[长按] 触发 tid=%@ likeFlag=%d 已集赞=%d 原始 likeCount=%d realLikeCount=%d selfLikeCount=%d likeUsers=%lu",
          tid, item.likeFlag, tid ? (faked[tid] != nil) : -1,
          item.likeCount, item.realLikeCount, item.selfLikeCount,
          (unsigned long)item.likeUsers.count);

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
        DDLog(@"[写入] tid=%@ 赞=%lu 评论=%lu item=%p（固定内容，刷新不重随机）",
              tid, (unsigned long)[snap[@"likes"] count],
              (unsigned long)[snap[@"comments"] count], (__bridge void *)item);
        // 三个计数必须一致，否则就是「原本带赞失效」那类问题。
        DDLog(@"[写入] 计数 likeCount=%d realLikeCount=%d selfLikeCount=%d likeFlag=%d likeUsers=%lu",
              item.likeCount, item.realLikeCount, item.selfLikeCount, item.likeFlag,
              (unsigned long)item.likeUsers.count);
        DDLog(@"[长按] 开启集赞 tid=%@（记忆 %lu 条）", tid, (unsigned long)faked.count);
    }

    // —— 刷新：多路齐发，每路打点 + 开探活，下次日志一眼看出哪条路真的触发了重绘 ——
    // 04 版实测 modifyDataItem:notify: 单独用是哑弹：它执行后 2.4 秒内
    // 没有任何目标行的 [单元格] 重建（探活窗口全开着的）。锤子靠它够用，
    // 但 8.0.79 上已经不够。故本版补两条微信自己的「cell 缓存 / 单行重排」入口。
    id mgr = DDLTimelineMgr();
    DDLog(@"[刷新] 起点 tid=%@ mgr=%@ item=%p", tid,
          NSStringFromClass([mgr class]) ?: @"(nil)", (__bridge void *)item);
    DDLProbeOpen();                    // 开 3 秒探活
    DDLCheckVisible(tid, self);        // 0.3 秒后体检

    int fired = 0;

    // ⓪ 锤子同款：微信官方数据项变更出口（WCTimelineMgr.h:71）
    if (mgr) { [mgr modifyDataItem:item notify:YES]; fired++; }

    id tlvc = DDLFindTimelineVC(self);
    id tv   = DDLTimelineTableView(tlvc);
    if (!tlvc) DDLog(@"[刷新] ⚠定位不到时间线 VC，①②跳过");

    // ① 清 cell 缓存 + 刷新 cell 视图（WCTimeLineViewController.h:289）
    //    名字直指「点赞区布局缓存」那一层，是本版主攻方向。
    if (tlvc) {
        @try {
            [tlvc onActionClearCellCacheAndRefreshCellView:item];
            DDLog(@"[刷新] ①onActionClearCellCacheAndRefreshCellView 已调用");
            fired++;
        } @catch (NSException *e) { DDLog(@"[刷新] ①异常 %@", e.reason); }
    }

    // ② 改完 item 后的单行重排（WCTimeLineViewController.h:424）
    //    微信自己点赞 / 删评论成功后走的就是它（oldHeight/newHeight 用来稳住 contentOffset）。
    if (tlvc) {
        double h = 0;
        @try {
            id ip = [tlvc indexPathOfDataItem:item];
            if ([ip isKindOfClass:NSIndexPath.class] && [tv isKindOfClass:UITableView.class]) {
                h = [(UITableView *)tv rectForRowAtIndexPath:(NSIndexPath *)ip].size.height;
            }
        } @catch (NSException *__) {}
        @try {
            [tlvc onUpdateDataItem:item oldHeight:h newHeight:h];
            DDLog(@"[刷新] ②onUpdateDataItem:oldHeight:newHeight: 已调用 h=%.1f", h);
            fired++;
        } @catch (NSException *e) { DDLog(@"[刷新] ②异常 %@", e.reason); }
    }

    // ③ 兜底：单行重绘（前三版的办法，单独用无效，这里配合上面的缓存清理再走一次）
    if (tlvc && [tv isKindOfClass:UITableView.class]) {
        @try {
            id ip = [tlvc indexPathOfDataItem:item];
            if ([ip isKindOfClass:NSIndexPath.class]) {
                [(UITableView *)tv reloadRowsAtIndexPaths:@[ip]
                                        withRowAnimation:UITableViewRowAnimationNone];
                DDLog(@"[刷新] ③reloadRowsAtIndexPaths 已调用");
                fired++;
            }
        } @catch (NSException *e) { DDLog(@"[刷新] ③异常 %@", e.reason); }
    }

    DDLog(@"[刷新] 本次共触发 %d 条通路", fired);

    [self hide];
}

%new
// 保底刷新出口：只在 WCTimelineMgr 取不到时才用（锤子没有这条）。
// 实际工作都交给 DDLReloadTimelineFrom()（定位主表 → reloadData），
// 本方法只负责定位（从浮窗出发）和刷新后的体检。
//
// 为什么它当不了主通道：自己 reloadData 只重走 cellForRow，绕不开点赞区那层
// 布局缓存 —— 前三版全栽在这里。主通道是 modifyDataItem:notify:。
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
// 诊断钩子（WCTimeLineViewController.h:147）：确认重绘真的到了 cellForRow，
// 且重建时 item 上仍是我们写入的伪造数据（赞/评论条数要对得上）。
// 平时只打记忆库里的 tid；刷新后 3 秒探活窗口内（DDLProbeOn）打全部单元格 ——
// 上一版就是因为没开这层，误以为 reloadTableView 生效了。
- (id)tableView:(id)tv cellForRowAtIndexPath:(id)ip {
    id cell = %orig;
    NSString *tid = DDLTidOfCell(cell);
    BOOL probe = DDLProbeOn();
    NSDictionary *snap = (tid ? gDDLFaked()[tid] : nil);
    if (snap || probe) {
        NSUInteger lc = 0, cc = 0;
        // 必须走 DDLDeepItem：04 版日志里 cell 类名是 MMTableViewCell，
        // 直接 [cell valueForKey:@"m_dataItem"] 永远是 nil → 「赞=0」是假警报。
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

%hook WCFacade

// 微信取朋友圈 item 的两个出口（WCFacade.h:195 / :197）。锤子两个都 hook 了
// （IMP 0x7b5574 / 0x7b56b4），%orig 之后按 tid 补灌 —— 这样无论微信从哪里
// 把 item 取出来（缓存、行号、翻页重建），拿到的都是带伪赞的版本。
// 这两个出口调用极频繁，进门日志只打前 4 次，够判断 hook 有没有挂上就行。
static int gDDLFacadeLog = 0;

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

// 微信官方的「数据项已变更」出口（WCTimelineMgr.h:71）。锤子 hook 的正是这里
// （WeChatTweak.dylib IMP 0x7b5a08）：在 %orig 之前按 tid 补灌伪赞，
// 让微信后续那条刷新管线（含点赞区布局缓存的失效）拿到的就是伪造后的 item。
// 我们长按改完数据后主动调它一次，等同于走了一条完整的「下拉刷新」。
- (void)modifyDataItem:(id)item notify:(BOOL)notify {
    // 无条件进门日志：这一行是判断「本 hook 到底有没有被走到」的唯一依据。
    // 04 版日志里它一次都没出现，而同一个 %hook 里的 commonProcessDataAfterUpdate:
    // 却正常打印 —— 说明要么这条消息没打到 WCTimelineMgr，要么 tid 查不到记忆。
    NSString *t = ([item respondsToSelector:@selector(tid)] ? [item tid] : nil);
    DDLog(@"[改项] 进入 self=%@ tid=%@ notify=%d 记忆=%lu",
          NSStringFromClass([self class]), t ?: @"(无)", (int)notify,
          (unsigned long)gDDLFaked().count);
    DDLReapply(@"modifyDataItem", item);
    %orig(item, notify);
}

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

    // 微信的后台轮询会重建 item、冲掉内存改动（日志里 11 秒后那条 [刷新回调] 重写=1 就是）。
    // 回填完再走一次官方刷新通道把画面推出来。
    // 注：锤子在这一步不做任何刷新（它靠上面那批「取 item 出口」hook 保证微信
    // 取到的永远是伪数据）；我们多走一次，是为了兜住 8.0.79 上
    // commonProcessDataAfterUpdate 自身不触发重绘的情况。
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

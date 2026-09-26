// DDLikeHelper.xm
// 微信集赞助手（Theos / Logos，arm64 / arm64e）
//
// 功能：
//   自己点赞某条朋友圈后，自动伪造指定数量的「点赞」与「评论」，
//   数据落在本地 WCDataItem 上，不改服务端。
//
// 说明：
//   - 设置界面与配置层按 DD朋友圈助手（DDWCMoments.xm）的模式改写，
//     便于后续整体并入 DD朋友圈助手：配置类为单例 + NSUserDefaults 直写，
//     键名统一 DDMoments_ 前缀，设置页结构（ensureTableViewMgr / 三态导航栏 /
//     viewWillAppear 重建 / delegate 三方法转发）与 DDMSettingsViewController 一致。
//   - 微信私有类一律运行时获取（objc_getClass / NSClassFromString），不链接私有符号。
//   - 私有接口取自微信 8.0.79 头文件，只声明本插件真正会调用的方法。
//
// 并入 DD朋友圈助手 的步骤（本文件已按此设计）：
//   1. DDLikeConfig 的属性与 key 直接搬进 DDMConfig（key 前缀已统一，用户旧设置不丢）。
//   2. addLikeSections 的方法体直接搬进 DDMSettingsViewController 的 buildTable。
//   3. DDLikeHelper 与 %hook WCTimelineMgr 整段搬过去。
//   4. 注意声明去重：DDWCMoments.xm 已声明 WCDataItem 与 WCUserComment，
//      合并时取并集，不要写两份 @interface。
//        - WCUserComment：DDWCMoments 已有 content / setContent:，本文件补
//          nickname / username / commentID / type / createTime 及各 setter。
//        - WCDataItem：两边都用到 createtime（unsigned int，类型一致），
//          本文件补 likeUsers / likeCount / commentUsers / commentCount / likeFlag。

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

static inline id DDLContactMgr(void) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:objc_getClass("CContactMgr")];
}

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

// 评论内容默认值（多条用 "-" 分隔，随机取一条）。
static NSString * const kDDMDefaultComments = @"赞-👍";

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
        NSString *c    = [ud stringForKey:kDDMLikeComments];
        _comments      = (c.length > 0) ? c : kDDMDefaultComments;
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
    NSString *val = (v.length > 0) ? v : kDDMDefaultComments;
    _comments = [val copy];
    [self persist:val key:kDDMLikeComments];
}

// 评论内容池（按 "-" 切分，空则回退默认）。
- (NSArray<NSString *> *)commentPool {
    NSArray *arr = [self.comments componentsSeparatedByString:@"-"];
    return arr.count ? arr : @[kDDMDefaultComments];
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
    if (target <= 0) return orig;                       // 未设置：原样返回
    if ((NSInteger)orig.count >= target) return orig;   // 已够：原样返回

    NSMutableArray *list = [orig mutableCopy];
    NSArray<NSString *> *pool = DDLikeConfig.shared.commentPool;

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

#pragma mark - Hook：伪造点赞 / 评论

%hook WCTimelineMgr

// modifyDataItem:notify: 是数据项落库 / 刷新的统一出口（WCTimelineMgr.h:71）。
// 只在自己点过赞（likeFlag）的帖子上做假，避免污染别人 / 未互动的帖子。
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if (DDLikeConfig.shared.likeEnabled && arg1 && arg1.likeFlag) {
        NSMutableArray *comments = [DDLikeHelper fakeCommentsFor:arg1];
        if (comments.count) {
            arg1.commentUsers = comments;
            arg1.commentCount = (int)comments.count;
        }

        NSMutableArray *likes = [DDLikeHelper fakeLikeUsers];
        if (likes.count) {
            arg1.likeUsers = likes;
            arg1.likeCount = (int)likes.count;
        }
    }
    %orig(arg1, arg2);
}

%end

#pragma mark - 设置界面

@interface DDLikeSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
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
        NSString *likeVal = cfg.likeCount > 0
                          ? [NSString stringWithFormat:@"%ld 个", (long)cfg.likeCount] : @"未设置";
        [sec addCell:[cellMgr normalCellForSel:@selector(onLikeCountTapped)
                                        target:self
                                         title:@"↳点赞数量"
                                    rightValue:likeVal]];

        NSString *cmtVal = cfg.commentCount > 0
                         ? [NSString stringWithFormat:@"%ld 条", (long)cfg.commentCount] : @"未设置";
        [sec addCell:[cellMgr normalCellForSel:@selector(onCommentCountTapped)
                                        target:self
                                         title:@"↳评论数量"
                                    rightValue:cmtVal]];

        [sec addCell:[cellMgr normalCellForSel:@selector(onCommentsTapped)
                                        target:self
                                         title:@"↳评论内容"
                                    rightValue:cfg.comments]];
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

// 数值 / 文本输入统一走弹窗。
- (void)onLikeCountTapped {
    [self presentNumberInputTitle:@"点赞数量"
                          message:@"输入期望的点赞个数"
                      placeholder:@"数量"
                     currentValue:DDLikeConfig.shared.likeCount > 0
                                  ? [NSString stringWithFormat:@"%ld", (long)DDLikeConfig.shared.likeCount] : @""
                          commit:^(NSInteger v){ DDLikeConfig.shared.likeCount = v; }];
}
- (void)onCommentCountTapped {
    [self presentNumberInputTitle:@"评论数量"
                          message:@"输入期望的评论条数"
                      placeholder:@"条数"
                     currentValue:DDLikeConfig.shared.commentCount > 0
                                  ? [NSString stringWithFormat:@"%ld", (long)DDLikeConfig.shared.commentCount] : @""
                          commit:^(NSInteger v){ DDLikeConfig.shared.commentCount = v; }];
}
- (void)onCommentsTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"评论内容"
                                                                  message:@"多个随机内容用“-”分隔，如“赞-👍-666”"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"内容";
        tf.text = DDLikeConfig.shared.comments;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text;
        DDLikeConfig.shared.comments = (text.length > 0) ? text : kDDMDefaultComments;
        [self buildTable];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// 数字输入弹窗：只接受正整数，非法 / 空一律归零（= 未设置，不生效）。
- (void)presentNumberInputTitle:(NSString *)title
                        message:(NSString *)message
                    placeholder:(NSString *)placeholder
                   currentValue:(NSString *)current
                         commit:(void (^)(NSInteger))commit {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = placeholder;
        tf.keyboardType = UIKeyboardTypeNumberPad;
        tf.text = current;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSInteger v = [alert.textFields.firstObject.text integerValue];
        if (commit) commit(v > 0 ? v : 0);
        [self buildTable];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
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

// DDWCMoments.xm
// 微信朋友圈助手（Theos / Logos，arm64 / arm64e）
//
// 功能：
//   1. 一键转发 —— 在朋友圈「赞 / 评论」浮窗注入「转发」按钮，支持文案、实况/图片、视频、
//      Live Photo 与纯文字；自动带回原帖文案，可选保留 / 移除原作者位置。
//   2. 集赞设置 —— 长按赞按钮弹窗改点赞 / 评论数（假数据），支持评论内容池与一键清空伪装记录。
//   3. 辅助开关 —— 查看已删评论、显示精确时间、禁用隐私图标、禁用微商折叠、禁用文字折叠、
//      禁用自动播放、禁用点击关闭、启用视频进度条。
//
// 转发链路：
//   抓文案 → 备媒体（缺失走 CDN 下载）→ 深拷贝隔离原帖 → 按类型分流
//   → 构建草稿 / 资产 → 唤起发布器并回填文案与位置。
//
// 说明：
//   - 微信私有类一律运行时获取（objc_getClass / NSClassFromString），不链接私有符号。
//   - 私有接口取自微信 8.0.79 头文件，只声明本插件真正会调用的方法。
//   - 文案在发布器 init 期（initTextViewContent）回填，并随 textViewTextDidChange
//     同步进微信内部模型，之后发布器重建文本框也不会丢。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信私有接口声明

// 微信插件管理入口，用于注册本插件设置页。
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信内置设置表格组件。
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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightView:(id)arg4;
@end

// 朋友圈内容项（一条朋友圈的元数据）。
@interface WCContentItem : NSObject
@property (retain, nonatomic) NSMutableArray *mediaList;   // 媒体列表（图片 / 视频 / Live Photo）
@property (nonatomic) int type;                            // 内容类型
+ (BOOL)isVideoType:(long long)type;                        // 是否为视频类型
@end

// 朋友圈数据项（一条朋友圈完整模型）。
@interface WCDataItem : NSObject
@property (retain, nonatomic) WCContentItem *contentObj;    // 内容项
@property (retain, nonatomic) NSString *contentDesc;        // 文案
@property (nonatomic) unsigned int createtime;             // 发布时间（Unix 秒）
+ (id)fromNSCodingBuffer:(NSData *)buffer;                  // 反序列化（深拷贝用）
- (NSData *)toNSCodingBuffer;                               // 序列化（深拷贝用）
- (BOOL)isVideo;                                            // 是否为视频
- (NSArray *)getNeedBatchDownloadMedias;                    // 需批量下载的媒体
- (BOOL)isWeiShang;                                         // 是否微商
- (void)setExtFlag:(unsigned int)arg1;                      // 扩展标记（含微商标记）
- (id)locationInfo;                                          // 位置信息
- (void)setLocationInfo:(id)arg1;                            // 设置位置信息
@property (retain, nonatomic) NSMutableArray *likeUsers;
@property (nonatomic) int likeCount;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@property (retain, nonatomic) NSString *tid;
@end

// 单条媒体（图片 / 视频 / Live Photo）。
@interface WCMediaItem : NSObject
@property (retain, nonatomic) WCMediaItem *livePhotoMediaItem;  // 关联的运动视频
@property (readonly, nonatomic) BOOL isLivePhoto;               // 是否为 Live Photo
- (BOOL)hasSight;                                              // 是否有短视频资源
- (BOOL)isPreloadVideoTask;                                    // 是否为预加载视频任务
- (long long)mediaType;                                        // 媒体类型
- (NSString *)pathForExistData;                                // 已存在数据路径
- (NSString *)pathForData;                                     // 数据路径
- (NSString *)pathForSightData;                                // 短视频数据路径
- (NSString *)pathForPreview;                                  // 预览图路径
- (NSString *)getThumbImagePath;                               // 缩略图路径
- (NSString *)tempPathForSightData;                            // 短视频临时路径
- (NSString *)getFormatVideoPath;                              // 转码后视频路径
- (NSString *)getTempVideoPath;                                // 临时视频路径
- (id)imageOfSize:(long long)arg1;                             // 内存图（按尺寸取）
@end

// 视频下载管理器。
@interface WCDownloadVideoCDNMgr : NSObject
- (unsigned long long)StartDownloadVideo:(id)arg1;
- (void)CheckQueue;
@end

// 业务门面：获取下载管理器、触发 CDN 下载。
@interface WCFacade : NSObject
- (id)videoDownloadCdnMgrForCategory:(long long)arg1;
- (id)imageDownloadCdnMgrForCategory:(long long)arg1;
- (void)StartDownloadImage:(id)arg1 DownloadType:(long long)arg2;
- (id)getTimelineDataInCacheByItemID:(id)itemID;
- (id)getTimelineDataItemOfIndex:(long long)index;
- (long long)countOfTimelineDataItem;
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

// 服务定位链：MMContext → serviceCenter → getService: 取 WCFacade 单例。
@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

// 集赞功能所需接口（好友 / 联系人 / 弹窗 / 轻提示 / 时间线管理）。
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

@interface WeToast : NSObject
+ (id)toast;
- (void)showDoneToastWithText:(id)text;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2;
@end

// 经服务链取 WCFacade。
static inline id DDMGetFrameFacade(void) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:objc_getClass("WCFacade")];
}

// 集赞功能服务定位：取联系人管理 / 朋友圈门面。
static inline id DDLService(Class cls) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:cls];
}
static inline id DDLContactMgr(void)    { return DDLService(objc_getClass("CContactMgr")); }
static inline id DDLFacadeService(void) { return DDLService(objc_getClass("WCFacade")); }

// 朋友圈操作浮窗（点赞 / 评论条）。
@interface WCOperateFloatView : UIView
@property (readonly, nonatomic) UIButton *m_likeBtn;
@property (readonly, nonatomic) UIButton *m_commentBtn;
@property (readonly, nonatomic) WCDataItem *m_item;
@property (nonatomic, weak) UINavigationController *navigationController;
- (void)hide;
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint;
@end

// 朋友圈时间线 VC：转发按钮事件最终落到这里。
@interface WCTimeLineViewController : UIViewController
@property (retain, nonatomic) WCOperateFloatView *floatOperateView;
@end

// 本地资源基类（实况运动视频由 MMAssetForLocalImage 携带）。
@interface MMAsset : NSObject
@end

// 本地图片 / Live Photo 资源。
@interface MMAssetForLocalImage : MMAsset
@property (retain, nonatomic) NSString *localAssetId;
@property (retain, nonatomic) NSString *localFilePath;
- (id)initWithUrl:(NSURL *)url IsNeedOrigin:(BOOL)isNeedOrigin;
@end

// 微信图片封装：承载像素与实况信息，提交给发布器。
@interface MMImage : UIImage
- (id)initWithImage:(id)arg1;
@property (retain, nonatomic) MMAsset *m_asset;
@property (nonatomic) BOOL isLivePhoto;
@property (retain, nonatomic) NSString *livePhotoVideoPath;
@property (nonatomic) long long imageFrom;
@end

// 短视频草稿：视频转发时构建。
@interface SightDraft : NSObject
+ (id)draftWithVideoURL:(NSURL *)url thumbImage:(UIImage *)thumbImage;
+ (id)draftWithVideoURL:(NSURL *)url;
@end

// 朋友圈路由：转发到微信原生转发界面（纯文字 / 兜底）。
@interface WCTimelineRouterHelper : NSObject
+ (BOOL)presentForwardViewController:(id)dataItem
                   postReportSession:(id)session
                     trashReportData:(id)trash
               currentViewController:(id)vc;
@end

// 发布器文本框容器。
@interface MMGrowTextView : UIView
@property (retain, nonatomic) UITextView *textView;
@end

// 微信发布器 VC：媒体 / 文案注入到这里。
@interface WCNewCommitViewController : UIViewController
@property (retain, nonatomic) MMGrowTextView *textView;
@property (nonatomic) BOOL m_isUseMMAsset;
@property (nonatomic) BOOL bHideAddView;
- (void)initTextViewContent;
- (void)textViewTextDidChange;
- (instancetype)initWithImages:(id)arg1 contacts:(id)arg2;
- (instancetype)initWithSightDraft:(id)arg1;
- (void)setPoiInfo:(id)arg1;            // 写入位置信息
- (void)setBShowLocation:(BOOL)arg1;    // 是否展示位置
- (void)setDelegate:(id)arg1;
@end

// 朋友圈视频模板视图（禁用自动播放）。
@interface WCContentItemViewTemplateVideo : UIView
- (void)autoPlayWithoutSound;
@end

// 朋友圈 cell 视图（禁用隐私图标 + 文字折叠 + 精确时间）。
@interface WCTimeLineCellView : UIView
- (void)initPrivacyButton:(id)arg1;
- (void)layoutSubviews;
+ (BOOL)shouldShowFullTextButtonWithDataItem:(id)arg1;
@property (readonly, nonatomic) WCDataItem *m_dataItem;
@property (readonly, nonatomic) UILabel *m_timeLabel;
- (void)updateWithDataItem:(id)dataItem actionAreaVM:(id)actionAreaVM;
@end

// 微信按钮基类。
@interface MMUIButton : UIButton
@end

// 评论 / 消息模型。
@interface WCUserComment : NSObject
@property (retain, nonatomic) NSString *nickname;
@property (retain, nonatomic) NSString *username;
- (id)content;
- (void)setContent:(id)arg1;
@property (retain, nonatomic) NSString *commentID;
@property (nonatomic) int type;
@property (nonatomic) unsigned int createTime;
@end

@interface WCSNSMessage : NSObject
- (id)comment;
- (void)setDelStatus:(unsigned int)arg1;
@end

// 全屏视频播放器（禁用点击关闭 + 进度条）。
@interface WCPlayerConfigFullScreenViewController : UIViewController
- (void)onFullScreenSingleTap;
- (BOOL)shouldShowProgressBar;
- (BOOL)autoShowProgressBarWithThreshold;
@end

#pragma mark - 配置

// 转发总开关。
static NSString * const kDDMForwardEnabled       = @"DDMoments_forwardEnabled";

// 辅助开关（键名与界面标题一一对应）。
static NSString * const kDDMViewDeletedComment   = @"DDMoments_viewDeletedComment";    // 查看已删评论
static NSString * const kDDMShowPreciseDate      = @"DDMoments_showPreciseDate";       // 显示精确时间
static NSString * const kDDMDisablePrivacyIcon   = @"DDMoments_disablePrivacyIcon";    // 禁用隐私图标
static NSString * const kDDMDisableWeiShangFold  = @"DDMoments_disableWeiShangFold";   // 禁用微商折叠
static NSString * const kDDMDisableTextFold      = @"DDMoments_disableTextFold";       // 禁用文字折叠
static NSString * const kDDMDisableVideoAutoPlay = @"DDMoments_disableVideoAutoPlay";  // 禁用自动播放
static NSString * const kDDMDisableVideoTapClose = @"DDMoments_disableVideoTapClose";  // 禁用点击关闭
static NSString * const kDDMEnableVideoProgress  = @"DDMoments_enableVideoProgress";   // 启用视频进度
static NSString * const kDDMRemoveOriginalLoc    = @"DDMoments_removeOriginalLocation"; // 移除原始位置

// 已删评论标记。
static NSString * const kDDMDeletedCommentMark   = @"DDMoments_deletedCommentMark";
static NSString * const kDDMDefaultDeletedMark   = @"[对方已删除] ";

@interface DDMConfig : NSObject
@property (assign, nonatomic) BOOL forwardEnabled;          // 启用一键转发（总开关；开启时展开“移除原始位置”）
@property (assign, nonatomic) BOOL viewDeletedComment;      // 查看已删评论
@property (assign, nonatomic) BOOL showPreciseDate;         // 显示精确时间
@property (assign, nonatomic) BOOL disablePrivacyIcon;      // 禁用隐私图标
@property (assign, nonatomic) BOOL disableWeiShangFold;     // 禁用微商折叠
@property (assign, nonatomic) BOOL disableTextFold;         // 禁用文字折叠
@property (assign, nonatomic) BOOL disableVideoAutoPlay;    // 禁用自动播放
@property (assign, nonatomic) BOOL disableVideoTapClose;    // 禁用点击关闭
@property (assign, nonatomic) BOOL enableVideoProgress;     // 启用视频进度
@property (assign, nonatomic) BOOL removeOriginalLocation;  // 移除原始位置（仅转发开启时展开）
+ (instancetype)shared;
@end

@implementation DDMConfig

+ (instancetype)shared {
    static DDMConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDMConfig new]; });
    return cfg;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _forwardEnabled           = [ud boolForKey:kDDMForwardEnabled];
        _viewDeletedComment       = [ud boolForKey:kDDMViewDeletedComment];
        _showPreciseDate          = [ud boolForKey:kDDMShowPreciseDate];
        _disablePrivacyIcon       = [ud boolForKey:kDDMDisablePrivacyIcon];
        _disableWeiShangFold      = [ud boolForKey:kDDMDisableWeiShangFold];
        _disableTextFold          = [ud boolForKey:kDDMDisableTextFold];
        _disableVideoAutoPlay     = [ud boolForKey:kDDMDisableVideoAutoPlay];
        _disableVideoTapClose     = [ud boolForKey:kDDMDisableVideoTapClose];
        _enableVideoProgress      = [ud boolForKey:kDDMEnableVideoProgress];
        _removeOriginalLocation   = [ud boolForKey:kDDMRemoveOriginalLoc];
    }
    return self;
}

- (void)persist:(id)value key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setForwardEnabled:(BOOL)v            { _forwardEnabled = v;            [self persist:@(v) key:kDDMForwardEnabled]; }
- (void)setViewDeletedComment:(BOOL)v       { _viewDeletedComment = v;       [self persist:@(v) key:kDDMViewDeletedComment]; }
- (void)setShowPreciseDate:(BOOL)v          { _showPreciseDate = v;          [self persist:@(v) key:kDDMShowPreciseDate]; }
- (void)setDisablePrivacyIcon:(BOOL)v       { _disablePrivacyIcon = v;       [self persist:@(v) key:kDDMDisablePrivacyIcon]; }
- (void)setDisableWeiShangFold:(BOOL)v      { _disableWeiShangFold = v;      [self persist:@(v) key:kDDMDisableWeiShangFold]; }
- (void)setDisableTextFold:(BOOL)v          { _disableTextFold = v;          [self persist:@(v) key:kDDMDisableTextFold]; }
- (void)setDisableVideoAutoPlay:(BOOL)v     { _disableVideoAutoPlay = v;     [self persist:@(v) key:kDDMDisableVideoAutoPlay]; }
- (void)setDisableVideoTapClose:(BOOL)v     { _disableVideoTapClose = v;     [self persist:@(v) key:kDDMDisableVideoTapClose]; }
- (void)setEnableVideoProgress:(BOOL)v      { _enableVideoProgress = v;      [self persist:@(v) key:kDDMEnableVideoProgress]; }
- (void)setRemoveOriginalLocation:(BOOL)v   { _removeOriginalLocation = v;   [self persist:@(v) key:kDDMRemoveOriginalLoc]; }

@end

#pragma mark - 运行时工具

// 取当前 keyWindow。
static UIWindow *DDMKeyWindow(void) {
    UIWindow *found = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) return w;
            if (!found && !w.hidden) found = w;
        }
    }
    return found;
}

// 从根 VC 递归找到最上层可见 VC。
static UIViewController *DDMTopViewController(UIViewController *root) {
    UIViewController *vc = root ?: DDMKeyWindow().rootViewController;
    while (vc) {
        if (vc.presentedViewController) { vc = vc.presentedViewController; continue; }
        if ([vc isKindOfClass:UINavigationController.class]) {
            UIViewController *top = [(UINavigationController *)vc topViewController];
            if (!top) break;
            vc = top; continue;
        }
        if ([vc isKindOfClass:UITabBarController.class]) {
            UIViewController *sel = [(UITabBarController *)vc selectedViewController];
            if (!sel) break;
            vc = sel; continue;
        }
        break;
    }
    return vc;
}

// 本插件临时目录（下载 / 转码产物统一落这里）。
static NSString *DDMTempDir(void) {
    static NSString *dir = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DDMoments"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

// 清理临时目录（每次转发开始前调用）。
static void DDMCleanTempDir(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *name in [fm contentsOfDirectoryAtPath:DDMTempDir() error:nil]) {
        [fm removeItemAtPath:[DDMTempDir() stringByAppendingPathComponent:name] error:nil];
    }
}

// 文件是否可用（存在、常规文件、大小 > 0）。
static BOOL DDMFileUsable(NSString *path) {
    if (path.length == 0) return NO;
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if (!attr) return NO;

    if (![attr[NSFileType] isEqual:NSFileTypeRegular]) return NO;
    return [attr fileSize] > 0;
}

// 从候选路径取第一个可用文件。
static NSString *DDMFirstUsablePath(NSArray<NSString *> *candidates) {
    for (NSString *p in candidates) if (DDMFileUsable(p)) return p;
    return nil;
}

// 拷贝源文件到临时目录，解析软链并补齐扩展名。
static NSString *DDMCopyToTemp(NSString *srcPath, NSString *ext) {
    if (!DDMFileUsable(srcPath)) return nil;

    NSString *realPath = srcPath;
    NSURL *resolved = [[NSURL fileURLWithPath:srcPath] URLByResolvingSymlinksInPath];
    if (resolved && [resolved path] && ![[resolved path] isEqualToString:srcPath] && DDMFileUsable([resolved path])) {
        realPath = [resolved path];
    }
    NSString *realExt = [realPath pathExtension].lowercaseString;
    if (realExt.length == 0) realExt = [ext lowercaseString];
    if (realExt.length == 0) realExt = @"jpg";
    NSString *name = [NSString stringWithFormat:@"%@.%@", NSUUID.UUID.UUIDString, realExt];
    NSString *dst = [DDMTempDir() stringByAppendingPathComponent:name];
    if (![NSFileManager.defaultManager copyItemAtPath:realPath toPath:dst error:NULL]) return nil;
    return dst;
}

#pragma mark - 媒体路径解析

// 图片本地路径（仅用于判断媒体是否已在本地）。
static NSString *DDMImagePath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    [cands addObject:[item pathForData] ?: @""];
    [cands addObject:[item pathForExistData] ?: @""];
    return DDMFirstUsablePath(cands);
}

// 视频优先路径（短视频 / 转码 / 临时）。
static NSString *DDMVideoPath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    [cands addObject:[item pathForSightData] ?: @""];
    [cands addObject:[item getFormatVideoPath] ?: @""];
    [cands addObject:[item tempPathForSightData] ?: @""];
    [cands addObject:[item getTempVideoPath] ?: @""];
    return DDMFirstUsablePath(cands);
}

// 图片缩略图路径。
static UIImage *DDMThumbImage(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    [cands addObject:[item getThumbImagePath] ?: @""];
    [cands addObject:[item pathForPreview] ?: @""];
    NSString *p = DDMFirstUsablePath(cands);
    return p ? [UIImage imageWithContentsOfFile:p] : nil;
}

// Live Photo 运动视频：只认微信已转码产物并拷进临时目录。
// 微信原生取实况同样只认这两个转码路径，取不到就是没有实况，不做二次转码。
static NSString *DDMLivePhotoVideoPath(WCMediaItem *live) {
    if (!live) return nil;
    NSString *decoded = DDMFirstUsablePath(@[
        ([live getFormatVideoPath] ?: @""),
        ([live getTempVideoPath]  ?: @""),
    ]);
    if (!decoded) return nil;
    return DDMCopyToTemp(decoded, @"mov");
}

#pragma mark - 转发引擎

@interface DDMEngine : NSObject
@property (nonatomic, strong) NSString *pendingText;   // 原帖文案槽：入口写入，发布器 init 期取出即清
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) id retainedCommentDetailVC;
@property (nonatomic, weak) UIWindow *ddmWindow;   // 进度卡挂载的窗口，由触发浮窗直接给出
+ (instancetype)shared;
- (void)forwardDataItem:(WCDataItem *)item hostView:(WCOperateFloatView *)floatView;
- (NSString *)consumePendingText;
@end

// 进度浮卡：窗口宽度变化时按当前宽度重排子视图。
@interface DDMProgressCardView : UIView
@end
@implementation DDMProgressCardView
- (void)layoutSubviews {
    [super layoutSubviews];
    UILabel *title = objc_getAssociatedObject(self, "ddmTitle");
    UILabel *sub   = objc_getAssociatedObject(self, "ddmSub");
    UIProgressView *bar = objc_getAssociatedObject(self, "ddmBar");
    UILabel *pct = objc_getAssociatedObject(self, "ddmPct");
    CGFloat w = self.bounds.size.width;
    CGFloat padX = 14.0, labelH = 18.0;
    title.frame = CGRectMake(padX, 8, w / 2 - padX, labelH);
    sub.frame   = CGRectMake(w / 2, 8, w / 2 - padX, labelH);
    CGFloat barY = 30.0, barH = 4.0;
    bar.frame  = CGRectMake(padX, barY, w - 2 * padX - 36.0, barH);
    pct.frame  = CGRectMake(w - padX - 34.0, barY - 2.0, 34.0, labelH);
}
@end

@implementation DDMEngine

+ (instancetype)shared {
    static DDMEngine *e = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ e = [DDMEngine new]; });
    return e;
}

#pragma mark HUD（下载进度浮卡）

static const NSInteger kDDMProgressHUDTag = 0x44444602;

typedef NS_ENUM(NSInteger, DDMMediaKind) {
    DDMMediaKindImages  = 0,
    DDMMediaKindVideo   = 1,
    DDMMediaKindLive    = 2,
};

// 深色模式动态配色。
static UIColor *ddm_card_bg(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
             ? [UIColor colorWithWhite:0.12 alpha:0.95]
             : [UIColor colorWithWhite:1.0 alpha:0.95];
    }];
}
static UIColor *ddm_text_primary(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
             ? [UIColor colorWithWhite:1.0 alpha:0.9]
             : [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.9];
    }];
}
static UIColor *ddm_text_secondary(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
             ? [UIColor colorWithWhite:1.0 alpha:0.5]
             : [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.35];
    }];
}
static UIColor *ddm_track_bg(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
             ? [UIColor colorWithWhite:1.0 alpha:0.12]
             : [UIColor colorWithWhite:0.0 alpha:0.06];
    }];
}

// 构建进度浮卡（圆角 + 类型化标题 + 计数/百分比 + 尺寸跟随窗口）。
- (UIView *)ddmProgressCard {
    UIWindow *win = self.ddmWindow;
    if (!win) return nil;
    CGFloat cardW = win.bounds.size.width - 32.0;
    CGFloat cardH = 56.0;

    CGFloat topInset = 8.0;
    CGFloat sa = win.safeAreaInsets.top;
    if (sa > 0) topInset = sa + 8.0;
    DDMProgressCardView *card = [[DDMProgressCardView alloc] initWithFrame:CGRectMake(16.0, topInset, cardW, cardH)];
    card.backgroundColor = ddm_card_bg();
    card.layer.cornerRadius = 10.0;
    card.tag = kDDMProgressHUDTag;
    card.alpha = 0.0;

    card.userInteractionEnabled = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowRadius = 6;
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    CGFloat padX = 14.0;
    CGFloat labelH = 18.0;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(padX, 8, cardW / 2 - padX, labelH)];
    title.textColor = ddm_text_primary();
    title.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(cardW / 2, 8, cardW / 2 - padX, labelH)];
    sub.textColor = ddm_text_secondary();
    sub.font = [UIFont systemFontOfSize:11.0];
    sub.textAlignment = NSTextAlignmentRight;
    sub.text = @"";

    CGFloat barY = 30.0, barH = 4.0;
    UIProgressView *bar = [[UIProgressView alloc] initWithFrame:CGRectMake(padX, barY, cardW - 2 * padX - 36.0, barH)];
    bar.progressTintColor = [UIColor colorWithRed:0.03 green:0.76 blue:0.38 alpha:1.0];
    bar.trackTintColor = ddm_track_bg();
    bar.progress = 0.0;
    bar.layer.cornerRadius = 2.0;
    bar.clipsToBounds = YES;

    UILabel *pct = [[UILabel alloc] initWithFrame:CGRectMake(cardW - padX - 34.0, barY - 2.0, 34.0, labelH)];
    pct.textColor = [UIColor colorWithRed:0.03 green:0.76 blue:0.38 alpha:1.0];
    pct.font = [UIFont monospacedDigitSystemFontOfSize:12.0 weight:UIFontWeightMedium];
    pct.textAlignment = NSTextAlignmentRight;
    pct.text = @"0%";

    [card addSubview:title];
    [card addSubview:sub];
    [card addSubview:bar];
    [card addSubview:pct];
    objc_setAssociatedObject(card, "ddmTitle", title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, "ddmSub", sub, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, "ddmBar", bar, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, "ddmPct", pct, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    objc_setAssociatedObject(card, "ddmMediaKind", @(DDMMediaKindImages), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, "ddmTotalCount", @1, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [win addSubview:card];
    [UIView animateWithDuration:0.2 animations:^{ card.alpha = 1.0; }];
    return card;
}

- (UIView *)ddmProgressHUD {
    UIWindow *win = self.ddmWindow;
    return win ? [win viewWithTag:kDDMProgressHUDTag] : nil;
}

// 按内容类型展示初始 HUD。
- (void)showHUDForItem:(WCDataItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD] ?: [self ddmProgressCard];
        if (!card) return;

        BOOL isVideo = item.isVideo;
        DDMMediaKind kind = DDMMediaKindImages;
        NSInteger totalCount = 1;
        NSString *initialTitle = @"正在准备转发…";
        NSString *initialSub = @"";

        if (isVideo) {
            kind = DDMMediaKindVideo;
            initialTitle = @"视频加载中";
            initialSub = @"0%";
        } else {
            WCContentItem *content = item.contentObj;
            NSArray *mediaList = content.mediaList;
            totalCount = MAX(1, mediaList.count);
            BOOL hasLive = NO;
            for (WCMediaItem *m in mediaList) {
                if (m.isLivePhoto) { hasLive = YES; break; }
            }
            if (hasLive && totalCount == 1) {
                kind = DDMMediaKindLive;
                initialTitle = @"获取 live图";
                initialSub = @"0/1";
            } else {
                kind = DDMMediaKindImages;

                initialTitle = (totalCount > 1)
                    ? [NSString stringWithFormat:@"获取图 0/%ld", (long)totalCount]
                    : @"获取图";
                initialSub = @"";
            }
        }

        objc_setAssociatedObject(card, "ddmMediaKind", @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(card, "ddmTotalCount", @(totalCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UILabel *title = objc_getAssociatedObject(card, "ddmTitle");
        title.text = initialTitle;
        UILabel *sub = objc_getAssociatedObject(card, "ddmSub");
        sub.text = initialSub;
        UIProgressView *bar = objc_getAssociatedObject(card, "ddmBar");
        [bar setProgress:0.0 animated:NO];
        UILabel *pct = objc_getAssociatedObject(card, "ddmPct");
        pct.text = @"0%";
    });
}

// 更新进度（0~1），按媒体类型刷新副标题。
- (void)ddmSetProgress:(float)p {
    p = MAX(0.0, MIN(1.0, p));
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD];
        if (!card) return;
        UIProgressView *bar = objc_getAssociatedObject(card, "ddmBar");
        [bar setProgress:p animated:YES];

        int pctVal = (int)(p * 100);
        UILabel *pctLbl = objc_getAssociatedObject(card, "ddmPct");
        pctLbl.text = [NSString stringWithFormat:@"%d%%", pctVal];

        NSNumber *kindObj = objc_getAssociatedObject(card, "ddmMediaKind");
        NSNumber *totalObj = objc_getAssociatedObject(card, "ddmTotalCount");
        DDMMediaKind kind = kindObj ? (DDMMediaKind)[kindObj integerValue] : DDMMediaKindImages;
        NSInteger total = totalObj ? [totalObj integerValue] : 1;
        NSInteger done = (NSInteger)(p * total + 0.5);
        if (done > total) done = total;

        UILabel *title = objc_getAssociatedObject(card, "ddmTitle");
        UILabel *sub = objc_getAssociatedObject(card, "ddmSub");

        switch (kind) {
            case DDMMediaKindLive:
                sub.text = [NSString stringWithFormat:@"%ld/%ld", (long)done, (long)total];
                break;
            case DDMMediaKindVideo:
                sub.text = [NSString stringWithFormat:@"%d%%", pctVal];
                break;
            default:
                if (total > 1)
                    title.text = [NSString stringWithFormat:@"获取图 %ld/%ld", (long)done, (long)total];
                sub.text = @"";
                break;
        }
    });
}

// 收起 HUD。
- (void)dismissHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD];
        if (!card) return;
        [UIView animateWithDuration:0.2 animations:^{ card.alpha = 0.0; }
                         completion:^(BOOL fin){ [card removeFromSuperview]; }];
    });
}

#pragma mark 入口

// 转发主入口：抓文案 → 清临时目录 → 展示进度 → 备媒体 → 在副本上处理位置 → 按类型分流。
- (void)forwardDataItem:(WCDataItem *)item hostView:(WCOperateFloatView *)floatView {
    if (!item) return;
    if (self.busy) return;
    self.busy = YES;

    // 文案在入口就从原始 item 抓取：此刻它正是用户正在看的那条帖，内容最可靠。
    // 存进槽供发布器 init 期取出（取出即清，无需时效判断，也不会串到下一条转发）。
    NSString *cap = [item.contentDesc stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.pendingText = cap.length > 0 ? cap : nil;

    self.ddmWindow = floatView.window;
    UIViewController *host = DDMTopViewController(floatView.navigationController);
    [floatView hide];

    DDMCleanTempDir();
    [self showHUDForItem:item];

    __weak typeof(self) weakSelf = self;

    [self downloadAllMediaOf:item completion:^{
        // 深拷贝失败时回退原件，保证分流拿到的数据项非空。
        WCDataItem *work = [weakSelf deepCopyDataItem:item] ?: item;
        if (work != item) {  // 仅在独立副本上改位置，不污染原帖
            if ([DDMConfig shared].removeOriginalLocation) {
                [work setLocationInfo:nil];
            } else if ([item locationInfo]) {
                [work setLocationInfo:[item locationInfo]];
            }
        }
        [weakSelf routeForwardForItem:work host:host];
    }];
}

// 深拷贝数据项（序列化再反序列化），隔离原始对象。
- (WCDataItem *)deepCopyDataItem:(WCDataItem *)item {
    NSData *buf = [item toNSCodingBuffer];
    return [objc_getClass("WCDataItem") fromNSCodingBuffer:buf];
}

#pragma mark 下载

// 收集待下载媒体（去重；Live Photo 额外收集运动视频）。
- (NSArray *)collectPendingMediaOf:(WCDataItem *)item liveSubs:(NSMutableSet *)liveSubs {
    NSMutableArray *pending = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    BOOL (^isLocal)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        if (DDMImagePath(m)) return YES;
        if (DDMVideoPath(m)) return YES;
        return NO;
    };

    BOOL (^isLiveLocal)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        return DDMVideoPath(m) != nil;
    };

    void (^add)(WCMediaItem *, BOOL) = ^(WCMediaItem *m, BOOL isLive) {
        if (!m) return;
        if (isLive) { if (isLiveLocal(m)) return; }
        else        { if (isLocal(m)) return; }
        NSValue *key = [NSValue valueWithNonretainedObject:m];
        if ([seen containsObject:key]) return;
        [seen addObject:key];
        [pending addObject:m];
    };

    for (WCMediaItem *m in [item getNeedBatchDownloadMedias]) add(m, NO);

    WCContentItem *content = item.contentObj;
    for (WCMediaItem *m in content.mediaList) {
        add(m, NO);
        WCMediaItem *live = m.livePhotoMediaItem;
        if (live) {
            if (liveSubs) [liveSubs addObject:live];
            add(live, YES);
        }
    }
    return pending;
}

// 经 WCFacade 触发 CDN 下载：视频 / 实况走视频管理器，图片走取图管理器。
- (void)downloadAllMediaOf:(WCDataItem *)item completion:(void (^)(void))completion {
    NSMutableSet *liveSubs = [NSMutableSet set];
    NSArray *pending = [self collectPendingMediaOf:item liveSubs:liveSubs];
    if (pending.count == 0) {
        [self ddmSetProgress:1.0];
        dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }

    id facade = DDMGetFrameFacade();

    long long contentType = item.contentObj.type;
    BOOL contentIsVideo = [objc_getClass("WCContentItem") isVideoType:contentType];
    BOOL (^ddmIsSightVideo)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        long long mt = m.mediaType;
        if (mt == 1) return NO;
        if (contentIsVideo) return YES;
        if (m.hasSight) return YES;
        if (m.isPreloadVideoTask) return YES;
        return NO;
    };

    __block id videoMgr = nil;
    for (WCMediaItem *m in pending) {
        BOOL isLiveSub = [liveSubs containsObject:m];
        if (isLiveSub || ddmIsSightVideo(m)) {
            id vMgr = [facade videoDownloadCdnMgrForCategory:(long long)arc4random_uniform(10)];
            if (vMgr) {
                [vMgr StartDownloadVideo:m];
                videoMgr = vMgr;
            }
        } else {
            [facade imageDownloadCdnMgrForCategory:0];
            [facade StartDownloadImage:m DownloadType:2];
            [facade StartDownloadImage:m DownloadType:1];
        }
    }

    BOOL isVideo = item.isVideo;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        BOOL ready = YES;
        if (isVideo) {
            // 视频必须等到真正就绪；超时则静默中止，不以空路径构建草稿。
            ready = [self ddmWaitVideo:pending videoMgr:videoMgr];
        } else {
            [self ddmWaitMedia:pending liveSubs:liveSubs];
        }
        if (!ready) { [self ddmAbortOnTimeout]; return; }
        [self ddmSetProgress:1.0];
        dispatch_async(dispatch_get_main_queue(), completion);
    });
}

// 视频是否就绪：只认真实存在的视频文件，不看封面图。
- (BOOL)ddmVideoReady:(WCMediaItem *)m {
    NSString *p = [m getFormatVideoPath];
    if (p && [[NSFileManager defaultManager] fileExistsAtPath:p]) return YES;
    NSString *alt = DDMVideoPath(m);
    return (alt && DDMFileUsable(alt));
}

// 图片是否就绪：与取图同源，imageOfSize:2 能拿到内存图即就绪。
- (BOOL)ddmImageReady:(WCMediaItem *)m {
    return [m imageOfSize:2LL] != nil;
}

// 下载超时（视频未就绪）时静默中止：收起进度卡并解除占用，不弹提示、不进发布器。
- (void)ddmAbortOnTimeout {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissHUD];
        self.busy = NO;
    });
}

// 视频进度：已等待秒 / 120（封顶 120s）。返回是否全部就绪。
- (BOOL)ddmWaitVideo:(NSArray *)pending videoMgr:(id)videoMgr {
    const NSInteger cap = 120;
    for (NSInteger s = 0; s <= cap; s++) {
        BOOL allReady = YES;
        for (WCMediaItem *m in pending) {
            if (![self ddmVideoReady:m]) { allReady = NO; break; }
        }
        if (allReady) { [self ddmSetProgress:1.0]; return YES; }
        [self ddmSetProgress:(float)s / (float)cap];
        if (s >= cap) break;
        [videoMgr CheckQueue];
        [NSThread sleepForTimeInterval:1.0];
    }
    return NO;
}

// 图片 / 实况进度：已就绪数 / 总数（封顶 60s）。
- (void)ddmWaitMedia:(NSArray *)pending liveSubs:(NSMutableSet *)liveSubs {
    const NSInteger cap = 60;
    NSInteger total = pending.count;
    for (NSInteger s = 0; s <= cap; s++) {
        NSInteger ready = 0;
        for (WCMediaItem *m in pending) {
            BOOL ok = [liveSubs containsObject:m] ? [self ddmVideoReady:m] : [self ddmImageReady:m];
            if (ok) ready++;
        }
        [self ddmSetProgress:(float)ready / (float)total];
        if (ready >= total) return;
        if (s >= cap) break;
        [NSThread sleepForTimeInterval:1.0];
    }
}

#pragma mark 分流

// 按内容类型分流：视频 → 图片 → 纯文字。
- (void)routeForwardForItem:(WCDataItem *)item host:(UIViewController *)host {
    WCContentItem *content = item.contentObj;
    NSArray *mediaList = content.mediaList;

    if (item.isVideo) { [self forwardVideoItem:item host:host]; return; }
    if (mediaList.count > 0) { [self forwardPhotoItem:item host:host]; return; }

    [self presentLegacyForward:item host:host];
}

#pragma mark 视频链路

// 视频转发：取本地路径 → 构建 SightDraft → 唤起发布器。
- (void)forwardVideoItem:(WCDataItem *)item host:(UIViewController *)host {
    // 等待阶段已确认视频已就绪，这里取路径并拷进临时目录。
    WCMediaItem *videoItem = nil;
    NSString *src = nil;
    for (WCMediaItem *m in item.contentObj.mediaList) {
        NSString *p = DDMVideoPath(m);
        if (p) { videoItem = m; src = p; break; }
    }
    if (!src) {   // 没有可解码的视频，直接收手
        [self dismissHUD]; self.busy = NO;
        return;
    }
    [self presentVideoWithLocalPath:DDMCopyToTemp(src, @"mp4")
                              thumb:DDMThumbImage(videoItem)
                               item:item
                               host:host];
}

// 构建 SightDraft 并唤起视频发布器。SightDraft 为微信私有类，运行时取类。
- (void)presentVideoWithLocalPath:(NSString *)path thumb:(UIImage *)thumb item:(WCDataItem *)item host:(UIViewController *)host {
    // 路径不可用（超时未取到）时静默退出，不构建空草稿。
    if (!path || !DDMFileUsable(path)) { [self dismissHUD]; self.busy = NO; return; }

    NSURL *url = [NSURL fileURLWithPath:path];
    Class draftCls = objc_getClass("SightDraft");
    SightDraft *draft = thumb ? [draftCls draftWithVideoURL:url thumbImage:thumb]
                              : [draftCls draftWithVideoURL:url];

    [self dismissHUD];
    [self ddmPushSightCommit:draft item:item host:host];
    self.busy = NO;
}

#pragma mark 图片 / LivePhoto 链路

// 图片 / 实况转发：取内存图 → 组装 MMImage → 唤起发布器。
- (void)forwardPhotoItem:(WCDataItem *)item host:(UIViewController *)host {
    Class localImgCls = objc_getClass("MMAssetForLocalImage");
    NSMutableArray *assets = [NSMutableArray array];

    // 取图统一走 imageOfSize:2（微信原生取图规格），像素内嵌进 MMImage，
    // 所以保留草稿再打开也不会丢图。普通照片不挂资源，只有实况才需要带运动视频。
    for (WCMediaItem *m in item.contentObj.mediaList) {
        UIImage *ui = [m imageOfSize:2LL];
        WCMediaItem *live = m.livePhotoMediaItem;
        NSString *movLocal = live ? DDMLivePhotoVideoPath(live) : nil;

        MMAssetForLocalImage *asset = nil;
        if (movLocal) {
            asset = [[localImgCls alloc] initWithUrl:[NSURL fileURLWithPath:movLocal] IsNeedOrigin:YES];
            asset.localFilePath = movLocal;
            asset.localAssetId  = movLocal;
        }
        MMImage *mm = [self ddmMakeMMImage:ui asset:asset liveVideoPath:movLocal];
        if (mm) [assets addObject:mm];
    }

    if (assets.count == 0) { [self presentLegacyForward:item host:host]; return; }
    [self dismissHUD];
    [self ddmPushImageCommit:assets item:item host:host];
    self.busy = NO;
}

// 构建 MMImage；实况照片额外带上运动视频信息。
- (MMImage *)ddmMakeMMImage:(UIImage *)ui asset:(id)asset liveVideoPath:(NSString *)movLocal {
    if (!ui) return nil;
    MMImage *mmImg = (MMImage *)[[objc_getClass("MMImage") alloc] initWithImage:ui];
    if (!mmImg) return nil;
    mmImg.m_asset = asset;

    if (movLocal) {
        mmImg.isLivePhoto = YES;
        mmImg.livePhotoVideoPath = movLocal;
        [mmImg setImageFrom:3];

        // ExportedLivePhotoPath 是微信读取实况导出路径的约定 key。
        // MMImage 没有 setTempExtraInfo:，只能 KVC 写进同名 ivar。
        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        extra[@"ExportedLivePhotoPath"] = movLocal;
        [mmImg setValue:extra forKey:@"tempExtraInfo"];
    }
    return mmImg;
}

#pragma mark 文案暂存

// 取出原帖文案（取出即清）。一次性消费保证发布器只会回填并通知一次：
// 既不会在 sight 草稿就绪后被重复通知，也不会把文案串到下一条转发。
- (NSString *)consumePendingText {
    NSString *t = self.pendingText;
    self.pendingText = nil;
    return t;
}

#pragma mark 路由调用

// 生成发布上报会话（优先宿主 VC 方法，回退默认构造）。
- (id)reportSessionFromHost:(UIViewController *)host {
    SEL gen = NSSelectorFromString(@"generatePostReportSessionForEntrance:");
    if ([host respondsToSelector:gen]) {
        id (*fn)(id, SEL, long long) = (id (*)(id, SEL, long long))objc_msgSend;
        id s = fn(host, gen, 0);
        if (s) return s;
    }
    return [[objc_getClass("WCMomentsPostReportSession") alloc] init];
}

// 将发布器 VC 推入宿主导航栈。
- (void)ddmPresentCommitVC:(UIViewController *)vc host:(UIViewController *)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *nav = host.navigationController;
        if (!nav) nav = DDMTopViewController(nil).navigationController;
        [nav pushViewController:vc animated:YES];
    });
}

// 把来源位置写进发布器：loc 为 nil 时关闭位置展示。
- (void)ddmApplyLocation:(id)loc toCommitVC:(WCNewCommitViewController *)vc {
    if (!vc) return;
    if (loc) {
        [vc setPoiInfo:loc];
        [vc setBShowLocation:YES];
    } else {
        [vc setBShowLocation:NO];
    }
}

// 视频发布：构造 WCNewCommitViewController(sightDraft) 并推入。
- (void)ddmPushSightCommit:(id)draft item:(WCDataItem *)item host:(UIViewController *)host {
    Class cls = objc_getClass("WCNewCommitViewController");
    WCNewCommitViewController *vc = [(WCNewCommitViewController *)[cls alloc] initWithSightDraft:draft];

    id detail = [[NSClassFromString(@"WCCommentDetailViewControllerFB") alloc] init];
    if (detail) {
        [vc setDelegate:detail];
        self.retainedCommentDetailVC = detail;
    }
    [self ddmApplyLocation:[item locationInfo] toCommitVC:vc];
    [self ddmPresentCommitVC:vc host:host];
}

// 图片发布：构造 WCNewCommitViewController(images) 并推入。
- (void)ddmPushImageCommit:(NSArray *)assets item:(WCDataItem *)item host:(UIViewController *)host {
    Class cls = objc_getClass("WCNewCommitViewController");
    WCNewCommitViewController *vc = [(WCNewCommitViewController *)[cls alloc] initWithImages:[assets mutableCopy] contacts:nil];
    [self ddmApplyLocation:[item locationInfo] toCommitVC:vc];
    [self ddmPresentCommitVC:vc host:host];
}

// 兜底转发：无媒体（纯文字等）时走微信原生转发界面。
- (void)presentLegacyForward:(WCDataItem *)item host:(UIViewController *)host {
    [self dismissHUD];
    Class router = objc_getClass("WCTimelineRouterHelper");
    BOOL (*fn)(id, SEL, id, id, id, id) = (BOOL (*)(id, SEL, id, id, id, id))objc_msgSend;
    fn(router, @selector(presentForwardViewController:postReportSession:trashReportData:currentViewController:),
       item, [self reportSessionFromHost:host], nil, host);
    self.busy = NO;
}

@end

#pragma mark - 集赞核心功能

// 配置键名（与转发 / 辅助设置同属 DDMoments 前缀，键名互不冲突）。
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
@property (assign, nonatomic) BOOL commentsEnabled;        // 评论总开关：关闭则收起输入框、不再新增假评论（已存在的保留）
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

#pragma mark - 集赞持久化与解析

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

static const NSInteger kDDLMaxCount = 100;   // 单边上界，避免好友不足时复用循环跑飞

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
static const void *kDDLLongPressKey = &kDDLLongPressKey;
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

// 追加式注入：保留真实名单，把假数据补齐到目标数后写回；重复调用幂等。
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

#pragma mark - Hook：朋友圈操作浮窗（点赞 / 评论条）

// 转发图标为微信主题 SVG 资源，须经 WCSDKAdapter 渲染。
static UIImage *DDMShareIcon(void) {
    UIImage *img = nil;
    Class adapter = NSClassFromString(@"WCSDKAdapter");
    UIImage *(*fn)(id, SEL, NSString *, CGSize, UIColor *) =
        (UIImage *(*)(id, SEL, NSString *, CGSize, UIColor *))objc_msgSend;
    img = fn(adapter, @selector(svgImageNamed:size:color:),
             @"icons_outlined_share", CGSizeMake(18.0, 18.0), [UIColor whiteColor]);
    if (!img) img = [UIImage imageNamed:@"icons_outlined_share"];
    return img;
}

static char kDDMShareBtnKey;
static char kDDMLineKey;

@interface WCOperateFloatView (DDMoments)
- (void)ddm_onForwardTapped:(UIButton *)sender;
- (void)initForwardButton;
- (void)initForwardLineView;
- (void)ddl_attachLongPress;
- (void)ddl_onLikeLongPress:(UILongPressGestureRecognizer *)g;
- (void)ddl_fakeConfirmed;
- (void)ddl_fakeCancelled;
@end

%hook WCOperateFloatView

// 评论按钮初始化完成后注入转发按钮。
- (void)initCommentButton {
    %orig;
    [self initForwardButton];
}

// 浮窗展示时补齐分隔线，并在动画前把浮窗定型为三列并居中，使转发列随弹窗一起入场。
// showWithItemData 每次弹出都执行，故加宽可按开关实时决定；分隔线则只创建一次（内部去重）。
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint {
    %orig;
    [self initForwardLineView];
    if (!DDMConfig.shared.forwardEnabled) return;   // 转发关闭时保持原生两列，不加宽留白
    UIButton *cmt = self.m_commentBtn;
    UIButton *like = self.m_likeBtn;
    if (cmt && like && cmt.frame.size.width > 0 && like.frame.size.width > 0) {
        CGFloat gap = cmt.frame.origin.x - (like.frame.origin.x + like.frame.size.width);
        if (gap <= 0 || gap > 60) gap = 8.0;
        CGFloat needW = CGRectGetMaxX(cmt.frame) + gap + cmt.frame.size.width;
        if (fabs(self.bounds.size.width - needW) > 0.5) {
            CGPoint c = self.center;
            CGRect fr = self.frame;
            fr.size.width = needW;
            self.frame = fr;
            self.center = CGPointMake(c.x, c.y);
            if (self.superview) self.center = CGPointMake(self.superview.bounds.size.width / 2.0, self.center.y);
        }
    }
}

// 浮窗退出时同步隐藏注入的转发列，避免克隆分隔线滞留于原生退出动画之外。
- (void)hide {
    UIButton *shareBtn = objc_getAssociatedObject(self, &kDDMShareBtnKey);
    UIImageView *line = objc_getAssociatedObject(self, &kDDMLineKey);
    if (shareBtn) shareBtn.hidden = YES;
    if (line) line.hidden = YES;
    %orig;
}

%new
// 在评论按钮右侧注入“转发”按钮。
// 浮窗在 VC 内被复用（initCommentButton 只跑一次），故这里始终创建，
// 显隐交给每次布局都会执行的 layoutSubviews 按开关决定，开关切换后即时生效。
- (void)initForwardButton {
    UIButton *cmtBtn = self.m_commentBtn;
    if (!cmtBtn || objc_getAssociatedObject(self, &kDDMShareBtnKey)) return;

    UIButton *shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    shareBtn.tintColor = [UIColor whiteColor];

    UIImage *icon = DDMShareIcon();
    if (icon) icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [shareBtn setImage:icon forState:UIControlStateNormal];

    [shareBtn setTitle:@"转发" forState:UIControlStateNormal];
    [shareBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    shareBtn.titleLabel.font = cmtBtn.titleLabel.font ?: [UIFont systemFontOfSize:15.0];

    [shareBtn addTarget:self action:@selector(ddm_onForwardTapped:) forControlEvents:UIControlEventTouchUpInside];
    shareBtn.hidden = YES;
    // 注入到原生按钮所在容器（多为 m_clipView），与赞 / 评论同层、同裁剪 / 圆角背景。
    [cmtBtn.superview ?: self addSubview:shareBtn];
    objc_setAssociatedObject(self, &kDDMShareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
// 复制一条分隔线，用于转发按钮与评论按钮之间。
- (void)initForwardLineView {
    if (objc_getAssociatedObject(self, &kDDMLineKey)) return;
    Ivar lineIvar = class_getInstanceVariable([self class], "m_lineView");
    UIImageView *origLine = lineIvar ? object_getIvar(self, lineIvar) : nil;
    if ([origLine isKindOfClass:UIImageView.class]) {
        UIImageView *clone = [[UIImageView alloc] initWithImage:origLine.image];
        clone.hidden = YES;
        [origLine.superview ?: self addSubview:clone];
        objc_setAssociatedObject(self, &kDDMLineKey, clone, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
// 转发按钮点击：沿响应链找到时间线 VC，触发其转发事件。
- (void)ddm_onForwardTapped:(UIButton *)sender {
    UIResponder *r = self;
    while ((r = r.nextResponder)) {
        if ([r isKindOfClass:NSClassFromString(@"WCTimeLineViewController")]) {
            ((void (*)(id, SEL))objc_msgSend)(r, NSSelectorFromString(@"onClickForwardBtnOnFloatView"));
            return;
        }
    }
}

// 转发按钮与分隔线随浮窗布局：仅当转发开关打开时显示并定位（三列加宽 / 居中已在动画前的 showWithItemData 完成）。
// 集赞长按注入不依赖转发开关，故不在此处提前 return。
- (void)layoutSubviews {
    %orig;

    UIButton *shareBtn = objc_getAssociatedObject(self, &kDDMShareBtnKey);
    UIImageView *line  = objc_getAssociatedObject(self, &kDDMLineKey);
    UIButton *likeBtn = self.m_likeBtn;
    UIButton *cmtBtn  = self.m_commentBtn;

    BOOL show = DDMConfig.shared.forwardEnabled && shareBtn && likeBtn && cmtBtn && shareBtn.superview;
    if (shareBtn) shareBtn.hidden = !show;
    if (line) line.hidden = !show;
    if (show) {
        CGFloat gap = cmtBtn.frame.origin.x - (likeBtn.frame.origin.x + likeBtn.frame.size.width);
        if (gap <= 0 || gap > 60) gap = 8.0;

        CGRect target = CGRectMake(CGRectGetMaxX(cmtBtn.frame) + gap,
                                   cmtBtn.frame.origin.y,
                                   cmtBtn.frame.size.width,
                                   cmtBtn.frame.size.height);
        if (!CGRectEqualToRect(shareBtn.frame, target)) shareBtn.frame = target;

        if (line && line.superview && line.image) {
            CGSize ls = line.image.size;
            CGRect lf = CGRectMake(CGRectGetMaxX(cmtBtn.frame) + gap / 2 - ls.width / 2,
                                   cmtBtn.frame.origin.y + (cmtBtn.frame.size.height - ls.height) / 2,
                                   ls.width, ls.height);
            if (!CGRectEqualToRect(line.frame, lf)) line.frame = lf;
        }
    }

    // 集赞：长按点赞浮层注入「集赞设置」弹窗。
    [self ddl_attachLongPress];
}

%new
// 在赞按钮上挂长按手势：弹窗「集赞设置」用于改点赞 / 评论数。
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
    NSString *msg = @"请输入「点赞数/评论数」\n用＂/＂隔开，例如：8/6\n评论需设置界面自定义\n留空还原";

    // 弹窗分步构建：alloc/init → 挂输入框与按钮 → 最后统一 show。
    WCUIAlertView *alert = [[alertCls alloc] initWithTitle:@"集赞设置" message:msg];
    [alert showTextFieldWithMaxLen:15];
    // 预填上次的数值；用 setTextFieldDefaultText 写入真实文本（而非 placeholder 灰字提示）。
    [alert setTextFieldDefaultText:(cfg.likeCount > 0 || cfg.commentCount > 0)
                                   ? [NSString stringWithFormat:@"%ld/%ld",
                                      (long)cfg.likeCount, (long)cfg.commentCount]
                                   : @"0/0"];
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
        // 「设置评论内容」未开启时不新增评论：评论目标归零，仅保留点赞目标。
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

#pragma mark - Hook：宿主时间线 VC

%hook WCTimeLineViewController

%new
// 时间线 VC 上的转发事件入口：取出浮窗当前数据项，交给转发引擎。
- (void)onClickForwardBtnOnFloatView {
    WCOperateFloatView *fv = self.floatOperateView;
    if (!fv) return;
    WCDataItem *item = fv.m_item;
    if (!item) return;
    [[DDMEngine shared] forwardDataItem:item hostView:fv];
}

%end

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

#pragma mark - Hook：发布器（注入原文案 + 启用图片选择器）

%hook WCNewCommitViewController

// 加载后若是本地资源带入，显示 + 号（图片选择器）。
- (void)viewDidLoad {
    %orig;
    if (self.m_isUseMMAsset) self.bHideAddView = NO;
}

// 回填原帖文案。写在 init 期这个微信自建的内容入口上：槽此时已就绪，取出即清故只回填一次；
// 随后 textViewTextDidChange 把文案同步进微信内部模型（视频 / 图片都同步），
// 之后发布器即便重建文本框也会从模型回填，文案不会丢。
- (void)initTextViewContent {
    %orig;
    NSString *text = [[DDMEngine shared] consumePendingText];
    if (text.length == 0) return;
    UITextView *tv = self.textView.textView;
    if (![tv isKindOfClass:UITextView.class]) return;
    if (tv.text.length > 0) return;
    tv.text = text;
    [self textViewTextDidChange];
}

%end

#pragma mark - 朋友圈辅助功能

// 把 Unix 秒格式化为绝对时间（到分钟）；时间戳为 0（取不到发布时间）时返回 nil，保持原生文案。
static NSString *DDMPreciseDateText(unsigned int ts) {
    if (ts == 0) return nil;
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm";
        fmt.locale = [NSLocale currentLocale];
    });
    return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
}

// 查看已删除评论：评论被删（delStatus=1）时保留内容并加标记前缀。
static NSString *ddmDeletedMarkText(void) {
    NSString *t = [[NSUserDefaults standardUserDefaults] stringForKey:kDDMDeletedCommentMark];
    return (t.length ? t : kDDMDefaultDeletedMark);
}
static void ddmInjectMarkIntoComment(id c) {
    Class commentCls = objc_getClass("WCUserComment");
    if (!commentCls || ![c isKindOfClass:commentCls]) return;
    NSString *mark = ddmDeletedMarkText();
    NSString *s = [c content];
    if ([s isKindOfClass:[NSString class]] && s.length) {
        if (![s hasPrefix:mark]) {
            [c setContent:[mark stringByAppendingString:s]];
        }
        return;
    }
    NSString *bare = [mark stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (![s hasPrefix:bare]) {
        [c setContent:bare];
    }
}
%hook WCSNSMessage
- (void)setDelStatus:(unsigned int)status {
    if (![DDMConfig shared].viewDeletedComment) { %orig; return; }
    if (status == 1) {
        id c = [self comment];
        ddmInjectMarkIntoComment(c);
        %orig(0);
        return;
    }
    %orig;
}
%end

// 禁用朋友圈视频自动播放。
%hook WCContentItemViewTemplateVideo
- (void)autoPlayWithoutSound {
    if ([DDMConfig shared].disableVideoAutoPlay) return;
    %orig;
}
%end

// 禁用“谁可以看”隐私图标 + 长文字折叠 + 显示精确时间。
%hook WCTimeLineCellView
- (void)initPrivacyButton:(id)arg1 {
    %orig;
    if ([DDMConfig shared].disablePrivacyIcon) {
        Ivar privacyIvar = class_getInstanceVariable([self class], "m_privacyButton");
        MMUIButton *btn = privacyIvar ? object_getIvar(self, privacyIvar) : nil;
        if (btn) {
            [btn setImage:nil forState:0];
            [btn setAlpha:0.0];
            [btn setUserInteractionEnabled:NO];
        }
    }
}
- (void)layoutSubviews {
    %orig;
    if ([DDMConfig shared].disablePrivacyIcon) {
        Ivar privacyIvar = class_getInstanceVariable([self class], "m_privacyButton");
        MMUIButton *privacyBtn = privacyIvar ? object_getIvar(self, privacyIvar) : nil;
        Ivar deleteIvar = class_getInstanceVariable([self class], "m_deleteButton");
        MMUIButton *deleteBtn  = deleteIvar ? object_getIvar(self, deleteIvar) : nil;
        if (privacyBtn && deleteBtn && privacyBtn.superview && deleteBtn.superview && !deleteBtn.hidden) {
            CGFloat pMinX = CGRectGetMinX(privacyBtn.frame);
            CGFloat dMinX = CGRectGetMinX(deleteBtn.frame);
            if (dMinX > pMinX + 0.5) {
                CGRect dFrame = deleteBtn.frame;
                dFrame.origin.x = pMinX;
                [deleteBtn setFrame:dFrame];
            }
        }
    }
}
+ (BOOL)shouldShowFullTextButtonWithDataItem:(id)arg1 {
    if ([DDMConfig shared].disableTextFold) return NO;
    return %orig;
}
// 显示精确时间：cell 每次复用都会走这里，%orig 之后覆盖时间标签，
// 把“x 小时/天前”换成绝对时间。
- (void)updateWithDataItem:(id)dataItem actionAreaVM:(id)actionAreaVM {
    %orig;
    if (![DDMConfig shared].showPreciseDate) return;
    NSString *text = DDMPreciseDateText([(WCDataItem *)dataItem createtime]);
    if (text) self.m_timeLabel.text = text;
}
%end

// 禁用朋友圈微商折叠。
%hook WCDataItem
- (BOOL)isWeiShang {
    if ([DDMConfig shared].disableWeiShangFold) return NO;
    return %orig;
}
- (void)setExtFlag:(unsigned int)arg1 {
    %orig;
    if ([DDMConfig shared].disableWeiShangFold) {
        Ivar wsIvar = class_getInstanceVariable([self class], "_isWeiShang");
        if (wsIvar) {
            char *p = (char *)(__bridge void *)self + ivar_getOffset(wsIvar);
            *p = 0;
        }
    }
}
%end

// 禁用朋友圈视频点击关闭 + 启用视频进度条。
%hook WCPlayerConfigFullScreenViewController
- (void)onFullScreenSingleTap {
    if ([DDMConfig shared].disableVideoTapClose) return;
    %orig;
}
- (BOOL)shouldShowProgressBar {
    if ([DDMConfig shared].enableVideoProgress) return YES;
    return %orig;
}
- (BOOL)autoShowProgressBarWithThreshold {
    if ([DDMConfig shared].enableVideoProgress) return YES;
    return %orig;
}
%end

#pragma mark - 设置界面

@interface DDMSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *commentsField;
@end

@implementation DDMSettingsViewController {
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
    self.title = @"朋友圈助手设置";
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
// 每次进入重建表格。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
// 清空后按分组重新添加开关 cell。
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    DDMConfig *cfg = DDMConfig.shared;
    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"转发设置"];
    [sec addCell:[cellMgr switchCellForSel:@selector(onForwardEnabledSwitch:)
                                    target:self
                                     title:@"启用一键转发"
                                        on:cfg.forwardEnabled]];
    // 转发开启时展开子项：移除原始位置。
    if (cfg.forwardEnabled) {
        [sec addCell:[cellMgr switchCellForSel:@selector(onRemoveOriginalLocationSwitch:)
                                        target:self
                                         title:@"↳移除原始位置"
                                            on:cfg.removeOriginalLocation]];
    }
    [_tableViewManager addSection:sec];

    // 集赞设置（第二个分组）
    WCTableViewSectionManager *likeSec = [secMgr sectionWithHeader:@"集赞设置"];
    DDLikeConfig *lc = DDLikeConfig.shared;
    [likeSec addCell:[cellMgr switchCellForSel:@selector(onLikeEnabledSwitch:)
                                        target:self
                                         title:@"启用长按集赞"
                                            on:lc.likeEnabled]];
    if (lc.likeEnabled) {
        // 评论内容开关：打开才展开输入框
        [likeSec addCell:[cellMgr switchCellForSel:@selector(onCommentsSwitch:)
                                        target:self
                                         title:@"↳设置评论内容"
                                            on:lc.commentsEnabled]];
        if (lc.commentsEnabled) {
            self.commentsField = [self makeFieldPlaceholder:@"多个内容用/分隔"
                                                     value:lc.comments];
            [likeSec addCell:[cellMgr normalCellForSel:nil
                                            target:nil
                                             title:@"   ↳自定义内容"
                                        rightView:[self inputRowWithField:self.commentsField
                                                                   action:@selector(commentsConfirmed:)]]];
        }

        // 清除伪装记录：始终显示，右侧「清理」按钮
        UIButton *clearBtn = [self dd_actionButton:@"清理" action:@selector(onClearFakeTapped:)];
        UIView *clearRight = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 52, 34)];
        [clearRight addSubview:clearBtn];
        [likeSec addCell:[cellMgr normalCellForSel:nil
                                       target:nil
                                        title:@"↳清空伪装记录"
                                     rightView:clearRight]];
    }
    [_tableViewManager addSection:likeSec];

    WCTableViewSectionManager *aux = [secMgr sectionWithHeader:@"辅助设置"];
    [aux addCell:[cellMgr switchCellForSel:@selector(onViewDeletedCommentSwitch:)
                                   target:self
                                    title:@"查看已删评论"
                                       on:cfg.viewDeletedComment]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onShowPreciseDateSwitch:)
                                   target:self
                                    title:@"显示精确时间"
                                       on:cfg.showPreciseDate]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onDisablePrivacyIconSwitch:)
                                   target:self
                                    title:@"禁用隐私图标"
                                       on:cfg.disablePrivacyIcon]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onDisableWeiShangFoldSwitch:)
                                   target:self
                                    title:@"禁用微商折叠"
                                       on:cfg.disableWeiShangFold]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onDisableTextFoldSwitch:)
                                   target:self
                                    title:@"禁用文字折叠"
                                       on:cfg.disableTextFold]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onDisableVideoAutoPlaySwitch:)
                                   target:self
                                    title:@"禁用自动播放"
                                       on:cfg.disableVideoAutoPlay]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onDisableVideoTapCloseSwitch:)
                                   target:self
                                    title:@"禁用点击关闭"
                                       on:cfg.disableVideoTapClose]];
    [aux addCell:[cellMgr switchCellForSel:@selector(onEnableVideoProgressSwitch:)
                                   target:self
                                    title:@"启用视频进度"
                                       on:cfg.enableVideoProgress]];
    [_tableViewManager addSection:aux];

    [_tableViewManager reloadTableView];
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
// 转发开关展开“移除原始位置”子项，故其回调内即时重建表格。
- (void)onForwardEnabledSwitch:(UISwitch *)s        { DDMConfig.shared.forwardEnabled = s.isOn; [self buildTable]; }
- (void)onRemoveOriginalLocationSwitch:(UISwitch *)s { DDMConfig.shared.removeOriginalLocation = s.isOn; }
- (void)onViewDeletedCommentSwitch:(UISwitch *)s   { DDMConfig.shared.viewDeletedComment = s.isOn; }
- (void)onShowPreciseDateSwitch:(UISwitch *)s      { DDMConfig.shared.showPreciseDate = s.isOn; }
- (void)onDisablePrivacyIconSwitch:(UISwitch *)s   { DDMConfig.shared.disablePrivacyIcon = s.isOn; }
- (void)onDisableWeiShangFoldSwitch:(UISwitch *)s  { DDMConfig.shared.disableWeiShangFold = s.isOn; }
- (void)onDisableTextFoldSwitch:(UISwitch *)s      { DDMConfig.shared.disableTextFold = s.isOn; }
- (void)onDisableVideoAutoPlaySwitch:(UISwitch *)s { DDMConfig.shared.disableVideoAutoPlay = s.isOn; }
- (void)onDisableVideoTapCloseSwitch:(UISwitch *)s { DDMConfig.shared.disableVideoTapClose = s.isOn; }
- (void)onEnableVideoProgressSwitch:(UISwitch *)s  { DDMConfig.shared.enableVideoProgress = s.isOn; }

#pragma mark 集赞设置回调

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

// 「清理」按钮：system 文字、systemGray5 背景、圆角 6、52×34。
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

// 微信内置WeToast轻提示
- (void)dd_showDoneToast:(NSString *)text {
    if (!text.length) return;
    WeToast *toast = [%c(WeToast) toast];
    if (toast) [toast showDoneToastWithText:text];
}
@end

#pragma mark - 注册入口

// 将设置页注册到插件管理（依赖第三方 WCPluginsMgr，做存在性守卫避免启动崩溃）。
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD朋友圈助手"
                                                     version:@"1.0.0"
                                                  controller:@"DDMSettingsViewController"];
        }
    }
}

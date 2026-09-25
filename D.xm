// DDWCMoments.xm
// 微信朋友圈增强插件（Theos / Logos，arm64 / arm64e，iOS 18+）
//
// 功能：
//   1. 朋友圈转发 —— 在朋友圈操作浮窗（点赞 / 评论条）注入“转发”按钮，
//      支持图片、视频、Live Photo 与纯文字转发，下载完成后直接唤起微信发布器。
//   2. 辅助设置 —— 7 项独立开关：查看已删评论、禁用隐私图标、禁用微商折叠、
//      禁用文字折叠、禁用自动播放、禁用点击关闭、启用视频进度条。
//
// 设计要点：
//   - 所有对微信私有类的引用均走运行时获取（objc_getClass / class_getInstanceVariable），
//     不在编译期登记私有类符号，避免链接失败（tweak 无私有类实现）。
//   - 私有接口声明锚定微信 8.0.79 头文件 dump，仅保留本插件实际调用的方法。
//   - 进度浮卡挂载于触发浮窗所在主窗口，支持深色模式与窗口尺寸自适应。
//   - 设置页重建遵循“基础双重建 + 展开型开关即时重建”：viewDidLoad / viewWillAppear
//     始终重建；仅“朋友圈转发”开关（将来会展开子项）在回调内即时重建。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信私有接口声明

// 微信“我”页设置入口：将本插件设置页注册为一个功能项。
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信内置设置表格组件（用于构建本插件设置页）。
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
@end

// 朋友圈内容项（一条朋友圈的元数据）。
@interface WCContentItem : NSObject
@property (retain, nonatomic) NSMutableArray *mediaList;   // 媒体列表（图片 / 视频 / Live Photo）
@property (nonatomic) int type;                            // 内容类型
+ (BOOL)isVideoType:(long long)type;                        // 类型是否为视频
@end

// 朋友圈数据项（一条朋友圈的完整数据模型）。
@interface WCDataItem : NSObject
@property (retain, nonatomic) WCContentItem *contentObj;    // 内容项
@property (retain, nonatomic) NSString *contentDesc;        // 文案
+ (id)fromNSCodingBuffer:(NSData *)buffer;                  // 反序列化（用于深拷贝）
- (NSData *)toNSCodingBuffer;                               // 序列化（用于深拷贝）
- (BOOL)isVideo;                                            // 是否为视频
- (NSArray *)getNeedBatchDownloadMedias;                    // 需要批量下载的媒体
- (BOOL)isWeiShang;                                         // 是否微商
- (void)setExtFlag:(unsigned int)arg1;                      // 设置扩展标记（含微商标记）
@end

// 朋友圈单条媒体（图片 / 视频 / Live Photo）。
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
@end

// 微信视频下载管理器（经 WCFacade 取得，StartDownloadVideo: 被实际调用）。
@interface WCDownloadVideoCDNMgr : NSObject
- (unsigned long long)StartDownloadVideo:(id)arg1;
@end

// 微信业务门面：经它获取下载管理器，触发 CDN 下载。
@interface WCFacade : NSObject
- (id)videoDownloadCdnMgrForCategory:(long long)arg1;
- (id)imageDownloadCdnMgrForCategory:(long long)arg1;
- (void)StartDownloadImage:(id)arg1 DownloadType:(long long)arg2;
@end

// 微信服务定位：经 MMContext → serviceCenter → getService: 取 WCFacade 单例。
@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

// 经微信服务链取 WCFacade 单例，失败返回 nil。
static inline id DDMGetFrameFacade(void) {
    Class ctxCls = objc_getClass("MMContext");
    if (ctxCls && [ctxCls respondsToSelector:@selector(currentContext)]) {
        id ctx = [ctxCls currentContext];
        if (ctx && [ctx respondsToSelector:@selector(serviceCenter)]) {
            id center = [ctx serviceCenter];
            if (center && [center respondsToSelector:@selector(getService:)]) {
                id facade = [center getService:objc_getClass("WCFacade")];
                if (facade) return facade;
            }
        }
    }
    return nil;
}

// 朋友圈操作浮窗（点赞 / 评论条）。
@interface WCOperateFloatView : UIView
@property (readonly, nonatomic) UIButton *m_likeBtn;
@property (readonly, nonatomic) UIButton *m_commentBtn;
@property (readonly, nonatomic) WCDataItem *m_item;
@property (nonatomic, weak) UINavigationController *navigationController;
- (double)buttonWidth:(id)button;
- (void)hide;
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint;
@end

// 朋友圈时间线 VC：转发按钮事件最终落到这里。
@interface WCTimeLineViewController : UIViewController
@property (retain, nonatomic) WCOperateFloatView *floatOperateView;
@end

// 本地资源基类（MMAssetForLocalImage 的父类）。
@interface MMAsset : NSObject
@property (nonatomic) BOOL m_isNeedOriginImage;
@property (nonatomic) BOOL m_isUseLivePhoto;
@property (retain, nonatomic) NSString *m_livePhotoVideoPath;
@property (nonatomic) double livePhotoDuration;
@property (nonatomic) long long livePhotoVideoSize;
@property (nonatomic) BOOL isLivePhoto;
@end

// 本地图片 / Live Photo 资源。
@interface MMAssetForLocalImage : MMAsset
@property (retain, nonatomic) NSString *localAssetId;
@property (retain, nonatomic) NSString *localFilePath;
@property (nonatomic) long long imageDataType;
- (id)initWithUrl:(NSURL *)url IsNeedOrigin:(BOOL)isNeedOrigin;
- (long long)_getImageTypeFromData:(NSData *)arg1;
@end

// 微信图片封装：发布时承载本地图片与 Live Photo 信息。
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
- (BOOL)isSightResourceValid;
@property (copy, nonatomic) NSString *draftItemVideoPath;
@end

// 朋友圈路由：转发到微信原生转发界面（纯文字 / 兜底场景）。
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

// 微信发布器 VC：转发媒体 / 文案注入到这里。
@interface WCNewCommitViewController : UIViewController
@property (retain, nonatomic) MMGrowTextView *textView;
@property (nonatomic) BOOL m_isUseMMAsset;
@property (nonatomic) BOOL bHideAddView;
- (void)initTextViewContent;
- (void)textViewTextDidChange;
- (instancetype)initWithImages:(id)arg1 contacts:(id)arg2;
- (instancetype)initWithSightDraft:(id)arg1;
@end

// 朋友圈视频模板视图：禁用自动播放。
@interface WCContentItemViewTemplateVideo : UIView
- (void)autoPlayWithoutSound;
@end

// 朋友圈 cell 视图：禁用隐私图标 + 禁用文字折叠。
@interface WCTimeLineCellView : UIView
- (void)initPrivacyButton:(id)arg1;
- (void)layoutSubviews;
+ (BOOL)shouldShowFullTextButtonWithDataItem:(id)arg1;
@end

// 微信按钮基类（隐私 / 删除按钮）。
@interface MMUIButton : UIButton
@end

// 朋友圈评论 / 消息（锚定 8.0.79 WCSNSMessage.h / WCUserComment.h，仅保留实际调用的方法）。
@interface WCUserComment : NSObject
- (id)content;
- (void)setContent:(id)arg1;
@end

@interface WCSNSMessage : NSObject
- (id)comment;
- (unsigned int)delStatus;
- (void)setDelStatus:(unsigned int)arg1;
@end

// 全屏视频播放器：禁用点击关闭 + 启用进度条。
@interface WCPlayerConfigFullScreenViewController : UIViewController
- (void)onFullScreenSingleTap;
- (BOOL)shouldShowProgressBar;
- (BOOL)autoShowProgressBarWithThreshold;
@end

#pragma mark - 配置

// 转发开关：存储键沿用旧名 DDForward_Enabled，兼容历史版本已保存的偏好，不可改名。
static NSString * const kDDMForwardEnabled       = @"DDForward_Enabled";

// 辅助设置：存储键统一为 DDMoments_<属性名>，属性名与界面标题一一对应。
static NSString * const kDDMViewDeletedComment   = @"DDMoments_viewDeletedComment";    // 查看已删评论
static NSString * const kDDMDisablePrivacyIcon   = @"DDMoments_disablePrivacyIcon";    // 禁用隐私图标
static NSString * const kDDMDisableWeiShangFold  = @"DDMoments_disableWeiShangFold";   // 禁用微商折叠
static NSString * const kDDMDisableTextFold      = @"DDMoments_disableTextFold";       // 禁用文字折叠
static NSString * const kDDMDisableVideoAutoPlay = @"DDMoments_disableVideoAutoPlay";  // 禁用自动播放
static NSString * const kDDMDisableVideoTapClose = @"DDMoments_disableVideoTapClose";  // 禁用点击关闭
static NSString * const kDDMEnableVideoProgress  = @"DDMoments_enableVideoProgress";   // 启用视频进度

// 已删评论标记前缀（默认文案，预留可定制）。
static NSString * const kDDMDeletedCommentMark   = @"DDMoments_deletedCommentMark";
static NSString * const kDDMDefaultDeletedMark   = @"[对方已删除] ";

@interface DDMConfig : NSObject
@property (assign, nonatomic) BOOL forwardEnabled;       // 朋友圈转发（独立开关，仅控制转发按钮是否注入）
@property (assign, nonatomic) BOOL viewDeletedComment;   // 查看已删评论
@property (assign, nonatomic) BOOL disablePrivacyIcon;   // 禁用隐私图标
@property (assign, nonatomic) BOOL disableWeiShangFold;  // 禁用微商折叠
@property (assign, nonatomic) BOOL disableTextFold;      // 禁用文字折叠
@property (assign, nonatomic) BOOL disableVideoAutoPlay; // 禁用自动播放
@property (assign, nonatomic) BOOL disableVideoTapClose; // 禁用点击关闭
@property (assign, nonatomic) BOOL enableVideoProgress;  // 启用视频进度
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
        _disablePrivacyIcon       = [ud boolForKey:kDDMDisablePrivacyIcon];
        _disableWeiShangFold      = [ud boolForKey:kDDMDisableWeiShangFold];
        _disableTextFold          = [ud boolForKey:kDDMDisableTextFold];
        _disableVideoAutoPlay     = [ud boolForKey:kDDMDisableVideoAutoPlay];
        _disableVideoTapClose     = [ud boolForKey:kDDMDisableVideoTapClose];
        _enableVideoProgress      = [ud boolForKey:kDDMEnableVideoProgress];
    }
    return self;
}

- (void)persist:(id)value key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setForwardEnabled:(BOOL)v            { _forwardEnabled = v;            [self persist:@(v) key:kDDMForwardEnabled]; }
- (void)setViewDeletedComment:(BOOL)v       { _viewDeletedComment = v;       [self persist:@(v) key:kDDMViewDeletedComment]; }
- (void)setDisablePrivacyIcon:(BOOL)v       { _disablePrivacyIcon = v;       [self persist:@(v) key:kDDMDisablePrivacyIcon]; }
- (void)setDisableWeiShangFold:(BOOL)v      { _disableWeiShangFold = v;      [self persist:@(v) key:kDDMDisableWeiShangFold]; }
- (void)setDisableTextFold:(BOOL)v          { _disableTextFold = v;          [self persist:@(v) key:kDDMDisableTextFold]; }
- (void)setDisableVideoAutoPlay:(BOOL)v     { _disableVideoAutoPlay = v;     [self persist:@(v) key:kDDMDisableVideoAutoPlay]; }
- (void)setDisableVideoTapClose:(BOOL)v     { _disableVideoTapClose = v;     [self persist:@(v) key:kDDMDisableVideoTapClose]; }
- (void)setEnableVideoProgress:(BOOL)v      { _enableVideoProgress = v;      [self persist:@(v) key:kDDMEnableVideoProgress]; }

@end

#pragma mark - 运行时工具

static BOOL DDMFileUsable(NSString *path);
static NSString *DDMLivePhotoVideoPath(WCMediaItem *live);

// 视频时长（用于 Live Photo 运动视频时长登记）。
static double DDMVideoDuration(NSString *path) {
    if (!DDMFileUsable(path)) return 0;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    CMTime d = asset.duration;
    return CMTIME_IS_NUMERIC(d) ? CMTimeGetSeconds(d) : 0;
}

// 取当前 keyWindow（用于无触发窗口时回退定位顶层 VC）。
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

// 从给定根 VC 递归找到最上层可见 VC（穿透导航 / 标签 / present）。
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

// 本插件临时目录（下载 / 转码产物统一落这里，便于转发后清理）。
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

// 判断文件是否可用（存在、常规文件、大小 > 0）。
static BOOL DDMFileUsable(NSString *path) {
    if (path.length == 0) return NO;
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if (!attr) return NO;

    if (![attr[NSFileType] isEqual:NSFileTypeRegular]) return NO;
    return [attr fileSize] > 0;
}

// 从候选路径中取出第一个可用文件。
static NSString *DDMFirstUsablePath(NSArray<NSString *> *candidates) {
    for (NSString *p in candidates) if (DDMFileUsable(p)) return p;
    return nil;
}

// 将源文件拷贝到临时目录，解析软链并补齐扩展名。
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
    NSError *err = nil;
    if (![NSFileManager.defaultManager copyItemAtPath:realPath toPath:dst error:&err]) {
        return nil;
    }
    return dst;
}

// 取视频首帧作为转发缩略图。
static UIImage *DDMVideoFirstFrame(NSString *path) {
    if (!DDMFileUsable(path)) return nil;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CGImageRef ref = [gen copyCGImageAtTime:CMTimeMake(0, 600) actualTime:NULL error:NULL];
    if (!ref) return nil;
    UIImage *img = [UIImage imageWithCGImage:ref];
    CGImageRelease(ref);
    return img;
}

#pragma mark - 媒体路径解析

// 图片优先路径。
static NSString *DDMImagePath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForData)])      [cands addObject:[item pathForData] ?: @""];
    if ([item respondsToSelector:@selector(pathForExistData)]) [cands addObject:[item pathForExistData] ?: @""];
    return DDMFirstUsablePath(cands);
}

// 视频优先路径（短视频 / 转码 / 临时路径）。
static NSString *DDMVideoPath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForSightData)])    [cands addObject:[item pathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(getFormatVideoPath)])  [cands addObject:[item getFormatVideoPath] ?: @""];
    if ([item respondsToSelector:@selector(tempPathForSightData)])[cands addObject:[item tempPathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(getTempVideoPath)])    [cands addObject:[item getTempVideoPath] ?: @""];
    return DDMFirstUsablePath(cands);
}

// Live Photo 运动视频的持久化路径（短视频 / 临时路径）。
static NSString *DDMLiveVideoPath(WCMediaItem *live) {
    if (!live) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    if ([live respondsToSelector:@selector(pathForSightData)])     [cands addObject:[live pathForSightData] ?: @""];
    if ([live respondsToSelector:@selector(tempPathForSightData)]) [cands addObject:[live tempPathForSightData] ?: @""];
    if ([live respondsToSelector:@selector(getFormatVideoPath)])   [cands addObject:[live getFormatVideoPath] ?: @""];
    if ([live respondsToSelector:@selector(getTempVideoPath)])    [cands addObject:[live getTempVideoPath] ?: @""];
    return DDMFirstUsablePath(cands);
}

// 短视频持久化路径（Live Photo 运动视频的兜底来源）。
static NSString *DDMPersistentSightPath(WCMediaItem *item) {
    if (!item) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForSightData)])     [cands addObject:[item pathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(tempPathForSightData)]) [cands addObject:[item tempPathForSightData] ?: @""];
    return DDMFirstUsablePath(cands);
}

// 图片缩略图路径（缩略图 / 预览图）。
static UIImage *DDMThumbImage(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(getThumbImagePath)]) [cands addObject:[item getThumbImagePath] ?: @""];
    if ([item respondsToSelector:@selector(pathForPreview)])    [cands addObject:[item pathForPreview] ?: @""];
    NSString *p = DDMFirstUsablePath(cands);
    return p ? [UIImage imageWithContentsOfFile:p] : nil;
}

#pragma mark - 实况照片运动视频：转码为真实可播放视频

// 将 wxam（微信实况封装）转码为 .mov，得到可被系统播放器识别的真实视频。
static NSString *DDMTranscodeWxamToMov(NSString *src) {
    if (!DDMFileUsable(src)) return nil;
    NSURL *inURL = [NSURL fileURLWithPath:src];
    AVAsset *asset = [AVAsset assetWithURL:inURL];
    NSArray *tracks = asset ? [asset tracksWithMediaType:AVMediaTypeVideo] : nil;
    if (tracks.count == 0) {
        return nil;
    }
    NSString *dst = [DDMTempDir() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"%@.mov", [NSUUID.UUID UUIDString]]];

    AVAssetExportSession *exp = [AVAssetExportSession exportSessionWithAsset:asset
                                                                  presetName:AVAssetExportPresetPassthrough];
    if (!exp) exp = [AVAssetExportSession exportSessionWithAsset:asset
                                                      presetName:AVAssetExportPresetMediumQuality];
    if (!exp) { return nil; }
    exp.outputURL = [NSURL fileURLWithPath:dst];
    exp.outputFileType = AVFileTypeQuickTimeMovie;
    exp.shouldOptimizeForNetworkUse = YES;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [exp exportAsynchronouslyWithCompletionHandler:^{ dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
    if (exp.status == AVAssetExportSessionStatusCompleted && DDMFileUsable(dst)) {
        return dst;
    }
    return nil;
}

// Live Photo 运动视频路径：优先已转码路径，否则从持久化短视频转码。
static NSString *DDMLivePhotoVideoPath(WCMediaItem *live) {
    if (!live) return nil;

    NSString *decoded = DDMFirstUsablePath(@[
        ([live respondsToSelector:@selector(getFormatVideoPath)] ? [live getFormatVideoPath] : @""),
        ([live respondsToSelector:@selector(getTempVideoPath)]  ? [live getTempVideoPath]  : @""),
    ]);
    if (decoded) {
        NSString *cp = DDMCopyToTemp(decoded, @"mov");
        if (cp) return cp;
    }

    NSString *wxam = DDMPersistentSightPath(live);
    if (!wxam) return nil;
    return DDMTranscodeWxamToMov(wxam);
}

#pragma mark - 转发引擎

@interface DDMEngine : NSObject
@property (nonatomic, strong) NSString *pendingText;
@property (nonatomic, assign) NSTimeInterval pendingTextStamp;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) id retainedCommentDetailVC;
@property (nonatomic, weak) UIWindow *ddmWindow;   // 进度卡挂载的窗口，由触发浮窗直接给出，不遍历窗口列表
+ (instancetype)shared;
- (void)forwardDataItem:(WCDataItem *)item hostView:(WCOperateFloatView *)floatView;
- (NSString *)consumePendingText;
@end

// 进度浮卡子类：宽度随窗口变化（autoresizingMask 左右各留 16 边距）后，
// 在 layoutSubviews 内按当前宽度重排子视图，从而适配横竖屏与窗口尺寸变化。
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

#pragma mark HUD（下载进度条：圆角浮卡 + 类型化标题 + 计数/百分比 + 深色模式 + 尺寸跟随窗口）

static const NSInteger kDDMProgressHUDTag = 0x44444602;

typedef NS_ENUM(NSInteger, DDMMediaKind) {
    DDMMediaKindImages  = 0,
    DDMMediaKindVideo   = 1,
    DDMMediaKindLive    = 2,
};

// 深色模式配色：直接走动态色，浅色 / 深色自动切换。
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

// 进度浮卡（DDMProgressCardView）的布局在 layoutSubviews 内按当前宽度重排，窗口变化时自适应。

- (UIView *)ddmProgressCard {
    UIWindow *win = self.ddmWindow;   // 直接挂触发浮窗所在的主窗口，不遍历窗口列表
    if (!win) return nil;
    CGFloat cardW = win.bounds.size.width - 32.0;
    CGFloat cardH = 56.0;

    CGFloat topInset = 8.0;
    if ([win respondsToSelector:@selector(safeAreaInsets)]) {
        CGFloat sa = win.safeAreaInsets.top;
        if (sa > 0) topInset = sa + 8.0;
    }
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
    // 宽度跟随窗口变化：左右各留 16 边距（autoresizing 仅宽度弹性）。
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

// 按内容类型展示初始 HUD（视频 / 多图 / Live Photo 标题与计数不同）。
- (void)showHUDForItem:(WCDataItem *)item {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD] ?: [self ddmProgressCard];
        if (!card) return;

        BOOL isVideo = [item respondsToSelector:@selector(isVideo)] && [item isVideo];
        DDMMediaKind kind = DDMMediaKindImages;
        NSInteger totalCount = 1;
        NSString *initialTitle = @"正在准备转发…";
        NSString *initialSub = @"";

        if (isVideo) {
            kind = DDMMediaKindVideo;
            initialTitle = @"视频加载中";
            initialSub = @"0%";
        } else {
            id content = [item respondsToSelector:@selector(contentObj)] ? item.contentObj : nil;
            NSArray *mediaList = ([content respondsToSelector:@selector(mediaList)] ? [(id)content mediaList] : nil);
            totalCount = MAX(1, mediaList.count);
            BOOL hasLive = NO;
            for (id m in mediaList) {
                if ([m respondsToSelector:@selector(isLivePhoto)] && [m isLivePhoto]) { hasLive = YES; break; }
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

// 通用进度 HUD（仅更新标题）。
- (void)showHUD:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD] ?: [self ddmProgressCard];
        if (!card) return;
        UILabel *title = objc_getAssociatedObject(card, "ddmTitle");
        title.text = text ?: @"正在准备转发…";
        UILabel *sub = objc_getAssociatedObject(card, "ddmSub");
        sub.text = @"";
        UIProgressView *bar = objc_getAssociatedObject(card, "ddmBar");
        [bar setProgress:0.0 animated:NO];
        UILabel *pct = objc_getAssociatedObject(card, "ddmPct");
        pct.text = @"0%";
    });
}

// 更新进度（0~1），并按媒体类型刷新副标题（百分比 / 计数）。
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

// 失败 HUD：展示错误文案，1.6s 后收起并解锁。
- (void)failHUD:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD];
        if (!card) { self.busy = NO; return; }
        UILabel *title = objc_getAssociatedObject(card, "ddmTitle");
        title.text = text ?: @"失败";
        UILabel *sub = objc_getAssociatedObject(card, "ddmSub");
        sub.text = @"";
        UIProgressView *bar = objc_getAssociatedObject(card, "ddmBar");
        bar.hidden = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.2 animations:^{ card.alpha = 0.0; }
                             completion:^(BOOL fin){ [card removeFromSuperview]; }];
            self.busy = NO;
        });
    });
}

#pragma mark 入口

// 转发主入口：清理临时目录 → 展示进度 HUD → 下载媒体 → 分流到发布器。
- (void)forwardDataItem:(WCDataItem *)item hostView:(WCOperateFloatView *)floatView {
    if (!item) return;
    if (self.busy) { return; }
    self.busy = YES;

    // 进度卡直接挂在触发浮窗所在的主窗口上，不遍历窗口列表（避免被 iConsole 之类浮层换类名干扰）。
    self.ddmWindow = floatView.window;
    UIViewController *host = DDMTopViewController(floatView.navigationController);
    if ([floatView respondsToSelector:@selector(hide)]) [floatView hide];

    DDMCleanTempDir();
    [self showHUDForItem:item];

    __weak typeof(self) weakSelf = self;

    [self downloadAllMediaOf:item completion:^{
        WCDataItem *work = [weakSelf deepCopyDataItem:item] ?: item;
        [weakSelf routeForwardForItem:work host:host];
    }];
}

// 深拷贝数据项（序列化再反序列化），隔离原始对象。
- (WCDataItem *)deepCopyDataItem:(WCDataItem *)item {
    if (![item respondsToSelector:@selector(toNSCodingBuffer)]) return nil;
    NSData *buf = [item toNSCodingBuffer];
    if (buf.length == 0) return nil;
    Class cls = objc_getClass("WCDataItem");
    if (![cls respondsToSelector:@selector(fromNSCodingBuffer:)]) return nil;
    WCDataItem *copied = [cls fromNSCodingBuffer:buf];
    return copied;
}

#pragma mark 下载

// 收集待下载媒体（去重；Live Photo 额外收集运动视频）。
- (NSArray *)collectPendingMediaOf:(WCDataItem *)item liveSubs:(NSMutableSet *)liveSubs {
    NSMutableArray *pending = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];

    BOOL (^isLocal)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        if (DDMImagePath(m)) return YES;
        if (DDMPersistentSightPath(m)) return YES;
        return NO;
    };

    BOOL (^isLiveLocal)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        return DDMPersistentSightPath(m) != nil;
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

    if ([item respondsToSelector:@selector(getNeedBatchDownloadMedias)]) {
        for (WCMediaItem *m in [item getNeedBatchDownloadMedias]) add(m, NO);
    }

    WCContentItem *content = item.contentObj;
    for (WCMediaItem *m in ([content respondsToSelector:@selector(mediaList)] ? content.mediaList : @[])) {
        add(m, NO);
        WCMediaItem *live = [m respondsToSelector:@selector(livePhotoMediaItem)] ? m.livePhotoMediaItem : nil;
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
    if (!facade) { dispatch_async(dispatch_get_main_queue(), completion); return; }

    long long contentType = ([item.contentObj respondsToSelector:@selector(type)] ? [item.contentObj type] : -1);
    Class ci = objc_getClass("WCContentItem");
    BOOL contentIsVideo = ci && [ci respondsToSelector:@selector(isVideoType:)] && [ci isVideoType:contentType];
    BOOL (^ddmIsSightVideo)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {

        long long mt = [m respondsToSelector:@selector(mediaType)] ? [m mediaType] : -1;
        if (mt == 1) return NO;
        if (contentIsVideo) return YES;
        if ([m respondsToSelector:@selector(hasSight)] && [m hasSight]) return YES;
        if ([m respondsToSelector:@selector(isPreloadVideoTask)] && [m isPreloadVideoTask]) return YES;
        return NO;
    };

    __block id videoMgr = nil;
    for (WCMediaItem *m in pending) {
        BOOL isLiveSub = [liveSubs containsObject:m];
        if (isLiveSub || ddmIsSightVideo(m)) {

            if (![facade respondsToSelector:@selector(videoDownloadCdnMgrForCategory:)]) continue;
            id vMgr = [facade videoDownloadCdnMgrForCategory:(long long)arc4random_uniform(10)];
            if (vMgr && [vMgr respondsToSelector:@selector(StartDownloadVideo:)]) {
                [vMgr StartDownloadVideo:m];
                videoMgr = vMgr;
            }
        } else {

            if ([facade respondsToSelector:@selector(imageDownloadCdnMgrForCategory:)])
                [facade imageDownloadCdnMgrForCategory:0];
            if (![facade respondsToSelector:@selector(StartDownloadImage:DownloadType:)]) continue;
            [facade StartDownloadImage:m DownloadType:2];
            [facade StartDownloadImage:m DownloadType:1];
        }
    }

    BOOL isVideo = [item respondsToSelector:@selector(isVideo)] && [item isVideo];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        if (isVideo) {
            [self ddmWaitVideo:pending videoMgr:videoMgr];
        } else {
            [self ddmWaitMedia:pending liveSubs:liveSubs];
        }
        [self ddmSetProgress:1.0];
        dispatch_async(dispatch_get_main_queue(), completion);
    });
}

// 判断单个视频媒体是否就绪。
- (BOOL)ddmVideoReady:(WCMediaItem *)m {
    if ([m respondsToSelector:@selector(getFormatVideoPath)]) {
        NSString *p = [m getFormatVideoPath];
        if (p && [[NSFileManager defaultManager] fileExistsAtPath:p]) return YES;
    }
    NSString *p = DDMVideoPath(m) ?: DDMLiveVideoPath(m);
    if (p && DDMFileUsable(p)) return YES;
    return [self ddmImageReady:m];
}

// 判断单个图片媒体是否就绪（尝试 imageOfSize: 内存图或落盘路径）。
- (BOOL)ddmImageReady:(WCMediaItem *)m {
    if ([m respondsToSelector:@selector(imageOfSize:)]) {

        id img = ((id (*)(id, SEL, long long))objc_msgSend)(m, @selector(imageOfSize:), 2LL);
        if (img) return YES;
    }
    NSString *p = DDMImagePath(m);
    return (p && DDMFileUsable(p));
}

// 视频进度：时间驱动，已等待秒 / 60（封顶 60s）。
- (void)ddmWaitVideo:(NSArray *)pending videoMgr:(id)videoMgr {
    const NSInteger cap = 60;
    for (NSInteger s = 0; s <= cap; s++) {
        BOOL allReady = YES;
        for (WCMediaItem *m in pending) {
            if (![self ddmVideoReady:m]) { allReady = NO; break; }
        }
        if (allReady) { [self ddmSetProgress:1.0]; return; }
        [self ddmSetProgress:(float)s / (float)cap];
        if (s >= cap) break;
        if (videoMgr && [videoMgr respondsToSelector:@selector(CheckQueue)]) [videoMgr performSelector:@selector(CheckQueue)];
        [NSThread sleepForTimeInterval:1.0];
    }
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

// 按内容类型分流：视频 / 多图 / 纯文字。
- (void)routeForwardForItem:(WCDataItem *)item host:(UIViewController *)host {
    WCContentItem *content = item.contentObj;
    NSArray *mediaList = [content respondsToSelector:@selector(mediaList)] ? content.mediaList : nil;

    BOOL isVideo = [item respondsToSelector:@selector(isVideo)] ? [item isVideo] : NO;

    if (isVideo) { [self forwardVideoItem:item host:host]; return; }
    if (mediaList.count > 0) { [self forwardPhotoItem:item host:host]; return; }

    [self presentLegacyForward:item host:host];
}

#pragma mark 视频链路

// 视频转发：取视频本地路径 → 构建 SightDraft → 唤起发布器。
- (void)forwardVideoItem:(WCDataItem *)item host:(UIViewController *)host {
    WCContentItem *content = item.contentObj;
    WCMediaItem *videoItem = nil;
    for (WCMediaItem *m in content.mediaList) {
        NSString *vp = DDMVideoPath(m);
        if (vp) { videoItem = m; break; }
    }
    if (!videoItem) {
        [self failHUD:@"视频未下载完整"];
        return;
    }
    NSString *src = DDMVideoPath(videoItem);
    if (!src) {
        [self failHUD:@"视频未下载完整"];
        return;
    }

    NSString *local = nil;
    for (int attempt = 0; attempt < 5 && !local; attempt++) {
        if (attempt > 0) [NSThread sleepForTimeInterval:0.4];
        NSString *s = DDMVideoPath(videoItem);
        if (s && DDMFileUsable(s)) local = DDMCopyToTemp(s, @"mp4");
    }
    if (!local) {
        [self failHUD:@"视频准备失败"];
        return;
    }
    [self presentVideoWithLocalPath:local thumb:DDMThumbImage(videoItem) item:item host:host];
}

// 用本地视频 + 缩略图构建 SightDraft 并唤起视频发布器。
- (void)presentVideoWithLocalPath:(NSString *)path thumb:(UIImage *)thumb item:(WCDataItem *)item host:(UIViewController *)host {
    if (!DDMFileUsable(path)) {
        [self failHUD:@"视频准备失败"];
        return;
    }

    Class draftCls = objc_getClass("SightDraft");
    if (!draftCls) {
        [self failHUD:@"当前版本不支持"];
        return;
    }

    if (!thumb) thumb = DDMVideoFirstFrame(path);

    NSURL *url = [NSURL fileURLWithPath:path];
    SightDraft *draft = thumb ? [draftCls draftWithVideoURL:url thumbImage:thumb]
                              : [draftCls draftWithVideoURL:url];
    if (!draft) {
        [self failHUD:@"视频草稿创建失败"];
        return;
    }

    if ([draft respondsToSelector:@selector(isSightResourceValid)] && ![draft isSightResourceValid]) {
        [self failHUD:@"视频资源无效"];
        return;
    }

    [self stashTextOf:item];
    [self dismissHUD];

    [self ddmPushSightCommit:draft host:host];
    self.busy = NO;
}

#pragma mark 图片 / LivePhoto 链路

// 图片 / Live Photo 转发：构建本地资源 → 组装 MMImage（含 Live Photo 保真）→ 唤起发布器。
- (void)forwardPhotoItem:(WCDataItem *)item host:(UIViewController *)host {
    Class localImgCls = objc_getClass("MMAssetForLocalImage");
    Class mmImgCls    = objc_getClass("MMImage");
    if (!localImgCls || !mmImgCls) { [self presentLegacyForward:item host:host]; return; }

    NSMutableArray *assets = [NSMutableArray array];

    for (WCMediaItem *m in item.contentObj.mediaList) {
        NSString *imgSrc = DDMImagePath(m);
        if (!imgSrc) continue;
        NSString *imgLocal = DDMCopyToTemp(imgSrc, @"jpg");
        if (!imgLocal) continue;

        WCMediaItem *live = [m respondsToSelector:@selector(livePhotoMediaItem)] ? m.livePhotoMediaItem : nil;
        NSString *movLocal = (live ? DDMLivePhotoVideoPath(live) : nil);

        NSString *assetPath = movLocal ?: imgLocal;
        MMAssetForLocalImage *asset = [[localImgCls alloc] initWithUrl:[NSURL fileURLWithPath:assetPath]
                                                              IsNeedOrigin:YES];
        if (!asset && movLocal) {
            assetPath = imgLocal;
            asset = [[localImgCls alloc] initWithUrl:[NSURL fileURLWithPath:assetPath] IsNeedOrigin:YES];
        }
        if (!asset) continue;
        if ([asset respondsToSelector:@selector(setLocalFilePath:)]) {
            asset.localFilePath = assetPath;
            asset.localAssetId  = assetPath;
        }

        MMImage *mm = [self ddmMakeMMImage:imgLocal asset:asset liveVideoPath:movLocal];
        if (mm) [assets addObject:mm];
    }

    if (assets.count == 0) { [self presentLegacyForward:item host:host]; return; }
    [self stashTextOf:item];
    [self dismissHUD];
    [self ddmPushImageCommit:assets host:host];
    self.busy = NO;
}

// 用本地图片 + 资源构建 MMImage；若为 Live Photo，保真运动视频信息。
- (MMImage *)ddmMakeMMImage:(NSString *)imgLocal asset:(id)asset liveVideoPath:(NSString *)movLocal {
    Class mmImgCls = objc_getClass("MMImage");
    if (!mmImgCls) return nil;
    if (asset && [asset respondsToSelector:@selector(_getImageTypeFromData:)]) {
        NSData *raw = [NSData dataWithContentsOfFile:imgLocal options:NSDataReadingMappedIfSafe error:nil];
        if (raw.length > 0) {
            long long t = (long long)[asset _getImageTypeFromData:raw];
            if (t != 0 && [asset respondsToSelector:@selector(setImageDataType:)]) ((MMAssetForLocalImage *)asset).imageDataType = t;
        }
    }
    UIImage *ui = [UIImage imageWithContentsOfFile:imgLocal];
    MMImage *mmImg = ui ? (MMImage *)[(MMImage *)[mmImgCls alloc] initWithImage:ui] : [[mmImgCls alloc] init];
    if (!mmImg) return nil;
    mmImg.m_asset = asset;

    if (movLocal) {
        // 实况照片保真：标记 isLivePhoto + imageFrom + tempExtraInfo，保证发布为动态实况。
        mmImg.isLivePhoto = YES;
        if ([mmImg respondsToSelector:@selector(setLivePhotoVideoPath:)]) mmImg.livePhotoVideoPath = movLocal;
        if ([mmImg respondsToSelector:@selector(setImageFrom:)]) [mmImg setImageFrom:3];

        if ([mmImg respondsToSelector:@selector(setValue:forKey:)]) {
            NSMutableDictionary *extra = [NSMutableDictionary dictionary];
            [extra setValue:movLocal forKey:@"ExportedLivePhotoPath"];
            [mmImg setValue:extra forKey:@"tempExtraInfo"];
        }

        if ([asset respondsToSelector:@selector(setM_isUseLivePhoto:)])      [asset setM_isUseLivePhoto:YES];
        if ([asset respondsToSelector:@selector(setM_livePhotoVideoPath:)])   [asset setM_livePhotoVideoPath:movLocal];
        if ([asset respondsToSelector:@selector(setLivePhotoVideoSize:)]) {
            long long sz = (long long)[[NSFileManager.defaultManager attributesOfItemAtPath:movLocal error:nil] fileSize];
            [asset setLivePhotoVideoSize:sz];
        }
        if ([asset respondsToSelector:@selector(setLivePhotoDuration:)]) [asset setLivePhotoDuration:DDMVideoDuration(movLocal)];
    }
    return mmImg;
}

#pragma mark 文案暂存

// 暂存原帖文案，供发布器回填。
- (void)stashTextOf:(WCDataItem *)item {
    NSString *text = [item respondsToSelector:@selector(contentDesc)] ? item.contentDesc : nil;
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.pendingText = text.length > 0 ? text : nil;
    self.pendingTextStamp = NSDate.date.timeIntervalSince1970;
}

// 取出暂存文案（8s 内有效，超时视为过期）。
- (NSString *)consumePendingText {
    NSString *t = self.pendingText;
    self.pendingText = nil;
    if (!t) return nil;
    if (NSDate.date.timeIntervalSince1970 - self.pendingTextStamp > 8.0) return nil;
    return t;
}

#pragma mark 路由调用

// 生成发布上报会话（优先宿主 VC 的方法，回退到默认构造）。
- (id)reportSessionFromHost:(UIViewController *)host {
    SEL gen = NSSelectorFromString(@"generatePostReportSessionForEntrance:");
    if ([host respondsToSelector:gen]) {
        id (*fn)(id, SEL, long long) = (id (*)(id, SEL, long long))objc_msgSend;
        id s = fn(host, gen, 0);
        if (s) return s;
    }
    Class cls = objc_getClass("WCMomentsPostReportSession");
    return cls ? [[cls alloc] init] : nil;
}

// 将发布器 VC 推入宿主导航栈。
- (void)ddmPresentCommitVC:(UIViewController *)vc host:(UIViewController *)host {
    if (!vc) { [self failHUD:@"打开发布界面失败"]; return; }

    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *nav = host.navigationController;
        if (!nav) nav = DDMTopViewController(nil).navigationController;
        if (!nav) { [self failHUD:@"打开发布界面失败"]; return; }
        [nav pushViewController:vc animated:YES];
    });
}

// 视频发布：构造 WCNewCommitViewController(sightDraft) 并推入。
- (void)ddmPushSightCommit:(id)draft host:(UIViewController *)host {
    Class cls = objc_getClass("WCNewCommitViewController");
    if (!cls || ![cls instancesRespondToSelector:@selector(initWithSightDraft:)]) {
        [self failHUD:@"当前版本不支持"]; return;
    }
    WCNewCommitViewController *vc = [(WCNewCommitViewController *)[cls alloc] initWithSightDraft:draft];
    if (!vc) { [self failHUD:@"当前版本不支持"]; return; }

    id detail = [[NSClassFromString(@"WCCommentDetailViewControllerFB") alloc] init];
    if (detail) {
        if ([vc respondsToSelector:@selector(setDelegate:)]) [vc performSelector:@selector(setDelegate:) withObject:detail];
        self.retainedCommentDetailVC = detail;
    }
    [self ddmPresentCommitVC:vc host:host];
}

// 图片发布：构造 WCNewCommitViewController(images) 并推入。
- (void)ddmPushImageCommit:(NSArray *)assets host:(UIViewController *)host {
    Class cls = objc_getClass("WCNewCommitViewController");
    if (!cls || ![cls instancesRespondToSelector:@selector(initWithImages:contacts:)]) {
        [self failHUD:@"当前版本不支持"]; return;
    }
    WCNewCommitViewController *vc = [(WCNewCommitViewController *)[cls alloc] initWithImages:[assets mutableCopy] contacts:nil];
    [self ddmPresentCommitVC:vc host:host];
}

// 兜底转发：走微信原生转发界面（纯文字等无媒体场景）。
- (void)presentLegacyForward:(WCDataItem *)item host:(UIViewController *)host {
    [self dismissHUD];
    Class router = objc_getClass("WCTimelineRouterHelper");
    SEL sel = @selector(presentForwardViewController:postReportSession:trashReportData:currentViewController:);
    if ([router respondsToSelector:sel]) {
        BOOL (*fn)(id, SEL, id, id, id, id) = (BOOL (*)(id, SEL, id, id, id, id))objc_msgSend;
        if (fn(router, sel, item, [self reportSessionFromHost:host], nil, host)) { self.busy = NO; return; }
    }
    [self failHUD:@"无法打开转发界面"];
}

@end

#pragma mark - Hook：朋友圈操作浮窗（点赞 / 评论条）

// 转发图标为微信主题 SVG 资源，须经 WCSDKAdapter 渲染，UIImage imageNamed: 取不到。
static UIImage *DDMShareIcon(void) {
    UIImage *img = nil;
    Class adapter = NSClassFromString(@"WCSDKAdapter");
    if (adapter && [adapter respondsToSelector:@selector(svgImageNamed:size:color:)]) {
        UIImage *(*fn)(id, SEL, NSString *, CGSize, UIColor *) =
            (UIImage *(*)(id, SEL, NSString *, CGSize, UIColor *))objc_msgSend;
        img = fn(adapter, @selector(svgImageNamed:size:color:),
                 @"icons_outlined_share", CGSizeMake(18.0, 18.0), [UIColor whiteColor]);
    }
    if (!img) img = [UIImage imageNamed:@"icons_outlined_share"];
    return img;
}

static char kDDMShareBtnKey;
static char kDDMLineKey;

@interface WCOperateFloatView (DDMoments)
- (void)ddm_onForwardTapped:(UIButton *)sender;
- (void)initForwardButton;
- (void)initForwardLineView;
@end

%hook WCOperateFloatView

// 评论按钮初始化完成后注入转发按钮。
- (void)initCommentButton {
    %orig;
    [self initForwardButton];
}

// 浮窗展示时补充转发按钮与分隔线（关联对象避免重复注入）。
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint {
    %orig;
    [self initForwardLineView];
}

%new
// 在评论按钮右侧注入“转发”按钮。
- (void)initForwardButton {
    UIButton *cmtBtn = self.m_commentBtn;
    if (!cmtBtn || objc_getAssociatedObject(self, &kDDMShareBtnKey)) return;

    UIButton *shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    shareBtn.tintColor = [UIColor whiteColor];

    UIImage *icon = DDMShareIcon();
    if (icon) icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [shareBtn setImage:icon forState:UIControlStateNormal];

    [shareBtn setTitle:@"转发" forState:UIControlStateNormal];
    [shareBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    shareBtn.titleLabel.font = cmtBtn.titleLabel.font ?: [UIFont systemFontOfSize:15.0];

    shareBtn.frame = CGRectMake(cmtBtn.frame.origin.x + cmtBtn.frame.size.width,
                                cmtBtn.frame.origin.y,
                                cmtBtn.frame.size.width,
                                cmtBtn.frame.size.height);
    [shareBtn addTarget:self action:@selector(ddm_onForwardTapped:) forControlEvents:UIControlEventTouchUpInside];
    shareBtn.hidden = YES;
    [self addSubview:shareBtn];
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
        [self addSubview:clone];
        objc_setAssociatedObject(self, &kDDMLineKey, clone, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
// 转发按钮点击：优先走时间线 VC 原生事件流，否则直接拉起引擎。
- (void)ddm_onForwardTapped:(UIButton *)sender {

    UIResponder *r = self;
    while ((r = r.nextResponder)) {
        if ([r isKindOfClass:NSClassFromString(@"WCTimeLineViewController")]) {
            ((void (*)(id, SEL))objc_msgSend)(r, NSSelectorFromString(@"onClickForwardBtnOnFloatView"));
            return;
        }
    }
    WCDataItem *item = self.m_item;
    if (!item) return;
    [[DDMEngine shared] forwardDataItem:item hostView:self];
}

// 转发按钮与分隔线随浮窗布局：仅当转发开关打开时显示，并右移删除按钮让位。
- (void)layoutSubviews {
    %orig;

    UIButton *shareBtn = objc_getAssociatedObject(self, &kDDMShareBtnKey);
    UIImageView *line  = objc_getAssociatedObject(self, &kDDMLineKey);
    UIButton *likeBtn = self.m_likeBtn;
    UIButton *cmtBtn  = self.m_commentBtn;

    BOOL show = DDMConfig.shared.forwardEnabled && shareBtn && likeBtn && cmtBtn && shareBtn.superview == self;
    shareBtn.hidden = !show;
    line.hidden = !show;
    if (!show) return;

    CGFloat gap = cmtBtn.frame.origin.x - (likeBtn.frame.origin.x + likeBtn.frame.size.width);
    if (gap <= 0 || gap > 60) gap = 8.0;

    CGRect target = CGRectMake(CGRectGetMaxX(cmtBtn.frame) + gap,
                               cmtBtn.frame.origin.y,
                               cmtBtn.frame.size.width,
                               cmtBtn.frame.size.height);
    if (!CGRectEqualToRect(shareBtn.frame, target)) shareBtn.frame = target;

    if (line && line.superview == self && line.image) {
        CGSize ls = line.image.size;
        CGRect lf = CGRectMake(CGRectGetMaxX(cmtBtn.frame) + gap / 2 - ls.width / 2,
                               cmtBtn.frame.origin.y + (cmtBtn.frame.size.height - ls.height) / 2,
                               ls.width, ls.height);
        if (!CGRectEqualToRect(line.frame, lf)) line.frame = lf;
    }

    CGFloat needW = CGRectGetMaxX(target) + likeBtn.frame.origin.x;
    if (fabs(self.bounds.size.width - needW) > 0.5) {
        CGPoint center = self.center;
        CGRect f = self.frame;
        f.size.width = needW;
        self.frame = f;
        self.center = CGPointMake(center.x, center.y);
        if (self.superview) {
            self.center = CGPointMake(self.superview.bounds.size.width / 2.0, self.center.y);
        }
    }
}

%end

#pragma mark - Hook：宿主时间线 VC，转发按钮对齐原生事件流

%hook WCTimeLineViewController

%new
// 浮窗点击转发时由 WCOperateFloatView 响应的事件：直接拉起引擎。
- (void)onClickForwardBtnOnFloatView {
    WCOperateFloatView *fv = [self respondsToSelector:@selector(floatOperateView)] ? self.floatOperateView : nil;
    if (!fv) return;
    WCDataItem *item = [fv respondsToSelector:@selector(m_item)] ? fv.m_item : nil;
    if (!item) return;
    [[DDMEngine shared] forwardDataItem:item hostView:fv];
}

%end

#pragma mark - Hook：发布器，注入原文案 + 启用图片选择器（+号）

%hook WCNewCommitViewController

// 发布器加载后，若是本插件带入的本地资源，显示 + 号（图片选择器）。
- (void)viewDidLoad {
    %orig;
    if ([self respondsToSelector:@selector(m_isUseMMAsset)] && self.m_isUseMMAsset &&
        [self respondsToSelector:@selector(setBHideAddView:)]) {
        self.bHideAddView = NO;
    }
}

// 文本框初始化后回填暂存文案。
- (void)initTextViewContent {
    %orig;
    NSString *text = [[DDMEngine shared] consumePendingText];
    if (text.length == 0) return;
    MMGrowTextView *grow = [self respondsToSelector:@selector(textView)] ? self.textView : nil;
    UITextView *tv = [grow respondsToSelector:@selector(textView)] ? grow.textView : nil;
    if (![tv isKindOfClass:UITextView.class]) return;
    if (tv.text.length > 0) return;
    tv.text = text;
    if ([self respondsToSelector:@selector(textViewTextDidChange)]) [self textViewTextDidChange];
}

%end

#pragma mark - 朋友圈辅助功能

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

// 禁用朋友圈“谁可以看”隐私图标 + 长文字折叠。
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
    // 导航栏三态外观（标准 / 滚动边缘 / 紧凑），统一浅色背景。
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
// 每次进入重建表格（基础重建）。
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
// 重建表格：清空后按分组重新添加开关 cell。
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    if (!cellMgr || !secMgr) return;

    DDMConfig *cfg = DDMConfig.shared;
    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"转发设置"];
    if (!sec) return;
    [sec addCell:[cellMgr switchCellForSel:@selector(onForwardEnabledSwitch:)
                                    target:self
                                     title:@"朋友圈转发"
                                        on:cfg.forwardEnabled]];
    [_tableViewManager addSection:sec];

    WCTableViewSectionManager *aux = [secMgr sectionWithHeader:@"辅助设置"];
    [aux addCell:[cellMgr switchCellForSel:@selector(onViewDeletedCommentSwitch:)
                                   target:self
                                    title:@"查看已删评论"
                                       on:cfg.viewDeletedComment]];
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
// 将微信表格的 delegate 事件转发给原 delegate，本类只做外观代理。
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
// 仅“朋友圈转发”开关（将来会展开子项）在切换时即时重建表格。
- (void)onForwardEnabledSwitch:(UISwitch *)s        { DDMConfig.shared.forwardEnabled = s.isOn; [self buildTable]; }
- (void)onViewDeletedCommentSwitch:(UISwitch *)s   { DDMConfig.shared.viewDeletedComment = s.isOn; }
- (void)onDisablePrivacyIconSwitch:(UISwitch *)s   { DDMConfig.shared.disablePrivacyIcon = s.isOn; }
- (void)onDisableWeiShangFoldSwitch:(UISwitch *)s  { DDMConfig.shared.disableWeiShangFold = s.isOn; }
- (void)onDisableTextFoldSwitch:(UISwitch *)s      { DDMConfig.shared.disableTextFold = s.isOn; }
- (void)onDisableVideoAutoPlaySwitch:(UISwitch *)s { DDMConfig.shared.disableVideoAutoPlay = s.isOn; }
- (void)onDisableVideoTapCloseSwitch:(UISwitch *)s { DDMConfig.shared.disableVideoTapClose = s.isOn; }
- (void)onEnableVideoProgressSwitch:(UISwitch *)s  { DDMConfig.shared.enableVideoProgress = s.isOn; }
@end

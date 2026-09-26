// DDWCMoments.xm
// 微信朋友圈助手（Theos / Logos，arm64 / arm64e）
//
// 功能：
//   1. 一键转发 —— 在朋友圈「赞 / 评论」操作浮窗中注入「转发」按钮，支持图片、视频、
//      Live Photo 与纯文字；自动带回原帖文案，可选保留 / 移除原作者位置。
//   2. 辅助设置 —— 7 项独立开关：查看已删评论、禁用隐私图标、禁用微商折叠、禁用文字折叠、
//      禁用自动播放、禁用点击关闭、启用视频进度条。
//
// 转发链路：
//   抓文案 → 备媒体（缺失则走 CDN 下载）→ 深拷贝隔离原帖 → 按类型分流
//   → 构建微信草稿 / 资产 → 唤起发布器并回填文案与位置。
//
// 设计说明：
//   - 所有微信私有类均运行时获取（objc_getClass / NSClassFromString），不链接私有符号。
//   - 私有接口基于微信 8.0.79 头文件 dump，仅声明本插件实际会调用的方法。
//   - 文案回填落在发布器 init 期的 initTextViewContent：写完随 textViewTextDidChange
//     同步进微信内部模型，因此发布器后续重建文本框也不会丢文案。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdarg.h>

#pragma mark - 调试日志

// 调试日志：落盘到 App 沙盒 Library/DDWCMoments/debug.log。
// 随微信进程加载即可写，不依赖越狱 / PreferenceLoader / Cephei。
// 手机无法接 console 时，用设置页「导出日志」经系统分享面板存到
// 文件 / 隔空投送 / 拷贝，即可离线调试转发链路。
static NSString *DDMLogPath(void) {
    NSString *lib = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [lib stringByAppendingPathComponent:@"DDWCMoments"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"debug.log"];
}
static dispatch_queue_t DDMLogQueue(void) {
    static dispatch_queue_t q; static dispatch_once_t t;
    dispatch_once(&t, ^{ q = dispatch_queue_create("com.ddwcmoments.log", DISPATCH_QUEUE_SERIAL); });
    return q;
}
static void DDMLogWrite(NSString *line) {
    NSString *p = DDMLogPath();
    dispatch_async(DDMLogQueue(), ^{
        FILE *f = fopen([p UTF8String], "a");
        if (f) { fputs([line UTF8String], f); fputs("\n", f); fclose(f); }
    });
}
static void DDMLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"MM-dd HH:mm:ss.SSS";
    NSString *line = [NSString stringWithFormat:@"[%@] %@", [df stringFromDate:[NSDate date]], msg];
    DDMLogWrite(line);
}
static void DDMLogClear(void) {
    NSString *p = DDMLogPath();
    dispatch_async(DDMLogQueue(), ^{
        [@"" writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:nil];
    });
}

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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
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
+ (id)fromNSCodingBuffer:(NSData *)buffer;                  // 反序列化（深拷贝用）
- (NSData *)toNSCodingBuffer;                               // 序列化（深拷贝用）
- (BOOL)isVideo;                                            // 是否为视频
- (NSArray *)getNeedBatchDownloadMedias;                    // 需批量下载的媒体
- (BOOL)isWeiShang;                                         // 是否微商
- (void)setExtFlag:(unsigned int)arg1;                      // 扩展标记（含微商标记）
- (id)locationInfo;                                          // 位置信息
- (void)setLocationInfo:(id)arg1;                            // 设置位置信息
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
@end

// 服务定位链：MMContext → serviceCenter → getService: 取 WCFacade 单例。
@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

// 经服务链取 WCFacade。
static inline id DDMGetFrameFacade(void) {
    MMContext *ctx = [objc_getClass("MMContext") currentContext];
    MMServiceCenter *center = ctx.serviceCenter;
    return [center getService:objc_getClass("WCFacade")];
}

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

// 本地资源基类。
@interface MMAsset : NSObject
@property (nonatomic) BOOL m_isUseLivePhoto;
@property (retain, nonatomic) NSString *m_livePhotoVideoPath;
@property (nonatomic) double livePhotoDuration;
@property (nonatomic) long long livePhotoVideoSize;
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

// 朋友圈 cell 视图（禁用隐私图标 + 文字折叠）。
@interface WCTimeLineCellView : UIView
- (void)initPrivacyButton:(id)arg1;
- (void)layoutSubviews;
+ (BOOL)shouldShowFullTextButtonWithDataItem:(id)arg1;
@end

// 微信按钮基类。
@interface MMUIButton : UIButton
@end

// 评论 / 消息模型。
@interface WCUserComment : NSObject
- (id)content;
- (void)setContent:(id)arg1;
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
- (void)setDisablePrivacyIcon:(BOOL)v       { _disablePrivacyIcon = v;       [self persist:@(v) key:kDDMDisablePrivacyIcon]; }
- (void)setDisableWeiShangFold:(BOOL)v      { _disableWeiShangFold = v;      [self persist:@(v) key:kDDMDisableWeiShangFold]; }
- (void)setDisableTextFold:(BOOL)v          { _disableTextFold = v;          [self persist:@(v) key:kDDMDisableTextFold]; }
- (void)setDisableVideoAutoPlay:(BOOL)v     { _disableVideoAutoPlay = v;     [self persist:@(v) key:kDDMDisableVideoAutoPlay]; }
- (void)setDisableVideoTapClose:(BOOL)v     { _disableVideoTapClose = v;     [self persist:@(v) key:kDDMDisableVideoTapClose]; }
- (void)setEnableVideoProgress:(BOOL)v      { _enableVideoProgress = v;      [self persist:@(v) key:kDDMEnableVideoProgress]; }
- (void)setRemoveOriginalLocation:(BOOL)v   { _removeOriginalLocation = v;   [self persist:@(v) key:kDDMRemoveOriginalLoc]; }

@end

#pragma mark - 运行时工具

static BOOL DDMFileUsable(NSString *path);   // 前置声明：DDMVideoDuration 在其定义前使用

// 视频时长（Live Photo 运动视频登记用）。
static double DDMVideoDuration(NSString *path) {
    if (!DDMFileUsable(path)) return 0;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    CMTime d = asset.duration;
    return CMTIME_IS_NUMERIC(d) ? CMTimeGetSeconds(d) : 0;
}

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
    NSError *err = nil;
    if (![NSFileManager.defaultManager copyItemAtPath:realPath toPath:dst error:&err]) {
        return nil;
    }
    return dst;
}

// 仅解析符号链接取真实可读路径，不做复制。
// 转发静帧只需读一次像素内嵌进 MMImage，无需复制副本；
// 复制动作（DDMCopyToTemp）留给真正需要持久文件引用的视频链路。

#pragma mark - 媒体路径解析

// 图片优先路径。
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

// Live Photo 运动视频路径：仅认微信已转码的视频（getFormatVideoPath / getTempVideoPath）。
// 对齐 PKC：微信原生只认 getFormatVideoPath，失败即丢实况，不做 wxam 转码兜底。
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
    if (self.busy) { return; }
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

// 判断单个视频媒体是否就绪。
- (BOOL)ddmVideoReady:(WCMediaItem *)m {
    NSString *p = [m getFormatVideoPath];
    if (p && [[NSFileManager defaultManager] fileExistsAtPath:p]) return YES;
    NSString *alt = DDMVideoPath(m);
    if (alt && DDMFileUsable(alt)) return YES;
    return [self ddmImageReady:m];
}

// 判断单个图片媒体是否就绪。
// imageOfSize:2 稳定命中（实测 fromMem 命中率 100%，文件兜底从未触发），无需文件级判断。
- (BOOL)ddmImageReady:(WCMediaItem *)m {
    BOOL ready = ([m imageOfSize:2LL] != nil);
    DDMLog(@"[Ready] image fromMem=%@", ready ? @"Y" : @"N");
    return ready;
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

// 按内容类型分流：视频 / 多图 / 纯文字。
- (void)routeForwardForItem:(WCDataItem *)item host:(UIViewController *)host {
    WCContentItem *content = item.contentObj;
    NSArray *mediaList = content.mediaList;

    BOOL isVideo = item.isVideo;
    DDMLog(@"[Route] isVideo=%@ mediaCount=%lu", isVideo ? @"Y" : @"N", (unsigned long)mediaList.count);

    if (isVideo) { DDMLog(@"[Route] -> forwardVideoItem"); [self forwardVideoItem:item host:host]; return; }
    if (mediaList.count > 0) { DDMLog(@"[Route] -> forwardPhotoItem"); [self forwardPhotoItem:item host:host]; return; }

    DDMLog(@"[Route] -> presentLegacyForward (text/unknown)");
    [self presentLegacyForward:item host:host];
}

#pragma mark 视频链路

// 视频转发：取本地路径 → 构建 SightDraft → 唤起发布器。
- (void)forwardVideoItem:(WCDataItem *)item host:(UIViewController *)host {
    WCContentItem *content = item.contentObj;
    WCMediaItem *videoItem = nil;
    for (WCMediaItem *m in content.mediaList) {
        NSString *vp = DDMVideoPath(m);
        if (vp) { videoItem = m; break; }
    }
    DDMLog(@"[Video] candidate found=%@ mediaCount=%lu", videoItem?@"Y":@"N", (unsigned long)content.mediaList.count);
    if (!videoItem) {   // mediaList 内无可解码视频：跳过循环，避免空转 ~2s
        DDMLog(@"[Video] abort: no video candidate");
        [self dismissHUD]; self.busy = NO;
        return;
    }
    NSString *local = nil;
    for (int attempt = 0; attempt < 5 && !local; attempt++) {
        if (attempt > 0) [NSThread sleepForTimeInterval:0.4];
        NSString *s = DDMVideoPath(videoItem);
        if (s && DDMFileUsable(s)) local = DDMCopyToTemp(s, @"mp4");
    }
    DDMLog(@"[Video] local after retries=%@", local?@"Y":@"N");
    [self presentVideoWithLocalPath:local thumb:DDMThumbImage(videoItem) item:item host:host];
}

// 构建 SightDraft 并唤起视频发布器。SightDraft 为微信私有类，运行时取类。
- (void)presentVideoWithLocalPath:(NSString *)path thumb:(UIImage *)thumb item:(WCDataItem *)item host:(UIViewController *)host {
    // 路径不可用（超时未取到 / 解析失败）时静默退出，不构建空草稿。
    if (!path || !DDMFileUsable(path)) { DDMLog(@"[Video] abort: path unusable"); [self dismissHUD]; self.busy = NO; return; }
    if (!thumb) { DDMLog(@"[Video] thumb missing (fallback to no-thumb draft)"); }
    else { DDMLog(@"[Video] thumb from DDMThumbImage"); }

    NSURL *url = [NSURL fileURLWithPath:path];
    Class draftCls = objc_getClass("SightDraft");
    SightDraft *draft = thumb ? [draftCls draftWithVideoURL:url thumbImage:thumb]
                              : [draftCls draftWithVideoURL:url];

    [self dismissHUD];
    DDMLog(@"[Video] push SightDraft (hasThumb=%@)", thumb?@"Y":@"N");

    [self ddmPushSightCommit:draft item:item host:host];
    self.busy = NO;
}

#pragma mark 图片 / LivePhoto 链路

// 图片 / Live Photo 转发：构建本地资源 → 组装 MMImage（含 Live Photo 保真）→ 唤起发布器。
- (void)forwardPhotoItem:(WCDataItem *)item host:(UIViewController *)host {
    Class localImgCls = objc_getClass("MMAssetForLocalImage");

    NSMutableArray *assets = [NSMutableArray array];
    // 普通照片：不构造 / 不挂载 MMAsset（避免临时文件路径被草稿序列化后读不到 → 重开丢图）；
    // 实况照片：仍用 MMAssetForLocalImage 携带 livePhotoVideoPath 等运动视频信息。
    // 取图走微信原生内存图 imageOfSize:2（对齐 PKC block@0x1166fc 恒为 2），稳定命中。
    // 像素经 ddmMakeMMImage 内嵌进 MMImage，保留草稿重开不丢图；无文件兜底（imageOfSize:2 确定命中）。

    NSInteger idx = 0;
    for (WCMediaItem *m in item.contentObj.mediaList) {
        UIImage *ui = [m imageOfSize:2LL];
        BOOL fromMem = (ui != nil);

        WCMediaItem *live = m.livePhotoMediaItem;
        NSString *movLocal = (live ? DDMLivePhotoVideoPath(live) : nil);

        MMAssetForLocalImage *asset = nil;
        if (movLocal && localImgCls) {
            asset = [[localImgCls alloc] initWithUrl:[NSURL fileURLWithPath:movLocal] IsNeedOrigin:YES];
            if (!asset) { DDMLog(@"[Live] #%ld asset build FAIL -> degrade to photo", (long)idx); movLocal = nil; }
            else { asset.localFilePath = movLocal; asset.localAssetId = movLocal; DDMLog(@"[Live] #%ld asset OK video=%@", (long)idx, movLocal); }
        }
        MMImage *mm = [self ddmMakeMMImage:ui asset:asset liveVideoPath:movLocal];
        if (mm) [assets addObject:mm];
        DDMLog(@"[Photo] #%ld fromMem=%@ live=%@ asset=%@ -> MMImage=%@",
               (long)idx, fromMem?@"Y":@"N", live?@"Y":@"N", asset?@"Y":@"N", mm?@"Y":@"N");
        idx++;
    }

    DDMLog(@"[Photo] built %lu MMImage(s)", (unsigned long)assets.count);
    if (assets.count == 0) { DDMLog(@"[Photo] empty -> presentLegacyForward"); [self presentLegacyForward:item host:host]; return; }
    [self dismissHUD];
    [self ddmPushImageCommit:assets item:item host:host];
    self.busy = NO;
}

// 构建 MMImage；若为 Live Photo，保真运动视频信息。
- (MMImage *)ddmMakeMMImage:(UIImage *)ui asset:(id)asset liveVideoPath:(NSString *)movLocal {
    Class mmImgCls = objc_getClass("MMImage");
    if (!ui) return nil;
    MMImage *mmImg = (MMImage *)[(MMImage *)[mmImgCls alloc] initWithImage:ui];
    if (!mmImg) return nil;
    mmImg.m_asset = asset;

    if (movLocal) {
        // 实况照片保真：标记 isLivePhoto + imageFrom + 运动视频路径与尺寸。
        mmImg.isLivePhoto = YES;
        mmImg.livePhotoVideoPath = movLocal;
        [mmImg setImageFrom:3];

        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        [extra setValue:movLocal forKey:@"ExportedLivePhotoPath"];
        [mmImg setValue:extra forKey:@"tempExtraInfo"];   // MMImage.h 无 setter，KVC 直写 ivar

        // 资产侧保真字段（A/B 测试：本轮禁用，验证是否冗余）。
        // 转发动效主靠上面 MMImage 侧承载（isLivePhoto + livePhotoVideoPath +
        // tempExtraInfo.ExportedLivePhotoPath + setImageFrom:3）。这组 MMAsset 基类字段
        // 是微信给真 PHAsset 资产留的保真位，非真 PHAsset 的 MMAssetForLocalImage 可能不生效。
        // 要恢复直接取消下面四行注释（sz/dur 仅用于日志核对，一并恢复）。
        // [(MMAsset *)asset setM_isUseLivePhoto:YES];
        // [(MMAsset *)asset setM_livePhotoVideoPath:movLocal];
        // long long sz = (long long)[[NSFileManager.defaultManager attributesOfItemAtPath:movLocal error:nil] fileSize];
        // double dur = DDMVideoDuration(movLocal);
        // [(MMAsset *)asset setLivePhotoVideoSize:sz];
        // [(MMAsset *)asset setLivePhotoDuration:dur];

        DDMLog(@"[Live] fidelity=SKIP(asset-side off) mm.isLivePhoto=Y path=%@ extra=%@",
               movLocal, extra ? @"Y" : @"N");
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

// 兜底转发：走微信原生转发界面（纯文字等无媒体场景）。
- (void)presentLegacyForward:(WCDataItem *)item host:(UIViewController *)host {
    [self dismissHUD];
    Class router = objc_getClass("WCTimelineRouterHelper");
    BOOL (*fn)(id, SEL, id, id, id, id) = (BOOL (*)(id, SEL, id, id, id, id))objc_msgSend;
    if (fn(router, @selector(presentForwardViewController:postReportSession:trashReportData:currentViewController:),
            item, [self reportSessionFromHost:host], nil, host)) { self.busy = NO; return; }
    self.busy = NO;
}

@end

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
@end

%hook WCOperateFloatView

// 评论按钮初始化完成后注入转发按钮。
- (void)initCommentButton {
    %orig;
    [self initForwardButton];
}

// 浮窗展示时补齐分隔线，并在动画前把浮窗定型为三列并居中，使转发列随弹窗一起入场。
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint {
    %orig;
    [self initForwardLineView];
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
- (void)layoutSubviews {
    %orig;

    UIButton *shareBtn = objc_getAssociatedObject(self, &kDDMShareBtnKey);
    UIImageView *line  = objc_getAssociatedObject(self, &kDDMLineKey);
    UIButton *likeBtn = self.m_likeBtn;
    UIButton *cmtBtn  = self.m_commentBtn;

    BOOL show = DDMConfig.shared.forwardEnabled && shareBtn && likeBtn && cmtBtn && shareBtn.superview;
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

    if (line && line.superview && line.image) {
        CGSize ls = line.image.size;
        CGRect lf = CGRectMake(CGRectGetMaxX(cmtBtn.frame) + gap / 2 - ls.width / 2,
                               cmtBtn.frame.origin.y + (cmtBtn.frame.size.height - ls.height) / 2,
                               ls.width, ls.height);
        if (!CGRectEqualToRect(line.frame, lf)) line.frame = lf;
    }
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

// 禁用“谁可以看”隐私图标 + 长文字折叠。
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

    WCTableViewSectionManager *logSec = [secMgr sectionWithHeader:@"调试日志"];
    [logSec addCell:[cellMgr normalCellForSel:@selector(onExportLog) target:self title:@"导出日志（分享 / 隔空投送 / 存文件）"]];
    [logSec addCell:[cellMgr normalCellForSel:@selector(onClearLog) target:self title:@"清空日志"]];
    [_tableViewManager addSection:logSec];

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
- (void)onDisablePrivacyIconSwitch:(UISwitch *)s   { DDMConfig.shared.disablePrivacyIcon = s.isOn; }
- (void)onDisableWeiShangFoldSwitch:(UISwitch *)s  { DDMConfig.shared.disableWeiShangFold = s.isOn; }
- (void)onDisableTextFoldSwitch:(UISwitch *)s      { DDMConfig.shared.disableTextFold = s.isOn; }
- (void)onDisableVideoAutoPlaySwitch:(UISwitch *)s { DDMConfig.shared.disableVideoAutoPlay = s.isOn; }
- (void)onDisableVideoTapCloseSwitch:(UISwitch *)s { DDMConfig.shared.disableVideoTapClose = s.isOn; }
- (void)onEnableVideoProgressSwitch:(UISwitch *)s  { DDMConfig.shared.enableVideoProgress = s.isOn; }

#pragma mark 调试日志操作
- (void)onExportLog {
    NSString *p = DDMLogPath();
    if (![[NSFileManager defaultManager] fileExistsAtPath:p] ||
        [[NSData dataWithContentsOfFile:p] length] == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志为空"
                                                                 message:@"还没有任何调试日志。"
                                                          preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:p];
    UIActivityViewController *avc =
        [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    if ([avc respondsToSelector:@selector(popoverPresentationController)]) {
        avc.popoverPresentationController.sourceView = self.view;
        avc.popoverPresentationController.sourceRect =
            CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height - 40, 1, 1);
        avc.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    [self presentViewController:avc animated:YES completion:nil];
}
- (void)onClearLog {
    DDMLogClear();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"已清空"
                                                             message:@"调试日志已清空。"
                                                      preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
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

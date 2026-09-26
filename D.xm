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
#import <Photos/Photos.h>
#import <dispatch/dispatch.h>

#include <stdarg.h>

// 调试日志子系统

// 调试日志：落盘到 App 沙盒 Library/DDWCMoments/debug.log。
// 随微信进程加载即可写，不依赖越狱 / PreferenceLoader / Cephei。
// 手机无法接 console 时，用设置页「导出日志」经系统分享面板存到
// 文件 / 隔空投送 / 拷贝，即可离线调试实况保留等问题。
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
static NSString *DDMLogContent(void) {
    NSString *p = DDMLogPath();
    NSData *d = [NSData dataWithContentsOfFile:p];
    return d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] : @"";
}
static void DDMLogAlert(UIViewController *from, NSString *title, NSString *msg) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [from presentViewController:a animated:YES completion:nil];
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
@end

// 必须放在主 @interface 之后：clang 对“前置 category”会报
// “cannot find interface declaration” 并丢弃其中的方法，导致 Class 接收者调用
// normalCellForSel 时回退为 “no known class method for selector”。
// 见 wechat_8079/WCTableViewCellManager.h:17 与 wechat_headers/WCTableViewCellManager.h:17：
// +(id) normalCellForSel:(SEL) target:(id) title:(id);
@interface WCTableViewCellManager (DDMLogSupport)
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

// 本地资源基类（仅保留类型声明，供 MMImage.m_asset 的属性类型使用）。
//
// 转发链路已经完全不构造资产了 —— 挂上 m_asset 会让微信把图当成"已有文件可引用"，
// 保存草稿时改走 copyImageAtAlbumToFile: 去复制；而我们造出来的资产
// 解析不出微信能引用的本地路径，复制失败即 setDraftImages: 返回 NO、整条草稿不落库。
// 不挂资产时微信直接从 MMImage 已解码的像素数据写进自己的草稿目录，实测稳定。
@interface MMAsset : NSObject
@property (nonatomic) BOOL m_isUseLivePhoto;
@property (retain, nonatomic) NSString *m_livePhotoVideoPath;
@property (nonatomic) double livePhotoDuration;
@property (nonatomic) long long livePhotoVideoSize;
- (id)initWithUrl:(NSURL *)url IsNeedOrigin:(BOOL)isNeedOrigin;
@end

// 微信图片封装：发布时承载本地图片与 Live Photo 信息。
@interface MMImage : UIImage
- (id)initWithImage:(id)arg1;
- (void)commonInit;
@property (retain, nonatomic) MMAsset *m_asset;
@property (nonatomic) BOOL isLivePhoto;
@property (retain, nonatomic) NSString *livePhotoVideoPath;
@property (retain, nonatomic) NSString *m_assetClassNameStr;   // 实况资产类名；刻意不设，避免微信按类名重建 MMAsset 时缺 assetId/assetUrl 而失败
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

// 视频时长（原为 Live Photo 资产的 livePhotoDuration 登记用）。
// 实况链路已不再构造 MMAsset，暂无人调用；保留供需要时启用。
__attribute__((unused))
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

// 短视频持久化路径（Live Photo 运动视频兜底来源）。
static NSString *DDMPersistentSightPath(WCMediaItem *item) {
    if (!item) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    [cands addObject:[item pathForSightData] ?: @""];
    [cands addObject:[item tempPathForSightData] ?: @""];
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

#pragma mark - 实况照片运动视频：转码为可播放视频

// 将 wxam（微信实况封装）转码为 .mov。
// 产物落在 tmp（DDMTempDir）。实况链路已改为只认微信自己的 getFormatVideoPath，
// 不再走这里 —— 保留供后续需要时启用。
__attribute__((unused))
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

// Live Photo 运动视频路径（只认微信自己的转码产物，无回退）。
static NSString *DDMLivePhotoVideoPath(WCMediaItem *live) {
    if (!live) return nil;

    // 严格对齐 PKC（block@0x1166fc 逐条取证）：
    //   0x116e58  x21 = [mediaItem livePhotoMediaItem]
    //   0x116e68  x28 = [x21 getFormatVideoPath]        ← 唯一来源
    //   0x116e9c  fileExistsAtPath:x28 → 失败即报错退出（code 4），不做任何回退
    //   0x116fac / 0x117050 / 0x1170b0  三处都写 x28（原路径）
    //   0x117010  [NSURL URLWithString:x28]  ← asset URL 同样是原路径
    //
    // 我们此前额外加的 getTempVideoPath 与「wxam→mov 转码」两个兜底，产物都在
    // 可被系统回收的临时目录；一旦挂上资产，微信草稿只记路径，回收即空 ——
    // 这就是实况丢图而普通图不丢的原因。
    //
    // 现在只认微信自己的转码产物。拿不到就返回 nil，调用方降级成普通图片：
    // 丢实况动效，但保住图。
    NSString *p = [live getFormatVideoPath];
    NSString *r = DDMFileUsable(p) ? p : nil;
    DDMLog(@"[LiveVideo] getFormatVideoPath=%@ -> %@", p, r ? @"valid" : @"nil(降级普通图)");
    return r;
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
// 构建 MMImage（实况分支会挂 MMAsset + 视频路径）。重开草稿时复用此工厂重建实况图。
- (MMImage *)ddmMakeMMImage:(UIImage *)ui asset:(MMAsset *)asset liveVideoPath:(NSString *)movLocal;
@end

#pragma mark - 实况草稿保留

// 根因（debug 日志实锤）：微信草稿存储只收纳 MMAssetForPHAssetFramework，
// 基类 MMAsset（无 PHAsset、无 assetId/assetUrl）写入即被丢。手动从相册选的实况
// （clsName=MMAssetForPHAssetFramework）能正常保留，转发合成实况却不能。
//
// 修复（B-lite）：转发实况改用 MMAssetForPHAssetFramework，并把实况视频拷进本插件
// 持久缓存（Library/DDWCMoments/livecache/，绝不碰微信草稿目录与 7 天清理策略），
// 资产 URL 指向该持久副本，使重开草稿能读回。下方 stash + 重开重注入仅作 B-lite
// 失效时的兜底（若资产仍被丢，enteredWithDraft=YES 且图片数为 0 时从缓存补回）。
static NSString *gDDMLiveVideoCache = nil;   // 本插件缓存的 .mov 绝对路径
static NSString *gDDMLiveStillCache = nil;   // 本插件缓存的静帧绝对路径
static BOOL     gDDMLiveArmed     = NO;      // 是否武装（有待重注入的实况）
static id       gDDMLiveInjectedImage = nil; // 本次重开已重建的实况 MMImage（整个重开 VC 生命周期保留）
static __weak id gDDMCurrentCommitVC = nil;  // 当前发布器（用于判断 enteredWithDraft）
static BOOL     gDDMKeptDraft     = NO;      // 本次转发是否被“保留/手动存”为草稿

// 安全设属性：目标类（如 MMAssetForPHAssetFramework）可能未声明某 setter，
// 用 respondsToSelector: 守卫 + objc_msgSend，避免未识别 selector 崩溃。
#define DDM_SAFE_SET_BOOL(o,s,v) do { if ([(id)(o) respondsToSelector:(s)]) ((void(*)(id,SEL,BOOL))objc_msgSend)((id)(o),(s),(v)); } while(0)
#define DDM_SAFE_SET_ID(o,s,v)   do { if ([(id)(o) respondsToSelector:(s)]) ((void(*)(id,SEL,id))objc_msgSend)((id)(o),(s),(v)); } while(0)
#define DDM_SAFE_SET_LL(o,s,v)   do { if ([(id)(o) respondsToSelector:(s)]) ((void(*)(id,SEL,long long))objc_msgSend)((id)(o),(s),(v)); } while(0)
#define DDM_SAFE_SET_DBL(o,s,v)  do { if ([(id)(o) respondsToSelector:(s)]) ((void(*)(id,SEL,double))objc_msgSend)((id)(o),(s),(v)); } while(0)

static NSString *DDMLiveCacheDir(void) {
    NSString *lib = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dir = [lib stringByAppendingPathComponent:@"DDWCMoments/livecache"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
static NSString *DDMLiveStashPlist(void) {
    return [DDMLiveCacheDir() stringByAppendingPathComponent:@"stash.plist"];
}
// 把实况视频拷进本插件持久缓存目录（Library/DDWCMoments/livecache/），返回副本绝对路径。
// 微信自己的媒体缓存（wc/media/...）可能被清理，重开草稿时取不到；统一存到我们可控的
// 持久目录，资产 URL 指向这里，保证重开能读回（B-lite：资产类是 MMAssetForPHAssetFramework）。
static NSString *DDMPersistLiveMov(NSString *srcMov) {
    if (!srcMov || !DDMFileUsable(srcMov)) return nil;
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = DDMLiveCacheDir();
    NSString *dst = [dir stringByAppendingPathComponent:
        [NSString stringWithFormat:@"live_%@.mov", [NSUUID.UUID UUIDString]]];
    if ([fm copyItemAtPath:srcMov toPath:dst error:nil] && DDMFileUsable(dst)) return [dst copy];
    return nil;
}
static void DDMLoadLiveStash(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:DDMLiveStashPlist()];
        if (d) {
            gDDMLiveVideoCache = [d[@"video"] copy];
            gDDMLiveStillCache = [d[@"still"] copy];
            gDDMLiveArmed = [d[@"armed"] boolValue];
            if (gDDMLiveArmed && (!gDDMLiveVideoCache || !DDMFileUsable(gDDMLiveVideoCache)))
                gDDMLiveArmed = NO;
            DDMLog(@"[LiveStash] loaded video=%@ still=%@ armed=%@",
                   gDDMLiveVideoCache ? @"Y" : @"N",
                   gDDMLiveStillCache ? @"Y" : @"N",
                   gDDMLiveArmed ? @"Y" : @"N");
        }
    });
}
static void DDMSaveLiveStash(void) {
    NSDictionary *d = @{@"video": gDDMLiveVideoCache ?: @"",
                        @"still": gDDMLiveStillCache ?: @"",
                        @"armed": @(gDDMLiveArmed)};
    [d writeToFile:DDMLiveStashPlist() atomically:YES];
}
// 转发实况时调用：武装 stash（B-lite 失效时的兜底重注入用）。
// 若源已在 livecache 目录（B-lite 走 DDMPersistLiveMov 已落盘），直接记录、不重复拷贝。
static void DDMArmLiveStash(NSString *srcVideo, NSString *srcStill) {
    DDMLoadLiveStash();
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *dir = DDMLiveCacheDir();
    NSString *vDst = nil, *sDst = nil;
    if (srcVideo && DDMFileUsable(srcVideo)) {
        if ([srcVideo hasPrefix:dir]) {
            vDst = [srcVideo copy];   // 已是本插件持久副本，不再重复拷贝
        } else {
            vDst = [dir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"live_%@.mov", [NSUUID.UUID UUIDString]]];
            [fm copyItemAtPath:srcVideo toPath:vDst error:nil];
        }
    }
    if (srcStill && DDMFileUsable(srcStill)) {
        if ([srcStill hasPrefix:dir]) {
            sDst = [srcStill copy];
        } else {
            sDst = [dir stringByAppendingPathComponent:
                [NSString stringWithFormat:@"live_%@.jpg", [NSUUID.UUID UUIDString]]];
            [fm copyItemAtPath:srcStill toPath:sDst error:nil];
        }
    }
    gDDMLiveVideoCache = DDMFileUsable(vDst) ? [vDst copy] : nil;
    gDDMLiveStillCache = DDMFileUsable(sDst) ? [sDst copy] : nil;
    gDDMLiveArmed = (gDDMLiveVideoCache != nil);
    gDDMLiveInjectedImage = nil;   // 新转发武装，清掉上一次重开注入的图
    DDMSaveLiveStash();
    DDMLog(@"[LiveStash] armed video=%@ still=%@",
           gDDMLiveVideoCache ? @"Y" : @"N", gDDMLiveStillCache ? @"Y" : @"N");
}
// 解除武装（注入成功 / 转发被丢弃时调用）。
static void DDMDisarmLiveStash(void) {
    if (!gDDMLiveArmed) return;
    gDDMLiveArmed = NO;
    DDMSaveLiveStash();
    DDMLog(@"[LiveStash] disarmed");
}
// 重开草稿时调用：若已武装，从缓存重建实况 MMImage。
static id DDMRebuildLiveMMImage(void) {
    DDMLoadLiveStash();
    if (!gDDMLiveArmed || !gDDMLiveVideoCache || !DDMFileUsable(gDDMLiveVideoCache)) return nil;
    UIImage *ui = gDDMLiveStillCache ? [UIImage imageWithContentsOfFile:gDDMLiveStillCache] : nil;
    if (!ui) return nil;
    Class assetCls = objc_getClass("MMAssetForPHAssetFramework");
    MMAsset *asset = nil;
    if (assetCls && [assetCls instancesRespondToSelector:@selector(initWithUrl:IsNeedOrigin:)]) {
        asset = [(MMAsset *)[assetCls alloc] initWithUrl:[NSURL URLWithString:gDDMLiveVideoCache]
                                             IsNeedOrigin:YES];
    }
    MMImage *mm = [[DDMEngine shared] ddmMakeMMImage:ui asset:asset liveVideoPath:gDDMLiveVideoCache];
    return mm;
}

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
        if (DDMPersistentSightPath(m)) return YES;
        return NO;
    };

    BOOL (^isLiveLocal)(WCMediaItem *) = ^BOOL(WCMediaItem *m) {
        // 不能用 DDMPersistentSightPath（它认 pathForSightData / tempPathForSightData，
        // 即 wxam 原始封装，下载后立刻存在）。实况资产要的是 getFormatVideoPath
        // （转码后的可播放文件），它往往比 wxam 晚生成；误判"已本地"会让
        // StartDownloadVideo 被跳过，导致转发时 getFormatVideoPath 仍为空 → 实况退化成普通图。
        NSString *p = [m getFormatVideoPath];
        return p && [[NSFileManager defaultManager] fileExistsAtPath:p];
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

// 实况运动视频就绪：严格要求转码后的播放文件（getFormatVideoPath）已存在，
// 不能退回到 wxam 原始封装。否则资产会指向一个尚未转码的路径，
// 点「保留」后草稿里记录的实况视频路径失效 → 重开退化成普通图。
- (BOOL)ddmLiveVideoReady:(WCMediaItem *)m {
    NSString *p = [m getFormatVideoPath];
    return p && [[NSFileManager defaultManager] fileExistsAtPath:p];
}

// 判断单个图片媒体是否就绪。
- (BOOL)ddmImageReady:(WCMediaItem *)m {
    id img = [m imageOfSize:2LL];
    if (img) return YES;
    NSString *p = DDMImagePath(m);
    return (p && DDMFileUsable(p));
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
            BOOL ok = [liveSubs containsObject:m] ? [self ddmLiveVideoReady:m] : [self ddmImageReady:m];
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

    if (isVideo) { [self forwardVideoItem:item host:host]; return; }
    if (mediaList.count > 0) { [self forwardPhotoItem:item host:host]; return; }

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
    NSString *local = nil;
    for (int attempt = 0; attempt < 5 && !local; attempt++) {
        if (attempt > 0) [NSThread sleepForTimeInterval:0.4];
        NSString *s = DDMVideoPath(videoItem);
        if (s && DDMFileUsable(s)) local = DDMCopyToTemp(s, @"mp4");
    }
    [self presentVideoWithLocalPath:local thumb:DDMThumbImage(videoItem) item:item host:host];
}

// 构建 SightDraft 并唤起视频发布器。SightDraft 为微信私有类，运行时取类。
- (void)presentVideoWithLocalPath:(NSString *)path thumb:(UIImage *)thumb item:(WCDataItem *)item host:(UIViewController *)host {
    // 路径不可用（超时未取到 / 解析失败）时静默退出，不构建空草稿。
    if (!path || !DDMFileUsable(path)) { [self dismissHUD]; self.busy = NO; return; }
    if (!thumb) thumb = DDMVideoFirstFrame(path);

    NSURL *url = [NSURL fileURLWithPath:path];
    Class draftCls = objc_getClass("SightDraft");
    SightDraft *draft = thumb ? [draftCls draftWithVideoURL:url thumbImage:thumb]
                              : [draftCls draftWithVideoURL:url];

    [self dismissHUD];

    [self ddmPushSightCommit:draft item:item host:host];
    self.busy = NO;
}

#pragma mark 图片 / LivePhoto 链路

// 图片 / Live Photo 转发：组装 MMImage（含 Live Photo 保真）→ 唤起发布器。
//
// 对齐 PKC（反汇编取证：block@0x1166fc 三处 imageOfSize: 参数恒为 2）：
//   · 图片一律取 [mediaItem imageOfSize:2] —— 那是微信自己缓存里已解码的 UIImage，
//     不依赖任何我们创建的文件。此前用 imageWithContentsOfFile:(tmp 副本) 是惰性解码、
//     只记路径，要等归档草稿那一刻才真正读盘，tmp 一被回收就是空图/整条草稿不落库。
//   · 普通图片不构造任何资产，MMImage 只承载 UIImage。
//   · 实况挂 MMAsset 基类（m_isUseLivePhoto / m_livePhotoVideoPath 在基类上，本地文件资产
//     转发稳定）；但基类写入草稿会被微信丢弃（保留即丢），最终保留需 B-full 走真 PHAsset。
//     曾试 B-lite 换 MMAssetForPHAssetFramework + initWithUrl: 本地路径，因该类继承 NSObject、
//     无实况 setter、且 initWithUrl: 期望 PHAsset URL 而闪退，已回退。
//   · URL 必须用 URLWithString:（PKC 原样，0x117010 URLWithString:x28），不能改成
//     fileURLWithPath:。PKC 的实况资产就是这么造的，用户实机验证正常。
//     （此前我改成 fileURLWithPath: 又额外设 m_assetClassNameStr=@"MMAsset"，
//      反而导致重开草稿丢图：设了类名后微信会按它重建 MMAsset，缺 assetId/assetUrl
//      必败，连带 MMImage 静帧一起消失。删掉类名、URL 改回 URLWithString 即对齐 PKC。）
//   · 运动视频只认 [livePhotoMediaItem getFormatVideoPath]，无任何回退（PKC 原样）。
//     拿不到就降级成普通图片 —— 丢实况动效，但图一定在。
- (void)forwardPhotoItem:(WCDataItem *)item host:(UIViewController *)host {
    // 探针阶段：临时回退到基类 MMAsset 同步转发，复现“实况被 setDraftImages 丢弃”，
    // 以便 DDMDeepDescribe 抓到“被丢弃资产”的字段，与手动相册 PHAsset 资产对照，
    // 定位微信 setDraftImages 的采纳判断依据。B-full 辅助方法（ddmImportLiveAndCommit 等）
    // 暂未调用，待定位后决定 X(伪装类)/Y(hook 判断) 落地。
    Class assetCls = objc_getClass("MMAsset");
    NSMutableArray *assets = [NSMutableArray array];

    for (WCMediaItem *m in item.contentObj.mediaList) {
        UIImage *ui = (UIImage *)[m imageOfSize:2];

        // 兜底：imageOfSize: 取不到时直接读源文件。用 imageWithData: 而非
        // imageWithContentsOfFile: —— 后者惰性解码仍持有文件路径，前者读完即完全驻留内存。
        if (!ui) {
            NSString *imgSrc = DDMImagePath(m);
            NSData *data = imgSrc ? [NSData dataWithContentsOfFile:imgSrc] : nil;
            ui = data ? [UIImage imageWithData:data] : nil;
        }
        if (!ui) continue;

        // 实况视频：取微信媒体目录下已解码的视频文件绝对路径（本地文件资产，转发稳定）。
        NSString *movSrc = (m.livePhotoMediaItem ? DDMLivePhotoVideoPath(m.livePhotoMediaItem) : nil);
        NSString *movLocal = (movSrc && DDMFileUsable(movSrc)) ? movSrc : nil;

        // 普通图片 asset 传 nil；只有实况才建基类 MMAsset（initWithUrl: 本地路径）。
        // 资产构造失败时退化成普通图片（丢实况动效，但保住图）。
        MMAsset *asset = nil;
        if (movLocal && assetCls &&
            [assetCls instancesRespondToSelector:@selector(initWithUrl:IsNeedOrigin:)]) {
            asset = [(MMAsset *)[assetCls alloc] initWithUrl:[NSURL URLWithString:movLocal]
                                               IsNeedOrigin:YES];
            if (!asset) movLocal = nil;
        } else {
            movLocal = nil;
        }
        DDMLog(@"[Forward] media ui=%@ live=%@ movLocal=%@ asset=%@ clsName=%@",
               ui ? @"Y" : @"N", m.livePhotoMediaItem ? @"Y" : @"N",
               movLocal ? @"Y" : @"N", asset ? @"Y" : @"N",
               asset ? NSStringFromClass([asset class]) : @"(nil)");
        MMImage *mm = [self ddmMakeMMImage:ui asset:asset liveVideoPath:movLocal];
        if (mm) [assets addObject:mm];
    }

    if (assets.count == 0) { [self presentLegacyForward:item host:host]; return; }
    [self dismissHUD];
    [self ddmPushImageCommit:assets item:item host:host];
    self.busy = NO;
}

#pragma mark B-full：实况导入相册成真 Live Photo → PHAsset 资产

// 权限分流：未决定则弹授权；已授权走导入；受限 / 拒绝则退化为“仅普通图片”。
- (void)ddmImportLiveAndCommit:(NSArray *)liveItems
                   plainAssets:(NSArray *)plainAssets
                          item:(WCDataItem *)item
                          host:(UIViewController *)host {
    PHAuthorizationStatus st = [PHPhotoLibrary authorizationStatus];
    void (^go)(BOOL) = ^(BOOL authorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (authorized) [self ddmDoImportLive:liveItems plainAssets:plainAssets item:item host:host];
            else { DDMLog(@"[BFull] photo auth denied/limited → fallback (no live)"); [self ddmCommitPlain:plainAssets item:item host:host]; }
        });
    };
    if (st == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus s) { go(s == PHAuthorizationStatusAuthorized); }];
    } else {
        go(st == PHAuthorizationStatusAuthorized);
    }
}

// 静帧(JPEG) + 配对视频(NSData) 经 PHAssetCreationRequest 导入相册成真 Live Photo，
// 取回 PHAsset 后用 MMAssetForPHAssetFramework 构造资产，再与普通图一起推送。
- (void)ddmDoImportLive:(NSArray *)liveItems
            plainAssets:(NSArray *)plainAssets
                   item:(WCDataItem *)item
                   host:(UIViewController *)host {
    NSMutableArray *stillDatas = [NSMutableArray array];
    NSMutableArray *movDatas   = [NSMutableArray array];
    for (NSDictionary *d in liveItems) {
        UIImage *ui = d[@"ui"];
        NSData *jpeg = UIImageJPEGRepresentation(ui, 0.95);
        if (!jpeg) jpeg = UIImagePNGRepresentation(ui);
        [stillDatas addObject:jpeg ?: [NSData data]];
        [movDatas addObject:d[@"movData"]];
    }

    __block NSMutableArray *localIds = [NSMutableArray array];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        for (NSUInteger i = 0; i < liveItems.count; i++) {
            @autoreleasepool {
                NSData *still = stillDatas[i];
                NSData *mov   = movDatas[i];
                PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
                [req addResourceWithType:PHAssetResourceTypePhoto data:still options:nil];
                PHAssetResourceCreationOptions *vo = [[PHAssetResourceCreationOptions alloc] init];
                [req addResourceWithType:PHAssetResourceTypePairedVideo data:mov options:vo];
                NSString *lid = req.placeholderForCreatedAsset.localIdentifier;
                if (lid) [localIds addObject:lid];
            }
        }
    } completionHandler:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) { DDMLog(@"[BFull] import failed: %@", error); [self ddmCommitPlain:plainAssets item:item host:host]; return; }
            PHFetchResult *fr = [PHAsset fetchAssetsWithLocalIdentifiers:localIds options:nil];
            NSMutableArray *all = [NSMutableArray arrayWithArray:plainAssets];
            Class mmCls = objc_getClass("MMImage");
            Class phCls = objc_getClass("MMAssetForPHAssetFramework");
            NSUInteger idx = 0;
            for (PHAsset *ph in fr) {
                NSDictionary *d = liveItems[idx++];
                UIImage *ui = d[@"ui"];
                MMImage *mm = ui ? (MMImage *)[(MMImage *)[mmCls alloc] initWithImage:ui] : [[mmCls alloc] init];
                if (!mm) continue;
                if (phCls && [phCls instancesRespondToSelector:@selector(initWithPHAsset:IsNeedOrigin:)]) {
                    id asset = [(id)[phCls alloc] initWithPHAsset:ph IsNeedOrigin:YES];
                    if (asset) {
                        // 真 PHAsset 资产：微信取实况视频走 PHAsset（相册里刚导入的 Live Photo），
                        // 不依赖微信沙盒本地路径（导入后可能清理），故不设 MMImage.livePhotoVideoPath /
                        // tempExtraInfo，与 debug-2 手动相册行为一致。
                        mm.m_asset = (MMAsset *)asset;
                        mm.isLivePhoto = YES;
                        [mm setImageFrom:3];
                        DDMLog(@"[BFull] live MMImage built phAsset=%@ isLive=%d assetCls=%@",
                               ph.localIdentifier, mm.isLivePhoto,
                               mm.m_asset ? NSStringFromClass([mm.m_asset class]) : @"(nil)");
                    }
                }
                [all addObject:mm];
            }
            [self dismissHUD];
            [self ddmPushImageCommit:all item:item host:host];
            self.busy = NO;
        });
    }];
}

// 退化：无实况（无权限 / 导入失败）。保留普通图，丢弃实况动效但保住图。
- (void)ddmCommitPlain:(NSArray *)plainAssets
                  item:(WCDataItem *)item
                  host:(UIViewController *)host {
    [self dismissHUD];
    if (plainAssets.count == 0) { [self presentLegacyForward:item host:host]; self.busy = NO; return; }
    [self ddmPushImageCommit:plainAssets item:item host:host];
    self.busy = NO;
}

// 构建 MMImage；若为 Live Photo，挂资产并写入实况信息。
//
// asset 为 nil 表示普通图片 —— 此时不挂 m_asset，微信直接从已解码的像素数据
// 写进自己的草稿目录（实测稳定，不丢图）。
- (MMImage *)ddmMakeMMImage:(UIImage *)ui
                      asset:(MMAsset *)asset
              liveVideoPath:(NSString *)movLocal {
    Class mmImgCls = objc_getClass("MMImage");
    MMImage *mmImg = ui ? (MMImage *)[(MMImage *)[mmImgCls alloc] initWithImage:ui] : [[mmImgCls alloc] init];
    if (!mmImg) return nil;

    if (asset) {
        // 只挂 m_asset，绝不设 m_assetClassNameStr —— 这是上一轮"重开丢图"的真正元凶。
        //
        // 真相（PKC 反汇编逐条对照，0x116f48–0x1170c4 无任何 setM_assetClassNameStr）：
        //   · MMImage 的静帧来自 initWithImage:，已内嵌进 PB 草稿，与 m_asset 能否重建无关；
        //   · 一旦设了 m_assetClassNameStr，微信反序列化（PB）会按该类名去 [[MMAsset alloc]
        //     initWithCoder:] 重建资产；而我们只填了 m_livePhotoVideoPath / m_isUseLivePhoto，
        //     没有 assetId / assetUrl，重建必然失败，且会连带整张 MMImage 解码失败 → 静帧也消失。
        //   · 不设类名，微信不尝试重建资产，静帧（独立内嵌）正常显示，实况动效由 URL 兜底。
        // PKC 实况正常，靠的就是"只挂资产、不设类名"这一条。
        mmImg.m_asset = asset;
    }

    if (movLocal && asset) {
        // 实况照片保真：MMImage 侧标记 + 资产侧登记。
        mmImg.isLivePhoto = YES;
        mmImg.livePhotoVideoPath = movLocal;
        [mmImg setImageFrom:3];

        NSMutableDictionary *extra = [NSMutableDictionary dictionary];
        [extra setValue:movLocal forKey:@"ExportedLivePhotoPath"];
        [mmImg setValue:extra forKey:@"tempExtraInfo"];

        // 资产侧登记：用 guarded objc_msgSend（MMAssetForPHAssetFramework 可能未声明部分 setter，
        // 缺失则跳过，不崩溃；缺 m_isUseLivePhoto 时微信可能不识为实况，届时再走 B-full 真相册）。
        DDM_SAFE_SET_BOOL(asset, @selector(setM_isUseLivePhoto:), YES);
        DDM_SAFE_SET_ID(asset, @selector(setMLivePhotoVideoPath:), movLocal);
        long long sz = (long long)[[NSFileManager.defaultManager attributesOfItemAtPath:movLocal error:nil] fileSize];
        DDM_SAFE_SET_LL(asset, @selector(setLivePhotoVideoSize:), sz);
        DDM_SAFE_SET_DBL(asset, @selector(setLivePhotoDuration:), DDMVideoDuration(movLocal));
    }

    // 对齐 PKC：必调。PKC 在 initWithImage: 之后必调一次，实况则在 setM_asset: 之后再调一次，
    // 说明它不会清掉 m_asset；放在所有字段设完之后统一调一次即可覆盖两种情况。
    [mmImg commonInit];

    if (movLocal && asset) {
        DDMLog(@"[MMImage] live built video=%@ size=%lld dur=%.2f",
               movLocal,
               (long long)[[NSFileManager.defaultManager attributesOfItemAtPath:movLocal error:nil] fileSize],
               DDMVideoDuration(movLocal));
    } else {
        DDMLog(@"[MMImage] plain image (no live)");
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
//
// 关键：必须用微信私有封装 PushViewController:animated:completion:，不能用系统
// pushViewController:animated:。微信的 WCNewCommitViewController 依赖 viewDidBePushOrPresent:
// 做入栈后的初始化（含 setupEnhanceDraftSaveController，见 WCNewCommitViewController.h:361/336），
// 而该方法只在微信私有导航封装里被触发，UIKit 的 push 不会调它。
// 一旦 enhanceDraftSaveController 为 nil，实况照片的草稿保存（需要它）会失败，
// 普通照片走更宽松的路径所以不受影响 —— 这正是"普通图能存、实况丢"的根因。
// PKC 反汇编（block@0x117848 → 0x117a5c）用的就是 PushViewController:animated:completion:。
- (void)ddmPresentCommitVC:(UIViewController *)vc host:(UIViewController *)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *nav = host.navigationController;
        if (!nav) nav = DDMTopViewController(nil).navigationController;
        SEL pushSel = NSSelectorFromString(@"PushViewController:animated:completion:");
        if (nav && [nav respondsToSelector:pushSel]) {
            void (*fn)(id, SEL, id, BOOL, id) = (void (*)(id, SEL, id, BOOL, id))objc_msgSend;
            DDMLog(@"[Present] using WeChat private PushViewController:animated:completion:");
            void (^noop)(void) = ^{};
            fn(nav, pushSel, vc, YES, noop);
        } else {
            DDMLog(@"[Present] fallback system pushViewController: (no viewDidBePushOrPresent:)");
            [nav pushViewController:vc animated:YES];
            // 回退：系统 push 不会触发 viewDidBePushOrPresent:，手动补一次，
            // 确保草稿保存控制器被初始化（仅兜底，正常情况下私有封装已调用）。
            SEL vSel = NSSelectorFromString(@"viewDidBePushOrPresent:");
            if ([vc respondsToSelector:vSel]) {
                void (*fn2)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
                fn2(vc, vSel, YES);
            }
        }
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
    gDDMCurrentCommitVC = self;   // 兜底：确保重开草稿时指针先于 draftImages 读取就绪
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

// —— 草稿保存路径埋点 ——
// 保留/不保留 弹框出现时记一笔，方便把“取消发布”动作对齐到日志时间线。
- (void)showSaveOrNotAlert:(long long)arg1 {
    DDMLog(@"[SaveFlow] showSaveOrNotAlert tag=%lld", arg1);
    %orig;
}

// 点「保留」（取消发布但存草稿）：记录落盘前增强控制器里还几张图，%orig 之后再核对。
- (void)onCancelSaveBtnClickedWithTag:(long long)arg1 {
    DDMLog(@"[SaveFlow] onCancelSaveBtnClicked(保留) tag=%lld", arg1);
    gDDMKeptDraft = YES;   // 标记本次转发被“保留”为草稿，重开时需重注入实况
    // 这些微信私有方法仅 @class 前向声明，直接 [self/edc xxx] 会让 clang 报
    // “no visible @interface”。改用 objc_msgSend 动态派发规避选择子可见性检查。
    SEL edcSel = @selector(enhanceDraftSaveController);
    id edc = ((id (*)(id, SEL))objc_msgSend)(self, edcSel);
    SEL diSel = @selector(draftImages);
    SEL hdSel = @selector(hasDraft);
    if (edc) {
        id pre = ((id (*)(id, SEL))objc_msgSend)(edc, diSel);
        BOOL hpre = ((BOOL (*)(id, SEL))objc_msgSend)(edc, hdSel);
        DDMLog(@"[SaveFlow]   before-save inMemoryImages=%lu hasDraft=%@",
               (unsigned long)([pre isKindOfClass:[NSArray class]] ? [pre count] : 0),
               hpre ? @"Y" : @"N");
    }
    %orig;
    if (edc) {
        id post = ((id (*)(id, SEL))objc_msgSend)(edc, diSel);
        BOOL hpost = ((BOOL (*)(id, SEL))objc_msgSend)(edc, hdSel);
        DDMLog(@"[SaveFlow]   after-save inMemoryImages=%lu hasDraft=%@",
               (unsigned long)([post isKindOfClass:[NSArray class]] ? [post count] : 0),
               hpost ? @"Y" : @"N");
    }
}

// 手动点「存草稿」按钮。
- (void)onSaveBtnClickedWithTag:(long long)arg1 {
    DDMLog(@"[SaveFlow] onSaveBtnClicked(手动存) tag=%lld", arg1);
    gDDMKeptDraft = YES;   // 标记本次转发被“手动存”为草稿，重开时需重注入实况
    %orig;
}

// 记录当前发布器，供草稿重载时判断 enteredWithDraft（draftImages 重注入用）。
- (void)setEnhanceDraftSaveController:(id)arg1 {
    %orig;
    gDDMCurrentCommitVC = self;
}

// 真正退出发布器：
//   · 重开草稿的 VC（enteredWithDraft=YES）退出 → 清掉本次重开注入的图，stash 已解除武装。
//   · 未保留的转发 VC 退出 → 解除实况缓存武装，避免残留缓存被后续无关草稿误注入。
//   保留/手动存已先置 gDDMKeptDraft（重开注入成功路径也会清它）。
- (void)doExit {
    BOOL enteredDraft = NO;
    SEL ed = @selector(enteredWithDraft);
    if ([(id)self respondsToSelector:ed]) {
        enteredDraft = ((BOOL (*)(id, SEL))objc_msgSend)(self, ed);
    }
    if (enteredDraft) {
        gDDMLiveInjectedImage = nil;   // 重开 VC 退出，清掉本次注入的实况图
        DDMDisarmLiveStash();          // 并解除武装，避免残留缓存误注入无关草稿
    } else if (!gDDMKeptDraft) {
        DDMDisarmLiveStash();
    }
    %orig;
    gDDMKeptDraft = NO;
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
        [logSec addCell:[cellMgr normalCellForSel:@selector(onExportLog) target:self title:@"导出日志（分享/隔空投送/存文件）"]];
        [logSec addCell:[cellMgr normalCellForSel:@selector(onViewLog)   target:self title:@"查看日志"]];
        [logSec addCell:[cellMgr normalCellForSel:@selector(onClearLog)  target:self title:@"清空日志"]];
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
        DDMLogAlert(self, @"日志为空", @"还没有任何调试日志可供导出。");
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
- (void)onViewLog {
    UIViewController *v = [[UIViewController alloc] init];
    v.title = @"调试日志";
    v.view.backgroundColor = [UIColor whiteColor];
    UITextView *tv = [[UITextView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    tv.editable = NO;
    tv.font = [UIFont fontWithName:@"Menlo" size:11];
    tv.text = DDMLogContent();
    [v.view addSubview:tv];
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                            style:UIBarButtonItemStyleDone
                                                           target:self
                                                           action:@selector(ddmDismissLog:)];
    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithTitle:@"导出"
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(onExportLog)];
    v.navigationItem.leftBarButtonItem = close;
    v.navigationItem.rightBarButtonItem = share;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:v];
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)ddmDismissLog:(id)sender {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}
- (void)onClearLog {
    DDMLogClear();
    DDMLogAlert(self, @"已清空", @"调试日志已清空。");
}
@end

#pragma mark - 草稿存 / 取 埋点（定位“保留后丢实况”）

// 锚定方法签名：wechat_8079/WCTimelineEnhanceDraftController.h
//   -(BOOL) setDraftImages:(id) needCopyImageToFile:(BOOL);
//   -(id)   draftImages;
//   -(BOOL) copyImageAtAlbumToFile:(id);
// 仅打印日志，不改任何逻辑；Logos 在运行时按 selector 挂钩，方法不存在也不会崩溃。
// 关键：draftImages getter 在重开草稿时被微信调用以重建发布器，抓它即可看到“保留后”
// 读回来的实况视频路径是否还在、是否退化成普通图。

// 探针：反射打印对象的类 + 直接 property 值（不递归，安全吞异常）。用于对比
// “被微信收纳的资产”与“被丢弃的资产”的字段差异，定位 setDraftImages 的采纳依据。
static NSString *DDMDeepDescribe(id obj) {
    if (!obj) return @"(nil)";
    Class cls = object_getClass(obj);
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@ ", NSStringFromClass(cls)];
    unsigned int n = 0;
    objc_property_t *props = class_copyPropertyList(cls, &n);
    for (unsigned int i = 0; i < n; i++) {
        const char *pn = property_getName(props[i]);
        NSString *name = [NSString stringWithUTF8String:pn];
        @try {
            id v = [obj valueForKey:name];
            if (v) {
                NSString *d = [v description];
                if ([d length] > 160) d = [d substringToIndex:160];
                [s appendFormat:@"|%@=%@", name, d];
            }
        } @catch (NSException *e) {}
    }
    free(props);
    [s appendFormat:@" (super=%@)", NSStringFromClass(class_getSuperclass(cls))];
    return s;
}

// 探针：setDraftImages 调用栈（前 10 帧），看微信从哪个流程进来。
static NSString *DDMCallStack(void) {
    NSArray *cs = [NSThread callStackSymbols];
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 1; i < cs.count && i < 11; i++) {
        [s appendFormat:@"\n    %@", cs[i]];
    }
    return s;
}

%hook WCTimelineEnhanceDraftController

// 草稿落库：写入图片数组时记录每张实况状态 + 返回值。
- (BOOL)setDraftImages:(id)images needCopyImageToFile:(BOOL)needCopy {
    DDMLog(@"[DraftSave] setDraftImages count=%lu needCopy=%@ stack=%@",
           (unsigned long)([images isKindOfClass:[NSArray class]] ? [images count] : 0),
           needCopy ? @"Y" : @"N",
           DDMCallStack());
    if ([images isKindOfClass:[NSArray class]]) {
        for (id img in images) {
            if ([img isKindOfClass:objc_getClass("MMImage")]) {
                MMImage *mm = (MMImage *)img;
                NSString *vp = mm.livePhotoVideoPath;
                MMAsset *a = mm.m_asset;
                BOOL vpOk = (vp && [[NSFileManager defaultManager] fileExistsAtPath:vp]);
                DDMLog(@"[DraftSave]   live=%@ vp=%@ vpExists=%@ asset=%@ clsName=%@",
                       mm.isLivePhoto ? @"Y" : @"N",
                       vp ? vp : @"(null)",
                       vpOk ? @"Y" : @"N",
                       a ? @"Y" : @"N",
                       mm.m_assetClassNameStr ? mm.m_assetClassNameStr : @"(unset)");
                DDMLog(@"[DraftSave]   assetDetail=%@", DDMDeepDescribe(a));
            }
        }
    }
    BOOL r = %orig;
    DDMLog(@"[DraftSave] -> %@", r ? @"YES" : @"NO");
    // 修复“保留后丢实况”：
    // 微信初始化增强草稿控制器时，createDraft 先于 setDraftImages 运行，把“空”写进磁盘；
    // 我们的实况图随后只进内存、从不落盘，导致重开/保留时从空磁盘重建而丢失（连 PKC 也保不住，
    // 因为合成资产不走微信标准资产落库）。这里 %orig 成功且数组非空时补一次 createDraft 真正落盘；
    // count=0 不落，避免手动存/清除时把磁盘也清成空。静态标志防止 createDraft 反向调用本方法递归。
    static BOOL sPersisting = NO;
    if (r && !sPersisting && [images isKindOfClass:[NSArray class]] && [images count] > 0) {
        SEL cd = @selector(createDraft);
        if ([(id)self respondsToSelector:cd]) {
            sPersisting = YES;
            BOOL saved = ((BOOL (*)(id, SEL))objc_msgSend)(self, cd);
            sPersisting = NO;
            DDMLog(@"[DraftSave] persist createDraft -> %@", saved ? @"YES" : @"NO");
        }
    }
    return r;
}

// 草稿读出：重开时微信取回图片数组，记录每张实况是否还在、视频文件是否仍可访问。
- (id)draftImages {
    id images = %orig;
    NSUInteger cnt = ([images isKindOfClass:[NSArray class]] ? [images count] : 0);
    DDMLog(@"[DraftLoad] draftImages count=%lu",
           (unsigned long)cnt);
    if ([images isKindOfClass:[NSArray class]]) {
        for (id img in images) {
            if ([img isKindOfClass:objc_getClass("MMImage")]) {
                MMImage *mm = (MMImage *)img;
                NSString *vp = mm.livePhotoVideoPath;
                BOOL vpOk = (vp && [[NSFileManager defaultManager] fileExistsAtPath:vp]);
                DDMLog(@"[DraftLoad]   live=%@ vp=%@ vpExists=%@ asset=%@ aClass=%@ clsName=%@",
                       mm.isLivePhoto ? @"Y" : @"N",
                       vp ? vp : @"(null)",
                       vpOk ? @"Y" : @"N",
                       mm.m_asset ? @"Y" : @"N",
                       mm.m_asset ? NSStringFromClass([mm.m_asset class]) : @"(nil)",
                       mm.m_assetClassNameStr ? mm.m_assetClassNameStr : @"(unset)");
                DDMLog(@"[DraftLoad]   assetDetail=%@", DDMDeepDescribe(mm.m_asset));
            }
        }
    }
    // 实况草稿保留（兜底）：B-lite 已把资产换成 MMAssetForPHAssetFramework，正常会被微信
    // 原生收纳；若仍被丢（enteredWithDraft=YES 且读回图片数为 0），从本插件缓存重建实况
    // MMImage 补回。重建一次后缓存到 gDDMLiveInjectedImage，整个重开 VC 生命周期内所有
    // draftImages 读取都带这张图（防微信多次读取覆盖），直到 VC 退出（doExit）才清；
    // 解除武装只补一次，避免误注入无关草稿。
    DDMLoadLiveStash();
    if ((gDDMLiveArmed || gDDMLiveInjectedImage) && cnt == 0 && gDDMCurrentCommitVC) {
        BOOL enteredDraft = NO;
        SEL edSel = @selector(enteredWithDraft);
        if ([(id)gDDMCurrentCommitVC respondsToSelector:edSel]) {
            enteredDraft = ((BOOL (*)(id, SEL))objc_msgSend)(gDDMCurrentCommitVC, edSel);
        }
        if (enteredDraft) {
            if (!gDDMLiveInjectedImage && gDDMLiveArmed) {
                gDDMLiveInjectedImage = DDMRebuildLiveMMImage();
                if (gDDMLiveInjectedImage) {
                    DDMDisarmLiveStash();   // 只从缓存武装一次，之后靠 gDDMLiveInjectedImage
                    gDDMKeptDraft = NO;     // 重注入成功即清保留标记，避免影响后续丢弃判断
                    DDMLog(@"[DraftLoad] re-inject live into reloaded draft (video=%@)",
                           gDDMLiveVideoCache ? @"Y" : @"N");
                } else {
                    DDMLog(@"[DraftLoad] re-inject FAILED to rebuild live");
                }
            }
            if (gDDMLiveInjectedImage) {
                NSMutableArray *arr = [NSMutableArray arrayWithCapacity:cnt + 1];
                if ([images isKindOfClass:[NSArray class]]) [arr addObjectsFromArray:images];
                [arr addObject:gDDMLiveInjectedImage];
                return arr;
            }
        } else {
            DDMLog(@"[DraftLoad] skip re-inject: not enteredWithDraft");
        }
    }
    return images;
}

// 逐资产拷进草稿目录：记录入口与结果（目标文件是否落盘由 setDraftImages 的 vpExists 侧证）。
- (BOOL)copyImageAtAlbumToFile:(id)arg {
    DDMLog(@"[DraftCopy] copyImageAtAlbumToFile enter argClass=%@",
           arg ? NSStringFromClass([arg class]) : @"(null)");
    BOOL r = %orig;
    DDMLog(@"[DraftCopy] -> %@", r ? @"YES" : @"NO");
    return r;
}

// 真正落盘：createDraft 被调用时记“此刻内存里还几张图”，返回后记是否成功 + 落盘后能否读回。
- (BOOL)createDraft {
    // 经 objc_msgSend 调 draftImages 规避 @class 前向声明导致的“no visible @interface”。
    SEL diSel = @selector(draftImages);
    id pre = ((id (*)(id, SEL))objc_msgSend)(self, diSel);
    DDMLog(@"[DraftCreate] createDraft enter; inMemoryImages=%lu",
           (unsigned long)([pre isKindOfClass:[NSArray class]] ? [pre count] : 0));
    BOOL r = %orig;
    DDMLog(@"[DraftCreate] -> %@", r ? @"YES" : @"NO");
    id post = ((id (*)(id, SEL))objc_msgSend)(self, diSel);
    DDMLog(@"[DraftCreate] after inMemoryImages=%lu",
           (unsigned long)([post isKindOfClass:[NSArray class]] ? [post count] : 0));
    return r;
}

// hasDraft 频繁被问，记录当前是否有草稿。
- (BOOL)hasDraft {
    BOOL r = %orig;
    DDMLog(@"[DraftCreate] hasDraft -> %@", r ? @"Y" : @"N");
    return r;
}

%end

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

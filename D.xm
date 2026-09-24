
// DDWCMoments：为微信朋友圈添加转发能力。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
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
+ (id)defaultSection;
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
@end

@interface WCContentItem : NSObject
@property (retain, nonatomic) NSMutableArray *mediaList;   // 锚定 WCContentItem.h:71  -(id) mediaList;
@property (nonatomic) int type;                            // 锚定 WCContentItem.h:88  -(int) type;
+ (BOOL)isVideoType:(long long)type;                       // 锚定 WCContentItem.h:5   +(BOOL) isVideoType:(long long);
+ (BOOL)isPhotoType:(long long)type;                       // 锚定 WCContentItem.h:43  +(BOOL) isPhotoType:(long long);
+ (BOOL)isTypeThatSupportsLivePhoto:(long long)type;       // 锚定 WCContentItem.h:44  +(BOOL) isTypeThatSupportsLivePhoto:(long long);
@end

@interface WCDataItem : NSObject
@property (retain, nonatomic) WCContentItem *contentObj;   // 锚定 WCDataItem.h:215  -(id) contentObj;
@property (retain, nonatomic) NSString *contentDesc;       // 锚定 WCDataItem.h:213  -(id) contentDesc;
@property (retain, nonatomic) NSString *tid;               // 锚定 WCDataItem.h:279  -(id) tid;
@property (retain, nonatomic) NSString *username;          // 锚定 WCDataItem.h:288  -(id) username;
+ (id)fromNSCodingBuffer:(NSData *)buffer;                 // 锚定 WCDataItem.h:7    +(id) fromNSCodingBuffer:(id);
- (NSData *)toNSCodingBuffer;                              // 锚定 WCDataItem.h:281  -(id) toNSCodingBuffer;
- (BOOL)isVideo;                                           // 锚定 WCDataItem.h:182  -(BOOL) isVideo;
- (BOOL)isPhoto;                                           // 锚定 WCDataItem.h:165  -(BOOL) isPhoto;
- (BOOL)hasLivePhoto;                                      // 锚定 WCDataItem.h:124  -(BOOL) hasLivePhoto;
- (BOOL)isTypeThatSupportsLivePhoto;                       // 锚定 WCDataItem.h:177  -(BOOL) isTypeThatSupportsLivePhoto;
- (BOOL)isFeedOfMine;                                      // 锚定 WCDataItem.h:149  -(BOOL) isFeedOfMine;
- (NSArray *)getNeedBatchDownloadMedias;                   // 锚定 WCDataItem.h:238  -(id) getNeedBatchDownloadMedias;
@end

@interface WCMediaItem : NSObject
@property (nonatomic) int type;
@property (nonatomic) int subType;
@property (nonatomic) CGSize imgSize;
@property (nonatomic) double videoDuration;
@property (retain, nonatomic) WCMediaItem *livePhotoMediaItem;
@property (nonatomic) long long livePhotoStillImageTimeMs;
@property (nonatomic) double livePhotoVideoScale;
@property (readonly, nonatomic) BOOL isLivePhoto;
- (BOOL)hasData;
- (BOOL)hasHdData;
- (BOOL)hasUhdData;
- (BOOL)hasSight;
- (BOOL)hasPreview;
- (BOOL)isPreloadVideoTask;
- (long long)mediaType;
- (NSString *)mediaID;
- (NSString *)pathForExistData;
- (NSString *)pathForUhdData;
- (NSString *)pathForHdData;
- (NSString *)pathForData;
- (NSString *)pathForSightData;
- (NSString *)pathForPreview;
- (NSString *)tempPathForSightData;
- (NSString *)getFormatVideoPath;
- (NSString *)getTempVideoPath;
- (NSString *)getThumbImagePath;
@end

@interface WCFacade : NSObject
- (id)videoDownloadCdnMgrForCategory:(long long)arg1;
- (id)imageDownloadCdnMgrForCategory:(long long)arg1;
- (void)StartDownloadImage:(id)arg1 DownloadType:(long long)arg2;
@end

@interface WCDownloadVideoCDNMgr : NSObject
- (unsigned long long)StartDownloadVideo:(id)arg1;
- (BOOL)IsMediaItemInDownloadQueue:(id)arg1;
- (unsigned long long)StartDownloadVideo:(id)arg1 DownloadMode:(unsigned long long)arg2;
@end

@interface MMServiceCenter : NSObject
- (id)getService:(Class)arg1;
@end

@interface MMContext : NSObject
+ (id)currentContext;
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@end

// 经 MMContext → serviceCenter → getService: 取 WCFacade 单例。
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

@interface WCOperateFloatView : UIView
@property (readonly, nonatomic) UIButton *m_likeBtn;
@property (readonly, nonatomic) UIButton *m_commentBtn;
@property (readonly, nonatomic) WCDataItem *m_item;
@property (nonatomic, weak) UINavigationController *navigationController;
- (double)buttonWidth:(id)button;
- (void)hide;
- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint;
@end

@interface WCTimeLineViewController : UIViewController
@property (retain, nonatomic) WCOperateFloatView *floatOperateView;
- (void)onClickForwardBtnOnFloatView;
@end

@interface MMAsset : NSObject
@property (nonatomic) BOOL m_isNeedOriginImage;
@property (nonatomic) BOOL m_isUseLivePhoto;
@property (retain, nonatomic) NSString *m_livePhotoVideoPath;
@property (nonatomic) double livePhotoDuration;
@property (nonatomic) long long livePhotoVideoSize;
- (BOOL)isLivePhoto;
- (BOOL)canUseLivePhoto;
- (BOOL)isPicture;
- (BOOL)isVideo;
@end

@interface MMAssetForLocalImage : MMAsset
@property (retain, nonatomic) NSString *localAssetId;
@property (retain, nonatomic) NSString *localFilePath;
@property (nonatomic) long long imageDataType;
- (id)initWithAssetId:(NSString *)assetId localFilePath:(NSString *)path isNeedOrigin:(BOOL)isNeedOrigin;
- (id)initWithUrl:(NSURL *)url IsNeedOrigin:(BOOL)isNeedOrigin;
- (long long)_getImageTypeFromData:(NSData *)arg1;
@end

@interface MMImage : UIImage
- (id)initWithImage:(id)arg1;
@property (retain, nonatomic) MMAsset *m_asset;
@property (nonatomic) BOOL isLivePhoto;
@property (retain, nonatomic) NSString *livePhotoVideoPath;
@property (nonatomic) long long imageFrom;
@end

@interface WCMomentsPostAssetInfo : NSObject
- (id)initWithImage:(id)image fromSource:(long long)source;
@property (nonatomic) BOOL isLivePhoto;
@property (nonatomic) BOOL livePhotoOpt;
@property (nonatomic) long long livePhotoDurationMs;
@end

@interface WCUploadMedia : NSObject
- (id)init;
@property (nonatomic) int type;
@property (nonatomic) int subType;
@property (retain, nonatomic) NSData *buffer;
@property (retain, nonatomic) NSString *mediaSourcePath;
@property (copy, nonatomic) NSString *livePhotoUUID;
@property (nonatomic) long long subMediaType;
@property (readonly, nonatomic) BOOL isSubMedia;
@property (readonly, nonatomic) BOOL isMainMedia;
- (BOOL)saveMediaFromSourcePath:(id)arg1;
@end

@interface WCUploadMediaContainer : NSObject
@property (retain, nonatomic) WCUploadMedia *livePhotoUploadMedia;
@property (readonly, nonatomic) WCUploadMedia *mainUploadMedia;
- (id)initWithMainUploadMedia:(id)arg1;
@end

@interface SightDraft : NSObject
+ (id)draftWithVideoURL:(NSURL *)url thumbImage:(UIImage *)thumbImage;
+ (id)draftWithVideoURL:(NSURL *)url;
- (BOOL)isSightResourceValid;
@property (copy, nonatomic) NSString *draftItemVideoPath;
@end

@interface WCTimelineRouterHelper : NSObject
+ (BOOL)presentCommitViewController:(BOOL)showLocation
                          sightDraft:(id)sightDraft
                   postReportSession:(id)session
                    trashReportData:(id)trash
               currentViewController:(id)vc
                        withExtBean:(id)extBean;
+ (BOOL)presentCommitViewController:(BOOL)showLocation
                            arrImage:(id)arrImage
                   postReportSession:(id)session
                    trashReportData:(id)trash
               currentViewController:(id)vc
                        withExtBean:(id)extBean;
+ (BOOL)presentForwardViewController:(id)dataItem
                   postReportSession:(id)session
                     trashReportData:(id)trash
               currentViewController:(id)vc;
@end

@interface MMGrowTextView : UIView
@property (retain, nonatomic) UITextView *textView;
@end

@interface WCNewCommitViewController : UIViewController
@property (retain, nonatomic) MMGrowTextView *textView;
@property (nonatomic) BOOL m_isUseMMAsset;
@property (nonatomic) BOOL bHideAddView;
- (void)initTextViewContent;
- (void)textViewTextDidChange;
- (instancetype)initWithImages:(id)arg1 contacts:(id)arg2;
- (instancetype)initWithSightDraft:(id)arg1;
@end

@interface MMLoadingView : UIView
@property (nonatomic, getter=isLoading) BOOL loading;
@property (nonatomic) BOOL ignoreInteractionEventsWhenLoading;
@property (retain, nonatomic) NSString *text;
- (void)startLoading;
- (void)stopLoading;
- (void)stopLoadingAndShowError:(NSString *)text duration:(double)duration;
- (void)stopLoadingAndShowOK:(NSString *)text duration:(double)duration;
@end

#pragma mark - 配置

static NSString * const kDDMEnabled = @"DDForward_Enabled";

@interface DDMConfig : NSObject
@property (assign, nonatomic) BOOL enabled;
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
        _enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDMEnabled];
    }
    return self;
}

- (void)persist:(id)value key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setEnabled:(BOOL)v { _enabled = v; [self persist:@(v) key:kDDMEnabled]; }

@end

#pragma mark - 运行时工具

static BOOL DDMFileUsable(NSString *path);
static NSString *DDMLivePhotoVideoPath(WCMediaItem *live);

static double DDMVideoDuration(NSString *path) {
    if (!DDMFileUsable(path)) return 0;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    CMTime d = asset.duration;
    return CMTIME_IS_NUMERIC(d) ? CMTimeGetSeconds(d) : 0;
}

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

static void DDMCleanTempDir(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *name in [fm contentsOfDirectoryAtPath:DDMTempDir() error:nil]) {
        [fm removeItemAtPath:[DDMTempDir() stringByAppendingPathComponent:name] error:nil];
    }
}

static BOOL DDMFileUsable(NSString *path) {
    if (path.length == 0) return NO;
    NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if (!attr) return NO;

    if (![attr[NSFileType] isEqual:NSFileTypeRegular]) return NO;
    return [attr fileSize] > 0;
}

static NSString *DDMFirstUsablePath(NSArray<NSString *> *candidates) {
    for (NSString *p in candidates) if (DDMFileUsable(p)) return p;
    return nil;
}

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

static NSString *DDMImagePath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForData)])      [cands addObject:[item pathForData] ?: @""];
    if ([item respondsToSelector:@selector(pathForExistData)]) [cands addObject:[item pathForExistData] ?: @""];
    return DDMFirstUsablePath(cands);
}

static NSString *DDMVideoPath(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForSightData)])    [cands addObject:[item pathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(getFormatVideoPath)])  [cands addObject:[item getFormatVideoPath] ?: @""];
    if ([item respondsToSelector:@selector(tempPathForSightData)])[cands addObject:[item tempPathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(getTempVideoPath)])    [cands addObject:[item getTempVideoPath] ?: @""];
    return DDMFirstUsablePath(cands);
}

static NSString *DDMLiveVideoPath(WCMediaItem *live) {
    if (!live) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    if ([live respondsToSelector:@selector(pathForSightData)])     [cands addObject:[live pathForSightData] ?: @""];
    if ([live respondsToSelector:@selector(tempPathForSightData)]) [cands addObject:[live tempPathForSightData] ?: @""];
    if ([live respondsToSelector:@selector(getFormatVideoPath)])   [cands addObject:[live getFormatVideoPath] ?: @""];
    if ([live respondsToSelector:@selector(getTempVideoPath)])    [cands addObject:[live getTempVideoPath] ?: @""];
    return DDMFirstUsablePath(cands);
}

static NSString *DDMPersistentSightPath(WCMediaItem *item) {
    if (!item) return nil;
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(pathForSightData)])     [cands addObject:[item pathForSightData] ?: @""];
    if ([item respondsToSelector:@selector(tempPathForSightData)]) [cands addObject:[item tempPathForSightData] ?: @""];
    return DDMFirstUsablePath(cands);
}

static UIImage *DDMThumbImage(WCMediaItem *item) {
    NSMutableArray *cands = [NSMutableArray array];
    if ([item respondsToSelector:@selector(getThumbImagePath)]) [cands addObject:[item getThumbImagePath] ?: @""];
    if ([item respondsToSelector:@selector(pathForPreview)])    [cands addObject:[item pathForPreview] ?: @""];
    NSString *p = DDMFirstUsablePath(cands);
    return p ? [UIImage imageWithContentsOfFile:p] : nil;
}

#pragma mark - 实况照片运动视频：转码为真实可播放视频

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
@property (nonatomic, weak) UIWindow *ddmWindow;   // 进度卡挂载的窗口，由触发浮窗直接给出，不再遍历窗口列表
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

#pragma mark HUD（下载进度条：圆角浮卡 + 类型化标题 + 计数/预耗时 + 灰底绿条 + 绿色百分比，支持深色模式，尺寸跟随窗口）

static const NSInteger kDDMProgressHUDTag = 0x44444602;

typedef NS_ENUM(NSInteger, DDMMediaKind) {
    DDMMediaKindImages  = 0,
    DDMMediaKindVideo   = 1,
    DDMMediaKindLive    = 2,
};

// 深色模式配色：直接走动态色
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

// 进度浮卡（DDMProgressCardView，定义见本文件前部）的布局逻辑在 layoutSubviews 内完成，
// 窗口尺寸变化时自动按当前宽度重排子视图。

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
    // 宽度跟随窗口变化：左右各留 16 边距（autoresizing 默认固定左右边距、仅宽度弹性）。
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

- (void)dismissHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *card = [self ddmProgressHUD];
        if (!card) return;
        [UIView animateWithDuration:0.2 animations:^{ card.alpha = 0.0; }
                         completion:^(BOOL fin){ [card removeFromSuperview]; }];
    });
}

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

// 经 WCFacade 触发 CDN 下载：视频/实况走视频管理器，图片走取图管理器。
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

- (BOOL)ddmVideoReady:(WCMediaItem *)m {
    if ([m respondsToSelector:@selector(getFormatVideoPath)]) {
        NSString *p = [m getFormatVideoPath];
        if (p && [[NSFileManager defaultManager] fileExistsAtPath:p]) return YES;
    }
    NSString *p = DDMVideoPath(m) ?: DDMLiveVideoPath(m);
    if (p && DDMFileUsable(p)) return YES;
    return [self ddmImageReady:m];
}

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

// 图片/实况进度：已就绪数 / 总数（封顶 60s）。
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

- (void)stashTextOf:(WCDataItem *)item {
    NSString *text = [item respondsToSelector:@selector(contentDesc)] ? item.contentDesc : nil;
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.pendingText = text.length > 0 ? text : nil;
    self.pendingTextStamp = NSDate.date.timeIntervalSince1970;
}

- (NSString *)consumePendingText {
    NSString *t = self.pendingText;
    self.pendingText = nil;
    if (!t) return nil;
    if (NSDate.date.timeIntervalSince1970 - self.pendingTextStamp > 8.0) return nil;
    return t;
}

#pragma mark 路由调用

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

- (void)ddmPresentCommitVC:(UIViewController *)vc host:(UIViewController *)host {
    if (!vc) { [self failHUD:@"打开发布界面失败"]; return; }

    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *nav = host.navigationController;
        if (!nav) nav = DDMTopViewController(nil).navigationController;
        if (!nav) { [self failHUD:@"打开发布界面失败"]; return; }
        [nav pushViewController:vc animated:YES];
    });
}

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

- (void)ddmPushImageCommit:(NSArray *)assets host:(UIViewController *)host {
    Class cls = objc_getClass("WCNewCommitViewController");
    if (!cls || ![cls instancesRespondToSelector:@selector(initWithImages:contacts:)]) {
        [self failHUD:@"当前版本不支持"]; return;
    }
    WCNewCommitViewController *vc = [(WCNewCommitViewController *)[cls alloc] initWithImages:[assets mutableCopy] contacts:nil];
    [self ddmPresentCommitVC:vc host:host];
}

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

#pragma mark - Hook：朋友圈操作浮窗（点赞/评论条）

// 转发图标：是微信主题 SVG 资源，
// 须经 WCSDKAdapter +svgImageNamed:size:color: 渲染，UIImage imageNamed: 取不到。
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

- (id)initWithParams:(id)params {
    self = %orig;
    if (!self) return self;
    return self;
}

- (void)initCommentButton {
    %orig;
    [self initForwardButton];
}

- (void)showWithItemData:(id)itemData tipPoint:(struct CGPoint)tipPoint {
    %orig;
    [self initForwardLineView];
}

%new
// 在评论按钮右侧注入"转发"按钮，图标。
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

- (void)layoutSubviews {
    %orig;

    UIButton *shareBtn = objc_getAssociatedObject(self, &kDDMShareBtnKey);
    UIImageView *line  = objc_getAssociatedObject(self, &kDDMLineKey);
    UIButton *likeBtn = self.m_likeBtn;
    UIButton *cmtBtn  = self.m_commentBtn;

    BOOL show = DDMConfig.shared.enabled && shareBtn && likeBtn && cmtBtn && shareBtn.superview == self;
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

- (void)viewDidLoad {
    %orig;
    if ([self respondsToSelector:@selector(m_isUseMMAsset)] && self.m_isUseMMAsset &&
        [self respondsToSelector:@selector(setBHideAddView:)]) {
        self.bHideAddView = NO;
    }
}

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
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");
    if (!cellMgr || !secMgr) return;

    DDMConfig *cfg = DDMConfig.shared;
    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"转发设置"];
    if (!sec) return;
    [sec addCell:[cellMgr switchCellForSel:@selector(onEnabledSwitch:)
                                    target:self
                                     title:@"朋友圈转发"
                                        on:cfg.enabled]];
    [_tableViewManager addSection:sec];

    [_tableViewManager reloadTableView];
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
- (void)onEnabledSwitch:(UISwitch *)sender { DDMConfig.shared.enabled = sender.isOn; }
@end

#pragma mark - 注册

// 注册设置页：朋友圈转发开关。
%ctor {
    @autoreleasepool {
        Class mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD朋友圈助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDMSettingsViewController"];
        }
    }
}

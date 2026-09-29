// ============================================================================
//  DDShell.xm —— 模板套壳（截图/录屏后套模板并保存到相册）  v1.0.0
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  功能逆向自 ZDY_v1.3.7.dylib 的「模板套壳」模块：
//    类     : ScreenshotShellHelper / SSShellLibraryVC / SSShellEditorVC
//             SSShellLibCell / SSShellHandleOverlay / SSShellImportResultVC
//    配置键 : com.custom.dlfs.screenshotShellEnabled        启用模板套壳
//             com.custom.dlfs.screenshotShellAutoShell      截图/录屏自动套壳
//             com.custom.dlfs.screenshotShellSelectedIds    套壳素材库已勾选
//             com.custom.dlfs.screenshotShellStretchFill    （ZDY 有，本插件不实现：
//                                                             渲染固定为等比铺满，不做拉伸变形）
//    模板   : ss_shell_%@.png（图片模板）/ ss_shell_%@.mp4（视频模板）
//             template_width / template_height
//    保存   : PHPhotoLibrary performChanges:completionHandler:
//             creationRequestForAssetFromImage: / FromVideoAtFileURL:
//    录屏检测: UIScreen.isCaptured（capturedDidChange）
//
//  本插件不 hook 微信内部逻辑，纯系统层实现：
//    截图 → UIApplicationUserDidTakeScreenshotNotification
//    录屏 → UIScreenCapturedDidChangeNotification（isCaptured 由 YES→NO）
//    取相册最新截图/录屏 → 叠加模板 → 存回相册
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明（入口用）

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(NSInteger)style;
- (void)clearAllSection;
- (id)getTableView;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
+ (id)centerCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@property (nonatomic, retain) id userInfo;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置

static NSString *const kDDShellEnabled     = @"DDShellEnabled";      // 启用模板套壳
static NSString *const kDDShellAuto        = @"DDShellAutoShell";    // 截图/录屏自动套壳
static NSString *const kDDShellSelectedTpl = @"DDShellSelectedTpl";  // 当前勾选的模板文件名

@interface DDShellConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL autoShell;
@property (nonatomic, copy) NSString *selectedTpl;
@end

@implementation DDShellConfig

+ (instancetype)shared {
    static DDShellConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _enabled = [ud objectForKey:kDDShellEnabled] ? [ud boolForKey:kDDShellEnabled] : NO;
        [ud setBool:_enabled forKey:kDDShellEnabled];
        _autoShell = [ud objectForKey:kDDShellAuto] ? [ud boolForKey:kDDShellAuto] : YES;
        [ud setBool:_autoShell forKey:kDDShellAuto];
        _selectedTpl = [ud stringForKey:kDDShellSelectedTpl] ?: @"";
        [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v {
    _enabled = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDShellEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setAutoShell:(BOOL)v {
    _autoShell = v;
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:kDDShellAuto];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setSelectedTpl:(NSString *)v {
    _selectedTpl = [v copy] ?: @"";
    [[NSUserDefaults standardUserDefaults] setObject:_selectedTpl forKey:kDDShellSelectedTpl];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 模板管理（素材库）

// 模板存放目录：Documents/DDShellTemplates/，与 ZDY 的 ss_shell_%@.png 同思路
static NSString *DD_TplDir(void) {
    static NSString *dir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        dir = [doc stringByAppendingPathComponent:@"DDShellTemplates"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

// 素材库全部模板（png/jpg）
static NSArray<NSString *> *DD_AllTemplates(void) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:DD_TplDir() error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in files) {
        if ([f.lowercaseString hasSuffix:@".png"] || [f.lowercaseString hasSuffix:@".jpg"] ||
            [f.lowercaseString hasSuffix:@".jpeg"]) {
            [out addObject:f];
        }
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

// 当前勾选的模板；未勾选时默认取第一个
static NSString *DD_ActiveTemplate(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    if (sel.length && [[NSFileManager defaultManager] fileExistsAtPath:[DD_TplDir() stringByAppendingPathComponent:sel]]) {
        return sel;
    }
    return [DD_AllTemplates() firstObject] ?: @"";
}

static UIImage *DD_LoadTemplate(NSString *name) {
    if (!name.length) return nil;
    NSString *path = [DD_TplDir() stringByAppendingPathComponent:name];
    NSData *d = [NSData dataWithContentsOfFile:path];
    return d ? [UIImage imageWithData:d] : nil;
}

// 从相册导入模板（存为 png，保留透明通道）
static void DD_ImportTemplateFromImage(UIImage *img, void (^done)(NSString *name)) {
    if (!img) { if (done) done(nil); return; }
    NSString *name = [NSString stringWithFormat:@"dd_shell_%@.png", [[NSUUID UUID] UUIDString]];
    NSData *png = UIImagePNGRepresentation(img);
    if (!png) { if (done) done(nil); return; }
    BOOL ok = [png writeToFile:[DD_TplDir() stringByAppendingPathComponent:name] atomically:YES];
    if (done) done(ok ? name : nil);
}

#pragma mark - 合成（截图 + 模板）

// 模板为带透明屏幕窗的整幅框图：先铺截图，再叠模板
// 截图按等比铺满（cover）居中裁切，不拉伸变形
static UIImage *DD_ComposeShellImage(UIImage *shot, UIImage *tpl) {
    if (!shot || !tpl) return nil;
    CGSize size = tpl.size;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        // 等比铺满：按比例放大到覆盖整个画布，居中裁掉溢出部分
        CGFloat scale = MAX(size.width / shot.size.width, size.height / shot.size.height);
        CGFloat w = shot.size.width * scale, h = shot.size.height * scale;
        [shot drawInRect:CGRectMake((size.width - w) / 2.0, (size.height - h) / 2.0, w, h)];
        [tpl drawInRect:CGRectMake(0, 0, size.width, size.height)];
    }];
}

#pragma mark - 相册（取最新素材 / 保存）

static void DD_EnsurePhotoAuth(void (^ready)(BOOL)) {
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus s) {
            ready(s == PHAuthorizationStatusAuthorized || s == PHAuthorizationStatusLimited);
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus s) {
            ready(s == PHAuthorizationStatusAuthorized);
        }];
    }
}

// 取相册最新的一张图片（截图后 iOS 会先落相册，故从相册取）
static void DD_LatestImage(void (^done)(UIImage *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:o];
    PHAsset *a = [r firstObject];
    if (!a) { done(nil); return; }
    PHImageRequestOptions *ro = [PHImageRequestOptions new];
    ro.synchronous = NO;
    ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    ro.networkAccessAllowed = NO;
    [[PHImageManager defaultManager] requestImageForAsset:a targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:ro resultHandler:^(UIImage *img, NSDictionary *info) {
        done(img);
    }];
}

static void DD_LatestVideoURL(void (^done)(NSURL *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:o];
    PHAsset *a = [r firstObject];
    if (!a) { done(nil); return; }
    PHVideoRequestOptions *vo = [PHVideoRequestOptions new];
    vo.version = PHVideoRequestOptionsVersionOriginal;
    vo.networkAccessAllowed = NO;
    [[PHImageManager defaultManager] requestAVAssetForVideo:a options:vo resultHandler:^(AVAsset *asset, AVAudioMix *mix, NSDictionary *info) {
        done([asset isKindOfClass:[AVURLAsset class]] ? ((AVURLAsset *)asset).URL : nil);
    }];
}

static void DD_SaveImageToAlbum(UIImage *img) {
    if (!img) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:img];
    } completionHandler:nil];
}

static void DD_SaveVideoToAlbum(NSURL *url) {
    if (!url) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:nil];
}

#pragma mark - 视频套壳（录屏 + 模板叠加）

// 用 AVFoundation 逐帧叠加模板后导出，再存回相册
static void DD_ComposeShellVideo(NSURL *srcURL, UIImage *tplImg) {
    if (!srcURL || !tplImg) return;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:srcURL options:nil];
    AVAssetTrack *v = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!v) return;

    CGSize size = CGSizeApplyAffineTransform(v.naturalSize, CGAffineTransformMakeScale(v.preferredTransform.a, v.preferredTransform.d));
    CGSize abs = CGSizeMake(fabs(size.width), fabs(size.height));
    CGImageRef tplCG = tplImg.CGImage;

    // 用 AVAssetReader+AVAssetWriter 逐帧叠加，兼容性最好
    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (!reader) return;
    NSDictionary *outSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey : @(abs.width),
        (id)kCVPixelBufferHeightKey : @(abs.height)
    };
    AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:v outputSettings:outSettings];
    [reader addOutput:out];

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dd_shell_out.mp4"];
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
    NSError *werr = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithContentType:AVFileTypeMPEG4 URL:[NSURL fileURLWithPath:tmp] error:&werr];
    if (!writer) return;
    AVAssetWriterInput *in = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:@{
        (id)AVVideoCodecKey : (id)AVVideoCodecTypeH264,
        (id)AVVideoWidthKey : @(abs.width),
        (id)AVVideoHeightKey : @(abs.height)
    }];
    in.expectsMediaDataInRealTime = NO;
    [writer addInput:in];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:in sourcePixelBufferAttributes:outSettings];

    if (![reader startReading]) return;
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];

    CIContext *cctx = [CIContext contextWithOptions:nil];
    dispatch_queue_t q = dispatch_queue_create("ddshell.compose", DISPATCH_QUEUE_SERIAL);
    [in requestMediaDataWhenReadyOnQueue:q usingBlock:^{
        while (in.isReadyForMoreMediaData) {
            CMSampleBufferRef sb = [out copyNextSampleBuffer];
            if (!sb) {
                in.markAsFinished;
                [writer finishWritingWithCompletionHandler:^{
                    if (writer.status == AVAssetWriterStatusCompleted) {
                        DD_SaveVideoToAlbum([NSURL fileURLWithPath:tmp]);
                    }
                    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
                }];
                break;
            }
            CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sb);
            CMTime ts = CMSampleBufferGetPresentationTimeStamp(sb);
            CIImage *frame = [CIImage imageWithCVPixelBuffer:pb];
            CIImage *tpl = [CIImage imageWithCGImage:tplCG];
            // 模板拉伸到视频尺寸后叠加
            CGAffineTransform t = CGAffineTransformMakeScale(abs.width / tpl.extent.size.width, abs.height / tpl.extent.size.height);
            tpl = [tpl imageByApplyingTransform:t];
            CIImage *result = [tpl imageByCompositingOverImage:frame];

            CVPixelBufferRef outPB = NULL;
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool, &outPB);
            if (outPB) {
                [cctx render:result toBitmap:CVPixelBufferGetBaseAddress(outPB) rowBytes:CVPixelBufferGetBytesPerRow(outPB) bounds:result.extent format:kCIFormatBGRA colorSpace:nil];
                [adaptor appendPixelBuffer:outPB withPresentationTime:ts];
                CVPixelBufferRelease(outPB);
            } else {
                // 池未就绪：跳过该帧
            }
            CFRelease(sb);
        }
    }];
}

#pragma mark - 监听器

@interface DDShellWatcher : NSObject
+ (instancetype)shared;
- (void)shellLatestScreenshot;
- (void)shellLatestRecording;
@end

@implementation DDShellWatcher {
    BOOL _wasCaptured;
}

+ (instancetype)shared {
    static DDShellWatcher *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onScreenshot:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
        // 录屏：isCaptured 状态变化（iOS 11+）
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCaptureChanged:) name:UIScreenCapturedDidChangeNotification object:nil];
        }
    }
    return self;
}

- (void)onScreenshot:(NSNotification *)n {
    if (![DDShellConfig shared].enabled || ![DDShellConfig shared].autoShell) return;
    // 截图刚落相册，稍等再取最新一张
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self shellLatestScreenshot];
    });
}

- (void)onCaptureChanged:(NSNotification *)n {
    if (![DDShellConfig shared].enabled || ![DDShellConfig shared].autoShell) return;
    BOOL captured = [UIScreen mainScreen].isCaptured;
    if (_wasCaptured && !captured) {
        // 录屏结束：系统落盘需要时间，延后取最新视频
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self shellLatestRecording];
        });
    }
    _wasCaptured = captured;
}

- (void)shellLatestScreenshot {
    UIImage *tpl = DD_LoadTemplate(DD_ActiveTemplate());
    if (!tpl) return;
    DD_EnsurePhotoAuth(^(BOOL ok) {
        if (!ok) return;
        DD_LatestImage(^(UIImage *img) {
            if (!img) return;
            UIImage *outImg = DD_ComposeShellImage(img, tpl);
            DD_SaveImageToAlbum(outImg);
        });
    });
}

- (void)shellLatestRecording {
    UIImage *tpl = DD_LoadTemplate(DD_ActiveTemplate());
    if (!tpl) return;
    DD_EnsurePhotoAuth(^(BOOL ok) {
        if (!ok) return;
        DD_LatestVideoURL(^(NSURL *url) {
            if (!url) return;
            DD_ComposeShellVideo(url, tpl);
        });
    });
}

@end

#pragma mark - 设置界面

@interface DDShellSettingsViewController : UIViewController <UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic) BOOL tplExpanded;
@end

@implementation DDShellSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    WCTableViewManager *mgr = [mgrCls alloc];
    _tableViewMgr = [mgr initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) {
        [self ensureTableViewMgr];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"模板套壳设置";

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewMgr.delegate;
    self.tableViewMgr.delegate = self;
}

- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls = objc_getClass("WCTableViewSectionManager");
    if (!_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    WCTableViewSectionManager *section = [secCls defaultSection];

    [section addCell:[cellCls switchCellForSel:@selector(enabledSwitchChanged:)
                                      target:self title:@"启用模板套壳"
                                          on:[DDShellConfig shared].enabled]];

    if ([DDShellConfig shared].enabled) {
        [section addCell:[cellCls switchCellForSel:@selector(autoSwitchChanged:)
                                          target:self title:@"↳截图/录屏自动套壳"
                                              on:[DDShellConfig shared].autoShell]];

        // 素材库：展开显示全部模板，勾选生效
        NSArray *tpls = DD_AllTemplates();
        NSString *active = DD_ActiveTemplate();
        [section addCell:[cellCls normalCellForSel:@selector(tplHeaderTapped:)
                                          target:self title:@"↳套壳素材库"
                                       rightValue:[NSString stringWithFormat:@"已勾选 %@ / 共 %lu", active ?: @"无", (unsigned long)tpls.count]]];

        if (self.tplExpanded) {
            for (NSString *t in tpls) {
                WCTableViewCellManager *c = [cellCls centerCellForSel:@selector(tplOptionTapped:)
                                                               target:self title:t];
                c.userInfo = t;
                [section addCell:c];
        }
        }

        [section addCell:[cellCls normalCellForSel:@selector(importTapped:)
                                          target:self title:@"↳从相册导入模板"
                                       rightValue:@""]];

        [section addCell:[cellCls normalCellForSel:@selector(shellShotTapped:)
                                          target:self title:@"↳立即套壳最新截图"
                                       rightValue:@""]];

        [section addCell:[cellCls normalCellForSel:@selector(shellVideoTapped:)
                                          target:self title:@"↳立即套壳最新录屏"
                                       rightValue:@""]];
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

// 下拉勾选取值（与 DD收款助手同思路，用 userInfo 回读）
- (void)tplHeaderTapped:(id)sender {
    self.tplExpanded = !self.tplExpanded;
    [self buildTable];
}

- (void)tplOptionTapped:(id)sender {
    NSString *t = nil;
    if ([sender respondsToSelector:@selector(userInfo)]) {
        id v = [sender performSelector:@selector(userInfo)];
        if ([v isKindOfClass:[NSString class]]) t = v;
    }
    if (t.length) [DDShellConfig shared].selectedTpl = t;
    self.tplExpanded = NO;
    [self buildTable];
}

- (void)importTapped:(id)sender {
    UIImagePickerController *pc = [[UIImagePickerController alloc] init];
    pc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pc.delegate = self;
    [self presentViewController:pc animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    DD_ImportTemplateFromImage(img, ^(NSString *name) {
        if (name.length) [DDShellConfig shared].selectedTpl = name;
        dispatch_async(dispatch_get_main_queue(), ^{ [self buildTable]; });
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)shellShotTapped:(id)sender {
    [[DDShellWatcher shared] shellLatestScreenshot];
}

- (void)shellVideoTapped:(id)sender {
    [[DDShellWatcher shared] shellLatestRecording];
}

- (void)enabledSwitchChanged:(UISwitch *)sender {
    [DDShellConfig shared].enabled = sender.isOn;
    [self buildTable];
}
- (void)autoSwitchChanged:(UISwitch *)sender {
    [DDShellConfig shared].autoShell = sender.isOn;
    [self buildTable];
}

#pragma mark - UITableViewDelegate 转发

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    // 勾选标记：当前生效模板
    WCTableViewCellManager *cellInfo = (WCTableViewCellManager *)[self.tableViewMgr cellInfoAtIndexPath:indexPath];
    if (cellInfo && [cellInfo.userInfo isKindOfClass:[NSString class]]) {
        NSString *t = cellInfo.userInfo;
        cell.accessoryType = [t isEqualToString:DD_ActiveTemplate()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        (void)[DDShellConfig shared];
        [DDShellWatcher shared]; // 挂载截图/录屏监听

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                      version:@"1.0.0"
                                                   controller:@"DDShellSettingsViewController"];
        }
    }
}

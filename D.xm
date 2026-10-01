// ============================================================================
//  DDShell.xm —— 截图模板套壳插件
//
//  功能：截图后自动把截图套入模板，并保存回相册。
//  流程：监听系统截屏通知 → 从相册取最新截图 → 透视贴入模板窗口 → 存回相册。
//  模板：每个模板一个目录，把 name.png 与 name.cfg 一起放入
//        Documents/DDShell/模板/name/，两者缺一不可。
//  cfg 为 JSON，字段：template_width / template_height 与四个屏幕窗角点坐标。
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)arg1;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(NSInteger)style;
- (void)clearAllSection;
- (id)getTableView;
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
@property (nonatomic, retain) id userInfo;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信原生弹层（WCR 同款）。编译期不引用类符号，运行时 NSClassFromString 取；
// 方法签名挂在 NSObject 分类上只为通过编译，运行时不变。
@interface NSObject (DDShellWCSheet)
- (id)initWithTitle:(NSString *)title delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle
destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles;
- (id)initWithTitle:(NSString *)title;
- (NSInteger)tag;
- (void)showInView:(id)view;
@end

#pragma mark - 配置

static NSString *const kDDShellEnabled     = @"DDShellEnabled";
static NSString *const kDDShellAuto        = @"DDShellAutoShell";
static NSString *const kDDShellSelectedTpl = @"DDShellSelectedTpl";
static NSString *const kDDShellDeleteSrc   = @"DDShellDeleteOriginal";
static NSString *const kDDShellProcessed   = @"DDShellProcessedIds";

// 截图后固定等待 1 秒，等系统把截图写入相册后再取
static const NSTimeInterval kDDShellDelay = 1.0;

@interface DDShellConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL autoShell;
@property (nonatomic) BOOL deleteOriginal;
@property (nonatomic, copy) NSString *selectedTpl;
- (BOOL)hasProcessed:(NSString *)lid;
- (void)markProcessed:(NSString *)lid;
@end

@implementation DDShellConfig

+ (instancetype)shared {
    static DDShellConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        // boolForKey 未设置时返回 NO，只有 autoShell 默认开，需要单独判一次
        _enabled        = [ud boolForKey:kDDShellEnabled];
        _autoShell      = [ud objectForKey:kDDShellAuto] ? [ud boolForKey:kDDShellAuto] : YES;
        _deleteOriginal = [ud boolForKey:kDDShellDeleteSrc];
        _selectedTpl    = [ud stringForKey:kDDShellSelectedTpl] ?: @"";
        [ud setBool:_enabled forKey:kDDShellEnabled];
        [ud setBool:_autoShell forKey:kDDShellAuto];
        [ud setBool:_deleteOriginal forKey:kDDShellDeleteSrc];
        [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
    }
    return self;
}

- (void)setEnabled:(BOOL)v        { _enabled = v;        [self dd_setBool:v forKey:kDDShellEnabled]; }
- (void)setAutoShell:(BOOL)v      { _autoShell = v;      [self dd_setBool:v forKey:kDDShellAuto]; }
- (void)setDeleteOriginal:(BOOL)v { _deleteOriginal = v; [self dd_setBool:v forKey:kDDShellDeleteSrc]; }
- (void)setSelectedTpl:(NSString *)v {
    _selectedTpl = [v copy] ?: @"";
    [[NSUserDefaults standardUserDefaults] setObject:_selectedTpl forKey:kDDShellSelectedTpl];
}

- (void)dd_setBool:(BOOL)v forKey:(NSString *)k {
    [[NSUserDefaults standardUserDefaults] setBool:v forKey:k];
}

// 已处理过的截图去重，避免重复套壳
- (BOOL)hasProcessed:(NSString *)lid {
    if (!lid.length) return NO;
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:kDDShellProcessed];
    return [arr containsObject:lid]; // 对 nil 发消息返回 NO，不用判空
}
- (void)markProcessed:(NSString *)lid {
    if (!lid.length) return;
    NSMutableArray *m = [[[NSUserDefaults standardUserDefaults] arrayForKey:kDDShellProcessed] ?: @[] mutableCopy];
    [m addObject:lid];
    if (m.count > 200) m = [[m subarrayWithRange:NSMakeRange(m.count - 200, 200)] mutableCopy];
    [[NSUserDefaults standardUserDefaults] setObject:m forKey:kDDShellProcessed];
}

@end

#pragma mark - 模板目录

// 模板根目录：Documents/DDShell/模板/
static NSString *DD_TplDir(void) {
    static NSString *dir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        dir = [doc stringByAppendingPathComponent:@"DDShell/模板"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

// 单个模板的目录：Documents/DDShell/模板/<名称>/
static NSString *DD_TplFolder(NSString *name) {
    return name.length ? [DD_TplDir() stringByAppendingPathComponent:name] : nil;
}

#pragma mark - 模板模型

@interface DDShellTemplate : NSObject
@property (nonatomic, copy)   NSString *name;        // 模板名（不含扩展名）
@property (nonatomic, strong) UIImage  *image;       // 机身前景图（png）
@property (nonatomic)         CGSize    canvasSize;  // 模板画布像素尺寸（来自 cfg 的 template_width/height）
@property (nonatomic)         CGPoint   lt, rt, lb, rb; // 屏幕窗四角（UIKit 坐标，左上原点，像素，来自 cfg）
@end

@implementation DDShellTemplate
@end

// 在指定目录里找 name.ext，扩展名大小写不敏感。
// iOS 文件系统大小写敏感，若直接拼小写扩展名，Name.PNG / Name.CFG 会被找不到。
static NSString *DD_FileInFolder(NSString *dir, NSString *name, NSString *ext) {
    if (!dir.length || !name.length) return nil;
    NSString *want = [[name stringByAppendingPathExtension:ext] lowercaseString];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil]; // 为 nil 时 for-in 不进循环
    for (NSString *f in files) {
        if ([f.lowercaseString isEqualToString:want]) return [dir stringByAppendingPathComponent:f];
    }
    return nil;
}

// 在模板自己的目录里找 name.ext
static NSString *DD_ActualFile(NSString *name, NSString *ext) {
    return DD_FileInFolder(DD_TplFolder(name), name, ext);
}

// 模板 cfg 路径：<模板目录>/<名称>/<名称>.cfg（大小写不敏感）
static NSString *DD_CfgPath(NSString *name) {
    return DD_ActualFile(name, @"cfg");
}

static NSDictionary *DD_LoadCfg(NSString *name) {
    NSData *d = [NSData dataWithContentsOfFile:DD_CfgPath(name)];
    if (!d.length) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

// 枚举模板：根目录下每个子目录是一个模板，必须同时含 <名称>.png 与 <名称>.cfg
static NSArray<NSString *> *DD_AllTemplateNames(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:DD_TplDir() error:nil]; // 为 nil 时 for-in 不进循环
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *item in items) {
        NSString *dir = [DD_TplDir() stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) continue; // 只看目录
        if (!DD_ActualFile(item, @"png")) continue;
        if (!DD_ActualFile(item, @"cfg")) continue; // png 与 cfg 必须同时存在
        [out addObject:item];
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

static DDShellTemplate *DD_TemplateNamed(NSString *name) {
    if (!name.length) return nil;
    NSString *png = DD_ActualFile(name, @"png"); // 扩展名大小写不敏感
    NSData *d = png ? [NSData dataWithContentsOfFile:png] : nil;
    if (!d.length) return nil; // 无 png 则模板无效
    UIImage *img = [UIImage imageWithData:d];
    if (!img) return nil;

    DDShellTemplate *t = [DDShellTemplate new];
    t.name = name;
    t.image = img;

    // cfg 必须存在，否则模板不生效
    NSDictionary *cfg = DD_LoadCfg(name);
    if (!cfg) return nil;

    // 画布尺寸取 cfg 的 template_width / template_height；缺字段则 W/H 为 0，下方 W<1 拦截判模板无效
    double lw = [cfg[@"template_width"] doubleValue];
    double lh = [cfg[@"template_height"] doubleValue];
    CGSize canvas = CGSizeMake(lw, lh);

    NSArray *keys = @[@"left_top", @"right_top", @"left_bottom", @"right_bottom"];
    CGPoint pts[4];
    for (NSUInteger i = 0; i < 4; i++) {
        id x = cfg[[keys[i] stringByAppendingString:@"_x"]];
        id y = cfg[[keys[i] stringByAppendingString:@"_y"]];
        if (!x || !y) return nil; // 四角坐标缺失则模板不生效
        pts[i] = CGPointMake([x doubleValue], [y doubleValue]);
    }
    t.canvasSize = canvas;
    t.lt = pts[0]; t.rt = pts[1]; t.lb = pts[2]; t.rb = pts[3];
    return t;
}

static NSString *DD_ActiveTemplateName(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    if (sel.length && DD_TemplateNamed(sel)) return sel;
    return [DD_AllTemplateNames() firstObject] ?: @"";
}


#pragma mark - 合成

// UIKit 坐标（左上原点）→ CoreImage 坐标（左下原点）翻转
static CIVector *DD_CIVec(CGPoint p, CGFloat canvasH) {
    return [CIVector vectorWithCGPoint:CGPointMake(p.x, canvasH - p.y)];
}

static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    UIImage *frameImg = t.image;
    CGImageRef frameCG = frameImg.CGImage;
    CGImageRef shotCG = shot.CGImage;
    if (!frameCG || !shotCG) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    if (W < 1.0 || H < 1.0) return nil;

    // 截图按实际像素尺寸计算（CGImageGetWidth/Height）
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 输出画布固定 1 倍（1 单位 = 1 像素），保证输出尺寸严格等于模板尺寸；
    // 不能用屏幕倍率（2x/3x），否则画布被放大、截图被拉伸变糊。
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);

    // 使用 GPU 渲染 CoreImage
    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 将整张截图透视映射到 cfg 四角围成的屏幕窗；
    // inputExtent 用截图自身像素尺寸，四角点落在模板画布坐标系中，保证 1:1 贴合。
    CIImage *src = [CIImage imageWithCGImage:shotCG];
    CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
    [f setDefaults];
    [f setValue:src forKey:kCIInputImageKey];
    [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, A, B)] forKey:@"inputExtent"];
    [f setValue:DD_CIVec(t.lt, H) forKey:@"inputTopLeft"];
    [f setValue:DD_CIVec(t.rt, H) forKey:@"inputTopRight"];
    [f setValue:DD_CIVec(t.rb, H) forKey:@"inputBottomRight"];
    [f setValue:DD_CIVec(t.lb, H) forKey:@"inputBottomLeft"];
    CIImage *o = [f valueForKey:kCIOutputImageKey];

    if (o) {
        CGRect ext = o.extent;
        CGImageRef cg = [ci createCGImage:o fromRect:ext];
        if (cg) {
            // 通过 UIImage 绘制规避 UIKit 上下文的坐标翻转
            UIImage *layer = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
            CGRect r = CGRectMake(ext.origin.x,
                                 H - ext.origin.y - ext.size.height,
                                 ext.size.width, ext.size.height);
            [layer drawInRect:r];
            CGImageRelease(cg);
        }
    }

    // 机身前景图盖在最上层
    [frameImg drawInRect:CGRectMake(0, 0, W, H)];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - 相册

// 从相册取最新一张图作为本次要套壳的截图
static void DD_LatestImageAsset(void (^done)(PHAsset *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:o];
    if (done) done([r firstObject]);
}

static void DD_SaveImageToAlbum(UIImage *img) {
    if (!img) return;
    __block PHObjectPlaceholder *ph = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromImage:img];
        ph = req.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        // 把套壳成品也标记为已处理，避免后续被当成未处理截图重复套壳
        if (success && ph.localIdentifier.length) {
            [[DDShellConfig shared] markProcessed:ph.localIdentifier];
        }
    }];
}

static void DD_DeleteAssets(NSArray<PHAsset *> *assets) {
    if (!assets.count) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest deleteAssets:assets];
    } completionHandler:nil];
}

#pragma mark - 监听器

// 微信内置提示控件，运行时通过类名获取，不在编译期链接。
@interface WeToast : NSObject
+ (instancetype)toast;
- (void)setLoadingStyle:(BOOL)style;
- (void)showToastWithText:(NSString *)text;
- (void)showDoneToastWithText:(NSString *)text;
- (void)hideWithAnimated:(BOOL)animated;
@end

static WeToast *gBusyToast = nil; // 进行中的「正在套壳」loading 提示，完成后收起

// 连拍互斥：同一时刻只处理一张截图，处理中到达的截屏事件直接丢弃
static dispatch_queue_t gShellQueue = nil;
static BOOL gShellBusy = NO; // 是否有任务正在处理（处理中则丢弃后续连拍）

// 微信原生提示（运行时按类名取 WeToast，编译期不产生链接符号）
static WeToast *DD_Toast(void) {
    return [NSClassFromString(@"WeToast") toast];
}

// 开始 loading / 收起 loading / 成功
static void DD_ShowShelling(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WeToast *toast = DD_Toast();
        [toast setLoadingStyle:YES];
        [toast showToastWithText:@"正在套壳"];
        gBusyToast = toast;
    });
}
static void DD_HideShelling(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
    });
}
static void DD_ShowShellDone(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
        [DD_Toast() showDoneToastWithText:@"套壳成功"];
    });
}
static void DD_ShowToast(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [DD_Toast() showToastWithText:text];
    });
}

@interface DDShellWatcher : NSObject
+ (instancetype)shared;
- (void)shellLatestScreenshotWithCompletion:(void (^)(void))completion;
- (void)dd_showShelling;
- (void)dd_hideShelling;
- (void)dd_showShellDone;
@end

@implementation DDShellWatcher

+ (instancetype)shared {
    static DDShellWatcher *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onScreenshot:)
                                                     name:UIApplicationUserDidTakeScreenshotNotification
                                                   object:nil];
    }
    return self;
}

- (void)onScreenshot:(NSNotification *)n {
    if (![DDShellConfig shared].enabled || ![DDShellConfig shared].autoShell) return;
    // 固定等待 1 秒，等系统把截图写入相册后再取
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDDShellDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!gShellQueue) gShellQueue = dispatch_queue_create("com.ddshell.shell", DISPATCH_QUEUE_SERIAL);
        dispatch_async(gShellQueue, ^{
            if (gShellBusy) return; // 连拍：已有任务在处理，本次直接丢弃
            gShellBusy = YES;
            [self shellLatestScreenshotWithCompletion:^{
                dispatch_async(gShellQueue, ^{
                    gShellBusy = NO; // 处理完解除互斥，放行下一次截屏
                });
            }];
        });
    });
}

- (void)shellLatestScreenshotWithCompletion:(void (^)(void))completion {
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!t) { if (completion) completion(); return; }
    DD_LatestImageAsset(^(PHAsset *asset) {
        if (!asset) { if (completion) completion(); return; }
        if ([[DDShellConfig shared] hasProcessed:asset.localIdentifier]) { if (completion) completion(); return; } // 去重
        PHImageRequestOptions *ro = [PHImageRequestOptions new];
        ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        ro.networkAccessAllowed = NO;
        [self dd_showShelling]; // 开始：显示「正在套壳」转圈提示
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:PHImageManagerMaximumSize
                                                  contentMode:PHImageContentModeDefault
                                                      options:ro
                                                resultHandler:^(UIImage *img, NSDictionary *info) {
            UIImage *outImg = (img) ? DD_ComposeShellImage(img, t) : nil;
            if (!outImg) { [self dd_hideShelling]; if (completion) completion(); return; } // 合成失败：静默收起提示
            DD_SaveImageToAlbum(outImg);
            [[DDShellConfig shared] markProcessed:asset.localIdentifier];
            if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
            [self dd_showShellDone]; // 结束：显示「套壳成功」提示
            if (completion) completion();
        }];
    });
}

// 微信原生提示的实例包装（转发到文件级静态函数，供截图路径调用）
- (void)dd_showShelling { DD_ShowShelling(); }
- (void)dd_hideShelling { DD_HideShelling(); }
- (void)dd_showShellDone { DD_ShowShellDone(); }


@end

#pragma mark - 导入导出

// 微信自带的 zip 库（宿主类，运行时按类名取，编译期不产生链接符号）
@interface DDZipArchive : NSObject
+ (BOOL)createZipFileAtPath:(id)zipPath withContentsOfDirectory:(id)dir keepParentDirectory:(BOOL)keep;
+ (BOOL)unzipFileAtPath:(id)zipPath toDestination:(id)dest;
@end

// 系统文件选择器（运行时按类名取，编译期不产生链接符号）
@interface DDFilePicker : UIViewController
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)types inMode:(NSInteger)mode;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, weak) id delegate;
@end

// 打包整个目录，zip 内保留该目录名（同 WCR：顶层有个 WCRefine_frames/）
static BOOL DD_ZipDirectory(NSString *srcDir, NSString *zipPath) {
    // 类不存在时 objc_getClass 返回 nil，对 nil 发消息返回 NO，不用额外判空
    return [objc_getClass("QSSZipArchive") createZipFileAtPath:zipPath
                                      withContentsOfDirectory:srcDir
                                          keepParentDirectory:YES];
}

// 解包 zip 到目录
static BOOL DD_UnzipToDirectory(NSString *zipPath, NSString *destDir) {
    return [objc_getClass("QSSZipArchive") unzipFileAtPath:zipPath toDestination:destDir];
}

// 递归找出所有合法模板目录：目录名与目录内的 <目录名>.png、<目录名>.cfg 三者齐备。
// zip 内可能是 DDShell模板/xx/、xx/ 或别的层级，所以要下钻。
static void DD_CollectTemplateFolders(NSString *dir, NSMutableArray<NSString *> *out) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil]; // 为 nil 时 for-in 不进循环
    for (NSString *item in items) {
        if ([item hasPrefix:@"."] || [item isEqualToString:@"__MACOSX"]) continue;
        NSString *p = [dir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:p isDirectory:&isDir] || !isDir) continue;
        if (DD_FileInFolder(p, item, @"png") && DD_FileInFolder(p, item, @"cfg")) {
            [out addObject:p];
        } else {
            DD_CollectTemplateFolders(p, out);
        }
    }
}

// 递归收集 root 下所有普通文件（跳过隐藏项与 macOS 资源叉）
static void DD_CollectFiles(NSString *dir, NSMutableArray<NSString *> *out) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil]; // 为 nil 时 for-in 不进循环
    for (NSString *item in items) {
        if ([item hasPrefix:@"."] || [item isEqualToString:@"__MACOSX"]) continue;
        NSString *p = [dir stringByAppendingPathComponent:item];
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:p isDirectory:&isDir]) continue;
        if (isDir) DD_CollectFiles(p, out); else [out addObject:p];
    }
}

// 把一整个模板目录装进模板根目录
static BOOL DD_InstallTemplateFolder(NSString *src) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = DD_TplFolder(src.lastPathComponent);
    if (!dst) return NO;
    if ([fm fileExistsAtPath:dst]) [fm removeItemAtPath:dst error:nil]; // 同名则覆盖
    return [fm copyItemAtPath:src toPath:dst error:nil];
}

// 散装文件导入：按文件名（去扩展名）把 png 与 cfg 配对，每对建一个模板目录
static NSInteger DD_ImportLooseFiles(NSArray<NSString *> *files) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary<NSString *, NSMutableDictionary *> *pairs = [NSMutableDictionary dictionary];
    for (NSString *f in files) {
        NSString *base = f.lastPathComponent.stringByDeletingPathExtension;
        NSString *ext  = f.pathExtension.lowercaseString;
        if (!base.length) continue;
        if (![ext isEqualToString:@"png"] && ![ext isEqualToString:@"cfg"]) continue;
        NSMutableDictionary *d = pairs[base] ?: [NSMutableDictionary dictionary];
        d[ext] = f;
        pairs[base] = d;
    }
    NSInteger n = 0;
    for (NSString *base in pairs) {
        NSDictionary *d = pairs[base];
        if (!d[@"png"] || !d[@"cfg"]) continue; // 单有 png 或单有 cfg 不成模板
        NSString *dst = DD_TplFolder(base);
        [fm removeItemAtPath:dst error:nil];
        if (![fm createDirectoryAtPath:dst withIntermediateDirectories:YES attributes:nil error:nil]) continue;
        [fm copyItemAtPath:d[@"png"] toPath:[dst stringByAppendingPathComponent:[base stringByAppendingPathExtension:@"png"]] error:nil];
        [fm copyItemAtPath:d[@"cfg"] toPath:[dst stringByAppendingPathComponent:[base stringByAppendingPathExtension:@"cfg"]] error:nil];
        n++;
    }
    return n;
}

// 把 root 下所有模板搬进模板根目录，返回成功数量
static NSInteger DD_ImportTemplatesFrom(NSString *root) {
    NSMutableArray<NSString *> *folders = [NSMutableArray array];
    DD_CollectTemplateFolders(root, folders);
    NSInteger n = 0;
    for (NSString *src in folders) {
        if (DD_InstallTemplateFolder(src)) n++;
    }
    if (!n) { // 没有整目录的，按散装 png + cfg 配对再试一次
        NSMutableArray<NSString *> *files = [NSMutableArray array];
        DD_CollectFiles(root, files);
        n = DD_ImportLooseFiles(files);
    }
    return n;
}

// 把指定模板打包成一个 zip，返回 zip 路径（打包失败返回 nil）
static NSString *DD_ExportTemplatesToZip(NSArray<NSString *> *names) {
    if (!names.count) return nil;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp   = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSString *stage = [tmp stringByAppendingPathComponent:@"DDShell模板"];
    [fm createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in names) {
        NSString *src = DD_TplFolder(name);
        if (!src.length) continue;
        [fm copyItemAtPath:src toPath:[stage stringByAppendingPathComponent:name] error:nil];
    }
    NSString *zip = [tmp stringByAppendingPathComponent:@"DDShell_套壳模板.zip"];
    return DD_ZipDirectory(stage, zip) ? zip : nil;
}

#pragma mark - 套壳素材库

// 两个 sheet 的 tag 沿用 WCR 的值：套壳操作 0x5e9d、选择导出方式 0x5ea1。
static const NSInteger DD_SHEET_TPL    = 0x5e9d;
static const NSInteger DD_SHEET_EXPORT = 0x5ea1;

// 网格排布：列数与间距。WCR 的算法是 itemW = (view宽 - gap*(列数+1)) / 列数，
// 它用的是 3 列（(屏宽-40)/3）；这里按双排取 2 列，要跟 WCR 完全一致把下面的 2 改成 3。
static const NSInteger kDDShellTplColumns = 2;
static const CGFloat   kDDShellTplGap     = 10.0;
static const CGFloat   kDDShellSearchH    = 44.0; // 搜索条高度，和 WCR 的 setupSearchBar 一致

// 缩略图缓存：模板 png 是全尺寸图（可能上千像素），每格都整图解一次码滚动会卡，
// 这里按格子边长解码一次后缓存，名字变了（重命名）路径也变，不会串图。
static NSCache *DD_ThumbCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 80;
    });
    return cache;
}

static UIImage *DD_ThumbForName(NSString *name, CGFloat side) {
    NSString *path = DD_ActualFile(name, @"png");
    if (!path.length || side <= 0) return nil;

    NSString *key = [NSString stringWithFormat:@"%@|%d", path, (int)side];
    UIImage *hit = [DD_ThumbCache() objectForKey:key];
    if (hit) return hit;

    UIImage *src = [UIImage imageWithContentsOfFile:path];
    if (!src || src.size.width <= 0 || src.size.height <= 0) return nil;

    CGFloat rate = MIN(side / src.size.width, side / src.size.height); // 等比缩放，不拉伸变形
    CGSize draw = CGSizeMake(src.size.width * rate, src.size.height * rate);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, [UIScreen mainScreen].scale);
    [src drawInRect:CGRectMake((side - draw.width) / 2, (side - draw.height) / 2, draw.width, draw.height)];
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (out) [DD_ThumbCache() setObject:out forKey:key];
    return out;
}

// 素材格：上图片下名字，选中时整格描边；右上角小角标只在勾选态出现
@interface DDShellTplCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *thumbView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UIView *markView;
@property (nonatomic, strong) UILabel *checkLabel;
@end

@implementation DDShellTplCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        UIColor *bg = [UIColor secondarySystemGroupedBackgroundColor]; // 灰页面上格子用白色，层次才对
        UIColor *fg = [UIColor labelColor];
        self.contentView.backgroundColor = bg;
        self.contentView.layer.cornerRadius = 8.0;   // 同 WCR
        self.contentView.layer.masksToBounds = YES;

        _thumbView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _thumbView.contentMode = UIViewContentModeScaleAspectFit;
        _thumbView.clipsToBounds = YES;
        [self.contentView addSubview:_thumbView];

        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont systemFontOfSize:12.0];
        _nameLabel.textColor = fg;
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self.contentView addSubview:_nameLabel];

        _markView = [[UIView alloc] initWithFrame:CGRectZero];
        _markView.layer.borderWidth = 2.5;
        _markView.layer.cornerRadius = 8.0;
        _markView.hidden = YES;
        [self.contentView addSubview:_markView];

        _checkLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _checkLabel.text = @"✓";
        _checkLabel.font = [UIFont boldSystemFontOfSize:14.0];
        _checkLabel.textColor = [UIColor whiteColor];
        _checkLabel.textAlignment = NSTextAlignmentCenter;
        _checkLabel.backgroundColor = [UIColor systemBlueColor];
        _checkLabel.layer.cornerRadius = 9.0;
        _checkLabel.layer.masksToBounds = YES;
        _checkLabel.hidden = YES;
        [self.contentView addSubview:_checkLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize s = self.contentView.bounds.size;
    CGFloat nameH = 20.0;
    self.thumbView.frame = CGRectMake(0, 0, s.width, s.height - nameH);
    self.nameLabel.frame = CGRectMake(4.0, s.height - nameH, s.width - 8.0, nameH);
    self.markView.frame = self.contentView.bounds;
    self.checkLabel.frame = CGRectMake(s.width - 24.0, 4.0, 18.0, 18.0);
}

@end

// 分组底色：不写死色值，直接向设置页同一个来源要——现造一个同款 WCTableViewManager，
// 读它 tableView 的底色。这样素材库页和设置页必然同色：微信换主题、改默认值两边一起变。
// 已实测能读到色值，不做 nil 退回、不兜底。
static UIColor *DD_WCGroupBackgroundColor(void) {
    static UIColor *color;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        id mgrCls = objc_getClass("WCTableViewManager");
        WCTableViewManager *mgr = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                                          style:UITableViewStyleInsetGrouped];
        // getTableView 返回 id，必须转成 UITableView *：否则编译器按 id 随便挑一个
        // backgroundColor 声明（挑到了 CALayer 的，返回 CGColorRef），类型就对不上了
        UITableView *tv = (UITableView *)[mgr getTableView];
        color = tv.backgroundColor;
    });
    return color;
}

// 导航栏底色：直接复用分组底色（同一个来源），导航栏和页面底色永远一致，
// 微信换主题时两边一起变，不会再出现一深一浅。
// 想让导航栏独立成别的色，把下面这行换成写死色值即可，例如：
//   return [UIColor colorWithRed:0xF2/255.0 green:0xF2/255.0 blue:0xF7/255.0 alpha:1.0]; // #F2F2F7
static UIColor *DD_NavBarBackgroundColor(void) {
    return DD_WCGroupBackgroundColor();
}

// 设置页和素材库页共用同一套导航栏外观：不透明 + 和页面底色同一个灰。
// 关键点：外观要「复制导航栏现有的再改背景」，不要从零 [[... alloc] init] + configureWithOpaqueBackground。
// 后者是系统默认样式，会把按钮配色一起重置掉，按钮文字色掉回 tintColor 继承、比微信自己的浅——
// 表现就是 push 动画期间还是对的，动画一结束（切到我们的外观）按钮闪一下变浅。
// 另外也不能用 configureWithDefaultBackground，那个是「默认半透明」，颜色会被导航栏背后的内容
// 影响（设置页背后是灰、素材库页 UIRectEdgeNone 背后没内容），同一个外观会渲染出一深一浅两种灰。
// 这里复制现有外观后只改背景（去毛玻璃 + 钉死底色 + 去阴影线），标题样式原样保留；
// 按钮则换成一套空的 buttonAppearance，纯按 tint 渲染（见函数内注释）。
static void DD_ApplyNavigationBarAppearance(UIViewController *vc) {
    UINavigationBarAppearance *base = vc.navigationController.navigationBar.standardAppearance;
    UINavigationBarAppearance *appearance = [base copy];
    appearance.backgroundEffect = nil;   // 去毛玻璃（等价于 opaque，但不会顺手重置按钮样式）
    appearance.backgroundImage = nil;
    appearance.backgroundColor = DD_NavBarBackgroundColor();
    appearance.shadowColor = nil;        // 去掉底部那条阴影线
    // 右上角按钮直接用 tint 渲染：给一个不带任何文字属性的 buttonAppearance，
    // 颜色就完全由 UINavigationBar 的 tintColor 决定，和返回箭头一致；
    // 不走 copy 出来的那套 buttonAppearance（它可能带微信自己的按钮色，且转场前后解析时机不一致）。
    appearance.buttonAppearance = [[UIBarButtonItemAppearance alloc] initWithStyle:UIBarButtonItemStylePlain];

    vc.navigationItem.standardAppearance = appearance;
    vc.navigationItem.scrollEdgeAppearance = appearance;
    vc.navigationItem.compactAppearance = appearance;
}

// 独立的素材库页面，交互对齐 WCRefineScreenshotFrameLibraryViewController：
//   双排网格列出模板，右上角常驻 导出 / 导入（导入最靠右），默认按名称排序；
//   点「导出」用微信原生 WCActionSheet 弹「选择导出方式」：选择导出 / 全部导出（取消自带）；
//   「选择导出」进入选择态，右上角换成 删除 / 导出 / 取消；
//   单点一个模板弹 WCActionSheet「套壳操作」：应用模板 / 重命名 / 选择，选「选择」同样进选择态。
@interface DDShellLibraryViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;                  // 自己贴 view 顶上的搜索框（不挂 navigationItem.searchController，避免撑高导航栏）
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *allNames;       // 排序后的全量，搜索只是过滤展示
@property (nonatomic, strong) NSArray<NSString *> *names;          // 当前展示（可能是过滤结果）
@property (nonatomic) BOOL isSelectMode;                          // 是否处于选择态
@property (nonatomic, strong) NSMutableSet<NSString *> *picked;    // 选择态下勾选的模板
@property (nonatomic, copy) NSString *tappedTpl;                   // 刚弹出操作菜单的那个模板
@end

@implementation DDShellLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.picked = [NSMutableSet set];
    self.edgesForExtendedLayout = UIRectEdgeNone; // view 从导航栏底下开始，搜索栏才不会顶进状态栏

    // 导航栏：和设置页同一套（不透明灰 + 无阴影线）
    DD_ApplyNavigationBarAppearance(self);

    // 页面底色：取和设置页同一个来源（WCTableViewManager 表格的底色），两页必然同色
    self.view.backgroundColor = DD_WCGroupBackgroundColor();

    [self setupSearchBar];
    [self setupCollectionView];
    [self setupNavigationBar];
    [self reloadList];
}

// 搜索条：和 WCR 一样自己贴在 view 顶上，不挂 navigationItem.searchController——
// 那个会把导航栏撑高一截，跟设置页对不上。用 minimal 样式（没有自带灰底和分隔线），
// 四周透出来的就是页面灰，看上去和导航栏连成一片。
- (void)setupSearchBar {
    UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, kDDShellSearchH)];
    sb.placeholder = @"搜索套壳名称";
    sb.delegate = self;
    sb.searchBarStyle = UISearchBarStyleMinimal;
    sb.searchTextField.backgroundColor = [UIColor secondarySystemBackgroundColor]; // 输入框本身是白的
    self.searchBar = sb;
    [self.view addSubview:sb];
}

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = kDDShellTplGap;
    layout.minimumLineSpacing = kDDShellTplGap;
    layout.sectionInset = UIEdgeInsetsMake(kDDShellTplGap, kDDShellTplGap, kDDShellTplGap, kDDShellTplGap);

    // frame 交给 viewDidLayoutSubviews，这里先零尺寸占位
    UICollectionView *cv = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    cv.backgroundColor = [UIColor clearColor]; // 透明，透出和设置页同色的页面底色
    cv.alwaysBounceVertical = YES;
    cv.delegate = self;
    cv.dataSource = self;
    [cv registerClass:[DDShellTplCell class] forCellWithReuseIdentifier:@"DDShellTplCell"];
    self.collectionView = cv;
    [self.view addSubview:cv];
}

// 布局跟 WCR 的 viewDidLayoutSubviews 一个算法：搜索条压在最上面，网格从它底下开始铺满剩余
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top; // 上面设了 UIRectEdgeNone，正常就是 0
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    self.searchBar.frame = CGRectMake(0, top, w, kDDShellSearchH);
    self.collectionView.frame = CGRectMake(0, top + kDDShellSearchH, w, h - top - kDDShellSearchH);
    [self.view bringSubviewToFront:self.searchBar];
}

// 返回按钮不自定义：直接用系统那个返回指示器，字形、大小、颜色都跟设置页完全一致。
// 之前用 SF Symbol chevron.left 手搓了一个，跟 UIKit 自己画的系统箭头不是同一个尺寸；
// 而且自定义 leftBarButtonItem 会把边缘侧滑返回弄失效，还得抢手势代理才能救回来。
// 箭头旁边不显示上一页标题，靠 push 前把上一页的 backBarButtonItem 标题置空（见 openLibraryTapped:）。

// 默认按名称排序（本地化、数字感知：「模板2」排在「模板10」前面）
- (void)reloadList {
    NSMutableArray *all = [DD_AllTemplateNames() mutableCopy];
    [all sortUsingSelector:@selector(localizedStandardCompare:)];
    self.allNames = all;
    [self applySearchFilter];
    [self updateEmptyState];
}

- (void)updateTitle {
    self.title = self.isSelectMode
        ? [NSString stringWithFormat:@"已选择（%ld个）", (long)self.picked.count]
        : [NSString stringWithFormat:@"套壳库（%ld个）", (long)self.names.count];
}

// 搜索过滤：只动展示的 names，全量 allNames 不变；标题跟着显示过滤后的数量
- (void)applySearchFilter {
    NSString *kw = (self.searchBar.text ?: @"").lowercaseString;
    if (!kw.length) {
        self.names = self.allNames;
    } else {
        NSMutableArray *m = [NSMutableArray array];
        for (NSString *n in self.allNames) {
            if ([n.lowercaseString containsString:kw]) [m addObject:n];
        }
        self.names = m;
    }
    [self updateTitle];
    [self.collectionView reloadData];
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    [self applySearchFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb {
    [sb resignFirstResponder];
}

// 空态用背景视图占满，不占一个格子
- (void)updateEmptyState {
    if (self.names.count) {
        self.collectionView.backgroundView = nil;
        return;
    }
    // 首次进来 collectionView 还没布局（frame 是零），靠 autoresizing 跟着撑开
    UILabel *l = [[UILabel alloc] initWithFrame:self.collectionView.bounds];
    l.text = @"（空：把 name.png + name.cfg 一起放 Documents/DDShell/模板/name/）";
    l.numberOfLines = 0;
    l.font = [UIFont systemFontOfSize:13.0];
    l.textColor = [UIColor grayColor];
    l.textAlignment = NSTextAlignmentCenter;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundView = l;
}

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewFlowLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat gap = kDDShellTplGap;
    CGFloat w = floor((cv.bounds.size.width - gap * (kDDShellTplColumns + 1)) / kDDShellTplColumns);
    return CGSizeMake(w, w + 30.0); // 正方形缩略图 + 20pt 名字行
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return self.names.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    DDShellTplCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"DDShellTplCell" forIndexPath:ip];
    NSString *n = self.names[ip.item];

    cell.nameLabel.text = n;
    CGFloat gap = kDDShellTplGap;
    CGFloat w = floor((cv.bounds.size.width - gap * (kDDShellTplColumns + 1)) / kDDShellTplColumns);
    cell.thumbView.image = DD_ThumbForName(n, w);

    BOOL picked = self.isSelectMode && [self.picked containsObject:n];
    BOOL active = !self.isSelectMode && [n isEqualToString:DD_ActiveTemplateName()];
    cell.checkLabel.hidden = !picked;
    cell.markView.hidden = !(picked || active);
    // 蓝框 = 已勾选待导出，绿框 = 当前正在用的模板
    cell.markView.layer.borderColor = picked ? [UIColor systemBlueColor].CGColor : [UIColor systemGreenColor].CGColor;
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
    if (ip.item >= (NSInteger)self.names.count) return;
    NSString *n = self.names[ip.item];

    if (self.isSelectMode) { // 选择态：点一下切换勾选
        if ([self.picked containsObject:n]) [self.picked removeObject:n]; else [self.picked addObject:n];
        [self setupNavigationBar]; // 删除/导出的可用性跟着勾选数变
        [self updateTitle];
        [self.collectionView reloadItemsAtIndexPaths:@[ip]];
        return;
    }

    // 普通态：弹出模板操作菜单（应用模板 / 重命名 / 选择），取消按钮 WCActionSheet 自带
    self.tappedTpl = n;
    [self showWCActionSheet:@"套壳操作" tag:DD_SHEET_TPL items:@[@"应用模板", @"重命名", @"选择"]];
}

#pragma mark 导航栏

- (UIBarButtonItem *)navButton:(NSString *)title action:(SEL)action {
    return [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:action];
}

// 右上角按钮（数组首个最靠右）：
//   普通态：导入 / 导出
//   选择态：取消 / 导出 / 删除
- (void)setupNavigationBar {
    UIBarButtonItem *right, *mid, *left;
    if (self.isSelectMode) {
        right = [self navButton:@"取消" action:@selector(cancelExportSelectMode)];
        mid   = [self navButton:@"导出" action:@selector(exportButtonTapped)];
        left  = [self navButton:@"删除" action:@selector(deleteSelectedFrames)];
        BOOL has = self.picked.count > 0; // 一个都没勾上时导出和删除不可点
        mid.enabled = has;
        left.enabled = has;
    } else {
        right = [self navButton:@"导入" action:@selector(uploadButtonTapped)];
        mid   = [self navButton:@"导出" action:@selector(exportButtonTapped)];
        left  = nil;
    }
    // rightBarButtonItems 数组首个显示在最靠屏幕边缘：取消 / 导入贴着右边缘，
    // 左侧不动，系统返回箭头保持原位
    NSMutableArray *items = [NSMutableArray array];
    if (right) [items addObject:right];
    if (mid)   [items addObject:mid];
    if (left)  [items addObject:left];
    self.navigationItem.rightBarButtonItems = items;
}

#pragma mark 微信原生 WCActionSheet

// WCR 同款用法：initWithTitle:delegate:cancelButtonTitle:... → 塞 WCActionSheetItem
// → setValue:forKey:buttonTitleList → setValue:forKey:tag → showInView:
- (void)showWCActionSheet:(NSString *)title tag:(NSInteger)tag items:(NSArray<NSString *> *)items {
    Class sheetCls = NSClassFromString(@"WCActionSheet");
    Class itemCls  = NSClassFromString(@"WCActionSheetItem");
    if (!sheetCls || !itemCls) return;

    id sheet = [[sheetCls alloc] initWithTitle:title
                                       delegate:self
                              cancelButtonTitle:@"取消"
                         destructiveButtonTitle:nil
                              otherButtonTitles:nil];

    NSMutableArray *list = [NSMutableArray array];
    for (NSString *t in items) {
        [list addObject:[[itemCls alloc] initWithTitle:t]];
    }
    [sheet setValue:list forKey:@"buttonTitleList"];
    [sheet setValue:@(tag) forKey:@"tag"];
    [sheet performSelector:@selector(showInView:) withObject:self.view];
}

// WCActionSheetDelegate 回调：按 tag 分发，buttonTitleList[0] 对应 index 0；
// 点自带「取消」的 index 落在所有 item 之后，不会命中任何分支。
- (void)actionSheet:(id)sheet clickedButtonAtIndex:(NSInteger)idx {
    NSInteger tag = [sheet tag];

    if (tag == DD_SHEET_EXPORT) { // 选择导出方式：0=选择导出 1=全部导出
        if (idx == 0) [self enterExportSelectMode];
        else if (idx == 1) [self exportAllFrames];
    } else if (tag == DD_SHEET_TPL) { // 套壳操作：0=应用模板 1=重命名 2=选择
        NSString *n = self.tappedTpl;
        if (idx == 0 && n.length) {
            [DDShellConfig shared].selectedTpl = n;
            [self reloadList];
            DD_ShowToast([NSString stringWithFormat:@"已应用模板：%@", n]);
        } else if (idx == 1 && n.length) {
            [self renameTemplateNamed:n];
        } else if (idx == 2) {
            [self enterExportSelectModeWithName:n];
        }
    }
    self.tappedTpl = nil;
}

#pragma mark 导出

// 点「导出」：选择态直接导出勾选的；普通态先问「选择导出」还是「全部导出」
- (void)exportButtonTapped {
    if (self.isSelectMode) { [self exportSelectedFrames]; return; }
    if (!self.names.count) { DD_ShowToast(@"没有可导出的套壳"); return; }

    [self showWCActionSheet:@"选择导出方式" tag:DD_SHEET_EXPORT items:@[@"选择导出", @"全部导出"]];
}

// 进入选择态：勾选清空，右上角换成 删除 / 导出 / 取消
- (void)enterExportSelectMode {
    if (!self.names.count) { DD_ShowToast(@"没有可导出的套壳"); return; }
    self.isSelectMode = YES;
    [self.picked removeAllObjects];
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

// 从「套壳操作 → 选择」进入：顺手把那一个勾上（对应 WCR 的 enterExportSelectModeFromLongPress）
- (void)enterExportSelectModeWithName:(NSString *)name {
    [self enterExportSelectMode];
    if (!self.isSelectMode || !name.length) return;
    [self.picked addObject:name];
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

- (void)cancelExportSelectMode {
    self.isSelectMode = NO;
    [self.picked removeAllObjects];
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

- (void)exportSelectedFrames {
    NSArray *names = [self.picked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    if (!names.count) { DD_ShowToast(@"请至少选择一个套壳"); return; }
    [self shareZipForNames:names];
}

// 「全部导出」= 全选后导出，WCR 用它代替全选按钮
- (void)exportAllFrames {
    if (!self.names.count) { DD_ShowToast(@"没有可导出的套壳"); return; }
    [self shareZipForNames:self.names];
}

// 打包后调起系统分享（存到文件 / 隔空投送等），分享成功则退出选择态
- (void)shareZipForNames:(NSArray<NSString *> *)names {
    NSString *zip = DD_ExportTemplatesToZip(names);
    if (!zip) { DD_ShowToast(@"导出失败"); return; }

    NSString *tmpDir = zip.stringByDeletingLastPathComponent; // 打包用的临时目录，分享结束后删掉
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[ [NSURL fileURLWithPath:zip] ]
                                                                     applicationActivities:nil];
    av.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *err) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
        if (completed) [self cancelExportSelectMode];
    };
    UIPopoverPresentationController *pop = av.popoverPresentationController;
    if (pop) { // iPad 需要锚点，否则崩溃
        pop.sourceView = self.view;
        pop.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:av animated:YES completion:nil];
}

#pragma mark 重命名

- (void)renameTemplateNamed:(NSString *)name {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"重命名"
                                                                message:name
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.text = name; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self renameTemplate:name to:ac.textFields.firstObject.text];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

// 目录和目录里的 png/cfg 一起改名；当前正在用的模板被改名则同步选中记录
- (void)renameTemplate:(NSString *)oldName to:(NSString *)newName {
    newName = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!newName.length) { DD_ShowToast(@"名字不能为空"); return; }
    if ([newName isEqualToString:oldName]) return;
    if ([newName containsString:@"/"]) { DD_ShowToast(@"名字不能包含 /"); return; }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDir = DD_TplFolder(oldName), *dstDir = DD_TplFolder(newName);
    if (!srcDir.length || !dstDir.length) { DD_ShowToast(@"重命名失败"); return; }
    if ([fm fileExistsAtPath:dstDir]) { DD_ShowToast(@"已有同名模板"); return; }

    BOOL ok = YES;
    for (NSString *ext in @[@"png", @"cfg"]) {
        NSString *src = DD_FileInFolder(srcDir, oldName, ext);
        if (!src) continue; // 单边文件缺失时只改目录名
        NSString *dst = [srcDir stringByAppendingPathComponent:[newName stringByAppendingPathExtension:ext]];
        if (![fm moveItemAtPath:src toPath:dst error:nil]) ok = NO;
    }
    if (ok) ok = [fm moveItemAtPath:srcDir toPath:dstDir error:nil];
    if (!ok) { DD_ShowToast(@"重命名失败"); return; }

    if ([[DDShellConfig shared].selectedTpl isEqualToString:oldName]) [DDShellConfig shared].selectedTpl = newName;
    [self reloadList];
    DD_ShowToast([NSString stringWithFormat:@"已重命名为 %@", newName]);
}

#pragma mark 删除

// 实际删除：连整目录一起删；删掉的是当前模板则回落到第一个剩下的模板
- (void)deleteNames:(NSArray<NSString *> *)names {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger n = 0;
    for (NSString *name in names) {
        NSString *dir = DD_TplFolder(name);
        if (dir.length && [fm removeItemAtPath:dir error:nil]) n++;
    }
    NSString *active = [DDShellConfig shared].selectedTpl;
    if (active.length && [names containsObject:active]) {
        [DDShellConfig shared].selectedTpl = DD_AllTemplateNames().firstObject ?: @"";
    }
    DD_ShowToast([NSString stringWithFormat:@"已删除 %ld 个模板", (long)n]);
}

// 选择态点右上角「删除」：先确认再删
- (void)deleteSelectedFrames {
    NSArray *names = [self.picked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    if (!names.count) { DD_ShowToast(@"请至少选择一个套壳"); return; }
    [self confirmDeleteNames:names];
}

// 删除确认，单个和批量共用
- (void)confirmDeleteNames:(NSArray<NSString *> *)names {
    if (!names.count) return;
    NSString *msg = names.count == 1
        ? [NSString stringWithFormat:@"确定要删除「%@」这个套壳模板吗？", names.firstObject]
        : [NSString stringWithFormat:@"确定要删除选中的 %ld 个套壳模板吗？", (long)names.count];

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"确认删除"
                                                                message:msg
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [self deleteNames:names];
        if (self.isSelectMode) [self cancelExportSelectMode]; else [self reloadList];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark 导入

// 从系统文件导入：zip / 模板目录 / 散装 png + cfg 都支持
- (void)uploadButtonTapped {
    NSArray *types = @[@"public.item", @"public.content", @"public.data", @"public.folder", @"public.zip-archive"];
    DDFilePicker *picker = [[NSClassFromString(@"UIDocumentPickerViewController") alloc] initWithDocumentTypes:types inMode:0]; // 0 = Import
    picker.allowsMultipleSelection = YES;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(id)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSMutableArray<NSURL *> *scoped = [NSMutableArray array];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *u in urls) {
        if (!u.isFileURL || !u.path.length) continue;
        if ([u startAccessingSecurityScopedResource]) [scoped addObject:u];
        [paths addObject:u.path];
    }
    if (!paths.count) {
        for (NSURL *u in scoped) [u stopAccessingSecurityScopedResource];
        return;
    }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSInteger n = 0;
        for (NSString *p in paths) {
            BOOL isDir = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDir];
            if (isDir) {
                n += DD_ImportTemplatesFrom(p);
            } else if ([p.pathExtension.lowercaseString isEqualToString:@"zip"]) {
                NSString *dest = [tmp stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
                if (DD_UnzipToDirectory(p, dest)) n += DD_ImportTemplatesFrom(dest);
            }
        }
        if (!n) n = DD_ImportLooseFiles(paths); // 直接挑了 png + cfg

        dispatch_async(dispatch_get_main_queue(), ^{
            for (NSURL *u in scoped) [u stopAccessingSecurityScopedResource];
            [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
            DD_ShowToast(n > 0 ? [NSString stringWithFormat:@"已导入 %ld 个模板", (long)n] : @"没有找到可导入的模板");
            [self reloadList];
        });
    });
}

- (void)documentPickerWasCancelled:(id)controller { }

@end

#pragma mark - 设置界面

@interface DDShellSettingsViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDShellSettingsViewController

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

    // 导航栏：和素材库页同一套（不透明灰 + 无阴影线）
    DD_ApplyNavigationBarAppearance(self);

    // 分组底色不在这里设：沿用 WCTableViewManager 自带的那套（和 DD收款助手设置页完全一致）。
    // 原来强行钉成 systemGroupedBackgroundColor，跟微信自己的主题色差一档，两页放一起看就不一样。
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    // tableView.backgroundColor 保持不动（交给 WCTableViewManager），卡片之间/四周的底色和收款助手同源；
    // 卡片本身的颜色由微信的 cell 决定，本来两边就是一样的。
    [self.view addSubview:tableView];
}

// 从素材库返回时刷新「N 个 / 当前 X」
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}

- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls  = objc_getClass("WCTableViewSectionManager");
    [self.tableViewMgr clearAllSection];
    WCTableViewSectionManager *section = [secCls defaultSection];

    [section addCell:[cellCls switchCellForSel:@selector(enabledSwitchChanged:)
                                        target:self title:@"启用模板套壳"
                                            on:[DDShellConfig shared].enabled]];

    if ([DDShellConfig shared].enabled) {
        [section addCell:[cellCls switchCellForSel:@selector(autoSwitchChanged:)
                                            target:self title:@"↳截图自动套壳"
                                                on:[DDShellConfig shared].autoShell]];

        // 素材库入口：点进去是独立页面，导出/导入在该页右上角
        NSArray *tpls = DD_AllTemplateNames();
        NSString *active = DD_ActiveTemplateName();
        [section addCell:[cellCls normalCellForSel:@selector(openLibraryTapped:)
                                            target:self title:@"↳套壳素材库"
                                         rightValue:[NSString stringWithFormat:@"%lu 个 / 当前 %@",
                                                    (unsigned long)tpls.count, active.length ? active : @"无"]]];

        [section addCell:[cellCls switchCellForSel:@selector(deleteSwitchChanged:)
                                            target:self title:@"↳删除套壳截图"
                                                on:[DDShellConfig shared].deleteOriginal]];

        [section addCell:[cellCls normalCellForSel:@selector(pickFromAlbumTapped:)
                                            target:self title:@"↳相册选图套壳"
                                         rightValue:nil]];
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

- (void)openLibraryTapped:(id)sender {
    // push 前把上一页的返回标题清空，素材库页就只剩系统那个返回箭头，不会带「模板套壳设置」字样。
    // 必须在 push 之前设，否则转场动画里会先闪一下旧标题。
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
    [self.navigationController pushViewController:[DDShellLibraryViewController new] animated:YES];
}

- (void)enabledSwitchChanged:(UISwitch *)sender {
    [DDShellConfig shared].enabled = sender.isOn;
    [self buildTable];
}
- (void)autoSwitchChanged:(UISwitch *)sender {
    [DDShellConfig shared].autoShell = sender.isOn;
    [self buildTable];
}
- (void)deleteSwitchChanged:(UISwitch *)sender {
    [DDShellConfig shared].deleteOriginal = sender.isOn;
    [self buildTable];
}

#pragma mark - 相册选图套壳

// 从相册挑选一张图，套入当前模板后存回相册（不删除所选原图）
- (void)pickFromAlbumTapped:(id)sender {
    if (!DD_TemplateNamed(DD_ActiveTemplateName())) return; // 无可用模板则不开选择器
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        UIImage *img = info[UIImagePickerControllerOriginalImage];
        DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
        if (!img || !t) return;
        DD_ShowShelling();
        UIImage *outImg = DD_ComposeShellImage(img, t);
        if (!outImg) { DD_HideShelling(); return; } // 合成失败：静默收起提示
        DD_SaveImageToAlbum(outImg); // 相册选图套壳不删除原图
        DD_ShowShellDone();
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        (void)[DDShellConfig shared];
        [DDShellWatcher shared]; // 挂载截图监听

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                      version:@"1.0.0"
                                                   controller:@"DDShellSettingsViewController"];
        }
    }
}

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
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 微信原生弹层。运行时按类名取，编译期不引用符号；方法签名挂在 NSObject 分类上只为通过编译。
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
    return [arr containsObject:lid];
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

// 在指定目录里找 name.ext。扩展名大小写不敏感：iOS 文件系统大小写敏感，
// 直接拼小写扩展名会漏掉 Name.PNG / Name.CFG。
static NSString *DD_FileInFolder(NSString *dir, NSString *name, NSString *ext) {
    if (!dir.length || !name.length) return nil;
    NSString *want = [[name stringByAppendingPathExtension:ext] lowercaseString];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *f in files) {
        if ([f.lowercaseString isEqualToString:want]) return [dir stringByAppendingPathComponent:f];
    }
    return nil;
}

// 在模板自己的目录里找 name.ext
static NSString *DD_ActualFile(NSString *name, NSString *ext) {
    return DD_FileInFolder(DD_TplFolder(name), name, ext);
}

// 模板 cfg 路径：<模板目录>/<名称>.cfg（扩展名大小写不敏感）
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
    NSArray *items = [fm contentsOfDirectoryAtPath:DD_TplDir() error:nil];
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
    NSString *png = DD_ActualFile(name, @"png");
    NSData *d = png ? [NSData dataWithContentsOfFile:png] : nil;
    if (!d.length) return nil;
    UIImage *img = [UIImage imageWithData:d];
    if (!img) return nil;

    DDShellTemplate *t = [DDShellTemplate new];
    t.name = name;
    t.image = img;

    // cfg 缺失则模板不生效
    NSDictionary *cfg = DD_LoadCfg(name);
    if (!cfg) return nil;

    // 画布尺寸取 cfg 的 template_width / template_height
    double lw = [cfg[@"template_width"] doubleValue];
    double lh = [cfg[@"template_height"] doubleValue];
    CGSize canvas = CGSizeMake(lw, lh);

    NSArray *keys = @[@"left_top", @"right_top", @"left_bottom", @"right_bottom"];
    CGPoint pts[4];
    for (NSUInteger i = 0; i < 4; i++) {
        id x = cfg[[keys[i] stringByAppendingString:@"_x"]];
        id y = cfg[[keys[i] stringByAppendingString:@"_y"]];
        if (!x || !y) return nil; // 四角缺一个则模板不生效
        pts[i] = CGPointMake([x doubleValue], [y doubleValue]);
    }
    t.canvasSize = canvas;
    t.lt = pts[0]; t.rt = pts[1]; t.lb = pts[2]; t.rb = pts[3];
    return t;
}

// 当前生效的模板：只认显式应用过的那个，库里有但没应用过就算没有
static NSString *DD_ActiveTemplateName(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    return (sel.length && DD_TemplateNamed(sel)) ? sel : @"";
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
    // 尺寸来自 cfg，上限也得挡：不加的话一个离谱的 template_width 就会去开几亿像素的
    // 画布，内存打满直接闪退，连「套壳失败」都来不及弹。8192 是 CoreGraphics 常见纹理上限。
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil;

    // 截图按实际像素尺寸参与计算
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 输出画布固定 1 倍（1 单位 = 1 像素），输出尺寸才严格等于模板尺寸；
    // 用屏幕倍率（2x/3x）会把画布放大、截图拉伸变糊。
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);

    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 整张截图透视映射到 cfg 四角围成的屏幕窗；
    // inputExtent 用截图自身像素尺寸，四角落在模板画布坐标系里，保证 1:1 贴合。
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
    done([r firstObject]);
}

static void DD_SaveImageToAlbum(UIImage *img) {
    __block PHObjectPlaceholder *ph = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromImage:img];
        ph = req.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        // 成品也标记为已处理，避免之后被当成未处理截图重复套壳
        if (success && ph.localIdentifier.length) {
            [[DDShellConfig shared] markProcessed:ph.localIdentifier];
        }
    }];
}

static void DD_DeleteAssets(NSArray<PHAsset *> *assets) {
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest deleteAssets:assets];
    } completionHandler:nil];
}

#pragma mark - 监听器

// 微信内置提示控件，运行时按类名获取，编译期不产生链接符号
@interface WeToast : NSObject
+ (instancetype)toast;
- (void)setLoadingStyle:(BOOL)style;
- (void)showToastWithText:(NSString *)text;
- (void)showDoneToastWithText:(NSString *)text;   // 方形带 ✓
- (void)showErrorToastWithText:(NSString *)text;  // 方形带错误图标
- (void)hideWithAnimated:(BOOL)animated;
@end

static WeToast *gBusyToast = nil; // 进行中的「正在套壳」loading 提示，完成后收起

// 连拍互斥：同一时刻只处理一张，处理中到达的截屏事件直接丢弃
static dispatch_queue_t gShellQueue = nil;
static BOOL gShellBusy = NO;

static WeToast *DD_Toast(void) {
    return [NSClassFromString(@"WeToast") toast];
}

// 开始 loading / 收起 loading / 成功 / 失败 / 纯文字
static void DD_ShowShelling(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WeToast *toast = DD_Toast();
        [toast setLoadingStyle:YES];
        [toast showToastWithText:@"正在套壳"];
        gBusyToast = toast;
    });
}
static void DD_ShowShellDone(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
        [DD_Toast() showDoneToastWithText:@"套壳成功"];
    });
}
static void DD_ShowShellError(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // loading 和这个是同一个 WeToast 实例，先收起再弹
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
        [DD_Toast() showErrorToastWithText:text];
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
    // 等系统把截图写入相册后再取
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDDShellDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!gShellQueue) gShellQueue = dispatch_queue_create("com.ddshell.shell", DISPATCH_QUEUE_SERIAL);
        dispatch_async(gShellQueue, ^{
            if (gShellBusy) return; // 连拍：已有任务在处理，本次丢弃
            gShellBusy = YES;
            [self shellLatestScreenshotWithCompletion:^{
                dispatch_async(gShellQueue, ^{
                    gShellBusy = NO;
                });
            }];
        });
    });
}

- (void)shellLatestScreenshotWithCompletion:(void (^)(void))completion {
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!t) { completion(); return; }
    DD_LatestImageAsset(^(PHAsset *asset) {
        if (!asset) { completion(); return; }
        if ([[DDShellConfig shared] hasProcessed:asset.localIdentifier]) { completion(); return; } // 去重
        PHImageRequestOptions *ro = [PHImageRequestOptions new];
        ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        ro.networkAccessAllowed = NO;
        [self dd_showShelling];
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:PHImageManagerMaximumSize
                                                  contentMode:PHImageContentModeDefault
                                                      options:ro
                                                resultHandler:^(UIImage *img, NSDictionary *info) {
            UIImage *outImg = (img) ? DD_ComposeShellImage(img, t) : nil;
            if (!outImg) { DD_ShowShellError(@"套壳失败"); completion(); return; }
            DD_SaveImageToAlbum(outImg);
            [[DDShellConfig shared] markProcessed:asset.localIdentifier];
            if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
            [self dd_showShellDone];
            completion();
        }];
    });
}

// 转发到文件级静态函数，供截图路径调用
- (void)dd_showShelling { DD_ShowShelling(); }
- (void)dd_showShellDone { DD_ShowShellDone(); }


@end

#pragma mark - 导入导出

// 微信自带的 zip 库，运行时按类名取，编译期不产生链接符号
@interface DDZipArchive : NSObject
+ (BOOL)createZipFileAtPath:(id)zipPath withContentsOfDirectory:(id)dir keepParentDirectory:(BOOL)keep;
+ (BOOL)unzipFileAtPath:(id)zipPath toDestination:(id)dest;
@end

// 系统文件选择器，运行时按类名取，编译期不产生链接符号
@interface DDFilePicker : UIViewController
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)types inMode:(NSInteger)mode;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic, weak) id delegate;
@end

// 打包整个目录，zip 内保留该目录名
static BOOL DD_ZipDirectory(NSString *srcDir, NSString *zipPath) {
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
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
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
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
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

// 微信原生弹窗（运行时按类名取，编译期不产生链接符号）。
// 按钮回调全用无参 selector：微信调用时带不带参数不确定，无参声明收不到也安全，
// 反过来说带参声明读不到值就是垃圾数据。按钮靠不同 selector 区分，输入框内容用
// getTextFieldText 从存下来的实例里取。
@interface WCUIAlertView : NSObject
- (instancetype)initWithTitle:(id)title message:(id)message;
- (void)addBtnTitle:(id)title target:(id)target sel:(SEL)sel;
- (void)setTextFieldDefaultText:(id)text;
- (void)showTextFieldWithMaxLen:(unsigned int)len;
- (void)show;
- (id)getTextFieldText;
@end

// 两个 sheet 的 tag：套壳操作 / 选择导出方式
static const NSInteger DD_SHEET_TPL    = 0x5e9d;
static const NSInteger DD_SHEET_EXPORT = 0x5ea1;

// 网格排布：列数与间距。格子宽 = (页面宽 - gap * (列数 + 1)) / 列数
static const NSInteger kDDShellTplColumns = 2;
static const CGFloat   kDDShellTplGap     = 10.0;
static const CGFloat   kDDShellSearchH    = 44.0;

// 缩略图缓存：模板 png 是全尺寸图（可能上千像素），每格都整图解一次码滚动会卡。
// 按格子边长解码一次后缓存；key 里带路径，重命名后不会串图。
static NSCache *DD_ThumbCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 80;
    });
    return cache;
}

static NSString *DD_ThumbKey(NSString *name, CGFloat side) {
    NSString *path = DD_ActualFile(name, @"png");
    return (path.length && side > 0) ? [NSString stringWithFormat:@"%@|%d", path, (int)side] : nil;
}

// 只查缓存，读不到就返回 nil：主线程调这个，不解码
static UIImage *DD_CachedThumb(NSString *name, CGFloat side) {
    NSString *key = DD_ThumbKey(name, side);
    return key ? [DD_ThumbCache() objectForKey:key] : nil;
}

// 生成缩略图并进缓存：会解整张 png，只在后台线程调
static UIImage *DD_ThumbForName(NSString *name, CGFloat side) {
    NSString *key = DD_ThumbKey(name, side);
    if (!key) return nil;

    UIImage *hit = [DD_ThumbCache() objectForKey:key];
    if (hit) return hit;

    UIImage *src = [UIImage imageWithContentsOfFile:DD_ActualFile(name, @"png")];
    if (!src || src.size.width <= 0 || src.size.height <= 0) return nil;

    CGFloat rate = MIN(side / src.size.width, side / src.size.height); // 等比缩放
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
        self.contentView.layer.cornerRadius = 8.0;
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

// 分组底色：直接取设置页 tableView 的底色，两页同源，微信换主题时跟着一起变。
// 素材库入口在设置页上，必然先经过设置页，所以到这里一定有值。
static UIColor *DD_GroupBackgroundColor = nil;

// 导航栏底边：全屏布局下 view.safeAreaInsets.top 就是它（状态栏 + 导航栏）。
// 微信的 Coordinator 会改写 VC 的 safeArea，偶尔量出来是 0，回退到导航栏的标准总高。
static CGFloat DD_TopUnderNavBar(UIView *view) {
    CGFloat top = view.safeAreaInsets.top;
    return top > 0 ? top : 64.0;
}

// 导航栏外观不碰：8.0.79 由 WCCustomNavigationBar / WCCustomNavigationBarCoordinator
// 自己实现整套导航栏（背景、标题、返回箭头、转场渲染），不走 UIKit 的 UINavigationBarAppearance。
// 按钮颜色按 item 钉，见 navButton:。

// 独立的素材库页面：
//   双排网格列出模板，右上角常驻 导出 / 导入（导入最靠右），默认按名称排序；
//   点「导出」用微信原生 WCActionSheet 弹「选择导出方式」：选择导出 / 全部导出（取消自带）；
//   「选择导出」进入选择态，右上角换成 删除 / 导出 / 取消；
//   单点一个模板弹 WCActionSheet「套壳操作」：应用模板 / 重命名 / 选择 / 删除此模板，
//   选「选择」同样进选择态。
@interface DDShellLibraryViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;           // 自己贴在 view 顶上的搜索框（不挂 navigationItem.searchController，那个会撑高导航栏）
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray<NSString *> *allNames;    // 排序后的全量，搜索只是过滤展示
@property (nonatomic, strong) NSArray<NSString *> *names;       // 当前展示（可能是过滤结果）
@property (nonatomic) BOOL isSelectMode;                        // 是否处于选择态
@property (nonatomic, strong) NSMutableSet<NSString *> *picked; // 选择态下勾选的模板
@property (nonatomic, copy) NSString *tappedTpl;                // 刚弹出操作菜单的那个模板
@property (nonatomic, copy) NSString *activeName;               // 当前生效的模板，列表刷新时算一次（每格现算会各解码一次全尺寸 png）
@property (nonatomic, strong) WCUIAlertView *renameAlert;       // 正在弹的重命名框，回调里取输入框内容用
@property (nonatomic, copy) NSString *renamingName;             // 正在改名的模板原名
@property (nonatomic, strong) NSArray<NSString *> *pendingDelete; // 删除确认框待删的模板
@end

@implementation DDShellLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.picked = [NSMutableSet set];

    // 保持默认全屏布局：不设 edgesForExtendedLayout = UIRectEdgeNone —— 它靠改 view 的
    // safeAreaInsets 实现，而微信的 Coordinator 转场时也在改同一块状态，两边一起改会对不齐。
    // 导航栏底下的位置在 viewDidLayoutSubviews 里量 safeAreaInsets.top 推算（见下方）。

    // 与设置页同一个底色
    self.view.backgroundColor = DD_GroupBackgroundColor;

    [self setupSearchBar];
    [self setupCollectionView];
    [self setupNavigationBar];
    [self reloadList];
}

// 搜索条自己贴在 view 顶上，不挂 navigationItem.searchController（那个会撑高导航栏）。
// minimal 样式没有自带的灰底和分隔线，四周透出页面底色，和导航栏连成一片。
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
    cv.backgroundColor = [UIColor clearColor]; // 透明，透出页面底色
    cv.alwaysBounceVertical = YES;
    cv.delegate = self;
    cv.dataSource = self;
    [cv registerClass:[DDShellTplCell class] forCellWithReuseIdentifier:@"DDShellTplCell"];
    self.collectionView = cv;
    [self.view addSubview:cv];
}

// 搜索条压在最上面，网格从它底下铺满剩余空间
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = DD_TopUnderNavBar(self.view);
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    self.searchBar.frame = CGRectMake(0, top, w, kDDShellSearchH);
    self.collectionView.frame = CGRectMake(0, top + kDDShellSearchH, w, h - top - kDDShellSearchH);
}

// 返回按钮不自定义：箭头由微信 Coordinator 的 defaultBackIndicator 生成，
// 前提是 push 走微信自己的 PushViewController:animated:（见 openLibraryTapped:）。
// 自定义 leftBarButtonItem 还会让边缘侧滑返回失效。

// 默认按名称排序（本地化、数字感知：「模板2」排在「模板10」前面）
- (void)reloadList {
    NSMutableArray *all = [DD_AllTemplateNames() mutableCopy];
    [all sortUsingSelector:@selector(localizedStandardCompare:)];
    self.allNames = all;
    self.activeName = DD_ActiveTemplateName();
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
    // 缩略图命中缓存当场给；没命中就丢后台解，回来时确认这格还显示着同一个模板再填
    cell.thumbView.image = DD_CachedThumb(n, w);
    if (!cell.thumbView.image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *img = DD_ThumbForName(n, w);
            if (!img) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                DDShellTplCell *c = (DDShellTplCell *)[cv cellForItemAtIndexPath:ip];
                if (c && [c.nameLabel.text isEqualToString:n]) c.thumbView.image = img;
            });
        });
    }

    BOOL picked = self.isSelectMode && [self.picked containsObject:n];
    BOOL active = !self.isSelectMode && [n isEqualToString:self.activeName];
    cell.checkLabel.hidden = !picked;
    cell.markView.hidden = !(picked || active);
    // 蓝框 = 已勾选待导出，绿框 = 当前正在用的模板
    cell.markView.layer.borderColor = picked ? [UIColor systemBlueColor].CGColor : [UIColor systemGreenColor].CGColor;
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)ip {
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
    [self showWCActionSheet:@"套壳操作" tag:DD_SHEET_TPL items:@[@"应用模板", @"重命名", @"选择", @"删除此模板"]];
}

#pragma mark 导航栏

// 按钮颜色按 item 钉：优先级是「item 自己的 titleTextAttributes」
// >「微信给 UIBarButtonItem 定的 appearance 代理」>「导航栏外观的 buttonAppearance」，
// 只有最上面那层钉得住。钉的颜色取导航栏 tintColor，跟着微信主题走，不写死。
- (UIBarButtonItem *)navButton:(NSString *)title action:(SEL)action {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:action];
    UIColor *tint = self.navigationController.navigationBar.tintColor;
    [item setTitleTextAttributes:@{ NSForegroundColorAttributeName: tint } forState:UIControlStateNormal];
    return item;
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
    // rightBarButtonItems 数组首个显示在最靠屏幕边缘：取消 / 导入贴着右边缘，左侧不动
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:right];
    [items addObject:mid];
    if (left) [items addObject:left]; // 普通态没有第三个，addObject:nil 会崩
    self.navigationItem.rightBarButtonItems = items;
}

#pragma mark 微信原生 WCActionSheet

// 构造微信原生 WCActionSheet：init → 塞 WCActionSheetItem → 设 buttonTitleList / tag → showInView:
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
// 自带「取消」的 index 落在所有 item 之后，不会命中任何分支。
- (void)actionSheet:(id)sheet clickedButtonAtIndex:(NSInteger)idx {
    NSInteger tag = [sheet tag];

    if (tag == DD_SHEET_EXPORT) { // 选择导出方式：0=选择导出 1=全部导出
        if (idx == 0) [self enterExportSelectMode];
        else if (idx == 1) [self exportAllFrames];
    } else if (tag == DD_SHEET_TPL) { // 套壳操作：0=应用模板 1=重命名 2=选择 3=删除此模板
        NSString *n = self.tappedTpl;
        if (idx == 0 && n.length) {
            [DDShellConfig shared].selectedTpl = n;
            [self reloadList]; // 绿框挪到新模板上就是反馈
        } else if (idx == 1 && n.length) {
            [self renameTemplateNamed:n];
        } else if (idx == 2) {
            [self enterExportSelectModeWithName:n];
        } else if (idx == 3 && n.length) {
            [self confirmDeleteNames:@[n]];
        }
    }
    self.tappedTpl = nil;
}

#pragma mark 导出

// 点「导出」：选择态直接导出勾选的；普通态先问「选择导出」还是「全部导出」
- (void)exportButtonTapped {
    if (self.isSelectMode) { [self exportSelectedFrames]; return; }
    if (!self.names.count) return; // 空素材库静默返回

    [self showWCActionSheet:@"选择导出方式" tag:DD_SHEET_EXPORT items:@[@"选择导出", @"全部导出"]];
}

// 进入选择态：勾选清空，右上角换成 删除 / 导出 / 取消
- (void)enterExportSelectMode {
    self.isSelectMode = YES;
    [self.picked removeAllObjects];
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

// 从「套壳操作 → 选择」进入：顺手把那一个勾上
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
    [self shareZipForNames:names];
}

// 「全部导出」= 当前列表全量导出
- (void)exportAllFrames {
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
    self.renamingName = name;
    WCUIAlertView *av = [[NSClassFromString(@"WCUIAlertView") alloc] initWithTitle:@"重命名" message:name];
    [av setTextFieldDefaultText:name];
    [av addBtnTitle:@"取消" target:self sel:@selector(ddAlertCancelled)];
    [av addBtnTitle:@"确定" target:self sel:@selector(ddRenameConfirmed)];
    [av showTextFieldWithMaxLen:32];
    [av show];
    self.renameAlert = av;
}

- (void)ddRenameConfirmed {
    NSString *text = [self.renameAlert getTextFieldText];
    NSString *oldName = self.renamingName;
    self.renameAlert = nil;
    self.renamingName = nil;
    [self renameTemplate:oldName to:text];
}

// 目录和目录里的 png/cfg 一起改名；当前正在用的模板被改名则同步选中记录
- (void)renameTemplate:(NSString *)oldName to:(NSString *)newName {
    newName = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!newName.length) { DD_ShowToast(@"名字不能为空"); return; }
    if ([newName isEqualToString:oldName]) return;
    if ([newName containsString:@"/"]) { DD_ShowToast(@"名字不能包含 /"); return; }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDir = DD_TplFolder(oldName), *dstDir = DD_TplFolder(newName);
    if (!srcDir.length || !dstDir.length) return; // 挡 fileExistsAtPath:nil 的崩
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

// 实际删除：连整目录一起删；删掉的是当前模板则清空选择
- (void)deleteNames:(NSArray<NSString *> *)names {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger n = 0;
    for (NSString *name in names) {
        NSString *dir = DD_TplFolder(name);
        if (dir.length && [fm removeItemAtPath:dir error:nil]) n++;
    }
    // 删掉正在用的就清空选择，不自动顶下一个
    if ([names containsObject:[DDShellConfig shared].selectedTpl]) {
        [DDShellConfig shared].selectedTpl = @"";
    }
    DD_ShowToast([NSString stringWithFormat:@"已删除 %ld 个模板", (long)n]);
}

// 选择态点右上角「删除」：先确认再删
- (void)deleteSelectedFrames {
    NSArray *names = [self.picked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [self confirmDeleteNames:names];
}

// 删除确认，单个和批量共用
- (void)confirmDeleteNames:(NSArray<NSString *> *)names {
    NSString *msg = names.count == 1
        ? [NSString stringWithFormat:@"确定要删除「%@」这个套壳模板吗？", names.firstObject]
        : [NSString stringWithFormat:@"确定要删除选中的 %ld 个套壳模板吗？", (long)names.count];

    self.pendingDelete = names;
    WCUIAlertView *av = [[NSClassFromString(@"WCUIAlertView") alloc] initWithTitle:@"确认删除" message:msg];
    [av addBtnTitle:@"取消" target:self sel:@selector(ddAlertCancelled)];
    [av addBtnTitle:@"删除" target:self sel:@selector(ddDeleteConfirmed)];
    [av show];
}

- (void)ddDeleteConfirmed {
    NSArray *names = self.pendingDelete;
    self.pendingDelete = nil;
    [self deleteNames:names];
    [self reloadList];                                    // 重新读盘排序，去掉已删的
    if (self.isSelectMode) [self cancelExportSelectMode]; // 再退出选择态
}

// 取消按钮共用：把弹窗带的临时状态清掉
- (void)ddAlertCancelled {
    self.renameAlert = nil;
    self.renamingName = nil;
    self.pendingDelete = nil;
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
        if (!u.path.length) continue; // 防 addObject:nil 崩
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
        if (!n) n = DD_ImportLooseFiles(paths); // 直接挑了 png + cfg 的情况

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

// 微信私有的 push（大写 P）：只有走它，Coordinator 才会接管返回箭头。
// 头文件 dump 里没有，真机存在；不判 respondsToSelector —— 取不到就直接崩，比静默退化好查。
@interface UINavigationController (DDShellWCPush)
- (void)PushViewController:(UIViewController *)viewController animated:(BOOL)animated;
@end

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

    // 导航栏不设任何外观，保持微信原样（见上方说明）。
    // backBarButtonItem 也不设：微信只在走自己的 PushViewController: 时才接管返回按钮。

    // 页面底色直接取现成 tableView 的底色，顺手存进 DD_GroupBackgroundColor 给素材库用 ——
    // 素材库入口就在本页，必然先走到这里。
    UITableView *tableView = [self.tableViewMgr getTableView];
    DD_GroupBackgroundColor = tableView.backgroundColor;
    self.view.backgroundColor = DD_GroupBackgroundColor;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    // tableView 的底色交给 WCTableViewManager 不动；frame 交给 viewDidLayoutSubviews。
    [self.view addSubview:tableView];
}

// 表格从导航栏底下开始：全屏铺的话往上滚单元格会从导航栏底下穿过，
// 微信自己的页面靠导航栏的毛玻璃糊住，我们这层没有，所以直接空出来（与素材库同一套算法）。
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = DD_TopUnderNavBar(self.view);
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = CGRectMake(0, top,
                                 self.view.bounds.size.width,
                                 self.view.bounds.size.height - top);
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
    // 走微信自己的 PushViewController:animated:（声明见上方），返回箭头才归微信管
    [self.navigationController PushViewController:[DDShellLibraryViewController new] animated:YES];
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
    // 没有可用模板时给个提示，否则点了没反应
    if (!DD_TemplateNamed(DD_ActiveTemplateName())) { DD_ShowToast(@"模板未选择"); return; }
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
        if (!t) { DD_ShowShellError(@"套壳失败"); return; } // 选图这会儿模板没了
        DD_ShowShelling();
        UIImage *outImg = DD_ComposeShellImage(img, t);
        if (!outImg) { DD_ShowShellError(@"套壳失败"); return; }
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

        // 取不到类时整条链都是给 nil 发消息，ObjC 天然 no-op
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                  version:@"1.0.0"
                                               controller:@"DDShellSettingsViewController"];
    }
}

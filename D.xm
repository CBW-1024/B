// ============================================================================
//  DDShell.xm —— 模板套壳（截图后套模板并保存到相册）  v3.0.0
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  ── 逆向来源 ──────────────────────────────────────────────────────────────
//  ZDY_v1.3.7.dylib : ScreenshotShellHelper / SSShellLibraryVC / SSShellEditorVC
//                     PHPhotoLibrary 落相册
//  WCRefine.dylib   : 完整工业级实现，本版按它校正合成算法
//      WCRefineScreenshotFrameProcessor  @ 0x279da60
//          applyFrameToImage:secondImage:   0x74659c  ← 真正的合成主体
//          applyFrameToImage:               0x7464f4  （薄封装，尾调用上面那个）
//      WCRefineScreenRecordingFrameTemplate @ 0x279d948（录屏路径，本插件不涉及）
//
//  ── WCR applyFrameToImage:secondImage: 的真实指令流（已逐条反汇编核对）────
//   objc_msgSend = __got[0x640]；模板 cfg 全为 objectForKeyedSubscript: + floatValue
//   1. W = cfg["template_width"]，H = cfg["template_height"]；W<=0 || H<=0 直接返回 nil
//   2. frame = [UIImage imageWithContentsOfFile: <机身前景图路径>]
//      scale = frame.scale；scale <= 0 时回退 [UIScreen mainScreen].scale
//   3. UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, scale)
//      ctx = UIGraphicsGetCurrentContext()
//   4. CIContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@NO}]
//      （GOT[0x708] = _kCIContextUseSoftwareRenderer，值为 @NO，即强制走 GPU）
//   5. shotCG = [shot CGImage]
//      A = CGImageGetWidth(shotCG)，B = CGImageGetHeight(shotCG)
//      src = [CIImage imageWithCGImage:shotCG]
//   6. f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"]
//      setValue:forKey: 共 6 次（kCIInputImageKey 从 GOT[0x720] 取）：
//        inputTopLeft      = CIVector(LT.x, H - LT.y)
//        inputTopRight     = CIVector(RT.x, H - RT.y)
//        inputBottomLeft   = CIVector(LB.x, H - LB.y)
//        inputBottomRight  = CIVector(RB.x, H - RB.y)
//        inputExtent       = CIVector(CGRectMake(0, 0, A, B))   ← 截图自身像素尺寸
//      （CFG 字符串已确认：inputTopLeft/inputTopRight/inputBottomLeft/
//        inputBottomRight/inputExtent，滤镜名 CIPerspectiveTransformWithExtent）
//   7. cg = [ciCtx createCGImage:f.outputImage fromRect:f.outputImage.extent]
//      CGContextDrawImage(ctx, extent, cg)          ← 1:1，不做二次缩放
//      CGImageRelease(cg)
//      （第二张图 secondImage 走同一套，mode=double 时用）
//   8. [frame drawInRect:CGRectMake(0, 0, W, H)]    ← 机身图盖在最上层
//   9. out = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext()
//
//  ── 由上面第 6/7 条得出的关键结论（本版据此修正模糊与尺寸错位）────────────
//   ★ 截图【整张】透视映射到 cfg 四角围成的屏幕窗，且 inputExtent 必须是
//     「截图自身的像素尺寸 (A,B)」，四角点落在模板画布坐标系 (W,H) 中。
//     这样无论模板多大，截图都恰好 1:1 填满窗口（像素级贴合），不会出现
//     「截图被缩放 / 窗口尺寸对不上」的问题。之前用 Wout×Hout 当 inputExtent
//     并给角点乘 S 是错的，会让角点跑到 extent 外被裁、尺寸错位。
//   ★ WCR【不做任何超采样】，输出就是 template_width×template_height × scale
//     （模板 PNG 为 1× 时 scale=1）。绝不能用 UIGraphicsImageRenderer 的
//     默认 scale（= 屏幕 2x/3x），那会把画布放大 3 倍、截图被拉伸 3 倍 → 糊。
//   ★ 输出画布固定 1×（1 单位 = 1 像素 = 模板像素），保证输出尺寸严格等于
//     template_width×template_height。不用默认 scale（= 屏幕 2x/3x），否则画布被放大 3 倍。
//
//  ── 模板格式（强制 png + cfg 成对）────────────────────────────────────────
//  把 name.png 与 name.cfg 一起放进 Documents/DDShellTemplates/。两者缺一则
//  该模板不生效（不自动探测、不回退 _dark）。name.cfg 为 JSON，字段：
//    {"template_width":1170,"template_height":2532,
//     "left_top_x":..,"left_top_y":.., "right_top_x":..,"right_top_y":..,
//     "left_bottom_x":..,"left_bottom_y":.., "right_bottom_x":..,"right_bottom_y":..}
//  四角坐标为模板像素坐标（左上原点），即屏幕窗在 PNG 中的位置。
//
//  本插件不 hook 微信内部逻辑，纯系统层实现：
//    截图 → UIApplicationUserDidTakeScreenshotNotification
//    取相册最新截图 → 透视贴进模板屏幕窗 → 存回相册
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明（入口用，与 DD收款助手保持一致，勿改）

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

static NSString *const kDDShellEnabled     = @"DDShellEnabled";
static NSString *const kDDShellAuto        = @"DDShellAutoShell";
static NSString *const kDDShellSelectedTpl = @"DDShellSelectedTpl";
static NSString *const kDDShellShotDelay   = @"DDShellShotDelay";
static NSString *const kDDShellDeleteSrc   = @"DDShellDeleteOriginal";
static NSString *const kDDShellProcessed   = @"DDShellProcessedIds";

@interface DDShellConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL autoShell;
@property (nonatomic) BOOL deleteOriginal;
@property (nonatomic) double shotDelay;
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
        _enabled        = [ud objectForKey:kDDShellEnabled]   ? [ud boolForKey:kDDShellEnabled]   : NO;
        _autoShell      = [ud objectForKey:kDDShellAuto]      ? [ud boolForKey:kDDShellAuto]      : YES;
        _deleteOriginal = [ud objectForKey:kDDShellDeleteSrc] ? [ud boolForKey:kDDShellDeleteSrc] : NO;
        _shotDelay      = [ud objectForKey:kDDShellShotDelay] ? [ud doubleForKey:kDDShellShotDelay] : 1.2;
        if (_shotDelay < 0) _shotDelay = 0;
        _selectedTpl = [ud stringForKey:kDDShellSelectedTpl] ?: @"";
        [ud setBool:_enabled forKey:kDDShellEnabled];
        [ud setBool:_autoShell forKey:kDDShellAuto];
        [ud setBool:_deleteOriginal forKey:kDDShellDeleteSrc];
        [ud setDouble:_shotDelay forKey:kDDShellShotDelay];
        [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v        { _enabled = v;        [self dd_setBool:v forKey:kDDShellEnabled]; }
- (void)setAutoShell:(BOOL)v      { _autoShell = v;      [self dd_setBool:v forKey:kDDShellAuto]; }
- (void)setDeleteOriginal:(BOOL)v { _deleteOriginal = v; [self dd_setBool:v forKey:kDDShellDeleteSrc]; }
- (void)setShotDelay:(double)v    { _shotDelay = v;      [self dd_setDouble:v forKey:kDDShellShotDelay]; }
- (void)setSelectedTpl:(NSString *)v {
    _selectedTpl = [v copy] ?: @"";
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
    [ud synchronize];
}

- (void)dd_setBool:(BOOL)v forKey:(NSString *)k {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:v forKey:k];
    [ud synchronize];
}
- (void)dd_setDouble:(double)v forKey:(NSString *)k {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setDouble:v forKey:k];
    [ud synchronize];
}

// 已处理过的 asset 去重（对应 WCR 的 AlbumEnhancementProcessedIds）
- (BOOL)hasProcessed:(NSString *)lid {
    if (!lid.length) return NO;
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:kDDShellProcessed];
    return arr ? [arr containsObject:lid] : NO;
}
- (void)markProcessed:(NSString *)lid {
    if (!lid.length) return;
    NSArray *old = [[NSUserDefaults standardUserDefaults] arrayForKey:kDDShellProcessed] ?: @[];
    NSMutableArray *m = [old mutableCopy];
    [m addObject:lid];
    if (m.count > 200) m = [[m subarrayWithRange:NSMakeRange(m.count - 200, 200)] mutableCopy];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:m forKey:kDDShellProcessed];
    [ud synchronize];
}

@end

#pragma mark - 模板目录

// Documents/DDShellTemplates/（WCR 用 Documents/WCRefine/frames，结构相同）
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

#pragma mark - 模板模型

@interface DDShellTemplate : NSObject
@property (nonatomic, copy)   NSString *name;        // 模板名（不含扩展名）
@property (nonatomic, strong) UIImage  *image;       // 机身前景图（png）
@property (nonatomic)         CGSize    canvasSize;  // 模板画布像素尺寸（来自 cfg 的 template_width/height）
@property (nonatomic)         CGPoint   lt, rt, lb, rb; // 屏幕窗四角（UIKit 坐标，左上原点，像素，来自 cfg）
@end

@implementation DDShellTemplate
@end

// 机身前景图（模板只支持 png+cfg，不再有 _dark 变体）
static UIImage *DD_FrameImage(DDShellTemplate *t) {
    return t.image;
}

static NSString *DD_CfgPath(NSString *name) {
    return [[DD_TplDir() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"cfg"];
}

static NSDictionary *DD_LoadCfg(NSString *name) {
    NSData *d = [NSData dataWithContentsOfFile:DD_CfgPath(name)];
    if (!d.length) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

// 素材库：仅保留「同时具备 name.png 与 name.cfg」的模板（强制 png+cfg 成对）
static NSArray<NSString *> *DD_AllTemplateNames(void) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:DD_TplDir() error:nil] ?: @[];
    NSMutableSet *pngs = [NSMutableSet set];
    NSMutableSet *cfgs = [NSMutableSet set];
    for (NSString *f in files) {
        NSString *low = f.lowercaseString;
        NSString *base = f.stringByDeletingPathExtension;
        if ([low hasSuffix:@".png"])      [pngs addObject:base];
        else if ([low hasSuffix:@".cfg"]) [cfgs addObject:base];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *b in pngs) {
        if ([cfgs containsObject:b]) [out addObject:b]; // 必须 png 与 cfg 同时存在
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

static DDShellTemplate *DD_TemplateNamed(NSString *name) {
    if (!name.length) return nil;
    NSString *png = [[DD_TplDir() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"png"];
    NSData *d = [NSData dataWithContentsOfFile:png];
    if (!d.length) {
        NSString *jpg = [[DD_TplDir() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"jpg"];
        d = [NSData dataWithContentsOfFile:jpg];
        if (!d.length) return nil;
    }
    UIImage *img = [UIImage imageWithData:d];
    if (!img || img.size.width < 8 || img.size.height < 8) return nil;

    DDShellTemplate *t = [DDShellTemplate new];
    t.name = name;
    t.image = img;

    // cfg 必须存在，否则模板不生效（不再自动探测、不回退）
    NSDictionary *cfg = DD_LoadCfg(name);
    if (!cfg) return nil;

    // 画布尺寸优先取 cfg 的 template_width/height（对齐 WCR）；缺省则用图片自身像素尺寸，
    // 以免手作 cfg 漏写这两个字段时模板被误判为无效。
    double lw = [cfg[@"template_width"] doubleValue];
    double lh = [cfg[@"template_height"] doubleValue];
    CGFloat iw = img.size.width * img.scale;
    CGFloat ih = img.size.height * img.scale;
    CGSize canvas = (lw > 0 && lh > 0) ? CGSizeMake(lw, lh) : CGSizeMake(iw, ih);

    NSArray *keys = @[@"left_top", @"right_top", @"left_bottom", @"right_bottom"];
    CGPoint pts[4];
    BOOL ok = YES;
    for (NSUInteger i = 0; i < 4; i++) {
        id x = cfg[[keys[i] stringByAppendingString:@"_x"]];
        id y = cfg[[keys[i] stringByAppendingString:@"_y"]];
        if (![x respondsToSelector:@selector(doubleValue)] || ![y respondsToSelector:@selector(doubleValue)]) { ok = NO; break; }
        pts[i] = CGPointMake([x doubleValue], [y doubleValue]);
    }
    if (!ok) return nil; // 四角缺失 → 模板不生效

    t.canvasSize = canvas; // 画布尺寸
    t.lt = pts[0]; t.rt = pts[1]; t.lb = pts[2]; t.rb = pts[3];
    return t;
}

static NSString *DD_ActiveTemplateName(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    if (sel.length && DD_TemplateNamed(sel)) return sel;
    return [DD_AllTemplateNames() firstObject] ?: @"";
}


#pragma mark - 合成（核心：透视贴进屏幕窗）

// UIKit 坐标（左上原点）→ CoreImage 坐标（左下原点）
static CIVector *DD_CIVec(CGPoint p, CGFloat canvasH) {
    return [CIVector vectorWithCGPoint:CGPointMake(p.x, canvasH - p.y)];
}

static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    UIImage *frameImg = DD_FrameImage(t);
    CGImageRef frameCG = frameImg.CGImage;
    CGImageRef shotCG = shot.CGImage;
    if (!frameCG || !shotCG) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    if (W < 1.0 || H < 1.0) return nil;

    // 截图按【像素】计（与 WCR 一致：CGImageGetWidth/Height，不走 UIImage.size）
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 输出画布固定 1×（1 单位 = 1 像素 = 模板像素），保证输出尺寸 == template_width×template_height。
    // 绝不能用 UIGraphicsImageRenderer / beginContext 的默认 scale（= 屏幕 2x/3x），
    // 那会把画布放大 3 倍、截图被拉伸 3 倍 → 糊。
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);

    // 与 WCR 完全一致：CIContext 强制 GPU（kCIContextUseSoftwareRenderer = @NO）
    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 整张截图透视映射到 cfg 四角围成的屏幕窗。
    // ★ inputExtent 必须是截图自身像素尺寸 (A,B)，四角点落在模板画布 (W,H) 坐标系中，
    //   这样截图恰好 1:1 填满窗口，不会出现尺寸错位 / 被裁。
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
            // CI 的 extent 是左下原点坐标；UIKit 上下文是左上原点，转换后 1:1 贴入，
            // 用 [UIImage drawInRect:] 规避 CGContextDrawImage 在 UIKit 上下文里的翻转歧义。
            UIImage *layer = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
            CGRect r = CGRectMake(ext.origin.x,
                                 H - ext.origin.y - ext.size.height,
                                 ext.size.width, ext.size.height);
            [layer drawInRect:r];
            CGImageRelease(cg);
        }
    }

    // 机身前景图盖在最上层（WCR 用 [frame drawInRect:]）
    [frameImg drawInRect:CGRectMake(0, 0, W, H)];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - 相册

static void DD_EnsurePhotoAuth(void (^ready)(BOOL)) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus s) {
        if (ready) ready(s == PHAuthorizationStatusAuthorized || s == PHAuthorizationStatusLimited);
    }];
}

static void DD_LatestImageAsset(void (^done)(PHAsset *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:o];
    if (done) done([r firstObject]);
}

static void DD_SaveImageToAlbum(UIImage *img) {
    if (!img) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:img];
    } completionHandler:nil];
}

static void DD_DeleteAssets(NSArray<PHAsset *> *assets) {
    if (!assets.count) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest deleteAssets:assets];
    } completionHandler:nil];
}

#pragma mark - 监听器

// 微信原生 toast。工程未导入 WeToast.h，这里手写一份精简前向声明（完整 @interface），
// 仅补充套壳提示用到的几个方法。放在顶层、不进入任何 @implementation，编译器即视为已知类；
// theos 对 tweak 默认允许 undefined symbol 延迟绑定到宿主（微信）进程中的符号（与引用
// WCPluginsMgr / WCTableViewManager 等微信类同一机制），因此无需在编译期链接微信头文件。
@interface WeToast : NSObject
+ (instancetype)toast;
- (void)setLoadingStyle:(BOOL)style;
- (void)showToastWithText:(NSString *)text;
- (void)showDoneToastWithText:(NSString *)text;
- (void)hideWithAnimated:(BOOL)animated;
@end

static WeToast *gBusyToast = nil; // 进行中的「正在套壳」loading 提示，供成功后收起

@interface DDShellWatcher : NSObject
+ (instancetype)shared;
- (void)shellLatestScreenshot;
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
    NSTimeInterval delay = [DDShellConfig shared].shotDelay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self shellLatestScreenshot];
    });
}

- (void)shellLatestScreenshot {
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!t) return;
    DD_EnsurePhotoAuth(^(BOOL ok) {
        if (!ok) return;
        DD_LatestImageAsset(^(PHAsset *asset) {
            if (!asset) return;
            if ([[DDShellConfig shared] hasProcessed:asset.localIdentifier]) return; // 去重
            PHImageRequestOptions *ro = [PHImageRequestOptions new];
            ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            ro.networkAccessAllowed = NO;
            [self dd_showShelling]; // 开始：微信原生「正在套壳」转圈提示
            [[PHImageManager defaultManager] requestImageForAsset:asset
                                                       targetSize:PHImageManagerMaximumSize
                                                      contentMode:PHImageContentModeDefault
                                                          options:ro
                                                    resultHandler:^(UIImage *img, NSDictionary *info) {
                UIImage *outImg = (img) ? DD_ComposeShellImage(img, t) : nil;
                if (!outImg) { [self dd_hideShelling]; return; } // 失败：静默收起，不给提示
                DD_SaveImageToAlbum(outImg);
                [[DDShellConfig shared] markProcessed:asset.localIdentifier];
                if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
                [self dd_showShellDone]; // 结束：成功提示（先收起「正在套壳」）
            }];
        });
    });
}

// 微信原生「正在处理」提示（loading 样式 + 转圈）。PHImageManager 回调可能在后台线程，统一回主线程。
// 注意：WeToast 是微信私有类，不在 tweak 的链接路径里；因此必须用 NSClassFromString 取 Class 变量后
// 再发消息（[cls toast]），绝不能写 [WeToast toast]——后者会让编译器生成 OBJC_CLASS_$_WeToast 链接符号，
// 链接期报 undefined symbols。手写 @interface 仅用于编译期类型检查，不参与符号引用。
- (void)dd_showShelling {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WeToast");
        if (!cls) return;
        WeToast *toast = [cls toast];
        if (!toast) return;
        [toast setLoadingStyle:YES];
        [toast showToastWithText:@"正在套壳"];
        gBusyToast = toast;
    });
}

- (void)dd_hideShelling {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
    });
}

// 收起「正在套壳」并弹出微信原生成功提示（带勾选图标）
- (void)dd_showShellDone {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gBusyToast hideWithAnimated:YES];
        gBusyToast = nil;
        Class cls = NSClassFromString(@"WeToast");
        if (!cls) return;
        [[cls toast] showDoneToastWithText:@"套壳成功"];
    });
}

@end

#pragma mark - 设置界面

@interface DDShellSettingsViewController : UIViewController <UITableViewDelegate>
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
                                            target:self title:@"↳截图自动套壳"
                                                on:[DDShellConfig shared].autoShell]];

        NSArray *tpls = DD_AllTemplateNames();
        NSString *active = DD_ActiveTemplateName();
        [section addCell:[cellCls normalCellForSel:@selector(tplHeaderTapped:)
                                            target:self title:@"↳套壳素材库"
                                         rightValue:[NSString stringWithFormat:@"%lu 个 / 当前 %@",
                                                    (unsigned long)tpls.count, active.length ? active : @"无"]]];

        if (self.tplExpanded) {
            if (tpls.count == 0) {
                [section addCell:[cellCls centerCellForSel:@selector(noopTapped:)
                                                    target:self
                                                     title:@"（空：把 name.png + name.cfg 一起放 Documents/DDShellTemplates/）"]];
            }
            for (NSString *t in tpls) {
                WCTableViewCellManager *c = [cellCls centerCellForSel:@selector(tplOptionTapped:) target:self title:t];
                c.userInfo = t;
                [section addCell:c];
            }
        }

        [section addCell:[cellCls normalCellForSel:@selector(shotDelayTapped:)
                                            target:self title:@"↳截图后延时"
                                         rightValue:[NSString stringWithFormat:@"%.1f 秒", [DDShellConfig shared].shotDelay]]];

        [section addCell:[cellCls switchCellForSel:@selector(deleteSwitchChanged:)
                                            target:self title:@"↳套壳后删除原图"
                                                on:[DDShellConfig shared].deleteOriginal]];
    }

    [self.tableViewMgr addSection:section];
    [self.tableViewMgr reloadTableView];
}

- (void)noopTapped:(id)sender { }

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

- (void)shotDelayTapped:(id)sender {
    [self dd_inputTitle:@"截图后延时" message:@"截图落相册需要一点时间，单位：秒" current:[DDShellConfig shared].shotDelay apply:^(double v) {
        [DDShellConfig shared].shotDelay = v;
    }];
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

- (void)dd_alert:(NSString *)title message:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)dd_inputTitle:(NSString *)title message:(NSString *)msg current:(double)cur apply:(void (^)(double))apply {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.text = [NSString stringWithFormat:@"%.1f", cur];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *txt = ac.textFields.firstObject.text ?: @"";
        double v = txt.doubleValue;
        if (v < 0) v = 0;
        if (v > 30) v = 30;
        if (apply) apply(v);
        dispatch_async(dispatch_get_main_queue(), ^{ [self buildTable]; });
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - UITableViewDelegate 转发

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = (WCTableViewCellManager *)[self.tableViewMgr cellInfoAtIndexPath:indexPath];
    if (cellInfo && [cellInfo.userInfo isKindOfClass:[NSString class]]) {
        NSString *t = cellInfo.userInfo;
        cell.accessoryType = [t isEqualToString:DD_ActiveTemplateName()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
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

#pragma mark - 注册入口（与 DD收款助手一致，勿改）

%ctor {
    @autoreleasepool {
        (void)[DDShellConfig shared];
        [DDShellWatcher shared]; // 挂载截图监听

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                      version:@"3.0.0"
                                                   controller:@"DDShellSettingsViewController"];
        }
    }
}

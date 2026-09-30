// ============================================================================
//  DDShell.xm —— 模板套壳（截图后套模板并保存到相册）  v3.0.0
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  ── 逆向来源 ──────────────────────────────────────────────────────────────
//  ZDY_v1.3.7.dylib : ScreenshotShellHelper / SSShellLibraryVC / SSShellEditorVC
//                     PHPhotoLibrary 落相册
//  WCRefine.dylib   : 完整工业级实现，本版按它校正合成算法
//      WCRefineScreenshotFrameProcessor
//          wcr_compositedFrameImageForSourceImage:templateInfo:
//          initWithPerspectiveCornersLeftTop:rightTop:leftBottom:rightBottom:
//          templateSize:frameImage:
//
//  ── WCR 关键机制（本版已对齐）────────────────────────────────────────────
//  1. 模板不是「一张图盖上去」，而是「带镂空屏幕窗的机身前景图」
//     模板三件套：name.png / name_dark.png / name.cfg
//     name.cfg（JSON，字段顺序取自 WCR 的写入模板）：
//       {"name":"", "author":"", "created_at":0, "mode":"single",
//        "template_width":1170, "template_height":2532,
//        "left_top_x":..,"left_top_y":.., "right_top_x":..,"right_top_y":..,
//        "left_bottom_x":..,"left_bottom_y":.., "right_bottom_x":..,"right_bottom_y":..}
//  2. 合成用 CIPerspectiveTransformWithExtent：
//     把整张截图透视映射到四角点围成的四边形（屏幕窗），模板再叠在上层。
//     截图内容不会被裁掉，且支持斜角/透视模板。
//  3. 探测屏幕窗用 refineCandidatePoints:withDarkFrameUsingRGBA: 同款思路：
//     降采样 → 从中心 flood fill 找 alpha 连通区 → 得到屏幕窗矩形 → 落 cfg 缓存。
//  4. 去重：screenshotFrameAlbumEnhancementProcessedIds，避免同一 asset 反复套壳。
//
//  ── 使用方式 ──────────────────────────────────────────────────────────────
//  模板文件自行放入 Documents/DDShellTemplates/（name.png，可选 name_dark.png，
//  以及可选的 name.cfg 描述屏幕窗四角）。缺省 name.cfg 时，插件在加载模板时会
//  根据图片的透明镂空区自动探测屏幕窗（对齐 WCR 的 refineCandidatePoints 思路）。
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
@property (nonatomic, strong) UIImage  *image;       // 日间图
@property (nonatomic, strong) UIImage  *darkImage;   // 夜间图（可选）
@property (nonatomic)         CGSize    canvasSize;  // 模板像素尺寸
@property (nonatomic)         CGPoint   lt, rt, lb, rb; // 屏幕窗四角（UIKit 坐标，左上原点，像素）
@property (nonatomic)         BOOL      hasRegion;   // 是否已确定屏幕窗
@end

@implementation DDShellTemplate
@end

// 当前生效的机身图（按系统深浅色自动选 _dark）
static UIImage *DD_FrameImage(DDShellTemplate *t) {
    if (!t) return nil;
    BOOL dark = (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    return (dark && t.darkImage) ? t.darkImage : t.image;
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

// 素材库：所有不以 _dark 结尾的 png/jpg 的 basename
static NSArray<NSString *> *DD_AllTemplateNames(void) {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:DD_TplDir() error:nil];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in files) {
        NSString *low = f.lowercaseString;
        if (!([low hasSuffix:@".png"] || [low hasSuffix:@".jpg"] || [low hasSuffix:@".jpeg"])) continue;
        NSString *base = f.stringByDeletingPathExtension;
        if ([base.lowercaseString hasSuffix:@"_dark"]) continue;
        [out addObject:base];
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

// 前向声明：实现位于下方「屏幕窗自动探测」节，加载模板时按需调用
static CGRect DD_DetectScreenRegion(UIImage *img);

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
    t.canvasSize = CGSizeMake(img.size.width * img.scale, img.size.height * img.scale);

    NSString *darkPath = [[DD_TplDir() stringByAppendingPathComponent:[name stringByAppendingString:@"_dark"]] stringByAppendingPathExtension:@"png"];
    NSData *dd = [NSData dataWithContentsOfFile:darkPath];
    if (dd.length) {
        UIImage *di = [UIImage imageWithData:dd];
        if (di && fabs(di.size.width * di.scale - t.canvasSize.width) < 2.0) t.darkImage = di;
    }

    NSDictionary *cfg = DD_LoadCfg(name);
    double lw = [cfg[@"template_width"] doubleValue];
    double lh = [cfg[@"template_height"] doubleValue];
    // cfg 里记录的模板尺寸；与真实图不符（换过图）则作废，需重新探测
    BOOL sizeOK = (lw > 0 && lh > 0 && fabs(lw - t.canvasSize.width) < 2.0 && fabs(lh - t.canvasSize.height) < 2.0);
    if (sizeOK) {
        NSArray *keys = @[@"left_top", @"right_top", @"left_bottom", @"right_bottom"];
        CGPoint pts[4];
        BOOL ok = YES;
        for (NSUInteger i = 0; i < 4; i++) {
            id x = cfg[[keys[i] stringByAppendingString:@"_x"]];
            id y = cfg[[keys[i] stringByAppendingString:@"_y"]];
            if (![x respondsToSelector:@selector(doubleValue)] || ![y respondsToSelector:@selector(doubleValue)]) { ok = NO; break; }
            pts[i] = CGPointMake([x doubleValue], [y doubleValue]);
        }
        if (ok) {
            t.lt = pts[0]; t.rt = pts[1]; t.lb = pts[2]; t.rb = pts[3];
            t.hasRegion = YES;
        }
    }

    // 缺 cfg（或 cfg 尺寸不匹配失效）时，按 WCR 同款思路从透明镂空区自动探测屏幕窗，
    // 不再依赖设置页手动触发；探测失败则 hasRegion 保持 NO，合成走等比居中回退。
    if (!t.hasRegion) {
        CGRect dr = DD_DetectScreenRegion(t.image);
        if (!CGRectIsEmpty(dr)) {
            t.lt = CGPointMake(CGRectGetMinX(dr), CGRectGetMinY(dr));
            t.rt = CGPointMake(CGRectGetMaxX(dr), CGRectGetMinY(dr));
            t.lb = CGPointMake(CGRectGetMinX(dr), CGRectGetMaxY(dr));
            t.rb = CGPointMake(CGRectGetMaxX(dr), CGRectGetMaxY(dr));
            t.hasRegion = YES;
        }
    }
    return t;
}

static NSString *DD_ActiveTemplateName(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    if (sel.length && DD_TemplateNamed(sel)) return sel;
    return [DD_AllTemplateNames() firstObject] ?: @"";
}

#pragma mark - 屏幕窗自动探测（对齐 WCR refineCandidatePoints:withDarkFrameUsingRGBA:）

// 降采样 → 从图像中心 flood fill 找 alpha 连通透明区 → 返回其在原图中的外接矩形（UIKit 坐标）
static CGRect DD_DetectScreenRegion(UIImage *img) {
    CGImageRef cg = img.CGImage;
    if (!cg) return CGRectZero;
    CGFloat W = (CGFloat)CGImageGetWidth(cg);
    CGFloat H = (CGFloat)CGImageGetHeight(cg);
    if (W < 16 || H < 16) return CGRectZero;

    CGFloat scale = MIN(1.0, 256.0 / MAX(W, H));
    size_t sw = (size_t)MAX(8, round(W * scale));
    size_t sh = (size_t)MAX(8, round(H * scale));

    size_t bytesPerRow = sw * 4;
    unsigned char *buf = (unsigned char *)calloc(bytesPerRow * sh, 1);
    if (!buf) return CGRectZero;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(buf, sw, sh, 8, bytesPerRow, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) { free(buf); return CGRectZero; }
    CGContextSetInterpolationQuality(ctx, kCGInterpolationLow);
    CGContextDrawImage(ctx, CGRectMake(0, 0, sw, sh), cg);
    CGContextRelease(ctx);

    const int kAlphaThreshold = 24; // 约 10%
    size_t n = sw * sh;
    unsigned char *visited = (unsigned char *)calloc(n, 1);
    int *stack = (int *)malloc(n * sizeof(int));
    if (!visited || !stack) { free(buf); free(visited); free(stack); return CGRectZero; }

    // 起点：中心；中心不透明则线性扫描找第一个透明像素
    size_t start = (sh / 2) * sw + (sw / 2);
    if (buf[start * 4 + 3] > kAlphaThreshold) {
        size_t found = n;
        for (size_t i = 0; i < n; i++) {
            if (buf[i * 4 + 3] <= kAlphaThreshold) { found = i; break; }
        }
        if (found == n) { free(buf); free(visited); free(stack); return CGRectZero; }
        start = found;
    }

    size_t sp = 0;
    stack[sp++] = (int)start;
    visited[start] = 1;
    size_t minX = sw, maxX = 0, minY = sh, maxY = 0;

    while (sp > 0) {
        int idx = stack[--sp];
        int x = idx % (int)sw;
        int y = idx / (int)sw;
        if ((size_t)x < minX) minX = (size_t)x;
        if ((size_t)x > maxX) maxX = (size_t)x;
        if ((size_t)y < minY) minY = (size_t)y;
        if ((size_t)y > maxY) maxY = (size_t)y;

        if (x > 0)            { size_t j = idx - 1;  if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (x < (int)sw - 1)  { size_t j = idx + 1;  if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (y > 0)            { size_t j = idx - sw; if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (y < (int)sh - 1)  { size_t j = idx + sw; if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
    }

    free(buf);
    free(visited);
    free(stack);

    CGFloat area  = (CGFloat)(maxX - minX + 1) * (CGFloat)(maxY - minY + 1);
    CGFloat total = (CGFloat)sw * (CGFloat)sh;
    // 占比异常说明整图透明或没有真正的镂空窗，交给回退逻辑处理
    if (area > total * 0.92 || area < total * 0.02) return CGRectZero;

    // buffer 由 CGContext 绘制，原点在左下；转换回 UIKit（左上原点）
    CGFloat top = (CGFloat)(sh - 1 - maxY);
    CGRect r = CGRectMake((CGFloat)minX / scale, top / scale,
                          (CGFloat)(maxX - minX + 1) / scale, (CGFloat)(maxY - minY + 1) / scale);
    return CGRectIntegral(r);
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
    CIImage *src = [CIImage imageWithCGImage:shotCG];
    CIImage *base = nil;

    if (t.hasRegion) {
        CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
        if (f) {
            [f setDefaults];
            [f setValue:src forKey:kCIInputImageKey];
            [f setValue:[CIVector vectorWithCGRect:src.extent] forKey:@"inputExtent"];
            [f setValue:DD_CIVec(t.lt, H) forKey:@"inputTopLeft"];
            [f setValue:DD_CIVec(t.rt, H) forKey:@"inputTopRight"];
            [f setValue:DD_CIVec(t.rb, H) forKey:@"inputBottomRight"];
            [f setValue:DD_CIVec(t.lb, H) forKey:@"inputBottomLeft"];
            CIImage *out = [f valueForKey:kCIOutputImageKey];
            if (out) base = out;
        }
    }

    if (!base) {
        // 回退（无 cfg 且探测失败）：截图等比例居中放进画布，不做拉伸变形
        CGFloat sw = src.extent.size.width, sh = src.extent.size.height;
        CGFloat s = MIN(W / sw, H / sh);
        CIImage *scaled = [src imageByApplyingTransform:CGAffineTransformMakeScale(s, s)];
        base = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation((W - sw * s) / 2.0, (H - sh * s) / 2.0)];
    }

    CIImage *frame = [CIImage imageWithCGImage:frameCG];
    CIImage *out = [frame imageByCompositingOverImage:base];
    out = [out imageByCroppingToRect:CGRectMake(0, 0, W, H)];

    static CIContext *ctx;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ ctx = [CIContext contextWithOptions:nil]; });
    CGImageRef cg = [ctx createCGImage:out fromRect:out.extent];
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg scale:1.0 orientation:UIImageOrientationUp];
    CGImageRelease(cg);
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

@interface DDShellWatcher : NSObject
+ (instancetype)shared;
- (void)shellLatestScreenshot;
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
            [[PHImageManager defaultManager] requestImageForAsset:asset
                                                       targetSize:PHImageManagerMaximumSize
                                                      contentMode:PHImageContentModeDefault
                                                          options:ro
                                                    resultHandler:^(UIImage *img, NSDictionary *info) {
                if (!img) return;
                UIImage *outImg = DD_ComposeShellImage(img, t);
                if (!outImg) return;
                DD_SaveImageToAlbum(outImg);
                [[DDShellConfig shared] markProcessed:asset.localIdentifier];
                if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
            }];
        });
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
                                                     title:@"（空：模板 PNG 放 Documents/DDShellTemplates/）"]];
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

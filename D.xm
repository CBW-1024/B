// ============================================================================
//  DDShell.xm —— 模板套壳（截图/录屏后套模板并保存到相册）  v2.0.0
//
//  单文件 iOS 插件（Logos / Theos），设置界面与入口参照 DD收款助手写法
//
//  ── 逆向来源 ──────────────────────────────────────────────────────────────
//  ZDY_v1.3.7.dylib  : ScreenshotShellHelper / SSShellLibraryVC / SSShellEditorVC
//                      ss_shell_%@.png、UIScreen.isCaptured、PHPhotoLibrary 落相册
//  WCRefine.dylib    : 完整工业级实现，本版按它校正合成算法
//      WCRefineScreenshotFrameProcessor      wcr_compositedFrameImageForSourceImage:templateInfo:
//      WCRefineScreenRecordingFrameProcessor wcr_exportFrameFromAsset:audioMix:templateInfo:completion:
//      WCRefineScreenRecordingFrameTemplate  initWithPerspectiveCornersLeftTop:rightTop:
//                                            leftBottom:rightBottom:templateSize:videoSize:frameImage:
//      WCRefinePerspectiveVideoCompositor    自定义 AVVideoCompositing（逐帧透视）
//      WCRefineFrameZipCreator               frame.zip 导入导出
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
//     —— 截图内容不会被裁掉，且支持斜角/透视模板。
//  3. 导入裸 PNG 时用 refineCandidatePoints:withDarkFrameUsingRGBA: 同款思路：
//     降采样 → 从中心 flood fill 找 alpha 连通区 → 得到屏幕窗矩形 → 落 cfg 缓存。
//  4. 去重：screenshotFrameAlbumEnhancementProcessedIds，避免同一 asset 反复套壳。
//
//  本插件不 hook 微信内部逻辑，纯系统层实现：
//    截图 → UIApplicationUserDidTakeScreenshotNotification
//    录屏 → UIScreenCapturedDidChangeNotification（isCaptured 由 YES→NO）
//    取相册最新截图/录屏 → 透视贴进模板屏幕窗 → 存回相册
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
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
static NSString *const kDDShellRecDelay    = @"DDShellRecDelay";
static NSString *const kDDShellDeleteSrc   = @"DDShellDeleteOriginal";
static NSString *const kDDShellProcessed   = @"DDShellProcessedIds";

@interface DDShellConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL autoShell;
@property (nonatomic) BOOL deleteOriginal;
@property (nonatomic) double shotDelay;
@property (nonatomic) double recDelay;
@property (nonatomic, copy) NSString *selectedTpl;
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
        _recDelay       = [ud objectForKey:kDDShellRecDelay]  ? [ud doubleForKey:kDDShellRecDelay]  : 3.0;
        if (_shotDelay < 0) _shotDelay = 0;
        if (_recDelay < 0) _recDelay = 0;
        _selectedTpl = [ud stringForKey:kDDShellSelectedTpl] ?: @"";
        [ud setBool:_enabled forKey:kDDShellEnabled];
        [ud setBool:_autoShell forKey:kDDShellAuto];
        [ud setBool:_deleteOriginal forKey:kDDShellDeleteSrc];
        [ud setDouble:_shotDelay forKey:kDDShellShotDelay];
        [ud setDouble:_recDelay forKey:kDDShellRecDelay];
        [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v      { _enabled = v;        [self dd_syncBool:v forKey:kDDShellEnabled]; }
- (void)setAutoShell:(BOOL)v    { _autoShell = v;      [self dd_syncBool:v forKey:kDDShellAuto]; }
- (void)setDeleteOriginal:(BOOL)v { _deleteOriginal = v; [self dd_syncBool:v forKey:kDDShellDeleteSrc]; }
- (void)setShotDelay:(double)v  { _shotDelay = v;      [self dd_syncDouble:v forKey:kDDShellShotDelay]; }
- (void)setRecDelay:(double)v   { _recDelay = v;       [self dd_syncDouble:v forKey:kDDShellRecDelay]; }
- (void)setSelectedTpl:(NSString *)v {
    _selectedTpl = [v copy] ?: @"";
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
    [ud synchronize];
}

- (void)dd_syncBool:(BOOL)v forKey:(NSString *)k {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:v forKey:k];
    [ud synchronize];
}
- (void)dd_syncDouble:(double)v forKey:(NSString *)k {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setDouble:v forKey:k];
    [ud synchronize];
}

// 已处理过的 asset 去重（对应 WCR 的 AlbumEnhancementProcessedIds）
- (NSArray<NSString *> *)processedIds {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kDDShellProcessed] ?: @[];
}
- (BOOL)hasProcessed:(NSString *)lid {
    if (!lid.length) return NO;
    return [[self processedIds] containsObject:lid];
}
- (void)markProcessed:(NSString *)lid {
    if (!lid.length) return;
    NSMutableArray *m = [[self processedIds] mutableCopy];
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
@property (nonatomic, copy)   NSString *mode;        // single / double
@end

@implementation DDShellTemplate
@end

// 当前生效的机身图（按系统深浅色自动选 _dark）
static UIImage *DD_TemplateFrameImage(DDShellTemplate *t) {
    if (!t) return nil;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
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

static void DD_SaveCfg(NSString *name, NSDictionary *cfg) {
    if (!name.length || !cfg) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:cfg options:NSJSONWritingPrettyPrinted error:nil];
    if (d) [d writeToFile:DD_CfgPath(name) atomically:YES];
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
    t.mode = [cfg[@"mode"] isKindOfClass:[NSString class]] ? cfg[@"mode"] : @"single";
    double lw = [cfg[@"template_width"] doubleValue];
    double lh = [cfg[@"template_height"] doubleValue];
    // cfg 里记录的模板尺寸；与真实图不符（改过图）则作废，需重新探测
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

        if (x > 0)                 { size_t j = idx - 1;   if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (x < (int)sw - 1)       { size_t j = idx + 1;   if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (y > 0)                 { size_t j = idx - sw;  if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
        if (y < (int)sh - 1)       { size_t j = idx + sw;  if (!visited[j] && buf[j*4+3] <= kAlphaThreshold) { visited[j] = 1; stack[sp++] = (int)j; } }
    }

    free(buf);
    free(visited);
    free(stack);

    CGFloat area = (CGFloat)(maxX - minX + 1) * (CGFloat)(maxY - minY + 1);
    CGFloat total = (CGFloat)sw * (CGFloat)sh;
    // 占比异常说明整图透明或没有真正的镂空窗，交给回退逻辑处理
    if (area > total * 0.92 || area < total * 0.02) return CGRectZero;

    // buffer 由 CGContext 绘制，原点在左下；转换回 UIKit（左上原点）
    CGFloat top    = (CGFloat)(sh - 1 - maxY);
    CGFloat height = (CGFloat)(maxY - minY + 1);
    CGRect r = CGRectMake((CGFloat)minX / scale, top / scale,
                          (CGFloat)(maxX - minX + 1) / scale, height / scale);
    return CGRectIntegral(r);
}

// 探测并把结果写成 cfg（与 WCR 同名同结构）
static BOOL DD_DetectAndSaveRegionForTemplate(NSString *name) {
    DDShellTemplate *t = DD_TemplateNamed(name);
    if (!t) return NO;
    CGRect r = DD_DetectScreenRegion(t.image);
    if (CGRectIsEmpty(r)) return NO;

    t.lt = CGPointMake(CGRectGetMinX(r), CGRectGetMinY(r));
    t.rt = CGPointMake(CGRectGetMaxX(r), CGRectGetMinY(r));
    t.lb = CGPointMake(CGRectGetMinX(r), CGRectGetMaxY(r));
    t.rb = CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r));
    t.hasRegion = YES;

    NSMutableDictionary *cfg = [(DD_LoadCfg(name) ?: @{}) mutableCopy];
    cfg[@"name"] = name ?: @"";
    cfg[@"author"] = cfg[@"author"] ?: @"DDShell";
    cfg[@"created_at"] = cfg[@"created_at"] ?: @((long long)[[NSDate date] timeIntervalSince1970]);
    cfg[@"mode"] = @"single";
    cfg[@"template_width"]  = @(t.canvasSize.width);
    cfg[@"template_height"] = @(t.canvasSize.height);
    cfg[@"left_top_x"] = @(t.lt.x);      cfg[@"left_top_y"] = @(t.lt.y);
    cfg[@"right_top_x"] = @(t.rt.x);     cfg[@"right_top_y"] = @(t.rt.y);
    cfg[@"left_bottom_x"] = @(t.lb.x);   cfg[@"left_bottom_y"] = @(t.lb.y);
    cfg[@"right_bottom_x"] = @(t.rb.x);  cfg[@"right_bottom_y"] = @(t.rb.y);
    DD_SaveCfg(name, cfg);
    return YES;
}

#pragma mark - 合成（核心：透视贴进屏幕窗）

// UIKit 坐标（左上原点）→ CoreImage 坐标（左下原点）
static CIVector *DD_CIVec(CGPoint p, CGFloat canvasH) {
    return [CIVector vectorWithCGPoint:CGPointMake(p.x, canvasH - p.y)];
}

// 用 CIPerspectiveTransformWithExtent 把截图映射到四角点，模板叠在上层
static CIImage *DD_ComposedCIImage(UIImage *shot, DDShellTemplate *t, BOOL useDark) {
    UIImage *frameImg = useDark ? (t.darkImage ?: t.image) : t.image;
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
        // 回退（无 cfg 且探测失败）：把截图等比例 contain 居中放进画布，不做拉伸
        CGFloat s = MIN(W / src.extent.size.width, H / src.extent.size.height);
        CGFloat w = src.extent.size.width * s, h = src.extent.size.height * s;
        CGAffineTransform tr = CGAffineTransformMakeScale(s, s);
        CIImage *scaled = [src imageByApplyingTransform:tr];
        base = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation((W - w) / 2.0, (H - h) / 2.0)];
    }

    CIImage *frame = [CIImage imageWithCGImage:frameCG];
    CGRect canvas = CGRectMake(0, 0, W, H);
    CIImage *out = [frame imageByCompositingOverImage:base];
    return [out imageByCroppingToRect:canvas];
}

static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
    CIImage *out = DD_ComposedCIImage(shot, t, dark);
    if (!out) return nil;
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
    if (@available(iOS 14, *)) {
        [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus s) {
            if (ready) ready(s == PHAuthorizationStatusAuthorized || s == PHAuthorizationStatusLimited);
        }];
    } else {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus s) {
            if (ready) ready(s == PHAuthorizationStatusAuthorized);
        }];
    }
}

static void DD_LatestImageAsset(void (^done)(PHAsset *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:o];
    if (done) done([r firstObject]);
}

static void DD_LatestVideoAsset(void (^done)(PHAsset *)) {
    PHFetchOptions *o = [PHFetchOptions new];
    o.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    o.fetchLimit = 1;
    PHFetchResult *r = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:o];
    if (done) done([r firstObject]);
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

static void DD_DeleteAssets(NSArray<PHAsset *> *assets) {
    if (!assets.count) return;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest deleteAssets:assets];
    } completionHandler:nil];
}

#pragma mark - 视频套壳（逐帧透视，对齐 WCRefinePerspectiveVideoCompositor）

static void DD_ComposeShellVideo(NSURL *srcURL, DDShellTemplate *t) {
    if (!srcURL || !t) return;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:srcURL options:nil];
    AVAssetTrack *v = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!v) return;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    if (W < 16 || H < 16) return;

    // 用 preferredTransform 把帧摆正，得到 (0,0,natural) 的 CIImage
    CGAffineTransform pt = v.preferredTransform;
    CGRect rawRect = CGRectMake(0, 0, v.naturalSize.width, v.naturalSize.height);
    CGRect rotRect = CGRectApplyAffineTransform(rawRect, pt);
    CGAffineTransform fix = CGAffineTransformConcat(pt, CGAffineTransformMakeTranslation(-rotRect.origin.x, -rotRect.origin.y));

    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (!reader) return;

    NSDictionary *decompress = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)
    };
    AVAssetReaderTrackOutput *vOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:v outputSettings:decompress];
    vOut.alwaysCopiesSampleData = NO;
    [reader addOutput:vOut];

    AVAssetTrack *a = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    AVAssetReaderTrackOutput *aOut = nil;
    if (a) {
        aOut = [[AVAssetReaderTrackOutput alloc] initWithTrack:a outputSettings:nil];
        [reader addOutput:aOut];
    }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dd_shell_out.mp4"];
    [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
    NSError *werr = nil;
    // 经典初始化（iOS 4.1+），不用 iOS 17+ 的 initWithContentType:；局部屏蔽废弃警告以适配 -Werror
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:tmp] fileType:AVFileTypeMPEG4 error:&werr];
#pragma clang diagnostic pop
    if (!writer) return;

    NSDictionary *videoSettings = @{
        (id)AVVideoCodecKey  : (id)AVVideoCodecTypeH264,
        (id)AVVideoWidthKey  : @((int)W),
        (id)AVVideoHeightKey : @((int)H)
    };
    AVAssetWriterInput *vin = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    vin.expectsMediaDataInRealTime = NO;
    [writer addInput:vin];

    NSDictionary *pbAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey  : @((int)W),
        (id)kCVPixelBufferHeightKey : @((int)H)
    };
    AVAssetWriterInputPixelBufferAdaptor *adaptor =
        [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:vin
                                                                         sourcePixelBufferAttributes:pbAttrs];

    AVAssetWriterInput *ain = nil;
    if (a) {
        ain = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:nil];
        ain.expectsMediaDataInRealTime = NO;
        if ([writer canAddInput:ain]) [writer addInput:ain];
    }

    DDShellTemplate *tmpl = t;   // block 内强引用模板
    UIImage *frameImg = DD_TemplateFrameImage(t);
    CIImage *frameCI = frameImg.CGImage ? [CIImage imageWithCGImage:frameImg.CGImage] : nil;
    if (!frameCI) return;       // 在 startWriting 之前退出，避免残留半成品 writer

    static CIContext *cctx;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cctx = [CIContext contextWithOptions:nil]; });
    CIContext *renderCtx = cctx;

    dispatch_queue_t vq = dispatch_queue_create("ddshell.video", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t aq = dispatch_queue_create("ddshell.audio", DISPATCH_QUEUE_SERIAL);

    // 视频轨与音频轨都写完（markAsFinished）后才能 finishWriting，否则导出会失败
    dispatch_group_t grp = dispatch_group_create();

    if (ain && aOut) {
        __block BOOL aDone = NO;
        dispatch_group_enter(grp);
        [ain requestMediaDataWhenReadyOnQueue:aq usingBlock:^{
            while (ain.isReadyForMoreMediaData) {
                CMSampleBufferRef sb = [aOut copyNextSampleBuffer];
                if (sb) {
                    [ain appendSampleBuffer:sb];
                    CFRelease(sb);
                } else {
                    [ain markAsFinished];
                    if (!aDone) { aDone = YES; dispatch_group_leave(grp); }
                    break;
                }
            }
        }];
    }

    __block BOOL vDone = NO;
    dispatch_group_enter(grp);
    [vin requestMediaDataWhenReadyOnQueue:vq usingBlock:^{
        while (vin.isReadyForMoreMediaData) {
            CMSampleBufferRef sb = [vOut copyNextSampleBuffer];
            if (!sb) {
                [vin markAsFinished];
                if (!vDone) { vDone = YES; dispatch_group_leave(grp); }
                break;
            }
            CMTime ts = CMSampleBufferGetPresentationTimeStamp(sb);
            CVPixelBufferRef pb = CMSampleBufferGetImageBuffer(sb);
            if (pb) {
                CIImage *f = [CIImage imageWithCVPixelBuffer:pb];
                f = [f imageByApplyingTransform:fix];
                CIImage *base = nil;

                if (tmpl.hasRegion) {
                    CIFilter *flt = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
                    if (flt) {
                        [flt setDefaults];
                        [flt setValue:f forKey:kCIInputImageKey];
                        [flt setValue:[CIVector vectorWithCGRect:f.extent] forKey:@"inputExtent"];
                        [flt setValue:DD_CIVec(tmpl.lt, H) forKey:@"inputTopLeft"];
                        [flt setValue:DD_CIVec(tmpl.rt, H) forKey:@"inputTopRight"];
                        [flt setValue:DD_CIVec(tmpl.rb, H) forKey:@"inputBottomRight"];
                        [flt setValue:DD_CIVec(tmpl.lb, H) forKey:@"inputBottomLeft"];
                        base = [flt valueForKey:kCIOutputImageKey];
                    }
                }
                if (!base) {
                    CGFloat s = MIN(W / f.extent.size.width, H / f.extent.size.height);
                    CIImage *scaled = [f imageByApplyingTransform:CGAffineTransformMakeScale(s, s)];
                    base = [scaled imageByApplyingTransform:CGAffineTransformMakeTranslation(
                                (W - f.extent.size.width * s) / 2.0, (H - f.extent.size.height * s) / 2.0)];
                }

                CIImage *out = [frameCI imageByCompositingOverImage:base];
                out = [out imageByCroppingToRect:CGRectMake(0, 0, W, H)];

                CVPixelBufferRef outPB = NULL;
                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool, &outPB);
                if (outPB) {
                    [renderCtx render:out toCVPixelBuffer:outPB];
                    [adaptor appendPixelBuffer:outPB withPresentationTime:ts];
                    CVPixelBufferRelease(outPB);
                }
            }
            CFRelease(sb);
        }
    }];

    dispatch_group_notify(grp, dispatch_get_main_queue(), ^{
        [writer finishWritingWithCompletionHandler:^{
            if (writer.status == AVAssetWriterStatusCompleted) {
                DD_SaveVideoToAlbum([NSURL fileURLWithPath:tmp]);
            }
            [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
        }];
    });
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
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onScreenshot:)
                                                     name:UIApplicationUserDidTakeScreenshotNotification
                                                   object:nil];
        if (@available(iOS 11.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onCaptureChanged:)
                                                         name:UIScreenCapturedDidChangeNotification
                                                       object:nil];
        }
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

- (void)onCaptureChanged:(NSNotification *)n {
    if (![DDShellConfig shared].enabled || ![DDShellConfig shared].autoShell) return;
    BOOL captured = [UIScreen mainScreen].isCaptured;
    if (_wasCaptured && !captured) {
        NSTimeInterval delay = [DDShellConfig shared].recDelay;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self shellLatestRecording];
        });
    }
    _wasCaptured = captured;
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

- (void)shellLatestRecording {
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!t) return;
    DD_EnsurePhotoAuth(^(BOOL ok) {
        if (!ok) return;
        DD_LatestVideoAsset(^(PHAsset *asset) {
            if (!asset) return;
            if ([[DDShellConfig shared] hasProcessed:asset.localIdentifier]) return;
            PHVideoRequestOptions *vo = [PHVideoRequestOptions new];
            vo.version = PHVideoRequestOptionsVersionOriginal;
            vo.networkAccessAllowed = NO;
            [[PHImageManager defaultManager] requestAVAssetForVideo:asset
                                                            options:vo
                                                      resultHandler:^(AVAsset *av, AVAudioMix *mix, NSDictionary *info) {
                if (![av isKindOfClass:[AVURLAsset class]]) return;
                NSURL *url = ((AVURLAsset *)av).URL;
                if (!url) return;
                [[DDShellConfig shared] markProcessed:asset.localIdentifier];
                DD_ComposeShellVideo(url, t);
                if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
            }];
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

        NSArray *tpls = DD_AllTemplateNames();
        NSString *active = DD_ActiveTemplateName();
        [section addCell:[cellCls normalCellForSel:@selector(tplHeaderTapped:)
                                            target:self title:@"↳套壳素材库"
                                         rightValue:[NSString stringWithFormat:@"%lu 个 / 当前 %@",
                                                    (unsigned long)tpls.count, active.length ? active : @"无"]]];

        if (self.tplExpanded) {
            if (tpls.count == 0) {
                [section addCell:[cellCls centerCellForSel:@selector(noopTapped:) target:self title:@"（素材库为空，请先导入）"]];
            }
            for (NSString *t in tpls) {
                WCTableViewCellManager *c = [cellCls centerCellForSel:@selector(tplOptionTapped:) target:self title:t];
                c.userInfo = t;
                [section addCell:c];
            }
        }

        // 屏幕窗（模板镂空区）状态与重新探测
        DDShellTemplate *cur = DD_TemplateNamed(active);
        NSString *regionText = @"未确定";
        if (cur && cur.hasRegion) {
            regionText = [NSString stringWithFormat:@"%.0f×%.0f", 
                          fabs(cur.rt.x - cur.lt.x), fabs(cur.lb.y - cur.lt.y)];
        } else if (cur) {
            regionText = @"未探测";
        }
        [section addCell:[cellCls normalCellForSel:@selector(regionTapped:)
                                            target:self title:@"↳模板屏幕窗"
                                         rightValue:regionText]];

        [section addCell:[cellCls normalCellForSel:@selector(importTapped:)
                                            target:self title:@"↳从相册导入模板"
                                         rightValue:@""]];

        [section addCell:[cellCls normalCellForSel:@selector(shotDelayTapped:)
                                            target:self title:@"↳截图后延时"
                                         rightValue:[NSString stringWithFormat:@"%.1f 秒", [DDShellConfig shared].shotDelay]]];

        [section addCell:[cellCls normalCellForSel:@selector(recDelayTapped:)
                                            target:self title:@"↳录屏后延时"
                                         rightValue:[NSString stringWithFormat:@"%.1f 秒", [DDShellConfig shared].recDelay]]];

        [section addCell:[cellCls switchCellForSel:@selector(deleteSwitchChanged:)
                                            target:self title:@"↳套壳后删除原图"
                                                on:[DDShellConfig shared].deleteOriginal]];

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

- (void)regionTapped:(id)sender {
    NSString *active = DD_ActiveTemplateName();
    if (!active.length) {
        [self dd_alert:@"提示" message:@"素材库为空，请先从相册导入模板。"];
        return;
    }
    BOOL ok = DD_DetectAndSaveRegionForTemplate(active);
    [self dd_alert:ok ? @"已探测" : @"探测失败"
           message:ok ? [NSString stringWithFormat:@"已根据模板透明区域确定屏幕窗，并写入 %@.cfg", active]
                      : @"未能识别模板的镂空屏幕区。请确认模板中间屏幕部分是透明的；若模板本身不透明，将按等比居中方式合成。"];
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
    if (!img) return;

    NSString *name = [NSString stringWithFormat:@"dd_shell_%@", [[NSUUID UUID] UUIDString]];
    NSData *png = UIImagePNGRepresentation(img);
    if (!png) return;
    NSString *path = [[DD_TplDir() stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"png"];
    if (![png writeToFile:path atomically:YES]) return;

    // 导入即自动探测屏幕窗（对齐 WCR 的 refineCandidatePoints）
    DD_DetectAndSaveRegionForTemplate(name);
    [DDShellConfig shared].selectedTpl = name;
    dispatch_async(dispatch_get_main_queue(), ^{ [self buildTable]; });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)shotDelayTapped:(id)sender {
    [self dd_inputTitle:@"截图后延时" message:@"截图落相册需要一点时间，单位：秒" current:[DDShellConfig shared].shotDelay apply:^(double v) {
        [DDShellConfig shared].shotDelay = v;
    }];
}

- (void)recDelayTapped:(id)sender {
    [self dd_inputTitle:@"录屏后延时" message:@"录屏结束后系统写盘较慢，单位：秒" current:[DDShellConfig shared].recDelay apply:^(double v) {
        [DDShellConfig shared].recDelay = v;
    }];
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
        [DDShellWatcher shared]; // 挂载截图/录屏监听

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                      version:@"2.0.0"
                                                   controller:@"DDShellSettingsViewController"];
        }
    }
}

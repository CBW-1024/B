// ============================================================================
//  DDShell.xm —— 截图模板套壳插件
//
//  功能：截图后自动把截图套入模板存回相册；也能从相册挑图或挑视频手动套。
//  流程：监听截屏通知 → 取相册最新一张 → 透视贴进模板的屏幕窗 → 盖机身图 → 存回相册。
//  模板：每个模板一个目录，含 <名字>.png（机身前景图）+ <名字>.cfg（画布尺寸与四角坐标）。
//  素材库：设置页入口，模板的导入导出（zip）、应用、重命名、删除都在这一页。
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明

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
- (NSInteger)tag;
- (void)showInView:(id)view;
@end

#pragma mark - 配置

static NSString *const kDDShellEnabled     = @"DDShellEnabled";
static NSString *const kDDShellAuto        = @"DDShellAutoShell";
static NSString *const kDDShellSelectedTpl = @"DDShellSelectedTpl";
static NSString *const kDDShellDeleteSrc   = @"DDShellDeleteOriginal";
static NSString *const kDDShellProcessed   = @"DDShellProcessedIds";

// 截图后固定等 1 秒，等系统把截图写进相册再取
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

// 已处理过的图记下来，避免同一张被反复套壳
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

// 模板根目录：Library/Preferences/DDShell/模板/
// 不放 Documents：微信的「清理缓存」会清掉它，模板会丢；Preferences 不会被清。
static NSString *DD_TplDir(void) {
    static NSString *dir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *lib  = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
        NSString *pref = [lib stringByAppendingPathComponent:@"Preferences"];
        dir = [pref stringByAppendingPathComponent:@"DDShell/模板"];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return dir;
}

// 单个模板的目录：Library/Preferences/DDShell/模板/<名称>/
static NSString *DD_TplFolder(NSString *name) {
    return name.length ? [DD_TplDir() stringByAppendingPathComponent:name] : nil;
}

#pragma mark - 临时目录

// 插件专用临时目录：NSTemporaryDirectory()/DDShell/
// 与微信原生 tmp 隔开，方便下次启动时整目录清掉，不留残骸。
static NSString *DD_TempRoot(void) {
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"DDShell"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root
                              withIntermediateDirectories:YES attributes:nil error:nil];
    return root;
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

// 模板 cfg 路径：<模板目录>/<名称>.cfg
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

// 当前生效的模板：只认显式应用过的那个，库里有但没应用过就算没有。
// 模板 png 在这里一次解析完，要套壳、要画布尺寸都直接拿这个对象，不用再解一遍
static DDShellTemplate *DD_ActiveTemplate(void) {
    NSString *sel = [DDShellConfig shared].selectedTpl;
    return sel.length ? DD_TemplateNamed(sel) : nil;
}

// 只要名字时用这个：没有生效模板就给空串，方便直接拼进界面文案和路径
static NSString *DD_ActiveTemplateName(void) {
    return DD_ActiveTemplate().name ?: @"";
}

#pragma mark - 合成

// UIKit 坐标（左上原点）→ CoreImage 坐标（左下原点）翻转
static CIVector *DD_CIVec(CGPoint p, CGFloat canvasH) {
    return [CIVector vectorWithCGPoint:CGPointMake(p.x, canvasH - p.y)];
}

// 按 contain 比例预缩源图：缩小走 Lanczos——截图到屏幕窗通常要缩好几倍，双线性的抗混叠
// 不够，文字、分割线、图标细边会出摩尔纹；放大不产生混叠，仿射就够了。
// 图片链和视频链共用这一段，两链的差别只在送进来的源是 CGImage 还是像素缓冲。
static CIImage *DD_ScaledSource(CIImage *src, CGFloat sc) {
    if (sc > 0.0 && isfinite(sc) && sc < 1.0) {
        CIFilter *lz = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        if (lz) {
            [lz setDefaults];
            [lz setValue:src forKey:kCIInputImageKey];
            [lz setValue:@(sc) forKey:kCIInputScaleKey];
            if (lz.outputImage) return lz.outputImage;
        }
    }
    return [src imageByApplyingTransform:CGAffineTransformMakeScale(sc, sc)];
}

// 把模板四角填进透视滤镜（y 已按画布高翻转到 CoreImage 坐标）
static void DD_SetPerspectiveCorners(CIFilter *f, DDShellTemplate *t, CGFloat canvasH) {
    [f setValue:DD_CIVec(t.lt, canvasH) forKey:@"inputTopLeft"];
    [f setValue:DD_CIVec(t.rt, canvasH) forKey:@"inputTopRight"];
    [f setValue:DD_CIVec(t.rb, canvasH) forKey:@"inputBottomRight"];
    [f setValue:DD_CIVec(t.lb, canvasH) forKey:@"inputBottomLeft"];
}

// 模板四角围出的屏幕窗包围盒（用来把源按 contain 预缩到窗口大小）
static CGRect DD_WindowBBox(DDShellTemplate *t) {
    CGFloat xs[4] = { t.lt.x, t.rt.x, t.rb.x, t.lb.x };
    CGFloat ys[4] = { t.lt.y, t.rt.y, t.rb.y, t.lb.y };
    CGFloat minX = xs[0], maxX = xs[0], minY = ys[0], maxY = ys[0];
    for (int i = 1; i < 4; i++) {
        if (xs[i] < minX) minX = xs[i];
        if (xs[i] > maxX) maxX = xs[i];
        if (ys[i] < minY) minY = ys[i];
        if (ys[i] > maxY) maxY = ys[i];
    }
    return CGRectMake(minX, minY, maxX - minX, maxY - minY);
}

// 把一张图透视贴进模板的屏幕窗，再盖上机身前景图，得到成品
static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    UIImage *frameImg = t.image;
    CGImageRef frameCG = frameImg.CGImage;
    CGImageRef shotCG = shot.CGImage;
    if (!frameCG || !shotCG) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    // 尺寸来自 cfg，按 CoreGraphics 的纹理上限卡一道，超了就放弃这次合成
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil;

    // 截图按实际像素尺寸参与计算
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 滤镜在这里先建好再判空：下面开了图形上下文，中途 return 会漏掉 EndImageContext
    CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
    if (!f) return nil;

    // 画布按 1 倍开（1 单位 = 1 像素），成品尺寸才严格等于 cfg 写的模板尺寸
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);
    // 透视结果的 extent 未必是整数（四角来自 cfg，可能带小数），落地时会再重采样一次，
    // 显式开最高质量插值，免得最后一公里被默认插值抹糊
    CGContextRef uctx = UIGraphicsGetCurrentContext();
    if (uctx) CGContextSetInterpolationQuality(uctx, kCGInterpolationHigh);

    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 先把源按 contain 预缩到屏幕窗大小，再做透视：直接把大分辨率喂进透视会让中间图过大、
    // 投影退化
    CGRect wb = DD_WindowBBox(t);
    CGFloat sc = MIN(wb.size.width / A, wb.size.height / B);
    if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
    CIImage *srcImg = DD_ScaledSource([CIImage imageWithCGImage:shotCG], sc);
    [f setDefaults];
    [f setValue:srcImg forKey:kCIInputImageKey];
    [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, A * sc, B * sc)] forKey:@"inputExtent"];
    DD_SetPerspectiveCorners(f, t, H);
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

#pragma mark - 视频套壳（相册选视频，逐帧透视合成后导出）

// 套壳指令：把模板和源视频的旋转信息带进自定义合成器。
// customVideoCompositorClass 只认类、由框架自己实例化，参数没法从外部传实例，
// 只能挂在 instruction 上，合成器每帧从 request 里取回来。
@interface DDShellVideoInstruction : NSObject <AVVideoCompositionInstruction>
@property (nonatomic)         CMTimeRange         timeRange;
@property (nonatomic)         BOOL                enablePostProcessing;
@property (nonatomic)         BOOL                containsTweening;
@property (nonatomic)         NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic)         CMPersistentTrackID passthroughTrackID;
@property (nonatomic, strong) DDShellTemplate    *tpl;
@property (nonatomic)         CGAffineTransform   preferredTransform;
@end

@implementation DDShellVideoInstruction
@end

// 逐帧合成器：每帧把源视频帧透视贴进模板窗口，再叠机身图，输出到像素缓冲
@interface DDShellVideoCompositor : NSObject <AVVideoCompositing>
@property (atomic, assign)   BOOL             shouldCancelAllRequests;
- (void)_renderOneRequest:(AVAsynchronousVideoCompositionRequest *)req;
@end

@implementation DDShellVideoCompositor {
    CIContext      *_ctx;
    CGColorSpaceRef _cs;
    CVPixelBufferRef _mid;   // 满画布中间缓冲：透视结果先烘焙进来，再与机身合成。
                            // 复用同一张、不逐帧分配，内存打平；在 dealloc 里释放。
    CGSize           _midSize;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cs  = CGColorSpaceCreateDeviceRGB();
        // 钉死 working/output 为 sRGB：宽色域 / P3 源会把 Core Image 推到浮点扩展范围
        // 缓冲，内存翻倍。
        // 不缓存中间结果：逐帧渲染的循环里不让显存跟着帧数累积。
        _ctx = [CIContext contextWithOptions:@{ (id)kCIContextWorkingColorSpace : (__bridge id)_cs,
                                                (id)kCIContextOutputColorSpace  : (__bridge id)_cs,
                                                (id)kCIContextCacheIntermediates : @NO }];
    }
    return self;
}
- (void)dealloc {
    if (_cs) CGColorSpaceRelease(_cs);
    if (_mid) CVPixelBufferRelease(_mid);
}
// 渲染上下文变化（尺寸/像素格式等），本合成器每帧直接从 request 取 renderContext，无需缓存
- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {}
- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    // 输出缓冲要 BGRA + IOSurface：编码器需要 BGRA，IOSurface 让它常驻 GPU 显存、
    // CI 渲染零拷贝，省掉逐帧 CPU 缓冲的内存与拷贝开销。
    return @{ (id)kCVPixelBufferPixelFormatTypeKey        : @(kCVPixelFormatType_32BGRA),
              (id)kCVPixelBufferIOSurfacePropertiesKey    : @{},
              (id)kCVPixelBufferOpenGLESCompatibilityKey  : @YES };
}
- (NSDictionary *)sourcePixelBufferAttributes {
    // 源帧直接要 420YUV：解码器原生输出就是这个，写 BGRA 会多一次转换、每帧内存也翻倍。
    // Core Image 会自动把 420YUV 转 RGB，合成部分不用为此改动；输出缓冲仍是 BGRA。
    // 必须带 PixelFormatTypeKey，否则 AVFoundation 直接抛 NSInvalidArgumentException。
    return @{ (id)kCVPixelBufferPixelFormatTypeKey        : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
              (id)kCVPixelBufferIOSurfacePropertiesKey    : @{},
              (id)kCVPixelBufferOpenGLESCompatibilityKey  : @YES };
}
- (void)cancelAllPendingVideoCompositionRequests {
    self.shouldCancelAllRequests = YES;
}
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)req {
    if (self.shouldCancelAllRequests) {
        // 框架每次导出结束都会把这个标志置 YES，且倾向于复用同一个合成器实例；
        // 不在这里复位的话，之后每次导出都会在入口被 finishCancelledRequest 早退、一帧不画。
        self.shouldCancelAllRequests = NO;
        [req finishCancelledRequest];
        return;
    }
    // 导出用的自定义合成器必须同步完成（start 返回前调用 finish*）：帧若被丢到自建队列
    // 异步提交，导出管线不会泵送它们，结果导出“成功”但画面全黑。
    // 只有 AVPlayerItem 的播放链路才支持真正的异步合成。
    [self _renderOneRequest:req];
}

- (void)_renderOneRequest:(AVAsynchronousVideoCompositionRequest *)req {
    @autoreleasepool {
        DDShellVideoInstruction *inst = (DDShellVideoInstruction *)req.videoCompositionInstruction;
        DDShellTemplate *t = inst.tpl;
        CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
        CGRect wb = DD_WindowBBox(t);

        CMPersistentTrackID tid = [(NSNumber *)inst.requiredSourceTrackIDs.firstObject intValue];
        CVPixelBufferRef src = [req sourceFrameByTrackID:tid];
        if (!src) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-1 userInfo:nil]]; return; }

        CVPixelBufferRef dst = [req.renderContext newPixelBuffer];
        if (!dst) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-2 userInfo:nil]]; return; }

        // 源帧先按视频自带旋转摆正。preferredTransform 常带位移把旋转后的帧挪回正位，
        // extent 原点往往不为 0，所以先把原点归零，再按 contain 预缩到屏幕窗大小，
        // 最后透视映射到窗口——避免把巨大坐标 / 大分辨率直接喂进透视。
        CIImage *raw = [CIImage imageWithCVPixelBuffer:src];
        CIImage *rot = [raw imageByApplyingTransform:inst.preferredTransform];
        CGRect re = rot.extent;
        CGFloat sc = MIN(wb.size.width / re.size.width, wb.size.height / re.size.height);
        if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
        // 先平移归零（只动 origin，不改采样），再按 contain 比例预缩
        CIImage *centered = [rot imageByApplyingTransform:CGAffineTransformMakeTranslation(-re.origin.x, -re.origin.y)];
        CIImage *srcImg = DD_ScaledSource(centered, sc);

        CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
        if (!f) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-3 userInfo:nil]]; CVPixelBufferRelease(dst); return; }
        [f setDefaults];
        [f setValue:srcImg forKey:kCIInputImageKey];
        [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, re.size.width * sc, re.size.height * sc)] forKey:@"inputExtent"];
        DD_SetPerspectiveCorners(f, t, H);
        CIImage *warped = f.outputImage;
        if (!warped) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-4 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        // 先烘焙再合成：① 把透视结果渲进 _mid（满画布 IOSurface，复用、不逐帧分配）；
        // ② 读回成普通位图 warpedBaked（已是 8bit sRGB，几何位置同画布），再与机身前景合成。
        // 不这么绕、直接把“滤镜图 + 位图”交出去合成，某些渲染路径下滤镜那层会渲空。
        if (!_mid || (size_t)_midSize.width != (size_t)W || (size_t)_midSize.height != (size_t)H) {
            if (_mid) { CVPixelBufferRelease(_mid); _mid = NULL; }
            CVReturn cvr = CVPixelBufferCreate(kCFAllocatorDefault,
                             (size_t)W, (size_t)H,
                             kCVPixelFormatType_32BGRA,
                             (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                                          (id)kCVPixelBufferOpenGLESCompatibilityKey : @YES },
                             &_mid);
            if (cvr != kCVReturnSuccess || !_mid) {
                [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-7 userInfo:nil]];
                CVPixelBufferRelease(dst); return;
            }
            _midSize = CGSizeMake(W, H);
        }

        @try {
            [_ctx render:warped toCVPixelBuffer:_mid bounds:CGRectMake(0, 0, W, H) colorSpace:_cs];
        } @catch (NSException *e) {
            [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-8 userInfo:@{NSLocalizedDescriptionKey:e.reason}]];
            CVPixelBufferRelease(dst); return;
        }
        CIImage *warpedBaked = [CIImage imageWithCVPixelBuffer:_mid]; // 已是 8bit sRGB，几何同画布
        if (!warpedBaked) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-9 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        CIImage *frame = [CIImage imageWithCGImage:t.image.CGImage];
        CIImage *outImg = [frame imageByCompositingOverImage:warpedBaked]; // 机身图盖在最上层（与预览同序）
        if (!outImg) { [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-5 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        @try {
            [_ctx render:outImg toCVPixelBuffer:dst bounds:CGRectMake(0, 0, W, H) colorSpace:_cs];
        } @catch (NSException *e) {
            [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-6 userInfo:@{NSLocalizedDescriptionKey:e.reason}]];
            CVPixelBufferRelease(dst);
            return;
        }

        // 出一帧交一帧：中间结果不缓存（init 里的 kCIContextCacheIntermediates:@NO），
        // 长视频的显存才不会跟着帧数往上堆
        [req finishWithComposedVideoFrame:dst];
        CVPixelBufferRelease(dst);
    }
}
@end

// 把一段视频逐帧套壳后导出成 mp4，返回临时文件 URL（失败返回 nil）
static NSURL *DD_ComposeShellVideo(NSURL *srcURL, DDShellTemplate *t) {
    AVURLAsset *asset = [AVURLAsset assetWithURL:srcURL];
    AVAssetTrack *vt = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!vt) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil; // 画布尺寸同样卡上限

    // 工作分辨率上限：模板画布常常比相册能收的 4K 像素还大，超限会被相册直接拒收，
    // 所以先按长边等比缩到上限内，再拿缩过的画布和四角去合成。
    // 老设备或更长视频若出现内存告警、导出失败，把 DD_WORK_CAP 往下调一档即可。
    static const CGFloat DD_WORK_CAP = 3200.0;
    CGFloat capW = DD_WORK_CAP, capH = DD_WORK_CAP, capPx = DD_WORK_CAP * DD_WORK_CAP;
    CGFloat s = MIN(MIN(1.0, capW / W), MIN(capH / H, sqrt(capPx / (W * H))));
    DDShellTemplate *st = t;
    if (s < 1.0) {
        CGFloat nW = floor((W * s) / 2.0) * 2.0;   // 取偶数，编码器要求
        CGFloat nH = floor((H * s) / 2.0) * 2.0;
        if (nW < 2.0) nW = 2.0;
        if (nH < 2.0) nH = 2.0;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(nW, nH), NO, 1.0);
        [t.image drawInRect:CGRectMake(0, 0, nW, nH)];
        UIImage *sim = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        st = [DDShellTemplate new];
        st.name = t.name;
        st.image = sim ?: t.image;
        st.canvasSize = CGSizeMake(nW, nH);
        st.lt = CGPointMake(t.lt.x * s, t.lt.y * s);
        st.rt = CGPointMake(t.rt.x * s, t.rt.y * s);
        st.lb = CGPointMake(t.lb.x * s, t.lb.y * s);
        st.rb = CGPointMake(t.rb.x * s, t.rb.y * s);
        W = nW; H = nH;
    }

    NSString *outPath = [DD_TempRoot() stringByAppendingPathComponent:
                         [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];

    AVMutableVideoComposition *vc = [AVMutableVideoComposition videoComposition];
    vc.renderSize = CGSizeMake(W, H);
    CMTime fd = vt.minFrameDuration;
    vc.frameDuration = (fd.timescale && fd.value) ? fd : CMTimeMake(1, 30);

    DDShellVideoInstruction *inst = [DDShellVideoInstruction new];
    inst.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    inst.enablePostProcessing = NO;
    inst.containsTweening = NO;
    inst.requiredSourceTrackIDs = @[ @(vt.trackID) ];
    inst.tpl = st;
    inst.preferredTransform = vt.preferredTransform;
    vc.instructions = @[ inst ];
    vc.customVideoCompositorClass = [DDShellVideoCompositor class];

    __block NSURL *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    // 画质预设只有 Low / Medium / Highest 三档，取 Highest 保清晰度
    AVAssetExportSession *ex = [[AVAssetExportSession alloc] initWithAsset:asset
                                                            presetName:AVAssetExportPresetHighestQuality];
    ex.outputURL = [NSURL fileURLWithPath:outPath];
    ex.outputFileType = AVFileTypeMPEG4;
    ex.videoComposition = vc;
    [ex exportAsynchronouslyWithCompletionHandler:^{
        if (ex.status == AVAssetExportSessionStatusCompleted) result = ex.outputURL;
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (!result) { // 导出失败，半截 mp4 不留
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
    }
    return result;
}

// 视频存相册。临时 mp4 无论成败都回收：失败时尤其要删——没相册权限或磁盘满这两种失败
// 会连着发生，留着只会让磁盘更紧，而下次启动才跑的整目录清理未必来得及。
// 导出失败那条路径在上面已经删过了，两条失败路径都不留残骸。
static void DD_SaveVideoToAlbum(NSURL *url, void (^done)(BOOL success, NSError *err)) {
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError *error) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        if (done) done(success, error);
    }];
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

static void DD_SaveImageToAlbum(UIImage *img, void (^done)(BOOL success, NSError *err)) {
    __block PHObjectPlaceholder *ph = nil;
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromImage:img];
        ph = req.placeholderForCreatedAsset;
    } completionHandler:^(BOOL success, NSError *error) {
        // 成品也记一笔，避免之后被当成未处理的截图重复套壳
        if (success && ph.localIdentifier.length) {
            [[DDShellConfig shared] markProcessed:ph.localIdentifier];
        }
        if (done) done(success, error);   // 真正存好/失败后才回调
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

static WeToast *gBusyToast = nil; // 进行中的 loading 提示（套壳 / 导入 / 导出），完成后收起

// 套壳闸门：同一时刻只放行一个任务，抢不到闸的直接放弃，不排队。
// 三条套壳入口（自动截屏 / 相册选图 / 相册选视频）都先抢它，任务彻底跑完才还闸。
// 不排队是有意的：排队意味着几十秒后才轮到，那时自动截屏取到的"相册最新一张"
// 早就不是刚截的那张了，会套错图，开了删原图还会删错图。
static dispatch_semaphore_t DD_ShellGate(void) {
    static dispatch_semaphore_t gate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gate = dispatch_semaphore_create(1); });
    return gate;
}

// 抢闸：抢到返回 YES。非阻塞，主线程上调也安全
static BOOL DD_ShellTryBegin(void) {
    return dispatch_semaphore_wait(DD_ShellGate(), DISPATCH_TIME_NOW) == 0;
}

// 还闸：必须在任务彻底结束（相册存完、提示弹完）之后调，漏一次后面就全废
static void DD_ShellEnd(void) {
    dispatch_semaphore_signal(DD_ShellGate());
}

static WeToast *DD_Toast(void) {
    return [NSClassFromString(@"WeToast") toast];
}

// loading / 成功 / 失败 / 纯文字四种提示，都用微信的 WeToast
// 收起 loading：调用方都在主线程
static void DD_HideLoading(void) {
    [gBusyToast hideWithAnimated:YES];
    gBusyToast = nil;
}
// 开始 loading，实例存下来给后面收起用。
// 上一个若还没收（比如套壳转着的时候又点了导出），先收掉它再起新的：
// gBusyToast 只留一个实例，直接覆盖会让上一个转圈永远停在屏幕上——它自己那次收起
// 调用只会收到新的这个。
static void DD_ShowLoading(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gBusyToast) DD_HideLoading();
        WeToast *toast = DD_Toast();
        [toast setLoadingStyle:YES];
        [toast showToastWithText:text];
        gBusyToast = toast;
    });
}
static void DD_ShowShellDone(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        DD_HideLoading();
        [DD_Toast() showDoneToastWithText:@"套壳成功"];
    });
}
// 方形带错误图标。loading 用的是同一个 WeToast 实例，先收起
static void DD_ShowError(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        DD_HideLoading();
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
        // 抢不到闸说明有套壳任务在跑，这次截屏直接放弃，不排队也不提示——
        // 等几十秒才轮到的话，"相册最新一张"早就不是刚截的那张了
        if (!DD_ShellTryBegin()) return;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self shellLatestScreenshotWithCompletion:^{
                DD_ShellEnd();
            }];
        });
    });
}

- (void)shellLatestScreenshotWithCompletion:(void (^)(void))completion {
    DDShellTemplate *t = DD_ActiveTemplate();
    if (!t) { completion(); return; }
    DD_LatestImageAsset(^(PHAsset *asset) {
        if (!asset) { completion(); return; }
        if ([[DDShellConfig shared] hasProcessed:asset.localIdentifier]) { completion(); return; } // 去重
        PHImageRequestOptions *ro = [PHImageRequestOptions new];
        ro.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        ro.networkAccessAllowed = NO;
        DD_ShowLoading(@"正在套壳");
        [[PHImageManager defaultManager] requestImageForAsset:asset
                                                   targetSize:PHImageManagerMaximumSize
                                                  contentMode:PHImageContentModeDefault
                                                      options:ro
                                                resultHandler:^(UIImage *img, NSDictionary *info) {
            UIImage *outImg = (img) ? DD_ComposeShellImage(img, t) : nil;
            if (!outImg) { DD_ShowError(@"套壳失败"); completion(); return; }
            // 成功提示必须等相册真正存好再弹，避免存失败也报成功；
            // 删除原图也放在成功分支，存失败时不删，避免原图丢失
            DD_SaveImageToAlbum(outImg, ^(BOOL success, NSError *err) {
                if (success) {
                    if ([DDShellConfig shared].deleteOriginal) DD_DeleteAssets(@[asset]);
                    DD_ShowShellDone();
                } else {
                    DD_ShowError(@"套壳失败");
                }
                completion();
            });
        }];
    });
}

@end

#pragma mark - 导入导出

// 这两个类只为提供 selector 声明：objc_getClass() 的返回值是 Class 类型的接收者，
// clang 要见到同名 selector 的声明才放行。实际取的是微信里的 QSSZipArchive，
// 编译期不产生链接符号。
@interface DDZipArchive : NSObject
+ (BOOL)createZipFileAtPath:(id)zipPath withContentsOfDirectory:(id)dir keepParentDirectory:(BOOL)keep;
+ (BOOL)unzipFileAtPath:(id)zipPath toDestination:(id)dest;
@end

// 同上：既当类型用，也给下面几个方法提供 selector 声明，
// 实际取的是 UIDocumentPickerViewController
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
        // 名字直接当目录名用：. 和 .. 会指到别的目录，覆盖同名时连上级一起删掉
        if ([base isEqualToString:@"."] || [base isEqualToString:@".."]) continue;
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
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp   = [DD_TempRoot() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    NSString *stage = [tmp stringByAppendingPathComponent:@"DDShell模板"];
    [fm createDirectoryAtPath:stage withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in names) {
        [fm copyItemAtPath:DD_TplFolder(name) toPath:[stage stringByAppendingPathComponent:name] error:nil];
    }
    NSString *zip = [tmp stringByAppendingPathComponent:@"DDShell_套壳模板.zip"];
    if (DD_ZipDirectory(stage, zip)) return zip;
    [fm removeItemAtPath:tmp error:nil]; // 打包失败，临时暂存目录回收（调用方提前 return 来不及清）
    return nil;
}

#pragma mark - 套壳素材库

// 微信原生弹窗（运行时按类名取，编译期不产生链接符号）。
// 按钮回调一律用无参 selector：微信调用时带不带参数不确定，无参声明收不到也安全。
// 按钮靠不同 selector 区分；输入框内容用 getTextFieldText 从存下来的实例里取。
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

// 格子边长：页面宽减去首尾间距后按列数平分（缩略图是正方形）
static CGFloat DD_CellSide(UICollectionView *cv) {
    CGFloat gap = kDDShellTplGap;
    return floor((cv.bounds.size.width - gap * (kDDShellTplColumns + 1)) / kDDShellTplColumns);
}

// 缩略图缓存：模板 png 是全尺寸图，每格都整图解一次码滚动会卡，按格子边长解码一次后缓存
static NSCache *DD_ThumbCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 80;
        // 条数之外再卡一层字节数：80 条全占满约 93MB，64MB 够铺好几屏，峰值压得住。
        // （NSCache 本身会在系统内存告警时自动清空，这里只是让平时也不至于堆那么高。）
        cache.totalCostLimit = 64 * 1024 * 1024;
    });
    return cache;
}

// key = 模板名 + 格子边长。用名字就够：模板路径本来就是按名字拼出来的，
// 名字一变路径必然跟着变，不存在“同名不同路径”。
static NSString *DD_ThumbKey(NSString *name, CGFloat side) {
    return (name.length && side > 0) ? [NSString stringWithFormat:@"%@|%d", name, (int)side] : nil;
}

// 模板内容或名字发生变化后清空缩略图缓存：导入同名模板时是整目录覆盖，png 换成了新图
// 但路径一字未变、key 也就完全一样，不清缓存格子会继续显示上一张缩略图。
// 改名 / 删除时 key 会跟着变（不会串图），但旧条目白占内存，一并清掉。
static void DD_ThumbCachePurge(void) {
    [DD_ThumbCache() removeAllObjects];
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
    // cost 必须显式给：totalCostLimit 只对 setObject:forKey:cost: 的条目起作用，
    // 不传 cost（默认 0）的话上面那条上限形同虚设。按位图实际占的字节算：
    // 画布是 side×side（pt），乘屏幕 scale 得像素边长，再乘 4 字节（RGBA）。
    if (out) {
        NSUInteger px = (NSUInteger)(side * [UIScreen mainScreen].scale + 0.5);
        [DD_ThumbCache() setObject:out forKey:key cost:px * px * 4];
    }
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

// 分组底色：取设置页 tableView 的底色，两页同源，微信换主题时一起变
static UIColor *DD_GroupBackgroundColor = nil;

// 导航栏底边：全屏布局下就是 view.safeAreaInsets.top（状态栏 + 导航栏）
static CGFloat DD_TopUnderNavBar(UIView *view) {
    return view.safeAreaInsets.top;
}

// 导航栏外观不碰：微信自己实现整套导航栏（背景、标题、返回箭头、转场渲染），
// 不走 UIKit 的 UINavigationBarAppearance。

// 独立的素材库页面：
//   双排网格列出模板，右上角常驻 导出 / 导入（导入最靠右），默认按名称排序；
//   点「导出」用微信原生 WCActionSheet 弹「选择导出方式」：选择导出 / 全部导出（取消自带）；
//   「选择导出」进入选择态，右上角换成 删除 / 导出 / 取消；
//   长按一个模板弹 WCActionSheet「套壳操作」：使用模板 / 重命名 / 选择·多选 / 删除此模板，
//   选「选择/多选」同样进选择态；单击一个模板则直接把它设为当前生效（绿框挪过去即反馈）。
@interface DDShellLibraryViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;           // 贴在 view 顶上的搜索框
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

    // 保持默认全屏布局，导航栏底边在 viewDidLayoutSubviews 里按 safeAreaInsets.top 量。
    // 不用 edgesForExtendedLayout = UIRectEdgeNone：它靠改 view 的 safeAreaInsets 实现，
    // 和微信 Coordinator 转场时改的是同一块状态。

    self.view.backgroundColor = DD_GroupBackgroundColor;

    [self setupSearchBar];
    [self setupCollectionView];
    [self setupNavigationBar];
    [self reloadList];
}

// 搜索条自己贴在 view 顶上：挂 navigationItem.searchController 会把导航栏撑高。
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
    // 一滚列表就收起搜索键盘。OnDrag = 开始拖动立刻收（干脆）；
    // 想要“键盘跟手往下走、拖回去还能取消”的细腻手感，可换 Interactive。
    cv.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    cv.delegate = self;
    cv.dataSource = self;
    [cv registerClass:[DDShellTplCell class] forCellWithReuseIdentifier:@"DDShellTplCell"];

    // 长按唤出「套壳操作」菜单（使用模板 / 重命名 / 选择·多选 / 删除此模板）；
    // 单击则由 didSelectItemAtIndexPath 直接把该模板设为当前生效。
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(onLongPressTpl:)];
    lp.minimumPressDuration = 0.5;                 // 系统默认时长，与常见“长按唤菜单”一致
    [cv addGestureRecognizer:lp];

    // 点列表任意位置（格子、格子间空白都算）收起搜索键盘。
    // cancelsTouchesInView 必须设 NO：默认 YES 会在手势成立后取消整条 touch 序列，
    // collectionView 就再也收不到这次点击，didSelectItemAtIndexPath 不触发（点不动模板）。
    UITapGestureRecognizer *tp = [[UITapGestureRecognizer alloc]
                                  initWithTarget:self action:@selector(onTapList:)];
    tp.cancelsTouchesInView = NO;
    [cv addGestureRecognizer:tp];

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
// 前提是 push 走微信自己的 PushViewController:animated:。自定义 leftBarButtonItem
// 还会让边缘侧滑返回失效。

// 默认按名称排序（本地化、数字感知：「模板2」排在「模板10」前面）
- (void)reloadList {
    NSMutableArray *all = [DD_AllTemplateNames() mutableCopy];
    [all sortUsingSelector:@selector(localizedStandardCompare:)];
    self.allNames = all;
    self.activeName = DD_ActiveTemplateName();
    [self applySearchFilter];
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

- (CGSize)collectionView:(UICollectionView *)cv layout:(UICollectionViewFlowLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)ip {
    CGFloat w = DD_CellSide(cv);
    return CGSizeMake(w, w + 30.0); // 正方形缩略图 + 20pt 名字行
}

- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)section {
    return self.names.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip {
    DDShellTplCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"DDShellTplCell" forIndexPath:ip];
    NSString *n = self.names[ip.item];

    cell.nameLabel.text = n;
    CGFloat w = DD_CellSide(cv);
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

// 长按某个模板 → 弹「套壳操作」菜单。
// 只在普通态响应：选择态下单击是切换勾选，再让长按弹菜单容易误触、且菜单里的
// 「选择/多选」在选择态下语义重复。
// cancelsTouchesInView 默认 YES：长按判定成立后 touch 序列被取消，不会连带触发单击选中。
- (void)onLongPressTpl:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    if (self.isSelectMode) return;
    CGPoint p = [g locationInView:self.collectionView];
    NSIndexPath *ip = [self.collectionView indexPathForItemAtPoint:p];
    if (!ip) return;
    if (ip.item < 0 || ip.item >= (NSInteger)self.names.count) return;
    NSString *n = self.names[ip.item];
    if (!n.length) return;

    self.tappedTpl = n;
    [self showWCActionSheet:@"套壳操作" tag:DD_SHEET_TPL items:@[@"使用模板", @"重命名", @"选择/多选", @"删除此模板"]];
}

// 点列表任意位置收起搜索键盘：模板少、列表滚不动时，滚动收起那招不生效，这里是兜底出口。
// 加了 cancelsTouchesInView=NO，本手势与「点格子选模板」「长按弹菜单」互不干扰。
- (void)onTapList:(UITapGestureRecognizer *)g {
    if (self.searchBar.isFirstResponder) [self.searchBar resignFirstResponder];
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

    // 普通态：点一下直接把这个模板设为当前生效（即菜单里的「使用模板」），
    // 完整操作菜单改由长按唤出。反馈沿用同一套：reloadList 后绿框挪到新模板上。
    [DDShellConfig shared].selectedTpl = n;
    [self reloadList];
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
    } else if (tag == DD_SHEET_TPL) { // 套壳操作：0=使用模板 1=重命名 2=选择/多选 3=删除此模板
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

// 选择态 UI 三连：按钮可用性、标题计数、格子勾选状态都跟着 picked 变，一次刷齐
- (void)refreshSelectUI {
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

// 进入选择态：勾选清空，右上角换成 删除 / 导出 / 取消
- (void)enterExportSelectMode {
    self.isSelectMode = YES;
    [self.picked removeAllObjects];
    [self refreshSelectUI];
}

// 从「套壳操作 → 选择/多选」进入：顺手把那一个勾上
- (void)enterExportSelectModeWithName:(NSString *)name {
    self.isSelectMode = YES;
    [self.picked removeAllObjects];
    [self.picked addObject:name];
    [self refreshSelectUI];
}

- (void)cancelExportSelectMode {
    self.isSelectMode = NO;
    [self.picked removeAllObjects];
    [self refreshSelectUI];
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
    // 打包要整批拷贝模板 png，丢后台跑，主线程留着转 loading
    DD_ShowLoading(@"正在导出模板");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *zip = DD_ExportTemplatesToZip(names);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!zip) { DD_ShowError(@"导出失败"); return; }

            DD_HideLoading();
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
        });
    });
}

#pragma mark 重命名

- (void)renameTemplateNamed:(NSString *)name {
    [self showRenameForName:name text:name message:name];
}

// 带输入框的重命名弹窗：输入框上方第一次显示模板原名，出错重弹时显示错误原因
- (void)showRenameForName:(NSString *)name text:(NSString *)text message:(NSString *)message {
    self.renamingName = name;
    WCUIAlertView *av = [[NSClassFromString(@"WCUIAlertView") alloc] initWithTitle:@"重命名" message:message];
    [av setTextFieldDefaultText:text];
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
    NSString *err = [self renameTemplate:oldName to:text];
    if (!err.length) return;
    // 按钮回调里直接再 show 会和本次弹窗的收起动画撞上，等一帧再弹，填过的内容留在框里
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showRenameForName:oldName text:text message:err];
    });
}

// 目录和目录里的 png/cfg 一起改名；当前正在用的模板被改名则同步选中记录
// 返回 nil 表示改好了，有错返回原因
- (NSString *)renameTemplate:(NSString *)oldName to:(NSString *)newName {
    newName = [newName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!newName.length) return @"名字不能为空";
    if ([newName isEqualToString:oldName]) return nil;
    // 名字直接当目录名用：/ 会被当成路径分隔符（模板藏进嵌套目录，列表读不到），
    // . 和 .. 会指到别的目录（删除时连上级一起删掉）
    if ([newName containsString:@"/"] || [newName isEqualToString:@"."] || [newName isEqualToString:@".."]) {
        return @"重命名不允许特殊符号";
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *srcDir = DD_TplFolder(oldName), *dstDir = DD_TplFolder(newName);
    if ([fm fileExistsAtPath:dstDir]) return @"已有同名模板";

    BOOL ok = YES;
    for (NSString *ext in @[@"png", @"cfg"]) {
        NSString *src = DD_FileInFolder(srcDir, oldName, ext);
        NSString *dst = [srcDir stringByAppendingPathComponent:[newName stringByAppendingPathExtension:ext]];
        if (![fm moveItemAtPath:src toPath:dst error:nil]) ok = NO;
    }
    if (ok) ok = [fm moveItemAtPath:srcDir toPath:dstDir error:nil];
    if (!ok) return @"重命名失败";

    if ([[DDShellConfig shared].selectedTpl isEqualToString:oldName]) [DDShellConfig shared].selectedTpl = newName;
    DD_ThumbCachePurge(); // 名字变了，旧 key 的条目留着只会白占内存
    [self reloadList]; // 列表里名字变了就是反馈，不用再弹回执
    return nil;
}

#pragma mark 删除

// 实际删除：连整目录一起删；删掉的是当前模板则清空选择
- (void)deleteNames:(NSArray<NSString *> *)names {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *name in names) {
        [fm removeItemAtPath:DD_TplFolder(name) error:nil];
    }
    // 删掉正在用的就清空选择，不自动顶下一个
    if ([names containsObject:[DDShellConfig shared].selectedTpl]) {
        [DDShellConfig shared].selectedTpl = @"";
    }
    DD_ThumbCachePurge(); // 清掉已删模板的残留条目（同名模板以后重新导入时也靠它避免串旧图）
}

// 选择态点右上角「删除」：先确认再删
- (void)deleteSelectedFrames {
    NSArray *names = [self.picked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [self confirmDeleteNames:names];
}

// 删除确认，单个和批量共用
- (void)confirmDeleteNames:(NSArray<NSString *> *)names {
    NSString *msg = names.count == 1
        ? [NSString stringWithFormat:@"已选：%@", names.firstObject]
        : [NSString stringWithFormat:@"已选：%ld 个模板", (long)names.count];

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

    NSString *tmp = [DD_TempRoot() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];

    // 解压 zip、整批拷模板都要在后台跑，模板多时好几秒没动静，先转上 loading 再走
    DD_ShowLoading(@"正在导入");
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
            DD_HideLoading();
            if (!n) DD_ShowToast(@"没有找到可导入的模板"); // 导入成功靠列表多出来的格子反馈
            DD_ThumbCachePurge();   // 同名模板是被覆盖安装的，不清缓存会显示上一张缩略图
            [self reloadList];
        });
    });
}

- (void)documentPickerWasCancelled:(id)controller { }

@end

#pragma mark - 设置界面

// 微信私有的 push（大写 P）：只有走它，Coordinator 才会接管返回箭头
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

    // 页面底色直接取现成 tableView 的底色，顺手存进 DD_GroupBackgroundColor 给素材库用
    UITableView *tableView = [self.tableViewMgr getTableView];
    DD_GroupBackgroundColor = tableView.backgroundColor;
    self.view.backgroundColor = DD_GroupBackgroundColor;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    // tableView 的底色交给 WCTableViewManager 不动；frame 交给 viewDidLayoutSubviews。
    [self.view addSubview:tableView];
}

// 表格从导航栏底下开始：全屏铺的话上滚时单元格会从导航栏底下穿过（与素材库同一套算法）。
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

        [section addCell:[cellCls normalCellForSel:@selector(pickVideoFromAlbumTapped:)
                                            target:self title:@"↳相册视频套壳"
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

#pragma mark - 相册选图/选视频套壳

// 拉起相册选择器：mediaTypes 传 nil 挑图片，传 @[@"public.movie"] 挑视频
- (void)presentAlbumPickerWithMediaTypes:(NSArray<NSString *> *)mediaTypes {
    if (!DD_ActiveTemplate()) { DD_ShowToast(@"模板未选择"); return; }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    if (mediaTypes) picker.mediaTypes = mediaTypes;
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
}

// 从相册挑选一张图，套入当前模板后存回相册（不删除所选原图）
- (void)pickFromAlbumTapped:(id)sender {
    [self presentAlbumPickerWithMediaTypes:nil];
}

// 从相册挑选一段视频，套入当前模板后导出存回相册（不删除所选原视频）
- (void)pickVideoFromAlbumTapped:(id)sender {
    [self presentAlbumPickerWithMediaTypes:@[ @"public.movie" ]]; // 只挑视频
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        // 图片与视频共用一个回调，按媒体类型分流
        if ([info[UIImagePickerControllerMediaType] isEqualToString:@"public.movie"]) {
            [self handlePickedVideo:info];
        } else {
            [self handlePickedImage:info];
        }
    }];
}

// 相册选图套壳：单张图透视贴入模板，存回相册
- (void)handlePickedImage:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    DDShellTemplate *t = DD_ActiveTemplate();
    if (!t) { DD_ShowError(@"套壳失败"); return; } // 选图期间模板可能已经被删了
    if (!DD_ShellTryBegin()) { DD_ShowToast(@"有套壳任务在进行中"); return; }
    // 合成要开全尺寸画布，丢后台跑，主线程留着转 loading
    DD_ShowLoading(@"正在套壳");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *outImg = DD_ComposeShellImage(img, t);
        if (!outImg) { DD_ShowError(@"套壳失败"); DD_ShellEnd(); return; }
        // 相册选图套壳不删除原图；成功提示必须等相册真正存好再弹，避免存失败也报成功
        DD_SaveImageToAlbum(outImg, ^(BOOL success, NSError *err) {
            if (success) {
                DD_ShowShellDone();
            } else {
                DD_ShowError(@"套壳失败");
            }
            DD_ShellEnd();
        });
    });
}

// 合成并存相册（放在 toast 提示函数之后，DD_ShowError/DD_ShowShellDone 才已声明）
static void DD_ComposeAndSaveVideo(NSURL *url, DDShellTemplate *t) {
    NSURL *outURL = DD_ComposeShellVideo(url, t);
    if (!outURL) { DD_ShowError(@"套壳失败"); DD_ShellEnd(); return; }
    DD_SaveVideoToAlbum(outURL, ^(BOOL success, NSError *err) {
        if (success) DD_ShowShellDone();
        else DD_ShowError(@"套壳失败");
        DD_ShellEnd();
    });
}

// 相册选视频套壳：逐帧透视合成后导出 mp4，存回相册
- (void)handlePickedVideo:(NSDictionary *)info {
    NSURL *url = info[UIImagePickerControllerMediaURL];
    DDShellTemplate *t = DD_ActiveTemplate();
    if (!url || !t) { DD_ShowError(@"套壳失败"); return; } // 选视频期间模板可能已经被删了
    if (!DD_ShellTryBegin()) { DD_ShowToast(@"有套壳任务在进行中"); return; }

    // 逐帧合成 + 导出是重活，丢后台跑，主线程留着转 loading
    DD_ShowLoading(@"正在套壳");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        DD_ComposeAndSaveVideo(url, t);
    });
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

        // 清掉上次会话（崩溃/强退/被杀）残留的临时文件；任务中途被杀时流程内的清理来不及跑
        NSString *tmpRoot = DD_TempRoot();
        for (NSString *item in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpRoot error:nil]) {
            [[NSFileManager defaultManager] removeItemAtPath:[tmpRoot stringByAppendingPathComponent:item] error:nil];
        }

        // 取不到类时整条链都是给 nil 发消息，ObjC 天然 no-op
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                  version:@"1.0.0"
                                               controller:@"DDShellSettingsViewController"];
    }
}

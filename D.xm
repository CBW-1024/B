// ============================================================================
//  DDShell.xm —— 截图模板套壳插件
//
//  功能：截图后自动把截图套入模板，并保存回相册；也可以从相册挑图手动套。
//  流程：监听系统截屏通知 → 从相册取最新截图 → 透视贴入模板窗口 → 存回相册。
//  cfg 为 JSON，字段：template_width / template_height 与四个屏幕窗角点坐标。
//  素材库：设置页入口，模板的导入导出（zip）、应用、重命名、删除都在这一页。
// ============================================================================

#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
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

// DDShell 专用临时目录：NSTemporaryDirectory()/DDShell/
// 与微信原生 tmp 隔离，便于在崩溃/强退/被杀后于下次启动统一清理，避免残骸堆积。
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

// 模板四角在画布里围出的屏幕窗包围盒（用来把源按 contain 预缩到窗口尺寸）
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

static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    UIImage *frameImg = t.image;
    CGImageRef frameCG = frameImg.CGImage;
    CGImageRef shotCG = shot.CGImage;
    if (!frameCG || !shotCG) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    // 尺寸取自 cfg，按 CoreGraphics 的纹理上限卡一道，超了就放弃这次合成
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil;

    // 截图按实际像素尺寸参与计算
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 画布按 1 倍开（1 单位 = 1 像素），成品尺寸才严格等于 cfg 写的模板尺寸
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);

    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 源先按 contain 预缩到屏幕窗尺寸，再做透视映射。直接把大图整张透视，中间图会被
    // 拉得过大、逐帧合成容易卡死或被相册拒收（ZDY 即先预缩放再透视）。
    CGRect wb = DD_WindowBBox(t);
    CGFloat sc = MIN(wb.size.width / A, wb.size.height / B);
    if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
    CIImage *src = [[CIImage imageWithCGImage:shotCG] imageByApplyingTransform:CGAffineTransformMakeScale(sc, sc)];
    CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
    [f setDefaults];
    [f setValue:src forKey:kCIInputImageKey];
    [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, A * sc, B * sc)] forKey:@"inputExtent"];
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

#pragma mark - 视频套壳（相册选视频，逐帧透视合成后导出）

// 把一帧源像素缓冲套壳成画布大小，渲染进 outBuf。
// 与图片路径一致：源先按 contain 预缩到屏幕窗、再做透视映射，机身图盖最上层。
// 源自带旋转由 pref（视频轨 preferredTransform）在这里摆正，再归一化原点后参与透视。
static BOOL DD_RenderShellFrame(CVPixelBufferRef srcPB, DDShellTemplate *t,
                               NSInteger W, NSInteger H, CGAffineTransform pref,
                               CIContext *ci, CGColorSpaceRef cs, CVPixelBufferRef outBuf) {
    if (!srcPB || !outBuf) return NO;
    CIImage *raw = [CIImage imageWithCVPixelBuffer:srcPB];
    // 按视频自带旋转摆正；preferredTransform 常带位移把旋转后的帧挪回正位，其 extent 原点
    // 往往不为 0。先归一化原点再量尺寸，避免把巨大坐标直接喂进透视导致投影退化。
    CIImage *rot = [raw imageByApplyingTransform:pref];
    CGRect re = rot.extent;
    CGFloat sW = re.size.width, sH = re.size.height;
    if (sW < 1.0 || sH < 1.0) return NO;

    // contain 预缩到屏幕窗（对齐 ZDY 先预缩放再透视，避免大分辨率直接透视导致投影退化）
    CGRect wb = DD_WindowBBox(t);
    CGFloat sc = MIN(wb.size.width / sW, wb.size.height / sH);
    if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
    CGAffineTransform norm = CGAffineTransformMakeTranslation(-re.origin.x, -re.origin.y);
    norm = CGAffineTransformConcat(norm, CGAffineTransformMakeScale(sc, sc));
    CIImage *srcImg = [rot imageByApplyingTransform:norm];

    CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
    [f setDefaults];
    [f setValue:srcImg forKey:kCIInputImageKey];
    [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, sW * sc, sH * sc)] forKey:@"inputExtent"];
    [f setValue:DD_CIVec(t.lt, H) forKey:@"inputTopLeft"];
    [f setValue:DD_CIVec(t.rt, H) forKey:@"inputTopRight"];
    [f setValue:DD_CIVec(t.rb, H) forKey:@"inputBottomRight"];
    [f setValue:DD_CIVec(t.lb, H) forKey:@"inputBottomLeft"];
    CIImage *warped = f.outputImage;

    CIImage *frame = [CIImage imageWithCGImage:t.image.CGImage];
    CIImage *outImg = [frame imageByCompositingOverImage:warped]; // 机身图盖在最上层
    [ci render:outImg toCVPixelBuffer:outBuf bounds:CGRectMake(0, 0, W, H) colorSpace:cs];
    return YES;
}

// 把一段视频逐帧套壳后导出成 mp4，返回临时文件 URL（失败返回 nil）。
// 走 AVAssetReader + AVAssetWriter 手动管线（对齐 ZDY），输出尺寸 / 编码 / 封装 / 音频全部
// 显式指定，彻底受控——规避系统 AVAssetExportSession 自动决策在大尺寸 / 非对齐模板上
// 产出被照片库判为 InvalidResource（PHPhotosErrorDomain 3302）的 mp4。
static NSURL *DD_ComposeShellVideo(NSURL *srcURL, DDShellTemplate *t) {
    AVURLAsset *asset = [AVURLAsset assetWithURL:srcURL];
    AVAssetTrack *vt = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!vt) return nil;
    CGAffineTransform pref = vt.preferredTransform; // 源自带旋转，在合成时摆正

    CGFloat cw = t.canvasSize.width, ch = t.canvasSize.height;
    if (cw < 2.0 || ch < 2.0 || cw > 8192.0 || ch > 8192.0) return nil; // 画布尺寸同样卡上限
    // H.264 要求宽高均为偶数；模板画布若非偶数，整体对齐到偶数（变化 ≤1px，无可见影响）
    NSInteger W = (NSInteger)round(cw), H = (NSInteger)round(ch);
    if (W % 2) W += 1;
    if (H % 2) H += 1;

    NSString *outPath = [DD_TempRoot() stringByAppendingPathComponent:
                         [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:outPath])
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];

    NSError *err = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
    if (!reader) return nil;
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:outPath]
                                                     fileType:AVFileTypeMPEG4 error:&err];
    if (!writer) { [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil]; return nil; }

    // 读取端：直读像素。旋转摆正放在合成函数里手动处理 preferredTransform，
    // 避开 iOS17+ 已移除的 AVAssetReaderTrackOutput.appliesPreferredTrackTransform 属性。
    AVAssetReaderTrackOutput *vout = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:vt
                                                                              outputSettings:@{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    }];
    vout.alwaysCopiesSampleData = NO;
    [reader addOutput:vout];

    // 写入端：显式 H.264 + 显式尺寸 + 显式封装，彻底受控
    AVAssetWriterInput *vIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                outputSettings:@{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(W),
        AVVideoHeightKey: @(H),
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
    }];
    vIn.expectsMediaDataInRealTime = NO;
    [writer addInput:vIn];

    // 音频：读取端解压成 PCM，写入端重新编码为 AAC；源无音频则跳过（视频仍可正常导入）
    AVAssetTrack *at = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetReaderTrackOutput *aout = nil;
    AVAssetWriterInput *aIn = nil;
    double aRate = 44100.0, aCh = 2.0;
    if (at) {
        CMFormatDescriptionRef fd = (__bridge CMFormatDescriptionRef)(at.formatDescriptions.firstObject);
        if (fd) {
            const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd);
            if (asbd) { aRate = asbd->mSampleRate ?: 44100.0; aCh = asbd->mChannelsPerFrame ?: 2.0; }
        }
        aout = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:at outputSettings:@{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVSampleRateKey: @(aRate),
            AVNumberOfChannelsKey: @(aCh),
            AVLinearPCMBitDepthKey: @16,
            AVLinearPCMIsBigEndianKey: @NO,
            AVLinearPCMIsFloatKey: @NO,
            AVLinearPCMIsNonInterleavedKey: @NO,
        }];
        aout.alwaysCopiesSampleData = NO;
        [reader addOutput:aout];
        aIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:@{
            AVFormatIDKey: @(kAudioFormatMPEG4AAC),
            AVSampleRateKey: @(aRate),
            AVNumberOfChannelsKey: @(aCh),
            AVEncoderBitRateKey: @(128000),
        }];
        aIn.expectsMediaDataInRealTime = NO;
        [writer addInput:aIn];
    }

    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

    // 自建输出像素缓冲池，绕开 iOS17+ 已废弃的 AVAssetWriterInputPixelBufferAdaptor
    CVPixelBufferPoolRef pbPool = NULL;
    NSDictionary *poolAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey : @(W),
        (id)kCVPixelBufferHeightKey : @(H),
        (id)kCVPixelBufferOpenGLESCompatibilityKey : @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    };
    CVPixelBufferPoolCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)poolAttrs, &pbPool);
    // 由一张样例缓冲推导输出格式描述，供后续把每帧包成 CMSampleBuffer 写入
    CMVideoFormatDescriptionRef vfmt = NULL;
    if (pbPool) {
        CVPixelBufferRef probe = NULL;
        if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pbPool, &probe) == kCVReturnSuccess) {
            CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, probe, &vfmt);
            CVPixelBufferRelease(probe);
        }
    }

    if (![reader startReading] || ![writer startWriting]) {
        if (cs) CGColorSpaceRelease(cs);
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
        return nil;
    }
    // 会话时间轴从 0 起算：源样本 PTS 均 ≥0，保证不会落在会话起点之前被丢弃 / 报错
    [writer startSessionAtSourceTime:kCMTimeZero];

    __block BOOL ok = YES;
    dispatch_group_t grp = dispatch_group_create();

    // 视频轨：逐帧透视套壳后写入
    dispatch_queue_t vq = dispatch_queue_create("com.ddshell.vreader", DISPATCH_QUEUE_SERIAL);
    dispatch_group_enter(grp);
    [vIn requestMediaDataWhenReadyOnQueue:vq usingBlock:^{
        while ([vIn isReadyForMoreMediaData]) {
            CMSampleBufferRef sb = [vout copyNextSampleBuffer];
            if (!sb) { [vIn markAsFinished]; dispatch_group_leave(grp); return; }
            @autoreleasepool {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(sb);
                CVPixelBufferRef srcPB = CMSampleBufferGetImageBuffer(sb);
                CVPixelBufferRef outPB = NULL;
                CMSampleBufferRef outSB = NULL;
                if (srcPB && pbPool && CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pbPool, &outPB) == kCVReturnSuccess) {
                    if (DD_RenderShellFrame(srcPB, t, W, H, pref, ci, cs, outPB) && vfmt) {
                        CMSampleTimingInfo timing;
                        timing.duration = kCMTimeInvalid;
                        timing.presentationTimeStamp = pts;
                        timing.decodeTimeStamp = kCMTimeInvalid;
                        if (CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, outPB, vfmt, &timing, &outSB) == 0
                            && outSB && ![vIn appendSampleBuffer:outSB]) ok = NO;
                    } else {
                        ok = NO;
                    }
                    if (outSB) CFRelease(outSB);
                    CVPixelBufferRelease(outPB);
                } else {
                    ok = NO;
                }
            }
            CFRelease(sb);
            if (!ok) { [vIn markAsFinished]; dispatch_group_leave(grp); return; }
        }
    }];

    // 音频轨：透传 PCM，由写入端编码为 AAC（时间戳自带，保证与视频同步）
    if (aout && aIn) {
        dispatch_queue_t aq = dispatch_queue_create("com.ddshell.areader", DISPATCH_QUEUE_SERIAL);
        dispatch_group_enter(grp);
        [aIn requestMediaDataWhenReadyOnQueue:aq usingBlock:^{
            while ([aIn isReadyForMoreMediaData]) {
                CMSampleBufferRef sb = [aout copyNextSampleBuffer];
                if (!sb) { [aIn markAsFinished]; dispatch_group_leave(grp); return; }
                if (![aIn appendSampleBuffer:sb]) ok = NO;
                CFRelease(sb);
                if (!ok) { [aIn markAsFinished]; dispatch_group_leave(grp); return; }
            }
        }];
    }

    dispatch_group_wait(grp, DISPATCH_TIME_FOREVER);

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if (cs) CGColorSpaceRelease(cs);
    if (vfmt) CFRelease(vfmt);
    if (pbPool) CVPixelBufferPoolRelease(pbPool);

    if (writer.status != AVAssetWriterStatusCompleted || !ok) {
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil]; // 半截 mp4 回收
        return nil;
    }
    return [NSURL fileURLWithPath:outPath];
}

// 视频存相册，存完回调（成功才删临时文件，失败保留以便排查，下次启动会清理）
static void DD_SaveVideoToAlbum(NSURL *url, void (^done)(BOOL success, NSError *err)) {
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError *error) {
        if (success) [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
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
        // 成品也标记为已处理，避免之后被当成未处理截图重复套壳
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

static WeToast *gBusyToast = nil; // 进行中的 loading 提示（套壳 / 导出），完成后收起

// 连拍互斥：同一时刻只处理一张，处理中到达的截屏事件直接丢弃
static dispatch_queue_t gShellQueue = nil;
static BOOL gShellBusy = NO;

static WeToast *DD_Toast(void) {
    return [NSClassFromString(@"WeToast") toast];
}

// loading / 成功 / 失败 / 纯文字四种提示，都用微信的 WeToast
// 开始 loading，实例存下来给后面收起用
static void DD_ShowLoading(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WeToast *toast = DD_Toast();
        [toast setLoadingStyle:YES];
        [toast showToastWithText:text];
        gBusyToast = toast;
    });
}
// 收起 loading：调用方都在主线程
static void DD_HideLoading(void) {
    [gBusyToast hideWithAnimated:YES];
    gBusyToast = nil;
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
        if (!gShellQueue) gShellQueue = dispatch_queue_create("com.ddshell.shell", DISPATCH_QUEUE_SERIAL);
        dispatch_async(gShellQueue, ^{
            if (gShellBusy) return; // 已有任务在跑，本次丢弃
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
                    DD_ShowError(err.localizedDescription.length ? err.localizedDescription : @"保存到相册失败");
                }
                completion();
            });
        }];
    });
}

@end

#pragma mark - 导入导出

// 只用来给这两个类方法提供 selector 声明：objc_getClass() 的返回值是 Class 类型的
// 接收者，clang 要见到同名 selector 的声明才放行。类名本身不参与，实际取的是微信里的
// QSSZipArchive，编译期不产生链接符号。别当死代码删。
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

// 分组底色：取设置页 tableView 的底色，两页同源，微信换主题时一起变
static UIColor *DD_GroupBackgroundColor = nil;

// 导航栏底边：全屏布局下就是 view.safeAreaInsets.top（状态栏 + 导航栏）
static CGFloat DD_TopUnderNavBar(UIView *view) {
    return view.safeAreaInsets.top;
}

// 导航栏外观不碰：8.0.79 由 WCCustomNavigationBar / WCCustomNavigationBarCoordinator
// 自己实现整套导航栏（背景、标题、返回箭头、转场渲染），不走 UIKit 的 UINavigationBarAppearance。

// 独立的素材库页面：
//   双排网格列出模板，右上角常驻 导出 / 导入（导入最靠右），默认按名称排序；
//   点「导出」用微信原生 WCActionSheet 弹「选择导出方式」：选择导出 / 全部导出（取消自带）；
//   「选择导出」进入选择态，右上角换成 删除 / 导出 / 取消；
//   单点一个模板弹 WCActionSheet「套壳操作」：使用模板 / 重命名 / 选择/多选 / 删除此模板，
//   选「选择/多选」同样进选择态。
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

    // 普通态：弹出模板操作菜单，取消按钮 WCActionSheet 自带
    self.tappedTpl = n;
    [self showWCActionSheet:@"套壳操作" tag:DD_SHEET_TPL items:@[@"使用模板", @"重命名", @"选择/多选", @"删除此模板"]];
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

// 进入选择态：勾选清空，右上角换成 删除 / 导出 / 取消
- (void)enterExportSelectMode {
    self.isSelectMode = YES;
    [self.picked removeAllObjects];
    [self setupNavigationBar];
    [self updateTitle];
    [self.collectionView reloadData];
}

// 从「套壳操作 → 选择/多选」进入：顺手把那一个勾上
- (void)enterExportSelectModeWithName:(NSString *)name {
    [self enterExportSelectMode];
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
}

// 选择态点右上角「删除」：先确认再删
- (void)deleteSelectedFrames {
    NSArray *names = [self.picked.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [self confirmDeleteNames:names];
}

// 删除确认，单个和批量共用
- (void)confirmDeleteNames:(NSArray<NSString *> *)names {
    NSString *msg = names.count == 1
        ? [NSString stringWithFormat:@"已选：「%@」", names.firstObject]
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
            if (!n) DD_ShowToast(@"没有找到可导入的模板"); // 导入成功靠列表多出来的格子反馈
            [self reloadList];
        });
    });
}

- (void)documentPickerWasCancelled:(id)controller { }

@end

#pragma mark - 设置界面

// 微信私有的 push（大写 P）：只有走它，Coordinator 才会接管返回箭头。
// 头文件 dump 里没有，真机存在。
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

// 从相册挑选一张图，套入当前模板后存回相册（不删除所选原图）
- (void)pickFromAlbumTapped:(id)sender {
    if (!DD_TemplateNamed(DD_ActiveTemplateName())) { DD_ShowToast(@"模板未选择"); return; }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
}

// 从相册挑选一段视频，套入当前模板后导出存回相册（不删除所选原视频）
- (void)pickVideoFromAlbumTapped:(id)sender {
    if (!DD_TemplateNamed(DD_ActiveTemplateName())) { DD_ShowToast(@"模板未选择"); return; }
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[ @"public.movie" ];   // 只挑视频
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:picker animated:YES completion:nil];
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
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!t) { DD_ShowError(@"套壳失败"); return; } // 选图期间模板可能已经被删了
    // 合成要开全尺寸画布，丢后台跑，主线程留着转 loading
    DD_ShowLoading(@"正在套壳");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *outImg = DD_ComposeShellImage(img, t);
        if (!outImg) { DD_ShowError(@"套壳失败"); return; }
        // 相册选图套壳不删除原图；成功提示必须等相册真正存好再弹，避免存失败也报成功
        DD_SaveImageToAlbum(outImg, ^(BOOL success, NSError *err) {
            if (success) {
                DD_ShowShellDone();
            } else {
                DD_ShowError(err.localizedDescription.length ? err.localizedDescription : @"保存到相册失败");
            }
        });
    });
}

// 相册选视频套壳：逐帧透视合成后导出 mp4，存回相册
- (void)handlePickedVideo:(NSDictionary *)info {
    NSURL *url = info[UIImagePickerControllerMediaURL];
    DDShellTemplate *t = DD_TemplateNamed(DD_ActiveTemplateName());
    if (!url || !t) { DD_ShowError(@"套壳失败"); return; } // 选视频期间模板可能已经被删了
    // 逐帧合成 + 导出是重活，丢后台跑，主线程留着转 loading
    DD_ShowLoading(@"正在套壳");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *outURL = DD_ComposeShellVideo(url, t);
        if (!outURL) { DD_ShowError(@"套壳失败"); return; }
        // 相册选视频套壳不删除原视频；成功提示必须等相册真正存好再弹，避免存失败也报成功
        DD_SaveVideoToAlbum(outURL, ^(BOOL success, NSError *err) {
            if (success) {
                DD_ShowShellDone();
            } else {
                DD_ShowError(err.localizedDescription.length ? err.localizedDescription : @"保存到相册失败");
            }
        });
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

        // 清理上次会话（崩溃/强退/被杀）残留的临时文件；任务中途被杀时 in-flow 清理来不及跑，靠这里兜底
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

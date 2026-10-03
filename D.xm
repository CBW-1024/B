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

#pragma mark - 调试日志

#include <stdarg.h>
// 调试日志写进文件（非越狱设备看不到 NSLog，靠导出日志文件定位问题）。
// 位置放在 DDShell 数据目录（Library/Preferences/DDShell/），不会被 %ctor 清临时目录误删。
static NSString *DD_LogPath(void) {
    NSString *base = [DD_TplDir() stringByDeletingLastPathComponent]; // .../DDShell
    return [base stringByAppendingPathComponent:@"ddshell_debug.log"];
}

static void DD_Log(NSString *fmt, ...) {
    if (!fmt) return;
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("ddshell.log", DISPATCH_QUEUE_SERIAL); });
    dispatch_sync(q, ^{
        NSString *path = DD_LogPath();
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:path]) {
            NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
            if (attr && [attr[NSFileSize] unsignedLongLongValue] > 2ULL * 1024 * 1024) {
                [fm removeItemAtPath:path error:nil];
            }
        }
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) { [fm createFileAtPath:path contents:data attributes:nil]; return; }
        @try { [fh seekToEndOfFile]; [fh writeData:data]; }
        @catch (NSException *e) {}
        [fh closeFile];
    });
}

#pragma mark - 崩溃捕获（写入日志文件，可导出查看）

#include <signal.h>
#include <execinfo.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>

// 崩溃日志路径缓存成 C 字符串：信号处理函数里不能安全调用 ObjC/dispatch，
// 必须用具异步信号安全的 open/write/close 直接落盘。
static char gDDLogPathC[1024] = {0};

static void DD_CrashAppend(const char *text) {
    if (!text || !*text || gDDLogPathC[0] == '\0') return;
    int fd = open(gDDLogPathC, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    size_t len = strlen(text);
    write(fd, text, len);
    write(fd, "\n", 1);
    close(fd);
}

static void DD_SignalHandler(int sig) {
    const char *name = "?";
    if (sig == SIGSEGV) name = "SIGSEGV 段错误/野指针";
    else if (sig == SIGBUS) name = "SIGBUS 总线错误/对齐";
    else if (sig == SIGABRT) name = "SIGABRT abort";
    else if (sig == SIGILL) name = "SIGILL 非法指令";
    else if (sig == SIGTRAP) name = "SIGTRAP";
    else if (sig == SIGFPE) name = "SIGFPE 浮点异常";
    char hdr[256];
    snprintf(hdr, sizeof(hdr), "[CRASH] signal %s (%d) epoch=%ld", name, sig, (long)time(NULL));
    DD_CrashAppend(hdr);
    void *frames[64];
    int n = backtrace(frames, 64);
    char **syms = backtrace_symbols(frames, n);
    if (syms) {
        for (int i = 0; i < n; i++) {
            char line[1024];
            snprintf(line, sizeof(line), "  %s", syms[i]);
            DD_CrashAppend(line);
        }
        free(syms);
    }
    // 还原默认处理并重新触发，让系统仍生成标准崩溃报告
    signal(sig, SIG_DFL);
    raise(sig);
}

static void DD_UncaughtExceptionHandler(NSException *e) {
    NSMutableString *s = [NSMutableString stringWithFormat:
        @"[CRASH] uncaught exception: %@\nreason: %@\n", e.name, e.reason];
    for (NSString *sym in e.callStackSymbols) [s appendFormat:@"  %@\n", sym];
    DD_CrashAppend(s.UTF8String);
}

static void DD_InstallCrashHandlers(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *p = DD_LogPath();
        if (p) strncpy(gDDLogPathC, p.fileSystemRepresentation, sizeof(gDDLogPathC) - 1);
        NSSetUncaughtExceptionHandler(DD_UncaughtExceptionHandler);
        int sigs[] = { SIGABRT, SIGBUS, SIGSEGV, SIGILL, SIGTRAP, SIGFPE };
        for (size_t i = 0; i < sizeof(sigs)/sizeof(sigs[0]); i++)
            signal(sigs[i], DD_SignalHandler);
        // 内存压力日志。注意区分两档：WARN 是最低档（系统内存偏紧，正常导出也可能触发），
        // CRITICAL 才是 jetsam(SIGKILL) 前兆（无法捕获）。实测各档（直至 3200+Highest）
        // 只打 WARN、从未 CRITICAL，且每次导出都成功——WARN 属可接受的轻度告警。
        // CRITICAL，且每次导出都成功——WARN 属可接受的轻度告警，不必按"即将被杀"处理。
        dispatch_source_t ps = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
            DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
            dispatch_get_main_queue());
        dispatch_source_set_event_handler(ps, ^{
            unsigned lvl = (unsigned)dispatch_source_get_data(ps);
            BOOL critical = (lvl & DISPATCH_MEMORYPRESSURE_CRITICAL) != 0;
            DD_Log(@"[内存压力] %@ —— %@", critical ? @"CRITICAL" : @"WARN",
                   critical ? @"jetsam(SIGKILL) 前兆，进程随时可能被杀且无法捕获"
                            : @"轻度告警（最低档），高码率编码期常见，通常不影响导出");
        });
        dispatch_resume(ps);
    });
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

// 窗口四角双线性插值：u 从左到右、v 从上到下，取值 0~1（对带透视畸变的梯形窗同样适用）
static CGPoint DD_QuadLerp(DDShellTemplate *t, CGFloat u, CGFloat v) {
    CGFloat tx = t.lt.x + (t.rt.x - t.lt.x) * u, ty = t.lt.y + (t.rt.y - t.lt.y) * u; // 上边
    CGFloat bx = t.lb.x + (t.rb.x - t.lb.x) * u, by = t.lb.y + (t.rb.y - t.lb.y) * u; // 下边
    return CGPointMake(tx + (bx - tx) * v, ty + (by - ty) * v);
}

// 源内容【真正该占据的子四边形】，返回等比缩放比 sc，四角写入 q[0..3]（lt/rt/rb/lb 顺序）。
// 【根因】透视是把源矩形"拉伸填满"四角：contain 只保证缩放等比、不保证映射不变形，contain
// 留出的空白不是留白而是被拉满。窗口是 312×640（1:2.05）的瘦长条，源比例差得越多越离谱：
//     竖屏截图 1:2.16 → 只差 5%，拉伸无感，直接填满
//     横屏 4:3 直接放 → 纵向 ×2.74（用户反馈的"被拉升"）
//     横屏 4:3 旋转后 1:1.33 → 仍差 54%，光旋转治不了
// 【做法】先算源等比缩放后在窗口里的占比，再把四角向内收缩到那个子区域、居中放置。
// 【容差 kTol】占比 >= 0.85 视为差异可忽略、继续填满——竖屏截图占 94.9%，走填满，行为与
// 改动前完全一致；横屏 16:9 旋转后占 86.6%，也填满（残留 15% 肉眼看不出）；横屏 4:3
// 旋转后只占 65%，超出容差 → 居中，零变形，上下露出模板屏幕底色。
static CGFloat DD_FitQuad(DDShellTemplate *t, CGFloat srcW, CGFloat srcH, CGPoint q[4]) {
    CGRect wb = DD_WindowBBox(t);
    CGFloat sc = MIN(wb.size.width / srcW, wb.size.height / srcH);
    if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
    CGFloat fw = (wb.size.width  > 0) ? (srcW * sc) / wb.size.width  : 1.0;
    CGFloat fh = (wb.size.height > 0) ? (srcH * sc) / wb.size.height : 1.0;
    if (fw > 1.0) fw = 1.0;
    if (fh > 1.0) fh = 1.0;
    static const CGFloat kTol = 0.85;
    if (fw >= kTol) fw = 1.0;
    if (fh >= kTol) fh = 1.0;
    CGFloat u0 = (1.0 - fw) / 2.0, u1 = u0 + fw;
    CGFloat v0 = (1.0 - fh) / 2.0, v1 = v0 + fh;
    q[0] = DD_QuadLerp(t, u0, v0);   // 左上
    q[1] = DD_QuadLerp(t, u1, v0);   // 右上
    q[2] = DD_QuadLerp(t, u1, v1);   // 右下
    q[3] = DD_QuadLerp(t, u0, v1);   // 左下
    return sc;
}

static UIImage *DD_ComposeShellImage(UIImage *shot, DDShellTemplate *t) {
    if (!shot || !t) return nil;
    UIImage *frameImg = t.image;
    CGImageRef frameCG = frameImg.CGImage;
    CGImageRef shotCG = shot.CGImage;
    if (!frameCG || !shotCG) return nil;

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    // 尺寸取自 cfg，按 CoreGraphics 的纹理上限卡一道，超了就放弃这次合成。
    // （曾试过【整体放大画布】做超采样来提升"被套的图"的清晰度：画布与四角同比放大，窗口
    //  跟着变大、被套图像素量随倍率平方增长——1.5× 时被套图 296×640→444×961。但代价是机身
    //  PNG 从 1:1 无损变成被放大、内存与成品体积同步平方增长，而各模板窗口占比差异很大
    //  （本例窗口仅占画布宽 11%），收益不稳定、复杂度不划算，已回退为直接用 cfg 尺寸。）
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil;

    // 截图按实际像素尺寸参与计算
    CGFloat A = (CGFloat)CGImageGetWidth(shotCG);
    CGFloat B = (CGFloat)CGImageGetHeight(shotCG);
    if (A < 1.0 || B < 1.0) return nil;

    // 画布按 1 倍开（1 单位 = 1 像素），成品尺寸才严格等于 cfg 写的模板尺寸
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(W, H), NO, 1.0);
    // 透视结果的 extent 未必是整数（四角来自 cfg，可能带小数），drawInRect 落地时会发生
    // 非整数倍的二次重采样。显式开最高质量插值，免得这最后一公里被默认的中等插值抹糊。
    CGContextRef uctx = UIGraphicsGetCurrentContext();
    if (uctx) CGContextSetInterpolationQuality(uctx, kCGInterpolationHigh);

    CIContext *ci = [CIContext contextWithOptions:@{ kCIContextUseSoftwareRenderer : @NO }];

    // 横屏源：旋转 90° 后再往竖屏窗口里放（用户诉求：横屏拍的会被纵向拉升）。这里只需要
    // 先定下旋转后的尺寸去参与 contain 计算，真正的旋转放到缩放【之后】做——避免 Core Image
    // 把"旋转 + 缩放"合并优化、让 Lanczos 退化成仿射采样（波纹会回来）。
    // 旋转方向取 M_PI_2；若躺倒方向不合预期，改成 -M_PI_2 即可。
    CGFloat SA = A, SB = B;
    BOOL rotated = (A > B);
    if (rotated) { SA = B; SB = A; }   // 旋转 90° 后宽高互换

    // 源先按 contain 预缩到屏幕窗尺寸，再做透视映射——避免把大分辨率直接喂进透视导致
    // 中间图过大、投影退化（ZDY 即先预缩放再透视）。
    // 缩小这一步必须用 Lanczos：截图到窗口是 4× 量级的缩小（实测 1242px 源 → 296px，
    // 仅剩 23.8%），仿射双线性的抗混叠不足，文字/列表分割线/图标细边会出摩尔纹与发虚
    // ——与视频链曾经"套入视频有波纹"完全同源（那里改 Lanczos 后消失）。放大(sc>=1)
    // 不产生混叠，仍走仿射即可。
    CGRect wb = DD_WindowBBox(t);
    CGPoint q[4];
    CGFloat sc = DD_FitQuad(t, SA, SB, q);
    // 诊断：窗口物理尺寸 = 被套图的清晰度硬上限（各模板窗口占比差异很大，本例仅占画布宽
    // 11%）；PNG 比画布小说明机身在被放大，比画布大则说明 cfg 写小了、浪费了真实像素。
    BOOL centered = (fabs(q[0].x - t.lt.x) > 0.5) || (fabs(q[0].y - t.lt.y) > 0.5);
    DD_Log(@"[图片套壳] name=%@ 画布=(%.0fx%.0f) PNG=(%.0fx%.0f) 窗口=(%.1fx%.1f) 源=(%.0fx%.0f)%@ sc=%.4f 被套图=(%.0fx%.0f) 放置=%@",
           t.name, W, H,
           (CGFloat)CGImageGetWidth(frameCG), (CGFloat)CGImageGetHeight(frameCG),
           wb.size.width, wb.size.height, A, B, rotated ? @"[已旋转90°]" : @"", sc,
           SA * sc, SB * sc, centered ? @"等比居中" : @"填满");
    CIImage *srcImg = nil;
    if (sc < 1.0) {
        CIFilter *lz = [CIFilter filterWithName:@"CILanczosScaleTransform"];
        if (lz) {
            [lz setDefaults];
            [lz setValue:[CIImage imageWithCGImage:shotCG] forKey:kCIInputImageKey];
            [lz setValue:@(sc) forKey:kCIInputScaleKey];
            srcImg = lz.outputImage;
        }
    }
    if (!srcImg) srcImg = [[CIImage imageWithCGImage:shotCG] imageByApplyingTransform:CGAffineTransformMakeScale(sc, sc)];
    if (rotated) {
        CIImage *r = [srcImg imageByApplyingTransform:CGAffineTransformMakeRotation((CGFloat)M_PI_2)];
        CGRect re = r.extent;
        // 旋转后 extent 原点会偏移（常为负），平移归零，透视才能按 (0,0,SA*sc,SB*sc) 取 extent
        srcImg = [r imageByApplyingTransform:CGAffineTransformMakeTranslation(-re.origin.x, -re.origin.y)];
    }
    CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
    [f setDefaults];
    [f setValue:srcImg forKey:kCIInputImageKey];
    [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, SA * sc, SB * sc)] forKey:@"inputExtent"];
    [f setValue:DD_CIVec(q[0], H) forKey:@"inputTopLeft"];
    [f setValue:DD_CIVec(q[1], H) forKey:@"inputTopRight"];
    [f setValue:DD_CIVec(q[2], H) forKey:@"inputBottomRight"];
    [f setValue:DD_CIVec(q[3], H) forKey:@"inputBottomLeft"];
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
@property (nonatomic)         BOOL                firstFrameLogged;
@property (nonatomic)         NSInteger           frameCount;
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
    CVPixelBufferRef _mid;   // 复用的满画布 8bit 中间缓冲：先把透视结果“烘焙”成位图，
                            // 再与机身前景合成。对齐 WCRefine 的 bake→composite 流程
                            // （它从不让渲染器直接合成“滤镜图”，而是先烘焙）；由框架复用的
                            // 同一合成器实例持有、dealloc 释放，逐帧零分配，内存打平防 jetsam。
    CGSize           _midSize;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cs  = CGColorSpaceCreateDeviceRGB();
        // 走 GPU 渲染（默认，不强制软件渲染）。软件渲染器会把 CIPerspectiveTransform
        // 滤镜输出渲空——表现为“有声音、模板在、视频没进模版”（模板来自静态 CGImage 能正常
        // 渲，唯独 warped 那层空）。经反汇编 WCRefine 确认其合成路径是“先烘焙 warped 到满
        // 画布 IOSurface 中间缓冲、再读回位图与前景合成”，且 GPU 路径原本就能正确渲出 warped。
        // 为防宽色域/P3 源把 Core Image 推到 float 扩展范围缓冲（内存翻倍），钉死 working/
        // output 为 sRGB；中间缓冲 _mid 复用单张满画布 IOSurface、不逐帧分配，内存打平。
        _ctx = [CIContext contextWithOptions:@{ (id)kCIContextWorkingColorSpace : (__bridge id)_cs,
                                                (id)kCIContextOutputColorSpace  : (__bridge id)_cs,
                                                // 不缓存中间结果：防止逐帧渲染循环里 GPU 显存随
                                                // 帧数累积（大分辨率长视频下会显著推高内存峰值）。
                                                (id)kCIContextCacheIntermediates : @NO }];
    }
    return self;
}
- (void)dealloc {
    if (_cs) CGColorSpaceRelease(_cs);
    if (_mid) CVPixelBufferRelease(_mid);   // 合成器实例常被框架复用，析构时回收中间缓冲
}
// 渲染上下文变化（尺寸/像素格式等），本合成器每帧直接从 request 取 renderContext，无需缓存
- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {}
- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    // 对齐 WCRefine：目标缓冲同样 BGRA + IOSurface + OpenGLES（与 source 对称）。
    // IOSurface 让渲染目标常驻 GPU 显存、CI 渲染零拷贝，规避“逐帧 CPU 缓冲”的内存与
    // 拷贝开销——这正是 WCR 在导出链路里既快又不崩的底层原因之一。
    return @{ (id)kCVPixelBufferPixelFormatTypeKey        : @(kCVPixelFormatType_32BGRA),
              (id)kCVPixelBufferIOSurfacePropertiesKey    : @{},
              (id)kCVPixelBufferOpenGLESCompatibilityKey  : @YES };
}
- (NSDictionary *)sourcePixelBufferAttributes {
    // 源帧格式：420YUV（420 YpCbCr 8-bit BiPlanar VideoRange）而非对齐 WCR 的 BGRA。
    // 理由：H.264/H.265 解码器原生输出就是 YUV，写 BGRA 会让系统额外做“解码→BGRA 转换”
    // 且每帧多占 ~2.6× 内存（5.3MB→2MB/帧 @1036×1280）；写 420YUV 则零转换、源解码内存
    // 直接砍到最低。Core Image 的 imageWithCVPixelBuffer: 对标准 420YUV 会自动转 RGB，
    // 合成逻辑无需改动；输出缓冲（required）仍是 BGRA+IOSurface（编码器需要，不可动）。
    // 这是“降分辨率/对齐 WCR 仍中段停摆”之后的减负改动：源解码是导出链路里我们能砍的
    // 最大一块内存。事后实测证明它才是根治——同一 1036 宽源从 BGRA 的 44s 中段停摆变为
    // 7s 匀速无停摆（此前误判为“仅小幅缓解”，实为完全消除）。
    // （备注：曾提议换 Photo Editing 扩展拿高内存预算作治本，后经日志证实本就跑在微信
    //  主进程、内存充裕，该方案已废弃，代码未保留。）
    // 必须含 kCVPixelBufferPixelFormatTypeKey（否则 AVFCore 直接抛 NSInvalidArgumentException）；
    // IOSurface 让源帧常驻 GPU 显存、与 CI 渲染零拷贝。
    return @{ (id)kCVPixelBufferPixelFormatTypeKey        : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
              (id)kCVPixelBufferIOSurfacePropertiesKey    : @{},
              (id)kCVPixelBufferOpenGLESCompatibilityKey  : @YES };
}
- (void)cancelAllPendingVideoCompositionRequests {
    self.shouldCancelAllRequests = YES;
}
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)req {
    if (self.shouldCancelAllRequests) {
        // 框架会在每次导出结束/释放时调用 cancelAllPendingVideoCompositionRequests
        // 把本标志置 YES，且倾向于复用同一合成器实例；若不在此复位，后续所有导出都会
        // 在入口被 finishCancelledRequest 早退、一帧不画，导致“空白视频”。
        self.shouldCancelAllRequests = NO;
        [req finishCancelledRequest];
        return;
    }
    // 注意：AVAssetExportSession 的自定义合成器必须同步完成（start 返回前调用
    // finish*），否则延迟到自建队列提交的帧不会被导出管线泵送，最终导出“成功”
    // 但画面全黑（空白视频）。AVPlayerItem 播放链路才支持真正的异步合成。
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
        if (!src) { DD_Log(@"[Compositor] 取源帧失败 tid=%d", tid); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-1 userInfo:nil]]; return; }

        CVPixelBufferRef dst = [req.renderContext newPixelBuffer];
        if (!dst) { DD_Log(@"[Compositor] 取目标缓冲失败"); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-2 userInfo:nil]]; return; }

        // 源帧先按视频自带旋转摆正；preferredTransform 常带位移把旋转后的帧挪回正位，
        // 其 extent 原点往往不为 0。先把原点归零再按 contain 预缩到屏幕窗尺寸，最后透视
        // 映射到窗口——避免把巨大坐标 / 大分辨率直接喂进透视导致中间图过大、投影退化，
        // 导出失败或相册拒收（ZDY 即先预缩放再透视）。
        CIImage *raw = [CIImage imageWithCVPixelBuffer:src];
        CIImage *rot = [raw imageByApplyingTransform:inst.preferredTransform];
        CGRect re = rot.extent;
        CGFloat sc = MIN(wb.size.width / re.size.width, wb.size.height / re.size.height);
        if (!(sc > 0.0) || !isfinite(sc)) sc = 1.0;
        // 先平移归零（仅移 origin，不改采样），再用 Lanczos 高质量缩小——相比仿射双线性，
        // Lanczos 抗混叠更好，可显著减轻套入视频细密纹理缩小后产生的摩尔纹/波纹。
        // 仅缩小时走 Lanczos；放大（sc>=1）不产生混叠，双线性即可。
        CIImage *centered = [rot imageByApplyingTransform:CGAffineTransformMakeTranslation(-re.origin.x, -re.origin.y)];
        CIImage *srcImg = nil;
        if (sc < 1.0) {
            CIFilter *lz = [CIFilter filterWithName:@"CILanczosScaleTransform"];
            if (lz) {
                [lz setDefaults];
                [lz setValue:centered forKey:kCIInputImageKey];
                [lz setValue:@(sc) forKey:kCIInputScaleKey];
                srcImg = lz.outputImage;
            }
        }
        if (!srcImg) srcImg = [centered imageByApplyingTransform:CGAffineTransformMakeScale(sc, sc)];
        inst.frameCount++;
        if (!inst.firstFrameLogged) {
            inst.firstFrameLogged = YES;
            DD_Log(@"[Compositor] 首帧 srcExtent=(%.0f x %.0f) sc=%.4f renderSize=(%.0f x %.0f) tid=%d",
                   re.size.width, re.size.height, sc, W, H, tid);
        } else if (inst.frameCount % 30 == 0) {
            CFStringRef d = CMTimeCopyDescription(NULL, req.compositionTime);
            DD_Log(@"[Compositor] 进度 #%ld t=%@", (long)inst.frameCount, d ? CFBridgingRelease(d) : @"?");
        }

        CIFilter *f = [CIFilter filterWithName:@"CIPerspectiveTransformWithExtent"];
        if (!f) { DD_Log(@"[Compositor] 透视滤镜不可用"); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-3 userInfo:nil]]; CVPixelBufferRelease(dst); return; }
        [f setDefaults];
        [f setValue:srcImg forKey:kCIInputImageKey];
        [f setValue:[CIVector vectorWithCGRect:CGRectMake(0, 0, re.size.width * sc, re.size.height * sc)] forKey:@"inputExtent"];
        [f setValue:DD_CIVec(t.lt, H) forKey:@"inputTopLeft"];
        [f setValue:DD_CIVec(t.rt, H) forKey:@"inputTopRight"];
        [f setValue:DD_CIVec(t.rb, H) forKey:@"inputBottomRight"];
        [f setValue:DD_CIVec(t.lb, H) forKey:@"inputBottomLeft"];
        CIImage *warped = f.outputImage;
        if (!warped) { DD_Log(@"[Compositor] 透视结果为空 extent=(%.0f x %.0f)", re.size.width*sc, re.size.height*sc); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-4 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        // 对齐 WCRefine 的 bake→composite 流程（已反汇编 0x1137770 / 0x1137db4 确认）：
        // ① 先把透视滤镜结果“烘焙”进一张满画布 8bit IOSurface 中间缓冲 _mid（复用、不逐帧
        //    分配）；GPU 渲染能正确写入并读回，软件渲染器则会把滤镜输出渲空。
        // ② 把 _mid 读回成普通位图 warpedBaked（已是 8bit sRGB，几何位置同画布），再与机身
        //    前景 frame 合成。先烘焙再合成，避免直接把“滤镜图+位图”的图交给渲染器合成
        //    （软件渲染下会渲空，正是之前“视频没进模版”的根因）。
        if (!_mid || (size_t)_midSize.width != (size_t)W || (size_t)_midSize.height != (size_t)H) {
            if (_mid) { CVPixelBufferRelease(_mid); _mid = NULL; }
            CVReturn cvr = CVPixelBufferCreate(kCFAllocatorDefault,
                             (size_t)W, (size_t)H,
                             kCVPixelFormatType_32BGRA,
                             (__bridge CFDictionaryRef)@{ (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                                          (id)kCVPixelBufferOpenGLESCompatibilityKey : @YES },
                             &_mid);
            if (cvr != kCVReturnSuccess || !_mid) {
                DD_Log(@"[Compositor] 中间缓冲创建失败 cvr=%d", cvr);
                [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-7 userInfo:nil]];
                CVPixelBufferRelease(dst); return;
            }
            _midSize = CGSizeMake(W, H);
            DD_Log(@"[Compositor] 中间缓冲 (%d x %d) 重建（满画布，复用）", (int)W, (int)H);
        }

        @try {
            [_ctx render:warped toCVPixelBuffer:_mid bounds:CGRectMake(0, 0, W, H) colorSpace:_cs];
        } @catch (NSException *e) {
            DD_Log(@"[Compositor] 透视烘焙抛异常 #%ld : %@", (long)inst.frameCount, e);
            [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-8 userInfo:@{NSLocalizedDescriptionKey:e.reason}]];
            CVPixelBufferRelease(dst); return;
        }
        CIImage *warpedBaked = [CIImage imageWithCVPixelBuffer:_mid]; // 已是 8bit sRGB，几何同画布
        if (!warpedBaked) { DD_Log(@"[Compositor] 烘焙图读回为空"); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-9 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        CIImage *frame = [CIImage imageWithCGImage:t.image.CGImage];
        CIImage *outImg = [frame imageByCompositingOverImage:warpedBaked]; // 机身图盖在最上层（与预览同序）
        if (!outImg) { DD_Log(@"[Compositor] 合成结果为空"); [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-5 userInfo:nil]]; CVPixelBufferRelease(dst); return; }

        @try {
            [_ctx render:outImg toCVPixelBuffer:dst bounds:CGRectMake(0, 0, W, H) colorSpace:_cs];
        } @catch (NSException *e) {
            DD_Log(@"[Compositor] render 抛异常 #%ld ext=(%.0f x %.0f) sc=%.4f : %@",
                   (long)inst.frameCount, W, H, sc, e);
            [req finishWithError:[NSError errorWithDomain:@"DDShell" code:-6 userInfo:@{NSLocalizedDescriptionKey:e.reason}]];
            CVPixelBufferRelease(dst);
            return;
        }

        // 注意：iOS 的 CIContext 没有 reclaimResources（该方法仅 macOS 可用，
        // CIContext.h 标注 NS_AVAILABLE_MAC(10_4)，编译期即 unavailable on iOS），不能调用。
        // iOS 端改用 init 里的 kCIContextCacheIntermediates:@NO 来斩断逐帧显存累积——
        // 它让 CI 不缓存中间纹理、每帧渲染后即回收，等价于“每帧 reclaim”。本 tweak 跑在
        // 微信主进程（内存远宽于扩展），但 3200 档 7.57MP 画布下显存累积仍可观，保留此设置。
        [req finishWithComposedVideoFrame:dst];
        CVPixelBufferRelease(dst);
    }
}
@end

// 把一段视频逐帧套壳后导出成 mp4，返回临时文件 URL（失败返回 nil）
static NSURL *DD_ComposeShellVideo(NSURL *srcURL, DDShellTemplate *t) {
    AVURLAsset *asset = [AVURLAsset assetWithURL:srcURL];
    AVAssetTrack *vt = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!vt) { DD_Log(@"[Compose] 无视频轨"); return nil; }
    DD_Log(@"[Compose] 视频轨 naturalSize=(%.0f x %.0f) fps=%.2f transform=%@",
           vt.naturalSize.width, vt.naturalSize.height, vt.nominalFrameRate,
           NSStringFromCGAffineTransform(vt.preferredTransform));

    CGFloat W = t.canvasSize.width, H = t.canvasSize.height;
    if (W < 1.0 || H < 1.0 || W > 8192.0 || H > 8192.0) return nil; // 画布尺寸同样卡上限

    // ── 工作分辨率上限（长边 DD_WORK_CAP）────────────────────────────────
    // 【硬天花板】相册 4K 像素 8,294,400：超过即 3302 存不进相册。画布原始 2840×3840
    // =10.9MP 是上限的 131%，故"用原始分辨率"不可行。本算法 s=C/3840（高度恒为长边约束），
    // C=3348 时正好 8.29MP 触顶；C=3200 用掉 91%（余量 9%），C=2160 用掉 41.6%。
    // 【当前默认 3200】输出约 2366×3200（7.57MP）。实测（944 宽源 / 16s 视频）：主进程，
    // 全程 #30→#480 匀速无停摆，2 次 [内存压力] WARN（均最低档、非 CRITICAL），约 27s
    // 导出成功、存相册 success=1（无 3302）。再上探到 3348 仅多 +12px 视频窗宽
    // （260→272px），却要贴 4K 硬线，收益/风险不划算，故定为最终档。
    // 【历史教训·勿回退】① 源格式改 420YUV(NV12) 是治"慢"的关键：此前 BGRA 源需每帧
    // NV12→BGRA 转换、源缓冲 2.6×，同一 1036 宽源从 44s 中段停摆变为 7s 匀速无停摆——
    // 停摆主因是【源内存】而非合成分辨率，所以降分辨率治不了停摆（曾实测 720 反而更慢）。
    // ② 曾误判合成跑在分享扩展(appex)（因输入 trim.MOV 落在 PluginKitPlugin 容器），实为
    // 证书注入主二进制 → 只跑在【微信主进程】：输出 mp4 落在 Containers/Data/Application/…，
    // DD_IsExtensionProcess() 恒 NO；trim.MOV 只是系统视频选择器/裁剪插件所写并授权主进程
    // 读取。③ 因此"为避 appex 内存墙而降分辨率"的前提不成立（2160/1440/1280/1080 各档
    // 实测都只 WARN、都成功），故把分辨率提回 3200 拿回清晰度。
    // 【降级链】更长视频/老设备若出现 CRITICAL 或 3302：2880 → 2560 → 2160（2160 已验证稳）。
    // 【模版几何上限】本模版视频框仅占画布宽约 11%，即便顶到 3348 窗口也仅约 272px 宽 ≈
    // 源宽 944px 的 29%——视频到不了源原生清晰度，属模版设计所限，非 tweak 可解。
    static const CGFloat DD_WORK_CAP = 3200.0;
    CGFloat capW = DD_WORK_CAP, capH = DD_WORK_CAP, capPx = DD_WORK_CAP * DD_WORK_CAP;
    CGFloat s = MIN(MIN(1.0, capW / W), MIN(capH / H, sqrt(capPx / (W * H))));
    DDShellTemplate *st = t;
    if (s < 1.0) {
        CGFloat nW = floor((W * s) / 2.0) * 2.0;
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
        DD_Log(@"[Compose] 画布超限，等比缩小 s=%.4f → renderSize=(%.0f x %.0f)", s, W, H);
    } else {
        DD_Log(@"[Compose] 画布 W=%.0f H=%.0f", W, H);
    }

    NSString *outPath = [DD_TempRoot() stringByAppendingPathComponent:
                         [[NSUUID UUID].UUIDString stringByAppendingPathExtension:@"mp4"]];

    AVMutableVideoComposition *vc = [AVMutableVideoComposition videoComposition];
    vc.renderSize = CGSizeMake(W, H);
    CMTime fd = vt.minFrameDuration;
    vc.frameDuration = (fd.timescale && fd.value) ? fd : CMTimeMake(1, 30);
    NSString *ddPreset = AVAssetExportPresetHighestQuality;
    DD_Log(@"[Compose] renderSize=(%.0f x %.0f) frameDuration=%lld/%d preset=%@",
           W, H, (long long)vc.frameDuration.value, vc.frameDuration.timescale, ddPreset);

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
    // 导出质量用 HighestQuality（清晰优先）：AVFoundation 画质预设仅有 Low/Medium/Highest
    // 三档，无中间 "High" 档。Medium 虽零 WARN 但把套入视频压出明显块效应发糊（用户否决）；
    // Highest 的代价只是中段偶发 [内存压力] WARN——已澄清那是 DISPATCH_MEMORYPRESSURE_WARN
    // （最低档，非 CRITICAL 前兆），主进程下实测每次都正常导出，可接受。
    // 波纹已由 CILanczosScaleTransform 独立解决，与编码档无关（回退 Medium 也不会复发）。
    // 若更长视频/老设备真出现 CRITICAL 或 3302，优先降 DD_WORK_CAP（3200→2880→2560→2160），
    // 编码档最后才考虑回 Medium（会发糊）。
    AVAssetExportSession *ex = [[AVAssetExportSession alloc] initWithAsset:asset
                                                            presetName:ddPreset];
    ex.outputURL = [NSURL fileURLWithPath:outPath];
    ex.outputFileType = AVFileTypeMPEG4;
    ex.videoComposition = vc;
    [ex exportAsynchronouslyWithCompletionHandler:^{
        if (ex.status == AVAssetExportSessionStatusCompleted) {
            DD_Log(@"[Compose] 导出成功 outPath=%@", outPath);
            result = ex.outputURL;
        } else {
            DD_Log(@"[Compose] 导出失败 status=%ld error=%@", (long)ex.status, [ex error]);
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    if (!result) { // 导出失败，半截 mp4 回收，避免留在临时目录
        DD_Log(@"[Compose] 导出失败 status=%ld error=%@ outPath=%@",
               (long)ex.status, [ex error], outPath);
        [[NSFileManager defaultManager] removeItemAtPath:outPath error:nil];
    }
    return result;
}

// 视频存相册，存完回调（成功才删临时文件，失败保留以便排查，下次启动会清理）
static void DD_SaveVideoToAlbum(NSURL *url, void (^done)(BOOL success, NSError *err)) {
    [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError *error) {
        DD_Log(@"[存相册] success=%d error=%@ (%@:%ld) url=%@",
               success, error.localizedDescription, error.domain, (long)error.code, url);
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

#pragma mark - 进程识别与视频套壳合成

// 当前 tweak 所在进程是否 App 扩展(appex)。判定依据：扩展的可执行路径/bundle 路径带
// PluginKitPlugin 或 .appex；微信主 App 走 Containers/Data|Bundle/Application，均无这两者。
// 实测（日志佐证）：证书注入主二进制时合成跑在【微信主进程】——输出 mp4 落在
// Containers/Data/Application/.../tmp/DDShell/，而输入 trim.MOV 虽在 PluginKitPlugin
// 容器（系统视频选择器/裁剪插件所写），只是授权给主进程读取，并不代表我们跑在扩展里。
static BOOL DD_IsExtensionProcess(void) {
    NSString *exe = [[NSBundle mainBundle] executablePath] ?: @"";
    NSString *bp  = [[NSBundle mainBundle] bundlePath]    ?: @"";
    return [exe containsString:@"PluginKitPlugin"] || [bp containsString:@".appex"];
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

        [section addCell:[cellCls normalCellForSel:@selector(exportLogTapped:)
                                            target:self title:@"↳导出调试日志"
                                         rightValue:nil]];

        [section addCell:[cellCls normalCellForSel:@selector(clearLogTapped:)
                                            target:self title:@"↳清空调试日志"
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

// 合成并存相册，抽出复用（放在 toast 提示函数之后，DD_ShowError/DD_ShowShellDone 才已声明）
static void DD_ComposeAndSaveVideo(NSURL *url, DDShellTemplate *t) {
    DD_Log(@"[视频套壳] 开始 name=%@ canvas=(%.0f x %.0f) url=%@ 进程=%@ exe=%@",
           t.name, t.canvasSize.width, t.canvasSize.height, url,
           DD_IsExtensionProcess() ? @"扩展(appex)" : @"主进程",
           [[NSBundle mainBundle] executablePath] ?: @"?");
    NSURL *outURL = DD_ComposeShellVideo(url, t);
    if (!outURL) { DD_ShowError(@"套壳失败"); return; }
    DD_SaveVideoToAlbum(outURL, ^(BOOL success, NSError *err) {
        if (success) DD_ShowShellDone();
        else DD_ShowError(err.localizedDescription.length ? err.localizedDescription : @"保存到相册失败");
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
        DD_ComposeAndSaveVideo(url, t);
    });
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 调试日志导出/清空

- (void)exportLogTapped:(id)sender {
    NSString *path = DD_LogPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
    if (!attr || [attr[NSFileSize] unsignedLongLongValue] == 0) {
        DD_ShowToast(@"还没有调试日志");
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                     applicationActivities:nil];
    if ([avc respondsToSelector:@selector(popoverPresentationController)]) {
        avc.popoverPresentationController.sourceView = self.view;
        avc.popoverPresentationController.sourceRect =
            CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height - 60.0, 0, 0);
        avc.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)clearLogTapped:(id)sender {
    [[NSFileManager defaultManager] removeItemAtPath:DD_LogPath() error:nil];
    DD_ShowToast(@"调试日志已清空");
}

@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        (void)[DDShellConfig shared];
        [DDShellWatcher shared]; // 挂载截图监听

        DD_Log(@"[启动] tweak 加载 进程=%@ exe=%@", DD_IsExtensionProcess() ? @"扩展(appex)" : @"主进程",
               [[NSBundle mainBundle] executablePath] ?: @"?");

        // 清理上次会话（崩溃/强退/被杀）残留的临时文件；任务中途被杀时 in-flow 清理来不及跑，靠这里兜底
        NSString *tmpRoot = DD_TempRoot();
        for (NSString *item in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmpRoot error:nil]) {
            [[NSFileManager defaultManager] removeItemAtPath:[tmpRoot stringByAppendingPathComponent:item] error:nil];
        }

        DD_InstallCrashHandlers(); // 崩溃捕获写入日志文件，供设置页导出查看

        // 取不到类时整条链都是给 nil 发消息，ObjC 天然 no-op
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD模板套壳"
                                                  version:@"1.0.0"
                                               controller:@"DDShellSettingsViewController"];
    }
}

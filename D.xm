// ============================================================================
//  DDShell.xm —— 截图模板套壳插件
//
//  功能：截图后自动把截图套入模板，并保存回相册。
//  流程：监听系统截屏通知 → 从相册取最新截图 → 透视贴入模板窗口 → 存回相册。
//  模板：将 name.png 与 name.cfg 一同放入
//        Documents/DDShellTemplates/，两者缺一不可。
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
        _enabled        = [ud objectForKey:kDDShellEnabled]   ? [ud boolForKey:kDDShellEnabled]   : NO;
        _autoShell      = [ud objectForKey:kDDShellAuto]      ? [ud boolForKey:kDDShellAuto]      : YES;
        _deleteOriginal = [ud objectForKey:kDDShellDeleteSrc] ? [ud boolForKey:kDDShellDeleteSrc] : NO;
        _selectedTpl = [ud stringForKey:kDDShellSelectedTpl] ?: @"";
        [ud setBool:_enabled forKey:kDDShellEnabled];
        [ud setBool:_autoShell forKey:kDDShellAuto];
        [ud setBool:_deleteOriginal forKey:kDDShellDeleteSrc];
        [ud setObject:_selectedTpl forKey:kDDShellSelectedTpl];
        [ud synchronize];
    }
    return self;
}

- (void)setEnabled:(BOOL)v        { _enabled = v;        [self dd_setBool:v forKey:kDDShellEnabled]; }
- (void)setAutoShell:(BOOL)v      { _autoShell = v;      [self dd_setBool:v forKey:kDDShellAuto]; }
- (void)setDeleteOriginal:(BOOL)v { _deleteOriginal = v; [self dd_setBool:v forKey:kDDShellDeleteSrc]; }
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

// 已处理过的截图去重，避免重复套壳
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

// 模板目录：Documents/DDShellTemplates/
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

// 按基名 + 扩展名在模板目录里找磁盘上真实存在的文件，扩展名大小写不敏感。
// iOS 文件系统大小写敏感，若直接拼小写扩展名，Foo.PNG / Foo.CFG 会被找不到。
static NSString *DD_ActualFile(NSString *base, NSString *ext) {
    NSString *dir = DD_TplDir();
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] ?: @[];
    NSString *lowerExt = ext.lowercaseString;
    for (NSString *f in files) {
        if (![f.stringByDeletingPathExtension isEqualToString:base]) continue;
        if ([f.pathExtension.lowercaseString isEqualToString:lowerExt]) {
            return [dir stringByAppendingPathComponent:f];
        }
    }
    return nil;
}

// 模板 cfg 路径：与 name.png 同目录、同名、.cfg 扩展名（大小写不敏感）
static NSString *DD_CfgPath(NSString *name) {
    return DD_ActualFile(name, @"cfg");
}

static NSDictionary *DD_LoadCfg(NSString *name) {
    NSData *d = [NSData dataWithContentsOfFile:DD_CfgPath(name)];
    if (!d.length) return nil;
    id obj = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

// 仅保留同时具备 name.png 与 name.cfg 的模板（强制 png+cfg 成对）
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
        if ([cfgs containsObject:b]) [out addObject:b]; // png 与 cfg 必须同时存在
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
    BOOL ok = YES;
    for (NSUInteger i = 0; i < 4; i++) {
        id x = cfg[[keys[i] stringByAppendingString:@"_x"]];
        id y = cfg[[keys[i] stringByAppendingString:@"_y"]];
        if (![x respondsToSelector:@selector(doubleValue)] || ![y respondsToSelector:@selector(doubleValue)]) { ok = NO; break; }
        pts[i] = CGPointMake([x doubleValue], [y doubleValue]);
    }
    if (!ok) return nil; // 四角坐标缺失则模板不生效

    t.canvasSize = canvas; // 画布尺寸
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

// 微信原生提示：开始 loading / 收起 loading / 成功（运行时取 WeToast 类）
static void DD_ShowShelling(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"WeToast");
        WeToast *toast = [cls toast];
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
        Class cls = NSClassFromString(@"WeToast");
        [[cls toast] showDoneToastWithText:@"套壳成功"];
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

#pragma mark - 设置界面

@interface DDShellSettingsViewController : UIViewController <UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic) BOOL tplExpanded;
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
    self.tableViewMgr.delegate = self; // 让 willDisplayCell 回调到本 VC（绘制勾选标记）
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

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    WCTableViewCellManager *cellInfo = (WCTableViewCellManager *)[self.tableViewMgr cellInfoAtIndexPath:indexPath];
    if (cellInfo && [cellInfo.userInfo isKindOfClass:[NSString class]]) {
        NSString *t = cellInfo.userInfo;
        cell.accessoryType = [t isEqualToString:DD_ActiveTemplateName()] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
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

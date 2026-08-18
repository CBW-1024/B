// DD后台高斯模糊 —— 微信后台高斯模糊（隐私防窥屏）
// 版本：1.0.0
//
// 功能：微信切入后台时，在窗口上盖一层高斯模糊遮罩，防止他人窥屏；
//       回到前台自动移除。设置界面仅一个开关，默认不延迟、不透明。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
+ (id)sectionInfoHeader:(NSString *)header;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
@end

@interface MicroMessengerAppDelegate : NSObject <UIApplicationDelegate>
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillEnterForeground:(UIApplication *)application;
- (void)applicationWillTerminate:(UIApplication *)application;
@end

#pragma mark - 配置

static NSString * const kDDBlurConfigKey   = @"DDBlurConfig";
static NSString * const kDDBlurEnableBlur  = @"enableBlur";

@interface DDBlurConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)enableBlur;
- (BOOL)hasEnableBlur;
@end

@implementation DDBlurConfig

+ (instancetype)shared {
    static DDBlurConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDBlurConfig new]; });
    return cfg;
}

// 配置存储在 NSUserDefaults 的 DDBlurConfig 字典中
- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDBlurConfigKey];
    return [cfg isKindOfClass:[NSDictionary class]] ? cfg : @{};
}

// 写入配置项；value 为 nil 时移除该项
- (void)setValue:(id)value forConfigKey:(NSString *)key {
    NSMutableDictionary *cfg = [[self config] mutableCopy];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (value) {
        [cfg setValue:value forKey:key];
    } else {
        [cfg removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDBlurConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)enableBlur  { return [[self.config objectForKey:kDDBlurEnableBlur] boolValue]; }
- (BOOL)hasEnableBlur { return [self.config objectForKey:kDDBlurEnableBlur] != nil; }

@end

#pragma mark - 后台高斯模糊

@interface DDBackgroundBlur : NSObject
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, assign) BOOL blurVisible;
+ (instancetype)shared;

- (void)applyBlur;
- (void)removeBlur;
- (void)handleAppDidEnterBackground;
- (void)handleAppWillEnterForeground;
@end

@implementation DDBackgroundBlur

+ (instancetype)shared {
    static DDBackgroundBlur *blur = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ blur = [DDBackgroundBlur new]; });
    return blur;
}

- (instancetype)init {
    if (self = [super init]) {
        _blurVisible = NO;
    }
    return self;
}

// 取当前前台主窗口（iOS 13+ 多场景）
- (UIWindow *)mainWindow {
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindow *window = scene.windows.firstObject;
            if (window) return window;
        }
    }
    return nil;
}

// 进入后台：在窗口上盖一层高斯模糊遮罩（默认不延迟、不透明 alpha=1.0）
- (void)handleAppDidEnterBackground {
    if (!DDBlurConfig.shared.enableBlur) return;
    if (self.blurVisible) return;
    [self applyBlur];
}

- (void)applyBlur {
    UIWindow *window = [self mainWindow];
    if (!window) return;

    // 高斯模糊层（随系统深浅色模式自适应）
    UIBlurEffectStyle style = UIBlurEffectStyleLight;  // 浅色模式：Light（对齐 WCPulse）
    if (window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        style = UIBlurEffectStyleDark;                 // 深色模式：Dark
    }
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:style];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 1.0;   // 默认不透明

    self.blurView = blurView;
    self.blurVisible = YES;
    [window addSubview:blurView];
}

// 回到前台：移除模糊遮罩
- (void)handleAppWillEnterForeground {
    if (self.blurVisible) {
        [self removeBlur];
    }
}

- (void)removeBlur {
    if (self.blurView) {
        [self.blurView removeFromSuperview];
        self.blurView = nil;
    }
    self.blurVisible = NO;
}

@end

#pragma mark - 生命周期 Hook

%hook MicroMessengerAppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    [[DDBackgroundBlur shared] handleAppDidEnterBackground];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    [[DDBackgroundBlur shared] handleAppWillEnterForeground];
}

%end

#pragma mark - 设置界面

@interface DDBlurSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDBlurSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    Class mgrCls = objc_getClass("WCTableViewManager");
    if (!mgrCls) return;
    WCTableViewManager *mgr = [mgrCls alloc];
    _tableViewMgr = [mgr initWithFrame:[UIScreen mainScreen].bounds
                                 style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) {
        [self ensureTableViewMgr];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD后台高斯模糊";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

// 构建设置项：仅"后台高斯模糊"一个开关
- (void)buildTable {
    Class cellCls = objc_getClass("WCTableViewCellManager");
    Class secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    DDBlurConfig *cfg = DDBlurConfig.shared;

    WCTableViewSectionManager *section = [secCls defaultSection];
    [section addCell:[cellCls switchCellForSel:@selector(toggleBlur:)
                                        target:self
                                         title:@"后台高斯模糊"
                                            on:cfg.hasEnableBlur]];
    [self.tableViewMgr addSection:section];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleBlur:(UISwitch *)sender {
    [DDBlurConfig.shared setValue:sender.isOn ? @(1) : nil
                   forConfigKey:kDDBlurEnableBlur];
    if (!sender.isOn) {
        // 关闭模糊时立即移除已盖上的遮罩
        [[DDBackgroundBlur shared] removeBlur];
    }
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        Class mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD后台高斯模糊"
                                                      version:@"1.0.0"
                                                   controller:@"DDBlurSettingsViewController"];
        }
    }
}

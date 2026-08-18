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

- (void)applyBlurToWindow:(UIWindow *)window;
- (void)removeBlur;
- (void)handleAppDidEnterBackground:(UIWindow *)window;
- (void)handleAppDidBecomeActive;
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

// 进入后台：在窗口上盖一层高斯模糊遮罩
// window 由 hook 直接传入（微信 delegate 的 window 属性，即主窗口），
// 对齐 WCPulse 的 [self window]
- (void)handleAppDidEnterBackground:(UIWindow *)window {
    if (!DDBlurConfig.shared.enableBlur) return;
    if (self.blurVisible) return;
    [self applyBlurToWindow:window];
}

- (void)applyBlurToWindow:(UIWindow *)window {
    if (!window) return;

    // 高斯模糊层：固定 UIBlurEffectStyleLight（完全对齐 WCPulse 反汇编 mov x2,#1）
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 0.0;   // 挂载前透明（对齐 WCPulse：先 alpha=0，再淡入）

    self.blurView = blurView;
    self.blurVisible = YES;
    [window addSubview:blurView];

    // 淡入动画（对齐 WCPulse：0.25s，delay=0 不延迟，CurveEaseOut）
    [UIView animateWithDuration:0.25
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         blurView.alpha = 1.0;   // 淡入到不透明
                     }
                     completion:nil];
}

// 回到前台：移除模糊遮罩（对齐 WCPulse 的 applicationDidBecomeActive）
- (void)handleAppDidBecomeActive {
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
    // 直接用 delegate 的 window 属性（即主窗口），对齐 WCPulse 的 [self window]
    UIWindow *window = self.window;
    if (!window) return;
    [[DDBackgroundBlur shared] handleAppDidEnterBackground:window];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    // 回到前台移除模糊层（对齐 WCPulse 的 applicationDidBecomeActive: 钩子）
    [[DDBackgroundBlur shared] handleAppDidBecomeActive];
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

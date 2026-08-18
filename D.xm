// DD后台高斯模糊 —— 微信后台高斯模糊（隐私防窥屏）

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
- (UIWindow *)window;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationDidBecomeActive:(UIApplication *)application;
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

- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDBlurConfigKey];
    return [cfg isKindOfClass:[NSDictionary class]] ? cfg : @{};
}

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

- (BOOL)enableBlur    { return [[self.config objectForKey:kDDBlurEnableBlur] boolValue]; }
- (BOOL)hasEnableBlur { return [self.config objectForKey:kDDBlurEnableBlur] != nil; }

@end

#pragma mark - 后台模糊

@interface DDBackgroundBlur : NSObject
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, assign) BOOL blurVisible;
+ (instancetype)shared;

- (void)applyBlurToWindow:(UIWindow *)window;
- (void)removeBlur;
- (void)handleEnterBackground:(UIWindow *)window;
- (void)handleDidBecomeActive;
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

// 进后台：盖模糊层
- (void)handleEnterBackground:(UIWindow *)window {
    if (!DDBlurConfig.shared.enableBlur) return;
    if (self.blurVisible) return;
    [self applyBlurToWindow:window];
}

// 施加：Light 高斯模糊 + 不透明 + 填满窗口
- (void)applyBlurToWindow:(UIWindow *)window {
    if (!window) return;

    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 1.0;   // 不透明，无动画

    self.blurView = blurView;
    self.blurVisible = YES;
    [window addSubview:blurView];
    [window bringSubviewToFront:blurView];
}

// 回前台：移除模糊层
- (void)handleDidBecomeActive {
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

// 进后台触发（App 级方法，scene 下必被调用）
- (void)applicationWillResignActive:(UIApplication *)application {
    %orig;
    if (!self.window) return;
    [[DDBackgroundBlur shared] handleEnterBackground:self.window];
}

// 回前台触发
- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    [[DDBackgroundBlur shared] handleDidBecomeActive];
}

%end

#pragma mark - 设置界面

@interface DDBlurSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDBlurSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    id mgrCls = objc_getClass("WCTableViewManager");
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

// 仅一个开关
- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    DDBlurConfig *cfg = DDBlurConfig.shared;

    WCTableViewSectionManager *sec = [secCls defaultSection];
    [sec addCell:[cellCls switchCellForSel:@selector(toggleBlur:)
                                     target:self
                                      title:@"后台高斯模糊"
                                         on:cfg.hasEnableBlur]];
    [self.tableViewMgr addSection:sec];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleBlur:(UISwitch *)sender {
    [DDBlurConfig.shared setValue:sender.isOn ? @(1) : nil
                   forConfigKey:kDDBlurEnableBlur];
    if (!sender.isOn) {
        [[DDBackgroundBlur shared] removeBlur];
    }
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD后台高斯模糊"
                                                      version:@"1.0.0"
                                                   controller:@"DDBlurSettingsViewController"];
        }
    }
}

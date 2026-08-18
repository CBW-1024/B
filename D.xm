// DD后台高斯模糊 —— 微信后台高斯模糊（隐私防窥屏）
// 版本：1.0.0
//
// 功能：微信切入后台时，在窗口上盖一层高斯模糊遮罩，防止他人窥屏；
//       回到前台自动移除。设置界面仅一个开关，默认不延迟、不透明。
//
// 诊断：内置内存日志系统（DDBlurLog），记录插件加载 / hook 触发 /
//       配置读取 / 取窗口 / 施加模糊 / 移除模糊 等关键节点；
//       设置界面提供「导出日志」与「清空日志」两个功能项，便于排查"没效果"。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 诊断日志（内存缓冲 + NSLog）

@interface DDBlurLog : NSObject
+ (instancetype)shared;
- (void)log:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2);
- (NSString *)dump;
- (void)clear;
@end

@implementation DDBlurLog {
    NSMutableArray<NSString *> *_lines;
    NSDateFormatter *_fmt;
}

+ (instancetype)shared {
    static DDBlurLog *log = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = [DDBlurLog new]; });
    return log;
}

- (instancetype)init {
    if (self = [super init]) {
        _lines = [NSMutableArray array];
        _fmt = [[NSDateFormatter alloc] init];
        _fmt.dateFormat = @"HH:mm:ss.SSS";
    }
    return self;
}

- (void)log:(NSString *)fmt, ... {
    if (!fmt) return;
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    NSString *ts = [_fmt stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@", ts, msg];
    @synchronized(self) {
        [_lines addObject:line];
        if (_lines.count > 500) {           // 只保留最近 500 条，避免无限膨胀
            [_lines removeObjectsInRange:NSMakeRange(0, _lines.count - 500)];
        }
    }
    NSLog(@"[DDBlur] %@", msg);             // 同步输出到 syslog（越狱机可看）
}

- (NSString *)dump {
    @synchronized(self) {
        if (_lines.count == 0) return @"(暂无日志)";
        return [_lines componentsJoinedByString:@"\n"];
    }
}

- (void)clear {
    @synchronized(self) {
        [_lines removeAllObjects];
    }
    [self log:@"日志已清空"];
}

@end

#pragma mark - 微信私有接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// MMAppSceneUtil：微信场景工具类，用于取当前活跃场景的根窗口。
// 显式声明类方法，避免编译器报 "no known class method for selector"。
@interface MMAppSceneUtil : NSObject
+ (UIWindow *)lastActiveSceneRootWindow;
+ (UIWindow *)mainWindowScene;
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
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillResignActive:(UIApplication *)application;
- (void)applicationDidBecomeActive:(UIApplication *)application;
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

    [[DDBlurLog shared] log:@"配置写入 key=%@ value=%@", key, value ?: @"(移除)"];
    [[DDBlurLog shared] log:@"当前 enableBlur=%d (读取回验)", [self enableBlur]];
}

- (BOOL)enableBlur  { return [[self.config objectForKey:kDDBlurEnableBlur] boolValue]; }
- (BOOL)hasEnableBlur { return [self.config objectForKey:kDDBlurEnableBlur] != nil; }

@end

#pragma mark - 后台高斯模糊

@interface DDBackgroundBlur : NSObject
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, assign) BOOL blurVisible;
@property (nonatomic, assign) BOOL observing;
+ (instancetype)shared;

- (void)startObserving;
- (UIWindow *)currentMainWindow;
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
        _observing = NO;
    }
    return self;
}

// 监听系统级后台/前台通知作为可靠兜底。
// 微信是 iOS 13+ 多场景 App，进后台/回前台由 UISceneDelegate 处理，
// AppDelegate 的 applicationDidEnterBackground: 不保证被系统直接调用；
// 而 UIApplicationDidEnterBackgroundNotification 等系统通知必定触发。
- (void)startObserving {
    if (self.observing) return;
    self.observing = YES;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(onDidEnterBackgroundNotification:)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(onDidBecomeActiveNotification:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];

    [[DDBlurLog shared] log:@"已注册后台/前台系统通知监听"];
}

- (void)onDidEnterBackgroundNotification:(NSNotification *)note {
    [[DDBlurLog shared] log:@"收到系统通知 UIApplicationDidEnterBackground"];
    UIWindow *window = [self currentMainWindow];
    if (!window) {
        [[DDBlurLog shared] log:@"[通知] 取主窗口失败(nil)，跳过"];
        return;
    }
    [self handleEnterBackground:window];
}

- (void)onDidBecomeActiveNotification:(NSNotification *)note {
    [[DDBlurLog shared] log:@"收到系统通知 UIApplicationDidBecomeActive"];
    [self handleDidBecomeActive];
}

// 取当前主窗口，多级兜底：
// 1) AppDelegate.window（对齐 WCPulse 的 [self window]）
// 2) 微信 MMAppSceneUtil.lastActiveSceneRootWindow（微信官方取场景根窗口）
// 3) 遍历 connectedScenes 找激活窗口
- (UIWindow *)currentMainWindow {
    // 1) AppDelegate.window
    id delegate = [UIApplication sharedApplication].delegate;
    if (delegate && [delegate respondsToSelector:@selector(window)]) {
        UIWindow *w = [delegate window];
        if (w) {
            [[DDBlurLog shared] log:@"取窗口[1.AppDelegate.window] = %@", w];
            return w;
        }
    }
    // 2) 微信 MMAppSceneUtil.lastActiveSceneRootWindow
    id sceneUtil = objc_getClass("MMAppSceneUtil");
    if (sceneUtil && [sceneUtil respondsToSelector:@selector(lastActiveSceneRootWindow)]) {
        id w = [sceneUtil lastActiveSceneRootWindow];
        if ([w isKindOfClass:[UIWindow class]]) {
            [[DDBlurLog shared] log:@"取窗口[2.MMAppSceneUtil] = %@", w];
            return w;
        }
    }
    // 3) 遍历场景取激活窗口
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) {
                [[DDBlurLog shared] log:@"取窗口[3.scene.keyWindow] = %@", w];
                return w;
            }
            if (w.windowLevel == UIWindowLevelNormal && !w.hidden) {
                [[DDBlurLog shared] log:@"取窗口[3.scene.normal] = %@", w];
                return w;
            }
        }
    }
    [[DDBlurLog shared] log:@"取窗口失败：所有来源均为 nil"];
    return nil;
}

// 进入后台：在窗口上盖一层高斯模糊遮罩
- (void)handleEnterBackground:(UIWindow *)window {
    if (!DDBlurConfig.shared.enableBlur) {
        [[DDBlurLog shared] log:@"[后台] enableBlur=NO，不施加模糊"];
        return;
    }
    if (self.blurVisible) {
        [[DDBlurLog shared] log:@"[后台] 模糊层已存在(blurVisible=YES)，跳过防重入"];
        return;
    }
    [[DDBlurLog shared] log:@"[后台] 触发施加，window=%@", window];
    [self applyBlurToWindow:window];
}

- (void)applyBlurToWindow:(UIWindow *)window {
    if (!window) {
        [[DDBlurLog shared] log:@"[施加] window=nil，无法施加"];
        return;
    }
    [[DDBlurLog shared] log:@"[施加] window=%@ bounds=%@", window, NSStringFromCGRect(window.bounds)];
    [[DDBlurLog shared] log:@"[施加] window.hidden=%d keyWindow=%d level=%.0f",
            window.hidden, window.isKeyWindow, window.windowLevel];

    // 高斯模糊层：固定 UIBlurEffectStyleLight（完全对齐 WCPulse 反汇编 mov x2,#1）
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.frame = window.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = 1.0;   // 直接完全不透明（无动画，一步到位）

    self.blurView = blurView;
    self.blurVisible = YES;
    [window addSubview:blurView];
    [window bringSubviewToFront:blurView];

    [[DDBlurLog shared] log:@"[施加] 模糊层已添加到 window，frame=%@ superview=%@",
            NSStringFromCGRect(blurView.frame), window];
}

// 回到前台：移除模糊遮罩（对齐 WCPulse 的 applicationDidBecomeActive）
- (void)handleDidBecomeActive {
    if (self.blurVisible) {
        [[DDBlurLog shared] log:@"[前台] 移除模糊层"];
        [self removeBlur];
    } else {
        [[DDBlurLog shared] log:@"[前台] 无模糊层(blurVisible=NO)，无需移除"];
    }
}

- (void)removeBlur {
    if (self.blurView) {
        [[DDBlurLog shared] log:@"[移除] 从 superview=%@ 移除 blurView=%@",
                self.blurView.superview, self.blurView];
        [self.blurView removeFromSuperview];
        self.blurView = nil;
    }
    self.blurVisible = NO;
}

@end

#pragma mark - 生命周期 Hook

%hook MicroMessengerAppDelegate

// 进后台：applicationWillResignActive 与 applicationDidEnterBackground 都可触发，
// 两者对齐 WCPulse hook 的同一组方法；blurVisible 防重入
- (void)applicationWillResignActive:(UIApplication *)application {
    [[DDBlurLog shared] log:@"hook 命中 applicationWillResignActive: self=%@", self];
    %orig;
    UIWindow *window = self.window ?: [[DDBackgroundBlur shared] currentMainWindow];
    if (!window) {
        [[DDBlurLog shared] log:@"[ResignActive] self.window=nil，走 currentMainWindow 兜底"];
        return;
    }
    [[DDBlurLog shared] log:@"[ResignActive] self.window=%@", window];
    [[DDBackgroundBlur shared] handleEnterBackground:window];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[DDBlurLog shared] log:@"hook 命中 applicationDidEnterBackground: self=%@", self];
    %orig;
    UIWindow *window = self.window ?: [[DDBackgroundBlur shared] currentMainWindow];
    if (!window) {
        [[DDBlurLog shared] log:@"[EnterBackground] self.window=nil，走 currentMainWindow 兜底"];
        return;
    }
    [[DDBlurLog shared] log:@"[EnterBackground] self.window=%@", window];
    [[DDBackgroundBlur shared] handleEnterBackground:window];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[DDBlurLog shared] log:@"hook 命中 applicationDidBecomeActive: self=%@", self];
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

// 构建设置项：开关 + 导出日志 + 清空日志
- (void)buildTable {
    id cellCls = objc_getClass("WCTableViewCellManager");
    id secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) {
        [[DDBlurLog shared] log:@"构建设置界面失败：微信私有类缺失 cellCls=%p secCls=%p mgr=%p",
                cellCls, secCls, _tableViewMgr];
        return;
    }

    [self.tableViewMgr clearAllSection];
    DDBlurConfig *cfg = DDBlurConfig.shared;
    [[DDBlurLog shared] log:@"构建设置界面：hasEnableBlur=%d enableBlur=%d",
            cfg.hasEnableBlur, cfg.enableBlur];

    // —— 第一组：功能开关 ——
    WCTableViewSectionManager *sec1 = [secCls defaultSection];
    [sec1 addCell:[cellCls switchCellForSel:@selector(toggleBlur:)
                                     target:self
                                      title:@"后台高斯模糊"
                                         on:cfg.hasEnableBlur]];
    [self.tableViewMgr addSection:sec1];

    // —— 第二组：诊断工具 ——
    WCTableViewSectionManager *sec2 = [secCls sectionInfoHeader:@"诊断"];
    [sec2 addCell:[cellCls normalCellForSel:@selector(exportLog:)
                                     target:self
                                      title:@"导出日志"
                                 rightValue:@""]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(clearLog:)
                                     target:self
                                      title:@"清空日志"
                                 rightValue:@""]];
    [self.tableViewMgr addSection:sec2];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleBlur:(UISwitch *)sender {
    [[DDBlurLog shared] log:@"开关切换 -> %@", sender.isOn ? @"ON" : @"OFF"];
    [DDBlurConfig.shared setValue:sender.isOn ? @(1) : nil
                   forConfigKey:kDDBlurEnableBlur];
    if (!sender.isOn) {
        // 关闭模糊时立即移除已盖上的遮罩
        [[DDBackgroundBlur shared] removeBlur];
    }
    [self buildTable];
}

// 导出日志：拼成文本，走系统分享面板
- (void)exportLog:(id)sender {
    NSString *logText = [[DDBlurLog shared] dump];
    [[DDBlurLog shared] log:@"导出日志，共 %lu 字符", (unsigned long)logText.length];

    // 前置一段说明，便于对照
    NSString *header =
        @"DD后台高斯模糊 v1.0.0 诊断日志\n"
        @"------------------------------------\n"
        @"- enableBlur 开关：进后台是否施加模糊\n"
        @"- hook 命中：applicationWillResignActive / DidEnterBackground / DidBecomeActive\n"
        @"- 取窗口：self.window 优先，回退 MMAppSceneUtil / connectedScenes\n"
        @"- [施加]：模糊层已添加到 window\n\n";
    NSString *payload = [header stringByAppendingString:logText];

    UIActivityViewController *avc = [[UIActivityViewController alloc]
        initWithActivityItems:@[payload] applicationActivities:nil];
    avc.popoverPresentationController.sourceView = self.view;
    avc.popoverPresentationController.sourceRect = CGRectMake(0, 0, 1, 1);
    [self presentViewController:avc animated:YES completion:nil];
}

// 清空日志
- (void)clearLog:(id)sender {
    [[DDBlurLog shared] clear];
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        [[DDBlurLog shared] log:@"+++++ DD后台高斯模糊 v1.0.0 插件加载 +++++"];
        [[DDBlurLog shared] log:@"进程: %@", [[NSProcessInfo processInfo] processName]];
        [[DDBlurLog shared] log:@"系统: iOS %@", [[UIDevice currentDevice] systemVersion]];

        // 监听系统后台/前台通知兜底（微信 scene 生命周期下 applicationDidEnterBackground: 不可靠）
        [[DDBackgroundBlur shared] startObserving];

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD后台高斯模糊"
                                                      version:@"1.0.0"
                                                   controller:@"DDBlurSettingsViewController"];
            [[DDBlurLog shared] log:@"已注册设置入口 DDBlurSettingsViewController"];
        } else {
            [[DDBlurLog shared] log:@"注册入口失败：WCPluginsMgr 不存在或未实现 sharedInstance"];
        }

        [[DDBlurLog shared] log:@"插件初始化完成，enableBlur=%d", [DDBlurConfig.shared enableBlur]];
    }
}

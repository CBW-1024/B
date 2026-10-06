// DD触摸轨迹 —— 触摸轨迹显示 + 录屏联动

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// ========== 微信内部类声明 ==========

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

// ========== 配置管理 ==========

static NSString * const kDDTouchTrailEnabledKey        = @"DDTouchTrail";
static NSString * const kDDTouchTrailOnlyWhenRecordKey = @"DDTouchTrailOnlyWhenRecording";

@interface DDTouchTrailConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL touchTrailEnabled;   // 启用触摸轨迹
@property (nonatomic, assign) BOOL onlyWhenRecording;   // 仅在录屏显示
@end

@implementation DDTouchTrailConfig

+ (instancetype)shared {
    static DDTouchTrailConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDTouchTrailConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        // boolForKey 对未写入过的 key 直接返回 NO，无需额外播种默认值
        _touchTrailEnabled = [ud boolForKey:kDDTouchTrailEnabledKey];
        _onlyWhenRecording = [ud boolForKey:kDDTouchTrailOnlyWhenRecordKey];
    }
    return self;
}

- (void)setTouchTrailEnabled:(BOOL)touchTrailEnabled {
    _touchTrailEnabled = touchTrailEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:touchTrailEnabled forKey:kDDTouchTrailEnabledKey];
}

- (void)setOnlyWhenRecording:(BOOL)onlyWhenRecording {
    _onlyWhenRecording = onlyWhenRecording;
    [[NSUserDefaults standardUserDefaults] setBool:onlyWhenRecording forKey:kDDTouchTrailOnlyWhenRecordKey];
}

@end

// ========== 辅助函数 ==========

static NSMutableDictionary *trailLayers = nil;

// 移除所有轨迹圆点（切换开关 / 异常自愈时调用）
static void DDClearTrails(void) {
    for (CALayer *layer in trailLayers.allValues) [layer removeFromSuperlayer];
    [trailLayers removeAllObjects];
}

// ========== 轨迹圆点 ==========

static const CGFloat kDDTouchTrailDotSize = 25.0;

// 轨迹圆点：纯图层，不参与 UIView 的布局 / 命中测试 / autoresizing
static CALayer *DDCreateTrailLayer(void) {
    CALayer *layer = [CALayer layer];
    layer.bounds = CGRectMake(0, 0, kDDTouchTrailDotSize, kDDTouchTrailDotSize);
    layer.cornerRadius = kDDTouchTrailDotSize / 2;
    // 柔和红 #FF6B6B，不透明：比纯红耐看，且避免 alpha blending 的合成开销
    layer.backgroundColor = [UIColor colorWithRed:1.0 green:0.42 blue:0.42 alpha:1.0].CGColor;
    layer.actions = @{ @"position": NSNull.null };   // 关掉隐式动画，避免移动自带 0.25s 补间
    return layer;
}

// ========== Hook 触摸事件 ==========

%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;

    // 实时判断：不缓存状态，录屏开关变化无需额外通知
    DDTouchTrailConfig *cfg = DDTouchTrailConfig.shared;
    if (!cfg.touchTrailEnabled) return;
    if (cfg.onlyWhenRecording && !UIScreen.mainScreen.isCaptured) return;

    for (UITouch *touch in event.allTouches) {
        CGPoint location = [touch locationInView:nil];
        NSValue *key = [NSValue valueWithPointer:(__bridge const void*)touch];
        CALayer *trail = trailLayers[key];

        switch (touch.phase) {
            case UITouchPhaseBegan:
            case UITouchPhaseMoved: {
                if (!trail) {
                    if (!touch.window) continue;   // 无窗口的触摸不建轨迹，避免堆积游离图层
                    trail = DDCreateTrailLayer();
                    [touch.window.layer addSublayer:trail];
                    trailLayers[key] = trail;
                }
                trail.position = location;
                break;
            }
            case UITouchPhaseEnded:
            case UITouchPhaseCancelled: {
                [trail removeFromSuperlayer];
                [trailLayers removeObjectForKey:key];
                break;
            }
            default: break;
        }
    }

    // 兜底：条目数超过物理手指上限，说明漏收了 Ended/Cancelled，全清自愈
    // 正在显示的圆点会在下一次 Moved 时重建，不会误伤
    if (trailLayers.count > 12) DDClearTrails();
}

%end

// ========== 设置界面 ==========

@interface DDTouchTrailSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDTouchTrailSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"触摸轨迹设置";

    // 表格整屏延伸，由 viewDidLayoutSubviews 推到导航栏底边
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    // 已手动避开导航栏，关掉系统自动 inset，避免两套机制叠加
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_tableViewManager.tableView];

    [self buildTable];
    self.view.backgroundColor = _tableViewManager.tableView.backgroundColor;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    UITableView *tableView = _tableViewManager.tableView;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    tableView.frame = CGRectMake(0, top, w, h - top);
}

// 构建设置项："启用触摸轨迹"开关，"仅在录屏显示"仅在总开关开启时显示
- (void)buildTable {
    [_tableViewManager clearAllSection];

    DDTouchTrailConfig *cfg = DDTouchTrailConfig.shared;
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionWithHeader:nil];

    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onMainSwitchChanged:)
                                                                        target:self
                                                                         title:@"启用触摸轨迹"
                                                                            on:cfg.touchTrailEnabled]];

    if (cfg.touchTrailEnabled) {
        [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onOnlyRecordSwitchChanged:)
                                                                            target:self
                                                                             title:@"↳仅在录屏显示"
                                                                                on:cfg.onlyWhenRecording]];
    }

    [_tableViewManager addSection:section];
    [_tableViewManager reloadTableView];
}

- (void)onMainSwitchChanged:(UISwitch *)sender {
    DDTouchTrailConfig.shared.touchTrailEnabled = sender.isOn;
    DDClearTrails();
    [self buildTable];
}

- (void)onOnlyRecordSwitchChanged:(UISwitch *)sender {
    DDTouchTrailConfig.shared.onlyWhenRecording = sender.isOn;
    DDClearTrails();
}

@end

// ========== 插件注册 ==========

%ctor {
    @autoreleasepool {
        trailLayers = [NSMutableDictionary dictionary];

        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD触摸轨迹"
                                                      version:@"1.0.0"
                                                   controller:@"DDTouchTrailSettingsViewController"];
        }
    }
}

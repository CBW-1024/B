// DD后台保活 —— 微信后台保活 + 后台掉线提醒

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioToolbox.h>
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

static NSString * const kDDBackgroundConfigKey            = @"DDBackgroundConfig";
static NSString * const kDDBEnableBackground     = @"enableBackground";
static NSString * const kDDBEnableBackgroundTips = @"enableBackgroundTips";
static NSString * const kDDBSilentMode           = @"silentMode";
static NSString * const kDDBPlaySystemSound      = @"playSystemSound";

@interface DDBackgroundConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)enableBackground;
- (BOOL)enableBackgroundTips;
- (BOOL)hasEnableBackground;
- (BOOL)hasEnableBackgroundTips;
@end

@implementation DDBackgroundConfig

+ (instancetype)shared {
    static DDBackgroundConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDBackgroundConfig new]; });
    return cfg;
}

// 配置存储在 NSUserDefaults 的 DDBackgroundConfig 字典中
- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDBackgroundConfigKey];
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
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDBackgroundConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)enableBackground     { return [[self.config objectForKey:kDDBEnableBackground] boolValue]; }
- (BOOL)enableBackgroundTips { return [[self.config objectForKey:kDDBEnableBackgroundTips] boolValue]; }
- (BOOL)hasEnableBackground     { return [self.config objectForKey:kDDBEnableBackground] != nil; }
- (BOOL)hasEnableBackgroundTips { return [self.config objectForKey:kDDBEnableBackgroundTips] != nil; }

@end

#pragma mark - 后台保活 / 掉线提醒

@interface DDBackgroundKeeper : NSObject
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSTimer *bgTaskTimer;
@property (nonatomic, strong) AVAudioPlayer *blankPlayer;
@property (nonatomic, strong) NSDate *backgroundEnteredAt;
@property (nonatomic, assign) NSTimeInterval accumulatedBackgroundSeconds;
+ (instancetype)shared;

- (void)enterBackgroundHandler;
- (void)requestMoreTime;
- (void)playBlankAudio;
- (void)playSoundForResource:(NSString *)resource;
- (BOOL)isSilentMode;
- (void)disableBackgroundHandler;
- (NSTimeInterval)totalBackgroundRuntimeSeconds;
- (NSString *)timeStringForSeconds:(NSTimeInterval)seconds;
- (void)postNotification:(NSString *)title body:(NSString *)body delay:(NSTimeInterval)delay;
- (void)sendDisconnectNotification:(NSString *)prompt;
@end

@implementation DDBackgroundKeeper

+ (instancetype)shared {
    static DDBackgroundKeeper *keeper = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ keeper = [DDBackgroundKeeper new]; });
    return keeper;
}

- (instancetype)init {
    if (self = [super init]) {
        _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        _accumulatedBackgroundSeconds = 0;
    }
    return self;
}

// 进入后台：申请后台任务 + 25s 定时器周期续命
- (void)enterBackgroundHandler {
    if (!DDBackgroundConfig.shared.enableBackground) return;

    self.backgroundEnteredAt = [NSDate date];

    __weak typeof(self) weakSelf = self;
    UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication]
        beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
                self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    self.backgroundTaskIdentifier = task;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:25.0
                                                      target:self
                                                    selector:@selector(requestMoreTime)
                                                    userInfo:nil
                                                     repeats:YES];
    self.bgTaskTimer = timer;
    [timer fire];
}

// 续命：剩余时间不足 30s 时播放静音音频并重新申请后台任务
- (void)requestMoreTime {
    NSTimeInterval remaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    if (remaining >= 30.0) return;

    [self playBlankAudio];

    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }

    __weak typeof(self) weakSelf = self;
    UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication]
        beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
                self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    self.backgroundTaskIdentifier = task;
}

// 播放微信自带的 blank.caf 静音占位音频，维持后台音频会话
- (void)playBlankAudio {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];
    [session setActive:YES error:nil];

    NSString *blankPath = [[NSBundle mainBundle] pathForResource:@"blank" ofType:@"caf"];
    if (blankPath.length == 0) return;

    NSURL *url = [NSURL fileURLWithPath:blankPath];
    if (!self.blankPlayer) {
        self.blankPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    }
    [self.blankPlayer play];
}

- (BOOL)isSilentMode {
    return [DDBackgroundConfig.shared.config objectForKey:kDDBSilentMode] != nil;
}

- (void)playSoundForResource:(NSString *)resource {
    if (resource.length > 0 && !self.isSilentMode) {
        // 提示反馈改为震动（kSystemSoundID_Vibrate = 0xfff）
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
    if ([DDBackgroundConfig.shared.config objectForKey:kDDBPlaySystemSound] != nil) {
        AudioServicesPlaySystemSound(0xfff);
    }
}

// 回到前台 / 关闭保活：停定时器、结束后台任务、累计本次后台时长
- (void)disableBackgroundHandler {
    if (self.bgTaskTimer) {
        [self.bgTaskTimer invalidate];
        self.bgTaskTimer = nil;
    }
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
    if (self.backgroundEnteredAt) {
        self.accumulatedBackgroundSeconds +=
            [[NSDate date] timeIntervalSinceDate:self.backgroundEnteredAt];
        self.backgroundEnteredAt = nil;
    }
}

- (NSTimeInterval)totalBackgroundRuntimeSeconds {
    NSTimeInterval acc = self.accumulatedBackgroundSeconds;
    if (self.backgroundEnteredAt) {
        acc += [[NSDate date] timeIntervalSinceDate:self.backgroundEnteredAt];
    }
    return acc;
}

// 把秒数格式化为 "X天X小时X分钟X秒"
- (NSString *)timeStringForSeconds:(NSTimeInterval)seconds {
    long long total = (long long)seconds;
    if (total <= 0) return @"0";

    NSMutableString *str = [NSMutableString string];
    long long days = total / 86400;
    total %= 86400;
    if (days > 0) [str appendFormat:@"%lld天", days];
    if (total > 0) {
        long long hours = total / 3600;
        total %= 3600;
        if (hours > 0) [str appendFormat:@"%lld小时", hours];
    }
    if (total > 0) {
        long long minutes = total / 60;
        total %= 60;
        if (minutes > 0) [str appendFormat:@"%lld分钟", minutes];
    }
    if (total > 0) {
        [str appendFormat:@"%lld秒", total];
    }
    return [str copy];
}

// 发送本地通知，delay 秒后触发；带系统默认提示音
- (void)postNotification:(NSString *)title body:(NSString *)body delay:(NSTimeInterval)delay {
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body  = body;
    content.sound = [UNNotificationSound defaultSound];

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delay repeats:NO];
    NSString *identifier = [NSString stringWithFormat:@"identifier_%f_%@",
                            [[NSDate date] timeIntervalSince1970],
                            [[NSUUID UUID] UUIDString]];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:nil];
}

// 掉线提醒：累计后台时长 > 0 时震动并推送本地通知
- (void)sendDisconnectNotification:(NSString *)prompt {
    if (!DDBackgroundConfig.shared.hasEnableBackground) return;
    if (!DDBackgroundConfig.shared.hasEnableBackgroundTips) return;

    NSTimeInterval seconds = [self totalBackgroundRuntimeSeconds];
    if (seconds <= 0) return;

    [self playSoundForResource:@"alarm"];
    NSString *timeText = [self timeStringForSeconds:seconds];
    NSString *message = [NSString stringWithFormat:@"%@，%@", prompt, timeText];
    [self postNotification:message body:@"" delay:1.0];
}

@end

#pragma mark - 生命周期 Hook

%hook MicroMessengerAppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    [[DDBackgroundKeeper shared] enterBackgroundHandler];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    // 回到前台：停止保活并累计后台时长
    [[DDBackgroundKeeper shared] disableBackgroundHandler];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;
    // 后台被终止（掉线）时触发掉线提醒
    [[DDBackgroundKeeper shared] sendDisconnectNotification:@"退出后台"];
}

%end

#pragma mark - 设置界面

@interface DDBackgroundSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDBackgroundSettingsViewController

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
    self.title = @"DD后台保活";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

// 构建设置项："保持后台运行"开关，"后台掉线提醒"仅在保活开启时显示
- (void)buildTable {
    Class cellCls = objc_getClass("WCTableViewCellManager");
    Class secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    DDBackgroundConfig *cfg = DDBackgroundConfig.shared;

    WCTableViewSectionManager *section = [secCls defaultSection];
    [section addCell:[cellCls switchCellForSel:@selector(toggleBackgroundRunning:)
                                        target:self
                                         title:@"保持后台运行"
                                            on:cfg.hasEnableBackground]];
    if (cfg.hasEnableBackground) {
        [section addCell:[cellCls switchCellForSel:@selector(toggleDisconnectTip:)
                                            target:self
                                             title:@"后台掉线提醒"
                                                on:cfg.hasEnableBackgroundTips]];
    }
    [self.tableViewMgr addSection:section];

    [self.tableViewMgr reloadTableView];
}

- (void)toggleBackgroundRunning:(UISwitch *)sender {
    [DDBackgroundConfig.shared setValue:sender.isOn ? @(1) : nil
                   forConfigKey:kDDBEnableBackground];
    if (!sender.isOn) {
        // 关闭保活时立即停止后台任务
        [[DDBackgroundKeeper shared] disableBackgroundHandler];
    }
    [self buildTable];
}

- (void)toggleDisconnectTip:(UISwitch *)sender {
    [DDBackgroundConfig.shared setValue:sender.isOn ? @(1) : nil
                   forConfigKey:kDDBEnableBackgroundTips];
    [self buildTable];
}

@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        Class mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD后台保活"
                                                      version:@"1.0.0"
                                                   controller:@"DDBackgroundSettingsViewController"];
        }
    }
}

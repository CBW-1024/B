// DD后台保活 v1.0.0
// 单文件 iOS 插件（Logos / Theos，arm64 + arm64e，部署 iOS 15.0+）
//
// 功能：提取自 PKC（dis_live1.txt 反汇编），严格对齐其 RUCrmialsmiufcq 实现：
//   1) 后台保活（保持后台运行）
//      - 进入后台：记录进后台时刻 + beginBackgroundTaskWithExpirationHandler
//        申请后台任务 + 启动 25s 定时器周期续命。
//      - 续命：backgroundTimeRemaining >= 30s 直接返回；否则播放静音占位音频
//        （AVAudioSession Playback + MixWithOthers + 静音 caf）+ 结束旧任务
//        并重新申请后台任务（形成续命循环）。
//   2) 后台掉线提醒
//      - applicationWillTerminate 时（后台被终止/掉线）：若 enableBackgroud 与
//        enableBackgroudTips 均已配置且累计后台时长 > 0：播放 alarm 提示音 +
//        UNUserNotificationCenter 本地通知，title 显示"X天X小时X分钟X秒"。
//
// 配置对齐 PKC：存于 NSUserDefaults 的 @"PKCConfig" 字典（OOXqaiiczuuvhpi 风格），
// key：enableBackgroud / enableBackgroudTips，值为 NSNumber(0/1)，开关 on 态反映
// key 是否存在（非 nil）。
//
// 设置界面 / 注册入口：参考 DD朋友圈转发 + PKC 的 MWFslyunytxupmodzgd 设置页
// （微信原生 WCTableViewManager 系列 + WCPluginsMgr registerControllerWithTitle:）。

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>
#import <AudioToolbox/AudioToolbox.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信私有接口声明

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
+ (id)sectionInfoHeader:(NSString *)header;   // 对齐 PKC：带 section 头
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4;
@end

// 微信 AppDelegate，挂钩生命周期。
@interface MicroMessengerAppDelegate : NSObject <UIApplicationDelegate>
- (void)applicationDidEnterBackground:(UIApplication *)application;
- (void)applicationWillEnterForeground:(UIApplication *)application;
- (void)applicationWillTerminate:(UIApplication *)application;
@end

#pragma mark - 配置（对齐 PKC 的 OOXqaiiczuuvhpi + pkcConfig）

static NSString * const kDDBPKCConfigKey    = @"PKCConfig";
static NSString * const kDDEnableBackgroud     = @"enableBackgroud";
static NSString * const kDDEnableBackgroudTips = @"enableBackgroudTips";

// 对齐 PKC：+setPKCConfigForKey:value:（读 PKCConfig 字典 → mutableCopy →
// setValue:forKey: → setPkcConfig: → 持久化回 PKCConfig）。
// enableBackgroud / enableBackgroudTips 的读写均经 PKCConfig 字典（对齐 PKC）。
@interface DDBConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)pkcConfig;                                   // 读当前 pkcConfig
- (void)setPKCConfigForKey:(NSString *)key value:(id)value;    // 写单个配置项并持久化
- (BOOL)enableBackgroud;       // pkcConfig[@"enableBackgroud"] boolValue
- (BOOL)enableBackgroudTips;   // pkcConfig[@"enableBackgroudTips"] boolValue
- (BOOL)hasEnableBackgroud;    // pkcConfig[@"enableBackgroud"] 非 nil
- (BOOL)hasEnableBackgroudTips;// pkcConfig[@"enableBackgroudTips"] 非 nil
@end

@implementation DDBConfig

+ (instancetype)shared {
    static DDBConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDBConfig new]; });
    return cfg;
}

- (NSDictionary *)pkcConfig {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDBPKCConfigKey];
    if ([cfg isKindOfClass:[NSDictionary class]]) return cfg;
    return @{};
}

- (void)setPKCConfigForKey:(NSString *)key value:(id)value {
    NSMutableDictionary *cfg = [[self pkcConfig] mutableCopy];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (value) {
        [cfg setValue:value forKey:key];
    } else {
        [cfg removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDBPKCConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)enableBackgroud     { return [[self.pkcConfig objectForKey:kDDEnableBackgroud] boolValue]; }
- (BOOL)enableBackgroudTips { return [[self.pkcConfig objectForKey:kDDEnableBackgroudTips] boolValue]; }
- (BOOL)hasEnableBackgroud     { return [self.pkcConfig objectForKey:kDDEnableBackgroud] != nil; }
- (BOOL)hasEnableBackgroudTips { return [self.pkcConfig objectForKey:kDDEnableBackgroudTips] != nil; }

@end

#pragma mark - 后台保活 / 掉线提醒核心（对齐 RUCrmialsmiufcq）

@interface DDBackgroundKeeper : NSObject
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTaskIdentifier; // ivar 0x8
@property (nonatomic, strong) NSTimer *bgTaskTimer;                        // ivar 0x10
@property (nonatomic, strong) AVAudioPlayer *blankPlayer;                  // ivar 0x18
@property (nonatomic, strong) AVAudioPlayer *player;                       // ivar 0x20
@property (nonatomic, strong) NSDate *backgroundEnteredAt;                 // ivar 0x28
@property (nonatomic, assign) NSTimeInterval accumulatedBackgroundSeconds; // ivar 0x30
+ (instancetype)shared;

- (void)enterBackgroundHandler;      // 进后台
- (void)requestMoreTime;             // 续命
- (void)playBlankAudio;              // 静音占位
- (NSString *)findSystemSoundFilePathWithKeyword:(NSString *)keyword;
- (void)playAudioForResource:(NSString *)resource;
- (void)playAudioForPath:(NSString *)path;
- (BOOL)isSilentMode;
- (BOOL)isMicrophoneInUse;
- (void)disbaleBackgroundHandler;    // 回前台/关闭
- (NSTimeInterval)totalBackgroundRuntimeSeconds;
- (NSString *)traForSec:(NSTimeInterval)sec;
- (void)pushMsgNotification:(NSString *)title body:(NSString *)body withTime:(NSTimeInterval)time;
- (void)sendStopTz:(id)arg;          // 掉线提醒
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
        _bgTaskIdentifier = UIBackgroundTaskInvalid;
        _accumulatedBackgroundSeconds = 0;
    }
    return self;
}

#pragma mark 进入后台

// 对齐 PKC enterBackgroundHandler：
//   pkcConfig[@"enableBackgroud"].boolValue 为 YES 时：
//   记录进后台时刻 → beginBackgroundTask → 25s 定时器 requestMoreTime 并立即 fire。
- (void)enterBackgroundHandler {
    if (!DDBConfig.shared.enableBackgroud) return;

    self.backgroundEnteredAt = [NSDate date];

    __weak typeof(self) weakSelf = self;
    UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication]
        beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            // 对齐 PKC：到期处理仅结束任务并复位 identifier（续命由 25s 定时器驱动）
            UIBackgroundTaskIdentifier cur = self.bgTaskIdentifier;
            if (cur != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:cur];
                self.bgTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    self.bgTaskIdentifier = task;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:25.0
                                                      target:self
                                                    selector:@selector(requestMoreTime)
                                                    userInfo:nil
                                                     repeats:YES];
    self.bgTaskTimer = timer;
    [timer fire];
}

#pragma mark 续命

// 对齐 PKC requestMoreTime：
//   不读配置，直接看 backgroundTimeRemaining：>= 30 → return；否则
//   playBlankAudio + endBackgroundTask 旧任务 + 重新 beginBackgroundTask（续命循环）。
- (void)requestMoreTime {
    NSTimeInterval remaining = [UIApplication sharedApplication].backgroundTimeRemaining;
    if (remaining >= 30.0) return;

    [self playBlankAudio];

    if (self.bgTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskIdentifier];
        self.bgTaskIdentifier = UIBackgroundTaskInvalid;
    }

    __weak typeof(self) weakSelf = self;
    UIBackgroundTaskIdentifier task = [[UIApplication sharedApplication]
        beginBackgroundTaskWithExpirationHandler:^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            UIBackgroundTaskIdentifier cur = self.bgTaskIdentifier;
            if (cur != UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:cur];
                self.bgTaskIdentifier = UIBackgroundTaskInvalid;
            }
        }];
    self.bgTaskIdentifier = task;
}

#pragma mark 静音占位音频

// 对齐 PKC playBlankAudio：
//   AVAudioSession setCategory:Playback withOptions:MixWithOthers(0x1) +
//   setActive:YES + 微信主 Bundle 的 blank.caf → AVAudioPlayer → play。
// 与 PKC 完全一致：直接复用微信自带的 blank.caf 静音占位音频（无需自造文件）。
- (void)playBlankAudio {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];
    [session setActive:YES error:nil];

    // 与 PKC 一致：从微信主 Bundle 取 blank.caf（微信自带该资源）
    NSString *blankPath = [[NSBundle mainBundle] pathForResource:@"blank" ofType:@"caf"];
    if (blankPath.length == 0) return;

    NSURL *url = [NSURL fileURLWithPath:blankPath];
    if (!self.blankPlayer) {
        NSError *err = nil;
        self.blankPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    }
    [self.blankPlayer play];
}

#pragma mark 系统提示音查找

// 对齐 PKC findSystemSoundFilePathWithKeyword:：
//   遍历 /System/Library/Audio/UISounds 子路径，文件名小写包含 "<keyword>.caf"
//   且扩展名为 caf 的第一个文件。
- (NSString *)findSystemSoundFilePathWithKeyword:(NSString *)keyword {
    if (keyword.length == 0) return nil;
    NSArray *subpaths = [[NSFileManager defaultManager]
        subpathsAtPath:@"/System/Library/Audio/UISounds"];
    NSString *target = [NSString stringWithFormat:@"%@.caf", keyword].lowercaseString;
    for (NSString *sub in subpaths) {
        if ([sub.lowercaseString containsString:target] &&
            [sub.pathExtension isEqualToString:@"caf"]) {
            return [@"/System/Library/Audio/UISounds" stringByAppendingPathComponent:sub];
        }
    }
    return nil;
}

#pragma mark 麦克风占用 / 静音模式

// 对齐 PKC isMicrophoneInUse：WAVOIPProxy / KaraBridging 是否有 isVoipWorking。
- (BOOL)isMicrophoneInUse {
    Class wav = NSClassFromString(@"WAVOIPProxy");
    if (wav && [wav respondsToSelector:@selector(isVoipWorking)]) {
        return [wav isVoipWorking];
    }
    Class kara = NSClassFromString(@"KaraBridging");
    if (kara && [kara respondsToSelector:@selector(isVoipWorking)]) {
        return [kara isVoipWorking];
    }
    return NO;
}

// 对齐 PKC isSilentMode：pkcConfig[@"pkcMsgPushJY"] 非 nil。
- (BOOL)isSilentMode {
    return [DDBConfig.shared.pkcConfig objectForKey:@"pkcMsgPushJY"] != nil;
}

#pragma mark 播放提示音

// 对齐 PKC playAudioForResource:：
//   非静音模式时 playAudioForPath:resource；若 pkcConfig[@"pkcMsgPushZD"] 非 nil
//   则 AudioServicesPlaySystemSound(0xfff)。
- (void)playAudioForResource:(NSString *)resource {
    if (resource.length > 0 && !self.isSilentMode) {
        [self playAudioForPath:resource];
    }
    if ([DDBConfig.shared.pkcConfig objectForKey:@"pkcMsgPushZD"] != nil) {
        AudioServicesPlaySystemSound(0xfff);
    }
}

// 对齐 PKC playAudioForPath:：
//   非麦克风占用时，用 findSystemSoundFilePathWithKeyword: 找系统 caf 播放。
- (void)playAudioForPath:(NSString *)path {
    if (self.isMicrophoneInUse) return;
    NSString *soundPath = [self findSystemSoundFilePathWithKeyword:path];
    if (soundPath.length == 0) return;

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
             withOptions:AVAudioSessionCategoryOptionMixWithOthers
                   error:nil];
    [session setActive:YES error:nil];

    NSURL *url = [NSURL fileURLWithPath:soundPath];
    if (!url) return;
    NSError *err = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    self.player.numberOfLoops = 0;
    self.player.volume = 1.0;
    [self.player prepareToPlay];
    [self.player play];
}

#pragma mark 回到前台 / 关闭

// 对齐 PKC disbaleBackgroundHandler：
//   invalidate 定时器 + 清 timer + 累计 backgroundEnteredAt 差值 + 清 backgroundEnteredAt。
- (void)disbaleBackgroundHandler {
    if (self.bgTaskTimer) {
        [self.bgTaskTimer invalidate];
        self.bgTaskTimer = nil;
    }
    if (self.bgTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskIdentifier];
        self.bgTaskIdentifier = UIBackgroundTaskInvalid;
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

#pragma mark 时间格式化（对齐 PKC traForSec:）

// 对齐 PKC traForSec:：
//   sec <= 0 → @"0"；否则按 86400/3600/60 分段 append "X天/X小时/X分钟/X秒"，
//   每段余数为 0 时不再追加该段。
- (NSString *)traForSec:(NSTimeInterval)sec {
    long long total = (long long)sec;
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

#pragma mark 本地通知

// 对齐 PKC pushMsgNotification:body:withTime:：
//   setTitle: = 第1参，setBody: = 第2参，trigger 间隔 = withTime:，
//   identifier = identifier_%f_%@（时间戳 + UUID）。不设置 sound（对齐 PKC）。
- (void)pushMsgNotification:(NSString *)title body:(NSString *)body withTime:(NSTimeInterval)time {
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body  = body;

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:time repeats:NO];
    NSString *identifier = [NSString stringWithFormat:@"identifier_%f_%@",
                            [[NSDate date] timeIntervalSince1970],
                            [[NSUUID UUID] UUIDString]];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:nil];
}

#pragma mark 掉线提醒

// 对齐 PKC sendStopTz:：
//   pkcConfig[@"enableBackgroud"] 非 nil 且 pkcConfig[@"enableBackgroudTips"] 非 nil
//   且 totalBackgroundRuntimeSeconds > 0 时：playAudioForResource:@"alarm" +
//   stringWithFormat(传入 arg + traForSec) → pushMsgNotification(title=组合串 body=@"" withTime:1.0)。
- (void)sendStopTz:(id)arg {
    if (!DDBConfig.shared.hasEnableBackgroud) return;
    if (!DDBConfig.shared.hasEnableBackgroudTips) return;

    NSTimeInterval sec = [self totalBackgroundRuntimeSeconds];
    if (sec <= 0) return;

    [self playAudioForResource:@"alarm"];
    NSString *traStr = [self traForSec:sec];
    NSString *msg = [NSString stringWithFormat:@"%@，%@", arg, traStr];
    [self pushMsgNotification:msg body:@"" withTime:1.0];
}

@end

#pragma mark - 生命周期 Hook（对齐 PKC 挂钩点）

%hook MicroMessengerAppDelegate

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    [[DDBackgroundKeeper shared] enterBackgroundHandler];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    // 对齐 PKC：回前台只停止保活并累计时长（不触发掉线提醒）
    [[DDBackgroundKeeper shared] disbaleBackgroundHandler];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    %orig;
    // 对齐 PKC：后台被终止（掉线）时触发掉线提醒，传"退出后台"文案
    [[DDBackgroundKeeper shared] sendStopTz:@"退出后台"];
}

%end

#pragma mark - 设置界面（参考 DD朋友圈转发）

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

// 设置页（排版参考 DD朋友圈转发，开关语义对齐 PKC）：
//   "保持后台运行"开关 on = enableBackgroud key 是否存在；
//   "后台掉线提醒"开关 on = enableBackgroudTips key 是否存在，且仅当保持后台运行
//   已配置（enableBackgroud 非 nil）时显示（对齐 PKC 的 createBackgroudTipsSwitchCell）。
- (void)buildTable {
    Class cellCls = objc_getClass("WCTableViewCellManager");
    Class secCls  = objc_getClass("WCTableViewSectionManager");
    if (!cellCls || !secCls || !_tableViewMgr) return;

    [self.tableViewMgr clearAllSection];
    DDBConfig *cfg = DDBConfig.shared;

    WCTableViewSectionManager *section = [secCls defaultSection];
    [section addCell:[cellCls switchCellForSel:@selector(settingEanbleBg:)
                                        target:self
                                         title:@"保持后台运行"
                                            on:cfg.hasEnableBackgroud]];
    if (cfg.hasEnableBackgroud) {
        [section addCell:[cellCls switchCellForSel:@selector(settingEanbleBgTips:)
                                            target:self
                                             title:@"后台掉线提醒"
                                                on:cfg.hasEnableBackgroudTips]];
    }
    [self.tableViewMgr addSection:section];

    [self.tableViewMgr reloadTableView];
}

// 对齐 PKC settingEanbleBg:：开启写 @(1)，关闭传 nil（移除 key）+ reload；
// 关闭时若在保活则立即停止。
- (void)settingEanbleBg:(UISwitch *)sender {
    [DDBConfig.shared setPKCConfigForKey:kDDEnableBackgroud
                                   value:sender.isOn ? @(1) : nil];
    if (!sender.isOn) {
        [[DDBackgroundKeeper shared] disbaleBackgroundHandler];
    }
    [self buildTable];
}

// 对齐 PKC settingEanbleBgTips:：开启写 @(1)，关闭传 nil（移除 key）+ reload。
- (void)settingEanbleBgTips:(UISwitch *)sender {
    [DDBConfig.shared setPKCConfigForKey:kDDEnableBackgroudTips
                                   value:sender.isOn ? @(1) : nil];
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

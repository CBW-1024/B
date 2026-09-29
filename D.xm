
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 微信内部类前向声明 ==========
// 插件需要调用微信私有 API，这里只声明用到的类与方法签名，
// 具体实现由微信二进制在运行时提供。
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
- (id)initWithFrame:(CGRect)arg1 style:(NSInteger)arg2;
- (id)getTableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

// ========== 功能类前向声明 ==========
// 猜拳 / 骰子的结果字段（类型、内容、MD5）位于 CExtendInfoOfEmoticon，
// 需先通过 m_extendInfoWithMsgType 取出扩展信息对象，再对其读写。
@interface CMessageWrap : NSObject
- (unsigned int)m_uiMessageType;
- (id)m_extendInfoWithMsgType;
@end

@interface CExtendInfoOfEmoticon : NSObject
- (unsigned int)m_uiGameType;
- (unsigned int)m_uiGameContent;
- (id)m_nsEmoticonMD5;
- (void)setM_uiGameType:(unsigned int)arg1;
- (void)setM_uiGameContent:(unsigned int)arg1;
- (void)setM_nsEmoticonMD5:(id)arg1;
@end

@interface CMessageMgr : NSObject
- (void)AddEmoticonMsg:(id)arg1 MsgWrap:(id)arg2;
@end

@interface GameController : NSObject
+ (id)getMD5ByGameContent:(unsigned int)arg1;
@end

@interface WCActionSheet : NSObject
- (id)initWithTitle:(id)arg1;
- (long long)addButtonWithTitle:(id)arg1 eventAction:(id)arg2;
- (void)showInView:(id)arg1;
@end

// ========== 配置管理 ==========
static NSString * const kDDGameCheatEnabledKey = @"DDGameCheat_Enabled";

@interface DDGameCheatConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL gameCheatEnabled;
@end

@implementation DDGameCheatConfig

+ (instancetype)sharedConfig {
    static DDGameCheatConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDGameCheatConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _gameCheatEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDGameCheatEnabledKey];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kDDGameCheatEnabledKey] == nil) {
            _gameCheatEnabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_gameCheatEnabled forKey:kDDGameCheatEnabledKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return self;
}

- (void)setGameCheatEnabled:(BOOL)gameCheatEnabled {
    _gameCheatEnabled = gameCheatEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:gameCheatEnabled forKey:kDDGameCheatEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// ========== 设置界面 ==========
@interface DDGameCheatSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDGameCheatSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"猜拳骰子设置";

    if (!self.tableViewManager) {
        self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                                  initWithFrame:[UIScreen mainScreen].bounds
                                          style:UITableViewStyleInsetGrouped];
    }
    if (!self.tableViewManager) return;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    [self buildTable];

    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    [self addGameSections];
    [_tableViewManager reloadTableView];
}

- (void)addGameSections {
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    WCTableViewSectionManager *sec = [secMgr sectionWithHeader:@"游戏设置"];
    [sec addCell:[cellMgr switchCellForSel:@selector(onSwitchChanged:)
                                    target:self
                                     title:@"猜拳骰子控制"
                                        on:[DDGameCheatConfig sharedConfig].gameCheatEnabled]];
    [_tableViewManager addSection:sec];
}

- (void)onSwitchChanged:(UISwitch *)sender {
    [DDGameCheatConfig sharedConfig].gameCheatEnabled = sender.isOn;
}

@end

// ========== Hook 猜拳骰子 ==========
%hook CMessageMgr

- (void)AddEmoticonMsg:(id)msg MsgWrap:(id)msgWrap {
    if (![DDGameCheatConfig sharedConfig].gameCheatEnabled) {
        %orig;
        return;
    }
    
    unsigned int messageType = [msgWrap m_uiMessageType];
    id extendInfo = [msgWrap m_extendInfoWithMsgType];

    unsigned int gameType = [extendInfo m_uiGameType];

    if (messageType == 47 && (gameType == 1 || gameType == 2)) {
        WCActionSheet *actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:(gameType == 1) ? @"请选择猜拳结果" : @"请选择骰子点数"];

        if (gameType == 1) {
            [actionSheet addButtonWithTitle:@"剪刀" eventAction:^{
                unsigned int content = 1;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                [extendInfo setM_nsEmoticonMD5:gameMD5];
                [extendInfo setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
            [actionSheet addButtonWithTitle:@"石头" eventAction:^{
                unsigned int content = 2;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                [extendInfo setM_nsEmoticonMD5:gameMD5];
                [extendInfo setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
            [actionSheet addButtonWithTitle:@"布" eventAction:^{
                unsigned int content = 3;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                [extendInfo setM_nsEmoticonMD5:gameMD5];
                [extendInfo setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
        } else {
            for (int i = 1; i <= 6; i++) {
                unsigned int content = 3 + i;
                NSString *title = [NSString stringWithFormat:@"%d点", i];
                [actionSheet addButtonWithTitle:title eventAction:^{
                    NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                    [extendInfo setM_nsEmoticonMD5:gameMD5];
                    [extendInfo setM_uiGameContent:content];
                    %orig(msg, msgWrap);
                }];
            }
        }
        
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        UIWindow *window = windowScene.windows.firstObject;
        [actionSheet showInView:window];
        return;
    }
    
    %orig;
}

%end

// ========== 插件注册 ==========
%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD猜拳骰子助手" version:@"1.0.0" controller:@"DDGameCheatSettingsViewController"];
        }
    }
}

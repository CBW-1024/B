
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ========== 微信内部类声明 ==========
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

// ========== 功能类声明 ==========
@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, assign) unsigned int m_uiGameType;
@property (nonatomic, assign) unsigned int m_uiGameContent;
@property (nonatomic, copy) NSString *m_nsEmoticonMD5;
- (void)setM_uiGameContent:(unsigned int)gameContent;
- (void)setM_nsEmoticonMD5:(NSString *)md5;
@end

@interface CMessageMgr : NSObject
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
@end

@interface GameController : NSObject
+ (NSString *)getMD5ByGameContent:(unsigned int)gameContent;
@end

@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title;
- (void)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))eventAction;
- (void)showInView:(UIView *)view;
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

@implementation DDGameCheatSettingsViewController {
    id _originalDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD猜拳骰子辅助";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];
    
    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;
    
    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    
    WCTableViewSectionManager *section = [[objc_getClass("WCTableViewSectionManager") alloc] init];
    BOOL isOn = [DDGameCheatConfig sharedConfig].gameCheatEnabled;
    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onSwitchChanged:) target:self title:@"启用猜拳骰子控制" on:isOn]];
    
    [_tableViewManager addSection:section];
    [_tableViewManager reloadTableView];
}

- (void)onSwitchChanged:(UISwitch *)sender {
    [DDGameCheatConfig sharedConfig].gameCheatEnabled = sender.isOn;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [super respondsToSelector:aSelector] || [_originalDelegate respondsToSelector:aSelector];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if ([_originalDelegate respondsToSelector:aSelector]) return _originalDelegate;
    return [super forwardingTargetForSelector:aSelector];
}

@end

// ========== Hook 猜拳骰子 ==========
%hook CMessageMgr

- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (![DDGameCheatConfig sharedConfig].gameCheatEnabled) {
        %orig;
        return;
    }
    
    unsigned int messageType = [msgWrap m_uiMessageType];
    unsigned int gameType = [msgWrap m_uiGameType];
    
    if (messageType == 47 && (gameType == 1 || gameType == 2)) {
        WCActionSheet *actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:(gameType == 1) ? @"请选择猜拳结果" : @"请选择骰子点数"];
        
        if (gameType == 1) {
            [actionSheet addButtonWithTitle:@"剪刀" eventAction:^{
                unsigned int content = 1;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                if (gameMD5) [msgWrap setM_nsEmoticonMD5:gameMD5];
                [msgWrap setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
            [actionSheet addButtonWithTitle:@"石头" eventAction:^{
                unsigned int content = 2;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                if (gameMD5) [msgWrap setM_nsEmoticonMD5:gameMD5];
                [msgWrap setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
            [actionSheet addButtonWithTitle:@"布" eventAction:^{
                unsigned int content = 3;
                NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                if (gameMD5) [msgWrap setM_nsEmoticonMD5:gameMD5];
                [msgWrap setM_uiGameContent:content];
                %orig(msg, msgWrap);
            }];
        } else {
            for (int i = 1; i <= 6; i++) {
                unsigned int content = 3 + i;
                NSString *title = [NSString stringWithFormat:@"%d点", i];
                [actionSheet addButtonWithTitle:title eventAction:^{
                    NSString *gameMD5 = [%c(GameController) getMD5ByGameContent:content];
                    if (gameMD5) [msgWrap setM_nsEmoticonMD5:gameMD5];
                    [msgWrap setM_uiGameContent:content];
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
        if (windowScene && actionSheet) {
            UIWindow *window = windowScene.windows.firstObject;
            if (window) [actionSheet showInView:window];
        }
        return;
    }
    
    %orig;
}

%end

// ========== 插件注册 ==========
%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD猜拳骰子辅助" version:@"1.0.0" controller:@"DDGameCheatSettingsViewController"];
        }
    }
}
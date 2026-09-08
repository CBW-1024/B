#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 微信类声明

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightView:(id)rightView;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
+ (id)sectionWithFooter:(NSString *)footer;
+ (id)sectionWithHeader:(NSString *)header Footer:(NSString *)footer;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (id)cellInfoAtIndexPath:(NSIndexPath *)indexPath;
- (void)reloadTableView;
@end

@interface WCPayInfoItem : NSObject
@property (nonatomic, retain) NSString *m_nsFeeDesc;
@property (nonatomic, retain) NSString *m_receiverDesc;
@property (nonatomic, retain) NSString *m_senderDesc;
@property (nonatomic, assign) unsigned int m_uiPaySubType;
@property (nonatomic, retain) NSString *m_nsTransferID;
@end

@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMesLocalID;
@property (nonatomic, retain) NSString *m_nsContent;
@property (nonatomic, retain) NSString *m_nsTitle;
@property (nonatomic, retain) NSString *m_nsFromUsr;
@property (nonatomic, retain) NSString *m_nsToUsr;
@property (nonatomic, retain) WCPayInfoItem *m_oWCPayInfoItem;
- (BOOL)IsTextMsg;
- (BOOL)isReferMsgType;
- (NSString *)GetDisplayContent;
- (void)parseWCPayInfoItemIfNeed;
@end

@interface CommonMessageViewModel : NSObject
@property (nonatomic, readonly) CMessageWrap *messageWrap;
@end

@interface CommonMessageCellView : UIView
@property (nonatomic, readonly) CommonMessageViewModel *viewModel;
@end

@interface BaseMsgContentViewController : UIViewController
- (void)clearNodeLayoutCache;
- (void)reloadNodeWithMessageWrap:(CMessageWrap *)msgWrap;
- (void)reloadVisibleNodeWithCellView:(UIView *)cellView;
- (UITableView *)getMsgTableView;
@end

@interface TextMessageCellView : CommonMessageCellView @end
@interface AppMessageCellView : CommonMessageCellView @end
@interface WCPayTransferMessageCellView : CommonMessageCellView @end

@interface MMMenuItem : UIMenuItem
- (instancetype)initWithTitle:(NSString *)title icon:(UIImage *)icon target:(id)target action:(SEL)action;
@end

@interface TimeoutNumber : UIView
- (void)updateNumber:(unsigned long long)number;
@end

@interface WCPayWalletEntryHeaderView : UIView
@property (retain, nonatomic) TimeoutNumber *timeoutNumber;
@property (retain, nonatomic) UIView *balanceEntryView;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface WCDataItem : NSObject
- (unsigned int)stepCount;
@end

@interface MMUILabel : UILabel @end

#pragma mark - 配置管理（接口声明）

// 功能开关配置键
static NSString * const kDDFeatureJokerEnabled = @"DDFeatureJokerEnabled";
static NSString * const kDDFeatureWalletEnabled = @"DDFeatureWalletEnabled";
static NSString * const kDDFeatureStepsEnabled = @"DDFeatureStepsEnabled";
static NSString * const kDDFeatureContactsEnabled = @"DDFeatureContactsEnabled";

// 存储键
static NSString * const kDDStepsValueStringKey = @"DDStepsValueString";
static NSString * const kDDContactsCountValueKey = @"DDContactsCountValue";
static NSString * const kDDLastStepsUpdateDateKey = @"DDLastStepsUpdateDate";
static NSString * const kDDCustomBalanceKey = @"DD_Custom_Balance_Fen";

@interface DDGlobalConfig : NSObject
+ (instancetype)shared;
@property (nonatomic) BOOL jokerEnabled;
@property (nonatomic) BOOL walletEnabled;
@property (nonatomic) BOOL stepsEnabled;
@property (nonatomic) BOOL contactsEnabled;
@property (nonatomic, copy) NSString *stepsValueString;
@property (nonatomic, copy) NSString *contactsValue;
- (NSInteger)stepsIntegerValue;
- (BOOL)hasStepsValue;
- (BOOL)hasContactsValue;
- (void)saveSteps;
- (void)saveContacts;
@end

#pragma mark - ① 聊天记录修改

static CMessageWrap *JokerGetMessageWrapFromCell(CommonMessageCellView *cell) {
    return cell.viewModel.messageWrap;
}

static id JokerGetViewControllerFromView(UIView *view) {
    UIResponder *responder = view;
    while (responder) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

static BOOL JokerIsTextMessage(CMessageWrap *msg) {
    return [msg IsTextMsg];
}

static BOOL JokerIsReferMessage(CMessageWrap *msg) {
    return [msg isReferMsgType];
}

static BOOL JokerIsTransferMessage(CMessageWrap *msg) {
    if (!msg) return NO;
    if ([msg respondsToSelector:@selector(parseWCPayInfoItemIfNeed)]) {
        [msg parseWCPayInfoItemIfNeed];
    }
    WCPayInfoItem *payInfo = msg.m_oWCPayInfoItem;
    if (!payInfo) return NO;
    return (payInfo.m_uiPaySubType == 3 || payInfo.m_uiPaySubType == 4 || payInfo.m_nsTransferID.length > 0);
}

static BOOL JokerIsSupportedMessage(CMessageWrap *msg) {
    return JokerIsTextMessage(msg) || JokerIsReferMessage(msg) || JokerIsTransferMessage(msg);
}

static NSString *JokerGetTransferAmount(CMessageWrap *msg) {
    if (!JokerIsTransferMessage(msg)) return nil;
    [msg parseWCPayInfoItemIfNeed];
    NSString *amount = msg.m_oWCPayInfoItem.m_nsFeeDesc ?: @"";
    if ([amount hasPrefix:@"¥"]) {
        amount = [amount substringFromIndex:1];
    }
    return amount;
}

static NSString *JokerNormalizeAmount(NSString *amount) {
    NSString *trimmed = [amount stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSMutableString *filtered = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if ((c >= '0' && c <= '9') || c == '.') {
            [filtered appendFormat:@"%C", c];
        }
    }
    return filtered.length ? filtered : nil;
}

static void JokerApplyAmountToPayInfo(CMessageWrap *msg, NSString *amount) {
    if (!msg || !amount) return;
    [msg parseWCPayInfoItemIfNeed];
    WCPayInfoItem *payInfo = msg.m_oWCPayInfoItem;
    if (payInfo) {
        NSString *final = [@"¥" stringByAppendingString:amount];
        payInfo.m_nsFeeDesc = final;
        payInfo.m_receiverDesc = final;
        payInfo.m_senderDesc = final;
    }
}

static NSString *JokerGetDisplayText(CMessageWrap *msg) {
    if (JokerIsTextMessage(msg)) return [msg GetDisplayContent];
    if (JokerIsReferMessage(msg)) return msg.m_nsTitle ?: @"";
    if (JokerIsTransferMessage(msg)) return JokerGetTransferAmount(msg);
    return nil;
}

static void JokerReloadCellAfterReplace(id vc, CMessageWrap *msg, CommonMessageCellView *cell) {
    if (!vc || !msg) return;
    if ([vc respondsToSelector:@selector(clearNodeLayoutCache)]) {
        [vc clearNodeLayoutCache];
    }
    if ([vc respondsToSelector:@selector(reloadNodeWithMessageWrap:)]) {
        [vc reloadNodeWithMessageWrap:msg];
    }
    if ([vc respondsToSelector:@selector(reloadVisibleNodeWithCellView:)]) {
        [vc reloadVisibleNodeWithCellView:cell];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![vc respondsToSelector:@selector(getMsgTableView)]) return;
        UITableView *tv = [vc getMsgTableView];
        if (![tv isKindOfClass:[UITableView class]]) return;
        [UIView performWithoutAnimation:^{
            [tv beginUpdates];
            [tv endUpdates];
        }];
    });
}

static void JokerPresentEditor(CommonMessageCellView *cell) {
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    if (!JokerIsSupportedMessage(msg)) return;
    id vc = JokerGetViewControllerFromView(cell);
    if (!vc) return;
    
    NSString *current = JokerGetDisplayText(msg) ?: @"";
    BOOL isTransfer = JokerIsTransferMessage(msg);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"小丑"
                                                                   message:@"仅当前页面生效，离开后自动恢复"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = current;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        if (isTransfer) {
            tf.keyboardType = UIKeyboardTypeDecimalPad;
            tf.placeholder = @"例如：888.88";
        }
    }];
    __weak typeof(cell) weakCell = cell;
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        typeof(weakCell) strongCell = weakCell;
        NSString *newText = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length && ![newText isEqualToString:current]) {
            if (isTransfer) {
                newText = JokerNormalizeAmount(newText);
                if (!newText) return;
            }
            if (JokerIsTextMessage(msg)) {
                msg.m_nsContent = newText;
            } else if (JokerIsReferMessage(msg)) {
                msg.m_nsTitle = newText;
            } else if (JokerIsTransferMessage(msg)) {
                JokerApplyAmountToPayInfo(msg, newText);
            }
            JokerReloadCellAfterReplace(vc, msg, strongCell);
        }
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

static NSArray *JokerInjectMenuItem(CommonMessageCellView *cell, NSArray *original) {
    if (![DDGlobalConfig shared].jokerEnabled) return original;
    CMessageWrap *msg = JokerGetMessageWrapFromCell(cell);
    if (!JokerIsSupportedMessage(msg)) return original;
    
    Class menuItemClass = NSClassFromString(@"MMMenuItem");
    if (!menuItemClass) return original;
    
    UIImage *icon = [[UIImage systemImageNamed:@"face.smiling.fill"] imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
    MMMenuItem *newItem = [[menuItemClass alloc] initWithTitle:@"小丑" icon:icon target:cell action:@selector(joker_handleMenuItem:)];
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:original];
    [newItems insertObject:newItem atIndex:0];
    return newItems;
}

%hook TextMessageCellView
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].jokerEnabled && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

%hook AppMessageCellView
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].jokerEnabled && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

%hook WCPayTransferMessageCellView
- (NSArray *)operationMenuItems {
    return JokerInjectMenuItem(self, %orig);
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(joker_handleMenuItem:)) {
        return [DDGlobalConfig shared].jokerEnabled && JokerIsSupportedMessage(JokerGetMessageWrapFromCell(self));
    }
    return %orig;
}
%new
- (void)joker_handleMenuItem:(id)sender {
    JokerPresentEditor(self);
}
%end

#pragma mark - ② 钱包零钱修改

static BOOL hasCustomWalletBalance(void) {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDDCustomBalanceKey] != nil;
}

static void saveWalletBalanceFen(unsigned long long fen) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%llu", fen] forKey:kDDCustomBalanceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void clearWalletBalance(void) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDDCustomBalanceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static unsigned long long loadWalletBalanceFen(void) {
    NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:kDDCustomBalanceKey];
    if (!s.length) return 0;
    long long val = [s longLongValue];
    return val > 0 ? (unsigned long long)val : 0;
}

%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)original {
    if ([DDGlobalConfig shared].walletEnabled && hasCustomWalletBalance()) {
        unsigned long long custom = loadWalletBalanceFen();
        %orig(custom);
        return;
    }
    %orig(original);
}

- (void)didMoveToSuperview {
    %orig;
    if (![DDGlobalConfig shared].walletEnabled) return;
    if (self.superview) {
        static const void *kTimeoutNumberLongPressKey = &kTimeoutNumberLongPressKey;
        if (objc_getAssociatedObject(self, kTimeoutNumberLongPressKey)) return;
        self.userInteractionEnabled = YES;
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(wallet_handleLongPress:)];
        lp.minimumPressDuration = 0.5;
        [self addGestureRecognizer:lp];
        objc_setAssociatedObject(self, kTimeoutNumberLongPressKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)wallet_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (![DDGlobalConfig shared].walletEnabled) return;
    
    unsigned long long cur = hasCustomWalletBalance() ? loadWalletBalanceFen() : 0;
    NSString *curYuan = hasCustomWalletBalance() ? [NSString stringWithFormat:@"%.2f", cur / 100.0] : @"";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"小丑"
                                                                   message:@"输入纯数字，留空则恢复真实余额"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = curYuan;
        tf.placeholder = @"例如：888.88";
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) {
            clearWalletBalance();
        } else {
            double yuan = [input doubleValue];
            if (yuan < 0) yuan = 0;
            unsigned long long fen = (unsigned long long)(yuan * 100 + 0.5);
            saveWalletBalanceFen(fen);
        }
        [self updateNumber:0];
    }]];
    UIResponder *resp = self;
    while (resp) {
        if ([resp isKindOfClass:[UIViewController class]]) {
            [(UIViewController *)resp presentViewController:alert animated:YES completion:nil];
            break;
        }
        resp = [resp nextResponder];
    }
}
%end

%hook WCPayWalletEntryHeaderView
- (void)didMoveToSuperview {
    %orig;
    if (![DDGlobalConfig shared].walletEnabled) return;
    if (self.superview && self.balanceEntryView) {
        self.balanceEntryView.userInteractionEnabled = YES;
        static const void *kHeaderLongPressKey = &kHeaderLongPressKey;
        if (objc_getAssociatedObject(self, kHeaderLongPressKey)) return;
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(walletHeader_handleLongPress:)];
        lp.minimumPressDuration = 0.5;
        [self.balanceEntryView addGestureRecognizer:lp];
        objc_setAssociatedObject(self, kHeaderLongPressKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)walletHeader_handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (![DDGlobalConfig shared].walletEnabled) return;
    
    unsigned long long cur = hasCustomWalletBalance() ? loadWalletBalanceFen() : 0;
    NSString *curYuan = hasCustomWalletBalance() ? [NSString stringWithFormat:@"%.2f", cur / 100.0] : @"";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"小丑"
                                                                   message:@"输入纯数字，留空则恢复真实余额"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = curYuan;
        tf.placeholder = @"例如：888.88";
        tf.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *input = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) {
            clearWalletBalance();
        } else {
            double yuan = [input doubleValue];
            if (yuan < 0) yuan = 0;
            unsigned long long fen = (unsigned long long)(yuan * 100 + 0.5);
            saveWalletBalanceFen(fen);
        }
        if (self.timeoutNumber) {
            [self.timeoutNumber updateNumber:0];
        }
    }]];
    UIResponder *resp = self;
    while (resp) {
        if ([resp isKindOfClass:[UIViewController class]]) {
            [(UIViewController *)resp presentViewController:alert animated:YES completion:nil];
            break;
        }
        resp = [resp nextResponder];
    }
}
%end

#pragma mark - ③ 运动步数修改

static BOOL isToday(NSDate *date) {
    if (!date) return NO;
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *dc1 = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    NSDateComponents *dc2 = [cal components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:[NSDate date]];
    return dc1.year == dc2.year && dc1.month == dc2.month && dc1.day == dc2.day;
}

%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kDDLastStepsUpdateDateKey];
        if (!last || !isToday(last)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
        }
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        NSDate *last = [[NSUserDefaults standardUserDefaults] objectForKey:kDDLastStepsUpdateDateKey];
        if (!last || !isToday(last)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
        }
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}
%end

%hook WCDataItem
- (unsigned int)stepCount {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.stepsEnabled && [cfg hasStepsValue]) {
        return (unsigned int)[cfg stepsIntegerValue];
    }
    return %orig;
}
%end

#pragma mark - ④ 好友数量修改

%hook MMUILabel
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    if (cfg.contactsEnabled && [cfg hasContactsValue]) {
        if ([text hasSuffix:@"个朋友"] && [[text substringToIndex:text.length-3] rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
            %orig([NSString stringWithFormat:@"%@个朋友", cfg.contactsValue]);
            return;
        }
    }
    %orig;
}
%end

#pragma mark - 设置界面

@interface DDJokerSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *stepsField;
@property (nonatomic, strong) UITextField *contactsField;
@end

@implementation DDJokerSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD小丑助手";

    // 设置导航栏外观（与 DD微信助手 一致）
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;

    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    _originalDelegate = _tableViewManager.delegate;
    _tableViewManager.delegate = self;

    [self buildTable];
}

// 通用方法：创建右侧输入框+确认按钮
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action placeholder:(NSString *)placeholder text:(NSString *)text {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 30)];
    
    field.frame = CGRectMake(0, 0, 150, 30);
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.placeholder = placeholder;
    field.text = text;
    field.textAlignment = NSTextAlignmentRight;
    field.keyboardType = UIKeyboardTypeNumberPad;
    [container addSubview:field];
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(158, 0, 42, 30);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];
    
    return container;
}

- (void)buildTable {
    [_tableViewManager clearAllSection];
    
    // 更新 footer 提示
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionWithHeader:@"小丑设置"
                                                                                                 Footer:@"聊天记录修改长按消息弹窗菜单小丑按钮（支持文字和转账金额），钱包余额修改长按服务页钱包入口或零钱详情页余额数字修改\n步数和好友数量修改后需重启微信生效"];
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    Class cellCls = objc_getClass("WCTableViewCellManager");
    
    // 1. 聊天记录修改开关
    [section addCell:[cellCls switchCellForSel:@selector(jokerSwitchChanged:) target:self title:@"聊天记录修改" on:cfg.jokerEnabled]];
    
    // 2. 钱包零钱修改开关
    [section addCell:[cellCls switchCellForSel:@selector(walletSwitchChanged:) target:self title:@"钱包零钱修改" on:cfg.walletEnabled]];
    
    // 3. 运动步数开关 + 子项（输入框+确认）
    [section addCell:[cellCls switchCellForSel:@selector(stepsSwitchChanged:) target:self title:@"运动步数修改" on:cfg.stepsEnabled]];
    if (cfg.stepsEnabled) {
        self.stepsField = [[UITextField alloc] init];
        NSString *currentSteps = [cfg hasStepsValue] ? cfg.stepsValueString : @"";
        UIView *rightView = [self inputRowWithField:self.stepsField
                                             action:@selector(stepsConfirm:)
                                        placeholder:@"输入：如88888"
                                               text:currentSteps];
        WCTableViewCellManager *stepsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳步数自定义" rightView:rightView];
        stepsSubCell.userInfo = @"SubCell";
        [section addCell:stepsSubCell];
    }
    
    // 4. 好友数量开关 + 子项（输入框+确认）
    [section addCell:[cellCls switchCellForSel:@selector(contactsSwitchChanged:) target:self title:@"好友数量修改" on:cfg.contactsEnabled]];
    if (cfg.contactsEnabled) {
        self.contactsField = [[UITextField alloc] init];
        NSString *currentContacts = [cfg hasContactsValue] ? cfg.contactsValue : @"";
        UIView *rightView = [self inputRowWithField:self.contactsField
                                             action:@selector(contactsConfirm:)
                                        placeholder:@"输入：如88888"
                                               text:currentContacts];
        WCTableViewCellManager *contactsSubCell = [cellCls normalCellForSel:nil target:nil title:@"↳数量自定义" rightView:rightView];
        contactsSubCell.userInfo = @"SubCell";
        [section addCell:contactsSubCell];
    }
    
    [_tableViewManager addSection:section];
    [_tableViewManager reloadTableView];
}

#pragma mark - UITableViewDelegate 转发

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    WCTableViewCellManager *cellInfo = [self.tableViewManager cellInfoAtIndexPath:indexPath];
    if ([cellInfo.userInfo isEqualToString:@"SubCell"]) {
        cell.indentationLevel = 1;
        cell.indentationWidth = 16.0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    return UITableViewAutomaticDimension;
}

#pragma mark - 开关事件

- (void)jokerSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].jokerEnabled = sender.isOn;
    [self buildTable];
}

- (void)walletSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].walletEnabled = sender.isOn;
    [self buildTable];
}

- (void)stepsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].stepsEnabled = sender.isOn;
    [self buildTable];
}

- (void)contactsSwitchChanged:(UISwitch *)sender {
    [DDGlobalConfig shared].contactsEnabled = sender.isOn;
    [self buildTable];
}

#pragma mark - 输入确认事件

- (void)stepsConfirm:(id)sender {
    NSString *input = self.stepsField.text;
    [self saveStepsInput:input];
    [self buildTable];
}

- (void)contactsConfirm:(id)sender {
    NSString *input = self.contactsField.text;
    [self saveContactsInput:input];
    [self buildTable];
}

#pragma mark - 保存逻辑（输入为空即关闭）

- (void)saveStepsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.stepsValueString = nil; // 关闭
    } else {
        NSInteger val = [trimmed integerValue];
        if (val < 0) val = 0;
        if (val > 100000) val = 100000;
        cfg.stepsValueString = [NSString stringWithFormat:@"%ld", (long)val];
    }
}

- (void)saveContactsInput:(NSString *)input {
    DDGlobalConfig *cfg = [DDGlobalConfig shared];
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        cfg.contactsValue = nil; // 关闭
    } else {
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        if ([trimmed rangeOfCharacterFromSet:nonDigits].location == NSNotFound) {
            cfg.contactsValue = trimmed;
        }
    }
}

@end

#pragma mark - 配置管理（实现）

@implementation DDGlobalConfig

+ (instancetype)shared {
    static DDGlobalConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDGlobalConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
        _jokerEnabled = [def boolForKey:kDDFeatureJokerEnabled];
        _walletEnabled = [def boolForKey:kDDFeatureWalletEnabled];
        _stepsEnabled = [def boolForKey:kDDFeatureStepsEnabled];
        _contactsEnabled = [def boolForKey:kDDFeatureContactsEnabled];
        _stepsValueString = [def stringForKey:kDDStepsValueStringKey];
        _contactsValue = [def stringForKey:kDDContactsCountValueKey];
        if (![def objectForKey:kDDLastStepsUpdateDateKey]) {
            [def setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
            [def synchronize];
        }
    }
    return self;
}

- (void)setJokerEnabled:(BOOL)enabled {
    _jokerEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureJokerEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setWalletEnabled:(BOOL)enabled {
    _walletEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureWalletEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsEnabled:(BOOL)enabled {
    _stepsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureStepsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setContactsEnabled:(BOOL)enabled {
    _contactsEnabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDFeatureContactsEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStepsValueString:(NSString *)stepsValueString {
    _stepsValueString = [stepsValueString copy];
    [self saveSteps];
}

- (void)setContactsValue:(NSString *)contactsValue {
    _contactsValue = [contactsValue copy];
    [self saveContacts];
}

- (NSInteger)stepsIntegerValue {
    if (![self hasStepsValue]) return 0;
    return [_stepsValueString integerValue];
}

- (BOOL)hasStepsValue {
    return _stepsValueString.length > 0;
}

- (BOOL)hasContactsValue {
    return _contactsValue.length > 0;
}

- (void)saveSteps {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_stepsValueString.length) {
        [def setObject:_stepsValueString forKey:kDDStepsValueStringKey];
    } else {
        [def removeObjectForKey:kDDStepsValueStringKey];
    }
    [def setObject:[NSDate date] forKey:kDDLastStepsUpdateDateKey];
    [def synchronize];
}

- (void)saveContacts {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    if (_contactsValue.length) {
        [def setObject:_contactsValue forKey:kDDContactsCountValueKey];
    } else {
        [def removeObjectForKey:kDDContactsCountValueKey];
    }
    [def synchronize];
}

@end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD小丑助手"
                                                      version:@"1.0.0"
                                                   controller:@"DDJokerSettingsViewController"];
        }
    }
}
//
//  DD语音包.xm
//  微信语音包插件
//
//  功能：
//   1. 聊天页长按「+」打开语音包面板
//   2. 语音消息菜单「纳入」，把聊过的语音归档进语音包
//   3. 面板内分层浏览 / 搜索 / 试听，点一条直接发到当前聊天
//   4. 设置页：总开关、持续发送、导入导出语音包目录
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ========== 常量定义 ==========

// UserDefaults key
static NSString * const kDDVoicePackEnabledKey = @"DDVoicePack_Enabled";
static NSString * const kDDVoicePackKeepPanelKey = @"DDVoicePack_KeepPanelAfterSend";

// 语音消息类型 / SILK 格式 / 语音结束标记
static const unsigned int kDDVoicePackMsgTypeVoice = 34;
static const unsigned int kDDVoicePackVoiceFormatSilk = 4;
static const unsigned int kDDVoicePackVoiceEndFlag = 1;

// 语音时长上下限（毫秒），微信只认 0.3s ~ 60s
static const unsigned int kDDVoicePackMinVoiceMs = 300;
static const unsigned int kDDVoicePackMaxVoiceMs = 60000;

// 面板高度 = 屏高 * 该比例
static const CGFloat kDDVoicePackSheetHeightRatio = 0.5;

// 搜索防抖间隔（秒）：逐字符递归整个语音包目录太重
static const NSTimeInterval kDDVoicePackSearchDebounce = 0.3;

// 微信 SILK 文件头：编码出来没有就以 0x02 开头，补上微信才认
static const uint8_t kDDVoicePackSilkHeader[] = { 0x02, '#', '!', 'S', 'I', 'L', 'K', '_', 'V', '3' };

// 关联对象 key
static const void *kDDVoicePackSheetContainerKey = &kDDVoicePackSheetContainerKey;
static const void *kDDVoicePackSheetFromVCKey = &kDDVoicePackSheetFromVCKey;
static const void *kDDVoicePackSheetAdapterKey = &kDDVoicePackSheetAdapterKey;
static const void *kDDVoicePackSheetConfigKey = &kDDVoicePackSheetConfigKey;
static const void *kDDVoicePackCellPathKey = &kDDVoicePackCellPathKey;
static const void *kDDVoicePackPreviewPlayerKey = &kDDVoicePackPreviewPlayerKey;
static const void *kDDVoicePackLongPressKey = &kDDVoicePackLongPressKey;
static const void *kDDVoicePackInputBridgeKey = &kDDVoicePackInputBridgeKey;

// 当前面板的宿主 VC（面板关闭后要通知它），以及待纳入的语音路径
static __weak UIViewController *gDDVoicePackSheetHostVC = nil;
static NSString *gDDVoicePackPendingImportPath = nil;

// ========== 微信内部类声明 ==========

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)serviceClass;
@end

@interface MMThemeManager : NSObject
- (UIImage *)svgImageNamed:(NSString *)name color:(UIColor *)color;
@end

// m_nsUsrName 定义在 CBaseContact 上（CContact 继承它），声明到父类避免误读
@interface CBaseContact : NSObject
- (NSString *)m_nsUsrName;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface CMessageMgr : NSObject
- (void)AddLocalMsg:(id)chatName MsgWrap:(id)msgWrap;
- (void)ModMsg:(id)chatName MsgWrap:(id)msgWrap;
// 首参传 nil：声明是两参，传 NSData 会被当成路径处理
- (BOOL)SaveMesVoice:(id)a0 MsgWrap:(id)a1;
@end

@interface CMessageWrap : NSObject
- (unsigned int)m_uiMessageType;
- (unsigned int)m_uiMesLocalID;
- (NSString *)m_nsFromUsr;
- (NSString *)m_nsToUsr;
- (void)setM_nsFromUsr:(NSString *)from;
- (void)setM_nsToUsr:(NSString *)to;
- (void)setM_uiStatus:(unsigned int)status;
- (void)setM_uiDownloadStatus:(unsigned int)status;
- (void)setM_nsMsgSource:(id)source;
- (void)setM_uiCreateTime:(unsigned int)time;
- (void)UpdateContent:(id)arg;
- (instancetype)initWithMsgType:(long long)type nsFromUsr:(NSString *)usr;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(NSString *)chat MsgWrap:(id)wrap;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
- (void)setM_dtVoice:(id)data;
- (void)setM_uiVoiceTime:(unsigned int)ms;
- (void)setM_uiVoiceFormat:(unsigned int)fmt;
- (void)setM_uiVoiceEndFlag:(unsigned int)flag;
- (void)setM_refMessageWrap:(id)wrap;
@end

@interface CUtility : NSObject
+ (NSString *)GetDocPath;
+ (NSString *)GetPathOfMesAudio:(NSString *)userName LocalID:(unsigned int)localID DocPath:(NSString *)docPath;
@end

@interface SilkAudioPlayer : NSObject
- (BOOL)preparePlayWithFile:(NSString *)path sync:(BOOL)sync;
- (void)playAtTime:(unsigned int)time;
- (void)stop;
@end

@interface MJSilkCodec : NSObject
- (BOOL)initEncoderWithSampleRate:(long long)rate;
- (id)encodeFromPCMData:(NSData *)pcm;
- (void)uninitEncoder;
@end

@interface BaseMsgContentViewController : UIViewController
- (id)GetContact;
@end

@interface MMTipsViewController : UIViewController
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message btnTitle:(NSString *)cancel handler:(id)cancelHandler btnTitle:(NSString *)ok handler:(id)okHandler;
- (void)addTextViewWithMaxLen:(unsigned int)maxLen;
- (id)getTextView;
- (void)setTextFieldDefaultText:(NSString *)text;
- (void)show;
@end

@interface MMPageSheetConfig : NSObject
@property (nonatomic, retain) NSString *title;
@property (nonatomic, assign) BOOL preferredCenterTitleAlignment;
@property (nonatomic, assign) BOOL navHidden;
@property (nonatomic, assign) BOOL isAllowTapBgMaskToClose;
@property (nonatomic, assign) BOOL enableDragToClose;
@property (nonatomic, retain) UIColor *titleColor;
@property (nonatomic, retain) UIColor *navBarBackgroundColor;
@property (nonatomic, retain) UIColor *contentBackgroundColor;
@property (nonatomic, retain) UIColor *maskBackgroundColor;
@property (nonatomic, retain) UIView *navBackButton;
@property (nonatomic, retain) UIView *navLeftButton;
@property (nonatomic, retain) UIView *navRightButton;
@end

@interface MMPageSheetAdapter : NSObject
+ (id)adapterWithViewController:(id)vc height:(double)height;
- (void)setPageSheetConfig:(id)config;
- (void)setDetailViewHeight:(double)h;
@end

@interface MMPageSheetContainerWindowController : UIViewController
- (void)setupWithProvider:(id)provider;
- (void)showPageSheetAnimated:(BOOL)animated parentView:(id)view parentViewController:(id)vc complete:(void (^)(void))block;
- (void)dismissWithAnimated:(BOOL)animated completion:(void (^)(void))block;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
- (void)clearAllSection;
- (void)addSection:(id)section;
- (void)reloadTableView;
- (id)getTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoHeader:(id)header;
+ (id)sectionInfoHeader:(id)header Footer:(id)footer;
- (void)addCell:(id)cell;
@end

// 注意：normalCellForSel:... 的两组变体分散在两个类上，混用会 unrecognized selector：
//   WCTableViewCellManager        -> title:detail:
//   WCTableViewNormalCellManager  -> title:rightValue:accessoryType:
@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title detail:(id)detail;
- (id)getCell;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue accessoryType:(long long)type;
@end

@interface MMUIButton : UIButton
@end

// 微信头文件里 MMMenuItem 直接继承 NSObject（不是 UIMenuItem），且没有 title 的 getter，
// 所以识别菜单项一律走 userInfo 打标记，不要读 title（会 unrecognized selector）
@interface MMMenuItem : NSObject
@property (nonatomic, retain) id userInfo;
- (instancetype)initWithTitle:(NSString *)title svgName:(NSString *)svgName target:(id)target action:(SEL)action;
@end

@interface VoiceMessageCellView : UIView
- (id)getMediaWrap;
- (id)getViewController;
- (NSArray *)operationMenuItems;
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender;
@end

// ========== 配置管理 ==========

@interface DDVoicePackConfig : NSObject
+ (BOOL)enabled;
+ (void)setEnabled:(BOOL)on;
+ (BOOL)keepPanelAfterSend;
+ (void)setKeepPanelAfterSend:(BOOL)on;
@end

@implementation DDVoicePackConfig

+ (BOOL)enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kDDVoicePackEnabledKey];
}
+ (void)setEnabled:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kDDVoicePackEnabledKey];
}

+ (BOOL)keepPanelAfterSend {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kDDVoicePackKeepPanelKey];
}
+ (void)setKeepPanelAfterSend:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kDDVoicePackKeepPanelKey];
}

@end

// ========== 辅助函数 ==========

// 沿用旧版目录：改路径会让用户已有的语音包凭空消失，不值得
static NSString *DDVoicePackRootPath(void) {
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    return [[[library stringByAppendingPathComponent:@"Preferences"] stringByAppendingPathComponent:@"WCVoice"] stringByAppendingPathComponent:@"Voice"];
}

static NSString *DDVoicePackTrim(NSString *text) {
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static void DDVoicePackListDirectory(NSString *dirPath, NSArray<NSString *> **outFolders, NSArray<NSString *> **outFiles) {
    if (outFolders) *outFolders = @[];
    if (outFiles) *outFiles = @[];
    if (!dirPath.length) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) return;

    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:dirPath error:nil]) {
        NSString *full = [dirPath stringByAppendingPathComponent:name];
        BOOL itemIsDir = NO;
        if ([fm fileExistsAtPath:full isDirectory:&itemIsDir] && itemIsDir) [folders addObject:name];
        else [files addObject:name];
    }
    if (outFolders) *outFolders = [folders sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (outFiles) *outFiles = [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSUInteger DDVoicePackFileCountIn(NSString *dirPath) {
    NSArray *folders = nil, *files = nil;
    DDVoicePackListDirectory(dirPath, &folders, &files);
    return files.count;
}

static BOOL DDVoicePackIsSilk(NSString *path) {
    NSString *ext = [[path pathExtension] lowercaseString];
    return [ext isEqualToString:@"silk"] || [ext isEqualToString:@"aud"];
}

static BOOL DDVoicePackIsDecodableAudio(NSString *path) {
    static NSSet *exts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        exts = [NSSet setWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"caf", @"flac", @"mp4", nil];
    });
    return [exts containsObject:[[path pathExtension] lowercaseString]];
}

// 去掉首尾空白和 .silk / .slik 后缀，返回可当文件名的基名
static NSString *DDVoicePackSanitizedName(NSString *raw) {
    NSString *text = DDVoicePackTrim(raw ?: @"");
    NSString *lower = [text lowercaseString];
    if ([lower hasSuffix:@".silk"] || [lower hasSuffix:@".slik"]) {
        text = DDVoicePackTrim([text substringToIndex:text.length - 5]);
    }
    return text.length ? text : nil;
}

static NSString *DDVoicePackBaseName(NSString *path) {
    NSString *name = [path lastPathComponent];
    NSString *ext = [path pathExtension];
    if (ext.length && [name hasSuffix:[@"." stringByAppendingString:ext]]) {
        return [name substringToIndex:name.length - ext.length - 1];
    }
    return name;
}

static NSArray<NSString *> *DDVoicePackSearchFiles(NSString *root, NSString *keyword) {
    if (!keyword.length) return @[];
    NSMutableArray *results = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:root];
    NSString *relativePath = nil;
    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [root stringByAppendingPathComponent:relativePath];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) continue;
        if (!DDVoicePackIsSilk(fullPath) && !DDVoicePackIsDecodableAudio(fullPath)) continue;
        if ([[relativePath lastPathComponent] rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [results addObject:fullPath];
        }
    }
    return [results sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static id DDVoicePackThemeManager(void) {
    id context = [MMContext activeUserContext] ?: [MMContext rootContext];
    return context ? [context getService:objc_getClass("MMThemeManager")] : nil;
}

static UIWindow *DDVoicePackKeyWindow(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    return nil;
}

static UIViewController *DDVoicePackTopVC(void) {
    UIViewController *top = DDVoicePackKeyWindow().rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if ([top isKindOfClass:[UINavigationController class]]) {
        return [(UINavigationController *)top topViewController];
    }
    if ([top isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)top selectedViewController];
        if ([selected isKindOfClass:[UINavigationController class]]) return [(UINavigationController *)selected topViewController];
        return selected;
    }
    return top;
}

// 发送一条语音（实现见「音频处理与发送」区，这里提前声明给面板用）
static void DDVoicePackSendFileAtPath(NSString *path, NSString *chatId);

// ========== 语音预览 ==========

// 两种播放器（SilkAudioPlayer / AVAudioPlayer）都挂在同一个 key 上，停止时按类型分派
static void DDVoicePackStopPreview(id owner) {
    if (!owner) return;
    id player = objc_getAssociatedObject(owner, kDDVoicePackPreviewPlayerKey);
    if (!player) return;
    if ([player isKindOfClass:[AVAudioPlayer class]]) [(AVAudioPlayer *)player stop];
    else if ([player respondsToSelector:@selector(stop)]) ((void (*)(id, SEL))objc_msgSend)(player, @selector(stop));
    objc_setAssociatedObject(owner, kDDVoicePackPreviewPlayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DDVoicePackPlayPreview(id owner, NSString *path) {
    if (!path.length) return;
    DDVoicePackStopPreview(owner);
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

    id player = nil;
    if (DDVoicePackIsSilk(path)) {
        Class cls = objc_getClass("SilkAudioPlayer");
        if (!cls) return;
        SilkAudioPlayer *silkPlayer = [[cls alloc] init];
        [silkPlayer preparePlayWithFile:path sync:NO];
        [silkPlayer playAtTime:0];
        player = silkPlayer;
    } else if (DDVoicePackIsDecodableAudio(path)) {
        AVAudioPlayer *avPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        [avPlayer play];
        player = avPlayer;
    }
    if (player) objc_setAssociatedObject(owner, kDDVoicePackPreviewPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ========== 输入弹窗桥接 ==========

// MMTipsViewController 的回调是 init 参数，block 里还要回头读输入框，
// 直接捕获 tipsVC 会形成 retain 环。桥接对象被 tipsVC 关联持有、弱引用 tipsVC，
// block 再捕获桥接对象，环就断了。
@interface DDVoicePackInputBridge : NSObject
@property (nonatomic, weak) id tipsVC;
@property (nonatomic, copy) void (^onCommit)(NSString *text);
@property (nonatomic, copy) void (^onCancel)(void);
@end

@implementation DDVoicePackInputBridge

- (void)ddvp_commit {
    if (!self.onCommit) return;
    NSString *text = @"";
    if ([self.tipsVC respondsToSelector:@selector(getTextView)]) {
        UITextView *textView = [self.tipsVC getTextView];
        text = textView.text ?: @"";
    }
    self.onCommit(text);
}
- (void)ddvp_cancel {
    if (self.onCancel) self.onCancel();
}

@end

// 弹一个带输入框的提示框，确定时把输入文本交给 onCommit，取消时走 onCancel
static void DDVoicePackShowInput(NSString *title,
                                 NSString *message,
                                 NSString *defaultText,
                                 void (^onCommit)(NSString *text),
                                 void (^onCancel)(void)) {
    Class tipsCls = objc_getClass("MMTipsViewController");
    if (!tipsCls) return;

    DDVoicePackInputBridge *bridge = [[DDVoicePackInputBridge alloc] init];
    bridge.onCommit = onCommit;
    bridge.onCancel = onCancel;

    id tipsVC = [[tipsCls alloc] initWithTitle:title
                                       message:message
                                      btnTitle:@"取消"
                                       handler:^{ [bridge ddvp_cancel]; }
                                      btnTitle:@"确定"
                                       handler:^{ [bridge ddvp_commit]; }];
    bridge.tipsVC = tipsVC;
    objc_setAssociatedObject(tipsVC, kDDVoicePackInputBridgeKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tipsVC addTextViewWithMaxLen:128];
    [tipsVC setTextFieldDefaultText:defaultText ?: @""];
    [tipsVC show];
}

// ========== 语音包列表面板 ==========

@interface DDVoicePackListController : UIViewController <UISearchBarDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSString *directoryPath;
@property (nonatomic, copy) NSArray<NSString *> *folderPaths;
@property (nonatomic, copy) NSArray<NSString *> *filePaths;
@property (nonatomic, copy) NSArray<NSString *> *searchResults;
@property (nonatomic, assign, getter=isSearching) BOOL searching;
@property (nonatomic, strong) id tableProxy;

+ (void)ddvp_setPendingImportPath:(NSString *)path;
+ (NSString *)ddvp_pendingImportPath;
+ (void)ddvp_clearPendingImportPath;
+ (void)ddvp_ensureRootDirectoryExists;
+ (void)ddvp_closeSheetIfNeeded;
+ (void)ddvp_presentFromViewController:(UIViewController *)fromVC;

- (void)ddvp_reloadData;
- (void)ddvp_syncSheetNavigationBar;
- (void)ddvp_updatePlusButton;
- (UIButton *)ddvp_plusButtonWithThemeManager:(id)themeManager color:(UIColor *)color;

// 以下供 DDVoicePackTableProxy 回调
- (NSString *)ddvp_pathAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)ddvp_swipeAllowedAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)ddvp_rowCanPreviewAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_previewItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_deleteItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_renameItemAtIndexPath:(NSIndexPath *)indexPath;

@end

// ========== 表格代理转发 ==========

// WCTableViewManager 自己就是 tableView 的 delegate，这里插一层代理只为吃下左滑相关回调
@interface DDVoicePackTableProxy : NSObject <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) id forwardTarget;
@property (nonatomic, weak) DDVoicePackListController *host;
@end

@implementation DDVoicePackTableProxy

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (sel_isEqual(aSelector, @selector(tableView:canEditRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:editingStyleForRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:commitEditingStyle:forRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:))) {
        return self;
    }
    return self.forwardTarget;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (sel_isEqual(aSelector, @selector(tableView:canEditRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:editingStyleForRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:commitEditingStyle:forRowAtIndexPath:)) ||
        sel_isEqual(aSelector, @selector(tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:))) {
        return YES;
    }
    return [self.forwardTarget respondsToSelector:aSelector];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return ((NSInteger (*)(id, SEL, UITableView *, NSInteger))objc_msgSend)(self.forwardTarget, _cmd, tableView, section);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return ((UITableViewCell *(*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.host ddvp_swipeAllowedAtIndexPath:indexPath]) return YES;
    return ((BOOL (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.host ddvp_swipeAllowedAtIndexPath:indexPath]) {
        return [self.host ddvp_rowCanPreviewAtIndexPath:indexPath] ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
    }
    return ((UITableViewCellEditingStyle (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete && [self.host ddvp_swipeAllowedAtIndexPath:indexPath]) {
        if (![self.host ddvp_rowCanPreviewAtIndexPath:indexPath]) [self.host ddvp_deleteItemAtIndexPath:indexPath];
        return;
    }
    ((void (*)(id, SEL, UITableView *, UITableViewCellEditingStyle, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, style, indexPath);
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self.host ddvp_swipeAllowedAtIndexPath:indexPath]) {
        return ((UISwipeActionsConfiguration *(*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
    }

    __weak typeof(self.host) weakHost = self.host;
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *sourceView, void (^done)(BOOL)) {
        [weakHost ddvp_deleteItemAtIndexPath:indexPath];
        done(YES);
    }];
    UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"重命名" handler:^(UIContextualAction *action, UIView *sourceView, void (^done)(BOOL)) {
        [weakHost ddvp_renameItemAtIndexPath:indexPath];
        done(YES);
    }];

    NSArray *actions = @[deleteAction, renameAction];
    BOOL fullSwipe = YES;
    if ([self.host ddvp_rowCanPreviewAtIndexPath:indexPath]) {
        UIContextualAction *previewAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"试听" handler:^(UIContextualAction *action, UIView *sourceView, void (^done)(BOOL)) {
            [weakHost ddvp_previewItemAtIndexPath:indexPath];
            done(YES);
        }];
        previewAction.backgroundColor = [UIColor systemBlueColor];
        actions = @[deleteAction, renameAction, previewAction];
        fullSwipe = NO;
    }
    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:actions];
    config.performsFirstActionWithFullSwipe = fullSwipe;
    return config;
}

@end

// ========== UIViewController 分类（关闭面板） ==========

@interface UIViewController (DDVoicePackSheet)
- (void)ddvp_dismissVoicePackSheet;
@end

@implementation UIViewController (DDVoicePackSheet)

- (void)ddvp_dismissVoicePackSheet {
    id container = objc_getAssociatedObject(self, kDDVoicePackSheetContainerKey);
    if (!container) return;
    // 试听的声音由列表页 viewWillDisappear 里停，这里只管关面板
    [container dismissWithAnimated:YES completion:nil];
    objc_setAssociatedObject(self, kDDVoicePackSheetContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gDDVoicePackSheetHostVC = nil;
}

@end

// ========== UINavigationController 分类（面板返回） ==========

@interface UINavigationController (DDVoicePackSheet)
- (void)ddvp_voicePackBack:(id)sender;
@end

@implementation UINavigationController (DDVoicePackSheet)

- (void)ddvp_voicePackBack:(id)sender {
    if (self.viewControllers.count > 1) {
        [self popViewControllerAnimated:YES];
        return;
    }
    UIViewController *host = objc_getAssociatedObject(self, kDDVoicePackSheetFromVCKey);
    [host ddvp_dismissVoicePackSheet];
}

@end

// ========== 语音包列表面板实现 ==========

@implementation DDVoicePackListController

#pragma mark - 类方法

+ (void)ddvp_setPendingImportPath:(NSString *)path {
    gDDVoicePackPendingImportPath = [path copy];
}
+ (NSString *)ddvp_pendingImportPath {
    return gDDVoicePackPendingImportPath;
}
+ (void)ddvp_clearPendingImportPath {
    gDDVoicePackPendingImportPath = nil;
}
+ (void)ddvp_ensureRootDirectoryExists {
    [[NSFileManager defaultManager] createDirectoryAtPath:DDVoicePackRootPath() withIntermediateDirectories:YES attributes:nil error:nil];
}
+ (void)ddvp_closeSheetIfNeeded {
    if ([DDVoicePackConfig keepPanelAfterSend]) return;
    [gDDVoicePackSheetHostVC ddvp_dismissVoicePackSheet];
}

+ (void)ddvp_presentFromViewController:(UIViewController *)fromVC {
    if (!fromVC) return;

    DDVoicePackListController *listVC = [[DDVoicePackListController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:listVC];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    Class adapterCls = objc_getClass("MMPageSheetAdapter");
    if (!adapterCls) {
        [fromVC presentViewController:nav animated:YES completion:nil];
        return;
    }

    CGFloat sheetHeight = [UIScreen mainScreen].bounds.size.height * kDDVoicePackSheetHeightRatio;
    id adapter = [adapterCls adapterWithViewController:nav height:sheetHeight];
    if (!adapter) {
        [fromVC presentViewController:nav animated:YES completion:nil];
        return;
    }

    Class configCls = objc_getClass("MMPageSheetConfig");
    MMPageSheetConfig *config = [[configCls alloc] init];
    config.title = @"语音包管理";
    config.preferredCenterTitleAlignment = YES;
    config.navHidden = NO;
    config.isAllowTapBgMaskToClose = YES;
    config.enableDragToClose = YES;
    config.navBarBackgroundColor = [UIColor systemBackgroundColor];
    config.titleColor = [UIColor labelColor];
    config.contentBackgroundColor = [UIColor systemBackgroundColor];
    config.maskBackgroundColor = [UIColor colorWithWhite:0 alpha:0.4];

    UIColor *btnColor = [UIColor labelColor];
    id themeManager = DDVoicePackThemeManager();

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 0, 44, 44);
    [backBtn setImage:[themeManager svgImageNamed:@"arrow_left_regular" color:btnColor] forState:UIControlStateNormal];
    [backBtn addTarget:nav action:@selector(ddvp_voicePackBack:) forControlEvents:UIControlEventTouchUpInside];
    config.navBackButton = backBtn;
    config.navLeftButton = backBtn;
    config.navRightButton = [listVC ddvp_plusButtonWithThemeManager:themeManager color:btnColor];

    objc_setAssociatedObject(nav, kDDVoicePackSheetFromVCKey, fromVC, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(nav, kDDVoicePackSheetAdapterKey, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(nav, kDDVoicePackSheetConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nav.navigationBarHidden = YES;

    [adapter setPageSheetConfig:config];
    [adapter setDetailViewHeight:sheetHeight];

    Class containerCls = objc_getClass("MMPageSheetContainerWindowController");
    id container = [[containerCls alloc] init];
    objc_setAssociatedObject(nav, kDDVoicePackSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(fromVC, kDDVoicePackSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(listVC, kDDVoicePackSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [container setupWithProvider:adapter];
    [container showPageSheetAnimated:YES parentView:nil parentViewController:fromVC complete:nil];
    gDDVoicePackSheetHostVC = fromVC;
}

#pragma mark - 生命周期

- (instancetype)init {
    if (self = [super init]) {
        _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
        _folderPaths = @[];
        _filePaths = @[];
        _searchResults = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    // 面板自带导航栏（MMPageSheetConfig），这里只在非面板形态下补个标题
    if (!objc_getAssociatedObject(self.navigationController, kDDVoicePackSheetConfigKey)) {
        self.title = @"语音包管理";
    }

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索语音包";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];

    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (objc_getAssociatedObject(self.navigationController, kDDVoicePackSheetConfigKey)) {
        self.title = nil;
    }
    [self ddvp_reloadData];
    [self ddvp_syncSheetNavigationBar];
    [self ddvp_updatePlusButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    DDVoicePackStopPreview(self);
    [self.searchBar resignFirstResponder];
}

#pragma mark - 目录与数据

- (NSString *)ddvp_currentDirectory {
    return self.directoryPath.length ? self.directoryPath : DDVoicePackRootPath();
}

- (NSString *)ddvp_sheetTitle {
    return self.directoryPath.length ? [self.directoryPath lastPathComponent] : @"语音包管理";
}

// 面板标题随层级变化，推给 MMPageSheetConfig 才生效
- (void)ddvp_syncSheetNavigationBar {
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    id config = objc_getAssociatedObject(nav, kDDVoicePackSheetConfigKey);
    id adapter = objc_getAssociatedObject(nav, kDDVoicePackSheetAdapterKey);
    if (!config || !adapter) return;
    [config setTitle:[self ddvp_sheetTitle]];
    [adapter setPageSheetConfig:config];
}

// 当前聊天对象：只有从聊天页进来的面板才知道往哪发
- (NSString *)ddvp_targetChatUserName {
    UINavigationController *nav = self.navigationController;
    if (!nav) return nil;
    UIViewController *fromVC = objc_getAssociatedObject(nav, kDDVoicePackSheetFromVCKey);
    if (!fromVC) return nil;

    Class baseMsgCls = objc_getClass("BaseMsgContentViewController");
    if (!baseMsgCls || ![fromVC isKindOfClass:baseMsgCls]) return nil;
    if (![fromVC respondsToSelector:@selector(GetContact)]) return nil;

    CBaseContact *contact = [fromVC GetContact];
    NSString *name = [contact respondsToSelector:@selector(m_nsUsrName)] ? [contact m_nsUsrName] : nil;
    return name.length ? name : nil;
}

- (NSString *)ddvp_pathAtIndexPath:(NSIndexPath *)indexPath {
    if (!indexPath) return nil;
    if (self.searching) {
        NSUInteger row = indexPath.row;
        return row < self.searchResults.count ? self.searchResults[row] : nil;
    }
    NSUInteger row = indexPath.row;
    if (row < self.folderPaths.count) return self.folderPaths[row];
    row -= self.folderPaths.count;
    return row < self.filePaths.count ? self.filePaths[row] : nil;
}

- (BOOL)ddvp_swipeAllowedAtIndexPath:(NSIndexPath *)indexPath {
    return [self ddvp_pathAtIndexPath:indexPath].length > 0;
}

- (BOOL)ddvp_rowCanPreviewAtIndexPath:(NSIndexPath *)indexPath {
    NSString *path = [self ddvp_pathAtIndexPath:indexPath];
    return DDVoicePackIsSilk(path) || DDVoicePackIsDecodableAudio(path);
}

- (void)ddvp_reloadData {
    [self.tableViewMgr clearAllSection];
    WCTableViewSectionManager *section = nil;

    if (self.searching) {
        if (self.searchResults.count) {
            section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:[NSString stringWithFormat:@"%lu 个结果", (unsigned long)self.searchResults.count] Footer:@""];
            for (NSString *path in self.searchResults) {
                [section addCell:[self ddvp_fileCellForPath:path title:[path lastPathComponent]]];
            }
        }
    } else {
        NSString *dirPath = [self ddvp_currentDirectory];
        NSArray *folders = nil, *files = nil;
        DDVoicePackListDirectory(dirPath, &folders, &files);

        NSMutableArray *folderPaths = [NSMutableArray array];
        for (NSString *name in folders) [folderPaths addObject:[dirPath stringByAppendingPathComponent:name]];
        self.folderPaths = folderPaths;

        NSMutableArray *filePaths = [NSMutableArray array];
        for (NSString *name in files) [filePaths addObject:[dirPath stringByAppendingPathComponent:name]];
        self.filePaths = filePaths;

        NSString *header = self.directoryPath.length
            ? [NSString stringWithFormat:@"%lu 条语音", (unsigned long)files.count]
            : [NSString stringWithFormat:@"%lu 个分类", (unsigned long)folders.count];
        section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:header Footer:@""];

        for (NSString *path in self.folderPaths) {
            NSString *detail = [NSString stringWithFormat:@"%lu 个语音", (unsigned long)DDVoicePackFileCountIn(path)];
            id cell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(ddvp_folderRowTapped:)
                                                                        target:self
                                                                         title:[path lastPathComponent]
                                                                        detail:detail];
            objc_setAssociatedObject(cell, kDDVoicePackCellPathKey, path, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [section addCell:cell];
        }
        for (NSString *path in self.filePaths) {
            [section addCell:[self ddvp_fileCellForPath:path title:[path lastPathComponent]]];
        }
    }

    if (section) [self.tableViewMgr addSection:section];
    [[self.tableViewMgr getTableView] reloadData];
    [self ddvp_installTableProxyIfNeeded];
}

- (id)ddvp_fileCellForPath:(NSString *)path title:(NSString *)title {
    id cell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(ddvp_fileRowTapped:)
                                                                       target:self
                                                                        title:title
                                                                   rightValue:@""
                                                                accessoryType:1];
    objc_setAssociatedObject(cell, kDDVoicePackCellPathKey, path, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return cell;
}

- (void)ddvp_installTableProxyIfNeeded {
    UITableView *tableView = [self.tableViewMgr getTableView];
    if ([tableView.delegate isKindOfClass:[DDVoicePackTableProxy class]]) return;

    DDVoicePackTableProxy *proxy = [[DDVoicePackTableProxy alloc] init];
    proxy.forwardTarget = tableView.delegate ?: tableView.dataSource;
    proxy.host = self;
    tableView.delegate = proxy;
    tableView.dataSource = proxy;
    self.tableProxy = proxy;
}

#pragma mark - 行点击

- (void)ddvp_folderRowTapped:(id)sender {
    if (self.searching) return;
    NSString *path = [self ddvp_pathForCellSender:sender];
    if (!path.length) return;

    DDVoicePackListController *child = [[DDVoicePackListController alloc] init];
    child.directoryPath = path;
    [self.navigationController pushViewController:child animated:YES];
}

- (void)ddvp_fileRowTapped:(id)sender {
    NSString *path = [self ddvp_pathForCellSender:sender];
    NSString *chatId = [self ddvp_targetChatUserName];
    if (!path.length || !chatId.length) return;
    DDVoicePackSendFileAtPath(path, chatId);
}

// cell manager 上挂了路径；取不到就退回用 indexPath 反查
- (NSString *)ddvp_pathForCellSender:(id)sender {
    NSString *path = objc_getAssociatedObject(sender, kDDVoicePackCellPathKey);
    if ([path isKindOfClass:[NSString class]] && path.length) return path;

    UITableViewCell *cell = [sender respondsToSelector:@selector(getCell)] ? [sender getCell] : sender;
    if (![cell isKindOfClass:[UITableViewCell class]]) return nil;
    NSIndexPath *indexPath = [[self.tableViewMgr getTableView] indexPathForCell:cell];
    return [self ddvp_pathAtIndexPath:indexPath];
}

#pragma mark - 左滑操作

- (void)ddvp_previewItemAtIndexPath:(NSIndexPath *)indexPath {
    DDVoicePackPlayPreview(self, [self ddvp_pathAtIndexPath:indexPath]);
}

- (void)ddvp_deleteItemAtIndexPath:(NSIndexPath *)indexPath {
    [[NSFileManager defaultManager] removeItemAtPath:[self ddvp_pathAtIndexPath:indexPath] error:nil];
    [self ddvp_refreshAfterMutation];
}

- (void)ddvp_renameItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *oldPath = [self ddvp_pathAtIndexPath:indexPath];
    if (!oldPath.length) return;
    NSString *parent = [oldPath stringByDeletingLastPathComponent];

    __weak typeof(self) weakSelf = self;
    DDVoicePackShowInput(@"重命名", @"请输入新名称", DDVoicePackBaseName(oldPath), ^(NSString *text) {
        [weakSelf ddvp_renameItemAtPath:oldPath parent:parent toName:DDVoicePackTrim(text) indexPath:indexPath];
    }, nil);
}

- (void)ddvp_renameItemAtPath:(NSString *)oldPath
                       parent:(NSString *)parent
                       toName:(NSString *)baseName
                    indexPath:(NSIndexPath *)indexPath {
    NSString *ext = [oldPath pathExtension];
    NSString *newName = ext.length ? [baseName stringByAppendingPathExtension:ext] : baseName;
    NSString *newPath = [parent stringByAppendingPathComponent:newName];

    if (!baseName.length || [[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
        __weak typeof(self) weakSelf = self;
        DDVoicePackShowInput(@"重命名", @"名称无效或已存在，请重新输入", baseName, ^(NSString *text) {
            [weakSelf ddvp_renameItemAtPath:oldPath parent:parent toName:DDVoicePackTrim(text) indexPath:indexPath];
        }, nil);
        return;
    }

    [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:nil];
    [self ddvp_refreshAfterMutation];
}

- (void)ddvp_refreshAfterMutation {
    if (self.searching) [self ddvp_runSearch];
    else [self ddvp_reloadData];
    [self ddvp_syncSheetNavigationBar];
}

#pragma mark - 右上角「+」

- (UIButton *)ddvp_plusButtonWithThemeManager:(id)themeManager color:(UIColor *)color {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 44, 44);
    [btn setImage:[themeManager svgImageNamed:@"plus_regular" color:color] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(ddvp_plusButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

// 根目录或有待纳入语音时才显示「+」，搜索态下让位给「取消」
- (BOOL)ddvp_shouldShowPlusButton {
    if (self.searching) return NO;
    return self.directoryPath.length == 0 || [DDVoicePackListController ddvp_pendingImportPath].length > 0;
}

- (void)ddvp_updatePlusButton {
    UINavigationController *nav = self.navigationController;
    if (!nav || self.searching) return;

    id config = objc_getAssociatedObject(nav, kDDVoicePackSheetConfigKey);
    BOOL show = [self ddvp_shouldShowPlusButton];

    if (config) {
        UIView *rightBtn = show ? [self ddvp_plusButtonWithThemeManager:DDVoicePackThemeManager() color:[UIColor labelColor]] : nil;
        [config setNavRightButton:rightBtn];
        [self ddvp_syncSheetNavigationBar];
        return;
    }
    if (show) {
        UIButton *btn = [self ddvp_plusButtonWithThemeManager:DDVoicePackThemeManager() color:[UIColor labelColor]];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)ddvp_plusButtonTapped {
    if (self.searching) return;

    NSString *root = [self ddvp_currentDirectory];
    NSString *pending = [DDVoicePackListController ddvp_pendingImportPath];

    // 有待纳入的语音时，「+」走命名保存；否则是新建分类
    if (pending.length) {
        [self ddvp_showImportInputToDirectory:root errorMessage:nil];
        return;
    }

    __weak typeof(self) weakSelf = self;
    DDVoicePackShowInput(@"语音包目录", @"请输入新增分类的名称", @"", ^(NSString *text) {
        NSString *name = DDVoicePackTrim(text);
        if (name.length) {
            [[NSFileManager defaultManager] createDirectoryAtPath:[root stringByAppendingPathComponent:name]
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        [weakSelf ddvp_reloadData];
    }, nil);
}

- (void)ddvp_showImportInputToDirectory:(NSString *)directory errorMessage:(NSString *)errorMessage {
    __weak typeof(self) weakSelf = self;
    DDVoicePackShowInput(@"纳入语音", errorMessage ?: @"请输入新名称", @"", ^(NSString *text) {
        NSString *baseName = DDVoicePackSanitizedName(text);
        NSString *pending = [DDVoicePackListController ddvp_pendingImportPath];
        NSString *destPath = [directory stringByAppendingPathComponent:[baseName stringByAppendingPathExtension:@"silk"]];

        if (!baseName.length || [[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
            [weakSelf ddvp_showImportInputToDirectory:directory errorMessage:@"名称无效或已存在，请重新输入"];
            return;
        }

        [[NSFileManager defaultManager] copyItemAtPath:pending toPath:destPath error:nil];
        [DDVoicePackListController ddvp_clearPendingImportPath];
        [weakSelf ddvp_reloadData];
        [weakSelf ddvp_updatePlusButton];
    }, ^{
        // 取消纳入就把待办清掉，否则「+」会一直停在导入态
        [DDVoicePackListController ddvp_clearPendingImportPath];
        [weakSelf ddvp_updatePlusButton];
    });
}

#pragma mark - 搜索

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searching = YES;
    self.searchResults = @[];
    [self ddvp_reloadData];

    id config = objc_getAssociatedObject(self.navigationController, kDDVoicePackSheetConfigKey);
    if (config) {
        UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
        [cancelBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        cancelBtn.titleLabel.font = [UIFont systemFontOfSize:17];
        [cancelBtn sizeToFit];
        [cancelBtn addTarget:self action:@selector(ddvp_searchCancelTapped) forControlEvents:UIControlEventTouchUpInside];
        [config setNavRightButton:cancelBtn];
        [self ddvp_syncSheetNavigationBar];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // 每敲一个字符就递归整个语音包目录太重，防抖一下
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ddvp_runSearch) object:nil];
    [self performSelector:@selector(ddvp_runSearch) withObject:nil afterDelay:kDDVoicePackSearchDebounce];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)ddvp_searchCancelTapped {
    self.searching = NO;
    self.searchResults = @[];
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self ddvp_updatePlusButton];
    [self ddvp_reloadData];
}

- (void)ddvp_runSearch {
    NSString *keyword = DDVoicePackTrim(self.searchBar.text);
    self.searchResults = keyword.length ? DDVoicePackSearchFiles(DDVoicePackRootPath(), keyword) : @[];
    [self ddvp_reloadData];
}

@end

// ========== 音频处理与发送 ==========

static unsigned int DDVoicePackDurationMs(NSString *path) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    CMTime duration = asset.duration;
    if (CMTIME_IS_NUMERIC(duration) && !CMTIME_IS_INDEFINITE(duration)) {
        Float64 seconds = CMTimeGetSeconds(duration);
        if (seconds > 0 && seconds < 3600) return (unsigned int)llround(seconds * 1000);
    }
    // SILK 不是 AVFoundation 认的格式，读不出时长时按文件大小粗估
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long fileSize = [attrs fileSize];
    if (fileSize > 0) return (unsigned int)(fileSize / 2000) * 1000;
    return 3000;
}

static NSData *DDVoicePackDecodeToPCM(NSString *path) {
    AVAudioFile *inFile = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:path] error:nil];
    if (!inFile) return nil;

    AVAudioFormat *inFormat = inFile.processingFormat;
    AVAudioFormat *outFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:YES];
    AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inFormat toFormat:outFormat];

    __block BOOL inputEOF = NO;
    AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer *(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
        if (inputEOF) {
            *outStatus = AVAudioConverterInputStatus_EndOfStream;
            return nil;
        }
        AVAudioPCMBuffer *inBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:inFormat frameCapacity:8192];
        if (![inFile readIntoBuffer:inBuffer error:nil] || inBuffer.frameLength == 0) {
            inputEOF = YES;
            *outStatus = AVAudioConverterInputStatus_EndOfStream;
            return nil;
        }
        *outStatus = AVAudioConverterInputStatus_HaveData;
        return inBuffer;
    };

    NSMutableData *pcm = [NSMutableData data];
    while (YES) {
        AVAudioPCMBuffer *outBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outFormat frameCapacity:16384];
        AVAudioConverterOutputStatus status = [converter convertToBuffer:outBuffer error:nil withInputFromBlock:inputBlock];
        if (outBuffer.frameLength) {
            [pcm appendBytes:outBuffer.audioBufferList->mBuffers[0].mData length:outBuffer.audioBufferList->mBuffers[0].mDataByteSize];
        }
        if (status == AVAudioConverterOutputStatus_EndOfStream || outBuffer.frameLength == 0) break;
    }
    return pcm;
}

static NSData *DDVoicePackEncodeSilk(NSData *pcm) {
    Class codecCls = objc_getClass("MJSilkCodec");
    if (!codecCls) return nil;
    MJSilkCodec *codec = [[codecCls alloc] init];
    [codec initEncoderWithSampleRate:16000];
    NSData *silk = [codec encodeFromPCMData:pcm];
    [codec uninitEncoder];
    return silk;
}

static NSData *DDVoicePackWithWeChatSilkHeader(NSData *silk) {
    if (!silk.length) return silk;
    const uint8_t *bytes = (const uint8_t *)silk.bytes;
    if (bytes[0] == 0x02) return silk;
    NSMutableData *out = [NSMutableData dataWithBytes:kDDVoicePackSilkHeader length:sizeof(kDDVoicePackSilkHeader)];
    [out appendData:silk];
    return out;
}

// SILK / AUD 直接用；其余格式先转 16k 单声道 PCM 再编 SILK
static NSData *DDVoicePackSilkPayload(NSString *path, unsigned int *outDurationMs) {
    unsigned int durationMs = DDVoicePackDurationMs(path);
    if (outDurationMs) *outDurationMs = durationMs;

    if (DDVoicePackIsSilk(path)) return [NSData dataWithContentsOfFile:path];

    NSData *pcm = DDVoicePackDecodeToPCM(path);
    if (!pcm.length) return nil;
    return DDVoicePackWithWeChatSilkHeader(DDVoicePackEncodeSilk(pcm));
}

static BOOL DDVoicePackSendSilk(NSData *silk, unsigned int durationMs, NSString *chatId) {
    if (!silk.length || !chatId.length) return NO;

    unsigned int voiceMs = durationMs;
    if (voiceMs < kDDVoicePackMinVoiceMs) voiceMs = kDDVoicePackMinVoiceMs;
    if (voiceMs > kDDVoicePackMaxVoiceMs) voiceMs = kDDVoicePackMaxVoiceMs;

    id context = [MMContext activeUserContext] ?: [MMContext rootContext];
    if (!context) return NO;

    CBaseContact *selfContact = [[context getService:objc_getClass("CContactMgr")] getSelfContact];
    NSString *myId = [selfContact respondsToSelector:@selector(m_nsUsrName)] ? [selfContact m_nsUsrName] : nil;
    if (!myId.length) return NO;

    CMessageWrap *msg = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:(long long)kDDVoicePackMsgTypeVoice nsFromUsr:myId];
    if (!msg) return NO;
    [msg setM_nsFromUsr:myId];
    [msg setM_nsToUsr:chatId];
    [msg setM_uiStatus:1];
    [msg setM_uiDownloadStatus:9];
    [msg setM_nsMsgSource:nil];
    [msg setM_uiCreateTime:[[context getService:objc_getClass("MMNewSessionMgr")] GenSendMsgTime]];

    CMessageMgr *msgMgr = [context getService:objc_getClass("CMessageMgr")];
    [msgMgr AddLocalMsg:chatId MsgWrap:msg];

    NSString *docPath = [CUtility GetDocPath];
    NSString *audioPath = [CUtility GetPathOfMesAudio:chatId LocalID:[msg m_uiMesLocalID] DocPath:docPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[audioPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [silk writeToFile:audioPath atomically:YES];

    // 告诉微信音频落在哪（DD语音助手验证过的步骤）。
    // 该方法在微信头文件里查无此物，加 respondsToSelector 保护：有就设，没有就跳过，别崩。
    SEL voicePathSel = NSSelectorFromString(@"setM_nsVoicePath:");
    if (audioPath.length && [msg respondsToSelector:voicePathSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(msg, voicePathSel, audioPath);
    }

    // 语音时长 / 格式 / 数据一律装 extInfo。CMessageWrap 上没有
    // setM_uiVoiceTime: / setM_uiVoiceFormat: / setM_dtVoice:，
    // 这几个只存在于 UploadVoiceWrap、MassSendWrap、CExtendInfoOfVoiceMsg 上，硬调会崩。
    CExtendInfoOfVoiceMsg *extInfo = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [extInfo setM_dtVoice:silk];
    [extInfo setM_uiVoiceTime:voiceMs];
    [extInfo setM_uiVoiceFormat:kDDVoicePackVoiceFormatSilk];
    [extInfo setM_uiVoiceEndFlag:kDDVoicePackVoiceEndFlag];
    [extInfo setM_refMessageWrap:msg];
    SEL extSel = NSSelectorFromString(@"setM_extendInfoWithMsgType:");
    if ([msg respondsToSelector:extSel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(msg, extSel, extInfo);
    }

    [msg UpdateContent:nil];
    [msgMgr ModMsg:chatId MsgWrap:msg];
    // 落盘：首参传 nil（传 NSData 会被当成路径）
    [msgMgr SaveMesVoice:nil MsgWrap:msg];

    // 上传：AudioSender 是微信语音发送链路上的服务对象，ResendVoiceMsg:MsgWrap: 是唯一入口。
    // 不再 KVC 取 m_upload（取不到会抛 NSUndefinedKeyException 直接崩），也不再退 MMNewUploadVoiceMgr。
    AudioSender *sender = [context getService:objc_getClass("AudioSender")];
    if (![sender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) return NO;
    [sender ResendVoiceMsg:chatId MsgWrap:msg];
    return YES;
}

// 转码（PCM + SILK 编码）耗时，长语音在主线程会卡住界面，丢串行队列里跑
static dispatch_queue_t DDVoicePackSendQueue(void) {
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.dd.voicepack.send", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static void DDVoicePackSendFileAtPath(NSString *path, NSString *chatId) {
    if (!path.length || !chatId.length) return;
    NSString *filePath = [path copy];
    NSString *targetChat = [chatId copy];

    dispatch_async(DDVoicePackSendQueue(), ^{
        unsigned int durationMs = 0;
        NSData *silk = DDVoicePackSilkPayload(filePath, &durationMs);
        if (!silk.length) return;
        // SILK 估不出时长时给个 3 秒兜底
        if (durationMs < 500) durationMs = 3000;

        if (DDVoicePackSendSilk(silk, durationMs, targetChat)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DDVoicePackListController ddvp_closeSheetIfNeeded];
            });
        }
    });
}

// ========== Hook 长按「+」按钮打开语音包 ==========

%hook MMUIButton

- (void)didMoveToSuperview {
    %orig;
    if (![DDVoicePackConfig enabled]) return;
    if (![self.accessibilityLabel isEqualToString:@"更多"]) return;

    if (objc_getAssociatedObject(self, kDDVoicePackLongPressKey)) return;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ddvp_moreLongPress:)];
    longPress.minimumPressDuration = 1.0;
    [self addGestureRecognizer:longPress];
    objc_setAssociatedObject(self, kDDVoicePackLongPressKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)ddvp_moreLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    [DDVoicePackListController ddvp_presentFromViewController:DDVoicePackTopVC()];
}

%end

// ========== Hook 语音消息菜单「纳入」 ==========

// 菜单项去重标记：MMMenuItem 没有 title / action 的 getter，只能用 userInfo 做记号
static NSString *DDVoicePackMenuToken(SEL action) {
    return [@"ddvp:" stringByAppendingString:NSStringFromSelector(action)];
}

// 往菜单末尾追加一项（开关关闭 / 已注入过则原样返回）
static NSArray *DDVoicePackAppendMenuItem(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    if (!enabled || !original) return original;

    NSString *token = DDVoicePackMenuToken(action);
    for (id item in original) {
        if (![item respondsToSelector:@selector(userInfo)]) continue;
        id userInfo = [item userInfo];
        if ([userInfo isKindOfClass:[NSString class]] && [(NSString *)userInfo isEqualToString:token]) return original;
    }

    MMMenuItem *item = [[objc_getClass("MMMenuItem") alloc] initWithTitle:title
                                                                svgName:@"biz_audio_outlined_star"
                                                                 target:cell
                                                                 action:action];
    if (!item) return original;
    item.userInfo = token;

    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];
    return items;
}

static BOOL DDVoicePackIsVoiceMessageWrap(id wrap) {
    return [wrap respondsToSelector:@selector(m_uiMessageType)] && [wrap m_uiMessageType] == kDDVoicePackMsgTypeVoice;
}

%hook VoiceMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    return DDVoicePackAppendMenuItem(self, items,
                                     [DDVoicePackConfig enabled] && DDVoicePackIsVoiceMessageWrap([self getMediaWrap]),
                                     @"纳入", @selector(ddvp_importVoice:));
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(ddvp_importVoice:)) {
        return [DDVoicePackConfig enabled] && DDVoicePackIsVoiceMessageWrap([self getMediaWrap]);
    }
    // %orig 独占一行：Logos 对行尾内容的处理很糙，跟其他语句写同一行容易出编译错
    BOOL origResult = %orig;
    return origResult;
}

%new
- (void)ddvp_importVoice:(id)sender {
    CMessageWrap *msg = [self getMediaWrap];
    if (!msg) return;

    // 语音文件在微信沙箱里的落盘路径，跟发送时用的一套算法
    BOOL fromSelf = [CMessageWrap isSenderFromMsgWrap:msg];
    NSString *chat = fromSelf ? [msg m_nsToUsr] : [msg m_nsFromUsr];
    if (!chat.length) return;

    NSString *path = [CUtility GetPathOfMesAudio:chat LocalID:[msg m_uiMesLocalID] DocPath:[CUtility GetDocPath]];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return;

    [DDVoicePackListController ddvp_setPendingImportPath:path];

    UIViewController *fromVC = [self respondsToSelector:@selector(getViewController)] ? [self getViewController] : nil;
    if (!fromVC) {
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                fromVC = (UIViewController *)responder;
                break;
            }
        }
    }
    if (fromVC) [DDVoicePackListController ddvp_presentFromViewController:fromVC];
    else [DDVoicePackListController ddvp_clearPendingImportPath];
}

%end

// ========== 设置界面 ==========

@interface DDVoicePackSettingsViewController : UIViewController <UIDocumentPickerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDVoicePackSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"语音包设置";

    // 表格整屏延伸，由 viewDidLayoutSubviews 推到导航栏底边
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_tableViewManager.tableView];

    [self ddvp_buildTable];
    self.view.backgroundColor = _tableViewManager.tableView.backgroundColor;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _tableViewManager.tableView.frame = CGRectMake(0, top, w, h - top);
}

- (void)ddvp_buildTable {
    [_tableViewManager clearAllSection];

    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"语音包设置（长按 + 打开入口）"];
    BOOL enabled = [DDVoicePackConfig enabled];
    [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onEnabledSwitchChanged:) target:self title:@"启用语音包" on:enabled]];
    if (enabled) {
        [section addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(onKeepPanelSwitchChanged:) target:self title:@"↳持续发送" on:[DDVoicePackConfig keepPanelAfterSend]]];
    }
    [_tableViewManager addSection:section];

    WCTableViewSectionManager *ioSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"数据管理"];
    [ioSection addCell:[objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(importVoicePack) target:self title:@"导入语音包" rightValue:@"" accessoryType:1]];
    [ioSection addCell:[objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(exportVoicePack) target:self title:@"导出语音包" rightValue:@"" accessoryType:1]];
    [_tableViewManager addSection:ioSection];

    [_tableViewManager reloadTableView];
}

- (void)onEnabledSwitchChanged:(UISwitch *)sender {
    [DDVoicePackConfig setEnabled:sender.isOn];
    if (sender.isOn) [DDVoicePackListController ddvp_ensureRootDirectoryExists];
    [self ddvp_buildTable];
}

- (void)onKeepPanelSwitchChanged:(UISwitch *)sender {
    [DDVoicePackConfig setKeepPanelAfterSend:sender.isOn];
}

#pragma mark - 导入导出

- (void)importVoicePack {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder, UTTypeAudio] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)exportVoicePack {
    NSURL *voiceDirURL = [NSURL fileURLWithPath:DDVoicePackRootPath() isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:voiceDirURL withIntermediateDirectories:YES attributes:nil error:nil];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[voiceDirURL] asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSString *destRoot = DDVoicePackRootPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:destRoot withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSURL *url in urls) [self ddvp_copyItemAtURL:url toDirectory:destRoot];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (void)ddvp_copyItemAtURL:(NSURL *)srcURL toDirectory:(NSString *)destDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    [fm fileExistsAtPath:srcURL.path isDirectory:&isDir];

    if (!isDir) {
        NSString *dstPath = [destDir stringByAppendingPathComponent:[srcURL lastPathComponent]];
        [fm removeItemAtPath:dstPath error:nil];
        [fm copyItemAtPath:srcURL.path toPath:dstPath error:nil];
        return;
    }
    for (NSURL *itemURL in [fm contentsOfDirectoryAtURL:srcURL includingPropertiesForKeys:nil options:0 error:nil]) {
        NSString *dstPath = [destDir stringByAppendingPathComponent:[itemURL lastPathComponent]];
        [fm removeItemAtPath:dstPath error:nil];
        [fm copyItemAtURL:itemURL toURL:[NSURL fileURLWithPath:dstPath] error:nil];
    }
}

@end

// ========== 插件注册 ==========

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if ([mgr respondsToSelector:@selector(sharedInstance)]) {
            id instance = [mgr sharedInstance];
            if ([instance respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
                [instance registerControllerWithTitle:@"DD语音包"
                                              version:@"1.0.0"
                                           controller:@"DDVoicePackSettingsViewController"];
            }
        }
    }
}

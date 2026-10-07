//
//  DDVoice.txt
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
#import <objc/runtime.h>
#import <objc/message.h>

// ========== 微信内部类声明 ==========

// 微信头文件 dump 里没有这个类，接口按 DD消息助手的写法声明
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

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
- (void)setM_nsToUsr:(NSString *)to;
- (void)setM_uiStatus:(unsigned int)status;
- (void)setM_uiDownloadStatus:(unsigned int)status;
- (void)setM_nsMsgSource:(id)source;
- (void)setM_uiCreateTime:(unsigned int)time;
- (void)UpdateContent:(id)arg;
- (void)setM_extendInfoWithMsgType:(id)info;
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
@property (nonatomic, readonly) UITableView *tableView;
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
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)rightValue accessoryType:(long long)type;
@end

// 注意：dump 出来的父类经常失真（MMUIButton、VoiceMessageCellView 都被写成 : NSObject，
// 实际一个是 UIButton 子类、一个是 UIView 子类，从它们带着 setFrame:/intrinsicContentSize 能看出来）。
// 所以下面该写 UIButton / UIViewController 的就照真实继承写，别照 dump 抄 NSObject。
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

// 微信内的 zip 工具，编译期只提供 selector 声明，运行期 objc_getClass 取，不产生链接符号
@interface DDVoicePackZipArchive : NSObject
+ (BOOL)createZipFileAtPath:(id)zipPath withContentsOfDirectory:(id)dir keepParentDirectory:(BOOL)keep;
+ (BOOL)unzipFileAtPath:(id)zipPath toDestination:(id)dest;
@end

// 打包整个目录，zip 内保留该目录名（和 DD模板套壳一致）
static BOOL DDVoicePackZipDirectory(NSString *srcDir, NSString *zipPath) {
    return [objc_getClass("QSSZipArchive") createZipFileAtPath:zipPath
                                      withContentsOfDirectory:srcDir
                                          keepParentDirectory:YES];
}

// 解包 zip 到目录
static BOOL DDVoicePackUnzipToDirectory(NSString *zipPath, NSString *destDir) {
    return [objc_getClass("QSSZipArchive") unzipFileAtPath:zipPath toDestination:destDir];
}

// 临时目录：打包/解压的中间暂存，用 UUID 隔离避免互相污染
static NSString *DDVoicePackTempRoot(void) {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[@"DDVoicePack_" stringByAppendingString:[NSUUID UUID].UUIDString]];
}

// ========== 配置管理 ==========

// UserDefaults key
static NSString * const kDDVoicePackEnabledKey = @"DDVoicePack_Enabled";
static NSString * const kDDVoicePackKeepPanelKey = @"DDVoicePack_KeepPanelAfterSend";

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

// 语音包根目录。放 Library/Preferences 下，和 DD模板套壳对齐：
// 微信「清理缓存」会清 Documents，但动不了 Preferences，语音不会丢；且不进 iCloud、不在文件 App 暴露
static NSString *DDVoicePackRootPath(void) {
    NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *pref = [library stringByAppendingPathComponent:@"Preferences"];
    return [[pref stringByAppendingPathComponent:@"DDVoicePack"] stringByAppendingPathComponent:@"Voice"];
}

static NSString *DDVoicePackTrim(NSString *text) {
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 语音包只认 SILK。.silk 是标准扩展名，.aud 是微信缓存语音用的（同一个 SILK 容器）
static BOOL DDVoicePackIsSilk(NSString *path) {
    NSString *ext = [[path pathExtension] lowercaseString];
    return [ext isEqualToString:@"silk"] || [ext isEqualToString:@"aud"];
}

// 列出一层目录：文件夹归 folders，SILK 文件归 files。
// 跳过隐藏文件（.DS_Store 之类）和认不出的格式——列出来点了也是静默失败
static void DDVoicePackListDirectory(NSString *dirPath, NSArray<NSString *> **outFolders, NSArray<NSString *> **outFiles) {
    if (!dirPath.length) return;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) return;

    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:dirPath error:nil]) {
        if ([name hasPrefix:@"."]) continue;
        NSString *full = [dirPath stringByAppendingPathComponent:name];
        BOOL itemIsDir = NO;
        if (![fm fileExistsAtPath:full isDirectory:&itemIsDir]) continue;
        if (itemIsDir) {
            [folders addObject:name];
        } else if (DDVoicePackIsSilk(full)) {
            [files addObject:name];
        }
    }
    if (outFolders) *outFolders = [folders sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (outFiles) *outFiles = [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSUInteger DDVoicePackFileCountIn(NSString *dirPath) {
    NSArray *files = nil;
    DDVoicePackListDirectory(dirPath, NULL, &files);
    return files.count;
}

// 去扩展名，重命名时当输入框的默认值
static NSString *DDVoicePackBaseName(NSString *path) {
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

static NSArray<NSString *> *DDVoicePackSearchFiles(NSString *root, NSString *keyword) {
    NSMutableArray *results = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:root];
    NSString *relativePath = nil;
    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [root stringByAppendingPathComponent:relativePath];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) continue;
        if (!DDVoicePackIsSilk(fullPath)) continue;
        if ([[relativePath lastPathComponent] rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [results addObject:fullPath];
        }
    }
    return [results sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static id DDVoicePackThemeManager(void) {
    // 微信内部类一律用 objc_getClass 拿，直接写类名会让链接器找符号
    Class ctxCls = objc_getClass("MMContext");
    id context = [ctxCls activeUserContext] ?: [ctxCls rootContext];
    return [context getService:objc_getClass("MMThemeManager")];
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

// 试听只走微信的 SilkAudioPlayer，挂在宿主上，下次播放前先停掉上一个
static const void *kDDVoicePackPreviewPlayerKey = &kDDVoicePackPreviewPlayerKey;

static void DDVoicePackStopPreview(id owner) {
    if (!owner) return;
    SilkAudioPlayer *player = objc_getAssociatedObject(owner, kDDVoicePackPreviewPlayerKey);
    [player stop];
    objc_setAssociatedObject(owner, kDDVoicePackPreviewPlayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void DDVoicePackPlayPreview(id owner, NSString *path) {
    DDVoicePackStopPreview(owner);
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

    Class cls = objc_getClass("SilkAudioPlayer");
    SilkAudioPlayer *player = [[cls alloc] init];
    [player preparePlayWithFile:path sync:NO];
    [player playAtTime:0];
    objc_setAssociatedObject(owner, kDDVoicePackPreviewPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ========== 输入弹窗桥接 ==========

// 桥接对象挂在 tipsVC 上保活
static const void *kDDVoicePackInputBridgeKey = &kDDVoicePackInputBridgeKey;

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
    UITextView *textView = [self.tipsVC getTextView];
    self.onCommit(textView.text ?: @"");
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
    [tipsVC addTextViewWithMaxLen:30];
    [tipsVC setTextFieldDefaultText:defaultText ?: @""];
    [tipsVC show];
}

// ========== 语音包列表面板 ==========

// 面板高度 = 屏高 * 该比例（固定，不随内容自适应）
static const CGFloat kDDVoicePackSheetHeightRatio = 0.6;

// 面板相关：container 挂 fromVC（关面板时从它身上取），adapter / config 挂 nav
static const void *kDDVoicePackSheetContainerKey = &kDDVoicePackSheetContainerKey;
static const void *kDDVoicePackSheetFromVCKey = &kDDVoicePackSheetFromVCKey;
static const void *kDDVoicePackSheetAdapterKey = &kDDVoicePackSheetAdapterKey;
static const void *kDDVoicePackSheetConfigKey = &kDDVoicePackSheetConfigKey;
// cell manager 上挂它对应的文件 / 目录路径
static const void *kDDVoicePackCellPathKey = &kDDVoicePackCellPathKey;

// 当前面板的宿主 VC（关面板要通知它），以及待纳入的语音路径
static __weak UIViewController *gDDVoicePackSheetHostVC = nil;
static NSString *gDDVoicePackPendingImportPath = nil;

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
+ (void)ddvp_closeSheetIfNeeded;
+ (void)ddvp_presentFromViewController:(UIViewController *)fromVC;

- (void)ddvp_reloadData;
- (void)ddvp_syncSheetNavigationBar;
- (void)ddvp_updatePlusButton;
- (UIButton *)ddvp_plusButton;
- (void)ddvp_showNewFolderInputToDirectory:(NSString *)directory;
- (void)ddvp_showImportInputToDirectory:(NSString *)directory;

// 以下供 DDVoicePackTableProxy 回调
- (NSString *)ddvp_pathAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)ddvp_swipeAllowedAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)ddvp_rowCanPreviewAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_previewItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_deleteItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_renameItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)ddvp_searchCancelTapped;

@end

// ========== 表格代理转发 ==========

// WCTableViewManager 自己就是 tableView 的 delegate，这里插一层代理只为吃下左滑相关回调
// 代理自己接管的回调（左滑相关），其余全部转发给微信原来的 delegate
static BOOL DDVoicePackProxyOwnsSelector(SEL aSelector) {
    return sel_isEqual(aSelector, @selector(tableView:canEditRowAtIndexPath:)) ||
           sel_isEqual(aSelector, @selector(tableView:editingStyleForRowAtIndexPath:)) ||
           sel_isEqual(aSelector, @selector(tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:)) ||
           sel_isEqual(aSelector, @selector(tableView:shouldIndentWhileEditingRowAtIndexPath:));
}

@interface DDVoicePackTableProxy : NSObject <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) id forwardTarget;
@property (nonatomic, weak) DDVoicePackListController *host;
@end

@implementation DDVoicePackTableProxy

- (id)forwardingTargetForSelector:(SEL)aSelector {
    if (DDVoicePackProxyOwnsSelector(aSelector)) return self;
    return self.forwardTarget;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (DDVoicePackProxyOwnsSelector(aSelector)) return YES;
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
        // 滑动删除已由 trailingSwipeActionsConfiguration 接管，不再返回 Delete 编辑样式，
        // 否则 iOS 叠加「滑动位移 + 编辑内缩」导致右滑收起后内容残留向右偏移。
        return UITableViewCellEditingStyleNone;
    }
    return ((UITableViewCellEditingStyle (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

// 滑动（editing）时不要对 contentView 施加缩进位移，否则左滑露出操作、右滑收起后行会残留向右偏移。
// 我们从不用传统左侧删除按钮，缩进纯属多余，禁用即可从源头消除偏移。
- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.host ddvp_swipeAllowedAtIndexPath:indexPath]) return NO;
    return ((BOOL (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

// 左滑（trailing）统一露出操作：文件行「试听 / 重命名 / 删除」，文件夹行「重命名 / 删除」（文件夹无试听）。
// 不再提供右滑，单一方向更简单。
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

    NSMutableArray *actions = [NSMutableArray arrayWithObjects:deleteAction, renameAction, nil];
    if ([self.host ddvp_rowCanPreviewAtIndexPath:indexPath]) {
        UIContextualAction *previewAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"试听" handler:^(UIContextualAction *action, UIView *sourceView, void (^done)(BOOL)) {
            [weakHost ddvp_previewItemAtIndexPath:indexPath];
            done(YES);
        }];
        previewAction.backgroundColor = [UIColor systemBlueColor];
        [actions addObject:previewAction];
    }

    UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:actions];
    config.performsFirstActionWithFullSwipe = YES;
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
    // 搜索中：左上角返回箭头先充当「取消搜索」，不 pop 也不关面板（A 方案：取消后再点才回上层/关面板）
    DDVoicePackListController *top = (DDVoicePackListController *)self.topViewController;
    if ([top isKindOfClass:[DDVoicePackListController class]] && top.searching) {
        [top ddvp_searchCancelTapped];
        return;
    }
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

// ---- 类方法 ----

+ (void)ddvp_setPendingImportPath:(NSString *)path {
    gDDVoicePackPendingImportPath = [path copy];
}
+ (NSString *)ddvp_pendingImportPath {
    return gDDVoicePackPendingImportPath;
}
+ (void)ddvp_clearPendingImportPath {
    gDDVoicePackPendingImportPath = nil;
}
+ (void)ddvp_closeSheetIfNeeded {
    if ([DDVoicePackConfig keepPanelAfterSend]) return;
    [gDDVoicePackSheetHostVC ddvp_dismissVoicePackSheet];
}

+ (void)ddvp_presentFromViewController:(UIViewController *)fromVC {
    if (!fromVC) return;

    DDVoicePackListController *listVC = [[DDVoicePackListController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:listVC];

    CGFloat sheetHeight = [UIScreen mainScreen].bounds.size.height * kDDVoicePackSheetHeightRatio;
    id adapter = [objc_getClass("MMPageSheetAdapter") adapterWithViewController:nav height:sheetHeight];

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

    id themeManager = DDVoicePackThemeManager();

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 0, 44, 44);
    [backBtn setImage:[themeManager svgImageNamed:@"icons_outlined_back" color:[UIColor labelColor]] forState:UIControlStateNormal];
    [backBtn addTarget:nav action:@selector(ddvp_voicePackBack:) forControlEvents:UIControlEventTouchUpInside];
    config.navLeftButton = backBtn;
    config.navRightButton = [listVC ddvp_plusButton];

    objc_setAssociatedObject(nav, kDDVoicePackSheetFromVCKey, fromVC, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(nav, kDDVoicePackSheetAdapterKey, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(nav, kDDVoicePackSheetConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    nav.navigationBarHidden = YES;

    [adapter setPageSheetConfig:config];
    [adapter setDetailViewHeight:sheetHeight];

    Class containerCls = objc_getClass("MMPageSheetContainerWindowController");
    id container = [[containerCls alloc] init];
    // container 只挂 fromVC：关面板时是从 fromVC 上取的
    objc_setAssociatedObject(fromVC, kDDVoicePackSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [container setupWithProvider:adapter];
    [container showPageSheetAnimated:YES parentView:nil parentViewController:fromVC complete:nil];
    gDDVoicePackSheetHostVC = fromVC;
}

// ---- 生命周期 ----

- (instancetype)init {
    if ((self = [super init])) {
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

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索语音包";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];

    UITableView *tableView = [self.tableViewMgr getTableView];
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
    [self ddvp_reloadData];
    [self ddvp_updatePlusButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    DDVoicePackStopPreview(self);
    [self.searchBar resignFirstResponder];
}

// ---- 目录与数据 ----

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
    [config setTitle:[self ddvp_sheetTitle]];
    [adapter setPageSheetConfig:config];
}

// 当前聊天对象：只有从聊天页进来的面板才知道往哪发
- (NSString *)ddvp_targetChatUserName {
    UINavigationController *nav = self.navigationController;
    if (!nav) return nil;
    UIViewController *fromVC = objc_getAssociatedObject(nav, kDDVoicePackSheetFromVCKey);
    if (!fromVC) return nil;

    // isKindOfClass 已经保证了类型，后面直接取就行，不用再 respondsToSelector
    if (![fromVC isKindOfClass:objc_getClass("BaseMsgContentViewController")]) return nil;

    CBaseContact *contact = [(BaseMsgContentViewController *)fromVC GetContact];
    return contact.m_nsUsrName;
}

- (NSString *)ddvp_pathAtIndexPath:(NSIndexPath *)indexPath {
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
    // 目录列表只列 SILK，所以这里等价于「这一行是文件而不是文件夹」
    return DDVoicePackIsSilk([self ddvp_pathAtIndexPath:indexPath]);
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

// 时长预估函数的前向声明（真正实现在文件后部，发送语音时复用同一份）
static unsigned int DDVoicePackDurationMs(NSString *path);

// 把毫秒格式化成列表副标题：短语音 "3秒"，长语音 "1:05"
static NSString *DDVoicePackFormatDuration(unsigned int ms) {
    unsigned int total = ms / 1000;
    if (total < 60) return [NSString stringWithFormat:@"语音时长：%u秒", total];
    return [NSString stringWithFormat:@"语音时长：%u分%u秒", total / 60, total % 60];
}

- (id)ddvp_fileCellForPath:(NSString *)path title:(NSString *)title {
    NSString *detail = DDVoicePackFormatDuration(DDVoicePackDurationMs(path));
    // 整行点按即发送，绑定 ddvp_fileRowTapped:
    id cell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(ddvp_fileRowTapped:)
                                                                target:self
                                                                 title:title
                                                                 detail:detail];
    objc_setAssociatedObject(cell, kDDVoicePackCellPathKey, path, OBJC_ASSOCIATION_COPY_NONATOMIC);

    // 文件行不需要导航箭头：cell 是 WCTableViewCellManager 封装，经 cellConfig → rightConfig 把 accessoryType 设为 0（无箭头）。
    // WCTableViewCellNormalConfig 必有 rightConfig、rightConfig 必响应 setAccessoryType:，无需 respondsToSelector 守卫。
    id cellConfig = ((id (*)(id, SEL))objc_msgSend)(cell, @selector(cellConfig));
    id rightCfg   = ((id (*)(id, SEL))objc_msgSend)(cellConfig, @selector(rightConfig));
    ((void (*)(id, SEL, unsigned long long))objc_msgSend)(rightCfg, @selector(setAccessoryType:), 0ULL);
    return cell;
}

- (void)ddvp_installTableProxyIfNeeded {
    UITableView *tableView = [self.tableViewMgr getTableView];
    if ([tableView.delegate isKindOfClass:[DDVoicePackTableProxy class]]) return;

    DDVoicePackTableProxy *proxy = [[DDVoicePackTableProxy alloc] init];
    id originalTarget = tableView.delegate;
    proxy.forwardTarget = originalTarget;
    proxy.host = self;
    tableView.delegate = proxy;
    tableView.dataSource = proxy;
    self.tableProxy = proxy;
}

// ---- 行点击 ----

- (void)ddvp_folderRowTapped:(id)sender {
    if (self.searching) return;
    NSString *path = [self ddvp_pathForCellSender:sender];
    DDVoicePackListController *child = [[DDVoicePackListController alloc] init];
    child.directoryPath = path;
    [self.navigationController pushViewController:child animated:YES];
}

// 文件行点按：取关联路径并直接发送到当前聊天
- (void)ddvp_fileRowTapped:(id)sender {
    NSString *path = [self ddvp_pathForCellSender:sender];
    NSString *chatId = [self ddvp_targetChatUserName];
    if (!chatId.length) return;
    DDVoicePackSendFileAtPath(path, chatId);
}

// cell manager 在 reload 时已把路径写到自身关联对象上，点哪行取哪行，无需再用 indexPath 反查
- (NSString *)ddvp_pathForCellSender:(id)sender {
    NSString *path = objc_getAssociatedObject(sender, kDDVoicePackCellPathKey);
    if ([path isKindOfClass:[NSString class]] && path.length) return path;
    return nil;
}

// ---- 左滑操作 ----

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
    DDVoicePackShowInput(@"重命名", @"请输入有效名字", DDVoicePackBaseName(oldPath), ^(NSString *text) {
        [weakSelf ddvp_renameItemAtPath:oldPath parent:parent toName:text indexPath:indexPath];
    }, nil);
}

- (void)ddvp_renameItemAtPath:(NSString *)oldPath
                       parent:(NSString *)parent
                       toName:(NSString *)rawName
                    indexPath:(NSIndexPath *)indexPath {
    // 输入框里只有名字，后缀沿用原文件的
    NSString *baseName = DDVoicePackTrim(rawName);
    // 清空了名字就是放弃，不改名也不提示
    if (!baseName.length) return;

    NSString *newPath = [[parent stringByAppendingPathComponent:baseName]
                         stringByAppendingPathExtension:[oldPath pathExtension]];

    // iOS 文件系统不区分大小写：只改大小写时新旧路径指向同一个文件，不能算「已存在」
    BOOL taken = [[NSFileManager defaultManager] fileExistsAtPath:newPath] &&
                 [newPath caseInsensitiveCompare:oldPath] != NSOrderedSame;
    // 完全同名就不必移动（避免 move 到自己身上）；否则真移动并记录成败
    BOOL moved = [newPath isEqualToString:oldPath] ||
                 [[NSFileManager defaultManager] moveItemAtPath:oldPath toPath:newPath error:nil];

    // 名字被别的文件占用、或移动失败（如名字含 /）都重弹，不静默吞掉
    if (taken || !moved) {
        __weak typeof(self) weakSelf = self;
        DDVoicePackShowInput(@"重命名", @"请输入有效名字", baseName, ^(NSString *text) {
            [weakSelf ddvp_renameItemAtPath:oldPath parent:parent toName:text indexPath:indexPath];
        }, nil);
        return;
    }
    [self ddvp_refreshAfterMutation];
}

- (void)ddvp_refreshAfterMutation {
    if (self.searching) [self ddvp_runSearch];
    else [self ddvp_reloadData];
}

// ---- 右上角「+」 ----

- (UIButton *)ddvp_plusButton {
    id themeManager = DDVoicePackThemeManager();
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 44, 44);
    [btn setImage:[themeManager svgImageNamed:@"icons_outlined_add" color:[UIColor labelColor]] forState:UIControlStateNormal];
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
    if (!nav) return;

    id config = objc_getAssociatedObject(nav, kDDVoicePackSheetConfigKey);
    BOOL show = [self ddvp_shouldShowPlusButton];
    [config setNavRightButton:show ? [self ddvp_plusButton] : nil];
    [self ddvp_syncSheetNavigationBar];
}

- (void)ddvp_plusButtonTapped {
    NSString *root = [self ddvp_currentDirectory];
    NSString *pending = [DDVoicePackListController ddvp_pendingImportPath];

    // 有待纳入的语音时，「+」走命名保存；否则是新建分类
    if (pending.length) {
        [self ddvp_showImportInputToDirectory:root];
        return;
    }

    [self ddvp_showNewFolderInputToDirectory:root];
}

- (void)ddvp_showNewFolderInputToDirectory:(NSString *)directory {
    __weak typeof(self) weakSelf = self;
    DDVoicePackShowInput(@"语音包目录", @"请输入有效名字", @"", ^(NSString *text) {
        NSString *name = DDVoicePackTrim(text);
        // 清空了名字就是放弃
        if (!name.length) return;

        // 名字带 / 会被当成多级路径，建出两级目录
        if ([name rangeOfString:@"/"].location != NSNotFound) {
            [weakSelf ddvp_showNewFolderInputToDirectory:directory];
            return;
        }

        [[NSFileManager defaultManager] createDirectoryAtPath:[directory stringByAppendingPathComponent:name]
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:nil];
        [weakSelf ddvp_reloadData];
    }, nil);
}

- (void)ddvp_showImportInputToDirectory:(NSString *)directory {
    __weak typeof(self) weakSelf = self;
    DDVoicePackShowInput(@"纳入语音", @"请输入有效名字", @"", ^(NSString *text) {
        NSString *baseName = DDVoicePackTrim(text);
        NSString *pending = [DDVoicePackListController ddvp_pendingImportPath];
        NSString *destPath = [directory stringByAppendingPathComponent:[baseName stringByAppendingPathExtension:@"silk"]];

        // 空名、被别的文件占用、复制失败（如名字含 /）都重弹，且不清除待办
        BOOL saved = baseName.length &&
                     ![[NSFileManager defaultManager] fileExistsAtPath:destPath] &&
                     [[NSFileManager defaultManager] copyItemAtPath:pending toPath:destPath error:nil];
        if (!saved) {
            [weakSelf ddvp_showImportInputToDirectory:directory];
            return;
        }
        [DDVoicePackListController ddvp_clearPendingImportPath];
        [weakSelf ddvp_reloadData];
        [weakSelf ddvp_updatePlusButton];
    }, ^{
        // 取消纳入就把待办清掉，否则「+」会一直停在导入态
        [DDVoicePackListController ddvp_clearPendingImportPath];
        [weakSelf ddvp_updatePlusButton];
    });
}

// ---- 搜索 ----

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.searching = YES;
    // 进入搜索后不实时筛选，先清空结果；点键盘「搜索」才出内容并收起键盘
    self.searchResults = @[];
    [self ddvp_reloadData];

    id config = objc_getAssociatedObject(self.navigationController, kDDVoicePackSheetConfigKey);
    // 搜索期间隐藏右上角「+」；取消搜索改由左上角返回箭头兼任（见 ddvp_voicePackBack:）
    [config setNavRightButton:nil];
    [self ddvp_syncSheetNavigationBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self ddvp_runSearch];
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

// 语音消息类型 / SILK 格式 / 语音结束标记
static const unsigned int kDDVoicePackMsgTypeVoice = 34;
static const unsigned int kDDVoicePackVoiceFormatSilk = 4;
static const unsigned int kDDVoicePackVoiceEndFlag = 1;

// 语音时长上下限（毫秒），微信只认 0.3s ~ 60s
static const unsigned int kDDVoicePackMinVoiceMs = 300;
static const unsigned int kDDVoicePackMaxVoiceMs = 60000;

// SILK 不是 AVFoundation 认的格式，读不出时长，按文件大小粗估（约 2KB/s）。
// 估不出来就是 0，由发送侧的 300ms 下限钳制兜住，这里不重复兜底
static unsigned int DDVoicePackDurationMs(NSString *path) {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return (unsigned int)([attrs fileSize] / 2000) * 1000;
}

static BOOL DDVoicePackSendSilk(NSData *silk, unsigned int durationMs, NSString *chatId) {
    unsigned int voiceMs = durationMs;
    if (voiceMs < kDDVoicePackMinVoiceMs) voiceMs = kDDVoicePackMinVoiceMs;
    if (voiceMs > kDDVoicePackMaxVoiceMs) voiceMs = kDDVoicePackMaxVoiceMs;

    Class ctxCls = objc_getClass("MMContext");
    id context = [ctxCls activeUserContext] ?: [ctxCls rootContext];
    if (!context) return NO;

    CBaseContact *selfContact = [[context getService:objc_getClass("CContactMgr")] getSelfContact];
    NSString *myId = [selfContact m_nsUsrName];
    if (!myId.length) return NO;

    CMessageWrap *msg = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:(long long)kDDVoicePackMsgTypeVoice nsFromUsr:myId];
    // m_nsFromUsr 已经由 initWithMsgType:nsFromUsr: 设好了，不用再设一遍
    [msg setM_nsToUsr:chatId];
    [msg setM_uiStatus:1];
    [msg setM_uiDownloadStatus:9];
    [msg setM_nsMsgSource:nil];
    [msg setM_uiCreateTime:[[context getService:objc_getClass("MMNewSessionMgr")] GenSendMsgTime]];

    CMessageMgr *msgMgr = [context getService:objc_getClass("CMessageMgr")];
    [msgMgr AddLocalMsg:chatId MsgWrap:msg];

    Class utilCls = objc_getClass("CUtility");
    NSString *docPath = [utilCls GetDocPath];
    NSString *audioPath = [utilCls GetPathOfMesAudio:chatId LocalID:[msg m_uiMesLocalID] DocPath:docPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:[audioPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [silk writeToFile:audioPath atomically:YES];

    // 语音时长 / 格式 / 数据一律装 extInfo。CMessageWrap 上没有
    // setM_uiVoiceTime: / setM_uiVoiceFormat: / setM_dtVoice:，
    // 这几个只存在于 UploadVoiceWrap、MassSendWrap、CExtendInfoOfVoiceMsg 上，硬调会崩。
    CExtendInfoOfVoiceMsg *extInfo = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [extInfo setM_dtVoice:silk];
    [extInfo setM_uiVoiceTime:voiceMs];
    [extInfo setM_uiVoiceFormat:kDDVoicePackVoiceFormatSilk];
    [extInfo setM_uiVoiceEndFlag:kDDVoicePackVoiceEndFlag];
    [extInfo setM_refMessageWrap:msg];
    [msg setM_extendInfoWithMsgType:extInfo];

    [msg UpdateContent:nil];
    [msgMgr ModMsg:chatId MsgWrap:msg];
    // 落盘：首参传 nil（传 NSData 会被当成路径）
    [msgMgr SaveMesVoice:nil MsgWrap:msg];

    // 上传：AudioSender 是微信语音发送链路上的服务对象，ResendVoiceMsg:MsgWrap: 是唯一入口。
    // 不再 KVC 取 m_upload（取不到会抛 NSUndefinedKeyException 直接崩），也不再退 MMNewUploadVoiceMgr。
    AudioSender *sender = [context getService:objc_getClass("AudioSender")];
    if (!sender) return NO;
    [sender ResendVoiceMsg:chatId MsgWrap:msg];
    return YES;
}

// 读文件 + 算时长都在后台串行队列里跑，长语音不至于卡住界面
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

    dispatch_async(DDVoicePackSendQueue(), ^{
        // 语音包里存的就是微信 SILK，原样发出去，不做任何转码
        NSData *silk = [NSData dataWithContentsOfFile:path];
        if (!silk.length) return;

        if (DDVoicePackSendSilk(silk, DDVoicePackDurationMs(path), chatId)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [DDVoicePackListController ddvp_closeSheetIfNeeded];
            });
        }
    });
}

// ========== Hook 长按「+」按钮打开语音包 ==========

// 长按手势挂在按钮上，防止 didMoveToSuperview 反复触发时重复添加
static const void *kDDVoicePackLongPressKey = &kDDVoicePackLongPressKey;

%hook MMUIButton

- (void)didMoveToSuperview {
    %orig;
    if (![DDVoicePackConfig enabled]) return;
    if (![self.accessibilityLabel isEqualToString:@"更多"]) return;

    if (objc_getAssociatedObject(self, kDDVoicePackLongPressKey)) return;
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(ddvp_moreLongPress:)];
    // 不设 minimumPressDuration，用系统默认（0.5 秒）
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
static NSString * const kDDVoicePackImportMenuToken = @"ddvp:import";

// 往菜单末尾追加「纳入」（开关关闭 / 已注入过则原样返回）
static NSArray *DDVoicePackAppendImportItem(id cell, NSArray *original, BOOL enabled) {
    if (!enabled || !original) return original;

    // 微信自己的菜单数组里全是 MMMenuItem，不用逐个问 userInfo
    for (MMMenuItem *item in original) {
        if ([[item userInfo] isEqual:kDDVoicePackImportMenuToken]) return original;
    }

    MMMenuItem *item = [[objc_getClass("MMMenuItem") alloc] initWithTitle:@"纳入"
                                                                svgName:@"icons_filled_voice"
                                                                 target:cell
                                                                 action:@selector(ddvp_importVoice:)];
    item.userInfo = kDDVoicePackImportMenuToken;

    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];
    return items;
}

// getMediaWrap 在语音 cell 上给的就是 CMessageWrap；不是消息对象时给 nil 发消息返回 0，自然判否
static BOOL DDVoicePackIsVoiceMessageWrap(id wrap) {
    return [wrap m_uiMessageType] == kDDVoicePackMsgTypeVoice;
}

%hook VoiceMessageCellView

- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    return DDVoicePackAppendImportItem(self, items,
                                       [DDVoicePackConfig enabled] && DDVoicePackIsVoiceMessageWrap([self getMediaWrap]));
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
    BOOL fromSelf = [objc_getClass("CMessageWrap") isSenderFromMsgWrap:msg];
    NSString *chat = fromSelf ? [msg m_nsToUsr] : [msg m_nsFromUsr];
    if (!chat.length) return;

    Class utilCls = objc_getClass("CUtility");
    NSString *path = [utilCls GetPathOfMesAudio:chat LocalID:[msg m_uiMesLocalID] DocPath:[utilCls GetDocPath]];
    if (!path.length || ![[NSFileManager defaultManager] fileExistsAtPath:path]) return;

    [DDVoicePackListController ddvp_setPendingImportPath:path];

    UIViewController *fromVC = [self getViewController];
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

// 仿 DD模板套壳：子类只作编译器的类型/selector 声明用——把老 initWithDocumentTypes:inMode: 重声明成 NSInteger 版，
// 编译器只看本声明、看不到 SDK 头里的 deprecated 属性，于是 -Werror 也拦不住它。
// 运行时通过 NSClassFromString(@"UIDocumentPickerViewController") 取【真实类】来 alloc，本子类不会被实例化，
// 因此不需要 @implementation、也不产生链接符号。全程只传字符串 UTI 标识符，不依赖 UniformTypeIdentifiers 框架。
@interface DDVoicePackPicker : UIDocumentPickerViewController
- (instancetype)initWithDocumentTypes:(NSArray<NSString *> *)types inMode:(NSInteger)mode;
@end

@implementation DDVoicePackSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"语音包设置";

    // 表格整屏延伸，由 viewDidLayoutSubviews 推到导航栏底边
    _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_tableViewManager.tableView];

    [self buildTable];
    self.view.backgroundColor = _tableViewManager.tableView.backgroundColor;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _tableViewManager.tableView.frame = CGRectMake(0, top, w, h - top);
}

- (void)buildTable {
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
    [self buildTable];
}

- (void)onKeepPanelSwitchChanged:(UISwitch *)sender {
    [DDVoicePackConfig setKeepPanelAfterSend:sender.isOn];
}

// ---- 导入导出 ----

- (void)importVoicePack {
    // 支持三种来源：整目录、zip 包、单个 .silk 文件。
    // 直接传字符串 UTI 标识符 + 老 API，不依赖 UniformTypeIdentifiers 框架（和 DD模板套壳一致）。
    NSArray *types = @[@"public.folder", @"public.zip-archive", @"public.data"];
    DDVoicePackPicker *picker = [[NSClassFromString(@"UIDocumentPickerViewController") alloc] initWithDocumentTypes:types inMode:0]; // 0 = Import；NSClassFromString 取真实类，DDVoicePackPicker 只用于编译器的类型/selector 声明，不参与实例化
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

// 整目录或单文件，都按同名落到语音包根下，同名则覆盖 —— 和 DD模板套壳一致
- (void)installVoicePackItem:(NSString *)src {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = [DDVoicePackRootPath() stringByAppendingPathComponent:src.lastPathComponent];
    [fm removeItemAtPath:dst error:nil];
    [fm copyItemAtPath:src toPath:dst error:nil];
}

// 解压后的目录：顶层有子文件夹就把每个子文件夹装成同名语音包；
// 顶层没有文件夹（散装 .silk）就逐个落根目录。对应 DD模板套壳 DD_ImportTemplatesFrom 的思路
- (void)importUnpackedDir:(NSString *)dir {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
    BOOL installedFolder = NO;
    for (NSString *name in items) {
        if ([name hasPrefix:@"."] || [name isEqualToString:@"__MACOSX"]) continue;
        NSString *full = [dir stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        [fm fileExistsAtPath:full isDirectory:&isDir];
        if (isDir) {
            [self installVoicePackItem:full];
            installedFolder = YES;
        }
    }
    if (installedFolder) return;
    for (NSString *name in items) {
        if ([name hasPrefix:@"."] || [name isEqualToString:@"__MACOSX"]) continue;
        NSString *full = [dir stringByAppendingPathComponent:name];
        if (DDVoicePackIsSilk(full)) [self installVoicePackItem:full];
    }
}

// zip 可能多包一层包装目录（如导出时打的 "DD语音包/"），下钻到真正装内容的那一层
- (NSString *)voicePackUnwrapIfSingleDir:(NSString *)dir {
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    NSMutableArray *subs = [NSMutableArray array];
    for (NSString *it in items) {
        if ([it hasPrefix:@"."] || [it isEqualToString:@"__MACOSX"]) continue;
        [subs addObject:it];
    }
    if (subs.count == 1) {
        NSString *only = [dir stringByAppendingPathComponent:subs[0]];
        BOOL isDir = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:only isDirectory:&isDir];
        if (isDir) return only;
    }
    return dir;
}

- (void)exportVoicePack {
    NSString *voiceDir = DDVoicePackRootPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:voiceDir]) return;

    // 打包丢后台，主线程不卡
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *tmp = DDVoicePackTempRoot();
        [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
        // 整目录拷进 stage 再压，zip 内保留目录名（和 DD模板套壳一致）
        NSString *stage = [tmp stringByAppendingPathComponent:@"DD语音包"];
        [fm copyItemAtPath:voiceDir toPath:stage error:nil];
        NSString *zip = [tmp stringByAppendingPathComponent:@"DD语音包.zip"];
        BOOL ok = DDVoicePackZipDirectory(stage, zip);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!ok) return; // 打包失败，临时目录等下次清理
            NSURL *zipURL = [NSURL fileURLWithPath:zip];
            UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[zipURL] applicationActivities:nil];
            av.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *items, NSError *err) {
                [fm removeItemAtPath:tmp error:nil]; // 分享结束回收临时目录
            };
            UIPopoverPresentationController *pop = av.popoverPresentationController;
            if (pop) { // iPad 需要锚点，否则崩溃
                pop.sourceView = self.view;
                pop.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
            }
            [self presentViewController:av animated:YES completion:nil];
        });
    });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSMutableArray<NSURL *> *scoped = [NSMutableArray array];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSURL *u in urls) {
        if (!u.path.length) continue; // 防 addObject:nil
        if ([u startAccessingSecurityScopedResource]) [scoped addObject:u];
        [paths addObject:u.path];
    }
    if (!paths.count) {
        for (NSURL *u in scoped) [u stopAccessingSecurityScopedResource];
        return;
    }

    NSString *destRoot = DDVoicePackRootPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:destRoot withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *tmp = DDVoicePackTempRoot();
    [[NSFileManager defaultManager] createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];

    // 解压 + 拷贝在后台跑，语音包多时避免主线程卡顿
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (NSString *p in paths) {
            BOOL isDir = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:p isDirectory:&isDir];
            if (isDir) {
                [self installVoicePackItem:p];
            } else if ([p.pathExtension.lowercaseString isEqualToString:@"zip"]) {
                NSString *unzipDir = [tmp stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
                if (DDVoicePackUnzipToDirectory(p, unzipDir)) {
                    [self importUnpackedDir:[self voicePackUnwrapIfSingleDir:unzipDir]];
                }
            } else if ([p.pathExtension.lowercaseString isEqualToString:@"silk"]) {
                [self installVoicePackItem:p];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            for (NSURL *u in scoped) [u stopAccessingSecurityScopedResource];
            [[NSFileManager defaultManager] removeItemAtPath:tmp error:nil];
        });
    });
}

@end

// ========== 插件注册 ==========

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD语音包"
                                                      version:@"1.0.0"
                                                   controller:@"DDVoicePackSettingsViewController"];
        }
    }
}

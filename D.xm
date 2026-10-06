//
//  DDVoice.xm
//  微信语音包插件
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 常量定义

static NSString * const kWCVoicePackDidSelectSilkFileNotification = @"WCVoicePackDidSelectSilkFileNotification";
static NSString * const kWCVoicePackDidSelectSilkFilePathKey = @"fullPath";
static NSString * const kWCVoicePackTargetChatUserNameKey = @"targetChatUserName";

static const void *kWCVoiceListPageSheetContainerKey = "WCVoiceListPageSheetContainer";
static const void *kWCVoiceFolderCellPathAssocKey = &kWCVoiceFolderCellPathAssocKey;
static const void *kWCVoiceFileCellPathAssocKey = &kWCVoiceFileCellPathAssocKey;
static const void *kWCVoicePackSheetFromVCKey = &kWCVoicePackSheetFromVCKey;
static const void *kWCVoicePackSheetAdapterKey = &kWCVoicePackSheetAdapterKey;
static const void *kWCVoicePackSheetConfigKey = &kWCVoicePackSheetConfigKey;
static const void *kWCVoicePackSheetContainerAssocKey = &kWCVoicePackSheetContainerAssocKey;
static const void *kWCVoicePackAVAudioPreviewPlayerKey = &kWCVoicePackAVAudioPreviewPlayerKey;
static const void *kWCVoiceSilkPreviewWeChatSilkPlayerKey = &kWCVoiceSilkPreviewWeChatSilkPlayerKey;
static const void *kWCVoiceLongPressGestureKey = &kWCVoiceLongPressGestureKey;

static __weak UIViewController *sWCVoicePackSheetHostFromVC = nil;
static NSString *sWCVoicePendingVoiceImportFromChatPath = nil;

#pragma mark - 微信私有类声明

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
- (id)getService:(Class)serviceClass;
@end

@interface WCTableViewManager : NSObject
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
- (void)clearAllSection;
- (id)getTableView;
- (void)addSection:(id)section;
- (void)reloadTableView;
@property (nonatomic, readonly) UITableView *tableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoHeader:(id)header;
+ (id)sectionInfoHeader:(id)header Footer:(id)footer;
- (void)addCell:(id)cell;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title rightValue:(id)right accessoryType:(long long)accessoryType;
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(id)title detail:(id)detail;
- (id)getCell;
@end

@interface MMTableView : UITableView
@end

@interface CContact : NSObject
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
- (NSUInteger)m_uiMesLocalID;
- (void)setM_nsFromUsr:(NSString *)from;
- (void)setM_nsToUsr:(NSString *)to;
- (void)setM_uiStatus:(unsigned int)status;
- (void)setM_uiDownloadStatus:(unsigned int)status;
- (void)setM_uiVoiceFormat:(unsigned int)format;
- (void)setM_uiVoiceTime:(unsigned int)time;
- (void)setM_nsVoicePath:(NSString *)path;
- (void)setM_dtVoice:(NSData *)data;
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

// 微信头文件里 MMMenuItem 直接继承 NSObject（不是 UIMenuItem），且没有 title 的 getter，
// 所以识别菜单项一律走 userInfo 标记，不要读 title（会 unrecognized selector）
@interface MMMenuItem : NSObject
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic, retain) UIImage *iconImage;
@property (nonatomic, assign) long long linePosition;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) long long menuType;
@property (nonatomic, retain) id userInfo;
- (instancetype)initWithTitle:(NSString *)title svgName:(NSString *)svgName target:(id)target action:(SEL)action;
@end

@interface MMUIButton : UIButton
@property (nonatomic, copy) NSString *accessibilityLabel;
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
- (void)setPageSheetConfig:(MMPageSheetConfig *)config;
- (void)setDetailViewHeight:(double)h;
@end

@interface MMPageSheetContainerWindowController : UIViewController
- (void)setupWithProvider:(id)provider;
- (void)showPageSheetAnimated:(BOOL)animated parentView:(id)view parentViewController:(id)vc complete:(void (^)(void))block;
- (void)dismissWithAnimated:(BOOL)animated completion:(void (^)(void))block;
@end

@interface CUtility : NSObject
+ (NSString *)GetDocPath;
+ (NSString *)GetPathOfMesAudio:(NSString *)userName LocalID:(unsigned int)localID DocPath:(NSString *)docPath;
@end

@interface SilkAudioPlayer : NSObject
- (BOOL)preparePlayWithFile:(id)path sync:(BOOL)sync;
- (void)playAtTime:(unsigned int)time;
- (void)stop;
@end

@interface VoiceMessageCellView : UIView
- (id)getMediaWrap;
- (id)getViewController;
- (NSArray *)operationMenuItems;
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender;
@end

@protocol WCPluginsMgrProtocol
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理

@interface WCVoiceConfig : NSObject
+ (BOOL)messageVoicePackManagementEnabled;
+ (void)setMessageVoicePackManagementEnabled:(BOOL)value;
+ (BOOL)messageVoicePackKeepPanelAfterSend;
+ (void)setMessageVoicePackKeepPanelAfterSend:(BOOL)value;
+ (NSInteger)messageVoicePackEntryMode;
+ (void)setMessageVoicePackEntryMode:(NSInteger)mode;
+ (NSInteger)messageVoicePackInterfaceHeightStep;
+ (void)setMessageVoicePackInterfaceHeightStep:(NSInteger)step;
@end

@implementation WCVoiceConfig

+ (BOOL)messageVoicePackManagementEnabled {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:@"WCVoice_messageVoicePackManagementEnabled"] == nil) return NO;
    return [ud boolForKey:@"WCVoice_messageVoicePackManagementEnabled"];
}
+ (void)setMessageVoicePackManagementEnabled:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"WCVoice_messageVoicePackManagementEnabled"];
}

+ (NSInteger)messageVoicePackEntryMode {
    NSInteger v = [[NSUserDefaults standardUserDefaults] integerForKey:@"WCVoice_messageVoicePackEntryMode"];
    if (v < 0 || v > 2) return 0;
    return v;
}
+ (void)setMessageVoicePackEntryMode:(NSInteger)mode {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:@"WCVoice_messageVoicePackEntryMode"];
}

+ (BOOL)messageVoicePackKeepPanelAfterSend {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"WCVoice_messageVoicePackKeepPanelAfterSend"];
}
+ (void)setMessageVoicePackKeepPanelAfterSend:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:@"WCVoice_messageVoicePackKeepPanelAfterSend"];
}

+ (NSInteger)messageVoicePackInterfaceHeightStep {
    NSInteger v = [[NSUserDefaults standardUserDefaults] integerForKey:@"WCVoice_messageVoicePackInterfaceHeightStep"];
    if (v < 1 || v > 10) return 5;
    return v;
}
+ (void)setMessageVoicePackInterfaceHeightStep:(NSInteger)step {
    [[NSUserDefaults standardUserDefaults] setInteger:step forKey:@"WCVoice_messageVoicePackInterfaceHeightStep"];
}

@end

#pragma mark - 语音预览工具

@interface WCVoiceSilkPreview : NSObject
+ (void)playSilkFileAtPath:(NSString *)path retainingPlayerOn:(id)owner;
+ (void)stopPreviewRetainedOnOwner:(id)owner;
@end

@implementation WCVoiceSilkPreview

+ (void)stopPreviewRetainedOnOwner:(id)owner {
    if (owner) {
        id player = objc_getAssociatedObject(owner, kWCVoiceSilkPreviewWeChatSilkPlayerKey);
        if (player) ((void (*)(id, SEL))objc_msgSend)(player, @selector(stop));
        objc_setAssociatedObject(owner, kWCVoiceSilkPreviewWeChatSilkPlayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

+ (void)playSilkFileAtPath:(NSString *)path retainingPlayerOn:(id)owner {
    [self stopPreviewRetainedOnOwner:owner];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    Class cls = objc_getClass("SilkAudioPlayer");
    if (!cls) return;
    id player = ((id (*)(id, SEL))objc_msgSend)([cls alloc], @selector(init));
    ((BOOL (*)(id, SEL, id, BOOL))objc_msgSend)(player, @selector(preparePlayWithFile:sync:), path, NO);
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(player, @selector(playAtTime:), 0u);
    if (owner) objc_setAssociatedObject(owner, kWCVoiceSilkPreviewWeChatSilkPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#pragma mark - 文件操作辅助函数

static NSString *WCVoicePackDirectoryPath(void) {
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    NSString *preferencesPath = [libraryPath stringByAppendingPathComponent:@"Preferences"];
    NSString *voiceRoot = [preferencesPath stringByAppendingPathComponent:@"WCVoice"];
    return [voiceRoot stringByAppendingPathComponent:@"Voice"];
}

static void WCVoicePackSortedFoldersAndFiles(NSString *dirPath, NSArray<NSString *> **outFolders, NSArray<NSString *> **outFiles) {
    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *files = [NSMutableArray array];
    if (outFolders) *outFolders = @[];
    if (outFiles) *outFiles = @[];
    if (!dirPath.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) return;
    NSArray *names = [fm contentsOfDirectoryAtPath:dirPath error:nil];
    for (NSString *name in names) {
        NSString *full = [dirPath stringByAppendingPathComponent:name];
        if ([fm fileExistsAtPath:full isDirectory:&isDir] && isDir) [folders addObject:name];
        else [files addObject:name];
    }
    if (outFolders) *outFolders = [folders sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (outFiles) *outFiles = [files sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSUInteger WCVoicePackDirectFileCountInDirectory(NSString *dirPath) {
    NSArray *folders, *files;
    WCVoicePackSortedFoldersAndFiles(dirPath, &folders, &files);
    return files.count;
}

static BOOL WCVoicePackPathLooksLikeSilkOrAud(NSString *path) {
    NSString *ext = [[path pathExtension] lowercaseString];
    return [ext isEqualToString:@"silk"] || [ext isEqualToString:@"aud"];
}

static BOOL WCVoicePackPathLooksLikeCompressibleAudio(NSString *path) {
    static NSSet *exts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        exts = [NSSet setWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"caf", @"flac", @"mp4", nil];
    });
    return [exts containsObject:[[path pathExtension] lowercaseString]];
}

static NSString *WCVoicePackSanitizedImportedSilkBaseName(NSString *raw) {
    NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!t.length) return nil;
    if ([[t lowercaseString] hasSuffix:@".silk"]) t = [t substringToIndex:t.length - 5];
    else if ([[t lowercaseString] hasSuffix:@".slik"]) t = [t substringToIndex:t.length - 5];
    t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return t;
}

static NSArray<NSString *> *WCVoiceSearchAudioFilesInDirectory(NSString *directory, NSString *keyword) {
    if (!keyword.length) return @[];
    NSMutableArray *results = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:directory];
    NSString *relativePath;
    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [directory stringByAppendingPathComponent:relativePath];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        if (isDir) continue;
        if (!WCVoicePackPathLooksLikeSilkOrAud(fullPath) && !WCVoicePackPathLooksLikeCompressibleAudio(fullPath)) continue;
        NSString *fileName = [relativePath lastPathComponent];
        if ([fileName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [results addObject:fullPath];
        }
    }
    return [results sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - 语音列表控制器接口声明

@class WCVoiceListController;

@interface WCVoiceListController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@property (nonatomic, copy) NSString *wcvoice_browsingDirectoryPath;
@property (nonatomic, copy) NSArray<NSString *> *wcvoice_voicePackFolderPathsOrdered;
@property (nonatomic, copy) NSArray<NSString *> *wcvoice_voicePackFilePathsOrdered;
@property (nonatomic, strong) id wcvoice_tableDelegateProxy;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, copy) NSArray<NSString *> *searchResults;
@property (nonatomic, assign) BOOL isSearching;

+ (void)wcvoice_setPendingVoiceImportFromChatPath:(NSString *)absolutePath;
+ (NSString *)wcvoice_pendingVoiceImportFromChatPath;
+ (void)wcvoice_clearPendingVoiceImportFromChat;
+ (void)wcvoice_ensureVoicePackRootDirectoryExists;
+ (void)wcvoice_dismissVoicePackPageSheetAfterSendIfConfigured;
+ (void)presentVoicePackPageSheetFromViewController:(UIViewController *)fromVC;

- (void)reloadTableData;
- (NSString *)wcvoice_fullPathForContentRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)wcvoice_voicePackSwipeActionsAllowedAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)wcvoice_voicePackRowSupportsSwipePreviewAtIndexPath:(NSIndexPath *)indexPath;
- (void)wcvoice_requestDeleteVoicePackItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)wcvoice_requestRenameVoicePackItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)wcvoice_requestPreviewSilkVoicePackItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)wcvoice_voicePackPlusButtonTapped;
- (void)wcvoice_syncMMPageSheetNavigationBar;
- (UIButton *)wcvoice_makeVoicePackPlusButtonWithThemeManager:(id)themeManager buttonColor:(UIColor *)buttonColor;
- (void)wcvoice_updateVoicePackPlusBarButtonVisibility;
- (void)wcvoice_voicePackFolderRowTapped:(id)sender;
- (void)wcvoice_voicePackFileRowTapped:(id)sender;
- (void)wcvoice_performVoicePackDirectoryCreateWithRoot:(NSString *)voiceRoot trimmedSubName:(NSString *)subName;
- (void)wcvoice_stopVoicePackAVAudioPreview;
- (void)wcvoice_playSilkPreviewForFullPath:(NSString *)full;
- (void)wcvoice_playCompressibleAudioPreviewAtPath:(NSString *)path;
- (NSString *)wcvoice_targetChatUserNameForVoiceSend;
- (void)wcvoice_installTableDelegateProxyIfNeeded;
- (NSString *)wcvoice_effectiveBrowsingDirectoryPath;

- (void)wcvoice_showRenameInputForIndexPath:(NSIndexPath *)indexPath errorMessage:(NSString *)errorMessage;
- (void)wcvoice_performVoicePackRenameFromPath:(NSString *)oldFull parent:(NSString *)parent newBaseName:(NSString *)baseName forIndexPath:(NSIndexPath *)indexPath;
- (void)wcvoice_showImportInputWithRoot:(NSString *)voiceRoot errorMessage:(NSString *)errorMessage;
- (void)performSearchWithKeyword:(NSString *)keyword;
- (void)clearSearch;
- (void)searchCancelButtonTapped;

@end

#pragma mark - 表代理转发

@interface WCVoicePackTableDelegateProxy : NSObject <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, weak) id forwardTarget;
@property (nonatomic, weak) WCVoiceListController *host;
@end

@implementation WCVoicePackTableDelegateProxy

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
    if ([self.host wcvoice_voicePackSwipeActionsAllowedAtIndexPath:indexPath]) return YES;
    return ((BOOL (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.host wcvoice_voicePackSwipeActionsAllowedAtIndexPath:indexPath]) {
        return [self.host wcvoice_voicePackRowSupportsSwipePreviewAtIndexPath:indexPath] ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
    }
    return ((UITableViewCellEditingStyle (*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && [self.host wcvoice_voicePackSwipeActionsAllowedAtIndexPath:indexPath]) {
        if (![self.host wcvoice_voicePackRowSupportsSwipePreviewAtIndexPath:indexPath]) {
            [self.host wcvoice_requestDeleteVoicePackItemAtIndexPath:indexPath];
        }
        return;
    }
    ((void (*)(id, SEL, UITableView *, UITableViewCellEditingStyle, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, editingStyle, indexPath);
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self.host wcvoice_voicePackSwipeActionsAllowedAtIndexPath:indexPath]) {
        __weak typeof(self.host) weakHost = self.host;
        UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"删除" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [weakHost wcvoice_requestDeleteVoicePackItemAtIndexPath:indexPath];
            completionHandler(YES);
        }];
        UIContextualAction *renameAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"重命名" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
            [weakHost wcvoice_requestRenameVoicePackItemAtIndexPath:indexPath];
            completionHandler(YES);
        }];
        if ([self.host wcvoice_voicePackRowSupportsSwipePreviewAtIndexPath:indexPath]) {
            UIContextualAction *previewAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"试听" handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
                [weakHost wcvoice_requestPreviewSilkVoicePackItemAtIndexPath:indexPath];
                completionHandler(YES);
            }];
            previewAction.backgroundColor = [UIColor systemBlueColor];
            UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, renameAction, previewAction]];
            config.performsFirstActionWithFullSwipe = NO;
            return config;
        }
        UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:@[deleteAction, renameAction]];
        config.performsFirstActionWithFullSwipe = YES;
        return config;
    }
    return ((UISwipeActionsConfiguration *(*)(id, SEL, UITableView *, NSIndexPath *))objc_msgSend)(self.forwardTarget, _cmd, tableView, indexPath);
}

@end

#pragma mark - UIViewController 分类

@interface UIViewController (WCVoiceListPageSheet)
- (void)dismissWCVoiceListPageSheet;
@end

@implementation UIViewController (WCVoiceListPageSheet)

- (void)dismissWCVoiceListPageSheet {
    id container = objc_getAssociatedObject(self, kWCVoiceListPageSheetContainerKey);
    if (container) {
        [WCVoiceSilkPreview stopPreviewRetainedOnOwner:nil];
        ((void (*)(id, SEL, BOOL, void (^)(void)))objc_msgSend)(container, @selector(dismissWithAnimated:completion:), YES, nil);
        objc_setAssociatedObject(self, kWCVoiceListPageSheetContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        sWCVoicePackSheetHostFromVC = nil;
    }
}

@end

#pragma mark - WCVoiceListController 实现

@implementation WCVoiceListController

+ (void)wcvoice_setPendingVoiceImportFromChatPath:(NSString *)absolutePath {
    sWCVoicePendingVoiceImportFromChatPath = [absolutePath copy];
}
+ (NSString *)wcvoice_pendingVoiceImportFromChatPath {
    return sWCVoicePendingVoiceImportFromChatPath;
}
+ (void)wcvoice_clearPendingVoiceImportFromChat {
    sWCVoicePendingVoiceImportFromChatPath = nil;
}
+ (void)wcvoice_ensureVoicePackRootDirectoryExists {
    [[NSFileManager defaultManager] createDirectoryAtPath:WCVoicePackDirectoryPath() withIntermediateDirectories:YES attributes:nil error:nil];
}
+ (void)wcvoice_dismissVoicePackPageSheetAfterSendIfConfigured {
    if ([WCVoiceConfig messageVoicePackKeepPanelAfterSend]) return;
    UIViewController *host = sWCVoicePackSheetHostFromVC;
    if (!host) return;
    [host dismissWCVoiceListPageSheet];
}

+ (void)presentVoicePackPageSheetFromViewController:(UIViewController *)fromVC {
    if (!fromVC) return;
    WCVoiceListController *hostVC = [[WCVoiceListController alloc] init];
    UIColor *bgColor = [UIColor systemBackgroundColor];
    hostVC.view.backgroundColor = bgColor;
    
    UINavigationController *sheetNav = [[UINavigationController alloc] initWithRootViewController:hostVC];
    sheetNav.modalPresentationStyle = UIModalPresentationPageSheet;
    
    Class adapterCls = objc_getClass("MMPageSheetAdapter");
    if (!adapterCls) {
        [fromVC presentViewController:sheetNav animated:YES completion:nil];
        return;
    }
    CGFloat heightStep = [WCVoiceConfig messageVoicePackInterfaceHeightStep];
    CGFloat sheetHeight = [UIScreen mainScreen].bounds.size.height * (CGFloat)heightStep / 10.0;
    id adapter = ((id (*)(id, SEL, id, double))objc_msgSend)(adapterCls, @selector(adapterWithViewController:height:), sheetNav, sheetHeight);
    if (!adapter) {
        [fromVC presentViewController:sheetNav animated:YES completion:nil];
        return;
    }
    
    Class configCls = objc_getClass("MMPageSheetConfig");
    id config = [[configCls alloc] init];
    [config setTitle:@"语音包管理"];
    [config setPreferredCenterTitleAlignment:YES];
    [config setNavHidden:NO];
    [config setIsAllowTapBgMaskToClose:YES];
    [config setEnableDragToClose:YES];
    
    Class ctxCls = objc_getClass("MMContext");
    Class themeCls = objc_getClass("MMThemeManager");
    id context = [ctxCls activeUserContext] ?: [ctxCls rootContext];
    id themeManager = [context getService:themeCls];
    UIColor *btnColor = [UIColor labelColor];
    
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 0, 44, 44);
    UIImage *backIcon = ((UIImage *(*)(id, SEL, NSString *, UIColor *))objc_msgSend)(themeManager, @selector(svgImageNamed:color:), @"arrow_left_regular", btnColor);
    [backBtn setImage:backIcon forState:UIControlStateNormal];
    [backBtn addTarget:sheetNav action:@selector(wcvoice_voicePackSheetBackInvoked:) forControlEvents:UIControlEventTouchUpInside];
    [config setNavBackButton:backBtn];
    [config setNavLeftButton:backBtn];
    
    UIButton *plusBtn = [hostVC wcvoice_makeVoicePackPlusButtonWithThemeManager:themeManager buttonColor:btnColor];
    [config setNavRightButton:plusBtn];
    
    [config setNavBarBackgroundColor:[UIColor systemBackgroundColor]];
    [config setTitleColor:[UIColor labelColor]];
    [config setContentBackgroundColor:bgColor];
    [config setMaskBackgroundColor:[UIColor colorWithWhite:0 alpha:0.4]];
    
    objc_setAssociatedObject(sheetNav, kWCVoicePackSheetFromVCKey, fromVC, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(sheetNav, kWCVoicePackSheetAdapterKey, adapter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(sheetNav, kWCVoicePackSheetConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sheetNav.navigationBarHidden = YES;
    
    ((void (*)(id, SEL, id))objc_msgSend)(adapter, @selector(setPageSheetConfig:), config);
    ((void (*)(id, SEL, double))objc_msgSend)(adapter, @selector(setDetailViewHeight:), sheetHeight);
    
    Class containerCls = objc_getClass("MMPageSheetContainerWindowController");
    id container = [[containerCls alloc] init];
    objc_setAssociatedObject(sheetNav, kWCVoicePackSheetContainerAssocKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(fromVC, kWCVoiceListPageSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(hostVC, kWCVoiceListPageSheetContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(container, @selector(setupWithProvider:), adapter);
    ((void (*)(id, SEL, BOOL, id, id, void (^)(void)))objc_msgSend)(container, @selector(showPageSheetAnimated:parentView:parentViewController:complete:), YES, nil, fromVC, nil);
    sWCVoicePackSheetHostFromVC = fromVC;
}

- (UIButton *)wcvoice_makeVoicePackPlusButtonWithThemeManager:(id)themeManager buttonColor:(UIColor *)buttonColor {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 44, 44);
    UIImage *icon = ((UIImage *(*)(id, SEL, NSString *, UIColor *))objc_msgSend)(themeManager, @selector(svgImageNamed:color:), @"plus_regular", buttonColor);
    [btn setImage:icon forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(wcvoice_voicePackPlusButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (instancetype)init {
    if (self = [super init]) {
        _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
        _wcvoice_voicePackFolderPathsOrdered = @[];
        _wcvoice_voicePackFilePathsOrdered = @[];
        _searchResults = @[];
        _isSearching = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (!objc_getAssociatedObject(self.navigationController, kWCVoicePackSheetConfigKey)) {
        self.title = @"语音包管理";
    }
    
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索语音包";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.showsCancelButton = NO;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.searchBar];
    
    MMTableView *tv = (MMTableView *)[self.tableViewMgr getTableView];
    tv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:tv];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [tv.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tv.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tv.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    [self wcvoice_updateVoicePackPlusBarButtonVisibility];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [WCVoiceSilkPreview stopPreviewRetainedOnOwner:self];
    [self wcvoice_stopVoicePackAVAudioPreview];
    [self.searchBar resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (objc_getAssociatedObject(self.navigationController, kWCVoicePackSheetConfigKey)) {
        self.title = nil;
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    }
    [self reloadTableData];
    [self wcvoice_syncMMPageSheetNavigationBar];
    [self wcvoice_updateVoicePackPlusBarButtonVisibility];
}

- (NSString *)wcvoice_effectiveBrowsingDirectoryPath {
    return self.wcvoice_browsingDirectoryPath.length ? self.wcvoice_browsingDirectoryPath : WCVoicePackDirectoryPath();
}

- (NSString *)wcvoice_voicePackPageSheetBarTitle {
    return self.wcvoice_browsingDirectoryPath.length ? [self.wcvoice_browsingDirectoryPath lastPathComponent] : @"语音包管理";
}

- (void)wcvoice_syncMMPageSheetNavigationBar {
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    id config = objc_getAssociatedObject(nav, kWCVoicePackSheetConfigKey);
    id adapter = objc_getAssociatedObject(nav, kWCVoicePackSheetAdapterKey);
    if (!config || !adapter) return;
    ((void (*)(id, SEL, id))objc_msgSend)(config, @selector(setTitle:), [self wcvoice_voicePackPageSheetBarTitle]);
    ((void (*)(id, SEL, id))objc_msgSend)(adapter, @selector(setPageSheetConfig:), config);
}

- (NSString *)wcvoice_targetChatUserNameForVoiceSend {
    UINavigationController *nav = self.navigationController;
    if (!nav) return nil;
    UIViewController *fromVC = objc_getAssociatedObject(nav, kWCVoicePackSheetFromVCKey);
    if (!fromVC) return nil;
    Class baseMsgCls = objc_getClass("BaseMsgContentViewController");
    if (!baseMsgCls || ![fromVC isKindOfClass:baseMsgCls]) return nil;
    if (![fromVC respondsToSelector:@selector(GetContact)]) return nil;
    id contact = ((id (*)(id, SEL))objc_msgSend)(fromVC, @selector(GetContact));
    if (!contact || ![contact respondsToSelector:@selector(m_nsUsrName)]) return nil;
    NSString *name = ((NSString *(*)(id, SEL))objc_msgSend)(contact, @selector(m_nsUsrName));
    return name.length ? name : nil;
}

- (BOOL)wcvoice_voicePackRowSupportsSwipePreviewAtIndexPath:(NSIndexPath *)indexPath {
    NSString *full = [self wcvoice_fullPathForContentRowAtIndexPath:indexPath];
    return WCVoicePackPathLooksLikeSilkOrAud(full) || WCVoicePackPathLooksLikeCompressibleAudio(full);
}

- (void)wcvoice_stopVoicePackAVAudioPreview {
    id player = objc_getAssociatedObject(self, kWCVoicePackAVAudioPreviewPlayerKey);
    if ([player isKindOfClass:[AVAudioPlayer class]]) [(AVAudioPlayer *)player stop];
    objc_setAssociatedObject(self, kWCVoicePackAVAudioPreviewPlayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)wcvoice_requestPreviewSilkVoicePackItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *full = [self wcvoice_fullPathForContentRowAtIndexPath:indexPath];
    if (WCVoicePackPathLooksLikeSilkOrAud(full)) [self wcvoice_playSilkPreviewForFullPath:full];
    else if (WCVoicePackPathLooksLikeCompressibleAudio(full)) [self wcvoice_playCompressibleAudioPreviewAtPath:full];
}

- (void)wcvoice_playSilkPreviewForFullPath:(NSString *)full {
    [self wcvoice_stopVoicePackAVAudioPreview];
    [WCVoiceSilkPreview playSilkFileAtPath:full retainingPlayerOn:self];
}

- (void)wcvoice_playCompressibleAudioPreviewAtPath:(NSString *)path {
    [WCVoiceSilkPreview stopPreviewRetainedOnOwner:self];
    [self wcvoice_stopVoicePackAVAudioPreview];
    NSURL *url = [NSURL fileURLWithPath:path];
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [player play];
    objc_setAssociatedObject(self, kWCVoicePackAVAudioPreviewPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)wcvoice_voicePackFileRowTapped:(id)sender {
    NSString *fullPath = objc_getAssociatedObject(sender, kWCVoiceFileCellPathAssocKey);
    if (![fullPath isKindOfClass:[NSString class]]) {
        UITableViewCell *cell = [sender respondsToSelector:@selector(getCell)] ? [sender getCell] : sender;
        MMTableView *tv = (MMTableView *)[self.tableViewMgr getTableView];
        NSIndexPath *ip = [tv indexPathForCell:cell];
        fullPath = [self wcvoice_fullPathForContentRowAtIndexPath:ip];
    }
    if (!fullPath.length) return;
    NSString *chatUser = [self wcvoice_targetChatUserNameForVoiceSend];
    if (!chatUser.length) return;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[kWCVoicePackDidSelectSilkFilePathKey] = fullPath;
    info[kWCVoicePackTargetChatUserNameKey] = chatUser;
    [[NSNotificationCenter defaultCenter] postNotificationName:kWCVoicePackDidSelectSilkFileNotification object:self userInfo:info];
}

- (void)wcvoice_voicePackFolderRowTapped:(id)sender {
    if (self.isSearching) return;
    NSString *fullPath = objc_getAssociatedObject(sender, kWCVoiceFolderCellPathAssocKey);
    if (![fullPath isKindOfClass:[NSString class]]) {
        UITableViewCell *cell = [sender respondsToSelector:@selector(getCell)] ? [sender getCell] : sender;
        MMTableView *tv = (MMTableView *)[self.tableViewMgr getTableView];
        NSIndexPath *ip = [tv indexPathForCell:cell];
        fullPath = self.wcvoice_voicePackFolderPathsOrdered[ip.row];
    }
    WCVoiceListController *child = [[WCVoiceListController alloc] init];
    child.wcvoice_browsingDirectoryPath = fullPath;
    [self.navigationController pushViewController:child animated:YES];
}

- (BOOL)wcvoice_shouldShowVoicePackPlusButton {
    if (self.isSearching) return NO;
    return self.wcvoice_browsingDirectoryPath.length == 0 || [WCVoiceListController wcvoice_pendingVoiceImportFromChatPath].length > 0;
}

- (void)wcvoice_updateVoicePackPlusBarButtonVisibility {
    UINavigationController *nav = self.navigationController;
    if (!nav) return;
    
    if (self.isSearching) return;
    
    BOOL show = [self wcvoice_shouldShowVoicePackPlusButton];
    id config = objc_getAssociatedObject(nav, kWCVoicePackSheetConfigKey);
    if (config) {
        if (show) {
            Class ctxCls = objc_getClass("MMContext");
            Class themeCls = objc_getClass("MMThemeManager");
            id context = [ctxCls activeUserContext] ?: [ctxCls rootContext];
            id themeManager = [context getService:themeCls];
            UIButton *plusBtn = [self wcvoice_makeVoicePackPlusButtonWithThemeManager:themeManager buttonColor:[UIColor labelColor]];
            ((void (*)(id, SEL, id))objc_msgSend)(config, @selector(setNavRightButton:), plusBtn);
        } else {
            ((void (*)(id, SEL, id))objc_msgSend)(config, @selector(setNavRightButton:), nil);
        }
        [self wcvoice_syncMMPageSheetNavigationBar];
        return;
    }
    if (show) {
        Class ctxCls = objc_getClass("MMContext");
        Class themeCls = objc_getClass("MMThemeManager");
        id context = [ctxCls activeUserContext] ?: [ctxCls rootContext];
        id themeManager = [context getService:themeCls];
        UIButton *plusBtn = [self wcvoice_makeVoicePackPlusButtonWithThemeManager:themeManager buttonColor:[UIColor labelColor]];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:plusBtn];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)wcvoice_voicePackPlusButtonTapped {
    if (self.isSearching) return;
    NSString *voiceRoot = [self wcvoice_effectiveBrowsingDirectoryPath];
    NSString *pendingSrc = [WCVoiceListController wcvoice_pendingVoiceImportFromChatPath];
    
    if (pendingSrc.length) {
        [self wcvoice_showImportInputWithRoot:voiceRoot errorMessage:nil];
        return;
    }
    
    Class tipsCls = objc_getClass("MMTipsViewController");
    __weak typeof(self) weakSelf = self;
    __block id tipsVC = [[tipsCls alloc] initWithTitle:@"语音包目录" message:@"请输入新增分类的名称" btnTitle:@"取消" handler:nil btnTitle:@"创建" handler:^{
        UITextView *tv = [tipsVC getTextView];
        [weakSelf wcvoice_performVoicePackDirectoryCreateWithRoot:voiceRoot trimmedSubName:[tv.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }];
    [tipsVC addTextViewWithMaxLen:128];
    [tipsVC setTextFieldDefaultText:@""];
    [tipsVC show];
}

- (void)wcvoice_showImportInputWithRoot:(NSString *)voiceRoot errorMessage:(NSString *)errorMessage {
    NSString *message = errorMessage ?: @"请输入新名称";
    Class tipsCls = objc_getClass("MMTipsViewController");
    __weak typeof(self) weakSelf = self;
    __block id tipsVC = [[tipsCls alloc] initWithTitle:@"纳入语音"
                                               message:message
                                              btnTitle:@"取消"
                                               handler:^{
        [WCVoiceListController wcvoice_clearPendingVoiceImportFromChat];
        [weakSelf wcvoice_updateVoicePackPlusBarButtonVisibility];
    }
                                              btnTitle:@"保存"
                                               handler:^{
        UITextView *tv = [tipsVC getTextView];
        NSString *base = WCVoicePackSanitizedImportedSilkBaseName(tv.text ?: @"");
        NSString *pendingSrc = [WCVoiceListController wcvoice_pendingVoiceImportFromChatPath];
        NSString *destFull = [voiceRoot stringByAppendingPathComponent:[base stringByAppendingPathExtension:@"silk"]];
        
        if (!base.length || [[NSFileManager defaultManager] fileExistsAtPath:destFull]) {
            [weakSelf wcvoice_showImportInputWithRoot:voiceRoot errorMessage:@"名称无效或已存在，请重新输入"];
            return;
        }
        
        [[NSFileManager defaultManager] copyItemAtPath:pendingSrc toPath:destFull error:nil];
        [WCVoiceListController wcvoice_clearPendingVoiceImportFromChat];
        [weakSelf reloadTableData];
        [weakSelf wcvoice_updateVoicePackPlusBarButtonVisibility];
    }];
    [tipsVC addTextViewWithMaxLen:128];
    [tipsVC setTextFieldDefaultText:@""];
    [tipsVC show];
}

- (void)wcvoice_performVoicePackDirectoryCreateWithRoot:(NSString *)voiceRoot trimmedSubName:(NSString *)subName {
    if (subName.length) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[voiceRoot stringByAppendingPathComponent:subName] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    [self reloadTableData];
}

- (void)reloadTableData {
    [self.tableViewMgr clearAllSection];
    
    if (self.isSearching) {
        if (self.searchResults.count > 0) {
            NSString *header = [NSString stringWithFormat:@"%lu 个结果", (unsigned long)self.searchResults.count];
            WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:header Footer:@""];
            Class NormalCell = objc_getClass("WCTableViewNormalCellManager");
            
            for (NSString *fullPath in self.searchResults) {
                NSString *name = [fullPath lastPathComponent];
                WCTableViewCellManager *cell = [NormalCell normalCellForSel:@selector(wcvoice_voicePackFileRowTapped:) target:self title:name rightValue:@"" accessoryType:1];
                objc_setAssociatedObject(cell, kWCVoiceFileCellPathAssocKey, fullPath, OBJC_ASSOCIATION_COPY_NONATOMIC);
                [section addCell:cell];
            }
            [self.tableViewMgr addSection:section];
        }
    } else {
        NSString *dirPath = [self wcvoice_effectiveBrowsingDirectoryPath];
        NSArray<NSString *> *folders, *files;
        WCVoicePackSortedFoldersAndFiles(dirPath, &folders, &files);
        
        NSMutableArray *folderPaths = [NSMutableArray array];
        for (NSString *name in folders) [folderPaths addObject:[dirPath stringByAppendingPathComponent:name]];
        self.wcvoice_voicePackFolderPathsOrdered = folderPaths;
        
        NSMutableArray *filePaths = [NSMutableArray array];
        for (NSString *name in files) [filePaths addObject:[dirPath stringByAppendingPathComponent:name]];
        self.wcvoice_voicePackFilePathsOrdered = filePaths;
        
        NSString *header = self.wcvoice_browsingDirectoryPath.length ? [NSString stringWithFormat:@"%lu 条语音", (unsigned long)files.count] : [NSString stringWithFormat:@"%lu 个分类", (unsigned long)folders.count];
        WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:header Footer:@""];
        Class NormalCell = objc_getClass("WCTableViewNormalCellManager");
        
        for (NSString *name in folders) {
            NSString *full = [dirPath stringByAppendingPathComponent:name];
            NSUInteger cnt = WCVoicePackDirectFileCountInDirectory(full);
            NSString *detail = [NSString stringWithFormat:@"%lu 个语音", (unsigned long)cnt];
            WCTableViewCellManager *cell = [NormalCell normalCellForSel:@selector(wcvoice_voicePackFolderRowTapped:) target:self title:name detail:detail];
            objc_setAssociatedObject(cell, kWCVoiceFolderCellPathAssocKey, full, OBJC_ASSOCIATION_COPY_NONATOMIC);
            [section addCell:cell];
        }
        for (NSString *name in files) {
            WCTableViewCellManager *cell = [NormalCell normalCellForSel:@selector(wcvoice_voicePackFileRowTapped:) target:self title:name rightValue:@"" accessoryType:1];
            objc_setAssociatedObject(cell, kWCVoiceFileCellPathAssocKey, [dirPath stringByAppendingPathComponent:name], OBJC_ASSOCIATION_COPY_NONATOMIC);
            [section addCell:cell];
        }
        [self.tableViewMgr addSection:section];
    }
    
    [[self.tableViewMgr getTableView] reloadData];
    [self wcvoice_installTableDelegateProxyIfNeeded];
}

- (BOOL)wcvoice_voicePackSwipeActionsAllowedAtIndexPath:(NSIndexPath *)indexPath {
    return [self wcvoice_fullPathForContentRowAtIndexPath:indexPath].length > 0;
}

- (NSString *)wcvoice_fullPathForContentRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isSearching) {
        NSUInteger row = indexPath.row;
        if (row < self.searchResults.count) {
            return self.searchResults[row];
        }
        return nil;
    }
    
    NSUInteger row = indexPath.row;
    if (row < self.wcvoice_voicePackFolderPathsOrdered.count) return self.wcvoice_voicePackFolderPathsOrdered[row];
    row -= self.wcvoice_voicePackFolderPathsOrdered.count;
    if (row < self.wcvoice_voicePackFilePathsOrdered.count) return self.wcvoice_voicePackFilePathsOrdered[row];
    return nil;
}

- (void)wcvoice_installTableDelegateProxyIfNeeded {
    MMTableView *tv = (MMTableView *)[self.tableViewMgr getTableView];
    if (![tv.delegate isKindOfClass:[WCVoicePackTableDelegateProxy class]]) {
        WCVoicePackTableDelegateProxy *proxy = [[WCVoicePackTableDelegateProxy alloc] init];
        id target = tv.delegate ? (id)tv.delegate : (id)tv.dataSource;
        proxy.forwardTarget = target;
        proxy.host = self;
        tv.delegate = proxy;
        tv.dataSource = proxy;
        self.wcvoice_tableDelegateProxy = proxy;
    }
}

- (void)wcvoice_requestDeleteVoicePackItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *full = [self wcvoice_fullPathForContentRowAtIndexPath:indexPath];
    [[NSFileManager defaultManager] removeItemAtPath:full error:nil];
    if (self.isSearching) {
        [self performSearchWithKeyword:self.searchBar.text];
    } else {
        [self reloadTableData];
    }
    [self wcvoice_syncMMPageSheetNavigationBar];
}

- (void)wcvoice_requestRenameVoicePackItemAtIndexPath:(NSIndexPath *)indexPath {
    [self wcvoice_showRenameInputForIndexPath:indexPath errorMessage:nil];
}

- (void)wcvoice_showRenameInputForIndexPath:(NSIndexPath *)indexPath errorMessage:(NSString *)errorMessage {
    NSString *oldFull = [self wcvoice_fullPathForContentRowAtIndexPath:indexPath];
    NSString *parent = [oldFull stringByDeletingLastPathComponent];
    NSString *oldFileName = [oldFull lastPathComponent];
    NSString *oldExtension = [oldFull pathExtension];
    NSString *baseName = oldFileName;
    if (oldExtension.length > 0 && [oldFileName hasSuffix:[@"." stringByAppendingString:oldExtension]]) {
        baseName = [oldFileName substringToIndex:oldFileName.length - oldExtension.length - 1];
    }
    
    NSString *message = errorMessage ?: @"请输入新名称";
    
    Class tipsCls = objc_getClass("MMTipsViewController");
    __weak typeof(self) weakSelf = self;
    __block id tipsVC = [[tipsCls alloc] initWithTitle:@"重命名"
                                               message:message
                                              btnTitle:@"取消"
                                               handler:nil
                                              btnTitle:@"确定"
                                               handler:^{
        UITextView *tv = [tipsVC getTextView];
        NSString *newBaseName = [tv.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [weakSelf wcvoice_performVoicePackRenameFromPath:oldFull parent:parent newBaseName:newBaseName forIndexPath:indexPath];
    }];
    [tipsVC addTextViewWithMaxLen:256];
    [tipsVC setTextFieldDefaultText:baseName];
    [tipsVC show];
}

- (void)wcvoice_performVoicePackRenameFromPath:(NSString *)oldFull
                                        parent:(NSString *)parent
                                   newBaseName:(NSString *)baseName
                                  forIndexPath:(NSIndexPath *)indexPath {
    NSString *oldExtension = [oldFull pathExtension];
    NSString *newName = baseName;
    if (oldExtension.length > 0) {
        newName = [baseName stringByAppendingPathExtension:oldExtension];
    }
    NSString *newPath = [parent stringByAppendingPathComponent:newName];
    
    if (baseName.length == 0 || [[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
        [self wcvoice_showRenameInputForIndexPath:indexPath errorMessage:@"名称无效或已存在，请重新输入"];
        return;
    }
    
    [[NSFileManager defaultManager] moveItemAtPath:oldFull toPath:newPath error:nil];
    if (self.isSearching) {
        [self performSearchWithKeyword:self.searchBar.text];
    } else {
        [self reloadTableData];
    }
    [self wcvoice_syncMMPageSheetNavigationBar];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    self.isSearching = YES;
    self.searchResults = @[];
    [self reloadTableData];
    
    UINavigationController *nav = self.navigationController;
    if (nav) {
        id config = objc_getAssociatedObject(nav, kWCVoicePackSheetConfigKey);
        if (config) {
            UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
            [cancelBtn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
            cancelBtn.titleLabel.font = [UIFont systemFontOfSize:17];
            [cancelBtn sizeToFit];
            [cancelBtn addTarget:self action:@selector(searchCancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            
            ((void (*)(id, SEL, id))objc_msgSend)(config, @selector(setNavRightButton:), cancelBtn);
            [self wcvoice_syncMMPageSheetNavigationBar];
        }
    }
    
    [searchBar becomeFirstResponder];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self performSearchWithKeyword:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchCancelButtonTapped {
    [self clearSearch];
}

- (void)performSearchWithKeyword:(NSString *)keyword {
    if (!keyword.length) {
        self.searchResults = @[];
    } else {
        NSString *rootDir = WCVoicePackDirectoryPath();
        self.searchResults = WCVoiceSearchAudioFilesInDirectory(rootDir, keyword);
    }
    [self reloadTableData];
}

- (void)clearSearch {
    self.isSearching = NO;
    self.searchResults = @[];
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    
    [self wcvoice_updateVoicePackPlusBarButtonVisibility];
    [self reloadTableData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.wcvoice_tableDelegateProxy forwardTarget] ? [(id)[self.wcvoice_tableDelegateProxy forwardTarget] tableView:tableView numberOfRowsInSection:section] : 0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self.wcvoice_tableDelegateProxy forwardTarget] ? [(id)[self.wcvoice_tableDelegateProxy forwardTarget] tableView:tableView cellForRowAtIndexPath:indexPath] : nil;
}

@end

#pragma mark - UINavigationController 分类

@interface UINavigationController (WCVoicePackSheet)
- (void)wcvoice_voicePackSheetBackInvoked:(id)sender;
@end

@implementation UINavigationController (WCVoicePackSheet)

- (void)wcvoice_voicePackSheetBackInvoked:(id)sender {
    UIViewController *fromVC = objc_getAssociatedObject(self, kWCVoicePackSheetFromVCKey);
    if (self.viewControllers.count > 1) {
        [self popViewControllerAnimated:YES];
    } else if (fromVC && [fromVC respondsToSelector:@selector(dismissWCVoiceListPageSheet)]) {
        [fromVC performSelector:@selector(dismissWCVoiceListPageSheet)];
    }
}

@end

#pragma mark - 音频处理与发送

static unsigned int WCVoicePackDurationMsFromFile(NSString *path) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path] options:nil];
    CMTime t = asset.duration;
    if (CMTIME_IS_NUMERIC(t) && !CMTIME_IS_INDEFINITE(t)) {
        Float64 sec = CMTimeGetSeconds(t);
        if (sec > 0 && sec < 3600) return (unsigned int)llround(sec * 1000);
    }
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long fileSize = [attrs fileSize];
    if (fileSize > 0) return (unsigned int)(fileSize / 2000) * 1000;
    return 3000;
}

static NSData *WCVoicePackDecodeFileToPCM16kMonoS16LE(NSURL *fileURL) {
    AVAudioFile *inFile = [[AVAudioFile alloc] initForReading:fileURL error:nil];
    if (!inFile) return nil;
    AVAudioFormat *inFmt = inFile.processingFormat;
    AVAudioFormat *outFmt = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16 sampleRate:16000 channels:1 interleaved:YES];
    AVAudioConverter *converter = [[AVAudioConverter alloc] initFromFormat:inFmt toFormat:outFmt];
    __block BOOL inputEOF = NO;
    AVAudioConverterInputBlock inputBlock = ^AVAudioBuffer *(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
        if (inputEOF) { *outStatus = AVAudioConverterInputStatus_EndOfStream; return nil; }
        AVAudioPCMBuffer *inBuf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:inFmt frameCapacity:8192];
        if (![inFile readIntoBuffer:inBuf error:nil] || inBuf.frameLength == 0) {
            inputEOF = YES;
            *outStatus = AVAudioConverterInputStatus_EndOfStream;
            return nil;
        }
        *outStatus = AVAudioConverterInputStatus_HaveData;
        return inBuf;
    };
    NSMutableData *pcm = [NSMutableData data];
    while (1) {
        AVAudioPCMBuffer *outBuf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:outFmt frameCapacity:16384];
        AVAudioConverterOutputStatus st = [converter convertToBuffer:outBuf error:nil withInputFromBlock:inputBlock];
        if (outBuf.frameLength) [pcm appendBytes:outBuf.audioBufferList->mBuffers[0].mData length:outBuf.audioBufferList->mBuffers[0].mDataByteSize];
        if (st == AVAudioConverterOutputStatus_EndOfStream || outBuf.frameLength == 0) break;
    }
    return pcm;
}

static NSData *WCVoicePackEncodePCMWithMJSilkCodec(NSData *pcm) {
    Class silkCls = objc_getClass("MJSilkCodec");
    if (!silkCls) return nil;
    id codec = ((id (*)(id, SEL))objc_msgSend)([silkCls alloc], @selector(init));
    ((BOOL (*)(id, SEL, long long))objc_msgSend)(codec, @selector(initEncoderWithSampleRate:), 16000LL);
    id ret = ((id (*)(id, SEL, id))objc_msgSend)(codec, @selector(encodeFromPCMData:), pcm);
    ((void (*)(id, SEL))objc_msgSend)(codec, @selector(uninitEncoder));
    return ret;
}

static NSData *WCVoicePackNormalizeEncodedSilkForWeChat(NSData *silk) {
    const uint8_t *p = (const uint8_t *)silk.bytes;
    if (silk.length >= 1 && p[0] == 0x02) return silk;
    static const uint8_t kWxHead[] = { 0x02, '#', '!', 'S', 'I', 'L', 'K', '_', 'V', '3' };
    NSMutableData *o = [NSMutableData dataWithBytes:kWxHead length:sizeof(kWxHead)];
    [o appendData:silk];
    return o;
}

static NSData *WCVoicePackPrepareSilkPayloadFromPath(NSString *path, unsigned int *outDurationMs) {
    if (WCVoicePackPathLooksLikeSilkOrAud(path)) {
        NSData *raw = [NSData dataWithContentsOfFile:path];
        *outDurationMs = WCVoicePackDurationMsFromFile(path);
        return raw;
    }
    unsigned int durMs = WCVoicePackDurationMsFromFile(path);
    NSData *pcm = WCVoicePackDecodeFileToPCM16kMonoS16LE([NSURL fileURLWithPath:path]);
    *outDurationMs = durMs;
    if (!pcm) return nil;
    NSData *silk = WCVoicePackEncodePCMWithMJSilkCodec(pcm);
    return WCVoicePackNormalizeEncodedSilkForWeChat(silk);
}

static BOOL WCVoicePackSendSilkPayload(NSData *silkData, unsigned int voiceTimeMs, NSString *chatId) {
    if (!silkData.length || !chatId.length) return NO;
    
    // 秒数一律用真实时长：伪装秒数由 DD语音助手 提供，这里不再重复实现
    unsigned int voiceMs = voiceTimeMs;
    if (voiceMs < 300) voiceMs = 300;
    if (voiceMs > 60000) voiceMs = 60000;
    
    id ctx = [objc_getClass("MMContext") activeUserContext] ?: [objc_getClass("MMContext") rootContext];
    if (!ctx) return NO;
    
    id contactMgr = [ctx getService:objc_getClass("CContactMgr")];
    id selfContact = [contactMgr getSelfContact];
    NSString *myUserId = ((NSString *(*)(id, SEL))objc_msgSend)(selfContact, @selector(m_nsUsrName));
    if (!myUserId.length) return NO;
    
    Class msgCls = objc_getClass("CMessageWrap");
    id voiceMsg = ((id (*)(id, SEL, long long, id))objc_msgSend)([msgCls alloc], @selector(initWithMsgType:nsFromUsr:), 34LL, myUserId);
    if (!voiceMsg) return NO;
    
    ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(setM_nsFromUsr:), myUserId);
    ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(setM_nsToUsr:), chatId);
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(voiceMsg, @selector(setM_uiStatus:), 1u);
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(voiceMsg, @selector(setM_uiDownloadStatus:), 9u);
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(voiceMsg, @selector(setM_uiVoiceFormat:), 4u);
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(voiceMsg, @selector(setM_uiVoiceTime:), voiceMs);
    ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(setM_nsMsgSource:), nil);
    
    id sessionMgr = [ctx getService:objc_getClass("MMNewSessionMgr")];
    unsigned int createTime = ((unsigned int (*)(id, SEL))objc_msgSend)(sessionMgr, @selector(GenSendMsgTime));
    ((void (*)(id, SEL, unsigned int))objc_msgSend)(voiceMsg, @selector(setM_uiCreateTime:), createTime);
    
    id msgMgr = [ctx getService:objc_getClass("CMessageMgr")];
    ((void (*)(id, SEL, id, id))objc_msgSend)(msgMgr, @selector(AddLocalMsg:MsgWrap:), chatId, voiceMsg);
    unsigned int localID = (unsigned int)((NSUInteger (*)(id, SEL))objc_msgSend)(voiceMsg, @selector(m_uiMesLocalID));
    
    Class utilClass = objc_getClass("CUtility");
    NSString *docPath = ((NSString *(*)(Class, SEL))objc_msgSend)(utilClass, @selector(GetDocPath));
    NSString *audioPath = ((NSString *(*)(Class, SEL, NSString *, unsigned int, NSString *))objc_msgSend)(utilClass, @selector(GetPathOfMesAudio:LocalID:DocPath:), chatId, localID, docPath);
    [[NSFileManager defaultManager] createDirectoryAtPath:[audioPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    [silkData writeToFile:audioPath atomically:YES];
    // 必须显式告诉微信文件落在哪，否则 ResendVoiceMsg 会按 localID 重算路径、读到坏文件
    if (audioPath.length) ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(setM_nsVoicePath:), audioPath);
    
    Class extCls = objc_getClass("CExtendInfoOfVoiceMsg");
    if (extCls) {
        id extInfo = ((id (*)(id, SEL))objc_msgSend)([extCls alloc], @selector(init));
        ((void (*)(id, SEL, id))objc_msgSend)(extInfo, @selector(setM_dtVoice:), silkData);
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(extInfo, @selector(setM_uiVoiceTime:), voiceMs);
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(extInfo, @selector(setM_uiVoiceFormat:), 4u);
        // 结束标记：不置 1 微信会认为这条语音数据不完整
        ((void (*)(id, SEL, unsigned int))objc_msgSend)(extInfo, @selector(setM_uiVoiceEndFlag:), 1u);
        ((void (*)(id, SEL, id))objc_msgSend)(extInfo, @selector(setM_refMessageWrap:), voiceMsg);
        
        SEL setExtSel = NSSelectorFromString(@"setM_extendInfoWithMsgType:");
        if ([voiceMsg respondsToSelector:setExtSel]) {
            ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, setExtSel, extInfo);
        }
    }
    
    ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(setM_dtVoice:), silkData);
    ((void (*)(id, SEL, id))objc_msgSend)(voiceMsg, @selector(UpdateContent:), nil);
    
    if ([msgMgr respondsToSelector:@selector(ModMsg:MsgWrap:)]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(msgMgr, @selector(ModMsg:MsgWrap:), chatId, voiceMsg);
    }
    // 落盘：DD语音助手验证过的必要步骤，首参传 nil（传 NSData 会被当成路径）
    if ([msgMgr respondsToSelector:@selector(SaveMesVoice:MsgWrap:)]) {
        ((BOOL (*)(id, SEL, id, id))objc_msgSend)(msgMgr, @selector(SaveMesVoice:MsgWrap:), nil, voiceMsg);
    }
    
    // 上传：AudioSender 是微信语音发送链路上的服务对象，ResendVoiceMsg:MsgWrap: 是唯一入口。
    // 不再 KVC 取 m_upload（取不到会抛 NSUndefinedKeyException 直接崩），也不再退 MMNewUploadVoiceMgr。
    id audioSender = [ctx getService:objc_getClass("AudioSender")];
    if (audioSender && [audioSender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
        ((void (*)(id, SEL, id, id))objc_msgSend)(audioSender, @selector(ResendVoiceMsg:MsgWrap:), chatId, voiceMsg);
        return YES;
    }
    return NO;
}

@interface WCVoicePackSenderNoteSink : NSObject
- (void)onVoicePackSilkNote:(NSNotification *)note;
@end

@implementation WCVoicePackSenderNoteSink
- (void)onVoicePackSilkNote:(NSNotification *)note {
    NSString *path = note.userInfo[kWCVoicePackDidSelectSilkFilePathKey];
    NSString *chatId = note.userInfo[kWCVoicePackTargetChatUserNameKey];
    if (!path.length || !chatId.length) return;
    unsigned int ms = 0;
    NSData *silk = WCVoicePackPrepareSilkPayloadFromPath(path, &ms);
    if (!silk) return;
    if (ms < 500) ms = 3000;
    if (WCVoicePackSendSilkPayload(silk, ms, chatId)) {
        [WCVoiceListController wcvoice_dismissVoicePackPageSheetAfterSendIfConfigured];
    }
}
@end

static WCVoicePackSenderNoteSink *sSenderSink;

@interface WCVoicePackSender : NSObject
@end

@implementation WCVoicePackSender
+ (void)load {
    sSenderSink = [WCVoicePackSenderNoteSink new];
    [[NSNotificationCenter defaultCenter] addObserver:sSenderSink selector:@selector(onVoicePackSilkNote:) name:kWCVoicePackDidSelectSilkFileNotification object:nil];
}
@end

#pragma mark - 设置控制器

@interface WCVoiceSettingsController : UIViewController <UIDocumentPickerDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
- (void)reloadTableData;
@end

@implementation WCVoiceSettingsController

- (instancetype)init {
    if (self = [super init]) {
        _tableViewManager = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleInsetGrouped];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"语音包设置";

    // 表格整屏延伸，由 viewDidLayoutSubviews 推到导航栏底边
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_tableViewManager.tableView];

    [self reloadTableData];
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

- (void)reloadTableData {
    [_tableViewManager clearAllSection];
    
    WCTableViewSectionManager *sec = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"语音包设置（长按+打开入口）"];
    BOOL mainOn = [WCVoiceConfig messageVoicePackManagementEnabled];
    [sec addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(mainSwitchChanged:) target:self title:@"启用语音包" on:mainOn]];
    if (mainOn) {
        [sec addCell:[objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(keepPanelChanged:) target:self title:@"↳持续发送" on:[WCVoiceConfig messageVoicePackKeepPanelAfterSend]]];
    }
    [_tableViewManager addSection:sec];
    
    WCTableViewSectionManager *ioSec = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"数据管理"];
    [ioSec addCell:[objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(importVoicePack) target:self title:@"导入语音包" rightValue:@"" accessoryType:1]];
    [ioSec addCell:[objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(exportVoicePack) target:self title:@"导出语音包" rightValue:@"" accessoryType:1]];
    [_tableViewManager addSection:ioSec];
    
    [_tableViewManager reloadTableView];
}

- (void)mainSwitchChanged:(UISwitch *)s { 
    BOOL newValue = s.isOn;
    [WCVoiceConfig setMessageVoicePackManagementEnabled:newValue];
    if (newValue) {
        [WCVoiceListController wcvoice_ensureVoicePackRootDirectoryExists];
    }
    [self reloadTableData]; 
}
- (void)keepPanelChanged:(UISwitch *)s { 
    [WCVoiceConfig setMessageVoicePackKeepPanelAfterSend:s.isOn]; 
}
- (NSString *)voicePackRootDirectory {
    return WCVoicePackDirectoryPath();
}

- (void)importVoicePack {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder, UTTypeAudio] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)exportVoicePack {
    NSURL *voiceDirURL = [NSURL fileURLWithPath:[self voicePackRootDirectory] isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:voiceDirURL withIntermediateDirectories:YES attributes:nil error:nil];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[voiceDirURL] asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    [self handleImportedURLs:urls];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}

- (void)handleImportedURLs:(NSArray<NSURL *> *)urls {
    NSString *destRoot = [self voicePackRootDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:destRoot withIntermediateDirectories:YES attributes:nil error:nil];
    
    for (NSURL *url in urls) {
        [self copyItemAtURL:url toDirectory:destRoot];
    }
}

- (void)copyItemAtURL:(NSURL *)srcURL toDirectory:(NSString *)destDir {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    [fm fileExistsAtPath:srcURL.path isDirectory:&isDir];
    
    if (isDir) {
        NSArray *contents = [fm contentsOfDirectoryAtURL:srcURL includingPropertiesForKeys:nil options:0 error:nil];
        for (NSURL *itemURL in contents) {
            NSString *itemName = [itemURL lastPathComponent];
            NSString *dstPath = [destDir stringByAppendingPathComponent:itemName];
            [fm removeItemAtPath:dstPath error:nil];
            [fm copyItemAtURL:itemURL toURL:[NSURL fileURLWithPath:dstPath] error:nil];
        }
    } else {
        NSString *name = [srcURL lastPathComponent];
        NSString *dstPath = [destDir stringByAppendingPathComponent:name];
        [fm removeItemAtPath:dstPath error:nil];
        [fm copyItemAtPath:srcURL.path toPath:dstPath error:nil];
    }
}

@end

#pragma mark - Hook 逻辑

static UIWindow *WCVoiceGetKeyWindow(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) if (w.isKeyWindow) return w;
        }
    }
    return nil;
}

static UIViewController *WCVoiceTopViewController(void) {
    UIWindow *win = WCVoiceGetKeyWindow();
    UIViewController *top = win.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if ([top isKindOfClass:[UINavigationController class]]) top = [(UINavigationController *)top topViewController];
    else if ([top isKindOfClass:[UITabBarController class]]) {
        UIViewController *sel = [(UITabBarController *)top selectedViewController];
        if ([sel isKindOfClass:[UINavigationController class]]) top = [(UINavigationController *)sel topViewController];
        else top = sel;
    }
    return top;
}

static NSString *WCVoiceGetVoiceFilePathForImport(CMessageWrap *msg) {
    Class cls = objc_getClass("CMessageWrap");
    BOOL isSender = ((BOOL (*)(id, SEL, id))objc_msgSend)(cls, @selector(isSenderFromMsgWrap:), msg);
    NSString *chat = isSender ? ((NSString *(*)(id, SEL))objc_msgSend)(msg, @selector(m_nsToUsr)) : ((NSString *(*)(id, SEL))objc_msgSend)(msg, @selector(m_nsFromUsr));
    Class util = objc_getClass("CUtility");
    NSString *doc = ((NSString *(*)(Class, SEL))objc_msgSend)(util, @selector(GetDocPath));
    return ((NSString *(*)(Class, SEL, NSString *, unsigned int, NSString *))objc_msgSend)(util, @selector(GetPathOfMesAudio:LocalID:DocPath:), chat, (unsigned int)((NSUInteger (*)(id, SEL))objc_msgSend)(msg, @selector(m_uiMesLocalID)), doc);
}

%hook MMUIButton
- (void)didMoveToSuperview {
    %orig;
    if (![WCVoiceConfig messageVoicePackManagementEnabled]) return;
    if ([self.accessibilityLabel isEqualToString:@"更多"]) {
        UILongPressGestureRecognizer *lp = objc_getAssociatedObject(self, kWCVoiceLongPressGestureKey);
        if (!lp) {
            lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(wcvoice_moreLongPress:)];
            lp.minimumPressDuration = 1.0;
            [self addGestureRecognizer:lp];
            objc_setAssociatedObject(self, kWCVoiceLongPressGestureKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
%new
- (void)wcvoice_moreLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [WCVoiceListController presentVoicePackPageSheetFromViewController:WCVoiceTopViewController()];
    }
}
%end

// 菜单项去重标记：MMMenuItem 没有 title / action 的 getter，只能用 userInfo 做记号
static NSString *WCVoiceMenuToken(SEL action) {
    return [@"wcvoice:" stringByAppendingString:NSStringFromSelector(action)];
}

// 往菜单末尾追加一项（开关关闭 / 已注入过则原样返回）
static NSArray *WCVoiceInjectMenuItem(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    if (!enabled || !original) return original;
    NSString *token = WCVoiceMenuToken(action);
    for (MMMenuItem *it in original) {
        id ui = [it userInfo];
        if ([ui isKindOfClass:[NSString class]] && [(NSString *)ui isEqualToString:token]) return original;
    }
    Class cls = objc_getClass("MMMenuItem");
    MMMenuItem *item = [[cls alloc] initWithTitle:title
                                          svgName:@"biz_audio_outlined_star"
                                           target:cell
                                           action:action];
    if (!item) return original;
    [item setUserInfo:token];
    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];
    return items;
}

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *items = %orig;
    CMessageWrap *msg = [self getMediaWrap];
    BOOL isVoice = msg && ((NSUInteger (*)(id, SEL))objc_msgSend)(msg, @selector(m_uiMessageType)) == 34;
    return WCVoiceInjectMenuItem(self, items,
                                 [WCVoiceConfig messageVoicePackManagementEnabled] && isVoice,
                                 @"纳入", @selector(wcvoice_importVoice:));
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(wcvoice_importVoice:)) {
        CMessageWrap *msg = [self getMediaWrap];
        return [WCVoiceConfig messageVoicePackManagementEnabled] && msg && ((NSUInteger (*)(id, SEL))objc_msgSend)(msg, @selector(m_uiMessageType)) == 34;
    }
    // %orig 独占一行：Logos 对行尾内容的处理很糙，跟其他语句写同一行容易出编译错
    BOOL origResult = %orig;
    return origResult;
}

%new
- (void)wcvoice_importVoice:(id)sender {
    CMessageWrap *msg = [self getMediaWrap];
    NSString *path = WCVoiceGetVoiceFilePathForImport(msg);
    [WCVoiceListController wcvoice_setPendingVoiceImportFromChatPath:path];
    UIViewController *vc = [self respondsToSelector:@selector(getViewController)] ? [self getViewController] : nil;
    if (!vc) {
        UIResponder *r = self;
        while ((r = [r nextResponder])) if ([r isKindOfClass:[UIViewController class]]) { vc = (UIViewController *)r; break; }
    }
    if (vc) [WCVoiceListController presentVoicePackPageSheetFromViewController:vc];
    else [WCVoiceListController wcvoice_clearPendingVoiceImportFromChat];
}
%end

#pragma mark - 插件注册

%ctor {
    [WCVoicePackSender class];
    
    Class mgr = objc_getClass("WCPluginsMgr");
    if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
        id inst = [mgr sharedInstance];
        if ([inst respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
            [inst registerControllerWithTitle:@"DD语音包" version:@"1.0.0" controller:@"WCVoiceSettingsController"];
        }
    }
}

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

/* ============================================================================
 * DD收藏语音转发 1.0.0
 * 全部逻辑逐条对齐锤子二进制反汇编结果，每条源码都标注了证据地址。
 * ==========================================================================*/

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewManager : NSObject
- (id)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
@end

// WCTableViewNormalCellManager.h:29
@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 accessoryType:(long long)arg4;
@end

@interface MMUIViewController : UIViewController
- (void)startLoadingWithText:(id)arg1;
- (void)stopLoading;
@end

// FavoritesItemDataField.h:192 duration / :245 GetDataPath
@interface FavoritesItemDataField : NSObject
@property(nonatomic) unsigned int duration;
- (id)GetDataPath;
@end

// CMessageWrap.h:249 / :437 / :445 / :448 / :451 / :590 / :1067
@interface CMessageWrap : NSObject
+ (id)getPathOfMsgImg:(id)arg1;
+ (_Bool)isSenderFromMsgWrap:(id)arg1;
- (id)initWithMsgType:(long long)arg1;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) id m_extendInfoWithMsgType;
@end

// CExtendInfoOfVoiceMsg.h
@interface CExtendInfoOfVoiceMsg : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(nonatomic, weak) CMessageWrap *m_refMessageWrap;
@end

// 锤子 0x759700 用 respondsToSelector 动态探测，8.0.76 头文件已无此类方法
@interface CUtility : NSObject
+ (id)GetDocPath;
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

// FavoritesMgr.h:174
@interface FavoritesMgr : NSObject
- (void)startDownloadFavoritesItem:(id)arg1 IsPriority:(_Bool)arg2;
@end

// SettingUtil.h:37
@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

// AudioSender.h:33 / :74 / :76 / :78
@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;
- (_Bool)deleteMessageFromDB:(id)arg1;
- (_Bool)addMessageToDB:(id)arg1;
- (id)getAudioFileName:(id)arg1 LocalID:(unsigned int)arg2;
@end

// MMNewSessionMgr.h:134
@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

// CBaseContact.h:13
@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

// ForwardMsgUtil.h:37
@interface ForwardMsgUtil : NSObject
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1;
@end

// ---- 下面是被 hook 的类，全部手写完整 interface，不做前向声明 ----

// FavoritesItem.h:153 type / :160 dataList / :171 needDownLoad / :177 / :183 / :184
@interface FavoritesItem : NSObject
@property(nonatomic) int type;
@property(retain, nonatomic) NSArray *dataList;
- (_Bool)needDownLoad;
- (_Bool)canBeForward;
- (id)canBeForwardWithMsg;
- (id)canBeForwardWithMsg:(_Bool)arg1;
@end

// MyFavoritesListViewController.h:10 / :29
@interface MyFavoritesListViewController : MMUIViewController
- (void)forwardData:(id)arg1;
@end

// FavForwardLogicController.h:13 ivar NSMutableArray *m_messageWrapList
@interface FavForwardLogicController : NSObject
- (void)addMsgFromItem:(id)arg1;
@end

// ForwardMessageLogicController.h:147 / :148 / :149 / :150
@interface ForwardMessageLogicController : NSObject
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3;
@end

// BaseMessageCellView.h + 8.0.76 反汇编双重确认：原生转发按钮相关方法。
// -canShowForwardMenuItem 是转发"可见性"闸门（语音默认返回 NO，见 0x1002a248c 的委派包装）；
// -forwardMenuItem 构造原生转发项（动作固定为 onForward:，见 0x1002a2300 的 initWithType:action:）；
// -onForward: 内部先校验 [messageWrap respondsToSelector:tryHandleMenu:withViewModel:]（0x1002a2384/0x1002a2394
//   的 tbz w22 分支），语音会被判为不可转发而直接跳走；-doForward 是已实测可用的转发触发入口。
// 本接口必须写在 VoiceMessageCellView 之前，因为后者继承它。
@interface BaseMessageCellView : NSObject
- (BOOL)canShowForwardMenuItem;
- (id)forwardMenuItem;
- (void)onForward:(id)arg1;
- (void)doForward;
@end

// VoiceMessageCellView.h：operationMenuItems / canPerformAction: 均由头文件确认
// doForward / forwardMenuItem / onForward: 是 BaseMessageCellView 声明的原生转发动作。
// 这里让它继承 BaseMessageCellView，以便直接调用其转发生态方法（forwardMenuItem / doForward / onForward:）。
@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

#pragma mark - 配置（两个独立开关，默认均 OFF）
// 对齐锤子双开关：enableVoiceForward(0x8d2fc0) 与 enableFavoritesVoiceForward(0x8d2920)
#define kDDFVEnableFav @"kDDFV_enableFavVoiceForward"   // 收藏语音转发
#define kDDFVEnableMsg @"kDDFV_enableVoiceMsgForward"    // 语音消息转发

// 锤子常量全部来自反汇编实测，不是约定的猜测值
// 0x78f0d4 / 0x78f110 / 0x78f2dc : type == 3 判定收藏语音
static const int kDDFavVoiceItemType = 3;
// 0x78f664 / 0x78f710 / 0x790900 : m_uiMessageType == 0x22 判定语音消息
static const long long kDDVoiceMsgType = 34;
// 0x7595d4 setM_uiVoiceFormat: mov w2,#4
static const unsigned int kDDVoiceFormat = 4;
// 0x7595e0 setM_uiVoiceEndFlag: mov w2,#1
static const unsigned int kDDVoiceEndFlag = 1;
// 0x75a018 setM_uiStatus: mov w2,#1
static const unsigned int kDDMsgStatusSending = 1;
// 0x7901b4 轮询上限 0xf0 次；0x7901d0 每次 sleepForTimeInterval: 0.25
static const int kDDDownloadWaitMax = 240;
static const NSTimeInterval kDDDownloadWaitStep = 0.25;
// 0x7906a4 ~ 0x7906bc : localID = X + 0x2710(10000)，X 由外部函数生成于 [0, 0x15f90) 区间
static const unsigned int kDDVoiceLocalIDBase = 10000;
static const unsigned int kDDVoiceLocalIDRange = 0x15f90;
// 收藏语音来源：把 FavoritesItem 绑到构造出的语音 wrap 上，供「发送时下载」反查并下载
static const void *kDDFavSourceKey = &kDDFavSourceKey;

@interface DDFavVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL favEnabled;  // 收藏语音转发
@property (assign, nonatomic) BOOL msgEnabled;  // 语音消息转发
@end

@implementation DDFavVoiceConfig
+ (instancetype)sharedConfig {
    static DDFavVoiceConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDFavVoiceConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDFavVoiceConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDFVEnableFav: @NO,
        kDDFVEnableMsg: @NO,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _favEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnableFav];
        _msgEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnableMsg];
    }
    return self;
}
- (void)setFavEnabled:(BOOL)v {
    _favEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnableFav];
}
- (void)setMsgEnabled:(BOOL)v {
    _msgEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnableMsg];
}
@end

// 收藏语音转发：仅由「收藏语音转发」开关控制（不依赖语音消息转发）
// FavoritesItem(0x78f0f4/0x78f100) / forwardData(0x78f27c/0x78f288) / addMsgFromItem(0x78f51c/0x78f528)
// 原二进制里收藏三件套确实还读了 enableVoiceForward(0x8d2fc0)，但用户要求两个开关可独立控制，
// 故收藏链路只认 favEnabled；发送汇点另由 ddForwardSendEnabled 兜底，保证只开收藏也能真正发出去。
static BOOL ddFavVoiceEnabled(void) {
    return [DDFavVoiceConfig sharedConfig].favEnabled;
}
// 语音消息转发：对应 enableVoiceForward(0x8d2fc0)，门控长按菜单「转发」按钮 + 原生降级防护
static BOOL ddVoiceMsgEnabled(void) {
    return [DDFavVoiceConfig sharedConfig].msgEnabled;
}
// 发送汇点（ForwardMessageLogicController）+ 降级防护（ForwardMsgUtil）：只要任一开关开启就接管。
// 因为收藏语音最终也会被构造成 type=34、走发送汇点发出；只开收藏时若汇点不接管就会静默失败，
// 所以这里取 fav || msg。这是两个开关之间唯一无法彻底拆开的点，已按证据与意图取舍。
static BOOL ddForwardSendEnabled(void) {
    DDFavVoiceConfig *c = [DDFavVoiceConfig sharedConfig];
    return c.favEnabled || c.msgEnabled;
}

#pragma mark - 日志
/* 证书注入环境读不到 syslog，所以日志同时写内存和 Documents/ddfavvoice.log，
 * 由「运行日志」页展示，可复制或通过系统分享导出到「文件」App。 */
#define kDDFVLogMaxLines 800

static NSMutableArray<NSString *> *gDDFVLogs = nil;
static NSObject *gDDFVLogLock = nil;

static NSObject *dd_logLock(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gDDFVLogLock = [NSObject new]; });
    return gDDFVLogLock;
}

static NSString *dd_logPath(void) {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([dirs count] == 0) return nil;
    return [(NSString *)[dirs firstObject] stringByAppendingPathComponent:@"ddfavvoice.log"];
}

static NSString *dd_timeStamp(void) {
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"MM-dd HH:mm:ss.SSS"];
    return [f stringFromDate:[NSDate date]];
}

static void dd_logInit(void) {
    @synchronized (dd_logLock()) {
        if (gDDFVLogs) return;
        gDDFVLogs = [NSMutableArray array];
        NSString *p = dd_logPath();
        NSData *old = [NSData dataWithContentsOfFile:p];
        if ([old length] == 0) return;
        NSString *txt = [[NSString alloc] initWithData:old encoding:NSUTF8StringEncoding];
        if ([txt length] == 0) return;
        NSArray *lines = [txt componentsSeparatedByString:@"\n"];
        NSRange r = NSMakeRange(0, [lines count]);
        if ([lines count] > kDDFVLogMaxLines) r = NSMakeRange([lines count] - kDDFVLogMaxLines, kDDFVLogMaxLines);
        [gDDFVLogs addObjectsFromArray:[lines subarrayWithRange:r]];
    }
}

static void dd_logLine(NSString *line) {
    if ([line length] == 0) return;
    NSLog(@"[DDFavVoice] %@", line);          // 越狱/带控制台时仍然打到系统日志
    @synchronized (dd_logLock()) {
        dd_logInit();
        NSString *record = [NSString stringWithFormat:@"%@ %@", dd_timeStamp(), line];
        [gDDFVLogs addObject:record];
        if ([gDDFVLogs count] > kDDFVLogMaxLines) {
            [gDDFVLogs removeObjectsInRange:NSMakeRange(0, [gDDFVLogs count] - kDDFVLogMaxLines)];
        }
        NSString *p = dd_logPath();
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
        if (!fh) {
            [[NSFileManager defaultManager] createFileAtPath:p contents:nil attributes:nil];
            fh = [NSFileHandle fileHandleForWritingAtPath:p];
        }
        if (fh) {
            [fh seekToEndOfFile];
            [fh writeData:[[record stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    }
}

#define DDLog(fmt, ...) dd_logLine(([NSString stringWithFormat:(fmt), ##__VA_ARGS__]))

static NSString *dd_logText(void) {
    @synchronized (dd_logLock()) {
        dd_logInit();
        if ([gDDFVLogs count] == 0) return @"暂无日志记录。开关打开后去聊天里转发一条收藏语音，再回到本页下拉刷新。";
        return [gDDFVLogs componentsJoinedByString:@"\n"];
    }
}

static void dd_logClear(void) {
    @synchronized (dd_logLock()) {
        dd_logInit();
        [gDDFVLogs removeAllObjects];
        [[NSFileManager defaultManager] removeItemAtPath:dd_logPath() error:nil];
        dd_logLine(@"日志已清空");
    }
}

#pragma mark - 判定工具

// 前向声明：定义见下方 dd_isInstanceOf（在首次使用前需先声明，否则 .mm 下报 undeclared）
static BOOL dd_isInstanceOf(id obj, const char *clsName);

static BOOL dd_isVoiceMsg(id msg) {
    if (!dd_isInstanceOf(msg, "CMessageWrap")) return NO;
    if (![msg respondsToSelector:@selector(m_uiMessageType)]) return NO;
    return ((CMessageWrap *)msg).m_uiMessageType == (unsigned int)kDDVoiceMsgType;
}

static BOOL dd_isFavVoiceItem(id obj) {
    if (!dd_isInstanceOf(obj, "FavoritesItem")) return NO;
    if (![obj respondsToSelector:@selector(type)]) return NO;
    return ((FavoritesItem *)obj).type == kDDFavVoiceItemType;
}

static BOOL dd_fileExists(NSString *path) {
    if (![path isKindOfClass:[NSString class]]) return NO;
    if ([path length] == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

// 共享的类型判定样板：objc_getClass + isKindOfClass
static BOOL dd_isInstanceOf(id obj, const char *clsName) {
    if (!obj) return NO;
    Class cls = objc_getClass(clsName);
    return cls && [obj isKindOfClass:cls];
}

// 对齐锤子 0x790644 / 0x759ecc：取当前登录用户名（SettingUtil getCurUsrName）
static NSString *dd_currentUsrName(void) {
    Class settingCls = objc_getClass("SettingUtil");
    if (!settingCls || ![settingCls respondsToSelector:@selector(getCurUsrName)]) return nil;
    id u = [settingCls getCurUsrName];
    return [u isKindOfClass:[NSString class]] ? (NSString *)u : nil;
}

static id dd_mmService(NSString *serviceName) {
    Class ctxCls = objc_getClass("MMContext");
    if (!ctxCls || ![ctxCls respondsToSelector:@selector(currentContext)]) return nil;
    id ctx = [ctxCls currentContext];
    if (!ctx || ![ctx respondsToSelector:@selector(getService:)]) return nil;
    Class svc = objc_getClass([serviceName UTF8String]);
    if (!svc) return nil;
    return [ctx getService:svc];
}

// 对齐锤子 0x7903b4 ~ 0x7903e4 与 0x78f3cc ~ 0x78f3f8
static void dd_startDownloadFavItem(id item) {
    Class ctxCls = objc_getClass("MMContext");
    Class mgrCls = objc_getClass("FavoritesMgr");
    if (!ctxCls || !mgrCls) return;
    if (![ctxCls respondsToSelector:@selector(currentContext)]) return;
    id ctx = [ctxCls currentContext];
    if (!ctx || ![ctx respondsToSelector:@selector(getService:)]) return;
    id mgr = [ctx getService:mgrCls];
    if (!mgr || ![mgr respondsToSelector:@selector(startDownloadFavoritesItem:IsPriority:)]) return;
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}

// 对齐锤子 0x7901b4 ~ 0x7901dc：轮询 needDownLoad，最多 240 次，每次 0.25s
static void dd_waitDownloadFinish(id item) {
    int remain = kDDDownloadWaitMax;
    while (remain-- > 0) {
        BOOL need = NO;
        if ([item respondsToSelector:@selector(needDownLoad)]) need = ((FavoritesItem *)item).needDownLoad;
        if (!need) break;
        [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
    }
}

// 对齐锤子 0x7903b4 发起下载 + 0x78fed0 DispatchQueue.global(qos:.utility).async{轮询→回主线程}
// 集中两处（addMsgFromItem: / forwardData:）重复的「后台轮询 + 主线程回调」样板
static void dd_downloadFavItemThen(id item, void (^done)(void)) {
    dd_startDownloadFavItem(item);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        dd_waitDownloadFinish(item);
        dispatch_async(dispatch_get_main_queue(), done);
    });
}

#pragma mark - 语音扩展信息

// 对齐锤子 0x75909c voiceExtendInfoForMessageWrap:createIfNeeded:
static id dd_voiceExtendInfo(id wrap, BOOL create) {
    if (!wrap) return nil;
    Class vcls = objc_getClass("CExtendInfoOfVoiceMsg");
    if (!vcls) return nil;
    if (![wrap respondsToSelector:@selector(m_extendInfoWithMsgType)]) return nil;
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext && [ext isKindOfClass:vcls]) return ext;
    if (!create) return nil;
    if (![wrap respondsToSelector:@selector(setM_extendInfoWithMsgType:)]) return nil;
    id nv = [[vcls alloc] init];
    if (!nv) return nil;
    // 0x7591a4 要求 5 个 setter 全部可用才继续
    if (![nv respondsToSelector:@selector(setM_uiVoiceTime:)] ||
        ![nv respondsToSelector:@selector(setM_uiVoiceFormat:)] ||
        ![nv respondsToSelector:@selector(setM_uiVoiceEndFlag:)] ||
        ![nv respondsToSelector:@selector(setM_dtVoice:)] ||
        ![nv respondsToSelector:@selector(setM_refMessageWrap:)]) {
        return nil;
    }
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}

// 对齐锤子 0x759474 voiceDataForMessageWrap:
static NSData *dd_voiceData(id wrap) {
    id ext = dd_voiceExtendInfo(wrap, NO);
    if (!ext) return nil;
    if (![ext respondsToSelector:@selector(m_dtVoice)]) return nil;
    return [ext m_dtVoice];
}

// 对齐锤子 0x759420 voiceDurationForMessageWrap: —— 直接返回 m_uiVoiceTime，无单位换算
static unsigned int dd_voiceDuration(id wrap) {
    id ext = dd_voiceExtendInfo(wrap, NO);
    if (!ext) return 0;
    if (![ext respondsToSelector:@selector(m_uiVoiceTime)]) return 0;
    return [ext m_uiVoiceTime];
}

// 对齐锤子 0x7594d0 configureVoiceMessageWrap:voiceData:duration:
// 对齐锤子 0x75951c：只写语音元信息（格式/结束标志/时长），不写音频数据，用于数据缺失时先构造"外壳"
static BOOL dd_configureVoiceMeta(id wrap, unsigned int duration) {
    if (!wrap || duration == 0) return NO;
    id ext = dd_voiceExtendInfo(wrap, YES);
    if (!ext) return NO;
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    return YES;
}

// 对齐锤子 0x75951c：把音频数据写进 m_dtVoice，供「发送时下载」在发送前补数据
static BOOL dd_injectVoiceData(id wrap, NSData *voiceData) {
    if (!wrap || [voiceData length] == 0) return NO;
    id ext = dd_voiceExtendInfo(wrap, YES);
    if (!ext) return NO;
    [ext setM_dtVoice:voiceData];
    return YES;
}

// 对齐锤子 0x75951c / 0x759520：元信息 + 数据，等价于旧版单函数
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    if (duration == 0 || [voiceData length] == 0) return NO;
    if (!dd_configureVoiceMeta(wrap, duration)) return NO;
    return dd_injectVoiceData(wrap, voiceData);
}

#pragma mark - 音频路径

// 对齐锤子 0x759a9c：决定语音文件归属哪个用户名
// 注意：MMService 侧还声明了返回 const void* 的同名类方法，必须走静态类型避免签名冲突
static NSString *dd_ownerUserForVoice(id msg) {
    if (![msg respondsToSelector:@selector(m_nsToUsr)]) return nil;
    id to = ((CMessageWrap *)msg).m_nsToUsr;
    if ([to isKindOfClass:[NSString class]]) {
        NSString *toStr = (NSString *)to;
        if ([toStr containsString:@"@chatroom"]) return toStr;
    }
    Class wrapCls = objc_getClass("CMessageWrap");
    if (wrapCls && [wrapCls respondsToSelector:@selector(isSenderFromMsgWrap:)]) {
        if ([wrapCls isSenderFromMsgWrap:msg] && [to isKindOfClass:[NSString class]]) return (NSString *)to;
    }
    if (![msg respondsToSelector:@selector(m_nsFromUsr)]) return nil;
    id from = ((CMessageWrap *)msg).m_nsFromUsr;
    return [from isKindOfClass:[NSString class]] ? (NSString *)from : nil;
}

// 对齐锤子 0x7596a8 voiceAudioPathForMessageWrap:
static NSString *dd_audioPathForMsg(id msg) {
    if (!msg) return nil;
    if (![msg respondsToSelector:@selector(m_uiMesLocalID)]) return nil;
    unsigned int localID = ((CMessageWrap *)msg).m_uiMesLocalID;
    // 0x7596e0：localID 为 0 直接返回 nil
    if (localID == 0) { DDLog(@"localID 为 0，拿不到音频路径"); return nil; }
    NSString *usr = dd_ownerUserForVoice(msg);
    if ([usr length] == 0) { DDLog(@"归属用户名为空，拿不到音频路径"); return nil; }
    DDLog(@"取音频路径 usr=%@ localID=%u", usr, localID);

    // 0x759714 ~ 0x759794：优先 CUtility GetPathOfMesAudio:LocalID:DocPath:
    Class cu = objc_getClass("CUtility");
    if (cu && [cu respondsToSelector:@selector(GetDocPath)] &&
        [cu respondsToSelector:@selector(GetPathOfMesAudio:LocalID:DocPath:)]) {
        id doc = [cu GetDocPath];
        if ([doc isKindOfClass:[NSString class]]) {
            id p = [cu GetPathOfMesAudio:usr LocalID:localID DocPath:doc];
            if ([p isKindOfClass:[NSString class]] && dd_fileExists((NSString *)p)) {
                DDLog(@"音频路径命中 CUtility");
                return (NSString *)p;
            }
        }
    }
    // 0x759840 ~ 0x75987c：其次 AudioSender getAudioFileName:LocalID:
    id sender = dd_mmService(@"AudioSender");
    if (sender && [sender respondsToSelector:@selector(getAudioFileName:LocalID:)]) {
        id p = [sender getAudioFileName:usr LocalID:localID];
        if ([p isKindOfClass:[NSString class]] && dd_fileExists((NSString *)p)) {
            DDLog(@"音频路径命中 AudioSender");
            return (NSString *)p;
        }
    }
    // 0x759888 ~ 0x759994：兜底，把 m_dtVoice 写成 NSTemporaryDirectory 下 UUID.aud
    NSData *data = dd_voiceData(msg);
    if ([data length] == 0) { DDLog(@"m_dtVoice 为空，无法导出临时音频"); return nil; }
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    if (![data writeToFile:tmp atomically:YES]) { DDLog(@"写临时音频失败 %@", tmp); return nil; }
    DDLog(@"音频路径走临时文件 %lu 字节", (unsigned long)[data length]);
    return dd_fileExists(tmp) ? tmp : nil;
}

// 对齐锤子 0x75a184：临时文件落到微信认的 Audio 目录（Img->Audio, .pic->.aud）
static NSString *dd_installAudioFile(id wrap, NSString *src) {
    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls || ![wrapCls respondsToSelector:@selector(getPathOfMsgImg:)]) return nil;
    id imgObj = [wrapCls getPathOfMsgImg:wrap];
    if (![imgObj isKindOfClass:[NSString class]]) return nil;
    NSString *p = [[(NSString *)imgObj stringByReplacingOccurrencesOfString:@"Img" withString:@"Audio"]
                                       stringByReplacingOccurrencesOfString:@".pic" withString:@".aud"];
    NSString *dir = [p stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    // 0x75a2cc ~ 0x75a2e8：锤子原逻辑在目录不存在时直接失败（其前提是录音已落盘、对应 Audio 子目录必已建立）。
    // 本插件凭空构造语音消息，对应 Audio 子目录往往尚未建立，必须主动创建，否则随机落盘失败
    // （见日志：转发给自己/群聊时 Audio 目录不存在 → 音频落盘失败 → ResendVoiceMsg 未触发 → 无消息）。
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) {
        NSError *mkErr = nil;
        if (![fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&mkErr]) {
            DDLog(@"Audio 目录创建失败 %@ %@", dir, mkErr);
            return nil;
        }
    }
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    return [fm copyItemAtPath:src toPath:p error:nil] ? p : nil;
}

#pragma mark - 语音发送

// 0x7906a4 ~ 0x7906bc：给构造出来的消息一个非零 localID，否则拿不到音频路径
static unsigned int dd_newVoiceLocalID(void) {
    return kDDVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDVoiceLocalIDRange);
}

// 对齐锤子 0x759cc4 sendVoiceWithUser:audPath:mp3Time:
static BOOL dd_sendVoice(NSString *usr, NSString *audPath, unsigned int duration) {
    if ([usr length] == 0 || !dd_fileExists(audPath)) return NO;
    id sender = dd_mmService(@"AudioSender");
    if (!sender) { DDLog(@"AudioSender 服务取不到"); return NO; }
    if (![sender respondsToSelector:@selector(addMessageToDB:)]) return NO;
    if (![sender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) return NO;

    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return NO;
    id raw = [wrapCls alloc];
    if (![raw respondsToSelector:@selector(initWithMsgType:)]) return NO;
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    if (!wrap) { DDLog(@"initWithMsgType 返回 nil"); return NO; }
    // 0x759ebc ~ 0x759ec4
    [wrap setM_uiMessageType:(unsigned int)kDDVoiceMsgType];

    // 0x759ecc ~ 0x759ed4
    NSString *fromUsr = dd_currentUsrName();
    if ([fromUsr length] == 0) { DDLog(@"取不到当前登录用户名"); return NO; }
    [wrap setM_nsFromUsr:fromUsr];
    [wrap setM_nsToUsr:usr];

    // 0x759fdc ~ 0x75a00c：GenSendMsgTime 优先，拿不到退回time(NULL)
    unsigned int createTime = (unsigned int)time(NULL);
    id sessionMgr = dd_mmService(@"MMNewSessionMgr");
    if (sessionMgr && [sessionMgr respondsToSelector:@selector(GenSendMsgTime)]) {
        unsigned int t = [sessionMgr GenSendMsgTime];
        if (t != 0) createTime = t;
    }
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMsgStatusSending];

    // 0x75a030 ~ 0x75a054
    NSData *d = [NSData dataWithContentsOfFile:audPath];
    if ([d length] == 0) { DDLog(@"音频文件读不出来 %@", audPath); return NO; }
    if (!dd_configureVoiceMsg(wrap, d, duration)) { DDLog(@"配置语音消息失败 duration=%u", duration); return NO; }
    if (![sender addMessageToDB:wrap]) { DDLog(@"addMessageToDB 失败"); return NO; }

    NSString *installed = dd_installAudioFile(wrap, audPath);
    if ([installed length] == 0) {
        DDLog(@"音频落盘失败 %@", audPath);
        if ([sender respondsToSelector:@selector(deleteMessageFromDB:)]) [sender deleteMessageFromDB:wrap];
        return NO;
    }
    DDLog(@"发送语音 -> %@ 时长=%ums 文件=%@", usr, duration, installed);
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    DDLog(@"ResendVoiceMsg 已调用");
    return YES;
}

// 对齐锤子 0x7908c8：接管语音消息的发送
// 对齐锤子 0x790950：发送前若收藏语音数据尚未就绪，下载后注入 m_dtVoice（「发送时下载」）
static BOOL dd_ensureFavVoiceData(id msg) {
    if ([dd_voiceData(msg) length] > 0) return YES;
    id favItem = objc_getAssociatedObject(msg, kDDFavSourceKey);
    if (!favItem || ![favItem respondsToSelector:@selector(dataList)]) return NO;
    NSArray *list = [favItem dataList];
    if (![list isKindOfClass:[NSArray class]] || [list count] == 0) return NO;
    id field = [list firstObject];
    if (![field respondsToSelector:@selector(GetDataPath)]) return NO;
    id p = [field GetDataPath];
    if (![p isKindOfClass:[NSString class]]) return NO;
    NSData *d = [NSData dataWithContentsOfFile:(NSString *)p
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    if ([d length] == 0) return NO;
    return dd_injectVoiceData(msg, d);
}

static BOOL dd_takeOverVoiceMsg(id msg, id contact) {
    if (!dd_isVoiceMsg(msg)) return NO;
    if (!contact) return NO;
    NSString *usr = nil;
    if ([contact respondsToSelector:@selector(m_nsUsrName)]) {
        id u = [(CBaseContact *)contact m_nsUsrName];
        if ([u isKindOfClass:[NSString class]]) usr = (NSString *)u;
    }
    if ([usr length] == 0) { DDLog(@"拿不到目标联系人用户名"); return NO; }
    unsigned int duration = dd_voiceDuration(msg);
    // 0x790950：时长为 0 不发送
    if (duration == 0) {
        DDLog(@"语音时长为 0，取消发送");
        return NO;
    }
    NSString *audPath = dd_audioPathForMsg(msg);
    if ([audPath length] == 0) {
        // 数据缺失：发送时下载收藏语音，注入后再发送，避免首次点转发被下载闸门挡住选人器
        id favItem = objc_getAssociatedObject(msg, kDDFavSourceKey);
        if (favItem && [favItem respondsToSelector:@selector(dataList)]) {
            DDLog(@"发送时语音数据缺失，现下载收藏语音再发送");
            // 一次性 block（跑完即释放，不形成循环引用），强持有 msg 以保证 shell wrap 在下载期间不被释放
            dd_downloadFavItemThen(favItem, ^{
                if (dd_ensureFavVoiceData(msg)) {
                    NSString *p = dd_audioPathForMsg(msg);
                    if ([p length] > 0) dd_sendVoice(usr, p, duration);
                    else DDLog(@"发送时下载后仍拿不到音频路径，取消发送");
                } else {
                    DDLog(@"发送时下载后仍未取到语音数据，取消发送");
                }
            });
            return YES; // 已异步处理，勿走原实现
        }
        DDLog(@"拿不到语音文件，取消发送");
        return NO;
    }
    DDLog(@"准备接管发送 -> %@ 文件=%@", usr, audPath);
    return dd_sendVoice(usr, audPath, duration);
}

// 对齐锤子 0x790a94：批量转发时逐条接管，返回剩下需要走原实现的消息
static NSArray *dd_takeOverVoiceList(NSArray *src, id contact) {
    NSMutableArray *rest = [NSMutableArray array];
    for (id m in src) {
        if ([m isKindOfClass:objc_getClass("CMessageWrap")] &&
            [m respondsToSelector:@selector(m_uiMessageType)] &&
            ((CMessageWrap *)m).m_uiMessageType == (unsigned int)kDDVoiceMsgType) {
            dd_takeOverVoiceMsg(m, contact);
            continue;
        }
        [rest addObject:m];
    }
    return rest;
}

#pragma mark - 收藏语音消息构造

// 对齐锤子 0x790570：把收藏语音数据构造成一条待转发的语音消息。
// 「发送时下载」：文件未就绪时不读数据，只构造成"外壳"（含时长/localID，足以让选人器正常弹出），
// 并把 FavoritesItem 绑到 wrap；真正的音频数据在发送接管处（dd_takeOverVoiceMsg）下载后注入 m_dtVoice。
static id dd_msgWrapFromFavData(id favData, id favItem) {
    if (!favData) return nil;
    Class fieldCls = objc_getClass("FavoritesItemDataField");
    if (!fieldCls || ![favData isKindOfClass:fieldCls]) return nil;
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    if (![field respondsToSelector:@selector(GetDataPath)]) return nil;

    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return nil;
    id raw = [wrapCls alloc];
    if (![raw respondsToSelector:@selector(initWithMsgType:)]) return nil;
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    if (!wrap) { DDLog(@"构造待转发消息失败"); return nil; }

    // 0x790644 ~ 0x79065c
    NSString *me = dd_currentUsrName();
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    // 0x790668 ~ 0x790678
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];
    // 0x7906a4 ~ 0x7906bc
    [wrap setM_uiMesLocalID:dd_newVoiceLocalID()];

    // 0x790688 ~ 0x79069c：时长直接用收藏数据里的 duration，不依赖文件是否下载
    unsigned int duration = field.duration;
    if (duration == 0) { DDLog(@"收藏语音 duration 为 0，放弃"); return nil; }
    if (!dd_configureVoiceMeta(wrap, duration)) { DDLog(@"配置语音元信息失败"); return nil; }

    // 绑定来源，供发送时下载反查
    if (favItem) objc_setAssociatedObject(wrap, kDDFavSourceKey, favItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 文件已就绪则直接读数据；否则留到发送时下载
    id pathObj = [field GetDataPath];
    if ([pathObj isKindOfClass:[NSString class]] && dd_fileExists((NSString *)pathObj)) {
        DDLog(@"收藏语音路径 %@", pathObj);
        NSData *data = [NSData dataWithContentsOfFile:(NSString *)pathObj
                                              options:NSDataReadingMappedIfSafe
                                                error:nil];
        if ([data length] > 0) {
            DDLog(@"收藏语音 %lu 字节 时长=%u", (unsigned long)[data length], duration);
            dd_injectVoiceData(wrap, data);
            return wrap;
        }
        DDLog(@"收藏语音文件暂未就绪，留待发送时下载");
    } else {
        DDLog(@"收藏语音文件不存在，留待发送时下载");
    }
    return wrap;
}

// 对齐锤子 0x790484 ~ 0x7904e8：取 dataList 首项构造消息，append 进 m_messageWrapList
static void dd_appendVoiceMsg(id favItem, id controller) {
    NSArray *list = ((FavoritesItem *)favItem).dataList;
    if (![list isKindOfClass:[NSArray class]] || [list count] == 0) { DDLog(@"收藏项 dataList 为空"); return; }
    DDLog(@"收藏语音 dataList 共 %lu 项", (unsigned long)[list count]);
    id wrap = dd_msgWrapFromFavData([list firstObject], favItem);
    if (!wrap) {
        DDLog(@"收藏语音没有可用数据");
        return;
    }
    Class ctrlCls = objc_getClass("FavForwardLogicController");
    if (ctrlCls && ![[controller class] isSubclassOfClass:ctrlCls]) { DDLog(@"控制器类型不符"); return; }
    Ivar iv = class_getInstanceVariable([controller class], "m_messageWrapList");
    if (!iv) { DDLog(@"找不到 m_messageWrapList 成员变量"); return; }
    id store = object_getIvar(controller, iv);
    if (![store isKindOfClass:[NSMutableArray class]]) { DDLog(@"m_messageWrapList 尚未初始化"); return; }
    [(NSMutableArray *)store addObject:wrap];
    DDLog(@"已加入待转发语音消息，列表现有 %lu 条", (unsigned long)[(NSMutableArray *)store count]);
}

#pragma mark - 一 收藏项转发闸门（0x78f0d4 / 0x78f14c / 0x78f1c4）
%hook FavoritesItem
- (_Bool)canBeForward {
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return YES;
    return %orig;
}
- (id)canBeForwardWithMsg {
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return nil;
    return %orig;
}
- (id)canBeForwardWithMsg:(_Bool)arg1 {
    if (ddFavVoiceEnabled() && self.type == kDDFavVoiceItemType) return nil;
    return %orig;
}
%end

#pragma mark - 二 阻止语音被降级成文本（0x78f628，受 enableVoiceForward 0x78f654 门控，收藏/语音任一开关开启即生效）
%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    if (ddForwardSendEnabled() && dd_isVoiceMsg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - 三 把收藏语音做成待转发消息（0x78f4e8，仅受「收藏语音转发」开关门控）
// 「发送时下载」架构：addMsgFromItem 必须同步把 item 加入列表并调用 %orig——
// 弹选人器的调用方是在本方法同步返回时判定就绪的，任何把 %orig 推迟（下载+重入）的写法都会让调用方在同步
// 返回时看不到就绪项，导致选人器不弹、必须再点一次（见 07:49:20.498 与 07:49:23.220 两次进入的现象）。
// 因此这里只构建语音消息（数据缺失时构造成"外壳"并绑定来源，见 dd_msgWrapFromFavData），不触发下载；
// 真正的下载 + 注入数据推迟到发送接管处（dd_takeOverVoiceMsg），从而一次点击即可弹出选人器。
%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1)) {
        FavoritesItem *item = (FavoritesItem *)arg1;
        DDLog(@"进入转发流程，收藏语音 type=%d", item.type);
        dd_appendVoiceMsg(item, self);
    }
    // 0x78f5cc：原实现无条件调用（同步，确保选人器正常弹出）
    %orig;
}
%end

#pragma mark - 四 接管语音消息的发送（0x78f6c8 / 0x78f77c / 0x78f8b0 / 0x78f9f8，受 enableVoiceForward 0x78f700 门控，收藏/语音任一开关开启即接管）
%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    if (dd_isVoiceMsg(arg1)) {
        if (!ddForwardSendEnabled()) { DDLog(@"语音转发两个开关均未开，走原生转发"); %orig; return; }
        // 0x78f718 ~ 0x78f724：命中即接管，无论成败都不再走原实现
        DDLog(@"单条转发命中语音，接管发送");
        BOOL ok = dd_takeOverVoiceMsg(arg1, arg2);
        DDLog(@"单条接管结果=%@", ok ? @"成功" : @"失败");
        return;
    }
    %orig;
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 {
    if (!ddForwardSendEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    DDLog(@"批量转发 %lu 条，开始逐条接管", (unsigned long)[(NSArray *)arg1 count]);
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3 {
    if (!ddForwardSendEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3 {
    if (!ddForwardSendEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
%end

#pragma mark - 五 MyFavoritesListViewController -forwardData: 直通（0x78f244）
// 注意：本方法在「收藏详情页」转发手势中并未被命中（见日志，转发入口直接走 addMsgFromItem:）。
// 早期曾在此处「先下载再转发」，但那会推迟 %orig，而弹选人器的调用方是在 addMsgFromItem: 同步返回时
// 判定就绪的——推迟 %orig 会让选人器不弹、必须再点一次。故这里改为直接 %orig 直通，
// 不触发下载、不推迟，真正的「发送时下载」已下沉到 addMsgFromItem:/dd_takeOverVoiceMsg。
%hook MyFavoritesListViewController
- (void)forwardData:(id)arg1 {
    %orig;
}
%end

#pragma mark - 六 普通语音消息长按菜单加「原生转发」按钮（仅受「语音消息转发」开关门控）
// 用微信原生转发按钮：复用 BaseMessageCellView -forwardMenuItem（动作 onForward:，与正常消息完全一致），
// 注入到语音 cell 长按菜单的首位置。这样语音消息长按弹出的"转发"就是微信原生那一项，而非自定义项。
// 限制解除分两层（均对 8.0.76 反汇编确认）：
//  1) -canShowForwardMenuItem 是转发可见性闸门，语音默认返回 NO；hook 后对语音返回 YES；
//  2) -onForward: 内部校验 [messageWrap respondsToSelector:tryHandleMenu:withViewModel:] 会把语音判为不可转发
//     而直接跳走（0x1002a2394 的 tbz w22）；hook 后对语音改走已实测可用的 -doForward，触发微信选人/选群，
//     最终落到第四节 ForwardMessageLogicController 接管发送 type=34 语音。
%hook BaseMessageCellView
- (BOOL)canShowForwardMenuItem {
    if (ddVoiceMsgEnabled() && [self isKindOfClass:%c(VoiceMessageCellView)]) {
        return YES;
    }
    return %orig;
}
- (void)onForward:(id)arg1 {
    if (ddVoiceMsgEnabled() && [self isKindOfClass:%c(VoiceMessageCellView)]) {
        DDLog(@"语音消息原生 onForward: 被拦截，改走 doForward 触发选人器");
        [self doForward];
        return;
    }
    %orig;
}
%end

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    if (!ddVoiceMsgEnabled()) return original;
    // 原生转发项：BaseMessageCellView -forwardMenuItem 构造，动作 onForward:、目标即 cell 自身
    id item = [self forwardMenuItem];
    if (item == nil) return original;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[original count] + 1];
    [items addObjectsFromArray:original];
    [items insertObject:item atIndex:0];
    return items;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    // 允许 iOS 显示并启用注入的原生 onForward: 菜单项（UIMenuController 会据此决定是否展示）
    if (action == @selector(onForward:) && ddVoiceMsgEnabled()) {
        return YES;
    }
    return %orig;
}
%end

#pragma mark - 日志查看页
@interface DDFavVoiceLogViewController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@end

@implementation DDFavVoiceLogViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"运行日志";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.alwaysBounceVertical = YES;
    tv.autocorrectionType = UITextAutocorrectionTypeNo;
    tv.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tv.textContainerInset = UIEdgeInsetsMake(8, 8, 8, 8);
    tv.font = [UIFont monospacedSystemFontOfSize:11.0 weight:UIFontWeightRegular];
    [self.view addSubview:tv];
    self.textView = tv;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                      target:self
                                                      action:@selector(onExport:)];
    UIBarButtonItem *copyItem = [[UIBarButtonItem alloc] initWithTitle:@"复制"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(onCopy:)];
    UIBarButtonItem *clearItem = [[UIBarButtonItem alloc] initWithTitle:@"清空"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(onClear:)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                          target:nil
                                                                          action:nil];
    [self setToolbarItems:@[copyItem, flex, clearItem] animated:NO];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:animated];
    [self reloadLog];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
}
- (void)reloadLog {
    NSString *text = dd_logText();
    self.textView.text = text;
    if ([text length] > 0) {
        NSRange tail = NSMakeRange([text length] - 1, 1);
        [self.textView scrollRangeToVisible:tail];
    }
}
- (void)onCopy:(id)sender {
    [UIPasteboard generalPasteboard].string = dd_logText();
    DDLog(@"日志已复制到剪贴板");
    [self reloadLog];
}
- (void)onClear:(id)sender {
    dd_logClear();
    [self reloadLog];
}
- (void)onExport:(id)sender {
    NSString *path = dd_logPath();
    if ([path length] == 0) return;
    // 导出前用内存里的最新内容重写一次，保证分享出去的是完整日志
    [[dd_logText() dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
    NSURL *url = [NSURL fileURLWithPath:path];
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                     applicationActivities:nil];
    if (av.popoverPresentationController) {
        av.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    }
    [self presentViewController:av animated:YES completion:nil];
}
@end

#pragma mark - 设置界面
@interface DDFavVoiceSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDFavVoiceSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (_tableViewManager) return;
    id mgrCls = objc_getClass("WCTableViewManager");
    _tableViewManager = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                               style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) { [self ensureTableViewMgr]; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD收藏语音转发";
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    [self ensureTableViewMgr];
    if (!_tableViewManager) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
}
- (void)buildTable {
    [_tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    WCTableViewSectionManager *sec = [secMgr defaultSection];
    DDFavVoiceConfig *cfg = [DDFavVoiceConfig sharedConfig];
    [sec addCell:[cellMgr switchCellForSel:@selector(onFavSwitch:) target:self title:@"收藏语音转发" on:cfg.favEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(onMsgSwitch:) target:self title:@"语音消息转发" on:cfg.msgEnabled]];
    [_tableViewManager addSection:sec];

    Class normMgr = objc_getClass("WCTableViewNormalCellManager");
    if (normMgr) {
        WCTableViewSectionManager *dbg = [secMgr defaultSection];
        [dbg addCell:[normMgr normalCellForSel:@selector(onOpenLogPage)
                                        target:self
                                         title:@"运行日志"
                                accessoryType:UITableViewCellAccessoryDisclosureIndicator]];
        [dbg addCell:[normMgr normalCellForSel:@selector(onClearLogNow)
                                        target:self
                                         title:@"清空日志"
                                accessoryType:UITableViewCellAccessoryNone]];
        [_tableViewManager addSection:dbg];
    }

    [_tableViewManager reloadTableView];
}
- (void)onOpenLogPage {
    DDFavVoiceLogViewController *vc = [DDFavVoiceLogViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}
- (void)onClearLogNow {
    dd_logClear();
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)onFavSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].favEnabled = s.on; }
- (void)onMsgSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].msgEnabled = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        dd_logLine(@"插件载入 DD收藏语音转发 1.0.0");
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD收藏语音转发"
                                                      version:@"1.0.0"
                                                   controller:@"DDFavVoiceSettingsViewController"];
            DDFavVoiceConfig *c = [DDFavVoiceConfig sharedConfig];
            DDLog(@"设置入口注册成功，收藏语音转发=%@ 语音消息转发=%@",
                  c.favEnabled ? @"开" : @"关", c.msgEnabled ? @"开" : @"关");
        } else {
            DDLog(@"WCPluginsMgr 缺失，设置入口未注册");
        }
    }
}

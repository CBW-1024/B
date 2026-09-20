#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

// 微信类前向声明
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
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightView:(id)arg4;
@property (nonatomic, retain) id userInfo;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 accessoryType:(long long)arg4;
@end

@interface FavoritesItemDataField : NSObject
@property(nonatomic) unsigned int duration;
- (id)GetDataPath;
@end

@interface CMessageWrap : NSObject
+ (id)getPathOfMsgImg:(id)arg1;
+ (_Bool)isSenderFromMsgWrap:(id)arg1;
- (id)initWithMsgType:(long long)arg1;
// 4 份 dump 均存在：wechat_dump/CMessageWrap.h:156、wechat76:550、wcd76_new:864、wechat_new:853
- (BOOL)IsVoiceMsg;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) id m_extendInfoWithMsgType;
@end

@interface CExtendInfoOfVoiceMsg : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(nonatomic, weak) CMessageWrap *m_refMessageWrap;
@end

// 语音上传结构（protobuf 生成类）。头文件证据：UploadVoiceWrap.h
// 自己录音发送链路：AudioSender OnRecorderPart:...Duration:
//                → MMNewUploadVoiceMgr AddNewPart:...VoiceTime:
//                → UploadVoiceWrap setM_uiVoiceTime:  ← 发出去前的最后一次写入
@interface UploadVoiceWrap : NSObject
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceLen;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(nonatomic) unsigned int m_uiVoiceCancelFlag;
@property(nonatomic) unsigned int m_uiVoiceForwardFlag;
@property(nonatomic) unsigned int m_uiOffset;
@property(nonatomic) unsigned int m_uiLen;
@property(nonatomic) unsigned int m_uiLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(retain, nonatomic) NSString *m_nsToUsrName;
@property(retain, nonatomic) NSString *m_nsFromUsrName;
@end

@interface CUtility : NSObject
+ (id)GetDocPath;
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface FavoritesMgr : NSObject
- (void)startDownloadFavoritesItem:(id)arg1 IsPriority:(_Bool)arg2;
@end

@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;
- (_Bool)deleteMessageFromDB:(id)arg1;
- (_Bool)addMessageToDB:(id)arg1;
- (id)getAudioFileName:(id)arg1 LocalID:(unsigned int)arg2;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface ForwardMsgUtil : NSObject
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1;
@end

@interface FavoritesItem : NSObject
@property(nonatomic) int type;
@property(retain, nonatomic) NSArray *dataList;
- (_Bool)needDownLoad;
- (_Bool)canBeForward;
- (id)canBeForwardWithMsg;
- (id)canBeForwardWithMsg:(_Bool)arg1;
@end

@interface FavForwardLogicController : NSObject
- (void)addMsgFromItem:(id)arg1;
@end

@interface ForwardMessageLogicController : NSObject
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3;
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3;
@end

// 语音 cell 转发生态（BaseMessageCellView 须先于 VoiceMessageCellView 声明）
@interface BaseMessageCellView : NSObject
- (BOOL)canShowForwardMenuItem;
- (id)forwardMenuItem;
- (void)onForward:(id)arg1;
- (void)doForward;
@end

@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

#pragma mark - 配置

#define kDDVoiceEnableFav @"kDDVoiceEnableFav"
#define kDDVoiceEnableMsg @"kDDVoiceEnableMsg"
#define kDDVoiceSecondsEnabled @"kDDVoiceSecondsEnabled"
#define kDDVoiceSeconds @"kDDVoiceSeconds"

// 微信语音最大时长（秒）：录制系统硬上限。
// 头文件证据：MMTapRecordButton.maxSeconds、TingAudioRecordConfiguration.maxTimeInSecond、
// TingAudioRecorder initWithRecordMinTime:recordMaxTime: —— 微信默认即 60 秒。
#define kDDVoiceMaxSeconds 60

static const int kDDVoiceFavItemType = 3;        // 收藏语音 type == 3
static const long long kDDVoiceMsgType = 34;      // 语音消息 m_uiMessageType == 0x22
static const unsigned int kDDVoiceFormat = 4;
static const unsigned int kDDVoiceEndFlag = 1;
static const unsigned int kDDMsgStatusSending = 1;
static const NSTimeInterval kDDDownloadWaitStep = 0.25;
static const unsigned int kDDVoiceLocalIDBase = 10000;
static const unsigned int kDDVoiceLocalIDRange = 0x15f90;
// 把收藏项绑到构造出的语音 wrap 上，供「发送时下载」反查并下载
static const void *kDDVoiceFavSourceKey = &kDDVoiceFavSourceKey;

@interface DDVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL favEnabled;  // 收藏语音转发
@property (assign, nonatomic) BOOL msgEnabled;  // 语音消息转发
@property (assign, nonatomic) BOOL voiceSecondsEnabled;  // 设置语音秒数
@property (copy, nonatomic) NSString *voiceSeconds;      // 自定义秒数（数字文本，空=不覆盖）
@end

@implementation DDVoiceConfig
+ (instancetype)sharedConfig {
    static DDVoiceConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDVoiceConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDVoiceConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDVoiceEnableFav: @NO,
        kDDVoiceEnableMsg: @NO,
        kDDVoiceSecondsEnabled: @NO,
        kDDVoiceSeconds: @"",
    }];
}
- (instancetype)init {
    if (self = [super init]) {
    _favEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceEnableFav];
    _msgEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceEnableMsg];
    _voiceSecondsEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDVoiceSecondsEnabled];
    _voiceSeconds = [[NSUserDefaults.standardUserDefaults stringForKey:kDDVoiceSeconds] copy] ?: @"";
    }
    return self;
}
- (void)setFavEnabled:(BOOL)v {
    _favEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableFav];
}
- (void)setMsgEnabled:(BOOL)v {
    _msgEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceEnableMsg];
}
- (void)setVoiceSecondsEnabled:(BOOL)v {
    _voiceSecondsEnabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDVoiceSecondsEnabled];
}
- (void)setVoiceSeconds:(NSString *)v {
    _voiceSeconds = [v copy];
    [NSUserDefaults.standardUserDefaults setObject:_voiceSeconds forKey:kDDVoiceSeconds];
}
@end

static BOOL dd_voice_fav_enabled(void) { return [DDVoiceConfig sharedConfig].favEnabled; }
static BOOL dd_voice_msg_enabled(void) { return [DDVoiceConfig sharedConfig].msgEnabled; }
// 发送汇点：收藏/语音任一开关开启即接管（收藏语音最终也构造成 type=34 走此路径发出）
static BOOL dd_voice_forward_enabled(void) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    return c.favEnabled || c.msgEnabled;
}

#pragma mark - 工具

// 优先用微信自己的判定（跨版本稳），取不到再回退硬编码 34
static BOOL dd_voice_is_msg(id msg) {
    if ([msg respondsToSelector:@selector(IsVoiceMsg)]) return [(CMessageWrap *)msg IsVoiceMsg];
    return ((CMessageWrap *)msg).m_uiMessageType == (unsigned int)kDDVoiceMsgType;
}
static BOOL dd_voice_is_fav_item(id obj) {
    return ((FavoritesItem *)obj).type == kDDVoiceFavItemType;
}
static BOOL dd_file_exists(NSString *path) {
    if ([path length] == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_current_usr_name(void) {
    return [objc_getClass("SettingUtil") getCurUsrName];
}
static id dd_mm_service(NSString *serviceName) {
    Class ctxCls = objc_getClass("MMContext");
    id ctx = [ctxCls currentContext];
    Class svc = objc_getClass([serviceName UTF8String]);
    return [ctx getService:svc];
}
static void dd_start_download_fav_item(id item) {
    Class ctxCls = objc_getClass("MMContext");
    Class mgrCls = objc_getClass("FavoritesMgr");
    id ctx = [ctxCls currentContext];
    id mgr = [ctx getService:mgrCls];
    [mgr startDownloadFavoritesItem:item IsPriority:YES];
}
// 轮询 needDownLoad 直至下载完成；不设上限
static void dd_wait_download_finish(id item) {
    while (((FavoritesItem *)item).needDownLoad) {
        [NSThread sleepForTimeInterval:kDDDownloadWaitStep];
    }
}
// 发起下载，后台轮询完成后回主线程回调
static void dd_download_fav_item_then(id item, void (^done)(void)) {
    DDVHit(kEvFavWait);
    DDVLog(@"收藏语音数据未就绪，等待下载完成");
    dd_start_download_fav_item(item);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        dd_wait_download_finish(item);
        dispatch_async(dispatch_get_main_queue(), done);
    });
}

#pragma mark - 日志

// 证书注入的机器看不到系统日志，改为插件内落盘 + 设置界面「导出 / 清空」。
// 埋点表预置初值 0：导出时计数仍为 0 的即「从未被调用」，可直接判定为冗余代码。
#define kDDVLogMaxLines 2000
#define kDDVLogHitStep  25          // 同一埋点每 25 次汇总一行，避免刷屏

#define DDVHit(e)    [[DDVoiceLog shared] hit:(e)]
#define DDVLog(...)  [[DDVoiceLog shared] log:__VA_ARGS__]

static NSString * const kEvUploadSet      = @"①上传链 UploadVoiceWrap.setM_uiVoiceTime";
static NSString * const kEvExtSet         = @"②存储   CExtendInfoOfVoiceMsg.setM_uiVoiceTime";
static NSString * const kEvExtGet         = @"③读取   CExtendInfoOfVoiceMsg.m_uiVoiceTime";
static NSString * const kEvGatePass       = @"闸门·通过(本人且语音)";
static NSString * const kEvGateDenyMine   = @"闸门·拒绝(非本人或非语音)";
static NSString * const kEvGateDenyNoRef  = @"闸门·拒绝(m_refMessageWrap为空)";
static NSString * const kEvMsOverride     = @"换算·覆盖生效";
static NSString * const kEvMsOff          = @"换算·不覆盖(开关关闭)";
static NSString * const kEvMsEmpty        = @"换算·不覆盖(秒数为空或0)";
static NSString * const kEvMsClamp        = @"换算·被B兜底裁剪(声明>真实)";
static NSString * const kEvSendVoice      = @"发送·dd_send_voice";
static NSString * const kEvFavWait        = @"发送·收藏等待下载";
static NSString * const kEvFavCanFwd      = @"hook FavoritesItem.canBeForward";
static NSString * const kEvFavCanFwdMsg   = @"hook FavoritesItem.canBeForwardWithMsg";
static NSString * const kEvFavCanFwdMsg1  = @"hook FavoritesItem.canBeForwardWithMsg:";
static NSString * const kEvConvertText    = @"hook ForwardMsgUtil.ConvertMsgToTextIfCannotSend";
static NSString * const kEvFavAddMsg      = @"hook FavForwardLogicController.addMsgFromItem";
static NSString * const kEvFwdMsg         = @"hook ForwardMessageLogicController.ForwardMsg";
static NSString * const kEvFwdList        = @"hook ForwardMessageLogicController.ForwardMsgList";
static NSString * const kEvFwdListBatch   = @"hook ForwardMessageLogicController.ForwardMsgList+RevokeBatchId";
static NSString * const kEvFwdListScene   = @"hook ForwardMessageLogicController.ForwardMsgList+batchRevokeScene";
static NSString * const kEvCellCanFwd     = @"hook BaseMessageCellView.canShowForwardMenuItem";
static NSString * const kEvCellOnFwd      = @"hook BaseMessageCellView.onForward";
static NSString * const kEvVoiceMenu      = @"hook VoiceMessageCellView.operationMenuItems";
static NSString * const kEvVoiceCanPerf   = @"hook VoiceMessageCellView.canPerformAction";

static NSArray<NSString *> *ddv_event_table(void) {
    static NSArray<NSString *> *t = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        t = @[ kEvUploadSet, kEvExtSet, kEvExtGet,
               kEvGatePass, kEvGateDenyMine, kEvGateDenyNoRef,
               kEvMsOverride, kEvMsOff, kEvMsEmpty, kEvMsClamp,
               kEvSendVoice, kEvFavWait,
               kEvFavCanFwd, kEvFavCanFwdMsg, kEvFavCanFwdMsg1,
               kEvConvertText, kEvFavAddMsg,
               kEvFwdMsg, kEvFwdList, kEvFwdListBatch, kEvFwdListScene,
               kEvCellCanFwd, kEvCellOnFwd, kEvVoiceMenu, kEvVoiceCanPerf ];
    });
    return t;
}

@interface DDVoiceLog : NSObject
+ (instancetype)shared;
- (void)hit:(NSString *)event;                 // 计数埋点（首次 + 每 25 次各一行）
- (void)log:(NSString *)fmt, ...;              // 明细（相邻相同内容自动合并 xN）
- (NSString *)flush;                           // 落盘，返回文件路径
- (void)clear;
- (NSInteger)lineCount;
- (NSString *)path;
@end

@implementation DDVoiceLog {
    NSMutableArray<NSString *> *_lines;
    NSMutableDictionary<NSString *, NSNumber *> *_counts;
    NSString *_lastMsg;
    NSString *_lastStamp;
    NSInteger _lastRepeat;
    NSString *_path;
}
+ (instancetype)shared {
    static DDVoiceLog *l = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ l = [DDVoiceLog new]; });
    return l;
}
- (instancetype)init {
    if (self = [super init]) {
        _lines  = [NSMutableArray array];
        _counts = [NSMutableDictionary dictionary];
        for (NSString *e in ddv_event_table()) _counts[e] = @0;
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        if ([doc length] == 0) doc = NSTemporaryDirectory();
        _path = [doc stringByAppendingPathComponent:@"DDVoiceLog.txt"];
    }
    return self;
}
- (NSString *)path { return _path; }
- (NSInteger)lineCount { @synchronized (self) { return (NSInteger)[_lines count]; } }
// 注意：getter 埋点会被后台线程（消息解析/落库）调用，共享状态必须加锁
- (NSString *)stamp {
    static NSDateFormatter *f = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ f = [NSDateFormatter new]; f.dateFormat = @"HH:mm:ss.SSS"; });
    return [f stringFromDate:[NSDate date]];
}
// 相邻相同内容合并成 xN，避免高频 hook 把日志刷爆
- (void)appendMsg:(NSString *)msg {
    @synchronized (self) {
        if (_lastMsg && [msg isEqualToString:_lastMsg]) {
            _lastRepeat += 1;
            [_lines removeLastObject];
            [_lines addObject:[NSString stringWithFormat:@"%@ %@   (x%ld)", _lastStamp, msg, (long)_lastRepeat]];
        } else {
            _lastMsg = msg; _lastStamp = [self stamp]; _lastRepeat = 1;
            [_lines addObject:[NSString stringWithFormat:@"%@ %@", _lastStamp, msg]];
        }
        NSUInteger over = 0;
        if ([_lines count] > kDDVLogMaxLines) over = [_lines count] - kDDVLogMaxLines;
        if (over > 0) [_lines removeObjectsInRange:NSMakeRange(0, over)];
    }
}
- (void)log:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    [self appendMsg:msg];
}
- (void)hit:(NSString *)event {
    NSInteger c;
    @synchronized (self) {
        c = [_counts[event] integerValue] + 1;
        _counts[event] = @(c);
    }
    if (c == 1) [self appendMsg:[NSString stringWithFormat:@"[首次命中] %@", event]];
    else if (c % kDDVLogHitStep == 0) [self appendMsg:[NSString stringWithFormat:@"[命中x%ld] %@", (long)c, event]];
}
- (void)clear {
    @synchronized (self) {
        [_lines removeAllObjects];
        for (NSString *e in ddv_event_table()) _counts[e] = @0;
        _lastMsg = nil; _lastRepeat = 0;
        [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
    }
    [self log:@"日志已清空"];
}
- (NSString *)flush {
    NSMutableString *s = [NSMutableString string];
    @synchronized (self) {
        [s appendString:@"DD语音助手 · 运行日志\n"];
        [s appendFormat:@"导出时间: %@\n", [NSDate date]];
        DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
        [s appendFormat:@"当前配置: 收藏语音转发=%@ / 语音消息转发=%@ / 自定义秒数=%@(%@)\n",
        c.favEnabled ? @"开" : @"关",
        c.msgEnabled ? @"开" : @"关",
        c.voiceSecondsEnabled ? @"开" : @"关",
        [c.voiceSeconds length] ? c.voiceSeconds : @"空"];
        [s appendFormat:@"日志文件: %@\n", _path];

        [s appendString:@"\n================ 一、埋点计数（0 = 从未被调用，可判定冗余）================\n"];
        for (NSString *e in ddv_event_table()) {
        [s appendFormat:@"%6ld  %@\n", (long)[_counts[e] integerValue], e];
        }

        [s appendString:@"\n================ 二、自动诊断 ================\n"];
        long nUpload = [_counts[kEvUploadSet] integerValue];
        long nExtSet = [_counts[kEvExtSet] integerValue];
        long nExtGet = [_counts[kEvExtGet] integerValue];
        long nPass   = [_counts[kEvGatePass] integerValue];
        long nNoRef  = [_counts[kEvGateDenyNoRef] integerValue];
        if (nUpload == 0 && nExtSet == 0 && nExtGet == 0) {
        [s appendString:@"※ 三条写入/读取链全部未命中：本次操作未触发任何语音时长写入（需实际录一条语音并发送）。\n"];
        } else {
        if (nUpload == 0) [s appendString:@"※ UploadVoiceWrap 未命中：自己录音的上传链没走这个 hook，可考虑移除。\n"];
        if (nExtSet == 0) [s appendString:@"※ CExtendInfoOfVoiceMsg.setM_uiVoiceTime 未命中：落库值不是从这里写入的。\n"];
        if (nExtGet == 0) [s appendString:@"※ CExtendInfoOfVoiceMsg.m_uiVoiceTime 未命中：气泡显示不读这个存储（需改 hook 显示层 VoiceMessageViewModel）。\n"];
        }
        if (nNoRef > 0 && nPass == 0) {
        [s appendString:@"※ 闸门全部因 m_refMessageWrap 为空被拒 → 把 Tweak.xm 里 kDDVoiceApplyWhenNoRef 改成 1。\n"];
        }
        NSMutableArray<NSString *> *dead = [NSMutableArray array];
        for (NSString *e in ddv_event_table()) {
        if ([_counts[e] integerValue] == 0) [dead addObject:e];
        }
        if ([dead count] > 0) {
        [s appendFormat:@"※ 以下 %lu 个埋点计数为 0（若已充分操作过全部功能，对应代码即冗余）：\n", (unsigned long)[dead count]];
        for (NSString *e in dead) [s appendFormat:@"     - %@\n", e];
        } else {
        [s appendString:@"※ 所有埋点均有命中，无冗余。\n"];
        }

        [s appendString:@"\n================ 三、明细（按时间）================\n"];
        for (NSString *l in _lines) [s appendFormat:@"%@\n", l];

        [s writeToFile:_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    return _path;
}
@end

#pragma mark - 语音扩展信息

static id dd_voiceExtendInfo(id wrap, BOOL create) {
    Class vcls = objc_getClass("CExtendInfoOfVoiceMsg");
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    if (!create) return nil;
    id nv = [[vcls alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
static NSData *dd_voiceData(id wrap) {
    return [dd_voiceExtendInfo(wrap, NO) m_dtVoice];
}
static unsigned int dd_voiceDuration(id wrap) {
    return [dd_voiceExtendInfo(wrap, NO) m_uiVoiceTime];
}
static BOOL dd_configureVoiceMeta(id wrap, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    return YES;
}
static BOOL dd_injectVoiceData(id wrap, NSData *voiceData) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_dtVoice:voiceData];
    return YES;
}
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    dd_configureVoiceMeta(wrap, duration);
    return dd_injectVoiceData(wrap, voiceData);
}
// 自定义语音秒数：毫秒进、毫秒出。
// ★ 单位依据（WCRefine 逆向 + 微信头文件互证）：m_uiVoiceTime 单位是【毫秒】
//   - WCRefine 0x8f4084 对自定义秒数 mul #1000，未启用时钳到 60000
//   - 录音层 MMTapRecordButton.maxSeconds 是 double 秒（上限 60），
//     TingAudioRecordConfiguration.maxTimeInSecond 亦为秒；
//     而 m_uiVoiceTime 是 unsigned int，60000 = 60 秒 × 1000 精确对应
// 开关关闭 / 输入为空 / 输入为 0 → 原样返回（等价于不覆盖）
static unsigned int dd_voiceTimeMs(unsigned int realMs) {
    DDVoiceConfig *c = [DDVoiceConfig sharedConfig];
    if (!c.voiceSecondsEnabled) { DDVHit(kEvMsOff); return realMs; }
    NSString *s = c.voiceSeconds;
    if ([s length] == 0) { DDVHit(kEvMsEmpty); return realMs; }
    NSInteger sec = [s integerValue];
    if (sec <= 0) { DDVHit(kEvMsEmpty); return realMs; }   // 0（含旧配置残留）视为不覆盖
    if (sec < 1)  sec = 1;
    if (sec > kDDVoiceMaxSeconds) sec = kDDVoiceMaxSeconds;
    unsigned int target = (unsigned int)sec * 1000; // ★ 秒 → 毫秒
    // B 兜底：声明时长不超过真实音频时长，避免接收方空播/进度条错位
    if (realMs > 0 && target > realMs) { DDVHit(kEvMsClamp); return realMs; }
    DDVHit(kEvMsOverride);
    DDVLog(@"时长覆盖 %u ms → %u ms（设定 %ld s）", realMs, target, (long)sec);
    return target;
}

#pragma mark - 音频路径

// 决定语音文件归属哪个用户名（群聊/发送方/接收方）
static NSString *dd_owner_user_for_voice(id msg) {
    NSString *to = (NSString *)((CMessageWrap *)msg).m_nsToUsr;
    if ([to containsString:@"@chatroom"]) return to;
    Class wrapCls = objc_getClass("CMessageWrap");
    if ([wrapCls isSenderFromMsgWrap:msg]) return to;
    return (NSString *)((CMessageWrap *)msg).m_nsFromUsr;
}
// 优先 CUtility 路径，其次 AudioSender 路径，兜底导出 m_dtVoice 到临时文件
static NSString *dd_audio_path_for_msg(id msg) {
    unsigned int localID = ((CMessageWrap *)msg).m_uiMesLocalID;
    NSString *usr = dd_owner_user_for_voice(msg);
    Class cu = objc_getClass("CUtility");
    NSString *cuPath = (NSString *)[cu GetPathOfMesAudio:usr LocalID:localID DocPath:[cu GetDocPath]];
    if (dd_file_exists(cuPath)) return cuPath;
    id sender = dd_mm_service(@"AudioSender");
    NSString *p = (NSString *)[sender getAudioFileName:usr LocalID:localID];
    if (dd_file_exists(p)) return p;
    NSData *data = dd_voiceData(msg);
    if ([data length] == 0) return nil;
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:tmp atomically:YES];
    return tmp;
}
// 把音频落到微信 Audio 目录（本地显示用，不阻断发送）
static NSString *dd_install_audio_file(id wrap, NSString *src) {
    Class wrapCls = objc_getClass("CMessageWrap");
    NSString *p = [[(NSString *)[wrapCls getPathOfMsgImg:wrap] stringByReplacingOccurrencesOfString:@"Img" withString:@"Audio"]
                                       stringByReplacingOccurrencesOfString:@".pic" withString:@".aud"];
    NSString *dir = [p stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    [fm copyItemAtPath:src toPath:p error:nil];
    return p;
}

#pragma mark - 语音发送

// 给构造出来的消息一个非零 localID，否则拿不到音频路径
static unsigned int dd_new_voice_local_id(void) {
    return kDDVoiceLocalIDBase + (unsigned int)arc4random_uniform(kDDVoiceLocalIDRange);
}
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    id sender = dd_mm_service(@"AudioSender");
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    id sessionMgr = dd_mm_service(@"MMNewSessionMgr");
    unsigned int t = [sessionMgr GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMsgStatusSending];
    NSData *d = [NSData dataWithContentsOfFile:audPath];
    dd_configureVoiceMsg(wrap, d, duration);
    [sender addMessageToDB:wrap];
    dd_install_audio_file(wrap, audPath);
    DDVHit(kEvSendVoice);
    DDVLog(@"发送语音 → %@ 时长=%u ms 文件=%@", usr, duration, [audPath lastPathComponent]);
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return YES;
}
// 收藏外壳：数据未就绪则下载后注入 m_dtVoice 再发送
static void dd_ensure_fav_voice_data(id msg) {
    if ([dd_voiceData(msg) length] > 0) return;
    id favItem = objc_getAssociatedObject(msg, kDDVoiceFavSourceKey);
    NSArray *list = [favItem dataList];
    id field = [list firstObject];
    NSData *d = [NSData dataWithContentsOfFile:(NSString *)[field GetDataPath]
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    dd_injectVoiceData(msg, d);
}

static BOOL dd_take_over_voice_msg(id msg, id contact) {
    if (!dd_voice_is_msg(msg)) return NO;
    NSString *usr = (NSString *)[(CBaseContact *)contact m_nsUsrName];
    unsigned int duration = dd_voiceTimeMs(dd_voiceDuration(msg));
    NSString *audPath = dd_audio_path_for_msg(msg);
    if ([audPath length] == 0) {
        id favItem = objc_getAssociatedObject(msg, kDDVoiceFavSourceKey);
        if (favItem) {
            dd_download_fav_item_then(favItem, ^{
                dd_ensure_fav_voice_data(msg);
                NSString *p = dd_audio_path_for_msg(msg);
                dd_send_voice(usr, p, duration);
            });
            return YES;
        }
        return dd_send_voice(usr, audPath, duration);
    }
    return dd_send_voice(usr, audPath, duration);
}
// 批量转发逐条接管，返回需走原实现的消息
static NSArray *dd_take_over_voice_list(NSArray *src, id contact) {
    NSMutableArray *rest = [NSMutableArray array];
    for (id m in src) {
        if (dd_voice_is_msg(m)) {
            dd_take_over_voice_msg(m, contact);
            continue;
        }
        [rest addObject:m];
    }
    return rest;
}

#pragma mark - 收藏语音消息构造

// 把收藏语音数据构造成待转发语音消息：文件未就绪则构造成"外壳"（含时长/localID），数据留待发送时下载
static id dd_msg_wrap_from_fav_data(id favData, id favItem) {
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    Class wrapCls = objc_getClass("CMessageWrap");
    id raw = [wrapCls alloc];
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    NSString *me = dd_current_usr_name();
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];
    [wrap setM_uiMesLocalID:dd_new_voice_local_id()];
    unsigned int duration = dd_voiceTimeMs(field.duration);
    dd_configureVoiceMeta(wrap, duration);
    if (favItem) objc_setAssociatedObject(wrap, kDDVoiceFavSourceKey, favItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    id pathObj = [field GetDataPath];
    if (dd_file_exists((NSString *)pathObj)) {
        NSData *data = [NSData dataWithContentsOfFile:(NSString *)pathObj
                                              options:NSDataReadingMappedIfSafe
                                                error:nil];
        if ([data length] > 0) {
            dd_injectVoiceData(wrap, data);
            return wrap;
        }
    }
    return wrap;
}
static void dd_append_voice_msg(id favItem, id controller) {
    NSArray *list = ((FavoritesItem *)favItem).dataList;
    if ([list count] == 0) return;
    id wrap = dd_msg_wrap_from_fav_data([list firstObject], favItem);
    Class ctrlCls = objc_getClass("FavForwardLogicController");
    if (ctrlCls && ![[controller class] isSubclassOfClass:ctrlCls]) return;
    Ivar iv = class_getInstanceVariable([controller class], "m_messageWrapList");
    if (!iv) return;
    id store = object_getIvar(controller, iv);
    if (![store isKindOfClass:[NSMutableArray class]]) return;
    [(NSMutableArray *)store addObject:wrap];
}

#pragma mark - 自定义语音秒数（单位：毫秒）

// 归属闸门：只改「自己发出」的语音，收到的语音保持原时长。
// 头文件证据（4 份 dump 均一致）：
//   CExtendInfoOfVoiceMsg.h —— @property(nonatomic, weak) CMessageWrap *m_refMessageWrap; // @synthesize
//   CMessageWrap.h          —— m_uiMessageType / m_nsFromUsr
// 逆向证据：WCRefine 0x8f8484 / 0x8f82f8 —— m_uiMessageType == 0x22(34) 且 m_nsFromUsr == 当前登录用户
//           （注意它用的是 m_nsFromUsr，不是 +isSenderFromMsgWrap:）
static BOOL dd_voice_is_mine(id wrap) {
    if (!wrap) return NO;                                                   // 无归属：保守不动
    if (!dd_voice_is_msg(wrap)) return NO;
    NSString *me = dd_current_usr_name();
    if ([me length] == 0) return NO;
    return [((CMessageWrap *)wrap).m_nsFromUsr isEqualToString:me];
}
// m_refMessageWrap 尚未绑定时是否仍覆盖：
//   0 = 保守（默认）。只改已归属且来自自己的语音。
//   1 = 激进。若自己录音时先写时长、后绑 wrap，导致本地气泡仍显示真实秒数，把这里改成 1。
//   判定依据看导出日志里的「闸门·拒绝(m_refMessageWrap为空)」计数。
#define kDDVoiceApplyWhenNoRef 0
// 归属闸门（带埋点：区分「通过 / 非本人 / ref 为空」三种结果）
static BOOL dd_voice_gate(id ext) {
    id wrap = [(CExtendInfoOfVoiceMsg *)ext m_refMessageWrap];
    if (!wrap) {
        DDVHit(kEvGateDenyNoRef);
#if kDDVoiceApplyWhenNoRef
        return YES;
#else
        return NO;
#endif
    }
    if (!dd_voice_is_mine(wrap)) { DDVHit(kEvGateDenyMine); return NO; }
    DDVHit(kEvGatePass);
    return YES;
}

// ① 上传链路：自己录音发送的必经点。
//    链路：AudioSender -OnRecorderPart:Offset:Len:EndFlag:ForceDelete:Duration:
//       → MMNewUploadVoiceMgr -AddNewPart:... VoiceTime:...
//       → UploadVoiceWrap -setM_uiVoiceTime:   ← 发出去前的最后一次写入
//    头文件证据：UploadVoiceWrap.h（4 份 dump 均有 m_uiVoiceTime/setM_uiVoiceTime:）
//              、MMNewUploadVoiceMgr.h、BaseUploadVoiceMgr.h
//    该结构只在上传自己语音时创建，无需归属闸门。
%hook UploadVoiceWrap
- (void)setM_uiVoiceTime:(unsigned int)v {
    DDVHit(kEvUploadSet);
    unsigned int out = dd_voiceTimeMs(v);
    DDVLog(@"上传链 写入 %u → %u ms%@", v, out, out == v ? @"（未改动）" : @"");
    %orig(out);
}
%end

// ② 存储 / 本地显示：CExtendInfoOfVoiceMsg 才是真正存储者。
//    CMessageWrap.m_uiVoiceTime 是 @dynamic（wechat76_dump/CMessageWrap.h:1069），
//    运行时才挂载 IMP，直接 %hook 有 %orig 为空的风险，故 hook 真实存储类。
//    被 @dynamic 转发后同样会走到这里，一处覆盖即可同时改「落库值」和「气泡显示」。
//    头文件证据：CExtendInfoOfVoiceMsg.h（m_uiVoiceTime 为 @synthesize，有真实 ivar）
%hook CExtendInfoOfVoiceMsg
- (void)setM_uiVoiceTime:(unsigned int)v {
    DDVHit(kEvExtSet);
    BOOL mine = dd_voice_gate(self);
    unsigned int out = mine ? dd_voiceTimeMs(v) : v;
    DDVLog(@"落库 写入 %u → %u ms（闸门=%@）", v, out, mine ? @"通过" : @"拒绝");
    %orig(out);
}
- (unsigned int)m_uiVoiceTime {
    DDVHit(kEvExtGet);
    unsigned int v = %orig;
    BOOL mine = dd_voice_gate(self);
    unsigned int out = mine ? dd_voiceTimeMs(v) : v;
    if (out != v) DDVLog(@"读取 %u → %u ms（闸门=通过）", v, out);
    return out;
}
%end

#pragma mark - 收藏语音转发闸门

%hook FavoritesItem
- (_Bool)canBeForward {
    DDVHit(kEvFavCanFwd);
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return YES;
    return %orig;
}
- (id)canBeForwardWithMsg {
    DDVHit(kEvFavCanFwdMsg);
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return nil;
    return %orig;
}
- (id)canBeForwardWithMsg:(_Bool)arg1 {
    DDVHit(kEvFavCanFwdMsg1);
    if (dd_voice_fav_enabled() && self.type == kDDVoiceFavItemType) return nil;
    return %orig;
}
%end

#pragma mark - 阻止语音被降级为文本

%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    DDVHit(kEvConvertText);
    if (dd_voice_forward_enabled() && dd_voice_is_msg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - 把收藏语音做成待转发消息

%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    DDVHit(kEvFavAddMsg);
    if (dd_voice_fav_enabled() && dd_voice_is_fav_item(arg1)) {
        dd_append_voice_msg(arg1, self);
    }
    %orig;
}
%end

#pragma mark - 接管语音消息发送

%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    DDVHit(kEvFwdMsg);
    if (dd_voice_is_msg(arg1)) {
        if (!dd_voice_forward_enabled()) { %orig; return; }
        dd_take_over_voice_msg(arg1, arg2);
        return;
    }
    %orig;
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 {
    DDVHit(kEvFwdList);
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3 {
    DDVHit(kEvFwdListBatch);
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3 {
    DDVHit(kEvFwdListScene);
    if (!dd_voice_forward_enabled()) { %orig; return; }
    NSArray *rest = dd_take_over_voice_list((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
%end

#pragma mark - 普通语音消息长按菜单加「转发」

%hook BaseMessageCellView
- (BOOL)canShowForwardMenuItem {
    DDVHit(kEvCellCanFwd);
    if (dd_voice_msg_enabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        return YES;
    }
    return %orig;
}
- (void)onForward:(id)arg1 {
    DDVHit(kEvCellOnFwd);
    if (dd_voice_msg_enabled() && [self isKindOfClass:objc_getClass("VoiceMessageCellView")]) {
        [self doForward];
        return;
    }
    %orig;
}
%end

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    DDVHit(kEvVoiceMenu);
    NSArray *original = %orig;
    if (!dd_voice_msg_enabled()) return original;
    id item = [self forwardMenuItem];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[original count] + 1];
    [items addObjectsFromArray:original];
    [items insertObject:item atIndex:0];
    return items;
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    DDVHit(kEvVoiceCanPerf);
    if (action == @selector(onForward:) && dd_voice_msg_enabled()) {
        return YES;
    }
    return %orig;
}
%end

#pragma mark - 设置界面

@interface DDVoiceSettingsViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@property (nonatomic, strong) UITextField *secondsField;
- (void)onExportLog:(id)sender;
- (void)onClearLog:(id)sender;
- (void)dd_alert:(NSString *)title msg:(NSString *)msg;
@end

@implementation DDVoiceSettingsViewController {
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
    self.title = @"DD语音助手";
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
    DDVoiceConfig *cfg = [DDVoiceConfig sharedConfig];

    // 设置语音秒数：开启后展开「自定义秒数」输入框
    [sec addCell:[cellMgr switchCellForSel:@selector(onSecondsSwitch:) target:self title:@"设置语音秒数" on:cfg.voiceSecondsEnabled]];
    if (cfg.voiceSecondsEnabled) {
        self.secondsField = [[UITextField alloc] init];
        self.secondsField.placeholder = @"自定义秒数(1-60)";
        self.secondsField.text = cfg.voiceSeconds;
        self.secondsField.textAlignment = NSTextAlignmentRight;
        self.secondsField.keyboardType = UIKeyboardTypeNumberPad;   // 键盘限制数字
        self.secondsField.delegate = self;                          // 限制：仅数字且 ≤60 秒
        [self.secondsField addTarget:self action:@selector(onSecondsChanged:) forControlEvents:UIControlEventEditingChanged];
        [sec addCell:[cellMgr normalCellForSel:nil
                                        target:nil
                                         title:@"   ↳自定义秒数"
                                     rightView:[self inputRowWithField:self.secondsField action:@selector(onSecondsConfirmed:)]]];
    }

    [sec addCell:[cellMgr switchCellForSel:@selector(onFavSwitch:) target:self title:@"收藏语音转发" on:cfg.favEnabled]];
    [sec addCell:[cellMgr switchCellForSel:@selector(onMsgSwitch:) target:self title:@"语音消息转发" on:cfg.msgEnabled]];

    // 日志（证书注入看不到系统日志，用导出文件代替）
    NSInteger n = [[DDVoiceLog shared] lineCount];
    [sec addCell:[cellMgr normalCellForSel:@selector(onExportLog:) target:self
                                     title:[NSString stringWithFormat:@"导出日志（%ld 行）", (long)n]
                                 rightView:nil]];
    [sec addCell:[cellMgr normalCellForSel:@selector(onClearLog:) target:self title:@"清空日志" rightView:nil]];
    [_tableViewManager addSection:sec];
    [_tableViewManager reloadTableView];
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
- (void)onFavSwitch:(UISwitch *)s {
    [DDVoiceConfig sharedConfig].favEnabled = s.on;
    DDVLog(@"配置 收藏语音转发 → %@", s.on ? @"开" : @"关");
}
- (void)onMsgSwitch:(UISwitch *)s {
    [DDVoiceConfig sharedConfig].msgEnabled = s.on;
    DDVLog(@"配置 语音消息转发 → %@", s.on ? @"开" : @"关");
}
// 导出日志：落盘后用系统分享面板发出（可存「文件」App / 发给自己 / 备忘录）
- (void)onExportLog:(id)sender {
    NSString *path = [[DDVoiceLog shared] flush];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self dd_alert:@"导出失败" msg:path];
        return;
    }
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                     applicationActivities:nil];
    av.popoverPresentationController.sourceView = self.view;
    av.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                                             CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:av animated:YES completion:nil];
}
// 清空日志
- (void)onClearLog:(id)sender {
    [[DDVoiceLog shared] clear];
    [self buildTable];
    [self dd_alert:@"已清空" msg:[[DDVoiceLog shared] path]];
}
- (void)dd_alert:(NSString *)title msg:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title
                                                                message:msg
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}
// 设置语音秒数：开关切换即重建表格（开启则展开输入框）
- (void)onSecondsSwitch:(UISwitch *)s {
    [DDVoiceConfig sharedConfig].voiceSecondsEnabled = s.isOn;
    DDVLog(@"配置 自定义语音秒数 → %@", s.isOn ? @"开" : @"关");
    [self buildTable];
}
// 输入即自动生效（空字符串视为不覆盖，等价于关闭）
- (void)onSecondsChanged:(UITextField *)field {
    [DDVoiceConfig sharedConfig].voiceSeconds = field.text;
}
// 确认：收起键盘并确认当前输入
- (void)onSecondsConfirmed:(id)sender {
    [DDVoiceConfig sharedConfig].voiceSeconds = self.secondsField.text;
    DDVLog(@"配置 自定义秒数 = %@", [self.secondsField.text length] ? self.secondsField.text : @"空(不覆盖)");
    [self.secondsField resignFirstResponder];
}
// 限制：仅允许数字、且不超过微信语音上限（60 秒）；空串保留（表示不覆盖/关闭）
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (textField != self.secondsField) return YES;
    NSString *next = [textField.text stringByReplacingCharactersInRange:range withString:string];
    if ([next length] == 0) return YES;                                       // 空 = 不覆盖（关闭）
    if ([[next stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] length] > 0)
        return NO;                                                            // 非数字字符拒绝
    int v = [next intValue];
    if (v < 1 || v > kDDVoiceMaxSeconds) return NO;                           // 限制：1~60 秒
    return YES;
}
// 右侧容器：输入框 + 确认按钮（尺寸/样式与 DD收款助手一致：灰底、圆角、系统默认文字颜色）
- (UIView *)inputRowWithField:(UITextField *)field action:(SEL)action {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 34)];
    container.backgroundColor = [UIColor clearColor];

    // 输入框（灰色背景、圆角、无边框、左右留白）
    field.frame = CGRectMake(0, 0, 160, 34);
    field.borderStyle = UITextBorderStyleNone;
    field.backgroundColor = [UIColor systemGray5Color];
    field.layer.cornerRadius = 6.0;
    field.layer.masksToBounds = YES;
    field.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.leftViewMode = UITextFieldViewModeAlways;
    field.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
    field.rightViewMode = UITextFieldViewModeAlways;
    [container addSubview:field];

    // 确认按钮（灰色背景、系统默认文字颜色、常规字体、圆角）
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(168, 0, 52, 34);
    [btn setTitle:@"确认" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor systemGray5Color];
    btn.layer.cornerRadius = 6.0;
    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:btn];

    return container;
}
@end

#pragma mark - 注册

%ctor {
    @autoreleasepool {
        DDVLog(@"插件载入（kDDVoiceApplyWhenNoRef=%d）", kDDVoiceApplyWhenNoRef);
        id mgr = objc_getClass("WCPluginsMgr");
        [[mgr sharedInstance] registerControllerWithTitle:@"DD语音助手"
                                                  version:@"1.0.0"
                                               controller:@"DDVoiceSettingsViewController"];
    }
}

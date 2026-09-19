
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

#pragma mark - 配置（单开关，默认 OFF）
#define kDDFVEnable @"kDDFV_enableFavVoiceForward"
static const BOOL kDDFVDefaultEnable = NO;

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

@interface DDFavVoiceConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL enabled;
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
    [NSUserDefaults.standardUserDefaults registerDefaults:@{ kDDFVEnable: @(kDDFVDefaultEnable) }];
}
- (instancetype)init {
    if (self = [super init]) {
        _enabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDFVEnable];
    }
    return self;
}
- (void)setEnabled:(BOOL)v {
    _enabled = v;
    [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDFVEnable];
}
@end

static BOOL ddFavVoiceEnabled(void) {
    return [DDFavVoiceConfig sharedConfig].enabled;
}

#pragma mark - 判定工具

static BOOL dd_isVoiceMsg(id msg) {
    if (!msg) return NO;
    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return NO;
    if (![msg isKindOfClass:wrapCls]) return NO;
    if (![msg respondsToSelector:@selector(m_uiMessageType)]) return NO;
    return ((CMessageWrap *)msg).m_uiMessageType == (unsigned int)kDDVoiceMsgType;
}

static BOOL dd_isFavVoiceItem(id obj) {
    if (!obj) return NO;
    Class itemCls = objc_getClass("FavoritesItem");
    if (!itemCls) return NO;
    if (![obj isKindOfClass:itemCls]) return NO;
    if (![obj respondsToSelector:@selector(type)]) return NO;
    return ((FavoritesItem *)obj).type == kDDFavVoiceItemType;
}

static BOOL dd_fileExists(NSString *path) {
    if (![path isKindOfClass:[NSString class]]) return NO;
    if ([path length] == 0) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
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
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    if (!wrap || !voiceData) return NO;
    // 0x75951c / 0x759520：wrap 为空或 duration 为 0 直接失败
    if (duration == 0) return NO;
    if ([voiceData length] == 0) return NO;
    id ext = dd_voiceExtendInfo(wrap, YES);
    if (!ext) return NO;
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    [ext setM_dtVoice:voiceData];
    return YES;
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
    if (localID == 0) return nil;
    NSString *usr = dd_ownerUserForVoice(msg);
    if ([usr length] == 0) return nil;

    // 0x759714 ~ 0x759794：优先 CUtility GetPathOfMesAudio:LocalID:DocPath:
    Class cu = objc_getClass("CUtility");
    if (cu && [cu respondsToSelector:@selector(GetDocPath)] &&
        [cu respondsToSelector:@selector(GetPathOfMesAudio:LocalID:DocPath:)]) {
        id doc = [cu GetDocPath];
        if ([doc isKindOfClass:[NSString class]]) {
            id p = [cu GetPathOfMesAudio:usr LocalID:localID DocPath:doc];
            if ([p isKindOfClass:[NSString class]] && dd_fileExists((NSString *)p)) return (NSString *)p;
        }
    }
    // 0x759840 ~ 0x75987c：其次 AudioSender getAudioFileName:LocalID:
    id sender = dd_mmService(@"AudioSender");
    if (sender && [sender respondsToSelector:@selector(getAudioFileName:LocalID:)]) {
        id p = [sender getAudioFileName:usr LocalID:localID];
        if ([p isKindOfClass:[NSString class]] && dd_fileExists((NSString *)p)) return (NSString *)p;
    }
    // 0x759888 ~ 0x759994：兜底，把 m_dtVoice 写成 NSTemporaryDirectory 下 UUID.aud
    NSData *data = dd_voiceData(msg);
    if ([data length] == 0) return nil;
    NSString *name = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    if (![data writeToFile:tmp atomically:YES]) return nil;
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
    // 0x75a2cc ~ 0x75a2e8：目录不存在就直接失败，锤子不会新建目录
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) {
        NSLog(@"[DDFavVoice] Audio 目录不存在 %@", dir);
        return nil;
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
    if (!sender) return NO;
    if (![sender respondsToSelector:@selector(addMessageToDB:)]) return NO;
    if (![sender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) return NO;

    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return NO;
    id raw = [wrapCls alloc];
    if (![raw respondsToSelector:@selector(initWithMsgType:)]) return NO;
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    if (!wrap) return NO;
    // 0x759ebc ~ 0x759ec4
    [wrap setM_uiMessageType:(unsigned int)kDDVoiceMsgType];

    // 0x759ecc ~ 0x759ed4
    NSString *fromUsr = nil;
    Class settingCls = objc_getClass("SettingUtil");
    if (settingCls && [settingCls respondsToSelector:@selector(getCurUsrName)]) {
        id u = [settingCls getCurUsrName];
        if ([u isKindOfClass:[NSString class]]) fromUsr = (NSString *)u;
    }
    if ([fromUsr length] == 0) return NO;
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
    if (!dd_configureVoiceMsg(wrap, d, duration)) return NO;
    if (![sender addMessageToDB:wrap]) return NO;

    NSString *installed = dd_installAudioFile(wrap, audPath);
    if ([installed length] == 0) {
        if ([sender respondsToSelector:@selector(deleteMessageFromDB:)]) [sender deleteMessageFromDB:wrap];
        return NO;
    }
    NSLog(@"[DDFavVoice] 发送语音 -> %@ 时长=%ums 文件=%@", usr, duration, installed);
    [sender ResendVoiceMsg:usr MsgWrap:wrap];
    return YES;
}

// 对齐锤子 0x7908c8：接管语音消息的发送
static BOOL dd_takeOverVoiceMsg(id msg, id contact) {
    if (!dd_isVoiceMsg(msg)) return NO;
    if (!contact) return NO;
    NSString *usr = nil;
    if ([contact respondsToSelector:@selector(m_nsUsrName)]) {
        id u = [(CBaseContact *)contact m_nsUsrName];
        if ([u isKindOfClass:[NSString class]]) usr = (NSString *)u;
    }
    if ([usr length] == 0) return NO;
    NSString *audPath = dd_audioPathForMsg(msg);
    if ([audPath length] == 0) {
        NSLog(@"[DDFavVoice] 拿不到语音文件，取消发送");
        return NO;
    }
    unsigned int duration = dd_voiceDuration(msg);
    // 0x790950：时长为 0 不发送
    if (duration == 0) {
        NSLog(@"[DDFavVoice] 语音时长为 0，取消发送");
        return NO;
    }
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

// 对齐锤子 0x790570：把收藏语音数据构造成一条待转发的语音消息
static id dd_msgWrapFromFavData(id favData) {
    if (!favData) return nil;
    Class fieldCls = objc_getClass("FavoritesItemDataField");
    if (!fieldCls || ![favData isKindOfClass:fieldCls]) return nil;
    FavoritesItemDataField *field = (FavoritesItemDataField *)favData;
    if (![field respondsToSelector:@selector(GetDataPath)]) return nil;

    id pathObj = [field GetDataPath];
    if (![pathObj isKindOfClass:[NSString class]]) return nil;
    NSData *data = [NSData dataWithContentsOfFile:(NSString *)pathObj
                                          options:NSDataReadingMappedIfSafe
                                            error:nil];
    if ([data length] == 0) return nil;

    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) return nil;
    id raw = [wrapCls alloc];
    if (![raw respondsToSelector:@selector(initWithMsgType:)]) return nil;
    CMessageWrap *wrap = [raw initWithMsgType:kDDVoiceMsgType];
    if (!wrap) return nil;

    // 0x790644 ~ 0x79065c
    NSString *me = nil;
    Class settingCls = objc_getClass("SettingUtil");
    if (settingCls && [settingCls respondsToSelector:@selector(getCurUsrName)]) {
        id u = [settingCls getCurUsrName];
        if ([u isKindOfClass:[NSString class]]) me = (NSString *)u;
    }
    if ([me length] > 0) [wrap setM_nsFromUsr:me];
    // 0x790668 ~ 0x790678
    [wrap setM_uiCreateTime:(unsigned int)time(NULL)];

    // 0x790688 ~ 0x79069c：时长直接用收藏数据里的 duration，不做换算
    unsigned int duration = field.duration;
    if (!dd_configureVoiceMsg(wrap, data, duration)) return nil;
    // 0x7906a4 ~ 0x7906bc
    [wrap setM_uiMesLocalID:dd_newVoiceLocalID()];
    return wrap;
}

// 对齐锤子 0x790484 ~ 0x7904e8：取 dataList 首项构造消息，append 进 m_messageWrapList
static void dd_appendVoiceMsg(id favItem, id controller) {
    NSArray *list = ((FavoritesItem *)favItem).dataList;
    if (![list isKindOfClass:[NSArray class]] || [list count] == 0) return;
    id wrap = dd_msgWrapFromFavData([list firstObject]);
    if (!wrap) {
        NSLog(@"[DDFavVoice] 收藏语音没有可用数据");
        return;
    }
    Class ctrlCls = objc_getClass("FavForwardLogicController");
    if (ctrlCls && ![[controller class] isSubclassOfClass:ctrlCls]) return;
    Ivar iv = class_getInstanceVariable([controller class], "m_messageWrapList");
    if (!iv) return;
    id store = object_getIvar(controller, iv);
    if (![store isKindOfClass:[NSMutableArray class]]) return;
    [(NSMutableArray *)store addObject:wrap];
    NSLog(@"[DDFavVoice] 已加入待转发语音消息");
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

#pragma mark - 二 阻止语音被降级成文本（0x78f628）
%hook ForwardMsgUtil
+ (id)ConvertMsgToTextIfCannotSend:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isVoiceMsg(arg1)) return nil;
    return %orig;
}
%end

#pragma mark - 三 把收藏语音做成待转发消息（0x78f4e8）
%hook FavForwardLogicController
- (void)addMsgFromItem:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1)) {
        FavoritesItem *item = (FavoritesItem *)arg1;
        id ctrl = self;
        if (item.needDownLoad) {
            // 0x7903d0 先发起下载；0x78fed0 是 DispatchQueue.global(qos:.utility).async{轮询→回主线程回调}
            // 轮询体见 0x79019c：最多 240 次、每次 sleepForTimeInterval:0.25
            dd_startDownloadFavItem(item);
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                dd_waitDownloadFinish(item);
                dispatch_async(dispatch_get_main_queue(), ^{ dd_appendVoiceMsg(item, ctrl); });
            });
        } else {
            dd_appendVoiceMsg(item, ctrl);
        }
    }
    // 0x78f5cc：原实现无条件调用
    %orig;
}
%end

#pragma mark - 四 接管语音消息的发送（0x78f6c8 / 0x78f77c / 0x78f8b0 / 0x78f9f8）
%hook ForwardMessageLogicController
- (void)ForwardMsg:(id)arg1 ToContact:(id)arg2 {
    if (ddFavVoiceEnabled() && dd_isVoiceMsg(arg1)) {
        // 0x78f718 ~ 0x78f724：命中即接管，无论成败都不再走原实现
        dd_takeOverVoiceMsg(arg1, arg2);
        return;
    }
    %orig;
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 {
    if (!ddFavVoiceEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 WithRevokeBatchId:(id)arg3 {
    if (!ddFavVoiceEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
- (void)ForwardMsgList:(id)arg1 ToContact:(id)arg2 batchRevokeScene:(unsigned long long)arg3 {
    if (!ddFavVoiceEnabled() || ![arg1 isKindOfClass:[NSArray class]]) { %orig; return; }
    NSArray *rest = dd_takeOverVoiceList((NSArray *)arg1, arg2);
    if ([rest count] == 0) return;
    %orig(rest, arg2, arg3);
}
%end

#pragma mark - 五 收藏列表转发前先完成下载（0x78f244）
%hook MyFavoritesListViewController
- (void)forwardData:(id)arg1 {
    if (ddFavVoiceEnabled() && dd_isFavVoiceItem(arg1) && ((FavoritesItem *)arg1).needDownLoad) {
        FavoritesItem *item = (FavoritesItem *)arg1;
        dd_startDownloadFavItem(item);
        if ([self respondsToSelector:@selector(startLoadingWithText:)]) {
            MMUIViewController *vc = (MMUIViewController *)self;
            [vc startLoadingWithText:@"语音下载中"];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                dd_waitDownloadFinish(item);
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([vc respondsToSelector:@selector(stopLoading)]) [vc stopLoading];
                });
            });
        }
        // 0x78f458：命中后直接收尾，不调用原实现
        return;
    }
    %orig;
}
%end

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
    [sec addCell:[cellMgr switchCellForSel:@selector(onEnableSwitch:) target:self title:@"启用收藏语音转发" on:[DDFavVoiceConfig sharedConfig].enabled]];
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
- (void)onEnableSwitch:(UISwitch *)s { [DDFavVoiceConfig sharedConfig].enabled = s.on; }
@end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD收藏语音转发"
                                                      version:@"1.0.0"
                                                   controller:@"DDFavVoiceSettingsViewController"];
        }
    }
}

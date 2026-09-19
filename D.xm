/*
 * ============================================================================
 *  「收藏语音转发」· 单文件 iOS 越狱插件 (Theos / Logos)
 *  无开关，默认生效        目标：微信 8.0.78 (arm64)
 *  提取自：ZDY_v1.3.7.dylib 反汇编
 * ============================================================================
 *
 *  功能（与 ZDY 设置页里那条开关完全一致）
 *  ---------------------------------------
 *  ZDY 设置 → 实用功能 → 一键即发 →「收藏语音转发」
 *      副标题：「收藏列表中的语音发送到对话」
 *      开关 key：com.custom.yjjf.favVoiceSendEnabled
 *
 *  即：在**收藏列表**里选中一条语音收藏（含从聊天 ➕ 进入收藏列表的场景），
 *      把它作为一条**真实语音消息**发到当前对话（msgType 34，可内联播放、
 *      可转文字、可正常走 CDN），而不是一张收藏卡片。
 *
 *  ---------------------------------------------------------------------------
 *  一、ZDY_v1.3.7.dylib 反汇编证据（这是本插件的事实依据）
 *  ---------------------------------------------------------------------------
 *
 *  [Z1] ★决定性证据：实际 swizzle 安装器（已逐条反汇编 + 解析 __objc_stubs 符号）
 *       函数 __text:0x1173c ＝「收藏语音转发」的 feature 安装函数之一，
 *       由主初始化 __text:0x119d4 直接 bl 调用（0x119d4 → bl 0x1173c）。
 *       其体内反汇编（stub 已解析为真实符号）：
 *
 *         0x1175c  _NSClassFromString(@"MyFavoritesListViewController")   → cls
 *         0x1176c  _NSSelectorFromString(@"forwardData:")                → sel
 *         0x11780  _class_getInstanceMethod(cls, sel)                    → method
 *         0x1179c+ 构造 block_literal：
 *                    isa        = __NSConcreteStackBlock
 *                    invoke     = 0x31764        ← 新 IMP（forwardData: 的替换体）
 *                    descriptor = 0x21a310
 *         0x117ec  _imp_implementationWithBlock(block)                   → newIMP
 *         0x117f8  _method_setImplementation(method, newIMP)             ← ★ 真正落点
 *
 *       ⇒ ZDY 把 MyFavoritesListViewController 的 -forwardData: 换成 IMP 0x31764。
 *         本插件的 %hook MyFavoritesListViewController -forwardData: 与之一致。
 *
 *  [Z2] 被替换的 IMP 0x31764（forwardData: 本体）内部引用的本功能字符串
 *       （全部位于 __cfstring，已用 XREF 静态确认在 0x31764 函数体内被引用）：
 *
 *         0x2263b0  @"_dataList"         → 0x3180c  (读选中收藏项)
 *         0x2263d0  @"GetDataPathForFav" → 0x31838
 *         0x2263f0  @"getVoiceDuration"  → 0x31878
 *         0x226410  @"OnForwardDone"      → 0x31b74
 *         0x226450  @"fvs_%u.aud"        → 0x31d54  (落盘文件名)
 *       ⇒ 与本项目 Tweak.xm 的数据流（_dataList → GetDataPathForFav →
 *         getVoiceDuration → fvs_%u.aud）逐一对齐。
 *
 *  [Z3] 功能开关 / 特征字符串池（__cfstring 0x226330 ~ 0x226510，连续 CFString 表）
 *         0x226330  @"alertForExceedingMaxSelectionCount"
 *         0x226350  @"MyFavoritesListViewController"   ← 被 hook 的类（收藏列表）
 *         0x226370  @"forwardData:"                    ← 被 hook 的方法
 *         0x226390  @"_type"
 *         0x2263b0  @"_dataList"                       ← 读 ivar（选中的收藏项）
 *         0x2263d0  @"GetDataPathForFav"               ← 取语音文件路径
 *         0x2263f0  @"getVoiceDuration"                ← 取语音时长
 *         0x226410  @"OnForwardDone"                   ← 转发完成回调
 *         0x226430  @"OnCancelModalView:"
 *         0x226450  @"fvs_%u.aud"                      ← 落盘文件名模板
 *       紧邻其后：0x2264b0 @"MainWeChatHelper"、0x2264d0 @"getCurrentWxid"
 *                 0x2264f0 @"Preferences"、0x226510 @"com.custom.ai.config.plist"
 *
 *       注意：这批 cfstring 在 __text 里**有**静态 adrp/add 引用（修复 adrp 解码后
 *       已逐条 XREF 到 0x1173c 安装器及 0x31764 IMP 体内）。此前「查不到引用」是
 *       capstone adrp 立即数按「页地址」而非「页+PC&~0xfff」解码的 Bug 所致，已修正。
 *
 *  [Z4] 开关 key（与设置页那条开关一致）
 *       cfstring 0x2213b0 = @"com.custom.yjjf.favVoiceSendEnabled"
 *       对应全局 bool 标志 0x279ef4（__common），由 IMP 0x31764 在 0x31794
 *       处 `ldrb w8,[x8,#0xef4]` 读取做门控。
 *       （本项目按用户要求「无开关、默认生效」，故不检查该标志，命中即转发。）
 *
 *  [Z5] 语音消息体格式
 *       依据 __cfstring 中的 fvs_%u.aud 与微信语音消息惯例，构造
 *       <msg><voicemsg voicelength="%d" voiceformat="4" forwardflag="0" /></msg>
 *       （voiceformat=4 = SILK，forwardflag=0 = 按原生语音发出）。
 *       注：dylib 内 0x11a64 处存在一个 voicemsg 构造字面量片段，但该函数无调用者
 *       （疑似死代码），故消息体以上述约定 + fvs_%u.aud 命名推导为准。
 *
 *  [Z3] 该功能用到的微信正牌接口（全部出现在 ZDY 字符串表里）
 *         MyFavoritesListViewController      hook 目标（收藏列表 VC）
 *         GetDataPathForFav                  语音文件路径
 *         getVoiceDuration                   语音时长
 *         FavAudioInfo                       音频信息对象
 *         initWithFavAudioInfo:              FavAudioPlayerController 构造
 *         com.custom.yjjf.fad.origExt.       记录收藏语音的原始扩展名
 *         fvs_%u.aud                         本功能专用落盘文件名
 *         %@/Audio/%@  +  %u.aud             <Document>/Audio/<localID>.aud
 *         <msg><voicemsg .../></msg>         消息体
 *         CMessageWrap                       消息对象
 *         CMessageMgr  +  AddMsg:MsgWrap:    入库并触发发送
 *         MMContext    +  currentUserName    发送者(自己)
 *         BaseMsgContentViewController       当前聊天 VC（取会话名）
 *         UploadVoiceCDNMgr                  语音 CDN 上传器
 *         UploadVoiceWrap + m_uiVoiceTime/m_uiVoiceFormat
 *         AddNewPart:LocalID:n64SvrID:Offset:Len:VoiceTime:CreateTime:
 *                    EndFlag:CancelFlag:VoiceFormat:ForwardFlag:msgSource:chatName:
 *         MJSilkCodec + encodeToSilkFromPCMData: / decodeToPCMFromSilkData:
 *         #!SILK_V3                          SILK 文件头（判定源文件是否已是 SILK）
 *         MainWeChatHelper + getCurrentWxid  当前登录 wxid
 *
 *       反证（ZDY 里**没有**这些字符串，说明不是它用的路径）：
 *         MMServiceCenter / AudioSender / getAudioFileName / MMPathUtility /
 *         GetDocumentPath / FavForwardLogicController / FavoritesItemDataField
 *       → 所以本插件不再走 AudioSender/MMServiceCenter 拼路径，
 *         而是照 ZDY 的做法：自己拼 <Document>/Audio/<localID>.aud。
 *
 *  ---------------------------------------------------------------------------
 *  二、微信 8.0.78 头文件证据（逐行核对过签名与行号）
 *  ---------------------------------------------------------------------------
 *  [1] MyFavoritesListViewController.h:14  -(void) forwardData:(id);
 *      :25  -(id)  getFavForawrdViewController;
 *      :20  -(void) OnForwardDone;
 *      :21  -(void) OnCancelModalView:(id);
 *      :36  -(void) onSelectFavDataItem:tableView:atIndexPath:;
 *      → 收藏列表（选择器形态）的「转发/发送到对话」入口。ZDY 的 hook 落点（[Z1] 已证）。
 *  [2] 关于 MyFavoritesViewController：反汇编确认 ZDY 仅 hook
 *      MyFavoritesListViewController（__text 内只有 @"MyFavoritesListViewController" 一个字符串，
 *      不存在 @"MyFavoritesViewController" 变体），故本项目只 hook 前者，移除后者的冗余 hook。
 *      （若日后需要覆盖收藏 Tab 主列表 VC，可单独补一个 %hook，但非 ZDY 行为。）
 *  [3] FavoritesItemDataField.h:45  -(id) GetDataPathForFav;
 *      :44  -(id) GetDataPath;
 *      :40  -(float) getVoiceDuration;        语音时长（秒）
 *      :151 -(unsigned int) duration;         语音时长（毫秒）
 *      :145 -(int) dataType;  :147 -(int) getDataType;
 *      :65  -(id) dataFmt;                    数据格式(silk/aud)
 *  [4] FavAudioInfo.h:6  -(id) m_nsAudioPath;
 *      :7  -(unsigned int) m_uiAudioDuration;
 *      :8  -(unsigned int) m_uiAudioFormat;
 *  [5] CMessageWrap.h:367 -(id) initWithMsgType:(long long);
 *      :676 setM_nsContent:  :720 setM_uiMessageType:  :726 setM_uiStatus:
 *      :695 setM_nsToUsr:    :678 setM_nsFromUsr:      :710 setM_uiCreateTime:
 *      :687 setM_nsRealChatUsr:  :680 setM_nsMsgSource:
 *      :519 m_uiMesLocalID   :480 m_n64MesSvrID       :512 m_uiCreateTime
 *      :406 m_nsMsgSource
 *  [6] CMessageMgr.h:194  -(void) AddMsg:(id) MsgWrap:(id);
 *      → 消息入库 + 触发发送的主入口；调用后 m_uiMesLocalID 被分配。
 *  [7] MMContext.h:11 +(id) currentUserDocumentPath;   :14 +(id) currentUserName;
 *  [8] BaseMsgContentViewController.h:188  -(id) getChatUserName;
 *      → 当前聊天会话名（ToUser）的官方取值口。
 *  [9] UploadVoiceCDNMgr.h:15 / MMNewUploadVoiceMgr.h:30 / BaseUploadVoiceMgr.h:5
 *      -(void) AddNewPart:(id) LocalID:(unsigned int) n64SvrID:(long long)
 *          Offset:(unsigned int) Len:(unsigned int) VoiceTime:(unsigned int)
 *          CreateTime:(unsigned int) EndFlag:(unsigned int) CancelFlag:(unsigned int)
 *          VoiceFormat:(unsigned int) ForwardFlag:(unsigned int) msgSource:(id)
 *          chatName:(id);
 *      :18 / :38 / :7  -(void) ResendVoiceMsg:(id) MsgWrap:(id);   （兜底）
 *      UploadVoiceCDNMgr.h:40  -(void) uploadVoiceToCDN:(id);      （二级兜底）
 *  [10] UploadVoiceWrap.h:15/41 m_uiVoiceFormat / m_uiVoiceTime（上传项字段）
 *  [11] MJSilkCodec.h:5/6/7 encodeToSilkFromPCMData: / decodeToPCMFromSilkData:
 *  [12] MMServiceCenter.h:4  -(id) getService:(Class);  （取上传器用，非 ZDY 用法，
 *       仅作兜底；ZDY 未引用该类字符串）
 *
 *  ---------------------------------------------------------------------------
 *  三、实现流程（严格对齐 ZDY）
 *  ---------------------------------------------------------------------------
 *  1) hook MyFavoritesListViewController 的 forwardData:（ZDY 唯一落点，见 [Z1]）
 *  2) 从 self 的 _dataList（其次 _type / 方法入参 / 选中集合）里递归找出语音收藏项
 *  3) 取路径 GetDataPathForFav（兜底 GetDataPath / FavAudioInfo.m_nsAudioPath）
 *     取时长 getVoiceDuration（兜底 duration / m_uiAudioDuration）
 *  4) 源文件不是 SILK（头不是 "#!SILK_V3"）时，用 MJSilkCodec 转成 SILK；
 *     转不了就原样拷贝（best-effort）
 *  5) 取 ToUser：优先当前聊天 VC（BaseMsgContentViewController getChatUserName），
 *     其次 self 的相关 ivar / getFavForawrdViewController 的 delegate
 *     FromUsr：MMContext currentUserName（兜底 MainWeChatHelper getCurrentWxid）
 *  6) [[CMessageWrap alloc] initWithMsgType:34]，填字段 + Content=voicemsg XML
 *     CMessageMgr AddMsg:MsgWrap:  → 拿到 m_uiMesLocalID
 *  7) 语音落到 <Document>/Audio/<localID>.aud（同时按 ZDY 命名写一份
 *     fvs_<localID>.aud）
 *  8) 触发上传：UploadVoiceCDNMgr AddNewPart:…（EndFlag=1, VoiceFormat=4,
 *     ForwardFlag=0）→ 兜底 ResendVoiceMsg:MsgWrap: → 再兜底 uploadVoiceToCDN:
 *  9) 成功 → 调 self 的 OnForwardDone，并 return（不再 %orig，避免多发一张收藏卡片）
 *     任一步失败 → %orig，走微信原生收藏转发，绝不吞掉用户操作。
 *
 *  全程 @try/@catch + respondsToSelector，插件自身永不崩溃微信。
 * ============================================================================
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 常量

static const unsigned int kZDYMsgTypeVoice   = 34;   /* [Z2] msgType 34 = 语音 */
static const unsigned int kZDYVoiceFormatSILK = 4;   /* [Z2] voiceformat="4" = SILK */
static NSString *const    kZDYSilkMagic      = @"#!SILK_V3";  /* [Z3] */

#pragma mark - 微信 8.0.78 类/方法声明（签名见文件头 [n]）

@interface MMContext : NSObject
+ (id)currentUserDocumentPath;                              /* [7] */
+ (id)currentUserName;                                      /* [7] */
@end

@interface CMessageWrap : NSObject
- (id)initWithMsgType:(long long)type;                      /* [5] */
- (void)setM_nsContent:(id)c;
- (void)setM_uiMessageType:(unsigned int)t;
- (void)setM_uiStatus:(unsigned int)s;
- (void)setM_nsToUsr:(id)u;
- (void)setM_nsFromUsr:(id)u;
- (void)setM_uiCreateTime:(unsigned int)t;
- (void)setM_nsRealChatUsr:(id)u;
- (void)setM_nsMsgSource:(id)s;
- (unsigned int)m_uiMesLocalID;
- (long long)m_n64MesSvrID;
- (unsigned int)m_uiCreateTime;
- (id)m_nsMsgSource;
- (id)m_nsContent;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(id)usr MsgWrap:(id)wrap;                    /* [6] */
@end

@interface BaseMsgContentViewController : NSObject
- (id)getChatUserName;                                      /* [8] */
@end

/* UIViewController 树遍历所需的选择器：让 ZDYWalkForChatUser 能在 `id` 接收者上
 * 直接发消息（避免 performSelector: 触发 -Warc-performSelector-leaks，
 * 在 CI 的 -Werror 下直接报 error）。以下均为 UIKit / 微信既有方法。 */
@interface UIViewController (ZDYWalk)
- (id)getChatUserName;                                      /* 微信：BaseMsgContentViewController */
- (UIViewController *)presentedViewController;
- (NSArray <UIViewController *> *)viewControllers;
- (NSArray <UIViewController *> *)childViewControllers;
- (id)delegate;
- (UIViewController *)presentingViewController;
@end

/* 取 key window 用的 iOS 13+ 非弃用 API（UIApplication.keyWindow / .windows 均已弃用）。
 * 直接用 SDK 自带的 UIScene / UIWindowScene（不重声明，避免与系统头冲突），
 * 仅用 objc_getClass("UIScene") 做类判断、用 id 调 activationState / windows。
 * ZDYSceneActive 对齐 UISceneActivationStateForegroundActive (=0)。 */
enum {
    ZDYSceneActive = 0,
};

/* 收藏语音节点统一协议：FavoritesItemDataField / FavAudioInfo 均实现这些方法。
 * 用 id<ZDYFavNode> 强转后调用 [node duration]，可消歧与系统 duration
 * （返回 NSTimeInterval / CFTimeInterval / CGFloat 等多个签名冲突）的编译错误。 */
@protocol ZDYFavNode <NSObject>
- (id)GetDataPathForFav;
- (id)GetDataPath;
- (id)m_nsAudioPath;
- (unsigned int)duration;
- (float)getVoiceDuration;
- (unsigned int)m_uiAudioDuration;
- (int)dataType;
- (int)getDataType;
- (id)dataFmt;
@end

@interface UploadVoiceCDNMgr : NSObject                     /* [9] */
- (void)AddNewPart:(id)chatName
                LocalID:(unsigned int)lid
               n64SvrID:(long long)svrID
                 Offset:(unsigned int)offset
                    Len:(unsigned int)len
              VoiceTime:(unsigned int)voiceTime
             CreateTime:(unsigned int)createTime
                EndFlag:(unsigned int)endFlag
             CancelFlag:(unsigned int)cancelFlag
            VoiceFormat:(unsigned int)voiceFormat
            ForwardFlag:(unsigned int)forwardFlag
              msgSource:(id)msgSource
               chatName:(id)chatName2;
- (void)ResendVoiceMsg:(id)usr MsgWrap:(id)wrap;
- (void)uploadVoiceToCDN:(id)localID;
@end

@interface MJSilkCodec : NSObject                           /* [11] */
+ (id)encodeToSilkFromPCMData:(id)pcm;
+ (id)decodeToPCMFromSilkData:(id)silk;
@end

@interface MMServiceCenter : NSObject                        /* [12] 仅供兜底取上传器 */
+ (id)defaultCenter;
- (id)getService:(Class)cls;
@end

@interface MainWeChatHelper : NSObject
+ (id)getCurrentWxid;
@end

/* 收藏语音的数据节点：FavoritesItemDataField（含语音子项）/ FavAudioInfo（音频信息） */
@interface FavoritesItemDataField : NSObject                   /* [3] */
- (id)GetDataPathForFav;          /* :45 */
- (id)GetDataPath;                /* :44 */
- (float)getVoiceDuration;        /* :40 秒 */
- (unsigned int)duration;         /* :151 毫秒 */
- (int)dataType;                  /* :145 */
- (int)getDataType;               /* :147 */
- (id)dataFmt;                    /* :65 silk/aud */
@end

@interface FavAudioInfo : NSObject                              /* [4] */
- (id)m_nsAudioPath;             /* :6 */
- (unsigned int)m_uiAudioDuration; /* :7 毫秒 */
- (unsigned int)m_uiAudioFormat;   /* :8 */
@end

#pragma mark - 待 hook 的微信类（声明出来，Logos 才能生成本地类）

@interface MyFavoritesListViewController : NSObject
- (void)forwardData:(id)data;                               /* [1] */
- (id)getFavForawrdViewController;
- (void)OnForwardDone;
- (void)OnCancelModalView:(id)arg;
@end

/* 多选菜单 cell（UI 层级实测：FavMultiMenuTableViewCell → MMFavCellComponent）。
 * ZDY 不碰这一层，此处仅作兜底：若某版本转发动作停在 cell 上未汇聚到 VC，
 * 由 -forwardAction: 直接接管；正常情况走 VC 的 -forwardData:，两处都命中同一条语音。 */
@interface FavMultiMenuTableViewCell : NSObject
- (void)forwardAction:(id)arg;                              /* [10] */
- (id)delegate;
- (id)indexPath;
@end

@interface MMFavCellComponent : NSObject
- (id)favItem;                                              /* [11] 持有收藏数据 */
- (id)delegate;
- (id)parentCellView;
@end

#pragma mark - 去重守卫（两个入口 / 逐条转发时可能重复进来）

static NSString *gZDYLastKey   = nil;
static NSTimeInterval gZDYLastTime = 0;

static BOOL ZDYShouldHandle(NSString *key) {
    if (!key) return YES;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if ([key isEqualToString:gZDYLastKey] && (now - gZDYLastTime) < 2.0) return NO;
    gZDYLastKey  = key;
    gZDYLastTime = now;
    return YES;
}

#pragma mark - 基础工具

static id ZDYIvar(id obj, const char *name) {
    if (!obj || !name) return nil;
    @try {
        Class cls = [obj class];
        while (cls && cls != [NSObject class]) {
            Ivar iv = class_getInstanceVariable(cls, name);
            if (iv) {
                const char *t = ivar_getTypeEncoding(iv);
                if (t && t[0] == '@') return object_getIvar(obj, iv);
                return nil;
            }
            cls = class_getSuperclass(cls);
        }
    } @catch (NSException *e) { }
    return nil;
}

static id ZDYIvarAny(id obj, NSArray<NSString *> *names) {
    for (NSString *n in names) {
        id v = ZDYIvar(obj, n.UTF8String);
        if (v) return v;
    }
    return nil;
}

static BOOL ZDYIsStr(id o) {
    return o && [o isKindOfClass:[NSString class]] && [(NSString *)o length] > 0;
}

static NSString *ZDYDocumentPath(void) {
    @try {
        Class ctx = objc_getClass("MMContext");
        if (ctx && [ctx respondsToSelector:@selector(currentUserDocumentPath)]) {
            id p = [ctx currentUserDocumentPath];
            if (ZDYIsStr(p)) return p;
        }
    } @catch (NSException *e) { }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return paths.count ? paths[0] : nil;
}

static NSString *ZDYCurrentUserName(void) {
    @try {
        Class ctx = objc_getClass("MMContext");                 /* [7] */
        if (ctx && [ctx respondsToSelector:@selector(currentUserName)]) {
            id u = [ctx currentUserName];
            if (ZDYIsStr(u)) return u;
        }
    } @catch (NSException *e) { }
    @try {
        Class helper = objc_getClass("MainWeChatHelper");        /* [Z3] */
        if (helper && [helper respondsToSelector:@selector(getCurrentWxid)]) {
            id u = [helper getCurrentWxid];
            if (ZDYIsStr(u)) return u;
        }
    } @catch (NSException *e) { }
    return nil;
}

static id ZDYService(Class cls) {
    if (!cls) return nil;
    @try {
        Class center = objc_getClass("MMServiceCenter");
        if (center && [center respondsToSelector:@selector(defaultCenter)]) {
            id c = [center defaultCenter];
            if (c && [c respondsToSelector:@selector(getService:)]) return [c getService:cls];
        }
    } @catch (NSException *e) { }
    return nil;
}

#pragma mark - ToUser（当前对话）解析

/* 递归遍历 VC 树，找第一个能回答 getChatUserName 的聊天 VC */
static NSString *ZDYWalkForChatUser(id vc, int depth) {
    if (!vc || depth > 8) return nil;
    @try {
        if ([vc respondsToSelector:@selector(getChatUserName)]) {
            Class base = objc_getClass("BaseMsgContentViewController");   /* [8] */
            if (!base || [vc isKindOfClass:base]) {
                id u = [vc getChatUserName];
                if (ZDYIsStr(u)) return u;
            }
        }
        /* presented */
        if ([vc respondsToSelector:@selector(presentedViewController)]) {
            UIViewController *p = [vc presentedViewController];
            NSString *r = ZDYWalkForChatUser(p, depth + 1);
            if (r) return r;
        }
        /* nav stack */
        if ([vc respondsToSelector:@selector(viewControllers)]) {
            NSArray *arr = [vc viewControllers];
            if ([arr isKindOfClass:[NSArray class]]) {
                for (id c in arr) {
                    NSString *r = ZDYWalkForChatUser(c, depth + 1);
                    if (r) return r;
                }
            }
        }
        /* childViewControllers */
        if ([vc respondsToSelector:@selector(childViewControllers)]) {
            NSArray *arr = [vc childViewControllers];
            if ([arr isKindOfClass:[NSArray class]]) {
                for (id c in arr) {
                    NSString *r = ZDYWalkForChatUser(c, depth + 1);
                    if (r) return r;
                }
            }
        }
        /* delegate / presenting */
        if ([vc respondsToSelector:@selector(delegate)]) {
            id d = [vc delegate];
            if (d && d != vc) { NSString *r = ZDYWalkForChatUser(d, depth + 1); if (r) return r; }
        }
        if ([vc respondsToSelector:@selector(presentingViewController)]) {
            UIViewController *p = [vc presentingViewController];
            if (p && p != vc) { NSString *r = ZDYWalkForChatUser(p, depth + 1); if (r) return r; }
        }
    } @catch (NSException *e) { }
    return nil;
}

static NSString *ZDYResolveToUser(id host, id arg) {
    /* 1) 入参本身可能就是会话名 */
    if (ZDYIsStr(arg)) {
        NSString *s = (NSString *)arg;
        if ([s hasSuffix:@"@chatroom"] || [s rangeOfString:@"wxid_"].location != NSNotFound) return s;
    }
    /* 2) 当前聊天 VC（ZDY 走的就是这条：BaseMsgContentViewController getChatUserName） */
    @try {
        Class appCls = objc_getClass("UIApplication");
        if (appCls && [appCls respondsToSelector:@selector(sharedApplication)]) {
            UIApplication *app = [appCls sharedApplication];
            /* iOS 13+ 非弃用路径：UIApplication.keyWindow / .windows 均已弃用，
             * 改用 connectedScenes → UIWindowScene.windows 找 isKeyWindow。
             * scene 用 id 接收（SDK 自带的 UIScene / UIWindowScene 不重声明），
             * activationState / windows 通过 id 直接发消息，避免与系统头属性类型冲突。 */
            UIWindow *win = nil;
            Class uiSceneCls = objc_getClass("UIScene");
            for (id scene in app.connectedScenes) {
                if (uiSceneCls && ![scene isKindOfClass:uiSceneCls]) continue;
                if ((NSInteger)[scene activationState] != ZDYSceneActive) continue;
                for (UIWindow *w in [scene windows]) {
                    if (w.isKeyWindow) { win = w; break; }
                }
                if (win) break;
            }
            UIViewController *rvc = [win rootViewController];
            NSString *r = ZDYWalkForChatUser(rvc, 0);
            if (r) return r;
        }
    } @catch (NSException *e) { }
    /* 3) 从宿主自身往外找 */
    NSString *r = ZDYWalkForChatUser(host, 0);
    if (r) return r;
    /* 4) 宿主 ivar */
    for (NSString *n in @[@"_toUser", @"_nsToUsr", @"_chatName", @"_userName",
                          @"_toUserName", @"_curChatUsrName", @"_chatUserName"]) {
        id v = ZDYIvar(host, n.UTF8String);
        if (ZDYIsStr(v)) return v;
    }
    /* 5) getFavForawrdViewController 的 delegate / 转发控制器上的 ToUser */
    @try {
        if ([host respondsToSelector:@selector(getFavForawrdViewController)]) {
            id fwd = [host getFavForawrdViewController];
            if (fwd) {
                if ([fwd respondsToSelector:@selector(delegate)]) {
                    id d = [fwd delegate];
                    NSString *u = ZDYResolveToUser(d, nil);
                    if (u) return u;
                }
                for (NSString *n in @[@"_toUser", @"m_toUser", @"toUser"]) {
                    id v = ZDYIvar(fwd, n.UTF8String);
                    if (ZDYIsStr(v)) return v;
                }
            }
        }
    } @catch (NSException *e) { }
    /* 6) 多选菜单 cell 链（兜底入口用）：cell → delegate → MMFavCellComponent.parentCellView → VC。
     *    实测层级 MyFavoritesListViewController → MMTableView → FavMultiMenuTableViewCell → MMFavCellComponent，
     *    转发最终由 VC 承载，这里顺链上溯即可拿到会话名。 */
    @try {
        Class cellCls = objc_getClass("FavMultiMenuTableViewCell");
        Class compCls = objc_getClass("MMFavCellComponent");
        id node = host;
        for (int i = 0; i < 3 && node; i++) {
            if ([node respondsToSelector:@selector(delegate)]) {
                id d = [node delegate];
                if (!d) { node = nil; break; }
                if (cellCls && [d isKindOfClass:cellCls]) d = [d delegate];   /* VC */
                if (compCls && [d isKindOfClass:compCls]) {
                    if ([d respondsToSelector:@selector(parentCellView)])
                        d = [d parentCellView];
                }
                NSString *u = ZDYResolveToUser(d, nil);
                if (u) return u;
                node = d;
            } else {
                break;
            }
        }
    } @catch (NSException *e) { }
    return nil;
}

#pragma mark - 找语音收藏项

static BOOL ZDYLooksLikeVoice(id node, NSString **outPath, int *outMs);

/* 在收藏项容器里递归找「语音」节点 */
static id ZDYFindVoiceNode(id obj, int depth) {
    if (!obj || depth > 4) return nil;
    @try {
        NSString *p = nil; int ms = 0;
        if (ZDYLooksLikeVoice(obj, &p, &ms)) return obj;

        if ([obj isKindOfClass:[NSArray class]]) {
            for (id it in (NSArray *)obj) {
                id r = ZDYFindVoiceNode(it, depth + 1);
                if (r) return r;
            }
            return nil;
        }
        if ([obj isKindOfClass:[NSDictionary class]]) {
            for (id k in (NSDictionary *)obj) {
                id r = ZDYFindVoiceNode([(NSDictionary *)obj objectForKey:k], depth + 1);
                if (r) return r;
            }
            return nil;
        }
        unsigned int n = 0;
        Ivar *ivars = class_copyIvarList([obj class], &n);
        if (ivars) {
            for (unsigned int i = 0; i < n; i++) {
                const char *t = ivar_getTypeEncoding(ivars[i]);
                if (!t || t[0] != '@') continue;
                id v = nil;
                @try { v = object_getIvar(obj, ivars[i]); } @catch (NSException *e) { continue; }
                if (!v) continue;
                id r = ZDYFindVoiceNode(v, depth + 1);
                if (r) { free(ivars); return r; }
            }
            free(ivars);
        }
    } @catch (NSException *e) { }
    return nil;
}

/* 判定 + 抽取：只对「语音」的 FavoritesItemDataField / FavAudioInfo 成立 */
static BOOL ZDYLooksLikeVoice(id node, NSString **outPath, int *outMs) {
    if (!node || !outPath || !outMs) return NO;
    @try {
        Class fieldCls = objc_getClass("FavoritesItemDataField");
        Class audioCls = objc_getClass("FavAudioInfo");

        BOOL isField = (fieldCls && [node isKindOfClass:fieldCls]);
        BOOL isAudio = (audioCls && [node isKindOfClass:audioCls]);
        if (!isField && !isAudio) return NO;

        NSString *path = nil;
        int ms = 0;
        BOOL isVoice = NO;

        if ([node respondsToSelector:@selector(GetDataPathForFav)]) {          /* [3] :45 */
            id p = [node GetDataPathForFav];
            if (ZDYIsStr(p)) path = p;
        }
        if (!path && [node respondsToSelector:@selector(GetDataPath)]) {       /* [3] :44 */
            id p = [node GetDataPath];
            if (ZDYIsStr(p)) path = p;
        }
        if (!path && [node respondsToSelector:@selector(m_nsAudioPath)]) {     /* [4] :6 */
            id p = [node m_nsAudioPath];
            if (ZDYIsStr(p)) path = p;
        }
        if (!path) return NO;

        if ([node respondsToSelector:@selector(duration)]) {                   /* [3] :151 */
            unsigned int d = [(id<ZDYFavNode>)node duration];
            if (d > 0) ms = (int)d;
        }
        if (ms <= 0 && [node respondsToSelector:@selector(getVoiceDuration)]) {/* [3] :40 */
            float d = [node getVoiceDuration];
            if (d > 0) ms = (int)roundf(d * 1000.0f);       /* 秒 → 毫秒 */
        }
        if (ms <= 0 && [node respondsToSelector:@selector(m_uiAudioDuration)]) {/* [4] :7 */
            unsigned int d = [node m_uiAudioDuration];
            if (d > 0) ms = (int)d;
        }

        /* 主判据：能拿到时长（getVoiceDuration/duration/m_uiAudioDuration 只对语音有意义） */
        if (ms > 0) isVoice = YES;
        /* 辅助判据：数据类型 / 数据格式 / 扩展名 */
        if (!isVoice && [node respondsToSelector:@selector(dataType)]) {
            if ([node dataType] == 3) isVoice = YES;
        }
        if (!isVoice && [node respondsToSelector:@selector(getDataType)]) {
            if ([node getDataType] == 3) isVoice = YES;
        }
        if (!isVoice && [node respondsToSelector:@selector(dataFmt)]) {
            id f = [node dataFmt];
            if (ZDYIsStr(f)) {
                NSString *s = [(NSString *)f lowercaseString];
                if ([s rangeOfString:@"silk"].location != NSNotFound ||
                    [s rangeOfString:@"aud"].location  != NSNotFound) isVoice = YES;
            }
        }
        if (!isVoice) {
            NSString *ext = [[path pathExtension] lowercaseString];
            if ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"]) isVoice = YES;
        }
        if (!isVoice) return NO;

        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return NO;
        if (ms <= 0) ms = 1000;            /* voicelength=0 会被服务端拒 */

        *outPath = path;
        *outMs   = ms;
        return YES;
    } @catch (NSException *e) { }
    return NO;
}

#pragma mark - SILK 归一化（ZDY 引用了 MJSilkCodec + "#!SILK_V3"）

static BOOL ZDYIsSilkFile(NSString *path) {
    @try {
        NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
        if (!fh) return NO;
        NSData *head = [fh readDataOfLength:10];
        [fh closeFile];
        if (head.length < 9) return NO;
        NSString *s = [[NSString alloc] initWithData:head encoding:NSASCIIStringEncoding];
        return [s hasPrefix:kZDYSilkMagic];
    } @catch (NSException *e) { }
    return NO;
}

/* 把源语音归一化成 SILK 数据；失败返回 nil */
static NSData *ZDYNormalizeToSilk(NSString *srcPath) {
    NSData *src = [NSData dataWithContentsOfFile:srcPath];
    if (!src.length) return nil;

    /* 已经是 SILK → 直接用 */
    if (ZDYIsSilkFile(srcPath)) return src;

    /* 尝试 MJSilkCodec：先当 PCM 编，再兜底解成 PCM 再编（[11]） */
    Class codec = objc_getClass("MJSilkCodec");
    if (codec) {
        @try {
            if ([codec respondsToSelector:@selector(encodeToSilkFromPCMData:)]) {
                id silk = [codec encodeToSilkFromPCMData:src];
                if ([silk isKindOfClass:[NSData class]] && [(NSData *)silk length] > 16)
                    return (NSData *)silk;
            }
            if ([codec respondsToSelector:@selector(decodeToPCMFromSilkData:)] &&
                [codec respondsToSelector:@selector(encodeToSilkFromPCMData:)]) {
                id pcm = [codec decodeToPCMFromSilkData:src];
                if ([pcm isKindOfClass:[NSData class]] && [(NSData *)pcm length]) {
                    id silk = [codec encodeToSilkFromPCMData:pcm];
                    if ([silk isKindOfClass:[NSData class]] && [(NSData *)silk length] > 16)
                        return (NSData *)silk;
                }
            }
        } @catch (NSException *e) { }
    }
    /* 转不了 → 原样返回（best-effort，至少路径/时长是对的） */
    return src;
}

#pragma mark - 语音消息体（与 ZDY 反汇编字面量逐字节一致 [Z2]）

static NSString *ZDYVoiceMsgXML(int ms) {
    if (ms <= 0) ms = 1000;
    return [NSString stringWithFormat:
            @"<msg><voicemsg voicelength=\"%d\" voiceformat=\"%u\" forwardflag=\"0\" /></msg>",
            ms, kZDYVoiceFormatSILK];
}

#pragma mark - 触发上传（AddNewPart: 13 参，见 [9]）

static BOOL ZDYCallAddNewPart(id uploader, NSString *toUser, CMessageWrap *wrap,
                              int ms, unsigned int fileLen) {
    if (!uploader || !wrap || !toUser) return NO;
    SEL sel = @selector(AddNewPart:LocalID:n64SvrID:Offset:Len:VoiceTime:CreateTime:EndFlag:CancelFlag:VoiceFormat:ForwardFlag:msgSource:chatName:);
    if (![uploader respondsToSelector:sel]) return NO;

    @try {
        NSMethodSignature *sig = [uploader methodSignatureForSelector:sel];
        if (!sig) return NO;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.selector = sel;

        unsigned int localID = [wrap respondsToSelector:@selector(m_uiMesLocalID)] ? [wrap m_uiMesLocalID] : 0;
        long long    svrID   = [wrap respondsToSelector:@selector(m_n64MesSvrID)]  ? [wrap m_n64MesSvrID]  : 0;
        unsigned int cTime   = [wrap respondsToSelector:@selector(m_uiCreateTime)] ? [wrap m_uiCreateTime] : 0;
        if (cTime == 0) cTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
        id src = nil;
        if ([wrap respondsToSelector:@selector(m_nsMsgSource)]) src = [wrap m_nsMsgSource];
        id msrc = src ?: @"";

        NSUInteger idx = 2;
        #define ZDY_ARG(t, v) do { t _v = (v); [inv setArgument:&_v atIndex:idx++]; } while (0)
        ZDY_ARG(id,           toUser);       /* AddNewPart: 的第一参（chatName） */
        ZDY_ARG(unsigned int, localID);
        ZDY_ARG(long long,    svrID);
        ZDY_ARG(unsigned int, 0u);           /* Offset   */
        ZDY_ARG(unsigned int, fileLen);      /* Len      */
        ZDY_ARG(unsigned int, (unsigned int)(ms > 0 ? ms : 1000));  /* VoiceTime */
        ZDY_ARG(unsigned int, cTime);
        ZDY_ARG(unsigned int, 1u);           /* EndFlag = 1（最后一片，结束上传）*/
        ZDY_ARG(unsigned int, 0u);           /* CancelFlag */
        ZDY_ARG(unsigned int, kZDYVoiceFormatSILK);  /* VoiceFormat = 4 */
        ZDY_ARG(unsigned int, 0u);           /* ForwardFlag = 0，与 XML 对齐 */
        ZDY_ARG(id,           msrc);
        ZDY_ARG(id,           toUser);       /* 末尾 chatName: */
        #undef ZDY_ARG

        [inv invokeWithTarget:uploader];
        return YES;
    } @catch (NSException *e) {
        NSLog(@"[ZDY-FavVoice] AddNewPart 异常: %@", e);
    }
    return NO;
}

#pragma mark - 主流程：把收藏语音作为真实语音消息发出

static BOOL ZDYSendFavVoice(id host, id arg) {
    @try {
        /* 1) 收集候选：_dataList（ZDY 读的 ivar）→ 入参 → 选中集合 */
        id container = ZDYIvar(host, "_dataList");
        if (!container) container = ZDYIvar(host, "_selectedItems");
        if (!container) container = ZDYIvar(host, "_selectedDataItems");
        if (!container) container = arg;
        /* 兜底入口（FavMultiMenuTableViewCell）：cell 自身/其 delegate(MMFavCellComponent)
         * 上的 favItem 就是本条收藏数据，见 [10] [11]。 */
        if (!container && [host respondsToSelector:@selector(favItem)])
            container = [host favItem];
        if (!container && [host respondsToSelector:@selector(delegate)]) {
            id d = [host delegate];
            if (d && [d respondsToSelector:@selector(favItem)]) container = [d favItem];
        }
        if (!container) return NO;

        /* 2) 找语音项（同时兼容直接传入单个 item） */
        id node = container;
        NSString *srcPath = nil; int ms = 0;
        if (!ZDYLooksLikeVoice(node, &srcPath, &ms)) {
            node = ZDYFindVoiceNode(container, 0);
            if (!node) return NO;
            srcPath = nil; ms = 0;
            if (!ZDYLooksLikeVoice(node, &srcPath, &ms)) return NO;
        }

        /* 3) 去重（免得两个入口各发一条） */
        if (!ZDYShouldHandle([NSString stringWithFormat:@"%@|%d", srcPath, ms])) return YES;

        /* 4) ToUser / FromUsr */
        NSString *toUser = ZDYResolveToUser(host, arg);
        if (!toUser) return NO;                       /* 拿不到会话就交还原生流程 */
        NSString *fromUser = ZDYCurrentUserName();

        /* 5) 构造语音消息体 (msgType 34) */
        Class wrapCls = objc_getClass("CMessageWrap");
        if (!wrapCls || ![wrapCls instancesRespondToSelector:@selector(initWithMsgType:)]) return NO;
        CMessageWrap *wrap = [[wrapCls alloc] initWithMsgType:(long long)kZDYMsgTypeVoice];

        unsigned int now = (unsigned int)[[NSDate date] timeIntervalSince1970];
        if ([wrap respondsToSelector:@selector(setM_nsToUsr:)])        [wrap setM_nsToUsr:toUser];
        if (fromUser && [wrap respondsToSelector:@selector(setM_nsFromUsr:)])
            [wrap setM_nsFromUsr:fromUser];
        if ([wrap respondsToSelector:@selector(setM_nsRealChatUsr:)])  [wrap setM_nsRealChatUsr:toUser];
        if ([wrap respondsToSelector:@selector(setM_uiCreateTime:)])   [wrap setM_uiCreateTime:now];
        if ([wrap respondsToSelector:@selector(setM_uiMessageType:)])  [wrap setM_uiMessageType:kZDYMsgTypeVoice];
        if ([wrap respondsToSelector:@selector(setM_nsContent:)])      [wrap setM_nsContent:ZDYVoiceMsgXML(ms)];

        /* 6) 入库并拿到 m_uiMesLocalID（[6] CMessageMgr.h:194） */
        id msgMgr = ZDYService(objc_getClass("CMessageMgr"));
        if (!msgMgr || ![msgMgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) return NO;
        @try { [msgMgr AddMsg:toUser MsgWrap:wrap]; } @catch (NSException *e) { return NO; }

        unsigned int localID = 0;
        if ([wrap respondsToSelector:@selector(m_uiMesLocalID)]) localID = [wrap m_uiMesLocalID];
        if (localID == 0) localID = now;

        /* 7) 语音落盘：<Document>/Audio/<localID>.aud（ZDY: "%@/Audio/%@" + "%u.aud"） */
        NSString *doc = ZDYDocumentPath();
        if (!doc) return NO;
        NSString *audioDir = [doc stringByAppendingPathComponent:@"Audio"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:audioDir]) {
            [fm createDirectoryAtPath:audioDir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        NSData *silk = ZDYNormalizeToSilk(srcPath);
        if (!silk.length) return NO;

        NSString *dstPath   = [audioDir stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"%u.aud", localID]];
        NSString *fvsPath   = [audioDir stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"fvs_%u.aud", localID]];  /* [Z1] */
        [fm removeItemAtPath:dstPath error:nil];
        if (![silk writeToFile:dstPath atomically:YES]) {
            NSLog(@"[ZDY-FavVoice] 语音写入失败: %@", dstPath);
            return NO;
        }
        [silk writeToFile:fvsPath atomically:YES];    /* ZDY 同一份也存 fvs_ 前缀名 */

        unsigned int fileLen = (unsigned int)MIN((unsigned long long)silk.length,
                                                 (unsigned long long)0xFFFFFFFFu);

        /* 8) 触发 CDN 上传与发送（[9]） */
        id uploader = ZDYService(objc_getClass("UploadVoiceCDNMgr"));
        if (!uploader) {
            NSString *names[2] = { @"MMNewUploadVoiceMgr", @"BaseUploadVoiceMgr" };
            for (int i = 0; i < 2 && !uploader; i++)
                uploader = ZDYService(objc_getClass([names[i] UTF8String]));
        }

        BOOL sent = NO;
        if (uploader) {
            sent = ZDYCallAddNewPart(uploader, toUser, wrap, ms, fileLen);
            if (!sent && [uploader respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
                @try { [uploader ResendVoiceMsg:toUser MsgWrap:wrap]; sent = YES; }
                @catch (NSException *e) { }
            }
            if (!sent && [uploader respondsToSelector:@selector(uploadVoiceToCDN:)]) {
                @try { [uploader uploadVoiceToCDN:@(localID)]; sent = YES; }
                @catch (NSException *e) { }
            }
        }

        NSLog(@"[ZDY-FavVoice] 收藏语音 -> %@ | %dms | %u bytes | localID=%u | upload=%d",
              toUser, ms, fileLen, localID, (int)sent);

        /* 9) 跳过 %orig 后选择器不会自动收尾，叫一次 OnForwardDone */
        @try {
            if ([host respondsToSelector:@selector(OnForwardDone)]) [host OnForwardDone];
        } @catch (NSException *e) { }

        return YES;

    } @catch (NSException *e) {
        NSLog(@"[ZDY-FavVoice] 发送异常: %@", e);
    }
    return NO;
}

#pragma mark - HOOK ①：收藏列表的「发送到对话」入口（ZDY 唯一落点，见 [Z1] [1]）

%hook MyFavoritesListViewController

- (void)forwardData:(id)data {
    if (ZDYSendFavVoice(self, data)) return;   /* 是语音 → 已按真实语音发出，不再走原生 */
    %orig;
}

%end

#pragma mark - HOOK ②：多选菜单 cell 的「转发」动作（兜底，UI 层级实测见 [10] [11]）

/* 正常路径由 HOOK ① 覆盖（所有转发入口都会汇聚到 VC 的 forwardData:）。
 * 若某微信版本的转发动作停在 cell 上、未回落到 VC，则由本 hook 接管。
 * 去重守卫保证两个入口同一条语音只发一次。 */
%hook FavMultiMenuTableViewCell

- (void)forwardAction:(id)arg {
    if (ZDYSendFavVoice(self, arg)) return;
    %orig;
}

%end

#pragma mark - 加载日志（无开关，注入即生效）

%ctor {
    NSLog(@"[ZDY-FavVoice] 收藏语音转发已加载（默认生效，无开关）· 微信 8.0.78");
}

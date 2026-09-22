//  DD语音助手 v1.0.6  —— 媒体互转  (WeChat Tweak, Theos/Logos 单文件)
//  长按消息 → 按消息类型在原生长按悬浮菜单追加转换按钮 → 点击转换并发送到当前聊天：
//    视频消息 / 文件消息 → 「转语音」→ 转换成语音消息，发到当前聊天
//    语音消息          → 「转文件」→ 转换成 m4a 文件消息，发到当前聊天
//  未下载的视频 / 文件：先自动下载，下载完成后再转换（WCR 同款思路）。
//
//  调试日志（自签证书/未越狱看不到 syslog，故日志留在 App 内部）：
//    · DDLogStore 同时写内存环形缓冲 + 微信沙盒 Documents/DDVoiceAssistantLogs/ddvoice_debug.log
//    · 设置页「调试日志」分组：导出日志（生成 txt → 系统分享面板，可存「文件」App / 隔空投送 / 收藏）
//                            清空日志、日志开关
//    · 关键链路（菜单注入 / 路径解析 / 下载 / 抽音轨 / SILK 编解码 / 发送）全部用 dd_log() 埋点
//
//  v1.0.2 逐条反汇编 WCRefine.dylib 取证后的修复（用户原话：视频转语音还是没声音 / 长按文件直接闪退 /
//         语音转文件没有反应）。本版所有改动都对着指令地址，不再靠猜：
//    ① 视频转语音没声音
//       · 采样率错：我写的是 8000Hz，WCR sub_0x8f1bc8 在 0x8f1f68 用的是 mov w2,#0x3e80 == 16000
//       · 容器头错：微信 .aud 正规头是 **10 字节 \x02#!SILK_V3**，v1.0.1 只补了 9 字节 #!SILK_V3，
//         少了开头那个 0x02 → 微信解不出 → 静音。证据 WCR sub_0x8f18d8:
//           0x8f19ac b[0]==0x02 且 memcmp(b+1,"#!SILK_V3",9) → 原样返回
//           0x8f1a90 dataWithCapacity:len+1 → appendBytes(0x02,1) → appendData:
//       · 编码顺序反：WCR sub_0x8f2804 主路径是类方法 +encodeToSilkFromPCMData:，
//         实例 API 只在 respondsToSelector: 失败时才兜底且写死 16000Hz；v1.0.1 正好反过来还试了 8000/24000
//    ② 长按文件直接闪退（v1.0.1 引入的回归）
//       我在 AppFileMessageCellView -operationMenuItems 里同步调了 dd_file_path_of_msg()。
//       反汇编 WCR WCRefineAppendVoiceToolsMediaMenuItems(0x8dd96c) + 三个子追加器
//       (0x8ddae4/0x8dde20/0x8de1f8)：建菜单阶段只读开关、判 cell 类名、去重、造 item，
//       **一次都不碰文件路径** → 路径解析全部推迟到点击之后；另加 dd_is_msg_wrap 类型守卫，
//       防止 dd_msg_of_cell 交回来的非 CMessageWrap 对象被塞进 GetPathOfAppData: 而越界。
//    ③ 语音转文件没反应
//       dd_decode_silk_to_pcm 旧的「剥 4 字节/剥 1 字节」候选逻辑认不出 10 字节的 \x02#!SILK_V3 头，
//       直接 return nil 静默退出 → 改成先认容器（含 0x02 变体），
//       并且候选必须先过 dd_silk_frames_valid（WCR sub_0x8f15f4 同款帧链遍历）再喂解码器。
//    ④ 顺带补上 AVLinearPCMIsNonInterleaved（WCR 的 PCM 输出字典是 7 个键：0x8f2134 mov x4,#7）
//
//  v1.0.3 逐条对「微信 8.0.79 头文件 dump（46581 个 .h）」校验后打的一批**实锤错**：
//  之前所有「按头文件第 X 行」的注释都是对着旧版本 dump 写的，人到 8.0.79 就已经失真了。
//    ① 【高危】MMMenuItem 的父类搞错了 —— 我写的是 UIMenuItem，实际是 NSObject（MMMenuItem.h:1）。
//       微信拿到 operationMenuItems 后会按 MMMenuItem 自己的字段（iconImage/menuType/
//       itemViewCreateHandler/userInfo…）取值，按 UIMenuItem 语义理解它结果不可预期。
//       顺带发现：8.0.79 的 MMMenuItem **没有 title getter、没有 action getter**
//       （51 行头文件里只有 target）→ 原先靠 `it.action == action` 去重根本不成立。
//       改：去重改用自己的 userInfo 标记（MMMenuItem.h:29 读 / :49 写）。
//    ② 菜单图标：v1.0.5 起直接吃微信内置 svg 资源名 icon_filled_record_voice.svg（用户确认存在），
//       无兜底（initWithTitle:svgName:target:action:，MMMenuItem.h:18）。
//    ③ m_oAppDataItem 在 8.0.79 全库（46581 个 .h）里**一个都没有** —— 不是「偶尔为 nil」，
//       是彻底废弃。取数据项改走 CMessageWrap.h:382 的 m_extendInfoWithMsgType。
//       这直接影响文件扩展名识别 → 「文件识别失败」那类消息的菜单表现。
//    ④ 【语音转文件没反应的最后一环】dd_send_file_to_chat 里
//       原来用 [wrap setValue:app forKey:@"m_oAppDataItem"] 挂数据项 → 8.0.79 抛
//       NSUndefinedKeyException 被 @catch 吞掉 → extendInfo 永远挂不上 → AddAppMsg 内部
//       拿不到数据项 → 静默失败。改：[wrap setM_extendInfoWithMsgType:]（CMessageWrap.h:637）。
//       兜底 addMessageToDB: 也错了 —— 它只在 AudioSender 上（AudioSender.h:13），
//       CMessageMgr 没有 → respondsToSelector 恒 NO。改 AddLocalMsg:（CMessageMgr.h:191）。
//    ⑤ BaseMessageCellView 上其实没有 viewModel（真实锚在 BaseChatCellView.h:17）；
//       canPerformAction:withSender: 在 BaseMessageCellView.h:11；
//       四个 cell 的 operationMenuItems 行号：Video:12 / AppVideo:7 / AppFile:17 / Voice:34。
//    ⑥ 文件路径新增一条「不依赖 msgWrap 内部字段」的五参通道
//       +GetPathOfAppDataByUserName:andMessageWrap:andAttachId:andAttachFileExt:retStrPath:
//       （CMessageWrap.h:107）—— 专治字段残缺的「识别失败」文件。
//
//  v1.0.4（用户确认内置图标后调整）
//    菜单按钮图标改用微信**内置 svg 资源名 voice_record_filled.svg**（用户明确确认该资源在 8.0.79
//    存在）。主路径回到 initWithTitle:svgName:target:action: 直接吃 svg 名（MMMenuItem.h:18），
//    每个候选确认真解出 iconImage 才采用；仅当 svg 全都解不出图时，才退回到 v1.0.3 的
//    initWithTitle:icon: 借原生图标方案，最后才是纯文字。这样「转语音」「转文件」两个按钮
//    统一用语音录音图标，不再出现一个有图一个没图。
//
//  v1.0.5（用户确认图标名后再次调整）
//    图标资源名改为用户最终确认的 **icon_filled_record_voice.svg**（8.0.79 内置，用户确认存在），
//    并去掉所有兜底：不再借原生图标、不做纯文字构造。直接 initWithTitle:svgName:target:action:
//    吃这个 svg 名（MMMenuItem.h:18）。「转语音」「转文件」按钮统一用这一个内置图标。
//
//  v1.0.6（参考「视频转语音.txt」重写视频路径解析，仍以 8.0.79 头文件为准）
//    那份参考文件是另一个插件的视频转语音逻辑还原，用户要求「只作参考、以最新头文件为准」。
//    其中两点对真机可靠性有用、且能在头文件里坐实，故采纳：
//    ① 解析出的视频路径**可能是目录**，要在目录里找第一个 .mp4/.mov/.m4v（参考
//       WCLiteFirstVideoFileUnderPath）—— 我方原先只判 dd_file_exists(videoPath)，若 videoPath
//       是目录就会把目录当文件喂给 AVAssetReader 而抽不到音轨。新增 dd_first_video_file_under_path 修复。
//    ② 视频路径多源：除 VideoMessageViewModel.videoPath（VideoMessageViewModel.h:24）外，补上
//       WCLanDeviceServiceUtil +filePathFromMsgWrap:（WCLanDeviceServiceUtil.h:7）与
//       CUtility +GetDocPath（CUtility.h:49）两条头文件里确凿存在的权威源做兜底
//       （参考 WCLiteResolveVideoMessageLocalPath，覆盖 videoPath 在视频号/未下载场景取不到的情况）。
//       参考里的 WCLiteVoicePackSender 是它私有发送类（不在头文件里），不采纳，仍走我方
//       AddLocalMsg + ResendVoiceMsg 发送链路。类型判定沿用 43/62（kDDMVideoMsgType / kDDMShortVideoMsgType）。
//
//  v1.0.7（根治「转出来是静音消息」—— 用户真机日志定位）
//    用户 2026-09-22 导出的 DDMediaConvert 调试日志显示：视频→语音一路抽 PCM、编码出 16600 字节 SILK、
//    落盘 4.aud、ResendVoiceMsg 也调了，但**播放静音**；同一日志里「语音→文件」读同一个 .aud 时，
//    MJSilkCodec 的 decodeToAudioDataFromSilkData: / decodeToPCMFromSilkData: 都返回 0 字节
//    → 编码器产物连微信自己的解码器都解不回来。微信语音播放器用的就是 MJSilkCodec 这个解码器，
//    解不回 = 播放静音。旧逻辑（v1.0.2~v1.0.6）即便回环解码失败仍把类方法产物硬发出去，于是静音照发。
//    修复：dd_encode_pcm_to_silk 改为收集类方法 + 实例 API 两路原始产物，对每个产物生成
//    「\x02#!SILK_V3(magic10)」与「#!SILK_V3(magic9)」两个容器变体，逐一交给
//    MJSilkCodec decodeToPCMFromSilkData: 回环验证，**只发能解回来的容器**；全部解不开则
//    return nil 放弃发送（绝不发静音消息）。用微信自己的解码器当裁判，彻底消除 magic9/magic10 猜测。
//    另：non-SILK 路径的语音时长改用「真实抽出的 PCM 长度」算（旧逻辑用 asset.duration=视频时长，
//    日志里出现过视频 16.167s、音轨仅 8s 导致气泡时长错、播放错位）。
//
//  v1.0.8（修 CI 真机构建编译错误，非功能改动）
//    Xcode 26 SDK + 全局 -Werror 下，Tweak.xm 第 203~232 行手动 forward-declare 的
//    @interface CMessageWrap 里，@property(retain,nonatomic) NSString *m_nsToUsr / m_nsFromUsr
//    与手写的 -setM_nsToUsr: / -setM_nsFromUsr: 参数类型 (id) 不一致，编译器报
//    「type of property does not match type of accessor [-Werror]」致 make package 失败。
//    修复：把这两个 setter 参数类型对齐为 (NSString *)，与 property 类型一致
//    （CMessageWrap.h:695 / :678 真实签名即 NSString*，头文件锚定无误）。
//    同步把 .devtools/clang_syntax_check/check.py 的校验从 -fsyntax-only 升级为全局 -Werror
//    （仅对 GNUstep 桩固有噪音 incompatible-library-redeclaration 降权），使沙箱静态检查
//    能复现 CI 的 property/accessor 类型不匹配错误，不再漏检。
//
//  v1.0.9（修「闪退后日志被清空」，非功能改动）
//    用户实测 v1.0.8：视频转语音已出声；但文件转语音偶发闪退，且**闪退后设置页日志为空**，
//    无法据此定位闪退。根因在 DDLogStore.append:（Tweak.xm 约第 507 行）：原实现走
//    dispatch_async(_q) 异步写、且 writeData: 后从不 synchronizeFile（fsync），只有「导出」时
//    flushSync 才 fsync。进程在转换流程中崩溃的瞬间，队列里尚未执行的 block 与未刷盘的页缓存
//    一并丢失 → 闪退前的关键日志不在文件里（DDLogStore.h 注释原称「内存环形缓冲 + 落盘」，
//    实际落盘被延迟到导出才发生）。修复：append: 改为 dispatch_sync(_q) 同步写，每条写前
//    seekToEndOfFile、写后 synchronizeFile（fsync）落盘；_handle 失效时就地重建。崩溃前的每条
//    日志都已落盘，且 init 仅在不存时建空文件、不清空已有日志文件，故重启微信后闪退日志可查。
//    下一步：请用户重装 v1.0.9 后复现文件转语音闪退，进设置页导出日志即可定位闪退根因。
//
//  v1.0.10（修「语音转文件发出的 m4a 重启后/清理后打不开」，确定性 bug）
//    用户确认「文件打不开」，与上一轮推断的诱因二一致：dd_send_file_to_chat 把
//    NSTemporaryDirectory() 下的 m4a 路径**直接**交给 AddAppMsg:MsgWrap:DataPath:Scene:，
//    而微信 AddAppMsg 后续读取/上传的就是这个 DataPath；NSTemporaryDirectory() 在进程重启或
//    系统周期性清理时会被清空，文件消息指向死路径 → 本地/重启后打不开。
//    修复：新增 dd_persist_copy 在发送前把 m4a 拷进微信持久沙盒（CUtility.GetDocPath 优先、
//    退回 NSDocumentDirectory），用持久副本路径构造 extendInfo 与发送；原临时文件保留不动。
//    锚定：CUtility +GetDocPath（CUtility.h:49）；NSSearchPathForDirectoriesInDomains(NSDocumentDirectory)。
//    注：诱因一（取源路径随微信运行态漂移、重启后可能掉 m_dtVoice 兜底致时长/内容变）仍待日志坐实，
//    本轮未动解码逻辑，避免把已能用的视频转语音又带出静音。
//
//  v1.0.11（据 2026-09-23 06:22 真机日志，修「文件消息变 0B/23.dat」+「文件转语音闪退」）
//    用户日志暴露两处：
//    ① 语音转文件（06:20:53，localID=22）→ 发出的文件消息重启后变 0B 的 23.dat（用户截图）。
//       log 74 行显示微信把该文件落在 OpenData/<hash>/23.m4a（23=localID），而不是我们持久化的
//       ddmc_voice_*.m4a。根因：AddAppMsg:MsgWrap:DataPath:Scene:（CMessageMgr.h:187）只做
//       「本地落库 + 拷进 OpenData」，**不触发上传** → 消息 status 停在 Sending、服务器无该文件
//       记录 → 微信把它当「未下载」（0B +「接收文件」按钮），重启/清理本地缓存后更明显。
//       修复：AddAppMsg 成功后紧接着调 StartUploadAppMsg:MsgWrap:Scene:（CMessageMgr.h:273）
//       触发上传，消息才变「已发送/已上传」。
//    ② 文件转语音闪退（06:21:00，对 localID=23 转语音）：日志到 `[voice.install] 复制结果=1`
//       后就断、无 `已调用 ResendVoiceMsg`，紧接 [ctor] 重启 → 崩溃点在 ResendVoiceMsg。
//       而 ResendVoiceMsg 跑在主线程 block 里，外层 @try 只包住 global block，主线程这段**无保护**。
//       修复：给 dd_media_to_voice / dd_voice_to_file 两处主线程发送 block 补 @try/@catch 兜异常。
//       （补上传后，我方发出的文件消息不再是「未上传」脏状态，对它的转语音崩溃亦应缓解。）
//
//  锚定证据（微信头文件 dump / WCRefine 加载态 dump）：
//   · 文件数据路径 —— CMessageWrap +GetPathOfAppData:msgWrap            (CMessageWrap.h:26)
//                     +GetPathOfAppData:LocalID:FileExt:retStrPath:      (CMessageWrap.h:106)
//                     +GetPathOfAppDataByUserName:andMessageWrap:…       (CMessageWrap.h:108)
//   · 语音文件落地 —— CMessageWrap -getVoicePath                        (CMessageWrap.h:362)
//                     +getPathOfAudio:msgWrap                           (CMessageWrap.h:66)
//                     CUtility +GetPathOfMesAudio:LocalID:DocPath:      (CUtility.h:82)
//   · 菜单图标   —— MMMenuItem -initWithTitle:svgName:target:action: 直接吃内置 svg 名
//                  icon_filled_record_voice.svg（MMMenuItem.h:18，用户确认存在，无兜底）
//                  去重靠 userInfo                                      (MMMenuItem.h:29 / :49)
//   · 视频路径   —— 普通视频 VideoMessageViewModel.videoPath (VideoMessageViewModel.h:24)；
//                  应用视频/视频号 AppVideoMessageViewModel 无路径属性（AppVideoMessageViewModel.h
//                  只有 coverImgUrl/isWSVideo/titleText），路径走 m_extendInfoWithMsgType 通道，
//                  与文件消息同（v1.0.3：原先写的 msgWrap.m_oAppDataItem 在 8.0.79 已不存在）
//   · SILK 编解码 —— MJSilkCodec +encodeToSilkFromPCMData: /
//                    +decodeToPCMFromSilkData: / +decodeToAudioDataFromSilkData:
//                                                            (MJSilkCodec.h:5 / :4 / :3)
//   · 语音路径   —— CUtility GetPathOfMesAudio: / AudioSender getAudioFileName:
//   · 视频下载   —— CMessageMgr -StartDownloadVideo:MsgWrap:Priority:Silent: (CMessageMgr.h:269)
//   · 文件下载   —— CMessageMgr -StartDownloadAppAttach:MsgWrap:Silent:  (CMessageMgr.h:32)
//   · 发文件消息 —— CMessageMgr -AddAppMsg:MsgWrap:DataPath:Scene:       (CMessageMgr.h:187，仅本地落库)
//                   CMessageMgr -StartUploadAppMsg:MsgWrap:Scene:         (CMessageMgr.h:273，触发上传)
//   · 文件 data  —— CExtendInfoOfAPP (m_uiAppMsgInnerType=6 文件 / m_nsAppFileName /
//                    m_nsAppFileExt / m_uiAppDataSize)                 (CExtendInfoOfAPP.h)
//   · 菜单落点   —— 各 cell 的 operationMenuItems + canPerformAction:withSender:
//   · 注册/设置  —— WCPluginsMgr / WCTableViewManager / WCTableViewSectionManager
//   · WCR 参考   —— WCRefine 加载态 dump 中 Video/AppFile/Voice 三个 cell 的
//                   WCRefine_onLongPressMediaToVoice: / WCRefine_onLongPressVoiceToFile:
//                   / WCRefine_sendVoiceFileToCurrentChat: 即为同一思路（本插件独立复刻）

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <Photos/Photos.h>
#import <substrate.h>
#include <string.h>   // memcmp / memcpy（SILK_V3 魔数校验）
#include <limits.h>   // LLONG_MAX（SILK 回环自校验打分）
#include <math.h>     // isfinite（AVAsset 时长可能是 indeterminate 的 NaN）

// CI（Xcode 26 / iOS 26.5 SDK）开了 -Werror，以下两类警告会直接变成 error：
//   · -Wdeprecated-declarations：AVFoundation / UIKit 部分老 API
//   · -Wobjc-multiple-method-names：微信类与系统类同名 selector（已尽量用显式类型转换规避，此处兜底）
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-multiple-method-names"

#pragma mark - 微信类声明（均锚定头文件 dump）

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
- (void)tableView:(id)arg1 didSelectRowAtIndexPath:(id)arg2;   // WCTableViewManager.h:64
@property (nonatomic, weak) id delegate;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)defaultSection;
+ (id)sectionWithHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

// WCTableViewCellManager.h —— 开关 cell (:38) / 普通 cell (:17 :25 :30) / 居中 cell (:4)
@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 on:(_Bool)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightValue:(id)a4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3 rightView:(id)a4;
+ (id)centerCellForSel:(SEL)arg1 target:(id)arg2 title:(id)a3;
@end

// 菜单项：注意它不是 UIMenuItem —— 8.0.79 头文件里 @interface MMMenuItem : NSObject
//   （MMMenuItem.h:1）。v1.0.2 及更早版本把它声明成 UIMenuItem 子类，是个实打实的错：
//   微信拿 operationMenuItems 数组时会按 MMMenuItem 自己的字段
//   （iconImage / menuType / itemViewCreateHandler / userInfo …）去取，
//   按 UIMenuItem 的语义理解它，行为不可预期。这里按真实声明改回 NSObject。
// 另注意两个容易踩空的点：
//   · MMMenuItem **没有** `title` getter、**没有** `action` getter（头文件 51 行里只有 target）
//     → 依赖 `it.action` 做去重在 8.0.79 上是永远不成立的，改用 userInfo 打标记。
//   · 有 `initWithTitle:icon:target:action:`（:15）可以直接吃 UIImage，
//     比猜 svg 资源名可靠得多 → 图标问题从根上解决。
@interface MMMenuItem : NSObject
- (id)initWithTitle:(id)a0 svgName:(id)a1 target:(id)a2 action:(SEL)a3;   // MMMenuItem.h:18
- (id)initWithTitle:(id)a0 icon:(id)a1 target:(id)a2 action:(SEL)a3;      // MMMenuItem.h:15  直接吃 UIImage
- (id)initWithTitle:(id)a0 target:(id)a1 action:(SEL)a2;                  // MMMenuItem.h:19  无图标降级构造器
- (id)iconImage;                                                          // MMMenuItem.h:12  读图标
- (void)setIconImage:(id)a0;                                              // MMMenuItem.h:38  兜底塞图标
- (id)userInfo;                                                           // MMMenuItem.h:29  去重标记位
- (void)setUserInfo:(id)a0;                                               // MMMenuItem.h:49
@end

// CMessageWrap.h（8.0.79）实测行号：m_uiMesLocalID:519 / m_uiMessageType:520 / m_uiCreateTime:512
//   / m_uiStatus:525 / m_nsFromUsr:404 / m_nsToUsr:421 / initWithMsgType::367 / isSenderFromMsgWrap::19
// ⚠ 以下两个字段 8.0.79 **不存在**（全库 46581 个头文件里都没有），已在 v1.0.3 删除：
//   · m_oAppDataItem     —— 老版本字段，8.0.79 已移除；文件/应用消息的数据项改走
//                           m_extendInfoWithMsgType（CMessageWrap.h:382）
//   · m_uiAppMsgInnerType —— 它在 CExtendInfoOfAPP 上（CExtendInfoOfAPP.h:201），不在 CMessageWrap 上
@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) NSString *m_nsFromUsr;
- (id)initWithMsgType:(long long)arg1;
+ (BOOL)isSenderFromMsgWrap:(id)arg1;
// 以下按头文件补齐（Xcode 26 SDK + ARC 下 id 接收者必须有可见声明，否则报 no known method）
+ (id)getPathOfMsgImg:(id)arg1;                     // CMessageWrap.h:72（小写 g，无大写 G 版本）
- (BOOL)IsVideoMsg;                                 // CMessageWrap.h:155
- (BOOL)IsFileMsg;                                  // CMessageWrap.h:128
- (BOOL)IsVoiceMsg;                                 // CMessageWrap.h:156
- (id)m_extendInfoWithMsgType;                      // CMessageWrap.h:382
- (void)setM_extendInfoWithMsgType:(id)arg1;        // CMessageWrap.h:637
- (void)setM_uiMessageType:(unsigned int)arg1;      // CMessageWrap.h:720
- (void)setM_uiCreateTime:(unsigned int)arg1;       // CMessageWrap.h:710
- (void)setM_uiStatus:(unsigned int)arg1;           // CMessageWrap.h:726
- (void)setM_nsToUsr:(NSString *)arg1;              // CMessageWrap.h:695
- (void)setM_nsFromUsr:(NSString *)arg1;            // CMessageWrap.h:678
// 路径接口（v1.0.3 全面按 8.0.79 头文件重校行号；m_oAppDataItem 已废弃见上方说明）
- (id)getVoicePath;                                 // CMessageWrap.h:362  语音文件本地路径（实例方法，无需拼 usr/localID）
+ (id)getPathOfAudio:(id)arg1;                      // CMessageWrap.h:66   语音路径（单参 msgWrap）
+ (id)GetPathOfAppData:(id)arg1;                    // CMessageWrap.h:26   文件/附件数据路径（单参 msgWrap）
+ (void)GetPathOfAppData:(id)a0 LocalID:(unsigned int)lid FileExt:(id)ext retStrPath:(void *)pp;  // :106
+ (void)GetPathOfAppDataByUserName:(id)usr andMessageWrap:(id)wrap retStrPath:(void *)pp;         // :108
+ (void)GetPathOfAppDataByUserName:(id)usr andMessageWrap:(id)wrap andAttachId:(id)aid
                                         andAttachFileExt:(id)aext retStrPath:(void *)pp;         // :107
@end

// 视频/小视频（43/62）本地路径的额外权威源（参考「视频转语音.txt」多源解析，类名以 8.0.79 头文件为准）
@interface WCLanDeviceServiceUtil : NSObject
+ (id)filePathFromMsgWrap:(id)arg1;                    // WCLanDeviceServiceUtil.h:7  —— 视频/文件落点路径
@end

@interface CExtendInfoOfAPP : NSObject   // 文件/app 消息的数据项（CExtendInfoOfAPP.h）
@property(nonatomic) unsigned int m_uiAppMsgInnerType;   // 6 = 文件
@property(retain, nonatomic) NSString *m_nsAppFileName;
@property(retain, nonatomic) NSString *m_nsAppFileExt;
@property(nonatomic) unsigned long long m_uiAppDataSize;
@property(retain, nonatomic) NSString *m_nsAppMediaUrl;
@property(retain, nonatomic) NSString *m_nsAppAttachID;
- (id)init;
- (id)getFileExt;                                   // CExtendInfoOfAPP.h:44
@end

// 语音消息的扩展信息（CExtendInfoOfVoiceMsg.h）
@interface CExtendInfoOfVoiceMsg : NSObject
- (id)m_dtVoice;                                    // :12
- (id)m_refMessageWrap;                             // :13
- (unsigned int)m_uiVoiceEndFlag;                   // :17
- (unsigned int)m_uiVoiceFormat;                    // :18
- (unsigned int)m_uiVoiceTime;                      // :20
- (void)setM_dtVoice:(id)arg1;                      // :27
- (void)setM_refMessageWrap:(id)arg1;               // :28
- (void)setM_uiVoiceEndFlag:(unsigned int)arg1;     // :30
- (void)setM_uiVoiceFormat:(unsigned int)arg1;      // :31
- (void)setM_uiVoiceTime:(unsigned int)arg1;        // :33
@end

@interface CBaseContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CUtility : NSObject
+ (id)GetDocPath;
+ (id)GetPathOfMesAudio:(id)arg1 LocalID:(unsigned int)arg2 DocPath:(id)arg3;
@end

@interface MMContext : NSObject
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface AudioSender : NSObject
- (void)ResendVoiceMsg:(id)arg1 MsgWrap:(id)arg2;   // AudioSender.h:62
- (_Bool)addMessageToDB:(id)arg1;                   // AudioSender.h:13（只有 AudioSender 有）
- (id)getAudioFileName:(id)arg1 LocalID:(unsigned int)arg2;   // AudioSender.h:35
@end

@interface CMessageMgr : NSObject
- (void)StartDownloadVideo:(id)a0 MsgWrap:(id)a1 Priority:(BOOL)a2 Silent:(BOOL)a3;   // CMessageMgr.h:269
- (BOOL)StartDownloadAppAttach:(id)a0 MsgWrap:(id)a1 Silent:(BOOL)a2;                  // CMessageMgr.h:32
- (BOOL)IsVideoMsgdDownloadIng:(id)a0;                                                // CMessageMgr.h:24
- (void)AddAppMsg:(id)a0 MsgWrap:(id)a1 DataPath:(id)a2 Scene:(unsigned int)a3;       // CMessageMgr.h:187
- (void)StartUploadAppMsg:(id)a0 MsgWrap:(id)a1 Scene:(unsigned int)a2;               // CMessageMgr.h:273（触发上传）
- (void)AddLocalMsg:(id)a0 MsgWrap:(id)a1;                                            // CMessageMgr.h:191
- (void)AddMsg:(id)a0 MsgWrap:(id)a1;                                                 // CMessageMgr.h:194
// ⚠ addMessageToDB: 只有 AudioSender 有（AudioSender.h:13），CMessageMgr 没有 ——
//   v1.0.2 把它误写在 CMessageMgr 上，调用点 respondsToSelector 永远为 NO → 兜底发送静默失败。
//   v1.0.3 改为上面真实存在的 AddLocalMsg: / AddMsg:。
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface SettingUtil : NSObject
+ (id)getCurUsrName;
@end

@interface BaseMsgContentViewController : UIViewController
- (id)getCurrentChatName;
@end

// SILK 编解码（微信自带，无需内嵌 FFmpeg；锚定 MJSilkCodec.h:1-15）
@interface MJSilkCodec : NSObject
+ (id)decodeToAudioDataFromSilkData:(id)a0;   // MJSilkCodec.h:3  SILK → 音频数据
+ (id)decodeToPCMFromSilkData:(id)a0;         // MJSilkCodec.h:4  SILK → PCM
+ (id)encodeToSilkFromPCMData:(id)a0;         // MJSilkCodec.h:5  PCM → SILK
// v1.0.2 更正：之前怀疑类方法 encodeToSilkFromPCMData: 用了“未知内部默认采样率”，
// 于是把实例 API 提到主路径 —— 这个判断是错的。
// 反汇编 WCRefine sub_0x8f2804 看清了它的真实取舍：
//   0x8f2890 先取 SEL 'encodeToSilkFromPCMData:'，
//   0x8f28b0 再问 'respondsToSelector:'，只有为 0 才 tbz 跳到 0x8f2a54 的实例 API 兜底。
// 也就是说 **类方法才是 WCR 的主路径**，实例侧只是保险丝。
// 真正的病根是两个别的：① PCM 采样率写成了 8000（WCR 是 16000）；
// ② 编码器产物少了容器头第一个字节 0x02（见下方 SILK 段落的取证说明）。
- (BOOL)initEncoderWithSampleRate:(long long)rate;  // MJSilkCodec.h:7
- (id)encodeFromPCMData:(id)a0;                     // MJSilkCodec.h:10
- (BOOL)uninitEncoder;                              // MJSilkCodec.h:8
- (void)setSampleRate:(long long)rate;              // MJSilkCodec.h:14
- (long long)sampleRate;                            // MJSilkCodec.h:11
@end

// viewModel 层级（cell.viewModel 返回 id，ARC 下需有可见声明才能直接调 selector）
@interface BaseMessageViewModel : NSObject
- (id)messageWrap;                                  // BaseMessageViewModel.h:49
@end
@interface VideoMessageViewModel : BaseMessageViewModel
- (id)videoPath;                                    // VideoMessageViewModel.h:24
@end
@interface AppVideoMessageViewModel : BaseMessageViewModel
- (BOOL)isWSVideo;                                  // AppVideoMessageViewModel.h:5
@end

// ⚠ 8.0.79 里 `viewModel` **不在 BaseMessageCellView 上**（该头文件 1000+ 行里一个 viewModel 都没有），
//   真实位置是 BaseChatCellView.h:17。运行时 cell 是从 BaseChatCellView 继承来的，
//   所以 [cell viewModel] 能跑通 —— 这里把它挂到 BaseMessageCellView 上只是为了 hook 内
//   能静态调用（self.viewModel），不是在宣称头文件里有这条。
@interface BaseChatCellView : NSObject
@property (readonly, nonatomic) id viewModel;       // BaseChatCellView.h:17（真实锚点）
@end

@interface BaseMessageCellView : BaseChatCellView
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;   // BaseMessageCellView.h:11（在基类上）
@end

// cell 层级：BaseMessageCellView 须先于子类声明
@interface VideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // VideoMessageCellView.h:12
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface AppVideoMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // AppVideoMessageCellView.h:7
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface AppFileMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // AppFileMessageCellView.h:17
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;
@end

@interface VoiceMessageCellView : BaseMessageCellView
- (id)operationMenuItems;                          // VoiceMessageCellView.h:34
- (BOOL)canPerformAction:(SEL)arg1 withSender:(id)arg2;   // VoiceMessageCellView.h:6
@end

// 8.0.79 另外发现 VoiceMessageViewModel.voiceTimeLength（VoiceMessageViewModel.h:36）能直接拿到
//   微信自己认为的语音秒数；本版没用（dd_voice_to_file 手上只有 msg 拿不到 cell.viewModel），
//   留作下一次若要交叉校验「m4a 时长 vs 语音秒数」时的现成入口。
// AppFileMessageViewModel 上的 isFileExist 已用起来（见 dd_file_ready_of_cell）。
@interface AppFileMessageViewModel : NSObject
- (BOOL)isFileExist;                               // AppFileMessageViewModel.h:9  文件是否已落地
- (BOOL)contentExists;                             // AppFileMessageViewModel.h:6
@end

#pragma mark - 配置（三个开关 + 发送模式）

#define kDDMCVideoToVoice @"kDDMCVideoToVoice"
#define kDDMCFileToVoice @"kDDMCFileToVoice"
#define kDDMCVoiceToFile @"kDDMCVoiceToFile"
#define kDDMCLogEnabled   @"kDDMCLogEnabled"

#define kDDMCVoiceMsgType 34          // 语音消息 m_uiMessageType (0x22)
#define kDDMCAppMsgType  49          // app/文件消息 m_uiMessageType (0x31)
#define kDDMVideoMsgType  43          // 视频消息 m_uiMessageType (0x2B)
#define kDDMShortVideoMsgType 62      // 小视频 m_uiMessageType (0x3E)
// 视频消息共三类（用户约束仅识别这 3 种）：
//   · 普通视频(43) + 小视频(62) → VideoMessageCellView（dd_video_path_of_cell 经 IsVideoMsg 校验）
//   · 视频号：AppVideoMessageCellView，AppVideoMessageViewModel.isWSVideo 为真（m_uiMessageType=49）
#define kDDMCAppInnerFile 6          // 文件 innerType
#define kDDMCVoiceFormat 4            // SILK
#define kDDMCVoiceEndFlag 1
#define kDDMCStatusSending 1
#define kDDMCVoiceSampleRate 16000    // 微信语音 PCM：16kHz / 单声道 / 16bit / 小端整型
                                      // ← 实测反汇编 WCRefine.dylib 取证，不是猜的：
                                      //   WCRefineVoiceDataFromMediaPath (0x8de548) → sub_0x8f1bc8(pcm 抽取)
                                      //   在 0x8f1f68 用 [NSNumber numberWithUnsignedInt:16000]，
                                      //   0x8f1fb4 用 numberWithUnsignedShort:1（单声道），
                                      //   0x8f2000 用 numberWithUnsignedShort:16（位深），
                                      //   7 个键一起交给 NSDictionary dictionaryWithObjects:forKeys:count:7 (0x8f2134)。
                                      //   v1.0.0/v1.0.1 这里写的 8000 —— 与 WCR 实测不符，是「转语音没声音」的主因之一。
#define kDDMCDownloadTimeout 90.0    // 自动下载等待上限（秒）

@interface DDMediaConvertConfig : NSObject
+ (instancetype)shared;
@property (assign, nonatomic) BOOL videoToVoiceEnabled;
@property (assign, nonatomic) BOOL fileToVoiceEnabled;
@property (assign, nonatomic) BOOL voiceToFileEnabled;
@property (assign, nonatomic) BOOL logEnabled;
@end

@implementation DDMediaConvertConfig
+ (instancetype)shared {
    static DDMediaConvertConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDMediaConvertConfig new]; });
    return c;
}
+ (void)initialize {
    if (self != [DDMediaConvertConfig class]) return;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        kDDMCVideoToVoice: @NO,
        kDDMCFileToVoice: @NO,
        kDDMCVoiceToFile: @NO,
        kDDMCLogEnabled: @YES,
    }];
}
- (instancetype)init {
    if (self = [super init]) {
        _videoToVoiceEnabled = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVideoToVoice];
        _fileToVoiceEnabled   = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCFileToVoice];
        _voiceToFileEnabled  = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCVoiceToFile];
        _logEnabled           = [NSUserDefaults.standardUserDefaults boolForKey:kDDMCLogEnabled];
    }
    return self;
}
- (void)setVideoToVoiceEnabled:(BOOL)v { _videoToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVideoToVoice]; }
- (void)setFileToVoiceEnabled:(BOOL)v { _fileToVoiceEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCFileToVoice]; }
- (void)setVoiceToFileEnabled:(BOOL)v { _voiceToFileEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCVoiceToFile]; }
- (void)setLogEnabled:(BOOL)v { _logEnabled = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kDDMCLogEnabled]; }
@end

#pragma mark - 调试日志（设置页导出 / 清空）

#define kDDLogMaxLines   3000                      // 内存缓冲上限，超出丢最早的 1/4
#define kDDLogDirName    @"DDVoiceAssistantLogs"
#define kDDLogFileName   @"ddvoice_debug.log"
#define kDDPluginName    @"DD语音助手"
#define kDDPluginVersion @"1.0.11"

@interface DDLogStore : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy)   NSString *logDir;
@property (nonatomic, copy)   NSString *logPath;
@property (nonatomic, strong) NSMutableArray<NSString *> *lines;
- (void)append:(NSString *)line;
- (void)flushSync;
- (void)clearAll;
- (NSUInteger)lineCount;
- (unsigned long long)fileSize;
@end

@implementation DDLogStore {
    NSFileHandle *_handle;
    dispatch_queue_t _q;
}
+ (instancetype)shared {
    static DDLogStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [DDLogStore new]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) {
        _q = dispatch_queue_create("com.ddvoice.log", DISPATCH_QUEUE_SERIAL);
        _lines = [NSMutableArray array];
        _enabled = YES;
        NSArray<NSString *> *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *doc = dirs.firstObject.length ? dirs.firstObject : NSTemporaryDirectory();
        _logDir  = [doc stringByAppendingPathComponent:kDDLogDirName];
        _logPath = [_logDir stringByAppendingPathComponent:kDDLogFileName];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:_logDir withIntermediateDirectories:YES attributes:nil error:nil];
        if (![fm fileExistsAtPath:_logPath]) [fm createFileAtPath:_logPath contents:nil attributes:nil];
        _handle = [NSFileHandle fileHandleForWritingAtPath:_logPath];
        @try { [_handle seekToEndOfFile]; } @catch (...) { _handle = nil; }
    }
    return self;
}
- (void)append:(NSString *)line {
    if (!line.length) return;
    // 同步落盘：原实现 dispatch_async 异步写、且 writeData 后从不 synchronizeFile（fsync），
    // 进程在转换流程中崩溃时队列里未执行的 block 与未刷盘的页缓存一起丢失 → 「闪退后日志被清空」。
    // 改为同步写 + 每条 fsync，确保崩溃前的每条日志都已落盘可查（init 不会清空已有日志文件）。
    dispatch_sync(_q, ^{
        if (self->_lines.count >= kDDLogMaxLines)
            [self->_lines removeObjectsInRange:NSMakeRange(0, kDDLogMaxLines / 4)];
        [self->_lines addObject:line];
        NSData *d = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
        @try {
            if (!self->_handle) self->_handle = [NSFileHandle fileHandleForWritingAtPath:self->_logPath];
            [self->_handle seekToEndOfFile];
            [self->_handle writeData:d];
            [self->_handle synchronizeFile];   // fsync：崩溃也不丢
        } @catch (...) {}
        NSLog(@"[%@] %@", kDDPluginName, line);
    });
}
- (void)flushSync { dispatch_sync(_q, ^{ @try { [_handle synchronizeFile]; } @catch (...) {} }); }
- (NSUInteger)lineCount { __block NSUInteger n = 0; dispatch_sync(_q, ^{ n = _lines.count; }); return n; }
- (unsigned long long)fileSize {
    __block unsigned long long sz = 0;
    dispatch_sync(_q, ^{
        sz = [[[NSFileManager defaultManager] attributesOfItemAtPath:_logPath error:nil][NSFileSize] unsignedLongLongValue];
    });
    return sz;
}
- (void)clearAll {
    dispatch_sync(_q, ^{
        [_lines removeAllObjects];
        @try { [_handle closeFile]; } @catch (...) {}
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:_logPath error:nil];
        [fm createFileAtPath:_logPath contents:nil attributes:nil];
        _handle = [NSFileHandle fileHandleForWritingAtPath:_logPath];
        @try { [_handle seekToEndOfFile]; } @catch (...) {}
    });
}
@end

static NSString *dd_log_stamp(void) {
    static NSDateFormatter *df = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ df = [NSDateFormatter new]; df.dateFormat = @"MM-dd HH:mm:ss.SSS"; });
    return [df stringFromDate:[NSDate date]];
}
static void dd_log(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void dd_log(NSString *fmt, ...) {
    DDLogStore *s = [DDLogStore shared];
    if (!s.enabled) return;
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [s append:[NSString stringWithFormat:@"%@ %@", dd_log_stamp(), msg]];
}

// 导出：flush → 拼头部信息 → 另存为带时间戳的 txt，返回路径
static NSString *dd_log_export_path(void) {
    DDLogStore *s = [DDLogStore shared];
    [s flushSync];
    NSData *d = [NSData dataWithContentsOfFile:s.logPath];
    NSString *body = [[NSString alloc] initWithData:(d ?: [NSData data]) encoding:NSUTF8StringEncoding];
    if (!body.length) body = @"（暂无日志，可能未触发任何转换流程或日志已清空）\n";
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *wxVer   = info[@"CFBundleShortVersionString"] ?: @"-";
    NSString *wxBuild = info[@"CFBundleVersion"] ?: @"-";
    static NSDateFormatter *fdf = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ fdf = [NSDateFormatter new]; fdf.dateFormat = @"yyyyMMdd_HHmmss"; });
    NSString *stamp = [fdf stringFromDate:[NSDate date]];
    NSString *text = [NSString stringWithFormat:
        @"%@ %@ 调试日志\n"
        @"设备: %@  系统: %@\n微信: %@ (%@)\n导出时间: %@\n日志条数: %lu  文件大小: %llu 字节\n"
        @"----------------------------------------\n%@",
        kDDPluginName, kDDPluginVersion,
        [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion,
        wxVer, wxBuild, [NSDate date],
        (unsigned long)[s lineCount], [s fileSize], body];
    NSString *dst = [s.logDir stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@_日志_%@.txt", kDDPluginName, stamp]];
    [[text dataUsingEncoding:NSUTF8StringEncoding] writeToFile:dst atomically:YES];
    dd_log(@"导出日志 → %@", dst);
    return dst;
}

#pragma mark - 通用工具

static BOOL dd_file_exists(NSString *path) {
    return path.length && [[NSFileManager defaultManager] fileExistsAtPath:path];
}
static NSString *dd_current_usr_name(void) { return [objc_getClass("SettingUtil") getCurUsrName]; }
static id dd_mm_service(NSString *name) {
    MMContext *ctx = (MMContext *)[objc_getClass("MMContext") currentContext];
    return [ctx getService:objc_getClass([name UTF8String])];
}
// 当前聊天对象（消息所属会话；WCR 用 sendToCurrentChat 同理取消息所在会话）
static NSString *dd_chat_usr_of_msg(CMessageWrap *msg) {
    Class wrapCls = objc_getClass("CMessageWrap");
    BOOL isSender = [wrapCls isSenderFromMsgWrap:msg];
    return isSender ? msg.m_nsToUsr : msg.m_nsFromUsr;
}

#pragma mark - 自动下载（未下载的视频/文件先下载再转）

// 取 cell 对应消息
static CMessageWrap *dd_msg_of_cell(id cell) {
    id vm = [cell viewModel];
    if ([vm respondsToSelector:@selector(messageWrap)]) {
        CMessageWrap *m = [vm messageWrap];
        dd_log(@"[msg] cell=%@ vm=%@ → msg type=%u localID=%u",
              NSStringFromClass([cell class]), NSStringFromClass([vm class]),
              m ? m.m_uiMessageType : 0, m ? m.m_uiMesLocalID : 0);
        return m;
    }
    dd_log(@"[msg] cell=%@ vm=%@ 无 messageWrap", NSStringFromClass([cell class]), NSStringFromClass([vm class]));
    return nil;
}

// 普通视频本地路径（VideoMessageCellView，承载 m_uiMessageType=43 视频 与 62 小视频，二者共用此类）
// 证据：VideoMessageViewModel.videoPath（VideoMessageViewModel.h:24）；
// 类型守卫 dd_is_msg_wrap 定义在文件靠后（约第 745 行），这里提前调用，故先前向声明
static BOOL dd_is_msg_wrap(id obj);
//       CMessageWrap IsVideoMsg/IsPureVideoMsg（CMessageWrap.h:155/144）；
//       CMessageMgr AddVideoMsg:43 / AddShortVideoMsg:62（CMessageMgr.h:63-64）
// v1.0.6：参考「视频转语音.txt」的多源解析思路（该文件仅供参考，类名以 8.0.79 头文件为准）重写为
//         目录感知 + 多源。关键启发：解析出的路径**可能是目录**，要在里面找第一个
//         .mp4/.mov/.m4v（参考 WCLiteFirstVideoFileUnderPath）；同时补上参考里的另外两条权威源
//         WCLanDeviceServiceUtil.filePathFromMsgWrap:（WCLanDeviceServiceUtil.h:7）与
//         CUtility.GetDocPath（CUtility.h:49）兜底，覆盖 videoPath 在某些视频号/未下载场景取不到的情况。

// 视频扩展名白名单（参考 WCLiteVideoToVoiceAllowedExtensions：mp4/mov/m4v）
static NSSet *dd_video_ext_set(void) {
    static NSSet *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [NSSet setWithObjects:@"mp4", @"mov", @"m4v", nil]; });
    return s;
}
// 目录感知：path 是带白名单后缀的文件 → 原样返回；是目录 → 扫首个白名单文件（非递归，对齐参考文件）
static NSString *dd_first_video_file_under_path(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || path.length == 0) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) return nil;
    if (!isDir) {
        return [dd_video_ext_set() containsObject:path.pathExtension.lowercaseString] ? path : nil;
    }
    NSArray *ents = [fm contentsOfDirectoryAtPath:path error:nil];
    for (NSString *name in ents) {
        if (![dd_video_ext_set() containsObject:name.pathExtension.lowercaseString]) continue;
        NSString *sub = [path stringByAppendingPathComponent:name];
        BOOL subDir = NO;
        if ([fm fileExistsAtPath:sub isDirectory:&subDir] && !subDir) return sub;
    }
    return nil;
}

static NSString *dd_video_path_of_cell(id cell) {
    id msg = dd_msg_of_cell(cell);
    // 视频消息含 43（视频）与 62（小视频），IsVideoMsg 对两者均返回 YES，做一道显式类型识别
    if (msg && [msg respondsToSelector:@selector(IsVideoMsg)] && ![msg IsVideoMsg]) {
        dd_log(@"[path.video] type=%u 非视频消息，跳过", msg ? ((CMessageWrap *)msg).m_uiMessageType : 0);
        return nil;
    }
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    // ① VideoMessageViewModel.videoPath（VideoMessageViewModel.h:24）—— 已下载视频最直接
    id vm = [cell respondsToSelector:@selector(viewModel)] ? [(id)cell viewModel] : nil;
    if ([vm respondsToSelector:@selector(videoPath)]) {
        NSString *p = [vm videoPath];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } else {
        dd_log(@"[path.video] vm=%@ 无 videoPath", NSStringFromClass([vm class]));
    }
    // ②~④ 仅当拿到真正的 CMessageWrap 时才打这些权威接口（避免越界，沿用 dd_is_msg_wrap 守卫）
    if (dd_is_msg_wrap(msg)) {
        // ② WCLanDeviceServiceUtil.filePathFromMsgWrap:（WCLanDeviceServiceUtil.h:7）
        Class lan = objc_getClass("WCLanDeviceServiceUtil");
        if (lan && [lan respondsToSelector:@selector(filePathFromMsgWrap:)]) {
            @try { id p = [lan filePathFromMsgWrap:msg];
                   if ([p isKindOfClass:[NSString class]] && ((NSString *)p).length) [cands addObject:p]; }
            @catch (NSException *e) { dd_log(@"[path.video] WCLanDeviceServiceUtil 异常 %@", e.reason); }
        }
        // ③ CMessageWrap +GetPathOfAppData:（CMessageWrap.h:26）
        Class wc = objc_getClass("CMessageWrap");
        if (wc && [wc respondsToSelector:@selector(GetPathOfAppData:)]) {
            @try { id p = [wc GetPathOfAppData:msg];
                   if ([p isKindOfClass:[NSString class]] && ((NSString *)p).length) [cands addObject:p]; }
            @catch (NSException *e) { dd_log(@"[path.video] GetPathOfAppData: 异常 %@", e.reason); }
        }
        // ④ CUtility +GetDocPath（CUtility.h:49）兜底扫文档目录
        Class cu = objc_getClass("CUtility");
        if (cu && [cu respondsToSelector:@selector(GetDocPath)]) {
            @try { id p = [cu GetDocPath];
                   if ([p isKindOfClass:[NSString class]] && ((NSString *)p).length) [cands addObject:p]; }
            @catch (NSException *e) { dd_log(@"[path.video] GetDocPath 异常 %@", e.reason); }
        }
    }
    // 目录感知查找：命中即返回
    NSUInteger idx = 0;
    for (NSString *p in cands) {
        NSString *f = dd_first_video_file_under_path(p);
        if (f.length) {
            dd_log(@"[path.video] 源#%lu 命中视频文件 → %@ (ext=%@)", (unsigned long)idx, f, f.pathExtension);
            return f;
        }
        idx++;
    }
    if (cands.count) {
        dd_log(@"[path.video] 无视频文件命中，返回候选#0 供下载轮询: %@", cands.firstObject);
        return cands.firstObject;   // 可能只是目录；dd_media_to_voice 触发下载后会再解析出文件
    }
    dd_log(@"[path.video] 完全取不到视频路径");
    return nil;
}

// 8.0.79 新见：AppFileMessageViewModel.isFileExist（AppFileMessageViewModel.h:9）
//   —— 直接问 viewModel「这文件到底落地了没」，比拿一条摸索出来的路径去 stat 更早知道答案。
//   NO = 确实没下载，后面那套下载触发 + 轮询才有意义；不确定时按「有」处理，让路径探测自己说话。
// 返回值只用于日志与提前判空，不改变既有行为。
static BOOL dd_file_ready_of_cell(id cell) {
    id vm = nil;
    @try { vm = [cell respondsToSelector:@selector(viewModel)] ? [(id)cell viewModel] : nil; } @catch (...) {}
    if (!vm) return YES;
    @try {
        if ([vm respondsToSelector:@selector(isFileExist)]) {
            BOOL ex = [(id)vm isFileExist];
            dd_log(@"[file.ready] vm=%@ isFileExist=%d", NSStringFromClass([vm class]), ex);
            return ex;
        }
    } @catch (NSException *e) { dd_log(@"[file.ready] isFileExist 异常 %@", e.reason); }
    return YES;
}

// 应用视频 / 视频号视频本地路径（AppVideoMessageCellView，m_uiMessageType=49 的 app 视频）
// 前向声明：下面会复用 dd_file_path_of_msg 的权威路径通道（两者定义在文件靠后处）
static id dd_app_item_of_msg(CMessageWrap *msg);
static NSString *dd_file_path_of_msg(CMessageWrap *msg);
// 证据：AppVideoMessageViewModel 无自己的视频路径属性（AppVideoMessageViewModel.h 仅
//       coverImgUrl/isWSVideo/titleText 等），视频文件落在消息数据项里，与文件消息同通道。
static NSString *dd_appvideo_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    // v1.0.1：与文件消息同通道，先走 CMessageWrap 权威接口（dd_file_path_of_msg 内部也是这套）
    NSString *authoritative = dd_file_path_of_msg(msg);
    if (authoritative.length) {
        dd_log(@"[path.appvideo] 走 GetPathOfAppData 通道命中 → %@", authoritative);
        return authoritative;
    }
    id appItem = dd_app_item_of_msg(msg);
    if (!appItem) return nil;
    NSArray *keys = @[@"m_nsDataPath", @"videoPath", @"m_nsVideoPath",
                      @"m_nsFilePath", @"dataPath", @"localPath", @"m_nsAppMediaUrl"];
    dd_log(@"[path.appvideo] appItem=%@", NSStringFromClass([appItem class]));
    for (NSString *k in keys) {
        @try {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && dd_file_exists(v)) {
                dd_log(@"[path.appvideo] 命中 key=%@ → %@", k, v);
                return v;
            }
        } @catch (...) {}
    }
    dd_log(@"[path.appvideo] 未命中任何路径键（可能需要真机校键名 / 视频未下载）");
    return nil;
}

// 文件消息的 m_oAppDataItem（可能 nil —— “识别失败”的文件就是这种）
// 类型守卫：dd_msg_of_cell 走的是通用的 [viewModel messageWrap]，不同 cell 的 vm
// 交出来的不一定是 CMessageWrap。把它原样塞进 CMessageWrap 的类方法（GetPathOfAppData: 等）
// 会直接在微信内部越界 → SIGSEGV。凡是要调 wrap 专属接口的地方，先过这一关。
static BOOL dd_is_msg_wrap(id obj) {
    if (!obj) return NO;
    if ([obj isKindOfClass:objc_getClass("CMessageWrap")]) return YES;
    // 没有类型信息时退而求其次：至少要有 CMessageWrap 的标志性字段
    return [obj respondsToSelector:@selector(m_uiMesLocalID)] &&
           [obj respondsToSelector:@selector(m_uiMessageType)];
}

// v1.0.3 重写：8.0.79 全库 46581 个头文件里**已经没有 m_oAppDataItem**（老版本字段，已移除），
// 所以它不是一个「偶尔为 nil」的通道，而是彻底不通 —— 这正是「文件识别失败」的消息
// 取不到扩展名、进而在菜单里连按钮都出不来的根因之一。
// 8.0.79 上文件/app 消息的数据项走 CMessageWrap.h:382 的 m_extendInfoWithMsgType，
// 返回的就是 CExtendInfoOfAPP（CExtendInfoOfAPP.h:201 起有 m_uiAppMsgInnerType /
// m_nsAppFileExt / m_uiAppDataSize / m_nsAppMediaUrl / m_nsAppAttachID）。
static id dd_app_item_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    if (!dd_is_msg_wrap(msg)) {
        dd_log(@"[ext.file] msg 不是 CMessageWrap(%@)，不碰它的字段", NSStringFromClass([msg class]));
        return nil;
    }
    id appItem = nil;
    // 1) 权威：m_extendInfoWithMsgType（CMessageWrap.h:382）
    @try {
        if ([msg respondsToSelector:@selector(m_extendInfoWithMsgType)])
            appItem = [msg m_extendInfoWithMsgType];
    } @catch (NSException *e) { dd_log(@"[ext.file] m_extendInfoWithMsgType 异常 %@", e.reason); appItem = nil; }
    if (appItem) {
        dd_log(@"[ext.file] 命中 m_extendInfoWithMsgType → %@", NSStringFromClass([appItem class]));
        return appItem;
    }
    // 2) 旧版本字段的 KVC 兜底（为兼容更老的微信；8.0.79 上这条路会抛 undefinedKey，被吞）
    @try { appItem = [msg valueForKey:@"m_oAppDataItem"]; } @catch (...) { appItem = nil; }
    if (!appItem) dd_log(@"[ext.file] 取不到数据项（m_extendInfoWithMsgType 与 KVC 兜底都失败）");
    return appItem;
}
// 扩展名字段全空的兜底路径（只走权威接口，避免与 dd_file_path_of_msg 互相递归打日志）
static NSString *dd_file_path_quick(CMessageWrap *msg) {
    if (!dd_is_msg_wrap(msg)) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    @try {
        NSString *p = (NSString *)[wrapCls GetPathOfAppData:msg];
        if ([p isKindOfClass:[NSString class]] && dd_file_exists(p)) return p;
    } @catch (...) {}
    return nil;
}
// 按 ZDY 逆向实证的取扩展名骨架改：多 key KVC 兜底 + `pathExtension` 补 + 强制小写
// （见 ZDY_文件类型识别逆向分析.md §1；大写扩展名如 .MP3 会被白名单漏判）
static NSString *dd_file_ext_of_msg(CMessageWrap *msg) {
    id appItem = dd_app_item_of_msg(msg);
    NSArray<NSString *> *keys = @[@"m_nsAppFileExt", @"m_nsFileExt", @"m_fileExt", @"fileExt", @"fileext",
                                  @"m_nsAttachFileExt", @"m_nsDownloadFileExt", @"m_nsAppFileName"];
    NSString *ext = nil;
    for (NSString *k in keys) {
        @try {
            id v = [appItem valueForKey:k];
            if (![v isKindOfClass:[NSString class]] || ((NSString *)v).length == 0) continue;
            NSString *raw = (NSString *)v;
            NSString *e = raw.pathExtension.length ? raw.pathExtension : raw;   // "song.mp3" 或 "mp3" 都吃
            if (e.length) { ext = e; break; }
        } @catch (...) {}
    }
    if (!ext.length) {   // 扩展名字段全空 → 从真实文件路径补（ZDY/锤子都这么做）
        NSString *p = dd_file_path_quick(msg);
        if (p.length) ext = p.pathExtension;
    }
    ext = ext.lowercaseString;
    unsigned int innerType = ([appItem respondsToSelector:@selector(m_uiAppMsgInnerType)])
        ? [(CExtendInfoOfAPP *)appItem m_uiAppMsgInnerType] : 0;
    dd_log(@"[ext.file] appItem=%@ ext=%@ innerType=%u",
          appItem ? NSStringFromClass([appItem class]) : @"(nil)", ext ?: @"(nil)", innerType);
    return ext;
}
// 仅 mp3 / m4a / wav / aac / amr / flac / caf 参与“文件转语音”（比原来只认 mp3/m4a 更实用）
static BOOL dd_file_is_audio(CMessageWrap *msg) {
    NSString *ext = dd_file_ext_of_msg(msg);
    static NSSet *audioExts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        audioExts = [NSSet setWithObjects:@"mp3", @"m4a", @"wav", @"aac", @"amr", @"flac", @"caf", @"aiff", nil];
    });
    BOOL ok = ext.length && [audioExts containsObject:ext];
    dd_log(@"[ext.file] 是否音频文件=%d (ext=%@)", ok, ext ?: @"(nil)");
    return ok;
}

// 文件消息本地路径（v1.0.3 按 8.0.79 头文件重排候选：
//   m_oAppDataItem 这个字段在 8.0.79 已彻底不存在，数据项改由 m_extendInfoWithMsgType 提供；
//   「识别失败」的文件过去取不到路径 → 转语音必然失败，现在多了一条不依赖内部字段的五参通道）
static NSString *dd_file_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    // v1.0.2：先过类型守卫。dd_msg_of_cell 对某些 cell 交回来的不是 CMessageWrap，
    // 直接丢给 GetPathOfAppData: 会在微信内部越界崩 —— 「长按文件直接闪退」的真凶之一。
    if (!dd_is_msg_wrap(msg)) {
        dd_log(@"[path.file] msg 类型非 CMessageWrap(%@)，拒绝调用 CMessageWrap 类方法",
              NSStringFromClass([msg class]));
        return nil;
    }
    Class wrapCls = objc_getClass("CMessageWrap");
    NSMutableArray<NSString *> *cands = [NSMutableArray array];

    // 1) +GetPathOfAppData:msgWrap —— CMessageWrap.h:26（单参，权威）
    @try {
        NSString *p = (NSString *)[wrapCls GetPathOfAppData:msg];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[path.file] GetPathOfAppData: 异常 %@", e.reason); }

    // 2) +GetPathOfAppDataByUserName:andMessageWrap:retStrPath: —— CMessageWrap.h:108
    @try {
        NSString *p = nil;
        [wrapCls GetPathOfAppDataByUserName:dd_current_usr_name() andMessageWrap:msg retStrPath:&p];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[path.file] GetPathOfAppDataByUserName: 异常 %@", e.reason); }

    // 3) m_extendInfoWithMsgType 出来的数据项里的路径键（v1.0.3：数据源从 m_oAppDataItem 换成它）
    id appItem = dd_app_item_of_msg(msg);
    NSArray<NSString *> *extKeys = @[@"m_nsAppMediaUrl", @"m_nsFilePath", @"m_nsDataPath",
                                     @"filePath", @"dataPath", @"localPath"];
    for (NSString *k in extKeys) {
        @try {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length) [cands addObject:v];
        } @catch (...) {}
    }

    // 4) v1.0.3 新增：五参版 GetPathOfAppDataByUserName:andMessageWrap:andAttachId:andAttachFileExt:retStrPath:
    //    （CMessageWrap.h:107）。它不依赖 msgWrap 内部的扩展名字段，由调用方显式传入 attachId + fileExt，
    //    对那些「文件识别失败」（内部字段残缺）的消息反而更稳。ext 从 m_nsAppFileExt 取，取不到就传 @""
    //    —— 经验值：这条路在字段残缺时是唯一还能出路径的通道。
    @try {
        NSString *ext = nil;
        for (NSString *k in @[@"m_nsAppFileExt", @"m_nsFileExt", @"fileExt"]) {
            id v = [appItem valueForKey:k];
            if ([v isKindOfClass:[NSString class]] && ((NSString *)v).length) { ext = v; break; }
        }
        id attachId = nil;
        @try { attachId = [appItem valueForKey:@"m_nsAppAttachID"]; } @catch (...) {}
        NSString *p = nil;
        [wrapCls GetPathOfAppDataByUserName:dd_current_usr_name()
                            andMessageWrap:msg
                              andAttachId:[attachId isKindOfClass:[NSString class]] ? attachId : @""
                         andAttachFileExt:ext ?: @""
                              retStrPath:&p];
        if ([p isKindOfClass:[NSString class]] && p.length) {
            dd_log(@"[path.file] 五参 GetPathOfAppData 命中 → %@", p);
            [cands addObject:p];
        }
    } @catch (NSException *e) { dd_log(@"[path.file] 五参 GetPathOfAppData 异常 %@", e.reason); }
    dd_log(@"[path.file] appItem=%@ 候选路径=%lu 条",
          appItem ? NSStringFromClass([appItem class]) : @"(nil)", (unsigned long)cands.count);
    NSUInteger idx = 0;
    for (NSString *p in cands) {
        if (dd_file_exists(p)) {
            dd_log(@"[path.file] 命中候选#%lu → %@ (ext=%@)", (unsigned long)idx, p, p.pathExtension);
            return p;
        }
        idx++;
    }
    if (cands.count) {   // 还没下载完也要把路径交出去，好让上层触发下载并轮询
        dd_log(@"[path.file] 无命中，返回候选#0 供下载轮询: %@", cands.firstObject);
        return cands.firstObject;
    }
    dd_log(@"[path.file] 完全取不到文件路径（appItem 与 GetPathOfAppData 均失败）");
    return nil;
}

// 触发视频下载（微信 CMessageMgr.StartDownloadVideo:MsgWrap:Priority:Silent:）
static void dd_trigger_video_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(StartDownloadVideo:MsgWrap:Priority:Silent:)]) {
        [mgr StartDownloadVideo:nil MsgWrap:msg Priority:YES Silent:YES];
        dd_log(@"[download.video] 已触发 StartDownloadVideo (localID=%u)", msg.m_uiMesLocalID);
    } else {
        dd_log(@"[download.video] CMessageMgr 无 StartDownloadVideo:MsgWrap:Priority:Silent:");
    }
}
// 触发文件/附件下载（CMessageMgr.StartDownloadAppAttach:MsgWrap:Silent:）
static void dd_trigger_file_download(CMessageWrap *msg) {
    if (!msg) return;
    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(StartDownloadAppAttach:MsgWrap:Silent:)]) {
        [mgr StartDownloadAppAttach:nil MsgWrap:msg Silent:YES];
        dd_log(@"[download.file] 已触发 StartDownloadAppAttach (localID=%u)", msg.m_uiMesLocalID);
    } else {
        dd_log(@"[download.file] CMessageMgr 无 StartDownloadAppAttach:MsgWrap:Silent:");
    }
}

// 轮询等待本地文件出现（自动下载是异步的，WCR 用 downloadMgr + completion 回调，此处用路径轮询兜底）
static NSString *dd_wait_local_path(NSString *(^pathBlock)(void), NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSUInteger rounds = 0;
    while ([deadline timeIntervalSinceNow] > 0) {
        NSString *p = pathBlock();
        if (dd_file_exists(p)) {
            dd_log(@"[download.wait] 第 %lu 轮轮询命中 → %@", (unsigned long)rounds, p);
            return p;
        }
        rounds++;
        [NSThread sleepForTimeInterval:0.5];
    }
    dd_log(@"[download.wait] 超时 %.0fs 仍未出现本地文件（共轮询 %lu 轮）", timeout, (unsigned long)rounds);
    return nil;
}

#pragma mark - 转换：媒体 → 语音（抽取音轨 → PCM → SILK → 发送语音消息到当前聊天）

// 语音扩展信息
static id dd_voiceExtendInfo(id wrap, BOOL create) {
    id ext = [wrap m_extendInfoWithMsgType];
    if (ext) return ext;
    if (!create) return nil;
    id nv = [[objc_getClass("CExtendInfoOfVoiceMsg") alloc] init];
    [nv setM_refMessageWrap:wrap];
    [wrap setM_extendInfoWithMsgType:nv];
    return nv;
}
static BOOL dd_configureVoiceMsg(id wrap, NSData *voiceData, unsigned int duration) {
    id ext = dd_voiceExtendInfo(wrap, YES);
    [ext setM_refMessageWrap:wrap];
    [ext setM_uiVoiceFormat:kDDMCVoiceFormat];
    [ext setM_uiVoiceEndFlag:kDDMCVoiceEndFlag];
    [ext setM_uiVoiceTime:duration];
    [ext setM_dtVoice:voiceData];
    return YES;
}
// 把音频数据落到微信语音标准落地路径。
// 优先用权威音频路径接口 CUtility.GetPathOfMesAudio:LocalID:DocPath:（CUtility.h:82），
// 它按 m_uiMesLocalID 直接给出语音文件落点，比字符串替换更稳。
// 兜底：最新头文件里只有 +getPathOfMsgImg:（小写 g，CMessageWrap.h:72，无大写 G 版本），
//       旧代码误用大写 G 的 GetPathOfMsgImg: 选择器（不存在）会触发 doesNotRecognizeSelector 崩溃，
//       此处改用小写并在 GetPathOfMesAudio 不可用时才走字符串换算。
static NSString *dd_install_audio_file(CMessageWrap *wrap, NSString *src) {
    dd_log(@"[voice.install] src=%@ 存在=%d localID=%u", src ?: @"(nil)", dd_file_exists(src), wrap.m_uiMesLocalID);
    NSString *p = nil;
    unsigned int localID = wrap.m_uiMesLocalID;
    NSString *usr = dd_chat_usr_of_msg(wrap);
    if (localID != 0) {
        p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:usr
                                                                LocalID:localID
                                                                DocPath:[objc_getClass("CUtility") GetDocPath]];
    }
    if (!p.length) {
        p = [[(NSString *)[objc_getClass("CMessageWrap") getPathOfMsgImg:wrap]
              stringByReplacingOccurrencesOfString:@"Img" withString:@"Audio"]
             stringByReplacingOccurrencesOfString:@".pic" withString:@".aud"];
    }
    if (!p.length) { dd_log(@"[voice.install] 无法解析语音落地路径（GetPathOfMesAudio 与 getPathOfMsgImg 均失败）"); return nil; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[p stringByDeletingLastPathComponent]
    withIntermediateDirectories:YES attributes:nil error:nil];
    if ([fm fileExistsAtPath:p]) [fm removeItemAtPath:p error:nil];
    NSError *cpErr = nil;
    [fm copyItemAtPath:src toPath:p error:&cpErr];
    dd_log(@"[voice.install] 目标=%@ 复制结果=%d 错误=%@", p, dd_file_exists(p), cpErr.localizedDescription ?: @"无");
    return p;
}

// 发送语音消息到指定会话（复用 DD语音助手 的发送链路：addMessageToDB + ResendVoiceMsg）
static BOOL dd_send_voice(NSString *usr, NSString *audPath, unsigned int duration) {
    NSData *data = [NSData dataWithContentsOfFile:audPath];
    dd_log(@"[voice.send] usr=%@ aud=%@ data=%lu 字节 duration=%ums",
          usr ?: @"(nil)", audPath ?: @"(nil)", (unsigned long)data.length, duration);
    if (data.length == 0) { dd_log(@"[voice.send] 语音数据为空，放弃发送"); return NO; }
    AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
    if (!sender) { dd_log(@"[voice.send] 取不到 AudioSender 服务"); return NO; }
    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCVoiceMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDMCVoiceMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMCStatusSending];
    dd_configureVoiceMsg(wrap, data, duration);
    BOOL added = NO;
    if ([sender respondsToSelector:@selector(addMessageToDB:)]) added = [sender addMessageToDB:wrap];
    dd_log(@"[voice.send] addMessageToDB=%d localID=%u", added, wrap.m_uiMesLocalID);
    dd_install_audio_file(wrap, audPath);
    if ([sender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
        [sender ResendVoiceMsg:usr MsgWrap:wrap];
        dd_log(@"[voice.send] 已调用 ResendVoiceMsg，会话=%@", usr ?: @"(nil)");
    } else {
        dd_log(@"[voice.send] AudioSender 无 ResendVoiceMsg:MsgWrap:");
    }
    return YES;
}

// AVFoundation 抽取音轨为 16bit 单声道 PCM
static NSData *dd_extract_pcm(NSString *mediaPath, double *outDuration) {
    if (!dd_file_exists(mediaPath)) return nil;
    NSURL *url = [NSURL fileURLWithPath:mediaPath];
    // WCRefine 同款：带 AVURLAssetPreferPreciseDurationAndTimingKey 建 asset
    // （WCR_三转换功能_逆向分析.md:108），否则长视频的 duration 会不准，语音时长会算错
    NSDictionary *opts = @{(id)AVURLAssetPreferPreciseDurationAndTimingKey: @YES};
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:opts];
    double dur = CMTimeGetSeconds(asset.duration);
    if (!isfinite(dur) || dur <= 0) dur = 0;
    if (outDuration) *outDuration = dur;
    NSError *err = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:&err];
    if (err) { dd_log(@"[pcm] AVAssetReader 创建失败: %@", err.localizedDescription); return nil; }
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!track) { dd_log(@"[pcm] 素材无音轨（纯视频/无音频）: %@", mediaPath); return nil; }
    dd_log(@"[pcm] 素材=%@ 时长=%.3fs 音轨=%@", mediaPath, (outDuration ? *outDuration : 0), track);
    // WCRefine sub_0x8f1bc8 还原的 7 键输出设置（0x8f1ef0~0x8f2138）；
    // count 是 mov x4,#7 —— 正好对应下面这 7 个键，多一个少一个都不是 WCR 那套。
    NSDictionary *outSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),   // 0x8f1ef4 got 槽（numberWithUnsignedInt: 构造）
        AVSampleRateKey: @(kDDMCVoiceSampleRate),  // 0x8f1f68 mov w2,#0x3e80 == 16000
        AVNumberOfChannelsKey: @1,                 // 0x8f1fb4 mov w2,#1      == 单声道
        AVLinearPCMBitDepthKey: @16,               // 0x8f2000 mov w2,#0x10   == 16bit
        AVLinearPCMIsFloatKey: @NO,
        AVLinearPCMIsBigEndianKey: @NO,
        AVLinearPCMIsNonInterleaved: @NO,
    };
    dd_log(@"[pcm] 输出设置 16000Hz/单声道/16bit/整型/小端/交织 (7 键，对齐 WCR sub_0x8f1bc8)");
    AVAssetReaderTrackOutput *out = [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                                                   outputSettings:outSettings];
    [reader addOutput:out];
    if (![reader startReading]) { dd_log(@"[pcm] startReading 失败: %@", reader.error.localizedDescription ?: @"无"); return nil; }
    NSMutableData *pcm = [NSMutableData data];
    while (reader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef sb = [out copyNextSampleBuffer];
        if (!sb) break;   // v1.0.1：原实现用 continue，某些素材上会空转成死循环卡住主线程
        CMBlockBufferRef bb = CMSampleBufferGetDataBuffer(sb);
        size_t len = 0; char *ptr = NULL;
        if (bb && CMBlockBufferGetDataPointer(bb, 0, NULL, &len, &ptr) == kCMBlockBufferNoErr
            && ptr && len) {
            [pcm appendBytes:ptr length:len];
        }
        CFRelease(sb);
    }
    BOOL ok = (reader.status == AVAssetReaderStatusCompleted);
    dd_log(@"[pcm] 抽取结果=%d PCM=%lu 字节 readerStatus=%ld 错误=%@",
          ok, (unsigned long)pcm.length, (long)reader.status, reader.error.localizedDescription ?: @"无");
    return ok ? pcm : nil;
}

#pragma mark - SILK 容器处理（v1.0.2：逐条对齐 WCRefine 反汇编，不再自创格式）

// ══════════════════════════════════════════════════════════════════════════
// 取证来源：反汇编 /workspace/wcr_analysis/WCRefine.dylib（不是推测，是逐条指令读出来的）
//
// ① WCRefine SILK 头归一化 —— sub_0x8f18d8
//   0x8f19ac: ldrb w8,[x8] ; subs w8,w8,#2        → 看第 0 字节是不是 0x02
//   0x8f19c4: add x1,x1,#0x389 (0x2324389='#!SILK_V3') ; mov x2,#9 ; memcmp
//   0x8f19e4: 命中「\x02 + #!SILK_V3」→ 原样返回 data
//   0x8f1a3c: 退一步 memcmp(bytes,"#!SILK_V3",9)
//   0x8f1a90: NSMutableData dataWithCapacity:len+1
//   0x8f1ac8: mov w8,#2 ; sturb → appendBytes(&0x02,1)
//   0x8f1af4: appendData:data                       → 补上 0x02 再返回
//   0x8f1b6c: 两种魔数都没有 → 返回 nil（WCR 直接判废，不硬喂解码器）
//   ⇒ 结论：微信 .aud 正规容器头是 **10 字节 \x02#!SILK_V3**；
//           MJSilkCodec 吐出来的常常只有 9 字节 #!SILK_V3，必须补 0x02。
//     v1.0.1 只补了 9 字节魔数、漏了开头那个 0x02 —— 容器头就是错的 → 播放端解不出 →「没声音」。
//
// ② WCRefine SILK 合法性探测 —— sub_0x8f15f4（遍历帧）
//   0x8f16d4: b[0]==0x02 && len>=10 && memcmp(b+1,"#!SILK_V3",9) → pos=10
//   0x8f1734: 否则 memcmp(b,"#!SILK_V3",9)          → pos=9
//   0x8f179c: u16 帧长 = b[pos] | b[pos+1]<<8（小端），pos+=2
//   0x8f17d8: 无 0x02 前缀时，帧长==0xFFFF 判为终止帧不合规则
//   0x8f17f4: 帧长==0 或 >0x1000 → 判废
//   0x8f180c: pos+帧长 > len → 判废
//   ⇒ 结论：容器后面是「[2 字节小端帧长][帧数据]」重复序列。
//
// ③ WCRefine 编码优先级 —— sub_0x8f2804
//   0x8f2890: SELREF → 'encodeToSilkFromPCMData:'（类方法）
//   0x8f28b0: 'respondsToSelector:' → tbz 失败才跳 0x8f2a54
//   0x8f2a58: 'initEncoderWithSampleRate:'  0x8f2b00: mov x2,#0x3e80 == 16000
//   0x8f2b28: 'encodeFromPCMData:'
//   0x8f2994 / 0x8f2be4: 两条路径的结果都过一遍 sub_0x8f18d8（①）再返回
//   ⇒ 结论：类方法是主路径，实例 API 只是兜底，且兜底采样率写死 16000。
//     v1.0.1 把顺序搞反了（实例优先、类方法兜底），还去试 8000/24000。
//
// ④ WCRefine 媒体→语音总入口 —— WCRefineVoiceDataFromMediaPath (0x8de548)
//   0x8de648: NSData dataWithContentsOfFile:path
//   0x8de678: path.pathExtension.lowercaseString
//   0x8de7d4/0x8de808/0x8de83c: 等于 "aud"/"silk"/"slk" 时
//   0x8de85c: 过 sub_0x8f15f4，合法就 **原样返回 fileData**（已经是语音数据，不必再编）
//   0x8deb70: 否则 sub_0x8f1bc8(path, &ms) 抽 PCM → 0x8dec18 sub_0x8f2804 编码
//   ⇒ 结论：文件本身就是 .aud/.silk 时复用原文，不要二次编码。
//
// ⑤ WCRefine 长按菜单 —— WCRefineAppendVoiceToolsMediaMenuItems (0x8dd96c)
//   整条链（sub_0x8ddae4 / sub_0x8dde20 / sub_0x8de1f8）在「建菜单」阶段
//   只做：读开关 → cell 类名 isEqualToString:/rangeOfString: → 按 identifier 去重 → 造 item。
//   **一次都不解析文件路径**。
//   ⇒ 结论：v1.0.1 我在 AppFileMessageCellView 的 operationMenuItems 里同步调
//     dd_file_path_of_msg()（内部会打 CMessageWrap +GetPathOfAppData: 等未经真机验证的接口），
//     这就是「长按文件直接闪退」的回归点 —— 路径解析必须挪到点击以后。
// ══════════════════════════════════════════════════════════════════════════

// 十六进制 dump（诊断用：下一轮日志能直接看出 .aud 到底是什么格式）
static NSString *dd_hex_head(NSData *d, NSUInteger n) {
    if (!d.length) return @"(空)";
    NSMutableString *s = [NSMutableString string];
    const unsigned char *b = (const unsigned char *)d.bytes;
    for (NSUInteger i = 0; i < MIN(d.length, n); i++)
        [s appendFormat:@"%02x ", (unsigned)b[i]];
    return s;
}

// 「裸魔数」判定：以 "#!SILK_V3" 这 9 字节开头（不管前面有没有 0x02）
static BOOL dd_silk_has_magic9(NSData *d) {
    return d.length >= 9 && memcmp(d.bytes, "#!SILK_V3", 9) == 0;
}
// 「带 0x02 前缀的完整容器头」判定（WCR sub_0x8f18d8 的第一分支）
static BOOL dd_silk_has_magic10(NSData *d) {
    return d.length >= 10 && ((const unsigned char *)d.bytes)[0] == 0x02
           && memcmp((const unsigned char *)d.bytes + 1, "#!SILK_V3", 9) == 0;
}
// 是否认得出这是 SILK 容器（两种魔数任一）
static BOOL dd_silk_is_container(NSData *d) {
    return dd_silk_has_magic10(d) || dd_silk_has_magic9(d);
}

// WCR sub_0x8f18d8 的等价实现：把编码器输出归一化成微信认的 \x02#!SILK_V3 容器。
// 返回 nil = 编码器给的根本不是 SILK（按 WCR 的做法直接判废，不硬喂播放器/解码器）。
static NSData *dd_silk_normalize(NSData *d) {
    if (d.length == 0) return nil;
    if (dd_silk_has_magic10(d)) {
        dd_log(@"[silk.norm] 已是 %@ 容器(%lu 字节)，原样返回", @"\\x02#!SILK_V3", (unsigned long)d.length);
        return d;
    }
    if (dd_silk_has_magic9(d)) {
        NSMutableData *m = [NSMutableData dataWithCapacity:d.length + 1];
        const unsigned char lead = 0x02;
        [m appendBytes:&lead length:1];
        [m appendData:d];
        dd_log(@"[silk.norm] %lu→%lu 字节：补 0x02 前缀（缺了它微信解不出，就是「没声音」）",
              (unsigned long)d.length, (unsigned long)m.length);
        return m;
    }
    dd_log(@"[silk.norm] 编码器输出无 SILK 魔数(%lu 字节 头16=%@)，按 WCR 判废",
          (unsigned long)d.length, dd_hex_head(d, 16));
    return nil;
}

// 剥掉开头那一众可能的私有前缀，露出 SILK 本体（读取侧候选生成用）
static NSData *dd_silk_body_from(NSData *d) {
    if (dd_silk_has_magic10(d)) return d;                                  // 已是标准头
    if (dd_silk_has_magic9(d))   return d;                                 // 已是裸魔数
    if (d.length > 10) {
        NSData *sub = [d subdataWithRange:NSMakeRange(1, d.length - 1)];   // 剥 1 字节
        if (dd_silk_has_magic10(sub) || dd_silk_has_magic9(sub)) return sub;
    }
    if (d.length > 13) {
        NSData *sub = [d subdataWithRange:NSMakeRange(4, d.length - 4)];   // 剥 4 字节长度头
        if (dd_silk_has_magic10(sub) || dd_silk_has_magic9(sub)) return sub;
    }
    return nil;
}
// WCR sub_0x8f15f4 的等价实现：按「帧长/帧内容」走一遍，确认容器没被写坏
static BOOL dd_silk_frames_valid(NSData *d) {
    if (!dd_silk_is_container(d)) return NO;
    const unsigned char *b = (const unsigned char *)d.bytes;
    NSUInteger len = d.length;
    BOOL has02 = dd_silk_has_magic10(d);
    NSUInteger pos = has02 ? 10 : 9;
    NSUInteger frames = 0;
    while (pos + 2 <= len) {
        NSUInteger frameLen = (NSUInteger)b[pos] | ((NSUInteger)b[pos + 1] << 8);
        pos += 2;
        if (!has02 && frameLen == 0xFFFF) return NO;   // 裸魔数变体里这是非法帧长
        if (frameLen == 0 || frameLen > 0x1000) {
            dd_log(@"[silk.frame] 第%lu帧 长度=%lu 越界，容器损坏", (unsigned long)frames + 1, (unsigned long)frameLen);
            return NO;
        }
        if (pos + frameLen > len) {
            dd_log(@"[silk.frame] 第%lu帧 长度=%lu 超出文件尾部(pos=%lu len=%lu)，容器损坏",
                  (unsigned long)frames + 1, (unsigned long)frameLen, (unsigned long)pos, (unsigned long)len);
            return NO;
        }
        pos += frameLen;
        frames++;
        if (pos == len) {
            dd_log(@"[silk.frame] 走完 %lu 帧，容器自洽(len=%lu)", (unsigned long)frames, (unsigned long)len);
            return YES;
        }
    }
    dd_log(@"[silk.frame] 尾部不足 2 字节帧长头(pos=%lu len=%lu)，容器损坏", (unsigned long)pos, (unsigned long)len);
    return NO;
}

// PCM → SILK：严格按 WCR sub_0x8f2804（0x8f2804~0x8f2d18）的顺序与参数
//   主路径 类方法 +encodeToSilkFromPCMData:（MJSilkCodec.h:5）
//   兜底   实例 -initEncoderWithSampleRate:16000 + -encodeFromPCMData:（MJSilkCodec.h:7/:10）
//
// v1.0.7 关键修复（针对「转出来是静音消息」）：
//   用户 2026-09-22 真机日志显示：编码器产出 16600 字节 SILK 并已落盘、ResendVoiceMsg 也调了，
//   但播放静音；同时「语音→文件」读同一个 .aud 时 MJSilkCodec 的 decodeToAudioDataFromSilkData /
//   decodeToPCMFromSilkData 都返回 0 字节 —— 即编码器产物连微信自己的解码器都解不回来。
//   微信语音播放器用的正是 MJSilkCodec 这个解码器，解不回 = 播放静音。
//   旧逻辑（v1.0.2~v1.0.6）即便回环解码失败，仍把类方法产物硬发出去（「退回类方法产物尝试发送」），
//   于是静音消息照发不误。
//   新逻辑：把每个编码器产物的「标准头 \x02#!SILK_V3(magic10)」与「裸 #!SILK_V3(magic9)」两个容器变体
//   都交给 MJSilkCodec 的 decodeToPCMFromSilkData: 做回环验证，**只发能解回来的那个**；
//   全部解不开 → 放弃发送（绝不发静音消息）。用微信自己的解码器当裁判，彻底消除 magic9/magic10 猜测。

// 把编码器原始产物整理成候选容器数组（去重、按优先级：已经是 magic10 优先，其次 magic9，再补 0x02 变体）
static NSArray<NSData *> *dd_silk_candidates_from(NSData *raw) {
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:2];
    if (!raw.length) return arr;
    if (dd_silk_has_magic10(raw)) {                 // 已经是标准 10 字节头
        [arr addObject:raw];
    } else if (dd_silk_has_magic9(raw)) {           // 裸 9 字节魔数
        [arr addObject:raw];                        // 先试原样
        NSMutableData *m = [NSMutableData dataWithCapacity:raw.length + 1];
        const unsigned char lead = 0x02;
        [m appendBytes:&lead length:1];
        [m appendData:raw];
        [arr addObject:m];                          // 再试补 0x02 变体
    }
    // 连裸魔数都不是 → 不是 SILK，不入候选（回环验证也救不回来）
    return arr;
}

// 回环验证：用微信自己的解码器 decodeToPCMFromSilkData: 逐个试候选，返回第一个能解出 PCM 的容器。
// 解不回来的容器微信播放器必然也解不出 → 静音，绝不该发出去。
static NSData *dd_pick_decodable_silk(NSArray<NSData *> *raws) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) {
        dd_log(@"[silk.enc] MJSilkCodec 无 decodeToPCMFromSilkData:，无法回环验证（保守放弃）");
        return nil;
    }
    for (NSData *raw in raws) {
        NSArray<NSData *> *cands = dd_silk_candidates_from(raw);
        for (NSData *c in cands) {
            NSData *pcm = nil;
            @try { pcm = [codec decodeToPCMFromSilkData:c]; }
            @catch (NSException *e) { pcm = nil; dd_log(@"[silk.enc] 回环解码异常: %@", e.reason); }
            if (pcm.length > 0) {
                dd_log(@"[silk.enc] ✅ 选中可解码容器 magic%d（%lu 字节 → 解出 PCM %lu 字节），微信播放器必能播",
                      dd_silk_has_magic10(c) ? 10 : 9, (unsigned long)c.length, (unsigned long)pcm.length);
                return c;
            }
            dd_log(@"[silk.enc] 候选 magic%d 解出 0 字节，跳过", dd_silk_has_magic10(c) ? 10 : 9);
        }
    }
    return nil;
}

static NSData *dd_encode_pcm_to_silk(NSData *pcm) {
    if (pcm.length == 0) { dd_log(@"[silk.enc] PCM 为空"); return nil; }
    Class codec = objc_getClass("MJSilkCodec");
    if (!codec) { dd_log(@"[silk.enc] 找不到 MJSilkCodec 类"); return nil; }
    dd_log(@"[silk.enc] 输入 PCM=%lu 字节（%.2fs @16000Hz/单声道/16bit）",
          (unsigned long)pcm.length, pcm.length / (double)(kDDMCVoiceSampleRate * 2));

    // 先收集两个编码器的原始产物（都不急着归一化，留给回环验证决定用哪个容器变体）
    NSMutableArray *raws = [NSMutableArray arrayWithCapacity:2];

    // ── 主路径：类方法（WCR 0x8f2890 取的就是这个 SEL，tbz 只在 respondsToSelector: 失败时才跳兜底）
    if ([codec respondsToSelector:@selector(encodeToSilkFromPCMData:)]) {
        @try {
            NSData *raw = [codec encodeToSilkFromPCMData:pcm];
            dd_log(@"[silk.enc] 类方法 → %lu 字节 头16=%@", (unsigned long)raw.length, dd_hex_head(raw, 16));
            if (raw.length) [raws addObject:raw];
        } @catch (NSException *e) {
            dd_log(@"[silk.enc] 类方法异常: %@", e.reason);
        }
    } else {
        dd_log(@"[silk.enc] MJSilkCodec 无类方法 encodeToSilkFromPCMData:");
    }

    // ── 兜底：实例 API，采样率写死 16000（WCR 0x8f2b00 mov x2,#0x3e80）
    if ([codec instancesRespondToSelector:@selector(initEncoderWithSampleRate:)] &&
        [codec instancesRespondToSelector:@selector(encodeFromPCMData:)]) {
        @try {
            id inst = [[codec alloc] init];
            if ([inst initEncoderWithSampleRate:(long long)kDDMCVoiceSampleRate]) {
                NSData *raw = [inst encodeFromPCMData:pcm];
                dd_log(@"[silk.enc] 实例 API @%dHz → %lu 字节 头16=%@",
                      (int)kDDMCVoiceSampleRate, (unsigned long)raw.length, dd_hex_head(raw, 16));
                if (raw.length) [raws addObject:raw];
            } else {
                dd_log(@"[silk.enc] initEncoderWithSampleRate:%d 返回 NO", (int)kDDMCVoiceSampleRate);
            }
            if ([inst respondsToSelector:@selector(uninitEncoder)]) [inst uninitEncoder];
        } @catch (NSException *e) {
            dd_log(@"[silk.enc] 实例 API 异常: %@", e.reason);
        }
    }

    if (!raws.count) { dd_log(@"[silk.enc] 类方法与实例 API 均无产物，放弃编码"); return nil; }

    // ── 回环验证：只发微信自己的解码器能解回来的容器（这是静音问题的根治点）
    NSData *ok = dd_pick_decodable_silk(raws);
    if (!ok) {
        dd_log(@"[silk.enc] ⚠ 全部编码器产物经 MJSilkCodec 回环解码均为 0 字节 → 微信播放器也解不出 → "
               "放弃发送（避免静音消息）。头16 分别：%@ / %@",
              raws.count > 0 ? dd_hex_head(raws[0], 16) : @"(空)",
              raws.count > 1 ? dd_hex_head(raws[1], 16) : @"(单路)");
        return nil;
    }
    return ok;
}
// SILK（.aud 全文）→ PCM
// WCR 的做法（0x8de7d4 起）：后缀是 aud/silk/slk 且 sub_0x8f15f4 判合格时，
// 直接把文件原文当语音数据用 ——— 因为它本来就是语音数据，压根不必解码。
// 我们这一步要把 .aud 解成 PCM（为了导出成 m4a 文件消息），所以必须解码；
// 候选顺序就照 WCR 那套容器认知排，优先级最高的是 \x02#!SILK_V3 原文。
static NSData *dd_decode_silk_to_pcm(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    if (![codec respondsToSelector:@selector(decodeToPCMFromSilkData:)]) {
        dd_log(@"[silk.dec] MJSilkCodec 无 decodeToPCMFromSilkData:"); return nil;
    }
    if (fileData.length < 12) { dd_log(@"[silk.dec] 数据过小(%lu 字节)，放弃", (unsigned long)fileData.length); return nil; }
    dd_log(@"[silk.dec] 输入=%lu 字节 头16=%@", (unsigned long)fileData.length, dd_hex_head(fileData, 16));

    // 候选①：文件原文（标准 \x02#!SILK_V3 容器时它就是正解）
    // 候选②：剥掉可能的私有前缀后露出的 SILK 本体
    // 候选③：给裸魔数补 0x02 后的标准容器（兜中奖多在编码结果而不是原生 .aud 上）
    NSMutableArray<NSData *> *cands = [NSMutableArray array];
    NSMutableArray<NSString *> *tags = [NSMutableArray array];
    NSData *body = dd_silk_body_from(fileData);
    if (dd_silk_has_magic10(fileData)) {
        [cands addObject:fileData]; [tags addObject:@"原文(\\x02#!SILK_V3)"];
    } else if (dd_silk_has_magic9(fileData)) {
        [cands addObject:fileData]; [tags addObject:@"原文(#!SILK_V3)"];
        NSData *full = dd_silk_normalize(fileData);
        if (full) { [cands addObject:full]; [tags addObject:@"补0x02成标准头"]; }
    } else if (body) {
        [cands addObject:body]; [tags addObject:@"剥前缀后本体"];
        NSData *full = dd_silk_normalize(body);
        if (full) { [cands addObject:full]; [tags addObject:@"本体+补0x02"]; }
    } else {
        dd_log(@"[silk.dec] 认不出 SILK 容器头，前32字节=%@", dd_hex_head(fileData, 32));
        return nil;
    }

    NSData *best = nil; NSString *bestTag = nil;
    for (NSUInteger i = 0; i < cands.count; i++) {
        NSData *cand = cands[i];
        // 容器帧链必须先自洽，绝不能把内容不明的数据丢进解码器 —— v1.0.0 就是这么 SIGSEGV 的
        if (!dd_silk_frames_valid(cand)) {
            dd_log(@"[silk.dec] 候选「%@」帧链不自洽，跳过（不喂解码器，避免越界崩）", tags[i]);
            continue;
        }
        NSData *pcm = nil;
        @try { pcm = [codec decodeToPCMFromSilkData:cand]; }
        @catch (NSException *e) { dd_log(@"[silk.dec] 候选「%@」异常: %@", tags[i], e.reason); continue; }
        dd_log(@"[silk.dec] 候选「%@」→ PCM %lu 字节", tags[i], (unsigned long)pcm.length);
        if (pcm.length > best.length) { best = pcm; bestTag = tags[i]; }
    }
    if (!best.length) { dd_log(@"[silk.dec] 所有候选均解不出 PCM，放弃"); return nil; }
    dd_log(@"[silk.dec] 命中候选=%@ PCM=%lu 字节（约%.2fs）", bestTag, (unsigned long)best.length,
          best.length / (double)(kDDMCVoiceSampleRate * 2));
    return best;
}

// 媒体 → 语音：先确保已下载，再抽音轨→SILK→发送语音消息到当前聊天
// pathBlock 由调用方按消息类型给出（普通视频取 videoPath；应用视频/文件取 appDataItem 路径）
// downloadBlock 由调用方按消息类型给出（普通视频用 StartDownloadVideo；应用视频/文件用 StartDownloadAppAttach）
static void dd_media_to_voice(CMessageWrap *msg, NSString *(^pathBlock)(void), void(^downloadBlock)(void)) {
    if (!msg) { dd_log(@"[media→voice] msg 为空，放弃"); return; }
    dd_log(@"[media→voice] ==== 开始 ==== type=%u localID=%u chat=%@",
          msg.m_uiMessageType, msg.m_uiMesLocalID, dd_chat_usr_of_msg(msg) ?: @"(nil)");
    NSString *usr = dd_chat_usr_of_msg(msg);
    // v1.0.1：抽音轨 + SILK 编码 + 回环自校验都不轻，挪到全局队列，避免长按菜单点击后
    //         主线程卡顿被 watchdog 杀；只有最后的发送回到主线程。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSString *path = pathBlock();
            if (!dd_file_exists(path)) {
                dd_log(@"[media→voice] 本地文件不存在，触发自动下载");
                if (downloadBlock) downloadBlock();
                path = dd_wait_local_path(pathBlock, kDDMCDownloadTimeout);
            }
            if (!dd_file_exists(path)) { dd_log(@"[media→voice] 下载失败/超时，放弃转换"); return; }

            // WCRefineVoiceDataFromMediaPath (0x8de548) 的原样逻辑：
            //   NSData dataWithContentsOfFile:path → [[path pathExtension] lowercaseString]
            //   后缀命中 aud/silk/slk 且 sub_0x8f15f4 判合格 → **直接把文件原文当语音数据**，
            //   不再走「抽 PCM → 重编码」这条既慢又有损的路。（发送语音文件本身就是 .aud 的情况）
            NSData *fileData = [NSData dataWithContentsOfFile:path];
            NSString *ext = [[path pathExtension] lowercaseString];
            NSData *aud = nil;
            double duration = 0;

            BOOL alreadySilk = fileData.length > 0 &&
                               ([ext isEqualToString:@"aud"] || [ext isEqualToString:@"silk"] ||
                                [ext isEqualToString:@"slk"]) &&
                               dd_silk_frames_valid(fileData);
            if (alreadySilk) {
                aud = fileData;
                // 注意：SILK 是压缩流，**不能**拿压缩后的字节数当成 16bit PCM 去估时长
                // （那样会把时长放大好几倍，语音条显示全是错的）。解一遍拿真实 PCM 长度才算得准，
                // 这里的解码只读不算重编码，产物仍然复用原文 fileData。
                NSData *pcm = dd_decode_silk_to_pcm(fileData);
                duration = pcm.length ? (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2) : 0;
                dd_log(@"[media→voice] 源文件已是合法 SILK(%@, %lu 字节)，按 WCR 原样复用不二次编码，"
                       "解出 PCM=%lu 字节 → 时长 %.2fs",
                      ext, (unsigned long)fileData.length, (unsigned long)pcm.length, duration);
            } else {
                NSData *pcm = dd_extract_pcm(path, &duration);
                if (pcm.length == 0) { dd_log(@"[media→voice] PCM 为空（无音轨或格式不支持），放弃"); return; }
                // 时长必须以「真实抽出的 PCM 长度」为准，不能用 asset.duration（那是视频时长，
                // 可能与音轨实际长度不符，日志里就出现过视频 16.167s、音轨仅 8s 的情况 → 气泡时长错、播放错位）
                duration = (double)pcm.length / (double)(kDDMCVoiceSampleRate * 2);
                aud = dd_encode_pcm_to_silk(pcm);
                if (aud.length == 0) { dd_log(@"[media→voice] SILK 编码失败（回环验证未通过，已放弃发送以免静音），放弃"); return; }
            }

            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [aud writeToFile:tmp atomically:YES];
            unsigned int ms = (unsigned int)(duration * 1000);
            if (ms == 0) ms = 1000;
            if (ms > 60000) { dd_log(@"[media→voice] 原始时长=%ums 超过微信语音 60s 上限，按 60s 发送", ms); ms = 60000; }
            dd_log(@"[media→voice] 时长=%ums → 发送语音 (aud=%lu 字节 标准容器头=%d)",
                  ms, (unsigned long)aud.length, dd_silk_has_magic10(aud));
            dispatch_async(dispatch_get_main_queue(), ^{
                // v1.0.11：ResendVoiceMsg 跑在主线程，外层 @try 只包了 global block，
                // 这里必须单独兜异常，否则微信内部抛出的 NSException 会直接崩进程
                // （用户日志 06:21:01 崩点即 voice.install 之后、ResendVoiceMsg 之前无日志）。
                @try {
                    BOOL sent = dd_send_voice(usr, tmp, ms);
                    dd_log(@"[media→voice] ==== 结束 ==== 发送结果=%d", sent);
                } @catch (NSException *e) {
                    dd_log(@"[media→voice] 发送阶段异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
                }
            });
        } @catch (NSException *e) {
            dd_log(@"[media→voice] 异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
        }
    });
}

#pragma mark - 转换：语音 → 文件（SILK → 音频/m4a → 作为文件消息发到当前聊天）

// 语音消息本地路径（v1.0.1：优先实例方法 -getVoicePath（CMessageWrap.h:362）。
// 它直接给出语音落点，不需要拼 usr/localID，也就绕开了
// "isSenderFromMsgWrap: 判错 → 拼出对方的 .aud 路径" 这个隐患）
static NSString *dd_voice_path_of_msg(CMessageWrap *msg) {
    if (!msg) return nil;
    Class wrapCls = objc_getClass("CMessageWrap");
    NSMutableArray<NSString *> *cands = [NSMutableArray array];
    @try {   // 1) 实例方法，最权威
        NSString *p = (NSString *)[msg getVoicePath];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] getVoicePath 异常 %@", e.reason); }
    @try {   // 2) +getPathOfAudio:msgWrap（CMessageWrap.h:66）
        NSString *p = (NSString *)[wrapCls getPathOfAudio:msg];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] getPathOfAudio: 异常 %@", e.reason); }
    @try {   // 3) CUtility.GetPathOfMesAudio:LocalID:DocPath:（CUtility.h:82）
        NSString *usr = [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
        NSString *p = (NSString *)[objc_getClass("CUtility") GetPathOfMesAudio:usr
                                                                        LocalID:msg.m_uiMesLocalID
                                                                        DocPath:[objc_getClass("CUtility") GetDocPath]];
        if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
    } @catch (NSException *e) { dd_log(@"[voice.path] GetPathOfMesAudio: 异常 %@", e.reason); }
    @try {   // 4) AudioSender.getAudioFileName:LocalID:（AudioSender.h）
        NSString *usr = [wrapCls isSenderFromMsgWrap:msg] ? msg.m_nsToUsr : msg.m_nsFromUsr;
        AudioSender *sender = (AudioSender *)dd_mm_service(@"AudioSender");
        if ([sender respondsToSelector:@selector(getAudioFileName:LocalID:)]) {
            NSString *p = [sender getAudioFileName:usr LocalID:msg.m_uiMesLocalID];
            if ([p isKindOfClass:[NSString class]] && p.length) [cands addObject:p];
        }
    } @catch (NSException *e) { dd_log(@"[voice.path] getAudioFileName: 异常 %@", e.reason); }

    NSUInteger idx = 0;
    for (NSString *p in cands) {
        dd_log(@"[voice.path] 候选#%lu %@ 存在=%d", (unsigned long)idx, p, dd_file_exists(p));
        if (dd_file_exists(p)) return p;
        idx++;
    }
    // 5) 文件系统里还没有 → 从 m_dtVoice 兜底导出（未下载完/路径接口失效）
    @try {
        NSData *d = (NSData *)((CExtendInfoOfVoiceMsg *)[msg m_extendInfoWithMsgType]).m_dtVoice;
        if (d.length) {
            NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                             [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"aud"]];
            [d writeToFile:tmp atomically:YES];
            dd_log(@"[voice.path] 回退 m_dtVoice → %@ (%lu 字节)", tmp, (unsigned long)d.length);
            return tmp;
        }
    } @catch (...) {}
    dd_log(@"[voice.path] 取不到语音文件（未下载或路径接口失效）");
    return nil;
}
// 读出 .aud 全文（v1.0.1：不再剥任何前缀，容器识别交给 dd_decode_silk_to_pcm 按魔数判断）
static NSData *dd_silk_data_of_msg(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[silk] msg 为空"); return nil; }
    NSString *p = dd_voice_path_of_msg(msg);
    if (!dd_file_exists(p)) { dd_log(@"[silk] 取不到语音文件 localID=%u", msg.m_uiMesLocalID); return nil; }
    NSData *d = [NSData dataWithContentsOfFile:p];
    dd_log(@"[silk] 文件=%@ %lu 字节 头16=%@", p.lastPathComponent, (unsigned long)d.length, dd_hex_head(d, 16));
    if (d.length < 12) { dd_log(@"[silk] 语音数据过小，放弃"); return nil; }
    return d;
}

// PCM → WAV：手写 44 字节 RIFF 头（16bit / 单声道 / 16000Hz），纯字节拼装，无第三方依赖
// 采样率必须跟 dd_extract_pcm 的输出设置一致（同取自 kDDMCVoiceSampleRate=16000），
// 否则 m4a 会整体变调。
static NSData *dd_wav_of_pcm(NSData *pcm) {
    if (pcm.length == 0) return nil;
    const uint32_t sampleRate = (uint32_t)kDDMCVoiceSampleRate;
    const uint16_t channels = 1, bits = 16;
    unsigned char hdr[44] = {0};
    memcpy(hdr + 0,  "RIFF", 4);
    uint32_t riffSize = (uint32_t)(36 + pcm.length); memcpy(hdr + 4,  &riffSize, 4);
    memcpy(hdr + 8,  "WAVE", 4);
    memcpy(hdr + 12, "fmt ", 4);
    uint32_t fmtSize = 16;                            memcpy(hdr + 16, &fmtSize, 4);
    uint16_t audioFmt = 1;                            memcpy(hdr + 20, &audioFmt, 2);   // 1 = PCM
    memcpy(hdr + 22, &channels, 2);
    memcpy(hdr + 24, &sampleRate, 4);
    uint32_t byteRate = sampleRate * channels * bits / 8; memcpy(hdr + 28, &byteRate, 4);
    uint16_t blockAlign = channels * bits / 8;        memcpy(hdr + 32, &blockAlign, 2);
    memcpy(hdr + 34, &bits, 2);
    memcpy(hdr + 36, "data", 4);
    uint32_t dataSize = (uint32_t)pcm.length;         memcpy(hdr + 40, &dataSize, 4);
    NSMutableData *wav = [NSMutableData dataWithCapacity:pcm.length + 44];
    [wav appendBytes:hdr length:44];
    [wav appendData:pcm];
    return wav;
}
// PCM → m4a（v1.0.1 重写）
// v1.0.0 用 AVAssetWriter + CMBlockBufferCreateWithMemoryBlock 直接借用 NSData.bytes，
// 且 memoryBlock 生命周期不受控；SILK 解码出来的 PCM 一旦不规整就会被 CMSampleBuffer 判定越界 → 闪退。
// 改为 WCRefine 验证过的路线：PCM → WAV 文件 → AVAssetExportSession(AVAssetExportPresetAppleM4A)
// （WCR_三转换功能_逆向分析.md:110 中关于 AVAssetExportSession / AVAssetExportPresetAppleM4A 的实证）
static NSString *dd_write_m4a(NSData *pcm) {
    if (pcm.length == 0) { dd_log(@"[m4a] PCM 为空"); return nil; }
    NSString *wavPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                         [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"wav"]];
    NSData *wav = dd_wav_of_pcm(pcm);
    if (![wav writeToFile:wavPath atomically:YES]) { dd_log(@"[m4a] WAV 写盘失败"); return nil; }
    dd_log(@"[m4a] WAV=%@ (%lu 字节, PCM=%lu, 约%.2fs)",
          wavPath.lastPathComponent, (unsigned long)wav.length, (unsigned long)pcm.length,
          pcm.length / (double)(kDDMCVoiceSampleRate * 2));

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"m4a"]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:wavPath] options:nil];
    AVAssetExportSession *ex = [AVAssetExportSession exportSessionWithAsset:asset
                                                                presetName:AVAssetExportPresetAppleM4A];
    if (!ex) { dd_log(@"[m4a] 创建 AVAssetExportSession 失败"); return nil; }
    ex.outputFileType = AVFileTypeAppleM4A;
    ex.outputURL = [NSURL fileURLWithPath:path];
    // done 区分「回调正常返回」和「20s 超时没等到回调」——超时时 status 可能还没落终态，不能算成功
    __block BOOL done = NO;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [ex exportAsynchronouslyWithCompletionHandler:^{ done = YES; dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
    BOOL ok = done && dd_file_exists(path) && ex.status == AVAssetExportSessionStatusCompleted;
    dd_log(@"[m4a] 导出结果=%d 状态=%ld 回调已返回=%d 错误=%@",
          ok, (long)ex.status, done, ex.error.localizedDescription ?: @"无");
    [[NSFileManager defaultManager] removeItemAtPath:wavPath error:nil];
    if (!ok) return nil;
    unsigned long long sz = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    dd_log(@"[m4a] 产物=%@ (%llu 字节)", path.lastPathComponent, sz);
    return path;
}

// v1.0.10：把临时目录产物拷进微信持久沙盒再发送，避免「NSTemporaryDirectory 被系统清理 →
// 文件消息指向死路径 → 重启后/清理后打不开」。微信 AddAppMsg:DataPath: 后续会直接读这个路径，
// 而临时目录在进程重启或系统周期性清理时会被清空，因此必须在发送前落到持久目录。
static NSString *dd_persist_copy(NSString *src) {
    if (!dd_file_exists(src)) return nil;
    NSString *dir = nil;
    Class util = objc_getClass("CUtility");
    if ([util respondsToSelector:@selector(GetDocPath)]) {   // CUtility.h:49
        @try {
            NSString *d = (NSString *)[util GetDocPath];
            if ([d isKindOfClass:[NSString class]] && d.length) dir = d;
        } @catch (NSException *e) { dd_log(@"[persist] GetDocPath 异常 %@", e.reason); }
    }
    if (!dir.length) {
        NSArray<NSString *> *ds = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        if (ds.count) dir = ds.firstObject;
    }
    if (!dir.length) dir = NSHomeDirectory();
    NSString *dst = [dir stringByAppendingPathComponent:
        [NSString stringWithFormat:@"ddmc_voice_%@.m4a", [[NSUUID UUID] UUIDString]]];
    NSError *e = nil;
    if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&e] || !dd_file_exists(dst)) {
        dd_log(@"[persist] 拷贝失败 %@ → %@", src.lastPathComponent, e.localizedDescription ?: @"未知");
        return nil;
    }
    return dst;
}

// 把 m4a 作为文件消息发到当前聊天（CExtendInfoOfAPP innerType=6 + CMessageMgr.AddAppMsg）
//  ⚠ 真机校验点：文件消息构造 + 本地文件上传发送在不同微信版本差异较大，需对照真机微调。
static BOOL dd_send_file_to_chat(NSString *usr, NSString *m4aPath, NSString *fileName) {
    // v1.0.10：先持久化，再用持久路径发送（见 dd_persist_copy 注释）。原临时文件保留不动，
    // 仅把 m4aPath 重定向到持久副本，后续 extendInfo / AddAppMsg 全部基于持久路径。
    NSString *persistPath = dd_persist_copy(m4aPath);
    if (persistPath.length) {
        dd_log(@"[file.send] 产物已拷入持久沙盒 %@ → %@", m4aPath.lastPathComponent, persistPath);
        m4aPath = persistPath;
    } else {
        dd_log(@"[file.send] 持久化拷贝失败，仍用临时路径（风险：重启后可能打不开）");
    }
    if (!dd_file_exists(m4aPath) || !usr.length) {
        dd_log(@"[file.send] 参数不合法: path=%@ usr=%@", m4aPath ?: @"(nil)", usr ?: @"(nil)");
        return NO;
    }
    NSData *fdata = [NSData dataWithContentsOfFile:m4aPath];
    if (fdata.length == 0) { dd_log(@"[file.send] m4a 数据为空"); return NO; }
    dd_log(@"[file.send] usr=%@ file=%@ size=%lu", usr, m4aPath, (unsigned long)fdata.length);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attr = [fm attributesOfItemAtPath:m4aPath error:nil];
    unsigned long long fsize = attr ? [attr[NSFileSize] unsignedLongLongValue] : fdata.length;

    CMessageWrap *wrap = [[objc_getClass("CMessageWrap") alloc] initWithMsgType:kDDMCAppMsgType];
    [wrap setM_uiMessageType:(unsigned int)kDDMCAppMsgType];
    [wrap setM_nsFromUsr:dd_current_usr_name()];
    [wrap setM_nsToUsr:usr];
    unsigned int createTime = (unsigned int)time(NULL);
    unsigned int t = [(MMNewSessionMgr *)dd_mm_service(@"MMNewSessionMgr") GenSendMsgTime];
    if (t != 0) createTime = t;
    [wrap setM_uiCreateTime:createTime];
    [wrap setM_uiStatus:kDDMCStatusSending];

    CExtendInfoOfAPP *app = [[objc_getClass("CExtendInfoOfAPP") alloc] init];
    [app setM_uiAppMsgInnerType:kDDMCAppInnerFile];
    [app setM_nsAppFileName:fileName];
    [app setM_nsAppFileExt:@"m4a"];
    [app setM_uiAppDataSize:fsize];
    // v1.0.3：这里原来是 [wrap setValue:app forKey:@"m_oAppDataItem"]，而 8.0.79 全库已无该字段
    // （KVC 抛 NSUndefinedKeyException 被 @catch 吞掉）→ extendInfo 永远挂不上 →
    // AddAppMsg 内部拿不到文件数据项 → 「语音转文件」走到最后一步静默失败（用户看到的就是「没反应」）。
    // 换成真实存在的权威 setter：CMessageWrap.h:637 setM_extendInfoWithMsgType:
    @try {
        [wrap setM_extendInfoWithMsgType:app];
        dd_log(@"[file.send] extendInfo 已挂载 setM_extendInfoWithMsgType: (CMessageWrap.h:637)");
    } @catch (NSException *e) {
        dd_log(@"[file.send] setM_extendInfoWithMsgType: 异常 %@", e.reason);
        @try { [wrap setValue:app forKey:@"m_oAppDataItem"]; } @catch (...) {}   // 老版本兼容
    }

    CMessageMgr *mgr = (CMessageMgr *)dd_mm_service(@"CMessageMgr");
    if ([mgr respondsToSelector:@selector(AddAppMsg:MsgWrap:DataPath:Scene:)]) {
        [mgr AddAppMsg:usr MsgWrap:wrap DataPath:m4aPath Scene:0];
        dd_log(@"[file.send] 已调用 AddAppMsg:MsgWrap:DataPath:Scene:");
        // v1.0.11：AddAppMsg 只做「本地落库 + 把文件拷进 OpenData」这一步，**不上传** →
        // 消息 status 停在 Sending、服务器无该文件记录 → 微信把文件消息当「未下载」，
        // 重启/系统清理本地缓存后显示 0B（用户截图 23.dat 0B + 「接收文件」按钮，23 即该消息
        // localID；日志 74 行也显示微信把它落在 OpenData/<hash>/23.m4a，而非我们持久化的副本）。
        // 必须紧接着调 StartUploadAppMsg:MsgWrap:Scene:（CMessageMgr.h:273）触发上传，消息才会
        // 变成「已发送/已上传」，重启后不再变 0B。
        if ([mgr respondsToSelector:@selector(StartUploadAppMsg:MsgWrap:Scene:)]) {
            [mgr StartUploadAppMsg:usr MsgWrap:wrap Scene:0];
            dd_log(@"[file.send] 已调用 StartUploadAppMsg:MsgWrap:Scene: 触发上传 (CMessageMgr.h:273)");
        } else {
            dd_log(@"[file.send] CMessageMgr 无 StartUploadAppMsg:MsgWrap:Scene:（无法触发上传）");
        }
        return YES;
    }
    // v1.0.3：原来的兜底是 [mgr addMessageToDB:]，但 8.0.79 里这个方法只存在于 AudioSender
    // （AudioSender.h:13），CMessageMgr 没有 → respondsToSelector 恒为 NO → 兜底形同虚设。
    // 换成 CMessageMgr 真实存在的本地落地接口（CMessageMgr.h:191 / :194）。
    if ([mgr respondsToSelector:@selector(AddLocalMsg:MsgWrap:)]) {
        [mgr AddLocalMsg:usr MsgWrap:wrap];
        dd_log(@"[file.send] AddAppMsg 不可用，已回退 AddLocalMsg:MsgWrap: (CMessageMgr.h:191)");
        return YES;
    }
    if ([mgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) {
        [mgr AddMsg:usr MsgWrap:wrap];
        dd_log(@"[file.send] 已回退 AddMsg:MsgWrap: (CMessageMgr.h:194)");
        return YES;
    }
    dd_log(@"[file.send] 无任何可用发送接口");
    return NO;
}

// SILK → m4a 文件：优先走直出音频接口 decodeToAudioDataFromSilkData:（MJSilkCodec.h:3），
// 若其返回 m4a/mp4 容器（'ftyp' box）则直接落盘，省去 PCM→AAC 重编码；否则回退 PCM→AAC。
static NSString *dd_decode_silk_to_audio(NSData *fileData) {
    Class codec = objc_getClass("MJSilkCodec");
    // 主路径：多候选 → PCM（经 dd_decode_silk_to_pcm 过滤掉会让解码器越界的容器变体）
    NSData *pcm = dd_decode_silk_to_pcm(fileData);
    if (pcm.length) {
        NSString *m4a = dd_write_m4a(pcm);
        if (m4a.length) return m4a;
        dd_log(@"[decode] PCM→m4a 失败，继续尝试直出通道");
    }
    // 备选：decodeToAudioDataFromSilkData:（MJSilkCodec.h:3）直出音频。
    // 实测 v1.0.0 它对我们送进去的数据返回 0 字节（容器不对），故排在 PCM 之后。
    if (![codec respondsToSelector:@selector(decodeToAudioDataFromSilkData:)]) {
        dd_log(@"[decode] 无 decodeToAudioDataFromSilkData:"); return nil;
    }
    NSData *stdCand = dd_silk_normalize(fileData);
    NSArray<NSData *> *tries = stdCand ? @[stdCand, fileData] : @[fileData];
    for (NSData *cand in tries) {
        NSData *audio = nil;
        @try { audio = [codec decodeToAudioDataFromSilkData:cand]; }
        @catch (NSException *e) { dd_log(@"[decode] 直出异常: %@", e.reason); continue; }
        dd_log(@"[decode] decodeToAudioDataFromSilkData → %lu 字节 头16=%@",
              (unsigned long)audio.length, dd_hex_head(audio, 16));
        if (audio.length < 32) continue;
        const unsigned char *b = (const unsigned char *)audio.bytes;
        BOOL isFtyp = (b[4]=='f' && b[5]=='t' && b[6]=='y' && b[7]=='p');
        BOOL isID3  = (b[0]=='I' && b[1]=='D' && b[2]=='3');
        BOOL isFmt  = (b[0]=='R' && b[1]=='I' && b[2]=='F' && b[3]=='F');
        if (isFtyp || isID3) {   // m4a/mp4 容器或 mp3(ID3) → 可直接落盘，无需重编码
            NSString *ext = isFtyp ? @"m4a" : @"mp3";
            NSString *p = [NSTemporaryDirectory() stringByAppendingPathComponent:
                [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:ext]];
            if ([audio writeToFile:p atomically:YES] && dd_file_exists(p)) {
                dd_log(@"[decode] 直出音频落盘(%@) → %@", ext, p.lastPathComponent);
                return p;
            }
        }
        if (isFmt && audio.length > 44) {   // WAV 容器 → 剥 44 字节头拿 PCM 再走统一封装
            NSData *raw = [audio subdataWithRange:NSMakeRange(44, audio.length - 44)];
            NSString *m4a = dd_write_m4a(raw);
            if (m4a.length) { dd_log(@"[decode] 直出 WAV → 转封装 m4a"); return m4a; }
        }
    }
    dd_log(@"[decode] 直出通道也没出结果");
    return nil;
}

// 语音消息 → 文件消息（"语音转文件"开关）：取 SILK → m4a → 作为文件消息发到当前聊天。
// v1.0.1：整条链路挪到全局队列跑。v1.0.0 在主线程上做 SILK 解码 + 音频编码，
// 长语音会把主线程堵住（微信被 watchdog 判无响应直接杀进程，表现为“闪退”）；
// 微信的消息发送 API 仍回主线程调用。
static void dd_voice_to_file(CMessageWrap *msg) {
    if (!msg) { dd_log(@"[voice→file] msg 为空，放弃"); return; }
    NSString *usr = dd_chat_usr_of_msg(msg);
    NSString *fn  = [NSString stringWithFormat:@"语音_%u.m4a", (unsigned int)time(NULL)];
    unsigned int localID = msg.m_uiMesLocalID;
    dd_log(@"[voice→file] ==== 开始 ==== localID=%u chat=%@", localID, usr ?: @"(nil)");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSData *silk = dd_silk_data_of_msg(msg);
            if (silk.length == 0) { dd_log(@"[voice→file] 取不到语音数据，放弃"); return; }
            NSString *m4a = dd_decode_silk_to_audio(silk);
            if (!m4a.length) { dd_log(@"[voice→file] 解码/封装失败，放弃"); return; }
            if (!m4a.length) { dd_log(@"[voice→file] 解码/封装失败，放弃"); return; }
            dispatch_async(dispatch_get_main_queue(), ^{
                @try {   // v1.0.11：AddAppMsg/StartUploadAppMsg 在主线程，单独兜异常
                    BOOL sent = dd_send_file_to_chat(usr, m4a, fn);
                    dd_log(@"[voice→file] ==== 结束 ==== 发送结果=%d", sent);
                } @catch (NSException *e) {
                    dd_log(@"[voice→file] 发送阶段异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
                }
            });
        } @catch (NSException *e) {
            // 兜底：解码/封装/发送任何异常都吞掉并留证据，避免把微信带崩
            dd_log(@"[voice→file] 异常（已捕获，避免闪退）: %@ | %@", e.name, e.reason);
        }
    });
}

#pragma mark - 菜单图标（用户确认 icon_filled_record_voice.svg 在 8.0.79 内置资源中存在，不做兜底）

// 用户确认 icon_filled_record_voice.svg 在 8.0.79 内置资源中存在，直接吃这个 svg 资源名，
// 不走任何兜底（不借原生图标、不做纯文字）。initWithTitle:svgName:target:action:（MMMenuItem.h:18）。
// 8.0.79 的 MMMenuItem **既没有 title getter 也没有 action getter**（51 行的头文件里只有 target），
// 所以原先用 `it.action == action` 去重的做法在这版本上恒不成立（同一 action 会被重复注入）。
// 改法：自己往 userInfo 里塞标记（MMMenuItem.h:29 读 / :49 写）。
static NSString *dd_menu_token(SEL action) {
    return [@"ddmc:" stringByAppendingString:NSStringFromSelector(action)];
}

static MMMenuItem *dd_convertMenuItem(NSString *title, id target, SEL action, NSArray *original) {
    Class cls = objc_getClass("MMMenuItem");
    if (!cls) return nil;
    MMMenuItem *item = nil;
    // 用户确认存在的内置 svg 图标，无兜底。
    @try {
        item = [[cls alloc] initWithTitle:title
                                  svgName:@"icon_filled_record_voice.svg"
                                   target:target
                                   action:action];
    } @catch (NSException *e) {
        dd_log(@"[menu.icon] initWithTitle:svgName: 异常: %@", e.reason);
        return nil;
    }
    if (!item) { dd_log(@"[menu.icon] MMMenuItem 构造返回 nil（svg=icon_filled_record_voice.svg）"); return nil; }
    @try { [item setUserInfo:dd_menu_token(action)]; } @catch (...) {}
    dd_log(@"[menu.icon] 用内置 svg icon_filled_record_voice.svg");
    return item;
}

// 统一注入：取原生菜单数组，按开关追加对应按钮
static NSArray *dd_inject_items(id cell, NSArray *original, BOOL enabled, NSString *title, SEL action) {
    dd_log(@"[menu] cell=%@ 注入「%@」enabled=%d 原生菜单数=%lu",
          NSStringFromClass([cell class]), title, enabled, (unsigned long)original.count);
    if (!enabled) { dd_log(@"[menu] 开关关闭/类型不匹配，不注入「%@」", title); return original; }
    // 按我们自己塞进 userInfo 的标记去重（8.0.79 的 MMMenuItem 读不出 title/action，见上方说明）。
    // 依据 WCR：它在基类 BaseMessageCellView 统一 hook operationMenuItems（BaseMessageCellView.h:65），
    // 四个子类各自也 hook（VideoMessageCellView.h:12 / AppVideoMessageCellView.h:7 /
    // AppFileMessageCellView.h:17 / VoiceMessageCellView.h:34）。两层 hook 叠加时同一个 action
    // 会被注入两次，菜单里就会出现两个同名按钮 —— 追加前先查一轮，命中就跳过。
    NSString *token = dd_menu_token(action);
    for (id it in original) {
        @try {
            if (![it respondsToSelector:@selector(userInfo)]) continue;
            id ui = [(id)it userInfo];
            if ([ui isKindOfClass:[NSString class]] && [(NSString *)ui isEqualToString:token]) {
                dd_log(@"[menu] 「%@」已存在（基类或其他 hook 已注入），跳过重复追加", title);
                return original;
            }
        } @catch (...) {}
    }
    MMMenuItem *item = dd_convertMenuItem(title, cell, action, original);
    if (!item) { dd_log(@"[menu] MMMenuItem 构造失败"); return original; }
    NSMutableArray *items = [NSMutableArray arrayWithArray:original];
    [items addObject:item];   // 追加到菜单末尾（与 WCR 行为一致）
    dd_log(@"[menu] 已追加「%@」→ 菜单数=%lu", title, (unsigned long)items.count);
    return items;
}

#pragma mark - Hook：视频消息 → 转语音

%hook VideoMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].videoToVoiceEnabled;
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(视频消息)");
    CMessageWrap *msg = dd_msg_of_cell(self);
    dd_media_to_voice(msg, ^NSString *{ return dd_video_path_of_cell(self); },
                          ^{ dd_trigger_video_download(msg); });
}
%end

%hook AppVideoMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    // 仅视频号（AppVideoMessageViewModel.isWSVideo）注入“转语音”，其他 app 视频不处理
    id vm = [self viewModel];
    if (![vm respondsToSelector:@selector(isWSVideo)] || ![vm isWSVideo]) {
        dd_log(@"[menu.appvideo] 非视频号（isWSVideo 缺失或为 NO），不注入");
        return original;
    }
    BOOL on = [DDMediaConvertConfig shared].videoToVoiceEnabled;
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].videoToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(应用视频/视频号)");
    // 仅视频号参与转换（isWSVideo）；非视频号 app 视频不处理
    id vm = [self viewModel];
    if ([vm respondsToSelector:@selector(isWSVideo)] && ![vm isWSVideo]) {
        dd_log(@"[action] 非视频号 app 视频，忽略");
        return;
    }
    CMessageWrap *msg = dd_msg_of_cell(self);
    // 视频号：type=49 app 视频，路径在 m_oAppDataItem，下载走 StartDownloadAppAttach（与文件同通道）
    dd_media_to_voice(msg, ^NSString *{ return dd_appvideo_path_of_msg(msg); },
                          ^{ dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：文件消息 → 转语音

%hook AppFileMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].fileToVoiceEnabled;
    // ⚠ 这里一行都不要碰文件路径。
    // v1.0.2 修复：v1.0.1 在这一步同步调了 dd_file_path_of_msg()，它内部会打
    // CMessageWrap +GetPathOfAppData: / +GetPathOfAppDataByUserName:andMessageWrap:retStrPath:
    // 这类从未在真机上验证过参数契约的权威接口 → 长按文件消息时直接 SIGSEGV（用户实测「长按文件直接闪退」）。
    // 反汇编证据：WCRefine 的 WCRefineAppendVoiceToolsMediaMenuItems (0x8dd96c) 及其三个子追加器
    // sub_0x8ddae4 / sub_0x8dde20 / sub_0x8de1f8 在建菜单阶段只做四件事：
    //   读开关 → cell 类名判定 → 按 identifier 去重 → 造 MMMenuItem，
    // 一次都不解析路径。路径一律推迟到「点击」那一刻（本 hook 的 dd_mediaToVoice:）才去取。
    // 所以这里顶多留一条不含路径的诊断日志。
    if (on) {
        CMessageWrap *msg = dd_msg_of_cell(self);
        dd_log(@"[menu.file] localID=%u 注入「转语音」（路径延迟到点击时解析）",
              msg ? msg.m_uiMesLocalID : 0);
    }
    return dd_inject_items(self, original, on, @"转语音", @selector(dd_mediaToVoice:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_mediaToVoice:) &&
        [DDMediaConvertConfig shared].fileToVoiceEnabled) return YES;
    return %orig;
}
%new
- (void)dd_mediaToVoice:(id)sender {
    dd_log(@"[action] 点击「转语音」(文件消息)");
    CMessageWrap *msg = dd_msg_of_cell(self);
    // 扩展名诊断放在「点击」之后 —— 这里崩也是崩在一次明确的用户操作上，
    // 而不是像 v1.0.1 那样在长按弹菜单的过程中把整个微信带崩。
    // 注意：拿不到扩展名（那些「文件识别失败」的）也照样往下转，
    // dd_extract_pcm 会用 AVFoundation 自己判断素材能不能抽音轨。
    NSString *ext = dd_file_ext_of_msg(msg);
    BOOL audio = dd_file_is_audio(msg);
    BOOL landed = dd_file_ready_of_cell(self);   // 8.0.79 AppFileMessageViewModel.h:9
    dd_log(@"[action] 文件消息 ext=%@ 疑似音频=%d 已落地=%d —— 无论如何都尝试抽音轨",
          ext ?: @"(nil)", audio, landed);
    dd_media_to_voice(msg, ^NSString *{ return dd_file_path_of_msg(msg); },
                          ^{ dd_trigger_file_download(msg); });
}
%end

#pragma mark - Hook：语音消息 → 转文件

%hook VoiceMessageCellView
- (NSArray *)operationMenuItems {
    NSArray *original = %orig;
    BOOL on = [DDMediaConvertConfig shared].voiceToFileEnabled;
    return dd_inject_items(self, original, on, @"转文件", @selector(dd_voiceToFile:));
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(dd_voiceToFile:) &&
        [DDMediaConvertConfig shared].voiceToFileEnabled) return YES;
    return %orig;
}
%new
- (void)dd_voiceToFile:(id)sender {
    dd_log(@"[action] 点击「转文件」(语音消息)");
    dd_voice_to_file(dd_msg_of_cell(self));
}
%end

#pragma mark - 设置页（参考 DD语音助手；新增「调试日志」分组：导出 / 清空 / 开关）

@interface DDMediaConvertSettingsViewController : UIViewController <UITableViewDelegate>
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end
@implementation DDMediaConvertSettingsViewController {
    id<UITableViewDelegate> _originalDelegate;
}
- (void)ensureTableViewMgr {
    if (self.tableViewManager) return;
    self.tableViewManager = [[objc_getClass("WCTableViewManager") alloc]
                              initWithFrame:[UIScreen mainScreen].bounds
                                      style:UITableViewStyleInsetGrouped];
}
- (instancetype)init {
    if (self = [super init]) [self ensureTableViewMgr];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kDDPluginName;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.shadowColor = nil;
    self.navigationItem.standardAppearance = appearance;
    self.navigationItem.scrollEdgeAppearance = appearance;
    self.navigationItem.compactAppearance = appearance;
    [self ensureTableViewMgr];
    if (!self.tableViewManager) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewManager getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    _originalDelegate = self.tableViewManager.delegate;
    self.tableViewManager.delegate = self;
    dd_log(@"[settings] 设置页已加载（插件 %@ v%@）", kDDPluginName, kDDPluginVersion);
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self buildTable];   // 回到页面时刷新日志条数 / 大小
}
- (void)buildTable {
    if (!self.tableViewManager) return;
    [self.tableViewManager clearAllSection];
    Class cellMgr = objc_getClass("WCTableViewCellManager");
    Class secMgr  = objc_getClass("WCTableViewSectionManager");

    // 分组一：转换开关（sectionWithHeader: 不可用则回退 defaultSection，与 DD语音助手一致）
    WCTableViewSectionManager *sec = [secMgr respondsToSelector:@selector(sectionWithHeader:)]
        ? [secMgr sectionWithHeader:@"转换开关"] : [secMgr defaultSection];
    if (sec) {
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleVideoToVoice:)
                                        target:self
                                         title:@"视频转语音"
                                            on:[DDMediaConvertConfig shared].videoToVoiceEnabled]];
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleFileToVoice:)
                                        target:self
                                         title:@"文件转语音"
                                            on:[DDMediaConvertConfig shared].fileToVoiceEnabled]];
        [sec addCell:[cellMgr switchCellForSel:@selector(toggleVoiceToFile:)
                                        target:self
                                         title:@"语音转文件"
                                            on:[DDMediaConvertConfig shared].voiceToFileEnabled]];
        [self.tableViewManager addSection:sec];
    }

    // 分组二：调试日志（未越狱/自签证书看不到 syslog，日志在这里导出）
    WCTableViewSectionManager *logSec = [secMgr respondsToSelector:@selector(sectionWithHeader:)]
        ? [secMgr sectionWithHeader:@"调试日志"] : [secMgr defaultSection];
    if (logSec) {
        [logSec addCell:[cellMgr switchCellForSel:@selector(toggleLog:)
                                           target:self
                                            title:@"记录调试日志"
                                               on:[DDMediaConvertConfig shared].logEnabled]];
        DDLogStore *store = [DDLogStore shared];
        NSString *cnt = [NSString stringWithFormat:@"%lu 条 / %.0f KB",
                         (unsigned long)[store lineCount], [store fileSize] / 1024.0];
        // 点击由 WCTableViewManager 内部按 cellInfo 的 sel+target 自动派发（与 DD语音助手机制一致）
        [logSec addCell:[cellMgr normalCellForSel:@selector(ddExportLog:)
                                           target:self
                                            title:@"导出日志"
                                       rightValue:cnt]];
        [logSec addCell:[cellMgr normalCellForSel:nil
                                           target:nil
                                            title:@"插件版本"
                                       rightValue:kDDPluginVersion]];
        [logSec addCell:[cellMgr normalCellForSel:@selector(ddClearLog:)
                                           target:self
                                            title:@"清空日志"
                                       rightValue:@""]];
        [self.tableViewManager addSection:logSec];
    }
    [self.tableViewManager reloadTableView];
}
- (void)toggleVideoToVoice:(UISwitch *)s {
    [DDMediaConvertConfig shared].videoToVoiceEnabled = s.on;
    dd_log(@"[settings] 视频转语音 = %d", s.on);
}
- (void)toggleFileToVoice:(UISwitch *)s {
    [DDMediaConvertConfig shared].fileToVoiceEnabled = s.on;
    dd_log(@"[settings] 文件转语音 = %d", s.on);
}
- (void)toggleVoiceToFile:(UISwitch *)s {
    [DDMediaConvertConfig shared].voiceToFileEnabled = s.on;
    dd_log(@"[settings] 语音转文件 = %d", s.on);
}
- (void)toggleLog:(UISwitch *)s {
    [DDMediaConvertConfig shared].logEnabled = s.on;
    [DDLogStore shared].enabled = s.on;
    dd_log(@"[settings] 记录调试日志 = %d", s.on);
}

#pragma mark 日志导出 / 清空（点击由 WCTableViewManager 内部按 cellInfo 的 sel 派发，无需自己处理）

- (void)ddExportLog:(id)sender {
    NSString *path = dd_log_export_path();
    NSUInteger n = [[DDLogStore shared] lineCount];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"日志已导出"
                         message:[NSString stringWithFormat:@"%@\n共 %lu 条\n\n可用「分享/存储」保存到文件 App 或隔空投送。",
                                  path.lastPathComponent, (unsigned long)n]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"分享/存储"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSURL *url = [NSURL fileURLWithPath:path];
        UIActivityViewController *av = [[UIActivityViewController alloc]
                                        initWithActivityItems:@[url] applicationActivities:nil];
        av.popoverPresentationController.sourceView = self.view;
        av.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
        [self presentViewController:av animated:YES completion:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制全文"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        NSString *text = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
        [UIPasteboard generalPasteboard].string = text ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制路径"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = path ?: @"";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)ddClearLog:(id)sender {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"清空日志"
                         message:@"将清空内存缓冲与日志文件，确定？"
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[DDLogStore shared] clearAll];
        dd_log(@"[settings] 日志已清空，重新开始记录");
        [self buildTable];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark 点击事件转发微信原 delegate（与 DD语音助手一致：cellInfo 的 sel 由 WCTableViewManager 内部派发）

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])
        [_originalDelegate tableView:tableView didSelectRowAtIndexPath:indexPath];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
        return [_originalDelegate tableView:tableView heightForRowAtIndexPath:indexPath];
    return UITableViewAutomaticDimension;
}
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 微信 cell 的样式/分隔线由原 delegate 绘制，必须转发（与 DD语音助手一致）
    if (_originalDelegate && [_originalDelegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)])
        [_originalDelegate tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
}
@end

#pragma mark - 注册入口（参考 DD语音助手）

%ctor {
    @autoreleasepool {
        // 日志开关在启动时同步一次（用户上次可能关闭过）
        [DDLogStore shared].enabled = [DDMediaConvertConfig shared].logEnabled;
        dd_log(@"[ctor] %@ v%@ 已加载", kDDPluginName, kDDPluginVersion);
        [[objc_getClass("WCPluginsMgr") sharedInstance]
            registerControllerWithTitle:kDDPluginName
                                version:kDDPluginVersion
                             controller:@"DDMediaConvertSettingsViewController"];
        dd_log(@"[ctor] 注册入口完成：%@ v%@", kDDPluginName, kDDPluginVersion);
    }
}

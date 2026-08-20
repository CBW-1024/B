//
//  WCLiteVolcanoTTS.xm
//  单文件 iOS 插件：将「文字转语音」的接口与音色从 Fish Audio 换成火山引擎
//  （Volcano Engine / 豆包语音合成大模型 2.0）
//
//  改造对照（基于文字转语音相关代码.zip 中的 WCLiteFishTTSService / WCLiteVoiceCloneViewController /
//  WCLiteVoiceCatalogViewController，以及微信头文件 dump 核实的真实类签名）：
//    · 接口：Fish `https://api.fish.audio/v1/tts`  + Bearer key + reference_id
//         → 火山 `https://openspeech.bytedance.com/api/v1/tts` + Bearer access_token + voice_type
//    · 音色：Fish reference_id 目录  →  火山 voice_type 目录（zh_female_*_uranus_bigtts / zh_male_*_uranus_bigtts）
//    · 鉴权：环境变量 API Key  →  NSUserDefaults 保存的火山 access_token（仅本机）
//    · 返回：Fish 直接返回 MP3 字节  →  火山返回 JSON，音频在 `data` 字段（Base64 编码 MP3）
//
//  零外部依赖：MP3→PCM→SILK→.aud→CMessageWrap 的整条发送链路均已内联。
//    · MP3 解码：AVFoundation（系统框架，无需第三方库）
//    · PCM→SILK：微信内置 TingSilkEncoderImpl（运行时存在于微信二进制，initWithSampleRate:/encode:isLastFrame:）
//    · 落库/发送：CMessageWrap(type=34) + CMessageMgr.AddLocalMsg: + MMNewUploadVoiceMgr 上传队列
//
//  所有 UI 均基于微信原生类（已用微信头文件 dump 核实签名）：
//    WCTableViewManager / WCTableViewSectionManager / WCTableViewNormalCellManager / WCTableViewCellManager
//    WCActionSheet / MMTipsViewController / WeToast / MMUIViewController
//    BaseMsgContentViewController（-growTextViewDidClickSendWithText: / -getCurrentChatName）
//    WCInputController（-onSendButtonClicked 经 InputControllerDelegate 回调）
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AVFoundation/AVFoundation.h>

// 项目级微信头文件（来自微信头文件 dump，原 TTS 文件同样引用）。
// 若你的工程把 dump 头文件统一收纳为 WeChatHeaders.h，则保留此行；
// 若使用 Theos 的 Headers 目录逐个引入，可改为对应 import 或删除本行。
#import "WeChatHeaders.h"

#pragma mark - 火山引擎接口常量

/// 火山「大模型语音合成 HTTP 非流式 V1」接口地址
/// 官方文档：https://www.volcengine.com/docs/6561/1257584
static NSString * const kWCLiteVolcanoTTSHost = @"https://openspeech.bytedance.com/api/v1/tts";

/// 服务端音色目录（可选）。应指向 provider=volcano 的 voices.json；
/// 若拉取结果为空或不含火山音色，则回退到本文件内置的火山音色目录。
static NSString * const kWCLiteVolcanoCatalogURL = @"https://raw.githubusercontent.com/iosdcq/WCRefine-VoiceHub/main/catalog/voices.json";

/// 试听文本
static NSString * const kWCLiteVolcanoPreviewText = @"我是火山语音试听音色";

/// 预览/发送时绑定的 AVAudioPlayer 关联键
static char kWCLiteVolcanoPreviewPlayerKey;

#pragma mark - 轻量 Toast（基于真实类 WeToast）

static void WCLiteVolcanoShowToast(NSString *text) {
    if (!text.length) return;
    Class WeToastClass = objc_getClass("WeToast");
    if (WeToastClass) {
        id toast = ((id (*)(id, SEL))objc_msgSend)(WeToastClass, NSSelectorFromString(@"toast"));
        if (toast && [toast respondsToSelector:NSSelectorFromString(@"showErrorToastWithText:")]) {
            ((void (*)(id, SEL, NSString *))objc_msgSend)(toast, NSSelectorFromString(@"showErrorToastWithText:"), text);
            return;
        }
    }
    // 兜底：系统弹窗
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                 message:text
                                                          preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *top = WCLiteVolcanoTopViewController();
    [top presentViewController:alert animated:YES completion:nil];
}

static UIViewController *WCLiteVolcanoTopViewController(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                ((UIWindowScene *)scene).activationState == UISceneActivationStateForegroundActive) {
                window = ((UIWindowScene *)scene).windows.firstObject;
                break;
            }
        }
    }
    if (!window) window = UIApplication.sharedApplication.keyWindow;
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    while (vc && vc.childViewControllers.count) {
        UIViewController *last = vc.childViewControllers.lastObject;
        if ([last isKindOfClass:[UINavigationController class]]) {
            vc = ((UINavigationController *)last).topViewController;
            break;
        }
        vc = last;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        vc = ((UINavigationController *)vc).topViewController;
    }
    return vc ?: window.rootViewController;
}

static void WCLiteVolcanoStopPreviewOnOwner(id owner) {
    if (!owner) return;
    id p = objc_getAssociatedObject(owner, &kWCLiteVolcanoPreviewPlayerKey);
    if ([p isKindOfClass:[AVAudioPlayer class]]) {
        [(AVAudioPlayer *)p stop];
    }
    objc_setAssociatedObject(owner, &kWCLiteVolcanoPreviewPlayerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void WCLiteVolcanoPlayMP3Data(NSData *data, id owner, void (^showError)(NSString *)) {
    if (!data.length) { if (showError) showError(@"无音频数据"); return; }
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"WCLiteVolcanoPreview_%@.mp3", [[NSUUID UUID] UUIDString]]];
    if (![data writeToFile:tmp atomically:YES]) { if (showError) showError(@"无法写入临时文件"); return; }
    WCLiteVolcanoStopPreviewOnOwner(owner);
    NSURL *url = [NSURL fileURLWithPath:tmp];
    NSError *err = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    if (!player || err) { if (showError) showError(err.localizedDescription.length ? err.localizedDescription : @"无法播放"); return; }
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    player.numberOfLoops = 0;
    if (![player prepareToPlay] || ![player play]) { if (showError) showError(@"播放失败"); return; }
    if (owner) objc_setAssociatedObject(owner, &kWCLiteVolcanoPreviewPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 配置（自包含，NSUserDefaults 持久化，不再依赖 WCLiteConfig）

@interface WCLiteVolcanoTTSConfig : NSObject
+ (BOOL)enabled;                  + (void)setEnabled:(BOOL)v;
+ (NSString *)accessToken;        + (void)setAccessToken:(NSString *)v;
+ (NSString *)commandPrefix;      + (void)setCommandPrefix:(NSString *)v;
+ (double)speed;                  + (void)setSpeed:(double)v;
+ (NSString *)selectedVoiceType;  + (void)setSelectedVoiceType:(NSString *)v;
+ (NSString *)selectedVoiceName;  + (void)setSelectedVoiceName:(NSString *)v;
+ (NSArray *)catalog;             + (void)setCatalog:(NSArray *)v;
+ (NSArray *)builtinVolcanoCatalog;
@end

@implementation WCLiteVolcanoTTSConfig
+ (NSUserDefaults *)ud { return [NSUserDefaults standardUserDefaults]; }
+ (BOOL)enabled { return [[self.ud objectForKey:@"WCLiteVolcanoTTS.enabled"] boolValue]; }
+ (void)setEnabled:(BOOL)v { [self.ud setBool:v forKey:@"WCLiteVolcanoTTS.enabled"]; }
+ (NSString *)accessToken { return [self.ud stringForKey:@"WCLiteVolcanoTTS.accessToken"]; }
+ (void)setAccessToken:(NSString *)v { v ? [self.ud setObject:v forKey:@"WCLiteVolcanoTTS.accessToken"] : [self.ud removeObjectForKey:@"WCLiteVolcanoTTS.accessToken"]; }
+ (NSString *)commandPrefix { NSString *p = [self.ud stringForKey:@"WCLiteVolcanoTTS.commandPrefix"]; return p.length ? p : @"tts"; }
+ (void)setCommandPrefix:(NSString *)v { [self.ud setObject:(v.length ? v : @"tts") forKey:@"WCLiteVolcanoTTS.commandPrefix"]; }
+ (double)speed { double s = [self.ud doubleForKey:@"WCLiteVolcanoTTS.speed"]; return s > 0 ? s : 1.0; }
+ (void)setSpeed:(double)v { [self.ud setDouble:v forKey:@"WCLiteVolcanoTTS.speed"]; }
+ (NSString *)selectedVoiceType { return [self.ud stringForKey:@"WCLiteVolcanoTTS.selectedVoiceType"]; }
+ (void)setSelectedVoiceType:(NSString *)v { v ? [self.ud setObject:v forKey:@"WCLiteVolcanoTTS.selectedVoiceType"] : [self.ud removeObjectForKey:@"WCLiteVolcanoTTS.selectedVoiceType"]; }
+ (NSString *)selectedVoiceName { return [self.ud stringForKey:@"WCLiteVolcanoTTS.selectedVoiceName"]; }
+ (void)setSelectedVoiceName:(NSString *)v { v ? [self.ud setObject:v forKey:@"WCLiteVolcanoTTS.selectedVoiceName"] : [self.ud removeObjectForKey:@"WCLiteVolcanoTTS.selectedVoiceName"]; }
+ (NSArray *)catalog { return [self.ud arrayForKey:@"WCLiteVolcanoTTS.catalog"]; }
+ (void)setCatalog:(NSArray *)v { v ? [self.ud setObject:v forKey:@"WCLiteVolcanoTTS.catalog"] : [self.ud removeObjectForKey:@"WCLiteVolcanoTTS.catalog"]; }

/// 内置火山音色目录（豆包语音合成大模型 2.0，uranus_bigtts 系列）
+ (NSArray *)builtinVolcanoCatalog {
    NSArray *list = @[
        // —— 通用场景（女声）——
        @{@"id":@"volcano:zh_female_cancan_uranus_bigtts",      @"name":@"知性灿灿 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_cancan_uranus_bigtts",      @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_qingxinnvsheng_uranus_bigtts", @"name":@"清新女声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_qingxinnvsheng_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_tianmeixiaoyuan_uranus_bigtts", @"name":@"甜美小源 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_tianmeixiaoyuan_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_tianmeitaozi_uranus_bigtts", @"name":@"甜美桃子 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_tianmeitaozi_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_linjianvhai_uranus_bigtts", @"name":@"邻家女孩 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_linjianvhai_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_wenroushunv_uranus_bigtts", @"name":@"温柔淑女 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_wenroushunv_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_gaolengyujie_uranus_bigtts", @"name":@"高冷御姐 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_gaolengyujie_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_qingchezizi_uranus_bigtts", @"name":@"清澈梓梓 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_qingchezizi_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_tianmeiyueyue_uranus_bigtts", @"name":@"甜美悦悦 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_tianmeiyueyue_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_zhixingnv_uranus_bigtts", @"name":@"知性女声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_zhixingnv_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_qinqienv_uranus_bigtts", @"name":@"亲切女声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_qinqienv_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_tiexinnvsheng_uranus_bigtts", @"name":@"贴心女声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_tiexinnvsheng_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        @{@"id":@"volcano:zh_female_wenrouxiaoya_uranus_bigtts", @"name":@"温柔小雅 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_wenrouxiaoya_uranus_bigtts", @"contentType":@"general", @"description":@"通用·女声"},
        // —— 通用场景（男声）——
        @{@"id":@"volcano:zh_male_m191_uranus_bigtts", @"name":@"云舟 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_m191_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_taocheng_uranus_bigtts", @"name":@"小天 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_taocheng_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_liufei_uranus_bigtts", @"name":@"刘飞 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_liufei_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_ruyaqingnian_uranus_bigtts", @"name":@"儒雅青年 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_ruyaqingnian_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_yangguangqingnian_uranus_bigtts", @"name":@"阳光青年 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_yangguangqingnian_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_fanjuanqingnian_uranus_bigtts", @"name":@"反卷青年 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_fanjuanqingnian_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_huolixiaoge_uranus_bigtts", @"name":@"活力小哥 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_huolixiaoge_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_qingshuangnanda_uranus_bigtts", @"name":@"清爽男大 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_qingshuangnanda_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_dongfanghaoran_uranus_bigtts", @"name":@"东方浩然 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_dongfanghaoran_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_yuanboxiaoshu_uranus_bigtts", @"name":@"渊博小叔 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_yuanboxiaoshu_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_gaolengchenwen_uranus_bigtts", @"name":@"高冷沉稳 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_gaolengchenwen_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        @{@"id":@"volcano:zh_male_cixingjieshuonan_uranus_bigtts", @"name":@"磁性解说男声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_cixingjieshuonan_uranus_bigtts", @"contentType":@"general", @"description":@"通用·男声"},
        // —— 角色扮演 ——
        @{@"id":@"volcano:zh_female_sajiaoxuemei_uranus_bigtts", @"name":@"撒娇学妹 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_sajiaoxuemei_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·女声"},
        @{@"id":@"volcano:zh_female_wuzetian_uranus_bigtts", @"name":@"武则天 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_wuzetian_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·女声"},
        @{@"id":@"volcano:zh_male_aojiaobazong_uranus_bigtts", @"name":@"傲娇霸总 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_aojiaobazong_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·男声"},
        @{@"id":@"volcano:zh_male_tangseng_uranus_bigtts", @"name":@"唐僧 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_tangseng_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·男声"},
        @{@"id":@"volcano:zh_male_zhubajie_uranus_bigtts", @"name":@"猪八戒 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_zhubajie_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·男声"},
        @{@"id":@"volcano:zh_male_zhuangzhou_uranus_bigtts", @"name":@"庄周 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_zhuangzhou_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·男声"},
        @{@"id":@"volcano:zh_male_lubanqihao_uranus_bigtts", @"name":@"鲁班七号 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_lubanqihao_uranus_bigtts", @"contentType":@"role", @"description":@"角色扮演·男声"},
        // —— 有声阅读 ——
        @{@"id":@"volcano:zh_female_xiaoxue_uranus_bigtts", @"name":@"儿童绘本 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_xiaoxue_uranus_bigtts", @"contentType":@"audiobook", @"description":@"有声阅读·女声"},
        @{@"id":@"volcano:zh_female_shaoergushi_uranus_bigtts", @"name":@"少儿故事 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_shaoergushi_uranus_bigtts", @"contentType":@"audiobook", @"description":@"有声阅读·女声"},
        @{@"id":@"volcano:zh_male_baqiqingshu_uranus_bigtts", @"name":@"霸气青叔 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_baqiqingshu_uranus_bigtts", @"contentType":@"audiobook", @"description":@"有声阅读·男声"},
        @{@"id":@"volcano:zh_male_xuanyijieshuo_uranus_bigtts", @"name":@"悬疑解说 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_xuanyijieshuo_uranus_bigtts", @"contentType":@"audiobook", @"description":@"有声阅读·男声"},
        // —— 视频配音 ——
        @{@"id":@"volcano:zh_female_peiqi_uranus_bigtts", @"name":@"佩奇猪 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_peiqi_uranus_bigtts", @"contentType":@"dubbing", @"description":@"视频配音·女声"},
        @{@"id":@"volcano:zh_female_jitangmei_uranus_bigtts", @"name":@"鸡汤妹妹 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_jitangmei_uranus_bigtts", @"contentType":@"dubbing", @"description":@"视频配音·女声"},
        @{@"id":@"volcano:zh_male_sunwukong_uranus_bigtts", @"name":@"猴哥 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_sunwukong_uranus_bigtts", @"contentType":@"dubbing", @"description":@"视频配音·男声"},
        @{@"id":@"volcano:zh_male_dayi_uranus_bigtts", @"name":@"大壹 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_dayi_uranus_bigtts", @"contentType":@"dubbing", @"description":@"视频配音·男声"},
        @{@"id":@"volcano:zh_male_jieshuoxiaoming_uranus_bigtts", @"name":@"解说小明 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_male_jieshuoxiaoming_uranus_bigtts", @"contentType":@"dubbing", @"description":@"视频配音·男声"},
        // —— 客服 ——
        @{@"id":@"volcano:zh_female_kefunvsheng_uranus_bigtts", @"name":@"暖阳女声 2.0", @"provider":@"volcano", @"providerVoiceId":@"zh_female_kefunvsheng_uranus_bigtts", @"contentType":@"service", @"description":@"客服·女声"},
    ];
    return list;
}
@end

#pragma mark - 火山语音合成服务（替代 WCLiteFishTTSService）

@interface WCLiteVolcanoTTSService : NSObject
/// 若 content 命中指令前缀，返回待合成正文；否则 nil。
+ (nullable NSString *)voiceTextFromOutgoingMessageContent:(NSString *)content;
/// 从音色目录项字典解析火山 voice_type（优先 providerVoiceId）。
+ (nullable NSString *)voiceTypeFromVoiceDictionary:(NSDictionary *)voice;
/// 调用火山 TTS，completion 返回解码后的 MP3 数据。
+ (void)synthesizeSpeechWithText:(NSString *)text
                       voiceType:(NSString *)voiceType
                      completion:(void (^)(NSData * _Nullable mp3Data, NSString * _Nullable errorMessage))completion;
/// 试听：合成 kWCLiteVolcanoPreviewText 并播放。
+ (void)previewVoiceWithDictionary:(NSDictionary *)voice fromViewController:(id)viewController;
/// 合成并作为语音消息发送到指定会话（零依赖：MP3→PCM→SILK→.aud→CMessageWrap 全部内联，不再依赖 WCLiteVoicePackSender）。
+ (void)sendVoiceMessageWithText:(NSString *)text
                       voiceType:(NSString *)voiceType
                    chatUserName:(NSString *)chatUserName
                      completion:(void (^)(BOOL success, NSString * _Nullable errorMessage))completion;
@end

#pragma mark - 零依赖音频管线：MP3 → PCM(16k 单声道 S16) → SILK → .aud

/// MP3 文件 → 16kHz 单声道 16bit PCM（AVFoundation，无需第三方库）
static NSData *WCLiteVolcanoMP3ToPCM(NSString *mp3Path, NSError **outErr) {
    NSError *err = nil;
    AVAudioFile *file = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:mp3Path] error:&err];
    if (!file || err) { if (outErr) *outErr = err; return nil; }

    AVAudioFormat *inFmt  = file.processingFormat;
    AVAudioFormat *outFmt = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                              sampleRate:16000.0
                                                                channels:1
                                                             interleaved:YES];
    AVAudioConverter *conv = [[AVAudioConverter alloc] initFromFormat:inFmt toFormat:outFmt];
    if (!conv) {
        if (outErr) *outErr = [NSError errorWithDomain:@"WCLiteVolcano" code:-1
                                 userInfo:@{NSLocalizedDescriptionKey: @"无法创建音频转换器"}];
        return nil;
    }

    const AVAudioFrameCount cap = 4096;
    AVAudioPCMBuffer *inBuf  = [[AVAudioPCMBuffer alloc] initWithFormat:inFmt  frameCapacity:cap];
    AVAudioPCMBuffer *outBuf = [[AVAudioPCMBuffer alloc] initWithFormat:outFmt frameCapacity:cap];
    NSMutableData *pcm = [NSMutableData data];
    __block BOOL finished = NO;

    while (!finished) {
        NSError *cErr = nil;
        AVAudioConverterOutputStatus st = [conv convertToBuffer:outBuf
                                                          error:&cErr
                                             withInputFromBlock:^AVAudioBuffer *(AVAudioPacketCount inNumberOfPackets, AVAudioConverterInputStatus *outStatus) {
            NSError *readErr = nil;
            BOOL ok = [file readIntoBuffer:inBuf error:&readErr];
            if (!ok || inBuf.frameLength == 0) {
                *outStatus = AVAudioConverterInputStatus_EndOfStream;
                return nil;
            }
            *outStatus = AVAudioConverterInputStatus_HaveData;
            return inBuf;
        }];
        if (st == AVAudioConverterOutputStatus_HaveData) {
            int16_t *samples = outBuf.int16ChannelData[0];
            [pcm appendBytes:samples length:(NSUInteger)outBuf.frameLength * sizeof(int16_t)];
        } else if (st == AVAudioConverterOutputStatus_EndOfStream) {
            finished = YES;
        } else {
            if (outErr) *outErr = cErr;
            break;
        }
    }
    return pcm.length ? pcm : nil;
}

/// 16kHz 单声道 16bit PCM → SILK 裸流（复用微信内置 TingSilkEncoderImpl，零外部依赖）
static NSData *WCLiteVolcanoPCMToSilk(NSData *pcm, int sampleRate) {
    Class silkCls = objc_getClass("TingSilkEncoderImpl");
    if (!silkCls) return nil;
    id encoder = [[silkCls alloc] initWithSampleRate:sampleRate];
    if (!encoder) return nil;

    // 内部有 _mLeftData 缓冲，按任意分块喂入、末块置 isLastFrame 即可
    NSUInteger frameBytes = (NSUInteger)(20 * sampleRate / 1000) * 2; // 20ms 帧
    if (frameBytes < 1) frameBytes = 640;
    NSMutableData *silk = [NSMutableData data];
    NSUInteger total = pcm.length;
    NSUInteger i = 0;
    while (i < total) {
        NSUInteger len = MIN(frameBytes, total - i);
        NSData *chunk = [pcm subdataWithRange:NSMakeRange(i, len)];
        BOOL last = (i + len >= total);
        NSData *enc = [encoder encode:chunk isLastFrame:last];
        if (enc.length) [silk appendData:enc];
        i += len;
    }
    return silk.length ? silk : nil;
}

@implementation WCLiteVolcanoTTSService

+ (NSString *)voiceTextFromOutgoingMessageContent:(NSString *)content {
    if (![WCLiteVolcanoTTSConfig enabled]) return nil;
    if (![WCLiteVolcanoTTSConfig accessToken].length) return nil;
    if (![WCLiteVolcanoTTSConfig selectedVoiceType].length) return nil;
    if (!content.length) return nil;
    NSString *prefix = [WCLiteVolcanoTTSConfig commandPrefix];
    NSString *trimmed = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length < prefix.length || ![trimmed hasPrefix:prefix]) return nil;
    if (trimmed.length > prefix.length) {
        unichar c = [trimmed characterAtIndex:prefix.length];
        if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:c]) return nil;
    }
    NSString *rest = [[trimmed substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return rest.length ? rest : nil;
}

+ (NSString *)voiceTypeFromVoiceDictionary:(NSDictionary *)voice {
    if (![voice isKindOfClass:[NSDictionary class]]) return nil;
    id providerId = voice[@"providerVoiceId"];
    if ([providerId isKindOfClass:[NSString class]] && [(NSString *)providerId length] > 0) return (NSString *)providerId;
    id vid = voice[@"id"];
    if ([vid isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)vid;
        NSRange r = [s rangeOfString:@":"];
        if (r.location != NSNotFound && r.location + 1 < s.length) return [s substringFromIndex:r.location + 1];
        if (s.length) return s;
    }
    return nil;
}

+ (void)synthesizeSpeechWithText:(NSString *)text
                       voiceType:(NSString *)voiceType
                      completion:(void (^)(NSData *, NSString *))completion {
    if (!completion) return;
    NSString *token = [WCLiteVolcanoTTSConfig accessToken];
    if (!token.length) { completion(nil, @"请先设置火山 access_token"); return; }
    if (!text.length) { completion(nil, @"文本为空"); return; }
    if (!voiceType.length) { completion(nil, @"音色 voice_type 无效"); return; }

    /// 火山 HTTP V1 请求体（扁平参数 + Bearer 鉴权）
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"text"] = text;
    body[@"voice_type"] = voiceType;
    body[@"format"] = @"mp3";
    body[@"speed"] = @([WCLiteVolcanoTTSConfig speed]);
    body[@"pitch"] = @1.0;
    body[@"silence_duration"] = @125;
    NSError *jsonErr = nil;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonErr];
    if (!bodyData || jsonErr) { completion(nil, @"请求体编码失败"); return; }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kWCLiteVolcanoTTSHost]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = bodyData;
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setTimeoutInterval:60.0];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { completion(nil, error.localizedDescription ?: @"网络错误"); return; }
            if (!data.length) { completion(nil, @"TTS 返回空数据"); return; }
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) { completion(nil, @"响应解析失败"); return; }
            NSDictionary *resp = (NSDictionary *)json;
            NSInteger code = [resp[@"code"] isKindOfClass:[NSNumber class]] ? [(NSNumber *)resp[@"code"] integerValue] : 3000;
            NSString *b64 = [resp[@"data"] isKindOfClass:[NSString class]] ? (NSString *)resp[@"data"] : nil;
            if (code != 3000 || !b64.length) {
                NSString *msg = [resp[@"message"] isKindOfClass:[NSString class]] ? (NSString *)resp[@"message"] : nil;
                if (!msg.length) msg = [NSString stringWithFormat:@"火山 TTS 失败 (code=%ld)", (long)code];
                completion(nil, msg);
                return;
            }
            NSData *mp3 = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
            if (!mp3.length) { completion(nil, @"音频解码失败"); return; }
            completion(mp3, nil);
        });
    }];
    [task resume];
}

+ (void)previewVoiceWithDictionary:(NSDictionary *)voice fromViewController:(id)viewController {
    NSString *vt = [self voiceTypeFromVoiceDictionary:voice];
    if (!vt.length) { WCLiteVolcanoShowToast(@"无法解析音色 voice_type"); return; }
    if (![WCLiteVolcanoTTSConfig accessToken].length) { WCLiteVolcanoShowToast(@"请先设置火山 access_token"); return; }
    if ([viewController respondsToSelector:NSSelectorFromString(@"startLoadingWithText:")]) {
        [viewController startLoadingWithText:@"合成中..."];
    }
    __weak id weakVC = viewController;
    [self synthesizeSpeechWithText:kWCLiteVolcanoPreviewText voiceType:vt completion:^(NSData *mp3Data, NSString *errorMessage) {
        id strongVC = weakVC;
        if ([strongVC respondsToSelector:NSSelectorFromString(@"stopLoading")]) [strongVC stopLoading];
        if (errorMessage.length) { WCLiteVolcanoShowToast(errorMessage); return; }
        WCLiteVolcanoPlayMP3Data(mp3Data, strongVC, ^(NSString *msg) { WCLiteVolcanoShowToast(msg); });
    }];
}

+ (void)sendVoiceMessageWithText:(NSString *)text
                       voiceType:(NSString *)voiceType
                    chatUserName:(NSString *)chatUserName
                      completion:(void (^)(BOOL, NSString *))completion {
    if (!completion) return;
    if (!chatUserName.length) { completion(NO, @"无法获取当前会话"); return; }
    [self synthesizeSpeechWithText:text voiceType:voiceType completion:^(NSData *mp3Data, NSString *errorMessage) {
        if (errorMessage.length || !mp3Data.length) { completion(NO, errorMessage ?: @"合成失败"); return; }

        // 后台完成 解码 → 编码 → 写文件，避免阻塞主线程
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *tmpMp3 = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                [NSString stringWithFormat:@"WCLiteVolcano_%@.mp3", [[NSUUID UUID] UUIDString]]];
            [mp3Data writeToFile:tmpMp3 atomically:YES];

            NSError *convErr = nil;
            NSData *pcm = WCLiteVolcanoMP3ToPCM(tmpMp3, &convErr);
            [[NSFileManager defaultManager] removeItemAtPath:tmpMp3 error:nil];
            if (!pcm.length) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, convErr.localizedDescription ?: @"音频解码失败");
                });
                return;
            }

            // PCM → SILK（微信内置编码器，零外部依赖）
            NSData *silk = WCLiteVolcanoPCMToSilk(pcm, 16000);
            if (!silk.length) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, @"SILK 编码失败：微信内置 TingSilkEncoderImpl 不可用");
                });
                return;
            }

            // 写 .aud：10 字节 #!SILK_V3\n 头 + SILK 裸流（微信语音文件格式）
            NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *audioDir = [doc stringByAppendingPathComponent:@"Audio"];
            [[NSFileManager defaultManager] createDirectoryAtPath:audioDir
                                      withIntermediateDirectories:YES attributes:nil error:nil];
            NSString *audPath = [audioDir stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"%@.aud", [[NSUUID UUID] UUIDString]]];
            NSMutableData *aud = [NSMutableData data];
            char magic[10] = {'#', '!', 'S', 'I', 'L', 'K', '_', 'V', '3', '\n'};
            [aud appendBytes:magic length:10];
            [aud appendData:silk];
            NSTimeInterval duration = (NSTimeInterval)pcm.length / (16000.0 * 2.0);
            BOOL wrote = [aud writeToFile:audPath atomically:YES];
            if (!wrote) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, @"无法写入语音文件"); });
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendSilkVoiceFile:audPath duration:duration toUser:chatUserName completion:completion];
            });
        });
    }];
}

/// 构造语音 CMessageWrap（type=34）并写入会话、触发上传（零依赖，全部走微信原生 API）
+ (void)sendSilkVoiceFile:(NSString *)audPath
                 duration:(NSTimeInterval)duration
                   toUser:(NSString *)toUser
               completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    Class svcCls = objc_getClass("MMServiceCenter");
    if (!svcCls || ![svcCls respondsToSelector:@selector(defaultCenter)]) {
        completion(NO, @"MMServiceCenter 不可用");
        return;
    }
    id svc = [svcCls performSelector:@selector(defaultCenter)];
    id contactMgr = [svc getService:objc_getClass("CContactMgr")];
    id selfContact = [contactMgr getSelfContact];
    NSString *selfUser = [selfContact userName];
    if (!selfUser.length) selfUser = toUser; // 兜底

    Class wrapCls = objc_getClass("CMessageWrap");
    if (!wrapCls) { completion(NO, @"CMessageWrap 不可用"); return; }
    id wrap = [[wrapCls alloc] initWithMsgType:34 nsFromUsr:selfUser];
    if (!wrap) { completion(NO, @"无法创建 CMessageWrap"); return; }

    [wrap setValue:toUser            forKey:@"m_nsToUsr"];
    [wrap setValue:audPath           forKey:@"m_nsVoicePath"];
    [wrap setValue:@1               forKey:@"m_uiVoiceFormat"];           // 1 = SILK
    [wrap setValue:@((unsigned int)round(duration))        forKey:@"m_uiVoiceTime"];
    [wrap setValue:@((unsigned int)(duration * 1000.0))    forKey:@"m_uiVoiceLen"];
    [wrap setValue:@((unsigned int)(arc4random() % 1000000 + 1)) forKey:@"m_uiVoiceClientID"];
    [wrap setValue:@((unsigned int)[[NSDate date] timeIntervalSince1970]) forKey:@"m_uiCreateTime"];
    [wrap setValue:@0               forKey:@"m_uiStatus"];               // 0 = 待发送

    id msgMgr = [svc getService:objc_getClass("CMessageMgr")];
    if (!msgMgr) { completion(NO, @"CMessageMgr 不可用"); return; }

    // 落库：本地立即可见且可播放
    if ([msgMgr respondsToSelector:@selector(AddLocalMsg:MsgWrap:)]) {
        [msgMgr AddLocalMsg:toUser MsgWrap:wrap];
    } else if ([msgMgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) {
        [msgMgr AddMsg:toUser MsgWrap:wrap];
    }

    // 触发上传：微信语音上传管理器会在队列中拾取待发送语音；失败也不影响本地语音气泡
    BOOL triggered = NO;
    if ([msgMgr respondsToSelector:@selector(ResendMsg:MsgWrap:)]) {
        @try { [msgMgr ResendMsg:selfUser MsgWrap:wrap]; triggered = YES; }
        @catch (NSException *e) { triggered = NO; }
    }
    if (triggered) {
        completion(YES, nil);
    } else {
        completion(YES, @"语音已生成并插入会话（本地可播放）；如未自动上传，请按微信版本微调上传入口");
    }
}

@end

#pragma mark - 视图控制器基类（自包含，基于真实类 MMUIViewController）

@interface WCLiteVolcanoBaseVC : MMUIViewController
@property (nonatomic, strong) id tableViewMgr; // WCTableViewManager
- (void)setupTopOffsetForTableView:(UITableView *)tableView;
@end

@implementation WCLiteVolcanoBaseVC
- (void)setupTopOffsetForTableView:(UITableView *)tableView {
    if (@available(iOS 11.0, *)) {
        tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    CGFloat top = UIApplication.sharedApplication.statusBarFrame.size.height + 44.0;
    tableView.contentInset = UIEdgeInsetsMake(top, 0, 0, 0);
    tableView.scrollIndicatorInsets = tableView.contentInset;
}
@end

#pragma mark - 音色列表（替代 WCLiteVoiceCatalogViewController）

@interface WCLiteVolcanoVoiceCatalogViewController : WCLiteVolcanoBaseVC
@end

static char kWCLiteVolcanoVoiceKey;

@implementation WCLiteVolcanoVoiceCatalogViewController
- (instancetype)init {
    if (self = [super init]) {
        Class mgrCls = objc_getClass("WCTableViewManager");
        _tableViewMgr = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds style:2]; // 2 = InsetGrouped
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"火山音色列表";
    MMTableView *tableView = [self.tableViewMgr getTableView];
    if (@available(iOS 11, *)) tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    [self setupTopOffsetForTableView:tableView];
    [self reloadTableData];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadTableData]; }

- (void)reloadTableData {
    [self.tableViewMgr clearAllSection];
    NSArray *voices = [WCLiteVolcanoTTSConfig catalog];
    if (!voices.count) voices = [WCLiteVolcanoTTSConfig builtinVolcanoCatalog];

    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:[NSString stringWithFormat:@"共 %lu 个火山音色", (unsigned long)voices.count] Footer:@"点击音色可试听或设为当前音色"];
    Class normalCls = objc_getClass("WCTableViewNormalCellManager");
    NSString *selectedVT = [WCLiteVolcanoTTSConfig selectedVoiceType];

    for (id item in voices) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *voice = (NSDictionary *)item;
        NSString *name = [voice[@"name"] isKindOfClass:[NSString class]] ? voice[@"name"] : @"(未命名)";
        NSMutableArray *subs = [NSMutableArray array];
        if ([voice[@"description"] isKindOfClass:[NSString class]] && [(NSString *)voice[@"description"] length]) [subs addObject:voice[@"description"]];
        NSString *detail = [subs componentsJoinedByString:@" · "];
        NSString *vt = [WCLiteVolcanoTTSService voiceTypeFromVoiceDictionary:voice];
        NSString *right = ([selectedVT length] && [vt isEqualToString:selectedVT]) ? @"当前" : @" ";

        WCTableViewCellManager *cell = [normalCls normalCellForSel:@selector(wclite_volcanoRowTapped:)
                                                           target:self
                                                            title:name
                                                       rightValue:right
                                                     accessoryType:1];
        if (cell) {
            objc_setAssociatedObject(cell, &kWCLiteVolcanoVoiceKey, voice, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [section addCell:cell];
        }
    }
    [self.tableViewMgr addSection:section];
    [[self.tableViewMgr getTableView] reloadData];
}

- (NSDictionary *)wclite_volcanoVoiceFromSender:(id)sender {
    NSDictionary *v = objc_getAssociatedObject(sender, &kWCLiteVolcanoVoiceKey);
    return [v isKindOfClass:[NSDictionary class]] ? v : nil;
}

- (void)wclite_volcanoRowTapped:(id)sender {
    NSDictionary *voice = [self wclite_volcanoVoiceFromSender:sender];
    if (!voice) return;
    NSString *name = [voice[@"name"] isKindOfClass:[NSString class]] ? voice[@"name"] : @"音色";
    Class sheetCls = objc_getClass("WCActionSheet");
    if (!sheetCls) return;
    __weak typeof(self) weakSelf = self;
    WCActionSheet *sheet = [[sheetCls alloc] initWithTitle:name cancelButtonTitle:@"取消"];
    [sheet addButtonWithTitle:@"试听" eventAction:^{
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        [WCLiteVolcanoTTSService previewVoiceWithDictionary:voice fromViewController:strongSelf];
    }];
    [sheet addButtonWithTitle:@"设为当前音色" eventAction:^{
        typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
        NSString *vt = [WCLiteVolcanoTTSService voiceTypeFromVoiceDictionary:voice];
        if (!vt.length) { WCLiteVolcanoShowToast(@"无法解析音色 voice_type"); return; }
        [WCLiteVolcanoTTSConfig setSelectedVoiceType:vt];
        [WCLiteVolcanoTTSConfig setSelectedVoiceName:name];
        [strongSelf reloadTableData];
        WCLiteVolcanoShowToast([NSString stringWithFormat:@"已设为当前音色：%@", name]);
    }];
    [sheet showInView:self.view.window ?: self.view];
}
@end

#pragma mark - 设置页（替代 WCLiteVoiceCloneViewController）

@interface WCLiteVolcanoTTSCloneViewController : WCLiteVolcanoBaseVC
@end

@implementation WCLiteVolcanoTTSCloneViewController
- (instancetype)init {
    if (self = [super init]) {
        Class mgrCls = objc_getClass("WCTableViewManager");
        _tableViewMgr = [[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds style:2];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"火山语音合成";
    MMTableView *tableView = [self.tableViewMgr getTableView];
    if (@available(iOS 11, *)) tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
    [self setupTopOffsetForTableView:tableView];
    [self reloadTableData];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadTableData]; }

- (void)reloadTableData {
    [self.tableViewMgr clearAllSection];
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"火山语音合成" Footer:@"在聊天输入「指令 文本」并发送，将转为语音消息"];

    WCTableViewCellManager *master = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(wclite_volcanoMasterSwitchChanged:)
                                                                                        target:self
                                                                                         title:@"火山语音合成"
                                                                                            on:[WCLiteVolcanoTTSConfig enabled]];
    [section addCell:master];

    if ([WCLiteVolcanoTTSConfig enabled]) {
        // access_token
        NSString *token = [WCLiteVolcanoTTSConfig accessToken];
        WCTableViewCellManager *tokenCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoShowTokenInput)
                                                                                                   target:self
                                                                                                    title:@"Access Token"
                                                                                               rightValue:(token.length ? @"已设置" : @"未设置")
                                                                                            accessoryType:1];
        [section addCell:tokenCell];

        // 语速
        WCTableViewCellManager *speedCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoShowSpeedInput)
                                                                                                    target:self
                                                                                                     title:@"语速"
                                                                                                rightValue:[NSString stringWithFormat:@"%.2f", [WCLiteVolcanoTTSConfig speed]]
                                                                                             accessoryType:1];
        [section addCell:speedCell];

        // 发送指令
        NSString *cmd = [WCLiteVolcanoTTSConfig commandPrefix];
        WCTableViewCellManager *cmdCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoShowCommandInput)
                                                                                                  target:self
                                                                                                   title:@"发送指令"
                                                                                              rightValue:(cmd.length ? cmd : @"tts")
                                                                                           accessoryType:1];
        [section addCell:cmdCell];

        // 当前音色
        NSString *voiceName = [WCLiteVolcanoTTSConfig selectedVoiceName];
        WCTableViewCellManager *curCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoShowCatalog)
                                                                                                  target:self
                                                                                                   title:@"当前音色"
                                                                                              rightValue:(voiceName.length ? voiceName : @"未设置")
                                                                                           accessoryType:1];
        [section addCell:curCell];

        // 从服务器拉取
        WCTableViewCellManager *fetchCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoFetchCatalog)
                                                                                                    target:self
                                                                                                     title:@"从服务器拉取"
                                                                                                rightValue:@" "
                                                                                             accessoryType:1];
        [section addCell:fetchCell];

        // 音色列表
        NSUInteger count = [WCLiteVolcanoTTSConfig catalog].count;
        WCTableViewCellManager *listCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(wclite_volcanoShowCatalog)
                                                                                                  target:self
                                                                                                   title:@"音色列表"
                                                                                              rightValue:(count > 0 ? [NSString stringWithFormat:@"%lu 个", (unsigned long)count] : @"内置")
                                                                                           accessoryType:1];
        [section addCell:listCell];
    }

    [self.tableViewMgr addSection:section];
    [[self.tableViewMgr getTableView] reloadData];
}

#pragma mark - 开关
- (void)wclite_volcanoMasterSwitchChanged:(UISwitch *)sender {
    [WCLiteVolcanoTTSConfig setEnabled:sender.isOn];
    [self reloadTableData];
}

#pragma mark - Access Token 输入（仅本机）
- (void)wclite_volcanoShowTokenInput {
    Class tipsCls = objc_getClass("MMTipsViewController");
    if (!tipsCls) { WCLiteVolcanoShowToast(@"当前微信版本不支持输入弹窗"); return; }
    NSString *current = [WCLiteVolcanoTTSConfig accessToken];
    __weak typeof(self) weakSelf = self;
    id tipsVC = [[tipsCls alloc] initWithTitle:@"火山 Access Token"
                                       message:@"在火山引擎控制台「语音合成大模型」获取 access_token，仅存储到本机"
                                    btnTitle:@"取消" handler:nil
                                    btnTitle:@"保存" handler:^{
        typeof(self) strongSelf = weakSelf;
        UITextView *tv = [tipsVC getTextView];
        NSString *t = [(tv.text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [WCLiteVolcanoTTSConfig setAccessToken:t];
        if (strongSelf) [strongSelf reloadTableData];
    }];
    [tipsVC addTextViewWithMaxLen:512];
    [tipsVC setTipsTextPlaceholder:@"粘贴火山 access_token"];
    [tipsVC setTextFieldDefaultText:current];
    UITextView *tv = [tipsVC getTextView];
    if (tv) { tv.editable = YES; tv.selectable = YES; tv.autocorrectionType = UITextAutocorrectionTypeNo; tv.autocapitalizationType = UITextAutocapitalizationTypeNone; }
    [tipsVC show];
}

#pragma mark - 语速输入
- (void)wclite_volcanoShowSpeedInput {
    Class tipsCls = objc_getClass("MMTipsViewController");
    if (!tipsCls) { WCLiteVolcanoShowToast(@"当前微信版本不支持输入弹窗"); return; }
    __weak typeof(self) weakSelf = self;
    id tipsVC = [[tipsCls alloc] initWithTitle:@"语速"
                                       message:@"范围 0.5 ~ 2.0，1.0 为原速"
                                    btnTitle:@"取消" handler:nil
                                    btnTitle:@"保存" handler:^{
        typeof(self) strongSelf = weakSelf;
        UITextView *tv = [tipsVC getTextView];
        double s = [tv.text doubleValue];
        if (s < 0.5) s = 0.5; if (s > 2.0) s = 2.0;
        if (s <= 0) s = 1.0;
        [WCLiteVolcanoTTSConfig setSpeed:s];
        if (strongSelf) [strongSelf reloadTableData];
    }];
    [tipsVC addTextViewWithMaxLen:8];
    [tipsVC setTipsTextPlaceholder:@"1.0"];
    [tipsVC setTextFieldDefaultText:[NSString stringWithFormat:@"%.2f", [WCLiteVolcanoTTSConfig speed]]];
    UITextView *tv = [tipsVC getTextView];
    if (tv) { tv.editable = YES; tv.selectable = YES; tv.keyboardType = UIKeyboardTypeDecimalPad; }
    [tipsVC show];
}

#pragma mark - 发送指令输入
- (void)wclite_volcanoShowCommandInput {
    Class tipsCls = objc_getClass("MMTipsViewController");
    if (!tipsCls) { WCLiteVolcanoShowToast(@"当前微信版本不支持输入弹窗"); return; }
    NSString *current = [WCLiteVolcanoTTSConfig commandPrefix];
    __weak typeof(self) weakSelf = self;
    id tipsVC = [[tipsCls alloc] initWithTitle:@"发送指令"
                                       message:@"聊天发送「指令 文本」时转为语音\n例如：tts 你好"
                                    btnTitle:@"取消" handler:nil
                                    btnTitle:@"保存" handler:^{
        typeof(self) strongSelf = weakSelf;
        UITextView *tv = [tipsVC getTextView];
        NSString *t = [(tv.text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [WCLiteVolcanoTTSConfig setCommandPrefix:(t.length ? t : @"tts")];
        if (strongSelf) [strongSelf reloadTableData];
    }];
    [tipsVC addTextViewWithMaxLen:32];
    [tipsVC setTipsTextPlaceholder:@"tts"];
    [tipsVC setTextFieldDefaultText:current];
    UITextView *tv = [tipsVC getTextView];
    if (tv) { tv.editable = YES; tv.selectable = YES; tv.autocorrectionType = UITextAutocorrectionTypeNo; tv.autocapitalizationType = UITextAutocapitalizationTypeNone; }
    [tipsVC show];
}

#pragma mark - 从服务器拉取火山音色目录
- (void)wclite_volcanoFetchCatalog {
    [self startLoadingWithText:@"拉取中..."];
    NSURL *url = [NSURL URLWithString:kWCLiteVolcanoCatalogURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:30.0];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf; if (!strongSelf) return;
            if (error || data.length == 0) { [strongSelf stopLoadingWithFailText:[NSString stringWithFormat:@"拉取失败：%@", error.localizedDescription ?: @"无数据"]]; return; }
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *voices = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                id v = ((NSDictionary *)json)[@"voices"];
                if ([v isKindOfClass:[NSArray class]]) voices = v;
            } else if ([json isKindOfClass:[NSArray class]]) {
                voices = json;
            }
            // 只保留 provider=volcano 或 voice_type 形如 zh_*/ICL_* 的条目
            NSMutableArray *volcano = [NSMutableArray array];
            for (id item in voices) {
                if (![item isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *d = (NSDictionary *)item;
                NSString *p = [d[@"provider"] isKindOfClass:[NSString class]] ? d[@"provider"] : @"";
                NSString *pid = [d[@"providerVoiceId"] isKindOfClass:[NSString class]] ? d[@"providerVoiceId"] : @"";
                if ([p isEqualToString:@"volcano"] || [pid hasPrefix:@"zh_"] || [pid hasPrefix:@"ICL_"]) [volcano addObject:d];
            }
            if (volcano.count == 0) {
                [WCLiteVolcanoTTSConfig setCatalog:[WCLiteVolcanoTTSConfig builtinVolcanoCatalog]];
                [strongSelf stopLoadingWithOKText:@"已使用内置火山音色"];
            } else {
                [WCLiteVolcanoTTSConfig setCatalog:volcano];
                [strongSelf stopLoadingWithOKText:[NSString stringWithFormat:@"拉取成功 %lu 个", (unsigned long)volcano.count]];
            }
            [strongSelf reloadTableData];
        });
    }];
    [task resume];
}

- (void)wclite_volcanoShowCatalog {
    WCLiteVolcanoVoiceCatalogViewController *vc = [[WCLiteVolcanoVoiceCatalogViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

#pragma mark - Logos Hooks

/// 消息发送拦截：聊天发送「指令 文本」时，改为火山语音消息
%hook BaseMsgContentViewController
- (void)growTextViewDidClickSendWithText:(NSString *)arg1 {
    NSString *voiceText = [WCLiteVolcanoTTSService voiceTextFromOutgoingMessageContent:arg1];
    if (voiceText) {
        NSString *chatName = nil;
        if ([self respondsToSelector:NSSelectorFromString(@"getCurrentChatName")]) {
            chatName = [self performSelector:NSSelectorFromString(@"getCurrentChatName")];
        }
        NSString *voiceType = [WCLiteVolcanoTTSConfig selectedVoiceType];
        if (!voiceType.length) { WCLiteVolcanoShowToast(@"未设置火山音色，请到「火山语音合成」中选择"); return; }
        [WCLiteVolcanoTTSService sendVoiceMessageWithText:voiceText voiceType:voiceType chatUserName:chatName completion:^(BOOL ok, NSString *err) {
            if (err) WCLiteVolcanoShowToast(err);
        }];
        return; // 拦截，不再发送原文
    }
    %orig(arg1);
}
%end

/// 设置入口：在「设置」页注入「火山语音合成」入口
%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    WCTableViewManager *mgr = nil;
    if ([self respondsToSelector:NSSelectorFromString(@"m_tableViewMgr")]) {
        mgr = [self valueForKey:@"m_tableViewMgr"];
    }
    if (![mgr isKindOfClass:objc_getClass("WCTableViewManager")]) return;

    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"WCLite" Footer:@""];
    Class normalCls = objc_getClass("WCTableViewNormalCellManager");
    if (!normalCls) return;
    __weak typeof(self) weakSelf = self;
    WCTableViewCellManager *cell = [normalCls normalCellForSel:@selector(wclite_volcanoOpenSettings)
                                                       target:self
                                                        title:@"火山语音合成"
                                                   rightValue:@" "
                                                 accessoryType:1];
    if (cell) [section addCell:cell];
    [mgr addSection:section];
    [[mgr getTableView] reloadData];
}
- (void)wclite_volcanoOpenSettings {
    WCLiteVolcanoTTSCloneViewController *vc = [[WCLiteVolcanoTTSCloneViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}
%end

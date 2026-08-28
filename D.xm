// DD文字转语音 —— 提取自 PKC 的文字转语音(TTS)功能，单文件插件
// 触发方式：聊天发送 /yy 文本（拦截后转语音）+ 长按输入区弹菜单输入文本
// 音色来源：内置音色数据（琅琅音色 175，已过滤男声及指定音色；讯飞音色 6）—— 不联网、不支持本地导入
// 语音合成：琅琅走 s.lang123.top；讯飞走 peiyin.xunfei.cn（均复用 PKC 的接口结构）

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

// ===================== 微信私有接口 =====================

// 插件管理
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 消息封装
@interface CMessageWrap : NSObject
@property(retain, nonatomic) NSString *m_nsContent;
@property(nonatomic) unsigned int m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(nonatomic) unsigned int m_uiVoiceEndFlag;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(retain, nonatomic) NSData *m_dtVoice;
@property(retain, nonatomic) NSString *m_nsTitle;
@property(nonatomic) unsigned int m_uiAppMsgInnerType;
+ (id)initWithMsgType:(long long)arg1 nsFromUsr:(id)arg2;
+ (id)getPathOfAudio:(id)arg1;
+ (id)getPathOfMsgImg:(id)arg1;
+ (BOOL)isSenderFromMsgWrap:(id)wrap;
- (BOOL)IsTextMsg;
@end

// 消息管理器（统一出口）
@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap;
@end

// 微信原生 ActionSheet（自带取消按钮，无需手动添加）
@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title;
- (long long)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))action;
- (void)showInView:(UIView *)view;
@end

// 聊天输入框/会话视图（用于长按输入区弹菜单）
@interface WCInputView : UIView
@end

// ===================== 配置 =====================

static NSString * const kDDTTVConfigKey = @"DDTextToVoiceConfig";
static NSString * const kDDTTVEnable      = @"enableTextToVoice";      // 1.启用文字转语音
static NSString * const kDDTTVBgEnable     = @"enableBackgroundMusic";  // 5.启用背景音
static NSString * const kDDTTVBgFilePath   = @"bgFilePath";             // 6.导入背景音(文件路径)

static NSString * const kDDTTVVoiceIDDefault = @"voiceIDDefault";       // 当前音色ID(vid)

// 语速默认、音量默认 1.0
static NSString * const kDDTTVSpeed    = @"speed";
static NSString * const kDDTTVVolume   = @"volume";

// 音色列表动态拉取(复用 PKC 数据源)
static NSString * const kDDTTVLangToken  = @"langToken";    // 琅琅音色 token
static NSString * const kDDTTVXFUid      = @"xfUid";        // 讯飞配音 uid

@interface DDTextToVoiceConfig : NSObject
+ (instancetype)shared;
- (NSDictionary *)config;
- (void)setValue:(id)value forConfigKey:(NSString *)key;
- (BOOL)hasValueForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (double)speed;   // 语速，默认 1.0
- (double)volume;  // 音量，默认 1.0
@end

@implementation DDTextToVoiceConfig

+ (instancetype)shared {
    static DDTextToVoiceConfig *cfg = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cfg = [DDTextToVoiceConfig new]; });
    return cfg;
}

- (NSDictionary *)config {
    NSDictionary *cfg = [[NSUserDefaults standardUserDefaults] objectForKey:kDDTTVConfigKey];
    return [cfg isKindOfClass:[NSDictionary class]] ? cfg : @{};
}

- (void)setValue:(id)value forConfigKey:(NSString *)key {
    NSMutableDictionary *cfg = [[self config] mutableCopy];
    if (!cfg) cfg = [NSMutableDictionary dictionary];
    if (value) {
        [cfg setValue:value forKey:key];
    } else {
        [cfg removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] setObject:cfg forKey:kDDTTVConfigKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)hasValueForKey:(NSString *)key { return [self.config objectForKey:key] != nil; }

- (BOOL)boolForKey:(NSString *)key {
    NSNumber *val = [self.config objectForKey:key];
    return val ? val.boolValue : NO;
}

- (double)doubleForKey:(NSString *)key {
    NSNumber *val = [self.config objectForKey:key];
    return val ? val.doubleValue : 0.0;
}

- (NSString *)stringForKey:(NSString *)key {
    id val = [self.config objectForKey:key];
    return [val isKindOfClass:NSString.class] ? val : nil;
}

- (double)speed {  // 语速默认 1.0
    NSNumber *v = [self.config objectForKey:kDDTTVSpeed];
    return v ? v.doubleValue : 1.0;
}
- (double)volume { // 音量默认 1.0
    NSNumber *v = [self.config objectForKey:kDDTTVVolume];
    return v ? v.doubleValue : 1.0;
}

@end

// ===================== 路径与文件工具 =====================

// 缓存根目录：<AppLibrary>/Preferences/DD/TextToVoice
static NSString *ddTTVBaseDir(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths lastObject] stringByAppendingPathComponent:@"Preferences/DD/TextToVoice"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

static NSString *ddTTVAudioDir(void) {
    NSString *dir = [ddTTVBaseDir() stringByAppendingPathComponent:@"Audio"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *ddTTVBgDir(void) {
    NSString *dir = [ddTTVBaseDir() stringByAppendingPathComponent:@"Bg"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *ddTTVIconDir(void) {
    NSString *dir = [ddTTVBaseDir() stringByAppendingPathComponent:@"Icon"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSString *ddTTVPreviewDir(void) {
    NSString *dir = [ddTTVBaseDir() stringByAppendingPathComponent:@"Preview"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

// 当前前台活跃窗口（多场景，替代已废弃的 keyWindow）
static UIWindow *ddTTVCurrentKeyWindow(void) {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *winScene = (UIWindowScene *)scene;
        if (winScene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in winScene.windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
        if (window) break;
    }
    return window;
}

// Toast 提示
static void ddTTVToast(NSString *msg) {
    if (!msg.length) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = ddTTVCurrentKeyWindow();
        if (!win) return;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = msg;
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        label.font = [UIFont systemFontOfSize:14.0];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.layer.cornerRadius = 8.0;
        label.layer.masksToBounds = YES;
        CGFloat w = MIN(260.0, win.bounds.size.width - 40);
        CGSize size = [label sizeThatFits:CGSizeMake(w - 20, CGFLOAT_MAX)];
        label.frame = CGRectMake((win.bounds.size.width - w) / 2,
                                 win.bounds.size.height - 180,
                                 w, size.height + 20);
        [win addSubview:label];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [label removeFromSuperview];
        });
    });
}

// ===================== 内置音色数据（琅琅 175 + 讯飞 6） =====================
// 数据来源：PKC 音色列表 ys.json；无联网刷新，仅内置静态数据

// DD文字转语音 —— 内置音色数据（自动生成，勿手工编辑）
// 数据来源：PKC 音色列表 ys.json
// 生成时间：2026-08-29
// 琅琅：已过滤男声 + 两批指定音色特征与音色名（详见 Docs/音色过滤记录.md），现 175 个
// 讯飞：仅保留图片中的 6 个

static NSString * const kDDTTVLangImgPrefix = @"https://res.lang123.top/res/img/";   // 琅琅头像前缀
static NSString * const kDDTTVXFImgPrefix   = @"https://pygfile.peiyinge.com/manageweb/speaker/";   // 讯飞头像前缀

static NSArray<NSDictionary *> *ddTTVBuiltinLangVoices(void) {
    return @[
        @{@"v": @"sambert-zhistella-v1", @"n": @"思莎", @"d": @"通用场景、知性女声", @"i": @"sambert-zhistella-v1.jpeg"},
        @{@"v": @"azure_zh-CN-XiaoxiaoNeural", @"n": @"晓晓Pro", @"d": @"热门女声、支持多情感、适配全场景", @"i": @"a2175586-f80d-4d2f-9873-314450063829.jpg"},
        @{@"v": @"azure_zh-CN-XiaoxiaoMultilingualNeural", @"n": @"晓晓Ultra", @"d": @"热门女声、炸裂逼真效果、支持70多种语音", @"i": @"a2175586-f80d-4d2f-9873-314450063829.jpg"},
        @{@"v": @"xiaochen", @"n": @"晓辰", @"d": @"热门知性女声、休闲放松、解说/宣传", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"ttson_257", @"n": @"晓辰Pro", @"d": @"热门知性女声、解说/宣传、高品质、更好听", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"azure_zh-CN-XiaochenMultilingualNeural", @"n": @"晓辰Ultra", @"d": @"热门知性女声、炸裂逼真效果、支持70多种语言", @"i": @"afc2bd9b-800b-46d4-b66c-6de22f174a82.jpg"},
        @{@"v": @"zhiyue", @"n": @"思悦", @"d": @"短视频配音、宣传解说、有声阅读、年轻女声", @"i": @"db2f9682-1d17-47ec-8841-8e899822764c.png"},
        @{@"v": @"sambert-zhijia-v1", @"n": @"思佳", @"d": @"新闻播报、标准女声", @"i": @"sambert-zhijia-v1.jpg"},
        @{@"v": @"sambert-zhijing-v1", @"n": @"思婧", @"d": @"通用场景、严厉女声", @"i": @"sambert-zhijing-v1.jpg"},
        @{@"v": @"sambert-zhiting-v1", @"n": @"思婷", @"d": @"通用场景、电台女声", @"i": @"sambert-zhiting-v1.jpg"},
        @{@"v": @"sambert-zhimiao-emo-v1", @"n": @"思妙", @"d": @"阅读产品简介、数字人、直播、情感女声", @"i": @"sambert-zhimiao-emo-v1.jpg"},
        @{@"v": @"zhiya", @"n": @"思雅", @"d": @"有声阅读、朗诵、宣传、冷静年轻女声", @"i": @"08d0c7f7-4266-4af1-a00e-a6db089a6489.png"},
        @{@"v": @"zhigui", @"n": @"梦洁", @"d": @"阅读、广告、宣传、年轻/活力女声", @"i": @"1fbd491a-77c0-4682-96f9-7d73ddc0374f.png"},
        @{@"v": @"zhimao", @"n": @"梦瑶", @"d": @"配音、解说、宣传广告女声", @"i": @"c6e51fc0-4149-46c2-8741-97f1b5eced17.png"},
        @{@"v": @"sambert-zhiqi-v1", @"n": @"梦琪", @"d": @"通用场景、温柔女声", @"i": @"sambert-zhiqi-v1.png"},
        @{@"v": @"sambert-zhiru-v1", @"n": @"梦茹", @"d": @"新闻播报、标准通用女声", @"i": @"sambert-zhiru-v1.png"},
        @{@"v": @"sambert-zhiqian-v1", @"n": @"梦倩", @"d": @"配音解说、新闻播报、标准女声", @"i": @"sambert-zhiqian-v1.png"},
        @{@"v": @"sambert-zhiwei-v1", @"n": @"梦薇", @"d": @"阅读产品简介、萝莉女声", @"i": @"sambert-zhiwei-v1.png"},
        @{@"v": @"sambert-zhina-v1", @"n": @"梦娜", @"d": @"通用场景、浙普女声", @"i": @"sambert-zhina-v1.png"},
        @{@"v": @"sambert-zhixiao-v1", @"n": @"梦笑", @"d": @"通用场景、资讯女声", @"i": @"sambert-zhixiao-v1.png"},
        @{@"v": @"ttson_253", @"n": @"晓颜", @"d": @"友好舒适女声、科普解说、广告旁白", @"i": @"3628870b-9317-4c63-a37b-0a9ec36d2e80.png"},
        @{@"v": @"ttson_248", @"n": @"晓梦", @"d": @"乐观温柔年轻女声、广告/宣传、支持多情感", @"i": @"3a28a73e-81ec-45df-825b-b97c73322490.png"},
        @{@"v": @"azure_zh-CN-XiaohanNeural", @"n": @"晓涵", @"d": @"温柔甜美女声、客服/宣传、支持多情感", @"i": @"azure_zh-CN-XiaohanNeural.png"},
        @{@"v": @"azure_zh-CN-XiaozhenNeural", @"n": @"晓甄", @"d": @"平静自信女声、阅读/解说、支持多情感", @"i": @"azure_zh-CN-XiaozhenNeural.png"},
        @{@"v": @"azure_zh-CN-XiaomoNeural", @"n": @"晓墨", @"d": @"放松平静女声、广告/解说、支持多情感、多角色", @"i": @"azure_zh-CN-XiaomoNeural.jpg"},
        @{@"v": @"azure_zh-CN-XiaoyouNeural", @"n": @"晓悠", @"d": @"清脆愉悦儿童女声、动漫/游戏/儿童场景", @"i": @"azure_zh-CN-XiaoyouNeural.png"},
        @{@"v": @"ttson_250", @"n": @"晓双", @"d": @"可爱愉悦儿童女声、动漫/游戏、支持多情感", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"azure_zh-CN-XiaoyiNeural", @"n": @"晓伊", @"d": @"明亮年轻女声/童声、支持多情感", @"i": @"36c3f744-2e03-412b-a4b4-959ba876cb55.jpeg"},
        @{@"v": @"sambert-zhiying-v1", @"n": @"智颖", @"d": @"通用场景、软萌童声", @"i": @"sambert-zhiying-v1.png"},
        @{@"v": @"azure_zh-CN-YunyiMultilingualNeural", @"n": @"云希Ultra", @"d": @"热门解说宣传、炸裂真实声音、支持70多种语言", @"i": @"ef921edd-6258-4252-83de-def8a3825f7c.jpeg"},
        @{@"v": @"BV700_streaming", @"n": @"婉如", @"d": @"豆包同款宣传解说女声、官方授权、支持多情感", @"i": @"BV700_streaming.png"},
        @{@"v": @"BV001_streaming", @"n": @"婉红", @"d": @"抖音小姐姐、剪映同款、宣传解说、支持多情感", @"i": @"BV001_streaming.png"},
        @{@"v": @"BV007_streaming", @"n": @"婉秋", @"d": @"豆包同款、配音/解说、甜美亲切女声、官方授权", @"i": @"BV007_streaming.png"},
        @{@"v": @"BV005_streaming", @"n": @"婉兰", @"d": @"视频配音、活泼可爱、甜美女声", @"i": @"BV005_streaming.png"},
        @{@"v": @"BV034_streaming", @"n": @"婉钰", @"d": @"双语教学、知性、温柔女声", @"i": @"BV034_streaming.png"},
        @{@"v": @"BV113_streaming", @"n": @"婉楚", @"d": @"有声书朗读、宣传解说年轻女声、支持多情感", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_1001", @"n": @"智瑜", @"d": @"情感女声", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_101001", @"n": @"智瑜Pro", @"d": @"优雅知性姐姐、优雅从容", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_1002", @"n": @"智聆", @"d": @"通用女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_101002", @"n": @"智聆Pro", @"d": @"亲切大方姐姐、亲切女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_1003", @"n": @"智美", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_101003", @"n": @"智美Pro", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_1005", @"n": @"智莉", @"d": @"通用女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_101005", @"n": @"智莉Pro", @"d": @"阅读女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_1007", @"n": @"智娜", @"d": @"客服女声", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_101007", @"n": @"智娜Pro", @"d": @"客服女声、自然大方", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_1008", @"n": @"智琪", @"d": @"客服女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101008", @"n": @"智琪Pro", @"d": @"甜美客服姐姐、甜美亲切", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_1009", @"n": @"智芸", @"d": @"知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_101009", @"n": @"智芸Pro", @"d": @"阅读女声、知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_1017", @"n": @"智蓉", @"d": @"情感女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101017", @"n": @"智蓉Pro", @"d": @"阅读女声、深情女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101006", @"n": @"智言", @"d": @"智能小助手、助手女声", @"i": @"mohuanxi_meet_24k.jpeg"},
        @{@"v": @"ten_101011", @"n": @"智燕", @"d": @"有气场女播音员、铿锵有力", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"ten_101016", @"n": @"智甜", @"d": @"可爱萌宝宝、儿童女声", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"ten_101019", @"n": @"智彤", @"d": @"时尚粤语姐姐、粤语女声", @"i": @"BV007_streaming.png"},
        @{@"v": @"ten_101023", @"n": @"智萱", @"d": @"亲切姐姐、自然女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101025", @"n": @"智薇", @"d": @"邻家姑娘、自然大方", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101026", @"n": @"智希", @"d": @"甜美小助手、助手女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101027", @"n": @"智梅", @"d": @"通用女声、柔美大方", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101028", @"n": @"智洁", @"d": @"通用女声、青春活力", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"ten_101032", @"n": @"智芳", @"d": @"通用女声、自然舒适", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101033", @"n": @"智蓓", @"d": @"客服女声", @"i": @"moxiaowei_meet_24k.jpeg"},
        @{@"v": @"ten_101081", @"n": @"智佳", @"d": @"客服女声、温柔女声", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101080", @"n": @"智英", @"d": @"客服女声、严肃女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101034", @"n": @"智莲", @"d": @"时尚甜美小姐姐、甜美女声", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_101035", @"n": @"智依", @"d": @"通用女声、知性女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101040", @"n": @"智川", @"d": @"四川辣妹子、四川女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_101055", @"n": @"智付", @"d": @"智能收银员、支付播报,特色声音", @"i": @"molingyu_meet_24k.jpeg"},
        @{@"v": @"ten_301003", @"n": @"爱小霞", @"d": @"多情感女声", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301004", @"n": @"爱小玲", @"d": @"多情感女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301009", @"n": @"爱小芸", @"d": @"阅读女声、婉约女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301010", @"n": @"爱小秋", @"d": @"多情感女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_301011", @"n": @"爱小芳", @"d": @"多情感女声", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"ten_301012", @"n": @"爱小琴", @"d": @"多情感女声、亲切女声", @"i": @"moliping_meet_24k.jpeg"},
        @{@"v": @"ten_301015", @"n": @"爱小璐", @"d": @"活力小姐姐、活力自然", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301020", @"n": @"爱小岚", @"d": @"多情感女声", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"ten_301021", @"n": @"爱小茹", @"d": @"阅读女声", @"i": @"moyuqingt1_meet_24k.jpeg"},
        @{@"v": @"ten_301022", @"n": @"爱小蓉", @"d": @"多情感女声、舒缓女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301023", @"n": @"爱小燕", @"d": @"客服女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301024", @"n": @"爱小莲", @"d": @"知心姐姐", @"i": @"monihong_meet_24k.png"},
        @{@"v": @"ten_301026", @"n": @"爱小雪", @"d": @"亲切姐姐", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301027", @"n": @"爱小媛", @"d": @"多情感女声、大方女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301028", @"n": @"爱小娴", @"d": @"通用女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301030", @"n": @"爱小溪", @"d": @"客服女声、自然大方,年轻活力", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_601000", @"n": @"爱小溪Ultra", @"d": @"对话女声、伶俐女声", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_301032", @"n": @"爱小荷", @"d": @"多情感女声、自然女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_601003", @"n": @"爱小荷Ultra", @"d": @"阅读女声、气质女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_301033", @"n": @"爱小叶", @"d": @"多情感女声、自然女声", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_601007", @"n": @"爱小叶Ultra", @"d": @"对话女声、阳光女孩", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_301035", @"n": @"爱小梅", @"d": @"多情感女声、自然女声", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"ten_301037", @"n": @"爱小静", @"d": @"对话女声、甜美年轻,自然舒适", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_601005", @"n": @"爱小静Ultra", @"d": @"对话女声、腼腆女孩", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301038", @"n": @"爱小桃", @"d": @"自然大方女声、优雅百变", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301039", @"n": @"爱小萌", @"d": @"对话女声", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"ten_301041", @"n": @"爱小菲", @"d": @"自然对话女声、亲和女声", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"ten_501001", @"n": @"智兰Ultra", @"d": @"资讯女声、轻快女声", @"i": @"mopeiqi_meet_24k.jpeg"},
        @{@"v": @"ten_501002", @"n": @"智菊Ultra", @"d": @"阅读女声、端庄大方", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_501004", @"n": @"月华Ultra", @"d": @"对话女声、气质聪慧", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_601001", @"n": @"爱小洛Ultra", @"d": @"阅读女声、纯真少女", @"i": @"molinghua_meet_24k.jpeg"},
        @{@"v": @"ten_601009", @"n": @"爱小芊Ultra", @"d": @"对话女声、清纯灵巧", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"ten_601010", @"n": @"爱小娇Ultra", @"d": @"对话女声、娇媚女声", @"i": @"arou_meet_24k.png"},
        @{@"v": @"ten_601012", @"n": @"爱小璟Ultra", @"d": @"特色女声、可爱萝莉", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"ten_601013", @"n": @"爱小伊Ultra", @"d": @"阅读女声、知性姐姐", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"moxinyu_meet_24k", @"n": @"魔欣羽", @"d": @"温柔知性，温婉大方、资讯|影视", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"moxiaoqi_meet_24k", @"n": @"魔小七", @"d": @"温柔细腻，自然动听、美食|直播", @"i": @"moxiaoqi_meet_24k.jpeg"},
        @{@"v": @"moxiaotuan_meet_24k", @"n": @"魔小团", @"d": @"团团音色，诙谐幽默、直播|游戏", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"moliyuan_meet_24k", @"n": @"魔丽媛", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moliyuan_meet_24k.png"},
        @{@"v": @"moyunyan_meet_24k", @"n": @"魔云烟", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"mokeke_meet_24k", @"n": @"魔可可", @"d": @"元气少女，乖甜可爱 、直播|娱乐", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"molingyanv1_meet_24k", @"n": @"魔灵雁", @"d": @"温柔大姐，朴素大方、直播|广告", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"moxiaorui_meet_24k", @"n": @"魔晓蕊", @"d": @"魅力女声，专业客服、助理|情感", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"moyanxi_meet_24k", @"n": @"魔妍希", @"d": @"真实自然，朗朗动听", @"i": @"moyanxi_meet_24k.jpeg"},
        @{@"v": @"mowanqing_meet_24k", @"n": @"魔婉清", @"d": @"温柔甜美，舒缓悦耳、资讯|情感", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"moliliv1_meet_24k", @"n": @"魔丽莉", @"d": @"甜美可爱，自然流畅、游戏|动漫", @"i": @"moliliv1_meet_24k.png"},
        @{@"v": @"moqingju_meet_24k", @"n": @"魔青桔", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moqingju_meet_24k.jpeg"},
        @{@"v": @"mojialing_meet_24k", @"n": @"魔嘉玲", @"d": @"腔调独特，别有风味 、美食|娱乐", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"moqiao_meet_24k", @"n": @"魔巧", @"d": @"真实自然，朗朗动听 、影视|广告", @"i": @"moqiao_meet_24k.png"},
        @{@"v": @"momengyao_meet_24k", @"n": @"魔梦瑶", @"d": @"温柔甜美，自然动听、直播|游戏", @"i": @"momengyao_meet_24k.png"},
        @{@"v": @"moyuyao_meet_24k", @"n": @"魔雨瑶", @"d": @"温柔甜美，自然动听、影视|情感", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"moxiaoman_meet_24k", @"n": @"魔小蛮", @"d": @"精灵可爱，自然动听、美食|资讯", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"molingyu_meet_24k", @"n": @"魔凌玉", @"d": @"活泼阳光，魅力四射 、资讯|影视", @"i": @"molingyu_meet_24k.jpeg"},
        @{@"v": @"moshuihan_meet_24k", @"n": @"魔水寒", @"d": @"精灵古怪，自然动听、影视|动漫", @"i": @"moshuihan_meet_24k.png"},
        @{@"v": @"modaji_meet_24k", @"n": @"魔妲己", @"d": @"魅惑妲己，娇软动听、娱乐|影视", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"molaojie_meet_24k", @"n": @"魔莎莎", @"d": @"自然随和，甜美吆喝、美食|资讯", @"i": @"molaojie_meet_24k.png"},
        @{@"v": @"moyuji_meet_24k", @"n": @"魔娱姬", @"d": @"亲切悦耳，青春阳光、资讯|影视", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"moxiaoyun_meet_24k", @"n": @"魔晓芸", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"molingying_meet_24k", @"n": @"魔绫英", @"d": @"亲切温和，自然流畅 、影视|情感", @"i": @"molingying_meet_24k.png"},
        @{@"v": @"mobailing_meet_24k", @"n": @"魔百灵", @"d": @"灵动悦耳，自然动听、影视|情感", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"momeiduo_meet_24k", @"n": @"魔美哆", @"d": @"可爱萌娃，清脆欢快、动漫", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiaonv_meet_24k", @"n": @"魔小巧", @"d": @"甜美可爱，稚嫩天真、游戏|动漫", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"molingji_meet_24k", @"n": @"魔灵姬", @"d": @"冷静诡异，自然动听、影视|动漫", @"i": @"molingji_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiao_meet_24k", @"n": @"魔小乔", @"d": @"幽默诙谐，亲切甜美、娱乐|影视", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"moyimeng_meet_24k", @"n": @"魔依梦", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"lanxin_meet_24k", @"n": @"兰馨", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"moyingtao_meet_24k", @"n": @"魔樱桃", @"d": @"可爱萝莉，自然动听、影视|情感", @"i": @"moyingtao_meet_24k.jpg"},
        @{@"v": @"F110_meet_24k", @"n": @"小依", @"d": @"温柔柔软，清新甜美、影视|情感", @"i": @"F110_meet_24k.png"},
        @{@"v": @"moshiqi_meet_24k", @"n": @"魔诗琪", @"d": @"温柔甜美，自然动听、情感|有声书", @"i": @"moshiqi_meet_24k.jpeg"},
        @{@"v": @"molinglanv1_meet_24k", @"n": @"魔灵兰", @"d": @"自然流畅，朗朗动听、助理", @"i": @"molinglanv1_meet_24k.jpeg"},
        @{@"v": @"mosumei_meet_24k", @"n": @"魔苏媚", @"d": @"魅惑妲己，勾魂摄魄、资讯|娱乐", @"i": @"mosumei_meet_24k.png"},
        @{@"v": @"moluoli_meet_24k", @"n": @"魔罗莉", @"d": @"可爱清新，清脆欢快、影视|游戏", @"i": @"moluoli_meet_24k.jpeg"},
        @{@"v": @"monuandong_meet_24k", @"n": @"魔暖冬", @"d": @"元气少女，自然流畅、资讯|影视", @"i": @"monuandong_meet_24k.jpeg"},
        @{@"v": @"mozhongling_meet_24k", @"n": @"魔钟灵", @"d": @"青春少女，可爱甜美、资讯|情感", @"i": @"mozhongling_meet_24k.jpeg"},
        @{@"v": @"moyuxia_meet_24k", @"n": @"魔羽霞", @"d": @"美妙悦耳，清脆欢快、资讯|影视", @"i": @"moyuxia_meet_24k.png"},
        @{@"v": @"linger_meet_24k", @"n": @"魔小环", @"d": @"可爱清新，清脆欢快", @"i": @"linger_meet_24k.png"},
        @{@"v": @"mopeiqi_meet_24k", @"n": @"魔佩奇", @"d": @"可爱清新，清脆欢快、影视|游戏", @"i": @"mopeiqi_meet_24k.jpeg"},
        @{@"v": @"xiaomansha_meet_24k", @"n": @"小蔓莎", @"d": @"温柔甜美，温暖治愈、资讯|影视", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"moduidui_meet_24k", @"n": @"魔怼怼", @"d": @"怼人御姐，真实自然、娱乐|影视", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"xiaoyan_meet_24k", @"n": @"小妍", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"miaomiao_meet_24k", @"n": @"妙妙", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"arou_meet_24k", @"n": @"阿柔", @"d": @"亲切温和，自然流畅、美食|资讯", @"i": @"arou_meet_24k.png"},
        @{@"v": @"weiwei_meet_24k", @"n": @"薇薇", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"moruyue_meet_24k", @"n": @"魔如玥", @"d": @"温柔甜美，自然动听、资讯|影视", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"mowenji_meet_24k", @"n": @"魔文姬", @"d": @"元气少女，乖甜可爱 、资讯|影视", @"i": @"mowenji_meet_24k.png"},
        @{@"v": @"aya_meet_24k", @"n": @"阿雅", @"d": @"亲切温和，自然流畅、资讯|影视", @"i": @"aya_meet_24k.png"},
        @{@"v": @"ajiao_meet_24k", @"n": @"阿娇", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"ajiao_meet_24k.png"},
        @{@"v": @"momengyan_meet_24k", @"n": @"魔梦妍", @"d": @"温柔知性，温婉大方、情感", @"i": @"momengyan_meet_24k.jpeg"},
        @{@"v": @"momeixuan_meet_24k", @"n": @"魔梅萱", @"d": @"可爱清新，清脆欢快、影视|情感", @"i": @"momeixuan_meet_24k.png"},
        @{@"v": @"lin_meet_24k", @"n": @"魔晓萱", @"d": @"温柔柔软，纯净轻快、资讯|影视", @"i": @"lin_meet_24k.png"},
        @{@"v": @"chuyaping_meet_24k", @"n": @"魔灵儿", @"d": @"节奏明快，自然动听、直播", @"i": @"chuyaping_meet_24k.png"},
        @{@"v": @"chunchun_meet_24k", @"n": @"春春", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"chunchun_meet_24k.png"},
        @{@"v": @"lili_meet_24k", @"n": @"丽丽", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lili_meet_24k.png"},
        @{@"v": @"mojiaxin_meet_24k", @"n": @"魔家欣", @"d": @"真实自然，朗朗动听、资讯|影视", @"i": @"mojiaxin_meet_24k.png"},
        @{@"v": @"jiuweihu_meet_24k", @"n": @"九尾狐", @"d": @"魅惑妲己，娇软动听、影视|游戏", @"i": @"jiuweihu_meet_24k.png"},
        @{@"v": @"shujun_meet_24k", @"n": @"淑君", @"d": @"亲切温和，自然流畅、情感", @"i": @"shujun_meet_24k.png"},
        @{@"v": @"mowutong_meet_24k", @"n": @"魔舞桐", @"d": @"元气少女，悦耳动听 、资讯|影视", @"i": @"mowutong_meet_24k.jpeg"},
        @{@"v": @"qiqi_meet_24k", @"n": @"魔嫣然", @"d": @"亲切温和，自然流畅、资讯|游戏", @"i": @"qiqi_meet_24k.png"},
        @{@"v": @"lingling_meet_24k", @"n": @"玲玲", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lingling_meet_24k.png"},
        @{@"v": @"wenwen_meet_24k", @"n": @"玟玟", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"wenwen_meet_24k.png"},
        @{@"v": @"momoli_meet_24k", @"n": @"魔茉莉", @"d": @"元气少女，自然动听、影视", @"i": @"momoli_meet_24k.png"},
        @{@"v": @"alan_meet_24k", @"n": @"阿岚", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"alan_meet_24k.png"},
        @{@"v": @"huier_meet_24k", @"n": @"慧儿", @"d": @"亲切温和，自然流畅、资讯", @"i": @"huier_meet_24k.png"},
        @{@"v": @"cissy_meet_24k", @"n": @"小娜", @"d": @"自然淳朴、资讯|情感", @"i": @"cissy_meet_24k.png"},
        @{@"v": @"azure_wuu-CN-XiaotongNeural", @"n": @"晓彤", @"d": @"上海话、阅读、解说温柔女声", @"i": @"azure_wuu-CN-XiaotongNeural.png"},
        @{@"v": @"azure_yue-CN-XiaoMinNeural", @"n": @"晓敏", @"d": @"粤语年轻女声、宣传、广告、客服", @"i": @"azure_yue-CN-XiaoMinNeural.png"},
    ];
}

static NSArray<NSDictionary *> *ddTTVBuiltinXFVoices(void) {
    return @[
        @{@"v": @"130210", @"n": @"聆玉言", @"d": @"成熟知性,超拟人", @"i": @"@1713428685247_f9e321cce86d7f10e646faf56367c542.jpg"},
        @{@"v": @"561236098", @"n": @"聆小琪", @"d": @"温柔甜美,自然解说", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"60027", @"n": @"粤语小月", @"d": @"淳朴方言,粤语", @"i": @"@1646721208676_e355a0775f8af6c872110c9b53e9d488.jpg"},
        @{@"v": @"564561400", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,温柔轻快", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"538984610", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,复古播音", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"68080", @"n": @"陕西小莹", @"d": @"淳朴方言,陕西话", @"i": @"@1646731448291_ed1bd19beba83aef3b42bdaa1c5d550a.jpg"},
    ];
}
// ===================== 音色管理（琅琅音色 / 讯飞音色） =====================

static NSString * const kDDTTVTypeLang = @"琅琅";   // 琅琅音色
static NSString * const kDDTTVTypeXF   = @"讯飞";   // 讯飞音色

// 头像地址还原：数据文件里存的是短路径，运行时拼前缀
static NSString *ddTTVVoiceImageURL(NSString *img) {
    if (!img.length) return @"";
    if ([img hasPrefix:@"http"]) return img;
    if ([img hasPrefix:@"@"]) return [kDDTTVXFImgPrefix stringByAppendingString:[img substringFromIndex:1]];
    return [kDDTTVLangImgPrefix stringByAppendingString:img];
}

// 归一化：兼容内置数据(v/n/d/i) 与联网数据(vid/name/desc/img)
static NSArray<NSDictionary *> *ddTTVNormalizeVoices(NSArray<NSDictionary *> *raw, NSString *type) {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:raw.count];
    for (NSDictionary *r in raw) {
        NSString *vid  = r[@"v"]    ?: r[@"vid"]  ?: @"";
        NSString *name = r[@"n"]    ?: r[@"name"] ?: @"";
        NSString *desc = r[@"d"]    ?: r[@"desc"] ?: @"";
        NSString *img  = r[@"i"]    ?: r[@"img"]  ?: @"";
        if (!vid.length || !name.length) continue;
        [out addObject:@{@"id": vid, @"name": name, @"desc": desc,
                         @"img": ddTTVVoiceImageURL(img), @"type": type}];
    }
    return out;
}

// 当前生效的音色分组：仅使用内置静态数据
static NSDictionary<NSString *, NSArray<NSDictionary *> *> *ddTTVVoiceGroups(void) {
    return @{kDDTTVTypeLang: ddTTVNormalizeVoices(ddTTVBuiltinLangVoices(), kDDTTVTypeLang),
             kDDTTVTypeXF:   ddTTVNormalizeVoices(ddTTVBuiltinXFVoices(),   kDDTTVTypeXF)};
}

// 琅琅音色列表
static NSArray<NSDictionary *> *ddTTVLangVoices(void) {
    return [ddTTVVoiceGroups() objectForKey:kDDTTVTypeLang];
}

// 讯飞音色列表
static NSArray<NSDictionary *> *ddTTVXFVoices(void) {
    return [ddTTVVoiceGroups() objectForKey:kDDTTVTypeXF];
}

// 根据音色ID查找音色信息（跨琅琅/讯飞）
static NSDictionary *ddTTVFindVoiceByID(NSString *voiceID) {
    if (!voiceID.length) return nil;
    for (NSDictionary *v in ddTTVLangVoices()) {
        if ([v[@"id"] isEqualToString:voiceID]) return v;
    }
    for (NSDictionary *v in ddTTVXFVoices()) {
        if ([v[@"id"] isEqualToString:voiceID]) return v;
    }
    return nil;
}

// 获取当前音色ID（默认琅琅第一个）
// 注意：内置音色表会随版本调整（如移除男声/指定特征音色），老版本已选中的 vid 可能已不存在，
// 若不加校验会拿着失效 vid 去请求、服务端报错。这里发现失效就回退到列表首个音色。
static NSString *ddTTVCurrentVoiceID(void) {
    NSString *vid = [DDTextToVoiceConfig.shared stringForKey:kDDTTVVoiceIDDefault];
    if (vid.length && ddTTVFindVoiceByID(vid)) return vid;
    return [ddTTVLangVoices() firstObject][@"id"] ?: @"";
}

// 获取当前音色名称（用于显示）
static NSString *ddTTVCurrentVoiceName(void) {
    NSDictionary *v = ddTTVFindVoiceByID(ddTTVCurrentVoiceID());
    return v[@"name"] ?: @"未选择";
}

static NSError *ddTTVError(NSString *msg) {
    return [NSError errorWithDomain:@"DDTTV"
                              code:-1
                          userInfo:@{NSLocalizedDescriptionKey: msg.length ? msg : @"未知错误"}];
}

static NSString *ddTTVEscape(NSString *text) {
    NSMutableCharacterSet *set = [NSMutableCharacterSet alphanumericCharacterSet];
    [set addCharactersInString:@"-_.~"];
    return [text stringByAddingPercentEncodingWithAllowedCharacters:set];
}

static void ddTTVRequest(NSURLRequest *request, void (^completion)(NSData *data, NSError *error)) {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (completion) completion(data, error);
        }];
    [task resume];
}

static void ddTTVGet(NSString *urlString, void (^completion)(NSData *data, NSError *error)) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30;
    ddTTVRequest(request, completion);
}

static void ddTTVPostJSON(NSString *urlString, id body, NSArray<NSString *> *headers,
                          void (^completion)(NSData *data, NSError *error)) {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30;
    [request setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    for (NSString *h in headers) {
        NSArray *kv = [h componentsSeparatedByString:@": "];
        if (kv.count >= 2) [request setValue:kv[1] forHTTPHeaderField:kv[0]];
    }
    if (body) request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    ddTTVRequest(request, completion);
}

static id ddTTVJSON(NSData *data) {
    if (!data.length) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

// ============ 琅琅音色 ============
// GetPayState?token=&t=  →  task/Submit (taskText = base64(speak XML))  →  轮询 task/GetDetail  →  下载 data.audioUrl
static NSString * const kDDTTVLangBase = @"https://s.lang123.top/proxy/api";

// 轮询琅琅任务结果（每 2 秒一次，最多 30 次）—— 用递归函数而非递归 block，避免 ARC retain cycle
static void ddTTVLangPoll(NSString *token, NSString *taskId, NSInteger retry,
                          void (^completion)(NSData *audioData, NSError *error)) {
    long long t = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *detailURL = [NSString stringWithFormat:@"%@/task/GetDetail?token=%@&t=%lld&taskId=%@",
                           kDDTTVLangBase, token, t, taskId];
    ddTTVGet(detailURL, ^(NSData *data, NSError *error) {
        if (error || !data.length) { if (completion) completion(nil, error ?: ddTTVError(@"查询任务失败")); return; }
        id json = ddTTVJSON(data);
        NSString *audioUrl = [[json objectForKey:@"data"] objectForKey:@"audioUrl"];
        if (audioUrl.length) {
            ddTTVGet(audioUrl, ^(NSData *audio, NSError *e) {
                if (completion) completion((e || !audio.length) ? nil : audio,
                                           e ?: (audio.length ? nil : ddTTVError(@"音频下载失败")));
            });
            return;
        }
        if (retry + 1 >= 30) { if (completion) completion(nil, ddTTVError(@"琅琅合成超时")); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ddTTVLangPoll(token, taskId, retry + 1, completion);
        });
    });
}

static void ddTTVLangSynth(NSString *text, NSString *vid, double speed, double volume,
                           void (^completion)(NSData *audioData, NSError *error)) {
    NSString *token = [DDTextToVoiceConfig.shared stringForKey:kDDTTVLangToken];
    if (!token.length) { if (completion) completion(nil, ddTTVError(@"未配置琅琅 Token")); return; }
    long long t = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSString *payURL = [NSString stringWithFormat:@"%@/user/GetPayState?token=%@&t=%lld", kDDTTVLangBase, token, t];

    ddTTVGet(payURL, ^(NSData *data, NSError *error) {
        if (error || !data.length) { if (completion) completion(nil, error ?: ddTTVError(@"会员状态查询失败")); return; }
        id json = ddTTVJSON(data);
        if (![json isKindOfClass:NSDictionary.class]) { if (completion) completion(nil, ddTTVError(@"琅琅返回异常")); return; }
        if ([[json objectForKey:@"code"] integerValue] != 200) {
            NSString *m = [json objectForKey:@"msg"] ?: @"Token 无效或会员已过期";
            if (completion) completion(nil, ddTTVError([NSString stringWithFormat:@"琅琅：%@", m]));
            return;
        }

        int vol  = (int)lround(volume * 2.0);   // 默认 1.0 → 2（与 PKC 默认一致）
        int rate = (int)lround(speed);          // 默认 1.0 → 1
        NSString *xml = [NSString stringWithFormat:
            @"<root><speak isMain=\"true\" name=\"%@\" voice=\"%@\" hostType=\"1\" volume=\"%d\" pitch=\"0\" rate=\"%d\"><s line=\"1\">%@</s></speak></root>",
            vid, vid, vol, rate, text];
        NSString *taskText = [[xml dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

        NSString *submitURL = [NSString stringWithFormat:@"%@/task/Submit?token=%@&t=%lld", kDDTTVLangBase, token, t];
        ddTTVPostJSON(submitURL, @{@"taskText": taskText}, nil, ^(NSData *d2, NSError *e2) {
            if (e2 || !d2.length) { if (completion) completion(nil, e2 ?: ddTTVError(@"提交任务失败")); return; }
            id j2 = ddTTVJSON(d2);
            if (![j2 isKindOfClass:NSDictionary.class] || [[j2 objectForKey:@"code"] integerValue] != 200) {
                NSString *m = [j2 objectForKey:@"msg"] ?: @"提交任务被拒绝";
                if (completion) completion(nil, ddTTVError([NSString stringWithFormat:@"琅琅：%@", m]));
                return;
            }
            id dObj = [j2 objectForKey:@"data"];
            NSString *taskId = [dObj objectForKey:@"taskId"] ?: [j2 objectForKey:@"taskId"];
            if (!taskId) { if (completion) completion(nil, ddTTVError(@"未取到 taskId")); return; }

            ddTTVLangPoll(token, taskId, 0, completion);
        });
    });
}

// ============ 讯飞音色 ============
// web-server/exchange  →  web-server/1.0/works_synth_sign  →  /synth?...&sign=&vid=
static NSString * const kDDTTVXFHost = @"https://peiyin.xunfei.cn";
static NSString * const kDDTTVXFSid  = @"BCB18B513D2E8D8C8759AB03C36ED647";
static NSString * const kDDTTVXFUA   = @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.110 Safari/537.36";

static NSArray<NSString *> *ddTTVXFHeaders(void) {
    return @[@"Host: peiyin.xunfei.cn",
             @"Origin: http://peiyin.xunfei.cn",
             @"Pragma: no-cache",
             @"Referer: http://peiyin.xunfei.cn/",
             [NSString stringWithFormat:@"User-Agent: %@", kDDTTVXFUA]];
}

static void ddTTVXFSynth(NSString *text, NSString *vid, double speed, double volume,
                         void (^completion)(NSData *audioData, NSError *error)) {
    NSString *exchangeURL = [kDDTTVXFHost stringByAppendingString:@"/web-server/exchange"];
    ddTTVPostJSON(exchangeURL, @{}, ddTTVXFHeaders(), ^(NSData *d1, NSError *e1) {
        if (e1 || !d1.length) { if (completion) completion(nil, e1 ?: ddTTVError(@"讯飞 exchange 失败")); return; }
        id ex = ddTTVJSON(d1);
        if (![ex isKindOfClass:NSDictionary.class]) ex = @{};

        NSDictionary *body = @{
            @"req":  ex,
            @"text": [NSString stringWithFormat:@"[te50][n0]%@", text],
            @"vid":  vid ?: @"",
        };
        NSString *signURL = [kDDTTVXFHost stringByAppendingString:@"/web-server/1.0/works_synth_sign"];
        ddTTVPostJSON(signURL, body, ddTTVXFHeaders(), ^(NSData *d2, NSError *e2) {
            if (e2 || !d2.length) { if (completion) completion(nil, e2 ?: ddTTVError(@"讯飞签名失败")); return; }
            id j2 = ddTTVJSON(d2);
            if (![j2 isKindOfClass:NSDictionary.class]) { if (completion) completion(nil, ddTTVError(@"讯飞签名返回异常")); return; }
            if ([[j2 objectForKey:@"status"] integerValue] != 0) {
                NSString *m = [j2 objectForKey:@"message"] ?: [j2 objectForKey:@"msg"] ?: @"签名被拒绝";
                if (completion) completion(nil, ddTTVError([NSString stringWithFormat:@"讯飞：%@", m]));
                return;
            }
            NSString *sign = [j2 objectForKey:@"sign"];
            if (!sign.length) sign = [[j2 objectForKey:@"data"] objectForKey:@"sign"];
            if (!sign.length) { if (completion) completion(nil, ddTTVError(@"讯飞未返回 sign")); return; }

            NSString *uid = [DDTextToVoiceConfig.shared stringForKey:kDDTTVXFUid] ?: @"";
            NSString *ts  = [NSString stringWithFormat:@"%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)];
            int vol = (int)lround(volume * 20.0);        // 默认 1.0 → 20（与 PKC 默认一致）
            int spd = (int)lround((speed - 1.0) * 10.0); // 默认 1.0 → 0
            NSString *url = [NSString stringWithFormat:
                @"%@/synth?uid=%@&ts=%@&sign=%@&vid=%@&f=v2&cc=0000&sid=%@&volume=%d&speed=%d&content=%@&listen=2",
                kDDTTVXFHost, uid, ts, sign, vid, kDDTTVXFSid, vol, spd, ddTTVEscape(text)];
            ddTTVGet(url, ^(NSData *audio, NSError *e3) {
                if (completion) completion((e3 || !audio.length) ? nil : audio,
                                           e3 ?: (audio.length ? nil : ddTTVError(@"讯飞音频下载失败")));
            });
        });
    });
}

// 统一入口：按当前音色所属平台分发
static void ddTTVSynthesizeWithVoice(NSString *text, NSString *voiceID, double speed, double volume,
                                     void (^completion)(NSData *audioData, NSError *error)) {
    if (!text.length) { if (completion) completion(nil, ddTTVError(@"文本为空")); return; }
    NSDictionary *v = ddTTVFindVoiceByID(voiceID);
    NSString *type = v[@"type"] ?: kDDTTVTypeLang;   // 查不到时按琅琅处理
    if ([type isEqualToString:kDDTTVTypeXF]) ddTTVXFSynth(text, voiceID, speed, volume, completion);
    else                                     ddTTVLangSynth(text, voiceID, speed, volume, completion);
}

// ===================== 背景音 =====================

// 播放/合成时叠加背景音（简单实现：记录背景音文件，实际混音在发送前由服务端或后续处理）
static AVAudioPlayer *ddTTVBgPlayer(void) {
    static AVAudioPlayer *player = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *bgPath = [DDTextToVoiceConfig.shared stringForKey:kDDTTVBgFilePath];
        if (bgPath.length && [[NSFileManager defaultManager] fileExistsAtPath:bgPath]) {
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:bgPath] error:nil];
            player.numberOfLoops = -1;
        }
    });
    return player;
}

static void ddTTVPlayBackgroundMusic(void) {
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    if (![cfg boolForKey:kDDTTVBgEnable]) return;
    AVAudioPlayer *p = ddTTVBgPlayer();
    if (p) {
        p.volume = cfg.volume;
        [p play];
    }
}

static void ddTTVStopBackgroundMusic(void) {
    AVAudioPlayer *p = ddTTVBgPlayer();
    if (p && p.playing) [p stop];
}

// ===================== 清理缓存 =====================

static void ddTTVCleanCache(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[ ddTTVAudioDir(), ddTTVPreviewDir(), ddTTVIconDir(), ddTTVBgDir() ];
    for (NSString *dir in dirs) {
        NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *f in files) {
            [fm removeItemAtPath:[dir stringByAppendingPathComponent:f] error:nil];
        }
    }
    ddTTVToast(@"缓存已清理");
}

// ===================== 语音消息发送 =====================

// 构造语音消息并发送（msgType 34 = 语音消息；silk 数据通过 m_dtVoice 设置）
// 注：完整语音发送依赖微信 CDN 上传链路，此处用 CMessageMgr AddMsg 走微信统一出口。
static BOOL ddTTVSendVoiceMessage(NSData *audioData, NSString *toUser) {
    if (!audioData.length || !toUser.length) return NO;
    Class msgWrapCls = objc_getClass("CMessageWrap");
    Class msgMgrCls  = objc_getClass("CMessageMgr");
    if (!msgWrapCls || !msgMgrCls) return NO;

    CMessageWrap *wrap = [msgWrapCls initWithMsgType:34 nsFromUsr:nil];
    if (!wrap) return NO;
    wrap.m_nsToUsr = toUser;
    wrap.m_uiVoiceFormat = 4;      // silk 格式
    wrap.m_uiVoiceEndFlag = 1;
    wrap.m_uiCreateTime = (unsigned int)time(NULL);
    wrap.m_uiVoiceTime = 3000;     // 3 秒占位
    wrap.m_dtVoice = audioData;

    id mgr = [[msgMgrCls alloc] init];
    if (!mgr) return NO;
    [mgr AddMsg:toUser MsgWrap:wrap];
    return YES;
}

// ===================== 文字转语音主流程 =====================

static void ddTTVConvertAndSend(NSString *text, NSString *toUser) {
    if (!text.length) return;
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    if (![cfg boolForKey:kDDTTVEnable]) {
        ddTTVToast(@"请先在插件设置中启用文字转语音");
        return;
    }
    NSString *voiceID = ddTTVCurrentVoiceID();
    ddTTVToast(@"正在合成语音…");

    ddTTVSynthesizeWithVoice(text, voiceID, cfg.speed, cfg.volume, ^(NSData *audioData, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !audioData.length) {
                ddTTVToast(error ? [NSString stringWithFormat:@"合成失败：%@", error.localizedDescription] : @"合成失败");
                return;
            }
            // 落盘到缓存目录
            NSString *fileName = [NSString stringWithFormat:@"ttv_%ld.mp3", (long)time(NULL)];
            NSString *filePath = [ddTTVAudioDir() stringByAppendingPathComponent:fileName];
            [audioData writeToFile:filePath atomically:YES];

            // 背景音
            ddTTVPlayBackgroundMusic();

            if (toUser.length) {
                // 发送语音消息
                BOOL ok = ddTTVSendVoiceMessage(audioData, toUser);
                ddTTVToast(ok ? @"语音已发送" : @"语音已保存(发送失败)");
            } else {
                ddTTVToast([NSString stringWithFormat:@"语音已保存：%@", fileName]);
            }
        });
    });
}

// ===================== 输入文本弹窗 =====================

static void ddTTVPromptTextAndConvert(NSString *toUser) {
    UIWindow *win = ddTTVCurrentKeyWindow();
    if (!win) return;
    UIViewController *vc = win.rootViewController;
    if (!vc) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"文字转语音"
                                                                  message:@"输入要转成语音的文字"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入文字…";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"转语音" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = [alert.textFields firstObject].text;
        if (text.length) ddTTVConvertAndSend(text, toUser);
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

// 长按输入区弹菜单
static void ddTTVShowInputMenu(NSString *toUser) {
    UIWindow *win = ddTTVCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");
    WCActionSheet *sheet = [(WCActionSheet *)[sheetCls alloc] initWithTitle:@"文字转语音"];
    if (!sheet) return;
    [sheet addButtonWithTitle:@"输入文字转语音" eventAction:^{
        ddTTVPromptTextAndConvert(toUser);
    }];
    [sheet addButtonWithTitle:@"取消" eventAction:^{}];
    [sheet showInView:win];
}

// ===================== Hook：/yy 命令拦截 =====================

%hook CMessageMgr

- (void)AddMsg:(NSString *)usr MsgWrap:(CMessageWrap *)wrap {
    BOOL shouldSend = YES;
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    Class msgWrapCls = objc_getClass("CMessageWrap");
    if ([cfg boolForKey:kDDTTVEnable] && wrap && msgWrapCls && [msgWrapCls isSenderFromMsgWrap:wrap]) {
        if (wrap.m_uiMessageType == 1 && wrap.m_nsContent.length) {
            NSString *content = [wrap.m_nsContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            // /yy 文本 → 转语音并发送
            if ([content hasPrefix:@"/yy"] || [content hasPrefix:@"/YY"]) {
                NSString *text = [[content substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if (text.length) {
                    NSString *toUser = usr.length ? usr : wrap.m_nsToUsr;
                    ddTTVConvertAndSend(text, toUser);
                    shouldSend = NO;
                }
            }
        }
    }
    if (shouldSend) { %orig; }
}

%end

// ===================== 长按输入区触发 =====================

// 长按输入区：弹"文字转语音"菜单（长按输入框空白区域触发）
// 用关联对象挂一个 UILongPressGestureRecognizer，避免重复添加
static void ddTTVEnsureLongPress(UIView *view) {
    if (!view) return;
    NSString *key = @"DDTTVLongPress";
    NSObject *holder = (NSObject *)view;
    if (objc_getAssociatedObject(holder, (__bridge const void *)(key))) return; // 已挂载
    objc_setAssociatedObject(holder, (__bridge const void *)(key), @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:view
                                        action:@selector(ddTTVLongPress:)];
    lp.minimumPressDuration = 0.6;
    [view addGestureRecognizer:lp];
}

%hook WCInputView

// 进入会话时给输入区挂长按手势（需调用 ddTTVEnsureLongPress）
// 某些版本 WCInputView 可能复用，这里通过 didMoveToWindow 统一挂载一次
- (void)didMoveToWindow {
    %orig;
    if (self.window) ddTTVEnsureLongPress(self);
}

%end

// 长按手势目标方法（作为 category 挂到 UIView 上）
@interface UIView (DDTTVLongPress)
- (void)ddTTVLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation UIView (DDTTVLongPress)
- (void)ddTTVLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    ddTTVShowInputMenu(nil);
}
@end

// ===================== 设置界面 =====================

@interface WCTableViewManager : NSObject
@property(retain, nonatomic) NSMutableArray *sections;
- (instancetype)initWithFrame:(struct CGRect)arg1 style:(long long)arg2;
- (id)getTableView;
- (void)addSection:(id)arg1;
- (void)clearAllSection;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
@property(retain, nonatomic) NSMutableArray *cells;
@property(copy, nonatomic) NSString *footerTitle;
+ (id)defaultSection;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
@end

@interface DDTextToVoiceSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewMgr;
@end

@implementation DDTextToVoiceSettingsViewController

- (void)ensureTableViewMgr {
    if (_tableViewMgr) return;
    Class mgrCls = objc_getClass("WCTableViewManager");
    _tableViewMgr = [(WCTableViewManager *)[mgrCls alloc] initWithFrame:[UIScreen mainScreen].bounds
                                                                  style:UITableViewStyleInsetGrouped];
}

- (instancetype)init {
    if (self = [super init]) {
        [self ensureTableViewMgr];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD文字转语音";
    [self ensureTableViewMgr];
    if (!_tableViewMgr) return;
    [self buildTable];
    UITableView *tableView = [self.tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)buildTable {
    if (!_tableViewMgr) return;
    [self.tableViewMgr clearAllSection];
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    Class secCls = objc_getClass("WCTableViewSectionManager");
    Class cellCls = objc_getClass("WCTableViewCellManager");

    // 第1节：基本设置
    WCTableViewSectionManager *sec1 = [secCls defaultSection];
    [sec1 addCell:[cellCls switchCellForSel:@selector(toggleEnable:)
                                     target:self
                                      title:@"1. 启用文字转语音"
                                         on:[cfg boolForKey:kDDTTVEnable]]];
    [sec1 addCell:[cellCls normalCellForSel:@selector(setVoice:)
                                     target:self
                                      title:[NSString stringWithFormat:@"2. 设置音色(%@)", ddTTVCurrentVoiceName()]]];
    [sec1 setFooterTitle:@"聊天发送指令：/yy 文字 转语音并发送"];
    [self.tableViewMgr addSection:sec1];

    // 第2节：背景音
    WCTableViewSectionManager *sec2 = [secCls defaultSection];
    [sec2 addCell:[cellCls switchCellForSel:@selector(toggleBg:)
                                     target:self
                                      title:@"3. 启用背景音"
                                         on:[cfg boolForKey:kDDTTVBgEnable]]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(importBg:)
                                     target:self
                                      title:@"4. 导入背景音"]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(setBg:)
                                     target:self
                                      title:@"5. 设置背景音"]];
    [self.tableViewMgr addSection:sec2];

    // 第3节：缓存
    WCTableViewSectionManager *sec3 = [secCls defaultSection];
    [sec3 addCell:[cellCls normalCellForSel:@selector(cleanCache:)
                                     target:self
                                      title:@"6. 清理缓存(语音/试听/图标/聊天语音)"]];
    [self.tableViewMgr addSection:sec3];

    // 第4节：接口配置
    WCTableViewSectionManager *sec4 = [secCls defaultSection];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setLangToken:)
                                     target:self
                                      title:[NSString stringWithFormat:@"7. 琅琅 Token：%@",
                                             [self dd_masked:[cfg stringForKey:kDDTTVLangToken]]]]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setXFUid:)
                                     target:self
                                      title:[NSString stringWithFormat:@"8. 讯飞 UID：%@",
                                             [cfg stringForKey:kDDTTVXFUid] ?: @"未设置"]]];
    [sec4 setFooterTitle:@"琅琅音色需填 Token"];
    [self.tableViewMgr addSection:sec4];

    [self.tableViewMgr reloadTableView];
}

// 1. 启用文字转语音
- (void)toggleEnable:(UISwitch *)sender {
    [DDTextToVoiceConfig.shared setValue:sender.isOn ? @(1) : nil forConfigKey:kDDTTVEnable];
    [self buildTable];
}

// 2. 设置音色（琅琅音色 / 讯飞音色）
- (void)setVoice:(id)sender {
    UIWindow *win = ddTTVCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");

    // 先选分类（琅琅音色 / 讯飞音色）
    NSArray *lang = ddTTVLangVoices();
    NSArray *xf   = ddTTVXFVoices();
    WCActionSheet *catSheet = [(WCActionSheet *)[sheetCls alloc] initWithTitle:@"选择音色分类"];
    if (!catSheet) return;
    [catSheet addButtonWithTitle:[NSString stringWithFormat:@"琅琅音色 (%lu)", (unsigned long)lang.count]
                     eventAction:^{ [self showVoiceList:lang title:@"琅琅音色"]; }];
    [catSheet addButtonWithTitle:[NSString stringWithFormat:@"讯飞音色 (%lu)", (unsigned long)xf.count]
                     eventAction:^{ [self showVoiceList:xf title:@"讯飞音色"]; }];
    [catSheet showInView:win];
}

// 展示某一分类的音色列表
- (void)showVoiceList:(NSArray<NSDictionary *> *)voices title:(NSString *)title {
    if (!voices.count) { ddTTVToast(@"暂无音色，请先刷新音色列表"); return; }
    UIWindow *win = ddTTVCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");
    WCActionSheet *sheet = [(WCActionSheet *)[sheetCls alloc]
        initWithTitle:[NSString stringWithFormat:@"%@ (%lu)", title, (unsigned long)voices.count]];
    if (!sheet) return;
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    NSString *cur = ddTTVCurrentVoiceID();
    for (NSDictionary *v in voices) {
        NSString *mark = [v[@"id"] isEqualToString:cur] ? @"✓ " : @"";
        NSString *desc = v[@"desc"];
        NSString *btnTitle = desc.length ? [NSString stringWithFormat:@"%@%@  %@", mark, v[@"name"], desc]
                                         : [NSString stringWithFormat:@"%@%@", mark, v[@"name"]];
        [sheet addButtonWithTitle:btnTitle eventAction:^{
            [cfg setValue:v[@"id"] forConfigKey:kDDTTVVoiceIDDefault];
            ddTTVToast([NSString stringWithFormat:@"已设置音色：%@", v[@"name"]]);
            [self buildTable];
        }];
    }
    [sheet showInView:win];
}

// Token 脱敏显示
- (NSString *)dd_masked:(NSString *)text {
    if (!text.length) return @"未设置";
    if (text.length <= 8) return @"已设置";
    return [NSString stringWithFormat:@"%@***%@", [text substringToIndex:4], [text substringFromIndex:text.length - 4]];
}

// 7. 琅琅 Token
- (void)setLangToken:(id)sender {
    [self dd_editConfig:kDDTTVLangToken title:@"琅琅 Token" placeholder:@"在 lang123.top 个人中心获取" secure:YES];
}

// 8. 讯飞 UID
- (void)setXFUid:(id)sender {
    [self dd_editConfig:kDDTTVXFUid title:@"讯飞 UID" placeholder:@"可留空" secure:NO];
}

// 通用配置编辑弹窗
- (void)dd_editConfig:(NSString *)key title:(NSString *)title placeholder:(NSString *)ph secure:(BOOL)secure {
    UIWindow *win = ddTTVCurrentKeyWindow();
    UIViewController *vc = win.rootViewController;
    if (!vc) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                  message:nil
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = ph;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.secureTextEntry = secure;
        tf.text = [DDTextToVoiceConfig.shared stringForKey:key] ?: @"";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = [alert.textFields firstObject].text;
        [DDTextToVoiceConfig.shared setValue:text.length ? text : nil forConfigKey:key];
        ddTTVToast(@"已保存");
        [self buildTable];
    }]];
    [vc presentViewController:alert animated:YES completion:nil];
}

// 3. 启用背景音
- (void)toggleBg:(UISwitch *)sender {
    [DDTextToVoiceConfig.shared setValue:sender.isOn ? @(1) : nil forConfigKey:kDDTTVBgEnable];
    if (sender.isOn) ddTTVPlayBackgroundMusic(); else ddTTVStopBackgroundMusic();
    [self buildTable];
}

// 4. 导入背景音
- (void)importBg:(id)sender {
    UIWindow *win = ddTTVCurrentKeyWindow();
    UIViewController *vc = win.rootViewController;
    if (!vc) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.movie"]; // 视频选背景音(实际用音频需真机适配)
    [vc presentViewController:picker animated:YES completion:nil];
    ddTTVToast(@"请在文件App中放入背景音，或从视频提取(需进一步适配)");
}

// 5. 设置背景音
- (void)setBg:(id)sender {
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    NSArray *bgs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:ddTTVBgDir() error:nil];
    UIWindow *win = ddTTVCurrentKeyWindow();
    if (!win) return;
    Class sheetCls = objc_getClass("WCActionSheet");
    WCActionSheet *sheet = [(WCActionSheet *)[sheetCls alloc] initWithTitle:@"选择背景音"];
    if (!sheet) return;
    for (NSString *name in bgs) {
        [sheet addButtonWithTitle:name eventAction:^{
            [cfg setValue:[ddTTVBgDir() stringByAppendingPathComponent:name] forConfigKey:kDDTTVBgFilePath];
            ddTTVToast(@"背景音已设置");
        }];
    }
    [sheet showInView:win];
}

// 6. 清理缓存
- (void)cleanCache:(id)sender {
    ddTTVCleanCache();
}

@end

// ===================== 注册入口 =====================

%ctor {
    @autoreleasepool {
        id mgr = objc_getClass("WCPluginsMgr");
        if (mgr && [mgr respondsToSelector:@selector(sharedInstance)]) {
            [[mgr sharedInstance] registerControllerWithTitle:@"DD文字转语音"
                                                      version:@"1.0.0"
                                                   controller:@"DDTextToVoiceSettingsViewController"];
        }
    }
}

// DD文字转语音 —— 提取自 PKC 的文字转语音(TTS)功能，单文件插件
// 触发方式：聊天发送 /yy 文本（拦截后转语音）+ 长按输入区弹菜单输入文本
// 音色来源：内置音色数据(琅琅音色 410 + 讯飞音色 268)，联网可刷新
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
static NSString * const kDDTTVCurrentVoice = @"currentVoiceID";         // 3.当前音色(琅琅音色→音色ID)
static NSString * const kDDTTVRefreshVoices = @"refreshVoices";         // 4.刷新音色列表(一次性动作)
static NSString * const kDDTTVBgEnable     = @"enableBackgroundMusic";  // 5.启用背景音
static NSString * const kDDTTVBgFilePath   = @"bgFilePath";             // 6.导入背景音(文件路径)
static NSString * const kDDTTVBgSet        = @"bgSet";                  // 7.设置背景音(一次性动作)
static NSString * const kDDTTVCleanCache   = @"cleanCache";             // 8.清理缓存(一次性动作)

static NSString * const kDDTTVVoiceIDDefault = @"voiceIDDefault";       // 当前音色ID(vid)

// 语速默认、音量默认 1.0
static NSString * const kDDTTVSpeed    = @"speed";
static NSString * const kDDTTVVolume   = @"volume";

// 音色列表动态拉取(复用 PKC 数据源)
static NSString * const kDDTTVYsURL      = @"ysJSONURL";    // ys.json 地址
static NSString * const kDDTTVYsProxy    = @"ysProxy";      // GitHub 代理前缀(可选)
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

// ===================== 内置音色数据（琅琅 410 + 讯飞 268） =====================
// 数据来源：PKC 音色列表 ys.json；联网刷新后会被缓存覆盖，此数据作为离线兜底

// DD文字转语音 —— 内置音色数据（自动生成，勿手工编辑）
// 数据来源：PKC 音色列表 ys.json（琅琅音色 + 讯飞音色）
// 生成时间：2026-08-29   琅琅 410 个 / 讯飞 268 个
// 联网刷新音色列表时会覆盖为最新数据并缓存到本地


static NSString * const kDDTTVLangImgPrefix = @"https://res.lang123.top/res/img/";   // 琅琅头像前缀
static NSString * const kDDTTVXFImgPrefix   = @"https://pygfile.peiyinge.com/manageweb/speaker/";   // 讯飞头像前缀

// 琅琅音色（410 个）
// 字段：v=vid  n=名称  d=描述  i=头像(img路径，缺省拼前缀；@开头用讯飞前缀；http开头为完整URL)
static NSArray<NSDictionary *> *ddTTVBuiltinLangVoices(void) {
    return @[
        @{@"v": @"zhiyuan", @"n": @"思媛", @"d": @"热门配音、演讲解说、逼真声音、磁性女声", @"i": @"36ad0860-6d03-49c4-b291-3b113fbb125f.png"},
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
        @{@"v": @"ttson_251", @"n": @"晓秋", @"d": @"知性舒适沉稳女声、宣传/解说、纪录片", @"i": @"c0667009-7fbe-4436-a7b5-d2f055ac4ad2.png"},
        @{@"v": @"ttson_248", @"n": @"晓梦", @"d": @"乐观温柔年轻女声、广告/宣传、支持多情感", @"i": @"3a28a73e-81ec-45df-825b-b97c73322490.png"},
        @{@"v": @"ttson_247", @"n": @"晓睿", @"d": @"成熟睿智女声、解说/百科、支持多情感", @"i": @"ee781313-6873-4c1a-841f-ceb771181e2b.png"},
        @{@"v": @"azure_zh-CN-XiaohanNeural", @"n": @"晓涵", @"d": @"温柔甜美女声、客服/宣传、支持多情感", @"i": @"azure_zh-CN-XiaohanNeural.png"},
        @{@"v": @"azure_zh-CN-XiaozhenNeural", @"n": @"晓甄", @"d": @"平静自信女声、阅读/解说、支持多情感", @"i": @"azure_zh-CN-XiaozhenNeural.png"},
        @{@"v": @"azure_zh-CN-XiaomoNeural", @"n": @"晓墨", @"d": @"放松平静女声、广告/解说、支持多情感、多角色", @"i": @"azure_zh-CN-XiaomoNeural.jpg"},
        @{@"v": @"azure_zh-CN-XiaoyouNeural", @"n": @"晓悠", @"d": @"清脆愉悦儿童女声、动漫/游戏/儿童场景", @"i": @"azure_zh-CN-XiaoyouNeural.png"},
        @{@"v": @"ttson_250", @"n": @"晓双", @"d": @"可爱愉悦儿童女声、动漫/游戏、支持多情感", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"azure_zh-CN-XiaoyiNeural", @"n": @"晓伊", @"d": @"明亮年轻女声/童声、支持多情感", @"i": @"36c3f744-2e03-412b-a4b4-959ba876cb55.jpeg"},
        @{@"v": @"mike", @"n": @"麦克阿瑟", @"d": @"火遍全网大将军、纪录片、电影解说男声", @"i": @"mike.jpg"},
        @{@"v": @"aixiang", @"n": @"艾祥", @"d": @"热门配音、演讲、解说、纪录片、磁性男声", @"i": @"4b730596-6574-477b-9f02-cf987c955681.png"},
        @{@"v": @"ainan", @"n": @"艾楠", @"d": @"阅读、解说、宣传广告、年轻男声", @"i": @"ad1b86e0-1d6f-4ca3-b84d-499f7e2598a2.png"},
        @{@"v": @"sambert-zhinan-v1", @"n": @"智楠", @"d": @"通用场景、广告男声", @"i": @"sambert-zhinan-v1.png"},
        @{@"v": @"sambert-zhichu-v1", @"n": @"智楚", @"d": @"新闻播报、舌尖男声", @"i": @"sambert-zhichu-v1.png"},
        @{@"v": @"sambert-zhide-v1", @"n": @"智德", @"d": @"新闻播报、标准男声", @"i": @"sambert-zhide-v1.png"},
        @{@"v": @"sambert-zhixiang-v1", @"n": @"智祥", @"d": @"配音解说、磁性男声", @"i": @"sambert-zhixiang-v1.png"},
        @{@"v": @"sambert-zhiming-v1", @"n": @"智茗", @"d": @"通用场景、诙谐男声", @"i": @"sambert-zhiming-v1.png"},
        @{@"v": @"sambert-zhimo-v1", @"n": @"智墨", @"d": @"通用场景、情感男声", @"i": @"sambert-zhimo-v1.png"},
        @{@"v": @"sambert-zhishu-v1", @"n": @"智竖", @"d": @"通用场景、资讯男声", @"i": @"sambert-zhishu-v1.png"},
        @{@"v": @"sambert-zhiying-v1", @"n": @"智颖", @"d": @"通用场景、软萌童声", @"i": @"sambert-zhiying-v1.png"},
        @{@"v": @"sambert-zhilun-v1", @"n": @"智伦", @"d": @"配音解说、悬疑男声", @"i": @"sambert-zhilun-v1.png"},
        @{@"v": @"sambert-zhifei-v1", @"n": @"智飞", @"d": @"配音解说、激昂男声", @"i": @"sambert-zhifei-v1.png"},
        @{@"v": @"zhida", @"n": @"明达", @"d": @"新闻、阅读、宣传、标准男声", @"i": @"ba99636b-dee8-4ab6-9131-bf66597db208.png"},
        @{@"v": @"zhishuo", @"n": @"明硕", @"d": @"朗读、客服、解说、标准通用男声", @"i": @"3cd52ee2-d67f-4797-be88-84e3e064a214.png"},
        @{@"v": @"sambert-zhihao-v1", @"n": @"明浩", @"d": @"通用场景、咨询男声", @"i": @"sambert-zhihao-v1.png"},
        @{@"v": @"sambert-zhiye-v1", @"n": @"明晔", @"d": @"通用场景、青年男声", @"i": @"sambert-zhiye-v1.png"},
        @{@"v": @"silang", @"n": @"四郎", @"d": @"热门/特色声音，搞笑、解说、男声", @"i": @"silang.jpg"},
        @{@"v": @"houge", @"n": @"猴哥", @"d": @"热门/特色声音，搞笑、配音、男声", @"i": @"houge.png"},
        @{@"v": @"ttson_254", @"n": @"云泽", @"d": @"爆火全网麦克阿瑟、纪录片男声、支持多情感", @"i": @"4b730596-6574-477b-9f02-cf987c955681.png"},
        @{@"v": @"ttson_252", @"n": @"云皓", @"d": @"温暖乐观成熟男声、解说/宣传、支持多情感", @"i": @"b3e48509-5965-462f-8d7e-19a7b40eba55.png"},
        @{@"v": @"azure_zh-CN-YunxiNeural", @"n": @"云希Pro", @"d": @"火遍全网、解说宣传男声、支持多情感、多角色", @"i": @"ef921edd-6258-4252-83de-def8a3825f7c.jpeg"},
        @{@"v": @"azure_zh-CN-YunyiMultilingualNeural", @"n": @"云希Ultra", @"d": @"热门解说宣传、炸裂真实声音、支持70多种语言", @"i": @"ef921edd-6258-4252-83de-def8a3825f7c.jpeg"},
        @{@"v": @"azure_zh-CN-YunjianNeural", @"n": @"云健", @"d": @"放松魅力标准男声、宣传/解说、支持多情感", @"i": @"21cbeef1-3b2d-4f8e-8610-0ebfc52dba15.jpeg"},
        @{@"v": @"azure_zh-CN-YunyangNeural", @"n": @"云扬", @"d": @"专业平静磁性男声、解说/朗读、支持多情感", @"i": @"8d9d77e5-fcd6-4cfc-a0b5-a397520fda92.jpeg"},
        @{@"v": @"ttson_249", @"n": @"云野", @"d": @"成熟放松磁性男声、讲故事/朗读、支持多情感", @"i": @"68aade2e-ee3f-47ab-a455-f12d82283a8d.jpg"},
        @{@"v": @"azure_zh-CN-YunfengNeural", @"n": @"云枫", @"d": @"自信深情年轻男声、阅读/解说、支持多情感", @"i": @"azure_zh-CN-YunfengNeural.jpg"},
        @{@"v": @"azure_zh-CN-YunjieNeural", @"n": @"云杰", @"d": @"自信温暖男声、对话/朗读/宣传", @"i": @"ef921edd-6258-4252-83de-def8a3825f7c.jpeg"},
        @{@"v": @"azure_zh-CN-YunxiaNeural", @"n": @"云夏", @"d": @"愉悦友好年轻男声、解说/朗读、支持多情感", @"i": @"b47dec80-178d-4582-8dbf-2c042e82f72b.jpeg"},
        @{@"v": @"BV700_streaming", @"n": @"婉如", @"d": @"豆包同款宣传解说女声、官方授权、支持多情感", @"i": @"BV700_streaming.png"},
        @{@"v": @"BV001_streaming", @"n": @"婉红", @"d": @"抖音小姐姐、剪映同款、宣传解说、支持多情感", @"i": @"BV001_streaming.png"},
        @{@"v": @"BV007_streaming", @"n": @"婉秋", @"d": @"豆包同款、配音/解说、甜美亲切女声、官方授权", @"i": @"BV007_streaming.png"},
        @{@"v": @"BV005_streaming", @"n": @"婉兰", @"d": @"视频配音、活泼可爱、甜美女声", @"i": @"BV005_streaming.png"},
        @{@"v": @"BV034_streaming", @"n": @"婉钰", @"d": @"双语教学、知性、温柔女声", @"i": @"BV034_streaming.png"},
        @{@"v": @"BV113_streaming", @"n": @"婉楚", @"d": @"有声书朗读、宣传解说年轻女声、支持多情感", @"i": @"BV113_streaming.png"},
        @{@"v": @"BV115_streaming", @"n": @"婉雪", @"d": @"有声书朗读、沉稳女声、支持多情感", @"i": @"BV115_streaming.png"},
        @{@"v": @"BV701_streaming", @"n": @"旭然", @"d": @"磁性朗读、有声书、深沉男声、支持多情感", @"i": @"BV701_streaming.png"},
        @{@"v": @"BV119_streaming", @"n": @"旭华", @"d": @"有声书朗读、小说朗读温暖男声、支持多情感", @"i": @"BV119_streaming.png"},
        @{@"v": @"BV102_streaming", @"n": @"旭鹏", @"d": @"儒雅、沉稳男声、有声阅读、支持多情感", @"i": @"BV102_streaming.png"},
        @{@"v": @"BV705_streaming", @"n": @"旭炀", @"d": @"宣传解说、朗读播报通用男声、支持多情感", @"i": @"BV705_streaming.png"},
        @{@"v": @"BV002_streaming", @"n": @"旭辉", @"d": @"抖音小哥、剪映同款、阅读宣传、朗读播报男声", @"i": @"BV002_streaming.png"},
        @{@"v": @"BV033_streaming", @"n": @"旭阳", @"d": @"双语教学、知性、温暖男声", @"i": @"BV033_streaming.png"},
        @{@"v": @"BV056_streaming", @"n": @"旭光", @"d": @"视频配音、阅读朗诵、宣传解说、阳光清脆男声", @"i": @"BV056_streaming.png"},
        @{@"v": @"BV051_streaming", @"n": @"旭萌", @"d": @"豆包同款、热门声音、奶气萌娃、官方授权", @"i": @"BV051_streaming.png"},
        @{@"v": @"ten_10510000", @"n": @"智逍遥", @"d": @"旁对白阅读", @"i": @"moqingyang_meet_24k.jpeg"},
        @{@"v": @"ten_100510000", @"n": @"智逍遥Pro", @"d": @"专业说书人、旁白解说", @"i": @"moqingyang_meet_24k.jpeg"},
        @{@"v": @"ten_1001", @"n": @"智瑜", @"d": @"情感女声", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_101001", @"n": @"智瑜Pro", @"d": @"优雅知性姐姐、优雅从容", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"ten_1002", @"n": @"智聆", @"d": @"通用女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_101002", @"n": @"智聆Pro", @"d": @"亲切大方姐姐、亲切女声", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"ten_1003", @"n": @"智美", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_101003", @"n": @"智美Pro", @"d": @"客服女声", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"ten_1004", @"n": @"智云", @"d": @"通用男声", @"i": @"mohouyuan_meet_24k.jpeg"},
        @{@"v": @"ten_101004", @"n": @"智云Pro", @"d": @"阅读男声", @"i": @"mohouyuan_meet_24k.jpeg"},
        @{@"v": @"ten_1005", @"n": @"智莉", @"d": @"通用女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_101005", @"n": @"智莉Pro", @"d": @"阅读女声", @"i": @"BV113_streaming.png"},
        @{@"v": @"ten_1007", @"n": @"智娜", @"d": @"客服女声", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_101007", @"n": @"智娜Pro", @"d": @"客服女声、自然大方", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"ten_1008", @"n": @"智琪", @"d": @"客服女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101008", @"n": @"智琪Pro", @"d": @"甜美客服姐姐、甜美亲切", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_1009", @"n": @"智芸", @"d": @"知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_101009", @"n": @"智芸Pro", @"d": @"阅读女声、知性女声", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"ten_1010", @"n": @"智华", @"d": @"通用男声", @"i": @"zhinengrengongkaizi_meet_24k.png"},
        @{@"v": @"ten_101010", @"n": @"智华Pro", @"d": @"通用男声、磁性男声", @"i": @"zhinengrengongkaizi_meet_24k.png"},
        @{@"v": @"ten_1017", @"n": @"智蓉", @"d": @"情感女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101017", @"n": @"智蓉Pro", @"d": @"阅读女声、深情女声", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_1018", @"n": @"智靖", @"d": @"情感男声", @"i": @"BV002_streaming.png"},
        @{@"v": @"ten_101018", @"n": @"智靖Pro", @"d": @"深情大叔、低沉磁性,电影配音", @"i": @"BV002_streaming.png"},
        @{@"v": @"ten_101006", @"n": @"智言", @"d": @"智能小助手、助手女声", @"i": @"mohuanxi_meet_24k.jpeg"},
        @{@"v": @"ten_101011", @"n": @"智燕", @"d": @"有气场女播音员、铿锵有力", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"ten_101012", @"n": @"智丹", @"d": @"资讯播报员、亲切细腻", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"ten_101013", @"n": @"智辉", @"d": @"新闻播音员", @"i": @"moyunlei_meet_24k.jpeg"},
        @{@"v": @"ten_101014", @"n": @"智宁", @"d": @"资讯播音员、资讯男声", @"i": @"mojunkai_meet_24k.jpeg"},
        @{@"v": @"ten_101015", @"n": @"智萌", @"d": @"纯真小朋友、儿童男声", @"i": @"BV051_streaming.png"},
        @{@"v": @"ten_101016", @"n": @"智甜", @"d": @"可爱萌宝宝、儿童女声", @"i": @"f524d7d6-ad8e-464d-a338-b3cb58133788.png"},
        @{@"v": @"ten_101019", @"n": @"智彤", @"d": @"时尚粤语姐姐、粤语女声", @"i": @"BV007_streaming.png"},
        @{@"v": @"ten_101020", @"n": @"智刚", @"d": @"新闻播音员、磅礴厚重", @"i": @"moqingyang_meet_24k.jpeg"},
        @{@"v": @"ten_101021", @"n": @"智瑞", @"d": @"新闻播音员、磁性沉稳", @"i": @"momengxin_meet_24k.jpeg"},
        @{@"v": @"ten_101022", @"n": @"智虹", @"d": @"经典新闻播音员、新闻女声", @"i": @"moxiaowei_meet_24k.jpeg"},
        @{@"v": @"ten_101023", @"n": @"智萱", @"d": @"亲切姐姐、自然女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101024", @"n": @"智皓", @"d": @"阅读男声、聊天男声,自然男声", @"i": @"modongye_meet_24k.png"},
        @{@"v": @"ten_101025", @"n": @"智薇", @"d": @"邻家姑娘、自然大方", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"ten_101026", @"n": @"智希", @"d": @"甜美小助手、助手女声", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"ten_101027", @"n": @"智梅", @"d": @"通用女声、柔美大方", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101028", @"n": @"智洁", @"d": @"通用女声、青春活力", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"ten_101029", @"n": @"智凯", @"d": @"纪录片配音员、人文男声", @"i": @"moyangming_meet_24k.jpeg"},
        @{@"v": @"ten_101030", @"n": @"智柯", @"d": @"通用男声、自然轻快", @"i": @"mojunyi_meet_24k.jpeg"},
        @{@"v": @"ten_101031", @"n": @"智奎", @"d": @"专业播音员、磁性男声", @"i": @"moxiaole_meet_24k.jpg"},
        @{@"v": @"ten_101032", @"n": @"智芳", @"d": @"通用女声、自然舒适", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101033", @"n": @"智蓓", @"d": @"客服女声", @"i": @"moxiaowei_meet_24k.jpeg"},
        @{@"v": @"ten_101081", @"n": @"智佳", @"d": @"客服女声、温柔女声", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"ten_101080", @"n": @"智英", @"d": @"客服女声、严肃女声", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"ten_101034", @"n": @"智莲", @"d": @"时尚甜美小姐姐、甜美女声", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_101035", @"n": @"智依", @"d": @"通用女声、知性女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_101040", @"n": @"智川", @"d": @"四川辣妹子、四川女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_101052", @"n": @"智味", @"d": @"美食评论家、美食男声", @"i": @"moqingshu_meet_24k.jpeg"},
        @{@"v": @"ten_101053", @"n": @"智方", @"d": @"沉稳解说员、沉稳磁性", @"i": @"monuoyan_meet_24k.jpeg"},
        @{@"v": @"ten_101054", @"n": @"智友", @"d": @"解说小哥哥、轻快男声,特色声音", @"i": @"moxiaole_meet_24k.jpg"},
        @{@"v": @"ten_101055", @"n": @"智付", @"d": @"智能收银员、支付播报,特色声音", @"i": @"molingyu_meet_24k.jpeg"},
        @{@"v": @"ten_101056", @"n": @"智林", @"d": @"东北幽默小哥、东北男声", @"i": @"momingzhi_meet_24k.jpeg"},
        @{@"v": @"ten_301000", @"n": @"爱小广", @"d": @"多情感男声", @"i": @"modisheng_meet_24k.jpeg"},
        @{@"v": @"ten_301001", @"n": @"爱小栋", @"d": @"多情感男声", @"i": @"moyangming_meet_24k.jpeg"},
        @{@"v": @"ten_301002", @"n": @"爱小海", @"d": @"暖心小哥哥、舒适男声", @"i": @"momingzhi_meet_24k.jpeg"},
        @{@"v": @"ten_301003", @"n": @"爱小霞", @"d": @"多情感女声", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301004", @"n": @"爱小玲", @"d": @"多情感女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301005", @"n": @"爱小章", @"d": @"资讯播音员、活力男声", @"i": @"kuankuan_meet_24k.jpeg"},
        @{@"v": @"ten_301006", @"n": @"爱小峰", @"d": @"多情感男声", @"i": @"molingluo_meet_24k.png"},
        @{@"v": @"ten_301007", @"n": @"爱小亮", @"d": @"温情哥哥", @"i": @"momingzhi_meet_24k.jpeg"},
        @{@"v": @"ten_301008", @"n": @"爱小博", @"d": @"多情感男声", @"i": @"molingluo_meet_24k.png"},
        @{@"v": @"ten_301009", @"n": @"爱小芸", @"d": @"阅读女声、婉约女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301010", @"n": @"爱小秋", @"d": @"多情感女声", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_301011", @"n": @"爱小芳", @"d": @"多情感女声", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"ten_301012", @"n": @"爱小琴", @"d": @"多情感女声、亲切女声", @"i": @"moliping_meet_24k.jpeg"},
        @{@"v": @"ten_301013", @"n": @"爱小康", @"d": @"阳光小哥哥、活力男声", @"i": @"modisheng_meet_24k.jpeg"},
        @{@"v": @"ten_301014", @"n": @"爱小辉", @"d": @"多情感男声、磁性男声", @"i": @"moxiaose_meet_24k.jpeg"},
        @{@"v": @"ten_301015", @"n": @"爱小璐", @"d": @"活力小姐姐、活力自然", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301016", @"n": @"爱小阳", @"d": @"资讯播音员、磁性男声", @"i": @"molingluo_meet_24k.png"},
        @{@"v": @"ten_301017", @"n": @"爱小泉", @"d": @"资讯播音员", @"i": @"moguishu_meet_24k.png"},
        @{@"v": @"ten_301018", @"n": @"爱小昆", @"d": @"多情感男声", @"i": @"modaxing_meet_24k.jpeg"},
        @{@"v": @"ten_301019", @"n": @"爱小诚", @"d": @"深情少年、深情男声", @"i": @"moyangming_meet_24k.jpeg"},
        @{@"v": @"ten_301020", @"n": @"爱小岚", @"d": @"多情感女声", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"ten_301021", @"n": @"爱小茹", @"d": @"阅读女声", @"i": @"moyuqingt1_meet_24k.jpeg"},
        @{@"v": @"ten_301022", @"n": @"爱小蓉", @"d": @"多情感女声、舒缓女声", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"ten_301023", @"n": @"爱小燕", @"d": @"客服女声", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"ten_301024", @"n": @"爱小莲", @"d": @"知心姐姐", @"i": @"monihong_meet_24k.png"},
        @{@"v": @"ten_301025", @"n": @"爱小武", @"d": @"资讯播音员", @"i": @"moxiaowan_meet_24k.jpeg"},
        @{@"v": @"ten_301026", @"n": @"爱小雪", @"d": @"亲切姐姐", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"ten_301027", @"n": @"爱小媛", @"d": @"多情感女声、大方女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301028", @"n": @"爱小娴", @"d": @"通用女声", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301029", @"n": @"爱小涛", @"d": @"多情感男声", @"i": @"motailong_meet_24k.jpeg"},
        @{@"v": @"ten_301030", @"n": @"爱小溪", @"d": @"客服女声、自然大方,年轻活力", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_601000", @"n": @"爱小溪Ultra", @"d": @"对话女声、伶俐女声", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"ten_301031", @"n": @"爱小树", @"d": @"多情感男声、自然男声", @"i": @"moqisong_meet_24k.png"},
        @{@"v": @"ten_601004", @"n": @"爱小树Ultra", @"d": @"资讯男声、儒雅男声", @"i": @"moqisong_meet_24k.png"},
        @{@"v": @"ten_301032", @"n": @"爱小荷", @"d": @"多情感女声、自然女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_601003", @"n": @"爱小荷Ultra", @"d": @"阅读女声、气质女声", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"ten_301033", @"n": @"爱小叶", @"d": @"多情感女声、自然女声", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_601007", @"n": @"爱小叶Ultra", @"d": @"对话女声、阳光女孩", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"ten_301034", @"n": @"爱小杭", @"d": @"多情感男声、自然男声", @"i": @"motianqi_meet_24k.jpeg"},
        @{@"v": @"ten_301035", @"n": @"爱小梅", @"d": @"多情感女声、自然女声", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"ten_301036", @"n": @"爱小柯", @"d": @"低沉慵懒小哥、磁性男声", @"i": @"mojiaxuan_meet_24k.jpeg"},
        @{@"v": @"ten_301037", @"n": @"爱小静", @"d": @"对话女声、甜美年轻,自然舒适", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_601005", @"n": @"爱小静Ultra", @"d": @"对话女声、腼腆女孩", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"ten_301038", @"n": @"爱小桃", @"d": @"自然大方女声、优雅百变", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"ten_301039", @"n": @"爱小萌", @"d": @"对话女声", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"ten_301040", @"n": @"爱小星", @"d": @"活力解说男声、体育达人", @"i": @"moyuanqiao_meet_24k.jpeg"},
        @{@"v": @"ten_301041", @"n": @"爱小菲", @"d": @"自然对话女声、亲和女声", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"ten_501000", @"n": @"智斌Ultra", @"d": @"阅读男声、磁性男声", @"i": @"moyuhao_meet_24k.png"},
        @{@"v": @"ten_501001", @"n": @"智兰Ultra", @"d": @"资讯女声、轻快女声", @"i": @"mopeiqi_meet_24k.jpeg"},
        @{@"v": @"ten_501002", @"n": @"智菊Ultra", @"d": @"阅读女声、端庄大方", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"ten_501003", @"n": @"智宇Ultra", @"d": @"阅读男声、成熟大叔", @"i": @"mobotong_meet_24k.jpeg"},
        @{@"v": @"ten_501004", @"n": @"月华Ultra", @"d": @"对话女声、气质聪慧", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"ten_501005", @"n": @"飞镜Ultra", @"d": @"对话男声、温和男声", @"i": @"moyingjun_meet_24k.jpeg"},
        @{@"v": @"ten_501006", @"n": @"千嶂Ultra", @"d": @"对话男声、沉稳大气", @"i": @"moqingyang_meet_24k.jpeg"},
        @{@"v": @"ten_501007", @"n": @"浅草Ultra", @"d": @"对话男声、青春男声", @"i": @"moyingjun_meet_24k.jpeg"},
        @{@"v": @"ten_601001", @"n": @"爱小洛Ultra", @"d": @"阅读女声、纯真少女", @"i": @"molinghua_meet_24k.jpeg"},
        @{@"v": @"ten_601002", @"n": @"爱小辰Ultra", @"d": @"对话男声、清朗男声", @"i": @"mowangshu_meet_24k.png"},
        @{@"v": @"ten_601006", @"n": @"爱小耀Ultra", @"d": @"阅读男声、沉稳男声", @"i": @"moqisong_meet_24k.png"},
        @{@"v": @"ten_601008", @"n": @"爱小豪Ultra", @"d": @"对话男声、霸道高冷", @"i": @"moguishu_meet_24k.png"},
        @{@"v": @"ten_601009", @"n": @"爱小芊Ultra", @"d": @"对话女声、清纯灵巧", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"ten_601010", @"n": @"爱小娇Ultra", @"d": @"对话女声、娇媚女声", @"i": @"arou_meet_24k.png"},
        @{@"v": @"ten_601011", @"n": @"爱小川Ultra", @"d": @"对话男声、活力少年", @"i": @"boguang_meet_24k.jpg"},
        @{@"v": @"ten_601012", @"n": @"爱小璟Ultra", @"d": @"特色女声、可爱萝莉", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"ten_601013", @"n": @"爱小伊Ultra", @"d": @"阅读女声、知性姐姐", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"ten_601014", @"n": @"爱小简Ultra", @"d": @"对话男声、清爽学生", @"i": @"moziying_meet_24k.png"},
        @{@"v": @"moqingyang_meet_24k", @"n": @"魔青扬", @"d": @"磁性浑厚，爽朗动听、直播|助理", @"i": @"moqingyang_meet_24k.jpeg"},
        @{@"v": @"moxinyu_meet_24k", @"n": @"魔欣羽", @"d": @"温柔知性，温婉大方、资讯|影视", @"i": @"moxinyu_meet_24k.png"},
        @{@"v": @"moxiaoqi_meet_24k", @"n": @"魔小七", @"d": @"温柔细腻，自然动听、美食|直播", @"i": @"moxiaoqi_meet_24k.jpeg"},
        @{@"v": @"molinglong_meet_24k", @"n": @"魔玲珑", @"d": @"成熟温柔，悦耳动听、美食|助理", @"i": @"molinglong_meet_24k.png"},
        @{@"v": @"moqingyun_meet_24k", @"n": @"魔青云", @"d": @"磁性浑厚，自然爽朗、直播|助理", @"i": @"moqingyun_meet_24k.jpeg"},
        @{@"v": @"moxiaotuan_meet_24k", @"n": @"魔小团", @"d": @"团团音色，诙谐幽默、直播|游戏", @"i": @"moxiaotuan_meet_24k.jpeg"},
        @{@"v": @"mohouyuan_meet_24k", @"n": @"魔候渊", @"d": @"真实自然，流畅动听、资讯|影视", @"i": @"mohouyuan_meet_24k.jpeg"},
        @{@"v": @"mochunyingv1_meet_24k", @"n": @"魔春莹", @"d": @"声音洪亮，知性大方、直播|资讯", @"i": @"mochunyingv1_meet_24k.jpeg"},
        @{@"v": @"mohelan_meet_24k", @"n": @"魔鹤兰", @"d": @"声音洪亮，知性大方、情感|朗诵", @"i": @"mohelan_meet_24k.jpeg"},
        @{@"v": @"moyangming_meet_24k", @"n": @"魔阳明", @"d": @"真实自然，朗朗动听、影视|纪录片", @"i": @"moyangming_meet_24k.jpeg"},
        @{@"v": @"moruiying_meet_24k", @"n": @"魔瑞英", @"d": @"成熟知性，自然流畅、资讯|影视", @"i": @"moruiying_meet_24k.jpeg"},
        @{@"v": @"molanglang_meet_24k", @"n": @"魔朗朗", @"d": @"活力男声，自然流畅、美食|直播", @"i": @"molanglang_meet_24k.jpeg"},
        @{@"v": @"moliyuan_meet_24k", @"n": @"魔丽媛", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moliyuan_meet_24k.png"},
        @{@"v": @"moyunyan_meet_24k", @"n": @"魔云烟", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyunyan_meet_24k.jpeg"},
        @{@"v": @"moshuxin_meet_24k@chat", @"n": @"魔书馨", @"d": @"成熟知性，温婉大方、助理|资讯", @"i": @"moshuxin_meet_24k@chat.jpeg"},
        @{@"v": @"molingsha_meet_24k", @"n": @"静公子", @"d": @"元气少女，乖甜可爱、资讯|影视", @"i": @"molingsha_meet_24k.png"},
        @{@"v": @"momoyuan_meet_24k", @"n": @"魔墨渊", @"d": @"磁性浑厚，爽朗动听、体育|影视", @"i": @"momoyuan_meet_24k.jpeg"},
        @{@"v": @"momengpo_meet_24k", @"n": @"魔孟婆", @"d": @"和蔼慈祥，温和自然、影视|情感", @"i": @"momengpo_meet_24k.jpeg"},
        @{@"v": @"mozhangyu_meet_24k", @"n": @"魔章鱼", @"d": @"真实自然，朗朗动听、娱乐|影视", @"i": @"mozhangyu_meet_24k.jpeg"},
        @{@"v": @"mohuanxi_meet_24k", @"n": @"魔欢喜", @"d": @"稚嫩可爱，童真无邪、游戏|动漫", @"i": @"mohuanxi_meet_24k.jpeg"},
        @{@"v": @"moguimei_meet_24k", @"n": @"魔桂梅", @"d": @"成熟知性，温婉大方、直播|有声书", @"i": @"moguimei_meet_24k.jpeg"},
        @{@"v": @"mozhenhuav1_meet_24k", @"n": @"魔振华", @"d": @"磁性沉着，娓娓动听、娱乐|有声书", @"i": @"mozhenhuav1_meet_24k.jpeg"},
        @{@"v": @"mokeke_meet_24k", @"n": @"魔可可", @"d": @"元气少女，乖甜可爱 、直播|娱乐", @"i": @"mokeke_meet_24k.jpeg"},
        @{@"v": @"molingyanv1_meet_24k", @"n": @"魔灵雁", @"d": @"温柔大姐，朴素大方、直播|广告", @"i": @"molingyanv1_meet_24k.png"},
        @{@"v": @"zhinengrengongkaizi_meet_24k", @"n": @"魔青宏", @"d": @"磁性浑厚，爽朗动听、直播|广告", @"i": @"zhinengrengongkaizi_meet_24k.png"},
        @{@"v": @"moxiaorui_meet_24k", @"n": @"魔晓蕊", @"d": @"魅力女声，专业客服、助理|情感", @"i": @"moxiaorui_meet_24k.jpeg"},
        @{@"v": @"mojiaqi_meet_24k", @"n": @"魔嘉琦", @"d": @"磁性浑厚，爽朗动听、直播|助理", @"i": @"mojiaqi_meet_24k.jpeg"},
        @{@"v": @"moyanxi_meet_24k", @"n": @"魔妍希", @"d": @"真实自然，朗朗动听", @"i": @"moyanxi_meet_24k.jpeg"},
        @{@"v": @"moyunlei_meet_24k", @"n": @"魔云雷", @"d": @"磁性温柔，爽朗动听、娱乐|情感", @"i": @"moyunlei_meet_24k.jpeg"},
        @{@"v": @"mojunkai_meet_24k", @"n": @"魔俊凯", @"d": @"磁性浑厚，爽朗动听", @"i": @"mojunkai_meet_24k.jpeg"},
        @{@"v": @"mowanqing_meet_24k", @"n": @"魔婉清", @"d": @"温柔甜美，舒缓悦耳、资讯|情感", @"i": @"mowanqing_meet_24k.jpeg"},
        @{@"v": @"moliliv1_meet_24k", @"n": @"魔丽莉", @"d": @"甜美可爱，自然流畅、游戏|动漫", @"i": @"moliliv1_meet_24k.png"},
        @{@"v": @"moqingju_meet_24k", @"n": @"魔青桔", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moqingju_meet_24k.jpeg"},
        @{@"v": @"mobeigai_meet_24k", @"n": @"魔北丐", @"d": @"磁性浑厚，铿锵有力、体育|影视", @"i": @"mobeigai_meet_24k.jpeg"},
        @{@"v": @"mowenkai_meet_24k", @"n": @"魔文楷", @"d": @"磁性浑厚，自然动听 、影视", @"i": @"mowenkai_meet_24k.jpeg"},
        @{@"v": @"momengxin_meet_24k", @"n": @"魔萌新", @"d": @"稚嫩可爱，童真无邪、游戏|动漫", @"i": @"momengxin_meet_24k.jpeg"},
        @{@"v": @"moxiaowei_meet_24k", @"n": @"魔小唯", @"d": @"成熟稳重，自然流畅、资讯|影视", @"i": @"moxiaowei_meet_24k.jpeg"},
        @{@"v": @"moshaolong_meet_24k", @"n": @"魔少龙", @"d": @"磁性浑厚，爽朗动听、助理|影视", @"i": @"moshaolong_meet_24k.png"},
        @{@"v": @"moaya_meet_24k", @"n": @"魔阿雅", @"d": @"成熟稳重，自然流畅", @"i": @"moaya_meet_24k.png"},
        @{@"v": @"modongye_meet_24k", @"n": @"魔冬野", @"d": @"磁性浑厚，自然动听、影视|广告", @"i": @"modongye_meet_24k.png"},
        @{@"v": @"mojialing_meet_24k", @"n": @"魔嘉玲", @"d": @"腔调独特，别有风味 、美食|娱乐", @"i": @"mojialing_meet_24k.jpeg"},
        @{@"v": @"moqiao_meet_24k", @"n": @"魔巧", @"d": @"真实自然，朗朗动听 、影视|广告", @"i": @"moqiao_meet_24k.png"},
        @{@"v": @"momengyao_meet_24k", @"n": @"魔梦瑶", @"d": @"温柔甜美，自然动听、直播|游戏", @"i": @"momengyao_meet_24k.png"},
        @{@"v": @"murong_meet_24k", @"n": @"慕容", @"d": @"成熟浑厚，朗朗动听、影视|情感", @"i": @"murong_meet_24k.jpg"},
        @{@"v": @"mojunyi_meet_24k", @"n": @"魔俊逸", @"d": @"磁性醇厚，郎朗动听、美食|影视", @"i": @"mojunyi_meet_24k.jpeg"},
        @{@"v": @"moyuyao_meet_24k", @"n": @"魔雨瑶", @"d": @"温柔甜美，自然动听、影视|情感", @"i": @"moyuyao_meet_24k.jpeg"},
        @{@"v": @"moxiaole_meet_24k", @"n": @"魔小乐", @"d": @"真实自然，朗朗动听、娱乐|影视", @"i": @"moxiaole_meet_24k.jpg"},
        @{@"v": @"kuaibanxiaoge_meet_24k", @"n": @"快板大叔", @"d": @"和蔼沧桑，温和自然、娱乐|影视", @"i": @"kuaibanxiaoge_meet_24k.png"},
        @{@"v": @"molingfei_meet_24k", @"n": @"魔凌飞", @"d": @"磁性浑厚，爽朗动听、娱乐|影视", @"i": @"molingfei_meet_24k.jpeg"},
        @{@"v": @"molingyum_meet_24k", @"n": @"魔凌宇", @"d": @"磁性浑厚，爽朗动听 、体育|影视", @"i": @"molingyum_meet_24k.png"},
        @{@"v": @"mochuideng_meet_24k", @"n": @"魔吹灯", @"d": @"磁性浑厚，爽朗动听、资讯|影视", @"i": @"mochuideng_meet_24k.jpeg"},
        @{@"v": @"moyuchuan_meet_24k", @"n": @"魔宇川", @"d": @"温柔少年，自然动听、情感|游戏", @"i": @"moyuchuan_meet_24k.jpeg"},
        @{@"v": @"moxiaoman_meet_24k", @"n": @"魔小蛮", @"d": @"精灵可爱，自然动听、美食|资讯", @"i": @"moxiaoman_meet_24k.jpeg"},
        @{@"v": @"moqingxuan_meet_24k", @"n": @"魔青玄", @"d": @"清亮悦耳，自然流畅、直播|广告", @"i": @"moqingxuan_meet_24k.png"},
        @{@"v": @"moqingshu_meet_24k", @"n": @"魔青书", @"d": @"磁性浑厚，朗朗动听、美食|影视", @"i": @"moqingshu_meet_24k.jpeg"},
        @{@"v": @"monuoyan_meet_24k", @"n": @"魔诺言", @"d": @"游戏解说，自然流畅、游戏", @"i": @"monuoyan_meet_24k.jpeg"},
        @{@"v": @"molingyu_meet_24k", @"n": @"魔凌玉", @"d": @"活泼阳光，魅力四射 、资讯|影视", @"i": @"molingyu_meet_24k.jpeg"},
        @{@"v": @"moshuihan_meet_24k", @"n": @"魔水寒", @"d": @"精灵古怪，自然动听、影视|动漫", @"i": @"moshuihan_meet_24k.png"},
        @{@"v": @"momingzhi_meet_24k", @"n": @"魔铭智", @"d": @"真实自然，朗朗动听 、影视|纪录片", @"i": @"momingzhi_meet_24k.jpeg"},
        @{@"v": @"modisheng_meet_24k", @"n": @"魔迪生", @"d": @"磁性温和，轻快动听、资讯|影视", @"i": @"modisheng_meet_24k.jpeg"},
        @{@"v": @"modaji_meet_24k", @"n": @"魔妲己", @"d": @"魅惑妲己，娇软动听、娱乐|影视", @"i": @"modaji_meet_24k.jpeg"},
        @{@"v": @"mohexian_meet_24k", @"n": @"魔鹤仙", @"d": @"沧桑沙哑，真实自然、影视|情感", @"i": @"mohexian_meet_24k.jpeg"},
        @{@"v": @"molaojie_meet_24k", @"n": @"魔莎莎", @"d": @"自然随和，甜美吆喝、美食|资讯", @"i": @"molaojie_meet_24k.png"},
        @{@"v": @"mosima_meet_24k", @"n": @"魔司马", @"d": @"磁性浑厚，爽朗动听 、影视|宣传片", @"i": @"mosima_meet_24k.jpeg"},
        @{@"v": @"kuankuan_meet_24k", @"n": @"魔鸿儒", @"d": @"儒雅温和，自然流畅、影视|纪录片", @"i": @"kuankuan_meet_24k.jpeg"},
        @{@"v": @"molingluo_meet_24k", @"n": @"魔翎洛", @"d": @"稳重磁性，自然动听、资讯|体育", @"i": @"molingluo_meet_24k.png"},
        @{@"v": @"moyuji_meet_24k", @"n": @"魔娱姬", @"d": @"亲切悦耳，青春阳光、资讯|影视", @"i": @"moyuji_meet_24k.jpeg"},
        @{@"v": @"moxiaoyun_meet_24k", @"n": @"魔晓芸", @"d": @"温柔知性，温婉大方、直播|助理", @"i": @"moxiaoyun_meet_24k.jpeg"},
        @{@"v": @"moliping_meet_24k", @"n": @"魔丽萍", @"d": @"成熟知性，稳重自然、影视|纪录片", @"i": @"moliping_meet_24k.jpeg"},
        @{@"v": @"mozhiyuan_meet_24k", @"n": @"魔志远", @"d": @"磁性浑厚，爽朗动听 ", @"i": @"mozhiyuan_meet_24k.jpeg"},
        @{@"v": @"molingying_meet_24k", @"n": @"魔绫英", @"d": @"亲切温和，自然流畅 、影视|情感", @"i": @"molingying_meet_24k.png"},
        @{@"v": @"molaofeng_meet_24k", @"n": @"魔老冯", @"d": @"专业评书，婉转沧桑、影视", @"i": @"molaofeng_meet_24k.jpeg"},
        @{@"v": @"mobailing_meet_24k", @"n": @"魔百灵", @"d": @"灵动悦耳，自然动听、影视|情感", @"i": @"mobailing_meet_24k.png"},
        @{@"v": @"moxiaose_meet_24k", @"n": @"魔萧瑟", @"d": @"磁性醇厚，朗朗动听、资讯|影视", @"i": @"moxiaose_meet_24k.jpeg"},
        @{@"v": @"moxiaoqim_meet_24k", @"n": @"魔小奇", @"d": @"青春阳光，活力四射、广告|游戏", @"i": @"moxiaoqim_meet_24k.png"},
        @{@"v": @"moguishu_meet_24k", @"n": @"魔诡叔", @"d": @"冷静诡异，真实自然、影视|动漫", @"i": @"moguishu_meet_24k.png"},
        @{@"v": @"momeiduo_meet_24k", @"n": @"魔美哆", @"d": @"可爱萌娃，清脆欢快、动漫", @"i": @"momeiduo_meet_24k.jpeg"},
        @{@"v": @"modaxing_meet_24k", @"n": @"魔大星", @"d": @"真实自然，朗朗动听、娱乐|影视", @"i": @"modaxing_meet_24k.jpeg"},
        @{@"v": @"moyuqingt1_meet_24k", @"n": @"魔雨杉", @"d": @"温柔甜美，自然动听、助理", @"i": @"moyuqingt1_meet_24k.jpeg"},
        @{@"v": @"monihong_meet_24k", @"n": @"魔霓虹", @"d": @"成熟温柔，悦耳动听、资讯|影视", @"i": @"monihong_meet_24k.png"},
        @{@"v": @"mosongyi_meet_24k", @"n": @"魔宋逸", @"d": @"磁性浑厚，自然动听 、影视|情感", @"i": @"mosongyi_meet_24k.jpeg"},
        @{@"v": @"moxiao_meet_24k", @"n": @"魔潇", @"d": @"磁性浑厚，爽朗动听 、纪录片|宣传片", @"i": @"moxiao_meet_24k.jpeg"},
        @{@"v": @"modongpo_meet_24k", @"n": @"魔东坡", @"d": @"磁性浑厚，朗朗动听、美食|有声书", @"i": @"modongpo_meet_24k.jpeg"},
        @{@"v": @"mojingtang_meet_24k", @"n": @"魔惊堂", @"d": @"专业评书，婉转沧桑、影视", @"i": @"mojingtang_meet_24k.png"},
        @{@"v": @"moxiaowan_meet_24k", @"n": @"魔小顽", @"d": @"可爱男孩，自然动听、情感|游戏", @"i": @"moxiaowan_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiaonv_meet_24k", @"n": @"魔小巧", @"d": @"甜美可爱，稚嫩天真、游戏|动漫", @"i": @"moxiaoqiaonv_meet_24k.jpeg"},
        @{@"v": @"motailong_meet_24k", @"n": @"魔泰龙", @"d": @"洪亮浑厚，朗朗动听、影视|游戏", @"i": @"motailong_meet_24k.jpeg"},
        @{@"v": @"moxinyi_meet_24k", @"n": @"魔欣怡", @"d": @"成熟温柔，悦耳动听、影视|情感", @"i": @"moxinyi_meet_24k.png"},
        @{@"v": @"molingji_meet_24k", @"n": @"魔灵姬", @"d": @"冷静诡异，自然动听、影视|动漫", @"i": @"molingji_meet_24k.jpeg"},
        @{@"v": @"moxiaodi_meet_24k", @"n": @"魔小笛", @"d": @"可爱男孩，自然动听、影视|情感", @"i": @"moxiaodi_meet_24k.png"},
        @{@"v": @"motianqi_meet_24k", @"n": @"魔天启", @"d": @"成熟浑厚，朗朗动听、资讯|影视", @"i": @"motianqi_meet_24k.jpeg"},
        @{@"v": @"moxiaoqiao_meet_24k", @"n": @"魔小乔", @"d": @"幽默诙谐，亲切甜美、娱乐|影视", @"i": @"moxiaoqiao_meet_24k.jpeg"},
        @{@"v": @"moyuning_meet_24k", @"n": @"魔雨凝", @"d": @"甜美稳重，自然动听、纪录片|宣传片", @"i": @"moyuning_meet_24k.jpeg"},
        @{@"v": @"mowenya_meet_24k", @"n": @"魔温雅", @"d": @"成熟知性，悦耳动听、资讯|影视", @"i": @"mowenya_meet_24k.png"},
        @{@"v": @"mojiaxuan_meet_24k", @"n": @"魔稼轩", @"d": @"亲切温和，自然流畅、资讯|有声书", @"i": @"mojiaxuan_meet_24k.jpeg"},
        @{@"v": @"moyimeng_meet_24k", @"n": @"魔依梦", @"d": @"温柔甜美，自然动听、直播|助理", @"i": @"moyimeng_meet_24k.jpeg"},
        @{@"v": @"mosonglin_meet_24k", @"n": @"魔宋霖", @"d": @"磁性浑厚，爽朗动听 、影视|广告", @"i": @"mosonglin_meet_24k.jpeg"},
        @{@"v": @"lanxin_meet_24k", @"n": @"兰馨", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"lanxin_meet_24k.png"},
        @{@"v": @"moxuantian_meet_24k", @"n": @"魔玄天", @"d": @"特色京腔，自然动听、资讯|游戏", @"i": @"moxuantian_meet_24k.png"},
        @{@"v": @"moyuanqiao_meet_24k", @"n": @"魔远桥", @"d": @"阳光帅气，爽朗动听、影视|情感", @"i": @"moyuanqiao_meet_24k.jpeg"},
        @{@"v": @"moyangang_meet_24k", @"n": @"魔岩刚", @"d": @"专业播音，字正腔圆、资讯|情感", @"i": @"moyangang_meet_24k.jpeg"},
        @{@"v": @"moyingtao_meet_24k", @"n": @"魔樱桃", @"d": @"可爱萝莉，自然动听、影视|情感", @"i": @"moyingtao_meet_24k.jpg"},
        @{@"v": @"moxiaolo_meet_24k", @"n": @"魔小洛", @"d": @"稚嫩可爱，童真无邪、游戏|动漫", @"i": @"moxiaolo_meet_24k.png"},
        @{@"v": @"moyinzhen_meet_24k", @"n": @"魔胤禛", @"d": @"磁性浑厚，爽朗动听、朗诵|游戏", @"i": @"moyinzhen_meet_24k.png"},
        @{@"v": @"emily_meet_24k", @"n": @"魔语嫣", @"d": @"磁性甜美，轻快美妙、资讯|游戏", @"i": @"emily_meet_24k.png"},
        @{@"v": @"moxie_meet_24k", @"n": @"魔邪", @"d": @"磁性温和，自然动听、影视|纪录片", @"i": @"moxie_meet_24k.jpeg"},
        @{@"v": @"F110_meet_24k", @"n": @"小依", @"d": @"温柔柔软，清新甜美、影视|情感", @"i": @"F110_meet_24k.png"},
        @{@"v": @"moshiqi_meet_24k", @"n": @"魔诗琪", @"d": @"温柔甜美，自然动听、情感|有声书", @"i": @"moshiqi_meet_24k.jpeg"},
        @{@"v": @"moxiaonuan_meet_24k", @"n": @"魔小暖", @"d": @"成熟知性，自然流畅、资讯|影视", @"i": @"moxiaonuan_meet_24k.jpeg"},
        @{@"v": @"xiaohu_meet_24k", @"n": @"魔小虎", @"d": @"可爱清新，清脆欢快、娱乐|影视", @"i": @"xiaohu_meet_24k.png"},
        @{@"v": @"molinglanv1_meet_24k", @"n": @"魔灵兰", @"d": @"自然流畅，朗朗动听、助理", @"i": @"molinglanv1_meet_24k.jpeg"},
        @{@"v": @"moshufan_meet_24k", @"n": @"魔书凡", @"d": @"自然流畅，朗朗动听、直播|助理", @"i": @"moshufan_meet_24k.jpeg"},
        @{@"v": @"mosumei_meet_24k", @"n": @"魔苏媚", @"d": @"魅惑妲己，勾魂摄魄、资讯|娱乐", @"i": @"mosumei_meet_24k.png"},
        @{@"v": @"mozhiying_meet_24k", @"n": @"魔志颖", @"d": @"磁性温暖，真实自然、资讯|影视", @"i": @"mozhiying_meet_24k.png"},
        @{@"v": @"xiaoshuang_meet_24k", @"n": @"小爽", @"d": @"成熟知性，悦耳动听、资讯|影视", @"i": @"xiaoshuang_meet_24k.png"},
        @{@"v": @"moluoli_meet_24k", @"n": @"魔罗莉", @"d": @"可爱清新，清脆欢快、影视|游戏", @"i": @"moluoli_meet_24k.jpeg"},
        @{@"v": @"moxiaomai_meet_24k", @"n": @"魔小麦", @"d": @"磁性浑厚，爽朗动听 、资讯|影视", @"i": @"moxiaomai_meet_24k.jpeg"},
        @{@"v": @"mokongming_meet_24k", @"n": @"魔孔明", @"d": @"娓娓道来，朗朗动听、朗诵|游戏", @"i": @"mokongming_meet_24k.png"},
        @{@"v": @"motianzhen_meet_24k", @"n": @"魔天真", @"d": @"可爱羊羊，自然动听、游戏|动漫", @"i": @"motianzhen_meet_24k.png"},
        @{@"v": @"mohongyi_meet_24k", @"n": @"魔弘毅", @"d": @"磁性浑厚，朗朗动听、美食|资讯", @"i": @"mohongyi_meet_24k.png"},
        @{@"v": @"monuandong_meet_24k", @"n": @"魔暖冬", @"d": @"元气少女，自然流畅、资讯|影视", @"i": @"monuandong_meet_24k.jpeg"},
        @{@"v": @"modiaoge_meet_24k", @"n": @"魔貂哥", @"d": @"专业评书，自然动听、影视", @"i": @"modiaoge_meet_24k.png"},
        @{@"v": @"motaijun_meet_24k", @"n": @"魔太君", @"d": @"幽默诙谐，趣味十足、娱乐|动漫", @"i": @"motaijun_meet_24k.jpeg"},
        @{@"v": @"M109_meet_24k", @"n": @"魔子画", @"d": @"青春阳光，热情欢快、资讯|影视", @"i": @"M109_meet_24k.jpeg"},
        @{@"v": @"moyidan_meet_24k", @"n": @"魔一丹", @"d": @"成熟温柔，自然耐听", @"i": @"moyidan_meet_24k.jpeg"},
        @{@"v": @"mozhongling_meet_24k", @"n": @"魔钟灵", @"d": @"青春少女，可爱甜美、资讯|情感", @"i": @"mozhongling_meet_24k.jpeg"},
        @{@"v": @"mocuishan_meet_24k", @"n": @"魔翠山", @"d": @"成熟浑厚，朗朗动听、影视|动漫", @"i": @"mocuishan_meet_24k.jpeg"},
        @{@"v": @"mozhengnan_meet_24k", @"n": @"魔正男", @"d": @"可爱男孩，自然动听、影视|情感", @"i": @"mozhengnan_meet_24k.jpeg"},
        @{@"v": @"moyuxia_meet_24k", @"n": @"魔羽霞", @"d": @"美妙悦耳，清脆欢快、资讯|影视", @"i": @"moyuxia_meet_24k.png"},
        @{@"v": @"linger_meet_24k", @"n": @"魔小环", @"d": @"可爱清新，清脆欢快", @"i": @"linger_meet_24k.png"},
        @{@"v": @"moshutong_meet_24k", @"n": @"魔叔同", @"d": @"成熟浑厚，朗朗动听、美食|影视", @"i": @"moshutong_meet_24k.jpeg"},
        @{@"v": @"lucy_meet_24k", @"n": @"魔小灵", @"d": @"可爱清新，清脆欢快、资讯|游戏", @"i": @"lucy_meet_24k.png"},
        @{@"v": @"wuhan037_meet_24k", @"n": @"魔杨逍", @"d": @"吊儿郎当，轻快自然、体育|影视", @"i": @"wuhan037_meet_24k.jpeg"},
        @{@"v": @"moxiaochan_meet_24k", @"n": @"魔小禅", @"d": @"可爱清新，清脆欢快、情感|游戏", @"i": @"moxiaochan_meet_24k.png"},
        @{@"v": @"moyingying_meet_24k", @"n": @"魔盈盈", @"d": @"成熟知性，悦耳动听、影视|动漫", @"i": @"moyingying_meet_24k.png"},
        @{@"v": @"mowanling_meet_24k", @"n": @"魔婉灵", @"d": @"成熟知性，温婉大方 、影视|情感", @"i": @"mowanling_meet_24k.png"},
        @{@"v": @"molixin_meet_24k", @"n": @"魔黎馨", @"d": @"成熟知性，温婉大方 、影视", @"i": @"molixin_meet_24k.png"},
        @{@"v": @"moqingzhao_meet_24k", @"n": @"魔清照", @"d": @"成熟知性，悦耳动听、资讯|影视", @"i": @"moqingzhao_meet_24k.jpeg"},
        @{@"v": @"mopeiqi_meet_24k", @"n": @"魔佩奇", @"d": @"可爱清新，清脆欢快、影视|游戏", @"i": @"mopeiqi_meet_24k.jpeg"},
        @{@"v": @"moshaoxin_meet_24k", @"n": @"魔少辛", @"d": @"真实自然，朗朗动听 、影视", @"i": @"moshaoxin_meet_24k.jpeg"},
        @{@"v": @"moxiuyuan_meet_24k", @"n": @"魔修远", @"d": @"激情男声，活力四射、娱乐|游戏", @"i": @"moxiuyuan_meet_24k.jpeg"},
        @{@"v": @"morunyu_meet_24k", @"n": @"魔润玉", @"d": @"磁性浑厚，爽朗动听 、资讯|影视", @"i": @"morunyu_meet_24k.png"},
        @{@"v": @"moyuhao_meet_24k", @"n": @"魔宇皓", @"d": @"真实自然，朗朗动听 、资讯|影视", @"i": @"moyuhao_meet_24k.png"},
        @{@"v": @"moguige_meet_24k", @"n": @"魔诡哥", @"d": @"冷静诡异，自然动听、影视", @"i": @"moguige_meet_24k.jpeg"},
        @{@"v": @"moxiaoyi_meet_24k", @"n": @"魔小易", @"d": @"可爱男孩，自然动听、影视|游戏", @"i": @"moxiaoyi_meet_24k.png"},
        @{@"v": @"mobotong_meet_24k", @"n": @"魔伯通", @"d": @"磁性浑厚，朗朗动听、影视|动漫", @"i": @"mobotong_meet_24k.jpeg"},
        @{@"v": @"moyingjun_meet_24k", @"n": @"魔英俊", @"d": @"磁性浑厚，爽朗动听、资讯", @"i": @"moyingjun_meet_24k.jpeg"},
        @{@"v": @"xiaomansha_meet_24k", @"n": @"小蔓莎", @"d": @"温柔甜美，温暖治愈、资讯|影视", @"i": @"xiaomansha_meet_24k.jpeg"},
        @{@"v": @"molinghua_meet_24k", @"n": @"魔凌华", @"d": @"温婉大气，自然动听、影视|纪录片", @"i": @"molinghua_meet_24k.jpeg"},
        @{@"v": @"moduidui_meet_24k", @"n": @"魔怼怼", @"d": @"怼人御姐，真实自然、娱乐|影视", @"i": @"moduidui_meet_24k.png"},
        @{@"v": @"moyuefeng_meet_24k", @"n": @"魔岳峰", @"d": @"磁性浑厚，自然动听、影视", @"i": @"moyuefeng_meet_24k.png"},
        @{@"v": @"mowukong_meet_24k", @"n": @"老禅师", @"d": @"和蔼沧桑，温和自然、影视|情感", @"i": @"mowukong_meet_24k.png"},
        @{@"v": @"mowangshu_meet_24k", @"n": @"魔望舒", @"d": @"磁性悦耳，爽朗动听、情感|有声书", @"i": @"mowangshu_meet_24k.png"},
        @{@"v": @"moqisong_meet_24k", @"n": @"魔奇松", @"d": @"真实自然，朗朗动听 、体育|影视", @"i": @"moqisong_meet_24k.png"},
        @{@"v": @"xiaoyan_meet_24k", @"n": @"小妍", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"xiaoyan_meet_24k.png"},
        @{@"v": @"mochenxiang_meet_24k", @"n": @"魔沉香", @"d": @"真实自然，朗朗动听、影视|纪录片", @"i": @"mochenxiang_meet_24k.png"},
        @{@"v": @"miaomiao_meet_24k", @"n": @"妙妙", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"miaomiao_meet_24k.png"},
        @{@"v": @"arou_meet_24k", @"n": @"阿柔", @"d": @"亲切温和，自然流畅、美食|资讯", @"i": @"arou_meet_24k.png"},
        @{@"v": @"mowaner_meet_24k", @"n": @"魔婉儿", @"d": @"成熟知性，温婉大方、资讯|有声书", @"i": @"mowaner_meet_24k.png"},
        @{@"v": @"weiwei_meet_24k", @"n": @"薇薇", @"d": @"亲切温和，自然流畅、影视|情感", @"i": @"weiwei_meet_24k.png"},
        @{@"v": @"mogongshu_meet_24k", @"n": @"魔龚叔", @"d": @"磁性浑厚，爽朗动听 、资讯|影视", @"i": @"mogongshu_meet_24k.png"},
        @{@"v": @"boguang_meet_24k", @"n": @"伯光", @"d": @"成熟浑厚，朗朗动听、影视|动漫", @"i": @"boguang_meet_24k.jpg"},
        @{@"v": @"moruyue_meet_24k", @"n": @"魔如玥", @"d": @"温柔甜美，自然动听、资讯|影视", @"i": @"moruyue_meet_24k.jpeg"},
        @{@"v": @"moziying_meet_24k", @"n": @"魔紫英", @"d": @"磁性浑厚，自然动听、影视|纪录片", @"i": @"moziying_meet_24k.png"},
        @{@"v": @"moxiaoling_meet_24k", @"n": @"魔晓玲", @"d": @"成熟知性，温婉大方 、影视|情感", @"i": @"moxiaoling_meet_24k.png"},
        @{@"v": @"mofeifan_meet_24k", @"n": @"魔非凡", @"d": @"真实自然，朗朗动听 、影视|情感", @"i": @"mofeifan_meet_24k.png"},
        @{@"v": @"moxuanxiao_meet_24k", @"n": @"魔玄霄", @"d": @"真实自然，朗朗动听 、资讯|影视", @"i": @"moxuanxiao_meet_24k.png"},
        @{@"v": @"mohaotian_meet_24k", @"n": @"魔昊天", @"d": @"阳光帅气，爽朗动听、资讯|影视", @"i": @"mohaotian_meet_24k.png"},
        @{@"v": @"mowenji_meet_24k", @"n": @"魔文姬", @"d": @"元气少女，乖甜可爱 、资讯|影视", @"i": @"mowenji_meet_24k.png"},
        @{@"v": @"aya_meet_24k", @"n": @"阿雅", @"d": @"亲切温和，自然流畅、资讯|影视", @"i": @"aya_meet_24k.png"},
        @{@"v": @"moqingxia_meet_24k", @"n": @"魔青霞", @"d": @"成熟知性，温婉大方 、广告", @"i": @"moqingxia_meet_24k.jpeg"},
        @{@"v": @"mosiqi_meet_24k", @"n": @"魔司棋", @"d": @"成熟知性，流畅自然、资讯|影视", @"i": @"mosiqi_meet_24k.png"},
        @{@"v": @"mowenshu_meet_24k", @"n": @"魔文殊", @"d": @"磁性浑厚，爽朗动听、影视", @"i": @"mowenshu_meet_24k.png"},
        @{@"v": @"moxuemei_meet_24k", @"n": @"魔雪梅", @"d": @"成熟温柔，悦耳动听、影视|有声书", @"i": @"moxuemei_meet_24k.png"},
        @{@"v": @"mozhuge_meet_24k", @"n": @"魔诸葛", @"d": @"磁性浑厚，自然动听 、资讯|影视", @"i": @"mozhuge_meet_24k.png"},
        @{@"v": @"amo_meet_24k", @"n": @"阿墨", @"d": @"成熟老练，朗朗动听、美食", @"i": @"amo_meet_24k.png"},
        @{@"v": @"ajiao_meet_24k", @"n": @"阿娇", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"ajiao_meet_24k.png"},
        @{@"v": @"momengyan_meet_24k", @"n": @"魔梦妍", @"d": @"温柔知性，温婉大方、情感", @"i": @"momengyan_meet_24k.jpeg"},
        @{@"v": @"momeixuan_meet_24k", @"n": @"魔梅萱", @"d": @"可爱清新，清脆欢快、影视|情感", @"i": @"momeixuan_meet_24k.png"},
        @{@"v": @"molingfeng_meet_24k", @"n": @"魔凌峰", @"d": @"磁性浑厚，爽朗动听、影视|情感", @"i": @"molingfeng_meet_24k.png"},
        @{@"v": @"moqianchuan_meet_24k", @"n": @"魔千川", @"d": @"磁性浑厚，朗朗动听 、影视", @"i": @"moqianchuan_meet_24k.png"},
        @{@"v": @"lin_meet_24k", @"n": @"魔晓萱", @"d": @"温柔柔软，纯净轻快、资讯|影视", @"i": @"lin_meet_24k.png"},
        @{@"v": @"molingbing_meet_24k", @"n": @"魔凌冰", @"d": @"成熟温柔，悦耳动听、资讯|影视", @"i": @"molingbing_meet_24k.png"},
        @{@"v": @"chuyaping_meet_24k", @"n": @"魔灵儿", @"d": @"节奏明快，自然动听、直播", @"i": @"chuyaping_meet_24k.png"},
        @{@"v": @"yingqiong_meet_24k", @"n": @"英琼", @"d": @"亲切温和，自然流畅、资讯", @"i": @"yingqiong_meet_24k.png"},
        @{@"v": @"zhuanger_meet_24k", @"n": @"庄儿", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"zhuanger_meet_24k.png"},
        @{@"v": @"moningxiang_meet_24k", @"n": @"魔凝香", @"d": @"成熟温柔，悦耳动听 、资讯|影视", @"i": @"moningxiang_meet_24k.png"},
        @{@"v": @"chunchun_meet_24k", @"n": @"春春", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"chunchun_meet_24k.png"},
        @{@"v": @"monandi_meet_24k", @"n": @"魔南帝", @"d": @"磁性浑厚，爽朗动听、影视", @"i": @"monandi_meet_24k.png"},
        @{@"v": @"lili_meet_24k", @"n": @"丽丽", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lili_meet_24k.png"},
        @{@"v": @"mojiaxin_meet_24k", @"n": @"魔家欣", @"d": @"真实自然，朗朗动听、资讯|影视", @"i": @"mojiaxin_meet_24k.png"},
        @{@"v": @"jiuweihu_meet_24k", @"n": @"九尾狐", @"d": @"魅惑妲己，娇软动听、影视|游戏", @"i": @"jiuweihu_meet_24k.png"},
        @{@"v": @"shujun_meet_24k", @"n": @"淑君", @"d": @"亲切温和，自然流畅、情感", @"i": @"shujun_meet_24k.png"},
        @{@"v": @"mowutong_meet_24k", @"n": @"魔舞桐", @"d": @"元气少女，悦耳动听 、资讯|影视", @"i": @"mowutong_meet_24k.jpeg"},
        @{@"v": @"moxiaodou_meet_24k", @"n": @"魔小逗", @"d": @"搞笑夹子，沙雕谐趣、娱乐|游戏", @"i": @"moxiaodou_meet_24k.png"},
        @{@"v": @"qiqi_meet_24k", @"n": @"魔嫣然", @"d": @"亲切温和，自然流畅、资讯|游戏", @"i": @"qiqi_meet_24k.png"},
        @{@"v": @"mohuaan_meet_24k", @"n": @"魔华安", @"d": @"磁性浑厚，自然动听 、影视", @"i": @"mohuaan_meet_24k.png"},
        @{@"v": @"lingling_meet_24k", @"n": @"玲玲", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"lingling_meet_24k.png"},
        @{@"v": @"wenwen_meet_24k", @"n": @"玟玟", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"wenwen_meet_24k.png"},
        @{@"v": @"momoli_meet_24k", @"n": @"魔茉莉", @"d": @"元气少女，自然动听、影视", @"i": @"momoli_meet_24k.png"},
        @{@"v": @"yuer_meet_24k", @"n": @"玉儿", @"d": @"成熟知性，自然流畅、资讯|游戏", @"i": @"yuer_meet_24k.png"},
        @{@"v": @"alan_meet_24k", @"n": @"阿岚", @"d": @"亲切温和，自然流畅、资讯|情感", @"i": @"alan_meet_24k.png"},
        @{@"v": @"huier_meet_24k", @"n": @"慧儿", @"d": @"亲切温和，自然流畅、资讯", @"i": @"huier_meet_24k.png"},
        @{@"v": @"cissy_meet_24k", @"n": @"小娜", @"d": @"自然淳朴、资讯|情感", @"i": @"cissy_meet_24k.png"},
        @{@"v": @"BV213_streaming", @"n": @"旭成", @"d": @"剪映同款、热门特色方言、广西表哥、官方授权", @"i": @"BV213_streaming.png"},
        @{@"v": @"BV021_streaming", @"n": @"旭昊", @"d": @"剪映同款、热门特色方言、东北老铁、官方授权", @"i": @"BV021_streaming.png"},
        @{@"v": @"BV019_streaming", @"n": @"旭庆", @"d": @"剪映同款、热门特色方言、重庆小伙、官方授权", @"i": @"BV019_streaming.png"},
        @{@"v": @"azure_zh-CN-shandong-YunxiangNeural", @"n": @"云翔", @"d": @"山东话、宣传、解说男声", @"i": @"azure_zh-CN-shandong-YunxiangNeural.png"},
        @{@"v": @"azure_zh-CN-henan-YundengNeural", @"n": @"云登", @"d": @"河南话、广告、宣传男声", @"i": @"azure_zh-CN-henan-YundengNeural.png"},
        @{@"v": @"azure_zh-CN-sichuan-YunxiNeural", @"n": @"云熙", @"d": @"四川话、宣传、解说男声", @"i": @"azure_zh-CN-sichuan-YunxiNeural.png"},
        @{@"v": @"azure_wuu-CN-XiaotongNeural", @"n": @"晓彤", @"d": @"上海话、阅读、解说温柔女声", @"i": @"azure_wuu-CN-XiaotongNeural.png"},
        @{@"v": @"azure_wuu-CN-YunzheNeural", @"n": @"云喆", @"d": @"上海话、广告、解说男声", @"i": @"azure_wuu-CN-YunzheNeural.png"},
        @{@"v": @"azure_yue-CN-XiaoMinNeural", @"n": @"晓敏", @"d": @"粤语年轻女声、宣传、广告、客服", @"i": @"azure_yue-CN-XiaoMinNeural.png"},
        @{@"v": @"azure_yue-CN-YunSongNeural", @"n": @"云松", @"d": @"粤语、宣传、广告男声", @"i": @"azure_yue-CN-YunSongNeural.jpg"},
    ];
}

// 讯飞音色（268 个）
// 字段：v=vid  n=名称  d=描述  i=头像(img路径，缺省拼前缀；@开头用讯飞前缀；http开头为完整URL)
static NSArray<NSDictionary *> *ddTTVBuiltinXFVoices(void) {
    return @[
        @{@"v": @"130097", @"n": @"天明", @"d": @"亲切温和,叙述（品质）", @"i": @"@1646709599103_2c0069a4cbedef10968bc0a1477f9b65.jpg"},
        @{@"v": @"130005", @"n": @"天明", @"d": @"亲切温和,叙述（标准）", @"i": @"@1666419568247_2c0069a4cbedef10968bc0a1477f9b65.jpg"},
        @{@"v": @"65271", @"n": @"天明", @"d": @"亲切温和,生气", @"i": @"@1666419568247_2c0069a4cbedef10968bc0a1477f9b65.jpg"},
        @{@"v": @"65272", @"n": @"天明", @"d": @"亲切温和,悲伤", @"i": @"@1666419568247_2c0069a4cbedef10968bc0a1477f9b65.jpg"},
        @{@"v": @"20079", @"n": @"天明", @"d": @"亲切温和,叙述", @"i": @"@1666419568247_2c0069a4cbedef10968bc0a1477f9b65.jpg"},
        @{@"v": @"130210", @"n": @"聆玉言", @"d": @"成熟知性,超拟人", @"i": @"@1713428685247_f9e321cce86d7f10e646faf56367c542.jpg"},
        @{@"v": @"607538082", @"n": @"聆玉言", @"d": @"成熟知性,知性讲解", @"i": @"@1713428685247_f9e321cce86d7f10e646faf56367c542.jpg"},
        @{@"v": @"581593897", @"n": @"知性女性-雅琴", @"d": @"成熟知性,教培", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241121/0641fff6-95fa-4b72-8953-bac46a7c52a6.png"},
        @{@"v": @"591593897", @"n": @"知性女性-雅琴", @"d": @"成熟知性,新闻", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241121/0641fff6-95fa-4b72-8953-bac46a7c52a6.png"},
        @{@"v": @"571593897", @"n": @"知性女性-雅琴", @"d": @"成熟知性,自然对话", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241121/0641fff6-95fa-4b72-8953-bac46a7c52a6.png"},
        @{@"v": @"130099", @"n": @"关山", @"d": @"大气浑厚,叙述（品质）", @"i": @"@1655690485405_54cabb0ded6abb9ae9036c51fc9dec05.png"},
        @{@"v": @"130117", @"n": @"关山", @"d": @"大气浑厚,纪录片（品质）", @"i": @"@1655690485405_54cabb0ded6abb9ae9036c51fc9dec05.png"},
        @{@"v": @"130026", @"n": @"关山", @"d": @"大气浑厚,叙述", @"i": @"@1655690485405_54cabb0ded6abb9ae9036c51fc9dec05.png"},
        @{@"v": @"130031", @"n": @"关山", @"d": @"大气浑厚,纪录片", @"i": @"@1655690485405_54cabb0ded6abb9ae9036c51fc9dec05.png"},
        @{@"v": @"561236098", @"n": @"聆小琪", @"d": @"温柔甜美,自然解说", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"130211", @"n": @"聆小琪", @"d": @"温柔甜美,超拟人", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"130101", @"n": @"聆小琪", @"d": @"温柔甜美,知识分享", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"130120", @"n": @"聆小琪", @"d": @"温柔甜美,大会主持", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"548505522", @"n": @"聆小琪", @"d": @"温柔甜美,教育培训", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"580422678", @"n": @"聆小琪", @"d": @"温柔甜美,语音助手", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"130121", @"n": @"聆小琪", @"d": @"温柔甜美,高兴", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"130134", @"n": @"聆小琪", @"d": @"温柔甜美,悲伤", @"i": @"@1713428599926_85e94df1071887d0477bb3d9aae87083.jpg"},
        @{@"v": @"65270", @"n": @"娱乐-野哥", @"d": @"诙谐幽默,叙述", @"i": @"@1646711563420_0c90bcae9c905c06aefb943a3436a1e5.jpg"},
        @{@"v": @"130275", @"n": @"娱乐-一航", @"d": @"激情力度,体育", @"i": @"@1726727047291_0871ccac91b8689f2c03a7c1b5decf75.jpg"},
        @{@"v": @"130276", @"n": @"娱乐-一航", @"d": @"激情力度,有声", @"i": @"@1726727047291_0871ccac91b8689f2c03a7c1b5decf75.jpg"},
        @{@"v": @"130277", @"n": @"娱乐-一航", @"d": @"激情力度,解说", @"i": @"@1726727047291_0871ccac91b8689f2c03a7c1b5decf75.jpg"},
        @{@"v": @"130278", @"n": @"娱乐-一航", @"d": @"激情力度,沉稳", @"i": @"@1726727047291_0871ccac91b8689f2c03a7c1b5decf75.jpg"},
        @{@"v": @"130102", @"n": @"新闻-小果", @"d": @"成熟知性,新闻（品质）", @"i": @"@1646717470635_0c9f665e0ede3beaa206a222a2e407ad.jpg"},
        @{@"v": @"20065", @"n": @"新闻-小果", @"d": @"成熟知性,新闻", @"i": @"@1646717470635_0c9f665e0ede3beaa206a222a2e407ad.jpg"},
        @{@"v": @"130035", @"n": @"阿森", @"d": @"年轻时尚,解说", @"i": @"@1660273449838_b296969a27c5596e4ec3b6edf47f66c3.png"},
        @{@"v": @"130182", @"n": @"阿森", @"d": @"年轻时尚,解说（舒缓）", @"i": @"@1660273449838_b296969a27c5596e4ec3b6edf47f66c3.png"},
        @{@"v": @"130206", @"n": @"聆飞逸", @"d": @"自然流畅,超拟人", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/07976add-0e05-4198-9171-3b592301b3ff.png"},
        @{@"v": @"130105", @"n": @"小露", @"d": @"可爱甜美,语音助手（品质）", @"i": @"@1646717942391_e49ece76fedbe18b97a457db5464e704.jpg"},
        @{@"v": @"130006", @"n": @"小露", @"d": @"可爱甜美,语音助手（标准）", @"i": @"@1646717942391_e49ece76fedbe18b97a457db5464e704.jpg"},
        @{@"v": @"130009", @"n": @"小露", @"d": @"可爱甜美,可爱", @"i": @"@1646717942391_e49ece76fedbe18b97a457db5464e704.jpg"},
        @{@"v": @"20070", @"n": @"小露", @"d": @"可爱甜美,语音助手", @"i": @"@1646717942391_e49ece76fedbe18b97a457db5464e704.jpg"},
        @{@"v": @"130258", @"n": @"主持-欣雅", @"d": @"成熟知性、大气浑厚,大会主持", @"i": @"@1720621878865_8dbb934c2d91f9f5d0d4bbeb74c6722b.jpg"},
        @{@"v": @"130256", @"n": @"小北", @"d": @"诙谐幽默、淳朴方言,冷幽默", @"i": @"@1709113163247_7293f87c18a8ab4a7a0c8a6f7cd24085.png"},
        @{@"v": @"130257", @"n": @"小北", @"d": @"诙谐幽默、淳朴方言,冷幽默", @"i": @"@1709113163247_7293f87c18a8ab4a7a0c8a6f7cd24085.png"},
        @{@"v": @"130208", @"n": @"聆小玥", @"d": @"温柔甜美、亲切温和,聆小玥-超拟人", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/af7f6677-4613-4aa2-b3d9-3b02a2cac321.png"},
        @{@"v": @"130109", @"n": @"超哥", @"d": @"自然流畅,新闻（品质）", @"i": @"@1646711380488_0d1377bf76b8ce694c85d37d1e137b87.jpg"},
        @{@"v": @"20051", @"n": @"超哥", @"d": @"自然流畅,新闻", @"i": @"@1646711380488_0d1377bf76b8ce694c85d37d1e137b87.jpg"},
        @{@"v": @"130254", @"n": @"欣悦", @"d": @"激情力度、自然流畅,口播", @"i": @"@1729243161419_3630bdafa1cc08ac99cf097a4064b45e.png"},
        @{@"v": @"130218", @"n": @"欣悦", @"d": @"激情力度、自然流畅,心灵鸡汤", @"i": @"@1729243161419_3630bdafa1cc08ac99cf097a4064b45e.png"},
        @{@"v": @"130217", @"n": @"欣悦", @"d": @"激情力度、自然流畅,直播", @"i": @"@1729243161419_3630bdafa1cc08ac99cf097a4064b45e.png"},
        @{@"v": @"130180", @"n": @"小俊", @"d": @"激情力度,广告（品质）", @"i": @"@1646721281265_428bbc5cdc2bf582f988d398e254959d.jpg"},
        @{@"v": @"65070", @"n": @"小俊", @"d": @"激情力度,广告", @"i": @"@1646721281265_428bbc5cdc2bf582f988d398e254959d.jpg"},
        @{@"v": @"130272", @"n": @"欣瑶", @"d": @"亲切温和、自然流畅,情感", @"i": @"@1721805644715_c55c33f1eb59df9e52156378dac200b2.png"},
        @{@"v": @"130271", @"n": @"欣瑶", @"d": @"亲切温和、自然流畅,教培", @"i": @"@1721805644715_c55c33f1eb59df9e52156378dac200b2.png"},
        @{@"v": @"130270", @"n": @"欣瑶", @"d": @"亲切温和、自然流畅,直播", @"i": @"@1721805644715_c55c33f1eb59df9e52156378dac200b2.png"},
        @{@"v": @"583035492", @"n": @"东北老弟-子阳", @"d": @"诙谐幽默、淳朴方言,就是那个东北味", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/4fd5f637-1ba3-45a9-9f73-6b62474b8243.png"},
        @{@"v": @"590944082", @"n": @"呆萌儿童-聆佑佑", @"d": @"呆萌可爱,呆萌", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/60097eb9-45be-47c8-8603-c723661d7e38.png"},
        @{@"v": @"540617550", @"n": @"呆萌儿童-聆佑佑", @"d": @"呆萌可爱,可爱", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/60097eb9-45be-47c8-8603-c723661d7e38.png"},
        @{@"v": @"130143", @"n": @"聆伯松", @"d": @"稳重磁性,有声小说（威严）", @"i": @"@1690788223145_ed449dfde9a4e176cdfc4fb70797dc56.jpg"},
        @{@"v": @"130142", @"n": @"聆伯松", @"d": @"稳重磁性,有声小说（日常）", @"i": @"@1690788223145_ed449dfde9a4e176cdfc4fb70797dc56.jpg"},
        @{@"v": @"130115", @"n": @"聆飞泓", @"d": @"大气浑厚,纪录片", @"i": @"@1669971779537_9073aedcaa0720a0a5a63b02191346fe.jpg"},
        @{@"v": @"130098", @"n": @"聆飞泓", @"d": @"大气浑厚,叙述", @"i": @"@1669971779537_9073aedcaa0720a0a5a63b02191346fe.jpg"},
        @{@"v": @"130219", @"n": @"明宇", @"d": @"激情力度、年轻时尚,教育培训", @"i": @"@1713782287512_6686baa5ded96261bb277da53ad041f6.jpg"},
        @{@"v": @"130213", @"n": @"明宇", @"d": @"激情力度、年轻时尚,直播", @"i": @"@1713782287512_6686baa5ded96261bb277da53ad041f6.jpg"},
        @{@"v": @"130181", @"n": @"聆小珊", @"d": @"亲切温和,资讯讲解", @"i": @"@1702372913956_c52d1cd44f3910c904a56bae5741bb1c.jpg"},
        @{@"v": @"130110", @"n": @"聆小珊", @"d": @"亲切温和,新闻", @"i": @"@1702372913956_c52d1cd44f3910c904a56bae5741bb1c.jpg"},
        @{@"v": @"130055", @"n": @"聆飞瀚", @"d": @"稳重磁性,纪录片", @"i": @"@1669905428074_7cd2ccfce46ad53bfeb0e78e706a8770.jpg"},
        @{@"v": @"130160", @"n": @"小娟", @"d": @"成熟知性,甜美（品质）", @"i": @"@1646731704817_ff1e1392047fba4e15d5ce51125733bc.jpeg"},
        @{@"v": @"130013", @"n": @"小娟", @"d": @"成熟知性,甜美", @"i": @"@1646731704817_ff1e1392047fba4e15d5ce51125733bc.jpeg"},
        @{@"v": @"130014", @"n": @"小娟", @"d": @"成熟知性,温情", @"i": @"@1646731704817_ff1e1392047fba4e15d5ce51125733bc.jpeg"},
        @{@"v": @"60026", @"n": @"小娟", @"d": @"成熟知性,客服", @"i": @"@1646731704817_ff1e1392047fba4e15d5ce51125733bc.jpeg"},
        @{@"v": @"130138", @"n": @"管哥", @"d": @"稳重磁性,叙述（品质）", @"i": @"@1646718342906_3f73d68506cdaa3d39fe294c053217dc.jpg"},
        @{@"v": @"130016", @"n": @"管哥", @"d": @"稳重磁性,叙述（标准）", @"i": @"@1646718342906_3f73d68506cdaa3d39fe294c053217dc.jpg"},
        @{@"v": @"20081", @"n": @"管哥", @"d": @"稳重磁性,叙述", @"i": @"@1646718342906_3f73d68506cdaa3d39fe294c053217dc.jpg"},
        @{@"v": @"130250", @"n": @"译制片女", @"d": @"诙谐幽默,译制片", @"i": @"@1717031979756_dc1b43251d57649a078fdb56902b54c0.png"},
        @{@"v": @"130193", @"n": @"萧文", @"d": @"年轻时尚,萧文", @"i": @"@1703667818242_5b6fedc721857afed1e7f243339e122a.jpg"},
        @{@"v": @"130273", @"n": @"广告-飞碟哥", @"d": @"诙谐幽默,营销", @"i": @"@1646719126631_08ee2698685b040d6f910e9ea272cf80.jpg"},
        @{@"v": @"130040", @"n": @"广告-飞碟哥", @"d": @"诙谐幽默,广告（标准）", @"i": @"@1646719126631_08ee2698685b040d6f910e9ea272cf80.jpg"},
        @{@"v": @"130184", @"n": @"广告-飞碟哥", @"d": @"诙谐幽默,广告（品质）", @"i": @"@1646719126631_08ee2698685b040d6f910e9ea272cf80.jpg"},
        @{@"v": @"20061", @"n": @"广告-飞碟哥", @"d": @"诙谐幽默,广告", @"i": @"@1646719126631_08ee2698685b040d6f910e9ea272cf80.jpg"},
        @{@"v": @"130163", @"n": @"一峰", @"d": @"稳重磁性,新闻（品质）", @"i": @"@1646730417298_66443b3ea57412a8c92130fc67b6847d.jpg"},
        @{@"v": @"130022", @"n": @"一峰", @"d": @"稳重磁性,新闻（标准）", @"i": @"@1646730417298_66443b3ea57412a8c92130fc67b6847d.jpg"},
        @{@"v": @"20072", @"n": @"一峰", @"d": @"稳重磁性,新闻", @"i": @"@1646730417298_66443b3ea57412a8c92130fc67b6847d.jpg"},
        @{@"v": @"130191", @"n": @"子雯", @"d": @"温柔甜美,台湾普通话-子雯", @"i": @"@1703667205575_975b1a990154c40681a60856a2fe4050.jpg"},
        @{@"v": @"130161", @"n": @"子悠", @"d": @"温柔甜美,口播", @"i": @"@1702372634297_1f5a2f4bca74f36d829ec108cc9b0b0e.jpg"},
        @{@"v": @"130139", @"n": @"子悠", @"d": @"温柔甜美,日常", @"i": @"@1702372634297_1f5a2f4bca74f36d829ec108cc9b0b0e.jpg"},
        @{@"v": @"130114", @"n": @"小鹏", @"d": @"稳重磁性,日常（品质）", @"i": @"@1646718051947_0e541fe6a5cfc28c284c019ce5f0889f.jpg"},
        @{@"v": @"20082", @"n": @"小鹏", @"d": @"稳重磁性,日常", @"i": @"@1646718051947_0e541fe6a5cfc28c284c019ce5f0889f.jpg"},
        @{@"v": @"130204", @"n": @"聆小璇", @"d": @"可爱甜美,超拟人", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130058", @"n": @"聆小璇", @"d": @"可爱甜美,自然讲解", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130050", @"n": @"聆小璇", @"d": @"可爱甜美,日常", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130085", @"n": @"聆小璇", @"d": @"可爱甜美,高兴", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130087", @"n": @"聆小璇", @"d": @"可爱甜美,悲伤", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130088", @"n": @"聆小璇", @"d": @"可爱甜美,严肃", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130089", @"n": @"聆小璇", @"d": @"可爱甜美,困惑", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130086", @"n": @"聆小璇", @"d": @"可爱甜美,抱歉", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"130051", @"n": @"聆小璇", @"d": @"可爱甜美,撒娇", @"i": @"@1713428668289_2d77a63d7bf2f15dd97ef4bd332af5f0.jpg"},
        @{@"v": @"523064535", @"n": @"楚哥", @"d": @"年轻时尚,资讯讲解", @"i": @"@1688111219049_4f777b7c8a50e493a2d2d747b28ececc.jpg"},
        @{@"v": @"130106", @"n": @"小钟", @"d": @"亲切温和,新闻（品质）", @"i": @"@1646720432037_697ae3d679f37a349fcc80e541f7df7c.jpg"},
        @{@"v": @"130011", @"n": @"小钟", @"d": @"亲切温和,新闻", @"i": @"@1646720432037_697ae3d679f37a349fcc80e541f7df7c.jpg"},
        @{@"v": @"130174", @"n": @"皓宇", @"d": @"年轻时尚,解说（品质）", @"i": @"@1646711646054_7b3e01f23010fc57ba8816baae0978bb.png"},
        @{@"v": @"130002", @"n": @"皓宇", @"d": @"年轻时尚,解说", @"i": @"@1646711646054_7b3e01f23010fc57ba8816baae0978bb.png"},
        @{@"v": @"130111", @"n": @"千雪", @"d": @"亲切温和,叙述（品质）", @"i": @"@1646727203889_dfe514e0f43bc0ed262383cea80466ac.jpg"},
        @{@"v": @"130008", @"n": @"千雪", @"d": @"亲切温和,叙述", @"i": @"@1646727203889_dfe514e0f43bc0ed262383cea80466ac.jpg"},
        @{@"v": @"521617550", @"n": @"豪叔", @"d": @"稳重磁性,豪叔", @"i": @"@1704872318717_4d45b9679c9c3c90df0b9f1f52a9275b.jpg"},
        @{@"v": @"130194", @"n": @"子韫", @"d": @"亲切温和,子韫", @"i": @"@1705566426969_4d1c6fb1d53dce1e5730528e2c5d439f.jpg"},
        @{@"v": @"534720886", @"n": @"直播-晓晗", @"d": @"自然流畅,口语直播", @"i": @"@1687334665564_73d6652d4609cf411c871adf42c927ec.jpg"},
        @{@"v": @"130167", @"n": @"直播-晓晗", @"d": @"自然流畅,直播（新）", @"i": @"@1687334665564_73d6652d4609cf411c871adf42c927ec.jpg"},
        @{@"v": @"130140", @"n": @"直播-晓晗", @"d": @"自然流畅,直播", @"i": @"@1687334665564_73d6652d4609cf411c871adf42c927ec.jpg"},
        @{@"v": @"130164", @"n": @"七哥", @"d": @"自然流畅,日常（品质）", @"i": @"@1646711810619_20fdc69e57ccbd058dc8a26ccf6226a0.jpg"},
        @{@"v": @"130007", @"n": @"七哥", @"d": @"自然流畅,日常（标准）", @"i": @"@1646711810619_20fdc69e57ccbd058dc8a26ccf6226a0.jpg"},
        @{@"v": @"20053", @"n": @"七哥", @"d": @"自然流畅,日常", @"i": @"@1646711810619_20fdc69e57ccbd058dc8a26ccf6226a0.jpg"},
        @{@"v": @"541617550", @"n": @"小恬", @"d": @"温柔甜美,小恬", @"i": @"@1704872866885_ca0267bc28f2d75af886f7817205e751.jpg"},
        @{@"v": @"130255", @"n": @"淑芬", @"d": @"成熟知性,口播", @"i": @"@1692685117787_1f037a9f3d782cb678a1580b11dc1fa2.png"},
        @{@"v": @"130150", @"n": @"淑芬", @"d": @"成熟知性,淑芬", @"i": @"@1692685117787_1f037a9f3d782cb678a1580b11dc1fa2.png"},
        @{@"v": @"130107", @"n": @"一菲", @"d": @"温柔甜美,日常（品质）", @"i": @"@1646719515453_c21c524605b11f95154068c3da328266.jpg"},
        @{@"v": @"130012", @"n": @"一菲", @"d": @"温柔甜美,日常（标准）", @"i": @"@1646719515453_c21c524605b11f95154068c3da328266.jpg"},
        @{@"v": @"20073", @"n": @"一菲", @"d": @"温柔甜美,日常", @"i": @"@1646719515453_c21c524605b11f95154068c3da328266.jpg"},
        @{@"v": @"130192", @"n": @"静怡", @"d": @"可爱甜美,静怡", @"i": @"@1703667528931_c4d051b21ec5a37b3ce2ead0400978a0.jpg"},
        @{@"v": @"130205", @"n": @"聆飞哲", @"d": @"年轻时尚,超拟人", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"589517550", @"n": @"聆飞哲", @"d": @"年轻时尚,自然", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"569517550", @"n": @"聆飞哲", @"d": @"年轻时尚,讲解", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130119", @"n": @"聆飞哲", @"d": @"年轻时尚,叙述", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130057", @"n": @"聆飞哲", @"d": @"年轻时尚,小说", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130126", @"n": @"聆飞哲", @"d": @"年轻时尚,严肃", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130128", @"n": @"聆飞哲", @"d": @"年轻时尚,高兴", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130127", @"n": @"聆飞哲", @"d": @"年轻时尚,抱歉", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130054", @"n": @"聆飞哲", @"d": @"年轻时尚,日常", @"i": @"@1713428712096_3af47778cd819d5d91dd3bcfeae1ee51.jpg"},
        @{@"v": @"130136", @"n": @"小媛", @"d": @"亲切温和,新闻（品质）", @"i": @"@1646718626707_7ea3040030b3b642640e5637d74469f2.jpg"},
        @{@"v": @"60100", @"n": @"小媛", @"d": @"亲切温和,新闻", @"i": @"@1646718626707_7ea3040030b3b642640e5637d74469f2.jpg"},
        @{@"v": @"575380829", @"n": @"小光", @"d": @"自然流畅,广告（品质）", @"i": @"@1702373003605_db52d324dccc94b23f99e834ef7a1651.jpg"},
        @{@"v": @"65110", @"n": @"小光", @"d": @"自然流畅,广告", @"i": @"@1702373003605_db52d324dccc94b23f99e834ef7a1651.jpg"},
        @{@"v": @"65230", @"n": @"宝哥", @"d": @"诙谐幽默,幽默", @"i": @"@1646721077473_86adccba0dc48bd56e9104cbc6f717da.jpg"},
        @{@"v": @"130176", @"n": @"水哥", @"d": @"稳重磁性,叙述（品质）", @"i": @"@1662015464888_a7116a601f7bd7e06743ee3bc19c3282.jpg"},
        @{@"v": @"130039", @"n": @"水哥", @"d": @"稳重磁性,叙述（标准）", @"i": @"@1662015464888_a7116a601f7bd7e06743ee3bc19c3282.jpg"},
        @{@"v": @"20071", @"n": @"水哥", @"d": @"稳重磁性,叙述", @"i": @"@1662015464888_a7116a601f7bd7e06743ee3bc19c3282.jpg"},
        @{@"v": @"130207", @"n": @"聆玉昭", @"d": @"默认,超拟人", @"i": @"@1713428697677_cfd1eccb557250b190ce0a5cc6e22d06.jpg"},
        @{@"v": @"130100", @"n": @"明泽", @"d": @"年轻时尚,日常（品质）", @"i": @"@1655690509429_ffdb9bdcf8da46f6a3775d88a486da3d.png"},
        @{@"v": @"130030", @"n": @"明泽", @"d": @"年轻时尚,对话", @"i": @"@1655690509429_ffdb9bdcf8da46f6a3775d88a486da3d.png"},
        @{@"v": @"130027", @"n": @"明泽", @"d": @"年轻时尚,日常", @"i": @"@1655690509429_ffdb9bdcf8da46f6a3775d88a486da3d.png"},
        @{@"v": @"130135", @"n": @"小英", @"d": @"亲切温和,日常（品质）", @"i": @"@1646719162970_9dcea6ef5a6c20add7e8749f6caf1bfb.jpg"},
        @{@"v": @"65040", @"n": @"小英", @"d": @"亲切温和,日常", @"i": @"@1646719162970_9dcea6ef5a6c20add7e8749f6caf1bfb.jpg"},
        @{@"v": @"130186", @"n": @"小薛", @"d": @"年轻时尚,广告（品质）", @"i": @"@1702373434048_39c712fe9a4cabd48d76a9b07fe6203a.jpg"},
        @{@"v": @"65320", @"n": @"小薛", @"d": @"年轻时尚,广告", @"i": @"@1702373434048_39c712fe9a4cabd48d76a9b07fe6203a.jpg"},
        @{@"v": @"130147", @"n": @"悦小妮", @"d": @"可爱甜美,日常", @"i": @"@1691421131500_8cc224e78a8c834c3e603aeed37ad954.png"},
        @{@"v": @"130168", @"n": @"聆万万", @"d": @"呆萌可爱,叙述", @"i": @"@1699860605462_33a3ad667701255870c7848d5e9d328d.jpg"},
        @{@"v": @"130175", @"n": @"嘉欣", @"d": @"激情力度,直播（品质）", @"i": @"@1651303134366_41ab46b4c8a15bff054a737fd07491dd.jpg"},
        @{@"v": @"130018", @"n": @"嘉欣", @"d": @"激情力度,直播", @"i": @"@1651303134366_41ab46b4c8a15bff054a737fd07491dd.jpg"},
        @{@"v": @"20052", @"n": @"刚哥", @"d": @"稳重磁性,叙述", @"i": @"@1646727710791_c121c7c1a0d1f0db93317c7abfee4f6a.jpg"},
        @{@"v": @"130137", @"n": @"顾辉", @"d": @"自然流畅,日常（品质）", @"i": @"@1651802850004_237c927a5ca90b59dfd1325ad505995b.jpg"},
        @{@"v": @"130023", @"n": @"顾辉", @"d": @"自然流畅,日常", @"i": @"@1651802850004_237c927a5ca90b59dfd1325ad505995b.jpg"},
        @{@"v": @"130146", @"n": @"聆小瑜", @"d": @"温柔甜美,日常", @"i": @"@1691421227817_1f527255af6be1a060b5ea5f7eabfc8f.png"},
        @{@"v": @"130198", @"n": @"聆小瑜", @"d": @"温柔甜美,高兴", @"i": @"@1691421227817_1f527255af6be1a060b5ea5f7eabfc8f.png"},
        @{@"v": @"130199", @"n": @"聆小瑜", @"d": @"温柔甜美,撒娇", @"i": @"@1691421227817_1f527255af6be1a060b5ea5f7eabfc8f.png"},
        @{@"v": @"130201", @"n": @"聆小瑜", @"d": @"温柔甜美,严肃", @"i": @"@1691421227817_1f527255af6be1a060b5ea5f7eabfc8f.png"},
        @{@"v": @"130200", @"n": @"聆小瑜", @"d": @"温柔甜美,抱歉", @"i": @"@1691421227817_1f527255af6be1a060b5ea5f7eabfc8f.png"},
        @{@"v": @"130165", @"n": @"晓燕", @"d": @"亲切温和,日常（品质）", @"i": @"@1702373169419_306ef9015d7dbd3621512b40f9181c41.jpg"},
        @{@"v": @"130024", @"n": @"晓燕", @"d": @"亲切温和,日常（标准）", @"i": @"@1702373169419_306ef9015d7dbd3621512b40f9181c41.jpg"},
        @{@"v": @"60020", @"n": @"晓燕", @"d": @"亲切温和,日常", @"i": @"@1702373169419_306ef9015d7dbd3621512b40f9181c41.jpg"},
        @{@"v": @"674554542", @"n": @"聆飞晨", @"d": @"饱满活泼,日常", @"i": @"@1669905473043_86a9547f3a24e8658c73182d43b1183e.jpg"},
        @{@"v": @"130056", @"n": @"聆飞晨", @"d": @"饱满活泼,广告", @"i": @"@1669905473043_86a9547f3a24e8658c73182d43b1183e.jpg"},
        @{@"v": @"130116", @"n": @"聆飞晨", @"d": @"饱满活泼,广告2", @"i": @"@1669905473043_86a9547f3a24e8658c73182d43b1183e.jpg"},
        @{@"v": @"130141", @"n": @"段哥", @"d": @"诙谐幽默,幽默", @"i": @"@1690168845455_1688d7065eeb99c6a79f5d070bd44acd.jpg"},
        @{@"v": @"531617550", @"n": @"子超", @"d": @"年轻时尚,解说", @"i": @"@1701334761478_d6ac98f335270e99ae162b621a0e05d0.jpg"},
        @{@"v": @"130112", @"n": @"小璇", @"d": @"温柔甜美,日常", @"i": @"@1646730648647_8f113bf9e9acf35e7d4a1d2db463c388.jpg"},
        @{@"v": @"130185", @"n": @"小晚", @"d": @"诙谐幽默,叙述（品质）", @"i": @"@1646728088360_8ba7a8fc364d423f56629b986e9bc67a.jpg"},
        @{@"v": @"20069", @"n": @"小晚", @"d": @"诙谐幽默,叙述", @"i": @"@1646728088360_8ba7a8fc364d423f56629b986e9bc67a.jpg"},
        @{@"v": @"130189", @"n": @"玲姐姐", @"d": @"温柔甜美,玲姐姐（品质）", @"i": @"@1646722945715_b2227386eabe56a26cb2f4d7df431a6a.jpg"},
        @{@"v": @"130190", @"n": @"小桃丸", @"d": @"呆萌可爱,小桃丸（品质）", @"i": @"@1646722124338_ea2772ac7aca0e0612bcf06edf46ed3d.jpg"},
        @{@"v": @"60120", @"n": @"小桃丸", @"d": @"呆萌可爱,小桃丸", @"i": @"@1646722124338_ea2772ac7aca0e0612bcf06edf46ed3d.jpg"},
        @{@"v": @"130145", @"n": @"聆小岚", @"d": @"温柔甜美,日常", @"i": @"@1691379983131_551e5c48a973ea8dc7c5a71bd9d31112.png"},
        @{@"v": @"130187", @"n": @"韦香主", @"d": @"稳重磁性,小说（品质）", @"i": @"@1646722604054_93820c9fa21fca0d21bdb56480cb6fc2.jpg"},
        @{@"v": @"62070", @"n": @"韦香主", @"d": @"稳重磁性,小说", @"i": @"@1646722604054_93820c9fa21fca0d21bdb56480cb6fc2.jpg"},
        @{@"v": @"626175508", @"n": @"解说子茹", @"d": @"亲切温和,解说子茹", @"i": @"@1701081816669_beb65bc1f852ff586f7765b1749dfdda.png"},
        @{@"v": @"130178", @"n": @"御姐聆小芸", @"d": @"年轻时尚,御姐聆小芸", @"i": @"@1694679942539_e1edc45ab6ffdc9dbaafba0420072693.png"},
        @{@"v": @"20062", @"n": @"小雅", @"d": @"亲切温和,温柔", @"i": @"@1646728316774_753b6321f4c18ed7366734cd32106c86.jpg"},
        @{@"v": @"633870173", @"n": @"思婷", @"d": @"温柔甜美,自然", @"i": @"@1698078126735_774ff11494ada1c40c8ee8e8e43b55ae.jpg"},
        @{@"v": @"561470586", @"n": @"子轩", @"d": @"年轻时尚,日常", @"i": @"@1702372719871_b00439fc908046d490763d98800e3ee5.jpg"},
        @{@"v": @"520753808", @"n": @"秀英", @"d": @"成熟知性,讲解", @"i": @"@1692685176333_1e4cf098e7b87ede1ada63ae29367f07.png"},
        @{@"v": @"130044", @"n": @"聆小瑶", @"d": @"温柔甜美,日常", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130052", @"n": @"聆小瑶", @"d": @"温柔甜美,二次元", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130059", @"n": @"聆小瑶", @"d": @"温柔甜美,高兴", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130060", @"n": @"聆小瑶", @"d": @"温柔甜美,抱歉", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130061", @"n": @"聆小瑶", @"d": @"温柔甜美,撒娇", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130062", @"n": @"聆小瑶", @"d": @"温柔甜美,严肃", @"i": @"@1669905415004_9e17d9a0a43f5828fb8c236a2c81f4cd.jpg"},
        @{@"v": @"130177", @"n": @"聆飞远", @"d": @"年轻时尚,游戏解说", @"i": @"@1675321167818_647125d13bc5d45b513b14a9d57efda8.jpg"},
        @{@"v": @"130103", @"n": @"聆飞远", @"d": @"年轻时尚,游戏解说（舒缓）", @"i": @"@1675321167818_647125d13bc5d45b513b14a9d57efda8.jpg"},
        @{@"v": @"130048", @"n": @"聆小璎", @"d": @"温柔甜美,日常", @"i": @"@1669905450929_35bb981a9a8b78088456dcc97d3faaca.jpg"},
        @{@"v": @"130053", @"n": @"聆小璎", @"d": @"温柔甜美,高兴", @"i": @"@1669905450929_35bb981a9a8b78088456dcc97d3faaca.jpg"},
        @{@"v": @"130074", @"n": @"聆小璎", @"d": @"温柔甜美,严肃", @"i": @"@1669905450929_35bb981a9a8b78088456dcc97d3faaca.jpg"},
        @{@"v": @"130072", @"n": @"聆小璎", @"d": @"温柔甜美,抱歉", @"i": @"@1669905450929_35bb981a9a8b78088456dcc97d3faaca.jpg"},
        @{@"v": @"130073", @"n": @"聆小璎", @"d": @"温柔甜美,撒娇", @"i": @"@1669905450929_35bb981a9a8b78088456dcc97d3faaca.jpg"},
        @{@"v": @"130124", @"n": @"聆小瑧", @"d": @"激情力度,直播", @"i": @"@1702373857839_0c36d41066f6ff31c0afa599c2555f9f.jpg"},
        @{@"v": @"130123", @"n": @"聆飞皓", @"d": @"激情力度,直播", @"i": @"@1689234724169_acf4b9e50c1225b4981507c034ca86cc.png"},
        @{@"v": @"130104", @"n": @"聆飞皓", @"d": @"激情力度,广告", @"i": @"@1689234724169_acf4b9e50c1225b4981507c034ca86cc.png"},
        @{@"v": @"130149", @"n": @"娱小妹", @"d": @"温柔甜美,解说", @"i": @"@1694679203554_b38a7d69913e1e728d50dda7f2db24d5.png"},
        @{@"v": @"130148", @"n": @"桂花婶", @"d": @"成熟知性,解说", @"i": @"@1695783472841_1d23c3c9dc88cda6065681f770b0a7ed.jpg"},
        @{@"v": @"130049", @"n": @"聆小璐", @"d": @"亲切温和,日常", @"i": @"@1669905462006_2506859c0192e7199ecd1250d7d27b5c.jpg"},
        @{@"v": @"130118", @"n": @"希涵", @"d": @"自然流畅,解说（品质）", @"i": @"@1647223228659_652e417b6186bf94cd2b0c4e24b272c5.jpg"},
        @{@"v": @"130274", @"n": @"希涵", @"d": @"自然流畅,营销", @"i": @"@1647223228659_652e417b6186bf94cd2b0c4e24b272c5.jpg"},
        @{@"v": @"130004", @"n": @"希涵", @"d": @"自然流畅,解说", @"i": @"@1647223228659_652e417b6186bf94cd2b0c4e24b272c5.jpg"},
        @{@"v": @"130183", @"n": @"歪果仁讲中文", @"d": @"诙谐幽默,歪果仁讲中文", @"i": @"@1700634933567_54f34ebace4d76f699f50077c1814a4b.jpg"},
        @{@"v": @"130047", @"n": @"聆小琬", @"d": @"可爱甜美,日常", @"i": @"@1669905389784_dd33de2cad55ced641f946a8d477c6f3.jpg"},
        @{@"v": @"130113", @"n": @"诺诺", @"d": @"亲切温和,叙述", @"i": @"@1678414910106_5c31b5116bec2ca62de828ce8c940da5.png"},
        @{@"v": @"130188", @"n": @"萌小新", @"d": @"呆萌可爱,萌小新（品质）", @"i": @"@1646721909112_c286577376cd6da506476586de3c1aa0.jpg"},
        @{@"v": @"60170", @"n": @"萌小新", @"d": @"呆萌可爱,萌小新", @"i": @"@1646721909112_c286577376cd6da506476586de3c1aa0.jpg"},
        @{@"v": @"521280366", @"n": @"Gavin", @"d": @"稳重磁性,日常", @"i": @"@1692684490416_b25b534591d8f8fc025249ba96faf558.png"},
        @{@"v": @"130033", @"n": @"大圣", @"d": @"诙谐幽默,孙大圣", @"i": @"@1659600407184_2b28db2946f96a63a331a9cd3cf58c85.jpg"},
        @{@"v": @"130108", @"n": @"豆豆", @"d": @"呆萌可爱,可爱", @"i": @"@1649645397291_9f51076ffcae292e98fa161a4238456f.jpg"},
        @{@"v": @"62060", @"n": @"百合仙子", @"d": @"成熟知性,叙述", @"i": @"@1646727479216_1975795c0493505dec4d059f98d5826b.jpg"},
        @{@"v": @"130166", @"n": @"宁宁", @"d": @"呆萌可爱,可爱（品质）", @"i": @"@1646720758226_bfa253d28e62b511eb9da9179c8efff6.jpg"},
        @{@"v": @"70002", @"n": @"宁宁", @"d": @"呆萌可爱,可爱", @"i": @"@1646720758226_bfa253d28e62b511eb9da9179c8efff6.jpg"},
        @{@"v": @"130025", @"n": @"小芳", @"d": @"呆萌可爱,日常（标准）", @"i": @"@1692192235055_6b45ed51463b29a0e359ffc7ef309cf1.png"},
        @{@"v": @"62020", @"n": @"小芳", @"d": @"呆萌可爱,日常", @"i": @"@1692192235055_6b45ed51463b29a0e359ffc7ef309cf1.png"},
        @{@"v": @"20067", @"n": @"宣哥", @"d": @"稳重磁性,叙述", @"i": @"@1646726943402_4ec158e5c77e317a9e9ee39c08eb0eb9.jpg"},
        @{@"v": @"65010", @"n": @"小洋", @"d": @"大气浑厚,广告", @"i": @"@1646719996719_c62113de2d396f45bca5180c3e6f6e3a.jpg"},
        @{@"v": @"20055", @"n": @"小师", @"d": @"温柔甜美,日常", @"i": @"@1646711686978_168783bfc0c2e39898adaa3c438f226d.jpg"},
        @{@"v": @"534206576", @"n": @"河南老丘", @"d": @"淳朴方言,河南话", @"i": @"@1689303111794_8f589d724e821317b80342204693574b.jpg"},
        @{@"v": @"20078", @"n": @"天哥", @"d": @"大气浑厚,叙述", @"i": @"@1646729561001_88b6b7c85c2bb964f376ae57b15e5ba6.jpg"},
        @{@"v": @"65250", @"n": @"辉叔", @"d": @"稳重磁性,叙述", @"i": @"@1646725915259_d30dd853be73ee1be7e544ffd2243816.jpg"},
        @{@"v": @"130151", @"n": @"楠楠", @"d": @"呆萌可爱,可爱", @"i": @"@1696763379302_bc15db0c99172dc93d1c2e58a34d98ab.jpg"},
        @{@"v": @"60150", @"n": @"老马", @"d": @"稳重磁性,新闻", @"i": @"@1646725618170_6b4bb63abe0568933adb7f247767af68.jpg"},
        @{@"v": @"62010", @"n": @"小华", @"d": @"稳重磁性,讲解", @"i": @"@1646725316525_7a7cbbf907f61e09c0029f29972ffddd.jpg"},
        @{@"v": @"15675", @"n": @"小宇", @"d": @"稳重磁性,新闻", @"i": @"@1646724991959_802462f6bf26597f8568b6e060e9dfc7.jpg"},
        @{@"v": @"65360", @"n": @"瑶瑶", @"d": @"年轻时尚,广告", @"i": @"@1646723737383_ae6ecf8f826177fe5d69a98b2caac12c.jpg"},
        @{@"v": @"60030", @"n": @"小峰", @"d": @"稳重磁性,新闻", @"i": @"@1646723340259_2abe7ac826c29ee416b924c2bbd4b09b.jpg"},
        @{@"v": @"65340", @"n": @"小南", @"d": @"亲切温和,广告", @"i": @"@1646711547535_340c7e1bd39ba4e7bbf566c4b1159bbc.jpg"},
        @{@"v": @"65080", @"n": @"程程", @"d": @"激情力度,广告", @"i": @"@1646722335247_3d978de1acd55ce9f8b3cba4c2021536.jpg"},
        @{@"v": @"130037", @"n": @"成都宝儿", @"d": @"淳朴方言,成都话", @"i": @"@1661217926402_d8e87ebf8f876f66f9eac9cdf0e7b47e.jpg"},
        @{@"v": @"574508087", @"n": @"Linda", @"d": @"亲切温和,日常", @"i": @"@1646728943969_36d5589ee90c25a94d90ffed48a1d4cf.jpg"},
        @{@"v": @"591915994", @"n": @"Lydia", @"d": @"亲切温和,教育", @"i": @"@1701763302197_5ed2ce73ea6a1c6910e4c98c2e65d25e.jpg"},
        @{@"v": @"577473290", @"n": @"Luna", @"d": @"亲切温和,日常", @"i": @"@1692684985383_818468ddb460c3bd842a28f371bca99e.png"},
        @{@"v": @"602803663", @"n": @"Lucy", @"d": @"成熟知性,教育", @"i": @"@1692684811087_80eb0e612760f756547b660c4c71ba7d.png"},
        @{@"v": @"581915994", @"n": @"Lara", @"d": @"亲切温和,新闻", @"i": @"@1701761884873_da4fd8a50d64f47b1bac8b9a28e787cc.jpg"},
        @{@"v": @"560280366", @"n": @"Ryan", @"d": @"亲切温和,日常", @"i": @"@1692001748355_131b98dac8609f781484f08c22a8abaa.png"},
        @{@"v": @"554508087", @"n": @"Catherine", @"d": @"亲切温和,新闻", @"i": @"@1646729856216_f5c3ac4cbf092a063786243913a4c139.jpg"},
        @{@"v": @"564508087", @"n": @"Laura", @"d": @"亲切温和,教育", @"i": @"@1685697884634_6225af75e3236a8a90c46134b9cd91f5.jpg"},
        @{@"v": @"593800095", @"n": @"Alice", @"d": @"亲切温和,日常", @"i": @"@1690274117663_d93dd1ce2e1b5460c7302dd57fb517c5.jpg"},
        @{@"v": @"544508087", @"n": @"Amanda", @"d": @"亲切温和,教育", @"i": @"@1690274038625_aebc9194fddcf3974a6da894626df31e.jpg"},
        @{@"v": @"60027", @"n": @"粤语小月", @"d": @"淳朴方言,粤语", @"i": @"@1646721208676_e355a0775f8af6c872110c9b53e9d488.jpg"},
        @{@"v": @"20077", @"n": @"内蒙小包", @"d": @"淳朴方言,内蒙古", @"i": @"@1646724304396_5481e1dedf8f0dbcc67fac90f2fc759e.jpg"},
        @{@"v": @"20076", @"n": @"合肥小肥", @"d": @"淳朴方言,合肥话", @"i": @"@1646723914438_9aa3e6d73ddb7793176273b632fae930.jpg"},
        @{@"v": @"20075", @"n": @"湖北小王", @"d": @"淳朴方言,湖北话", @"i": @"@1646723580396_03aaf53a4ef42313d05b5c1d3dc8e239.jpg"},
        @{@"v": @"20074", @"n": @"山东小东", @"d": @"淳朴方言,山东话", @"i": @"@1646723208988_65b9a6e40854a17c846027a821ffaa75.jpg"},
        @{@"v": @"68040", @"n": @"东北晓倩", @"d": @"淳朴方言,东北话", @"i": @"@1646722756045_42dcb82b980e73dae0bde6812ac85a9a.jpg"},
        @{@"v": @"68010", @"n": @"湖南小强", @"d": @"淳朴方言,湖南话", @"i": @"@1646722301187_439e5283cf5277204d7068629e076ac2.jpg"},
        @{@"v": @"593035492", @"n": @"俄罗斯小哥-Evgenii", @"d": @"稳重磁性、亲切温和,俄语助手", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241114/a7687b33-7c35-4a80-85ee-cca46914b555.png"},
        @{@"v": @"14009", @"n": @"Yangjin", @"d": @"亲切温和,藏语Yangjin", @"i": @"@1697685353973_3f9a408fed97d9602dbb136388c7e7dc.png"},
        @{@"v": @"14008", @"n": @"Malgorzata", @"d": @"亲切温和,波兰语Malgorzata", @"i": @"@1697685031427_c1c477865010d7b8ea3e27df44be146e.png"},
        @{@"v": @"14007", @"n": @"Thuhien", @"d": @"亲切温和,越南语Thuhien", @"i": @"@1697684742771_29eeb04d53afd13c6b7e3e41dbbfe1f1.png"},
        @{@"v": @"14003", @"n": @"Dilare", @"d": @"亲切温和,维吾尔语Dilare", @"i": @"@1697684021337_2e51f1f011a616fa8ceec68cbbe6b2b0.png"},
        @{@"v": @"14005", @"n": @"Grace", @"d": @"成熟知性,菲律宾语Grace", @"i": @"@1693557024143_4d64c54580f10e9d039ec389ed37b319.png"},
        @{@"v": @"14004", @"n": @"Rania", @"d": @"成熟知性,阿拉伯语Rania", @"i": @"@1693551112794_1ac3a5836844f9e80a0a21016f9fc144.png"},
        @{@"v": @"14006", @"n": @"Pedro", @"d": @"稳重磁性,葡萄牙语Pedro", @"i": @"@1693554835344_127a3e2b682c7353038736ab615bd09e.png"},
        @{@"v": @"14002", @"n": @"Anna", @"d": @"亲切温和,意大利语Anna", @"i": @"@1693363642505_58f599d7d16dda6c6f89841d3c16e16f.png"},
        @{@"v": @"14001", @"n": @"Kris", @"d": @"亲切温和,印尼语Kris", @"i": @"@1693363573726_8e5995ef15ad631a5af245f1df5607b9.png"},
        @{@"v": @"548039623", @"n": @"Hashim", @"d": @"亲切温和,马来语Hashim", @"i": @"@1693363508966_3f6d0e1e31c1967ef07d646ad615baa1.png"},
        @{@"v": @"521655454", @"n": @"俄语姐姐-Keshu", @"d": @"亲切温和,俄语Keshu", @"i": @"@1693363390658_7eac3d4db8d7a5a3443c322ab4e33881.png"},
        @{@"v": @"538039623", @"n": @"Suparut", @"d": @"亲切温和,泰语Suparut", @"i": @"@1693363308469_6e4d220d0210e78e38ea4b360e2c2a4c.png"},
        @{@"v": @"680396237", @"n": @"Christiane", @"d": @"亲切温和,德语Christiane", @"i": @"@1689910037935_f85237cd63e173330a32ebf7948aa99e.png"},
        @{@"v": @"616554542", @"n": @"Miya", @"d": @"亲切温和,韩语Miya", @"i": @"https://openstorage.xfyousheng.com/asset/asset/20241122/15633392-343f-4503-b6b4-99aa92ee6db6.png"},
        @{@"v": @"580396237", @"n": @"Aurora", @"d": @"亲切温和,西班牙语Aurora", @"i": @"@1688715362455_99c8ef576f385bc322564d5694df6fc2.png"},
        @{@"v": @"528039623", @"n": @"Lisa", @"d": @"亲切温和,法语Lisa", @"i": @"@1687144553357_dfeacdebdd52607b78a0eca093c2ed7a.png"},
        @{@"v": @"564561400", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,温柔轻快", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"538984610", @"n": @"日本甜妹-中村樱", @"d": @"温柔甜美、亲切温和,复古播音", @"i": @"@1688717354729_d0284195e3ed58b1031d7297c7690c60.png"},
        @{@"v": @"130036", @"n": @"苏州苏小曦", @"d": @"淳朴方言,苏州话", @"i": @"@1661218773274_995882b996619ea85a44333150e7014e.jpg"},
        @{@"v": @"130034", @"n": @"合肥子沁", @"d": @"淳朴方言,合肥话", @"i": @"@1660201073931_bb78d23c22cf54b4395541c1228a436b.jpg"},
        @{@"v": @"130032", @"n": @"上海阮灵", @"d": @"淳朴方言,上海话", @"i": @"@1657866369906_bb77cc8fcccb7bd3bb646b602318afd4.jpg"},
        @{@"v": @"68080", @"n": @"陕西小莹", @"d": @"淳朴方言,陕西话", @"i": @"@1646731448291_ed1bd19beba83aef3b42bdaa1c5d550a.jpg"},
        @{@"v": @"10003", @"n": @"广东晓梅", @"d": @"淳朴方言,广东话", @"i": @"@1646730936274_dfb8de21906d3cdff3ef955688e5648d.jpg"},
        @{@"v": @"69030", @"n": @"Steve", @"d": @"稳重磁性,日常", @"i": @"@1646723126755_81b8a1b77068d06e1c8190825253066f.jpg"},
        @{@"v": @"68030", @"n": @"河南小坤", @"d": @"淳朴方言,河南话", @"i": @"@1646722047293_16416bd520c3c4410ba24559945e03f1.jpg"},
        @{@"v": @"68060", @"n": @"四川小蓉", @"d": @"淳朴方言,四川话", @"i": @"@1646721656482_9a3d2d06a2e8d3748ebe345bf1d76b93.jpg"},
    ];
}

// ===================== 音色管理（琅琅音色 / 讯飞音色） =====================

static NSString * const kDDTTVTypeLang = @"琅琅";   // 琅琅音色
static NSString * const kDDTTVTypeXF   = @"讯飞";   // 讯飞音色

// 联网刷新后的音色列表缓存
static NSString *ddTTVYsCachePath(void) {
    return [ddTTVBaseDir() stringByAppendingPathComponent:@"ys.json"];
}

// ys.json 下载地址（可配置代理前缀，国内网络走代理）
static NSString *ddTTVYsURL(void) {
    DDTextToVoiceConfig *cfg = DDTextToVoiceConfig.shared;
    NSString *url = [cfg stringForKey:kDDTTVYsURL];
    if (!url.length) url = @"https://raw.githubusercontent.com/curtinlv/PKCUpdateLog/refs/heads/main/ys.json";
    NSString *proxy = [cfg stringForKey:kDDTTVYsProxy];
    NSString *gh = @"https://raw.githubusercontent.com";
    if (proxy.length && [url hasPrefix:gh]) {
        url = [proxy stringByAppendingString:[url substringFromIndex:gh.length]];
    }
    return url;
}

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

// 读取缓存中的 ys.json（只取琅琅音色 / 讯飞音色）
static NSDictionary *ddTTVYsCachedGroups(void) {
    NSData *data = [NSData dataWithContentsOfFile:ddTTVYsCachePath()];
    if (!data.length) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class]) return nil;
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"琅琅音色", @"讯飞音色"]) {
        id grp = [json objectForKey:key];
        NSArray *list = [grp isKindOfClass:NSDictionary.class] ? [grp objectForKey:@"list"] : nil;
        if ([list isKindOfClass:NSArray.class] && list.count) [out setObject:list forKey:key];
    }
    return out.count ? out : nil;
}

// 当前生效的音色分组：优先联网刷新过的缓存，否则用内置数据
static NSDictionary *ddTTVVoiceGroups(void) {
    NSDictionary *cached = ddTTVYsCachedGroups();
    NSArray *langRaw = cached[@"琅琅音色"] ?: ddTTVBuiltinLangVoices();
    NSArray *xfRaw   = cached[@"讯飞音色"] ?: ddTTVBuiltinXFVoices();
    return @{kDDTTVTypeLang: ddTTVNormalizeVoices(langRaw, kDDTTVTypeLang),
             kDDTTVTypeXF:   ddTTVNormalizeVoices(xfRaw,   kDDTTVTypeXF)};
}

// 琅琅音色列表
static NSArray<NSDictionary *> *ddTTVLangVoices(void) {
    return [ddTTVVoiceGroups() objectForKey:kDDTTVTypeLang];
}

// 讯飞音色列表
static NSArray<NSDictionary *> *ddTTVXFVoices(void) {
    return [ddTTVVoiceGroups() objectForKey:kDDTTVTypeXF];
}

// 获取当前音色ID（默认琅琅第一个）
static NSString *ddTTVCurrentVoiceID(void) {
    NSString *vid = [DDTextToVoiceConfig.shared stringForKey:kDDTTVVoiceIDDefault];
    if (!vid.length) vid = [ddTTVLangVoices() firstObject][@"id"];
    return vid;
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

// 获取当前音色名称（用于显示）
static NSString *ddTTVCurrentVoiceName(void) {
    NSDictionary *v = ddTTVFindVoiceByID(ddTTVCurrentVoiceID());
    return v[@"name"] ?: @"未选择";
}

// 联网刷新音色列表（只缓存琅琅 / 讯飞两个分组）
static void ddTTVFetchVoiceList(void (^completion)(BOOL ok, NSString *msg)) {
    NSURL *url = [NSURL URLWithString:ddTTVYsURL()];
    if (!url) { if (completion) completion(NO, @"地址无效"); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data.length) {
                if (completion) completion(NO, error.localizedDescription ?: @"下载失败");
                return;
            }
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:NSDictionary.class]) {
                if (completion) completion(NO, @"数据格式错误");
                return;
            }
            id g1 = [json objectForKey:@"琅琅音色"];
            id g2 = [json objectForKey:@"讯飞音色"];
            NSUInteger n1 = ([g1 isKindOfClass:NSDictionary.class] && [[g1 objectForKey:@"list"] isKindOfClass:NSArray.class]) ? [[g1 objectForKey:@"list"] count] : 0;
            NSUInteger n2 = ([g2 isKindOfClass:NSDictionary.class] && [[g2 objectForKey:@"list"] isKindOfClass:NSArray.class]) ? [[g2 objectForKey:@"list"] count] : 0;
            if (!n1 && !n2) { if (completion) completion(NO, @"未找到琅琅/讯飞音色分组"); return; }
            NSDictionary *slim = @{@"琅琅音色": g1 ?: @{}, @"讯飞音色": g2 ?: @{}};
            NSData *out = [NSJSONSerialization dataWithJSONObject:slim options:0 error:nil];
            [out writeToFile:ddTTVYsCachePath() atomically:YES];
            if (completion) completion(YES, [NSString stringWithFormat:@"琅琅 %lu / 讯飞 %lu", (unsigned long)n1, (unsigned long)n2]);
        });
    }];
    [task resume];
}

// ===================== 语音合成（琅琅 / 讯飞） =====================

static NSError *ddTTVError(NSString *msg) {
    return [NSError errorWithDomain:@"DDTTV" code:-1
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

            __block NSInteger retry = 0;
            __block void (^poll)(void) = ^{
                long long t2 = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
                NSString *detailURL = [NSString stringWithFormat:@"%@/task/GetDetail?token=%@&t=%lld&taskId=%@",
                                       kDDTTVLangBase, token, t2, taskId];
                ddTTVGet(detailURL, ^(NSData *d3, NSError *e3) {
                    if (e3 || !d3.length) { if (completion) completion(nil, e3 ?: ddTTVError(@"查询任务失败")); return; }
                    id j3 = ddTTVJSON(d3);
                    NSString *audioUrl = [[j3 objectForKey:@"data"] objectForKey:@"audioUrl"];
                    if (audioUrl.length) {
                        ddTTVGet(audioUrl, ^(NSData *audio, NSError *e4) {
                            if (completion) completion((e4 || !audio.length) ? nil : audio,
                                                       e4 ?: (audio.length ? nil : ddTTVError(@"音频下载失败")));
                        });
                        return;
                    }
                    if (++retry >= 30) { if (completion) completion(nil, ddTTVError(@"琅琅合成超时")); return; }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), poll);
                });
            };
            poll();
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
    if (cfg.boolForKey:kDDTTVEnable && wrap && msgWrapCls && [msgWrapCls isSenderFromMsgWrap:wrap]) {
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
                                         on:cfg.boolForKey:kDDTTVEnable]];
    [sec1 addCell:[cellCls normalCellForSel:@selector(setVoice:)
                                     target:self
                                      title:[NSString stringWithFormat:@"2. 设置音色(%@)", ddTTVCurrentVoiceName()]]];
    [sec1 addCell:[cellCls normalCellForSel:@selector(refreshVoices:)
                                     target:self
                                      title:@"3. 刷新音色列表"]];
    [sec1 setFooterTitle:@"聊天发送指令：/yy 文字 转语音并发送"];
    [self.tableViewMgr addSection:sec1];

    // 第2节：背景音
    WCTableViewSectionManager *sec2 = [secCls defaultSection];
    [sec2 addCell:[cellCls switchCellForSel:@selector(toggleBg:)
                                     target:self
                                      title:@"4. 启用背景音"
                                         on:cfg.boolForKey:kDDTTVBgEnable]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(importBg:)
                                     target:self
                                      title:@"5. 导入背景音"]];
    [sec2 addCell:[cellCls normalCellForSel:@selector(setBg:)
                                     target:self
                                      title:@"6. 设置背景音"]];
    [self.tableViewMgr addSection:sec2];

    // 第3节：缓存
    WCTableViewSectionManager *sec3 = [secCls defaultSection];
    [sec3 addCell:[cellCls normalCellForSel:@selector(cleanCache:)
                                     target:self
                                      title:@"7. 清理缓存(语音/试听/图标/聊天语音)"]];
    [self.tableViewMgr addSection:sec3];

    // 第4节：接口配置
    WCTableViewSectionManager *sec4 = [secCls defaultSection];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setLangToken:)
                                     target:self
                                      title:[NSString stringWithFormat:@"8. 琅琅 Token：%@",
                                             [self dd_masked:[cfg stringForKey:kDDTTVLangToken]]]]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setXFUid:)
                                     target:self
                                      title:[NSString stringWithFormat:@"9. 讯飞 UID：%@",
                                             [cfg stringForKey:kDDTTVXFUid] ?: @"未设置"]]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setYsAddr:)
                                     target:self
                                      title:@"10. 音色列表地址(ys.json)"]];
    [sec4 addCell:[cellCls normalCellForSel:@selector(setYsProxy:)
                                     target:self
                                      title:[NSString stringWithFormat:@"11. 列表代理：%@",
                                             [cfg stringForKey:kDDTTVYsProxy] ?: @"直连 GitHub"]]];
    [sec4 setFooterTitle:@"琅琅音色需填 Token；讯飞 UID 可留空"];
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

// 3. 刷新音色列表（联网拉取 ys.json）
- (void)refreshVoices:(id)sender {
    ddTTVToast(@"正在拉取音色列表…");
    ddTTVFetchVoiceList(^(BOOL ok, NSString *msg) {
        ddTTVToast(ok ? [NSString stringWithFormat:@"已更新：%@", msg]
                      : [NSString stringWithFormat:@"更新失败：%@", msg]);
        [self buildTable];
    });
}

// Token 脱敏显示
- (NSString *)dd_masked:(NSString *)text {
    if (!text.length) return @"未设置";
    if (text.length <= 8) return @"已设置";
    return [NSString stringWithFormat:@"%@***%@", [text substringToIndex:4], [text substringFromIndex:text.length - 4]];
}

// 8. 琅琅 Token
- (void)setLangToken:(id)sender {
    [self dd_editConfig:kDDTTVLangToken title:@"琅琅 Token" placeholder:@"在 lang123.top 个人中心获取" secure:YES];
}

// 9. 讯飞 UID
- (void)setXFUid:(id)sender {
    [self dd_editConfig:kDDTTVXFUid title:@"讯飞 UID" placeholder:@"可留空" secure:NO];
}

// 10. 音色列表地址（ys.json）
- (void)setYsAddr:(id)sender {
    [self dd_editConfig:kDDTTVYsURL title:@"音色列表地址" placeholder:@"留空用 PKC 默认地址" secure:NO];
}

// 11. GitHub 代理前缀
- (void)setYsProxy:(id)sender {
    [self dd_editConfig:kDDTTVYsProxy title:@"音色列表代理" placeholder:@"如 https://gh-proxy.com" secure:NO];
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

// 4. 启用背景音
- (void)toggleBg:(UISwitch *)sender {
    [DDTextToVoiceConfig.shared setValue:sender.isOn ? @(1) : nil forConfigKey:kDDTTVBgEnable];
    if (sender.isOn) ddTTVPlayBackgroundMusic(); else ddTTVStopBackgroundMusic();
    [self buildTable];
}

// 5. 导入背景音
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

// 6. 设置背景音
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

// 7. 清理缓存
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

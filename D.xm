//  DD广告拦截 —— 单文件越狱插件（Theos/Logos）
//
//  屏蔽微信广告，按场景分五个模块：
//    1. 朋友圈广告：拦广告数据的落地与拉取
//    2. 公众号广告：拦列表的原生数据层，文章页拦广告票据与广告请求
//    3. 视频号广告：拦视频流与评论区广告的数据、曝光与上报
//    4. 小程序启动广告：拦开屏广告（冷启动 / 热启动）
//    5. 激励广告：页面一出现即关闭，跳过倒计时
//
//  总开关关闭时全部放行；分项开关在总开关开启后才展开。
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

#pragma mark - 微信类前向声明

@interface WCTableViewManager : NSObject
- (UITableView *)getTableView;
- (void)clearAllSection;
- (void)addSection:(id)section;
- (void)reloadTableView;
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
@end

@interface WCTableViewSectionManager : NSObject
+ (instancetype)defaultSection;
- (void)addCell:(id)cell;
@property (nonatomic, copy) NSString *headerTitle;
@property (nonatomic, copy) NSString *footerTitle;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controllerName;
@end

#pragma mark - 配置：广告屏蔽开关（DDAdBlockConfig）

// 总开关 + 5 个分项，默认全关，持久化到 NSUserDefaults。

static NSString * const kMaster           = @"DDAdBlock_Master";
static NSString * const kMoments          = @"DDAdBlock_Moments";
static NSString * const kBrand            = @"DDAdBlock_Brand";
static NSString * const kFinder           = @"DDAdBlock_Finder";
static NSString * const kMiniProgram      = @"DDAdBlock_MiniProgram";
static NSString * const kRewardedFastPass = @"DDAdBlock_RewardedFastPass";

@interface DDAdBlockConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL master;
@property (assign, nonatomic) BOOL moments;
@property (assign, nonatomic) BOOL brand;
@property (assign, nonatomic) BOOL finder;
@property (assign, nonatomic) BOOL miniProgram;
@property (assign, nonatomic) BOOL rewardedFastPass;
@end

@implementation DDAdBlockConfig
+ (instancetype)sharedConfig {
    static DDAdBlockConfig *c = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [DDAdBlockConfig new]; });
    return c;
}
- (instancetype)init {
    if (self = [super init]) {
        _master           = [NSUserDefaults.standardUserDefaults boolForKey:kMaster];
        _moments          = [NSUserDefaults.standardUserDefaults boolForKey:kMoments];
        _brand            = [NSUserDefaults.standardUserDefaults boolForKey:kBrand];
        _finder           = [NSUserDefaults.standardUserDefaults boolForKey:kFinder];
        _miniProgram      = [NSUserDefaults.standardUserDefaults boolForKey:kMiniProgram];
        _rewardedFastPass = [NSUserDefaults.standardUserDefaults boolForKey:kRewardedFastPass];
    }
    return self;
}
- (void)setMaster:(BOOL)v           { _master = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMaster]; }
- (void)setMoments:(BOOL)v          { _moments = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMoments]; }
- (void)setBrand:(BOOL)v            { _brand = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kBrand]; }
- (void)setFinder:(BOOL)v           { _finder = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kFinder]; }
- (void)setMiniProgram:(BOOL)v      { _miniProgram = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMiniProgram]; }
- (void)setRewardedFastPass:(BOOL)v { _rewardedFastPass = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kRewardedFastPass]; }
@end

#pragma mark - Hook：朋友圈广告

static inline BOOL momentsEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].moments;
}

// 广告数据管不起来，后面的取数、落盘、展示整条链路都不存在。
%hook WCAdvertiseDataHelper
- (id)init {
    if (momentsEnabled()) return nil;
    return %orig;
}
%end

// 广告数据不写进本地存储。
%hook WCAdvertiseStorage
- (void)setOAdvertiseData:(id)arg1 {
    if (momentsEnabled()) return;
    %orig;
}
%end

#pragma mark - Hook：公众号广告

static inline BOOL brandEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].brand;
}

// 文章内广告位的容器：底部 / 顶部 / 文中 CPC / 评论区广告、iframe 广告。
static NSString *DDAdBlockAdSelector(void) {
    return @"#js_bottom_ad_area,#js_top_ad_area,#js_tail_video_ad_area,"
           @"#js_ad_area,#js_cpc_area,#js_cpc_container,#js_ad_container,"
           @"#cidad_comment_constant_key,.comment-ad-container,"
           @".recommend_friend_content_wrap,.ad_control-tips,"
           @".js_bottom_ad_area,.js_ad_area,.js_ad_link,.js_cpc_area,"
           @"[id^=\"js_ad_\"],[class*=\"js_ad_\"],"
           @"iframe.iframe_ad_container,iframe.iframe_adv_ad_container,"
           @"iframe[src*=\"/mp/advertisement\"],iframe[src*=\"/mp/ad_\"]";
}

// 只对公众号文章页生效；写入隐藏样式，再扫两遍兜住异步插入的广告。
// 不挂常驻监听，避免长文章里的性能开销。
static NSString *DDAdBlockInjectJS(void) {
    return [NSString stringWithFormat:
        @"(function(){"
        @"var host=(window.location&&window.location.hostname||'').toLowerCase();"
        @"if(host!=='mp.weixin.qq.com'&&!host.endsWith('.mp.weixin.qq.com'))return 0;"
        @"if(window.__ddAdBlocked){"
        @"if(typeof window.__ddHideAds==='function')return window.__ddHideAds();return 0;}"
        @"window.__ddAdBlocked=1;"
        @"var sel='%@';"
        @"try{var s=document.createElement('style');s.id='__dd_adblock';"
        @"s.textContent=sel+'{display:none!important;height:0!important;min-height:0!important;"
        @"margin:0!important;padding:0!important;overflow:hidden!important;}';"
        @"(document.head||document.documentElement).appendChild(s);}catch(e){}"
        @"function hideNode(n){"
        @"if(!n||n.nodeType!==1)return 0;"
        @"var c=0;"
        @"try{"
        @"if(n.matches&&n.matches(sel)&&n.getAttribute('data-dd-ad-hidden')!=='1'){"
        @"n.setAttribute('data-dd-ad-hidden','1');"
        @"n.style.setProperty('display','none','important');"
        @"n.style.setProperty('height','0','important');"
        @"n.style.setProperty('min-height','0','important');"
        @"n.style.setProperty('margin','0','important');"
        @"n.style.setProperty('padding','0','important');"
        @"n.style.setProperty('overflow','hidden','important');"
        @"c++;}"
        @"var sub=n.querySelectorAll(sel);"
        @"for(var i=0;i<sub.length;i++)c+=hideNode(sub[i]);"
        @"}catch(e){}"
        @"return c;}"
        @"window.__ddHideAds=function(){try{return hideNode(document.documentElement);}catch(e){return 0;}};"
        @"window.__ddHideAds();"
        @"setTimeout(window.__ddHideAds,0);"
        @"setTimeout(window.__ddHideAds,1000);"
        @"document.addEventListener('DOMContentLoaded',window.__ddHideAds,{once:true});"
        @"return 0;})();",
        DDAdBlockAdSelector()];
}

// 列表：原生数据层拦截
%hook BrandTLExptConfig
- (BOOL)isExptNotShowAd {
    if (brandEnabled()) return YES;
    return %orig;
}
%end

%hook BrandTLCanvasCardMgr
+ (BOOL)isAdCardOpen {
    if (brandEnabled()) return NO;
    return %orig;
}
+ (BOOL)isAdRequestOpen {
    if (brandEnabled()) return NO;
    return %orig;
}
- (void)handleBizAdNotifyNewXml:(id)arg1 {
    if (brandEnabled()) return;
    %orig;
}
%end

// 订阅号消息流里的广告卡片：数据段建不起来，卡片就不会出现。
%hook BTCanvasMsgSectionData
- (id)initWithMsgWrap:(id)arg1 sectionWidth:(double)arg2 displayMode:(unsigned int)arg3 delegate:(id)arg4 {
    if (brandEnabled()) return nil;
    return %orig;
}
%end

// 订阅号消息流里的推荐卡片：推荐关注 / 推荐视频号，数据建不出来就不展示。
// 这两个类头文件里没声明 init，走的是 NSObject 的实现，hook 继承方法同样生效。
%hook BTRecommendMsgData
- (id)init {
    if (brandEnabled()) return nil;
    return %orig;
}
%end

%hook BTRecommendFinderData
- (id)init {
    if (brandEnabled()) return nil;
    return %orig;
}
%end

%hook BrandAdDataParser
+ (id)adDataItemForContent:(id)arg1 {
    if (brandEnabled()) return nil;
    return %orig;
}
+ (id)adDataItemForMsgWrap:(id)arg1 {
    if (brandEnabled()) return nil;
    return %orig;
}
+ (id)adInfoDicForContent:(id)arg1 {
    if (brandEnabled()) return nil;
    return %orig;
}
+ (id)adInfoDicForMsgWrap:(id)arg1 {
    if (brandEnabled()) return nil;
    return %orig;
}
%end

// 注入点选在系统类的初始化方法：任何 WKWebView 创建都必然经过，
// 不依赖微信自己是否调用 webViewUserScriptsForConfiguration。
// 脚本内部限定 mp.weixin.qq.com，不会波及其它页面。
%hook WKWebView
- (id)initWithFrame:(CGRect)arg1 configuration:(id)arg2 {
    id webView = %orig;
    if (!brandEnabled()) return webView;

    WKWebViewConfiguration *cfg = (WKWebViewConfiguration *)arg2;
    if (!cfg) cfg = [(WKWebView *)webView configuration];
    WKUserContentController *ucc = [cfg userContentController];
    if (!ucc) {
        ucc = [WKUserContentController new];
        [cfg setUserContentController:ucc];
    }
    WKUserScript *script = [[WKUserScript alloc] initWithSource:DDAdBlockInjectJS()
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
    [ucc addUserScript:script];
    return webView;
}
%end

// 文章页：拦广告票据，页面拿不到票据就不渲染广告
%hook MMWebViewController
// completion 按最少参数声明：多出来的参数由调用方写寄存器，block 不用就不读，避免读到脏值。
- (void)getTokenWithAdUrl:(id)arg1 posId:(id)arg2 completion:(id)arg3 {
    if (brandEnabled()) {
        void (^completion)(id) = arg3;
        if (completion) completion(nil);
        return;
    }
    %orig;
}
%end

#pragma mark - Hook：视频号广告

static inline BOOL finderEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].finder;
}

// 评论区广告
%hook WCFinderComment
- (id)advertisementInfo {
    if (finderEnabled()) return nil;
    return %orig;
}
- (id)commentAdImageUrl {
    if (finderEnabled()) return nil;
    return %orig;
}
- (id)promotionInfo {
    if (finderEnabled()) return nil;
    return %orig;
}
%end

%hook WCFinderDataItem
- (unsigned long long)adFlag {
    if (finderEnabled()) return 0;
    return %orig;
}
%end

%hook WCAdFinderInfo
- (BOOL)isValid {
    if (finderEnabled()) return NO;
    return %orig;
}
%end

%hook WCFinderCommentAdTableViewCell
// 行高置 0：广告被拦掉后，评论区不会再空出一块留白。
+ (double)sectionHeightWith:(id)arg1 width:(double)arg2 halfScreenHeight:(double)arg3 {
    if (finderEnabled()) return 0.0;
    return %orig;
}
// 媒体区高度置 0，卡片不占位。
- (double)heightForMediaWithRatio:(double)arg1 maxHeightPercentage:(long long)arg2 minArea:(unsigned long long)arg3 {
    if (finderEnabled()) return 0.0;
    return %orig;
}
- (void)updateWithModel:(id)arg1 width:(double)arg2 {
    %orig;
    if (finderEnabled()) [(UIView *)self setHidden:YES];
}
%end

// 视频流广告
%hook WCFinderDataItem
- (BOOL)isHardAdFeed {
    if (finderEnabled()) return NO;
    return %orig;
}
- (BOOL)isHardAdLiveFeed {
    if (finderEnabled()) return NO;
    return %orig;
}
- (BOOL)isFromAdsStream {
    if (finderEnabled()) return NO;
    return %orig;
}
- (void)setIsFromAdsStream:(BOOL)arg1 {
    if (finderEnabled()) {
        %orig(NO);
        return;
    }
    %orig;
}
- (id)jumpInfoContainer {
    if (finderEnabled()) return nil;
    return %orig;
}
- (id)postJumpInfoContainer {
    if (finderEnabled()) return nil;
    return %orig;
}
- (id)adLiveCoverUrl {
    if (finderEnabled()) return nil;
    return %orig;
}
- (id)adsParams {
    if (finderEnabled()) return nil;
    return %orig;
}
%end

#pragma mark - Hook：小程序启动广告

static inline BOOL miniProgramEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].miniProgram;
}

// 开屏广告：三处原生开关都判否，微信自己就不走展示流程。
%hook WAAppTaskSplashADConfig
- (BOOL)canShowSplashADWindow {
    if (miniProgramEnabled()) return NO;
    return %orig;
}
- (BOOL)canHotStartShowSplashAD {
    if (miniProgramEnabled()) return NO;
    return %orig;
}
- (BOOL)splashADHasContent {
    if (miniProgramEnabled()) return NO;
    return %orig;
}
- (void)handleShowSplashAdCalled:(BOOL)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

// JS 侧触发开屏的入口，一并挡掉。
%hook WAJSEventHandler_showSplashAd
- (void)handleJSEvent:(id)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

%hook WAJSEventHandler_showSplashAdMenu
- (void)handleJSEvent:(id)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

#pragma mark - Hook：激励广告快速跳过

static inline BOOL rewardedEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].rewardedFastPass;
}

%hook WCFinderRewardAdViewController
// 页面一出现即关闭，跳过倒计时等待。
- (void)viewDidAppear:(BOOL)arg1 {
    if (rewardedEnabled()) {
        [(id)self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    %orig;
}
%end

#pragma mark - 设置界面（唯一入口：DDAdBlockSettingsViewController）

@interface DDAdBlockSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDAdBlockSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD广告拦截";
    // 导航栏外观交给微信原生渲染；视图整屏延伸，由 viewDidLayoutSubviews 把表格推到导航栏底边。
    Class mgrCls = objc_getClass("WCTableViewManager");
    _tableViewManager = [[mgrCls alloc] initWithFrame:self.view.bounds
                                                style:UITableViewStyleInsetGrouped];
    UITableView *tableView = [_tableViewManager getTableView];
    self.view.backgroundColor = tableView.backgroundColor;
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:tableView];

    [self buildSections];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat top = self.view.safeAreaInsets.top;
    UITableView *tableView = [_tableViewManager getTableView];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    tableView.frame = CGRectMake(0, top, w, h - top);
}

- (void)buildSections {
    Class sectionCls = objc_getClass("WCTableViewSectionManager");
    DDAdBlockConfig *cfg = [DDAdBlockConfig sharedConfig];

    [_tableViewManager clearAllSection];

    WCTableViewSectionManager *secMain = [sectionCls defaultSection];
    secMain.headerTitle = @"广告屏蔽开关";
    [secMain addCell:[self switchCellWithTitle:@"启用广告拦截" on:cfg.master action:@selector(onMasterSwitch:)]];
    // 总开关关闭时折叠分项，开启才展开。
    if (cfg.master) {
        [secMain addCell:[self switchCellWithTitle:@"屏蔽朋友圈广告" on:cfg.moments action:@selector(onMomentsSwitch:)]];
        [secMain addCell:[self switchCellWithTitle:@"屏蔽公众号广告" on:cfg.brand action:@selector(onBrandSwitch:)]];
        [secMain addCell:[self switchCellWithTitle:@"屏蔽视频号广告" on:cfg.finder action:@selector(onFinderSwitch:)]];
        [secMain addCell:[self switchCellWithTitle:@"屏蔽小程序启动广告" on:cfg.miniProgram action:@selector(onMiniProgramSwitch:)]];
    }
    [_tableViewManager addSection:secMain];

    if (cfg.master) {
        WCTableViewSectionManager *secAdv = [sectionCls defaultSection];
        secAdv.headerTitle = @"进阶拦截";
        secAdv.footerTitle = @"开启后，激励广告将自动快速跳过（无需等待）";
        [secAdv addCell:[self switchCellWithTitle:@"激励广告快速跳过" on:cfg.rewardedFastPass action:@selector(onRewardedSwitch:)]];
        [_tableViewManager addSection:secAdv];
    }

    [_tableViewManager reloadTableView];
}

- (id)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action {
    Class cellCls = objc_getClass("WCTableViewCellManager");
    return [cellCls switchCellForSel:action target:self title:title on:on];
}

// 开关切换即重建表格（总开关开启则展开分项）
- (void)onMasterSwitch:(UISwitch *)s       { [DDAdBlockConfig sharedConfig].master = s.isOn; [self buildSections]; }
- (void)onMomentsSwitch:(UISwitch *)s      { [DDAdBlockConfig sharedConfig].moments = s.isOn; }
- (void)onBrandSwitch:(UISwitch *)s        { [DDAdBlockConfig sharedConfig].brand = s.isOn; }
- (void)onFinderSwitch:(UISwitch *)s       { [DDAdBlockConfig sharedConfig].finder = s.isOn; }
- (void)onMiniProgramSwitch:(UISwitch *)s  { [DDAdBlockConfig sharedConfig].miniProgram = s.isOn; }
- (void)onRewardedSwitch:(UISwitch *)s     { [DDAdBlockConfig sharedConfig].rewardedFastPass = s.isOn; }

@end

#pragma mark - 注册入口

%ctor {
    @autoreleasepool {
        Class mgrCls = objc_getClass("WCPluginsMgr");
        if (mgrCls) {
            [[mgrCls sharedInstance] registerControllerWithTitle:@"DD广告拦截"
                                                         version:@"1.0.0"
                                                      controller:@"DDAdBlockSettingsViewController"];
        }
    }
}
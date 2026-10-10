//  DD广告拦截 —— 单文件越狱插件（Theos/Logos）
//
//  屏蔽微信广告，按场景分五个模块：
//    1. 朋友圈广告：拦广告数据的落地与拉取
//    2. 公众号广告：拦原生数据层，并在文章页注入 CSS / JS 隐藏广告位
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

%hook WCAdvertiseDataHelper
// 兜住本地残留：插件安装前 / 开关关闭期间已落盘的广告，不再加载。
- (void)tryLoadAdvertiseData {
    if (momentsEnabled()) return;
    %orig;
}
- (BOOL)isAdPreviewExpired:(id)arg1 {
    if (momentsEnabled()) return YES;
    return %orig;
}
// 取广告数据：一律返回空，朋友圈就凑不出广告条目。
- (id)getAdvertiseDataByCurMinTime:(unsigned int)arg1 MaxTime:(unsigned int)arg2 checkDataValid:(BOOL)arg3 {
    if (momentsEnabled()) return [NSMutableArray array];
    return %orig;
}
- (id)getTopAdvertiseDataByTopNumber:(unsigned int)arg1 {
    if (momentsEnabled()) return [NSMutableArray array];
    return %orig;
}
%end

%hook WCTimelineMgr
- (id)getAdvertiseDataByCurMinTime:(unsigned int)arg1 MaxTime:(unsigned int)arg2 {
    if (momentsEnabled()) return [NSMutableArray array];
    return %orig;
}
- (void)onAdPullWithAdDatas:(id)arg1 {
    if (momentsEnabled()) return;
    %orig;
}
- (void)tryToProcessWithNewAdList:(id)arg1 {
    if (momentsEnabled()) return;
    %orig;
}
%end

#pragma mark - Hook：公众号广告

static inline BOOL brandEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].brand;
}

// 隐藏广告容器及其父节点：容器常嵌在 li / div 内，只藏自身会留下空白。
static NSString *DDAdBlockMPHideCSS(void) {
    return @".iframe_ad_container,.iframe_adv_ad_container,.comment-ad-container,"
           @"li.cidad_comment_constant_key,#cidad_comment_constant_key,"
           @".adv_keyword_search,.ad_control-tips"
           @"{display:none!important;height:0!important;min-height:0!important;"
           @"margin:0!important;padding:0!important;overflow:hidden!important;}";
}

static NSString *DDAdBlockMPHideParentCSS(void) {
    return @"div:has(> .iframe_ad_container),li:has(> .comment-ad-container)"
           @"{display:none!important;height:0!important;}";
}

// 注入 JS：写入隐藏样式，并用 MutationObserver 兜住之后异步插入的广告节点。
static NSString *DDAdBlockInjectJS(void) {
    return [NSString stringWithFormat:
        @"(function(){"
        @"if(window.__dd_injected)return;"
        @"window.__dd_injected=true;"
        @"if(window.__dd_ob){window.__dd_ob.disconnect();delete window.__dd_ob;}"
        @"if(window.__dd_timer){clearTimeout(window.__dd_timer);delete window.__dd_timer;}"
        @"try{"
        @"var s=document.createElement('style');s.id='__dd_adblock';"
        @"s.textContent='%@'+'%@';"
        @"(document.head||document.documentElement).appendChild(s);"
        @"var sweep=function(){try{Array.prototype.forEach.call("
        @"document.querySelectorAll('.iframe_ad_container,.comment-ad-container'),"
        @"function(e){var p=e.parentElement,n=0;"
        @"while(p&&n<3){if(p.tagName==='LI'||(p.className&&/comment-ad|discuss_media/.test(p.className))){"
        @"p.style.setProperty('display','none','important');break;}p=p.parentElement;n++;}});}catch(e){}};"
        @"sweep();"
        @"if(window.MutationObserver){"
        @"var timer=null;"
        @"window.__dd_ob=new MutationObserver(function(){"
        @"if(timer)return;timer=setTimeout(function(){timer=null;sweep();},300);});"
        @"window.__dd_ob.observe(document.documentElement,{childList:true,subtree:true});"
        @"window.__dd_timer=timer;"
        @"}"
        @"}catch(e){}})();",
        DDAdBlockMPHideCSS(), DDAdBlockMPHideParentCSS()];
}

// 广告 URL 特征串，命中即拦。用于公众号文章页的子帧请求。
static NSArray<NSString *> *DDAdBlockURLBlocklist(void) {
    static NSArray *list;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        list = @[
            @"support.weixin.qq.com/cgi-bin/mmsupport-bin/",
            @"cpro.baidu.com",
            @"pos.baidu.com",
            @"go.mobile.qq.com/ad",
            @"/cgi-bin/mmbiz-bin/ad",
            @"ad.weixin.qq.com",
            @"wxad",
            @"adunit-",
            @"_ad_",
            @"&adpos=",
        ];
    });
    return list;
}

static BOOL ddURLIsAd(NSString *url) {
    if (url.length == 0) return NO;
    for (NSString *sub in DDAdBlockURLBlocklist()) {
        if ([url containsString:sub]) return YES;
    }
    return NO;
}

// 原生数据层拦截
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

// WebView：注入脚本 + 拦截广告 URL
%hook MMWebViewController
- (id)webViewUserScriptsForConfiguration {
    id scripts = %orig;
    if (!brandEnabled()) return scripts;
    NSMutableArray *arr = [scripts isKindOfClass:[NSArray class]]
        ? [(NSArray *)scripts mutableCopy]
        : [NSMutableArray array];
    WKUserScript *us = [[WKUserScript alloc] initWithSource:DDAdBlockInjectJS()
                                              injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                           forMainFrameOnly:NO];
    [arr addObject:us];
    return arr;
}

- (BOOL)webView:(id)arg1 shouldStartLoadWithRequest:(id)arg2 navigationType:(long long)arg3 isMainFrame:(BOOL)arg4 navigationAction:(id)arg5 {
    if (brandEnabled() && !arg4) {
        NSString *u = [[(NSURLRequest *)arg2 URL] absoluteString];
        if (ddURLIsAd(u)) return NO;
    }
    return %orig;
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
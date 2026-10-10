//
//  DDAdBlock.xm
//  DD广告拦截
//  版本: 1.0.0
//  功能: 屏蔽微信广告（朋友圈、公众号、视频号、直播、搜索、小程序）
//        激励广告快速跳过
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

// ============================================================================
//  私有类声明（供设置界面及插件注册使用）
// ============================================================================

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

// ============================================================================
//  配置类（8 个开关，默认全关，持久化到 NSUserDefaults）
// ============================================================================

static NSString * const kMaster           = @"DDAdBlock_Master";
static NSString * const kMoments          = @"DDAdBlock_Moments";
static NSString * const kBrand            = @"DDAdBlock_Brand";
static NSString * const kFinder           = @"DDAdBlock_Finder";
static NSString * const kLive             = @"DDAdBlock_Live";
static NSString * const kMiniProgram      = @"DDAdBlock_MiniProgram";
static NSString * const kSearch           = @"DDAdBlock_Search";
static NSString * const kRewardedFastPass = @"DDAdBlock_RewardedFastPass";

@interface DDAdBlockConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL master;
@property (assign, nonatomic) BOOL moments;
@property (assign, nonatomic) BOOL brand;
@property (assign, nonatomic) BOOL finder;
@property (assign, nonatomic) BOOL live;
@property (assign, nonatomic) BOOL miniProgram;
@property (assign, nonatomic) BOOL search;
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
        _live             = [NSUserDefaults.standardUserDefaults boolForKey:kLive];
        _miniProgram      = [NSUserDefaults.standardUserDefaults boolForKey:kMiniProgram];
        _search           = [NSUserDefaults.standardUserDefaults boolForKey:kSearch];
        _rewardedFastPass = [NSUserDefaults.standardUserDefaults boolForKey:kRewardedFastPass];
    }
    return self;
}
- (void)setMaster:(BOOL)v           { _master = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMaster]; }
- (void)setMoments:(BOOL)v          { _moments = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMoments]; }
- (void)setBrand:(BOOL)v            { _brand = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kBrand]; }
- (void)setFinder:(BOOL)v           { _finder = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kFinder]; }
- (void)setLive:(BOOL)v             { _live = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kLive]; }
- (void)setMiniProgram:(BOOL)v      { _miniProgram = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kMiniProgram]; }
- (void)setSearch:(BOOL)v           { _search = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kSearch]; }
- (void)setRewardedFastPass:(BOOL)v { _rewardedFastPass = v; [NSUserDefaults.standardUserDefaults setBool:v forKey:kRewardedFastPass]; }
@end

// ============================================================================
//  模块 1：朋友圈广告
// ============================================================================

static inline BOOL momentsEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].moments;
}

%hook WCAdvertiseDataHelper
- (void)saveAdPullCompareInfo:(id)arg1 {
    if (momentsEnabled()) return;
    %orig;
}
- (void)saveAdvertiseMsgXmlDatas {
    if (momentsEnabled()) return;
    %orig;
}
- (void)addAdvertiseDataList:(id)arg1 {
    if (momentsEnabled()) return;
    %orig;
}
- (void)saveAdvertiseDatas {
    if (momentsEnabled()) return;
    %orig;
}
- (void)tryLoadAdvertiseData {
    if (momentsEnabled()) return;
    %orig;
}
- (BOOL)isAdPreviewExpired:(id)arg1 {
    if (momentsEnabled()) return YES;
    return %orig;
}
%end

%hook WCTimelineMgr
- (id)getAdvertiseDataByCurMinTime:(unsigned int)arg1 MaxTime:(unsigned int)arg2 checkDataValid:(BOOL)arg3 {
    if (momentsEnabled()) return [NSMutableArray array];
    return %orig;
}
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

// ============================================================================
//  模块 2：公众号广告（WKUserScript 单次注入，无重复执行）
// ============================================================================

static inline BOOL brandEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].brand;
}

// CSS 隐藏规则
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

// 注入 JS（防重复注入 + Observer 防抖）
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

// URL 黑名单
static NSArray<NSString *> *DDAdBlockURLBlocklist(void) {
    static NSArray *list;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        list = @[
            @"wxa.wxs.qq.com/tmpl/px/",
            @"wxa.wxs.qq.com/tmpl/lite/",
            @"support.weixin.qq.com/cgi-bin/mmsupport-bin/",
            @"wxapp.tc.qq.com/ad/",
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
- (BOOL)isAdCardOpen {
    if (brandEnabled()) return NO;
    return %orig;
}
- (BOOL)isAdRequestOpen {
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

// WebView 拦截（仅 WKUserScript 注入，无 webViewDidFinishLoad 重复）
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
        if ([u containsString:@"wxa.wxs.qq.com"] && [u containsString:@"/tmpl/px/"]) {
            return NO;
        }
        if (ddURLIsAd(u)) {
            return NO;
        }
    }
    return %orig;
}
%end

// ============================================================================
//  模块 3：视频号广告
// ============================================================================

static inline BOOL finderEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].finder;
}

static void ddViewSetHidden(id view, BOOL hidden) {
    if (!view) return;
    SEL sel = @selector(setHidden:);
    if (class_respondsToSelector([(id)view class], sel)) {
        void (*imp)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[(id)view methodForSelector:sel];
        if (imp) imp((id)view, sel, hidden);
    }
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
- (void)updateWithModel:(id)arg1 width:(double)arg2 {
    if (finderEnabled()) {
        %orig;
        ddViewSetHidden((id)self, YES);
        return;
    }
    %orig;
}
- (double)heightForMediaWithRatio:(double)arg1 maxHeightPercentage:(long long)arg2 minArea:(unsigned long long)arg3 {
    if (finderEnabled()) return 0.0;
    return %orig;
}
- (void)updatePlayerViewWithCommentInfo:(id)arg1 videoInfo:(id)arg2 {
    if (finderEnabled()) return;
    %orig;
}
- (void)updateImageViewWithCommentImageInfo:(id)arg1 imgInfo:(id)arg2 {
    if (finderEnabled()) return;
    %orig;
}
- (void)clickADContentActionWithArea:(NSInteger)arg1 {
    if (finderEnabled()) return;
    %orig;
}
- (id)commentAdReportDictWithReportScene:(NSInteger)arg1 {
    if (finderEnabled()) return nil;
    return %orig;
}
- (BOOL)canReportWithReportScene:(NSInteger)arg1 {
    if (finderEnabled()) return NO;
    return %orig;
}
%end

%hook WCFinderCommentDetailViewController
- (void)checkCommentAdPlayerExposeStateIfNeeded {
    if (finderEnabled()) return;
    %orig;
}
- (void)reportCommentAd:(id)arg1 withReportScene:(NSInteger)arg2 {
    if (finderEnabled()) return;
    %orig;
}
- (void)reportCommentAdIfNeededWithReportScene:(NSInteger)arg2 {
    if (finderEnabled()) return;
    %orig;
}
- (void)_configADCellReportBehavior:(id)arg1 comment:(id)arg2 {
    if (finderEnabled()) return;
    %orig;
}
- (void)commentAdCell:(id)arg1 clickFeedbackButton:(id)arg2 atSection:(NSInteger)arg3 {
    if (finderEnabled()) return;
    %orig;
}
- (void)commentAdCell:(id)arg1 longPressAtSection:(NSInteger)arg3 {
    if (finderEnabled()) return;
    %orig;
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

// ============================================================================
//  模块 4：直播广告
// ============================================================================

static inline BOOL liveEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].live;
}

%hook WCFinderAdCountdownBannerView
- (void)setupSubviews {
    if (liveEnabled()) return;
    %orig;
}
- (void)startCountdown {
    if (liveEnabled()) return;
    %orig;
}
- (void)updateUIWithTime:(long long)arg1 {
    if (liveEnabled()) return;
    %orig;
}
- (BOOL)adHasPlayOver {
    if (liveEnabled()) return YES;
    return %orig;
}
%end

%hook WCFinderLiveHomePageViewController
- (void)onAdSectionView:(id)arg1 selectElementVM:(id)arg2 {
    if (liveEnabled()) return;
    %orig;
}
%end

// ============================================================================
//  模块 5：搜索广告
// ============================================================================

static inline BOOL searchEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].search;
}

%hook WCAdSearchH5Info
- (BOOL)isValid {
    if (searchEnabled()) return NO;
    return %orig;
}
+ (id)fromXML:(struct XmlReaderNode_t *)arg1 {
    if (searchEnabled()) return nil;
    return %orig;
}
%end

// ============================================================================
//  模块 6：小程序广告（JS 防重复注入 + Observer 防抖 + URL 拦截）
// ============================================================================

static inline BOOL miniProgramEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].miniProgram;
}

static NSString *DDAdBlockMiniAppHideCSS(void) {
    return @"wx-ad,wx-ad-custom,ad,ad-custom,.wx-ad,.wx-ad-custom"
           @"{display:none!important;height:0!important;min-height:0!important;"
           @"max-height:0!important;margin:0!important;padding:0!important;"
           @"overflow:hidden!important;}";
}

static NSString *DDAdBlockMiniAppInjectJS(void) {
    return [NSString stringWithFormat:
        @"(function(){"
        @"if(window.__dd_injected_wa)return;"
        @"window.__dd_injected_wa=true;"
        @"if(window.__dd_ob_wa){window.__dd_ob_wa.disconnect();delete window.__dd_ob_wa;}"
        @"if(window.__dd_timer_wa){clearTimeout(window.__dd_timer_wa);delete window.__dd_timer_wa;}"
        @"try{"
        @"var s=document.createElement('style');s.id='__dd_adblock_wa';"
        @"s.textContent='%@';"
        @"(document.head||document.documentElement).appendChild(s);"
        @"var sweep=function(){try{Array.prototype.forEach.call("
        @"document.querySelectorAll('wx-ad,wx-ad-custom,.wx-ad,.wx-ad-custom'),"
        @"function(e){e.style.setProperty('display','none','important');"
        @"e.style.setProperty('height','0','important');"
        @"e.style.setProperty('max-height','0','important');});}catch(e){}};"
        @"sweep();"
        @"if(window.MutationObserver){"
        @"var timer=null;"
        @"window.__dd_ob_wa=new MutationObserver(function(){"
        @"if(timer)return;timer=setTimeout(function(){timer=null;sweep();},300);});"
        @"window.__dd_ob_wa.observe(document.documentElement,{childList:true,subtree:true});"
        @"window.__dd_timer_wa=timer;"
        @"}"
        @"}catch(e){}})();",
        DDAdBlockMiniAppHideCSS()];
}

// 原生层拦截
%hook WAAppTaskSplashADConfig
- (void)handleShowSplashAdCalled:(BOOL)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

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

%hook WAJSEventHandler_adOperateWXData
- (void)handleJSEvent:(id)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

%hook MagicAdCommonService
- (id)getAdInfoWithPosId:(id)arg1 {
    if (miniProgramEnabled()) return nil;
    return %orig;
}
- (id)getCachedAdInfoForPosId:(id)arg1 {
    if (miniProgramEnabled()) return nil;
    return %orig;
}
- (void)getAdInfoAsyncWithPosId:(id)arg1 completion:(id)arg2 {
    if (miniProgramEnabled()) return;
    %orig;
}
- (void)getAdInfoAsyncWithPosId:(id)arg1 timeoutMs:(long long)arg2 completion:(id)arg3 {
    if (miniProgramEnabled()) return;
    %orig;
}
- (void)triggerUpdateAdWithPosId:(id)arg1 pullType:(unsigned char)arg2 {
    if (miniProgramEnabled()) return;
    %orig;
}
- (void)updateAdInfoByCGIInstantlyWithPosId:(id)arg1 pullType:(unsigned char)arg2 isDelayPull:(BOOL)arg3 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

%hook MagicAdCGIMgr
+ (void)getAdsCGIWithPosIds:(id)arg1 successBlock:(id)arg2 failBlock:(id)arg3 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

%hook MagicAdPushMgrService
- (void)handleAdMsg:(id)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

%hook WCAdvertisePushService
- (void)handlePushMsg:(id)arg1 {
    if (miniProgramEnabled()) return;
    %orig;
}
%end

// WebView 拦截（仅在 webViewDidFinishLoad 注入一次，JS 内部防重复）
%hook WAWebViewController
- (void)webViewDidFinishLoad:(id)arg1 navigation:(id)arg2 {
    %orig;
    if (!miniProgramEnabled()) return;
    id wv = nil;
    @try {
        wv = [(id)self valueForKey:@"webView"];
    } @catch (__unused NSException *e) {}
    if (![wv respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) return;
    [wv evaluateJavaScript:DDAdBlockMiniAppInjectJS() completionHandler:nil];
}

- (BOOL)webView:(id)arg1 shouldStartLoadWithRequest:(id)arg2 navigationType:(long long)arg3 isMainFrame:(BOOL)arg4 navigationAction:(id)arg5 {
    if (miniProgramEnabled() && !arg4) {
        NSString *u = [[(NSURLRequest *)arg2 URL] absoluteString];
        if (ddURLIsAd(u)) {
            return NO;
        }
    }
    return %orig;
}
%end

// ============================================================================
//  模块 7：激励广告快速跳过
// ============================================================================

static inline BOOL rewardedEnabled(void) {
    return [DDAdBlockConfig sharedConfig].master && [DDAdBlockConfig sharedConfig].rewardedFastPass;
}

%hook WCFinderRewardAdViewController
- (void)viewDidAppear:(BOOL)arg1 {
    if (rewardedEnabled()) {
        [(id)self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    %orig;
}
%end

// ============================================================================
//  设置界面
// ============================================================================

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
    [secMain addCell:[self switchCellWithTitle:@"屏蔽朋友圈广告" on:cfg.moments action:@selector(onMomentsSwitch:)]];
    [secMain addCell:[self switchCellWithTitle:@"屏蔽公众号广告" on:cfg.brand action:@selector(onBrandSwitch:)]];
    [secMain addCell:[self switchCellWithTitle:@"屏蔽视频号广告" on:cfg.finder action:@selector(onFinderSwitch:)]];
    [secMain addCell:[self switchCellWithTitle:@"屏蔽直播广告" on:cfg.live action:@selector(onLiveSwitch:)]];
    [secMain addCell:[self switchCellWithTitle:@"屏蔽搜索广告" on:cfg.search action:@selector(onSearchSwitch:)]];
    [secMain addCell:[self switchCellWithTitle:@"屏蔽小程序广告" on:cfg.miniProgram action:@selector(onMiniProgramSwitch:)]];
    [_tableViewManager addSection:secMain];

    WCTableViewSectionManager *secAdv = [sectionCls defaultSection];
    secAdv.headerTitle = @"进阶拦截";
    secAdv.footerTitle = @"开启后，激励广告将自动快速跳过（无需等待）";
    [secAdv addCell:[self switchCellWithTitle:@"激励广告快速跳过" on:cfg.rewardedFastPass action:@selector(onRewardedSwitch:)]];
    [_tableViewManager addSection:secAdv];

    [_tableViewManager reloadTableView];
}

- (id)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action {
    Class cellCls = objc_getClass("WCTableViewCellManager");
    return [cellCls switchCellForSel:action target:self title:title on:on];
}

- (void)onMasterSwitch:(UISwitch *)s       { [DDAdBlockConfig sharedConfig].master = s.isOn; }
- (void)onMomentsSwitch:(UISwitch *)s      { [DDAdBlockConfig sharedConfig].moments = s.isOn; }
- (void)onBrandSwitch:(UISwitch *)s        { [DDAdBlockConfig sharedConfig].brand = s.isOn; }
- (void)onFinderSwitch:(UISwitch *)s       { [DDAdBlockConfig sharedConfig].finder = s.isOn; }
- (void)onLiveSwitch:(UISwitch *)s         { [DDAdBlockConfig sharedConfig].live = s.isOn; }
- (void)onSearchSwitch:(UISwitch *)s       { [DDAdBlockConfig sharedConfig].search = s.isOn; }
- (void)onMiniProgramSwitch:(UISwitch *)s  { [DDAdBlockConfig sharedConfig].miniProgram = s.isOn; }
- (void)onRewardedSwitch:(UISwitch *)s     { [DDAdBlockConfig sharedConfig].rewardedFastPass = s.isOn; }

@end

// ============================================================================
//  插件注册
// ============================================================================

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
// DDAdBlockTweak.xm
//
// WeChat 广告屏蔽插件（Logos / theos）
// ---------------------------------------------------------------------------
// 修复说明（基于 微信.zip 头文件 dump 逐条核对 + 对 WeChatAdBlocker.dylib
// 真实插件做反汇编，结论见各 hook 注释）：
//
//  WeChatAdBlocker 反汇编结论：
//    · 它是以 MSHookMessageEx（MobileSubstrate）直接写的方法级 hook 插件，
//      自带 ADTools / SWTools / WeChatAdBlockerSettingViewController 三个类；
//    · 它 hook 的 selector 覆盖（从 __objc_methname 提取）：
//        WCAdXmlParser:      SetAdvertiseInfo:ByAdInfo: / ByAdInfoXml: / SetAdvertiseXml:ByAdXml:
//        BrandTLExptConfig:  isExptNotShowAd
//        WCAdvertiseStorage: oAdvertiseData / nsAdvertiseID
//        WCAdDB:             addAdvertiseData:needUpdateCreateTime: / addAdvertiseDataList:
//                            saveAdvertiseDatas / saveAdvertiseMsgXmlDatas / tryLoadAdvertiseData
//        WCFinderDataItem:   adFlag / finderDataItemFromObject: / isAdsLive / isAd
//        WAAppTaskSplashADConfig: canShowSplashADWindow / canHotStartShowSplashAD / splashADHasContent
//        WAAppTask:          splashAD_createSplashADWindow / splashAD_handleShouldShowEvent
//        WCAdvertisePushService: handlePushMsg:
//        AdPushMsgDBMgr:     insertNewPushMsg:
//        MagicAdPushMgrService: handleAdMsg:
//        小程序 JS 桥:       handleJSEvent:HandlerFacade:ExtraData:
//        Canvas/品牌 Flutter 广告、MagicAd 服务等
//    · 视频号广告真实插件走【数据层】拦截（WCFinderDataItem.finderDataItemFromObject:），
//      不碰 WCFinderCommentAdTableViewCell。
//
//  【问题 1】公众号文章 & 留言中的广告隐藏无效
//    根因：原代码向 WKWebView 注入的 CSS 拼接成
//        "#js_ad_card,{display:none!important}"  ← 选择器与规则块之间多了逗号
//    这在 CSS 里是「选择器列表 + 空选择器」的非法写法，浏览器会丢弃整条规则，
//    于是 HTML 广告一个都没被隐藏。
//    修复：
//      (a) 修正 CSS，去掉逗号；并用 MutationObserver 持续清理动态插入的广告节点；
//      (b) 在 WKWebView 请求层拦截文章广告端点 /mp/getappmsgad、/ad.wx.com 等，
//          从源头阻止广告数据加载（真实 WeChatAdBlocker.dylib 也正是这么做的，
//          见二进制中字符串 "mp.weixin.qq.com/mp/getappmsgad"）。
//
//  【问题 2】视频号评论区广告屏蔽无效
//    根因（反汇编修正）：真实插件根本不把
//    WCFinderComment.advertisementInfo/promotionInfo 置 nil，也不靠 cell 高度——
//    而是用 +[WCFinderDataItem finderDataItemFromObject:]（微信/WCFinderDataItem.h:151）
//    在广告数据进入渲染模型前就丢弃。
//    修复：采用数据层拦截（真实插件做法）+ 保留专用 cell 高度归零作为双保险。
//
//  【问题 3】WCAdXmlParser 漏掉一条广告解析路径
//    原代码只 hook 了 SetAdvertiseInfo:ByAdInfo: 与 SetAdvertiseXml:ByAdXml:，
//    但头文件 WCAdXmlParser.h:40 还声明了
//        + (BOOL)SetAdvertiseInfo:(id)arg1 ByAdInfoXml:(struct XmlReaderNode_t *)arg2;
//    公众号广告可能走这条 XML 节点变体绕过拦截。已补上（真实插件同样覆盖了它）。
//
//  ============ 三大核心功能对应实现（v1.0.4） ============
//  功能1 · 朋友圈隐藏广告：
//      WCAdvertiseStorage（存储 setter 拦截）
//      + WCAdvertiseDataHelper（数据装载枢纽：addAdvertiseData: /
//        addAdvertiseDataList: / saveAdvertiseDatas / tryLoadAdvertiseData）
//      证据：微信/WCAdvertiseDataHelper.h:51/52/56/57
//  功能2 · 公众号文章 + 留言区隐藏广告：
//      · 请求层：MMWebViewController.webView:shouldStartLoadWithRequest:... 拦截
//        getappmsgad / ad.wx.com / ad.weixin.qq.com
//      · 渲染层：MMWebViewController.webViewDidFinishLoad:navigation: 注入 CSS +
//        MutationObserver（含文章正文 + 底部推荐 + 留言区广告选择器）
//      · 数据层：BrandTLExptConfig.isExptNotShowAd / WCAdXmlParser（含 ByAdInfoXml）/
//        WCAdDB / BizRecommendArticleResp（底部原生推广卡）
//      · 【关键修正】WXBaseWebViewController 无子类、为死代码；公众号文章页实际
//        承载于 MMWebViewController，故 CSS 注入此前从未生效，现已迁移。
//  功能3 · 视频号评论区隐藏广告：
//      · 数据层：+[WCFinderDataItem finderDataItemFromObject:] 按广告标识丢弃
//        （真实插件做法）
//      · 渲染层：WCFinderCommentAdTableViewCell（评论区专用广告 cell）
//        高度归零 + 内容清空，双保险。
//  功能4 · 小程序广告（splash 启动页 + 小程序【内】广告全屏蔽，v1.0.7）：
//      【启动页】屏蔽：
//      · 守卫类：WAAppTaskSplashADConfig.canShowSplashADWindow /
//        canHotStartShowSplashAD / splashADHasContent → NO
//      · 任务层：WAAppTask.splashAD_handleShouldShowEvent / splashAD_createSplashADWindow
//        / splashAD_setAllowHotStartSplashAD:interval:（禁热启动）/
//        splashAd_checkForceShowSplashAdWhenHotStart → NO /
//        splashAD_sendShouldShowIfAllowed → NO
//      · JS 桥：WAJSEventHandler_showSplashAd / _showSplashAdMenu /
//        _enableSplashAdHotStart 的 handleJSEvent: 直接 return
//      【小程序内广告】屏蔽（插屏/横幅/原生/激励视频/格子等，Magic Ad 服务）：
//      · _TtC6WeChat27MagicAdMiniProgramJsApiList.getAdMiniProgramJsApiList → []
//        （广告 JS API 不注册，最上游）
//      · MagicAdMiniProgramAppBrandJsApiList.getAdMiniProgramAppBrandJsApiList → []
//      · _TtC9WeAppCore25MagicAdMiniProgramService.prepareWithAppId: → return
//      · _TtC9WeAppCore25MagicAdMiniProgramService.handleJsEvent:extraInfo:callback:
//        → return（拦截所有广告 JS 事件）
//      证据：微信/_TtC6WeChat27MagicAdMiniProgramJsApiList.h:13、
//            MagicAdMiniProgramAppBrandJsApiList.h:13、
//            _TtC9WeAppCore25MagicAdMiniProgramService.h:28/34
//      · JS 桥：WAJSEventHandler_showSplashAd / _showSplashAdMenu /
//        _enableSplashAdHotStart 的 handleJSEvent: 直接 return
//      证据：微信/WAAppTask.h:1279/1296/1297/1302/1303、
//            WAAppTaskSplashADConfig.h:101/103/105、
//            WAJSEventHandler_enableSplashAdHotStart.h:11
// ---------------------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <WebKit/WebKit.h>

// ========== MMWebViewController 类别声明 ==========
// 【编译修复】Logos 的 %hook 块内不能声明 @property（会报 unexpected '@'），
// 故在此用具名类别声明 webView 属性，使 self.webView 可编译。
// 对应微信/MMWebViewController.h:478 的 webView 属性（运行时真实存在，仅编译期可见性）。
@interface MMWebViewController (DDAdBlockWebView)
@property(retain, nonatomic) WKWebView *webView;
@end

// ========== 插件管理入口 ==========
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// ========== 配置类（4个独立开关） ==========
static NSString * const kDDAdBlockTimelineKey = @"DDAdBlock_Timeline";
static NSString * const kDDAdBlockBrandKey    = @"DDAdBlock_Brand";
static NSString * const kDDAdBlockFinderKey   = @"DDAdBlock_Finder";
static NSString * const kDDAdBlockMiniAppKey  = @"DDAdBlock_MiniApp";

@interface DDAdBlockConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL blockTimeline;
@property (assign, nonatomic) BOOL blockBrand;
@property (assign, nonatomic) BOOL blockFinder;
@property (assign, nonatomic) BOOL blockMiniApp;
@end

@implementation DDAdBlockConfig

+ (instancetype)sharedConfig {
    static DDAdBlockConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ config = [DDAdBlockConfig new]; });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        if ([ud objectForKey:kDDAdBlockTimelineKey] == nil) [ud setBool:YES forKey:kDDAdBlockTimelineKey];
        if ([ud objectForKey:kDDAdBlockBrandKey] == nil)    [ud setBool:YES forKey:kDDAdBlockBrandKey];
        if ([ud objectForKey:kDDAdBlockFinderKey] == nil)   [ud setBool:YES forKey:kDDAdBlockFinderKey];
        if ([ud objectForKey:kDDAdBlockMiniAppKey] == nil)  [ud setBool:YES forKey:kDDAdBlockMiniAppKey];
        _blockTimeline = [ud boolForKey:kDDAdBlockTimelineKey];
        _blockBrand    = [ud boolForKey:kDDAdBlockBrandKey];
        _blockFinder   = [ud boolForKey:kDDAdBlockFinderKey];
        _blockMiniApp  = [ud boolForKey:kDDAdBlockMiniAppKey];
    }
    return self;
}

- (void)setBlockTimeline:(BOOL)value {
    _blockTimeline = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockTimelineKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockBrand:(BOOL)value {
    _blockBrand = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockBrandKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockFinder:(BOOL)value {
    _blockFinder = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockFinderKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)setBlockMiniApp:(BOOL)value {
    _blockMiniApp = value;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDAdBlockMiniAppKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// ========== 核心 Hook ==========

// 1. 朋友圈广告（阻止广告数据存储）
//    证据：微信/WCAdvertiseStorage.h:25/29 的 oAdvertiseData / nsAdvertiseID 属性
//    （setter 由 @property 自动合成，签名有效）
%hook WCAdvertiseStorage
- (void)setOAdvertiseData:(NSData *)oAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)setNsAdvertiseID:(NSString *)nsAdvertiseID {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
%end

// 1.2 【朋友圈广告 · 数据装载层拦截（真实 WeChatAdBlocker 覆盖的核心入口）】
//     WCAdvertiseDataHelper 是朋友圈广告数据装载/持久化的枢纽：
//       · addAdvertiseData:needUpdateCreateTime:  → 单条广告写入
//       · addAdvertiseDataList:                   → 广告列表批量写入
//       · saveAdvertiseDatas / tryLoadAdvertiseData → 落盘/回读
//     证据：微信/WCAdvertiseDataHelper.h:51/52/56/57
//     hook 后广告既不会被装载进内存，也不会被持久化（下拉刷新后不再出现）。
%hook WCAdvertiseDataHelper
- (void)addAdvertiseData:(id)arg1 needUpdateCreateTime:(BOOL)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)addAdvertiseDataList:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)saveAdvertiseDatas {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)tryLoadAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
%end

// 2. 公众号广告
// 2.1 实验开关强制返回"不显示广告"
//     证据：微信/BrandTLExptConfig.h:37 - (BOOL)isExptNotShowAd;
%hook BrandTLExptConfig
- (BOOL)isExptNotShowAd {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
%end

// 2.2 阻止广告XML解析
//     证据：微信/WCAdXmlParser.h
//       :37 + SetAdvertiseXml:ByAdXml:
//       :40 + SetAdvertiseInfo:ByAdInfoXml:   <-- 原代码漏掉的 XML 节点变体
//       :41 + SetAdvertiseInfo:ByAdInfo:
%hook WCAdXmlParser
+ (BOOL)SetAdvertiseInfo:(id)arg1 ByAdInfo:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (BOOL)SetAdvertiseInfo:(id)arg1 ByAdInfoXml:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (BOOL)SetAdvertiseXml:(id)arg1 ByAdXml:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
%end

// 2.3 阻止广告数据存储与读取
//     证据：微信/WCAdDB.h:27 fetchPullRecordList: / :29 savePullRecordInfo:sessionKey:isAsync:
%hook WCAdDB
- (id)fetchPullRecordList:(unsigned int)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return @[];
    return %orig;
}
- (void)savePullRecordInfo:(id)arg1 sessionKey:(id)arg2 isAsync:(BOOL)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// 2.4 公众号文章底部"相关阅读 / 推荐"原生推广卡
//     证据：微信/BizRecommendArticleResp.h:11（含 recCard / finderNativeCard）
%hook BizRecommendArticleResp
- (id)recCard {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)finderNativeCard {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

// 2.5 公众号文章内 & 留言区广告
//     【关键修正】经头文件核对：WXBaseWebViewController 没有任何子类，
//     公众号文章页实际承载在 MMWebViewController（微信/MMWebViewController.h，
//     webView 属性 :478，加载回调 webViewDidFinishLoad:navigation: :760，
//     请求决策 webView:shouldStartLoadWithRequest:... :771）。
//     原先 hook WXBaseWebViewController 是死代码（无子类触发），故公众号广告
//     CSS 注入从未执行。现已迁移到 MMWebViewController。
//     两层防护：
//       (A) 请求层拦截广告端点（getappmsgad / ad.wx.com / ad.weixin.qq.com）；
//       (B) 页面加载完成后注入 CSS + MutationObserver 隐藏/移除已存在的广告 DOM。
%hook MMWebViewController

// (A) 拦截广告请求：返回 NO 取消加载
//     证据：微信/MMWebViewController.h:771
//       - (BOOL)webView:(id)arg1 shouldStartLoadWithRequest:(id)arg2
//             navigationType:(long long)arg3 isMainFrame:(BOOL)arg4 navigationAction:(id)arg5;
- (BOOL)webView:(id)arg1 shouldStartLoadWithRequest:(id)arg2 navigationType:(long long)arg3 isMainFrame:(BOOL)arg4 navigationAction:(id)arg5 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) {
        NSURLRequest *req = arg2;
        NSURL *reqURL = req.URL;
        NSString *reqStr = reqURL.absoluteString ?: @"";
        // 文章内广告拉取端点 / 广告域名（仅拦截明确广告地址，避免误伤正常资源）
        if ([reqStr containsString:@"getappmsgad"] ||
            [reqStr containsString:@"ad.wx.com"] ||
            [reqStr containsString:@"ad.weixin.qq.com"]) {
            return NO;
        }
    }
    return %orig;
}

// (B) 加载完成后注入样式 + 持续清理
//     证据：微信/MMWebViewController.h:760 - (void)webViewDidFinishLoad:(id)arg1 navigation:(id)arg2;
- (void)webViewDidFinishLoad:(id)arg1 navigation:(id)arg2 {
    %orig;
    if (![DDAdBlockConfig sharedConfig].blockBrand) return;
    NSURL *url = self.webView.URL;
    NSString *urlStr = url.absoluteString ?: @"";
    if (![urlStr containsString:@"mp.weixin.qq.com"]) return;

    // ⚠️ 注意：以下 CSS 选择器已修正（原代码的 "selector,{...}" 逗号写法非法，
    // 导致整条规则被丢弃）。具体 class 名请用 Safari Web Inspector 连真机校准。
    // 选择器表与 JS 逻辑保持一致即可，去掉逗号、用 display:none!important 隐藏，
    // 再用 querySelectorAll + .remove() + MutationObserver 兜底动态插入的广告。
    NSString *js =
    @"(function(){"
    // 文章正文 + 底部推荐 + 留言区广告选择器
    //（留言区与正文同处 mp.weixin.qq.com 页面内嵌 HTML，见下 .comment_ad 相关项）
    @"var sels=['#js_ad_card','#js_bottom_ad_area','.ad_card','.weui-ad',"
    @"'.related-article','[data-ad]','.appmsg_ad_card',"
    @"'.mp_card_ad','.js_ad_card','.ad_card_container',"
    // —— 留言区广告 ——
    @"'.comment_ad','.comment_ad_area','.js_comment_ad','#js_comment_ad',"
    @"'.comment_ad_wrap','.ad_comment','.js_comment_area_ad',"
    @"'.comment_list_ad','.js_discuss_ad','.js_comment_list .ad'];"
    @"var css='';"
    @"for(var i=0;i<sels.length;i++){css+=sels[i]+'{display:none !important;}';}"
    @"var s=document.getElementById('dd_adblock_style');"
    @"if(!s){s=document.createElement('style');s.id='dd_adblock_style';"
    @"(document.head||document.documentElement).appendChild(s);}"
    @"s.textContent=css;"
    @"var hide=function(){"
    @"for(var i=0;i<sels.length;i++){"
    @"var ns=document.querySelectorAll(sels[i]);"
    @"for(var j=0;j<ns.length;j++){ns[j].remove();}"
    @"}};"
    @"hide();"
    @"if(!window.__dd_adblock_mo){"
    @"window.__dd_adblock_mo=new MutationObserver(hide);"
    @"window.__dd_adblock_mo.observe(document.documentElement,{childList:true,subtree:true});"
    @"}"
    @"})();";

    if ([self.webView respondsToSelector:@selector(evaluateJavaScript:completionHandler:)]) {
        [self.webView evaluateJavaScript:js completionHandler:nil];
    }
}
%end

// 3. 视频号去广告
// 3.1 【修复·视频号评论区广告 —— 采用数据层拦截（与真实 WeChatAdBlocker.dylib 一致）】
//     反汇编 WeChatAdBlocker.dylib 后确认：真实插件【根本不碰】
//     WCFinderCommentAdTableViewCell，而是用
//         WCFinderDataItem + finderDataItemFromObject:  ← 数据层工厂
//         WCAdFinderInfo / FinderObjectAdInfo
//     在广告数据进入渲染模型前就把它拦截掉。
//     之前的"评论区 cell 高度归零"只对"已把广告做成 cell"的路径有效，
//     当广告仍以普通 comment 渲染时会失效——数据层拦截才是根治。
//
//     证据（微信/WCFinderDataItem.h:151）：
//         + (id)finderDataItemFromObject:(id)arg1;
//     该工厂把"广告对象"转换成 WCFinderDataItem；返回 nil 即丢弃该广告。
%hook WCFinderDataItem
+ (id)finderDataItemFromObject:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockFinder && arg1 != nil) {
        // 仅当入参携带广告标识时才丢弃，避免误伤普通视频数据。
        // 用 objc_msgSend 调用，规避编译器对 id 类型未知 selector 的检查。
        //  - 响应 isAd 且判定为广告 → 丢弃
        //  - adFlag 非 0 → 丢弃（广告标识）
        //  - 携带 advertisementInfo → 丢弃
        if ([arg1 respondsToSelector:@selector(isAd)] &&
            ((BOOL (*)(id, SEL))objc_msgSend)(arg1, @selector(isAd))) return nil;
        if ([arg1 respondsToSelector:@selector(adFlag)] &&
            ((unsigned long long (*)(id, SEL))objc_msgSend)(arg1, @selector(adFlag)) != 0) return nil;
        if ([arg1 respondsToSelector:@selector(advertisementInfo)] &&
            ((id (*)(id, SEL))objc_msgSend)(arg1, @selector(advertisementInfo)) != nil) return nil;
    }
    return %orig;
}
%end

// 3.2 视频流广告标识（数据层兜底）
//     证据：微信/WCFinderDataItem.h:527 @property adFlag
%hook WCFinderDataItem
- (unsigned long long)adFlag {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0;
    return %orig;
}
%end

// 3.3 【保留·评论区专用广告 cell 兜底】
//     反汇编结论：真实插件不 hook 此 cell，但作为双保险，当个别广告绕过
//     数据层仍走到专用 cell 时，让高度归零 + 内容清空，确保不显示。
//     证据：微信/WCFinderCommentAdTableViewCell.h:12/44/46/96/111
%hook WCFinderCommentAdTableViewCell
+ (double)sectionHeightWith:(id)arg1 width:(double)arg2 halfScreenHeight:(double)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0.0;
    return %orig;
}
+ (double)heightForMediaWithRatio:(double)arg1 commentViewHeight:(double)arg2 maxHeightPercentage:(long long)arg3 width:(double)arg4 minArea:(unsigned long long)arg5 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0.0;
    return %orig;
}
- (double)heightForMediaWithRatio:(double)arg1 maxHeightPercentage:(long long)arg2 minArea:(unsigned long long)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0.0;
    return %orig;
}
- (void)updateWithModel:(id)arg1 width:(double)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
%end

// 4. 小程序【启动页】广告（启动页由本区块拦截；小程序内广告见 4.2.2 区块）
// 4.1 【修复·改用真实插件对应的守卫类 WAAppTaskSplashADConfig】
//     反汇编 WeChatAdBlocker.dylib 确认：真实插件 hook 的 splash 开关是
//     WAAppTaskSplashADConfig 的 canShowSplashADWindow / canHotStartShowSplashAD /
//     splashADHasContent 三个属性，而非 WAAppTask 的 splashAD_* 方法。
//     证据：微信/WAAppTaskSplashADConfig.h:101/103/105（均为 @property, BOOL）
%hook WAAppTaskSplashADConfig
- (BOOL)canShowSplashADWindow {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return NO;
    return %orig;
}
- (BOOL)canHotStartShowSplashAD {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return NO;
    return %orig;
}
- (BOOL)splashADHasContent {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return NO;
    return %orig;
}
%end

// 4.2 【保留·原有 WAAppTask 层双保险 + 补上游入口】
//     证据：微信/WAAppTask.h
//       :1296 splashAD_createSplashADWindow
//       :1297 splashAD_handleShouldShowEvent
//       :1279 splashAD_setAllowHotStartSplashAD:interval:  ← 允许热启动广告
//       :1302 splashAd_checkForceShowSplashAdWhenHotStart  ← 热启动强制显示
//       :1303 splashAD_sendShouldShowIfAllowed             ← "是否允许显示"判定
//     补这些上游入口，防止数据层守卫被绕过（尤其热启动强制广告路径）。
%hook WAAppTask
- (void)splashAD_handleShouldShowEvent {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
- (void)splashAD_createSplashADWindow {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
- (void)splashAD_setAllowHotStartSplashAD:(BOOL)arg1 interval:(unsigned long long)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
- (BOOL)splashAd_checkForceShowSplashAdWhenHotStart {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return NO;
    return %orig;
}
- (BOOL)splashAD_sendShouldShowIfAllowed {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return NO;
    return %orig;
}
%end

//    证据：微信/WAJSEventHandler_showSplashAd.h:11 - (void)handleJSEvent:
%hook WAJSEventHandler_showSplashAd
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook WAJSEventHandler_showSplashAdMenu
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

// 4.2.1 【新增·小程序 JS 主动开启热启动广告入口】
//     证据：微信/WAJSEventHandler_enableSplashAdHotStart.h:11 - (void)handleJSEvent:(id)arg1;
//     小程序 JS 调用"开启热启动广告"时拦截，阻止后续冷/热启动广告生效。
%hook WAJSEventHandler_enableSplashAdHotStart
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

// 4.2.2 【新增·小程序【内】广告屏蔽（v1.0.7，含激励视频，用户要求全屏蔽）】
//     小程序内广告（插屏/横幅/原生/激励视频/格子广告）由 Magic Ad 原生服务承载：
//       · 广告 JS API 列表注册源（返回空数组 → 广告 API 不注册，最上游）
//       · _TtC9WeAppCore25MagicAdMiniProgramService（小程序广告统一原生服务）
//     证据：
//       微信/_TtC6WeChat27MagicAdMiniProgramJsApiList.h:13 + getAdMiniProgramJsApiList
//       微信/MagicAdMiniProgramAppBrandJsApiList.h:13   + getAdMiniProgramAppBrandJsApiList
//       微信/_TtC9WeAppCore25MagicAdMiniProgramService.h:
//            :28 - (void)handleJsEvent:extraInfo:callback:
//            :34 - (void)prepareWithAppId:
%hook _TtC6WeChat27MagicAdMiniProgramJsApiList
+ (id)getAdMiniProgramJsApiList {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return @[];
    return %orig;
}
%end

%hook MagicAdMiniProgramAppBrandJsApiList
+ (id)getAdMiniProgramAppBrandJsApiList {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return @[];
    return %orig;
}
%end

%hook _TtC9WeAppCore25MagicAdMiniProgramService
- (void)prepareWithAppId:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
- (void)handleJsEvent:(id)arg1 extraInfo:(id)arg2 callback:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

// 4.3 【新增·推送广告拦截（反汇编真实插件揭示的覆盖面）】
//     微信"服务通知/公众号"推送广告数据入口，真实插件一并屏蔽。
//     证据：微信/WCAdvertisePushService.h:14 - (void)handlePushMsg:(id)arg1;
//           微信/AdPushMsgDBMgr.h:23        - (void)insertNewPushMsg:(id)arg1;
%hook WCAdvertisePushService
- (void)handlePushMsg:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

%hook AdPushMsgDBMgr
- (void)insertNewPushMsg:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// ========== 设置界面 ==========
//    证据：微信/WCTableViewManager.h / WCTableViewSectionManager.h / WCTableViewCellManager.h
@interface WCTableViewManager : NSObject
- (id)initWithFrame:(CGRect)frame style:(NSInteger)style;
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, weak) id delegate;
- (void)clearAllSection;
- (void)addSection:(id)arg1;
- (void)reloadTableView;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionWithHeader:(NSString *)header;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)switchCellForSel:(SEL)sel target:(id)target title:(id)title on:(BOOL)on;
@end

// 设置视图控制器
@interface DDAdBlockSettingsViewController : UIViewController
@property (nonatomic, strong) WCTableViewManager *tableViewManager;
@end

@implementation DDAdBlockSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD广告屏蔽设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    Class managerCls = %c(WCTableViewManager);
    _tableViewManager = [[managerCls alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    _tableViewManager.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableViewManager.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:_tableViewManager.tableView];

    [self buildTable];
}

- (void)buildTable {
    [_tableViewManager clearAllSection];

    Class sectionCls = %c(WCTableViewSectionManager);
    Class cellCls = %c(WCTableViewCellManager);

    WCTableViewSectionManager *section = [sectionCls sectionWithHeader:@""];
    DDAdBlockConfig *cfg = [DDAdBlockConfig sharedConfig];

    [section addCell:[cellCls switchCellForSel:@selector(onTimelineSwitch:) target:self title:@"屏蔽朋友圈广告" on:cfg.blockTimeline]];
    [section addCell:[cellCls switchCellForSel:@selector(onBrandSwitch:) target:self title:@"屏蔽公众号广告" on:cfg.blockBrand]];
    [section addCell:[cellCls switchCellForSel:@selector(onFinderSwitch:) target:self title:@"屏蔽视频号广告" on:cfg.blockFinder]];
    [section addCell:[cellCls switchCellForSel:@selector(onMiniAppSwitch:) target:self title:@"屏蔽小程序广告" on:cfg.blockMiniApp]];

    [_tableViewManager addSection:section];
    [_tableViewManager reloadTableView];
}

- (void)onTimelineSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockTimeline = sender.isOn;
}
- (void)onBrandSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockBrand = sender.isOn;
}
- (void)onFinderSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockFinder = sender.isOn;
}
- (void)onMiniAppSwitch:(UISwitch *)sender {
    [DDAdBlockConfig sharedConfig].blockMiniApp = sender.isOn;
}

@end

// ========== 插件注册 ==========
%ctor {
    @autoreleasepool {
        Class mgrClass = NSClassFromString(@"WCPluginsMgr");
        if (mgrClass) {
            id mgr = [mgrClass sharedInstance];
            if ([mgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
                [mgr registerControllerWithTitle:@"DD广告屏蔽"
                                         version:@"1.0.9"
                                      controller:@"DDAdBlockSettingsViewController"];
            }
        }
    }
}

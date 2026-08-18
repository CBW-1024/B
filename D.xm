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
//        【v1.4.0 修复】删除了原 CSS 注入 + MutationObserver：反汇编确认真实插件
//        不注入 CSS，且 querySelectorAll().remove() 会误删文章正文节点导致
//        "公众号文章打不开"，故改回与真实插件一致的请求拦截 + 数据层拦截。
//      · 数据层：BrandTLExptConfig（4 个 isExptNotShow* 开关）/ WCAdXmlParser
//        （含 ByAdInfoXml / Canvas 广告）/ WCAdDB / BrandAdDataParser /
//        BrandTLCanvasCardMgr / BizRecommendArticleResp（底部原生推广卡）
//      · 【关键修正】WXBaseWebViewController 无子类、为死代码；公众号文章页实际
//        承载于 MMWebViewController，故此前 CSS 注入从未生效，现已迁移。
//  功能3 · 视频号评论区隐藏广告：
//      · 数据层：+[WCFinderDataItem finderDataItemFromObject:] 按广告标识丢弃
//        （真实插件做法，仅 isAd / isAdsLive / adFlag 精确判断）
//        【v1.4.0 修复】删除了 WCFinderCommentAdTableViewCell 高度归零 hook：
//        反汇编确认真实插件完全不碰它，且该 hook 破坏视频 cell 渲染导致
//        "视频号播放不了视频"。
//  功能5 · 搜索页广告（v1.4.0，对齐真实插件 SearchNoAds）：
//      · WXSearchJSLogicImpl 推荐数据入口：handleJSApiFuncOfGetRcmdData: /
//        onSearchRecmdDataReturn: / onSearchRecmdDataSuccess: / handleRcmdDataOfGlobalTab:
//        屏蔽搜索结果页"为你推荐"广告流；正常搜索结果不受影响。
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
//
//  ============ CI 编译修复（v1.2.0） ============
//  连续三轮解决了 GitHub Actions 在 MMWebViewController 块上的编译错误：
//    1) property 'webView' cannot be found in forward class object —— 原因是
//       MMWebViewController 仅有 @class 前置声明，编译器不认识 webView 属性。
//    2) unexpected '@' in program —— Logos 的 %hook 块内不支持 @property 声明
//       （@property 只能出现在 @interface 里），故不能靠声明属性来救。
//    3) cannot find interface declaration for 'MMWebViewController' —— 想改用
//       @interface MMWebViewController (DDAdBlockWebView) 类别来声明属性，但普通
//       类别需要完整的类接口声明，而本文件只有 @class 前置声明，依然编译不过。
//  正确的做法（沿用用户上传的完整头文件信息）：在文件顶部显式补齐
//   @interface MMWebViewController : UIViewController 完整接口，声明真实存在的
//   webView 属性（微信/MMWebViewController.h:478，类型 WKWebView<YYWebViewInterface>，
//   编译期声明为 WKWebView* 以规避对自定义协议的依赖），于是 self.webView 点语法
//   恢复可用，无需 KVC 绕弯。已确认该接口仅此一处定义、CI 不预定义完整形式，
//   不会产生重复/不一致定义。
//  webView:shouldStartLoadWithRequest:... 用参数 arg2 取请求，无需属性。
//
//  ============ 对齐真实插件 WeChatAdBlocker.dylib（v1.3.0） ============
//  通过重新提取 dylib 的 __objc_methname / __objc_classname / __objc_selrefs，
//  重建真实插件的去广告覆盖面，并补齐本插件缺失的入口（此前"去广告不彻底"）：
//   · BrandTLExptConfig：原只 hook isExptNotShowAd，现补齐 isExptNotShowRecCard
//     （底部推荐卡片）/ isExptNotShowRecoFlow（推荐信息流）/ isExptNotShowFinderLiveBar
//     （视频号直播栏）三个开关 —— 这很可能是公众号"推荐流/卡片广告"没去掉的根因；
//   · WCAdvertiseDataHelper：补齐 saveAdvertiseMsgXmlDatas / saveAdPullCompareInfo:；
//   · WCAdXmlParser：补齐 ExtractRecommendAdInfo:ByAdMsgXml: 与 Canvas 广告
//     setAdCanvasPage:... / setAdCanvasInfo: / setSKAdItems: / setAdCanvasExtXml:；
//   · 新增 BrandAdDataParser（品牌广告数据解析 4 个工厂方法）；
//   · 新增 BrandTLCanvasCardMgr（isAdRequestOpen / isAdCardOpen / handleBizAdNotifyNewXml:）；
//   · 新增 WCAdvertiseStatMgr（getAdvertiseInfoForItem: 阻断广告统计上报链路）；
//   · 新增 MagicAdPushMgrService（handleAdMsg: MagicAd 推送统一入口）；
//   · WAAppTask：补齐 isSplashADFinished → YES（状态位层面跳过启动广告）；
//   · WCFinderDataItem：补齐 isAdsLive → NO。
//
//  ============ 全面对齐真实插件反汇编（v1.4.1） ============
//  对 WeChatAdBlocker.dylib 的 __init_offsets（4 个初始化函数）+ 193 处
//  MSHookMessageEx 调用点逐点还原（类名=__cstring，selector=__objc_selrefs 解 PAC，
//  替换 IMP=__text，old IMP=__bss），得到真实插件 hook 的 64 类 / 192 方法。
//  据此对去广告逻辑做以下对齐/补齐（反调试类 JailBreakHelper/CUtility/
//  TSEnvironment/ClientCheckMgr/NewMainFrameViewController 属插件自身反检测，
//  非去广告，不移植）：
//   · 搜索页：真实插件 hook 的是 WXSearchJSLogicImpl.functionCall:withParams:
//     withCallbackID:，用 5 关键词（log/adDataReport/getAdIdInfo/
//     reportSearchStatistics/reportSearchRealTimeStatistics）拦截广告上报/统计；
//     本插件新增该 hook，原有 Rcmd 钩子保留兜底。
//   · 视频号：真实插件只用 finderDataItemFromObject: + isAd 判断（dylib@0x6754）；
//     本插件以 isAd 为主判，保留 isAdsLive/adFlag 兜底，不误伤普通视频。
//   · 朋友圈：补齐 WCAdvertiseStorage 的 PBArrayAdd_* 编码层拦截；
//     WCAdvertiseDataHelper 补齐 IsAdvertiseDataValid:dataItem:/isAdPreviewExpired:。
//     （真实插件涉及的 m_advertiseList/m_bLoaded/getCachedBodyWrapList 在本微信版本
//     中非该类方法——前者是 ivar、后者在 WCAdvertiseStatMgr，已核对不移植以防误伤）
//   · 公众号统计：补齐 WCAdvertiseStatMgr 全部 log* 曝光上报拦截；
//     WCAdDB 补齐 createPullRecordTable/createTables/initDB；
//     BrandAdDataParser 补齐 bizTypeForAdInfoDic:/traceIdForAdInfoDic:。
//   · 推送广告：WCAdvertisePushService/MagicAdPushMgrService 补齐
//     OnGetNewXmlMsg:Type:MsgWrap:；AdPushMsgDBMgr 补齐 initDB。
//
//  ============ 完全对齐真实插件（v1.5.0） ============
//  对真实插件 193 处 MSHookMessageEx 逐点核对 + 与本微信版本头文件逐一比对后，
//  大幅补齐本版本【真实存在】的去广告 hook 目标（此前因"版本差异"判断过于保守，
//  漏掉了本版本确实存在的方法）：
//   · 视频号广告【数据模型层】：FinderObjectAdInfo（adDesc/adH5/adLeadLink/adMiniApp/
//     adItems）、ObjectAdItem、ObjectAdContentH5、WCAdFinderInfo.isValid、
//     WCFinderRouterHelper.pushFinderAdPageViewController...（广告页路由）
//     （WCFinderFeedContentVM 的 initWithDataItem:scene:dataScene:... 本版本无 dataScene
//     参数，确认为版本差异，不移植）
//   · 朋友圈存储补全：WCAdvertiseStorage 补 oAdvertiseData getter（返回 nil 丢弃广告
//     数据）/ initialize / init；WCAdvertiseDataHelper 补 init（getCachedBodyWrapList
//     /m_* 本版本为 ivar 非方法，不移植）
//   · 品牌广告数据模型：WCAdvertiseInfo（h5PageWrap/poiH5PageWrap/adType/adExpired/
//     previewExpiredTime/setItem:value:forDynamic:/dictionaryFromADDynamicInfo:）、
//     BrandAdDataItem（dicAdInfo/content）
//   · 公众号动态 Canvas 广告链路：WCCanvasDynamicDataLoader / WCAdDynamicCanvasServerData
//     / WCAdDynamicCanvasPageInfo / WCAdCanvasLoadParams / WCADPageWrap / WCADCanvasInfo
//     / WCADBodyWrap / WCAdSearchH5Info
//   · WebView 广告 JS 事件桥：WebviewJSEventHandler_adDataReport / getAdIdInfo、
//     WAJSEventHandler_adOperateWXData、MBEventHandler_getAdPushMsg / getOldAdInfo /
//     setAdRequestInfo / setFeedsAdRequestInfo / setAdCardRequestInfo、
//     WCAdFormWebViewJSLogic、LocalJSLogicBase.sendEvent:handler:result:
//   · 品牌广告 Flutter 卡片：BrandTLFlutterViewController（enableAd / 推荐流插入 /
//     点击上报）
//  【合理不移植项】
//   · 反调试类（JailBreakHelper/CUtility/TSEnvironment/ClientCheckMgr/NewMainFrameVC）：
//     插件自身反检测，非去广告
//   · JS 基础设施（JSEvent/JSFunctionDef/WAJSInvoker/WCJSInvoker/NSURL.URLWithString:）：
//     全局改动风险极高，非直接去广告
//   · Magic Ad 品牌 Swift 服务（_TtC6WeChat19MagicAdBrandService 等约 25 个方法）：
//     属"品牌广告服务"整体框架，hook 服务生命周期方法可能破坏品牌文章正常展示，
//     风险高；且用户核心诉求（朋友圈/公众号/视频号/搜索/小程序）均已覆盖
//   · LocalJSEventHandler_WebAPIBridge：WebAPI 桥，可能影响正常 H5 功能
// ---------------------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <WebKit/WebKit.h>

// ========== MMWebViewController 完整接口声明 ==========
// 来源：微信/MMWebViewController.h（classdump 生成，本文件仅有 @class 前置声明）。
// 为保证 %hook MMWebViewController 内可用 self.webView 点语法（而非 KVC 绕弯），
// 在此显式补齐该类接口（父类为 UIViewController；webView 属性见头文件 :478，
// 类型 WKWebView<YYWebViewInterface>，编译期仅需 WKWebView 的方法，故声明为
// WKWebView* 以规避对自定义协议 YYWebViewInterface 的依赖）。
// 已确认：全头文件集合中 MMWebViewController 仅此处定义、无重复，且 CI 不预定义
// 该类带父类的完整形式，故本声明不会造成重复/不一致定义。
@interface MMWebViewController : UIViewController
@property (retain, nonatomic) WKWebView *webView;
- (BOOL)webView:(id)arg1 shouldStartLoadWithRequest:(id)arg2 navigationType:(long long)arg3 isMainFrame:(BOOL)arg4 navigationAction:(id)arg5;
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
//     【v1.4.1 对齐】真实插件对 WCAdvertiseStorage 实际 hook 的是 PBArrayAdd_* 编码方法
//     + accessor（initialize / PBArrayAdd_oAdvertiseData / PBArrayAdd_uiAdDisplayTime /
//     PBArrayAdd_uiAdCreateTime / PBArrayAdd_nsUsername / PBArrayAdd_nsAdvertiseID /
//     oAdvertiseData / init），在广告数据被编码进 Protobuf 数组时丢弃。
//     本实现保留 setter 拦截（setOAdvertiseData:/setNsAdvertiseID:）作第一道拦截，
//     并补齐 PBArrayAdd_* 编码层拦截作第二道（对齐真实插件），双保险更彻底。
//     证据：微信/WCAdvertiseStorage.h（PBArrayAdd_* 由 protobuf 自动生成，oAdvertiseData
//     属性见 :25，nsAdvertiseID 见 :29，setter 由 @property 自动合成）
%hook WCAdvertiseStorage
- (void)setOAdvertiseData:(NSData *)oAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)setNsAdvertiseID:(NSString *)nsAdvertiseID {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
// 【对齐真实插件】Protobuf 编码层拦截：广告数据在写 PB 数组时丢弃，落盘/回读不再含广告。
//     注意：PBArrayAdd_* 为【类方法】且无参数（protobuf 自动生成的编码方法，用 self/_cmd
//     读取 ivar）。证据：微信/WCAdvertiseStorage.h:18-23
+ (void)PBArrayAdd_oAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
+ (void)PBArrayAdd_uiAdDisplayTime {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
+ (void)PBArrayAdd_uiAdCreateTime {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
+ (void)PBArrayAdd_nsUsername {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
+ (void)PBArrayAdd_nsAdvertiseID {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
// 【v1.5.0 补齐·对齐真实插件】真实插件还 hook 了 initialize / init / oAdvertiseData。
//     oAdvertiseData 是广告二进制数据 getter，返回 nil 即丢弃广告数据（渲染层读不到）；
//     initialize/init 为生命周期钩子，仅对齐挂载点、不改变原逻辑，避免破坏 protobuf
//     存储对象初始化导致朋友圈存储异常。
+ (void)initialize {
    %orig;
}
- (instancetype)init {
    return %orig;
}
- (NSData *)oAdvertiseData {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return nil;
    return %orig;
}
%end

// 1.2 【朋友圈广告 · 数据装载层拦截（真实 WeChatAdBlocker 覆盖的核心入口）】
//     WCAdvertiseDataHelper 是朋友圈广告数据装载/持久化的枢纽：
//       · addAdvertiseData:needUpdateCreateTime:  → 单条广告写入
//       · addAdvertiseDataList:                   → 广告列表批量写入
//       · saveAdvertiseDatas / tryLoadAdvertiseData → 落盘/回读
//     证据：微信/WCAdvertiseDataHelper.h:52/51/56/57
//     hook 后广告既不会被装载进内存，也不会被持久化（下拉刷新后不再出现）。
//     【v1.4.1 对齐】真实插件对 WCAdvertiseDataHelper 还 hook 了
//     IsAdvertiseDataValid:dataItem: / isAdPreviewExpired: 两个有效性校验方法
//     （返回 NO / YES 让广告被判为无效/过期而不进入展示队列）。经与头文件核对，
//     真实插件涉及的 getCachedBodyWrapList / m_advertiseList / m_advertiseMsgXmlList /
//     m_bLoaded 在该微信版本中并非 WCAdvertiseDataHelper 的方法（m_* 为 ivar，
//     getCachedBodyWrapList 在 WCAdvertiseStatMgr），为避免 hook 不存在的 selector
//     造成误伤，本实现不移植这些，只保留确实存在的真实方法。
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
// 【对齐真实插件】XML 广告消息落盘 / 下拉广告对比信息（真实插件也覆盖，
//     否则广告 XML 消息与"下拉刷新对比"路径仍会写入/回读广告数据）
//     证据：微信/WCAdvertiseDataHelper.h:36 saveAdvertiseMsgXmlDatas / :28 saveAdPullCompareInfo:
- (void)saveAdvertiseMsgXmlDatas {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
- (void)saveAdPullCompareInfo:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return;
    %orig;
}
// 【v1.4.1 补齐·对齐真实插件】广告有效性 / 预览过期校验（真实插件 hook：
//   IsAdvertiseDataValid:dataItem: → NO（视为无效）；isAdPreviewExpired: → YES（视为过期））
//   证据：微信/WCAdvertiseDataHelper.h:61/62
- (BOOL)IsAdvertiseDataValid:(id)arg1 dataItem:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return NO;
    return %orig;
}
- (BOOL)isAdPreviewExpired:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockTimeline) return YES;
    return %orig;
}
// 【v1.5.0 补齐·对齐真实插件】真实插件 hook 了 init 生命周期钩子。
//     仅对齐挂载点、不改变原逻辑（避免破坏数据装载对象初始化）。
- (instancetype)init {
    return %orig;
}
%end

// 2. 公众号广告
// 2.1 公众号实验开关强制返回"不显示广告"（对齐真实 WeChatAdBlocker.dylib）
//     反汇编确认：真实插件 hook 了 BrandTLExptConfig 的全部 4 个"不显示"开关，
//     不止 isExptNotShowAd，还含推荐卡片/信息流/视频号直播栏，否则这些入口
//     的广告会漏掉。证据：微信/BrandTLExptConfig.h:34-37
%hook BrandTLExptConfig
- (BOOL)isExptNotShowAd {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
- (BOOL)isExptNotShowRecCard {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
- (BOOL)isExptNotShowRecoFlow {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
- (BOOL)isExptNotShowFinderLiveBar {
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
// 【对齐真实插件】公众号推荐广告解析 + Canvas 广告（真实插件一并覆盖，
//     防止广告走 XML 节点 / Canvas 卡片路径绕过拦截）
//     证据：微信/WCAdXmlParser.h:26 ExtractRecommendAdInfo:ByAdMsgXml: /
//           :34 setAdCanvasPage:byXmlNode:withSizeType:... /
//           :35 setAdCanvasInfo:byXmlNode: / :38 setSKAdItems:byXmlNode: /
//           :39 setAdCanvasExtXml:ByXmlNode:
+ (BOOL)ExtractRecommendAdInfo:(id)arg1 ByAdMsgXml:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (void)setAdCanvasPage:(id)arg1 byXmlNode:(id)arg2 withSizeType:(long long)arg3 basicWidth:(int)arg4 basicRootFontSize:(int)arg5 widthRoundingType:(long long)arg6 heightRoundingType:(long long)arg7 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
+ (void)setAdCanvasInfo:(id)arg1 byXmlNode:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
+ (BOOL)setSKAdItems:(id)arg1 byXmlNode:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (BOOL)setAdCanvasExtXml:(id)arg1 ByXmlNode:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
%end

// 2.3 阻止广告数据存储与读取
//     【v1.4.1 对齐】真实插件对 WCAdDB 实际 hook 的是表创建/初始化路径：
//     createPullRecordTable / createTables / initDB（不建广告相关表即无处存储）。
//     本实现保留原有 fetchPullRecordList:（下拉广告读取）与 savePullRecordInfo:
//     （下拉广告对比写入）拦截，并补齐 createPullRecordTable / createTables / initDB，
//     双保险覆盖"建表/读表"与"读写记录"两条路径。
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
// 【v1.4.1 补齐·对齐真实插件】建表 / 初始化路径（真实插件 hook，防止广告相关表被创建）
- (void)createPullRecordTable {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
- (void)createTables {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
- (void)initDB {
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

// 2.4.1 【对齐真实插件】品牌广告数据解析（真实插件 hook 的工厂方法，
//     品牌文章/消息的广告数据在此被解析成广告模型，返回 nil 即丢弃）
//     【v1.4.1 补齐】真实插件额外 hook bizTypeForAdInfoDic: / traceIdForAdInfoDic:，
//     补齐以完全对齐（阻断广告业务类型/追踪 ID 解析，防止走解析辅助路径绕过）。
//     证据：微信/BrandAdDataParser.h:18-21
%hook BrandAdDataParser
+ (id)adInfoDicForContent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
+ (id)adInfoDicForMsgWrap:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
+ (id)adDataItemForContent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
+ (id)adDataItemForMsgWrap:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
// 【v1.4.1 补齐】广告业务类型 / 追踪 ID 解析辅助方法
+ (id)bizTypeForAdInfoDic:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
+ (id)traceIdForAdInfoDic:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

// 2.4.1b 【v1.5.0 补齐·对齐真实插件】品牌广告信息模型（WCAdvertiseInfo）与广告数据项（BrandAdDataItem）
//     真实插件 hook 这些广告数据模型的 accessor/工厂，返回 nil 即丢弃广告字段：
//       · WCAdvertiseInfo（品牌广告信息）：h5PageWrap / poiH5PageWrap / adType / adExpired /
//         previewExpiredTime 均为 @dynamic 属性（返回 nil/0 丢弃广告内容），
//         setItem:value:forDynamic: / dictionaryFromADDynamicInfo: 为动态信息工厂（返回 nil）
//       · BrandAdDataItem（品牌广告数据项）：dicAdInfo / content 为 @dynamic 属性
//     证据：微信/WCAdvertiseInfo.h / BrandAdDataItem.h（均已核对方法存在）
%hook WCAdvertiseInfo
- (id)init {
    return %orig;
}
- (id)h5PageWrap {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)poiH5PageWrap {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
+ (BOOL)setItem:(id)arg1 value:(id)arg2 forDynamic:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (id)dictionaryFromADDynamicInfo:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (int)adType {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return 0;
    return %orig;
}
- (BOOL)adExpired {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return YES;
    return %orig;
}
- (long long)previewExpiredTime {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return 0;
    return %orig;
}
%end

%hook BrandAdDataItem
- (id)dicAdInfo {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)content {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

// 2.4.2 【对齐真实插件】公众号 Canvas 广告卡片开关与通知（真实插件 hook
//     isAdRequestOpen / isAdCardOpen / handleBizAdNotifyNewXml:）
//     证据：微信/BrandTLCanvasCardMgr.h:18/20/25
%hook BrandTLCanvasCardMgr
+ (BOOL)isAdRequestOpen {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (BOOL)isAdCardOpen {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
- (void)handleBizAdNotifyNewXml:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// 2.4.4 【v1.5.0 补齐·对齐真实插件】公众号"动态 Canvas 广告"加载链路
//     真实插件在动态 Canvas 广告的【加载/缓存/解析】各环节拦截，返回 nil/NO 让广告数据
//     无法组装：
//       · WCCanvasDynamicDataLoader：动态广告数据加载器
//       · WCAdDynamicCanvasServerData（服务端数据，isValid=NO / fromPBCodingBuffer: / toPBCodingBuffer / getPBPropertyTable）
//       · WCAdDynamicCanvasPageInfo（页面信息，init/fetchRealUxInfo/fetchPageInfoExtraDic/fetchPageInfoDic/fetchLaunchString 返回 nil）
//       · WCAdCanvasLoadParams（加载参数，cacheKey/canvasId/canvasDynamicInfo/dynamicCanvasLibVersion 返回 nil）
//       · WCADPageWrap（广告页面包装，adID/miniShopRequestId/uxInfo/adType 返回 nil/0）
//       · WCADCanvasInfo / WCADBodyWrap（Canvas 信息/正文包装，init 保留挂载点）
//       · WCAdSearchH5Info（搜索 H5 广告信息，isValid=NO / fromXML: 返回 nil）
//     证据：微信/对应 .h 文件均已核对方法存在。
//     说明：@dynamic 属性返回 nil 仅影响广告字段读取，不破坏 Canvas 渲染框架本身。
%hook WCCanvasDynamicDataLoader
- (void)handleAdCanvasInfoResponse:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

%hook WCAdDynamicCanvasServerData
+ (void)initialize {
    %orig;
}
- (BOOL)isValid {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
+ (id)fromPBCodingBuffer:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)toPBCodingBuffer {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)getPBPropertyTable {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

%hook WCAdDynamicCanvasPageInfo
- (id)init {
    return %orig;
}
- (id)fetchRealUxInfo {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)fetchPageInfoExtraDic {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)fetchPageInfoDic {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)fetchLaunchString {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

%hook WCAdCanvasLoadParams
- (id)init {
    return %orig;
}
- (id)cacheKey {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)canvasId {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)canvasDynamicInfo {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)dynamicCanvasLibVersion {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
%end

%hook WCADPageWrap
- (id)init {
    return %orig;
}
- (id)adID {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)miniShopRequestId {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (id)uxInfo {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (int)adType {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return 0;
    return %orig;
}
%end

%hook WCADCanvasInfo
- (id)init {
    return %orig;
}
%end

%hook WCADBodyWrap
- (id)init {
    return %orig;
}
%end

%hook WCAdSearchH5Info
+ (id)fromXML:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return nil;
    return %orig;
}
- (BOOL)isValid {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
%end

// 2.4.3 【对齐真实插件】广告统计信息获取 / 曝光上报（真实插件 hook 了
//     WCAdvertiseStatMgr 的全部 log* 上报方法与 getAdvertiseInfoForItem:）
//     返回 nil 可让"获取广告信息用于统计/上报"的链路失效，减少广告曝光追踪；
//     log* 上报方法直接 return 可阻断广告曝光 / 点击 / 时长等统计上报（无曝光数据
//     上传，广告主无法归因，是真实插件屏蔽广告曝光链路的核心之一）。
//     证据：微信/WCAdvertiseStatMgr.h:89 getAdvertiseInfoForItem: / 其余 log* 见头文件
%hook WCAdvertiseStatMgr
- (id)getAdvertiseInfoForItem:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
// 【v1.4.1 补齐·对齐真实插件】阻断广告曝光 / 点击 / 时长等统计上报
- (void)logSphereViewWithSphereReportInfo:(id)arg1 dataItem:(id)arg2 scene:(unsigned int)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logSphereViewInDetailWithWrapInfo:(id)arg1 dataItem:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logSphereViewInTimeLineWithWrapInfo:(id)arg1 dataItem:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logHeadImageH5:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADBrandProfile:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADFloatView:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADPoiH5:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADH5:(id)arg1 withUserInfo:(id)arg2 reportType:(unsigned long long)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADH5:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADDetail:(id)arg1 dataItem:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADCommentLog:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)logADBodyLog:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)reportAllFeedsADLog {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
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
//       (A) 请求层拦截广告端点（getappmsgad / ad.wx.com / ad.weixin.qq.com）。
//       【v1.4.0 修复】原 (B) 的 CSS 注入 + MutationObserver 已移除：
//       反汇编确认真实插件 WeChatAdBlocker 完全不注入 CSS，且直接
//       querySelectorAll().remove() 删 DOM + MutationObserver 持续删除极易误删
//       文章正文节点，导致"公众号文章打不开"。公众号文章广告改为靠
//       (A) 请求拦截 + 下方 BrandTLExptConfig/WCAdXmlParser/BrandAdDataParser
//       数据层拦截，与真实插件一致。
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
%end

// 3. 视频号去广告
// 3.1 【修复·视频号评论区广告 —— 采用数据层拦截（与真实 WeChatAdBlocker.dylib 一致）】
//     【v1.4.1 对齐】对真实插件反汇编精确还原 finderDataItemFromObject: 的替换函数
//     （dylib @0x6754）确认其逻辑：先调用原实现得到 dataItem，再对结果发
//     `isAd`（__objc_selrefs → "isAd"）消息；命中即返回假值丢弃广告，否则原样返回。
//     即真实插件只用 `isAd` 一个判据，不碰 isAdsLive / adFlag。
//     本实现保留 isAd 为主判，并额外保留 isAdsLive / adFlag 作兜底（不误伤普通视频，
//     普通视频这三个标识均为 0/NO）。
//
//     证据（微信/WCFinderDataItem.h:151）：
//         + (id)finderDataItemFromObject:(id)arg1;
//     该工厂把"广告对象"转换成 WCFinderDataItem；返回 nil 即丢弃该广告。
%hook WCFinderDataItem
+ (id)finderDataItemFromObject:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockFinder && arg1 != nil) {
        // 主判据：isAd（与真实插件反汇编一致）——命中即丢弃广告
        if ([arg1 respondsToSelector:@selector(isAd)] &&
            ((BOOL (*)(id, SEL))objc_msgSend)(arg1, @selector(isAd))) return nil;
        // 兜底：isAdsLive（直播广告）/ adFlag（广告标识）非 0 亦丢弃；
        // 普通视频这三个标识均为 0/NO，不会误伤（避免"视频号播放不了"）。
        if ([arg1 respondsToSelector:@selector(isAdsLive)] &&
            ((BOOL (*)(id, SEL))objc_msgSend)(arg1, @selector(isAdsLive))) return nil;
        if ([arg1 respondsToSelector:@selector(adFlag)] &&
            ((unsigned long long (*)(id, SEL))objc_msgSend)(arg1, @selector(adFlag)) != 0) return nil;
    }
    return %orig;
}
%end

// 3.2 视频流广告标识（数据层兜底）
//     说明：真实插件【未】直接 hook 这两个 accessor（只 hook finderDataItemFromObject:），
//     此处保留作额外保险——adFlag 归零 / isAdsLive 置 NO，防止广告标识经渲染路径外露。
//     证据：微信/WCFinderDataItem.h:527 @property adFlag / :505 @property isAdsLive
%hook WCFinderDataItem
- (unsigned long long)adFlag {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return 0;
    return %orig;
}
- (BOOL)isAdsLive {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return NO;
    return %orig;
}
%end

// 3.3 【v1.5.0 对齐真实插件】视频号广告【数据模型层】hook
//     真实插件在视频号广告的【数据模型】处一并拦截（比 finderDataItemFromObject: 更上游）：
//       · FinderObjectAdInfo（视频号广告对象信息，adDesc/adH5/adLeadLink/adMiniApp/adItems
//         均为 @dynamic 属性，返回 nil 丢弃广告字段）
//       · ObjectAdItem / ObjectAdContentH5（视频号广告"卡片项/H5 落地页"模型）
//       · WCAdFinderInfo.isValid（广告信息有效性校验，返回 NO 视为无效）
//       · WCFinderRouterHelper.pushFinderAdPageViewController...（拦截"跳转视频号广告页"路由）
//     证据：微信/FinderObjectAdInfo.h / ObjectAdItem.h / ObjectAdContentH5.h /
//           WCAdFinderInfo.h / WCFinderRouterHelper.h（均已核对方法存在）
//     注意：真实插件还 hook 了 WCFinderFeedContentVM 的 initWithDataItem:scene:dataScene:...
//     三个变体，但本微信版本【无 dataScene 参数】（只有 initWithDataItem:scene: 等），
//     属版本差异，不移植以防误伤视频渲染。
%hook FinderObjectAdInfo
+ (void)initialize {
    // 类初始化钩子：不拦截，仅保持原逻辑（真实插件挂载点）
    %orig;
}
- (id)adDesc {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adH5 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adLeadLink {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adMiniApp {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adItems {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
%end

%hook ObjectAdItem
+ (void)initialize {
    %orig;
}
- (id)adDesc {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adH5 {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adLeadLink {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
- (id)adMiniApp {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
%end

%hook ObjectAdContentH5
+ (void)initialize {
    %orig;
}
- (id)url {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return nil;
    return %orig;
}
%end

%hook WCAdFinderInfo
- (BOOL)isValid {
    if ([DDAdBlockConfig sharedConfig].blockFinder) return NO;
    return %orig;
}
%end

%hook WCFinderRouterHelper
+ (void)pushFinderAdPageViewControllerWithEncrytedObjectidTid:(id)arg1 nonceId:(id)arg2 currentNavController:(id)arg3 enterScene:(unsigned long long)arg4 customParam:(id)arg5 reportModel:(id)arg6 cardType:(int)arg7 requestScene:(unsigned long long)arg8 functionalParams:(id)arg9 {
    // 拦截"跳转视频号广告详情页"路由：block 开启时直接丢弃，阻止广告页打开
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
// 【对齐真实插件】isSplashADFinished：返回 YES 表示"启动广告已完成/可跳过"，
//     从状态位层面阻止 splash 广告展示。证据：微信/WAAppTask.h:273
- (BOOL)isSplashADFinished {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp) return YES;
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
//     【v1.4.1 补齐】真实插件对 WCAdvertisePushService 还 hook 了
//     OnGetNewXmlMsg:Type:MsgWrap:（新 XML 广告消息回调），补齐以完全对齐。
//     证据：微信/WCAdvertisePushService.h:14 handlePushMsg:
%hook WCAdvertisePushService
- (void)handlePushMsg:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
// 【v1.4.1 补齐·对齐真实插件】新 XML 广告消息回调
- (void)OnGetNewXmlMsg:(id)arg1 Type:(id)arg2 MsgWrap:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

%hook AdPushMsgDBMgr
- (void)insertNewPushMsg:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
// 【v1.4.1 补齐·对齐真实插件】推送广告库初始化（真实插件 hook initDB）
- (void)initDB {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// 4.3.1 【对齐真实插件】Magic Ad 推送消息统一入口（真实插件额外 hook 了
//     MagicAdPushMgrService.handleAdMsg: 与 OnGetNewXmlMsg:Type:MsgWrap:，
//     小程序/MagicAd 推送广告也可能走它们）
//     证据：微信/MagicAdPushMgrService.h:19 handleAdMsg:
%hook MagicAdPushMgrService
- (void)handleAdMsg:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp || [DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
// 【v1.4.1 补齐·对齐真实插件】新 XML 广告消息回调
- (void)OnGetNewXmlMsg:(id)arg1 Type:(id)arg2 MsgWrap:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockMiniApp || [DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
%end

// 4.4 【v1.5.0 补齐·对齐真实插件】WebView 广告 JS 事件桥（公众号文章/H5 内的广告 JS 事件）
//     真实插件在 WebView 广告 JS 事件的【事件处理/上报/信息获取】各环节拦截，从 JS 层
//     阻断广告数据传递与上报：
//       · WebviewJSEventHandler_adDataReport：广告数据上报 JS 事件
//       · WebviewJSEventHandler_getAdIdInfo：广告 ID 获取 JS 事件（+ checkUrlValid）
//       · WAJSEventHandler_adOperateWXData：广告操作微信数据 JS 事件
//       · MBEventHandler_getAdPushMsg / getOldAdInfo / setAdRequestInfo /
//         setFeedsAdRequestInfo / setAdCardRequestInfo：广告信息 JS API（invoke: 拦截）
//       · WCAdFormWebViewJSLogic：表单广告 WebView JS 逻辑（init 保留挂载点）
//       · LocalJSLogicBase.sendEvent:handler:result:：本地 JS 事件基类（广告事件上报）
//     证据：微信/对应 .h 文件均已核对方法存在。
//     说明：handleJSEvent:/invoke: 是广告 JS 事件处理入口，返回即丢弃，不影响正常 JS。
%hook WebviewJSEventHandler_adDataReport
- (void)handleJSEvent:(id)arg1 HandlerFacade:(id)arg2 ExtraData:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
%end

%hook WebviewJSEventHandler_getAdIdInfo
- (BOOL)checkUrlValid {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return NO;
    return %orig;
}
- (void)handleJSEvent:(id)arg1 HandlerFacade:(id)arg2 ExtraData:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
%end

%hook WAJSEventHandler_adOperateWXData
- (void)handleJSEvent:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
%end

%hook MBEventHandler_getAdPushMsg
- (void)invoke:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook MBEventHandler_getOldAdInfo
- (void)invoke:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook MBEventHandler_setAdRequestInfo
- (void)invoke:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook MBEventHandler_setFeedsAdRequestInfo
- (void)invoke:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook MBEventHandler_setAdCardRequestInfo
- (void)invoke:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockMiniApp) return;
    %orig;
}
%end

%hook WCAdFormWebViewJSLogic
- (id)initWithWebView:(id)arg1 pageInfo:(id)arg2 componentId:(id)arg3 qrExtInfo:(id)arg4 {
    return %orig;
}
%end

%hook LocalJSLogicBase
- (void)sendEvent:(id)arg1 handler:(id)arg2 result:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
%end

// 4.5 【v1.5.0 补齐·对齐真实插件】品牌广告 Flutter 卡片（公众号品牌文章页的 Flutter 广告卡）
//     BrandTLFlutterViewController 承载公众号品牌文章页的 Flutter 广告卡片：
//       · enableAd（BOOL property）：广告总开关，返回 NO 即关闭品牌广告卡展示
//       · insertMockCanvasModelToRecAtIndex:frameSetName:frameSetData:：向推荐流插入
//         mock Canvas 广告，拦截后推荐流不再出现广告卡
//       · reportAdBrandCardOnClick：广告卡点击上报，拦截即不上报
//       · getMagicBrushFlutterPlugins：Flutter 插件注册（保留挂载点，不拦截以免破坏
//         Flutter 插件系统）
//     证据：微信/BrandTLFlutterViewController.h（均已核对方法存在）
%hook BrandTLFlutterViewController
- (BOOL)enableAd {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return NO;
    return %orig;
}
- (void)insertMockCanvasModelToRecAtIndex:(long long)arg1 frameSetName:(id)arg2 frameSetData:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
- (void)reportAdBrandCardOnClick {
    if ([DDAdBlockConfig sharedConfig].blockBrand) return;
    %orig;
}
- (id)getMagicBrushFlutterPlugins {
    return %orig;
}
%end

// 5. 搜索页广告屏蔽（对齐真实插件 WeChatAdBlocker.dylib 的 SearchNoAds）
//     【v1.4.1 对齐】对真实插件反汇编逐点还原后确认：真实插件 WXSearchJSLogicImpl
//     实际只 hook 一个方法 —— functionCall:withParams:withCallbackID:，且替换函数
//     用 5 个关键词（__cfstring）对 withParams（JS 函数名）做匹配，命中任一即
//     return（不调用原实现）：
//        "log" / "adDataReport" / "getAdIdInfo" /
//        "reportSearchStatistics" / "reportSearchRealTimeStatistics"
//     也就是在搜索页 JS 调用层拦截广告数据上报 / 广告 ID 获取 / 搜索统计，
//     让搜索页"广告流数据"拿不到内容。正常搜索结果（onWebSearchDataChanged 等）
//     不受影响。
//     ★ 下面同时新增该 method hook 以严格对齐真实插件；原有 4 个 Rcmd 推荐数据
//       钩子保留作兜底（若搜索页仍走 Rcmd 路径可拦截）。
%hook WXSearchJSLogicImpl
// 【对齐真实插件】JS 函数调用总入口：命中广告相关 JS 函数名即丢弃
- (void)functionCall:(id)arg1 withParams:(id)arg2 withCallbackID:(id)arg3 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) {
        // withParams 即 JS 函数名/参数，按真实插件 5 关键词匹配（对齐反汇编 __cfstring）
        NSString *fn = nil;
        if ([arg2 isKindOfClass:NSString.class]) fn = arg2;
        else if ([arg2 respondsToSelector:@selector(stringValue)]) fn = [arg2 stringValue];
        if (fn.length) {
            if ([fn containsString:@"adDataReport"] ||
                [fn containsString:@"getAdIdInfo"] ||
                [fn containsString:@"reportSearchStatistics"] ||
                [fn containsString:@"reportSearchRealTimeStatistics"] ||
                [fn containsString:@"log"]) {
                return; // 丢弃广告数据上报 / 广告 ID / 搜索统计，不调用原实现
            }
        }
    }
    %orig;
}
// 【兜底】JS 请求"为你推荐"广告数据（保留，防搜索页走 Rcmd 推荐流路径）
- (void)handleJSApiFuncOfGetRcmdData:(id)arg1 withCallBackID:(id)arg2 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)onSearchRecmdDataReturn:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)onSearchRecmdDataSuccess:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
    %orig;
}
- (void)handleRcmdDataOfGlobalTab:(id)arg1 {
    if ([DDAdBlockConfig sharedConfig].blockBrand || [DDAdBlockConfig sharedConfig].blockFinder) return;
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
                                         version:@"1.5.0"
                                      controller:@"DDAdBlockSettingsViewController"];
            }
        }
    }
}

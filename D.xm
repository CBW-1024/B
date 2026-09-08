/*
 * zzAFHidePluginEntry —— 隐藏并关闭微信「插件」入口（单文件 Theos / Logos）
 *
 * 目标：wcplugins.dylib 注入到「我」页面的「插件」行 → 隐藏 + 关闭跳转。
 * 开关：长按底部「我」2 秒切换，存 NSUserDefaults（hidePluginEntryEnable），无设置界面。
 * 日志：微信沙盒 Documents/AFHidePluginEntry.log（见文件内 AF_LOG_PATH，启动即打印真实绝对路径）
 *
 * ── 逆向证据 ────────────────────────────────────────────────────────────────
 * wcplugins.dylib（ARM64，85,680 B，符号未 strip）
 *   符号 __ZL45$MoreViewController_addFunctionSection_method      @0x7210  → hook 注入点
 *   符号 __ZL47$MoreViewController_pushPluginController_method    @0x75EC  → %new 跳转方法
 *   0x726C valueForKey:@"m_tableViewMgr"   0x72AC imageNamed:@"WeChat_Lab_Logo_light_small"
 *   0x72D8 @"插件"（入口标题）              0x7358 normalCellForSel:target:leftImage:title:WithDisclosureIndicator:
 *   0x747C getSectionAt: → 0x74A4 addCell: → 0x74B4 getTableView → 0x74D8 reloadData
 *   自带类：WCPluginsMgr（+sharedInstance / registerControllerWithTitle:version:controller:）
 *          WCPluginsViewController、WCPluginModel —— 微信原始头文件里没有，可用来保守判定
 *
 * 微信头文件（WeChat/*.h）
 *   MoreViewController.h     :3 类声明   :9 m_tableViewMgr   :46 pushPluginController
 *                            :61 reloadMoreView  :64 viewDidAppear:  :83 addFunctionSection
 *   WCTableViewManager.h     :6 sections   :23 getTableView   :34 reloadTableView
 *   WCTableViewSectionManager.h :26 cells  :43 addCell:   ← 主拦截点
 *   WCTableViewCellManager.h :5 cellConfig
 *   WCTableViewCellBaseConfig.h :7 clickAction(SEL)  :8 clickTarget   ← 不用再 KVC 猜 sel/target
 *   WCTableViewCellNormalConfig.h :9 leftConfig   WCTableViewCellLeftConfig.h :6 title
 *   MMTabBarController.h     :4 类   :6 _tabBarBtns   :28 viewDidAppear:
 *                            :49 getTabBarBtnViews   :65 onTabBarItemViewsRelayout
 *
 * ── 为什么主拦截点是 addCell: 而不是 addFunctionSection ──────────────────────
 *   Substrate 后装者在外层。若本插件先加载：
 *     wcplugins(后) → 我们(先) → 原实现 → 我们清理 → 返回 → wcplugins 才 addCell: → 清理被覆盖
 *   而 WCTableViewSectionManager 的 addCell: 只有 wcplugins 在「调用」、没人在 hook，
 *   不存在互相覆盖 → 与加载顺序无关。dylib 仍用 zz 前缀，让兜底清理也排在 wcplugins 之后。
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#include <string.h>

// 越狱插件要兼容多个 iOS 版本，弃用告警统一在源码内关掉，
// 不依赖外部 CFLAGS（TWEAK_NAME 改了名字后 *_CFLAGS 变量容易对不上而失效）
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - 可调参数

/// 日志总开关（关掉后不再写文件，性能零开销）
static const BOOL   kAFLogEnabled   = YES;
/// 日志详细模式：记录每一次 addCell:（微信每次刷新会调几十次，排错时才开）
static const BOOL   kAFVerboseLog   = NO;
/// 日志超过这个体积就清空重来（字节）
static const UInt64 kAFLogMaxBytes  = 512 * 1024;
/// 是否要求 WCPluginsMgr 存在才生效（YES = 极端保守，绝不误伤微信原生行）
static const BOOL   kAFRequirePluginsMgr = YES;
/// 「我」页面清单 dump 的最小间隔（秒），避免刷屏
static const NSTimeInterval kAFDumpInterval = 60.0;

#pragma mark - 前向声明（Logos 会把 %hook 里的 self 类型写成被 hook 的类名，必须先声明）

@interface MoreViewController : UIViewController
@end
@interface MMTabBarController : UITabBarController
@end
@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)a0;
@end

#pragma mark - 日志

static NSString * const kAFLogFileName = @"AFHidePluginEntry.log";

static NSString *AFLogPath(void) {
    // 在微信进程里，NSDocumentDirectory 就是微信沙盒 Documents
    static NSString *p;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        p = [doc stringByAppendingPathComponent:kAFLogFileName];
    });
    return p;
}

static NSFileHandle *gAFLogFH;

static NSString *AFNow(void) {
    static NSDateFormatter *f;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        f = [[NSDateFormatter alloc] init];
        f.dateFormat = @"MM-dd HH:mm:ss.SSS";
    });
    return [f stringFromDate:[NSDate date]];
}

static void AFLogOpen(void) {
    if (gAFLogFH) return;
    NSString *path = AFLogPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createFileAtPath:path contents:nil attributes:nil];
    } else {
        NSDictionary *attr = [fm attributesOfItemAtPath:path error:nil];
        if ([attr[NSFileSize] unsignedLongLongValue] > kAFLogMaxBytes) {
            [fm removeItemAtPath:path error:nil];
            [fm createFileAtPath:path contents:nil attributes:nil];
        }
    }
    gAFLogFH = [NSFileHandle fileHandleForWritingAtPath:path];
    [gAFLogFH seekToEndOfFile];
}

static void AFLogWrite(NSString *line) {
    if (!kAFLogEnabled) return;
    @synchronized ([NSFileHandle class]) {
        @try {
            if (!gAFLogFH) AFLogOpen();
            if (!gAFLogFH) return;
            NSString *s = [NSString stringWithFormat:@"%@ %@\n", AFNow(), line];
            [gAFLogFH writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
        } @catch (NSException *e) {
            gAFLogFH = nil;
        }
    }
}

#define AFLog(fmt, ...) AFLogWrite([NSString stringWithFormat:(fmt), ##__VA_ARGS__])

#pragma mark - 开关

static NSString * const kAFHideKey = @"hidePluginEntryEnable";

static BOOL AFHideEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kAFHideKey];
}

static void AFSetHideEnabled(BOOL on) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:on forKey:kAFHideKey];
    [ud synchronize];
}

#pragma mark - 取 cell 信息

static id AFSafeValue(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try { return [obj valueForKey:key]; }
    @catch (NSException *e) { return nil; }
}

/// 读返回 SEL 的 getter —— KVC 对 SEL 类型不可靠，必须用 NSInvocation
static SEL AFReadSEL(id obj, SEL getter) {
    if (!obj || ![obj respondsToSelector:getter]) return NULL;
    NSMethodSignature *sig = [obj methodSignatureForSelector:getter];
    if (!sig || strcmp(sig.methodReturnType, ":") != 0) return NULL;
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    inv.selector = getter;
    @try { [inv invokeWithTarget:obj]; } @catch (NSException *e) { return NULL; }
    SEL s = NULL;
    [inv getReturnValue:&s];
    return s;
}

static NSString *AFCellTitle(id cell) {
    id t = AFSafeValue(AFSafeValue(AFSafeValue(cell, @"cellConfig"), @"leftConfig"), @"title");
    if ([t isKindOfClass:NSString.class]) return t;
    t = AFSafeValue(cell, @"title");                       // 旧版 cell 自带 title
    return [t isKindOfClass:NSString.class] ? t : nil;
}

static NSString *AFCellActionName(id cell) {
    SEL s = AFReadSEL(AFSafeValue(cell, @"cellConfig"), NSSelectorFromString(@"clickAction"));
    if (s) return NSStringFromSelector(s);

    id v = AFSafeValue(cell, @"sel");                      // 老版本回退
    if ([v isKindOfClass:NSString.class]) return v;
    if ([v isKindOfClass:NSValue.class]) {
        SEL s2 = NULL;
        @try { [v getValue:&s2]; } @catch (NSException *e) { }
        if (s2) return NSStringFromSelector(s2);
    }
    return nil;
}

static id AFCellTarget(id cell) {
    id cfg = AFSafeValue(cell, @"cellConfig");
    SEL g = NSSelectorFromString(@"clickTarget");
    if ([cfg respondsToSelector:g]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id t = [cfg performSelector:g];
#pragma clang diagnostic pop
        if (t) return t;
    }
    return AFSafeValue(cell, @"target");
}

/// 一行描述，日志和排错全靠它
static NSString *AFDescribeCell(id cell) {
    id target = AFCellTarget(cell);
    return [NSString stringWithFormat:@"title=\"%@\" action=%@ target=%@",
            AFCellTitle(cell) ?: @"(nil)",
            AFCellActionName(cell) ?: @"(nil)",
            target ? NSStringFromClass([target class]) : @"(nil)"];
}

#pragma mark - 判定

/// 纯特征判定，不看开关 —— dump 时用它能标出「哪行是插件行」
static BOOL AFCellLooksLikePlugin(id cell) {
    if (!cell) return NO;

    NSString *title = AFCellTitle(cell);
    if (title.length == 0) return NO;

    BOOL exact = [@[@"插件", @"插件管理", @"插件中心", @"插件归纳", @"微信插件", @"插件设置"] containsObject:title];
    BOOL fuzzy = [title rangeOfString:@"插件"].location != NSNotFound;
    if (!exact && !fuzzy) return NO;

    NSString *action = AFCellActionName(cell) ?: @"";
    if ([action isEqualToString:@"pushPluginController"]) return YES;      // wcplugins 字符串铁证
    if ([action rangeOfString:@"plugin" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;

    id target = AFCellTarget(cell);
    NSString *cls = target ? NSStringFromClass([target class]) : @"";
    if ([cls rangeOfString:@"Plugin" options:NSCaseInsensitiveSearch].location != NSNotFound) return YES;
    // action 读不到时的兜底：标题精确为「插件」且 target 就是「我」页本身
    if (exact && [cls hasSuffix:@"MoreViewController"]) return YES;
    return NO;
}

/// 真正用于拦截的判定：叠加开关 + 插件体系存在性
static BOOL AFIsPluginEntryCell(id cell) {
    if (!AFHideEnabled()) return NO;
    if (kAFRequirePluginsMgr && !NSClassFromString(@"WCPluginsMgr")) return NO;
    return AFCellLooksLikePlugin(cell);
}

#pragma mark - 「我」页面：容器、扫描、清理

static NSInteger gAFHitCount = 0;              // 本次拦截计数（Toast 展示用）
static void AFDumpIfNeeded(id vc, BOOL force); // 定义在文件末尾（节流 dump）

static id AFMgr(id vc) {
    return AFSafeValue(vc, @"m_tableViewMgr") ?: AFSafeValue(vc, @"m_tableViewInfo");
}

static NSArray *AFSections(id mgr) {
    id s = AFSafeValue(mgr, @"sections");
    return [s isKindOfClass:NSArray.class] ? s : nil;
}

static void AFReloadMgr(id mgr) {
    if ([mgr respondsToSelector:NSSelectorFromString(@"reloadTableView")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [mgr performSelector:NSSelectorFromString(@"reloadTableView")];
#pragma clang diagnostic pop
        return;
    }
    UITableView *tv = AFSafeValue(mgr, @"tableView");
    if ([tv isKindOfClass:UITableView.class]) [tv reloadData];
}

/// 打印「我」页面全部 cell（含命中标记）—— 看日志就知道微信里到底有没有「插件」行、叫什么
static void AFDumpMoreVC(id vc) {
    id mgr = AFMgr(vc);
    NSArray *sections = AFSections(mgr);
    if (!sections) { AFLog(@"[dump] 取不到 sections（m_tableViewMgr=%@）", mgr ? @"有" : @"无"); return; }

    AFLog(@"[dump] ---- 「我」页面清单 %@ | %lu 段 ----", NSStringFromClass([vc class]), (unsigned long)sections.count);
    NSUInteger hits = 0, total = 0;
    for (NSUInteger i = 0; i < sections.count; i++) {
        NSArray *cells = AFSafeValue(sections[i], @"cells");
        if (![cells isKindOfClass:NSArray.class]) continue;
        for (NSUInteger j = 0; j < cells.count; j++) {
            BOOL hit = AFCellLooksLikePlugin(cells[j]);
            if (hit) hits++;
            total++;
            AFLog(@"[dump] s%lu.c%-2lu %@%@", (unsigned long)i, (unsigned long)j,
                  AFDescribeCell(cells[j]), hit ? @"   <<< 疑似插件行" : @"");
        }
    }
    AFLog(@"[dump] 共 %lu 行，疑似插件行 %lu（隐藏开关=%@）",
          (unsigned long)total, (unsigned long)hits, AFHideEnabled() ? @"开" : @"关");
}

/// 移除已混进 cells 的插件行，返回移除数量
static NSInteger AFCleanMoreVC(id vc, const char *tag) {
    if (!AFHideEnabled()) return 0;
    NSArray *sections = AFSections(AFMgr(vc));
    if (!sections) { AFLog(@"[clean:%s] 取不到 sections", tag); return 0; }

    NSInteger removed = 0;
    for (id section in sections) {
        NSMutableArray *cells = AFSafeValue(section, @"cells");
        if (![cells isKindOfClass:NSMutableArray.class]) continue;
        NSMutableArray *doomed = [NSMutableArray array];
        for (id cell in cells) {
            if (AFCellLooksLikePlugin(cell)) [doomed addObject:cell];
        }
        if (doomed.count == 0) continue;
        for (id cell in doomed) AFLog(@"[clean:%s] 移除 %@", tag, AFDescribeCell(cell));
        [cells removeObjectsInArray:doomed];
        removed += doomed.count;
    }
    if (removed) {
        AFReloadMgr(AFMgr(vc));
        AFLog(@"[clean:%s] 共移除 %ld 行，已刷新", tag, (long)removed);
    }
    return removed;
}

static void AFCleanLater(id vc, const char *tag) {
    dispatch_async(dispatch_get_main_queue(), ^{ AFCleanMoreVC(vc, tag); });
}

/// 首次安装完成后提示一次日志在哪（微信沙盒 Documents，爱思/iMazing 导出微信容器即可看到）
/// 注意：必须在 AFToast 之后定义
static void AFHintLogPathOnce(void);

static void AFToast(NSString *text) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:UIWindowScene.class]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { window = w; break; }
                }
            }
        }
    }
    if (!window) {
        // keyWindow 自 iOS 13 起弃用；这里用 pragma 就地压制，避免外部 CFLAGS 没带 -Wno- 时被 -Werror 卡住
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = UIApplication.sharedApplication.keyWindow;
#pragma clang diagnostic pop
    }
    if (!window) return;

    UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat w = [text sizeWithAttributes:@{NSFontAttributeName: font}].width + 32;
    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, MIN(w, window.bounds.size.width - 40), 36)];
    tip.text = text;
    tip.font = font;
    tip.textColor = [UIColor whiteColor];
    tip.textAlignment = NSTextAlignmentCenter;
    tip.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.78];
    tip.layer.cornerRadius = 8;
    tip.layer.masksToBounds = YES;
    tip.alpha = 0;
    tip.center = CGPointMake(window.bounds.size.width / 2, window.bounds.size.height - 120);
    [window addSubview:tip];

    [UIView animateWithDuration:0.18 animations:^{ tip.alpha = 1; } completion:^(BOOL f) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.25 animations:^{ tip.alpha = 0; } completion:^(BOOL f2) {
                [tip removeFromSuperview];
            }];
        });
    }];
}

static void AFHintLogPathOnce(void) {
    NSString *k = @"AFHidePluginEntry.logHinted";
    if ([[NSUserDefaults standardUserDefaults] boolForKey:k]) return;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:k];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AFToast([NSString stringWithFormat:@"日志: Documents/%@", kAFLogFileName]);
    });
}

#pragma mark - 长按「我」2 秒

static UIView *AFMeTabButton(id tabBarVC) {
    NSArray *views = nil;
    SEL sel = NSSelectorFromString(@"getTabBarBtnViews");       // MMTabBarController.h:49
    if ([tabBarVC respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id ret = [tabBarVC performSelector:sel];
#pragma clang diagnostic pop
        if ([ret isKindOfClass:NSArray.class]) views = ret;
    }
    if (views.count == 0) {                                     // 回退：ivar _tabBarBtns
        Ivar iv = class_getInstanceVariable([tabBarVC class], "_tabBarBtns");
        if (iv) {
            id ret = object_getIvar(tabBarVC, iv);
            if ([ret isKindOfClass:NSArray.class]) views = ret;
        }
    }
    // 微信 tab：微信/通讯录/发现/我 → 「我」是最后一个
    UIView *last = [views lastObject];
    if ([last isKindOfClass:UIView.class]) return last;
    for (id v in views) {                                       // 再兜底：找带「我」的按钮
        if ([v isKindOfClass:UIView.class] &&
            (((UIView *)v).accessibilityLabel.length == 0 ||
             [((UIView *)v).accessibilityLabel containsString:@"我"])) return v;
    }
    return nil;
}

static char kAFGestureKey;

static void AFInstallGesture(id tabBarVC) {
    if (!tabBarVC) return;
    SEL action = NSSelectorFromString(@"af_toggleHidePluginEntryLongPress:");
    if (![tabBarVC respondsToSelector:action]) return;          // %new 没注入成功就别装

    UIView *meBtn = AFMeTabButton(tabBarVC);
    if (!meBtn) return;
    if (objc_getAssociatedObject(meBtn, &kAFGestureKey)) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:tabBarVC action:action];
    lp.minimumPressDuration = 2.0;
    lp.cancelsTouchesInView = NO;                               // 不吞掉正常点击
    [meBtn addGestureRecognizer:lp];
    objc_setAssociatedObject(meBtn, &kAFGestureKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AFLog(@"[gesture] 已装长按手势 → %@ (0x%lx)", NSStringFromClass([meBtn class]), (unsigned long)meBtn);
}

#pragma mark - Hook ①：主拦截点（顺序无关）

%group AFSectionGroup

%hook WCTableViewSectionManager

// WCTableViewSectionManager.h:43；wcplugins 在 addFunctionSection 里靠它插入「插件」行（0x74A4）
- (void)addCell:(id)cell {
    if (kAFVerboseLog) AFLog(@"[addCell] %@", AFDescribeCell(cell));
    if (AFIsPluginEntryCell(cell)) {
        AFLog(@"[addCell] ✅ 已拦截 %@", AFDescribeCell(cell));
        gAFHitCount++;
        return;
    }
    %orig;
}

%end

// ---- end of %group AFSectionGroup ----
%end

#pragma mark - Hook ②：「我」页面兜底清理

%group AFMoreVCGroup

%hook MoreViewController

- (void)addFunctionSection {
    %orig;
    AFCleanMoreVC(self, "addFunctionSection");
}

- (void)reloadMoreView {
    %orig;
    AFCleanLater(self, "reloadMoreView");
    AFDumpIfNeeded(self, NO);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    AFCleanLater(self, "viewDidAppear");
    AFDumpIfNeeded(self, NO);
}

%end

// ---- end of %group AFMoreVCGroup ----
%end

#pragma mark - Hook ③：底部 Tab（长按手势载体）

%group AFTabBarGroup

%hook MMTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    AFInstallGesture(self);
}

- (void)onTabBarItemViewsRelayout {
    %orig;                                  // MMTabBarController.h:65 重建后按钮会换新，要重装
    AFInstallGesture(self);
}

%new
- (void)af_toggleHidePluginEntryLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    BOOL on = !AFHideEnabled();
    AFSetHideEnabled(on);
    gAFHitCount = 0;

    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [fb impactOccurred];
    }
    AFLog(@"[switch] 长按触发 → 隐藏=%@", on ? @"开" : @"关");

    UIViewController *selVC = nil;
    if ([self isKindOfClass:UITabBarController.class]) {
        selVC = ((UITabBarController *)self).selectedViewController;
        if ([selVC isKindOfClass:UINavigationController.class]) {
            selVC = [(UINavigationController *)selVC topViewController];
        }
    }
    if ([selVC respondsToSelector:NSSelectorFromString(@"reloadMoreView")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [selVC performSelector:NSSelectorFromString(@"reloadMoreView")];
#pragma clang diagnostic pop
    }
    AFDumpIfNeeded(selVC, YES);              // 切换后强制 dump 一次，看日志立知命中情况
    AFToast(on ? [NSString stringWithFormat:@"已隐藏插件入口 · 拦截 %ld 行", (long)gAFHitCount]
               : @"已恢复插件入口");
}

%end

// ---- end of %group AFTabBarGroup ----
%end

#pragma mark - 动态 hook：pushPluginController（真正「关闭」跳转）

// wcplugins 用 %new 加的（0x75EC），编译期不一定存在；用 Logos %hook 会因 orig==NULL 在 %orig 处崩溃，
// 所以运行时 MSHookMessageEx 挂，并且先判 class_getInstanceMethod。
static void (*AFOrigPush)(id self, SEL _cmd);
static void AFHookPush(id self, SEL _cmd) {
    AFLog(@"[push] pushPluginController 被调用（隐藏=%@）", AFHideEnabled() ? @"开 → 已吞掉" : @"关 → 放行");
    if (AFHideEnabled()) return;
    if (AFOrigPush) AFOrigPush(self, _cmd);
}

static void (*AFOrigPushAlt)(id self, SEL _cmd);
static void AFHookPushAlt(id self, SEL _cmd) {
    if (AFHideEnabled()) return;
    if (AFOrigPushAlt) AFOrigPushAlt(self, _cmd);
}

static void (*AFOrigAltReload)(id self, SEL _cmd);
static void AFHookAltReload(id self, SEL _cmd) {
    if (AFOrigAltReload) AFOrigAltReload(self, _cmd);
    AFCleanLater(self, "alt:reloadMoreView");
    AFDumpIfNeeded(self, NO);
}

#pragma mark - 计数与 dump 节流

static CFAbsoluteTime gAFLastDump = 0;

static void AFDumpIfNeeded(id vc, BOOL force) {
    if (![vc isKindOfClass:UIViewController.class]) return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (!force && now - gAFLastDump < kAFDumpInterval) return;
    gAFLastDump = now;
    AFDumpMoreVC(vc);
}

#pragma mark - ctor

%ctor {
    @autoreleasepool {
        NSString *ver = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
        AFLog(@"==== zzAFHidePluginEntry 启动 | 微信 %@ | iOS %@ ====",
              ver ?: @"?", UIDevice.currentDevice.systemVersion);
        AFLog(@"[log] 日志路径: %@", AFLogPath());
        AFLog(@"[log] 用爱思助手 / iMazing 导出微信容器，或 Filza 打开上面路径即可查看");
        AFLog(@"[switch] 初始状态 隐藏=%@", AFHideEnabled() ? @"开" : @"关");

        const char *probe[] = { "MoreViewController", "WCTableViewSectionManager",
                                "MMTabBarController", "WCPluginsMgr" };
        for (int i = 0; i < 4; i++) {
            AFLog(@"[ctor] %-28s = %@", probe[i], objc_getClass(probe[i]) ? @"存在" : @"不存在");
        }

        if (objc_getClass("WCTableViewSectionManager")) { %init(AFSectionGroup); AFLog(@"[ctor] 已 hook WCTableViewSectionManager -addCell:"); }
        else AFLog(@"[ctor] !! WCTableViewSectionManager 不存在，主拦截点未安装");

        if (objc_getClass("MoreViewController")) { %init(AFMoreVCGroup); AFLog(@"[ctor] 已 hook MoreViewController"); }
        else AFLog(@"[ctor] !! MoreViewController 不存在");

        if (objc_getClass("MMTabBarController")) { %init(AFTabBarGroup); AFLog(@"[ctor] 已 hook MMTabBarController"); }
        else AFLog(@"[ctor] !! MMTabBarController 不存在，长按手势不可用");

        Class moreVC = objc_getClass("MoreViewController");
        SEL pushSel = NSSelectorFromString(@"pushPluginController");
        if (moreVC && class_getInstanceMethod(moreVC, pushSel)) {
            MSHookMessageEx(moreVC, pushSel, (IMP)&AFHookPush, (IMP *)&AFOrigPush);
            AFLog(@"[ctor] 已 hook -[MoreViewController pushPluginController]（关闭跳转）");
        } else {
            AFLog(@"[ctor] !! pushPluginController 不存在，跳转拦截未安装");
        }

        Class alt = objc_getClass("NewMoreViewController");
        if (alt && alt != moreVC) {
            AFLog(@"[ctor] 检测到 NewMoreViewController，启用兜底分支");
            if (class_getInstanceMethod(alt, NSSelectorFromString(@"reloadMoreView"))) {
                MSHookMessageEx(alt, NSSelectorFromString(@"reloadMoreView"),
                                (IMP)&AFHookAltReload, (IMP *)&AFOrigAltReload);
            }
            if (class_getInstanceMethod(alt, pushSel)) {
                MSHookMessageEx(alt, pushSel, (IMP)&AFHookPushAlt, (IMP *)&AFOrigPushAlt);
            }
        }
        AFLog(@"==== ctor 完成 ====");
        AFHintLogPathOnce();
    }
}

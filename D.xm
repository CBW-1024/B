/*
 * zzAFHidePluginEntry —— 隐藏微信「我」页面的「插件」入口（单文件 Theos / Logos）
 *
 * 只做一件事：拦掉 wcplugins 加进来的那一行。不 hook 跳转、不禁用插件功能。
 *
 * ── 实测依据（微信 8.0.78 / iOS 18.7.10，AFHidePluginEntry.log）─────────────
 *   [dump] s2.c5  title="插件" action=pushPluginController target=MoreViewController
 *   [拦截] ✅ title="插件" action=pushPluginController target=MoreViewController
 *   [dump] 共 7 行（隐藏=开）     ← 切换开关后页面从 8 行变 7 行
 *
 * ── 为什么只 hook 一个 addCell: 就够 ────────────────────────────────────────
 *   wcplugins 在 -[MoreViewController addFunctionSection] 里靠 [section addCell:] 插入该行：
 *     0x747C getSectionAt: → 0x74A4 addCell: → 0x74B4 getTableView → 0x74D8 reloadData
 *   而开关切换后微信会重建整张表、重新 addCell:（实测日志里切换后立刻又出现一次拦截），
 *   所以拦截 addCell: 这一个点同时覆盖了「首次加载」和「后续刷新」，不需要任何兜底清理。
 *   附带好处：addCell: 只有 wcplugins 在「调用」、没人在 hook，因此与 dylib 加载顺序无关。
 *
 * 开关：长按底部「我」2 秒，Success / Warning 两种震动反馈，无界面无弹窗。
 * 日志：微信沙盒 Documents/AFHidePluginEntry.log
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#include <string.h>

// 越狱插件要兼容多个 iOS 版本，弃用告警在源码内关掉，不依赖外部 CFLAGS
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma mark - 可调参数

/// 日志总开关
static const BOOL kAFLogEnabled = YES;
/// 日志超过这个体积就清空重来（字节）
static const UInt64 kAFLogMaxBytes = 512 * 1024;

#pragma mark - 前向声明（Logos 会把 %hook 里的 self 类型写成被 hook 的类名）

@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)a0;
@end
@interface MMTabBarController : UITabBarController
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
static NSObject *gAFLogLock;

static void AFLogWrite(NSString *line) {
    if (!kAFLogEnabled) return;
    if (!gAFLogLock) gAFLogLock = [NSObject new];
    @synchronized (gAFLogLock) {
        @try {
            if (!gAFLogFH) {
                NSString *path = AFLogPath();
                NSFileManager *fm = [NSFileManager defaultManager];
                if (![fm fileExistsAtPath:path]) {
                    [fm createFileAtPath:path contents:nil attributes:nil];
                } else if ([fm attributesOfItemAtPath:path error:nil][NSFileSize].unsignedLongLongValue > kAFLogMaxBytes) {
                    [fm removeItemAtPath:path error:nil];
                    [fm createFileAtPath:path contents:nil attributes:nil];
                }
                gAFLogFH = [NSFileHandle fileHandleForWritingAtPath:path];
                [gAFLogFH seekToEndOfFile];
            }
            static NSDateFormatter *fmt;
            static dispatch_once_t once;
            dispatch_once(&once, ^{ fmt = [[NSDateFormatter alloc] init]; fmt.dateFormat = @"MM-dd HH:mm:ss.SSS"; });
            NSString *s = [NSString stringWithFormat:@"%@ %@\n", [fmt stringFromDate:[NSDate date]], line];
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

#pragma mark - 读 cell 信息

static id AFSafeValue(id obj, NSString *key) {
    if (!obj || key.length == 0) return nil;
    @try { return [obj valueForKey:key]; }
    @catch (NSException *e) { return nil; }
}

/// SEL 类型不能走 KVC，必须用 NSInvocation 读
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
    return [t isKindOfClass:NSString.class] ? t : nil;
}

static NSString *AFCellActionName(id cell) {
    SEL s = AFReadSEL(AFSafeValue(cell, @"cellConfig"), NSSelectorFromString(@"clickAction"));
    return s ? NSStringFromSelector(s) : nil;
}

static NSString *AFDescribeCell(id cell) {
    id target = AFSafeValue(AFSafeValue(cell, @"cellConfig"), @"clickTarget");
    return [NSString stringWithFormat:@"title=\"%@\" action=%@ target=%@",
            AFCellTitle(cell) ?: @"(nil)",
            AFCellActionName(cell) ?: @"(nil)",
            target ? NSStringFromClass([target class]) : @"(nil)"];
}

#pragma mark - 判定

/// 纯特征，不看开关 —— dump 时用来给行打标记
static BOOL AFCellLooksLikePlugin(id cell) {
    NSString *title = AFCellTitle(cell);
    if ([title rangeOfString:@"插件"].location == NSNotFound) return NO;
    NSString *action = AFCellActionName(cell) ?: @"";
    return [action isEqualToString:@"pushPluginController"] ||                              // 实测值
           [action rangeOfString:@"plugin" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

/// 拦截判定：叠加开关 + 插件体系存在性（WCPluginsMgr 是 wcplugins 自带的类，微信原生没有）
static BOOL AFIsPluginCell(id cell) {
    return AFHideEnabled() && NSClassFromString(@"WCPluginsMgr") && AFCellLooksLikePlugin(cell);
}

#pragma mark - dump「我」页面清单（只在切换开关后调用）

static void AFDumpMoreVC(id vc) {
    NSArray *sections = AFSafeValue(AFSafeValue(vc, @"m_tableViewMgr"), @"sections");
    if (![sections isKindOfClass:NSArray.class]) { AFLog(@"[dump] 取不到 sections"); return; }

    NSUInteger total = 0, hits = 0;
    for (NSUInteger i = 0; i < sections.count; i++) {
        NSArray *cells = AFSafeValue(sections[i], @"cells");
        if (![cells isKindOfClass:NSArray.class]) continue;
        for (NSUInteger j = 0; j < cells.count; j++) {
            BOOL hit = AFCellLooksLikePlugin(cells[j]);
            if (hit) hits++;
            total++;
            AFLog(@"[dump] s%lu.c%-2lu %@%@", (unsigned long)i, (unsigned long)j,
                  AFDescribeCell(cells[j]), hit ? @"   <<< 插件入口" : @"");
        }
    }
    AFLog(@"[dump] 共 %lu 行，插件入口 %lu 行（隐藏=%@）",
          (unsigned long)total, (unsigned long)hits, AFHideEnabled() ? @"开" : @"关");
}

#pragma mark - 触觉反馈

/// 开 = 成功反馈，关 = 警告反馈，手感不同，不看屏幕也知道切到哪边
static void AFHaptic(BOOL enabled) {
    if (@available(iOS 10.0, *)) {
        UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
        [fb prepare];
        [fb notificationOccurred:enabled ? UINotificationFeedbackTypeSuccess
                                         : UINotificationFeedbackTypeWarning];
    }
}

#pragma mark - 长按「我」2 秒

/// MMTabBarController.h:49 -[MMTabBarController getTabBarBtnViews]
static UIView *AFMeTabButton(id tabBarVC) {
    NSArray *views = nil;
    SEL sel = NSSelectorFromString(@"getTabBarBtnViews");
    if ([tabBarVC respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id ret = [tabBarVC performSelector:sel];
#pragma clang diagnostic pop
        if ([ret isKindOfClass:NSArray.class]) views = ret;
    }
    // 微信 tab：微信/通讯录/发现/我 → 「我」是最后一个（实测命中 UITabBarButton）
    UIView *last = [views lastObject];
    return [last isKindOfClass:UIView.class] ? last : nil;
}

static char kAFGestureKey;

static void AFInstallGesture(id tabBarVC) {
    SEL action = NSSelectorFromString(@"af_toggleHidePluginEntryLongPress:");
    if (!tabBarVC || ![tabBarVC respondsToSelector:action]) return;
    UIView *meBtn = AFMeTabButton(tabBarVC);
    if (!meBtn || objc_getAssociatedObject(meBtn, &kAFGestureKey)) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:tabBarVC action:action];
    lp.minimumPressDuration = 2.0;
    lp.cancelsTouchesInView = NO;                       // 不吞掉正常点击
    [meBtn addGestureRecognizer:lp];
    objc_setAssociatedObject(meBtn, &kAFGestureKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AFLog(@"[gesture] 已装长按手势 → %@ (0x%lx)", NSStringFromClass([meBtn class]), (unsigned long)meBtn);
}

#pragma mark - 唯一的拦截点

%hook WCTableViewSectionManager

// wcplugins 在 -[MoreViewController addFunctionSection] 里靠这个方法插入「插件」行（0x74A4）
- (void)addCell:(id)cell {
    if (AFIsPluginCell(cell)) {
        AFLog(@"[拦截] ✅ %@", AFDescribeCell(cell));
        return;
    }
    %orig;
}

%end

#pragma mark - 长按手势载体

%hook MMTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    AFInstallGesture(self);
}

%new
- (void)af_toggleHidePluginEntryLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    BOOL on = !AFHideEnabled();
    AFSetHideEnabled(on);
    AFHaptic(on);
    AFLog(@"[switch] 长按触发 → 隐藏=%@", on ? @"开" : @"关");

    // 让微信重建「我」页：重建时会重新走 addCell:，插件行在那一趟就被拦掉了（实测验证过）
    UIViewController *vc = self.selectedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) vc = [(UINavigationController *)vc topViewController];
    if ([vc respondsToSelector:NSSelectorFromString(@"reloadMoreView")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [vc performSelector:NSSelectorFromString(@"reloadMoreView")];
#pragma clang diagnostic pop
    }
    dispatch_async(dispatch_get_main_queue(), ^{ AFDumpMoreVC(vc); });
}

%end

#pragma mark - ctor

%ctor {
    @autoreleasepool {
        AFLog(@"==== zzAFHidePluginEntry 启动 | 微信 %@ | iOS %@ ====",
              [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"] ?: @"?",
              UIDevice.currentDevice.systemVersion);
        AFLog(@"[log] 路径: %@（爱思/iMazing 导出微信容器，或 Filza 直接打开）", AFLogPath());
        AFLog(@"[switch] 初始状态 隐藏=%@", AFHideEnabled() ? @"开" : @"关");
        AFLog(@"[ctor] 类探测 SectionMgr=%d TabBar=%d PluginsMgr=%d",
              !!objc_getClass("WCTableViewSectionManager"),
              !!objc_getClass("MMTabBarController"),
              !!objc_getClass("WCPluginsMgr"));
        %init;
        AFLog(@"[ctor] 已 hook -[WCTableViewSectionManager addCell:]（唯一拦截点）");
        AFLog(@"[ctor] 已 hook MMTabBarController（长按手势）");
        AFLog(@"==== ctor 完成 ====");
    }
}

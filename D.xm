// ═══════════════════════════════════════════════════════════════════
//  WXBundleIDBypass — 纯运行时 dylib 版（不依赖 CydiaSubstrate / 越狱）
//
//  适用场景: 重签名 IPA + 注入 dylib（Sideloadly / 爱思 / iOSGods 等）
//  不适用:   Theos/Logos（那个版本见 Tweak.xm）
//
//  绕过原理（基于砸壳微信二进制 dump 的类级证据）:
//    WeChat/ManualAuthAesReqData.h   @property NSString *bundleId;
//    WeChat/AutoAuthAesReqData.h     @property NSString *bundleId;
//    这两个登录请求体会把 bundleId 明文上报服务端，
//    服务端判定非官方包 -> "该 bundleId 需要内测资格" -> 拒绝登录。
//    微信 dump 中不存在任何客户端侧 bundleId 校验方法（grep 零命中），
//    且 BaseRequest 不含 bundleId -> 这是唯一上报入口。
//
//  日志会写到:
//    <微信沙盒>/Documents/WXBypassLogs/bypass.log
//  在 iOS「文件」App ->「我的 iPhone」-> 微信  里可以看到
//  （需要重签名时给 Info.plist 加上 UIFileSharingEnabled = YES，见 README）
// ═══════════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdlib.h>

#pragma mark - 配置

// 官方微信 bundleId：分身的 bundleId 会统一伪装成这个
static NSString * const kSpoofBundleID = @"com.tencent.xin";

// ── 可选开关 ──────────────────────────────────────────────
// 是否连 NSBundle 的 bundleIdentifier 一起伪装。
// 主方案（改登录请求体）失败时再开这个。
// ⚠️ 风险：会影响 App 内所有读取自身 bundleId 的地方，
//    可能导致钥匙串访问组、App Group、扩展等异常。默认关闭。
#define WXBID_ALSO_SPOOF_NSBUNDLE 0
// ─────────────────────────────────────────────────────────

// 关键方法名（微信 dump 中确认存在）
static NSString * const kTargetClasses[] = {
    @"ManualAuthAesReqData",
    @"AutoAuthAesReqData",
};

#pragma mark - 文件日志

static NSString *WXBypassLogDirectory(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = paths.firstObject;
    if (!doc) doc = @"/var/mobile/Documents";
    return [doc stringByAppendingPathComponent:@"WXBypassLogs"];
}

static NSString *WXBypassLogPath(void) {
    return [WXBypassLogDirectory() stringByAppendingPathComponent:@"bypass.log"];
}

static NSFileHandle *gLogHandle = nil;
static dispatch_queue_t gLogQueue = NULL;

static void WXLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [fmt stringFromDate:[NSDate date]], msg];

    // 同时 NSLog（越狱设备可在 Console 看到）
    NSLog(@"[WXBundleIDBypass] %@", msg);

    dispatch_async(gLogQueue ?: dispatch_get_main_queue(), ^{
        if (!gLogHandle) {
            NSString *dir = WXBypassLogDirectory();
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
            NSString *path = WXBypassLogPath();
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            }
            gLogHandle = [NSFileHandle fileHandleForWritingAtPath:path];
            if (gLogHandle) [gLogHandle seekToEndOfFile];
        }
        if (gLogHandle) {
            [gLogHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [gLogHandle synchronizeFile];   // 立即落盘，防止杀进程丢日志
        }
    });
}

#pragma mark - Swizzle 工具

// 安全替换实例方法：若方法继承自父类，则在本类新增 override，
// 绝不改动父类的实现（否则会波及所有子类，风险极大）。
static BOOL WXSwizzle(Class cls, SEL sel, id block) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) {
        WXLog(@"    [跳过] %@ 未实现 %@", cls, NSStringFromSelector(sel));
        return NO;
    }

    IMP newImp = imp_implementationWithBlock(block);

    Class superCls = class_getSuperclass(cls);
    Method superM = superCls ? class_getInstanceMethod(superCls, sel) : NULL;
    BOOL inherited = (superM && method_getImplementation(m) == method_getImplementation(superM));

    if (inherited) {
        BOOL added = class_addMethod(cls, sel, newImp, method_getTypeEncoding(m));
        WXLog(@"    [%@] %@ %@ 继承自父类 -> 在本类新增 override（父类实现未动）",
              added ? @"成功" : @"失败", cls, NSStringFromSelector(sel));
        return added;
    }

    IMP oldImp = method_setImplementation(m, newImp);
    WXLog(@"    [成功] %@ %@ 已替换 (orig=%p -> new=%p)",
          cls, NSStringFromSelector(sel), oldImp, newImp);
    return oldImp != NULL;
}

#pragma mark - 核心: 强制伪装 bundleId

// 对「任意一个实现了 setBundleId:/bundleId 的类」做伪装
static void SpoofBundleIDOnClass(Class cls) {
    if (!cls) return;
    NSString *clsName = NSStringFromClass(cls);

    SEL setSel = @selector(setBundleId:);
    SEL getSel = @selector(bundleId);

    Method setM = class_getInstanceMethod(cls, setSel);
    if (setM) {
        IMP origSet = method_getImplementation(setM);
        WXSwizzle(cls, setSel, ^(id self_, NSString *bundleId) {
            WXLog(@">>> %@ setBundleId: 原始=%@  ->  伪装=%@", clsName, bundleId, kSpoofBundleID);
            ((void (*)(id, SEL, NSString *))origSet)(self_, setSel, kSpoofBundleID);
        });
    }

    Method getM = class_getInstanceMethod(cls, getSel);
    if (getM) {
        IMP origGet = method_getImplementation(getM);
        WXSwizzle(cls, getSel, ^NSString *(id self_) {
            NSString *orig = ((NSString *(*)(id, SEL))origGet)(self_, getSel);
            if (orig && ![orig isEqualToString:kSpoofBundleID]) {
                WXLog(@">>> %@ bundleId getter 原始=%@  ->  伪装=%@", clsName, orig, kSpoofBundleID);
            }
            return kSpoofBundleID;
        });
    }
}

#pragma mark - 诊断: 全量扫描哪些类实现了 setBundleId:

static void ScanAndReportClassesWithBundleID(void) {
    WXLog(@"---- 开始全量扫描: 所有实现了 setBundleId: 的类 ----");

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSMutableArray *found = [NSMutableArray array];

    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        unsigned int mcount = 0;
        Method *methods = class_copyMethodList(cls, &mcount);
        for (unsigned int m = 0; m < mcount; m++) {
            SEL sel = method_getName(methods[m]);
            NSString *name = NSStringFromSelector(sel);
            if ([name isEqualToString:@"setBundleId:"]) {
                [found addObject:NSStringFromClass(cls)];
                break;
            }
        }
        free(methods);
    }
    free(classes);

    WXLog(@"当前进程共 %u 个类，其中实现 setBundleId: 的有 %lu 个:", count, (unsigned long)found.count);
    for (NSString *c in [found sortedArrayUsingSelector:@selector(compare:)]) {
        WXLog(@"    * %@", c);
    }
    WXLog(@"---- 扫描结束 ----");
}

#pragma mark - 兜底: 请求体生成后二次校正

static void SpoofRequestBuilder(NSString *clsName, SEL genSel, NSString *reqKeyPath) {
    Class cls = NSClassFromString(clsName);
    if (!cls) {
        WXLog(@"    [跳过] 未找到类 %@（版本可能不同）", clsName);
        return;
    }
    Method m = class_getInstanceMethod(cls, genSel);
    if (!m) {
        WXLog(@"    [跳过] %@ 未实现 %@", clsName, NSStringFromSelector(genSel));
        return;
    }

    IMP orig = method_getImplementation(m);
    WXSwizzle(cls, genSel, ^id(id self_, BOOL a0) {
        id req = ((id (*)(id, SEL, BOOL))orig)(self_, genSel, a0);
        @try {
            id aes = [req valueForKey:@"aesReqData"];
            NSString *cur = [aes valueForKey:@"bundleId"];
            if (cur && ![cur isEqualToString:kSpoofBundleID]) {
                [aes setValue:kSpoofBundleID forKey:@"bundleId"];
                WXLog(@">>> %@ %@ 二次校正: %@ -> %@",
                      clsName, NSStringFromSelector(genSel), cur, kSpoofBundleID);
            } else {
                WXLog(@"    %@ %@ 生成完毕，bundleId=%@", clsName, NSStringFromSelector(genSel), cur);
            }
        } @catch (NSException *e) {
            WXLog(@"    [异常] %@ %@ 二次校正失败: %@", clsName, NSStringFromSelector(genSel), e);
        }
        return req;
    });
}

#pragma mark - 入口

__attribute__((constructor))
static void WXBundleIDBypassEntry(void) {
    @autoreleasepool {
        gLogQueue = dispatch_queue_create("com.wx.bypass.log", DISPATCH_QUEUE_SERIAL);

        WXLog(@"═══════════════════════════════════════════");
        WXLog(@"  WXBundleIDBypass 已注入");
        WXLog(@"═══════════════════════════════════════════");

        // 基本环境
        NSBundle *mb = [NSBundle mainBundle];
        WXLog(@"进程: %@", [[NSProcessInfo processInfo] processName]);
        WXLog(@"可执行文件: %@", [[NSBundle mainBundle] executablePath]);
        WXLog(@"当前 bundleId: %@", mb.bundleIdentifier);
        WXLog(@"Info.plist CFBundleIdentifier: %@", mb.infoDictionary[@"CFBundleIdentifier"]);
        WXLog(@"微信版本: %@ (%@)",
              mb.infoDictionary[@"CFBundleShortVersionString"],
              mb.infoDictionary[@"CFBundleVersion"]);
        WXLog(@"系统: %@", [[UIDevice currentDevice] systemVersion]);
        WXLog(@"伪装目标: %@", kSpoofBundleID);
        WXLog(@"日志路径: %@", WXBypassLogPath());

        // 1) 诊断扫描
        ScanAndReportClassesWithBundleID();

        // 2) 目标类直接 hook
        WXLog(@"---- 开始 hook 已知登录请求体 ----");
        for (size_t i = 0; i < sizeof(kTargetClasses)/sizeof(kTargetClasses[0]); i++) {
            Class cls = NSClassFromString(kTargetClasses[i]);
            if (!cls) {
                WXLog(@"  [严重] 未找到类 %@ —— 请查看上方扫描结果，可能是版本差异", kTargetClasses[i]);
                continue;
            }
            WXLog(@"  处理类: %@", kTargetClasses[i]);
            SpoofBundleIDOnClass(cls);
        }

        // 3) 兜底：请求构造处二次校正
        WXLog(@"---- 开始 hook 请求构造入口（兜底）----");
        SpoofRequestBuilder(@"WCAccountManualAuthControlLogic",
                            @selector(genManualAuthRequest:), @"aesReqData");
        SpoofRequestBuilder(@"WCAccountAutoLoginControlLogic",
                            @selector(genAutoAuthRequest:), @"aesReqData");

#if WXBID_ALSO_SPOOF_NSBUNDLE
        // 4) 可选：连 NSBundle.bundleIdentifier 一起伪装
        WXLog(@"---- [可选开关已开] hook NSBundle bundleIdentifier ----");
        Method mbM = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
        if (mbM) {
            IMP origMB = method_getImplementation(mbM);
            method_setImplementation(mbM, imp_implementationWithBlock(^NSString *(id self_) {
                NSString *orig = ((NSString *(*)(id, SEL))origMB)(self_, @selector(bundleIdentifier));
                if (self_ == [NSBundle mainBundle] && orig && ![orig isEqualToString:kSpoofBundleID]) {
                    WXLog(@">>> NSBundle(mainBundle) bundleIdentifier 原始=%@ -> 伪装=%@",
                          orig, kSpoofBundleID);
                    return kSpoofBundleID;
                }
                return orig;   // 非 mainBundle 保持原样，避免影响扩展/资源包
            }));
            WXLog(@"    [成功] NSBundle bundleIdentifier 已替换");
        }
#endif

        WXLog(@"---- 初始化完成，等待登录流程触发 ----");
        WXLog(@"提示: 若下方始终没有 '>>>' 开头的记录，说明登录请求未走到被 hook 的路径，");
        WXLog(@"      请把本文件发回，重点看「全量扫描」那段列出的类名。");
    }
}

//============================================================================
//  WCPBidSpoof — 微信多开 bundle id 处理（单文件 Logos tweak）
//----------------------------------------------------------------------------
//  对齐商业插件 WCRefine (WCR) 的【已验证】行为：bundleIdentifier 透传真实 id。
//
//  ⚠️ 关键修正（v1.0.6）：之前版本全局把 bundleIdentifier 改成 com.tencent.xin，
//     导致 UI 移位 + APNs 推送丢失。反编译 WCR 并用 Unicorn 模拟跑通后证实：
//     WCR 的 bundleIdentifier hook【永远返回真实 id】，从不伪装成 com.tencent.xin。
//
//  【证据：WCR bundleIdentifier IMP（0x1582ec0）Unicorn 模拟结果】
//    * 门控=开：执行 61 条指令 → 最终 x0 = 真实 bid（"com.tencent.qy.xin"）
//      门控=关：执行 32 条指令 → 最终 x0 = 真实 bid
//      → 两种状态都返回真实 id，com.tencent.xin(CFString 0x1f8fe88) 分支是死代码
//        （被 `self == bundleIdentifier 返回的 NSString` 这个永不成立的条件守着）。
//    * 返回路径调 (*0x2203458)(self,_cmd)；二进制里无指令写入 0x2203458，
//      该槽由动态链接器/CydiaSubstrate 在加载时填入【原始 bundleIdentifier IMP】，
//      故返回真实 id。这是 WCR「没有任何问题」(推送/UI 正常) 的根因：
//      它从不改动微信推送/UI 子系统读取的 bundle id。
//
//  【为什么全局伪装会坏推送/UI】
//    APNs topic = app【真实】bundle id（苹果用它加密 device token）。微信把
//    [NSBundle mainBundle] bundleIdentifier] 当 topic 上报服务器；伪装成官方 id 后
//    topic 与 token 加密主题不符 → 苹果静默丢弃推送。WCR 返回真实 id，天然规避。
//
//  【证据来源】
//  * WCR 反编译：/workspace/work/WCRefine.dylib（hooks_inventory.txt 共 1788 个 hook）
//      - 仅 hook NSBundle @bundleIdentifier（IMP=0x1582ec0, &orig=0x2203458），
//        门控字节 0x2203560；模拟证实返回真实 id。
//      - 完整反汇编：python3 wcr/wcrdis.py 1582ec0 900
//      - 模拟器：    python3 wcr/wcr_emu.py gate1 / gate0
//      - **不 hook objectForInfoDictionaryKey:**（grep hooks_inventory 零命中）。
//      - 仅 hook 通知*点击响应* userNotificationCenter:didReceiveNotificationResponse:
//        （IMP 0x157b0f0 / 0x157b4c4）：先调 orig 再跑多开路由，不碰注册/deviceToken/解密。
//  * WCP 还原（/workspace/WCP_bid_hook取证.md）：WCP 的 bundleIdentifier 在某些门控下
//      确实会返回 com.tencent.xin，但那是 WCP 的行为；WCR 已修正为透传真实 id，
//      本插件以【工作正常的 WCR】为对齐基准。
//  * 微信头文件（/workspace/wx76/微信/）：TSEnvironment.h:25、FBSDKAppEventsDeviceInfo.h:17
//      证明微信内部通过 NSBundle 读 bundleID，hook 在正确层级。
//
//  【本插件策略（对齐 WCR）】
//    1. bundleIdentifier → 返回真实 id（%orig），仅记录日志供调试。
//       这正是 WCR 的做法，可保推送 topic 与 UI 资源分支正确。
//    2. objectForInfoDictionaryKey: → 默认不 hook（WCR 不 hook）。如需观察微信是否
//       经此路径识别多开，可开 HOOK_OBJECT_FOR_INFO_DICT 仅记日志，不改返回值。
//    3. 不 hook 任何推送注册 / deviceToken / 解密方法（与 WCR 一致）。
//
//  【登录 / 人脸 如何处理？】
//    若你的多开仍需“登录 / 过人脸”，那不是 bundle id 伪装能解决的——WCR 返回真实 id
//    也能正常登录/过人脸，说明相关机制在【其他 hook】（如 FaceRecogFlashHandler 之类），
//    而非 bundle id。需要时可单独逆向 WCR 的对应 hook 再补。
//
//  【日志】
//    无条件在 %ctor 开日志，写到【app 文件沙盒 Documents】：
//      NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
//      → /var/mobile/Containers/Data/Application/<UUID>/Documents/wcpbidspoof.log
//    （rootful / rootless 越狱下都正确；文件打不开则走 NSLog 兜底，syslog 搜 [WCPBidSpoof]）
//============================================================================

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <time.h>
#include <stdarg.h>
#include <execinfo.h>
#include <unistd.h>
#include <string.h>

//------------------------------ 配置开关 -------------------------------------
#define WCP_VERSION                "1.0.6"
#define HOOK_BUNDLE_IDENTIFIER    1   // 是否 hook bundleIdentifier（仅记日志 + 透传真实 id）
#define HOOK_OBJECT_FOR_INFO_DICT 0   // ⚠️ WCR 不 hook 此方法。开=仅记日志不改返回值
#define ENABLE_LOGGING            1   // 沙盒文件日志（打不开则走 NSLog 兜底）
#define LOG_VERBOSE               1   // 1 = 打印每次 bundleIdentifier 调用；0 = 不打印
#define WCP_LOG_MAX_LINES         8000

//------------------------------ 日志子系统 -----------------------------------
static FILE        *gWCPLog = NULL;
static volatile int gWCPLogging = 0;     // 重入保护（日志内部若触发 hook 直接丢弃）
static long         gWCPLogLines = 0;
static volatile int gWCPInHook  = 0;     // hook 内部重入保护
static long         gWCPCallCount = 0;
static char         gWCPLogPath[2048] = {0};  // 软件文件沙盒 Documents 路径（%ctor 解析）

// 只写到 app 的【文件沙盒 Documents】：/var/mobile/Containers/Data/Application/<UUID>/Documents
// 取径方式用 NSSearchPathForDirectoriesInDomains，rootful / rootless 都正确（不受 /var/jb 重定向影响）。
// 若沙盒路径打不开，不写文件、不散落到 /tmp 等非沙盒目录，改走 NSLog 兜底（syslog 可见）。
static void WCPLogOpen(void) {
    if (gWCPLog) return;
    if (!gWCPLogPath[0]) return;         // 路径未就绪（%ctor 未设置），交给 NSLog
    gWCPLog = fopen(gWCPLogPath, "a");
    if (gWCPLog) {
        fprintf(gWCPLog, "=== WCPBidSpoof log opened @ %s (uid=%d HOME=%s) ===\n",
                gWCPLogPath, getuid(), getenv("HOME") ?: "(null)");
        fflush(gWCPLog);
    }
}

// 先把格式串展开成 C 串（va_list 仅消费一次），再写文件 / NSLog。
static void WCPLogV(const char *fmt, va_list ap) {
#if !ENABLE_LOGGING
    (void)fmt; (void)ap;
    return;
#else
    if (gWCPLogging) return;
    gWCPLogging = 1;
    char body[2048];
    vsnprintf(body, sizeof(body), fmt, ap);
    if (gWCPLog) {
        if (gWCPLogLines < WCP_LOG_MAX_LINES) {
            time_t t = time(NULL);
            struct tm tm_now; localtime_r(&t, &tm_now);
            fprintf(gWCPLog, "[%04d-%02d-%02d %02d:%02d:%02d] %s\n",
                    tm_now.tm_year + 1900, tm_now.tm_mon + 1, tm_now.tm_mday,
                    tm_now.tm_hour, tm_now.tm_min, tm_now.tm_sec, body);
            fflush(gWCPLog);
            gWCPLogLines++;
        }
    } else {
        // 文件未开：兜底走 NSLog（设备 syslog / 控制台可见）
        NSLog(@"[WCPBidSpoof] %s", body);
    }
    gWCPLogging = 0;
#endif
}

// 变参 C 壳：把 C 格式串 + 变参正确打包成 va_list 再交给 WCPLogV。
// 注意：不能直接 WCPLogV("%s", charPtr) —— WCPLogV 第 2 形参是 va_list，
// 直接塞 const char* 既编不过（arm64 上 va_list==char*，丢 const 限定符），
// 运行时也会让 vsnprintf 读到野指针崩溃。必须经变参函数生成合法 va_list。
static void WCPLogC(const char *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    WCPLogV(fmt, ap);
    va_end(ap);
}

static void WCPLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *body = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    WCPLogC("%s", [body UTF8String]);
}

//------------------------------ 判定逻辑 -------------------------------------
static BOOL IsMainBundle(NSBundle *self) {
    return self == [NSBundle mainBundle];
}

%group WCPBidSpoof

%hook NSBundle

// 证据：WCR MSHookMessageEx(NSBundle, @bundleIdentifier, IMP=0x1582ec0, &orig=0x2203458)
// 模拟证实：该 IMP 无论门控开/关都返回【真实 id】——com.tencent.xin 分支是死代码。
// 故本 hook 对齐 WCR：仅记日志 + 透传真实 id（不伪装）。
- (NSString *)bundleIdentifier {
#if HOOK_BUNDLE_IDENTIFIER
    if (gWCPInHook) return %orig;          // 重入保护
    gWCPInHook = 1;
    NSString *orig = %orig;
    gWCPCallCount++;

#if LOG_VERBOSE
    if (IsMainBundle(self)) {
        WCPLog(@"bundleIdentifier | MAIN orig=%@ (passthrough, WCR-aligned) #%ld",
               orig, gWCPCallCount);
    }
#endif

    gWCPInHook = 0;
    return orig;                            // ← 真实 id 透传（与 WCR 一致）
#else
    return %orig;
#endif
}

// 证据：WCR 不 hook objectForInfoDictionaryKey:（grep hooks_inventory 零命中）。
// 默认不 hook；开启后仅记日志、不改返回值（用于观察微信是否经此路径识别多开）。
- (id)objectForInfoDictionaryKey:(NSString *)key {
#if HOOK_OBJECT_FOR_INFO_DICT
    if (IsMainBundle(self) && [key isEqualToString:@"CFBundleIdentifier"]) {
        NSString *orig = %orig;
        WCPLog(@"objectForInfoDictionaryKey | key=CFBundleIdentifier orig=%@ (passthrough) #%ld",
               orig, gWCPCallCount);
        return orig;
    }
#endif
    return %orig;
}

%end

%end

%ctor {
    @autoreleasepool {
        // 先解析 app 文件沙盒 Documents 路径（此时 hook 尚未安装，调用原生方法安全）
        NSString *doc = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                            NSUserDomainMask, YES).firstObject;
        if (!doc) {
            const char *home = getenv("HOME");
            if (home && *home) doc = [NSString stringWithFormat:@"%s/Documents", home];
        }
        if (doc) snprintf(gWCPLogPath, sizeof(gWCPLogPath),
                          "%s/wcpbidspoof.log", doc.UTF8String);
        WCPLogOpen();   // 无条件开日志，保证能在沙盒里找到文件
        NSString *exe = [[NSBundle mainBundle] executablePath];
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        WCPLog(@"=== WCPBidSpoof %s init (uid=%d) exe=%@ bid=%@ BID=%d OFI=%d ===",
               WCP_VERSION, getuid(), exe, bid,
               HOOK_BUNDLE_IDENTIFIER, HOOK_OBJECT_FOR_INFO_DICT);
        // 始终在微信进程内安装 hook；是否伪装在每次调用时按真实 bid + 调用方判定。
        // 官方版（com.tencent.xin）调用会落到 orig，行为无变化。
        if (exe && [exe containsString:@"WeChat"]) {
            %init(WCPBidSpoof);
            WCPLog(@"init: hooks installed (bundleIdentifier = passthrough real id, WCR-aligned)");
        } else {
            WCPLog(@"init: executable not WeChat, skip");
        }
    }
}

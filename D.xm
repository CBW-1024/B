#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>

// ============================================================================
// NC — 微信反检测 / 多开保活层
//
// 1:1 对齐 WCRefine 的 -[NSBundle bundleIdentifier] hook（2026-08-29 逐指令反汇编核实）
// ────────────────────────────────────────────────────────────────────────────
// WCRefine 确实 hook 了 -[NSBundle bundleIdentifier]，证据链（铁证，全部来自本机二进制）：
//
// ▸ hook 注册（构造函数 @0x15826f4，封装自 MSHookMessageEx）：
//       adrp x0, 0x1daa000 ; +0x764 → "NSBundle"
//       bl   0x1ca5afc     ; objc_getClass("NSBundle")
//       ldr  x1, [x8,#0x3b0] ; @selector(bundleIdentifier)  (selref 0x20533b0)
//       adrp x2, 0x1582000 ; +0xec0  → replacement IMP = 0x1582ec0
//       adrp x3, 0x2203000 ; +0x458  → &orig @ 0x2203458
//       bl   0x1ca5328     ; MSHookMessageEx(NSBundle, bundleIdentifier, repl, &orig)
//
// ▸ replacement IMP @0x1582ec0 的三层门控（与下列 NC 实现逐条对应）：
//   ① 全局开关字节 @0x2203560 (bit0)：为 0 → 直接走 orig 返回【真实 bid】。
//      该字节初始为 0，由 FaceRecogFlashHandler initPipeline 置 1（dealloc 置 0），
//      故"启动/推送注册"阶段读到真实 bid（APNs 正常），initPipeline 后才进入伪装态。
//   ② self==[NSBundle mainBundle] 判定（classref@0x2073560=NSBundle +
//      @selector(mainBundle)@0x204a800 比较）：非主包 → 返回【真实 bid】
//   ③ 调用 0x159556c() 辅助判定 —— 这是对齐的核心，见下。返回 1 →
//      CFString @0x1f8fe88 = @"com.tencent.xin"；返回 0 → orig 真实 bid。
//
// ▸ 辅助函数 0x159556c 的真实机制（已逐 selector 解析，非"会话态"）：
//       A  = objc_msgSend(classref@0x2073670=NSThread,
//                         @selector(callStackReturnAddresses)@0x205e818)
//            → [NSThread callStackReturnAddresses]   (NSArray<NSNumber*>，栈返回地址)
//       B  = objc_msgSend(A, @selector(count)@0x204a340)
//       if (B <= 2)  → return 0  (栈太浅，不伪装)
//       C  = objc_msgSend(A, @selector(objectAtIndexedSubscript:)@0x204a6c8, 2)  → 栈帧2地址
//       D  = objc_msgSend(C, @selector(unsignedLongLongValue)@0x204b530)         → 地址转 u64
//       再取 classref@0x20734c0 配置类的 stringWithUTF8String:@0x204d530 结果，
//       与 [NSBundle mainBundle].bundlePath(@0x205c990) 做
//       length@0x204a398 / hasPrefix:@0x204a380 字符串前缀匹配，最终定 0 或 1。
//   ⇒ WCR 用【调用栈返回地址 + 主包 bundlePath 字符串前缀匹配】判定是否处于
//     "需要伪装的调用上下文"。默认（不命中）返回真实 bid；命中时返回 com.tencent.xin。
//
//   这解释了 WCR 为什么"完美"：它【不是全局伪装、也不是手动会话态标志】，而是
//   【默认真实 bid，仅当调用栈命中登录/鉴权深层路径才伪装】。推送令牌注册发生在
//   登录前的浅栈调用里 → 读到真实 bid → APNs 按真实 bid(com.tencent.qy.xin) 派发；
//   登录/长连接(Mars)鉴权在深层调用栈里 → 命中 → 伪装成官方 bid → 过服务端校验。
//
// ── 本实现的 1:1 对齐策略 ──────────────────────────────────────────────────
// 机制逐条对齐 WCR：① 开关 + ② 主包判定 + ③ 调用栈判定；【默认真实 bid，
// 仅"主包 + 调用者位于主程序镜像"才伪装】。多开装包 bid 非 com.tencent.xin
// （如 com.tencent.qy.xin）时，微信服务端在 登录 / 长连接(Mars)鉴权 时按官方
// bid 校验 app 身份 → 非官方直接被拒；故登录/鉴权链须伪装成 com.tencent.xin，
// 其余（含推送注册，通常由框架发起）一律真实 bid。
//
// ③ 调用栈判定的 1:1 还原说明：WCR 的 0x159556c 取 [NSThread callStackReturnAddresses]
// 的 A[2]（即 bundleIdentifier 的调用点返回地址），将该地址经配置类 NSString 化后
// 与主包路径做 hasPrefix:/length 匹配。配置串来自 WCR 运行时/远端、本机静态不可见，
// 故以「调用者镜像 == 主程序 executablePath」精确近似：只命中"主程序镜像内"的调用
// （登录/鉴权多在此），天然排除"框架镜像"调用（推送/SDK 多在此）→ 推送拿真实 bid、
// APNs 不丢，比"关键词匹配"更贴近 WCR 的"调用者镜像"语义。
// 若实测某次登录未命中（登录链恰好不在主程序镜像），把该场景的 backtrace 给我再放宽。
// ============================================================================

// 官方微信 bundle id（伪装目标）
#define WC_OFFICIAL_BID @"com.tencent.xin"

// 总开关：对齐 WCR 全局字节 @0x2203560。
// 关键时序（已逐指令核实）：该字节【初始为 0】（bid 不伪装）→
//   FaceRecogFlashHandler initPipeline 运行时置 1（启用伪装）→
//   FaceRecogFlashHandler dealloc 时置 0（关闭伪装）。
// 故默认 NO（与 @0x2203560 初始 0 一致）：app 启动、推送令牌注册发生在
// initPipeline 之前 → 读到真实 bid → APNs 正常；initPipeline 跑完后登录/鉴权
// 读到的才是官方 bid。切勿默认 YES——否则启动即全局伪装会搞挂推送。
// 调试时临时置 NO 即等同 WCR 该字节清零。
static BOOL g_wcBidEnabled = NO;

#pragma mark - 调用栈判定：对齐 WCR 0x159556c 的调用者镜像分析

/// 对齐 WCR 辅助函数 0x159556c：用调用栈判定当前 bundleIdentifier 的调用者
/// 是否位于【主程序可执行文件镜像】内。
///
/// WCR 机制：取 [NSThread callStackReturnAddresses] 的 A[2]（bundleIdentifier 的
/// 调用点返回地址），将该地址经配置类 NSString 化后与主包路径做前缀匹配。
/// 本实现以 dladdr 取该返回地址所属镜像路径，与目标主程序 executablePath 精确比较，
/// 语义等价且更严格：只命中"主程序镜像内"的调用（登录/鉴权多在此），
/// 排除"框架镜像"调用（推送/SDK 多在此）→ 推送天然拿到真实 bid，APNs 不丢。
///
/// 与 WCR 的偏差（已尽量收窄）：WCR 实际比较的配置串来自运行时/远端、本机不可见，
/// 故以 executablePath 近似。其余（取 A[2]、count<=2 早退）均与 WCR 逐条一致。
static BOOL wc_callerInMainBundle(void) {
    NSArray<NSNumber *> *addrs = [NSThread callStackReturnAddresses];
    if (addrs.count <= 2) return NO;                         // 对齐 WCR: B<=2 → 不伪装
    uintptr_t pc = addrs[2].unsignedLongLongValue;            // 对齐 WCR: C = A[2]
    Dl_info info;
    if (dladdr((void *)pc, &info) == 0 || info.dli_fname == NULL) return NO;
    NSString *callerImage = [NSString stringWithUTF8String:info.dli_fname];
    // 对齐 WCR 的"主包路径前缀匹配"：用主程序可执行文件路径精确判定调用者镜像。
    return [callerImage isEqualToString:[NSBundle mainBundle].executablePath];
}

#pragma mark - 1:1 对齐 WCR 的 bundleIdentifier 三层门控

// WCR replacement IMP @0x1582ec0 逐条对应：
//   ① g_wcBidEnabled == NO             → 返回真实 bid            (对齐 @0x2203560 开关)
//   ② self != 主包                     → 返回真实 bid            (对齐 self==mainBundle 判定)
//   ③ wc_callerInMainBundle() == YES   → 返回 @"com.tencent.xin" (对齐 0x159556c 调用者镜像判定)
//   其余                               → 返回真实 bid
// 即【默认真实、调用者位于主程序镜像才伪装】，与 WCR 行为同构。
%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *real = %orig;

    // 官方包（单开 / 非多开）：原样返回，无操作
    if ([real isEqualToString:WC_OFFICIAL_BID]) {
        return real;
    }
    // ① 总开关关闭 → 真实 bid
    if (!g_wcBidEnabled) {
        return real;
    }
    // ② 非主包（其它 embedded framework）→ 真实 bid
    if (self != [NSBundle mainBundle]) {
        return real;
    }
    // ③ 调用者位于主程序镜像（登录/鉴权多在此）→ 伪装成官方 bid，过服务端校验
    if (wc_callerInMainBundle()) {
        return WC_OFFICIAL_BID;
    }
    // 其余（推送注册等浅栈路径）→ 真实 bid，保住 APNs
    return real;
}

%end

#pragma mark - FaceRecogFlashHandler Hook：对齐 WCR 的 bid 伪装生命周期开关

// WCR 用 FaceRecogFlashHandler 的 lifecycle 驱动 bid 伪装总开关 @0x2203560：
//   initPipeline (replacement IMP 0x1583034): strb #1 -> @0x2203560   (启用伪装)
//   dealloc     (replacement IMP 0x1583074): strb #0 -> @0x2203560   (关闭伪装)
// 这正是 WCR "完美" 的关键：推送令牌注册发生在 initPipeline 之前（开关=0 → 真实 bid
// → APNs 正常），initPipeline 跑完才进入伪装态（登录/鉴权读到的才是官方 bid）。
// 纯透传 %orig 会漏掉置位副作用 → 伪装永不启用。两个 hook 必须保留并保持置位顺序。
//
// 证据锚定：wx76/微信/FaceRecogFlashHandler.h:97
//     @interface FaceRecogFlashHandler
//     - (void)initPipeline;        // line 97

%hook FaceRecogFlashHandler

- (void)initPipeline {
    g_wcBidEnabled = YES;   // 对齐 WCR 0x1583034：置 @0x2203560=1，启用 bid 伪装
    %orig;
}

- (void)dealloc {
    g_wcBidEnabled = NO;    // 对齐 WCR 0x1583074：置 @0x2203560=0，关闭 bid 伪装
    %orig;
}

%end

#pragma mark - 构造函数：初始化所有 Hook

%ctor {
    @autoreleasepool {
        %init;
    }
}

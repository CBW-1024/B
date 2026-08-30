/*
 * WCPulseLite.xm  —  单文件 iOS 越狱 Tweak（theos / Logos）
 * ============================================================================
 * 功能：让把 bundle id 从 com.tencent.xin 改成 com.tencent.qy.xin 重打包后的
 *      微信测试版能够正常登录（绕过"该账号尚未获得体验资格，无法使用该微信
 *      测试版本"这一闸门）。
 *
 * ── 逆向结论（已用 capstone 反汇编 WCPulse.dylib 坐实）──────────────────────
 *  登录闸门是【微信测试版自己的】：它取 [NSBundle mainBundle] bundleIdentifier]
 *  与官方 bid 比对，不符即弹"体验资格"提示。该文案并不在 WCPulse 二进制内
 *  （搜不到"体验资格/尚未获得"），印证闸门属于微信，WCPulse 只在外层把"bid"
 *  这块上游输入替换掉。
 *
 *  WCPulse 实际挂接的代码（反汇编定位的地址）：
 *    • 替换实现(被 hook 的 bundleIdentifier IMP) @ 0x50a20
 *    • 注册函数(__mod_init 大初始化函数)        @ 0x25e1c
 *        把 0x50a20 作为 IMP 传给 MSHookMessageEx(NSBundle, bundleIdentifier, …)
 *    • 关键明文引用（arm64e 链式绑定藏死了其它名字，但这几处是明文）：
 *        NSBundle 类引用            @ 0xaffea0
 *        mainBundle   selref 槽     @ 0xaf8eb0
 *        bundleIdentifier selref 槽 @ 0xaf8eb8
 *
 *  被替换实现的语义（源码级还原）：
 *      - (NSString *)bundleIdentifier {
 *          NSBundle *main = [NSBundle mainBundle];
 *          NSString *realBid = [main bundleIdentifier];   // 重打包后 = com.tencent.qy.xin
 *          if ([self isEqual:main]) {                      // self 就是主 bundle
 *              return SPOOFED_BID;                         // 运行时解出的 com.tencent.xin
 *          }
 *          return ORIG_IMP(self, _cmd);                    // 其它走原实现
 *      }
 *
 *  要返回的官方 bid 不在明文（全二进制搜不到 com.tencent.xin / com.tencent.qy.xin
 *  字面量），而是藏在以密钥 WCPulse#Ctrl@2026 加密的高熵 blob 里、由混淆 helper
 *  运行时解出。机理上返回 com.tencent.xin（返回其它值对过闸无意义），用文末 Frida
 *  抓 [NSBundle mainBundle] bundleIdentifier] 即可确认；若实测不同，改 kSpoofedBundleId。
 *
 * ── 本 Tweak 手段（仅一条，与 WCPulse 同思路）──────────────────────────────
 *  hook [NSBundle bundleIdentifier]：仅当接收者是 [NSBundle mainBundle]（即被重打包
 *  的微信本体）时返回官方 bid，其余一律走原实现，避免误伤插件自身 / 系统框架。
 *
 * ── 构建（需 theos + iOS SDK，Mac/Linux 均可）──────────────────────────────
 *  目录结构：
 *    WCPulseLite/
 *      ├─ Makefile
 *      ├─ control        (见下方注释模板)
 *      ├─ Tweak.xm       = 本文件
 *    Makefile：
 *      TWEAK_NAME = WCPulseLite
 *      WCPulseLite_FILES = Tweak.xm
 *      WCPulseLite_FRAMEWORKS = Foundation
 *      include $(THEOS)/makefiles/common.mk
 *      include $(THEOS_MAKE_PATH)/tweak.mk
 *      after-install::
 *          install.exec "killall -9 WeChat || true"
 *  然后：  make package  →  安装到越狱机  →  重启微信。
 * ============================================================================
 */

#import <substrate.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// 要伪造返回的官方 bundle id。
// 若用 Frida 抓到 WCPulse 实测返回的不是这个值，改这里即可（依据见文件头注释）。
static NSString *const kSpoofedBundleId = @"com.tencent.xin";

// 原实现指针（由 MSHookMessageEx 回填）。
static NSString *(*orig_bundleIdentifier)(NSBundle *, SEL) = NULL;

// ── 替换实现：仅对主 bundle 生效 ────────────────────────────────────────────
static NSString *hook_bundleIdentifier(NSBundle *self, SEL _cmd) {
    if (self == [NSBundle mainBundle]) {
        return kSpoofedBundleId;
    }
    return orig_bundleIdentifier ? orig_bundleIdentifier(self, _cmd) : nil;
}

%ctor {
    Class nsBundle = objc_getClass("NSBundle");
    SEL selBid = @selector(bundleIdentifier);

    if (nsBundle && class_getInstanceMethod(nsBundle, selBid)) {
        MSHookMessageEx(nsBundle, selBid,
                        (IMP)hook_bundleIdentifier,
                        (IMP *)&orig_bundleIdentifier);
        NSLog(@"[WCPulseLite] 已 hook [NSBundle bundleIdentifier] -> 主 bundle 返回 %@", kSpoofedBundleId);
    } else {
        NSLog(@"[WCPulseLite] 未找到 NSBundle/bundleIdentifier，跳过");
    }

    NSLog(@"[WCPulseLite] loaded");
}

/*
 * ── 附：Frida 验证脚本（确认本 Tweak 行为正确）──────────────────────────────
 *
 *  (1) 确认主 bundle 返回的 bid：
 *      var mb = ObjC.classes.NSBundle.mainBundle();
 *      console.log("[bid] " + mb.bundleIdentifier().toString());
 *      // 期望: com.tencent.xin
 *      // 若为其它值，把上面的 kSpoofedBundleId 改成它。
 *
 *  (2) 抓取微信内部被 hook 的"体验资格"判定 selector（如需更精确对齐）：
 *      var MSHookMessageEx = Module.findExportByName(null, "MSHookMessageEx");
 *      Interceptor.attach(MSHookMessageEx, {
 *        onEnter: function(args) {
 *          var cls = new ObjC.Object(args[0]);
 *          var sel = ObjC.selectorAsString(args[1]);
 *          if (/Private|Internal|Test|Beta|Qualif|Open|Bundle|Identif/i.test(sel)) {
 *            console.log("[hook] class=" + cls.$className + " sel=" + sel);
 *          }
 *        }
 *      });
 */

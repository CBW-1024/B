// ═══════════════════════════════════════════════════════════════════
//  WXBundleIDBypass — 微信多开/分身 bundleId 登录限制绕过
//
//  绕过原理（基于砸壳微信二进制 dump 的类级证据）:
//  ─────────────────────────────────────────────────────────────────
//  微信登录请求会把 bundleId 明文上报服务端:
//
//    WeChat/ManualAuthAesReqData.h   (账密登录请求体)
//        @property NSString *bundleId;
//        - (void)setBundleId:(id)a0;
//        - (id)bundleId;
//
//    WeChat/AutoAuthAesReqData.h     (自动登录请求体)
//        @property NSString *bundleId;
//        - (void)setBundleId:(id)a0;
//        - (id)bundleId;
//
//  构造方（调用链上游）:
//    WeChat/WCAccountManualAuthControlLogic.h
//        - (id)genManualAuthRequest:(BOOL)a0;   -> ManualAuthRequest.aesReqData
//    WeChat/WCAccountAutoLoginControlLogic.h
//        - (id)genAutoAuthRequest:(BOOL)a0;     -> AutoAuthRequest.aesReqData
//
//  证据要点:
//   • setBundleId: 在整份 43394 个头文件的微信 dump 中，
//     「仅」ManualAuthAesReqData 与 AutoAuthAesReqData 两个类声明。
//     -> 这是登录链路上报 bundleId 的唯一入口，hook 点极干净。
//   • 微信 dump 中不存在任何客户端侧 bundleId 校验方法
//     （grep -E "(check|verify|validate).*[Bb]undle" 零命中）。
//     -> 拦截发生在服务端，客户端必须「改上报值」而非「改本地判断」。
//   • BaseRequest.h 不含 bundleId 字段
//     （仅 sessionKey/uin/deviceId/clientVersion/deviceType/scene）。
//     -> 只需改这两个登录请求体，不影响其他业务请求。
//
//  因此: 把上报的 bundleId 强制写成官方 com.tencent.xin，
//        服务端即认为是官方包，放行登录。
// ═══════════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 官方微信 bundleId —— 分身/多开的 bundleId 会被统一伪装成这个
static NSString * const kOfficialBundleID = @"com.tencent.xin";

// 是否开启调试日志（改 1 可在 Xcode/Console 看到上报值变化）
#define WXBID_DEBUG 1

#if WXBID_DEBUG
    #define WXBIDLog(...) NSLog(@"[WXBundleIDBypass] " __VA_ARGS__)
#else
    #define WXBIDLog(...)
#endif

#pragma mark - 账密登录请求体

%hook ManualAuthAesReqData

- (void)setBundleId:(id)bundleId {
    WXBIDLog(@"ManualAuth setBundleId: 原始=%@ -> 伪装=%@", bundleId, kOfficialBundleID);
    %orig(kOfficialBundleID);
}

- (id)bundleId {
    NSString *orig = %orig;
    if (orig && ![orig isEqualToString:kOfficialBundleID]) {
        WXBIDLog(@"ManualAuth bundleId getter: 原始=%@ -> 伪装=%@", orig, kOfficialBundleID);
    }
    return kOfficialBundleID;
}

%end

#pragma mark - 自动登录请求体

%hook AutoAuthAesReqData

- (void)setBundleId:(id)bundleId {
    WXBIDLog(@"AutoAuth setBundleId: 原始=%@ -> 伪装=%@", bundleId, kOfficialBundleID);
    %orig(kOfficialBundleID);
}

- (id)bundleId {
    NSString *orig = %orig;
    if (orig && ![orig isEqualToString:kOfficialBundleID]) {
        WXBIDLog(@"AutoAuth bundleId getter: 原始=%@ -> 伪装=%@", orig, kOfficialBundleID);
    }
    return kOfficialBundleID;
}

%end

#pragma mark - 兜底:构造请求后二次校正
// 部分版本可能绕过 setter 直接给 ivar/属性赋值，
// 这里在请求体生成后做最后一道校正。

%hook WCAccountManualAuthControlLogic

- (id)genManualAuthRequest:(BOOL)a0 {
    id req = %orig;
    @try {
        id aes = [req valueForKey:@"aesReqData"];
        if (aes) {
            NSString *cur = [aes valueForKey:@"bundleId"];
            if (cur && ![cur isEqualToString:kOfficialBundleID]) {
                [aes setValue:kOfficialBundleID forKey:@"bundleId"];
                WXBIDLog(@"ManualAuthRequest 二次校正: %@ -> %@", cur, kOfficialBundleID);
            }
        }
    } @catch (NSException *e) {
        WXBIDLog(@"ManualAuth 二次校正异常: %@", e);
    }
    return req;
}

%end

%hook WCAccountAutoLoginControlLogic

- (id)genAutoAuthRequest:(BOOL)a0 {
    id req = %orig;
    @try {
        id aes = [req valueForKey:@"aesReqData"];
        if (aes) {
            NSString *cur = [aes valueForKey:@"bundleId"];
            if (cur && ![cur isEqualToString:kOfficialBundleID]) {
                [aes setValue:kOfficialBundleID forKey:@"bundleId"];
                WXBIDLog(@"AutoAuthRequest 二次校正: %@ -> %@", cur, kOfficialBundleID);
            }
        }
    } @catch (NSException *e) {
        WXBIDLog(@"AutoAuth 二次校正异常: %@", e);
    }
    return req;
}

%end

%ctor {
    WXBIDLog(@"已注入，当前 bundleId=%@，登录上报将伪装为 %@",
             [[NSBundle mainBundle] bundleIdentifier], kOfficialBundleID);
}

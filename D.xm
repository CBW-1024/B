#import <Foundation/Foundation.h>

#define WC_OFFICIAL_BID @"com.tencent.xin"

static BOOL g_inAuthChain = NO;

%hook NSBundle
- (NSString *)bundleIdentifier {
    if (g_inAuthChain && self == [NSBundle mainBundle]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}
%end

%hook WCAccountManualAuthControlLogic
- (id)genManualAuthRequest:(BOOL)arg {
    g_inAuthChain = YES;
    id r = %orig;
    g_inAuthChain = NO;
    return r;
}
- (id)genManualAuthRequest {
    g_inAuthChain = YES;
    id r = %orig;
    g_inAuthChain = NO;
    return r;
}
%end

%hook WCAccountAutoLoginControlLogic
- (BOOL)startAutoAuth:(id)arg {
    g_inAuthChain = YES;
    BOOL r = %orig;
    g_inAuthChain = NO;
    return r;
}
%end

%hook WCAccountControlMgr
- (void)startManualAuth {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
- (void)startAutoAuth {
    g_inAuthChain = YES;
    %orig;
    g_inAuthChain = NO;
}
%end

%hook ManualAuthAesReqData
- (void)setBundleId:(NSString *)bundleId { %orig(WC_OFFICIAL_BID); }
- (NSString *)bundleId { return WC_OFFICIAL_BID; }
%end

%hook AutoAuthAesReqData
- (void)setBundleId:(NSString *)bundleId { %orig(WC_OFFICIAL_BID); }
- (NSString *)bundleId { return WC_OFFICIAL_BID; }
%end

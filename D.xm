#import <Foundation/Foundation.h>

#define WC_OFFICIAL_BID @"com.tencent.xin"

%hook ManualAuthAesReqData
- (void)setBundleId:(NSString *)bundleId {
    %orig(WC_OFFICIAL_BID);
}
- (NSString *)bundleId {
    return WC_OFFICIAL_BID;
}
%end

%hook AutoAuthAesReqData
- (void)setBundleId:(NSString *)bundleId {
    %orig(WC_OFFICIAL_BID);
}
- (NSString *)bundleId {
    return WC_OFFICIAL_BID;
}
%end

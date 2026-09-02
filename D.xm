#import <Foundation/Foundation.h>

#define WC_OFFICIAL_BID @"com.tencent.xin"

%hook NSBundle

- (NSString *)bundleIdentifier {
    if (self == [NSBundle mainBundle]) {
        return WC_OFFICIAL_BID;
    }
    return %orig;
}

%end

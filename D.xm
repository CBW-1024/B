//
//  拦截 openURL → Safari 跳转
//  规则：afzs.store/about/  +  tlvip.net/mzsm.html
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL BJShouldBlock(NSURL *url) {
    if (!url) return NO;
    NSString *host = url.host ?: @"";
    NSString *path = url.path ?: @"";
    if (path.length > 1 && [path hasSuffix:@"/"])
        path = [path substringToIndex:path.length - 1];

    if ([host caseInsensitiveCompare:@"tlvip.net"] == NSOrderedSame &&
        [path caseInsensitiveCompare:@"/mzsm.html"] == NSOrderedSame) return YES;

    if ([host caseInsensitiveCompare:@"afzs.store"] == NSOrderedSame &&
        [path caseInsensitiveCompare:@"/about"] == NSOrderedSame) return YES;

    return NO;
}

@interface UIApplication (BJ)
- (BOOL)bj_openURL:(NSURL *)url;
- (void)bj_openURL:(NSURL *)url options:(NSDictionary *)options
 completionHandler:(void(^)(BOOL))completion;
@end

@implementation UIApplication (BJ)

- (BOOL)bj_openURL:(NSURL *)url {
    if (BJShouldBlock(url)) return NO;
    return [self bj_openURL:url];
}

- (void)bj_openURL:(NSURL *)url options:(NSDictionary *)options
 completionHandler:(void(^)(BOOL))completion {
    if (BJShouldBlock(url)) {
        if (completion) completion(NO);
        return;
    }
    [self bj_openURL:url options:options completionHandler:completion];
}

@end

static void BJInstall(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class cls = objc_getClass("UIApplication");
        if (!cls) return;

        Method m1 = class_getInstanceMethod(cls, @selector(openURL:));
        Method m2 = class_getInstanceMethod(cls, @selector(bj_openURL:));
        if (m1 && m2) method_exchangeImplementations(m1, m2);

        Method m3 = class_getInstanceMethod(cls, @selector(openURL:options:completionHandler:));
        Method m4 = class_getInstanceMethod(cls, @selector(bj_openURL:options:completionHandler:));
        if (m3 && m4) method_exchangeImplementations(m3, m4);
    });
}

__attribute__((constructor))
static void _BJCtor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BJInstall();
    });
}
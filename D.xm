#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>

static NSString * const kAFKey = @"hidePluginEntryEnable";
static char kAFGestureKey;

@interface WCTableViewSectionManager : NSObject
- (void)addCell:(id)a0;
@end

@interface MMTabBarController : UITabBarController
@end

%hook WCTableViewSectionManager

- (void)addCell:(id)cell {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kAFKey] &&
        [[cell valueForKeyPath:@"cellConfig.leftConfig.title"] isEqualToString:@"插件"]) return;
    %orig;
}

%end

%hook MMTabBarController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *me = [((id (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"getTabBarBtnViews")) lastObject];
    if (!me || objc_getAssociatedObject(me, &kAFGestureKey)) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(af_toggle:)];
    lp.minimumPressDuration = 2.0;
    lp.cancelsTouchesInView = NO;
    [me addGestureRecognizer:lp];
    objc_setAssociatedObject(me, &kAFGestureKey, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)af_toggle:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;

    BOOL on = ![[NSUserDefaults standardUserDefaults] boolForKey:kAFKey];
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:kAFKey];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];

    UIViewController *vc = self.selectedViewController;
    if ([vc isKindOfClass:UINavigationController.class]) vc = [(UINavigationController *)vc topViewController];
    ((void (*)(id, SEL))objc_msgSend)(vc, NSSelectorFromString(@"reloadMoreView"));
}

%end

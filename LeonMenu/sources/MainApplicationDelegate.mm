#import "MainApplicationDelegate.h"
#import "RootViewController.h"

@implementation MainApplicationDelegate {
    RootViewController *_rootViewController;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    _rootViewController = [[RootViewController alloc] init];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = _rootViewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [_rootViewController reloadState];
}

@end

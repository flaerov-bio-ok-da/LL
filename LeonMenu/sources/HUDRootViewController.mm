//
//  HUDRootViewController.mm — floating overlay: mod menu <-> Leon
//

#import <notify.h>
#import <objc/runtime.h>

#import "HUDRootViewController.h"
#import "ModMenuView.h"
#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"

static const CGFloat kLeonSize = 78.0;
static const CGFloat kEdge = 8.0;

@interface HUDRootViewController () <ModMenuViewDelegate>
@end

@implementation HUDRootViewController {
    ModMenuView *_menu;
    UIView *_leon;            // container (handles gestures + bobbing)
    UIImageView *_leonImage;
    BOOL _menuOpen;
    BOOL _animating;
    BOOL _hasMenuPosition;
    CGPoint _menuCenter;
    CGPoint _leonCenter;
    CGPoint _panStart;
    UIInterfaceOrientation _orientation;
    FBSOrientationObserver *_orientationObserver;
    UIImpactFeedbackGenerator *_haptic;
}

- (instancetype)init
{
    if (self = [super init]) {
        _orientation = UIInterfaceOrientationPortrait;
        _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak typeof(self) weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *update) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf updateOrientation:(UIInterfaceOrientation)update.orientation duration:update.duration];
            });
        }];
    }
    return self;
}

- (void)dealloc
{
    [_orientationObserver invalidate];
}

- (void)loadView
{
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.backgroundColor = nil;   // fully transparent: touches outside menu/Leon go to apps below
    v.opaque = NO;
    self.view = v;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Menu
    _menu = [[ModMenuView alloc] initWithFrame:CGRectZero];
    _menu.delegate = self;
    _menu.alpha = 0.0;
    [self.view addSubview:_menu];

    // Leon
    _leon = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kLeonSize, kLeonSize)];
    _leon.backgroundColor = nil;
    _leon.hidden = YES;
    _leonImage = [[UIImageView alloc] initWithFrame:_leon.bounds];
    _leonImage.image = [UIImage imageNamed:@"leon"];
    _leonImage.contentMode = UIViewContentModeScaleAspectFit;
    _leonImage.layer.shadowColor = UIColor.blackColor.CGColor;
    _leonImage.layer.shadowOpacity = 0.35;
    _leonImage.layer.shadowRadius = 6.0;
    _leonImage.layer.shadowOffset = CGSizeMake(0, 3);
    [_leon addSubview:_leonImage];
    [self.view addSubview:_leon];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(leonTapped)];
    [_leon addGestureRecognizer:tap];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leonPanned:)];
    pan.maximumNumberOfTouches = 1;
    [_leon addGestureRecognizer:pan];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    notify_post(NOTIFY_LAUNCHED_HUD);

    if (!_hasMenuPosition) {
        CGRect b = self.view.bounds;
        _menuCenter = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
        _leonCenter = CGPointMake(kEdge + kLeonSize / 2.0, CGRectGetHeight(b) * 0.32);
        _hasMenuPosition = YES;
    }
    if (!_menuOpen) [self presentMenuFromLaunch];
}

#pragma mark - Geometry

- (CGFloat)menuScale
{
    CGSize d = [ModMenuView designSize];
    CGSize b = self.view.bounds.size;
    return MIN(1.0, MIN((b.width - 2 * kEdge) / d.width, (b.height - 2 * kEdge) / d.height));
}

- (CGPoint)clampCenter:(CGPoint)c size:(CGSize)s
{
    CGRect b = self.view.bounds;
    CGFloat hw = s.width / 2.0, hh = s.height / 2.0;
    c.x = MIN(MAX(c.x, hw + kEdge), CGRectGetWidth(b) - hw - kEdge);
    c.y = MIN(MAX(c.y, hh + kEdge), CGRectGetHeight(b) - hh - kEdge);
    return c;
}

- (CGSize)scaledMenuSize
{
    CGSize d = [ModMenuView designSize];
    CGFloat s = [self menuScale];
    return CGSizeMake(d.width * s, d.height * s);
}

#pragma mark - Show / hide

- (void)presentMenuFromLaunch
{
    _menuOpen = YES;
    CGFloat s = [self menuScale];
    _menu.center = [self clampCenter:_menuCenter size:[self scaledMenuSize]];
    _menu.transform = CGAffineTransformMakeScale(s * 0.6, s * 0.6);
    _menu.alpha = 0.0;
    [UIView animateWithDuration:0.55 delay:0.05 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self->_menu.transform = CGAffineTransformMakeScale(s, s);
        self->_menu.alpha = 1.0;
    } completion:nil];
}

- (void)openMenu
{
    if (_menuOpen || _animating) return;
    _menuOpen = YES;
    _animating = YES;
    [_haptic impactOccurred];

    CGFloat s = [self menuScale];
    CGPoint target = [self clampCenter:_menuCenter size:[self scaledMenuSize]];

    [self stopBobbing];
    [UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self->_leon.transform = CGAffineTransformMakeScale(0.4, 0.4);
        self->_leon.alpha = 0.0;
    } completion:^(BOOL finished) {
        self->_leon.hidden = YES;
        self->_leon.transform = CGAffineTransformIdentity;
    }];

    _menu.center = _leon.center;
    _menu.transform = CGAffineTransformMakeScale(s * 0.08, s * 0.08);
    _menu.alpha = 0.0;
    [UIView animateWithDuration:0.5 delay:0.04 usingSpringWithDamping:0.78 initialSpringVelocity:0.4 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self->_menu.center = target;
        self->_menu.transform = CGAffineTransformMakeScale(s, s);
        self->_menu.alpha = 1.0;
    } completion:^(BOOL finished) {
        self->_animating = NO;
    }];
}

- (void)closeMenu
{
    if (!_menuOpen || _animating) return;
    _menuOpen = NO;
    _animating = YES;
    [_haptic impactOccurred];

    _menuCenter = _menu.center;
    CGFloat s = [self menuScale];
    CGPoint leonTarget = [self clampCenter:_leonCenter size:CGSizeMake(kLeonSize, kLeonSize)];

    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self->_menu.center = leonTarget;
        self->_menu.transform = CGAffineTransformMakeScale(s * 0.08, s * 0.08);
        self->_menu.alpha = 0.0;
    } completion:nil];

    _leon.center = leonTarget;
    _leon.hidden = NO;
    _leon.alpha = 0.0;
    _leon.transform = CGAffineTransformMakeScale(0.3, 0.3);
    [UIView animateWithDuration:0.55 delay:0.18 usingSpringWithDamping:0.55 initialSpringVelocity:0.7 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self->_leon.alpha = 1.0;
        self->_leon.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self->_animating = NO;
        [self startBobbing];
    }];
}

- (void)startBobbing
{
    CABasicAnimation *bob = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
    bob.fromValue = @(-2.5);
    bob.toValue = @(2.5);
    bob.duration = 1.4;
    bob.autoreverses = YES;
    bob.repeatCount = HUGE_VALF;
    bob.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_leonImage.layer addAnimation:bob forKey:@"bob"];
}

- (void)stopBobbing
{
    [_leonImage.layer removeAnimationForKey:@"bob"];
}

#pragma mark - Gestures

- (void)modMenuDidRequestClose:(ModMenuView *)menu
{
    [self closeMenu];
}

- (void)modMenu:(ModMenuView *)menu didPan:(UIPanGestureRecognizer *)pan
{
    if (_animating) return;
    CGPoint t = [pan translationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            _panStart = _menu.center;
            [UIView animateWithDuration:0.15 animations:^{ self->_menu.alpha = 0.92; }];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            _menu.center = CGPointMake(_panStart.x + t.x, _panStart.y + t.y);
            break;
        }
        default: {
            CGPoint v = [pan velocityInView:self.view];
            CGPoint p = CGPointMake(_menu.center.x + v.x * 0.08, _menu.center.y + v.y * 0.08);
            CGPoint target = [self clampCenter:p size:[self scaledMenuSize]];
            _menuCenter = target;
            [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.3 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                self->_menu.center = target;
                self->_menu.alpha = 1.0;
            } completion:nil];
            break;
        }
    }
}

- (void)leonTapped
{
    [self openMenu];
}

- (void)leonPanned:(UIPanGestureRecognizer *)pan
{
    if (_animating) return;
    CGPoint t = [pan translationInView:self.view];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            _panStart = _leon.center;
            [self stopBobbing];
            [UIView animateWithDuration:0.2 animations:^{ self->_leon.transform = CGAffineTransformMakeScale(1.12, 1.12); }];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            _leon.center = CGPointMake(_panStart.x + t.x, _panStart.y + t.y);
            break;
        }
        default: {
            // Snap to the nearest side
            CGRect b = self.view.bounds;
            CGPoint v = [pan velocityInView:self.view];
            CGFloat projectedX = _leon.center.x + v.x * 0.1;
            CGFloat x = (projectedX < CGRectGetMidX(b)) ? kEdge + kLeonSize / 2.0 : CGRectGetWidth(b) - kEdge - kLeonSize / 2.0;
            CGPoint target = [self clampCenter:CGPointMake(x, _leon.center.y + v.y * 0.08) size:CGSizeMake(kLeonSize, kLeonSize)];
            _leonCenter = target;
            [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.65 initialSpringVelocity:0.5 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                self->_leon.center = target;
                self->_leon.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                [self startBobbing];
            }];
            break;
        }
    }
}

#pragma mark - Orientation (same approach as TrollSpeed)

static inline CGFloat orientationAngle(UIInterfaceOrientation o)
{
    switch (o) {
        case UIInterfaceOrientationPortraitUpsideDown: return M_PI;
        case UIInterfaceOrientationLandscapeLeft: return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight: return M_PI_2;
        default: return 0;
    }
}

- (void)updateOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
    if (orientation == _orientation || orientation == UIInterfaceOrientationUnknown) return;

    CGSize oldSize = self.view.bounds.size;
    _orientation = orientation;

    CGRect screen = UIScreen.mainScreen.bounds;
    CGRect bounds = UIInterfaceOrientationIsLandscape(orientation)
        ? CGRectMake(0, 0, MAX(screen.size.width, screen.size.height), MIN(screen.size.width, screen.size.height))
        : CGRectMake(0, 0, MIN(screen.size.width, screen.size.height), MAX(screen.size.width, screen.size.height));

    // Keep relative positions
    CGFloat rx = oldSize.width > 0 ? bounds.size.width / oldSize.width : 1;
    CGFloat ry = oldSize.height > 0 ? bounds.size.height / oldSize.height : 1;

    [UIView animateWithDuration:duration * 0.5 animations:^{
        self.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.view.transform = CGAffineTransformIdentity;
        self.view.bounds = bounds;
        self.view.center = CGPointMake(CGRectGetMidX(screen), CGRectGetMidY(screen));
        self.view.transform = CGAffineTransformMakeRotation(orientationAngle(orientation));

        self->_menuCenter = [self clampCenter:CGPointMake(self->_menu.center.x * rx, self->_menu.center.y * ry) size:[self scaledMenuSize]];
        BOOL leftSide = self->_leonCenter.x < oldSize.width / 2.0;
        CGFloat lx = leftSide ? kEdge + kLeonSize / 2.0 : bounds.size.width - kEdge - kLeonSize / 2.0;
        self->_leonCenter = [self clampCenter:CGPointMake(lx, self->_leonCenter.y * ry) size:CGSizeMake(kLeonSize, kLeonSize)];

        CGFloat s = [self menuScale];
        if (self->_menuOpen) {
            self->_menu.transform = CGAffineTransformMakeScale(s, s);
            self->_menu.center = self->_menuCenter;
        } else {
            self->_leon.center = self->_leonCenter;
        }

        [UIView animateWithDuration:0.3 animations:^{
            self.view.alpha = 1.0;
        }];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end

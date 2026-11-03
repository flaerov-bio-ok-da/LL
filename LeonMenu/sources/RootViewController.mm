//
//  RootViewController.mm — the in-app screen: a single START button
//

#import <notify.h>
#import "RootViewController.h"
#import "HUDHelper.h"

#define RGB(r, g, b) [UIColor colorWithRed:(r) / 255.0 green:(g) / 255.0 blue:(b) / 255.0 alpha:1.0]

static UIFont *CourierFont(CGFloat size, BOOL bold)
{
    UIFont *f = [UIFont fontWithName:(bold ? @"CourierNewPS-BoldMT" : @"CourierNewPSMT") size:size];
    return f ?: [UIFont monospacedSystemFontOfSize:size weight:(bold ? UIFontWeightBold : UIFontWeightRegular)];
}

@interface StartButton : UIButton
@end

@implementation StartButton
- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.8
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

@implementation RootViewController {
    StartButton *_button;
    UILabel *_status;
    BOOL _running;
    BOOL _busy;
    UIImpactFeedbackGenerator *_haptic;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.frame = self.view.bounds;
    bg.colors = @[ (id)RGB(36, 24, 24).CGColor, (id)RGB(14, 10, 12).CGColor ];
    [self.view.layer addSublayer:bg];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"Legit Cheat | TenrySoft";
    title.font = CourierFont(20, NO);
    title.textColor = RGB(112, 208, 100);
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    _button = [StartButton buttonWithType:UIButtonTypeCustom];
    _button.translatesAutoresizingMaskIntoConstraints = NO;
    _button.titleLabel.font = CourierFont(30, YES);
    _button.layer.cornerRadius = 22;
    _button.layer.borderWidth = 3;
    _button.layer.shadowOpacity = 0.6;
    _button.layer.shadowRadius = 16;
    _button.layer.shadowOffset = CGSizeZero;
    [_button addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_button];

    _status = [[UILabel alloc] init];
    _status.font = CourierFont(13, NO);
    _status.textColor = RGB(135, 128, 128);
    _status.textAlignment = NSTextAlignmentCenter;
    _status.numberOfLines = 0;
    _status.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_status];

    [NSLayoutConstraint activateConstraints:@[
        [_button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_button.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_button.widthAnchor constraintEqualToConstant:220],
        [_button.heightAnchor constraintEqualToConstant:76],
        [title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [title.bottomAnchor constraintEqualToAnchor:_button.topAnchor constant:-48],
        [_status.topAnchor constraintEqualToAnchor:_button.bottomAnchor constant:28],
        [_status.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:32],
        [_status.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-32],
    ]];

    [self applyRunning:NO animated:NO];
    [self startPulse];
}

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

- (void)startPulse
{
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    pulse.fromValue = @8;
    pulse.toValue = @22;
    pulse.duration = 1.2;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_button.layer addAnimation:pulse forKey:@"pulse"];
}

- (void)applyRunning:(BOOL)running animated:(BOOL)animated
{
    _running = running;
    UIColor *c = running ? RGB(220, 70, 70) : RGB(112, 208, 100);
    void (^apply)(void) = ^{
        [self->_button setTitle:(running ? @"STOP" : @"START") forState:UIControlStateNormal];
        [self->_button setTitleColor:c forState:UIControlStateNormal];
        self->_button.backgroundColor = [c colorWithAlphaComponent:0.12];
        self->_button.layer.borderColor = c.CGColor;
        self->_button.layer.shadowColor = c.CGColor;
        self->_status.text = running
            ? @"Menu is running on top of everything.\nOpen any game - tap Leon to open the menu."
            : @"Tap START to launch the floating menu.";
    };
    if (animated) {
        [UIView transitionWithView:self.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:apply completion:nil];
    } else {
        apply();
    }
}

- (void)reloadState
{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL on = IsHUDEnabled();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self->_busy) [self applyRunning:on animated:YES];
        });
    });
}

- (void)tapped
{
    if (_busy) return;
    _busy = YES;
    _button.enabled = NO;
    [_haptic impactOccurred];

    BOOL enable = !_running;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (enable) {
            dispatch_semaphore_t sem = dispatch_semaphore_create(0);
            int token;
            notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &token, dispatch_get_main_queue(), ^(int t) {
                notify_cancel(t);
                dispatch_semaphore_signal(sem);
            });
            SetHUDEnabled(YES);
            dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
        } else {
            SetHUDEnabled(NO);
        }
        BOOL on = IsHUDEnabled();
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_busy = NO;
            self->_button.enabled = YES;
            [self applyRunning:on animated:YES];
            if (enable && !on) {
                self->_status.text = @"Could not start the overlay.\nInstall the app with TrollStore.";
            }
        });
    });
}

@end

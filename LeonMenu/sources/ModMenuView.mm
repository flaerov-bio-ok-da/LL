#import "ModMenuView.h"

#define RGB(r, g, b) [UIColor colorWithRed:(r) / 255.0 green:(g) / 255.0 blue:(b) / 255.0 alpha:1.0]

static UIFont *MenuFont(CGFloat size, BOOL bold)
{
    UIFont *font = [UIFont fontWithName:(bold ? @"CourierNewPS-BoldMT" : @"CourierNewPSMT") size:size];
    if (!font) font = [UIFont monospacedSystemFontOfSize:size weight:(bold ? UIFontWeightBold : UIFontWeightRegular)];
    return font;
}

// Geometry measured from the reference screenshot
static const CGFloat kMenuW = 400.0, kMenuH = 280.0;
static const CGFloat kBorderX = 3.0, kBorderY = 2.0;
static const CGFloat kInnerW = kMenuW - 2 * kBorderX;   // 394
static const CGFloat kInnerH = kMenuH - 2 * kBorderY;   // 276
static const CGFloat kHeaderH = 60.0;
static const CGFloat kFooterH = 10.0;
static const CGFloat kTabX = 49.0, kTabY = 31.0, kTabW = 296.0, kTabH = 20.0;
static const CGFloat kRowTop = 31.0, kRowStep = 32.0, kBox = 17.0;

#pragma mark - Checkbox row

@interface MMCheckRow : UIView
@property (nonatomic, assign, getter=isOn) BOOL on;
@property (nonatomic, copy) void (^onToggle)(BOOL on);
- (instancetype)initWithTitle:(NSString *)title on:(BOOL)on;
@end

@implementation MMCheckRow {
    UIView *_box;
    CAShapeLayer *_check;
    UILabel *_label;
}

- (instancetype)initWithTitle:(NSString *)title on:(BOOL)on
{
    if (self = [super initWithFrame:CGRectMake(0, 0, 128, kRowStep)]) {
        _box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kBox, kBox)];
        _box.layer.borderWidth = 2.0;
        _box.layer.cornerRadius = 2.5;
        [self addSubview:_box];

        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(3.5, 8.8)];
        [path addLineToPoint:CGPointMake(7.0, 12.2)];
        [path addLineToPoint:CGPointMake(13.6, 4.6)];
        _check = [CAShapeLayer layer];
        _check.frame = _box.bounds;
        _check.path = path.CGPath;
        _check.fillColor = UIColor.clearColor.CGColor;
        _check.strokeColor = RGB(112, 208, 100).CGColor;
        _check.lineWidth = 2.4;
        _check.lineCap = kCALineCapRound;
        _check.lineJoin = kCALineJoinRound;
        [_box.layer addSublayer:_check];

        _label = [[UILabel alloc] initWithFrame:CGRectMake(24, 0, 104, 34)];
        _label.text = title;
        _label.font = MenuFont(13, YES);
        _label.textColor = UIColor.whiteColor;
        _label.numberOfLines = 2;
        _label.lineBreakMode = NSLineBreakByWordWrapping;
        _label.adjustsFontSizeToFitWidth = YES;
        _label.minimumScaleFactor = 0.8;
        [self addSubview:_label];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
        [self addGestureRecognizer:tap];

        _on = on;
        [self applyState:NO];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize fit = [_label sizeThatFits:CGSizeMake(104, 40)];
    CGFloat h = MIN(MAX(fit.height, kBox), 34);
    _label.frame = CGRectMake(24, kBox / 2.0 - h / 2.0, 104, h);
}

- (void)applyState:(BOOL)animated
{
    UIColor *border = _on ? RGB(112, 208, 100) : RGB(44, 48, 52);
    UIColor *fill = _on ? [RGB(36, 24, 24) colorWithAlphaComponent:0.55] : UIColor.clearColor;

    if (animated) {
        CABasicAnimation *stroke = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
        stroke.fromValue = @(_on ? 0.0 : 1.0);
        stroke.toValue = @(_on ? 1.0 : 0.0);
        stroke.duration = 0.18;
        stroke.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [_check addAnimation:stroke forKey:@"stroke"];

        [UIView animateWithDuration:0.12 animations:^{
            self->_box.transform = CGAffineTransformMakeScale(0.82, 0.82);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.45 initialSpringVelocity:0.8 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                self->_box.transform = CGAffineTransformIdentity;
            } completion:nil];
        }];
        [UIView animateWithDuration:0.18 animations:^{
            self->_box.backgroundColor = fill;
        }];
        CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:@"borderColor"];
        b.fromValue = (__bridge id)_box.layer.borderColor;
        b.toValue = (__bridge id)border.CGColor;
        b.duration = 0.18;
        [_box.layer addAnimation:b forKey:@"border"];
    } else {
        _box.backgroundColor = fill;
    }
    _box.layer.borderColor = border.CGColor;
    _check.strokeEnd = _on ? 1.0 : 0.0;
}

- (void)tapped
{
    _on = !_on;
    [self applyState:YES];
    static UIImpactFeedbackGenerator *haptic;
    if (!haptic) haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];
    if (_onToggle) _onToggle(_on);
}

@end

#pragma mark - Menu

@implementation ModMenuView {
    UIView *_inner;
    UIView *_header;
    UIView *_tabBar;
    UIView *_pill;
    NSArray<UILabel *> *_tabLabels;
    UIScrollView *_body;
    UIView *_grid;
    UILabel *_premiumLabel;
    NSInteger _selectedTab;
    NSArray<NSArray<NSString *> *> *_tabItems;
    NSMutableSet<NSString *> *_enabled;
}

+ (CGSize)designSize { return CGSizeMake(kMenuW, kMenuH); }

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:CGRectMake(0, 0, kMenuW, kMenuH)]) {
        _enabled = [NSMutableSet set];
        _tabItems = @[
            @[ @"Custom Nick", @"Gloves", @"Mass Kill",
               @"Custom ID", @"Custom Medal", @"Tele Kill",
               @"Custom Clan", @"Head Aim", @"Bunny Hop",
               @"God Mode", @"Body Aim", @"Gravity Hack",
               @"Always Respawn", @"Can Kick", @"Jump Hack",
               @"Radar Hack", @"Drop Knife", @"Fire Rite" ],
            @[ @"No Recoil", @"Infinite Ammo", @"Rapid Fire",
               @"No Spread", @"One Shot", @"Fast Reload",
               @"Auto Shoot", @"Wall Shot", @"Silent Aim",
               @"Big Bullets", @"No Reload", @"Knife Range",
               @"Skin Changer", @"Fast Switch", @"Laser Sight" ],
            @[ @"Speed Hack", @"Fly Hack", @"No Clip",
               @"Unlock All", @"Free Shop", @"Anti Ban",
               @"Fake Lag", @"Ghost Mode", @"Auto Win",
               @"Fast Respawn", @"Hide Name", @"FPS Boost" ],
            @[ @"ESP Box", @"ESP Line", @"ESP Name",
               @"ESP Health", @"ESP Distance", @"Chams",
               @"Wallhack", @"No Fog", @"No Flash",
               @"Crosshair", @"FOV Circle", @"Night Mode",
               @"Big Heads", @"Show Radar", @"Rainbow UI" ],
        ];

        self.backgroundColor = RGB(198, 212, 226);     // light steel border
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 10.0;
        self.layer.shadowOffset = CGSizeMake(0, 4);

        _inner = [[UIView alloc] initWithFrame:CGRectMake(kBorderX, kBorderY, kInnerW, kInnerH)];
        _inner.clipsToBounds = YES;
        _inner.backgroundColor = RGB(125, 129, 130);
        [self addSubview:_inner];

        [self buildBody];
        [self buildHeader];
        [self buildFooter];
        [self reloadGridAnimated:NO];
    }
    return self;
}

- (void)buildHeader
{
    _header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kInnerW, kHeaderH)];
    _header.backgroundColor = RGB(36, 24, 24);
    [_inner addSubview:_header];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, kInnerW, 22)];
    title.text = @"Legit Cheat | TenrySoft";
    title.textAlignment = NSTextAlignmentCenter;
    title.font = MenuFont(15, YES);
    title.textColor = RGB(112, 208, 100);
    [_header addSubview:title];

    UILabel *close = [[UILabel alloc] initWithFrame:CGRectMake(kInnerW - 26, 2, 24, 24)];
    close.text = @"×";
    close.textAlignment = NSTextAlignmentCenter;
    close.font = MenuFont(18, YES);
    close.textColor = RGB(120, 100, 100);
    close.userInteractionEnabled = YES;
    [close addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTapped)]];
    [_header addSubview:close];

    _tabBar = [[UIView alloc] initWithFrame:CGRectMake(kTabX, kTabY, kTabW, kTabH)];
    _tabBar.backgroundColor = RGB(39, 22, 30);
    _tabBar.layer.cornerRadius = kTabH / 2.0;
    _tabBar.layer.borderWidth = 2.0;
    _tabBar.layer.borderColor = RGB(61, 42, 70).CGColor;
    [_header addSubview:_tabBar];

    CGFloat segW = kTabW / 4.0;
    _pill = [[UIView alloc] initWithFrame:CGRectMake(3, 3, segW - 2, kTabH - 6)];
    _pill.backgroundColor = RGB(203, 208, 204);
    _pill.layer.cornerRadius = (kTabH - 6) / 2.0;
    [_tabBar addSubview:_pill];

    NSMutableArray *labels = [NSMutableArray array];
    NSArray *names = @[ @"Player", @"Weapon", @"Other", @"Visuals" ];
    for (NSInteger i = 0; i < 4; i++) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(segW * i, 0, segW, kTabH)];
        l.text = names[i];
        l.textAlignment = NSTextAlignmentCenter;
        l.font = MenuFont(10, NO);
        l.textColor = (i == 0) ? RGB(70, 70, 70) : RGB(135, 128, 128);
        l.tag = i;
        l.userInteractionEnabled = YES;
        [l addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tabTapped:)]];
        [_tabBar addSubview:l];
        [labels addObject:l];
    }
    _tabLabels = labels;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    pan.maximumNumberOfTouches = 1;
    [_header addGestureRecognizer:pan];
}

- (void)buildBody
{
    _body = [[UIScrollView alloc] initWithFrame:CGRectMake(0, kHeaderH, kInnerW, kInnerH - kHeaderH - kFooterH)];
    _body.backgroundColor = RGB(125, 129, 130);
    _body.showsVerticalScrollIndicator = NO;
    _body.alwaysBounceVertical = YES;
    _body.clipsToBounds = YES;
    [_inner addSubview:_body];

    // Sits slightly under the header, exactly like the screenshot
    _premiumLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, -6, kInnerW - 19, 24)];
    _premiumLabel.text = @"Premium Mod Menu 0.17.4";
    _premiumLabel.textAlignment = NSTextAlignmentRight;
    _premiumLabel.font = MenuFont(18, YES);
    _premiumLabel.textColor = UIColor.whiteColor;
    [_body addSubview:_premiumLabel];
}

- (void)buildFooter
{
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, kInnerH - kFooterH, kInnerW, kFooterH)];
    footer.backgroundColor = RGB(33, 24, 23);
    footer.clipsToBounds = YES;
    [_inner addSubview:footer];

    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, -1, kInnerW, 12)];
    l.text = @"Download Free Version https:/TenryOffChanell";
    l.textAlignment = NSTextAlignmentCenter;
    l.font = MenuFont(10, NO);
    l.textColor = RGB(22, 140, 46);
    [footer addSubview:l];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    pan.maximumNumberOfTouches = 1;
    [footer addGestureRecognizer:pan];
}

- (void)reloadGridAnimated:(BOOL)animated
{
    UIView *old = _grid;
    NSArray<NSString *> *items = _tabItems[_selectedTab];
    NSInteger rows = (items.count + 2) / 3;
    CGFloat contentH = kRowTop + rows * kRowStep + 4;

    UIView *grid = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kInnerW, contentH)];
    const CGFloat colX[3] = { 7.0, 138.0, 270.0 };
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        NSString *key = [NSString stringWithFormat:@"%ld/%@", (long)_selectedTab, items[i]];
        MMCheckRow *row = [[MMCheckRow alloc] initWithTitle:items[i] on:[_enabled containsObject:key]];
        row.frame = CGRectMake(colX[i % 3], kRowTop + (i / 3) * kRowStep, 128, kRowStep);
        row.onToggle = ^(BOOL on) {
            __strong typeof(weakSelf) s = weakSelf;
            if (!s) return;
            if (on) [s->_enabled addObject:key]; else [s->_enabled removeObject:key];
        };
        [grid addSubview:row];
    }
    _grid = grid;
    [_body insertSubview:grid belowSubview:_premiumLabel];
    _body.contentSize = CGSizeMake(kInnerW, MAX(contentH, _body.bounds.size.height + 1));
    [_body setContentOffset:CGPointZero animated:animated];

    if (animated) {
        grid.alpha = 0.0;
        grid.transform = CGAffineTransformMakeTranslation(0, 10);
        [UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            grid.alpha = 1.0;
            grid.transform = CGAffineTransformIdentity;
            old.alpha = 0.0;
        } completion:^(BOOL finished) {
            [old removeFromSuperview];
        }];
    } else {
        [old removeFromSuperview];
    }
}

- (void)tabTapped:(UITapGestureRecognizer *)tap
{
    NSInteger idx = tap.view.tag;
    if (idx == _selectedTab) return;
    _selectedTab = idx;

    CGFloat segW = kTabW / 4.0;
    CGRect target = CGRectMake(segW * idx + (idx == 3 ? -1 : (idx == 0 ? 3 : 1)), 3, segW - 2, kTabH - 6);
    [UIView animateWithDuration:0.42 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.6 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self->_pill.frame = target;
    } completion:nil];

    for (UILabel *l in _tabLabels) {
        UIColor *c = (l.tag == idx) ? RGB(70, 70, 70) : RGB(135, 128, 128);
        [UIView transitionWithView:l duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            l.textColor = c;
        } completion:nil];
    }

    static UISelectionFeedbackGenerator *sel;
    if (!sel) sel = [[UISelectionFeedbackGenerator alloc] init];
    [sel selectionChanged];

    [self reloadGridAnimated:YES];
}

- (void)closeTapped
{
    [self.delegate modMenuDidRequestClose:self];
}

- (void)panned:(UIPanGestureRecognizer *)pan
{
    [self.delegate modMenu:self didPan:pan];
}

@end

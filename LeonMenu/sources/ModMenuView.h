#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class ModMenuView;

@protocol ModMenuViewDelegate <NSObject>
- (void)modMenuDidRequestClose:(ModMenuView *)menu;
- (void)modMenu:(ModMenuView *)menu didPan:(UIPanGestureRecognizer *)pan;
@end

/// 1:1 copy of the "Legit Cheat | TenrySoft" menu. Designed at 400x280 pt.
@interface ModMenuView : UIView
@property (nonatomic, weak) id<ModMenuViewDelegate> delegate;
+ (CGSize)designSize;
@end

NS_ASSUME_NONNULL_END

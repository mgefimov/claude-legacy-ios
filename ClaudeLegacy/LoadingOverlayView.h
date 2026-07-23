//
//  LoadingOverlayView.h
//  ClaudeLegacy
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Full screen overlay shown while claude.ai is being fetched and transpiled.
/// Reports the current stage plus the file that is being processed right now.
@interface LoadingOverlayView : UIView

/// Current stage, e.g. "Compiling modules · 12/48".
- (void)setStage:(NSString *)stage detail:(nullable NSString *)detail;

/// Progress in 0...1. Never moves backwards.
- (void)setProgress:(float)progress animated:(BOOL)animated;

/// Replaces the progress UI with a message and a tappable button.
- (void)showMessage:(NSString *)message buttonTitle:(NSString *)title handler:(void (^)(void))handler;

/// Puts the overlay back into the loading state after -showMessage:...
- (void)resetToLoading;

/// Fades out and removes itself from the view hierarchy.
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END

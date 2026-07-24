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

/// Build fingerprint of the loaded site, shown under the app version once known.
/// claude.ai exposes no version number, so this is the hash from its entry chunk.
- (void)setSiteBuild:(nullable NSString *)build;

/// Replaces the progress UI with an error, the raw failure text and two actions.
/// `details` is meant for console-style output (JS exceptions, network errors).
- (void)showErrorWithMessage:(NSString *)message
                     details:(nullable NSString *)details
                retryHandler:(void (^)(void))retryHandler
             continueHandler:(void (^)(void))continueHandler;

/// Puts the overlay back into the loading state after -showErrorWithMessage:...
- (void)resetToLoading;

/// Fades out and removes itself from the view hierarchy.
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END

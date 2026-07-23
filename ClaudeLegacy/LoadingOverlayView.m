//
//  LoadingOverlayView.m
//  ClaudeLegacy
//

#import "LoadingOverlayView.h"

@interface LoadingOverlayView ()

@property (nonatomic, strong) UIStackView *stack;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *stageLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UILabel *errorDetailsLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *continueButton;
@property (nonatomic, copy, nullable) void (^retryHandler)(void);
@property (nonatomic, copy, nullable) void (^continueHandler)(void);

@end

@implementation LoadingOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUp];
    }
    return self;
}

- (void)setUp {
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithRed:31/255.0 green:31/255.0 blue:30/255.0 alpha:1.0]   // #1f1f1e
        : [UIColor colorWithRed:0xF8/255.0 green:0xF7/255.0 blue:0xF3/255.0 alpha:1.0];  // #F8F7F3
    }];

    UIColor *accent = [UIColor colorWithRed:0xD9/255.0 green:0x77/255.0 blue:0x57/255.0 alpha:1.0]; // #D97757

    _iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LargeIcon"]];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.hidden = (_iconView.image == nil);
    [_iconView.heightAnchor constraintEqualToConstant:96].active = YES;

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.text = @"Claude Legacy";
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _progressView.progressTintColor = accent;
    _progressView.progress = 0;

    _stageLabel = [[UILabel alloc] init];
    _stageLabel.font = [UIFont systemFontOfSize:13];
    _stageLabel.textColor = UIColor.secondaryLabelColor;
    _stageLabel.textAlignment = NSTextAlignmentCenter;
    _stageLabel.numberOfLines = 2;

    _detailLabel = [[UILabel alloc] init];
    _detailLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _detailLabel.textColor = UIColor.tertiaryLabelColor;
    _detailLabel.textAlignment = NSTextAlignmentCenter;
    _detailLabel.numberOfLines = 1;
    _detailLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    _messageLabel = [[UILabel alloc] init];
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.textColor = UIColor.labelColor;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 0;
    _messageLabel.hidden = YES;

    _errorDetailsLabel = [[UILabel alloc] init];
    _errorDetailsLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _errorDetailsLabel.textColor = UIColor.secondaryLabelColor;
    _errorDetailsLabel.textAlignment = NSTextAlignmentCenter;
    _errorDetailsLabel.numberOfLines = 6;
    _errorDetailsLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _errorDetailsLabel.hidden = YES;

    _retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _retryButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [_retryButton setTitle:@"Reload" forState:UIControlStateNormal];
    [_retryButton setTitleColor:accent forState:UIControlStateNormal];
    [_retryButton addTarget:self action:@selector(handleRetry) forControlEvents:UIControlEventTouchUpInside];
    _retryButton.hidden = YES;

    _continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _continueButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [_continueButton setTitle:@"Continue anyway" forState:UIControlStateNormal];
    [_continueButton setTitleColor:UIColor.secondaryLabelColor forState:UIControlStateNormal];
    [_continueButton addTarget:self action:@selector(handleContinue) forControlEvents:UIControlEventTouchUpInside];
    _continueButton.hidden = YES;

    _stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView,
                                                             _titleLabel,
                                                             _progressView,
                                                             _stageLabel,
                                                             _detailLabel,
                                                             _messageLabel,
                                                             _errorDetailsLabel,
                                                             _retryButton,
                                                             _continueButton]];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.alignment = UIStackViewAlignmentFill;
    _stack.spacing = 8;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_stack setCustomSpacing:20 afterView:_iconView];
    [_stack setCustomSpacing:20 afterView:_titleLabel];
    [_stack setCustomSpacing:14 afterView:_progressView];
    [_stack setCustomSpacing:10 afterView:_messageLabel];
    [_stack setCustomSpacing:20 afterView:_errorDetailsLabel];
    [self addSubview:_stack];

    // Beats the labels' compression resistance (750) so long text wraps inside
    // the fixed width instead of stretching the stack and truncating.
    NSLayoutConstraint *width = [_stack.widthAnchor constraintEqualToConstant:280];
    width.priority = UILayoutPriorityRequired - 1;

    [NSLayoutConstraint activateConstraints:@[
        [_stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-20],
        width,
        [_stack.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-48],
    ]];
}

- (void)setStage:(NSString *)stage detail:(NSString *)detail {
    _stageLabel.text = stage;
    _detailLabel.text = detail.length > 0 ? detail : @" ";
}

- (void)setProgress:(float)progress animated:(BOOL)animated {
    float clamped = MAX(0.0f, MIN(1.0f, progress));
    if (clamped <= _progressView.progress) {
        return; // progress is monotonic, otherwise the bar looks broken
    }
    [_progressView setProgress:clamped animated:animated];
}

- (void)showErrorWithMessage:(NSString *)message
                     details:(NSString *)details
                retryHandler:(void (^)(void))retryHandler
             continueHandler:(void (^)(void))continueHandler {
    self.retryHandler = retryHandler;
    self.continueHandler = continueHandler;

    _titleLabel.text = @"Something went wrong";
    _messageLabel.text = message;
    _messageLabel.hidden = NO;
    _errorDetailsLabel.text = details;
    _errorDetailsLabel.hidden = (details.length == 0);
    _retryButton.hidden = NO;
    _continueButton.hidden = NO;
    _progressView.hidden = YES;
    _stageLabel.hidden = YES;
    _detailLabel.hidden = YES;
}

- (void)resetToLoading {
    self.retryHandler = nil;
    self.continueHandler = nil;
    _titleLabel.text = @"Claude Legacy";
    _messageLabel.hidden = YES;
    _errorDetailsLabel.hidden = YES;
    _retryButton.hidden = YES;
    _continueButton.hidden = YES;
    _progressView.hidden = NO;
    _stageLabel.hidden = NO;
    _detailLabel.hidden = NO;
    _progressView.progress = 0;
}

- (void)handleRetry {
    void (^handler)(void) = self.retryHandler;
    if (handler) {
        handler();
    }
}

- (void)handleContinue {
    void (^handler)(void) = self.continueHandler;
    if (handler) {
        handler();
    }
}

- (void)dismiss {
    if (self.superview == nil) {
        return;
    }
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

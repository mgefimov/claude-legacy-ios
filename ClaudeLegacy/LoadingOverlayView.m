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
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy, nullable) void (^actionHandler)(void);

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
    _messageLabel.font = [UIFont systemFontOfSize:13];
    _messageLabel.textColor = UIColor.secondaryLabelColor;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.numberOfLines = 0;
    _messageLabel.hidden = YES;

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [_actionButton setTitleColor:accent forState:UIControlStateNormal];
    [_actionButton addTarget:self action:@selector(handleAction) forControlEvents:UIControlEventTouchUpInside];
    _actionButton.hidden = YES;

    _stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView,
                                                             _titleLabel,
                                                             _progressView,
                                                             _stageLabel,
                                                             _detailLabel,
                                                             _messageLabel,
                                                             _actionButton]];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.alignment = UIStackViewAlignmentFill;
    _stack.spacing = 8;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_stack setCustomSpacing:20 afterView:_iconView];
    [_stack setCustomSpacing:20 afterView:_titleLabel];
    [_stack setCustomSpacing:14 afterView:_progressView];
    [_stack setCustomSpacing:16 afterView:_messageLabel];
    [self addSubview:_stack];

    NSLayoutConstraint *width = [_stack.widthAnchor constraintEqualToConstant:280];
    width.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [_stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-20],
        width,
        [_stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:24],
        [_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-24],
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

- (void)showMessage:(NSString *)message buttonTitle:(NSString *)title handler:(void (^)(void))handler {
    self.actionHandler = handler;
    _messageLabel.text = message;
    _messageLabel.hidden = NO;
    [_actionButton setTitle:title forState:UIControlStateNormal];
    _actionButton.hidden = NO;
    _progressView.hidden = YES;
    _stageLabel.hidden = YES;
    _detailLabel.hidden = YES;
}

- (void)resetToLoading {
    self.actionHandler = nil;
    _messageLabel.hidden = YES;
    _actionButton.hidden = YES;
    _progressView.hidden = NO;
    _stageLabel.hidden = NO;
    _detailLabel.hidden = NO;
    _progressView.progress = 0;
}

- (void)handleAction {
    void (^handler)(void) = self.actionHandler;
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

//
//  ViewController.m
//  ClaudePatcher
//
//  Created by Efimov.mg on 23/2/2026.
//
#import <objc/runtime.h>
#import "ViewController.h"
#import "PolyfillsLoader.h"
#import "LoadingOverlayView.h"

#import <WebKit/WebKit.h>

/// Number of modules the previous successful launch had to transpile — used to
/// turn the module counter into a real percentage on every launch but the first.
static NSString *const kModuleCountKey = @"LastModuleCount";

/// Seconds without any module activity before the page is assumed to be ready.
static const NSTimeInterval kSettleAfterReadySignal = 0.3;
static const NSTimeInterval kSettleWithoutReadySignal = 6.0;
/// Hard stop: never keep the overlay up longer than this.
static const NSTimeInterval kLoadingTimeout = 60.0;

@interface ViewController () <WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic) IBOutlet WKWebView *webView;

@property (nonatomic, strong) LoadingOverlayView *loadingOverlay;
@property (nonatomic, strong) NSTimer *settleTimer;
@property (nonatomic, strong) NSDate *lastActivity;
@property (nonatomic, strong) NSDate *loadingStartedAt;
@property (nonatomic, assign) NSInteger modulesDone;
@property (nonatomic, assign) NSInteger modulesExpected;
@property (nonatomic, assign) NSInteger pendingScripts;
@property (nonatomic, assign) BOOL pageReady;
@property (nonatomic, assign) BOOL navigationFinished;
@property (nonatomic, copy, nullable) NSString *lastErrorMessage;
@property (nonatomic, assign) NSInteger errorCount;

@end

@implementation ViewController

/// Injects a bundled .js file as a document-start user script, in the order added.
- (void)injectScriptNamed:(NSString *)name {
    NSURL *scriptURL = [NSBundle.mainBundle URLForResource:name withExtension:@"js"];
    NSString *js = scriptURL
        ? [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:nil]
        : nil;
    if (js.length == 0) {
        NSLog(@"[inject] %@.js is missing from the bundle", name);
        return;
    }

    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:js
                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                  forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:userScript];
}

- (void)injectIOSVersion {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *versionString = [NSString stringWithFormat:@"%ld.%ld",
                               (long)version.majorVersion,
                               (long)version.minorVersion];
    
    NSString *js = [NSString stringWithFormat:
                    @"window.iosVersion = %@;",
                    [self jsStringLiteral:versionString]];
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:script];
}

/// Rewrites CSS that newer WebKit parses natively but older versions silently
/// drop. Each fix is paired with the iOS version that made it unnecessary, so a
/// system new enough gets nothing injected at all — not even the pipeline.
- (void)injectCSSCompatibilityFixes {
    // @{script, major, minor} — the version is the one where WebKit gained the
    // feature. Order is preserved: it becomes the order of the CSS transforms.
    NSArray<NSArray *> *fixes = @[
        @[@"css-layer-flatten",  @15, @4], // @layer, Safari 15.4
        @[@"css-viewport-units", @15, @4], // dvh/svh/lvh units, Safari 15.4
    ];

    NSMutableArray<NSString *> *needed = [NSMutableArray array];
    for (NSArray *fix in fixes) {
        if (![PolyfillsLoader isIOSVersionOrNewer:[fix[1] integerValue]
                                            minor:[fix[2] integerValue]]) {
            [needed addObject:fix[0]];
        }
    }

    if (needed.count == 0) {
        return; // nothing to patch on this system
    }

    [self injectScriptNamed:@"css-compat"]; // the pipeline the fixes register into
    for (NSString *name in needed) {
        [self injectScriptNamed:name];
    }
    NSLog(@"[inject] CSS fixes: %@", [needed componentsJoinedByString:@", "]);
}

- (void)injectCustomCSS {
    NSString *css = @"button[data-testid='login-with-google'] { display: none !important; }"
    "button[data-testid='login-with-google'] + p { display: none !important; }";
    NSString *js = [NSString stringWithFormat:
                    @"(function(){"
                    "var s=document.createElement('style');"
                    "s.textContent=%@;"
                    "document.head.appendChild(s);"
                    "})()", [self jsStringLiteral:css]];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                               forMainFrameOnly:YES];
    [_webView.configuration.userContentController addUserScript:script];
}

- (NSString *)jsStringLiteral:(NSString *)str {
    NSString *escaped = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithRed:31/255.0 green:31/255.0 blue:30/255.0 alpha:1.0]   // #1f1f1e
        : [UIColor colorWithRed:0xF8/255.0 green:0xF7/255.0 blue:0xF3/255.0 alpha:1.0];  // #F8F7F3
    }];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    _webView.scrollView.refreshControl = refreshControl;

    _webView.opaque = NO;
    _webView.backgroundColor = UIColor.clearColor;
    _webView.navigationDelegate = self;
    _webView.scrollView.scrollEnabled = YES;

    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"patchScript"];
    [self.webView.configuration.userContentController addScriptMessageHandler:self name:@"loadingStatus"];

    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:0 context:NULL];

    [self showLoadingOverlay];

    // Injecting the polyfills reads a few hundred files off disk, so give the
    // overlay a chance to reach the screen before blocking the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startLoading];
    });
}

- (void)dealloc {
    [_settleTimer invalidate];
    [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

- (void)startLoading {
    [self.loadingOverlay setStage:@"Preparing compatibility layer" detail:nil];

    [self injectIOSVersion];
    [self injectCustomCSS];
    [self injectScriptNamed:@"legacy-transpiler"];
    [self injectScriptNamed:@"patch"];
    [self injectCSSCompatibilityFixes];
    [PolyfillsLoader injectPolyfillsIntoController:_webView.configuration.userContentController];

    [self.loadingOverlay setProgress:0.05 animated:YES];
    [self.loadingOverlay setStage:@"Connecting to claude.ai" detail:nil];

    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
//    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://192.168.1.136:3000"]]];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    [_webView reload];
}

#pragma mark - Loading overlay

- (void)showLoadingOverlay {
    if (self.loadingOverlay.superview != nil) {
        return;
    }

    LoadingOverlayView *overlay = [[LoadingOverlayView alloc] initWithFrame:self.view.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:overlay];
    self.loadingOverlay = overlay;

    [overlay setStage:@"Starting" detail:nil];

    self.modulesExpected = [[NSUserDefaults standardUserDefaults] integerForKey:kModuleCountKey];
    [self resetLoadingProgress];
}

- (void)resetLoadingProgress {
    self.modulesDone = 0;
    self.pendingScripts = 0;
    self.pageReady = NO;
    self.navigationFinished = NO;
    self.lastActivity = [NSDate date];
    self.loadingStartedAt = [NSDate date];

    [self.settleTimer invalidate];
    self.settleTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                        target:self
                                                      selector:@selector(checkIfSettled)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (BOOL)isLoadingOverlayVisible {
    return self.loadingOverlay.superview != nil;
}

- (void)noteActivity {
    self.lastActivity = [NSDate date];
}

/// Dismisses the overlay once module activity has stopped, or after a hard timeout.
- (void)checkIfSettled {
    if (![self isLoadingOverlayVisible]) {
        [self.settleTimer invalidate];
        self.settleTimer = nil;
        return;
    }

    if ([[NSDate date] timeIntervalSinceDate:self.loadingStartedAt] > kLoadingTimeout) {
        NSLog(@"[loading] timed out after %.0fs", kLoadingTimeout);
        if (self.pageReady) {
            [self finishLoading];
        } else {
            [self showFailure:@"Claude is taking longer than expected to load."
                      details:[self errorDetails]];
        }
        return;
    }

    if (self.pendingScripts > 0) {
        return;
    }

    NSTimeInterval idle = [[NSDate date] timeIntervalSinceDate:self.lastActivity];
    if (self.pageReady) {
        if (idle >= kSettleAfterReadySignal) {
            [self finishLoading];
        }
        return;
    }

    // No ready signal from the page: wait until the navigation itself finished
    // and nothing has been transpiled for a while, then decide whether the page
    // simply had nothing to transpile or actually failed.
    if (!self.navigationFinished || idle < kSettleWithoutReadySignal) {
        return;
    }

    if (self.lastErrorMessage != nil) {
        [self showFailure:@"Claude could not be started on this iOS version."
                  details:[self errorDetails]];
    } else if (self.modulesDone == 0) {
        [self showFailure:@"The page loaded but no application code was executed."
                  details:@"No script was intercepted by the transpiler."];
    } else {
        [self finishLoading];
    }
}

- (void)finishLoading {
    [self.settleTimer invalidate];
    self.settleTimer = nil;

    if (self.modulesDone > 0) {
        [[NSUserDefaults standardUserDefaults] setInteger:self.modulesDone forKey:kModuleCountKey];
    }

    [self.loadingOverlay setStage:@"Ready" detail:nil];
    [self.loadingOverlay setProgress:1.0 animated:YES];
    [self.loadingOverlay dismiss];
}

- (void)updateModuleProgress {
    if (![self isLoadingOverlayVisible]) {
        return;
    }

    float progress;
    if (self.modulesExpected > 0) {
        float ratio = MIN(1.0f, (float)self.modulesDone / (float)self.modulesExpected);
        progress = 0.28f + 0.67f * ratio;
    } else {
        // First launch: no estimate of the module count, approach 0.88 asymptotically.
        progress = 0.28f + 0.6f * (1.0f - expf(-(float)self.modulesDone / 30.0f));
    }
    [self.loadingOverlay setProgress:progress animated:YES];
}

- (NSString *)moduleStageText {
    if (self.modulesExpected > 0) {
        return [NSString stringWithFormat:@"Compiling modules · %ld/%ld",
                (long)MIN(self.modulesDone, self.modulesExpected), (long)self.modulesExpected];
    }
    if (self.modulesDone > 0) {
        return [NSString stringWithFormat:@"Compiling modules · %ld", (long)self.modulesDone];
    }
    return @"Compiling modules";
}

/// Turns the overlay into an error screen. Keeps the overlay up on purpose: a
/// failed load leaves a blank web view behind, which tells the user nothing.
- (void)showFailure:(NSString *)message details:(NSString *)details {
    if (![self isLoadingOverlayVisible]) {
        return;
    }

    NSLog(@"[loading] failed: %@ (%@)", message, details);

    [self.settleTimer invalidate];
    self.settleTimer = nil;

    __weak typeof(self) weakSelf = self;
    [self.loadingOverlay showErrorWithMessage:message details:details retryHandler:^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf.loadingOverlay resetToLoading];
        [strongSelf.loadingOverlay setStage:@"Connecting to claude.ai" detail:nil];
        strongSelf.lastErrorMessage = nil;
        [strongSelf resetLoadingProgress];
        [strongSelf.webView reload];
    } continueHandler:^{
        typeof(self) strongSelf = weakSelf;
        [strongSelf.loadingOverlay dismiss];
    }];
}

- (void)showFailureForError:(NSError *)error {
    NSString *details = error.userInfo[@"WKJavaScriptExceptionMessage"] ?: error.localizedDescription;
    [self showFailure:@"Could not load claude.ai." details:details];
}

/// Remembers the first failure seen while loading; -checkIfSettled decides
/// whether it actually kept the page from starting.
- (void)recordErrorMessage:(NSString *)message {
    if (message.length == 0 || self.pageReady) {
        return;
    }
    NSLog(@"[loading] error while loading: %@", message);
    self.errorCount += 1;
    if (self.lastErrorMessage == nil) {
        self.lastErrorMessage = message;
    }
}

/// First error plus how many followed it — the rest are usually the same cause.
- (NSString *)errorDetails {
    if (self.lastErrorMessage == nil) {
        return nil;
    }
    if (self.errorCount > 1) {
        return [NSString stringWithFormat:@"%@\n\n+ %ld more error(s)",
                self.lastErrorMessage, (long)(self.errorCount - 1)];
    }
    return self.lastErrorMessage;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
    if (![keyPath isEqualToString:@"estimatedProgress"]) {
        return;
    }
    if (![self isLoadingOverlayVisible] || self.modulesDone > 0) {
        return;
    }
    // The page fetch itself only accounts for the first quarter of the bar.
    [self.loadingOverlay setProgress:0.05f + 0.20f * self.webView.estimatedProgress animated:YES];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if ([self isLoadingOverlayVisible]) {
        [self.loadingOverlay setStage:@"Connecting to claude.ai" detail:webView.URL.host];
        [self noteActivity];
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    if ([self isLoadingOverlayVisible] && self.modulesDone == 0) {
        [self.loadingOverlay setStage:@"Loading page" detail:webView.URL.path];
        [self noteActivity];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [webView.scrollView.refreshControl endRefreshing];

    self.navigationFinished = YES;
    if ([self isLoadingOverlayVisible] && self.modulesDone == 0) {
        [self.loadingOverlay setStage:@"Starting Claude" detail:nil];
        [self.loadingOverlay setProgress:0.28 animated:YES];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [webView.scrollView.refreshControl endRefreshing];
    if (error.code != NSURLErrorCancelled) {
        [self showFailureForError:error];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [webView.scrollView.refreshControl endRefreshing];
    if (error.code != NSURLErrorCancelled) {
        [self showFailureForError:error];
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [webView.scrollView.refreshControl endRefreshing];
    [self showLoadingOverlay];
    [self showFailure:@"The web process stopped — the device may have run out of memory."
              details:nil];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:@"loadingStatus"]) {
        [self handleLoadingStatus:message.body];
        return;
    }

    if (![message.name isEqualToString:@"patchScript"]) {
        return;
    }

    NSString *code = message.body;
    NSString *file = nil;
    if ([message.body isKindOfClass:NSDictionary.class]) {
        code = message.body[@"code"];
        file = message.body[@"file"];
    }
    if (![code isKindOfClass:NSString.class]) {
        return;
    }

    [self noteActivity];
    if ([self isLoadingOverlayVisible]) {
        self.pendingScripts += 1;
        [self.loadingOverlay setStage:[self moduleStageText] detail:file];
    }

    NSString *wrapped = [NSString stringWithFormat:@"%@\n;'ok'", code];

    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:wrapped completionHandler:^(id res, NSError *err) {
        if (err) {
            NSLog(@"[evaluateJavaScript]: fail %@", code);
        } else {
            NSLog(@"[evaluateJavaScript]: success"); // always return a serializable value
        }

        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (err) {
            NSString *reason = err.userInfo[@"WKJavaScriptExceptionMessage"] ?: err.localizedDescription;
            [strongSelf recordErrorMessage:[NSString stringWithFormat:@"%@: %@", file ?: @"module", reason]];
        }
        [strongSelf noteActivity];
        strongSelf.modulesDone += 1;
        if ([strongSelf isLoadingOverlayVisible]) {
            strongSelf.pendingScripts = MAX(0, strongSelf.pendingScripts - 1);
            [strongSelf.loadingOverlay setStage:[strongSelf moduleStageText] detail:file];
            [strongSelf updateModuleProgress];
        }
    }];
}

- (void)handleLoadingStatus:(id)body {
    if (![body isKindOfClass:NSDictionary.class] || ![self isLoadingOverlayVisible]) {
        return;
    }

    NSString *stage = body[@"stage"];
    NSString *file = body[@"file"];

    if ([stage isEqualToString:@"boot"]) {
        [self noteActivity];
        [self.loadingOverlay setStage:@"Patching JavaScript engine" detail:nil];
    } else if ([stage isEqualToString:@"download"]) {
        [self noteActivity];
        [self.loadingOverlay setStage:self.modulesDone > 0 ? [self moduleStageText] : @"Downloading modules"
                              detail:file];
    } else if ([stage isEqualToString:@"ready"]) {
        self.pageReady = YES;
    } else if ([stage isEqualToString:@"error"]) {
        NSString *jsMessage = [body[@"message"] isKindOfClass:NSString.class] ? body[@"message"] : @"Unknown JavaScript error";
        [self recordErrorMessage:jsMessage];
        if ([body[@"fatal"] boolValue]) {
            [self showFailure:@"Claude could not be started on this iOS version."
                      details:jsMessage];
        }
    }
}

@end

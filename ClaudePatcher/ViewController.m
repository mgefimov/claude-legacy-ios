//
//  ViewController.m
//  ClaudePatcher
//
//  Created by Efimov.mg on 23/2/2026.
//

#import "ViewController.h"

#import <WebKit/WebKit.h>

@interface ViewController () <WKNavigationDelegate, WKScriptMessageHandler>

@property (nonatomic) IBOutlet WKWebView *webView;

@end

@implementation ViewController

- (void) injectPatch {
    NSBundle *extensionBundle = [NSBundle bundleWithURL:[NSBundle.mainBundle URLForResource:@"ClaudePatcher Extension" withExtension:@"appex" subdirectory:@"PlugIns"]];
    NSURL *scriptURL = [extensionBundle URLForResource:@"content" withExtension:@"js"];

    NSString *js = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:nil];
    if (js) {
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
        [_webView.configuration.userContentController addUserScript:userScript];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:0x26/255.0 green:0x26/255.0 blue:0x24/255.0 alpha:1.0]   // #262624
            : [UIColor colorWithRed:0xF8/255.0 green:0xF7/255.0 blue:0xF3/255.0 alpha:1.0];  // #F8F7F3
    }];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    _webView.scrollView.refreshControl = refreshControl;

    _webView.opaque = NO;
    _webView.backgroundColor = UIColor.clearColor;
    _webView.navigationDelegate = self;
    _webView.scrollView.scrollEnabled = YES;

    [_webView.configuration.userContentController addScriptMessageHandler:self name:@"controller"];

    [self injectPatch];

    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleDefault;
}

- (void)handleRefresh:(UIRefreshControl *)refreshControl {
    [_webView reload];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [webView.scrollView.refreshControl endRefreshing];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    // Override point for customization.
}

@end

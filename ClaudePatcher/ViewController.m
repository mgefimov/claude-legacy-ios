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

- (void)viewDidLoad {
    [super viewDidLoad];

    _webView.navigationDelegate = self;
    _webView.scrollView.scrollEnabled = NO;

    [_webView.configuration.userContentController addScriptMessageHandler:self name:@"controller"];

    [_webView loadFileURL:[NSBundle.mainBundle URLForResource:@"Main" withExtension:@"html"] allowingReadAccessToURL:NSBundle.mainBundle.resourceURL];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Override point for customization.
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    // Override point for customization.
}

@end

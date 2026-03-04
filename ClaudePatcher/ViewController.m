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

    _webView.navigationDelegate = self;
    _webView.scrollView.scrollEnabled = YES;

    [_webView.configuration.userContentController addScriptMessageHandler:self name:@"controller"];

    [self injectPatch];

    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // Override point for customization.
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    // Override point for customization.
}

@end

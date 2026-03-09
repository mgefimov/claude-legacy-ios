// Based on https://github.com/PoomSmart/Polyfills/blob/main/Tweak.x

#import <WebKit/WebKit.h>

@interface PolyfillsLoader : NSObject

+ (void)injectPolyfillsIntoController:(WKUserContentController *)controller;

@end

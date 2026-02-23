//
//  SafariWebExtensionHandler.m
//  ClaudePatcher Extension
//
//  Created by Efimov.mg on 23/2/2026.
//

#import "SafariWebExtensionHandler.h"

#import <SafariServices/SafariServices.h>

@implementation SafariWebExtensionHandler

- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {
    NSExtensionItem *request = context.inputItems.firstObject;

    NSUUID *profile;
    if (@available(iOS 17.0, macOS 14.0, *)) {
        profile = request.userInfo[SFExtensionProfileKey];
    } else {
        profile = request.userInfo[@"profile"];
    }

    id message;
    if (@available(iOS 15.0, macOS 11.0, *)) {
        message = request.userInfo[SFExtensionMessageKey];
    } else {
        message = request.userInfo[@"message"];
    }

    NSLog(@"Received message from browser.runtime.sendNativeMessage: %@ (profile: %@)", message, profile.UUIDString ?: @"none");

    NSExtensionItem *response = [[NSExtensionItem alloc] init];
    if (@available(iOS 15.0, macOS 11.0, *)) {
        response.userInfo = @{ SFExtensionMessageKey: @{ @"echo": message } };
    } else {
        response.userInfo = @{ @"message": @{ @"echo": message } };
    }

    [context completeRequestReturningItems:@[ response ] completionHandler:nil];
}

@end

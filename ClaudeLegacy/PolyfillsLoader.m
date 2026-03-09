#import "PolyfillsLoader.h"

@implementation PolyfillsLoader

+ (BOOL)isIOSVersionOrNewer:(NSInteger)major minor:(NSInteger)minor {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion > major) return YES;
    if (version.majorVersion == major && version.minorVersion >= minor) return YES;
    return NO;
}

+ (NSString *)loadJSFromFile:(NSString *)filePath {
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return nil;
    }
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"PolyfillsLoader: Error reading JS file %@: %@", filePath, error.localizedDescription);
        return nil;
    }
    return content;
}

+ (NSString *)loadJSFromDirectory:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directoryPath]) {
        return @"";
    }

    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    if (error) {
        return @"";
    }

    NSArray *jsFiles = [[files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'js'"]]
                        sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    NSMutableString *combinedScript = [NSMutableString string];
    for (NSString *fileName in jsFiles) {
        NSString *filePath = [directoryPath stringByAppendingPathComponent:fileName];
        NSString *content = [self loadJSFromFile:filePath];
        if (!content) continue;
        if ([fileName isEqualToString:@"Navigator.hardwareConcurrency.js"]) {
            NSInteger coreCount = [[NSProcessInfo processInfo] processorCount];
            NSInteger clamped = (coreCount <= 2) ? 2 : (coreCount <= 4) ? 4 : (coreCount <= 6) ? 6 : 8;
            NSString *js = [NSString stringWithFormat:@"window.__injectedHardwareConcurrency__ = %ld;\n", (long)clamped];
            content = [js stringByAppendingString:content];
        }
        [combinedScript appendString:content];
        [combinedScript appendString:@"\n"];
    }
    return [combinedScript copy];
}

+ (NSString *)loadScriptsFromDirectory:(NSString *)fullBasePath {
    NSMutableString *combinedScripts = [NSMutableString string];

    // Load base scripts (always included)
    NSString *baseScriptsPath = [fullBasePath stringByAppendingPathComponent:@"base"];
    NSString *baseScripts = [self loadJSFromDirectory:baseScriptsPath];
    if (baseScripts.length > 0) {
        [combinedScripts appendString:baseScripts];
        [combinedScripts appendString:@"\n"];
    }

    // Discover version directories
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *allItems = [fileManager contentsOfDirectoryAtPath:fullBasePath error:&error];
    if (error) return [combinedScripts copy];

    NSMutableArray *versionDirs = [NSMutableArray array];
    NSRegularExpression *versionRegex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+\\.\\d+$" options:0 error:nil];

    for (NSString *item in allItems) {
        NSString *itemPath = [fullBasePath stringByAppendingPathComponent:item];
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory] && isDirectory) {
            if ([versionRegex numberOfMatchesInString:item options:0 range:NSMakeRange(0, item.length)] > 0) {
                [versionDirs addObject:item];
            }
        }
    }

    // Sort version directories in ascending order
    [versionDirs sortUsingComparator:^NSComparisonResult(NSString *v1, NSString *v2) {
        NSArray *c1 = [v1 componentsSeparatedByString:@"."];
        NSArray *c2 = [v2 componentsSeparatedByString:@"."];
        NSInteger major1 = [c1[0] integerValue], major2 = [c2[0] integerValue];
        if (major1 != major2) return major1 < major2 ? NSOrderedAscending : NSOrderedDescending;
        NSInteger minor1 = c1.count > 1 ? [c1[1] integerValue] : 0;
        NSInteger minor2 = c2.count > 1 ? [c2[1] integerValue] : 0;
        if (minor1 != minor2) return minor1 < minor2 ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];

    // Load scripts from version directories where current iOS is older
    for (NSString *versionStr in versionDirs) {
        NSArray *components = [versionStr componentsSeparatedByString:@"."];
        NSInteger vMajor = [components[0] integerValue];
        NSInteger vMinor = components.count > 1 ? [components[1] integerValue] : 0;

        if ([self isIOSVersionOrNewer:vMajor minor:vMinor]) continue;

        NSString *versionPath = [fullBasePath stringByAppendingPathComponent:versionStr];
        NSString *versionScripts = [self loadJSFromDirectory:versionPath];
        if (versionScripts.length > 0) {
            [combinedScripts appendString:versionScripts];
            [combinedScripts appendString:@"\n"];
        }
    }

    return [combinedScripts copy];
}

+ (void)injectPolyfillsIntoController:(WKUserContentController *)controller {
    NSString *basePath = [[NSBundle mainBundle] pathForResource:@"Polyfills" ofType:nil];
    if (!basePath) {
        NSLog(@"PolyfillsLoader: Polyfills directory not found in bundle");
        return;
    }

    NSMutableString *startScripts = [NSMutableString string];
    NSMutableString *endScripts = [NSMutableString string];

    // Priority scripts (document start, loaded first)
    NSString *priorityPath = [basePath stringByAppendingPathComponent:@"scripts-priority"];
    NSString *priority = [self loadScriptsFromDirectory:priorityPath];
    if (priority.length > 0) {
        [startScripts appendString:priority];
        [startScripts appendString:@"\n"];
    }

    // Main scripts (document start)
    NSString *scriptsPath = [basePath stringByAppendingPathComponent:@"scripts"];
    NSString *main = [self loadScriptsFromDirectory:scriptsPath];
    if (main.length > 0) {
        [startScripts appendString:main];
        [startScripts appendString:@"\n"];
    }

    // Post scripts (document end)
    NSString *postPath = [basePath stringByAppendingPathComponent:@"scripts-post"];
    NSString *post = [self loadScriptsFromDirectory:postPath];
    if (post.length > 0) {
        [endScripts appendString:post];
    }

    if (startScripts.length > 0) {
        WKUserScript *script = [[WKUserScript alloc] initWithSource:[startScripts copy]
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                    forMainFrameOnly:NO];
        [controller addUserScript:script];
        NSLog(@"PolyfillsLoader: Injected start scripts (%lu chars)", (unsigned long)startScripts.length);
    }

    if (endScripts.length > 0) {
        WKUserScript *script = [[WKUserScript alloc] initWithSource:[endScripts copy]
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                    forMainFrameOnly:NO];
        [controller addUserScript:script];
        NSLog(@"PolyfillsLoader: Injected end scripts (%lu chars)", (unsigned long)endScripts.length);
    }
}

@end

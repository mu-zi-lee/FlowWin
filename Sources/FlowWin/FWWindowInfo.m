#import "FWWindowInfo.h"

@implementation FWWindowInfo
- (NSString *)displayName {
    if (self.title.length == 0) {
        return self.ownerName ?: @"未知窗口";
    }
    return [NSString stringWithFormat:@"%@ - %@", self.ownerName ?: @"未知 App", self.title];
}
@end

@implementation FWWindowLister
+ (NSArray<FWWindowInfo *> *)windowsMatchingOwnerPID:(pid_t)targetPID {
    CFArrayRef windowArray = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    if (!windowArray) {
        return @[];
    }

    NSArray *windows = CFBridgingRelease(windowArray);
    NSMutableArray<FWWindowInfo *> *results = [NSMutableArray array];
    pid_t currentPID = [[NSProcessInfo processInfo] processIdentifier];

    for (NSDictionary *dictionary in windows) {
        NSNumber *windowNumber = dictionary[(id)kCGWindowNumber];
        NSNumber *ownerPIDNumber = dictionary[(id)kCGWindowOwnerPID];
        NSString *ownerName = dictionary[(id)kCGWindowOwnerName];
        NSNumber *layerNumber = dictionary[(id)kCGWindowLayer];
        NSDictionary *boundsDictionary = dictionary[(id)kCGWindowBounds];

        if (!windowNumber || !ownerPIDNumber || !ownerName || !layerNumber || !boundsDictionary) {
            continue;
        }

        if (layerNumber.integerValue != 0) {
            continue;
        }

        pid_t ownerPID = ownerPIDNumber.intValue;
        if (ownerPID == currentPID) {
            continue;
        }
        if (targetPID > 0 && ownerPID != targetPID) {
            continue;
        }

        CGRect bounds = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDictionary, &bounds)) {
            continue;
        }

        if (bounds.size.width < 80 || bounds.size.height < 60) {
            continue;
        }

        NSNumber *alphaNumber = dictionary[(id)kCGWindowAlpha];
        if (alphaNumber && alphaNumber.doubleValue <= 0) {
            continue;
        }

        FWWindowInfo *info = [FWWindowInfo new];
        info.windowID = (CGWindowID)windowNumber.unsignedIntValue;
        info.ownerPID = ownerPID;
        info.ownerName = ownerName;
        info.title = dictionary[(id)kCGWindowName] ?: @"";
        info.quartzBounds = bounds;
        [results addObject:info];
    }

    return results;
}

+ (NSArray<FWWindowInfo *> *)allWindows {
    NSMutableArray<FWWindowInfo *> *results = [[self windowsMatchingOwnerPID:0] mutableCopy];
    [results sortUsingComparator:^NSComparisonResult(FWWindowInfo *left, FWWindowInfo *right) {
        return [left.displayName localizedCaseInsensitiveCompare:right.displayName];
    }];
    return results;
}

+ (FWWindowInfo *)windowWithID:(CGWindowID)windowID {
    CFArrayRef windowArray = CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, windowID);
    if (!windowArray) {
        return nil;
    }

    NSArray *windows = CFBridgingRelease(windowArray);
    for (NSDictionary *dictionary in windows) {
        NSNumber *windowNumber = dictionary[(id)kCGWindowNumber];
        if (!windowNumber || windowNumber.unsignedIntValue != windowID) {
            continue;
        }

        NSNumber *ownerPIDNumber = dictionary[(id)kCGWindowOwnerPID];
        NSString *ownerName = dictionary[(id)kCGWindowOwnerName];
        NSDictionary *boundsDictionary = dictionary[(id)kCGWindowBounds];
        if (!ownerPIDNumber || !ownerName || !boundsDictionary) {
            continue;
        }

        CGRect bounds = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDictionary, &bounds)) {
            continue;
        }

        FWWindowInfo *info = [FWWindowInfo new];
        info.windowID = windowID;
        info.ownerPID = ownerPIDNumber.intValue;
        info.ownerName = ownerName;
        info.title = dictionary[(id)kCGWindowName] ?: @"";
        info.quartzBounds = bounds;
        return info;
    }
    return nil;
}

+ (FWWindowInfo *)frontmostWindowForPID:(pid_t)pid {
    if (pid <= 0) {
        return nil;
    }
    return [self windowsMatchingOwnerPID:pid].firstObject;
}
@end

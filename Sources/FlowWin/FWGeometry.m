#import "FWGeometry.h"

NSRect FWCocoaFrameFromQuartzBounds(CGRect quartzBounds) {
    CGPoint center = CGPointMake(CGRectGetMidX(quartzBounds), CGRectGetMidY(quartzBounds));

    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
        if (!screenNumber) {
            continue;
        }

        CGDirectDisplayID displayID = screenNumber.unsignedIntValue;
        CGRect displayBounds = CGDisplayBounds(displayID);
        if (!CGRectContainsPoint(displayBounds, center)) {
            continue;
        }

        CGFloat localX = CGRectGetMinX(quartzBounds) - CGRectGetMinX(displayBounds);
        CGFloat localYFromTop = CGRectGetMinY(quartzBounds) - CGRectGetMinY(displayBounds);
        return NSMakeRect(
            screen.frame.origin.x + localX,
            NSMaxY(screen.frame) - localYFromTop - quartzBounds.size.height,
            quartzBounds.size.width,
            quartzBounds.size.height
        );
    }

    CGFloat mainHeight = CGDisplayBounds(CGMainDisplayID()).size.height;
    return NSMakeRect(
        quartzBounds.origin.x,
        mainHeight - quartzBounds.origin.y - quartzBounds.size.height,
        quartzBounds.size.width,
        quartzBounds.size.height
    );
}

CGRect FWQuartzBoundsFromCocoaFrame(NSRect cocoaFrame) {
    CGPoint center = CGPointMake(NSMidX(cocoaFrame), NSMidY(cocoaFrame));

    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
        if (!screenNumber) {
            continue;
        }

        CGDirectDisplayID displayID = screenNumber.unsignedIntValue;
        if (!NSPointInRect(center, screen.frame)) {
            continue;
        }

        CGRect displayBounds = CGDisplayBounds(displayID);
        CGFloat localX = NSMinX(cocoaFrame) - NSMinX(screen.frame);
        CGFloat localYFromTop = NSMaxY(screen.frame) - NSMaxY(cocoaFrame);
        return CGRectMake(CGRectGetMinX(displayBounds) + localX,
                          CGRectGetMinY(displayBounds) + localYFromTop,
                          NSWidth(cocoaFrame),
                          NSHeight(cocoaFrame));
    }

    CGFloat mainHeight = CGDisplayBounds(CGMainDisplayID()).size.height;
    return CGRectMake(NSMinX(cocoaFrame),
                      mainHeight - NSMaxY(cocoaFrame),
                      NSWidth(cocoaFrame),
                      NSHeight(cocoaFrame));
}

CGRect FWActiveDisplayQuartzUnion(void) {
    uint32_t displayCount = 0;
    if (CGGetActiveDisplayList(0, NULL, &displayCount) != kCGErrorSuccess || displayCount == 0) {
        return CGDisplayBounds(CGMainDisplayID());
    }

    CGDirectDisplayID *displays = calloc(displayCount, sizeof(CGDirectDisplayID));
    if (!displays) {
        return CGDisplayBounds(CGMainDisplayID());
    }

    CGRect unionBounds = CGRectNull;
    if (CGGetActiveDisplayList(displayCount, displays, &displayCount) == kCGErrorSuccess) {
        for (uint32_t index = 0; index < displayCount; index++) {
            unionBounds = CGRectIsNull(unionBounds)
                ? CGDisplayBounds(displays[index])
                : CGRectUnion(unionBounds, CGDisplayBounds(displays[index]));
        }
    }
    free(displays);

    return CGRectIsNull(unionBounds) ? CGDisplayBounds(CGMainDisplayID()) : unionBounds;
}

CGPoint FWParkingPositionForSourceBounds(CGRect sourceBounds) {
    CGRect displayBounds = FWActiveDisplayQuartzUnion();
    return CGPointMake(CGRectGetMaxX(displayBounds) + FWSourceWindowParkingMargin,
                       MAX(CGRectGetMinY(displayBounds), CGRectGetMinY(sourceBounds)));
}

CGFloat FWDisplayIntersectionArea(CGRect bounds) {
    if (CGRectIsEmpty(bounds)) {
        return 0;
    }

    uint32_t displayCount = 0;
    if (CGGetActiveDisplayList(0, NULL, &displayCount) != kCGErrorSuccess || displayCount == 0) {
        CGRect intersection = CGRectIntersection(bounds, CGDisplayBounds(CGMainDisplayID()));
        return CGRectIsNull(intersection) || CGRectIsEmpty(intersection)
            ? 0
            : CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    }

    CGDirectDisplayID *displays = calloc(displayCount, sizeof(CGDirectDisplayID));
    if (!displays) {
        CGRect intersection = CGRectIntersection(bounds, CGDisplayBounds(CGMainDisplayID()));
        return CGRectIsNull(intersection) || CGRectIsEmpty(intersection)
            ? 0
            : CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
    }

    CGFloat visibleArea = 0;
    if (CGGetActiveDisplayList(displayCount, displays, &displayCount) == kCGErrorSuccess) {
        for (uint32_t index = 0; index < displayCount; index++) {
            CGRect intersection = CGRectIntersection(bounds, CGDisplayBounds(displays[index]));
            if (!CGRectIsNull(intersection) && !CGRectIsEmpty(intersection)) {
                visibleArea += CGRectGetWidth(intersection) * CGRectGetHeight(intersection);
            }
        }
    }
    free(displays);
    return visibleArea;
}

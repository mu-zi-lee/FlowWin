#import "FWAccessibility.h"
#import "FWGeometry.h"

BOOL FWAccessibilityTrusted(BOOL prompt) {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @(prompt)};
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

BOOL FWAXCopyCGPointAttribute(AXUIElementRef element, CFStringRef attribute, CGPoint *point) {
    if (!element || !point) {
        return NO;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || !value) {
        return NO;
    }

    BOOL ok = CFGetTypeID(value) == AXValueGetTypeID() &&
              AXValueGetType((AXValueRef)value) == kAXValueCGPointType &&
              AXValueGetValue((AXValueRef)value, kAXValueCGPointType, point);
    CFRelease(value);
    return ok;
}

BOOL FWAXCopyCGSizeAttribute(AXUIElementRef element, CFStringRef attribute, CGSize *size) {
    if (!element || !size) {
        return NO;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || !value) {
        return NO;
    }

    BOOL ok = CFGetTypeID(value) == AXValueGetTypeID() &&
              AXValueGetType((AXValueRef)value) == kAXValueCGSizeType &&
              AXValueGetValue((AXValueRef)value, kAXValueCGSizeType, size);
    CFRelease(value);
    return ok;
}

BOOL FWAXSetCGPointAttribute(AXUIElementRef element, CFStringRef attribute, CGPoint point) {
    if (!element) {
        return NO;
    }

    AXValueRef value = AXValueCreate(kAXValueCGPointType, &point);
    if (!value) {
        return NO;
    }

    AXError error = AXUIElementSetAttributeValue(element, attribute, value);
    CFRelease(value);
    return error == kAXErrorSuccess;
}

BOOL FWAXSetCGSizeAttribute(AXUIElementRef element, CFStringRef attribute, CGSize size) {
    if (!element) {
        return NO;
    }

    AXValueRef value = AXValueCreate(kAXValueCGSizeType, &size);
    if (!value) {
        return NO;
    }

    AXError error = AXUIElementSetAttributeValue(element, attribute, value);
    CFRelease(value);
    return error == kAXErrorSuccess;
}

BOOL FWAXElementSupportsAction(AXUIElementRef element, CFStringRef action) {
    if (!element || !action) {
        return NO;
    }

    CFArrayRef actions = NULL;
    AXError error = AXUIElementCopyActionNames(element, &actions);
    if (error != kAXErrorSuccess || !actions) {
        return NO;
    }

    BOOL supportsAction = CFArrayContainsValue(actions,
                                              CFRangeMake(0, CFArrayGetCount(actions)),
                                              action);
    CFRelease(actions);
    return supportsAction;
}

AXUIElementRef FWCopyAXElementAtPoint(pid_t ownerPID, CGPoint point) {
    AXUIElementRef application = AXUIElementCreateApplication(ownerPID);
    if (!application) {
        return NULL;
    }

    AXUIElementRef element = NULL;
    AXError error = AXUIElementCopyElementAtPosition(application, point.x, point.y, &element);
    CFRelease(application);
    if (error != kAXErrorSuccess || !element) {
        return NULL;
    }

    return element;
}

NSString *FWAXCopyStringAttribute(AXUIElementRef element, CFStringRef attribute) {
    if (!element || !attribute) {
        return nil;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || !value) {
        return nil;
    }

    NSString *string = CFGetTypeID(value) == CFStringGetTypeID() ? [(__bridge NSString *)value copy] : nil;
    CFRelease(value);
    return string;
}

BOOL FWAXSetBoolAttribute(AXUIElementRef element, CFStringRef attribute, BOOL boolValue) {
    if (!element || !attribute) {
        return NO;
    }

    CFBooleanRef value = boolValue ? kCFBooleanTrue : kCFBooleanFalse;
    return AXUIElementSetAttributeValue(element, attribute, value) == kAXErrorSuccess;
}

BOOL FWAXRoleIsTextInput(NSString *role) {
    return [role isEqualToString:@"AXTextField"] ||
           [role isEqualToString:@"AXTextArea"] ||
           [role isEqualToString:@"AXComboBox"] ||
           [role isEqualToString:@"AXSearchField"];
}

AXUIElementRef FWAXCopyParentElement(AXUIElementRef element) {
    if (!element) {
        return NULL;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, kAXParentAttribute, &value);
    if (error != kAXErrorSuccess || !value) {
        return NULL;
    }

    if (CFGetTypeID(value) != AXUIElementGetTypeID()) {
        CFRelease(value);
        return NULL;
    }

    return (AXUIElementRef)value;
}

BOOL FWAXFocusElementIfEditable(AXUIElementRef element) {
    NSString *role = FWAXCopyStringAttribute(element, kAXRoleAttribute);
    if (!FWAXRoleIsTextInput(role)) {
        return NO;
    }

    return FWAXSetBoolAttribute(element, kAXFocusedAttribute, YES);
}

BOOL FWAXPressElementAtPoint(pid_t ownerPID, CGPoint point) {
    AXUIElementRef element = FWCopyAXElementAtPoint(ownerPID, point);
    if (!element) {
        return NO;
    }

    BOOL pressed = NO;
    AXUIElementRef current = element;
    for (NSUInteger depth = 0; current && depth < 5 && !pressed; depth++) {
        if (FWAXElementSupportsAction(current, kAXPressAction)) {
            pressed = AXUIElementPerformAction(current, kAXPressAction) == kAXErrorSuccess;
        } else {
            pressed = FWAXFocusElementIfEditable(current);
        }

        if (!pressed) {
            AXUIElementRef parent = FWAXCopyParentElement(current);
            if (current != element) {
                CFRelease(current);
            }
            current = parent;
        }
    }
    if (current && current != element) {
        CFRelease(current);
    }
    CFRelease(element);
    return pressed;
}

BOOL FWAXScrollElementAtPoint(pid_t ownerPID, CGPoint point, CGFloat deltaY, CGFloat deltaX) {
    AXUIElementRef element = FWCopyAXElementAtPoint(ownerPID, point);
    if (!element) {
        return NO;
    }

    CFStringRef verticalAction = deltaY > 0 ? CFSTR("AXScrollUp") : CFSTR("AXScrollDown");
    CFStringRef horizontalAction = deltaX > 0 ? CFSTR("AXScrollLeft") : CFSTR("AXScrollRight");
    BOOL scrolled = NO;
    AXUIElementRef current = element;
    for (NSUInteger depth = 0; current && depth < 6 && !scrolled; depth++) {
        if (fabs(deltaY) >= fabs(deltaX) && fabs(deltaY) >= 0.01 && FWAXElementSupportsAction(current, verticalAction)) {
            scrolled = AXUIElementPerformAction(current, verticalAction) == kAXErrorSuccess;
        } else if (fabs(deltaX) >= 0.01 && FWAXElementSupportsAction(current, horizontalAction)) {
            scrolled = AXUIElementPerformAction(current, horizontalAction) == kAXErrorSuccess;
        }

        if (!scrolled) {
            AXUIElementRef parent = FWAXCopyParentElement(current);
            if (current != element) {
                CFRelease(current);
            }
            current = parent;
        }
    }
    if (current && current != element) {
        CFRelease(current);
    }

    CFRelease(element);
    return scrolled;
}

BOOL FWAXWindowMatchesWindowID(AXUIElementRef window, CGWindowID windowID) {
    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(window, CFSTR("AXWindowNumber"), &value);
    if (error != kAXErrorSuccess || !value) {
        return NO;
    }

    int64_t number = 0;
    BOOL ok = CFGetTypeID(value) == CFNumberGetTypeID() &&
              CFNumberGetValue((CFNumberRef)value, kCFNumberSInt64Type, &number) &&
              number == windowID;
    CFRelease(value);
    return ok;
}

BOOL FWAXWindowFrameMatchesQuartzBounds(AXUIElementRef window, CGRect quartzBounds) {
    if (CGRectIsEmpty(quartzBounds)) {
        return NO;
    }

    CGPoint position = CGPointZero;
    CGSize size = CGSizeZero;
    if (!FWAXCopyCGPointAttribute(window, kAXPositionAttribute, &position) ||
        !FWAXCopyCGSizeAttribute(window, kAXSizeAttribute, &size)) {
        return NO;
    }

    return fabs(position.x - CGRectGetMinX(quartzBounds)) <= 3.0 &&
           fabs(position.y - CGRectGetMinY(quartzBounds)) <= 3.0 &&
           fabs(size.width - CGRectGetWidth(quartzBounds)) <= 3.0 &&
           fabs(size.height - CGRectGetHeight(quartzBounds)) <= 3.0;
}

AXUIElementRef FWCopyAXWindowForWindowID(pid_t ownerPID, CGWindowID windowID, CGRect quartzBounds) {
    AXUIElementRef application = AXUIElementCreateApplication(ownerPID);
    if (!application) {
        return NULL;
    }

    CFTypeRef windowsValue = NULL;
    AXError error = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute, &windowsValue);
    if (error != kAXErrorSuccess || !windowsValue || CFGetTypeID(windowsValue) != CFArrayGetTypeID()) {
        if (windowsValue) {
            CFRelease(windowsValue);
        }
        CFRelease(application);
        return NULL;
    }

    AXUIElementRef fallbackWindow = NULL;
    CFArrayRef windows = (CFArrayRef)windowsValue;
    CFIndex count = CFArrayGetCount(windows);
    for (CFIndex index = 0; index < count; index++) {
        AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, index);
        if (!window || CFGetTypeID(window) != AXUIElementGetTypeID()) {
            continue;
        }

        if (FWAXWindowMatchesWindowID(window, windowID)) {
            CFRetain(window);
            CFRelease(windowsValue);
            CFRelease(application);
            return window;
        }

        if (!fallbackWindow && FWAXWindowFrameMatchesQuartzBounds(window, quartzBounds)) {
            fallbackWindow = window;
        }
    }

    if (fallbackWindow) {
        CFRetain(fallbackWindow);
    }
    CFRelease(windowsValue);
    CFRelease(application);
    return fallbackWindow;
}

CGRect FWAXWindowBounds(AXUIElementRef window, CGRect fallbackBounds) {
    CGPoint position = fallbackBounds.origin;
    CGSize size = fallbackBounds.size;
    FWAXCopyCGPointAttribute(window, kAXPositionAttribute, &position);
    FWAXCopyCGSizeAttribute(window, kAXSizeAttribute, &size);
    return CGRectMake(position.x, position.y, size.width, size.height);
}

BOOL FWParkAXWindowOutsideDisplays(AXUIElementRef window, CGRect sourceBounds, CGRect *parkedBounds) {
    CGPoint parkingPosition = FWParkingPositionForSourceBounds(sourceBounds);
    if (!FWAXSetCGPointAttribute(window, kAXPositionAttribute, parkingPosition)) {
        return NO;
    }

    if (parkedBounds) {
        *parkedBounds = FWAXWindowBounds(window,
                                         CGRectMake(parkingPosition.x,
                                                    parkingPosition.y,
                                                    CGRectGetWidth(sourceBounds),
                                                    CGRectGetHeight(sourceBounds)));
    }
    return YES;
}

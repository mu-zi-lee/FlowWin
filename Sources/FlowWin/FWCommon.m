#import "FWCommon.h"

CGFloat const FlowWinDefaultOpacity = 0.40;
CGFloat const FWOpacityScrollStep = 0.02;
CGFloat const FWOpacityPreciseScrollScale = 0.0004;
CGFloat const FWOpacityPreciseScrollMaxDelta = 0.01;
CGFloat const FWSourceWindowParkingMargin = 160.0;
NSTimeInterval const FWBackdropRefreshInterval = 1.0 / 30.0;
NSTimeInterval const FWMirrorInteractiveRefreshInterval = 1.0 / 30.0;
NSTimeInterval const FWMirrorStreamRefreshInterval = 1.0;
NSTimeInterval const FWMirrorFallbackRefreshInterval = 1.0 / 10.0;
int32_t const FWStreamTargetFrameRate = 20;
CGFloat const FWStreamMaxPixelArea = 3840.0 * 2160.0;
NSInteger const FWBackdropWindowLevelOffset = -1;
UInt32 const FWHotKeyToggleFrontmostID = 1;
UInt32 const FWHotKeyCloseAllID = 2;
OSType const FWHotKeySignature = 'FlWn';
NSString *const FWAutomationSocketName = @"flowwin-automation.sock";
NSString *const FWAutomationCommandKey = @"command";
NSString *const FWAutomationWindowIDKey = @"windowID";
NSString *const FWAutomationToggleFrontmostCommand = @"toggle-frontmost";
NSString *const FWAutomationPinFrontmostCommand = @"pin-frontmost";
NSString *const FWAutomationCloseAllCommand = @"close-all";
NSString *const FWAutomationRefreshMenuCommand = @"refresh-menu";
NSString *const FWAutomationPinWindowCommand = @"pin-window";
NSString *const FWAutomationUnpinWindowCommand = @"unpin-window";
NSString *const FWAutomationToggleWindowCommand = @"toggle-window";
NSString *const FWAutomationQuitCommand = @"quit";

CGEventFlags FWCGEventFlagsFromNSEventFlags(NSEventModifierFlags flags, BOOL stripControl) {
    CGEventFlags result = 0;
    if ((flags & NSEventModifierFlagShift) == NSEventModifierFlagShift) {
        result |= kCGEventFlagMaskShift;
    }
    if (!stripControl && (flags & NSEventModifierFlagControl) == NSEventModifierFlagControl) {
        result |= kCGEventFlagMaskControl;
    }
    if ((flags & NSEventModifierFlagOption) == NSEventModifierFlagOption) {
        result |= kCGEventFlagMaskAlternate;
    }
    if ((flags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand) {
        result |= kCGEventFlagMaskCommand;
    }
    if ((flags & NSEventModifierFlagCapsLock) == NSEventModifierFlagCapsLock) {
        result |= kCGEventFlagMaskAlphaShift;
    }
    return result;
}

CGFloat FWOpacityDeltaFromScrollEvent(NSEvent *event) {
    if (event.momentumPhase != NSEventPhaseNone) {
        return 0;
    }

    double dominantDelta = fabs(event.scrollingDeltaY) >= fabs(event.scrollingDeltaX)
        ? event.scrollingDeltaY
        : event.scrollingDeltaX;
    if (fabs(dominantDelta) < 0.01) {
        return 0;
    }

    CGFloat direction = dominantDelta > 0 ? 1.0 : -1.0;
    if (event.hasPreciseScrollingDeltas) {
        CGFloat delta = MIN(FWOpacityPreciseScrollMaxDelta, fabs(dominantDelta) * FWOpacityPreciseScrollScale);
        return direction * delta;
    }
    return direction * FWOpacityScrollStep;
}

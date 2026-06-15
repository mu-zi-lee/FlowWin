#import "FWCommon.h"

BOOL FWAccessibilityTrusted(BOOL prompt);
BOOL FWAXCopyCGPointAttribute(AXUIElementRef element, CFStringRef attribute, CGPoint *point);
BOOL FWAXCopyCGSizeAttribute(AXUIElementRef element, CFStringRef attribute, CGSize *size);
BOOL FWAXSetCGPointAttribute(AXUIElementRef element, CFStringRef attribute, CGPoint point);
BOOL FWAXSetCGSizeAttribute(AXUIElementRef element, CFStringRef attribute, CGSize size);
BOOL FWAXElementSupportsAction(AXUIElementRef element, CFStringRef action);
AXUIElementRef FWCopyAXElementAtPoint(pid_t ownerPID, CGPoint point);
NSString *FWAXCopyStringAttribute(AXUIElementRef element, CFStringRef attribute);
BOOL FWAXSetBoolAttribute(AXUIElementRef element, CFStringRef attribute, BOOL boolValue);
BOOL FWAXRoleIsTextInput(NSString *role);
AXUIElementRef FWAXCopyParentElement(AXUIElementRef element);
BOOL FWAXFocusElementIfEditable(AXUIElementRef element);
BOOL FWAXPressElementAtPoint(pid_t ownerPID, CGPoint point);
BOOL FWAXScrollElementAtPoint(pid_t ownerPID, CGPoint point, CGFloat deltaY, CGFloat deltaX);
BOOL FWAXWindowMatchesWindowID(AXUIElementRef window, CGWindowID windowID);
BOOL FWAXWindowFrameMatchesQuartzBounds(AXUIElementRef window, CGRect quartzBounds);
AXUIElementRef FWCopyAXWindowForWindowID(pid_t ownerPID, CGWindowID windowID, CGRect quartzBounds);
CGRect FWAXWindowBounds(AXUIElementRef window, CGRect fallbackBounds);
BOOL FWParkAXWindowOutsideDisplays(AXUIElementRef window, CGRect sourceBounds, CGRect *parkedBounds);

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <errno.h>
#import <float.h>
#import <fcntl.h>
#import <limits.h>
#import <math.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <sys/un.h>
#import <unistd.h>

extern CGFloat const FlowWinDefaultOpacity;
extern CGFloat const FWOpacityScrollStep;
extern CGFloat const FWOpacityPreciseScrollScale;
extern CGFloat const FWOpacityPreciseScrollMaxDelta;
extern CGFloat const FWSourceWindowParkingMargin;
extern NSTimeInterval const FWBackdropRefreshInterval;
extern NSTimeInterval const FWMirrorInteractiveRefreshInterval;
extern NSTimeInterval const FWMirrorStreamRefreshInterval;
extern NSTimeInterval const FWMirrorFallbackRefreshInterval;
extern int32_t const FWStreamTargetFrameRate;
extern CGFloat const FWStreamMaxPixelArea;
extern NSInteger const FWBackdropWindowLevelOffset;
extern UInt32 const FWHotKeyToggleFrontmostID;
extern UInt32 const FWHotKeyCloseAllID;
extern OSType const FWHotKeySignature;
extern NSString *const FWAutomationSocketName;
extern NSString *const FWAutomationCommandKey;
extern NSString *const FWAutomationWindowIDKey;
extern NSString *const FWAutomationToggleFrontmostCommand;
extern NSString *const FWAutomationPinFrontmostCommand;
extern NSString *const FWAutomationCloseAllCommand;
extern NSString *const FWAutomationRefreshMenuCommand;
extern NSString *const FWAutomationPinWindowCommand;
extern NSString *const FWAutomationUnpinWindowCommand;
extern NSString *const FWAutomationToggleWindowCommand;
extern NSString *const FWAutomationQuitCommand;

CGEventFlags FWCGEventFlagsFromNSEventFlags(NSEventModifierFlags flags, BOOL stripControl);
CGFloat FWOpacityDeltaFromScrollEvent(NSEvent *event);

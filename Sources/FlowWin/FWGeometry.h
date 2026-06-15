#import "FWCommon.h"

NSRect FWCocoaFrameFromQuartzBounds(CGRect quartzBounds);
CGRect FWQuartzBoundsFromCocoaFrame(NSRect cocoaFrame);
CGRect FWActiveDisplayQuartzUnion(void);
CGPoint FWParkingPositionForSourceBounds(CGRect sourceBounds);
CGFloat FWDisplayIntersectionArea(CGRect bounds);

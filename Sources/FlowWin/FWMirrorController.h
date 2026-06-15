#import "FWCommon.h"
#import "FWWindowInfo.h"

@class FWMirrorController;

@protocol FWMirrorInteraction <NSObject>
@property(nonatomic, copy, readonly) NSString *label;
@property(nonatomic, assign, readonly) CGFloat opacity;
@property(nonatomic, assign, readonly) BOOL attachedToSource;
@property(nonatomic, assign, readonly) BOOL clickThrough;
@property(nonatomic, assign, readonly) BOOL modifierOperateActive;
@property(nonatomic, assign, readonly) BOOL modifierMoveActive;
@property(nonatomic, assign, readonly) BOOL commandHoldActive;
@property(nonatomic, assign, readonly) BOOL nativeControlActive;
- (BOOL)beginMovingPinnedWindowAtMouseLocation:(NSPoint)mouseLocation;
- (void)movePinnedWindowToMouseLocation:(NSPoint)mouseLocation;
- (void)endMovingPinnedWindow;
- (BOOL)adjustOpacityWithScrollEvent:(NSEvent *)event;
- (BOOL)forwardSourceMouseEvent:(NSEvent *)event fromView:(NSView *)view eventType:(CGEventType)eventType;
- (BOOL)forwardSourceScrollEvent:(NSEvent *)event fromView:(NSView *)view;
@end

@protocol FWMirrorControllerDelegate <NSObject>
- (void)mirrorControllerDidLoseSourceWindow:(FWMirrorController *)mirror;
- (void)mirrorControllerAutoUnpinTimerDidFire:(FWMirrorController *)mirror;
- (void)mirrorController:(FWMirrorController *)mirror adjustOpacityBy:(CGFloat)delta;
@end

@interface FWMirrorController : NSObject <FWMirrorInteraction>
@property(nonatomic, weak) id<FWMirrorControllerDelegate> delegate;
@property(nonatomic, assign, readonly) CGWindowID windowID;
@property(nonatomic, assign, readonly) pid_t ownerPID;
@property(nonatomic, copy, readonly) NSString *label;
@property(nonatomic, assign, readonly) CGFloat opacity;
@property(nonatomic, assign, readonly) BOOL clickThrough;
@property(nonatomic, assign, readonly) BOOL attachedToSource;
@property(nonatomic, assign, readonly) BOOL modifierOperateActive;
@property(nonatomic, assign, readonly) BOOL modifierMoveActive;
@property(nonatomic, assign, readonly) BOOL commandHoldActive;
@property(nonatomic, assign, readonly) BOOL nativeControlActive;
@property(nonatomic, assign, readonly) BOOL hasAutoUnpinTimer;
@property(nonatomic, assign, readonly) NSTimeInterval autoUnpinInterval;
@property(nonatomic, copy, readonly) NSString *autoUnpinStatus;
- (instancetype)initWithWindowInfo:(FWWindowInfo *)windowInfo;
- (void)setMirrorOpacity:(CGFloat)opacity;
- (void)setAutoUnpinInterval:(NSTimeInterval)interval;
- (void)setModifierOperateActive:(BOOL)active;
- (void)setModifierMoveActive:(BOOL)active;
- (BOOL)beginNativeControlModeIfMouseInside:(NSPoint)mouseLocation;
- (void)endNativeControlMode;
- (BOOL)beginCommandHoldModeIfMouseInside:(NSPoint)mouseLocation;
- (void)endCommandHoldMode;
- (void)updateCommandHoldForMouseLocation:(NSPoint)mouseLocation eventType:(NSEventType)eventType;
- (BOOL)containsMouseLocation:(NSPoint)mouseLocation;
- (void)toggleClickThrough;
- (void)stop;
@end

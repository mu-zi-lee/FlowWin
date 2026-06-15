#import "FWCommon.h"

@interface FWMirrorCommand : NSObject
@property(nonatomic, assign) CGWindowID windowID;
@property(nonatomic, assign) CGFloat opacity;
@property(nonatomic, assign) BOOL hasOpacity;
@property(nonatomic, assign) NSTimeInterval autoUnpinInterval;
@property(nonatomic, assign) BOOL hasAutoUnpinInterval;
+ (instancetype)commandWithWindowID:(CGWindowID)windowID;
+ (instancetype)commandWithWindowID:(CGWindowID)windowID opacity:(CGFloat)opacity;
+ (instancetype)commandWithWindowID:(CGWindowID)windowID autoUnpinInterval:(NSTimeInterval)interval;
@end

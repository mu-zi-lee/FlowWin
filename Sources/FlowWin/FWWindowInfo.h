#import "FWCommon.h"

@interface FWWindowInfo : NSObject
@property(nonatomic, assign) CGWindowID windowID;
@property(nonatomic, assign) pid_t ownerPID;
@property(nonatomic, copy) NSString *ownerName;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, assign) CGRect quartzBounds;
@property(nonatomic, readonly) NSString *displayName;
@end

@interface FWWindowLister : NSObject
+ (NSArray<FWWindowInfo *> *)allWindows;
+ (FWWindowInfo *)windowWithID:(CGWindowID)windowID;
+ (FWWindowInfo *)frontmostWindowForPID:(pid_t)pid;
@end

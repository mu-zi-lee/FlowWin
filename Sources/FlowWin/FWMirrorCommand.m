#import "FWMirrorCommand.h"

@implementation FWMirrorCommand
+ (instancetype)commandWithWindowID:(CGWindowID)windowID {
    FWMirrorCommand *command = [FWMirrorCommand new];
    command.windowID = windowID;
    command.hasOpacity = NO;
    command.hasAutoUnpinInterval = NO;
    return command;
}

+ (instancetype)commandWithWindowID:(CGWindowID)windowID opacity:(CGFloat)opacity {
    FWMirrorCommand *command = [self commandWithWindowID:windowID];
    command.opacity = opacity;
    command.hasOpacity = YES;
    return command;
}

+ (instancetype)commandWithWindowID:(CGWindowID)windowID autoUnpinInterval:(NSTimeInterval)interval {
    FWMirrorCommand *command = [self commandWithWindowID:windowID];
    command.autoUnpinInterval = interval;
    command.hasAutoUnpinInterval = YES;
    return command;
}
@end

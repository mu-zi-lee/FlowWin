#import "FWCommon.h"
#import "FWMirrorController.h"

@interface FWAppDelegate : NSObject <NSApplicationDelegate, FWMirrorControllerDelegate>
- (void)startFlowWin;
- (void)pinFrontmostWindow:(id)sender;
- (void)toggleFrontmostWindow:(id)sender;
- (void)closeAllMirrors:(id)sender;
- (void)applyGlobalOpacity:(CGFloat)opacity scheduleMenuRefresh:(BOOL)scheduleMenuRefresh;
- (void)scheduleOpacityMenuRefresh;
- (BOOL)performAutomationCommand:(NSString *)command userInfo:(NSDictionary *)userInfo;
@end

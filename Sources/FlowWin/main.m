#import "FWAppDelegate.h"
#import "FWAccessibility.h"
#import "FWAutomation.h"
#import "FWWindowInfo.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        int automationExitCode = FWRunAutomationCLI(argc, argv);
        if (automationExitCode >= 0) {
            return automationExitCode;
        }

        if (argc > 1 && strcmp(argv[1], "--list-windows") == 0) {
            NSArray<FWWindowInfo *> *windows = [FWWindowLister allWindows];
            printf("screen-recording=%s\n", CGPreflightScreenCaptureAccess() ? "allowed" : "not-allowed");
            printf("accessibility=%s\n", FWAccessibilityTrusted(NO) ? "allowed" : "not-allowed");
            printf("windows=%lu\n", (unsigned long)windows.count);
            NSUInteger limit = MIN(windows.count, 20);
            for (NSUInteger index = 0; index < limit; index++) {
                FWWindowInfo *window = windows[index];
                printf("%u\t%s\t%.0fx%.0f\n",
                       window.windowID,
                       window.displayName.UTF8String,
                       window.quartzBounds.size.width,
                       window.quartzBounds.size.height);
            }
            return 0;
        }

        if (argc > 1 && strcmp(argv[1], "--preflight") == 0) {
            printf("screen-recording=%s\n", CGPreflightScreenCaptureAccess() ? "allowed" : "not-allowed");
            printf("accessibility=%s\n", FWAccessibilityTrusted(NO) ? "allowed" : "not-allowed");
            return 0;
        }

        NSApplication *application = NSApplication.sharedApplication;
        static FWAppDelegate *delegate = nil;
        delegate = [FWAppDelegate new];
        application.delegate = delegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate startFlowWin];
        });
        [application run];
    }
    return 0;
}

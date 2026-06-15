#import "FWCommon.h"

void FWPrintAutomationUsage(void);
NSString *FWAutomationSocketPath(void);
BOOL FWWriteAllToFileDescriptor(int fileDescriptor, const void *bytes, NSUInteger length);
int FWPostAutomationCommand(NSString *command, NSDictionary *userInfo);
int FWRunAutomationCLI(int argc, const char *argv[]);

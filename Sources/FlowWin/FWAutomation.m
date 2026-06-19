#import "FWAutomation.h"

static NSTimeInterval const FWAutomationResponseTimeout = 1.0;

void FWPrintAutomationUsage(void) {
    printf("FlowWin automation commands:\n");
    printf("  FlowWin --pin-frontmost\n");
    printf("  FlowWin --toggle-frontmost\n");
    printf("  FlowWin --close-all\n");
    printf("  FlowWin --refresh-menu\n");
    printf("  FlowWin --quit\n");
    printf("  FlowWin --pin-window <window-id>\n");
    printf("  FlowWin --unpin-window <window-id>\n");
    printf("  FlowWin --toggle-window <window-id>\n");
    printf("\n");
    printf("URL scheme examples:\n");
    printf("  open 'flowwin://toggle-frontmost'\n");
    printf("  open 'flowwin://close-all'\n");
    printf("  open 'flowwin://quit'\n");
    printf("  open 'flowwin://pin-window?windowID=123'\n");
}

NSString *FWAutomationSocketPath(void) {
    NSString *name = [NSString stringWithFormat:@"%u-%@", getuid(), FWAutomationSocketName];
    return [@"/tmp" stringByAppendingPathComponent:name];
}

BOOL FWWriteAllToFileDescriptor(int fileDescriptor, const void *bytes, NSUInteger length) {
    const uint8_t *cursor = bytes;
    NSUInteger remaining = length;
    while (remaining > 0) {
        ssize_t written = write(fileDescriptor, cursor, remaining);
        if (written < 0) {
            if (errno == EINTR) {
                continue;
            }
            return NO;
        }
        cursor += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

int FWPostAutomationCommand(NSString *command, NSDictionary *userInfo) {
    NSMutableDictionary *payload = [NSMutableDictionary dictionaryWithObject:command forKey:FWAutomationCommandKey];
    if (userInfo) {
        [payload addEntriesFromDictionary:userInfo];
    }

    NSError *serializationError = nil;
    NSData *payloadData = [NSPropertyListSerialization dataWithPropertyList:payload
                                                                     format:NSPropertyListBinaryFormat_v1_0
                                                                    options:0
                                                                      error:&serializationError];
    if (!payloadData) {
        fprintf(stderr, "failed to serialize automation command: %s\n", serializationError.localizedDescription.UTF8String);
        return 2;
    }

    NSString *socketPath = FWAutomationSocketPath();
    if (socketPath.length >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        fprintf(stderr, "automation socket path is too long.\n");
        return 3;
    }

    int socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (socketFD < 0) {
        fprintf(stderr, "failed to create automation socket: %s\n", strerror(errno));
        return 3;
    }

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strncpy(address.sun_path, socketPath.fileSystemRepresentation, sizeof(address.sun_path) - 1);

    if (connect(socketFD, (struct sockaddr *)&address, sizeof(address)) < 0) {
        fprintf(stderr,
                "FlowWin automation listener not reachable at %s: %s. Start FlowWin.app first.\n",
                socketPath.fileSystemRepresentation,
                strerror(errno));
        close(socketFD);
        return 3;
    }

    struct timeval timeout;
    timeout.tv_sec = (time_t)FWAutomationResponseTimeout;
    timeout.tv_usec = (suseconds_t)((FWAutomationResponseTimeout - timeout.tv_sec) * 1000000.0);
    setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));

    if (!FWWriteAllToFileDescriptor(socketFD, payloadData.bytes, payloadData.length)) {
        fprintf(stderr, "failed to send automation command: %s\n", strerror(errno));
        close(socketFD);
        return 3;
    }
    shutdown(socketFD, SHUT_WR);

    NSMutableData *responseData = [NSMutableData data];
    uint8_t buffer[4096];
    for (;;) {
        ssize_t count = read(socketFD, buffer, sizeof(buffer));
        if (count > 0) {
            [responseData appendBytes:buffer length:(NSUInteger)count];
            continue;
        }
        if (count == 0) {
            break;
        }
        if (errno == EINTR) {
            continue;
        }
        fprintf(stderr, "failed to read automation response: %s\n", strerror(errno));
        close(socketFD);
        return 3;
    }
    close(socketFD);

    BOOL ok = NO;
    if (responseData.length > 0) {
        NSDictionary *response = [NSPropertyListSerialization propertyListWithData:responseData
                                                                           options:NSPropertyListImmutable
                                                                            format:nil
                                                                             error:nil];
        if ([response isKindOfClass:NSDictionary.class]) {
            ok = [response[@"ok"] boolValue];
        }
    }

    printf("sent=%s ok=%s\n", command.UTF8String, ok ? "yes" : "no");
    return ok ? 0 : 4;
}

int FWRunAutomationCLI(int argc, const char *argv[]) {
    if (argc <= 1) {
        return -1;
    }

    const char *argument = argv[1];
    if (strcmp(argument, "--automation-help") == 0 || strcmp(argument, "--help") == 0) {
        FWPrintAutomationUsage();
        return 0;
    }

    if (strcmp(argument, "--pin-frontmost") == 0) {
        return FWPostAutomationCommand(FWAutomationPinFrontmostCommand, nil);
    }
    if (strcmp(argument, "--toggle-frontmost") == 0) {
        return FWPostAutomationCommand(FWAutomationToggleFrontmostCommand, nil);
    }
    if (strcmp(argument, "--close-all") == 0) {
        return FWPostAutomationCommand(FWAutomationCloseAllCommand, nil);
    }
    if (strcmp(argument, "--refresh-menu") == 0) {
        return FWPostAutomationCommand(FWAutomationRefreshMenuCommand, nil);
    }
    if (strcmp(argument, "--quit") == 0) {
        return FWPostAutomationCommand(FWAutomationQuitCommand, nil);
    }

    NSString *command = nil;
    if (strcmp(argument, "--pin-window") == 0) {
        command = FWAutomationPinWindowCommand;
    } else if (strcmp(argument, "--unpin-window") == 0) {
        command = FWAutomationUnpinWindowCommand;
    } else if (strcmp(argument, "--toggle-window") == 0) {
        command = FWAutomationToggleWindowCommand;
    }

    if (command) {
        if (argc <= 2) {
            fprintf(stderr, "%s requires a window id.\n", argument);
            return 2;
        }
        NSDictionary *userInfo = @{FWAutomationWindowIDKey: [NSString stringWithUTF8String:argv[2]]};
        return FWPostAutomationCommand(command, userInfo);
    }

    return -1;
}

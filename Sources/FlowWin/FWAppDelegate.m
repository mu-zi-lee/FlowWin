#import "FWAppDelegate.h"
#import "FWAccessibility.h"
#import "FWAutomation.h"
#import "FWMirrorCommand.h"
#import "FWWindowInfo.h"

@interface FWAppDelegate ()
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, FWMirrorController *> *mirrors;
@property(nonatomic, assign) EventHandlerRef hotKeyEventHandler;
@property(nonatomic, assign) EventHotKeyRef toggleFrontmostHotKey;
@property(nonatomic, assign) EventHotKeyRef closeAllHotKey;
@property(nonatomic, assign) BOOL toggleFrontmostHotKeyRegistered;
@property(nonatomic, assign) BOOL closeAllHotKeyRegistered;
@property(nonatomic, assign) int automationSocketFD;
@property(nonatomic, strong) dispatch_source_t automationSocketSource;
@property(nonatomic, strong) id localFlagsMonitor;
@property(nonatomic, strong) id localMouseMonitor;
@property(nonatomic, strong) id globalFlagsMonitor;
@property(nonatomic, strong) id globalMouseMonitor;
@property(nonatomic, weak) FWMirrorController *optionMovingMirror;
@property(nonatomic, weak) FWMirrorController *commandHoldMirror;
@property(nonatomic, assign) BOOL commandModifierActive;
@property(nonatomic, assign) CGFloat globalOpacity;
@property(nonatomic, assign) BOOL opacityMenuRefreshScheduled;
- (void)startFlowWin;
- (void)pinFrontmostWindow:(id)sender;
- (void)toggleFrontmostWindow:(id)sender;
- (void)closeAllMirrors:(id)sender;
- (void)applyGlobalOpacity:(CGFloat)opacity scheduleMenuRefresh:(BOOL)scheduleMenuRefresh;
- (void)scheduleOpacityMenuRefresh;
- (BOOL)performAutomationCommand:(NSString *)command userInfo:(NSDictionary *)userInfo;
@end

static OSStatus FWHandleHotKey(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    (void)nextHandler;
    EventHotKeyID hotKeyID;
    OSStatus status = GetEventParameter(event,
                                        kEventParamDirectObject,
                                        typeEventHotKeyID,
                                        NULL,
                                        sizeof(hotKeyID),
                                        NULL,
                                        &hotKeyID);
    if (status != noErr || hotKeyID.signature != FWHotKeySignature) {
        return status;
    }

    FWAppDelegate *delegate = (__bridge FWAppDelegate *)userData;
    if (hotKeyID.id == FWHotKeyToggleFrontmostID) {
        [delegate toggleFrontmostWindow:nil];
        return noErr;
    }
    if (hotKeyID.id == FWHotKeyCloseAllID) {
        [delegate closeAllMirrors:nil];
        return noErr;
    }
    return eventNotHandledErr;
}

@implementation FWAppDelegate

#pragma mark - Application Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self startFlowWin];
}

- (void)startFlowWin {
    if (self.mirrors) {
        return;
    }

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.mirrors = [NSMutableDictionary dictionary];
    self.globalOpacity = FlowWinDefaultOpacity;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"FlowWin";
    [self registerGlobalHotKeys];
    [self registerModifierMonitors];
    [self registerAutomationHandlers];
    [self rebuildMenu];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    for (FWMirrorController *mirror in self.mirrors.allValues) {
        [mirror stop];
    }
    [self unregisterGlobalHotKeys];
    [self unregisterModifierMonitors];
    [self unregisterAutomationHandlers];
}

#pragma mark - Hot Keys

- (void)registerGlobalHotKeys {
    EventTypeSpec hotKeyEventType = { kEventClassKeyboard, kEventHotKeyPressed };
    OSStatus handlerStatus = InstallApplicationEventHandler(&FWHandleHotKey,
                                                            1,
                                                            &hotKeyEventType,
                                                            (__bridge void *)self,
                                                            &_hotKeyEventHandler);
    if (handlerStatus != noErr) {
        NSLog(@"FlowWin: failed to install hotkey handler (%d)", handlerStatus);
        return;
    }

    EventHotKeyID toggleID = { FWHotKeySignature, FWHotKeyToggleFrontmostID };
    OSStatus toggleStatus = RegisterEventHotKey(kVK_ANSI_P,
                                                controlKey | optionKey | cmdKey,
                                                toggleID,
                                                GetApplicationEventTarget(),
                                                0,
                                                &_toggleFrontmostHotKey);
    self.toggleFrontmostHotKeyRegistered = toggleStatus == noErr;
    if (toggleStatus != noErr) {
        NSLog(@"FlowWin: failed to register Control-Option-Command-P (%d)", toggleStatus);
    }

    EventHotKeyID closeAllID = { FWHotKeySignature, FWHotKeyCloseAllID };
    OSStatus closeAllStatus = RegisterEventHotKey(kVK_ANSI_X,
                                                  controlKey | optionKey | cmdKey,
                                                  closeAllID,
                                                  GetApplicationEventTarget(),
                                                  0,
                                                  &_closeAllHotKey);
    self.closeAllHotKeyRegistered = closeAllStatus == noErr;
    if (closeAllStatus != noErr) {
        NSLog(@"FlowWin: failed to register Control-Option-Command-X (%d)", closeAllStatus);
    }

}

#pragma mark - Automation Listener

- (void)registerAutomationHandlers {
    self.automationSocketFD = -1;
    NSString *socketPath = FWAutomationSocketPath();
    if (socketPath.length >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        NSLog(@"FlowWin: automation socket path is too long");
        return;
    }

    int socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (socketFD < 0) {
        NSLog(@"FlowWin: failed to create automation socket (%s)", strerror(errno));
        return;
    }

    unlink(socketPath.fileSystemRepresentation);

    struct sockaddr_un address;
    memset(&address, 0, sizeof(address));
    address.sun_family = AF_UNIX;
    strncpy(address.sun_path, socketPath.fileSystemRepresentation, sizeof(address.sun_path) - 1);

    if (bind(socketFD, (struct sockaddr *)&address, sizeof(address)) < 0) {
        NSLog(@"FlowWin: failed to bind automation socket (%s)", strerror(errno));
        close(socketFD);
        return;
    }

    if (listen(socketFD, 8) < 0) {
        NSLog(@"FlowWin: failed to listen on automation socket (%s)", strerror(errno));
        close(socketFD);
        unlink(socketPath.fileSystemRepresentation);
        return;
    }

    int flags = fcntl(socketFD, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(socketFD, F_SETFL, flags | O_NONBLOCK);
    }

    self.automationSocketFD = socketFD;
    NSLog(@"FlowWin: automation listener ready at %@", socketPath);
    self.automationSocketSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                                         (uintptr_t)socketFD,
                                                         0,
                                                         dispatch_get_main_queue());
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.automationSocketSource, ^{
        [weakSelf acceptAutomationConnections];
    });
    dispatch_source_set_cancel_handler(self.automationSocketSource, ^{
        close(socketFD);
        unlink(socketPath.fileSystemRepresentation);
    });
    dispatch_resume(self.automationSocketSource);

    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
}

- (void)unregisterAutomationHandlers {
    if (self.automationSocketSource) {
        dispatch_source_cancel(self.automationSocketSource);
        self.automationSocketSource = nil;
        self.automationSocketFD = -1;
    } else if (self.automationSocketFD >= 0) {
        close(self.automationSocketFD);
        self.automationSocketFD = -1;
        unlink(FWAutomationSocketPath().fileSystemRepresentation);
    }

    [[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass
                                                                        andEventID:kAEGetURL];
}

- (void)acceptAutomationConnections {
    for (;;) {
        int clientFD = accept(self.automationSocketFD, NULL, NULL);
        if (clientFD < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
                return;
            }
            NSLog(@"FlowWin: failed to accept automation connection (%s)", strerror(errno));
            return;
        }
        [self handleAutomationClient:clientFD];
    }
}

- (void)handleAutomationClient:(int)clientFD {
    NSMutableData *requestData = [NSMutableData data];
    uint8_t buffer[4096];
    for (;;) {
        ssize_t count = read(clientFD, buffer, sizeof(buffer));
        if (count > 0) {
            [requestData appendBytes:buffer length:(NSUInteger)count];
            continue;
        }
        if (count == 0) {
            break;
        }
        if (errno == EINTR) {
            continue;
        }
        NSLog(@"FlowWin: failed to read automation command (%s)", strerror(errno));
        close(clientFD);
        return;
    }

    NSDictionary *payload = [NSPropertyListSerialization propertyListWithData:requestData
                                                                      options:NSPropertyListImmutable
                                                                       format:nil
                                                                        error:nil];
    NSString *command = [payload isKindOfClass:NSDictionary.class] ? payload[FWAutomationCommandKey] : nil;
    BOOL ok = [command isKindOfClass:NSString.class] && [self performAutomationCommand:command userInfo:payload];
    NSDictionary *response = @{@"ok": @(ok)};
    NSData *responseData = [NSPropertyListSerialization dataWithPropertyList:response
                                                                      format:NSPropertyListBinaryFormat_v1_0
                                                                     options:0
                                                                       error:nil];
    if (responseData) {
        FWWriteAllToFileDescriptor(clientFD, responseData.bytes, responseData.length);
    }
    close(clientFD);
}

- (void)unregisterGlobalHotKeys {
    if (self.toggleFrontmostHotKey) {
        UnregisterEventHotKey(self.toggleFrontmostHotKey);
        self.toggleFrontmostHotKey = NULL;
    }
    if (self.closeAllHotKey) {
        UnregisterEventHotKey(self.closeAllHotKey);
        self.closeAllHotKey = NULL;
    }
    if (self.hotKeyEventHandler) {
        RemoveEventHandler(self.hotKeyEventHandler);
        self.hotKeyEventHandler = NULL;
    }
}

#pragma mark - Global Input Monitors

- (void)registerModifierMonitors {
    __weak typeof(self) weakSelf = self;
    self.localFlagsMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged
                                                                   handler:^NSEvent *(NSEvent *event) {
        [weakSelf updateModifierOperateStateFromFlags:event.modifierFlags];
        return event;
    }];
    self.localMouseMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskMouseMoved |
                                                                            NSEventMaskLeftMouseDown |
                                                                            NSEventMaskLeftMouseDragged |
                                                                            NSEventMaskLeftMouseUp)
                                                                  handler:^NSEvent *(NSEvent *event) {
        [weakSelf handleGlobalMouseEvent:event];
        return event;
    }];
    self.globalFlagsMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskFlagsChanged
                                                                     handler:^(NSEvent *event) {
        [weakSelf updateModifierOperateStateFromFlags:event.modifierFlags];
    }];
    self.globalMouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskMouseMoved |
                                                                              NSEventMaskLeftMouseDown |
                                                                              NSEventMaskLeftMouseDragged |
                                                                              NSEventMaskLeftMouseUp)
                                                                    handler:^(NSEvent *event) {
        [weakSelf handleGlobalMouseEvent:event];
    }];
}

- (void)unregisterModifierMonitors {
    if (self.localFlagsMonitor) {
        [NSEvent removeMonitor:self.localFlagsMonitor];
        self.localFlagsMonitor = nil;
    }
    if (self.localMouseMonitor) {
        [NSEvent removeMonitor:self.localMouseMonitor];
        self.localMouseMonitor = nil;
    }
    if (self.globalFlagsMonitor) {
        [NSEvent removeMonitor:self.globalFlagsMonitor];
        self.globalFlagsMonitor = nil;
    }
    if (self.globalMouseMonitor) {
        [NSEvent removeMonitor:self.globalMouseMonitor];
        self.globalMouseMonitor = nil;
    }
    self.optionMovingMirror = nil;
    self.commandHoldMirror = nil;
}

- (void)updateModifierOperateStateFromFlags:(NSEventModifierFlags)flags {
    BOOL operateActive = (flags & NSEventModifierFlagControl) == NSEventModifierFlagControl;
    BOOL moveActive = (flags & NSEventModifierFlagOption) == NSEventModifierFlagOption;
    BOOL commandActive = (flags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand;
    BOOL commandPressed = commandActive && !self.commandModifierActive;
    self.commandModifierActive = commandActive;
    NSArray<FWMirrorController *> *mirrors = self.mirrors.allValues.copy;
    NSPoint mouseLocation = NSEvent.mouseLocation;
    for (FWMirrorController *mirror in mirrors) {
        BOOL wasOperateActive = mirror.modifierOperateActive;
        BOOL wasCommandHoldActive = mirror.commandHoldActive;
        [mirror setModifierOperateActive:operateActive];
        [mirror setModifierMoveActive:moveActive];
        if (operateActive && !wasOperateActive) {
            [mirror beginNativeControlModeIfMouseInside:mouseLocation];
        } else if (!operateActive && wasOperateActive) {
            if (!mirror.commandHoldActive) {
                [mirror endNativeControlMode];
            }
        }

        BOOL commandOnly = commandActive && !operateActive && !moveActive &&
                           (flags & NSEventModifierFlagShift) != NSEventModifierFlagShift;
        if (commandPressed && commandOnly && !wasCommandHoldActive && [mirror beginCommandHoldModeIfMouseInside:mouseLocation]) {
            self.commandHoldMirror = mirror;
        }
    }
}

- (FWMirrorController *)mirrorAtMouseLocation:(NSPoint)mouseLocation {
    NSArray<FWMirrorController *> *mirrors = self.mirrors.allValues.copy;
    for (FWMirrorController *mirror in mirrors) {
        if ([mirror containsMouseLocation:mouseLocation]) {
            return mirror;
        }
    }
    return nil;
}

- (void)handleGlobalMouseEvent:(NSEvent *)event {
    [self handleGlobalOptionMoveEvent:event];
    NSPoint mouseLocation = NSEvent.mouseLocation;
    [self.commandHoldMirror updateCommandHoldForMouseLocation:mouseLocation eventType:event.type];
    if (!self.commandHoldMirror.commandHoldActive) {
        self.commandHoldMirror = nil;
    }
}

- (void)handleGlobalOptionMoveEvent:(NSEvent *)event {
    BOOL optionActive = (event.modifierFlags & NSEventModifierFlagOption) == NSEventModifierFlagOption;
    NSPoint mouseLocation = NSEvent.mouseLocation;

    if (event.type == NSEventTypeLeftMouseDown) {
        if (!optionActive) {
            return;
        }
        FWMirrorController *mirror = [self mirrorAtMouseLocation:mouseLocation];
        if (!mirror) {
            return;
        }
        self.optionMovingMirror = mirror;
        [mirror setModifierMoveActive:YES];
        [mirror beginMovingPinnedWindowAtMouseLocation:mouseLocation];
        return;
    }

    if (event.type == NSEventTypeLeftMouseDragged) {
        [self.optionMovingMirror movePinnedWindowToMouseLocation:mouseLocation];
        return;
    }

    if (event.type == NSEventTypeLeftMouseUp) {
        [self.optionMovingMirror endMovingPinnedWindow];
        [self.optionMovingMirror setModifierMoveActive:optionActive];
        self.optionMovingMirror = nil;
    }
}

#pragma mark - Menu

- (void)rebuildMenu {
    NSMenu *menu = [NSMenu new];

    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"FlowWin" action:nil keyEquivalent:@""];
    titleItem.enabled = NO;
    [menu addItem:titleItem];

    NSMenuItem *developerItem = [[NSMenuItem alloc] initWithTitle:@"由木子不是木子狸开发"
                                                           action:nil
                                                    keyEquivalent:@""];
    developerItem.enabled = NO;
    [menu addItem:developerItem];

    NSMenuItem *freewareItem = [[NSMenuItem alloc] initWithTitle:@"软件完全免费"
                                                          action:nil
                                                   keyEquivalent:@""];
    freewareItem.enabled = NO;
    [menu addItem:freewareItem];

    if (FWAccessibilityTrusted(NO)) {
        NSMenuItem *accessibilityItem = [[NSMenuItem alloc] initWithTitle:@"辅助功能：已允许" action:nil keyEquivalent:@""];
        accessibilityItem.enabled = NO;
        [menu addItem:accessibilityItem];
    } else {
        NSMenuItem *accessibilityItem = [[NSMenuItem alloc] initWithTitle:@"授予辅助功能权限"
                                                                   action:@selector(requestAccessibilityPermission:)
                                                            keyEquivalent:@""];
        accessibilityItem.target = self;
        [menu addItem:accessibilityItem];

        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"打开辅助功能设置"
                                                              action:@selector(openAccessibilitySettings:)
                                                       keyEquivalent:@""];
        settingsItem.target = self;
        [menu addItem:settingsItem];
    }

    if (CGPreflightScreenCaptureAccess()) {
        NSMenuItem *permissionItem = [[NSMenuItem alloc] initWithTitle:@"屏幕录制：已允许" action:nil keyEquivalent:@""];
        permissionItem.enabled = NO;
        [menu addItem:permissionItem];
    } else {
        NSMenuItem *permissionItem = [[NSMenuItem alloc] initWithTitle:@"授予屏幕录制权限"
                                                                action:@selector(requestScreenCapturePermission:)
                                                         keyEquivalent:@""];
        permissionItem.target = self;
        [menu addItem:permissionItem];

        NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"打开屏幕录制设置"
                                                              action:@selector(openScreenRecordingSettings:)
                                                       keyEquivalent:@""];
        settingsItem.target = self;
        [menu addItem:settingsItem];
    }

    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *frontmostItem = [[NSMenuItem alloc] initWithTitle:@"固定/取消固定前台窗口"
                                                           action:@selector(toggleFrontmostWindow:)
                                                    keyEquivalent:@"p"];
    frontmostItem.target = self;
    frontmostItem.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand;
    [menu addItem:frontmostItem];

    NSMenuItem *shortcutsItem = [[NSMenuItem alloc] initWithTitle:@"全局快捷键" action:nil keyEquivalent:@""];
    NSMenu *shortcutsMenu = [NSMenu new];
    NSString *pinShortcutTitle = self.toggleFrontmostHotKeyRegistered
        ? @"固定前台窗口：Control-Option-Command-P"
        : @"固定前台窗口：Control-Option-Command-P 不可用";
    NSMenuItem *pinShortcutItem = [[NSMenuItem alloc] initWithTitle:pinShortcutTitle action:nil keyEquivalent:@""];
    pinShortcutItem.enabled = NO;
    [shortcutsMenu addItem:pinShortcutItem];

    NSString *closeShortcutTitle = self.closeAllHotKeyRegistered
        ? @"关闭固定窗口：Control-Option-Command-X"
        : @"关闭固定窗口：Control-Option-Command-X 不可用";
    NSMenuItem *closeShortcutItem = [[NSMenuItem alloc] initWithTitle:closeShortcutTitle action:nil keyEquivalent:@""];
    closeShortcutItem.enabled = NO;
    [shortcutsMenu addItem:closeShortcutItem];

    shortcutsItem.submenu = shortcutsMenu;
    [menu addItem:shortcutsItem];

    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *pinItem = [[NSMenuItem alloc] initWithTitle:@"固定窗口" action:nil keyEquivalent:@""];
    NSMenu *pinMenu = [NSMenu new];
    NSArray<FWWindowInfo *> *windows = [FWWindowLister allWindows];
    if (!CGPreflightScreenCaptureAccess()) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"需要屏幕录制权限" action:nil keyEquivalent:@""];
        emptyItem.enabled = NO;
        [pinMenu addItem:emptyItem];
    } else if (windows.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"没有找到窗口" action:nil keyEquivalent:@""];
        emptyItem.enabled = NO;
        [pinMenu addItem:emptyItem];
    } else {
        for (FWWindowInfo *windowInfo in windows) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:windowInfo.displayName
                                                          action:@selector(pinWindow:)
                                                   keyEquivalent:@""];
            item.target = self;
            item.representedObject = windowInfo;
            item.state = self.mirrors[@(windowInfo.windowID)] ? NSControlStateValueOn : NSControlStateValueOff;
            [pinMenu addItem:item];
        }
    }
    pinItem.submenu = pinMenu;
    [menu addItem:pinItem];

    if (self.mirrors.count > 0) {
        FWMirrorController *mirror = self.mirrors.allValues.firstObject;
        NSString *title = mirror.label.length > 0 ? [NSString stringWithFormat:@"当前固定：%@", mirror.label] : @"当前固定窗口";
        NSMenuItem *mirrorItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        mirrorItem.submenu = [self menuForMirror:mirror];
        [menu addItem:mirrorItem];

        NSMenuItem *closeAllItem = [[NSMenuItem alloc] initWithTitle:@"关闭固定窗口"
                                                              action:@selector(closeAllMirrors:)
                                                       keyEquivalent:@""];
        closeAllItem.target = self;
        [menu addItem:closeAllItem];
    }

    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:@"刷新窗口列表"
                                                         action:@selector(refreshMenu:)
                                                  keyEquivalent:@"r"];
    refreshItem.target = self;
    [menu addItem:refreshItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出 FlowWin"
                                                      action:@selector(quit:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (NSMenu *)menuForMirror:(FWMirrorController *)mirror {
    NSMenu *menu = [NSMenu new];

    NSMenuItem *clickThroughItem = [[NSMenuItem alloc] initWithTitle:@"鼠标穿透到下层应用"
                                                              action:@selector(toggleClickThrough:)
                                                       keyEquivalent:@""];
    clickThroughItem.target = self;
    clickThroughItem.state = mirror.clickThrough ? NSControlStateValueOn : NSControlStateValueOff;
    clickThroughItem.representedObject = [FWMirrorCommand commandWithWindowID:mirror.windowID];
    [menu addItem:clickThroughItem];

    NSString *interactionStatus = mirror.clickThrough
        ? @"默认穿透；Control 临时操作，Command 保持到移出"
        : @"直接操作源窗口；Option 拖动移动，Option+滚轮调透明度";
    NSMenuItem *clickThroughStatusItem = [[NSMenuItem alloc] initWithTitle:interactionStatus
                                                                    action:nil
                                                             keyEquivalent:@""];
    clickThroughStatusItem.enabled = NO;
    [menu addItem:clickThroughStatusItem];

    NSMenuItem *opacityHeaderItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"透明度：%.0f%%", self.globalOpacity * 100.0]
                                                               action:nil
                                                        keyEquivalent:@""];
    opacityHeaderItem.enabled = NO;
    [menu addItem:opacityHeaderItem];

    NSMenuItem *opacitySliderItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    NSView *opacityView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 240, 34)];
    NSTextField *minLabel = [NSTextField labelWithString:@"1"];
    minLabel.frame = NSMakeRect(8, 9, 18, 16);
    minLabel.alignment = NSTextAlignmentRight;
    NSTextField *maxLabel = [NSTextField labelWithString:@"100"];
    maxLabel.frame = NSMakeRect(206, 9, 28, 16);
    NSSlider *opacitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(30, 6, 170, 22)];
    opacitySlider.minValue = 1.0;
    opacitySlider.maxValue = 100.0;
    opacitySlider.doubleValue = MAX(1.0, MIN(100.0, self.globalOpacity * 100.0));
    opacitySlider.continuous = YES;
    opacitySlider.target = self;
    opacitySlider.action = @selector(setGlobalOpacityFromSlider:);
    opacitySlider.toolTip = @"所有固定窗口透明度";
    [opacityView addSubview:minLabel];
    [opacityView addSubview:opacitySlider];
    [opacityView addSubview:maxLabel];
    opacitySliderItem.view = opacityView;
    [menu addItem:opacitySliderItem];

    NSMenuItem *timerStatusItem = [[NSMenuItem alloc] initWithTitle:mirror.autoUnpinStatus action:nil keyEquivalent:@""];
    timerStatusItem.enabled = NO;
    [menu addItem:timerStatusItem];

    NSMenuItem *timerItem = [[NSMenuItem alloc] initWithTitle:@"自动取消固定" action:nil keyEquivalent:@""];
    NSMenu *timerMenu = [NSMenu new];
    NSArray<NSDictionary *> *timerPresets = @[
        @{@"label": @"关闭", @"value": @0},
        @{@"label": @"5 分钟", @"value": @300},
        @{@"label": @"15 分钟", @"value": @900},
        @{@"label": @"30 分钟", @"value": @1800},
        @{@"label": @"1 小时", @"value": @3600}
    ];

    for (NSDictionary *preset in timerPresets) {
        NSTimeInterval interval = [preset[@"value"] doubleValue];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:preset[@"label"]
                                                      action:@selector(setMirrorAutoUnpinTimer:)
                                               keyEquivalent:@""];
        item.target = self;
        BOOL selected = interval <= 0 ? !mirror.hasAutoUnpinTimer : fabs(mirror.autoUnpinInterval - interval) < 0.001;
        item.state = selected ? NSControlStateValueOn : NSControlStateValueOff;
        item.representedObject = [FWMirrorCommand commandWithWindowID:mirror.windowID autoUnpinInterval:interval];
        [timerMenu addItem:item];
    }
    timerItem.submenu = timerMenu;
    [menu addItem:timerItem];

    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *closeItem = [[NSMenuItem alloc] initWithTitle:@"关闭固定窗口"
                                                       action:@selector(closeMirror:)
                                                keyEquivalent:@""];
    closeItem.target = self;
    closeItem.representedObject = [FWMirrorCommand commandWithWindowID:mirror.windowID];
    [menu addItem:closeItem];

    return menu;
}

- (void)refreshMenu:(NSMenuItem *)sender {
    (void)sender;
    [self rebuildMenu];
}

- (void)requestScreenCapturePermission:(NSMenuItem *)sender {
    (void)sender;
    CGRequestScreenCaptureAccess();
    [self rebuildMenu];
}

- (void)requestAccessibilityPermission:(NSMenuItem *)sender {
    (void)sender;
    FWAccessibilityTrusted(YES);
    [self rebuildMenu];
}

- (void)openScreenRecordingSettings:(NSMenuItem *)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)openAccessibilitySettings:(NSMenuItem *)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [NSWorkspace.sharedWorkspace openURL:url];
}

#pragma mark - Automation Commands

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    (void)replyEvent;
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString ?: @""];
    if (!components) {
        NSBeep();
        return;
    }

    NSString *command = components.host;
    if (command.length == 0 && components.path.length > 1) {
        command = [components.path substringFromIndex:1];
    }

    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *queryItem in components.queryItems) {
        if (queryItem.name.length == 0 || queryItem.value.length == 0) {
            continue;
        }
        userInfo[queryItem.name] = queryItem.value;
    }

    if (![self performAutomationCommand:command userInfo:userInfo]) {
        NSBeep();
    }
}

- (BOOL)performAutomationCommand:(NSString *)command userInfo:(NSDictionary *)userInfo {
    if ([command isEqualToString:FWAutomationPinFrontmostCommand]) {
        [self pinFrontmostWindow:nil];
        return YES;
    }

    if ([command isEqualToString:FWAutomationToggleFrontmostCommand]) {
        [self toggleFrontmostWindow:nil];
        return YES;
    }

    if ([command isEqualToString:FWAutomationCloseAllCommand]) {
        [self closeAllMirrors:nil];
        return YES;
    }

    if ([command isEqualToString:FWAutomationRefreshMenuCommand] || [command isEqualToString:@"refresh"]) {
        [self rebuildMenu];
        return YES;
    }

    if ([command isEqualToString:FWAutomationQuitCommand]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSApp terminate:nil];
        });
        return YES;
    }

    if ([command isEqualToString:FWAutomationPinWindowCommand] ||
        [command isEqualToString:FWAutomationUnpinWindowCommand] ||
        [command isEqualToString:FWAutomationToggleWindowCommand]) {
        NSNumber *windowIDNumber = [self automationWindowIDFromUserInfo:userInfo];
        if (!windowIDNumber) {
            return NO;
        }

        CGWindowID windowID = (CGWindowID)windowIDNumber.unsignedIntValue;
        if ([command isEqualToString:FWAutomationUnpinWindowCommand]) {
            [self unpinMirrorForWindowID:windowID];
            [self rebuildMenu];
            return YES;
        }

        FWWindowInfo *windowInfo = [FWWindowLister windowWithID:windowID];
        if (!windowInfo) {
            return NO;
        }

        if ([command isEqualToString:FWAutomationPinWindowCommand]) {
            [self pinMirrorForWindowInfo:windowInfo];
        } else {
            [self toggleMirrorForWindowInfo:windowInfo];
        }
        [self rebuildMenu];
        return YES;
    }

    return NO;
}

- (NSNumber *)automationWindowIDFromUserInfo:(NSDictionary *)userInfo {
    id value = userInfo[FWAutomationWindowIDKey];
    if ([value isKindOfClass:NSNumber.class]) {
        return value;
    }
    if (![value isKindOfClass:NSString.class]) {
        return nil;
    }

    unsigned long long parsedValue = strtoull([value UTF8String], NULL, 10);
    if (parsedValue == 0 || parsedValue > UINT32_MAX) {
        return nil;
    }
    return @((uint32_t)parsedValue);
}

#pragma mark - Mirror Management

- (void)pinWindow:(NSMenuItem *)sender {
    FWWindowInfo *windowInfo = sender.representedObject;
    if (![windowInfo isKindOfClass:FWWindowInfo.class]) {
        return;
    }

    [self toggleMirrorForWindowInfo:windowInfo];
    [self rebuildMenu];
}

- (FWWindowInfo *)frontmostWindowInfo {
    NSRunningApplication *frontmostApplication = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (!frontmostApplication) {
        return nil;
    }

    return [FWWindowLister frontmostWindowForPID:frontmostApplication.processIdentifier];
}

- (void)pinFrontmostWindow:(id)sender {
    (void)sender;
    FWWindowInfo *windowInfo = [self frontmostWindowInfo];
    if (!windowInfo) {
        NSBeep();
        return;
    }

    [self pinMirrorForWindowInfo:windowInfo];
    [self rebuildMenu];
}

- (void)toggleMirrorForWindowInfo:(FWWindowInfo *)windowInfo {
    NSNumber *key = @(windowInfo.windowID);
    FWMirrorController *existingMirror = self.mirrors[key];
    if (existingMirror) {
        [self unpinMirrorForWindowID:windowInfo.windowID];
    } else {
        [self pinMirrorForWindowInfo:windowInfo];
    }
}

- (void)pinMirrorForWindowInfo:(FWWindowInfo *)windowInfo {
    NSNumber *key = @(windowInfo.windowID);
    if (self.mirrors[key]) {
        return;
    }

    [self closeAllMirrors:nil];
    FWMirrorController *mirror = [[FWMirrorController alloc] initWithWindowInfo:windowInfo];
    mirror.delegate = self;
    [mirror setMirrorOpacity:self.globalOpacity];
    self.mirrors[key] = mirror;
    [self updateModifierOperateStateFromFlags:NSEvent.modifierFlags];
}

- (void)unpinMirrorForWindowID:(CGWindowID)windowID {
    NSNumber *key = @(windowID);
    FWMirrorController *mirror = self.mirrors[key];
    [mirror stop];
    [self.mirrors removeObjectForKey:key];
}

- (void)toggleFrontmostWindow:(id)sender {
    (void)sender;
    FWWindowInfo *windowInfo = [self frontmostWindowInfo];
    if (!windowInfo) {
        NSBeep();
        return;
    }

    [self toggleMirrorForWindowInfo:windowInfo];
    [self rebuildMenu];
}

#pragma mark - Mirror Delegate

- (void)mirrorControllerDidLoseSourceWindow:(FWMirrorController *)mirror {
    NSNumber *key = @(mirror.windowID);
    if (self.mirrors[key] != mirror) {
        return;
    }

    [mirror stop];
    [self.mirrors removeObjectForKey:key];
    [self rebuildMenu];
}

- (void)mirrorControllerAutoUnpinTimerDidFire:(FWMirrorController *)mirror {
    NSNumber *key = @(mirror.windowID);
    if (self.mirrors[key] != mirror) {
        return;
    }

    [mirror stop];
    [self.mirrors removeObjectForKey:key];
    [self rebuildMenu];
}

- (void)mirrorController:(FWMirrorController *)mirror adjustOpacityBy:(CGFloat)delta {
    NSNumber *key = @(mirror.windowID);
    if (self.mirrors[key] != mirror) {
        return;
    }

    [self applyGlobalOpacity:self.globalOpacity + delta scheduleMenuRefresh:YES];
}

#pragma mark - Opacity and Timers

- (void)applyGlobalOpacity:(CGFloat)opacity scheduleMenuRefresh:(BOOL)scheduleMenuRefresh {
    CGFloat clampedOpacity = MAX(0.01, MIN(1.0, opacity));
    if (fabs(clampedOpacity - self.globalOpacity) < 0.001) {
        return;
    }

    self.globalOpacity = clampedOpacity;
    for (FWMirrorController *mirror in self.mirrors.allValues.copy) {
        [mirror setMirrorOpacity:clampedOpacity];
    }
    if (scheduleMenuRefresh) {
        [self scheduleOpacityMenuRefresh];
    }
}

- (void)scheduleOpacityMenuRefresh {
    if (self.opacityMenuRefreshScheduled) {
        return;
    }

    self.opacityMenuRefreshScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.opacityMenuRefreshScheduled = NO;
        [self rebuildMenu];
    });
}

- (void)setMirrorOpacity:(NSMenuItem *)sender {
    FWMirrorCommand *command = sender.representedObject;
    if (![command isKindOfClass:FWMirrorCommand.class] || !command.hasOpacity) {
        return;
    }

    [self applyGlobalOpacity:command.opacity scheduleMenuRefresh:NO];
    [self rebuildMenu];
}

- (void)setGlobalOpacityFromSlider:(NSSlider *)sender {
    [self applyGlobalOpacity:sender.doubleValue / 100.0 scheduleMenuRefresh:NO];
}

- (void)setMirrorAutoUnpinTimer:(NSMenuItem *)sender {
    FWMirrorCommand *command = sender.representedObject;
    if (![command isKindOfClass:FWMirrorCommand.class] || !command.hasAutoUnpinInterval) {
        return;
    }

    FWMirrorController *mirror = self.mirrors[@(command.windowID)];
    [mirror setAutoUnpinInterval:command.autoUnpinInterval];
    [self rebuildMenu];
}

- (void)toggleClickThrough:(NSMenuItem *)sender {
    FWMirrorCommand *command = sender.representedObject;
    if (![command isKindOfClass:FWMirrorCommand.class]) {
        return;
    }

    FWMirrorController *mirror = self.mirrors[@(command.windowID)];
    [mirror toggleClickThrough];
    [self rebuildMenu];
}

#pragma mark - Closing

- (void)closeMirror:(NSMenuItem *)sender {
    FWMirrorCommand *command = sender.representedObject;
    if (![command isKindOfClass:FWMirrorCommand.class]) {
        return;
    }

    NSNumber *key = @(command.windowID);
    FWMirrorController *mirror = self.mirrors[key];
    [mirror stop];
    [self.mirrors removeObjectForKey:key];
    [self rebuildMenu];
}

- (void)closeAllMirrors:(NSMenuItem *)sender {
    (void)sender;
    for (FWMirrorController *mirror in self.mirrors.allValues) {
        [mirror stop];
    }
    [self.mirrors removeAllObjects];
    [self rebuildMenu];
}

- (void)quit:(NSMenuItem *)sender {
    (void)sender;
    [NSApp terminate:nil];
}
@end

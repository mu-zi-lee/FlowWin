#import "FWMirrorController.h"
#import "FWAccessibility.h"
#import "FWGeometry.h"

#pragma mark - Mirror Views

@interface FWMirrorContentView : NSView
@property(nonatomic, weak) id<FWMirrorInteraction> mirror;
@property(nonatomic, assign) BOOL forwardingSourceMouse;
@property(nonatomic, assign) BOOL movingPinnedWindow;
@end

@interface FWMirrorChromeView : NSView
@property(nonatomic, weak) id<FWMirrorInteraction> mirror;
@end

@implementation FWMirrorContentView
- (BOOL)isOpaque {
    return NO;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    (void)event;
    return YES;
}

- (BOOL)acceptsMirrorInteraction {
    return !self.mirror.clickThrough || self.mirror.modifierOperateActive || self.mirror.modifierMoveActive;
}

- (NSView *)hitTest:(NSPoint)point {
    if (![self acceptsMirrorInteraction]) {
        return nil;
    }
    return [super hitTest:point] ? self : nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
}

- (void)mouseDown:(NSEvent *)event {
    if (![self acceptsMirrorInteraction]) {
        return;
    }

    BOOL optionDrag = (event.modifierFlags & NSEventModifierFlagOption) == NSEventModifierFlagOption;
    if (self.mirror.modifierMoveActive || optionDrag) {
        self.movingPinnedWindow = [self.mirror beginMovingPinnedWindowAtMouseLocation:NSEvent.mouseLocation];
        return;
    }

    self.forwardingSourceMouse = [self.mirror forwardSourceMouseEvent:event
                                                             fromView:self
                                                            eventType:kCGEventLeftMouseDown];
}

- (void)mouseDragged:(NSEvent *)event {
    if (self.movingPinnedWindow) {
        [self.mirror movePinnedWindowToMouseLocation:NSEvent.mouseLocation];
        return;
    }

    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventLeftMouseDragged];
    }
}

- (void)mouseUp:(NSEvent *)event {
    if (self.movingPinnedWindow) {
        [self.mirror endMovingPinnedWindow];
    }
    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventLeftMouseUp];
    }
    self.movingPinnedWindow = NO;
    self.forwardingSourceMouse = NO;
}

- (void)rightMouseDown:(NSEvent *)event {
    if (![self acceptsMirrorInteraction] || self.mirror.modifierMoveActive) {
        return;
    }

    self.forwardingSourceMouse = [self.mirror forwardSourceMouseEvent:event
                                                             fromView:self
                                                            eventType:kCGEventRightMouseDown];
}

- (void)rightMouseDragged:(NSEvent *)event {
    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventRightMouseDragged];
    }
}

- (void)rightMouseUp:(NSEvent *)event {
    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventRightMouseUp];
    }
    self.forwardingSourceMouse = NO;
}

- (void)otherMouseDown:(NSEvent *)event {
    if (![self acceptsMirrorInteraction] || self.mirror.modifierMoveActive) {
        return;
    }

    self.forwardingSourceMouse = [self.mirror forwardSourceMouseEvent:event
                                                             fromView:self
                                                            eventType:kCGEventOtherMouseDown];
}

- (void)otherMouseDragged:(NSEvent *)event {
    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventOtherMouseDragged];
    }
}

- (void)otherMouseUp:(NSEvent *)event {
    if (self.forwardingSourceMouse) {
        [self.mirror forwardSourceMouseEvent:event
                                    fromView:self
                                   eventType:kCGEventOtherMouseUp];
    }
    self.forwardingSourceMouse = NO;
}

- (void)scrollWheel:(NSEvent *)event {
    BOOL optionScroll = (event.modifierFlags & NSEventModifierFlagOption) == NSEventModifierFlagOption;
    if (optionScroll) {
        [self.mirror adjustOpacityWithScrollEvent:event];
        return;
    }

    if (![self acceptsMirrorInteraction] || self.mirror.modifierMoveActive) {
        return;
    }
    [self.mirror forwardSourceScrollEvent:event fromView:self];
}
@end

@implementation FWMirrorChromeView
- (BOOL)isOpaque {
    return NO;
}

- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = self.bounds;
    if (NSIsEmptyRect(bounds)) {
        return;
    }

    NSColor *modeColor = [NSColor colorWithWhite:1.0 alpha:0.36];
    if (self.mirror.modifierMoveActive) {
        modeColor = [NSColor systemBlueColor];
    } else if (self.mirror.commandHoldActive) {
        modeColor = [NSColor systemGreenColor];
    } else if (self.mirror.modifierOperateActive) {
        modeColor = [NSColor systemOrangeColor];
    }
    NSString *status = [NSString stringWithFormat:@"%.0f%%", self.mirror.opacity * 100.0];
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:1.0 alpha:0.88]
    };

    NSSize textSize = [status sizeWithAttributes:attributes];
    CGFloat pillWidth = MIN(NSWidth(bounds) - 16.0, MAX(52.0, ceil(textSize.width) + 24.0));
    if (pillWidth >= 44.0) {
        CGFloat pillHeight = 22.0;
        NSRect pillRect = NSMakeRect(NSMinX(bounds) + 8.0,
                                     NSMaxY(bounds) - pillHeight - 8.0,
                                     pillWidth,
                                     pillHeight);
        NSBezierPath *pill = [NSBezierPath bezierPathWithRoundedRect:pillRect
                                                             xRadius:9.0
                                                             yRadius:9.0];
        [[NSColor colorWithWhite:0.0 alpha:0.52] setFill];
        [pill fill];

        NSRect dotRect = NSMakeRect(NSMinX(pillRect) + 8.0,
                                    NSMidY(pillRect) - 2.0,
                                    4.0,
                                    4.0);
        NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:dotRect];
        [modeColor setFill];
        [dot fill];

        [status drawInRect:NSMakeRect(NSMinX(pillRect) + 16.0,
                                      NSMidY(pillRect) - textSize.height / 2.0,
                                      NSWidth(pillRect) - 22.0,
                                      textSize.height)
            withAttributes:attributes];
    }
}
@end

@interface FWMirrorController () <SCStreamOutput, SCStreamDelegate>
@property(nonatomic, assign, readwrite) CGWindowID windowID;
@property(nonatomic, assign, readwrite) pid_t ownerPID;
@property(nonatomic, copy, readwrite) NSString *label;
@property(nonatomic, assign, readwrite) CGFloat opacity;
@property(nonatomic, assign, readwrite) BOOL clickThrough;
@property(nonatomic, assign, readwrite) BOOL attachedToSource;
@property(nonatomic, assign, readwrite) BOOL modifierOperateActive;
@property(nonatomic, assign, readwrite) BOOL modifierMoveActive;
@property(nonatomic, assign, readwrite) BOOL commandHoldActive;
@property(nonatomic, assign, readwrite) BOOL nativeControlActive;
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) FWMirrorContentView *mirrorContentView;
@property(nonatomic, strong) NSImageView *imageView;
@property(nonatomic, strong) FWMirrorChromeView *chromeView;
@property(nonatomic, strong) NSTextField *placeholderLabel;
@property(nonatomic, strong) NSWindow *backdropWindow;
@property(nonatomic, strong) NSImageView *backdropImageView;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) NSTimer *autoUnpinTimer;
@property(nonatomic, strong) NSTimer *backdropRefreshTimer;
@property(nonatomic, strong) NSDate *autoUnpinDeadline;
@property(nonatomic, strong) SCStream *captureStream;
@property(nonatomic, strong) dispatch_queue_t captureQueue;
@property(nonatomic, strong) CIContext *ciContext;
@property(nonatomic, assign) BOOL streamCaptureActive;
@property(nonatomic, assign) BOOL streamCaptureStarting;
@property(nonatomic, assign) BOOL streamConfigurationUpdating;
@property(nonatomic, assign) BOOL needsStreamConfigurationUpdate;
@property(nonatomic, assign) BOOL streamFrameDisplayPending;
@property(nonatomic, assign) NSSize streamConfigurationSize;
@property(nonatomic, assign) NSTimeInterval refreshInterval;
@property(nonatomic, assign) NSTimeInterval autoUnpinInterval;
@property(nonatomic, assign) NSRect sourceFrame;
@property(nonatomic, assign) CGRect sourceQuartzBounds;
@property(nonatomic, assign) AXUIElementRef sourceAXWindow;
@property(nonatomic, assign) CGImageRef cachedSourceMaskImage;
@property(nonatomic, assign) BOOL sourceWindowParked;
@property(nonatomic, assign) BOOL sourceRestoreFrameValid;
@property(nonatomic, assign) CGPoint sourceRestorePosition;
@property(nonatomic, assign) CGSize sourceRestoreSize;
@property(nonatomic, assign) NSRect pinnedFrame;
@property(nonatomic, assign) BOOL movingPinnedWindow;
@property(nonatomic, assign) BOOL commandHoldMouseDown;
@property(nonatomic, assign) NSPoint moveStartMouseLocation;
@property(nonatomic, assign) NSRect moveStartPinnedFrame;
- (void)startStreamCapture;
- (void)stopStreamCapture;
- (void)restartStreamCapture;
- (void)updateStreamCaptureConfigurationForSize:(NSSize)size;
- (BOOL)beginStreamFrameDisplayIfPossible;
- (void)finishStreamFrameDisplay;
- (NSTimeInterval)desiredRefreshInterval;
- (void)updateRefreshTimerIfNeeded;
- (void)parkSourceWindowIfPossible;
- (void)enforceSourceWindowParkingIfNeededWithBounds:(CGRect)updatedQuartzBounds;
- (void)restoreSourceWindowIfNeeded;
- (void)releaseSourceAXWindow;
- (BOOL)moveSourceWindowToPinnedFrame;
- (void)updateNativeControlFramesFromSourceBounds:(CGRect)sourceBounds;
- (void)refreshBackdropImage;
- (NSImage *)maskedBackdropImageWithBackground:(NSImage *)backgroundImage;
- (CGImageRef)newSourceMaskImage;
- (CGImageRef)copySourceMaskImage;
- (void)invalidateSourceMaskImage;
- (NSImage *)captureBackdropImageBehindWindowNumber:(CGWindowID)windowNumber frame:(NSRect)frame;
@end

typedef struct {
    NSUInteger count;
    CFTimeInterval totalDuration;
} FWPerfMetric;

static FWPerfMetric FWPerfRefreshMetric = {0, 0};
static FWPerfMetric FWPerfFallbackCaptureMetric = {0, 0};
static FWPerfMetric FWPerfStreamFrameMetric = {0, 0};
static FWPerfMetric FWPerfBackdropMetric = {0, 0};
static FWPerfMetric FWPerfNativeControlMetric = {0, 0};
static CFTimeInterval FWPerfLastReportTime = 0;

static BOOL FWPerfEnabled(void) {
    static BOOL initialized = NO;
    static BOOL enabled = NO;
    if (!initialized) {
        NSString *value = NSProcessInfo.processInfo.environment[@"FLOWWIN_PERF"];
        enabled = value.length > 0 && ![value isEqualToString:@"0"];
        initialized = YES;
    }
    return enabled;
}

static void FWPerfResetMetrics(void) {
    FWPerfRefreshMetric = (FWPerfMetric){0, 0};
    FWPerfFallbackCaptureMetric = (FWPerfMetric){0, 0};
    FWPerfStreamFrameMetric = (FWPerfMetric){0, 0};
    FWPerfBackdropMetric = (FWPerfMetric){0, 0};
    FWPerfNativeControlMetric = (FWPerfMetric){0, 0};
}

static double FWPerfAverageMilliseconds(FWPerfMetric metric) {
    return metric.count == 0 ? 0 : (metric.totalDuration / (double)metric.count) * 1000.0;
}

static void FWPerfReportIfNeeded(CFTimeInterval now) {
    if (FWPerfLastReportTime <= 0) {
        FWPerfLastReportTime = now;
        return;
    }

    CFTimeInterval elapsed = now - FWPerfLastReportTime;
    if (elapsed < 5.0) {
        return;
    }

    double streamFPS = elapsed > 0 ? (double)FWPerfStreamFrameMetric.count / elapsed : 0;
    NSLog(@"FlowWin perf: refresh=%lu avg=%.2fms fallback=%lu avg=%.2fms stream=%.1ffps backdrop=%lu avg=%.2fms native=%lu avg=%.2fms",
          (unsigned long)FWPerfRefreshMetric.count,
          FWPerfAverageMilliseconds(FWPerfRefreshMetric),
          (unsigned long)FWPerfFallbackCaptureMetric.count,
          FWPerfAverageMilliseconds(FWPerfFallbackCaptureMetric),
          streamFPS,
          (unsigned long)FWPerfBackdropMetric.count,
          FWPerfAverageMilliseconds(FWPerfBackdropMetric),
          (unsigned long)FWPerfNativeControlMetric.count,
          FWPerfAverageMilliseconds(FWPerfNativeControlMetric));
    FWPerfResetMetrics();
    FWPerfLastReportTime = now;
}

static void FWPerfRecord(FWPerfMetric *metric, CFTimeInterval duration) {
    if (!FWPerfEnabled()) {
        return;
    }

    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    @synchronized (FWMirrorController.class) {
        metric->count += 1;
        metric->totalDuration += duration;
        FWPerfReportIfNeeded(now);
    }
}

@implementation FWMirrorController

#pragma mark - Lifecycle

- (instancetype)initWithWindowInfo:(FWWindowInfo *)windowInfo {
    self = [super init];
    if (!self) {
        return nil;
    }

    _windowID = windowInfo.windowID;
    _ownerPID = windowInfo.ownerPID;
    _label = windowInfo.displayName.copy;
    _opacity = FlowWinDefaultOpacity;
    _clickThrough = YES;
    _attachedToSource = YES;

    _pinnedFrame = FWCocoaFrameFromQuartzBounds(windowInfo.quartzBounds);
    _sourceFrame = _pinnedFrame;
    _sourceQuartzBounds = windowInfo.quartzBounds;
    _window = [[NSWindow alloc] initWithContentRect:_pinnedFrame
                                          styleMask:NSWindowStyleMaskBorderless
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _captureQueue = dispatch_queue_create("local.flowwin.capture", DISPATCH_QUEUE_SERIAL);
    _ciContext = [CIContext contextWithOptions:nil];
    _imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _chromeView = [[FWMirrorChromeView alloc] initWithFrame:NSZeroRect];
    _placeholderLabel = [NSTextField labelWithString:@"请授予屏幕录制权限，然后重新启动 FlowWin。"];

    [self configureWindow];
    [self startStreamCapture];
    [self parkSourceWindowIfPossible];
    [self startRefreshing];
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)configureWindow {
    FWMirrorContentView *contentView = [[FWMirrorContentView alloc] initWithFrame:NSMakeRect(0,
                                                                                            0,
                                                                                            NSWidth(self.window.frame),
                                                                                            NSHeight(self.window.frame))];
    contentView.mirror = self;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.mirrorContentView = contentView;

    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.imageView.imageAlignment = NSImageAlignCenter;
    self.imageView.wantsLayer = YES;
    self.imageView.layer.magnificationFilter = kCAFilterTrilinear;
    self.imageView.layer.minificationFilter = kCAFilterTrilinear;
    self.imageView.layer.zPosition = 0;
    self.imageView.alphaValue = self.opacity;

    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.alignment = NSTextAlignmentCenter;
    self.placeholderLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.placeholderLabel.maximumNumberOfLines = 3;
    self.placeholderLabel.textColor = NSColor.secondaryLabelColor;
    self.placeholderLabel.hidden = YES;

    self.chromeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chromeView.mirror = self;
    self.chromeView.wantsLayer = YES;
    self.chromeView.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.chromeView.layer.zPosition = 10;

    [contentView addSubview:self.imageView];
    [contentView addSubview:self.placeholderLabel];
    [contentView addSubview:self.chromeView];

    [NSLayoutConstraint activateConstraints:@[
        [self.imageView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.imageView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [self.placeholderLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:16],
        [self.placeholderLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-16],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:contentView.centerYAnchor],
        [self.chromeView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.chromeView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.chromeView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.chromeView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    self.window.contentView = contentView;
    self.window.opaque = NO;
    self.window.backgroundColor = NSColor.clearColor;
    self.window.hasShadow = NO;
    self.window.acceptsMouseMovedEvents = YES;
    self.window.level = NSScreenSaverWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                     NSWindowCollectionBehaviorFullScreenAuxiliary |
                                     NSWindowCollectionBehaviorStationary;
    self.window.alphaValue = 1.0;
    [self updateWindowInteraction];
    [self.window orderFrontRegardless];
}

#pragma mark - Refresh

- (NSTimeInterval)desiredRefreshInterval {
    if (self.nativeControlActive) {
        return FWMirrorInteractiveRefreshInterval;
    }
    if (self.streamCaptureActive || self.streamCaptureStarting) {
        return FWMirrorStreamRefreshInterval;
    }
    return FWMirrorFallbackRefreshInterval;
}

- (void)startRefreshing {
    [self refresh];
    __weak typeof(self) weakSelf = self;
    self.refreshInterval = [self desiredRefreshInterval];
    self.timer = [NSTimer timerWithTimeInterval:self.refreshInterval
                                        repeats:YES
                                          block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf refresh];
    }];
    self.timer.tolerance = self.refreshInterval >= 0.5 ? 0.1 : 0.02;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)updateRefreshTimerIfNeeded {
    NSTimeInterval desiredInterval = [self desiredRefreshInterval];
    if (self.timer && fabs(self.refreshInterval - desiredInterval) < 0.001) {
        return;
    }

    [self.timer invalidate];
    self.timer = nil;
    self.refreshInterval = desiredInterval;

    __weak typeof(self) weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:desiredInterval
                                        repeats:YES
                                          block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf refresh];
    }];
    self.timer.tolerance = desiredInterval >= 0.5 ? 0.1 : 0.02;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)refresh {
    CFTimeInterval refreshStart = FWPerfEnabled() ? CFAbsoluteTimeGetCurrent() : 0;
    FWWindowInfo *updatedInfo = [FWWindowLister windowWithID:self.windowID];
    if (!updatedInfo) {
        FWPerfRecord(&FWPerfRefreshMetric, refreshStart > 0 ? CFAbsoluteTimeGetCurrent() - refreshStart : 0);
        [self.delegate mirrorControllerDidLoseSourceWindow:self];
        return;
    }

    self.label = updatedInfo.displayName;
    if (!self.nativeControlActive && !self.movingPinnedWindow && !NSEqualRects(self.window.frame, self.pinnedFrame)) {
        [self.window setFrame:self.pinnedFrame display:YES];
    }

    CGRect updatedQuartzBounds = updatedInfo.quartzBounds;
    if (self.nativeControlActive) {
        [self updateNativeControlFramesFromSourceBounds:updatedQuartzBounds];
    } else {
        [self enforceSourceWindowParkingIfNeededWithBounds:updatedQuartzBounds];
        updatedQuartzBounds = self.sourceWindowParked ? self.sourceQuartzBounds : updatedQuartzBounds;
    }
    self.sourceQuartzBounds = updatedQuartzBounds;
    CGFloat updatedWidth = CGRectGetWidth(updatedQuartzBounds);
    CGFloat updatedHeight = CGRectGetHeight(updatedQuartzBounds);
    if (fabs(updatedWidth - NSWidth(self.sourceFrame)) > 1.0 ||
        fabs(updatedHeight - NSHeight(self.sourceFrame)) > 1.0) {
        self.pinnedFrame = NSMakeRect(NSMinX(self.pinnedFrame),
                                      NSMinY(self.pinnedFrame),
                                      updatedWidth,
                                      updatedHeight);
        if (!self.movingPinnedWindow) {
            [self.window setFrame:self.pinnedFrame display:YES];
        }
        [self updateStreamCaptureConfigurationForSize:self.pinnedFrame.size];
    }
    self.sourceFrame = self.pinnedFrame;
    [self updateWindowInteraction];

    if (self.streamCaptureActive || self.streamCaptureStarting) {
        [self updateRefreshTimerIfNeeded];
        FWPerfRecord(&FWPerfRefreshMetric, refreshStart > 0 ? CFAbsoluteTimeGetCurrent() - refreshStart : 0);
        return;
    }

    CFTimeInterval fallbackStart = FWPerfEnabled() ? CFAbsoluteTimeGetCurrent() : 0;
    CGImageRef sourceImage = CGWindowListCreateImage(
        CGRectNull,
        kCGWindowListOptionIncludingWindow,
        self.windowID,
        kCGWindowImageBoundsIgnoreFraming | kCGWindowImageNominalResolution
    );
    FWPerfRecord(&FWPerfFallbackCaptureMetric, fallbackStart > 0 ? CFAbsoluteTimeGetCurrent() - fallbackStart : 0);

    if (!sourceImage) {
        if (!self.imageView.image) {
            self.placeholderLabel.hidden = NO;
        }
        FWPerfRecord(&FWPerfRefreshMetric, refreshStart > 0 ? CFAbsoluteTimeGetCurrent() - refreshStart : 0);
        return;
    }

    size_t imageWidth = CGImageGetWidth(sourceImage);
    size_t imageHeight = CGImageGetHeight(sourceImage);
    BOOL looksComplete = imageWidth + 2 >= (size_t)ceil(MAX(1.0, updatedWidth)) &&
                         imageHeight + 2 >= (size_t)ceil(MAX(1.0, updatedHeight));
    if (!looksComplete && self.imageView.image) {
        CGImageRelease(sourceImage);
        FWPerfRecord(&FWPerfRefreshMetric, refreshStart > 0 ? CFAbsoluteTimeGetCurrent() - refreshStart : 0);
        return;
    }

    self.placeholderLabel.hidden = YES;
    NSImage *image = [[NSImage alloc] initWithCGImage:sourceImage
                                                size:self.pinnedFrame.size];
    self.imageView.image = image;
    CGImageRelease(sourceImage);
    [self updateRefreshTimerIfNeeded];
    FWPerfRecord(&FWPerfRefreshMetric, refreshStart > 0 ? CFAbsoluteTimeGetCurrent() - refreshStart : 0);
}

- (void)setMirrorOpacity:(CGFloat)opacity {
    self.opacity = opacity;
    self.imageView.alphaValue = opacity;
    [self.chromeView setNeedsDisplay:YES];
}

#pragma mark - Capture

- (CGFloat)backingScaleFactorForPinnedFrame {
    NSPoint center = NSMakePoint(NSMidX(self.pinnedFrame), NSMidY(self.pinnedFrame));
    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(center, screen.frame) && screen.backingScaleFactor > 0) {
            return screen.backingScaleFactor;
        }
    }

    CGFloat scale = NSScreen.mainScreen.backingScaleFactor;
    return scale > 0 ? scale : 2.0;
}

- (SCStreamConfiguration *)streamConfigurationForSize:(NSSize)size {
    SCStreamConfiguration *configuration = [SCStreamConfiguration new];
    CGFloat scale = [self backingScaleFactorForPinnedFrame];
    CGFloat pixelWidth = MAX(1.0, ceil(size.width * scale));
    CGFloat pixelHeight = MAX(1.0, ceil(size.height * scale));
    CGFloat pixelArea = pixelWidth * pixelHeight;
    if (pixelArea > FWStreamMaxPixelArea) {
        CGFloat areaScale = sqrt(FWStreamMaxPixelArea / pixelArea);
        pixelWidth = MAX(1.0, floor(pixelWidth * areaScale));
        pixelHeight = MAX(1.0, floor(pixelHeight * areaScale));
    }

    configuration.width = (size_t)pixelWidth;
    configuration.height = (size_t)pixelHeight;
    configuration.pixelFormat = kCVPixelFormatType_32BGRA;
    configuration.minimumFrameInterval = CMTimeMake(1, FWStreamTargetFrameRate);
    configuration.queueDepth = 3;
    configuration.showsCursor = NO;
    configuration.scalesToFit = YES;
    return configuration;
}

- (BOOL)streamConfigurationSizeMatchesSize:(NSSize)size {
    return fabs(self.streamConfigurationSize.width - size.width) <= 1.0 &&
           fabs(self.streamConfigurationSize.height - size.height) <= 1.0;
}

- (void)startStreamCapture {
    if (self.streamCaptureStarting || self.captureStream) {
        return;
    }
    if (@available(macOS 12.3, *)) {
        self.streamCaptureStarting = YES;
        __weak typeof(self) weakSelf = self;
        [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                                    onScreenWindowsOnly:NO
                                                      completionHandler:^(SCShareableContent *shareableContent, NSError *error) {
            FWMirrorController *mirror = weakSelf;
            if (!mirror) {
                return;
            }
            if (error || !shareableContent) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    mirror.streamCaptureStarting = NO;
                    [mirror updateRefreshTimerIfNeeded];
                });
                return;
            }

            SCWindow *targetWindow = nil;
            for (SCWindow *window in shareableContent.windows) {
                if (window.windowID == mirror.windowID) {
                    targetWindow = window;
                    break;
                }
            }

            if (!targetWindow) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    mirror.streamCaptureStarting = NO;
                    [mirror updateRefreshTimerIfNeeded];
                });
                return;
            }

            SCContentFilter *filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:targetWindow];
            NSSize captureSize = mirror.pinnedFrame.size;
            SCStreamConfiguration *configuration = [mirror streamConfigurationForSize:captureSize];

            SCStream *stream = [[SCStream alloc] initWithFilter:filter configuration:configuration delegate:mirror];
            NSError *outputError = nil;
            if (![stream addStreamOutput:mirror type:SCStreamOutputTypeScreen sampleHandlerQueue:mirror.captureQueue error:&outputError]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    mirror.streamCaptureStarting = NO;
                    [mirror updateRefreshTimerIfNeeded];
                });
                return;
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                mirror.captureStream = stream;
                [stream startCaptureWithCompletionHandler:^(NSError *startError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        mirror.streamCaptureStarting = NO;
                        mirror.streamCaptureActive = startError == nil;
                        if (startError) {
                            mirror.captureStream = nil;
                            mirror.streamConfigurationSize = NSZeroSize;
                        } else {
                            mirror.streamConfigurationSize = captureSize;
                            [mirror updateStreamCaptureConfigurationForSize:mirror.pinnedFrame.size];
                        }
                        [mirror updateRefreshTimerIfNeeded];
                    });
                }];
            });
        }];
    }
}

- (void)stopStreamCapture {
    SCStream *stream = self.captureStream;
    self.captureStream = nil;
    self.streamCaptureActive = NO;
    self.streamCaptureStarting = NO;
    self.streamConfigurationUpdating = NO;
    self.needsStreamConfigurationUpdate = NO;
    [self finishStreamFrameDisplay];
    self.streamConfigurationSize = NSZeroSize;
    if (stream) {
        [stream stopCaptureWithCompletionHandler:nil];
    }
}

- (void)restartStreamCapture {
    [self stopStreamCapture];
    [self startStreamCapture];
}

- (void)updateStreamCaptureConfigurationForSize:(NSSize)size {
    if (!self.captureStream || !self.streamCaptureActive) {
        return;
    }
    if ([self streamConfigurationSizeMatchesSize:size]) {
        return;
    }
    if (self.streamConfigurationUpdating) {
        self.needsStreamConfigurationUpdate = YES;
        return;
    }

    self.streamConfigurationUpdating = YES;
    SCStream *stream = self.captureStream;
    SCStreamConfiguration *configuration = [self streamConfigurationForSize:size];
    __weak typeof(self) weakSelf = self;
    [stream updateConfiguration:configuration completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            FWMirrorController *mirror = weakSelf;
            if (!mirror || mirror.captureStream != stream) {
                return;
            }

            mirror.streamConfigurationUpdating = NO;
            if (error) {
                [mirror restartStreamCapture];
                return;
            }

            mirror.streamConfigurationSize = size;
            if (mirror.needsStreamConfigurationUpdate ||
                ![mirror streamConfigurationSizeMatchesSize:mirror.pinnedFrame.size]) {
                mirror.needsStreamConfigurationUpdate = NO;
                [mirror updateStreamCaptureConfigurationForSize:mirror.pinnedFrame.size];
            }
        });
    }];
}

- (BOOL)beginStreamFrameDisplayIfPossible {
    @synchronized (self) {
        if (self.streamFrameDisplayPending) {
            return NO;
        }
        self.streamFrameDisplayPending = YES;
        return YES;
    }
}

- (void)finishStreamFrameDisplay {
    @synchronized (self) {
        self.streamFrameDisplayPending = NO;
    }
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    CFTimeInterval frameStart = FWPerfEnabled() ? CFAbsoluteTimeGetCurrent() : 0;
    if (type != SCStreamOutputTypeScreen || !sampleBuffer || !CMSampleBufferIsValid(sampleBuffer)) {
        return;
    }

    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachmentsArray && CFArrayGetCount(attachmentsArray) > 0) {
        CFDictionaryRef attachments = CFArrayGetValueAtIndex(attachmentsArray, 0);
        NSNumber *status = (__bridge NSNumber *)CFDictionaryGetValue(attachments, (__bridge const void *)SCStreamFrameInfoStatus);
        if (status && status.integerValue != SCFrameStatusComplete && status.integerValue != SCFrameStatusStarted) {
            return;
        }
    }

    if (![self beginStreamFrameDisplayIfPossible]) {
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) {
        [self finishStreamFrameDisplay];
        return;
    }

    CIImage *ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
    if (!ciImage) {
        [self finishStreamFrameDisplay];
        return;
    }

    CGImageRef cgImage = [self.ciContext createCGImage:ciImage fromRect:ciImage.extent];
    if (!cgImage) {
        [self finishStreamFrameDisplay];
        return;
    }
    FWPerfRecord(&FWPerfStreamFrameMetric, frameStart > 0 ? CFAbsoluteTimeGetCurrent() - frameStart : 0);

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        FWMirrorController *mirror = weakSelf;
        if (!mirror || mirror.captureStream != stream) {
            CGImageRelease(cgImage);
            [mirror finishStreamFrameDisplay];
            return;
        }

        mirror.placeholderLabel.hidden = YES;
        NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:mirror.pinnedFrame.size];
        mirror.imageView.image = image;
        CGImageRelease(cgImage);
        [mirror finishStreamFrameDisplay];
    });
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    (void)error;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.captureStream == stream) {
            self.captureStream = nil;
            self.streamCaptureActive = NO;
            self.streamCaptureStarting = NO;
            [self updateRefreshTimerIfNeeded];
        }
    });
}

#pragma mark - Auto Unpin

- (BOOL)hasAutoUnpinTimer {
    return self.autoUnpinTimer != nil;
}

- (NSString *)autoUnpinStatus {
    if (!self.autoUnpinDeadline) {
        return @"自动取消：关闭";
    }

    NSTimeInterval remaining = MAX(0, [self.autoUnpinDeadline timeIntervalSinceNow]);
    if (remaining < 60) {
        return @"自动取消：少于 1 分钟";
    }

    NSUInteger minutes = (NSUInteger)ceil(remaining / 60.0);
    if (minutes < 60) {
        return [NSString stringWithFormat:@"自动取消：%lu 分钟后", (unsigned long)minutes];
    }

    NSUInteger hours = minutes / 60;
    NSUInteger remainder = minutes % 60;
    if (remainder == 0) {
        return [NSString stringWithFormat:@"自动取消：%lu 小时后", (unsigned long)hours];
    }
    return [NSString stringWithFormat:@"自动取消：%lu 小时 %lu 分钟后", (unsigned long)hours, (unsigned long)remainder];
}

- (void)setAutoUnpinInterval:(NSTimeInterval)interval {
    [self.autoUnpinTimer invalidate];
    self.autoUnpinTimer = nil;
    self.autoUnpinDeadline = nil;
    _autoUnpinInterval = 0;

    if (interval <= 0) {
        return;
    }

    _autoUnpinInterval = interval;
    self.autoUnpinDeadline = [NSDate dateWithTimeIntervalSinceNow:interval];
    __weak typeof(self) weakSelf = self;
    self.autoUnpinTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          repeats:NO
                                                            block:^(NSTimer *timer) {
        (void)timer;
        FWMirrorController *mirror = weakSelf;
        if (!mirror) {
            return;
        }
        [mirror.delegate mirrorControllerAutoUnpinTimerDidFire:mirror];
    }];
}

- (void)toggleClickThrough {
    self.clickThrough = !self.clickThrough;
    [self updateWindowInteraction];
}

- (void)setModifierOperateActive:(BOOL)active {
    if (self.modifierOperateActive == active) {
        return;
    }

    _modifierOperateActive = active;
    [self updateWindowInteraction];
}

- (void)setModifierMoveActive:(BOOL)active {
    if (self.modifierMoveActive == active) {
        return;
    }

    _modifierMoveActive = active;
    [self updateWindowInteraction];
}

- (void)updateWindowInteraction {
    BOOL modifierActive = self.modifierOperateActive || self.modifierMoveActive;
    BOOL nextAttachedToSource = !self.sourceWindowParked;
    BOOL nextIgnoresMouseEvents = self.nativeControlActive || (!modifierActive && self.clickThrough);
    BOOL interactionChanged = self.attachedToSource != nextAttachedToSource ||
                              self.window.ignoresMouseEvents != nextIgnoresMouseEvents;

    self.attachedToSource = nextAttachedToSource;
    self.window.ignoresMouseEvents = nextIgnoresMouseEvents;
    self.window.hasShadow = NO;
    if (interactionChanged) {
        [self.chromeView setNeedsDisplay:YES];
    }
}

#pragma mark - Source Window Placement

- (void)parkSourceWindowIfPossible {
    if (self.sourceWindowParked || !FWAccessibilityTrusted(YES)) {
        return;
    }

    AXUIElementRef sourceWindow = FWCopyAXWindowForWindowID(self.ownerPID, self.windowID, self.sourceQuartzBounds);
    if (!sourceWindow) {
        NSLog(@"FlowWin: failed to find AX window for %u", self.windowID);
        return;
    }

    self.sourceAXWindow = sourceWindow;
    CGPoint position = CGPointMake(CGRectGetMinX(self.sourceQuartzBounds), CGRectGetMinY(self.sourceQuartzBounds));
    CGSize size = CGSizeMake(CGRectGetWidth(self.sourceQuartzBounds), CGRectGetHeight(self.sourceQuartzBounds));
    if (FWAXCopyCGPointAttribute(sourceWindow, kAXPositionAttribute, &position) &&
        FWAXCopyCGSizeAttribute(sourceWindow, kAXSizeAttribute, &size)) {
        self.sourceRestoreFrameValid = YES;
        self.sourceRestorePosition = position;
        self.sourceRestoreSize = size;
    } else if (!CGRectIsEmpty(self.sourceQuartzBounds)) {
        self.sourceRestoreFrameValid = YES;
        self.sourceRestorePosition = position;
        self.sourceRestoreSize = size;
    }

    CGRect parkedBounds = self.sourceQuartzBounds;
    if (!FWParkAXWindowOutsideDisplays(sourceWindow, self.sourceQuartzBounds, &parkedBounds)) {
        NSLog(@"FlowWin: failed to park source window %u", self.windowID);
        return;
    }

    self.sourceWindowParked = YES;
    self.sourceQuartzBounds = parkedBounds;
    [self updateWindowInteraction];
}

- (void)enforceSourceWindowParkingIfNeededWithBounds:(CGRect)updatedQuartzBounds {
    if (!self.sourceWindowParked || !self.sourceAXWindow) {
        return;
    }
    if (FWDisplayIntersectionArea(updatedQuartzBounds) <= 0.5) {
        return;
    }

    CGRect parkedBounds = updatedQuartzBounds;
    if (!FWParkAXWindowOutsideDisplays(self.sourceAXWindow, updatedQuartzBounds, &parkedBounds)) {
        return;
    }

    self.sourceQuartzBounds = parkedBounds;
}

- (void)restoreSourceWindowIfNeeded {
    if (!self.sourceWindowParked || !self.sourceAXWindow || !self.sourceRestoreFrameValid) {
        return;
    }

    FWAXSetCGSizeAttribute(self.sourceAXWindow, kAXSizeAttribute, self.sourceRestoreSize);
    FWAXSetCGPointAttribute(self.sourceAXWindow, kAXPositionAttribute, self.sourceRestorePosition);
    self.sourceWindowParked = NO;
}

- (BOOL)moveSourceWindowToPinnedFrame {
    if (!FWAccessibilityTrusted(YES)) {
        return NO;
    }

    if (!self.sourceAXWindow) {
        self.sourceAXWindow = FWCopyAXWindowForWindowID(self.ownerPID, self.windowID, self.sourceQuartzBounds);
        if (!self.sourceAXWindow) {
            NSLog(@"FlowWin: failed to find AX window for native control %u", self.windowID);
            return NO;
        }
    }

    CGRect targetBounds = FWQuartzBoundsFromCocoaFrame(self.pinnedFrame);
    CGSize targetSize = CGSizeMake(CGRectGetWidth(targetBounds), CGRectGetHeight(targetBounds));
    CGPoint targetPosition = CGPointMake(CGRectGetMinX(targetBounds), CGRectGetMinY(targetBounds));

    if (!FWAXSetCGSizeAttribute(self.sourceAXWindow, kAXSizeAttribute, targetSize)) {
        return NO;
    }
    if (!FWAXSetCGPointAttribute(self.sourceAXWindow, kAXPositionAttribute, targetPosition)) {
        return NO;
    }

    self.sourceWindowParked = NO;
    self.sourceQuartzBounds = FWAXWindowBounds(self.sourceAXWindow, targetBounds);
    return YES;
}

#pragma mark - Backdrop

- (void)configureBackdropWindowIfNeeded {
    if (self.backdropWindow) {
        return;
    }

    NSWindow *window = [[NSWindow alloc] initWithContentRect:self.pinnedFrame
                                                  styleMask:NSWindowStyleMaskBorderless
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0,
                                                                           0,
                                                                           NSWidth(self.pinnedFrame),
                                                                           NSHeight(self.pinnedFrame))];
    imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    imageView.imageScaling = NSImageScaleAxesIndependently;
    imageView.imageAlignment = NSImageAlignCenter;

    window.contentView = imageView;
    window.opaque = NO;
    window.backgroundColor = NSColor.clearColor;
    window.hasShadow = NO;
    window.ignoresMouseEvents = YES;
    window.level = self.window.level + FWBackdropWindowLevelOffset;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary |
                                NSWindowCollectionBehaviorStationary;
    window.alphaValue = 1.0;

    self.backdropWindow = window;
    self.backdropImageView = imageView;
}

- (void)updateNativeControlFramesFromSourceBounds:(CGRect)sourceBounds {
    NSRect updatedFrame = FWCocoaFrameFromQuartzBounds(sourceBounds);
    if (!NSEqualRects(self.pinnedFrame, updatedFrame)) {
        BOOL sizeChanged = fabs(NSWidth(self.pinnedFrame) - NSWidth(updatedFrame)) > 1.0 ||
                           fabs(NSHeight(self.pinnedFrame) - NSHeight(updatedFrame)) > 1.0;
        self.pinnedFrame = updatedFrame;
        [self.window setFrame:self.pinnedFrame display:YES];
        [self.backdropWindow setFrame:self.pinnedFrame display:YES];
        if (sizeChanged) {
            [self invalidateSourceMaskImage];
            [self updateStreamCaptureConfigurationForSize:self.pinnedFrame.size];
        }
    }
}

- (NSImage *)captureBackdropImageBehindWindowNumber:(CGWindowID)windowNumber frame:(NSRect)frame {
    if (NSIsEmptyRect(frame)) {
        return nil;
    }

    CGRect quartzBounds = FWQuartzBoundsFromCocoaFrame(frame);
    CGImageRef imageRef = CGWindowListCreateImage(quartzBounds,
                                                  kCGWindowListOptionOnScreenBelowWindow,
                                                  windowNumber,
                                                  kCGWindowImageBoundsIgnoreFraming | kCGWindowImageNominalResolution);
    if (!imageRef) {
        return nil;
    }

    NSImage *image = [[NSImage alloc] initWithCGImage:imageRef size:frame.size];
    CGImageRelease(imageRef);
    return image;
}

- (void)refreshBackdropImage {
    CFTimeInterval backdropStart = FWPerfEnabled() ? CFAbsoluteTimeGetCurrent() : 0;
    if (!self.backdropWindow || !self.backdropImageView) {
        return;
    }

    CGWindowID relativeWindow = self.nativeControlActive && !self.sourceWindowParked
        ? self.windowID
        : (CGWindowID)self.window.windowNumber;
    NSImage *image = [self captureBackdropImageBehindWindowNumber:relativeWindow frame:self.pinnedFrame];
    if (image) {
        self.backdropImageView.image = [self maskedBackdropImageWithBackground:image] ?: image;
    }
    FWPerfRecord(&FWPerfBackdropMetric, backdropStart > 0 ? CFAbsoluteTimeGetCurrent() - backdropStart : 0);
}

- (CGImageRef)newSourceMaskImage {
    CGImageRef imageRef = CGWindowListCreateImage(CGRectNull,
                                                  kCGWindowListOptionIncludingWindow,
                                                  self.windowID,
                                                  kCGWindowImageBoundsIgnoreFraming | kCGWindowImageNominalResolution);
    return imageRef;
}

- (CGImageRef)copySourceMaskImage {
    if (self.nativeControlActive && self.cachedSourceMaskImage) {
        return CGImageRetain(self.cachedSourceMaskImage);
    }

    CGImageRef imageRef = [self newSourceMaskImage];
    if (self.nativeControlActive && imageRef) {
        [self invalidateSourceMaskImage];
        self.cachedSourceMaskImage = CGImageRetain(imageRef);
    }
    return imageRef;
}

- (void)invalidateSourceMaskImage {
    if (!self.cachedSourceMaskImage) {
        return;
    }
    CGImageRelease(self.cachedSourceMaskImage);
    self.cachedSourceMaskImage = NULL;
}

- (NSImage *)maskedBackdropImageWithBackground:(NSImage *)backgroundImage {
    if (!backgroundImage || NSIsEmptyRect(self.pinnedFrame)) {
        return nil;
    }

    CGFloat scale = [self backingScaleFactorForPinnedFrame];
    size_t width = (size_t)MAX(1.0, ceil(NSWidth(self.pinnedFrame) * scale));
    size_t height = (size_t)MAX(1.0, ceil(NSHeight(self.pinnedFrame) * scale));
    CGImageRef backgroundRef = [backgroundImage CGImageForProposedRect:NULL context:nil hints:nil];
    if (!backgroundRef) {
        return nil;
    }

    CGImageRef maskRef = [self copySourceMaskImage];
    if (!maskRef) {
        return nil;
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) {
        CGImageRelease(maskRef);
        return nil;
    }

    CGRect drawRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(context, drawRect, backgroundRef);
    CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
    CGContextDrawImage(context, drawRect, maskRef);
    CGImageRelease(maskRef);

    CGImageRef maskedRef = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (!maskedRef) {
        return nil;
    }

    NSImage *maskedImage = [[NSImage alloc] initWithCGImage:maskedRef size:self.pinnedFrame.size];
    CGImageRelease(maskedRef);
    return maskedImage;
}

#pragma mark - Native Control

- (BOOL)beginNativeControlModeIfMouseInside:(NSPoint)mouseLocation {
    CFTimeInterval nativeControlStart = FWPerfEnabled() ? CFAbsoluteTimeGetCurrent() : 0;
    if (self.nativeControlActive) {
        return YES;
    }
    if (![self containsMouseLocation:mouseLocation] || self.modifierMoveActive) {
        return NO;
    }
    if (!self.clickThrough) {
        return NO;
    }

    [self configureBackdropWindowIfNeeded];
    [self invalidateSourceMaskImage];
    [self.backdropWindow setFrame:self.pinnedFrame display:YES];
    [self refreshBackdropImage];
    [self.backdropWindow orderFrontRegardless];
    [self.window orderFrontRegardless];

    if (![self moveSourceWindowToPinnedFrame]) {
        [self.backdropWindow orderOut:nil];
        [self parkSourceWindowIfPossible];
        [self updateWindowInteraction];
        return NO;
    }

    self.nativeControlActive = YES;
    NSRunningApplication *application = [NSRunningApplication runningApplicationWithProcessIdentifier:self.ownerPID];
    [application activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    [self updateWindowInteraction];
    [self updateRefreshTimerIfNeeded];

    __weak typeof(self) weakSelf = self;
    self.backdropRefreshTimer = [NSTimer timerWithTimeInterval:FWBackdropRefreshInterval
                                                       repeats:YES
                                                         block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf refreshBackdropImage];
    }];
    self.backdropRefreshTimer.tolerance = 0.015;
    [NSRunLoop.mainRunLoop addTimer:self.backdropRefreshTimer forMode:NSRunLoopCommonModes];
    FWPerfRecord(&FWPerfNativeControlMetric, nativeControlStart > 0 ? CFAbsoluteTimeGetCurrent() - nativeControlStart : 0);
    return YES;
}

- (BOOL)beginCommandHoldModeIfMouseInside:(NSPoint)mouseLocation {
    if (self.commandHoldActive) {
        return YES;
    }
    if (![self beginNativeControlModeIfMouseInside:mouseLocation]) {
        return NO;
    }

    self.commandHoldActive = YES;
    self.commandHoldMouseDown = NO;
    [self.chromeView setNeedsDisplay:YES];
    return YES;
}

- (void)endCommandHoldMode {
    if (!self.commandHoldActive) {
        return;
    }

    self.commandHoldActive = NO;
    self.commandHoldMouseDown = NO;
    [self endNativeControlMode];
}

- (void)updateCommandHoldForMouseLocation:(NSPoint)mouseLocation eventType:(NSEventType)eventType {
    if (!self.commandHoldActive) {
        return;
    }

    if (eventType == NSEventTypeLeftMouseDown || eventType == NSEventTypeLeftMouseDragged) {
        self.commandHoldMouseDown = YES;
    } else if (eventType == NSEventTypeLeftMouseUp) {
        self.commandHoldMouseDown = NO;
    }

    if ([self containsMouseLocation:mouseLocation] || self.commandHoldMouseDown) {
        return;
    }
    [self endCommandHoldMode];
}

- (void)endNativeControlMode {
    if (!self.nativeControlActive && !self.backdropWindow) {
        return;
    }

    BOOL wasNativeControlActive = self.nativeControlActive;
    [self.backdropRefreshTimer invalidate];
    self.backdropRefreshTimer = nil;
    self.nativeControlActive = NO;
    self.commandHoldActive = NO;
    self.commandHoldMouseDown = NO;

    if (wasNativeControlActive) {
        FWWindowInfo *updatedInfo = [FWWindowLister windowWithID:self.windowID];
        if (updatedInfo) {
            [self updateNativeControlFramesFromSourceBounds:updatedInfo.quartzBounds];
            self.sourceQuartzBounds = updatedInfo.quartzBounds;
            self.sourceRestoreFrameValid = YES;
            self.sourceRestorePosition = updatedInfo.quartzBounds.origin;
            self.sourceRestoreSize = updatedInfo.quartzBounds.size;
        }
    }

    if (wasNativeControlActive && self.sourceAXWindow) {
        CGRect parkedBounds = self.sourceQuartzBounds;
        if (FWParkAXWindowOutsideDisplays(self.sourceAXWindow, self.sourceQuartzBounds, &parkedBounds)) {
            self.sourceWindowParked = YES;
            self.sourceQuartzBounds = parkedBounds;
        }
    }

    [self.backdropWindow orderOut:nil];
    [self invalidateSourceMaskImage];
    [self updateWindowInteraction];
    [self updateRefreshTimerIfNeeded];
}

- (void)releaseSourceAXWindow {
    if (!self.sourceAXWindow) {
        return;
    }

    CFRelease(self.sourceAXWindow);
    self.sourceAXWindow = NULL;
}

#pragma mark - Pinned Window Movement

- (BOOL)beginMovingPinnedWindowAtMouseLocation:(NSPoint)mouseLocation {
    self.movingPinnedWindow = YES;
    self.moveStartMouseLocation = mouseLocation;
    self.moveStartPinnedFrame = self.pinnedFrame;
    return YES;
}

- (void)movePinnedWindowToMouseLocation:(NSPoint)mouseLocation {
    if (!self.movingPinnedWindow) {
        return;
    }

    CGFloat deltaX = mouseLocation.x - self.moveStartMouseLocation.x;
    CGFloat deltaY = mouseLocation.y - self.moveStartMouseLocation.y;
    self.pinnedFrame = NSOffsetRect(self.moveStartPinnedFrame, deltaX, deltaY);
    [self.window setFrame:self.pinnedFrame display:YES];
    [self.chromeView setNeedsDisplay:YES];
}

- (void)endMovingPinnedWindow {
    self.movingPinnedWindow = NO;
}

- (BOOL)adjustOpacityWithScrollEvent:(NSEvent *)event {
    CGFloat delta = FWOpacityDeltaFromScrollEvent(event);
    if (fabs(delta) < 0.001) {
        return NO;
    }

    [self.delegate mirrorController:self adjustOpacityBy:delta];
    return YES;
}

#pragma mark - Forwarded Input

- (BOOL)containsMouseLocation:(NSPoint)mouseLocation {
    return NSPointInRect(mouseLocation, self.window.frame);
}

- (NSRect)sourceImageRectInBounds:(NSRect)bounds {
    if (NSWidth(self.sourceFrame) <= 0 || NSHeight(self.sourceFrame) <= 0) {
        return bounds;
    }

    CGFloat sourceAspectRatio = NSWidth(self.sourceFrame) / NSHeight(self.sourceFrame);
    CGFloat boundsAspectRatio = NSWidth(bounds) / MAX(1.0, NSHeight(bounds));
    if (boundsAspectRatio > sourceAspectRatio) {
        CGFloat width = NSHeight(bounds) * sourceAspectRatio;
        return NSMakeRect(NSMidX(bounds) - width / 2.0, NSMinY(bounds), width, NSHeight(bounds));
    }

    CGFloat height = NSWidth(bounds) / sourceAspectRatio;
    return NSMakeRect(NSMinX(bounds), NSMidY(bounds) - height / 2.0, NSWidth(bounds), height);
}

- (BOOL)sourceQuartzPointForEvent:(NSEvent *)event fromView:(NSView *)view point:(CGPoint *)sourcePoint {
    NSPoint localPoint = [view convertPoint:event.locationInWindow fromView:nil];
    NSRect imageRect = [self sourceImageRectInBounds:view.bounds];
    if (!NSPointInRect(localPoint, imageRect) || CGRectIsEmpty(self.sourceQuartzBounds)) {
        return NO;
    }

    CGFloat normalizedX = (localPoint.x - NSMinX(imageRect)) / NSWidth(imageRect);
    CGFloat normalizedY = (localPoint.y - NSMinY(imageRect)) / NSHeight(imageRect);
    sourcePoint->x = CGRectGetMinX(self.sourceQuartzBounds) + normalizedX * CGRectGetWidth(self.sourceQuartzBounds);
    sourcePoint->y = CGRectGetMinY(self.sourceQuartzBounds) + (1.0 - normalizedY) * CGRectGetHeight(self.sourceQuartzBounds);
    return YES;
}

- (BOOL)forwardSourceMouseEvent:(NSEvent *)event fromView:(NSView *)view eventType:(CGEventType)eventType {
    BOOL isPress = eventType == kCGEventLeftMouseDown ||
                   eventType == kCGEventRightMouseDown ||
                   eventType == kCGEventOtherMouseDown;
    if (!FWAccessibilityTrusted(isPress)) {
        if (isPress) {
            NSBeep();
        }
        return NO;
    }
    CGPoint sourceQuartzPoint = CGPointZero;
    if (![self sourceQuartzPointForEvent:event fromView:view point:&sourceQuartzPoint]) {
        return NO;
    }

    if (isPress) {
        NSRunningApplication *application = [NSRunningApplication runningApplicationWithProcessIdentifier:self.ownerPID];
        [application activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }

    if (eventType == kCGEventLeftMouseUp && FWAXPressElementAtPoint(self.ownerPID, sourceQuartzPoint)) {
        return YES;
    }

    CGEventRef originalEvent = event.CGEvent;
    CGEventRef cgEvent = originalEvent ? CGEventCreateCopy(originalEvent) : NULL;
    if (!cgEvent) {
        return NO;
    }

    int64_t buttonNumber = event.buttonNumber;
    if (eventType == kCGEventLeftMouseDown ||
        eventType == kCGEventLeftMouseDragged ||
        eventType == kCGEventLeftMouseUp) {
        buttonNumber = kCGMouseButtonLeft;
    } else if (eventType == kCGEventRightMouseDown ||
               eventType == kCGEventRightMouseDragged ||
               eventType == kCGEventRightMouseUp) {
        buttonNumber = kCGMouseButtonRight;
    }

    CGEventSetType(cgEvent, eventType);
    CGEventSetLocation(cgEvent, sourceQuartzPoint);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventClickState, event.clickCount);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventButtonNumber, buttonNumber);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventWindowUnderMousePointer, (int64_t)self.windowID);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent, (int64_t)self.windowID);
    CGEventSetFlags(cgEvent, FWCGEventFlagsFromNSEventFlags(event.modifierFlags, self.modifierOperateActive));
    CGEventPostToPid(self.ownerPID, cgEvent);
    CFRelease(cgEvent);
    return YES;
}

- (BOOL)forwardSourceScrollEvent:(NSEvent *)event fromView:(NSView *)view {
    if (!FWAccessibilityTrusted(NO)) {
        return NO;
    }
    CGPoint sourceQuartzPoint = CGPointZero;
    if (![self sourceQuartzPointForEvent:event fromView:view point:&sourceQuartzPoint]) {
        return NO;
    }

    if (FWAXScrollElementAtPoint(self.ownerPID, sourceQuartzPoint, event.scrollingDeltaY, event.scrollingDeltaX)) {
        return YES;
    }

    CGEventRef originalEvent = event.CGEvent;
    CGEventRef cgEvent = originalEvent ? CGEventCreateCopy(originalEvent) : NULL;
    if (!cgEvent) {
        return NO;
    }

    CGEventSetLocation(cgEvent, sourceQuartzPoint);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventWindowUnderMousePointer, (int64_t)self.windowID);
    CGEventSetIntegerValueField(cgEvent, kCGMouseEventWindowUnderMousePointerThatCanHandleThisEvent, (int64_t)self.windowID);
    CGEventSetFlags(cgEvent, FWCGEventFlagsFromNSEventFlags(event.modifierFlags, self.modifierOperateActive));
    CGEventPostToPid(self.ownerPID, cgEvent);
    CFRelease(cgEvent);
    return YES;
}

#pragma mark - Teardown

- (void)stop {
    [self stopStreamCapture];
    [self.timer invalidate];
    self.timer = nil;
    [self.autoUnpinTimer invalidate];
    self.autoUnpinTimer = nil;
    self.autoUnpinDeadline = nil;
    [self.backdropRefreshTimer invalidate];
    self.backdropRefreshTimer = nil;
    [self.window orderOut:nil];
    [self.backdropWindow orderOut:nil];
    [self restoreSourceWindowIfNeeded];
    [self releaseSourceAXWindow];
    [self invalidateSourceMaskImage];
}
@end

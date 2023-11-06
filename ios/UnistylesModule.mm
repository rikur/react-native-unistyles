#import "UnistylesModule.h"
#import "UnistylesHelpers.h"
#import "UnistylesRuntime.h"

#import <React/RCTAppearance.h>
#import <React/RCTBridge+Private.h>
#import <jsi/jsi.h>

using namespace facebook;

@implementation UnistylesModule

RCT_EXPORT_MODULE(Unistyles)

#pragma mark - Lifecycle

- (instancetype)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleOrientationChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appearanceChanged:)
                                                     name:RCTUserInterfaceStyleDidChangeNotification
                                                   object:nil];
    }

    return self;
}

- (void)dealloc {
    if (self.unistylesRuntime != nullptr) {
        delete (UnistylesRuntime*)self.unistylesRuntime;
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


+ (BOOL)requiresMainQueueSetup {
    return YES;
}

#pragma mark - Event handlers

- (void)handleOrientationChange:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;

        ((UnistylesRuntime*)self.unistylesRuntime)->handleScreenSizeChange((int)screenWidth, (int)screenHeight);
    });
}

- (void)appearanceChanged:(NSNotification *)notification {
    std::string colorScheme = getColorScheme();

    ((UnistylesRuntime*)self.unistylesRuntime)->handleAppearanceChange(colorScheme);
}

#pragma mark - Event emitter
- (NSArray<NSString *> *)supportedEvents {
    return @[@"onChange"];
}

- (void)startObserving {
    self.hasListeners = YES;
}

- (void)stopObserving {
    self.hasListeners = NO;
}

- (void)emitEvent:(NSString *)eventName withBody:(NSDictionary *)body {
    if (self.hasListeners) {
        [self sendEventWithName:@"onChange" body:body];
    }
}

#pragma mark - Core

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(install)
{
    NSLog(@"Installing Unistyles 🦄...");

    RCTBridge* bridge = [RCTBridge currentBridge];
    RCTCxxBridge* cxxBridge = (RCTCxxBridge*)bridge;

    if (cxxBridge == nil) {
        return @false;
    }

    auto jsiRuntime = (jsi::Runtime*)cxxBridge.runtime;

    if (jsiRuntime == nil) {
        return @false;
    }

    auto& runtime = *jsiRuntime;
    UnistylesModule *__weak weakSelf = self;

    registerUnistylesHostObject(runtime, weakSelf);

    NSLog(@"Installed Unistyles 🦄!");

    return @true;
}


void registerUnistylesHostObject(jsi::Runtime &runtime, UnistylesModule* weakSelf) {
    CGFloat initialScreenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat initialScreenHeight = [UIScreen mainScreen].bounds.size.height;
    std::string initialColorScheme = getColorScheme();
    UnistylesThemeChangeEvent onThemeChange = ^(std::string theme) {
        NSDictionary *body = @{
            @"type": @"theme",
            @"payload": @{
                @"themeName": cxxStringToNSString(theme)
            }
        };

        [weakSelf emitEvent:@"onChange" withBody:body];
    };
    UnistylesBreakpointChangeEvent onBreakpointChange = ^(std::string breakpoint) {
        NSDictionary *body = @{
            @"type": @"breakpoint",
            @"payload": @{
                @"breakpoint": cxxStringToNSString(breakpoint)
            }
        };

        [weakSelf emitEvent:@"onChange" withBody:body];
    };

    auto unistylesRuntime = std::make_shared<UnistylesRuntime>(
        onThemeChange,
        onBreakpointChange,
        (int)initialScreenWidth,
        (int)initialScreenHeight,
        initialColorScheme
    );

    weakSelf.unistylesRuntime = unistylesRuntime.get();

    auto hostObject = jsi::Object::createFromHostObject(runtime, unistylesRuntime);

    runtime.global().setProperty(runtime, "__UNISTYLES__", std::move(hostObject));
}

@end

#pragma mark - End
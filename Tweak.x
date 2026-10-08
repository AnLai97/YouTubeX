#import <UIKit/UIKit.h>
#import <substrate.h>
#import <notify.h>
#import <objc/runtime.h>
#import "YTXPrefs.h"

static BOOL ytxEnabled = kYTXDefaultEnabled;
static BOOL ytxAlways = kYTXDefaultActivation == 1;
static BOOL ytxIPadLayout = kYTXDefaultIPadLayout;
static BOOL ytxForceLandscape = kYTXDefaultForceLandscape;

// Set once a YouTube scene shows up on the CarPlay screen (CarBridge launches it there)
static BOOL ytxOnCarPlay;
// While YES the trait hooks return the real values, so screen detection sees the truth
static BOOL ytxBypass;

static BOOL YTXActive(void)    { return ytxEnabled && (ytxAlways || ytxOnCarPlay); }
static BOOL YTXIPad(void)      { return YTXActive() && ytxIPadLayout; }
static BOOL YTXLandscape(void) { return YTXActive() && ytxForceLandscape; }

#pragma mark - Prefs

static BOOL YTXReadBool(NSUserDefaults *prefs, NSString *key, BOOL fallback) {
	id obj = [prefs objectForKey:key];
	return [obj respondsToSelector:@selector(boolValue)] ? [obj boolValue] : fallback;
}

// YouTube is sandboxed: prefer the notify state written by the prefs bundle, then try the
// plist by absolute path (Dopamine's cfprefsd allows it), then the defaults.
static void YTXLoadPrefs(void) {
	int token;
	uint64_t state = 0;
	if (notify_register_check(kYTXPrefsChanged, &token) == NOTIFY_STATUS_OK) {
		notify_get_state(token, &state);
		notify_cancel(token);
	}
	NSString *source;
	if (state & kYTXStateValid) {
		ytxEnabled = (state & kYTXStateEnabled) != 0;
		ytxAlways = (state & kYTXStateAlways) != 0;
		ytxIPadLayout = (state & kYTXStateIPadLayout) != 0;
		ytxForceLandscape = (state & kYTXStateForceLandscape) != 0;
		source = @"notify";
	} else {
		NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"/var/mobile/Library/Preferences/" kYTXDomain ".plist"];
		ytxEnabled = YTXReadBool(prefs, @kYTXEnabled, kYTXDefaultEnabled);
		id activation = [prefs objectForKey:@kYTXActivation];
		ytxAlways = ([activation respondsToSelector:@selector(integerValue)] ? [activation integerValue] : kYTXDefaultActivation) == 1;
		ytxIPadLayout = YTXReadBool(prefs, @kYTXIPadLayout, kYTXDefaultIPadLayout);
		ytxForceLandscape = YTXReadBool(prefs, @kYTXForceLandscape, kYTXDefaultForceLandscape);
		source = @"plist";
	}
	NSLog(@"[YouTubeX] prefs (%@): enabled=%d always=%d ipadLayout=%d forceLandscape=%d", source, ytxEnabled, ytxAlways, ytxIPadLayout, ytxForceLandscape);
}

// The layout is chosen when YouTube builds its screens, so changes apply on the next launch;
// reloading here only keeps the values current for orientation checks.
static void YTXPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	YTXLoadPrefs();
}

#pragma mark - CarPlay detection

static BOOL YTXScreenIsCar(UIScreen *screen) {
	if (!screen) return NO;
	ytxBypass = YES;
	UIUserInterfaceIdiom idiom = screen.traitCollection.userInterfaceIdiom;
	ytxBypass = NO;
	BOOL car = idiom == UIUserInterfaceIdiomCarPlay || screen != [UIScreen mainScreen];
	NSLog(@"[YouTubeX] screen %@ idiom=%ld main=%d -> car=%d", screen, (long)idiom, screen == [UIScreen mainScreen], car);
	return car;
}

static void YTXCheckScreen(UIScreen *screen) {
	if (ytxOnCarPlay || !YTXScreenIsCar(screen)) return;
	ytxOnCarPlay = YES;
	NSLog(@"[YouTubeX] running on CarPlay: ipad=%d landscape=%d", YTXIPad(), YTXLandscape());
}

#pragma mark - iPad layout

%hook UIDevice
- (UIUserInterfaceIdiom)userInterfaceIdiom {
	UIUserInterfaceIdiom idiom = %orig;
	return idiom == UIUserInterfaceIdiomPhone && YTXIPad() ? UIUserInterfaceIdiomPad : idiom;
}
%end

%hook UITraitCollection
- (UIUserInterfaceIdiom)userInterfaceIdiom {
	UIUserInterfaceIdiom idiom = %orig;
	if (ytxBypass || !YTXIPad()) return idiom;
	return idiom == UIUserInterfaceIdiomPhone || idiom == UIUserInterfaceIdiomCarPlay ? UIUserInterfaceIdiomPad : idiom;
}

// A full-screen iPad app is regular in both directions; YouTube picks its wide layouts from this
- (UIUserInterfaceSizeClass)horizontalSizeClass {
	UIUserInterfaceSizeClass size = %orig;
	return size == UIUserInterfaceSizeClassCompact && !ytxBypass && YTXIPad() ? UIUserInterfaceSizeClassRegular : size;
}

- (UIUserInterfaceSizeClass)verticalSizeClass {
	UIUserInterfaceSizeClass size = %orig;
	return size == UIUserInterfaceSizeClassCompact && !ytxBypass && YTXIPad() ? UIUserInterfaceSizeClassRegular : size;
}
%end

%hook UIViewController
// On iPad, share sheets and action sheets are popovers and crash without an anchor.
// YouTube's iPhone code never sets one, so anchor them to the middle of the presenting view.
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion {
	if (YTXIPad()) {
		BOOL sheet = [vc isKindOfClass:[UIActivityViewController class]]
			|| ([vc isKindOfClass:[UIAlertController class]] && ((UIAlertController *)vc).preferredStyle == UIAlertControllerStyleActionSheet)
			|| vc.modalPresentationStyle == UIModalPresentationPopover;
		UIPopoverPresentationController *popover = sheet ? vc.popoverPresentationController : nil;
		if (popover && !popover.sourceView && !popover.barButtonItem) {
			UIView *view = self.viewIfLoaded ?: self.view;
			popover.sourceView = view;
			popover.sourceRect = CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds), 1, 1);
			popover.permittedArrowDirections = 0;
		}
	}
	%orig;
}

#pragma mark - Landscape

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return YTXLandscape() ? UIInterfaceOrientationMaskLandscape : %orig;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
	return YTXLandscape() ? UIInterfaceOrientationLandscapeRight : %orig;
}

- (BOOL)shouldAutorotate {
	return YTXLandscape() ? YES : %orig;
}
%end

%hook UIApplication
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window {
	return YTXLandscape() ? UIInterfaceOrientationMaskLandscape : %orig;
}
%end

// The app delegate can also restrict orientations; it's YouTube's class, so hook it at launch.
static UIInterfaceOrientationMask (*orig_delegateOrientations)(id, SEL, UIApplication *, UIWindow *);
static UIInterfaceOrientationMask hook_delegateOrientations(id self, SEL _cmd, UIApplication *app, UIWindow *window) {
	return YTXLandscape() ? UIInterfaceOrientationMaskLandscape : orig_delegateOrientations(self, _cmd, app, window);
}

static void YTXHookAppDelegate(void) {
	Class cls = object_getClass([UIApplication sharedApplication].delegate);
	SEL sel = @selector(application:supportedInterfaceOrientationsForWindow:);
	if (!cls || !class_getInstanceMethod(cls, sel)) return;
	MSHookMessageEx(cls, sel, (IMP)hook_delegateOrientations, (IMP *)&orig_delegateOrientations);
	NSLog(@"[YouTubeX] hooked %@ orientations", NSStringFromClass(cls));
}

// UIKit's internal wrapper around supportedInterfaceOrientations. YouTube's own controllers
// override the public method without calling super, so this is where they all pass through.
// Private, so it's only hooked if this iOS version has it.
static UIInterfaceOrientationMask (*orig_wrapperOrientations)(id, SEL);
static UIInterfaceOrientationMask hook_wrapperOrientations(id self, SEL _cmd) {
	return YTXLandscape() ? UIInterfaceOrientationMaskLandscape : orig_wrapperOrientations(self, _cmd);
}

static void YTXHookOrientationWrapper(void) {
	SEL sel = NSSelectorFromString(@"__supportedInterfaceOrientations");
	if (!class_getInstanceMethod([UIViewController class], sel)) {
		NSLog(@"[YouTubeX] %@ not found", NSStringFromSelector(sel));
		return;
	}
	MSHookMessageEx([UIViewController class], sel, (IMP)hook_wrapperOrientations, (IMP *)&orig_wrapperOrientations);
}

// iOS 16 only rotates when asked, so request landscape once the scene is on screen
static void YTXRotate(UIWindowScene *scene) {
	if (!YTXLandscape() || ![scene isKindOfClass:[UIWindowScene class]]) return;
	for (UIWindow *window in scene.windows) {
		if (@available(iOS 16.0, *)) [window.rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];
	}
	if (@available(iOS 16.0, *)) {
		UIWindowSceneGeometryPreferencesIOS *prefs = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
		[scene requestGeometryUpdateWithPreferences:prefs errorHandler:^(NSError *error) {
			NSLog(@"[YouTubeX] rotate failed: %@", error);
		}];
	}
}

%ctor {
	YTXLoadPrefs();
	NSLog(@"[YouTubeX] loaded in %@", [NSBundle mainBundle].bundleIdentifier);

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, YTXPrefsChanged,
		CFSTR(kYTXPrefsChanged), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	YTXHookOrientationWrapper();

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSOperationQueue *main = [NSOperationQueue mainQueue];
	[nc addObserverForName:UISceneWillConnectNotification object:nil queue:main usingBlock:^(NSNotification *note) {
		if ([note.object isKindOfClass:[UIWindowScene class]]) YTXCheckScreen(((UIWindowScene *)note.object).screen);
	}];
	[nc addObserverForName:UISceneDidActivateNotification object:nil queue:main usingBlock:^(NSNotification *note) {
		if ([note.object isKindOfClass:[UIWindowScene class]]) YTXCheckScreen(((UIWindowScene *)note.object).screen);
		YTXRotate(note.object);
	}];
	[nc addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:main usingBlock:^(NSNotification *note) {
		YTXHookAppDelegate();
	}];
}

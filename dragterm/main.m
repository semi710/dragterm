//
//  main.m
//  dragterm
//
//  Created by Nate Weaver on 2019-06-07.
//  Copyright © 2019 Nate Weaver/Derailer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "DTDraggingSourceView.h"
#import <getopt.h>
#import <termios.h>

static NSString *ASCIIfy(NSString *str) {
	str = [str stringByReplacingOccurrencesOfString:@"©" withString:@"Copyright"];
	str = [str stringByReplacingOccurrencesOfString:@"–" withString:@"-"]; // en dash to hyphen
	return str;
}

static void printVersion(void) {
	NSBundle *bundle = NSBundle.mainBundle;

	NSString *shortVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *bundleVersion = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *copyright = [bundle objectForInfoDictionaryKey:@"NSHumanReadableCopyright"];

	printf("dragterm %s (v%s)\n", shortVersion.UTF8String, bundleVersion.UTF8String);
	printf("%s\n", ASCIIfy(copyright).UTF8String);
}

static void printUsage(BOOL stdErr) {
	fprintf(stdErr ? stderr : stdout, "Usage: %s <files>\n", getprogname());
}

static int parseArguments(int argc, char * const argv[]) {
	struct option longopts[] = {
		{ "version", no_argument, NULL, 'v' },
		{ "help", no_argument, NULL, 'h' },
		{ NULL, 0, NULL, 0 }
	};
	int c;
	while ((c = getopt_long(argc, argv, "vh", longopts, NULL)) != -1) {
		switch (c) {
			case 'v':
				printVersion();
				exit(0);
			case 'h':
				printUsage(NO);
				exit(0);
		}
	}

	return optind;
}

static void signalHandler(int signum) {
	exit(0);
}

// CGEventTap callback: cancel from any Space/app. Key codes: Esc=53, q=12, d=2.
static CGEventRef dtKeyTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
	if (type == kCGEventKeyDown) {
		CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
		CGEventFlags flags = CGEventGetFlags(event);
		if (keyCode == 53 || keyCode == 12) // Esc or q
			exit(0);
		if (keyCode == 2 && (flags & kCGEventFlagMaskControl)) // Ctrl-D
			exit(0);
	}
	return event;
}

int main(int argc, char * const argv[]) {
	@autoreleasepool {
		signal(SIGINT, signalHandler);

		if (argc < 2) {
			printUsage(YES);
			return 1;
		}

		int diff = parseArguments(argc, argv);
		argc -= diff;
		argv += diff;

		if (argc < 1)
			return 1;

		NSApplicationLoad();
		[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

		NSMutableArray<NSURL *> *urls = [NSMutableArray arrayWithCapacity:argc - 1];

		for (int i = 0; i < argc; ++i) {
			NSURL *fileURL = [NSURL fileURLWithPath:@(argv[i])].absoluteURL;

			if (![fileURL checkResourceIsReachableAndReturnError:nil]) {
				fprintf(stderr, "Couldn't find file: %s\n", argv[i]);
				return 1;
			}

			[urls addObject:fileURL];
		}

		if (urls.count == 1)
			printf("Dragging %s\n", urls[0].path.UTF8String);
		else
			printf("Dragging %lu files\n", urls.count);

		NSRect frame = (NSRect){ { 0.0, 0.0 }, { 256.0, 256.0 }};

		NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
		window.opaque = NO;
		window.backgroundColor = NSColor.clearColor;
		window.level = NSStatusWindowLevel;
		window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
		window.ignoresMouseEvents = NO;

		DTDraggingSourceView *sourceView = [[DTDraggingSourceView alloc] initWithFrame:frame];
		window.contentView = sourceView;
		sourceView.iconSize = 64.0;
		sourceView.URLs = urls;

		NSPoint mouseLocation = NSEvent.mouseLocation;
		frame.origin = mouseLocation;
		frame.origin.x -= frame.size.width / 2.0;
		frame.origin.y -= frame.size.height / 2.0;
		[window setFrame:frame display:YES];

		[window orderFront:nil];

		NSFileHandle.fileHandleWithStandardInput.readabilityHandler = ^(NSFileHandle *fileHandle) {
			NSData *data = fileHandle.availableData;

			if (data.length == 1) {
				char *bytes = (char *)data.bytes;

				if (bytes[0] == '\e' || bytes[0] == 0x04 || bytes[0] == 'q') // 0x04 is END OF TRANSMISSION (Ctrl-D)
					exit(0);
			}

			putc('\a', stderr);
		};

		// Global key tap: cancel from any Space/app. Needs Accessibility.
		// ponytail: stdin handler above stays as fallback when Accessibility isn't granted.
		CFMachPortRef keyTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
			kCGEventTapOptionListenOnly, CGEventMaskBit(kCGEventKeyDown), dtKeyTapCallback, NULL);
		if (keyTap) {
			CFRunLoopSourceRef src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyTap, 0);
			CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopCommonModes);
			CFRunLoopAddSource(CFRunLoopGetCurrent(), src, (__bridge CFStringRef)NSEventTrackingRunLoopMode);
			CFRelease(keyTap);
			CFRelease(src);
		} else {
			fprintf(stderr, "drag: Accessibility not granted; keyboard cancel works only when terminal has focus.\nRight-click the icon to cancel from any Space.\n");
		}

		struct termios info;
		tcgetattr(0, &info);
		info.c_lflag &= ~(ICANON | ECHO);
		info.c_cc[VMIN] = 0;
		info.c_cc[VTIME] = 0;
		tcsetattr(0, TCSANOW, &info);

	// Poll-based follow: mouseMoved delivery to a background app breaks across
	// Space swipes until the cursor re-enters the window. A timer avoids that.
	__block BOOL shiftWasDown = NO;
	void (^followCursor)(void) = ^{
		NSPoint loc = NSEvent.mouseLocation;
		NSRect f = window.frame;
		NSPoint origin = (NSPoint){ loc.x - f.size.width / 2.0, loc.y - f.size.height / 2.0 };
		if (!NSEqualPoints(origin, f.origin)) {
			f.origin = origin;
			[window setFrame:f display:NO];
		}

		BOOL shiftDown = (CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState) & kCGEventFlagMaskShift) != 0;
		if (shiftDown != shiftWasDown) {
			window.ignoresMouseEvents = shiftDown;
			window.alphaValue = shiftDown ? 0.3 : 1.0;
			shiftWasDown = shiftDown;
		}
	};
	NSTimer *followTimer = [NSTimer timerWithTimeInterval:1.0 / 60.0 repeats:YES block:^(NSTimer *t) {
		followCursor();
	}];
	// Coalesced fires are fine: a few ms of lag is invisible on a drag ghost.
	followTimer.tolerance = 0.02;
	[[NSRunLoop currentRunLoop] addTimer:followTimer forMode:NSRunLoopCommonModes];
	[[NSRunLoop currentRunLoop] addTimer:followTimer forMode:(NSString *)NSEventTrackingRunLoopMode];

	while (1) {
		NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:NSDate.distantFuture inMode:NSEventTrackingRunLoopMode dequeue:YES];
		[NSApp sendEvent:event];
	}
	}

	return 0;
}

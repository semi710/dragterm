//
//  DTDraggingSourceView.m
//  drag
//
//  Created by Nate Weaver on 2019-06-07.
//  Copyright © 2019 Nate Weaver/Derailer. All rights reserved.
//

#import "DTDraggingSourceView.h"
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>

@interface DTDraggingSourceView ()

@property (nonatomic, copy)	NSImage *icon;

@end

static NSRect DTCenterRect(NSRect baseRect, CGFloat rectDim) {
	NSRect rect = NSZeroRect;
	rect.size = (NSSize){ rectDim, rectDim };
	rect.origin = (NSPoint){ (baseRect.size.width - rectDim) / 2.0, (baseRect.size.height - rectDim) / 2.0};
	return rect;
}

@implementation DTDraggingSourceView

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	if (operation == NSDragOperationDelete) {
		[NSWorkspace.sharedWorkspace recycleURLs:self.URLs completionHandler:^(NSDictionary<NSURL *,NSURL *> * _Nonnull newURLs, NSError * _Nullable error) {
			[NSApp terminate:nil];
		}];
	} else {
		[NSApp terminate:nil];
	}
}

- (NSDragOperation)draggingSession:(nonnull NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
	return NSDragOperationEvery;
}

- (void)setURLs:(NSArray<NSURL *> *)urls {
	_URLs = [urls copy];
	NSImage *icon;

	if (urls.count == 1) {
		NSURL *url = urls.firstObject;
		[url getResourceValue:&icon forKey:NSURLEffectiveIconKey error:nil];

		// Icon shows immediately; swap in the content thumbnail if QuickLook has one.
		QLThumbnailGenerationRequest *request = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:url
			size:(CGSize){ self.iconSize, self.iconSize }
			scale:2.0
			representationTypes:QLThumbnailGenerationRequestRepresentationTypeThumbnail];
		[[QLThumbnailGenerator sharedGenerator] generateBestRepresentationForRequest:request
			completionHandler:^(QLThumbnailRepresentation * _Nullable rep, NSError * _Nullable error) {
				if (!rep)
					return;
				dispatch_async(dispatch_get_main_queue(), ^{
						self.icon = rep.NSImage;
						self.needsDisplay = YES;
				});
			}];
	} else
		icon = [NSImage imageNamed:NSImageNameMultipleDocuments];

	self.icon = icon;
}

- (void)drawRect:(NSRect)dirtyRect {
	[self.icon drawInRect:DTCenterRect(self.bounds, self.iconSize)];
}

- (void)rightMouseDown:(NSEvent *)event {
	exit(0);
}

- (void)mouseDown:(NSEvent *)event {
	[self.window orderOut:nil];

	NSMutableArray<NSDraggingItem *> *items = [NSMutableArray arrayWithCapacity:self.URLs.count];

	for (NSURL *url in self.URLs) {
		NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:url];
		NSImage *icon;
		CGFloat iconSize = self.iconSize;
		if (self.URLs.count == 1)
			icon = self.icon; // may be the loaded thumbnail by now
		else
			[url getResourceValue:&icon forKey:NSURLEffectiveIconKey error:nil];

		item.draggingFrame = DTCenterRect(self.bounds, iconSize);

		item.imageComponentsProvider = ^NSArray<NSDraggingImageComponent *> *{
			NSDraggingImageComponent *iconComponent = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
			iconComponent.contents = [NSImage imageWithSize:(NSSize){ iconSize, iconSize } flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
				[icon drawInRect:dstRect];
				return YES;
			}];
			iconComponent.frame = (NSRect){ { 0.0, 0.0 }, { iconSize, iconSize } };
			return @[iconComponent];
		};

		[items addObject:item];
	}

	[self beginDraggingSessionWithItems:items event:event source:self];
}

@end

//
//  AppDelegate.m
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "INAppStoreWindow.h"
#import "PlaybackController.h"
#import "Track.h"
#import "WindowController.h"

NSString *const AppDelegateHTMLImagePlaceholder = @"{{ image_url }}";

@interface AppDelegate ()
@property (nonatomic, retain) WindowController *windowController;
@property (nonatomic, retain) PlaybackController *playbackController;
@end

@implementation AppDelegate

@synthesize windowController = _windowController;
@synthesize playbackController = _playbackController;

+ (AppDelegate *)sharedInstance
{
    return [NSApp delegate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setWindowController:[WindowController windowController]];
    [self.windowController showWindow:self];

    // Basic implementation of the default loop count.
    // Infinity = 31 until further notice.
    [self setPlaybackController:[PlaybackController playbackController]];
    [self.playbackController setLoopInfiniteCount:31];
    [self.playbackController updateLoopCount:10];
    
    // Set the max value of the loop counter.
    [[self.windowController loopCountStepper] setMaxValue:(double)[self.playbackController loopInfiniteCount]];
}

@end

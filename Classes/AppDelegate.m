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
@property (nonatomic, strong) WindowController *windowController;
@property (nonatomic, strong) PlaybackController *playbackController;
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
	WindowController *windowController = [[WindowController alloc] init];
    [self setWindowController:windowController];
    [self.windowController showWindow:self];
  
    // Basic implementation of the default loop count.
    // Infinity = 31 until further notice.
	PlaybackController *playbackController = [[PlaybackController alloc] init];
    [self setPlaybackController:playbackController];
    [self.playbackController setLoopInfiniteCount:31];
    [self.playbackController updateLoopCount:10];
    
    // Set the max value of the loop counter.
    [[self.windowController loopCountStepper] setMaxValue:(double)[self.playbackController loopInfiniteCount]];
}

- (IBAction)openFile:(id)sender 
{
    void(^handler)(NSInteger);
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp3", @"m4a", nil]];
    
    handler = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *filePath = [[panel URLs] objectAtIndex:0];
            if (![[AppDelegate sharedInstance].playbackController openURL:filePath]) {
                NSLog(@"Could not load track.");
                return;
            }
        }
    };
    
    [panel beginSheetModalForWindow:[[AppDelegate sharedInstance].windowController window] completionHandler:handler];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
	return [self.playbackController openURL:[NSURL fileURLWithPath:filename]];
}

@end

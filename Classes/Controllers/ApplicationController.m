//
//  AppDelegate.m
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "ApplicationController.h"

#import "INAppStoreWindow.h"
#import "PlaybackController.h"
#import "Track.h"
#import "WindowController.h"

// All builds should expire in 4 weeks time.
#define EXPIREAFTERDAYS 28

@interface ApplicationController ()
@property (nonatomic, strong) WindowController *windowController;
@property (nonatomic, strong) PlaybackController *playbackController;

- (void)checkFreshness;
@end

@implementation ApplicationController

@synthesize windowController = _windowController;
@synthesize playbackController = _playbackController;

+ (ApplicationController *)sharedInstance
{
    return [NSApp delegate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Kill the application if it's over EXPIREAFTERDAYS days old.
    [self checkFreshness];

    WindowController *windowController = [[WindowController alloc] init];
    [self setWindowController:windowController];
    [self.windowController showWindow:self];

    // Basic implementation of the default loop count.
    // Infinity = 31 until further notice.
	PlaybackController *playbackController = [[PlaybackController alloc] init];
    [self setPlaybackController:playbackController];
    [self.playbackController setLoopInfiniteCount:31];
    [self.playbackController updateLoopCount:31];

    // Set the max value of the loop counter.
    [[self.windowController loopCountStepper] setMaxValue:(double)[self.playbackController loopInfiniteCount]];
}

- (void)checkFreshness
{
#if EXPIREAFTERDAYS
    NSString* compileDateString = [NSString stringWithUTF8String:__DATE__];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    [formatter setDateFormat:@"MMM dd yyyy"];
    NSDate *compileDate = [formatter dateFromString:compileDateString];
    NSDate *expireDate = [compileDate dateByAddingTimeInterval:(60*60*24*EXPIREAFTERDAYS)];

    if ([expireDate earlierDate:[NSDate date]] == expireDate) {
        // TODO: Run an alert or whatever.
        [NSApp terminate:self];
    }
#endif
}

- (IBAction)openFile:(id)sender
{
    void(^handler)(NSInteger);

    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setAllowedFileTypes:[NSArray arrayWithObject:@"public.audio"]];

    handler = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *filePath = [[panel URLs] objectAtIndex:0];
            if (![[ApplicationController sharedInstance].playbackController openURL:filePath]) {
                NSLog(@"Could not load track.");
                return;
            }
            [[ApplicationController sharedInstance].windowController showPlayerView];
            [[ApplicationController sharedInstance].playbackController openURL:filePath];
        }
    };

    [panel beginSheetModalForWindow:[[ApplicationController sharedInstance].windowController window] completionHandler:handler];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    [self.windowController showPlayerView];
    return [self.playbackController openURL:[NSURL fileURLWithPath:filename]];
}

@end

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
@property (nonatomic, retain) Track *track;
@end

@implementation AppDelegate

@synthesize windowController = _windowController;
@synthesize playbackController = _playbackController;
@synthesize track = _track;

+ (AppDelegate *)sharedInstance
{
    return [NSApp delegate];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setWindowController:[WindowController windowController]];
    [self.windowController showWindow:self];

    [self setPlaybackController:[PlaybackController playbackController]];

    // Basic implementation of the default loop count.
    // Infinity = 31 until further notice.
    [self.playbackController setLoopInfiniteCount:31];
    [self.playbackController updateLoopCount:10];
    [[self.windowController loopCountStepper] setMaxValue:(double)[self.playbackController loopInfiniteCount]];
}

- (BOOL)performOpen:(NSURL *)fileURL
{
    if (fileURL == nil) {
        return NO; // Make me smarter.
    }
    
    // Stop the music there's a track playing.
    [[[self.playbackController track] asset] stop];

    // Add the filename to the recently opened menu (hopefully).
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];

    // Bring the window to the foreground (if needed).
    [self.windowController showWindow:self];

    // Play the funky music right boy.
    [self setTrack:[[Track alloc] initWithFileURL:fileURL]];
    [self.playbackController loadTrack:self.track];
    return YES;
}

- (IBAction)openFile:(id)sender 
{
    void(^handler)(NSInteger);
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp3", @"m4a", nil]];
    
    handler = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *filePath = [[panel URLs] objectAtIndex:0];
            if (![self performOpen:filePath]) {
                NSLog(@"Could not load track.");
                return;
            }
        }
    };
    
    [panel beginSheetModalForWindow:[self.windowController window] completionHandler:handler];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    return [self performOpen:[NSURL fileURLWithPath:filename]];
}


@end

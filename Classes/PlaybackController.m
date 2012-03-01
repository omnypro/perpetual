//
//  PlaybackController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlaybackController.h"

#import "AppDelegate.h"
#import "MetadataController.h"
#import "Track.h"
#import "WindowController.h"

@interface PlaybackController ()
@property (nonatomic, retain) Track *track;

- (void)loadTrack;
- (BOOL)performOpen:(NSString *)filename;
@end

@implementation PlaybackController

@synthesize track = _track;

@synthesize paused = _paused;
@synthesize currentTime = _currentTime;
@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;

- (void)updateLoopCount:(NSUInteger)count
{
    WindowController *ui = [AppDelegate sharedInstance].windowController;
    
    // Sets the property and updates the label.
    self.loopCount = count;
    if (self.loopCount < self.loopInfiniteCount) {
        [ui.loopCountLabel setStringValue:[NSString stringWithFormat:@"x%d", self.loopCount]];
    }
    else {
        [ui.loopCountLabel setStringValue:@"∞"];
    }
    
    // Finally, update the stepper so it's snychronized.
    [ui.loopCountStepper setIntegerValue:self.loopCount];
}

- (void)checkTime:(NSTimer *)timer
{
    self.currentTime = [self.track.asset currentTime];
    
    if (self.currentTime.timeValue >= self.track.endTime.timeValue && self.track.startTime.timeValue < self.track.endTime.timeValue && [self loopCount] > 0) {
        if (self.loopCount < self.loopInfiniteCount) {
            [self updateLoopCount:self.loopCount - 1];
        }
        [self setCurrentTime:self.track.startTime];
    }
}

- (void)loadTrack
{
    // Is this really needed?
    self.paused = YES;
    
    // Compose the initial user interface.
    // ???: Should we be doing this in the playback controller?
    WindowController *ui = [AppDelegate sharedInstance].windowController;
    [ui.progressBar setMaxValue:self.track.duration.timeValue];
    [ui.startSlider setMaxValue:self.track.duration.timeValue];
    [ui.startSlider setFloatValue:0.0];
    [ui.endSlider setMaxValue:self.track.duration.timeValue];
    [ui.endSlider setFloatValue:self.track.duration.timeValue];
    [ui.startSlider setNumberOfTickMarks:(int)self.track.duration.timeValue / self.track.duration.timeScale];
    [ui.endSlider setNumberOfTickMarks:(int)self.track.duration.timeValue / self.track.duration.timeScale];
    
    // Fetch all of the metadata.
    [[MetadataController metadataController] fetchMetadataForURL:self.track.assetURL];
    
    // Start the timer loop.
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}

# pragma mark File Handling

- (BOOL)performOpen:(NSURL *)fileURL
{
    if (fileURL == nil) {
        return NO; // Make me smarter.
    }
    
    // Stop the music there's a track playing.
    [[self.track asset] stop];
    
    // Add the filename to the recently opened menu (hopefully).
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];
    
    // Bring the window to the foreground (if needed).
    [[AppDelegate sharedInstance].windowController showWindow:self];
    
    // Play the funky music right boy.
    [self setTrack:[[Track alloc] initWithFileURL:fileURL]];
    [self loadTrack];
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
    
    [panel beginSheetModalForWindow:[[AppDelegate sharedInstance].windowController window] completionHandler:handler];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    return [self performOpen:[NSURL fileURLWithPath:filename]];
}

@end

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
    [[self window] makeKeyAndOrderFront:self];

    // Play the funky music right boy.
    Track *track = [[Track alloc] initWithFileURL:fileURL];
    [[self playbackController] loadTrack:track withOriginalFileURL:fileURL];
    return YES;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    return [self performOpen:[NSURL fileURLWithPath:filename]];
}

- (void)updateUserInterface
{
    float volume = [self.music volume];
    [self.volumeSlider setFloatValue:volume];
}


#pragma mark IBAction Methods

- (IBAction)startSliderSet:(id)sender
{
    if ([self.startSlider doubleValue] < (float)self.endTime.timeValue) {
        self.startTime = QTMakeTime((long)[self.startSlider doubleValue], self.timeScale);
    }
    else {
        [self.startSlider setFloatValue:(float)self.startTime.timeValue];
    }
}

- (IBAction)endSliderSet:(id)sender
{
    if ([self.endSlider doubleValue] > (float)self.startTime.timeValue) {
        self.endTime = QTMakeTime((long)[self.endSlider doubleValue], self.timeScale);
    }
    else {
        [self.endSlider setFloatValue:(float)self.endTime.timeValue];
    }
}

- (IBAction)currentTimeBarSet:(id)sender
{
    NSTimeInterval ct = [self.currentTimeBar doubleValue];
    [self.music setCurrentTime:QTMakeTime((long)ct, self.timeScale)];
}

- (IBAction)setFloatForVolume:(id)sender
{
    float newValue = [sender floatValue];
    [self.music setVolume:newValue];
    [self updateUserInterface];
}

- (IBAction)playButtonClick:(id)sender
{
    if (!self.paused) {
        [self.music stop];
        self.paused = YES;
    }
    else {
        [self.music play];
        self.paused = NO;
    }
}

- (IBAction)loopStepperStep:(id)sender
{
    [self setTheLoopCount:[self.loopCountStepper intValue]];
}


#pragma mark NSWindow Delegate Methods

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    return NSOffsetRect(NSInsetRect(rect, 8, 0), 0, -18);
}


#pragma mark WebView Delegate Methods

- (NSUInteger)webView:(WebView *)webView dragDestinationActionMaskForDraggingInfo:(id<NSDraggingInfo>)draggingInfo
{
    return WebDragDestinationActionNone; // We shouldn't be able to drag things into the webView.
}

- (NSUInteger)webView:(WebView *)webView dragSourceActionMaskForPoint:(NSPoint)point
{
    return WebDragSourceActionNone; // We shouldn't be able to drag the artwork out of the webView.
}

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    return nil; // Disable the webView's contextual menu.
}

- (BOOL)webView:(WebView *)webView shouldChangeSelectedDOMRange:(DOMRange *)currentRange toDOMRange:(DOMRange *)proposedRange affinity:(NSSelectionAffinity)selectionAffinity stillSelecting:(BOOL)flag
{
    return NO; // Prevent the selection of content.
}

@end

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

#import <CoreAudio/CoreAudio.h>
#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>

NSString *const AppDelegateHTMLImagePlaceholder = @"{{ image_url }}";

@interface AppDelegate ()
@property (nonatomic, retain) WindowController *windowController;
@property (nonatomic, retain) PlaybackController *playbackController;
@end

@implementation AppDelegate

@synthesize windowController = _windowController;
@synthesize playbackController = _playbackController;

@synthesize window = _window;
@synthesize startSlider = _startSlider;
@synthesize endSlider = _endSlider;
@synthesize currentTimeLabel = _currentTimeLabel;
@synthesize trackTitle = _trackTitle;
@synthesize trackSubTitle = _trackSubTitle;
@synthesize currentTimeBar = _currentTimeBar;
@synthesize playButton = _playButton;
@synthesize loopCountLabel = _loopCountLabel;
@synthesize loopCountStepper = _loopCountStepper;
@synthesize coverWebView = _coverWebView;
@synthesize openFileButton = _openFileButton;
@synthesize volumeSlider = _volumeSlider;

@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;
@synthesize timeScale = _timeScale;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize currentTime = _currentTime;
@synthesize music = _music;
@synthesize paused = _paused;

#pragma mark API

+ (AppDelegate *)sharedInstance
{
    return [NSApp delegate];
}

- (void)awakeFromNib
{
    // Load our blank cover, since we obviously have no audio to play.
    [self injectCoverArtWithIdentifier:@"cover.jpg"];
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
    [[[self playbackController] track] stop];

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

- (IBAction)openFile:(id)sender
{
    void (^handler)(NSInteger);

    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp3", @"m4a", nil]];

    handler = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *filePath = [[panel URLs] objectAtIndex:0];
            if (![self performOpen:filePath]) {
                NSLog(@"Could not load music.");
                return;
            }
        }
    };

    [panel beginSheetModalForWindow:[self window] completionHandler:handler];
}

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

//
//  WindowController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "WindowController.h"

#import "AppDelegate.h"
#import "INAppStoreWindow.h"
#import "PlaybackController.h"
#import "Track.h"

#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

NSString *const WindowControllerHTMLImagePlaceholder = @"{{ image_url }}";

@interface WindowController () <NSWindowDelegate>
@property (nonatomic, strong) PlaybackController *playbackController;

- (void)composeInterface;
- (void)layoutTitleBarSegmentedControls;
- (void)layoutWebView;
- (void)layoutInitialInterface:(id)sender;
- (void)updateVolumeSlider;

- (void)playbackHasProgressed:(NSNotification *)notification;
- (void)trackLoopCountChanged:(NSNotification *)notification;
- (void)trackWasLoaded:(NSNotification *)notification;
@end

@implementation WindowController

@synthesize playbackController = _playbackController;

// Cover and Statistics Display
@synthesize webView = _webView;

// Track Metadata Displays
@synthesize trackTitle = _trackTitle;
@synthesize trackSubtitle = _trackSubtitle;
@synthesize currentTime = _currentTime;
@synthesize rangeTime = _rangeTime;

// Sliders and Progress Bar
@synthesize startSlider = _startSlider;
@synthesize endSlider = _endSlider;
@synthesize progressBar = _progressBar;

// Lower Toolbar
@synthesize open = _openFile;
@synthesize play = _play;
@synthesize volumeControl = _volumeControl;
@synthesize loopCountLabel = _loopCountLabel;
@synthesize loopCountStepper = _loopCountStepper;

- (id)init
{	
	return [super initWithWindowNibName:@"Window"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [[self window] setAllowsConcurrentViewDrawing:YES];

    // Register notifications for our playback services.
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidStart:) name:PlaybackDidStartNotification object:nil];
    // [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackDidStop:) name:PlaybackDidStopNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackHasProgressed:) name:PlaybackHasProgressedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackLoopCountChanged:) name:TrackLoopCountChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackWasLoaded:) name:TrackWasLoadedNotification object:nil];
    
    [self composeInterface];
}

#pragma mark Window Compositioning

- (void)composeInterface
{
    // Customize INAppStoreWindow.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    window.titleBarHeight = 40.f;
    window.trafficLightButtonsLeftMargin = 7.f;
    // window.backgroundColor

    [self layoutTitleBarSegmentedControls];
    [self layoutWebView];

    // Load our blank cover, since we obviously have no audio to play.
    [self layoutCoverArtWithIdentifier:@"cover.jpg"];
}

- (void)layoutTitleBarSegmentedControls
{
    // - NOOP -
    // Implements a very crude NSSegmentedControl, used to switch between the 
    // album view of the track currently opened and the listening statistics 
    // for that track.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    NSView *titleBarView = [window titleBarView];
    NSSize controlSize = NSMakeSize(100.f, 32.f);
    NSRect controlFrame = NSMakeRect(NSMidX([titleBarView bounds]) - (controlSize.width / 2.f), 
                                     NSMidY([titleBarView bounds]) - (controlSize.height / 2.f), 
                                     controlSize.width, 
                                     controlSize.height);
    NSSegmentedControl *switcher = [[NSSegmentedControl alloc] initWithFrame:controlFrame];
    [switcher setSegmentCount:2];
    [switcher setSegmentStyle:NSSegmentStyleTexturedRounded];
    [switcher setLabel:@"Music" forSegment:0];
    [switcher setLabel:@"Statistics" forSegment:1];
    [switcher setSelectedSegment:0];
    [switcher setEnabled:FALSE forSegment:1]; // Disables the statistics segment.
    [switcher setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin|NSViewMaxYMargin];
    [[switcher cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    [titleBarView addSubview:switcher];
}

- (void)layoutWebView
{
    // Set us up as the delegate of the WebView for relevant events.
    // UIDelegate and FrameLoadDelegate are set in Interface Builder.
    [[self webView] setEditingDelegate:self];    
}

- (void)layoutInitialInterface:(Track *)track
{
    // Compose the initial user interface.
    // Set the max value of the progress bar to the duration of the track.
    self.progressBar.maxValue = track.duration;
    
    // Set the slider attributes.
    self.startSlider.maxValue = track.duration;
    self.startSlider.floatValue = 0.f;
    self.startSlider.numberOfTickMarks = track.duration; // SECONDS. OMG. >_<
    self.endSlider.maxValue = track.duration;
    self.endSlider.floatValue = track.duration;
    self.endSlider.numberOfTickMarks = track.duration; // THOSE ARE SECONDS. AHMAGAD!! (╯°□°）╯︵ ┻━┻
    
    // Set the track title, artist, and album using the derived metadata.
    self.trackTitle.stringValue = track.title;
    self.trackSubtitle.stringValue = [NSString stringWithFormat:@"%@ / %@", track.albumName, track.artist];
    
    // Load the cover art using the derived data URI.
    [self layoutCoverArtWithIdentifier:[track.imageDataURI absoluteString]];                
}


- (void)layoutCoverArtWithIdentifier:(NSString *)identifier
{
    NSURL *htmlFileURL = [[NSBundle mainBundle] URLForResource:@"cover" withExtension:@"html"];
    NSError *err = nil;
    NSMutableString *html = [NSMutableString stringWithContentsOfURL:htmlFileURL encoding:NSUTF8StringEncoding error:&err];
    if (html == nil) {
        // Do something with the error.
        NSLog(@"%@", err);
        return;
    }
    
    [html replaceOccurrencesOfString:WindowControllerHTMLImagePlaceholder withString:identifier options:0 range:NSMakeRange(0, html.length)];
    [self.webView.mainFrame loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];
}

- (void)updateVolumeSlider
{
    float volume = [[AppDelegate sharedInstance].playbackController.track.asset volume];
    [self.volumeControl setFloatValue:volume];
}


#pragma mark Notification Observers

- (void)playbackHasProgressed:(NSNotification *)notification
{
    PlaybackController *object = [notification object];
    if ([object isKindOfClass:[PlaybackController class]]) {
        // Get the system calendar.
        NSCalendar *sysCalendar = [NSCalendar currentCalendar];
        
        // Create 2 NSDate objects whose difference is the NSTimeInterval 
        // we want to convert.
        NSDate *date1 = [[NSDate alloc] init];
        NSDate *date2 = [[NSDate alloc] initWithTimeInterval:object.track.asset.currentTime sinceDate:date1];

        // Get get the appropriate minutes/seconds conversation and place it
        // into our currentTime label.
        unsigned int unitFlags = NSMinuteCalendarUnit | NSSecondCalendarUnit;
        NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date1 toDate:date2 options:0];
        [self.currentTime setStringValue:[NSString stringWithFormat:@"%02d:%02d", [conversionInfo minute], [conversionInfo second]]];

        // Finally, update our progress bar's... progress.
        [self.progressBar setFloatValue:object.track.asset.currentTime];
    }    
}

- (void)trackLoopCountChanged:(NSNotification *)notification
{
    PlaybackController *object = [notification object];
    if ([object isKindOfClass:[PlaybackController class]]) {
        // Update the labels.
        if (object.loopCount < object.loopInfiniteCount) {
            [self.loopCountLabel setStringValue:[NSString stringWithFormat:@"x%d", object.loopCount]];
        }
        else {
            [self.loopCountLabel setStringValue:@"∞"];
        }
        
        // Finally, update the stepper so it's snychronized.
        [self.loopCountStepper setIntegerValue:object.loopCount];
    }
}

- (void)trackWasLoaded:(NSNotification *)notification
{
    PlaybackController *object = [notification object];
    if ([object isKindOfClass:[PlaybackController class]]) {      
        [self layoutInitialInterface:[object track]];
        [self showWindow:self];
        [self.play setEnabled:TRUE];
    }
}


#pragma mark IBAction Methods

- (IBAction)handlePlayState:(id)sender 
{
    PlaybackController *playbackController = [AppDelegate sharedInstance].playbackController;
    if (playbackController.track.asset.playing) {
        [playbackController stop];
    }
    else {
        [playbackController play];
    }
}

- (IBAction)incrementLoopCount:(id)sender 
{
    [[AppDelegate sharedInstance].playbackController updateLoopCount:[self.loopCountStepper intValue]];
}

- (IBAction)setFloatForStartSlider:(id)sender 
{
    PlaybackController *playbackController = [AppDelegate sharedInstance].playbackController;
    if (self.startSlider.doubleValue > playbackController.track.endTime) {
        playbackController.track.startTime = self.startSlider.doubleValue;
    }
    else {
        self.startSlider.doubleValue = playbackController.track.startTime;
    }
}

- (IBAction)setFloatForEndSlider:(id)sender 
{
    PlaybackController *playbackController = [AppDelegate sharedInstance].playbackController;
    if (self.endSlider.doubleValue > playbackController.track.startTime) {
        playbackController.track.endTime = self.endSlider.doubleValue;
    }
    else {
        self.endSlider.doubleValue = playbackController.track.startTime;
    }
}

- (IBAction)setTimeForCurrentTime:(id)sender 
{
    NSTimeInterval interval = self.progressBar.doubleValue;
    AVAudioPlayer *asset = [AppDelegate sharedInstance].playbackController.track.asset;
    asset.currentTime = interval;
}

- (IBAction)setFloatForVolume:(id)sender 
{
    float newValue = [sender floatValue];
    [[AppDelegate sharedInstance].playbackController.track.asset setVolume:newValue];
    [self updateVolumeSlider];
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

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

#import <WebKit/WebKit.h>

NSString *const WindowControllerHTMLImagePlaceholder = @"{{ image_url }}";

@interface WindowController () <NSWindowDelegate>
@property (nonatomic, retain) PlaybackController *playbackController;

- (void)composeInterface;
- (void)layoutTitleBarSegmentedControls;
- (void)layoutWebView;
- (void)updateUserInterface;
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

- (void)updateUserInterface
{
    float volume = [self.playbackController.track.asset volume];
    [self.volumeControl setFloatValue:volume];
}

#pragma mark IBAction Methods

- (IBAction)handlePlayState:(id)sender 
{
    PlaybackController *playbackController = [AppDelegate sharedInstance].playbackController;
    if (![playbackController paused]) {
        [[playbackController.track asset] stop];
        [playbackController setPaused:YES];
    }
    else {
        [[playbackController.track asset] play];
        [playbackController setPaused:NO];
    }
}

- (IBAction)incrementLoopCount:(id)sender 
{
    [[AppDelegate sharedInstance].playbackController updateLoopCount:[self.loopCountStepper intValue]];
}

- (IBAction)setFloatForStartSlider:(id)sender 
{
    if ([self.startSlider doubleValue] > (float)self.playbackController.track.endTime.timeValue) {
        self.playbackController.track.startTime = QTMakeTime((long)[self.startSlider doubleValue], self.playbackController.track.duration.timeScale);
    }
    else {
        [self.startSlider setFloatValue:(float)self.playbackController.track.startTime.timeValue];
    }
}

- (IBAction)setFloatForEndSlider:(id)sender {
    if ([self.endSlider doubleValue] > (float)self.playbackController.track.startTime.timeValue) {
        self.playbackController.track.endTime = QTMakeTime((long)[self.endSlider doubleValue], self.playbackController.track.duration.timeScale);
    }
    else {
        [self.endSlider setFloatValue:(float)self.playbackController.track.startTime.timeValue];
    }
}

- (IBAction)setTimeForCurrentTime:(id)sender 
{
    NSTimeInterval ti = [self.progressBar doubleValue];
    [self.playbackController setCurrentTime:QTMakeTime((long)ti, self.playbackController.track.duration.timeScale)];
}

- (IBAction)setFloatForVolume:(id)sender {
    float newValue = [sender floatValue];
    [self.playbackController.track.asset setVolume:newValue];
    [self updateUserInterface];
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

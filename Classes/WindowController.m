//
//  WindowController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "WindowController.h"

#import "INAppStoreWindow.h"

#import <WebKit/WebKit.h>

@interface WindowController () <NSWindowDelegate>
- (void)composeInterface;
- (void)layoutTitleBarSegmentedControls;
- (void)layoutWebView;
@end

@implementation WindowController

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
@synthesize openFile = _openFile;
@synthesize play = _play;
@synthesize volumeControl = _volumeControl;

+ (WindowController *)windowController
{
    return [[WindowController alloc] initWithWindowNibName:@"Window"];
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
    NSRect controlFrame = NSMakeRect(NSMidX([titleBarView bounds]) - (controlSize.width / 2.f), NSMidY([titleBarView bounds]) - (controlSize.height / 2.f), controlSize.width, controlSize.height);
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


#pragma mark IBAction Methods

- (IBAction)setFloatForStartSlider:(id)sender {
}

- (IBAction)setFloatForEndSlider:(id)sender {
}

- (IBAction)setTimeForCurrentTime:(id)sender {
}

- (IBAction)setFloatForVolume:(id)sender {
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

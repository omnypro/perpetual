//
//  WindowController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "WindowController.h"

#import "ApplicationController.h"
#import "DropHandlerView.h"
#import "DropZoneViewController.h"
#import "INAppStoreWindow.h"
#import "PlaybackController.h"
#import "PlayerViewController.h"
#import "PlayerFooterView.h"
#import "Track.h"

#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

@interface WindowController () <NSWindowDelegate>
@property (nonatomic, strong) PlaybackController *playbackController;
@property (nonatomic, strong) DropZoneViewController *dropZoneViewController;
@property (nonatomic, strong) NSViewController *currentViewController;
@property (nonatomic, strong) PlayerViewController *playerViewController;

- (void)setupControllers;
- (void)composeInterface;
- (void)layoutTitleBarSegmentedControls;
- (void)updateVolumeSlider;

- (void)swapViewController:(NSViewController *)viewController;
- (void)showPlayerView;

- (void)trackLoopCountChanged:(NSNotification *)notification;
@end

@implementation WindowController

@synthesize dropZoneViewController = _dropZoneViewController;
@synthesize playbackController = _playbackController;
@synthesize currentViewController = _currentViewController;
@synthesize playerViewController = _playerViewController;

@synthesize footerView = _footerView;
@synthesize masterView = _masterView;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileWasDropped:) name:FileWasDroppedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackLoopCountChanged:) name:TrackLoopCountChangedNotification object:nil];

    [self setupControllers];
    [self composeInterface];
}

#pragma mark Window Compositioning

- (void)setupControllers
{
    self.dropZoneViewController = [[DropZoneViewController alloc] initWithNibName:@"DropZone" bundle:nil];
    self.playerViewController = [[PlayerViewController alloc] initWithNibName:@"PlayerView" bundle:nil];

    self.currentViewController = self.dropZoneViewController;
    [self.currentViewController.view setFrame:self.masterView.bounds];
    [self.currentViewController.view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self.masterView addSubview:self.currentViewController.view];
}

- (void)composeInterface
{
    // Customize INAppStoreWindow.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    window.titleBarHeight = 35.f;
    window.trafficLightButtonsLeftMargin = 7.f;

    [self layoutTitleBarSegmentedControls];

    // Make all of our text labels look pretty.
    [[self.loopCountLabel cell] setBackgroundStyle:NSBackgroundStyleLowered];
}

- (void)layoutTitleBarSegmentedControls
{
    // - NOOP -
    // Implements a very crude NSSegmentedControl, used to switch between the
    // album view of the track currently opened and the listening statistics
    // for that track.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    NSView *titleBarView = [window titleBarView];
    NSSize controlSize = NSMakeSize(64.f, 32.f);
    NSRect controlFrame = NSMakeRect(NSMaxX([titleBarView bounds]) - (controlSize.width + 7.f), NSMidY([titleBarView bounds]) - (controlSize.height / 2.f + 1.f), controlSize.width, controlSize.height);

    NSSegmentedControl *switcher = [[NSSegmentedControl alloc] initWithFrame:controlFrame];
    [switcher setSegmentCount:2];
    [switcher setSegmentStyle:NSSegmentStyleTexturedRounded];
    [switcher setImage:[NSImage imageNamed:@"MusicNoteTemplate"] forSegment:0];
    [switcher setImage:[NSImage imageNamed:@"InfinityTemplate"] forSegment:1];
    [switcher setSelectedSegment:0];
    [switcher setEnabled:FALSE forSegment:1]; // Disables the statistics segment.
    [switcher setAutoresizingMask:NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin|NSViewMaxYMargin];
    [[switcher cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];

    [titleBarView addSubview:switcher];
}

- (void)updateVolumeSlider
{
    float volume = [[ApplicationController sharedInstance].playbackController.track.asset volume];
    [self.volumeControl setFloatValue:volume];
}


- (void)swapViewController:(NSViewController *)viewController
{
    // Don't switch the view if it doesn't need switching.
    if (self.currentViewController == viewController) return;

    NSView *currentView = [self.currentViewController view];
    NSView *swappedView = [viewController view];

    [self.masterView replaceSubview:currentView with:swappedView];
    self.currentViewController = viewController;
    currentView = swappedView;

    [currentView setFrame:[self.masterView bounds]];
    [currentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

- (void)showPlayerView
{
    [self swapViewController:self.playerViewController];
}


#pragma mark Notification Observers

- (void)fileWasDropped:(NSNotification *)notification
{
    DropHandlerView *object = [notification object];
    if ([object isKindOfClass:[DropHandlerView class]]) {
        if (self.currentViewController == self.dropZoneViewController) {
            // TODO: Animate this! o_o;
            [self showPlayerView];
        }

        [[[ApplicationController sharedInstance] playbackController] openURL:object.fileURL];
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


#pragma mark IBAction Methods

- (IBAction)handlePlayState:(id)sender
{
    PlaybackController *playbackController = [ApplicationController sharedInstance].playbackController;
    if (playbackController.track.asset.playing) {
        [playbackController stop];
    }
    else {
        [playbackController play];
    }
}

- (IBAction)incrementLoopCount:(id)sender
{
    [[ApplicationController sharedInstance].playbackController updateLoopCount:[self.loopCountStepper intValue]];
}

- (IBAction)setFloatForVolume:(id)sender
{
    float newValue = [sender floatValue];
    [[ApplicationController sharedInstance].playbackController.track.asset setVolume:newValue];
    [self updateVolumeSlider];
}


#pragma mark NSWindow Delegate Methods

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    return NSOffsetRect(NSInsetRect(rect, 8, 0), 0, -13);
}

@end

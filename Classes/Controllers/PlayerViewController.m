//
//  PlayerViewController.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlayerViewController.h"

#import "ApplicationController.h"
#import "NSString+TimeConversion.h"
#import "PlaybackController.h"
#import "SMDoubleSlider.h"
#import "Track.h"
#import "WindowController.h"

#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

NSString *const WindowControllerHTMLImagePlaceholder = @"{{ image_url }}";

@interface PlayerViewController ()
- (void)composeInterface;
- (void)layoutRangeSlider;
- (void)layoutWebView;
- (void)layoutInitialInterface:(Track *)track;
- (void)resetInterface;

- (void)playbackHasProgressed:(NSNotification *)notification;
- (void)trackWasLoaded:(NSNotification *)notification;
@end

@implementation PlayerViewController

@synthesize webView = _webView;
@synthesize trackTitle = _trackTitle;
@synthesize trackSubtitle = _trackSubtitle;
@synthesize currentTime = _currentTime;
@synthesize rangeTime = _rangeTime;
@synthesize progressBar = _progressBar;
@synthesize rangeSlider = _rangeSlider;

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self composeInterface];
}

- (void)loadView
{
    [super loadView];

    // Register notifications for our playback services.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackHasProgressed:) name:PlaybackHasProgressedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackWasLoaded:) name:TrackWasLoadedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rangeDidChange:) name:RangeDidChangeNotification object:nil];
}

- (void)composeInterface;
{
    [self layoutRangeSlider];
    [self layoutWebView];

    // Make all of our text labels look pretty.
    [[self.trackTitle cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [[self.trackSubtitle cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [[self.currentTime cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [[self.rangeTime cell] setBackgroundStyle:NSBackgroundStyleRaised];

    // Load our blank cover, since we obviously have no audio to play.
    [self layoutCoverArtWithIdentifier:@"cover.jpg"];
}

- (void)layoutRangeSlider;
{
    self.rangeSlider.allowsTickMarkValuesOnly = YES;
    self.rangeSlider.minValue = 0.f;
    self.rangeSlider.maxValue = 1.f;
    self.rangeSlider.doubleLoValue = 0.f;
    self.rangeSlider.doubleHiValue = 1.f;
    self.rangeSlider.numberOfTickMarks = 2;
    self.rangeSlider.tickMarkPosition = NSTickMarkAbove;
    [self.rangeSlider setAction:@selector(setFloatForSlider:)];
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

- (void)layoutInitialInterface:(Track *)track
{
    // Compose the initial user interface.
    // Set the max value of the progress bar to the duration of the track.
    self.progressBar.maxValue = track.duration;

    // Set the slider attributes.
    self.rangeSlider.maxValue = track.duration;
    self.rangeSlider.doubleHiValue = track.duration;
    self.rangeSlider.numberOfTickMarks = track.duration;

    // Fill in rangeTime with the difference between the two slider's values.
    // Until we start saving people's slider positions, this will always
    // equal the duration of the song at launch.
    NSTimeInterval rangeValue = self.rangeSlider.doubleHiValue - self.rangeSlider.doubleLoValue;
    self.rangeTime.stringValue = [NSString convertIntervalToMinutesAndSeconds:rangeValue];

    // Set the track title, artist, and album using the derived metadata.
    self.trackTitle.stringValue = track.title;
    if (track.albumName && track.artist != nil) {
        self.trackSubtitle.stringValue = [NSString stringWithFormat:@"%@ / %@", track.albumName, track.artist];
    }

    // Load the cover art using the derived data URI.
    if (track.imageDataURI != nil) {
        [self layoutCoverArtWithIdentifier:[track.imageDataURI absoluteString]];
    }
}

- (void)resetInterface
{
    self.trackTitle.stringValue = @"Untitled Song";
    self.trackSubtitle.stringValue = @"Untitled Album / Untitled Artist";
    [self layoutCoverArtWithIdentifier:@"cover.jpg"];
}


#pragma mark Notification Observers

- (void)playbackHasProgressed:(NSNotification *)notification
{
    PlaybackController *object = [notification object];
    if ([object isKindOfClass:[PlaybackController class]]) {
        self.currentTime.stringValue = [NSString convertIntervalToMinutesAndSeconds:object.track.asset.currentTime];
        self.progressBar.floatValue = object.track.asset.currentTime;
    }
}

- (void)rangeDidChange:(NSNotification *)notification
{
    NSTimeInterval rangeValue = self.rangeSlider.doubleHiValue - self.rangeSlider.doubleLoValue;
    self.rangeTime.stringValue = [NSString convertIntervalToMinutesAndSeconds:rangeValue];
}

- (void)trackWasLoaded:(NSNotification *)notification
{
    PlaybackController *object = [notification object];
    if ([object isKindOfClass:[PlaybackController class]]) {
        [self resetInterface];
        [self layoutInitialInterface:[object track]];

        WindowController *windowController = [ApplicationController sharedInstance].windowController;
        [windowController.play setEnabled:TRUE];
    }
}


#pragma mark IBAction Methods

- (IBAction)setFloatForSlider:(id)sender
{
    PlaybackController *playbackController = [ApplicationController sharedInstance].playbackController;
    playbackController.track.startTime = self.rangeSlider.doubleLoValue;
    playbackController.track.endTime = self.rangeSlider.doubleHiValue;
    [[NSNotificationCenter defaultCenter] postNotificationName:RangeDidChangeNotification object:self userInfo:nil];
}

- (IBAction)setTimeForCurrentTime:(id)sender
{
    NSTimeInterval interval = self.progressBar.doubleValue;
    AVAudioPlayer *asset = [ApplicationController sharedInstance].playbackController.track.asset;
    asset.currentTime = interval;
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

//
//  PlayerViewController.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlayerViewController.h"

#import "ApplicationController.h"
#import "PlaybackController.h"
#import "SMDoubleSlider.h"
#import "Track.h"

#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

NSString *const WindowControllerHTMLImagePlaceholder = @"{{ image_url }}";
NSString *const RangeDidChangeNotification = @"com.revyver.perpetual.RangeDidChangeNotification";

@interface PlayerViewController ()
@property (nonatomic, strong) PlaybackController *playbackController;

- (void)layoutRangeSlider;
- (void)layoutWebView;
- (void)resetInterface;
@end

@implementation PlayerViewController

// Cover and Statistics Display
@synthesize webView = _webView;

// Track Metadata Displays
@synthesize trackTitle = _trackTitle;
@synthesize trackSubtitle = _trackSubtitle;
@synthesize currentTime = _currentTime;
@synthesize rangeTime = _rangeTime;

// Sliders and Progress Bar
@synthesize progressBar = _progressBar;
@synthesize rangeSlider = _rangeSlider;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
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

- (void)resetInterface
{
    self.trackTitle.stringValue = @"Untitled Song";
    self.trackSubtitle.stringValue = @"Untitled Album / Untitled Artist";
    [self layoutCoverArtWithIdentifier:@"cover.jpg"];
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

//
//  AppDelegate.m
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "INAppStoreWindow.h"
#import "NSString+base64.h"

#import <CoreAudio/CoreAudio.h>
#import <QTKit/QTKit.h>
#import <WebKit/WebKit.h>

NSString *const AppDelegateHTMLImagePlaceholder = @"{{ image_url }}";

@implementation AppDelegate

@synthesize window = _window;
@synthesize startSlider = _startSlider;
@synthesize endSlider = _endSlider;
@synthesize currentTimeLabel = _currentTimeLabel;
@synthesize currentTimeBar = _currentTimeBar;
@synthesize playButton = _playButton;
@synthesize currentTrackLabel = _currentTrackLabel;
@synthesize loopCountLabel = _loopCountLabel;
@synthesize loopCountStepper = _loopCountStepper;
@synthesize coverWebView = _coverWebView;

@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;
@synthesize timeScale = _timeScale;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;
@synthesize currentTime = _currentTime;
@synthesize music = _music;
@synthesize paused = _paused;


- (void)setTheLoopCount:(NSUInteger)theLoopCount
{
    // Sets the property and updates the label.
    [self setLoopCount:theLoopCount];
    if ([self loopCount] < [self loopInfiniteCount]) {
        [self.loopCountLabel setStringValue:[NSString stringWithFormat:@"x%d",self.loopCount]];
    }
    else {
        [self.loopCountLabel setStringValue:@"∞"];
    }
    // Finally update the stepper so it's synchronized.
    [self.loopCountStepper setIntegerValue:[self loopCount]];
}

- (void)awakeFromNib
{
    // Customize INAppStoreWindow.
    [[self window] setDelegate:self];
    [[self window] setTitleBarHeight:40.0];
    [[self window] setTrafficLightButtonsLeftMargin:7.0];

    // Set us up as the delegate of the webView for relevant events.
    [[self coverWebView] setUIDelegate:self];
    [[self coverWebView] setFrameLoadDelegate:self];
    [[self coverWebView] setEditingDelegate:self];

    // Load our blank cover, since we obviously have no audio to play.
    [self loadCoverArtWithIdentifier:@"cover.jpg"];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // - NOOP -
    // Implements a very crude NSSegmentControl, used to switch between the album view
    // of the track currently opened and the listening statistics for that track.
    NSView *titleBarView = [[self window] titleBarView];
    NSSize switcherSize = NSMakeSize(100.f, 30.f);
    NSRect switcherFrame = NSMakeRect(NSMidX([titleBarView bounds]) - (switcherSize.width / 2.f), NSMidY([titleBarView bounds]) - (switcherSize.height / 2.f), switcherSize.width, switcherSize.height);
    NSSegmentedControl *switcher = [[NSSegmentedControl alloc] initWithFrame:switcherFrame];
    [switcher setSegmentCount:2];
    [switcher setSegmentStyle:NSSegmentStyleTexturedRounded];
    [switcher setLabel:@"Music" forSegment:0];
    [switcher setLabel:@"Statistics" forSegment:1];
    [switcher setSelectedSegment:0];
    [switcher setEnabled:FALSE forSegment:1]; // Disables the statistics segment.
    [[switcher cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    [titleBarView addSubview:switcher];

    // Basic implementation of the default loop count.
    // Infinity = 31 until further notice.
    [self setLoopInfiniteCount:31];
    [self setTheLoopCount:10];
    [[self loopCountStepper] setMaxValue:(double)[self loopInfiniteCount]];
}

- (void)checkTime:(NSTimer*)theTimer
{
    self.currentTime = [self.music currentTime];

    if (self.currentTime.timeValue >= self.endTime.timeValue && self.startTime.timeValue < self.endTime.timeValue && [self loopCount] > 0){
        if ([self loopCount] < [self loopInfiniteCount]) {
            // [self loopInfiniteCount] is the magic infinite number.
            [self setTheLoopCount:[self loopCount]-1];
        }
        [self.music setCurrentTime:self.startTime];
    }


    NSCalendar *sysCalendar = [NSCalendar currentCalendar];

    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:self.currentTime.timeValue/self.timeScale sinceDate:date1];

    unsigned int unitFlags = NSMinuteCalendarUnit | NSSecondCalendarUnit;

    NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];

    [self.currentTimeLabel setStringValue:[NSString stringWithFormat:@"%02d:%02d",[conversionInfo minute],[conversionInfo second]]];
    [self.currentTimeBar setFloatValue:(float)self.currentTime.timeValue];

}

- (void)loadMusic:(NSURL *) fileURL
{
    // Load the track from URL.
    NSError *err = nil;
    self.music = [[QTMovie alloc] initWithURL:fileURL error:&err];
    if (self.music == nil) {
        // TODO: Error handling.
        NSLog(@"%@", err);
        return;
    }

    //Really needed anymore?
    self.paused = YES;

    // Find and set slider max values.
    QTTime maxTime = [self.music duration];
    self.timeScale = [self.music duration].timeScale;
    float maxValue = (float)maxTime.timeValue;
    self.startTime = QTMakeTime(0.0, self.timeScale);
    self.endTime = maxTime;

    [self.currentTimeBar setMaxValue:maxValue];
    [self.startSlider setMaxValue:maxValue];
    [self.startSlider setFloatValue:0.0];
    [self.endSlider setMaxValue:maxValue];
    [self.endSlider setFloatValue:maxValue];
    [self.startSlider setNumberOfTickMarks:(int) maxValue/self.timeScale];
    [self.endSlider setNumberOfTickMarks:(int) maxValue/self.timeScale];

    // Set title and artist labels from.
    NSString *trackTitle = @"Unknown title";
    NSString *trackArtist = @"Unknown artist";

    NSArray * mdFormatsArray = [self.music availableMetadataFormats];
    for (int i=0;i<[mdFormatsArray count];i++) {
        NSArray * mdArray = [self.music metadataForFormat:[mdFormatsArray objectAtIndex:i]];
        // NSLog(@"%@", mdArray);
        // Fixme: find out why we need to replace @ with ©.
        NSArray * titleMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:[QTMetadataiTunesMetadataKeySongName stringByReplacingOccurrencesOfString:@"@" withString:@"©"] keySpace:nil];
        if ([titleMetadataItems count] > 0) {
            trackTitle = [[titleMetadataItems objectAtIndex:0] stringValue];
        }
        // Fixme: find out why we need to replace @ with ©.
        NSArray * artistMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:[QTMetadataiTunesMetadataKeyArtist stringByReplacingOccurrencesOfString:@"@" withString:@"©"] keySpace:nil];
        if ([artistMetadataItems count] > 0) {
            trackArtist = [[artistMetadataItems objectAtIndex:0] stringValue];
        }
        NSArray * coverArtMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:[QTMetadataiTunesMetadataKeyCoverArt stringByReplacingOccurrencesOfString:@"@" withString:@"©"] keySpace:nil];
        if ([coverArtMetadataItems count] > 0) {
            NSImage *coverArt = [[NSImage alloc] initWithData:[[coverArtMetadataItems objectAtIndex:0] dataValue]];
            NSLog(@"%@", coverArt);

            NSString *base64 = [NSString encodeBase64WithData:[[coverArtMetadataItems objectAtIndex:0] dataValue]];
            NSString *base64uri = [NSString stringWithFormat:@"data:image/png;base64,%@", base64];
            [self loadCoverArtWithIdentifier:base64uri];
        }
    }

    [self.currentTrackLabel setStringValue:[NSString stringWithFormat:@"%@\n%@",trackTitle,trackArtist]];

    // Start loop and play track.
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}

- (void)loadCoverArtWithIdentifier:(NSString *)identifier
{
    NSURL *htmlFileURL = [[NSBundle mainBundle] URLForResource:@"cover" withExtension:@"html"];
    NSError *err = nil;
    NSMutableString *html = [NSMutableString stringWithContentsOfURL:htmlFileURL encoding:NSUTF8StringEncoding error:&err];
    if (html == nil) {
        // Do something with the error.
        NSLog(@"%@", err);
        return;
    }

    [html replaceOccurrencesOfString:AppDelegateHTMLImagePlaceholder withString:identifier options:0 range:NSMakeRange(0, html.length)];
    [self.coverWebView.mainFrame loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];
}


- (BOOL)performOpen:(NSURL *)fileURL
{
    if (fileURL == nil) {
        return NO; // Make me smarter.
    }

    // Stop the music there's a track playing.
    [self.music stop];

    // Add the filename to the recently opened menu (hopefully).
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];

    // Bring the window to the foreground (if needed).
    [[self window] makeKeyAndOrderFront:self];

    // Play the funky music right boy.
    [self loadMusic:fileURL];
    return YES;
}

- (IBAction)openFile:(id)sender {
    void (^handler)(NSInteger);

    NSOpenPanel *panel = [NSOpenPanel openPanel];

    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"mp3", @"m4a", nil]];

    handler = ^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSString *filePath = [[panel URLs] objectAtIndex:0];
            if (![self performOpen:filePath]) {
                NSLog(@"Could not load music.");
            }
        }
    };

    [panel beginSheetModalForWindow:[self window] completionHandler:handler];
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    return [self performOpen:[NSURL fileURLWithPath:filename]];
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

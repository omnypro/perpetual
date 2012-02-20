//
//  AppDelegate.h
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@class INAppStoreWindow;
@class WebView;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (unsafe_unretained) IBOutlet INAppStoreWindow *window;
@property (weak) IBOutlet NSButton *playButton;
@property (weak) IBOutlet NSSlider *startSlider;
@property (weak) IBOutlet NSSlider *endSlider;
@property (weak) IBOutlet NSLevelIndicator *currentTimeBar;
@property (weak) IBOutlet NSTextField *currentTimeLabel;
@property (weak) IBOutlet NSTextField *trackTitle;
@property (weak) IBOutlet NSTextField *trackSubTitle;
@property (weak) IBOutlet NSTextField *loopCountLabel;
@property (weak) IBOutlet NSStepper *loopCountStepper;
@property (weak) IBOutlet WebView *coverWebView;
@property (weak) IBOutlet NSButton *openFileButton;
@property (weak) IBOutlet NSSlider *volumeSlider;

@property (assign) BOOL paused;
@property (assign) QTTime startTime;
@property (assign) QTTime endTime;
@property (assign) QTTime currentTime;
@property (assign) long timeScale;
@property (assign) NSUInteger loopCount;

// The value where we'll start looping infinitely.
@property (assign) NSInteger loopInfiniteCount;


@property (retain) QTMovie *music;
- (void)updateUserInterface;

- (void)checkTime:(NSTimer*)theTimer;
- (IBAction)loopStepperStep:(id)sender;
- (IBAction)playButtonClick:(id)sender;
- (IBAction)startSliderSet:(id)sender;
- (IBAction)endSliderSet:(id)sender;
- (IBAction)currentTimeBarSet:(id)sender;
- (IBAction)setFloatForVolume:(id)sender;

- (void)fetchMetadataForURL:(NSURL *)fileURL;
- (void)injectCoverArtWithIdentifier:(NSString *)identifier;

- (IBAction)openFile:(id)sender;
- (BOOL)performOpen:(NSString *)filename;

@end

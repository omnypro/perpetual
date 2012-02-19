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

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) IBOutlet INAppStoreWindow *window;
@property (weak) IBOutlet NSButton *playButton;
@property (weak) IBOutlet NSSlider *startSlider;
@property (weak) IBOutlet NSSlider *endSlider;
@property (weak) IBOutlet NSLevelIndicator *currentTimeBar;
@property (weak) IBOutlet NSTextField *currentTimeLabel;
@property (weak) IBOutlet NSTextField *currentTrackLabel;
@property (weak) IBOutlet NSTextField *loopCountLabel;
@property (weak) IBOutlet NSStepper *loopCountStepper;
@property (weak) IBOutlet WebView *coverWebView;

@property (assign) BOOL paused;
@property (assign) QTTime startTime;
@property (assign) QTTime endTime;
@property (assign) QTTime currentTime;
@property (assign) long timeScale;
@property (assign) NSUInteger loopCount;

// The value where we'll start looping infinitely.
@property (assign) NSInteger loopInfiniteCount;


@property (retain) QTMovie *music;
- (void)checkTime:(NSTimer*)theTimer;
- (IBAction)loopStepperStep:(id)sender;
- (IBAction)playButtonClick:(id)sender;
- (IBAction)startSliderSet:(id)sender;
- (IBAction)endSliderSet:(id)sender;
- (IBAction)currentTimeBarSet:(id)sender;

- (void)loadCoverArtWithIdentifier:(NSString *)identifier;
@end

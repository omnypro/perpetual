//
//  AppDelegate.h
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>
#import "INAppStoreWindow.h"
#import "TooltipWindow.h"
#import "ColorGradientView.h"

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
@property (weak) IBOutlet ColorGradientView *gradientView;


@property (assign) BOOL paused;
@property (assign) QTTime startTime;
@property (assign) QTTime endTime;
@property (assign) QTTime currentTime;
@property (assign) long timeScale;
@property (assign) int loopCount;
@property (nonatomic, strong) TooltipWindow * TimeTooltip;



//The value where we'll start looping infinitely
@property (assign) int loopInfiniteCount;


@property (retain) QTMovie *music;
- (NSString*)QTTimeToString:(QTTime) time;
- (void)checkTime:(NSTimer*)theTimer;
- (IBAction)loopStepperStep:(id)sender;
- (IBAction)playButtonClick:(id)sender;
- (IBAction)startSliderSet:(id)sender;
- (IBAction)endSliderSet:(id)sender;
- (IBAction)currentTimeBarSet:(id)sender;
- (IBAction)openFile:(id)sender;
@end

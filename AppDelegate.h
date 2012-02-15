//
//  AppDelegate.h
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "INAppStoreWindow.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (unsafe_unretained) INAppStoreWindow *window;

@property (weak) IBOutlet NSButton *playButton;
@property (weak) IBOutlet NSSlider *startSlider;
@property (weak) IBOutlet NSSlider *endSlider;
@property (weak) IBOutlet NSLevelIndicator *currentTimeBar;
@property (weak) IBOutlet NSTextField *currentTimeLabel;

@property (assign) BOOL paused;
@property (assign) double startTime;
@property (assign) double endTime;
@property (assign) double currentTime;

@property (retain) NSSound *music;
- (void)checkTime:(NSTimer*)theTimer;
- (IBAction)playButtonClick:(id)sender;
- (IBAction)startSliderSet:(id)sender;
- (IBAction)endSliderSet:(id)sender;
- (IBAction)currentTimeBarSet:(id)sender;
- (IBAction)openFile:(id)sender;
@end

//
//  WindowController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WebView;

@interface WindowController : NSWindowController 

// Cover and Statistics Display
@property (weak) IBOutlet WebView *webView;

// Track Metadata Displays
@property (weak) IBOutlet NSTextField *trackTitle;
@property (weak) IBOutlet NSTextField *trackSubtitle;
@property (weak) IBOutlet NSTextField *currentTime;
@property (weak) IBOutlet NSTextField *rangeTime;

// Sliders and Progress Bar
@property (weak) IBOutlet NSSlider *startSlider;
@property (weak) IBOutlet NSSlider *endSlider;
@property (weak) IBOutlet NSLevelIndicator *progressBar;

// Lower Toolbar
@property (weak) IBOutlet NSButton *open;
@property (weak) IBOutlet NSButton *play;
@property (weak) IBOutlet NSSlider *volumeControl;
@property (weak) IBOutlet NSTextField *loopCountLabel;
@property (weak) IBOutlet NSStepper *loopCountStepper;

+ (WindowController *)windowController;

- (IBAction)incrementLoopCount:(id)sender;
- (IBAction)openFile:(id)sender;
- (IBAction)setFloatForStartSlider:(id)sender;
- (IBAction)setFloatForEndSlider:(id)sender;
- (IBAction)setTimeForCurrentTime:(id)sender;
- (IBAction)setFloatForVolume:(id)sender;

@end

//
//  WindowController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PlayerFooterView;
@class SMDoubleSlider;
@class WebView;

@interface WindowController : NSWindowController

@property (weak) IBOutlet PlayerFooterView *footerView;

// Cover and Statistics Display
@property (weak) IBOutlet WebView *webView;

// Track Metadata Displays
@property (weak) IBOutlet NSTextField *trackTitle;
@property (weak) IBOutlet NSTextField *trackSubtitle;
@property (weak) IBOutlet NSTextField *currentTime;
@property (weak) IBOutlet NSTextField *rangeTime;

// Sliders and Progress Bar
@property (weak) IBOutlet NSLevelIndicator *progressBar;
@property (weak) IBOutlet SMDoubleSlider *rangeSlider;

// Lower Toolbar
@property (weak) IBOutlet NSButton *open;
@property (weak) IBOutlet NSButton *play;
@property (weak) IBOutlet NSSlider *volumeControl;
@property (weak) IBOutlet NSTextField *loopCountLabel;
@property (weak) IBOutlet NSStepper *loopCountStepper;

- (void)layoutCoverArtWithIdentifier:(NSString *)identifier;

- (IBAction)handlePlayState:(id)sender;
- (IBAction)incrementLoopCount:(id)sender;
- (IBAction)setFloatForSlider:(id)sender;
- (IBAction)setTimeForCurrentTime:(id)sender;
- (IBAction)setFloatForVolume:(id)sender;

@end

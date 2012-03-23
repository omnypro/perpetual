//
//  PlayerViewController.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMDoubleSlider;
@class WebView;

@interface PlayerViewController : NSViewController

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

@end

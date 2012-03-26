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

@property (weak) IBOutlet WebView *webView;
@property (weak) IBOutlet NSTextField *trackTitle;
@property (weak) IBOutlet NSTextField *trackSubtitle;
@property (weak) IBOutlet NSTextField *currentTime;
@property (weak) IBOutlet NSTextField *rangeTime;
@property (weak) IBOutlet NSLevelIndicator *progressBar;
@property (weak) IBOutlet SMDoubleSlider *rangeSlider;

- (void)layoutCoverArtWithIdentifier:(NSString *)identifier;

- (IBAction)setFloatForSlider:(id)sender;
- (IBAction)setTimeForCurrentTime:(id)sender;

@end

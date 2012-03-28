//
//  WindowController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PlayerFooterView;

@interface WindowController : NSWindowController

@property (weak) IBOutlet PlayerFooterView *footerView;
@property (weak) IBOutlet NSView *masterView;

@property (weak) IBOutlet NSButton *open;
@property (weak) IBOutlet NSButton *play;
@property (weak) IBOutlet NSSlider *volumeControl;
@property (weak) IBOutlet NSTextField *loopCountLabel;
@property (weak) IBOutlet NSStepper *loopCountStepper;

- (void)showPlayerView;

- (IBAction)handlePlayState:(id)sender;
- (IBAction)incrementLoopCount:(id)sender;
- (IBAction)setFloatForVolume:(id)sender;

@end

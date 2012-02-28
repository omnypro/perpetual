//
//  WindowController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "WindowController.h"

#import "INAppStoreWindow.h"

@interface WindowController () <NSWindowDelegate>
- (void)composeInterface;
- (void)layoutTitleBarSegmentedControls;
@end

@implementation WindowController

+ (WindowController *)windowController
{
    return [[WindowController alloc] initWithWindowNibName:@"Window"];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self composeInterface];
}

- (void)composeInterface
{
    // Customize INAppStoreWindow.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    window.titleBarHeight = 40.f;
    window.trafficLightButtonsLeftMargin = 7.f;
    
    [self layoutTitleBarSegmentedControls];
}

- (void)layoutTitleBarSegmentedControls
{
    // - NOOP -
    // Implements a very crude NSSegmentedControl, used to switch between the 
    // album view of the track currently opened and the listening statistics 
    // for that track.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    NSView *titleBarView = [window titleBarView];
    NSSize controlSize = NSMakeSize(100.f, 32.f);
    NSRect controlFrame = NSMakeRect(NSMidX([titleBarView bounds]) - (controlSize.width / 2.f), NSMidY([titleBarView bounds]) - (controlSize.height / 2.f), controlSize.width, controlSize.height);
    NSSegmentedControl *switcher = [[NSSegmentedControl alloc] initWithFrame:controlFrame];
    [switcher setSegmentCount:2];
    [switcher setSegmentStyle:NSSegmentStyleTexturedRounded];
    [switcher setLabel:@"Music" forSegment:0];
    [switcher setLabel:@"Statistics" forSegment:1];
    [switcher setSelectedSegment:0];
    [switcher setEnabled:FALSE forSegment:1]; // Disables the statistics segment.
    [switcher setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
    [[switcher cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    [titleBarView addSubview:switcher];
}

@end

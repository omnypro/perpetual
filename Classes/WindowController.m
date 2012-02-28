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
    window.titleBarHeight = 40.0f;
    window.trafficLightButtonsLeftMargin = 7.0f;
    
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
}

@end

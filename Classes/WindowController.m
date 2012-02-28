//
//  WindowController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "WindowController.h"

#import "INAppStoreWindow.h"

@implementation WindowController

+ (WindowController *)windowController
{
    return [[WindowController alloc] initWithWindowNibName:@"Window"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Customize INAppStoreWindow.
    INAppStoreWindow *window = (INAppStoreWindow *)[self window];
    window.titleBarHeight = 40.0f;
    window.trafficLightButtonsLeftMargin = 7.0f;
}

@end

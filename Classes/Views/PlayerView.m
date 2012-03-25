//
//  PlayerView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/25/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlayerView.h"

@implementation PlayerView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    
    //// Abstracted Graphic Attributes
    NSRect rectangleFrame = NSMakeRect(0, 70, 480, 50);
    NSRect rectangle2Frame = NSMakeRect(0, 0, 480, 70);
    
    //// Rectangle Drawing
    NSBezierPath* rectanglePath = [NSBezierPath bezierPathWithRect: rectangleFrame];
    [[NSColor lightGrayColor] setFill];
    [rectanglePath fill];
    
    //// Rectangle 2 Drawing
    NSBezierPath* rectangle2Path = [NSBezierPath bezierPathWithRect: rectangle2Frame];
    [[NSColor darkGrayColor] setFill];
    [rectangle2Path fill];
}

@end

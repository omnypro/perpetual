//
//  ColorGradientView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "ColorGradientView.h"

@implementation ColorGradientView

@synthesize startingColor = _startingColor;
@synthesize endingColor = _endingColor;
@synthesize angle = _angle;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.startingColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
        self.endingColor = nil;
        self.angle = 270;
    }
    return self;
}

- (void)drawRect:(NSRect)rect
{
    if (self.endingColor == nil || [self.startingColor isEqual:self.endingColor]) {
        [self.startingColor set];
        NSRectFill(rect);
    }
    else {
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:self.startingColor endingColor:self.endingColor];
        [gradient drawInRect:self.bounds angle:self.angle];
    }
}

@end

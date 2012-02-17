//
//  ColorGradientView.m
//  Perpetual
//
//  Created by Kalle Persson on 2/17/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import "ColorGradientView.h"
@implementation ColorGradientView

// Automatically create accessor methods
@synthesize startingStrokeColor;
@synthesize endingStrokeColor;
@synthesize startingColor;
@synthesize endingColor;
@synthesize angle;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
        [self setEndingColor:nil];
        [self setAngle:270];
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
    if (endingColor == nil || [startingColor isEqual:endingColor]) {
        [startingColor set];
        NSRectFill(rect);
    }
    else {
        NSGradient* aGradient;
        if(startingStrokeColor != nil && startingColor != nil && endingColor != nil && endingStrokeColor != nil) {
            aGradient = [[NSGradient alloc] initWithColorsAndLocations:startingStrokeColor,0.0,startingColor,0.02,endingColor,0.98,endingStrokeColor,1.0,nil];
        }
        else if(startingStrokeColor != nil && startingColor != nil && endingColor != nil) {
            aGradient = [[NSGradient alloc] initWithColorsAndLocations:startingStrokeColor,0.0,startingColor,0.05,endingColor,1.0,nil];
        }
        else if(startingColor != nil && endingColor != nil && endingStrokeColor != nil) {
            aGradient = [[NSGradient alloc] initWithColorsAndLocations:startingColor,1.0,endingColor,0.95,endingStrokeColor,1.0,nil];
        }
        else if(startingColor != nil && endingColor != nil) {
            aGradient = [[NSGradient alloc] initWithColorsAndLocations:startingColor,0.0,endingColor,1.0,nil];
        }
        [aGradient drawInRect:[self bounds] angle:angle];
    }
}

@end
//
//  ColorGradientView.h
//  Perpetual
//
//  Created by Kalle Persson on 2/17/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface ColorGradientView : NSView
{
    NSColor *startingColor;
    NSColor *endingColor;
    NSColor *startingStrokeColor;
    NSColor *endingStrokeColor;
    int angle;
}

// Define the variables as properties
@property(nonatomic, retain) NSColor *startingColor;
@property(nonatomic, retain) NSColor *endingColor;
@property(nonatomic, retain) NSColor *startingStrokeColor;
@property(nonatomic, retain) NSColor *endingStrokeColor;

@property(assign) int angle;

@end
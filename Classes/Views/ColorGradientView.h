//
//  ColorGradientView.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ColorGradientView : NSView

@property (nonatomic, retain) NSColor *startingColor;
@property (nonatomic, retain) NSColor *endingColor;
@property (assign) int angle;

@end

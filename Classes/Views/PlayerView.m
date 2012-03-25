//
//  PlayerView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/25/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlayerView.h"

#import "NSColor+Hex.h"

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
    
    //// Color Declarations
    NSColor* topColor = [NSColor colorWithCalibratedRed: 0.97 green: 0.97 blue: 0.97 alpha: 1];
    NSColor* bottomColor = [NSColor colorWithCalibratedRed: 0.82 green: 0.82 blue: 0.82 alpha: 1];
    NSColor* topHighlightCover = [NSColor whiteColor];
    NSColor* bottomShadowColor = [NSColor colorWithCalibratedRed: 0.62 green: 0.62 blue: 0.62 alpha: 1];
    
    //// Gradient Declarations
    NSGradient* gradient = [[NSGradient alloc] initWithStartingColor: topColor endingColor: bottomColor];
    
    //// Shadow Declarations
    NSShadow* innerShadow = [[NSShadow alloc] init];
    [innerShadow setShadowColor: topHighlightCover];
    [innerShadow setShadowOffset: NSMakeSize(0, -1)];
    [innerShadow setShadowBlurRadius: 0];
    NSShadow* dropShadow = [[NSShadow alloc] init];
    [dropShadow setShadowColor: bottomShadowColor];
    [dropShadow setShadowOffset: NSMakeSize(0, -1)];
    [dropShadow setShadowBlurRadius: 0];
    
    //// Abstracted Graphic Attributes
    NSRect rectangle2Frame = NSMakeRect(0, 0, 480, 72);
    NSRect rectangleFrame = NSMakeRect(0, 72, 480, 48);
    
    
    //// Rectangle 2 Drawing
    NSBezierPath* rectangle2Path = [NSBezierPath bezierPathWithRect: rectangle2Frame];
    [[NSColor colorWithHex:@"#151515"] setFill];
    [rectangle2Path fill];
    
    
    
    //// Rectangle Drawing
    NSBezierPath* rectanglePath = [NSBezierPath bezierPathWithRect: rectangleFrame];
    [NSGraphicsContext saveGraphicsState];
    [dropShadow set];
    [dropShadow.shadowColor setFill];
    [rectanglePath fill];
    [gradient drawInBezierPath: rectanglePath angle: -90];
    
    ////// Rectangle Inner Shadow
    NSRect rectangleBorderRect = NSInsetRect([rectanglePath bounds], -innerShadow.shadowBlurRadius, -innerShadow.shadowBlurRadius);
    rectangleBorderRect = NSOffsetRect(rectangleBorderRect, -innerShadow.shadowOffset.width, -innerShadow.shadowOffset.height);
    rectangleBorderRect = NSInsetRect(NSUnionRect(rectangleBorderRect, [rectanglePath bounds]), -1, -1);
    
    NSBezierPath* rectangleNegativePath = [NSBezierPath bezierPathWithRect: rectangleBorderRect];
    [rectangleNegativePath appendBezierPath: rectanglePath];
    [rectangleNegativePath setWindingRule: NSEvenOddWindingRule];
    
    [NSGraphicsContext saveGraphicsState];
    {
        NSShadow* innerShadow = [innerShadow copy];
        CGFloat xOffset = innerShadow.shadowOffset.width + round(rectangleBorderRect.size.width);
        CGFloat yOffset = innerShadow.shadowOffset.height;
        innerShadow.shadowOffset = NSMakeSize(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset));
        [innerShadow set];
        [[NSColor grayColor] setFill];
        [rectanglePath addClip];
        NSAffineTransform* transform = [NSAffineTransform transform];
        [transform translateXBy: -round(rectangleBorderRect.size.width) yBy: 0];
        [[transform transformBezierPath: rectangleNegativePath] fill];
    }
    [NSGraphicsContext restoreGraphicsState];
    
    [NSGraphicsContext restoreGraphicsState];
    
    
}

@end

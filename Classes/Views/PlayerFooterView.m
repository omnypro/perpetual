//
//  PlayerFooterView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/22/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlayerFooterView.h"

#import "NSColor+Hex.h"

@implementation PlayerFooterView

- (void)drawRect:(NSRect)rect
{
    NSGradient* gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithHex:@"#303030"] endingColor:[NSColor colorWithHex:@"#1f1f1f"]];
    
    NSShadow* shadow = [[NSShadow alloc] init];
    [shadow setShadowColor:[NSColor colorWithHex:@"#505050"]];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:0];
    
    NSBezierPath* path = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, 480, 32)];
    [gradient drawInBezierPath: path angle: -90];
    
    NSRect borderRect = NSInsetRect([path bounds], -shadow.shadowBlurRadius, -shadow.shadowBlurRadius);
    borderRect = NSOffsetRect(borderRect, -shadow.shadowOffset.width, -shadow.shadowOffset.height);
    borderRect = NSInsetRect(NSUnionRect(borderRect, [path bounds]), -1, -1);
    
    NSBezierPath* negativePath = [NSBezierPath bezierPathWithRect: borderRect];
    [negativePath appendBezierPath:path];
    [negativePath setWindingRule:NSEvenOddWindingRule];
    
    [NSGraphicsContext saveGraphicsState];
    {
        NSShadow* innerShadow = [shadow copy];
        CGFloat xOffset = innerShadow.shadowOffset.width + round(borderRect.size.width);
        CGFloat yOffset = innerShadow.shadowOffset.height;
        innerShadow.shadowOffset = NSMakeSize(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset));
        [innerShadow set];
        [[NSColor grayColor] setFill];
        [path addClip];
        NSAffineTransform* transform = [NSAffineTransform transform];
        [transform translateXBy:-round(borderRect.size.width) yBy: 0];
        [[transform transformBezierPath:negativePath] fill];
    }
    [NSGraphicsContext restoreGraphicsState];
}

@end

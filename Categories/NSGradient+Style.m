//
//  NSGradient+Style.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/6/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "NSGradient+Style.h"

@implementation NSGradient (Style)

+ (NSGradient *)gradientWithColors:(NSArray *)colorArray {
	
	return [[self alloc] initWithColors:colorArray];
}

+ (NSGradient *)gradientWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor;
{
    return [self gradientWithColors:[NSArray arrayWithObjects:startingColor, endingColor, nil]];
}

@end

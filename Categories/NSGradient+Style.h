//
//  NSGradient+Style.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/6/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSGradient (Style)

+ (NSGradient *)gradientWithColors:(NSArray *)colorArray;
+ (NSGradient *)gradientWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor;

@end

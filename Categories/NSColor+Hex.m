//
//  NSColor+Hex.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/5/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "NSColor+Hex.h"

@implementation NSColor (Hex)

+ (NSColor *) colorWithHex:(NSString *)hexColor
{
    // Remove the hash if it exists.
    hexColor = [hexColor stringByReplacingOccurrencesOfString:@"#" withString:@""];
    int length = (int)[hexColor length];
    bool triple = (length == 3);
    
    NSMutableArray *rgb = [[NSMutableArray alloc] init];
    
    // Make sure the string is three or six characters long.
    if (triple || length == 6) {
        
        CFIndex i = 0;
        UniChar character = 0;
        NSString *segment = @"";
        CFStringInlineBuffer buffer;
        CFStringInitInlineBuffer((__bridge CFStringRef)hexColor, &buffer, CFRangeMake(0, length));
        
        while ((character = CFStringGetCharacterFromInlineBuffer(&buffer, i)) != 0 ) {
            if (triple) segment = [segment stringByAppendingFormat:@"%c%c", character, character];
            else segment = [segment stringByAppendingFormat:@"%c", character];
            
            if ((int)[segment length] == 2) {
                NSScanner *scanner = [[NSScanner alloc] initWithString:segment];
                
                unsigned number;
                
                while([scanner scanHexInt:&number]){
                    [rgb addObject:[NSNumber numberWithFloat:(float)(number / (float)255)]];
                }
                segment = @"";
            }
            i++;
        }
     
        // Pad the array out (for cases where we're given invalid input),
        while ([rgb count] != 3) [rgb addObject:[NSNumber numberWithFloat:0.0]];
        
        return [NSColor colorWithCalibratedRed:[[rgb objectAtIndex:0] floatValue] green:[[rgb objectAtIndex:1] floatValue] blue:[[rgb objectAtIndex:2] floatValue] alpha:1];
    }
    else {
        NSException* invalidHexException = [NSException exceptionWithName:@"InvalidHexException" reason:@"Hex color not three or six characters (excluding hash)." userInfo:nil];
        @throw invalidHexException;
    }    
}

- (NSString *) hexColor
{
    float r, g, b;
    
    if ([[self colorSpaceName] isEqualToString:NSCalibratedWhiteColorSpace]) {
        r = [self whiteComponent];
        g = [self whiteComponent];
        b = [self whiteComponent];
    }
    else if ([[self colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace] || [[self colorSpaceName] isEqualToString:NSDeviceRGBColorSpace]) {
        r = [self redComponent];
        g = [self greenComponent];
        b = [self blueComponent];
    } 
    else {
        return @"transparent";
    }
    
    return [NSString stringWithFormat:@"#%0.2X%0.2X%0.2X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];    
}

@end

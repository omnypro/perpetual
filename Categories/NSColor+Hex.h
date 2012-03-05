//
//  NSColor+Hex.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/5/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSColor (Hex)

+ (NSColor *) colorWithHex:(NSString *)hexColor;

- (NSString *) hexColor;

@end

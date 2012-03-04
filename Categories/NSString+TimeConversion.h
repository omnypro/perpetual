//
//  NSString+TimeConversion.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/3/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (TimeConversion)

+ (NSString *)convertIntervalToMinutesAndSeconds:(NSTimeInterval)interval;

@end

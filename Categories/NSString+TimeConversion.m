//
//  NSString+TimeConversion.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/3/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "NSString+TimeConversion.h"

@implementation NSString (TimeConversion)

+ (NSString *)convertIntervalToMinutesAndSeconds:(NSTimeInterval)interval
{
    // Get the system calendar.
    NSCalendar *sysCalendar = [NSCalendar currentCalendar];
    
    // Create 2 NSDate objects whose difference is the NSTimeInterval
    // we want to convert.
    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:interval sinceDate:date1];
    
    // Get get the appropriate minutes/seconds conversation and place it
    // into our currentTime label.
    unsigned int unitFlags = NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date1 toDate:date2 options:0];    
    return [NSString stringWithFormat:@"%02d:%02d", [conversionInfo minute], [conversionInfo second]];
}

@end

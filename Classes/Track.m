//
//  Track.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "Track.h"

@implementation Track

@synthesize asset = _asset;
@synthesize duration = _duration;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;

- (id)initWithFileURL:(NSURL *)fileURL
{
    self = [super init];
    if (!self) {
        NSLog(@"Could not initialize track.");
        return nil;
    }
    
    NSError *err = nil;
    self.asset = [[QTMovie alloc] initWithURL:fileURL error:&err];
    if (self.asset == nil) {
        NSLog(@"%@", err);
        return nil;
    }
    
    self.duration = [self.asset duration];
    self.startTime = QTMakeTime(0.0, self.duration.timeScale);
    self.endTime = self.duration;
    
    return self;
}

@end

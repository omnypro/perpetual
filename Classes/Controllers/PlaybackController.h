//
//  PlaybackController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

@interface PlaybackController : NSObject

@property (nonatomic, readonly, strong) Track *track;

@property (assign) BOOL paused;
@property (assign) NSUInteger loopCount;
@property (assign) NSUInteger loopInfiniteCount;

- (void)updateLoopCount:(NSUInteger)count;
- (BOOL)openURL:(NSURL *)filename;
- (void)play;
- (void)stop;

@end

//
//  PlaybackController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Track;

extern NSString *const PlaybackDidStartNotification;
extern NSString *const PlaybackDidStopNotification;
extern NSString *const PlaybackHasProgressedNotification;
extern NSString *const TrackLoopCountChangedNotification;
extern NSString *const TrackWasLoadedNotification;

@interface PlaybackController : NSObject

@property (nonatomic, readonly, strong) Track *track;

@property (assign) BOOL paused;
@property (assign) NSTimeInterval currentTime;
@property (assign) NSUInteger loopCount;
@property (assign) NSUInteger loopInfiniteCount;

- (void)updateLoopCount:(NSUInteger)count;
- (BOOL)openURL:(NSURL *)filename;
- (void)play;
- (void)stop;

@end

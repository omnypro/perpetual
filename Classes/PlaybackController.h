//
//  PlaybackController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <QTKit/QTKit.h>

@class Track;

extern NSString *const TrackWasLoadedNotification;
extern NSString *const PlaybackDidStartNotification;
extern NSString *const PlaybackDidStopNotification;

@interface PlaybackController : NSObject

@property (nonatomic, readonly, strong) Track *track;

@property (assign) BOOL paused;
@property (assign) QTTime currentTime;
@property (assign) NSUInteger loopCount;
@property (assign) NSUInteger loopInfiniteCount;

- (void)updateLoopCount:(NSUInteger)count;
- (BOOL)openURL:(NSURL *)filename;

@end

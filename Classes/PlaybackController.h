//
//  PlaybackController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <QTKit/QTKit.h>

@class Track;

@interface PlaybackController : NSObject

@property (nonatomic, readonly, retain) Track *track;

@property (assign) BOOL paused;
@property (assign) QTTime currentTime;
@property (assign) NSUInteger loopCount;
@property (assign) NSUInteger loopInfiniteCount;

+ (PlaybackController *)playbackController;

- (void)updateLoopCount:(NSUInteger)count;
- (IBAction)openFile:(id)sender;

@end

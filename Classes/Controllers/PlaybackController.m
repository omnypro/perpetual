//
//  PlaybackController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlaybackController.h"

#import "Constants.h"
#import "Track.h"

@interface PlaybackController ()
@property (nonatomic, strong) Track *track;

- (void)loadTrack;
@end

@implementation PlaybackController

@synthesize track = _track;

@synthesize paused = _paused;
@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name:FileWasDroppedNotification object:nil];
    }

    return self;
}

- (void)updateLoopCount:(NSUInteger)count
{
    self.loopCount = count;
    [[NSNotificationCenter defaultCenter] postNotificationName:TrackLoopCountChangedNotification object:self userInfo:nil];
}

- (void)checkTime:(NSTimer *)timer
{
    if (self.track.asset.currentTime >= self.track.endTime && self.track.startTime < self.track.endTime && self.loopCount > 0) {
        if (self.loopCount < self.loopInfiniteCount) {
            [self updateLoopCount:self.loopCount - 1];
        }
        self.track.asset.currentTime = self.track.startTime;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackHasProgressedNotification object:self userInfo:nil];
}


# pragma mark File Handling

- (void)loadTrack
{
    // Broadcast a notification to tell the UI to update.
    [[NSNotificationCenter defaultCenter] postNotificationName:TrackWasLoadedNotification object:self userInfo:nil];

    // Start the timer loop.
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}

- (BOOL)openURL:(NSURL *)fileURL
{
    if (fileURL == nil) {
        return NO; // Make me smarter.
    }

    // Stop the music there's a track playing.
    [[self.track asset] stop];

    // Add the filename to the recently opened menu (hopefully).
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];

    // Play the funky music right boy.
    [self setTrack:[[Track alloc] initWithFileURL:fileURL]];
    [self loadTrack];
    return YES;
}


# pragma mark Playback Handling

- (void)play
{
    [self.track.asset play];
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackDidStartNotification object:self userInfo:nil];
}


- (void)stop
{
    [self.track.asset stop];
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackDidStopNotification object:self userInfo:nil];
}

@end

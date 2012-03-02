//
//  PlaybackController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlaybackController.h"

#import "AppDelegate.h"
#import "Track.h"
#import "WindowController.h"

NSString *const PlaybackDidStartNotification = @"com.revyver.perpetual.PlaybackDidStartNotification"; 
NSString *const PlaybackDidStopNotification = @"com.revyver.perpetual.PlaybackDidStopNotification";
NSString *const PlaybackHasProgressedNotification = @"com.revyver.perpetual.PlaybackHasProgressedNotification";
NSString *const TrackLoopCountChangedNotification = @"com.revyver.perpetual.TrackLoopCountChangedNotification";
NSString *const TrackWasLoadedNotification = @"com.revyver.perpetual.TrackWasLoadedNotification";

@interface PlaybackController ()
@property (nonatomic, strong) Track *track;

- (void)loadTrack;
@end

@implementation PlaybackController

@synthesize track = _track;

@synthesize paused = _paused;
@synthesize currentTime = _currentTime;
@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;

- (void)updateLoopCount:(NSUInteger)count {  
    self.loopCount = count;
    [[NSNotificationCenter defaultCenter] postNotificationName:TrackLoopCountChangedNotification object:self userInfo:nil];
}

- (void)checkTime:(NSTimer *)timer
{
    self.currentTime = [self.track.asset currentTime];
    
    if (self.currentTime.timeValue >= self.track.endTime.timeValue && self.track.startTime.timeValue < self.track.endTime.timeValue && self.loopCount > 0) {
        if (self.loopCount < self.loopInfiniteCount) {
            [self updateLoopCount:self.loopCount - 1];
        }
        self.currentTime = self.track.startTime;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackHasProgressedNotification object:self userInfo:nil];
}


# pragma mark File Handling

- (void)loadTrack
{
    // Is this really needed?
    self.paused = YES;
     
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
    
    // Bring the window to the foreground (if needed).
    [[AppDelegate sharedInstance].windowController showWindow:self];
    
    // Play the funky music right boy.
    [self setTrack:[[Track alloc] initWithFileURL:fileURL]];
    [self loadTrack];
    return YES;
}


# pragma mark Playback Handling

- (void)play
{
    [self.track.asset play];
    self.paused = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackDidStartNotification object:self userInfo:nil];
}


- (void)stop
{
    [self.track.asset stop];
    self.paused = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:PlaybackDidStopNotification object:self userInfo:nil];
}

@end

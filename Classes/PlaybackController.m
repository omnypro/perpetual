//
//  PlaybackController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/28/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PlaybackController.h"

#import "MetadataController.h"
#import "Track.h"
#import "WindowController.h"

@interface PlaybackController ()
@property (nonatomic, retain) WindowController *ui;
@end

@implementation PlaybackController

@synthesize ui = _ui;

@synthesize track = _track;
@synthesize paused = _paused;
@synthesize currentTime = _currentTime;
@synthesize loopCount = _loopCount;
@synthesize loopInfiniteCount = _loopInfiniteCount;

+ (PlaybackController *)playbackController
{
    return [[PlaybackController alloc] init];
}

- (void)updateLoopCount:(NSUInteger)count
{
    // Sets the property and updates the label.
    self.loopCount = count;
    if (self.loopCount < self.loopInfiniteCount) {
        [self.ui.loopCountLabel setStringValue:[NSString stringWithFormat:@"x%d", self.loopCount]];
    }
    else {
        [self.ui.loopCountLabel setStringValue:@"∞"];
    }
    
    // Finally, update the stepper so it's snychronized.
    [self.ui.loopCountStepper setIntegerValue:self.loopCount];
}

- (void)checkTime:(NSTimer *)timer
{
    self.currentTime = [self.track.asset currentTime];
    
    if (self.currentTime.timeValue >= self.track.endTime.timeValue && self.track.startTime.timeValue < self.track.endTime.timeValue && [self loopCount] > 0) {
        if (self.loopCount < self.loopInfiniteCount) {
            [self updateLoopCount:self.loopCount - 1];
        }
        [self setCurrentTime:self.track.startTime];
    }
}

- (void)loadTrack:(Track *)track withOriginalFileURL:(NSURL *)fileURL
{
    // Is this really needed?
    self.track = track;
    self.paused = YES;
    
    // Compose the initial user interface.
    // ???: Should we be doing this in the playback controller?
    [self.ui.progressBar setMaxValue:self.track.duration.timeValue];
    [self.ui.startSlider setMaxValue:self.track.duration.timeValue];
    [self.ui.startSlider setFloatValue:0.0];
    [self.ui.endSlider setMaxValue:self.track.duration.timeValue];
    [self.ui.endSlider setFloatValue:self.track.duration.timeValue];
    [self.ui.startSlider setNumberOfTickMarks:(int)self.track.duration.timeValue / self.track.duration.timeScale];
    [self.ui.endSlider setNumberOfTickMarks:(int)self.track.duration.timeValue / self.track.duration.timeScale];
    
    // Fetch all of the metadata.
    [[MetadataController metadataController] fetchMetadataForURL:fileURL];
    
    // Start the timer loop.
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}


@end

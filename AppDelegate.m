//
//  AppDelegate.m
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import "AppDelegate.h"
#import <CoreAudio/CoreAudio.h>
#import <QTKit/QTKit.h>
#import "metadataRetriever.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize startSlider;
@synthesize endSlider;
@synthesize currentTimeLabel;
@synthesize currentTimeBar;
@synthesize playButton;
@synthesize currentTrackLabel;

@synthesize timeScale;
@synthesize startTime;
@synthesize endTime;
@synthesize currentTime;
@synthesize music;
@synthesize paused;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[self window] setTitleBarHeight:30.0];
    [[self window] setTrafficLightButtonsLeftMargin:7.0];
}

-(void) checkTime:(NSTimer*)theTimer{
    currentTime = [music currentTime];

    if(currentTime.timeValue >= endTime.timeValue && startTime.timeValue < endTime.timeValue){
        [music setCurrentTime:startTime];
    }


    NSCalendar *sysCalendar = [NSCalendar currentCalendar];

    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:currentTime.timeValue/timeScale sinceDate:date1];

    unsigned int unitFlags = NSMinuteCalendarUnit | NSSecondCalendarUnit;

    NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];

    [currentTimeLabel setStringValue:[NSString stringWithFormat:@"%02d:%02d",[conversionInfo minute],[conversionInfo second]]];
    [currentTimeBar setFloatValue:(float)currentTime.timeValue];

}

- (void)loadMusic:(NSURL *) fileURL {
    //Load the track from URL
    //TODO: Error handling
    music = [[QTMovie alloc] initWithURL:fileURL error:nil];

    //Really needed anymore?
    paused = YES;

    //Find and set slider max values
    QTTime maxTime = [music duration];
    timeScale = [music duration].timeScale;
    float maxValue = (float)maxTime.timeValue;
    startTime = QTMakeTime(0.0,timeScale);
    endTime = maxTime;
    
    [currentTimeBar setMaxValue:maxValue];
    [startSlider setMaxValue:maxValue];
    [startSlider setFloatValue:0.0];
    [endSlider setMaxValue:maxValue];
    [endSlider setFloatValue:maxValue];
    [startSlider setNumberOfTickMarks:(int) maxValue/timeScale];
    [endSlider setNumberOfTickMarks:(int) maxValue/timeScale];
    
    //Set title and artist labels from metadata
    NSArray * mdArray = [music commonMetadata];
    NSString * trackTitle = @"Unknown title";
    NSString * trackArtist = @"Unknown artist";

    NSArray * titleMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:@"title" keySpace:nil];
    if([titleMetadataItems count] > 0) {
        trackTitle = [[titleMetadataItems objectAtIndex:0] stringValue];
    }
    NSArray * artistMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:@"artist" keySpace:nil];
    if([artistMetadataItems count] > 0) {
        trackArtist = [[artistMetadataItems objectAtIndex:0] stringValue];
    }
    
    [currentTrackLabel setStringValue:[NSString stringWithFormat:@"%@\n%@",trackTitle,trackArtist]];
    
    //Start loop and play track
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
}

- (IBAction)startSliderSet:(id)sender {
    if([startSlider doubleValue] < (float)endTime.timeValue) {
        startTime = QTMakeTime((long)[startSlider doubleValue],timeScale);

    }
    else{
        [startSlider setFloatValue:(float)startTime.timeValue];
    }
}

- (IBAction)endSliderSet:(id)sender {
    if([endSlider doubleValue] > (float)startTime.timeValue) {
        endTime = QTMakeTime((long)[endSlider doubleValue],timeScale);
    }
    else{
        [endSlider setFloatValue:(float)endTime.timeValue];
    }
}

- (IBAction)currentTimeBarSet:(id)sender {
    NSTimeInterval ct = [currentTimeBar doubleValue];
    [music setCurrentTime:QTMakeTime((long)ct,timeScale)];
}

- (IBAction)playButtonClick:(id)sender {
    if(!paused) {
        [music stop];
        paused = YES;
    }
    else {
        [music play];
        paused = NO;
    }
}

- (IBAction)openFile:(id)sender {
    NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
    NSInteger tvarNSInteger	= [openPanel runModal];
    if(tvarNSInteger == NSOKButton){
        [music stop];
        NSURL * fileURL = [openPanel URL];
        [self loadMusic:fileURL];
    }
}

@end

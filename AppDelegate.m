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

@implementation AppDelegate

@synthesize window = _window;
@synthesize startSlider;
@synthesize endSlider;
@synthesize currentTimeLabel;
@synthesize currentTimeBar;
@synthesize playButton;
@synthesize currentTrackLabel;
@synthesize loopCountLabel;
@synthesize loopCountStepper;

@synthesize loopCount;
@synthesize loopInfiniteCount;
@synthesize timeScale;
@synthesize startTime;
@synthesize endTime;
@synthesize currentTime;
@synthesize music;
@synthesize paused;

-(void) setTheLoopCount:(int)theLoopCount{
    //Sets the property and updates the label
    [self setLoopCount:theLoopCount];
    if([self loopCount] < [self loopInfiniteCount]) {
        [loopCountLabel setStringValue:[NSString stringWithFormat:@"x%d",self.loopCount]];
    }
    else {
        [loopCountLabel setStringValue:@"∞"];
    }
    //Finally update the stepper so it's synchronized
    [loopCountStepper setIntValue:[self loopCount]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [[self window] setTitleBarHeight:30.0];
    [[self window] setTrafficLightButtonsLeftMargin:7.0];
    [self setLoopInfiniteCount:31];
    [self setTheLoopCount:10];
    [[self loopCountStepper] setMaxValue:(double)[self loopInfiniteCount]];
}

-(void) checkTime:(NSTimer*)theTimer{
    currentTime = [music currentTime];

    if(currentTime.timeValue >= endTime.timeValue && startTime.timeValue < endTime.timeValue && [self loopCount] > 0){
        if([self loopCount] < [self loopInfiniteCount]) {
            //[self loopInfiniteCount] is the magic infinite number
            [self setTheLoopCount:[self loopCount]-1];
        }
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
    
    //Set title and artist labels from 
    NSString * trackTitle = @"Unknown title";
    NSString * trackArtist = @"Unknown artist";
    
    NSArray * mdFormatsArray = [music availableMetadataFormats];
    for(int i=0;i<[mdFormatsArray count];i++) {
        NSArray * mdArray = [music metadataForFormat:[mdFormatsArray objectAtIndex:i]];   
        //Fixme: find out why we need to replace @ with ©
        NSArray * titleMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:[QTMetadataiTunesMetadataKeySongName stringByReplacingOccurrencesOfString:@"@" withString:@"©"] keySpace:nil];
        if([titleMetadataItems count] > 0) {
            trackTitle = [[titleMetadataItems objectAtIndex:0] stringValue];
        }
        //Fixme: find out why we need to replace @ with ©
        NSArray * artistMetadataItems = [QTMetadataItem metadataItemsFromArray:mdArray withKey:[QTMetadataiTunesMetadataKeyArtist stringByReplacingOccurrencesOfString:@"@" withString:@"©"] keySpace:nil];
        if([artistMetadataItems count] > 0) {
            trackArtist = [[artistMetadataItems objectAtIndex:0] stringValue];
        }
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

- (IBAction)loopStepperStep:(id)sender {
    [self setTheLoopCount:[loopCountStepper intValue]];
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

//
//  AppDelegate.m
//  Test
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import "AppDelegate.h"
#import <CoreAudio/CoreAudio.h>

@implementation AppDelegate

@synthesize window = _window;
@synthesize startSlider;
@synthesize endSlider;
@synthesize currentTimeLabel;
@synthesize currentTimeBar;

@synthesize playButton;

@synthesize startTime;
@synthesize endTime;

@synthesize currentTime;

@synthesize music;

@synthesize paused;


-(void) checkTime:(NSTimer*)theTimer{
    currentTime = [music currentTime];
    if([music isPlaying]){
        if(currentTime >= endTime && startTime < endTime){
            [music setCurrentTime:startTime];
        }
    }
    
    
    // Create the NSDates
    NSCalendar *sysCalendar = [NSCalendar currentCalendar];

    NSDate *date1 = [[NSDate alloc] init];
    NSDate *date2 = [[NSDate alloc] initWithTimeInterval:currentTime sinceDate:date1]; 
    
    // Get conversion to months, days, hours, minutes
    unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSMonthCalendarUnit | NSSecondCalendarUnit;
    
    NSDateComponents *conversionInfo = [sysCalendar components:unitFlags fromDate:date1  toDate:date2  options:0];
    
    [currentTimeLabel setStringValue:[NSString stringWithFormat:@"%02d:%02d",[conversionInfo minute],[conversionInfo second]]];
    [currentTimeBar setFloatValue:currentTime];

}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application

}

- (void)loadMusic:(NSURL *) fileURL {
    NSSound * m = [NSSound alloc];
    music = [m initWithContentsOfURL:fileURL byReference:YES];
    //music = [[NSSound alloc] initWithContentsOfURL:fileURL byReference:YES];
    double maxValue = [music duration];
    paused = YES;
    startTime = 0.0;
    endTime = maxValue;
    [currentTimeBar setMaxValue:endTime];
    [startSlider setMaxValue:maxValue];
    [startSlider setFloatValue:0.0];
    [endSlider setMaxValue:maxValue];
    [endSlider setFloatValue:maxValue];
    [startSlider setNumberOfTickMarks:(int) endTime];
    [endSlider setNumberOfTickMarks:(int) endTime];
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(checkTime:) userInfo:nil repeats:YES];
    [music play];
    [music pause];    
}

- (IBAction)startSliderSet:(id)sender {
//    NSLog(@"%f",[startSlider doubleValue]);
    if([startSlider doubleValue] < endTime) {
        startTime = [startSlider doubleValue];
    }
    else{
        [startSlider setFloatValue:startTime];
    }
}

- (IBAction)endSliderSet:(id)sender {
//    NSLog(@"%f",[endSlider doubleValue]);
    if([endSlider doubleValue] > startTime) {
        endTime = [endSlider doubleValue];
    }
    else{
        [endSlider setFloatValue:endTime];
    }
}

- (IBAction)currentTimeBarSet:(id)sender {
    NSTimeInterval ct = [currentTimeBar doubleValue];
    [music setCurrentTime:ct];
}

- (IBAction)playButtonClick:(id)sender {
    if(!paused) {
        [music pause];
        paused = YES;
    }
    else {
        [music resume];
        paused = NO;
    }
}

- (IBAction)openFile:(id)sender {
    NSOpenPanel *openPanel	= [NSOpenPanel openPanel];
    NSInteger tvarNSInteger	= [openPanel runModal];
    if(tvarNSInteger == NSOKButton){
        NSURL * fileURL = [openPanel URL];    
        [self loadMusic:fileURL];
    } else if(tvarNSInteger == NSCancelButton) {
     	return;
    } else {
     	return;
    }
}


@end

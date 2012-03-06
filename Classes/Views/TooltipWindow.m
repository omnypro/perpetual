//
//  TooltipWindow.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/5/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "TooltipWindow.h"

@implementation TooltipWindow

@synthesize time = _time;

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    if (self) {
        self.alphaValue = 0.90;
        self.backgroundColor = [NSColor colorWithDeviceRed:1.0 green:0.90 blue:0.75 alpha:1.0];
        self.hasShadow = YES;
        self.level = NSStatusWindowLevel;
        self.opaque = NO;
        [self ignoresMouseEvents];
        
        self.time = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 4, 64, 24)];
        self.time.editable = NO;
        self.time.selectable = NO;
        self.time.bezeled = NO;
        self.time.bordered = NO;
        self.time.drawsBackground = NO;
        self.time.alignment = NSCenterTextAlignment;
        self.time.stringValue = @"00:00";
        
        [[self contentView] addSubview:self.time];
        [self hide];        
    }
    return self;
}

- (void)hide
{
    [self orderOut:nil];
}

- (void)show
{
    [self orderFront:nil];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(hide) userInfo:nil repeats:NO];
}

- (void)updatePosition:(float)y
{
    NSPoint mp = [NSEvent mouseLocation];
    NSPoint p = NSMakePoint(120, 120);
    NSRect frame = [self frame];
    p.x = mp.x - frame.size.width / 2.0;
    p.y = y;
    self.frameOrigin = p;
}

- (void)setString:(NSString *)stringValue
{
    self.time.stringValue = stringValue;
}

@end

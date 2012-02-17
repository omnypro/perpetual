//
//  TooltipWindow.m
//  Perpetual
//
//  Created by Kalle Persson on 2/17/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import "TooltipWindow.h"


@implementation TooltipWindow

@synthesize textField;


- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
    self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation];
    if (self) {
        [self setOpaque:NO];
        [self setAlphaValue:0.90];
        [self setBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:0.95 blue:0.76 alpha:1.0]];
        [self setHasShadow:YES];
        [self setLevel:NSStatusWindowLevel];
        [self ignoresMouseEvents];
        textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,-4,64,24)];
        [textField setEditable:NO];
        [textField setSelectable:NO];
        [textField setBezeled:NO];
        [textField setBordered:NO];
        [textField setDrawsBackground:NO];
        [textField setAlignment:NSCenterTextAlignment];
        [textField setStringValue:@"00:00"];
        [[self contentView] addSubview:textField];
        [self hide];

    }

    return self;
}


-(void)hide {
    [self orderOut:nil];    
}

-(void)show {
    [self orderFront:nil];    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(hide) userInfo:nil repeats:NO];
}


-(void)setString:(NSString *) stringValue {
    [textField setStringValue:stringValue];
}

- (void)updatePosition:(float) y
{
    NSPoint mp = [NSEvent mouseLocation];
    NSPoint p = NSMakePoint(120,120);
    NSRect f = [self frame];
    p.x = mp.x - f.size.width / 2.0;
    p.y = y;
    [self setFrameOrigin:p];
}

@end

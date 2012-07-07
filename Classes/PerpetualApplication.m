//
//  PerpetualApplication.m
//  Perpetual
//
//  Created by Red Davis on 29/05/2012.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "PerpetualApplication.h"
#import <IOKit/hidsystem/ev_keymap.h>


@interface PerpetualApplication ()

- (void)mediaKeyEvent:(int)key;

@end


@implementation PerpetualApplication

@dynamic delegate;

- (void)sendEvent:(NSEvent *)theEvent {
    
    BOOL callSuper = YES;
    if (theEvent.type == NSSystemDefined && theEvent.subtype == 8) {
        
        // Taken from http://rogueamoeba.com/utm/2007/09/29/
        int keyCode = (([theEvent data1] & 0xFFFF0000) >> 16);
		int keyFlags = ([theEvent data1] & 0x0000FFFF);
		int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
                
        if (keyState == 0) {
            
            callSuper = NO;
            [self mediaKeyEvent:keyCode];
        }
    }
    
    // If play button is pressed, we do not want it opening iTunes
    if (callSuper) {
        
        [super sendEvent:theEvent];
    }
}

- (void)mediaKeyEvent:(int)key; {
    
    if (key == NX_KEYTYPE_PLAY) {
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(playMediaKeyWasClicked)]) {
            
            [self.delegate playMediaKeyWasClicked];
        }
    }
}

@end

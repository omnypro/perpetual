//
//  TooltipWindow.h
//  Perpetual
//
//  Created by Bryan Veloso on 3/5/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TooltipWindow : NSWindow

@property (nonatomic, strong) NSTextField *time;

- (void)hide;
- (void)show;
- (void)updatePosition:(float)y;
- (void)setString:(NSString *)stringValue;

@end

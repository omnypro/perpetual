//
//  TooltipWindow.h
//  Perpetual
//
//  Created by Kalle Persson on 2/17/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface TooltipWindow : NSWindow

@property (strong) NSTextField *textField;
- (void)show;
- (void)hide;
- (void)updatePosition:(float) y;
- (void)setString:(NSString *) stringValue;

@end

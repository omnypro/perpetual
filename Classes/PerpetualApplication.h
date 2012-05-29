//
//  PerpetualApplication.h
//  Perpetual
//
//  Created by Red Davis on 29/05/2012.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol PerpetualApplicationDelegate <NSApplicationDelegate>
@optional
- (void)playMediaKeyWasClicked;
@end


@interface PerpetualApplication : NSApplication

@property (nonatomic, unsafe_unretained) id <PerpetualApplicationDelegate> delegate;

@end

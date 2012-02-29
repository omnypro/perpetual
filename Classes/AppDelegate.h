//
//  AppDelegate.h
//  Perpetual
//
//  Created by Kalle Persson on 2/14/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PlaybackController;
@class Track;
@class WindowController;

@interface AppDelegate : NSObject <NSApplicationDelegate> {}

@property (nonatomic, readonly, retain) WindowController *windowController;
@property (nonatomic, readonly, retain) PlaybackController *playbackController;
@property (nonatomic, readonly, retain) Track *track;

+ (AppDelegate *)sharedInstance;

@end

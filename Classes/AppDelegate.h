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

@property (nonatomic, readonly, strong) WindowController *windowController;
@property (nonatomic, readonly, strong) PlaybackController *playbackController;

+ (AppDelegate *)sharedInstance;

- (IBAction)openFile:(id)sender;

@end

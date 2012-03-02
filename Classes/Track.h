//
//  Track.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface Track : NSObject

@property (nonatomic, readonly) AVAudioPlayer *asset;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimeInterval endTime;

//@property (nonatomic, readonly) QTMovie *asset;
//@property (nonatomic, readonly) QTTime duration;
//@property (nonatomic) QTTime startTime;
//@property (nonatomic) QTTime endTime;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *artist;
@property (nonatomic, readonly) NSString *albumName;
@property (nonatomic, readonly) NSURL *imageDataURI;

- (id)initWithFileURL:(NSURL *)fileURL;

@end

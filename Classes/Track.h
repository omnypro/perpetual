//
//  Track.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QTKit/QTKit.h>

@interface Track : NSObject

@property (retain) QTMovie *asset;
@property (assign) QTTime duration;
@property (assign) QTTime startTime;
@property (assign) QTTime endTime;

- (id)initWithFileURL:(NSURL *)fileURL;

@end

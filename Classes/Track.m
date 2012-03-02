//
//  Track.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "Track.h"

#import "NSString+base64.h"

#import <AVFoundation/AVFoundation.h>

@implementation Track

@synthesize asset = _asset;
@synthesize duration = _duration;
@synthesize startTime = _startTime;
@synthesize endTime = _endTime;

@synthesize title = _title;
@synthesize artist = _artist;
@synthesize albumName = _albumName;
@synthesize imageDataURI = _imageDataURI;

- (id)initWithFileURL:(NSURL *)fileURL
{
    self = [super init];
    if (!self) {
        NSLog(@"Could not initialize track.");
        return nil;
    }
    
    NSError *err = nil;
    _asset = [[QTMovie alloc] initWithURL:fileURL error:&err];
    if (self.asset == nil) {
        NSLog(@"%@", err);
        return nil;
    }
    
    _duration = [self.asset duration];
    _startTime = QTMakeTime(0.0, self.duration.timeScale);
    _endTime = self.duration;
	
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    for (NSString *format in [asset availableMetadataFormats]) {
        for (AVMetadataItem *item in [asset metadataForFormat:format]) {
            if ([[item commonKey] isEqualToString:@"title"]) {
                _title = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"artist"]) {
                _artist = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"albumName"]) {
                _albumName = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"artwork"]) {
                NSURL *base64uri = nil;
                if ([[item value] isKindOfClass:[NSDictionary class]]) {
                    // MP3s ID3 tags store artwork as a dictionary in the "value" key with the data under a key of "data".
                    NSString *base64 = [NSString encodeBase64WithData:[(NSDictionary *)[item value] objectForKey:@"data"]];
                    NSString *mimeType = [(NSDictionary *)[item value] objectForKey:@"MIME"];
                    base64uri = [NSURL URLWithString:[NSString stringWithFormat:@"data:%@;base64,%@", mimeType, base64]];
                } else {
                    // M4As, on the other hand, store simply artwork as data in the "value" key.
                    NSString *base64 = [NSString encodeBase64WithData:(NSData *)[item value]];
                    base64uri = [NSURL URLWithString:[NSString stringWithFormat:@"data:image/png;base64,%@", base64]];
                }
				_imageDataURI = base64uri;
			}
        }
    }
    

    
    return self;
}

@end

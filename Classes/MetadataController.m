//
//  MetadataController.m
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "MetadataController.h"

#import "NSString+base64.h"
#import "WindowController.h"

#import <AVFoundation/AVFoundation.h>

@implementation MetadataController

+ (MetadataController *)metadataController
{
    return [[MetadataController alloc] init];
}

- (void)fetchMetadataForURL:(NSURL *)fileURL
{
    NSString *title = nil;
    NSString *artist = nil;
    NSString *album = nil;
    
    WindowController *ui = [WindowController windowController];
    AVAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    for (NSString *format in [asset availableMetadataFormats]) {
        for (AVMetadataItem *item in [asset metadataForFormat:format]) {
            if ([[item commonKey] isEqualToString:@"title"]) {
                title = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"artist"]) {
                artist = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"albumName"]) {
                album = (NSString *)[item value];
            }
            if ([[item commonKey] isEqualToString:@"artwork"]) {
                NSString *base64uri = nil;
                if ([[item value] isKindOfClass:[NSDictionary class]]) {
                    // MP3s ID3 tags store artwork as a dictionary in the "value" key with the data under a key of "data".
                    NSString *base64 = [NSString encodeBase64WithData:[(NSDictionary *)[item value] objectForKey:@"data"]];
                    NSString *mimeType = [(NSDictionary *)[item value] objectForKey:@"MIME"];
                    base64uri = [NSString stringWithFormat:@"data:%@;base64,%@", mimeType, base64];
                } else {
                    // M4As, on the other hand, store simply artwork as data in the "value" key.
                    NSString *base64 = [NSString encodeBase64WithData:(NSData *)[item value]];
                    base64uri = [NSString stringWithFormat:@"data:image/png;base64,%@", base64];
                }
                if (base64uri != nil) {
                    [ui layoutCoverArtWithIdentifier:base64uri];
                }
            }
        }
    }
    
    [ui.trackTitle setStringValue:title];
    [ui.trackSubtitle setStringValue:[NSString stringWithFormat:@"%@ / %@", album, artist]];
}

@end

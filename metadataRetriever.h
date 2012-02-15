//
//  metadataRetriever.h
//  SwiftLoad
//
//  Created by Nathaniel Symer on 12/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface metadataRetriever : NSObject

+ (NSArray *)getMetadataForFile:(NSString *)filePath;

+ (NSString *)artistForMetadataArray:(NSArray *)array;

+ (NSString *)songForMetadataArray:(NSArray *)array;

+ (NSString *)albumForMetadataArray:(NSArray *)array;

@end

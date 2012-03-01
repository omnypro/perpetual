//
//  MetadataController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/29/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MetadataController : NSObject

- (void)fetchMetadataForURL:(NSURL *)fileURL;

@end

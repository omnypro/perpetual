//
//  StringUtilities.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/18/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSString (NSStringAdditions)

+ (NSString *)encodeBase64WithString:(NSString *)strData;
+ (NSString *)encodeBase64WithData:(NSData *)objData;

@end

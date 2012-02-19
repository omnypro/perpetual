//
//  StringUtilities.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/18/12.
//  Copyright (c) 2012 Afonso Wilsson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (NSStringAdditions)

+ (NSString *)encodeBase64WithString:(NSString *)strData;
+ (NSString *)encodeBase64WithData:(NSData *)objData;

@end

//
//  WindowController.h
//  Perpetual
//
//  Created by Bryan Veloso on 2/27/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class WebView;

@interface WindowController : NSWindowController 

+ (WindowController *)windowController;

@property (weak) IBOutlet WebView *webView;

@end

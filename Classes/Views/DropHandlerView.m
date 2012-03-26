//
//  DropHandlerView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/26/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "DropHandlerView.h"

#import "Constants.h"

@implementation DropHandlerView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    }
    
    return self;
}

#pragma Drag Operation Methods

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
    if ([files count] == 1) {
        NSString *filepath = [files lastObject];
        if ([[filepath pathExtension] isEqualToString:@"m4a"] || [[filepath pathExtension] isEqualToString:@"mp3"]) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if ([[pasteboard types] containsObject:NSFilenamesPboardType]) {
        NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
        if ([files count] == 1) {
            NSLog(@"YAYHOORAY.");
            [[NSNotificationCenter defaultCenter] postNotificationName:FileWasDroppedNotification object:self userInfo:nil];
            return YES;
        }
    }
    return NO;
}

@end

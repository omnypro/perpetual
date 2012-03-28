//
//  DropHandlerView.m
//  Perpetual
//
//  Created by Bryan Veloso on 3/26/12.
//  Copyright (c) 2012 Revyver, Inc. All rights reserved.
//

#import "DropHandlerView.h"

@interface DropHandlerView ()
@property (nonatomic, retain) NSArray *pasteboardTypes;
@end

@implementation DropHandlerView

@synthesize fileURL = _fileURL;
@synthesize pasteboardTypes = _pasteboardTypes;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _pasteboardTypes = [NSArray arrayWithObjects:@"com.apple.pasteboard.promised-file-url", @"public.file-url", nil];
        [self registerForDraggedTypes:self.pasteboardTypes];
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
    for (NSPasteboardItem *item in [pasteboard pasteboardItems]) {
        NSString *fileString = nil;
        for (NSString *type in self.pasteboardTypes) {
            if ([[item types] containsObject:type]) {
                fileString = [item stringForType:type];
                NSLog(@"%@", fileString);
                break;
            }
        }
        if (fileString) {
            self.fileURL = [NSURL URLWithString:fileString];
            NSLog(@"%@", self.fileURL);
            [[NSNotificationCenter defaultCenter] postNotificationName:FileWasDroppedNotification object:self userInfo:nil];
            return YES;
        }
    }
    return NO;
}

@end

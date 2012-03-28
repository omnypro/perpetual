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
    for (NSPasteboardItem *item in [[sender draggingPasteboard] pasteboardItems]) {
        for (NSString *type in self.pasteboardTypes) {
            if ([[item types] containsObject:type]) {
                return NSDragOperationCopy;
            }
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
    for (NSPasteboardItem *item in [[sender draggingPasteboard] pasteboardItems]) {
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
            [[NSNotificationCenter defaultCenter] postNotificationName:FileWasDroppedNotification object:self userInfo:nil];
            return YES;
        }
    }
    return NO;
}

@end

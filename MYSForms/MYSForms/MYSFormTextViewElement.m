//
//  MYSFormTextViewElement.m
//  MYSForms
//
//  Created by Adam Kirk on 5/20/14.
//  Copyright (c) 2014 Mysterious Trousers. All rights reserved.
//

#import "MYSFormTextViewElement.h"
#import "MYSFormTextViewCell-Private.h"


@interface MYSFormTextViewElement () <MYSFormTextViewCellDelegate>
@end


@implementation MYSFormTextViewElement

- (instancetype)init
{
    self = [super init];
    if (self) {
        _editable = YES;
        _font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    }
    return self;
}

+ (instancetype)textViewElementWithModelKeyPath:(NSString *)modelKeyPath
{
    MYSFormTextViewElement *element = [self new];
    element.modelKeyPath            = modelKeyPath;
    return element;
}

- (void)setCell:(MYSFormTextViewCell *)cell
{
    [super setCell:cell];
    cell.textViewCellDelegate = self;
}




#pragma mark - DELEGATE text view cell

- (void)textViewFormCell:(MYSFormTextViewCell *)cell textDidChange:(NSString *)text
{
    [self.delegate formElement:self valueDidChange:text];
}

- (NSString *)textViewFormCellCurrentModelValue:(MYSFormTextViewCell *)cell
{
    return [self.dataSource modelValueForFormElement:self];
}

@end


//
//  MYSFormImagePickerCell.m
//  MYSForms
//
//  Created by Adam Kirk on 5/10/14.
//  Copyright (c) 2014 Mysterious Trousers. All rights reserved.
//

#import "MYSFormImagePickerCell.h"
#import "MYSFormImagePickerElement.h"
#import "MYSFormImagePickerCell-Private.h"


@interface MYSFormImagePickerCell () <UIActionSheetDelegate>
@end


@implementation MYSFormImagePickerCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.imageView.backgroundColor = [UIColor darkGrayColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.imageView.layer.cornerRadius   = self.imageView.bounds.size.width / 2.0;
    self.imageView.layer.masksToBounds  = YES;
}

+ (CGSize)sizeRequiredForElement:(MYSFormImagePickerElement *)element width:(CGFloat)width
{
    return CGSizeMake(width, 100);
}




#pragma mark - Public

- (NSString *)valueKeyPath
{
    return @"imageView.image";
}

- (void)populateWithElement:(MYSFormImagePickerElement *)element
{
    self.label.text             = element.label;
    self.userInteractionEnabled = element.isEnabled;
    [super populateWithElement:element];
}




#pragma mark - Actions

- (IBAction)cellWasTapped:(id)sender
{
    [self.imagePickerCellDelegate formImagePickerCellWasTapped:self];
}


@end


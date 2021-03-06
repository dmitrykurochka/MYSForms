//
//  MYSFormPickerElement.h
//  MYSForms
//
//  Created by Adam Kirk on 5/14/14.
//  Copyright (c) 2014 Mysterious Trousers. All rights reserved.
//

#import "MYSFormElement.h"
#import "MYSFormPickerCell.h"


@interface MYSFormPickerElement : MYSFormElement

+ (instancetype)pickerElementWithLabel:(NSString *)label modelKeyPath:(NSString *)modelKeyPath;

/**
 The label that appears as the title of what the user is picking. On the left of the element is the title and on the
 right is the current value they've chosen.
 */
@property (nonatomic, copy) NSString *label;

/**
 This allows you to set all the values of the picker at once.
 */
- (void)setValues:(NSArray *)values;

/**
 Adds value to the picker. This allows you to add values one by one, perhaps in a loop. If there is no
 component at index, one is created, as well as any needed up to that index.
 */
- (void)addValue:(id)value;

/**
 To fully control the contents of the picker view, set an object you control as the dataSource/delegate. Optionally, you can
 provide to this element prepared static content that it will display.
 */
@property (nonatomic, weak) id<UIPickerViewDataSource> pickerDataSource;
@property (nonatomic, weak) id<UIPickerViewDelegate> pickerDelegate;

/**
 `YES` if the picker has currently been toggled visible in the form.
 */
@property (nonatomic, assign, readonly, getter = isVisible) BOOL visible;


@end

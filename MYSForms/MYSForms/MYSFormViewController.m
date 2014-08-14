//
//  MYSFormViewController.m
//  MYSForms
//
//  Created by Adam Kirk on 5/1/14.
//  Copyright (c) 2014 Mysterious Trousers. All rights reserved.
//

#import "MYSForms.h"
#import "MYSFormMessageChildElement.h"
#import "MYSFormLoadingChildCell.h"
#import "MYSFormMessageChildElement-Private.h"
#import "MYSFormViewChildElement.h"
#import "MYSFormViewChildCell.h"
#import "MYSCollectionViewSpringyLayout.h"
#import "MYSCollectionView.h"


typedef NS_ENUM(NSUInteger, MYSFormMessagePosition) {
    MYSFormMessagePositionAbove,
    MYSFormMessagePositionBelow
};


@interface MYSFormViewController () <UICollectionViewDelegateFlowLayout,
UITextFieldDelegate,
MYSFormElementDataSource,
MYSFormElementDelegate>
@property (nonatomic, strong) NSMutableArray      *elements;
@property (nonatomic, strong) NSMutableDictionary *cachedCellSizes;
@property (nonatomic, assign) NSUInteger          outstandingValidationErrorCount;
@end


@implementation MYSFormViewController

- (void)formInit;
{
    self.elements = [NSMutableArray new];
    self.fixedWidth = 0;
}

- (instancetype)init
{
    self = [super initWithCollectionViewLayout:[MYSCollectionViewSpringyLayout new]];
    if (self) {
        [self formInit];
    }
    return self;
}

- (id)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
    self = [super initWithCollectionViewLayout:layout];
    if (self) {
        [self formInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self formInit];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.collectionView.backgroundColor      = [UIColor whiteColor];
    self.view.backgroundColor                = [UIColor whiteColor];
    self.collectionView.alwaysBounceVertical = YES;
    
    [self configureForm];
    
    [self registerElementCellsForReuse];
    [self setupKeyboardNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeAllModelObservers];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [(MYSCollectionView *)self.collectionView disableDynamics];
    [self.cachedCellSizes removeAllObjects];
    [self.collectionView reloadData];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [(MYSCollectionView *)self.collectionView enableDynamics];
    [self.cachedCellSizes removeAllObjects];
    [self.collectionView reloadData];
}




#pragma mark - Public

- (void)setModel:(id)model
{
    [self removeAllModelObservers];
    _model = model;
    for (MYSFormElement *element in self.elements) {
        if ([self elementHasValidKeyPath:element]) {
            [self.model addObserver:self
                         forKeyPath:element.modelKeyPath
                            options:0
                            context:NULL];
        }
        [element updateCell];
    }
}

- (void)configureForm
{
    // overriden by subclasses
}

- (void)registerElementCellsForReuse
{
    for (MYSFormElement *element in self.elements) {
        [self registerCellForClass:[element cellClass]];
    }
    
    // register metadata cells
    [self registerCellForClass:[MYSFormMessageChildCell class]];
    [self registerCellForClass:[MYSFormLoadingChildCell class]];
    
    // register view child cell
    [self.collectionView registerClass:[MYSFormViewChildCell class] forCellWithReuseIdentifier:NSStringFromClass([MYSFormViewChildCell class])];
    
    // register an invisble footer cell
    [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"InvisibleCell"];
}

- (void)addFormElement:(MYSFormElement *)element
{
    [self addFormElement:element atIndex:[self.elements count]];
}

- (void)addFormElement:(MYSFormElement *)element atIndex:(NSInteger)index
{
    if (![element canAddElement]) return;
    
    
    element.dataSource  = self;
    element.delegate    = self;
    
    [self.elements insertObject:element atIndex:index];
    
    if ([self elementHasValidKeyPath:element]) {
        [self addObserver:self.model
               forKeyPath:element.modelKeyPath
                  options:0
                  context:NULL];
    }
}

- (BOOL)validate
{
    if (!self.collectionView.window) return YES;
    
    // validate and add any needed form error elements
    BOOL valid = YES;
    NSMutableArray *errorElementsToShow = [NSMutableArray new];
    for (MYSFormElement *element in self.elements) {
        NSArray *validationErrors = [element validationErrors];
        if ([validationErrors count] > 0) {
            valid = NO;
            for (NSError *error in validationErrors) {
                MYSFormMessageChildElement *errorFormElement = [MYSFormMessageChildElement messageElementWithMessage:[error localizedDescription]
                                                                                                                type:MYSFormChildElementTypeValidationError
                                                                                                       parentElement:element];
                [errorElementsToShow addObject:errorFormElement];
            }
        }
    }
    self.outstandingValidationErrorCount = [errorElementsToShow count];
    
    // remove all existing error elements
    [self hideChildrenOfElement:nil type:MYSFormChildElementTypeValidationError completion:^{
        [self showChildElements:errorElementsToShow position:MYSFormMessagePositionBelow duration:0 completion:nil];
    }];
    
    return valid;
}

- (void)attemptToDismissKeyboard
{
    [[self currentFirstResponder] resignFirstResponder];
}

- (NSArray *)visibleTextInputs
{
    NSMutableArray *visibleTextInputs = [NSMutableArray new];
    for (MYSFormElement *element in self.elements) {
        UIView * textInput = [element.cell textInput];
        if (textInput.window) {
            [visibleTextInputs addObject:textInput];
        }
    }
    return visibleTextInputs;
}

- (void)showLoadingMessage:(NSString *)message aboveElement:(MYSFormElement *)element completion:(void (^)(void))completion
{
    if (!self.collectionView.window) return;
    MYSFormMessageChildElement *loadingElement = [MYSFormMessageChildElement messageElementWithMessage:message type:MYSFormChildElementTypeLoading parentElement:element];
    [self showChildElements:@[loadingElement] position:MYSFormMessagePositionAbove duration:0 completion:completion];
}

- (void)hideLoadingAboveElement:(MYSFormElement *)element completion:(void (^)(void))completion
{
    if (!self.collectionView.window) return;
    [self hideChildrenOfElement:element type:MYSFormChildElementTypeLoading completion:completion];
}

- (void)showErrorMessage:(NSString *)message
            belowElement:(MYSFormElement *)element
                duration:(NSTimeInterval)duration
              completion:(void (^)(void))completion
{
    MYSFormMessageChildElement *errorMessage = [MYSFormMessageChildElement messageElementWithMessage:message
                                                                                                type:MYSFormChildElementTypeError
                                                                                       parentElement:element];
    [self showChildElements:@[errorMessage]
                   position:MYSFormMessagePositionBelow
                   duration:duration
                 completion:completion];
}

- (void)hideErrorMessageBelowElement:(MYSFormElement *)element completion:(void (^)(void))completion
{
    [self hideChildrenOfElement:element type:MYSFormChildElementTypeError completion:completion];
}

- (void)showSuccessMessage:(NSString *)message
              belowElement:(MYSFormElement *)element
                  duration:(NSTimeInterval)duration
                completion:(void (^)(void))completion
{
    MYSFormMessageChildElement *successMessage = [MYSFormMessageChildElement messageElementWithMessage:message
                                                                                                  type:MYSFormChildElementTypeSuccess
                                                                                         parentElement:element];
    [self showChildElements:@[successMessage]
                   position:MYSFormMessagePositionBelow
                   duration:duration
                 completion:completion];
}

- (void)hideSuccessMessageBelowElement:(MYSFormElement *)element completion:(void (^)(void))completion
{
    [self hideChildrenOfElement:element type:MYSFormChildElementTypeSuccess completion:completion];
}


#pragma mark (properties)

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;
    for (MYSFormElement *element in self.elements) {
        element.enabled = enabled;
    }
}




#pragma mark - DATASOURCE collection view

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.elements count] + 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item < [self.elements count]) {
        MYSFormElement *element = self.elements[indexPath.row];
        MYSFormCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([element cellClass]) forIndexPath:indexPath];
        [cell populateWithElement:element];
        element.cell = cell;
        [element updateCell];
        return cell;
    }
    
    // have to do this because there's some bug I can't figure out that causes the last cell in a collection view to jump/stutter
    // when rows are inserted.
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"InvisibleCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    return cell;
}




#pragma mark - DELEGATE collection view

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item < [self.elements count] && [self.formDelegate respondsToSelector:@selector(formViewController:willRemoveElement:cell:)]) {
        MYSFormElement *element = self.elements[indexPath.item];
        [self.formDelegate formViewController:self willRemoveElement:element cell:cell];
    }
}




#pragma mark - DELEGATE flow layout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item < [self.elements count]) {
        NSValue *cachedSize = self.cachedCellSizes[indexPath];
        if (!cachedSize) {
            MYSFormElement *element = self.elements[indexPath.row];
            CGFloat width = self.fixedWidth > 0 && self.fixedWidth < collectionView.frame.size.width ? self.fixedWidth : collectionView.frame.size.width;
            CGSize size = [[element cellClass] sizeRequiredForElement:element width:width];
            size.width = width;
            cachedSize = [NSValue valueWithCGSize:size];
            self.cachedCellSizes[indexPath] = cachedSize;
        }
        return [cachedSize CGSizeValue];
    }
    return CGSizeMake(self.collectionView.frame.size.width, 50);
}




#pragma mark - DATASOURCE form element

- (id)modelValueForFormElement:(MYSFormElement *)formElement
{
    if ([self elementHasValidKeyPath:formElement]) {
        id value = [self.model valueForKeyPath:formElement.modelKeyPath];
        
        // transform the value if needed
        if (formElement.valueTransformer && [[formElement.valueTransformer class] allowsReverseTransformation]) {
            value = [formElement.valueTransformer transformedValue:value];
        }
        
        return value;
    }
    return nil;
}




#pragma mark - DELEGATE form element

- (void)formElement:(MYSFormElement *)formElement valueDidChange:(id)value
{
    // transform the value if needed
    if (formElement.valueTransformer && [[formElement.valueTransformer class] allowsReverseTransformation]) {
        value = [formElement.valueTransformer reverseTransformedValue:value];
    }
    
    if ([self elementHasValidKeyPath:formElement]) {
        [self.model setValue:value forKeyPath:formElement.modelKeyPath];
        if ([self.formDelegate respondsToSelector:@selector(formViewController:didUpdateModelWithValue:element:)]) {
            [self.formDelegate formViewController:self didUpdateModelWithValue:value element:formElement];
        }
    }
    else {
        if ([self.formDelegate respondsToSelector:@selector(formViewController:failedToUpdateModelWithValue:element:)]) {
            [self.formDelegate formViewController:self failedToUpdateModelWithValue:value element:formElement];
        }
    }
}

- (void)formElement:(MYSFormElement *)formElement didRequestPresentationOfActionSheet:(UIActionSheet *)actionSheet
{
    [actionSheet showInView:self.view];
}

- (void)formElement:(MYSFormElement *)formElement didRequestPresentationOfViewController:(UIViewController *)viewController
           animated:(BOOL)animated
         completion:(void (^)(void))completion
{
    [self presentViewController:viewController animated:animated completion:completion];
}

- (void)formElement:(MYSFormElement *)formElement didRequestPresentationOfChildView:(UIView *)childView
{
    MYSFormViewChildElement *viewChildElement = [MYSFormViewChildElement viewChildElementWithView:childView parentElement:formElement];
    [self showChildElements:@[viewChildElement] position:MYSFormMessagePositionBelow duration:0 completion:nil];
}

- (void)formElement:(MYSFormElement *)formElement didRequestDismissalOfChildView:(UIView *)childView
{
    [self hideChildrenOfElement:formElement type:MYSFormChildElementTypeView completion:nil];
}




#pragma mark - KVO (the model changed)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    for (MYSFormElement *element in self.elements) {
        if ([element.modelKeyPath isEqualToString:keyPath]) {
            if (![[element.cell textInput] isFirstResponder]) {
                [element updateCell];
            }
            return;
        }
    }
}




#pragma mark - Private

#pragma mark (showing/hiding child elements)

- (void)showChildElements:(NSArray *)childElements
                 position:(MYSFormMessagePosition)position
                 duration:(NSTimeInterval)duration
               completion:(void (^)(void))completion
{
    if (!self.collectionView.window) return;
    
    for (MYSFormMessageChildElement *childElement in childElements) {
        if (!childElement.parentElement) {
            childElement.parentElement = (MYSFormElement *)[self.elements firstObject];
        }
    }
    
    NSMutableArray *indexPathsToInsert  = [NSMutableArray new];
    
    for (MYSFormElement *element in [self.elements copy]) {
        NSInteger indexOffset       = position == MYSFormMessagePositionBelow ? 1 : 0;
        NSInteger indexMultiplier   = position == MYSFormMessagePositionBelow ? 1 : -1;
        for (MYSFormMessageChildElement *childElement in childElements) {
            if ([element isEqual:childElement.parentElement]) {
                NSInteger index = [self.elements indexOfObject:childElement.parentElement];
                NSAssert(index != NSNotFound, @"element must be added to the form.");
                
                NSInteger newIndex = index + (indexOffset++ * indexMultiplier);
                [self addFormElement:childElement atIndex:newIndex];
                [indexPathsToInsert addObject:[NSIndexPath indexPathForItem:newIndex inSection:0]];
                
                if (duration > 0) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self hideChildrenOfElement:childElement.parentElement type:childElement.type completion:nil];
                    });
                }
            }
        }
    }
    
    if ([indexPathsToInsert count] > 0) {
        [self.cachedCellSizes removeAllObjects];
        [self.collectionView performBatchUpdates:^{
            [self.collectionView insertItemsAtIndexPaths:indexPathsToInsert];
        } completion:^(BOOL finished) {
            NSIndexPath *ip = [indexPathsToInsert firstObject];
            if (ip) [self.collectionView scrollToItemAtIndexPath:ip atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:YES];
            if (completion) completion();
        }];
    }
    else {
        if (completion) completion();
    }
    
}

- (void)hideChildrenOfElement:(MYSFormElement *)parentElement type:(MYSFormChildElementType)type completion:(void (^)(void))completion
{
    if (!self.collectionView.window) return;
    
    NSArray *childElements = [self.elements filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(MYSFormElement *element, NSDictionary *bindings) {
        return ([element isKindOfClass:[MYSFormChildElement class]] && [(MYSFormChildElement *)element type] == type);
    }]];
    
    NSMutableArray *indexPathsToRemove = [NSMutableArray new];
    for (MYSFormMessageChildElement *childElement in childElements) {
        if (!parentElement || [childElement.parentElement isEqual:parentElement]) {
            NSIndexPath *ip = [self.collectionView indexPathForCell:childElement.cell];
            if (ip) {
                [self.elements removeObject:childElement];
                [indexPathsToRemove addObject:ip];
            }
            
            //            NSInteger index = [self.elements indexOfObject:childElement];
            //            NSIndexPath *ip = [NSIndexPath indexPathForItem:index inSection:0];
            //            [self.elements removeObject:childElement];
            //            [indexPathsToRemove addObject:ip];
        }
    }
    
    if ([indexPathsToRemove count] > 0) {
        [self.cachedCellSizes removeAllObjects];
        [self.collectionView performBatchUpdates:^{
            [self.collectionView deleteItemsAtIndexPaths:indexPathsToRemove];
        } completion:^(BOOL finished) {
            if (completion) completion();
        }];
    }
    else {
        if (completion) completion();
    }
}




#pragma mark (keyboard)

- (void)setupKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
     {
         if ([self.formDelegate respondsToSelector:@selector(formViewControllerWillShowKeyboard:)]) {
             [self.formDelegate formViewControllerWillShowKeyboard:note];
         }
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
     {
         if ([self.formDelegate respondsToSelector:@selector(formViewControllerWillHideKeyboard:)]) {
             [self.formDelegate formViewControllerWillHideKeyboard:note];
         }
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidBeginEditingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
     {
         UITextField *textField = note.object;
         if ([[self visibleTextInputs] containsObject:textField]) {
             if ([self textInputAfter:textField]) {
                 textField.returnKeyType = UIReturnKeyNext;
             }
             else {
                 textField.returnKeyType = UIReturnKeyDone;
             }
         }
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidEndEditingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
     {
         UITextField *textField = note.object;
         if ([[self visibleTextInputs] containsObject:textField]) {
             if (self.outstandingValidationErrorCount > 0) {
                 [self validate];
             }
         }
     }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:MYSFormTextFieldCellDidHitReturnKey
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note)
     {
         UITextField *textField = note.object;
         if ([[self visibleTextInputs] containsObject:textField]) {
             UIView *nextTextInput = [self textInputAfter:textField];
             if (nextTextInput) {
                 [nextTextInput becomeFirstResponder];
             }
             else {
                 if ([self.formDelegate respondsToSelector:@selector(formViewControllerDidSubmit:)]) {
                     [self.formDelegate formViewControllerDidSubmit:self];
                 }
             }
         }
     }];
}


#pragma mark (KVO helpers)

- (void)removeAllModelObservers
{
    if (self.model) {
        for (MYSFormElement *element in self.elements) {
            if ([self elementHasValidKeyPath:element]) {
                @try {
                    [self.model removeObserver:self forKeyPath:element.modelKeyPath];
                }
                @catch (NSException *exception) {}
            }
        }
    }
}

- (BOOL)elementHasValidKeyPath:(MYSFormElement *)element
{
    BOOL hasModel   = self.model != nil;
    BOOL isValid    = [element isModelKeyPathValid];
    return hasModel && isValid;
}


#pragma mark (text input)

- (UIView *)textInputAfter:(UIView *)textInput
{
    BOOL textInputFound = NO;
    for (MYSFormElement *element in self.elements) {
        if ([element.cell textInput] == textInput) {
            textInputFound = YES;
            continue;
        }
        if (textInputFound && [element.cell textInput].window) {
            return [element.cell textInput];
        }
    }
    return nil;
}

// TODO: if the next text input is off screen, we need to scroll to it first, then give it first responder status.
- (NSArray *)textInputElements
{
    NSMutableArray *textInputs = [NSMutableArray new];
    for (MYSFormElement *element in self.elements) {
        if ([element isTextInput]) {
            [textInputs addObject:element];
        }
    }
    return textInputs;
}

- (UIView *)currentFirstResponder
{
    NSArray *visibleTextInputs = [self visibleTextInputs];
    for (UIView *textInput in visibleTextInputs) {
        if ([textInput isFirstResponder]) {
            return textInput;
        }
    }
    return nil;
}

- (void)registerCellForClass:(Class)cellClass
{
    UINib *nib = [UINib nibWithNibName:NSStringFromClass(cellClass) bundle:nil];
    [self.collectionView registerNib:nib forCellWithReuseIdentifier:NSStringFromClass(cellClass)];
}


@end

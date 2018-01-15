#import <UIKit/UIKit.h>

@interface SBAlertItem : NSObject

// alertController must only have properties written to in configure:
@property (readonly) UIAlertController *alertController;

// both of these image properties are only applicable on the lockscreen
@property (getter=_iconImagePath, nonatomic, retain) NSString *iconImagePath;
@property (getter=_attachmentImagePath, nonatomic, retain) NSString *attachmentImagePath;

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require;
- (void)dismiss;

@end


@interface BJSBAlertItem : SBAlertItem

@property (nonatomic) NSArray<UIAlertAction *> *alertActions;
@property (nonatomic) NSString *alertTitle;
@property (nonatomic) NSString *alertMessage;
@property (nonatomic) NSAttributedString *alertAttributedMessage;

- (void)present;

@end

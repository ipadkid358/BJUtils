#import <UIKit/UIKit.h>

@interface SBAlertItem : NSObject

// alertController must only have properties written to in -configure:requirePasscodeForActions:
@property (readonly) UIAlertController *alertController;

// both of these image properties are only applicable on the lockscreen
// iconImage should be 20 by 20 points (40x40 @2x, 60x60 @3x)
@property (getter=_iconImagePath, nonatomic, retain) NSString *iconImagePath;
@property (getter=_attachmentImagePath, nonatomic, retain) NSString *attachmentImagePath;

// use the -present convenience method in BJSBAlertItem
+ (void)activateAlertItem:(SBAlertItem *)alertItem;

// SpringBoard will call this, do not call yourself
- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require;
- (void)dismiss;

@end


@interface BJSBAlertItem : SBAlertItem

@property (nonatomic) NSArray<UIAlertAction *> *alertActions;
@property (nonatomic) NSString *alertTitle;
@property (nonatomic) NSString *alertMessage;

// does not work on the lockscreen, I provide checks to show plain text if required
@property (nonatomic) NSAttributedString *alertAttributedMessage;

- (void)present;

@end

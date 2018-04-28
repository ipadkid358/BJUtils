#import <UIKit/UIKit.h>

@interface SBAlertItem : NSObject

// alertController must only have properties written to in -configure:requirePasscodeForActions:
@property (readonly) UIAlertController *alertController;

/**
 @brief Absolute path to an image to be presented in the icon area of the notification. Only presented on the lockscreen
 
 @discussion References images should be 20 by 20 points (40x40 @2x, 60x60 @3x)
 */
@property (getter=_iconImagePath, nonatomic, retain) NSString *iconImagePath;

/**
 @brief Absolute path to an image to be presented in the bottom right corner of the notification. Only presented on the lockscreen
 
 @discussion References images should be 20 by 20 points (40x40 @2x, 60x60 @3x)
 */
@property (getter=_attachmentImagePath, nonatomic, retain) NSString *attachmentImagePath;

// use the -present convenience method in BJSBAlertItem
+ (void)activateAlertItem:(SBAlertItem *)alertItem;

// SpringBoard will call this, do not call yourself
- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require;

/// Dismiss the alert. Passing NULL to the completion handler on UIAlertAction will automatically call this
- (void)dismiss;

@end

/// Convenience class to safely configure and show a SpringBoard alert
@interface BJSBAlertItem : SBAlertItem

/// Actions to be availible to the user. See UIAlertController documentation
@property (nonatomic) NSArray<UIAlertAction *> *alertActions;

/// Larger bold text shown on the alert. Presented above the message
@property (nonatomic) NSString *alertTitle;

/// Smaller text to show in the alert. Presented under the title
@property (nonatomic) NSString *alertMessage;

/// Attributed string to show in place of alertMessage. Does not work on the lockscreen, checks provided to show plain text if required
@property (nonatomic) NSAttributedString *alertAttributedMessage;

/// Convenience method to show the alert. Thread safe
- (void)present;

@end

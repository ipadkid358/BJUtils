#import <objc/runtime.h>

#import "BJSBAlertItem.h"

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isLockScreenActive;
@end

@interface SpringBoard
- (BOOL)hasFinishedLaunching;
@end

@interface UIAlertController (BlackJacketPrivate)
@property (setter=_setAttributedMessage:, getter=_attributedMessage, nonatomic, copy) NSAttributedString *attributedMessage;
- (void)_setActions:(NSArray<UIAlertAction *> *)actions;
@end


@implementation BJSBAlertItem

- (void)configure:(BOOL)configure requirePasscodeForActions:(BOOL)require {
    [super configure:configure requirePasscodeForActions:require];
    
    UIAlertController *alert = self.alertController;
    [alert _setActions:_alertActions];
    alert.title = _alertTitle;
    
    if (_alertAttributedMessage) {
        // attributedMessages will not appear on the lock screen
        SBLockScreenManager *lockscreenManager = [objc_getClass("SBLockScreenManager") sharedInstance];
        if (lockscreenManager.isLockScreenActive) {
            alert.message = _alertAttributedMessage.string;
        } else {
            alert.attributedMessage = _alertAttributedMessage;
        }
    } else {
        alert.message = _alertMessage;
    }
}

// added for convenience
- (void)present {
    SpringBoard *springboard = (SpringBoard *)UIApplication.sharedApplication;
    // if SpringBoard hasn't finished launching, it will crash
    if (!springboard.hasFinishedLaunching) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [SBAlertItem activateAlertItem:self];
    });
}

@end

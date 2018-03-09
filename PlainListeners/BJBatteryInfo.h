#import <libactivator/libactivator.h>

/// Simple Activator Listener to show battery info from IOKit.
/// Uses BJSBAlertItem to present information to user
@interface BJBatteryInfo : NSObject <LAListener>
@end

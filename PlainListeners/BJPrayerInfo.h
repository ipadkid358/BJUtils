#import <libactivator/libactivator.h>

/// Simple Activator Listener to show prayer info from Al-Adhan.
/// Uses BJSBAlertItem to present to user, and BJLocation to retrive location information
@interface BJPrayerInfo : NSObject <LAListener>
@end

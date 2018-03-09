#import <libactivator/libactivator.h>

/// Simple Activator Listener to show weather info from AccuWeather.
/// Uses BJSBAlertItem to present to user, and BJLocation to retrive location information
@interface BJWeatherInfo : NSObject <LAListener>
@end

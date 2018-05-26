#import <CoreLocation/CoreLocation.h>

/// Convience singlton for getting location easily. Notifications are posted with the location on significant distance changes
@interface BJLocation : NSObject <CLLocationManagerDelegate>

/**
 @brief Shared location instance. A new instance should not be manually created
 
 @returns Globally used location instance
 */
+ (instancetype)sharedInstance;

/// The current location of the device. This is updated with significant distance changes
@property (nonatomic, readonly) CLLocation *latestLocation;

/// Force a location update. Caller should listen for BJLocationDidChangeNotification to access the new location
- (void)forcePreciseLocationUpdate;

@end

/// Name of the notification posted when latestLocation has been updated
OBJC_EXTERN NSNotificationName const BJLocationDidChangeNotification;

/// Name of the key in userInfo for the location that triggered the notification
OBJC_EXTERN NSString *const BJLocationNewLocationKey;

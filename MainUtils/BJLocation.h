#import <CoreLocation/CoreLocation.h>

/// Convience class for getting location once, if polling location, please use your own class
@interface BJLocation : NSObject <CLLocationManagerDelegate>

/**
 @brief Shared location instance. A new instance should not be manually created
 
 @returns Globally used location instance
 */
+ (instancetype)sharedInstance;

// TODO: See if iOS posts a native notification for significat distance changes, otherwise post our own
/// The current location of the device. This is updated with significant distance changes
@property (nonatomic, readonly) CLLocation *latestLocation;

@end

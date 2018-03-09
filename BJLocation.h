#import <CoreLocation/CoreLocation.h>

@interface BJLocation : NSObject <CLLocationManagerDelegate>

/*!
 @brief Get the current device location, optionally presenting a user alert
 
 @param show Show an alert to the user, indicating a location fetch is in progress. Alert is automatically dismissed on fetch completion
 @param block Called on completion with location information
 */
- (void)showFetch:(BOOL)show callBlock:(void (^)(CLLocation *location))block;

@end

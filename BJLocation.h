#import <CoreLocation/CoreLocation.h>

@interface BJLocation : NSObject <CLLocationManagerDelegate>

- (void)showFetch:(BOOL)show callBlock:(void (^)(CLLocation *location))block;

@end


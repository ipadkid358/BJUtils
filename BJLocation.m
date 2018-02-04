#import "BJLocation.h"
#import "BJSBAlertItem.h"

@interface CLLocationManager (BlackJacketPrivate)
+ (void)setAuthorizationStatusByType:(CLAuthorizationStatus)type forBundleIdentifier:(NSString *)bundle;
@end


@implementation BJLocation {
    CLLocationManager *locationManager;
    void (^blockToRun)(CLLocation *location);
    BJSBAlertItem *sbAlert;
}

- (void)showFetch:(BOOL)show callBlock:(void (^)(CLLocation *location))block {
    blockToRun = block;
    
    if (show) {
        sbAlert = [BJSBAlertItem new];
        sbAlert.alertTitle = @"Getting Location";
        sbAlert.alertMessage = @"Calculating current location, please wait...";
        sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [sbAlert dismiss];
        }]];
        
        [sbAlert present];
    }
    
    // authorizationStatus should only need to be reset once per lifetime, but you never know
    while (CLLocationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
        // bundleID should always be com.apple.springboard, but didn't really want to hard code it
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        [CLLocationManager setAuthorizationStatusByType:kCLAuthorizationStatusAuthorizedAlways forBundleIdentifier:bundleID];
    }
    
    [locationManager requestLocation];
}

- (instancetype)init {
    if (self = [super init]) {
        // CLLocationManager -init needs to be on the main thread
        // to avoid returning before being properly initialized, we using dispatch_sync
        // calling dispatch_sync on the same thread will lock that thread
        if (NSThread.isMainThread) {
            locationManager = CLLocationManager.new;
            locationManager.delegate = self;
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                locationManager = CLLocationManager.new;
                locationManager.delegate = self;
            });
        }
    }
    
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // This method is required at runtime
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [sbAlert dismiss];
    sbAlert = NULL;
    
    blockToRun(locations.firstObject);
}

@end

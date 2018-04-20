#import "BJLocation.h"
#import "BJSBAlertItem.h"

@interface CLLocationManager (BlackJacketPrivate)
+ (void)setAuthorizationStatusByType:(CLAuthorizationStatus)type forBundleIdentifier:(NSString *)bundle;
@end


@implementation BJLocation {
    /// LocationManager of which we are the delegate, need to hold a strong reference to this
    CLLocationManager *_locationManager;
    /// Block passed in by the caller of showFetch:callBlock:
    void (^_blockToRun)(CLLocation *location);
    /// Alert item used to alert the user a location fetch is in process
    BJSBAlertItem *_sbAlert;
}

- (void)showFetch:(BOOL)show callBlock:(void (^)(CLLocation *location))block {
    _blockToRun = block;
    
    if (show) {
        _sbAlert = [BJSBAlertItem new];
        _sbAlert.alertTitle = @"Getting Location";
        _sbAlert.alertMessage = @"Calculating current location, please wait...";
        _sbAlert.alertActions = @[ [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleCancel handler:NULL] ];
        
        [_sbAlert present];
    }
    
    // authorizationStatus should only need to be reset once per lifetime, but you never know
    while (CLLocationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
        // bundleID should always be com.apple.springboard, but didn't really want to hard code it
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        [CLLocationManager setAuthorizationStatusByType:kCLAuthorizationStatusAuthorizedAlways forBundleIdentifier:bundleID];
    }
    
    [_locationManager requestLocation];
}

- (instancetype)init {
    if (self = [super init]) {
        // CLLocationManager -init needs to be on the main thread
        // to avoid returning before being properly initialized, we using dispatch_sync
        // calling dispatch_sync on the same thread will lock that thread
        void (^setupLocationManager)(void) = ^{
            _locationManager = CLLocationManager.new;
            _locationManager.delegate = self;
        };
        
        if (NSThread.isMainThread) {
            setupLocationManager();
        } else {
            dispatch_sync(dispatch_get_main_queue(), setupLocationManager);
        }
    }
    
    return self;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [_sbAlert dismiss];
    _sbAlert = NULL;
    
    _blockToRun(NULL);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    [_sbAlert dismiss];
    _sbAlert = NULL;
    
    _blockToRun(locations.firstObject);
}

@end

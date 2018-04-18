#import <Flipswitch/Flipswitch.h>

/// Flipswitch data source class that toggles Dropbear between listening on all IPs, and only my VPN
@interface BJDropbearSwitch : NSObject <FSSwitchDataSource>
@end

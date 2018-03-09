#import <libactivator/libactivator.h>

/// Simple Activator Listener to connect to a bluetooth device.
/// Uses private Bluetooth API to connect to a specific pre-paired device by MAC address
@interface BJBluetooth : NSObject <LAListener>
@end

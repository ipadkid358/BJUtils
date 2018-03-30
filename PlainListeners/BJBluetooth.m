#import "BJBluetooth.h"
#import "../BJSharedInfo.h"

@interface BluetoothDevice : NSObject
- (NSString *)address;
- (void)connect;
@end

@interface BluetoothManager : NSObject
+ (instancetype)sharedInstance;
- (NSArray<BluetoothDevice *> *)pairedDevices;
@end


@implementation BJBluetooth

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    // Keep my headphone's MAC private, stored in plist
    NSString *mac = @kHeadphoneMACAddress;
    for (BluetoothDevice *device in BluetoothManager.sharedInstance.pairedDevices) {
        if ([device.address isEqualToString:mac]) {
            [device connect];
            event.handled = YES;
            break;
        }
    }
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.bluetooth"];
}

@end

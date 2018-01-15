#import "BJBluetooth.h"

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
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ipadkid.bjutils"];
    NSString *mac = [userDefaults stringForKey:@"BJBmacAddress"];
    for (BluetoothDevice *device in BluetoothManager.sharedInstance.pairedDevices) {
        if ([device.address isEqualToString:mac]) {
            [device connect];
        }
    }
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.bluetooth"];
}

@end

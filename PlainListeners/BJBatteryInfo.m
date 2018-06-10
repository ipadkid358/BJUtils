// https://www.reddit.com/r/jailbreakdevelopers/comments/2kdj0e/getting_battery_capacity/clkblp3/
// Direct: http://www.tateu.net/repo/files/IOKit.zip
// Mirror: https://ipadkid.cf/mirrors/IOKit.zip
#import <IOKit/IOKitLib.h>

#import "BJBatteryInfo.h"
#import "../MainUtils/BJSBAlertItem.h"

@interface BluetoothDevice : NSObject
- (NSString *)name;
- (int)batteryLevel;
@end

@interface BluetoothManager : NSObject
+ (instancetype)sharedInstance;
- (NSArray<BluetoothDevice *> *)connectedDevices;
@end


@implementation BJBatteryInfo

static NSMutableString *parseValuesIntoMonospacedBlock(NSArray<NSString *> *values) {
    NSArray<NSString *> *keys = @[@"Capacity", @"Charge", @"Temperature"];
    NSUInteger dictSize = keys.count;
    if (dictSize != values.count) {
        return NULL;
    }
    
    NSUInteger lengths[dictSize];
    
    NSUInteger maxLen = 0;
    for (int i = 0; i < dictSize; i++) {
        NSUInteger thisLen = [keys[i] length] + [values[i] length];
        maxLen = MAX(maxLen, thisLen);
        lengths[i] = thisLen;
    }
    
    NSMutableString *ret = [NSMutableString string];
    NSString *blankString = @"";
    NSString *spaceString = @" ";
    for (int i = 0; i < dictSize; i++) {
        NSString *padding = [blankString stringByPaddingToLength:(maxLen - lengths[i]) withString:spaceString startingAtIndex:0];
        [ret appendFormat:@"\n%@:%@ %@", keys[i], padding, values[i]];
    }
    
    return ret;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    // this does not work in *sandboxed* apps on iOS 10 and newer, possibly only on 64-bit devices
    // works on iPhone 5, iOS 10.3.3, but not 6 Plus, 10.2 (both jailbroken, same app compiled with Xcode)
    // another method of accessing this information is demoed in the project below, with the same restrictions
    // https://github.com/ipadkid358/personal-tweaks/blob/master/FullStatusInfo/Tweak.x#L38
    CFMutableDictionaryRef props;
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMPowerSource"));
    IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0);
    NSDictionary *properties = (__bridge NSMutableDictionary *)props;
    CFRelease(props);
    
    NSNumber *maxCapacity = properties[@"DesignCapacity"];
    NSNumber *currentCapacity = properties[@"AppleRawMaxCapacity"];
    NSNumber *currentPower = properties[@"AppleRawCurrentCapacity"];
    NSNumber *celsiusTemp = properties[@"Temperature"];
    int mc = maxCapacity.intValue;
    int cc = currentCapacity.intValue;
    int cp = currentPower.intValue;
    // Temperature is the Celsius value times 100
    float ct = celsiusTemp.floatValue/100;
    
    // %.1f indicated 1 decimal place of a float (or double)
    NSMutableString *body = parseValuesIntoMonospacedBlock(@[
         [NSString stringWithFormat:@"%d/%d", cc, mc],
         [NSString stringWithFormat:@"%d/%d", cp, cc],
         [NSString stringWithFormat:@"%.1f°C", ct]
    ]);
    
    for (BluetoothDevice *bluetoothDevice in BluetoothManager.sharedInstance.connectedDevices) {
        int thisBattery = bluetoothDevice.batteryLevel;
        // devices that do not support battery information are supposed to return -1 for -batteryLevel
        if (thisBattery == -1) {
            continue;
        }
        
        // Because these are each different devices, there are two line breaks
        [body appendFormat:@"\n\n%@: %d%%", bluetoothDevice.name, thisBattery];
    }
    
    NSDictionary<NSString *, id> *alertAttribs = @{ NSFontAttributeName : [UIFont fontWithName:@"Courier" size:14] };

    BJSBAlertItem *sbAlert = [BJSBAlertItem new];
    sbAlert.alertTitle = @"Battery Info";
    sbAlert.alertAttributedMessage = [[NSAttributedString alloc] initWithString:body attributes:alertAttribs];
    sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:NULL]];
    sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.battery/Notif";
    [sbAlert present];
    event.handled = YES;
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.battery"];
}

@end

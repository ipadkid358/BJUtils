// https://www.reddit.com/r/jailbreakdevelopers/comments/2kdj0e/getting_battery_capacity/clkblp3/
// Direct: http://www.tateu.net/repo/files/IOKit.zip
// Mirror: https://ipadkid.cf/mirrors/IOKit.zip
#import <IOKit/IOKitLib.h>

#import "BJBatteryInfo.h"
#import "BJSBAlertItem.h"


@implementation BJBatteryInfo

- (NSString *)parseValues:(NSArray<NSString *> *)values {
    NSArray<NSString *> *keys = @[@"Capacity", @"Charge", @"Temperature"];
    NSMutableArray<NSNumber *> *lengths = [NSMutableArray new];
    NSUInteger maxLen = 0;
    for (int i = 0; i < 3; i++) {
        NSUInteger thisLen = [keys[i] length] + [values[i] length];
        maxLen = MAX(maxLen, thisLen);
        [lengths addObject:[NSNumber numberWithUnsignedInteger:thisLen]];
    }
    
    NSMutableString *ret = [NSMutableString new];
    for (int i = 0; i < 3; i++) {
        NSUInteger pad = maxLen - [lengths[i] unsignedIntegerValue];
        [ret appendFormat:@"\n%@:%@ %@", keys[i], [NSString.string stringByPaddingToLength:pad withString:@" " startingAtIndex:0], values[i]];
    }
    
    return ret;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    // this does not work in sandboxed apps in iOS 10 and newer, possibly only on 64-bit devices
    CFMutableDictionaryRef props;
    IORegistryEntryCreateCFProperties(IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMPowerSource")), &props, kCFAllocatorDefault, 0);
    NSDictionary *properties = (__bridge NSMutableDictionary *)props;
    CFRelease(props);
    
    NSNumber *maxCapacity = properties[@"DesignCapacity"];
    NSNumber *currentCapacity = properties[@"AppleRawMaxCapacity"];
    NSNumber *currentPower = properties[@"AppleRawCurrentCapacity"];
    NSNumber *celsiusTemp = properties[@"Temperature"];
    int mc = maxCapacity.intValue;
    int cc = currentCapacity.intValue;
    int cp = currentPower.intValue;
    float ct = celsiusTemp.floatValue/100;
    
    // %.1f indicated 1 decimal place of a float (or double)
    NSString *body = [self parseValues:@[[NSString stringWithFormat:@"%d/%d", cc, mc], [NSString stringWithFormat:@"%d/%d", cp, cc], [NSString stringWithFormat:@"%.1f°C", ct]]];
    
    BJSBAlertItem *sbAlert = [BJSBAlertItem new];
    sbAlert.alertTitle = @"Battery Info";
    sbAlert.alertAttributedMessage = [[NSAttributedString alloc] initWithString:body attributes:@{@"NSFont":[UIFont fontWithName:@"Courier" size:14]}];
    sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [sbAlert dismiss];
    }]];
    sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.battery/Notif";
    [sbAlert present];
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.battery"];
}

@end

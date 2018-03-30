#import <spawn.h>

#import "BJDropbearSwitch.h"
#import "../BJSharedInfo.h"

@implementation BJDropbearSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier {
    NSDictionary *prefsCheck = [NSDictionary dictionaryWithContentsOfFile:@kDropbearPath];
    if (!prefsCheck) {
        return FSSwitchStateIndeterminate;
    }
    
    NSArray *progArgs = prefsCheck[@kProgramArgumentsKey];
    return (progArgs && [progArgs.lastObject isEqualToString:@kSSHPortString]);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier {
    execlp("/usr/bin/toggleDropbearSwitch", "toggleDropbearSwitch", ((newState == 1) ? "1" : "0"));
}

@end

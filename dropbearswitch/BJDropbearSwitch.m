#import <spawn.h>

#import "BJDropbearSwitch.h"

@implementation BJDropbearSwitch

- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier {
    NSDictionary *prefsCheck = [NSDictionary dictionaryWithContentsOfFile:@"/Library/LaunchDaemons/dropbear.plist"];
    if (!prefsCheck) {
        return FSSwitchStateOff;
    }
    
    NSArray *progArgs = prefsCheck[@"ProgramArguments"];
    return (progArgs && [progArgs.lastObject isEqualToString:@"22"]);
}

- (void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString *)switchIdentifier {
    pid_t pid;
    NSNumber *switchState = [NSNumber numberWithInt:newState];
    char *argv[] = { "toggleDropbearSwitch", (char *)switchState.stringValue.UTF8String, NULL };
    
    posix_spawn(&pid, "/usr/bin/toggleDropbearSwitch", NULL, NULL, argv, NULL);
    waitpid(pid, NULL, 0);
}

@end

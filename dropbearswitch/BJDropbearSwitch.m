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
    pid_t pid;
    char *argv[] = { "toggleDropbearSwitch", (newState ? "1" : "0"), NULL };
    posix_spawn(&pid, "/usr/bin/toggleDropbearSwitch", NULL, NULL, argv, NULL);
    // don't really need to wait, but we don't want the switch to be spammed or anything
    waitpid(pid, NULL, 0);
}

@end

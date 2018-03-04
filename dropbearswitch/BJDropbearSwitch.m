#import <spawn.h>

#import "BJDropbearSwitch.h"
#import "../BJSharedStrings.h"

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
    NSNumber *switchState = [NSNumber numberWithInt:newState];
    char *argv[] = { "toggleDropbearSwitch", (char *)switchState.stringValue.UTF8String, NULL };
    
    posix_spawn(&pid, "/usr/bin/toggleDropbearSwitch", NULL, NULL, argv, NULL);
    waitpid(pid, NULL, 0);
}

@end

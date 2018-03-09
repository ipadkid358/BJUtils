#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <spawn.h>

#import "../BJSharedInfo.h"

void toggleDropbear(char *load) {
    pid_t pid;
    char *argv[] = { "launchctl", load, kDropbearPath, NULL };
    
    posix_spawn(&pid, "/bin/launchctl", NULL, NULL, argv, NULL);
    waitpid(pid, NULL, 0);
}

int main(int argc, char *argv[]) {
    uid_t root = 0;
    gid_t wheel = 0;
    
    setuid(root);
    setgid(wheel);
    
    // root required for setting permissions on the plist, and to load and unload the process
    if ((getuid() != root) || (getgid() != wheel)) {
        return 1;
    }
    
    @autoreleasepool {
        NSString *dropbearPath = @kDropbearPath;
        NSMutableDictionary *dropbearPrefs = [NSMutableDictionary dictionaryWithContentsOfFile:dropbearPath];
        if (!dropbearPrefs) {
            return 1;
        }
        
        NSString *progArgsKey = @kProgramArgumentsKey;
        NSMutableArray *progArgs = [NSMutableArray arrayWithArray:dropbearPrefs[progArgsKey]];
        NSString *basePort = @kSSHPortString;
        if (progArgs.count != 7) {
            progArgs[4] = @"127.0.0.1:51022";
            progArgs[5] = @"-p";
            progArgs[6] = basePort;
        }
        
        const char *coreArg = argv[1];
        if (!coreArg) {
            return 1;
        }
        
        // problem with this is if the device is not on the VPN, the server needs to be restarted again, once it is
        progArgs[6] = [[NSString stringWithUTF8String:coreArg] boolValue] ? basePort : @kPhoneVPNIP ":" kSSHPortString;
        
        dropbearPrefs[progArgsKey] = progArgs;
        
        if (![dropbearPrefs writeToFile:dropbearPath atomically:YES]) {
            return 1;
        }
        
        chown(kDropbearPath, 0, 0);
        chmod(kDropbearPath, 0644);
        toggleDropbear("unload");
        toggleDropbear("load");
    }
    
    return 0;
}

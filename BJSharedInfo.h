#define kDropbearPath "/Library/LaunchDaemons/dropbear.plist"
#define kSSHPortString "22"
#define kProgramArgumentsKey "ProgramArguments"
#define kPhoneVPNIP "10.8.0.2"

/// Single shared UserDefaults instance. Used in multiple classes, and allows memory to stay low. Set in +[BJServer load]
extern NSUserDefaults *sharedBlackJacketDefaults;

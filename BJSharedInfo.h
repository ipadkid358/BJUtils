#if defined(__has_include)
#   if __has_include("BJPrivateKeys.h")
#       include "BJPrivateKeys.h"
#   endif
#endif

#ifndef BJHasPrivateKeys
#   error \
Please see readMe, this tweak is not intended for public use. \
Some information is stored in a private header file, which this project will not compile without
#endif

#define kDropbearPath "/Library/LaunchDaemons/dropbear.plist"
#define kSSHPortString "22"
#define kProgramArgumentsKey "ProgramArguments"

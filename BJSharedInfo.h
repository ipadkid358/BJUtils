#if defined(__has_include)
#    if __has_include("BJPrivateKeys.h")
#        include "BJPrivateKeys.h"
#    endif
#endif

#ifndef BJHasPrivateKeys
#    error Please see readMe, this tweak is not intended for public use. Some information is stored in a private header file, which this project will not compile without
#endif

/// Macro used to force only one instance of a class at runtime
#define force_shared_instace_runtime                                                                                                           \
    ({                                                                                                                                         \
        static dispatch_once_t onceToken;                                                                                                      \
        static BOOL onceOnly = YES;                                                                                                            \
        if (!onceOnly) {                                                                                                                       \
            NSString *thisClassName = NSStringFromClass(self.class);                                                                           \
            SEL sharedInstanceCheck = @selector(sharedInstance);                                                                               \
            NSString *sharedInstanceString = NSStringFromSelector(sharedInstanceCheck);                                                        \
            NSAssert(0, @"%@ can only be created once per lifetime. Use %@.%@ to access", thisClassName, thisClassName, sharedInstanceString); \
        }                                                                                                                                      \
        dispatch_once(&onceToken, ^{                                                                                                           \
            onceOnly = NO;                                                                                                                     \
        });                                                                                                                                    \
    })

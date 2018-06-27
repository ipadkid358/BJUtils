#import <UIKit/UIKit.h>

/// A TCP server instance that manages requests from my server. All connections are done directly over a VPN
@interface BJServer : NSObject

/// Shared server instance. A new instance should not be manually created
@property (class, readonly, strong) BJServer *sharedInstance;

/**
 @brief Start running the server. Handles starting all relavent notifications
 
 @returns Whether the server was successfully started. Should only fail if the server is already running
 */
- (BOOL)start;

/**
 @brief Stop running the server. Handles cancelling all notifications, and freeing memory
 
 @returns Whether the server was successfully stopped. Should only fail if the server is not running when called
 */
- (BOOL)stop;

@end

#import <UIKit/UIKit.h>

@interface BJServer : NSObject

/*!
 @brief Shared server instance. A new server should not be manually created
 
 @returns Globally used server instance
 */
+ (instancetype)sharedInstance;

/*!
 @brief Start running the server. Handles starting all relavent notifications
 
 @returns Whether the server was successfully started. Should only fail if the server is already running
 */
- (BOOL)start;

/*!
 @brief Stop running the server. Handles cancelling all notifications, and freeing memory
 
 @returns Whether the server was successfully stopped. Should only fail if the server is not running when called
 */
- (BOOL)stop;

@end

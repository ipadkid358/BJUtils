#import <UIKit/UIKit.h>

@interface BJServer : NSObject

+ (instancetype)sharedInstance;
- (BOOL)start;
- (BOOL)stop;

@end

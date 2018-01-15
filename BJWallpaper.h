#import <libactivator/libactivator.h>

@interface BJWallpaper : NSObject <LAListener>

@property BOOL shouldPost;

+ (instancetype)sharedInstance;
- (void)updateWallpaper;

@end

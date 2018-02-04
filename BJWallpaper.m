#import "BJWallpaper.h"

@interface PLStaticWallpaperImageViewController : NSObject
- (instancetype)initWithUIImage:(UIImage *)image;
- (void)setWallpaperForLocations:(long long)mask;
@end

@implementation BJWallpaper

+ (instancetype)sharedInstance {
    static dispatch_once_t dispatchOnce;
    static BJWallpaper *ret = nil;
    
    dispatch_once(&dispatchOnce, ^{
        ret = self.new;
        [LASharedActivator registerListener:ret forName:@"com.ipadkid.wallpaper"];
    });
    
    return ret;
}

- (void)updateWallpaper {
    @autoreleasepool {
        // use the link from Preferences, but if it can't be parsed, fall back to Unsplash
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ipadkid.bjutils"];
        NSString *fallback = @"https://source.unsplash.com/random";
        NSURL *from = [NSURL URLWithString:[userDefaults stringForKey:@"BJWImageURL"]] ?: [NSURL URLWithString:fallback];
        [[NSURLSession.sharedSession dataTaskWithURL:from completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!data) {
                return;
            }
            
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                PLStaticWallpaperImageViewController *wallpaper = [[PLStaticWallpaperImageViewController alloc] initWithUIImage:image];
                
                if (_shouldPost) {
                    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1:1627/wallpaper"]];
                    req.HTTPMethod = @"POST";
                    req.HTTPBody = data;
                    [[NSURLSession.sharedSession dataTaskWithRequest:req] resume];
                }
                
                if (wallpaper) {
                    // see: https://github.com/ipadkid358/UnsplashWalls#-setwallpaperforlocations-documentation
                    [wallpaper setWallpaperForLocations:3];
                }
            }
        }] resume];
    }
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    [self updateWallpaper];
}

@end

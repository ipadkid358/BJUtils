#import <notify.h>
#import <objc/runtime.h>

#import "../BJSharedInfo.h"
#import "BJWallpaper.h"

@interface PLStaticWallpaperImageViewController : NSObject
- (instancetype)initWithUIImage:(UIImage *)image;
- (void)setWallpaperForLocations:(PLStaticWallpaperLocation)mask;
@end

@interface SBFWallpaperView : UIView
- (UIImage *)snapshotImage;
@end

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (SBFWallpaperView *)lockscreenWallpaperView;
- (SBFWallpaperView *)homescreenWallpaperView;
- (SBFWallpaperView *)sharedWallpaperView;
@end


@implementation BJWallpaper {
    NSUserDefaults *_defaults;
}

- (instancetype)init {
    if (self = [super init]) {
        force_shared_instace_runtime;
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ipadkid.bjutils"];
    }
    
    return self;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t dispatchOnce;
    static BJWallpaper *ret = nil;
    
    dispatch_once(&dispatchOnce, ^{
        ret = self.new;
        [LASharedActivator registerListener:ret forName:@"com.ipadkid.wallpaper"];
        [ret updateEndpoint];
        
        __weak __typeof(ret) weakself = ret;
        int notifyRegToken;
        notify_register_dispatch("com.ipadkid.bjutils/wallpaper", &notifyRegToken, dispatch_get_main_queue(), ^(int token) {
            [weakself updateEndpoint];
        });
    });
    
    return ret;
}

- (void)updateEndpoint {
    // use the link from Preferences, but if it can't be parsed, fall back to Unsplash
    _wallpaperEndpoint = [_defaults URLForKey:@"BJWImageURL"] ?: [NSURL URLWithString:@"https://source.unsplash.com/random"];
}

- (void)updateWallpaperForLocation:(PLStaticWallpaperLocation)location {
    @autoreleasepool {
        [[NSURLSession.sharedSession dataTaskWithURL:_wallpaperEndpoint completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
                    [wallpaper setWallpaperForLocations:location];
                }
            }
        }] resume];
    }
}

- (UIImage *)wallpaperForLocation:(PLStaticWallpaperLocation)location {
    SBWallpaperController *wallpaperController = [objc_getClass("SBWallpaperController") sharedInstance];
    SBFWallpaperView *wallpaperView = NULL;
    
    switch (location) {
        case PLStaticWallpaperLocationHomescreen:
            wallpaperView = wallpaperController.homescreenWallpaperView;
            break;
            
        case PLStaticWallpaperLocationLockscreen:
            wallpaperView = wallpaperController.lockscreenWallpaperView;
            break;
            
        default:
            wallpaperView = wallpaperController.sharedWallpaperView;
            break;
    }
    
    if (!wallpaperView) {
        wallpaperView = wallpaperController.sharedWallpaperView;
    }
    
    return wallpaperView.snapshotImage;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    [self updateWallpaperForLocation:(PLStaticWallpaperLocationLockscreen | PLStaticWallpaperLocationHomescreen)];
}

@end

#import <libactivator/libactivator.h>

/// Convenience reference to wallpaper locations
typedef NS_ENUM(NSUInteger, PLStaticWallpaperLocation) {
    /// Wallpaper lockscreen location
    PLStaticWallpaperLocationLockscreen = 1,
    /// Wallpaper homescreen location
    PLStaticWallpaperLocationHomescreen = 2,
};

/// Activator Listener to change SpringBoard wallpaper. Provides an interface for getting and settings wallpapers.
/// Optionally posts set wallpapers to my server (based on shouldPost property)
@interface BJWallpaper : NSObject <LAListener>

/**
 @brief Shared instance for convenience purposes
 
 @returns Wallpaper shared instance
 */
+ (instancetype)sharedInstance;

/// Whether the new wallpapers should be sent to the server
@property (nonatomic) BOOL shouldPost;

/// URL from which the wallpaper with be downloaded from
@property (nonatomic) NSURL *wallpaperEndpoint;

/**
 @brief Fetches a new wallpaper from the wallpaperEndpoint and sets it to location
 
 @param location Specify lockscreen, homescreen, or both (using bitwise)
 */
- (void)updateWallpaperForLocation:(PLStaticWallpaperLocation)location;

/**
 @brief Retrive the current wallpaper for a location
 
 @param location Specify lockscreen, homescreen, or both (using bitwise, only will work if the wallpaper was set to both locations)
 
 @returns Full image of the wallpaper
 */
- (UIImage *)wallpaperForLocation:(PLStaticWallpaperLocation)location;

@end

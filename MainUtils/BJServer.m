#import <MediaRemote/MediaRemote.h>
#import <AVFoundation/AVFoundation.h>
#import <arpa/inet.h>
#import <objc/runtime.h>

#import "../BJSharedInfo.h"
#import "BJLocation.h"
#import "BJSBAlertItem.h"
#import "BJServer.h"
#import "BJWallpaper.h"

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)nowPlayingApplication;
@end

@interface VolumeControl : NSObject
+ (instancetype)sharedVolumeControl;
- (void)setMediaVolume:(float)volume;
@end

@interface SBTelephonyManager : NSObject
+ (instancetype)sharedTelephonyManager;
- (BOOL)isUsingVPNConnection;
@end

@interface UIApplication (UIApplicationOpenURL)
- (void)applicationOpenURL:(NSURL *)url;
@end

/// Key used to check userDefaults to get the persitent load state
static NSString *kPersistentLoadKey = @"BJPersistantServerLoadKey";
/// Persisent preferences, used to check server load persistence
static NSUserDefaults *userDefaults = NULL;

@implementation BJServer {
    /// Notification ref, used to remove the notification observer
    id<NSObject> _musicNotifToken;
    /// AudioPlayer used to play and stop sounds when triggered by the server
    AVAudioPlayer *_audioPlayer;
    /// Timer used to check VPN every two minutes, used to stop the timer
    NSTimer *_minuteTimer;
    /// If the server is currently loaded, used to disallow multiple starts
    BOOL _isLoaded;
    /// Socket the TCP server is using, used to stop the server
    int _tcpCloseSocket;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t dispatchOnce;
    static BJServer *ret = nil;
    
    dispatch_once(&dispatchOnce, ^{
        ret = self.new;
    });
    
    return ret;
}

- (instancetype)init {
    if (self = [super init]) {
        force_shared_instace_runtime;
    }
    return self;
}

- (void)startAudio {
    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:NULL];
    
    // No particular reason for this file, any audio file can be used
    NSData *musicData = [NSData dataWithContentsOfFile:@"/System/Library/Audio/UISounds/New/Sherwood_Forest.caf"];
    _audioPlayer = [[AVAudioPlayer alloc] initWithData:musicData error:NULL];
    _audioPlayer.numberOfLoops = -1;
    
    // audioPlayer.volume doesn't appear to work
    VolumeControl *volumeControl = [objc_getClass("VolumeControl") sharedVolumeControl];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [audioSession setActive:YES error:NULL];
        [_audioPlayer play];
        [volumeControl setMediaVolume:1];
    });
}

- (void)stopAudio {
    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_audioPlayer) {
            [_audioPlayer stop];
            _audioPlayer = NULL;
            [audioSession setActive:NO error:NULL];
        }
    });
}

- (void)postLocation {
    CLGeocoder *geocoder = CLGeocoder.new;
    CLLocation *location = BJLocation.sharedInstance.latestLocation;
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (error) {
            return;
        }
        
        CLPlacemark *targetPlacemark = placemarks.firstObject;
        if (targetPlacemark) {
            CLLocationCoordinate2D coordinates = location.coordinate;
            CLLocationDegrees latitude = coordinates.latitude;
            CLLocationDegrees longitude = coordinates.longitude;
            NSString *restrict postStrTemplate = @"%@, %@, %@ %@ <a href=\"https://maps.google.com/?ll=%f,%f\" target=\"_blank\">(%f, %f)</a>";
            NSString *postStr = [NSString stringWithFormat:postStrTemplate, targetPlacemark.name, targetPlacemark.locality, targetPlacemark.administrativeArea, targetPlacemark.postalCode, latitude, longitude, latitude, longitude];
            
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1:1627/location"]];
            req.HTTPMethod = @"POST";
            req.HTTPBody = [postStr dataUsingEncoding:NSUTF8StringEncoding];
            [[NSURLSession.sharedSession dataTaskWithRequest:req] resume];
        }
    }];
}

- (void)tcpHandler:(NSString *)body {
    @autoreleasepool {
        if ([body isEqualToString:@"wallpapr"]) {
            [BJWallpaper.sharedInstance updateWallpaperForLocation:(PLStaticWallpaperLocationLockscreen | PLStaticWallpaperLocationHomescreen)];
            return;
        }
        if ([body isEqualToString:@"strAudio"]) {
            [self startAudio];
            return;
        }
        if ([body isEqualToString:@"stpAudio"]) {
            [self stopAudio];
            return;
        }
        if ([body isEqualToString:@"location"]) {
            [self postLocation];
            return;
        }
    }
}

- (void)tcpListener {
    __weak __typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        struct sockaddr_in serv;
        memset(&serv, 0, sizeof(serv));
        serv.sin_family = AF_INET;
        // listening on my phone's IP on my VPN
        serv.sin_addr.s_addr = inet_addr(kPhoneVPNIP);
        // port 8080, because that's fairly normal, and SpringBoard does not run as a privileged user
        serv.sin_port = htons(8080);
        
        _tcpCloseSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (!_tcpCloseSocket) {
            // fail silently if a connection isn't able to be made
            // this is more for safety reasons, I highly doubt it will ever happen
            return;
        }
        
        bind(_tcpCloseSocket, (struct sockaddr *)&serv, sizeof(struct sockaddr));
        
        char value = 1;
        setsockopt(_tcpCloseSocket, SOL_SOCKET, SO_REUSEADDR, &value, 1);
        
        listen(_tcpCloseSocket, 1);
        
        const int buffSize = 8;
        char reader[buffSize];
        int consocket;
        // this is locking, unless you're a command line tool, this needs to be in a background thread
        while (_tcpCloseSocket && (consocket = accept(_tcpCloseSocket, NULL, NULL))) {
            memset(&reader, 0, buffSize);
            read(consocket, &reader, buffSize);
            [weakself tcpHandler:[[NSString alloc] initWithBytes:reader length:buffSize encoding:NSUTF8StringEncoding]];
            // to make sure everything went well, this is sent back to the server, 2 is strlen("OK")
            write(consocket, "OK", 2);
            close(consocket);
        }
        
        close(_tcpCloseSocket);
    });
}

- (void)musicListener {
    static NSString *lastMusicStringFetch = NULL;
    NSURL *fetchMusicEndpoint = [NSURL URLWithString:@"https://ipadkid.cf/status/music.txt"];
    [[NSURLSession.sharedSession dataTaskWithURL:fetchMusicEndpoint completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            lastMusicStringFetch = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }] resume];
    
    NSString *notifName = (__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification;
    _musicNotifToken = [NSNotificationCenter.defaultCenter addObserverForName:notifName object:NULL queue:NULL usingBlock:^(NSNotification *note) {
        SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
        NSString *playingApp = mediaController.nowPlayingApplication.bundleIdentifier;
        // only report audio from YouTube Music
        if (![playingApp isEqualToString:@"com.google.ios.youtubemusic"]) {
            return;
        }
        
        MRMediaRemoteGetNowPlayingInfo(dispatch_get_global_queue(0, 0), ^(CFDictionaryRef result) {
            NSDictionary *musicDict = (__bridge NSDictionary *)result;
            
            NSString *songName = musicDict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTitle];
            NSString *artistName = musicDict[(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtist];
            if (!songName || !artistName) {
                return;
            }
            
            NSString *newMusic = [NSString stringWithFormat:@"%@ by %@", songName, artistName];
            if ([newMusic isEqualToString:lastMusicStringFetch]) {
                return;
            }
            
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1:1627/music"]];
            req.HTTPMethod = @"POST";
            req.HTTPBody = [newMusic dataUsingEncoding:NSUTF8StringEncoding];
            [[NSURLSession.sharedSession dataTaskWithRequest:req] resume];
            lastMusicStringFetch = newMusic;
        });
    }];
}

- (void)everyOtherMinute:(NSTimer *)timer {
    __weak __typeof(self) weakself = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1/ip"] cachePolicy:1 timeoutInterval:2.2];
        [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                BJSBAlertItem *sbAlert = [BJSBAlertItem new];
                sbAlert.alertMessage = error.localizedDescription;
                sbAlert.alertTitle = @"VPN Issue";
                sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [sbAlert dismiss];
                }], [UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [UIApplication.sharedApplication applicationOpenURL:[NSURL URLWithString:@"prefs:root=General&path=VPN"]];
                    [sbAlert dismiss];
                }], [UIAlertAction actionWithTitle:@"Unload" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    [weakself stop];
                    [sbAlert dismiss];
                }]];
                
                [sbAlert present];
            }
        }] resume];
    });
}

- (BOOL)stop {
    if (!_isLoaded) {
        return NO;
    }
    
    [userDefaults setBool:NO forKey:kPersistentLoadKey];
    
    // tcpListener
    close(_tcpCloseSocket);
    _tcpCloseSocket = 0;
    
    // musicListener
    if (_musicNotifToken) {
        [NSNotificationCenter.defaultCenter removeObserver:_musicNotifToken];
        _musicNotifToken = NULL;
    }
    
    // everyOtherMinute
    [_minuteTimer invalidate];
    _minuteTimer = NULL;
    
    // turn off posts for wallpaper
    BJWallpaper.sharedInstance.shouldPost = NO;
    
    // set unloaded
    _isLoaded = NO;
    return YES;
}

- (BOOL)start {
    if (_isLoaded) {
        return NO;
    }
    
    _isLoaded = YES;
    [self tcpListener];
    [self musicListener];
    
    _minuteTimer = [NSTimer scheduledTimerWithTimeInterval:120 target:self selector:@selector(everyOtherMinute:) userInfo:NULL repeats:YES];
    
    BJWallpaper.sharedInstance.shouldPost = YES;
    [userDefaults setBool:YES forKey:kPersistentLoadKey];
    
    return YES;
}

// load is called automatically when the class is loaded into the runtime
+ (void)load {
    // make sure all classes are added into the runtime before making objc_getClass calls
    dispatch_async(dispatch_get_main_queue(), ^{
        BJServer *server = BJServer.sharedInstance;
        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ipadkid.bjutils"];
        if ((BJWallpaper.sharedInstance.shouldPost = [userDefaults boolForKey:kPersistentLoadKey])) {
            [server start];
        }
        
        [NSNotificationCenter.defaultCenter addObserverForName:@"SBVPNConnectionChangedNotification" object:NULL queue:NULL usingBlock:^(NSNotification *note) {
            SBTelephonyManager *telephoneInfo = [objc_getClass("SBTelephonyManager") sharedTelephonyManager];
            if (telephoneInfo.isUsingVPNConnection) {
                [server start];
            }
        }];
    });
}

@end

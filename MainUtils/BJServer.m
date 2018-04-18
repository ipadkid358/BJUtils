#import <MediaRemote/MediaRemote.h>

#import <AVFoundation/AVFoundation.h>
#import <arpa/inet.h>
#import <notify.h>
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

@interface UIApplication (BlackJacketPrivate)
- (void)applicationOpenURL:(NSURL *)target;
@end

@implementation BJServer {
    /// Last string posted to the music server, check for duplicates
    NSString *_lastMusicStringFetch;
    /// Notification ref, used to remove the notification observer
    id<NSObject> _musicSystemNotif;
    /// AudioPlayer used to play and stop sounds when triggered by the server
    AVAudioPlayer *_audioPlayer;
    /// Strong reference to a Location instance
    BJLocation *_locationInstance;
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
    [_locationInstance showFetch:NO callBlock:^(CLLocation *location) {
        [CLGeocoder.new reverseGeocodeLocation:location
                             completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
                                 if (error) {
                                     return;
                                 }
                                 
                                 CLPlacemark *targetPlacemark = placemarks.firstObject;
                                 if (targetPlacemark) {
                                     CLLocationCoordinate2D coordinates = location.coordinate;
                                     CLLocationDegrees latitude = coordinates.latitude;
                                     CLLocationDegrees longitude = coordinates.longitude;
                                     NSString *postStr = [NSString stringWithFormat:@"%@, %@, %@ %@ <a href=\"https://maps.google.com/?ll=%f,%f\" target=\"_blank\">(%f, %f)</a>",
                                                          targetPlacemark.name, targetPlacemark.locality, targetPlacemark.administrativeArea,
                                                          targetPlacemark.postalCode, latitude, longitude, latitude, longitude];
                                     
                                     NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1:1627/location"]];
                                     req.HTTPMethod = @"POST";
                                     req.HTTPBody = [postStr dataUsingEncoding:NSUTF8StringEncoding];
                                     [[NSURLSession.sharedSession dataTaskWithRequest:req] resume];
                                 }
                             }];
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
            [self tcpHandler:[[NSString alloc] initWithBytes:reader length:buffSize encoding:NSUTF8StringEncoding]];
            // to make sure everything went well, this is sent back to the server, the 2 is strlen("OK")
            write(consocket, "OK", 2);
            close(consocket);
        }
        
        close(_tcpCloseSocket);
    });
}

- (void)musicListener {
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:@"https://ipadkid.cf/status/music.txt"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            _lastMusicStringFetch = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }] resume];
    
    NSString *notifName = (__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification;
    _musicSystemNotif = [NSNotificationCenter.defaultCenter addObserverForName:notifName object:NULL queue:NULL usingBlock:^(NSNotification *note) {
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
            if ([newMusic isEqualToString:_lastMusicStringFetch]) {
                return;
            }
            
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1:1627/music"]];
            req.HTTPMethod = @"POST";
            req.HTTPBody = [newMusic dataUsingEncoding:NSUTF8StringEncoding];
            [[NSURLSession.sharedSession dataTaskWithRequest:req] resume];
            _lastMusicStringFetch = newMusic;
        });
    }];
}

- (void)everyOtherMinute:(NSTimer *)timer {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1/ip"] cachePolicy:1 timeoutInterval:2.2];
        [[NSURLSession.sharedSession dataTaskWithRequest:req
                                       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                           if (error) {
                                               BJSBAlertItem *sbAlert = [BJSBAlertItem new];
                                               sbAlert.alertMessage = error.localizedDescription;
                                               sbAlert.alertTitle = @"VPN Issue";
                                               sbAlert.alertActions = @[
                                                                        [UIAlertAction actionWithTitle:@"Thanks"
                                                                                                 style:UIAlertActionStyleCancel
                                                                                               handler:^(UIAlertAction *action) {
                                                                                                   [sbAlert dismiss];
                                                                                               }],
                                                                        [UIAlertAction actionWithTitle:@"Settings"
                                                                                                 style:UIAlertActionStyleDefault
                                                                                               handler:^(UIAlertAction *action) {
                                                                                                   [UIApplication.sharedApplication applicationOpenURL:[NSURL URLWithString:@"prefs:root=General&path=VPN"]];
                                                                                                   [sbAlert dismiss];
                                                                                               }],
                                                                        [UIAlertAction actionWithTitle:@"Unload"
                                                                                                 style:UIAlertActionStyleDestructive
                                                                                               handler:^(UIAlertAction *action) {
                                                                                                   [self stop];
                                                                                                   [sbAlert dismiss];
                                                                                               }]
                                                                        ];
                                               [sbAlert present];
                                           }
                                       }] resume];
    });
}

- (BOOL)stop {
    if (!_isLoaded) {
        return NO;
    }
    
    // tcpListener
    close(_tcpCloseSocket);
    _tcpCloseSocket = 0;
    
    // musicListener
    _lastMusicStringFetch = NULL;
    if (_musicSystemNotif) {
        [NSNotificationCenter.defaultCenter removeObserver:_musicSystemNotif];
        _musicSystemNotif = NULL;
    }
    
    // everyOtherMinute
    [_minuteTimer invalidate];
    _minuteTimer = NULL;
    
    // turn off posts for wallpaper
    BJWallpaper.sharedInstance.shouldPost = NO;
    
    // free memory
    _locationInstance = NULL;
    
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
    
    _locationInstance = [BJLocation new];
    
    _minuteTimer = [NSTimer scheduledTimerWithTimeInterval:120 target:self selector:@selector(everyOtherMinute:) userInfo:NULL repeats:YES];
    
    BJWallpaper.sharedInstance.shouldPost = YES;
    
    return YES;
}

// load is called automatically when the class is loaded into the runtime
+ (void)load {
    // make sure all classes are added into the runtime before making objc_getClass calls
    dispatch_async(dispatch_get_main_queue(), ^{
        [BJServer.sharedInstance start];
    });
}

@end

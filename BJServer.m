#import <MediaRemote/MediaRemote.h>
#import <Flipswitch/FSSwitchPanel.h>

#import <AVFoundation/AVFoundation.h>
#import <arpa/inet.h>
#import <objc/runtime.h>
#import <notify.h>

#import "BJServer.h"
#import "BJWallpaper.h"
#import "BJSBAlertItem.h"
#import "BJLocation.h"

#define PHONEIP "10.8.0.2"

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
    NSString *lastMusicStringFetch;
    id<NSObject> musicSystemNotif;
    AVAudioPlayer *audioPlayer;
    BJLocation *locationInstance;
    NSTimer *minuteTimer;
    BOOL isLoaded;
    int tcpCloseSocket;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t dispatchOnce;
    static BJServer *ret = nil;
    
    dispatch_once(&dispatchOnce, ^{
        ret = self.new;
        
        // check that dropbear is setup the way I want, could change after reboot
        [ret checkDropbear];
    });
    
    return ret;
}

- (void)startAudio {
    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:NULL];
    
    // No particular reason for this file, any audio file can be used
    NSData *musicData = [NSData dataWithContentsOfFile:@"/System/Library/Audio/UISounds/New/Sherwood_Forest.caf"];
    audioPlayer = [[AVAudioPlayer alloc] initWithData:musicData error:NULL];
    audioPlayer.numberOfLoops = -1;
    
    // audioPlayer.volume doesn't appear to work
    VolumeControl *volumeControl = [objc_getClass("VolumeControl") sharedVolumeControl];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [audioSession setActive:YES error:NULL];
        [audioPlayer play];
        [volumeControl setMediaVolume:1];
    });
}

- (void)stopAudio {
    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (audioPlayer) {
            [audioPlayer stop];
            audioPlayer = NULL;
            [audioSession setActive:NO error:NULL];
        }
    });
}

- (void)postLocation {
    [locationInstance showFetch:NO callBlock:^(CLLocation *location) {
        [CLGeocoder.new reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
            if (error) {
                return;
            }
            
            CLPlacemark *targetPlacemark = placemarks.firstObject;
            if (targetPlacemark) {
                CLLocationCoordinate2D coordinates = location.coordinate;
                CLLocationDegrees latitude = coordinates.latitude;
                CLLocationDegrees longitude = coordinates.longitude;
                NSString *postStr = [NSString stringWithFormat:@"%@, %@, %@ %@ <a href=\"https://maps.google.com/?ll=%f,%f\" target=\"_blank\">(%f, %f)</a>", targetPlacemark.name, targetPlacemark.locality, targetPlacemark.administrativeArea, targetPlacemark.postalCode, latitude, longitude, latitude, longitude];
                
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
            [BJWallpaper.sharedInstance updateWallpaper];
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
        serv.sin_addr.s_addr = inet_addr(PHONEIP);
        serv.sin_port = htons(8080);
        
        tcpCloseSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (!tcpCloseSocket) {
            return;
        }
        
        bind(tcpCloseSocket, (struct sockaddr *)&serv, sizeof(struct sockaddr));
        
        char value = 1;
        setsockopt(tcpCloseSocket, SOL_SOCKET, SO_REUSEADDR, &value, 1);
        
        listen(tcpCloseSocket, 1);
        int consocket;
        const int buffSize = 8;
        char reader[buffSize];
        while (tcpCloseSocket && (consocket = accept(tcpCloseSocket, NULL, NULL))) {
            memset(&reader, 0, buffSize);
            read(consocket, &reader, buffSize);
            [self tcpHandler:[[NSString alloc] initWithBytes:reader length:buffSize encoding:NSUTF8StringEncoding]];
            write(consocket, "OK", 2);
            close(consocket);
        }
        
        close(tcpCloseSocket);
    });
}

- (void)musicListener {
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://ipadkid.cf/status/music.txt"] cachePolicy:1 timeoutInterval:1.6];
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            lastMusicStringFetch = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        if (!lastMusicStringFetch) {
            lastMusicStringFetch = [NSString new];
        }
    }] resume];
    
    NSString *notifName = (__bridge NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification;
    musicSystemNotif = [NSNotificationCenter.defaultCenter addObserverForName:notifName object:NULL queue:NULL usingBlock:^(NSNotification *note) {
        SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
        NSString *playingApp = mediaController.nowPlayingApplication.bundleIdentifier;
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
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://10.8.0.1/ip"] cachePolicy:1 timeoutInterval:1.2];
        [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!data || error || ![[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] isEqualToString:@PHONEIP]) {
                BJSBAlertItem *sbAlert = [BJSBAlertItem new];
                sbAlert.alertMessage = error ? error.localizedDescription : @"An unexpected IP was assigned";
                sbAlert.alertTitle = @"VPN Issue";
                NSMutableArray<UIAlertAction *> *vpnAlertActions = [NSMutableArray new];
                [vpnAlertActions addObject:[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                    [sbAlert dismiss];
                }]];
                [vpnAlertActions addObject:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    [UIApplication.sharedApplication applicationOpenURL:[NSURL URLWithString:@"prefs:root=General&path=VPN"]];
                    [sbAlert dismiss];
                }]];
                [vpnAlertActions addObject:[UIAlertAction actionWithTitle:@"Unload" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                    [self stop];
                    [sbAlert dismiss];
                }]];
                sbAlert.alertActions = vpnAlertActions;
                [sbAlert present];
            }
        }] resume];
    });
}

- (BOOL)stop {
    if (!isLoaded) {
        return NO;
    }
    
    // tcpListener
    close(tcpCloseSocket);
    tcpCloseSocket = 0;
    
    // musicListener
    lastMusicStringFetch = NULL;
    if (musicSystemNotif) {
        [NSNotificationCenter.defaultCenter removeObserver:musicSystemNotif];
        musicSystemNotif = NULL;
    }
    
    // everyOtherMinute
    [minuteTimer invalidate];
    minuteTimer = NULL;
    
    // turn off posts for wallpaper
    BJWallpaper.sharedInstance.shouldPost = NO;
    
    // free memory
    locationInstance = NULL;
    
    // set unloaded
    isLoaded = NO;
    return YES;
}

- (BOOL)start {
    if (isLoaded) {
        return NO;
    }
    
    isLoaded = YES;
    [self tcpListener];
    [self musicListener];
    
    locationInstance = [BJLocation new];
    
    minuteTimer = [NSTimer scheduledTimerWithTimeInterval:120 target:self selector:@selector(everyOtherMinute:) userInfo:NULL repeats:YES];
    
    BJWallpaper.sharedInstance.shouldPost = YES;
    
    return YES;
}

- (void)checkDropbear {
    NSDictionary<NSString *, id> *dropbearPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/Library/LaunchDaemons/dropbear.plist"];
    NSArray<NSString *> *progArgs = dropbearPrefs[@"ProgramArguments"];
    if (progArgs.count == 7) {
        // it's fine
        return;
    }
    
    // Uses: https://github.com/ipadkid358/DropbearSwitch
    [FSSwitchPanel.sharedPanel setState:FSSwitchStateOff forSwitchIdentifier:@"com.julioverne.dropbearswitch"];
}

// load is called automatically on load
+ (void)load {
    // make sure everything gets fully loaded first
    dispatch_async(dispatch_get_main_queue(), ^{
        [BJServer.sharedInstance start];
    });
}

@end
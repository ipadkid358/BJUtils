#import "BJWeatherInfo.h"
#import "BJLocation.h"
#import "BJSBAlertItem.h"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end


@implementation BJWeatherInfo {
    BJLocation *locationInstance;
    NSString *apiKey;
    BOOL presenting;
}

- (instancetype)init {
    if (self = [super init]) {
        locationInstance = BJLocation.new;
        // because I didn't want to expose my API key, it's hardcoded in a plist
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ipadkid.bjutils"];
        apiKey = [userDefaults stringForKey:@"BJWApiKey"];
    }
    
    return self;
}

- (NSString *)parseKey:(NSString *)key info:(NSDictionary *)info {
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *source = info[key];
    
    // don't want any ten digit deciamls
    id metric = source[@"Metric"][@"Value"];
    if ([metric isKindOfClass:NSNumber.class]) {
        float value = [metric floatValue];
        metric = [NSString stringWithFormat:@"%.1f", value];
    }
    
    id imperial = source[@"Imperial"][@"Value"];
    if ([imperial isKindOfClass:NSNumber.class]) {
        float value = [imperial floatValue];
        imperial = [NSString stringWithFormat:@"%.1f", value];
    }
    
    return [NSString stringWithFormat:@"%@ %@  |  %@ %@", metric, source[@"Metric"][@"Unit"], imperial, source[@"Imperial"][@"Unit"]];
}

- (NSString *)parseAccuWeather:(NSDictionary *)dict {
    NSDictionary *windInfo = dict[@"Wind"];
    return [NSString stringWithFormat:@"\n"
            "Temperature:\n%@\n\n"
            "Description:\n%@\n\n"
            "Wind Chill:\n%@\n\n"
            "Apparent:\n%@\n\n"
            "RealFeel:\n%@\n\n"
            "Shade RealFeel:\n%@\n\n"
            "Wind Speed:\n%@\n\n"
            "Wind Direction:\n%@\n\n"
            "Wind Gusts:\n%@",
            [self parseKey:@"Temperature" info:dict],
            dict[@"WeatherText"],
            [self parseKey:@"WindChillTemperature" info:dict],
            [self parseKey:@"ApparentTemperature" info:dict],
            [self parseKey:@"RealFeelTemperature" info:dict],
            [self parseKey:@"RealFeelTemperatureShade" info:dict],
            [self parseKey:@"Speed" info:windInfo],
            windInfo[@"Direction"][@"Localized"],
            [self parseKey:@"Speed" info:dict[@"WindGust"]]];
}

- (void)accuweatherInfo:(NSString *)locationKey {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.accuweather.com/currentconditions/v1/%@?apikey=%@&details=true", locationKey, apiKey]];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data || error) {
            return;
        }
        
        // there are a lot of keys, and a lot of opportunities to crash
        NSString *alertBody;
        NSString *alertImage;
        @try {
            NSArray *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSDictionary *informalInfo = parsed.firstObject;
            alertBody = [self parseAccuWeather:informalInfo];
            
            NSNumber *weatherCode = informalInfo[@"WeatherIcon"];
            alertImage = [@"/Library/Application Support/BJSupport/WeatherIcons" stringByAppendingPathComponent:weatherCode.stringValue];
        }
        @catch (NSException *exception) {
            alertBody = @"Failed to parse weather response";
        }
        
        BJSBAlertItem *sbAlert = [BJSBAlertItem new];
        sbAlert.alertTitle = @"Weather Info";
        sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.weather/Notif";
        sbAlert.alertMessage = alertBody;
        sbAlert.attachmentImagePath = alertImage;
        
        sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"More Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                // I can only hope this BundleID is a joke, official AccuWeather app
                [LSApplicationWorkspace.defaultWorkspace openApplicationWithBundleID:@"com.yourcompany.TestWithCustomTabs"];
            });
            [sbAlert dismiss];
        }], [UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [sbAlert dismiss];
        }]];
        [sbAlert present];
    }] resume];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    presenting = NO;
    [locationInstance showFetch:YES callBlock:^(CLLocation *location) {
        if (presenting) {
            return;
        }
        
        presenting = YES;
        CLLocationCoordinate2D coordinates = location.coordinate;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.accuweather.com/locations/v1/cities/geoposition/search.json?q=%f,%f&apikey=%@", coordinates.latitude, coordinates.longitude, apiKey]];
        [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!data || error) {
                return;
            }
            
            NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (!parsed) {
                return;
            }
            
            NSString *locationKey = parsed[@"Key"];
            if (locationKey) {
                [self accuweatherInfo:locationKey];
            }
        }] resume];
    }];
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.weather"];
}

@end

#import "BJWeatherInfo.h"
#import "../BJSharedInfo.h"
#import "../BJLocation.h"
#import "../BJSBAlertItem.h"

#define kAccuWeatherAPIBase "https://api.accuweather.com"

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end


@implementation BJWeatherInfo {
    BJLocation *_locationInstance;
    BOOL _presenting;
}

- (instancetype)init {
    if (self = [super init]) {
        _locationInstance = BJLocation.new;
    }
    
    return self;
}

- (NSString *)_parseAccuWeatherKey:(NSString *)key info:(NSDictionary *)info {
    // to used to parse source
    NSString *const metricKey = @"Metric";
    NSString *const imperialKey = @"Imperial";
    NSString *const unitKey = @"Unit";
    NSString *const valueKey = @"Value";
    
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *source = info[key];
    
    // don't want any ten digit deciamls
    id metric = source[metricKey][valueKey];
    if ([metric isKindOfClass:NSNumber.class]) {
        float value = [metric floatValue];
        metric = [NSString stringWithFormat:@"%.1f", value];
    }
    
    id imperial = source[imperialKey][valueKey];
    if ([imperial isKindOfClass:NSNumber.class]) {
        float value = [imperial floatValue];
        imperial = [NSString stringWithFormat:@"%.1f", value];
    }
    
    return [NSString stringWithFormat:@"%@ %@  |  %@ %@", metric, source[metricKey][unitKey], imperial, source[imperialKey][unitKey]];
}

- (NSString *)parseAccuWeather:(NSDictionary *)dict {
    if (!dict) {
        return NULL;
    }
    
    NSDictionary *windInfo = dict[@"Wind"];
    if (!windInfo) {
        return NULL;
    }
    
    NSDictionary *windDirection = windInfo[@"Direction"];
    if (!windDirection) {
        return NULL;
    }
    // key explanations can be found in the REST API docs below
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
            [self _parseAccuWeatherKey:@"Temperature" info:dict],
            dict[@"WeatherText"],
            [self _parseAccuWeatherKey:@"WindChillTemperature" info:dict],
            [self _parseAccuWeatherKey:@"ApparentTemperature" info:dict],
            [self _parseAccuWeatherKey:@"RealFeelTemperature" info:dict],
            [self _parseAccuWeatherKey:@"RealFeelTemperatureShade" info:dict],
            [self _parseAccuWeatherKey:@"Speed" info:windInfo],
            windDirection[@"Localized"],
            [self _parseAccuWeatherKey:@"Speed" info:dict[@"WindGust"]]];
}

- (void)accuweatherInfo:(NSString *)locationKey {
    // REST API: https://developer.accuweather.com/accuweather-current-conditions-api/apis/get/currentconditions/v1/%7BlocationKey%7D
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@kAccuWeatherAPIBase "/currentconditions/v1/%@?details=true&apikey=" kAccuWeatherAPIKey, locationKey]];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data || error) {
            return;
        }
        
        NSArray *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSDictionary *informalInfo = parsed.firstObject;
        NSNumber *weatherCode = informalInfo[@"WeatherIcon"];
        
        BJSBAlertItem *sbAlert = [BJSBAlertItem new];
        sbAlert.alertTitle = @"Weather Info";
        sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.weather/Notif";
        sbAlert.alertMessage = [self parseAccuWeather:informalInfo] ?: @"Failed to parse weather response";
        sbAlert.attachmentImagePath = [@"/Library/Application Support/BJSupport/WeatherIcons" stringByAppendingPathComponent:weatherCode.stringValue];
        
        sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"More Info" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            // calling -openApplicationWithBundleID: from the main thread results in long open times
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                // I can only hope this BundleID is a joke, official AccuWeather app
                [LSApplicationWorkspace.defaultWorkspace openApplicationWithBundleID:@"com.yourcompany.TestWithCustomTabs"];
            });
            
            [sbAlert dismiss];
        }], [UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:NULL]];
        [sbAlert present];
    }] resume];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    _presenting = NO;
    [_locationInstance showFetch:YES callBlock:^(CLLocation *location) {
        if (_presenting) {
            return;
        }
        
        _presenting = YES;
        CLLocationCoordinate2D coordinates = location.coordinate;
        // REST API: https://developer.accuweather.com/accuweather-locations-api/apis/get/locations/v1/cities/geoposition/search
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@kAccuWeatherAPIBase "/locations/v1/cities/geoposition/search.json?q=%f,%f&apikey=" kAccuWeatherAPIKey, coordinates.latitude, coordinates.longitude]];
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

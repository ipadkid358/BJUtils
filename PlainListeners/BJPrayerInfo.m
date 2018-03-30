#import "BJPrayerInfo.h"
#import "../BJLocation.h"
#import "../BJSBAlertItem.h"

@implementation BJPrayerInfo {
    BJLocation *_locationInstance;
    BOOL _presenting;
}

- (instancetype)init {
    if (self = [super init]) {
        _locationInstance = BJLocation.new;
    }
    
    return self;
}

- (NSString *)messageForTimings:(NSDictionary *)timings {
    return [NSString stringWithFormat:@""
            @"\nFajr start: %@"
            @"\nFajr end:   %@"
            @"\nDhuhr:      %@"
            @"\nAsr:        %@"
            @"\nMaghrib:    %@"
            @"\nIsha:       %@",
            timings[@"Fajr"], timings[@"Sunrise"], timings[@"Dhuhr"], timings[@"Asr"], timings[@"Maghrib"], timings[@"Isha"]];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    _presenting = NO;
    [_locationInstance showFetch:YES callBlock:^(CLLocation *location) {
        if (_presenting) {
            return;
        }
        
        _presenting = YES;
        CLLocationCoordinate2D coordinates = location.coordinate;
        // REST API: https://aladhan.com/prayer-times-api#GetTimings
        NSString *getStr = [NSString stringWithFormat:@"https://api.aladhan.com/timings/0?method=2&latitude=%f&longitude=%f", coordinates.latitude, coordinates.longitude];
        [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:getStr] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!data) {
                return;
            }
            
            NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (!parsed) {
                return;
            }
            
            NSDictionary<NSString *, NSDictionary *> *coreData = parsed[@"data"];
            if (!coreData) {
                return;
            }
            
            NSDictionary<NSString *, NSString *> *timings = coreData[@"timings"];
            if (!timings) {
                return;
            }
            
            BJSBAlertItem *sbAlert = [BJSBAlertItem new];
            NSDictionary<NSString *, id> *alertAttribs = @{@"NSFont":[UIFont fontWithName:@"Courier" size:14]};
            
            sbAlert.alertTitle = @"Prayer Info";
            sbAlert.alertAttributedMessage = [[NSAttributedString alloc] initWithString:[self messageForTimings:timings] attributes:alertAttribs];
            sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:NULL]];
            sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.prayer/Notif";
            [sbAlert present];
        }] resume];
    }];
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.prayer"];
}

@end

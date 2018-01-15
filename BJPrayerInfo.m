#import "BJPrayerInfo.h"
#import "BJLocation.h"
#import "BJSBAlertItem.h"

@implementation BJPrayerInfo {
    BJLocation *locationInstance;
    BOOL presenting;
}

- (instancetype)init {
    if (self = [super init]) {
        locationInstance = BJLocation.new;
    }
    
    return self;
}

- (NSString *)messageForTimings:(NSDictionary *)timings {
    NSArray<NSString *> *keys = @[@"Fajr start:", @"Fajr end:", @"Dhuhr:", @"Asr:", @"Maghrib:", @"Isha:"];
    NSArray<NSString *> *values = @[timings[@"Fajr"], timings[@"Sunrise"], timings[@"Dhuhr"], timings[@"Asr"], timings[@"Maghrib"], timings[@"Isha"]];
    NSUInteger maxLen = 0;
    for (int i = 0; i < 6; i++) {
        maxLen = MAX(maxLen, [keys[i] length]);
    }
    
    NSMutableString *str = [NSMutableString new];
    for (int i = 0; i < 6; i++) {
        [str appendFormat:@"\n%@ %@", [keys[i] stringByPaddingToLength:maxLen withString:@" " startingAtIndex:0], values[i]];
    }
    
    return str;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    presenting = NO;
    [locationInstance showFetch:YES callBlock:^(CLLocation *location) {
        if (presenting) {
            return;
        }
        
        presenting = YES;
        CLLocationCoordinate2D coordinates = location.coordinate;
        NSString *getStr = [NSString stringWithFormat:@"https://api.aladhan.com/timings/0?method=2&latitude=%f&longitude=%f", coordinates.latitude, coordinates.longitude];
        [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:getStr] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!data || error) {
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
            UIFont *font = [UIFont fontWithName:@"Courier" size:14];
            
            sbAlert.alertTitle = @"Prayer Info";
            sbAlert.alertAttributedMessage = [[NSAttributedString alloc] initWithString:[self messageForTimings:timings] attributes:@{@"NSFont":font}];
            sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [sbAlert dismiss];
            }]];
            sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.prayer/Notif";
            [sbAlert present];
        }] resume];
    }];
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.prayer"];
}

@end

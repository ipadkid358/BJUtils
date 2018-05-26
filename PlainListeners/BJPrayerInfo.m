#import "BJPrayerInfo.h"
#import "../MainUtils/BJLocation.h"
#import "../MainUtils/BJSBAlertItem.h"

// MARK: Degree trigonometric functions
#define r2d(r) ((r)*180.0)/M_PI
#define d2r(d) ((d)*M_PI)/180.0

#define dsin(v) sin(d2r(v))
#define dcos(v) cos(d2r(v))
#define dtan(v) tan(d2r(v))

#define darcsin(v) r2d(asin(v))
#define darccos(v) r2d(acos(v))
#define darctan(v) r2d(atan(v))

#define darccot(v) r2d(atan(1/(v)))
#define darctan2(v, m) r2d(atan2(v, m))

// MARK: Fast number formatting
#define patchDegreeAngle(v) ((v)-360.0*(floor((v)/360.0)))
#define patchTimeHour(v) ((v)-24.0*floor((v)/24.0))


@implementation BJPrayerInfo

/// Calculate the current julian date
static NSTimeInterval get_julian_date() {
    const NSTimeInterval secsPerDay = 60 * 60 * 24;
    const NSTimeInterval julian_epoch = 2440588;
    
    double days = floor(NSDate.date.timeIntervalSince1970/secsPerDay);
    double jd = julian_epoch + days - 0.5; // 0.5 offsets rounding errors
    
    return jd;
}

/// Given a multiplier, calculate the lenght of a shadow at a latitude and sun declination
static double shadow_length_calculation(double length, double lat, double declination) {
    double top = -dsin(length)-dsin(lat)*dsin(declination);
    double bot = dcos(lat)*dcos(declination);
    double calc = darccos(top/bot);
    return calc/15;
}

/// Calculate Asr prayer time under ISNA ruling for latitude and sun declination
static double calculate_asr_prayer(double lat, double declination) {
    double a = -darccot(1 + dtan(ABS(lat-declination)));
    double t = darccos((-dsin(a)- dsin(declination)* dsin(lat))/ (dcos(declination) * dcos(lat)));
    return t/15;
}

// http://aa.usno.navy.mil/faq/docs/SunApprox.php
/// Calculation the sun declination and equation of time using the current julian date (calculated internally)
static void get_sun_declination_eqT(double *declination, double *eqT) {
    double jd = get_julian_date();
    
    const double D = jd - 2451545;
    
    double g = patchDegreeAngle(357.529 + 0.98560028 * D);
    double q = patchDegreeAngle(280.459 + 0.98564736 * D);
    double L = patchDegreeAngle(q + 1.915 * dsin(g) + 0.020 * dsin(2*g));
    
    double e = 23.439 - 0.00000036 * D;
    *declination = darcsin(dsin(e) * dsin(L));
    
    double RA = darctan2(dcos(e) * dsin(L), dcos(L))/15;
    *eqT = q/15 - patchTimeHour(RA);
}

/// Convert timing representations to human readable, 12 hour time format (am-pm suffix not included)
static NSString *create_float_time12(double time) {
    if (isnan(time)) {
        return NULL;
    }
    
    time = patchTimeHour(time + 1/120.0);
    double hours = floor(time);
    double minutes = floor((time - hours) * 60);
    
    hours += 11;
    int hrs = (int)hours % 12;
    hrs += 1;
    
    return [NSString stringWithFormat:@"% 2d:%02.0f", hrs, minutes];
}

// in accordance to http://praytimes.org/calculation under ISNA rulings
/// return a formatted string of the 5 prayer times and sunrise using latitude, longitude, and altitude (pass 0 for alt if unknown)
/// under the ISNA rulings of calculation methods
static NSString *calculatePrayerTimesUsingLatLongAlt(CLLocationDegrees lat, CLLocationDegrees lng, CLLocationDistance alt) {
    const double fajr_angle = 15;
    const double isha_angle = 15;
    
    double declination, eqT;
    get_sun_declination_eqT(&declination, &eqT);
    
    double dhuhr_prayer = 12 - eqT;
    
    const double altitude_offset = shadow_length_calculation(0.833 + 0.0347 * sqrt(alt), lat, declination);
    
    double sunrise_time = dhuhr_prayer - altitude_offset; // end of fajr
    double sunset_time = dhuhr_prayer + altitude_offset; // maghrib
    
    double fajr_prayer = dhuhr_prayer - shadow_length_calculation(fajr_angle, lat, declination);
    double isha_prayer = dhuhr_prayer + shadow_length_calculation(isha_angle, lat, declination);
    
    double asr_prayer = dhuhr_prayer + calculate_asr_prayer(lat, declination);
    
    double timezone_offset = NSTimeZone.localTimeZone.secondsFromGMT/3600.0 - lng/15.0;
    
    fajr_prayer  += timezone_offset;
    sunrise_time += timezone_offset;
    dhuhr_prayer += timezone_offset;
    asr_prayer   += timezone_offset;
    sunset_time  += timezone_offset;
    isha_prayer  += timezone_offset;
    
    return [NSString stringWithFormat:@""
            @"\nFajr start: %@"
            @"\nFajr end:   %@"
            @"\nDhuhr:      %@"
            @"\nAsr:        %@"
            @"\nMaghrib:    %@"
            @"\nIsha:       %@",
            create_float_time12(fajr_prayer),
            create_float_time12(sunrise_time),
            create_float_time12(dhuhr_prayer),
            create_float_time12(asr_prayer),
            create_float_time12(sunset_time),
            create_float_time12(isha_prayer)];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    CLLocation *location = BJLocation.sharedInstance.latestLocation;
    CLLocationCoordinate2D coordinates = location.coordinate;
    NSString *formattedMessage = calculatePrayerTimesUsingLatLongAlt(coordinates.latitude, coordinates.longitude, location.altitude);
    
    BJSBAlertItem *sbAlert = [BJSBAlertItem new];
    NSDictionary<NSString *, id> *alertAttribs = @{ NSFontAttributeName : [UIFont fontWithName:@"Courier" size:14] };
    sbAlert.alertTitle = @"Prayer Info";
    sbAlert.alertAttributedMessage = [[NSAttributedString alloc] initWithString:formattedMessage attributes:alertAttribs];
    sbAlert.alertActions = @[[UIAlertAction actionWithTitle:@"Thanks" style:UIAlertActionStyleCancel handler:NULL]];
    sbAlert.iconImagePath = @"/Library/Activator/Listeners/com.ipadkid.prayer/Notif";
    [sbAlert present];
}

+ (void)load {
    [LASharedActivator registerListener:self.new forName:@"com.ipadkid.prayer"];
}

@end

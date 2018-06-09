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

#define formatPrayerTime(t) [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:((dayReferenceStart) + (secsPerHour*(t)))]]

@implementation BJPrayerInfo

/// Calculate the current julian date
static NSTimeInterval calculateJulianDate() {
    const NSTimeInterval secsPerDay = 60 * 60 * 24;
    const NSTimeInterval julianEpoch = 2440588;
    const NSTimeInterval nowTime = NSDate.date.timeIntervalSince1970;
    
    double days = floor(nowTime/secsPerDay);
    
    return julianEpoch + days - 0.5; // 0.5 offsets rounding errors;
}

/// Given a multiplier, calculate the lenght of a shadow at a latitude and sun declination
static double calculateShadowLength(double angle, double lat, double declination) {
    return darccos((-dsin(angle) - dsin(lat)*dsin(declination)) / (dcos(lat)*dcos(declination)))/15;
}

/// Calculate Asr prayer time under ISNA ruling for latitude and sun declination
static double calculateAsrOffset(double lat, double declination) {
    const unsigned calcOffset = 1;
    return darccos((-dsin(-darccot(calcOffset + dtan(ABS(lat-declination)))) - dsin(declination)*dsin(lat)) / (dcos(declination)*dcos(lat)))/15;
}

// http://aa.usno.navy.mil/faq/docs/SunApprox.php
/// Calculation the sun declination and equation of time using the current julian date (calculated internally)
static void calculateDeclinationEquationOfTime(double *declination, double *eqT) {
    const double julianDate = calculateJulianDate();
    
    const double julianReferenceDate = julianDate - 2451545;
    
    double sunAnomly = patchDegreeAngle(357.529 + 0.98560028 * julianReferenceDate);
    double sunLng = patchDegreeAngle(280.459 + 0.98564736 * julianReferenceDate);
    double eclipticLng = patchDegreeAngle(sunLng + 1.915 * dsin(sunAnomly) + 0.020 * dsin(2*sunAnomly));
    
    double e = 23.439 - 0.00000036 * julianReferenceDate;
    *declination = darcsin(dsin(e) * dsin(eclipticLng));
    
    double rightAscension = darctan2(dcos(e) * dsin(eclipticLng), dcos(eclipticLng))/15;
    *eqT = sunLng/15 - rightAscension;
}

// in accordance to http://praytimes.org/calculation under ISNA rulings
/// return a formatted string of the 5 prayer times and sunrise using latitude, longitude, and altitude (pass 0 for alt if unknown)
/// under the ISNA rulings of calculation methods
static NSString *calculatePrayerTimesUsingLatLongAlt(CLLocationDegrees lat, CLLocationDegrees lng, CLLocationDistance alt) {
    const double fajr_angle = 15;
    const double isha_angle = 15;
    
    double declination, eqT;
    calculateDeclinationEquationOfTime(&declination, &eqT);
    
    NSTimeInterval dhuhrTime = 12 - eqT;
    
    const NSTimeInterval altitudeOffset = calculateShadowLength(0.833 + 0.0347 * sqrt(alt), lat, declination);
    
    NSTimeInterval sunriseTime = dhuhrTime - altitudeOffset; // end of fajr
    NSTimeInterval sunsetTime = dhuhrTime + altitudeOffset; // maghrib
    
    NSTimeInterval fajrTime = dhuhrTime - calculateShadowLength(fajr_angle, lat, declination);
    NSTimeInterval ishaTime = dhuhrTime + calculateShadowLength(isha_angle, lat, declination);
    
    NSTimeInterval asrTime = dhuhrTime + calculateAsrOffset(lat, declination);
    
    NSInteger timezone = NSTimeZone.localTimeZone.secondsFromGMT;
    const double secsPerHour = 60 * 60;
    NSTimeInterval timezoneOffset = timezone/secsPerHour - lng/15.0 + 1/120.0;
    
    fajrTime    += timezoneOffset;
    sunriseTime += timezoneOffset;
    dhuhrTime   += timezoneOffset;
    asrTime     += timezoneOffset;
    sunsetTime  += timezoneOffset;
    ishaTime    += timezoneOffset;
    
    const double secsPerDay = secsPerHour * 24;
    double daysSinceRegerenceDate = floor(NSDate.date.timeIntervalSinceReferenceDate/secsPerDay);
    NSTimeInterval dayReferenceStart = daysSinceRegerenceDate*secsPerDay - timezone;
    
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.timeStyle = NSDateFormatterShortStyle;
    
    return [NSString stringWithFormat:@""
            @"\nFajr start: %@"
            @"\nFajr end:   %@"
            @"\nDhuhr:      %@"
            @"\nAsr:        %@"
            @"\nMaghrib:    %@"
            @"\nIsha:       %@",
            formatPrayerTime(fajrTime),
            formatPrayerTime(sunriseTime),
            formatPrayerTime(dhuhrTime),
            formatPrayerTime(asrTime),
            formatPrayerTime(sunsetTime),
            formatPrayerTime(ishaTime)];
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

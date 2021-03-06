//
//  OAAlarmInfo.m
//  OsmAnd
//
//  Created by Alexey Kulish on 30/06/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAAlarmInfo.h"
#import "Localization.h"

@implementation OAAlarmInfo

- (instancetype)initWithType:(EOAAlarmInfoType)type locationIndex:(int)locationIndex
{
    self = [super init];
    if (self)
    {
        _type = type;
        _locationIndex = locationIndex;
    }
    return self;
}

+ (OAAlarmInfo *) createSpeedLimit:(int)speed coordinate:(CLLocationCoordinate2D)coordinate
{
    OAAlarmInfo *info = [[OAAlarmInfo alloc] initWithType:AIT_SPEED_LIMIT locationIndex:0];
    info.coordinate = CLLocationCoordinate2DMake(coordinate.latitude, coordinate.longitude);
    info.intValue = speed;
    return info;
}

+ (OAAlarmInfo *) createAlarmInfo:(RouteTypeRule&)ruleType locInd:(int)locInd coordinate:(CLLocationCoordinate2D)coordinate
{
    OAAlarmInfo *alarmInfo = nil;
    if ("highway" == ruleType.getTag())
    {
        if ("speed_camera" == ruleType.getValue())
        {
            alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_SPEED_CAMERA locationIndex:locInd];
        }
        else if ("stop" == ruleType.getValue())
        {
            alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_STOP locationIndex:locInd];
        }
    }
    else if ("barrier" == ruleType.getTag())
    {
        if ("toll_booth" == ruleType.getValue())
        {
            alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_TOLL_BOOTH locationIndex:locInd];
        }
        else if ("border_control" == ruleType.getValue())
        {
            alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_BORDER_CONTROL locationIndex:locInd];
        }
    }
    else if("traffic_calming" == ruleType.getTag())
    {
        alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_TRAFFIC_CALMING locationIndex:locInd];
    }
    else if ("hazard" == (ruleType.getTag()))
    {
        alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_HAZARD locationIndex:locInd];
    }
    else if ("railway" == (ruleType.getTag()) && "level_crossing" == ruleType.getValue())
    {
        alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_RAILWAY locationIndex:locInd];
    }
    else if ("crossing" == (ruleType.getTag()) && "uncontrolled" == ruleType.getValue())
    {
        alarmInfo = [[OAAlarmInfo alloc] initWithType:AIT_PEDESTRIAN locationIndex:locInd];
    }
    if (alarmInfo)
    {
        alarmInfo.coordinate = coordinate;
    }
    return alarmInfo;
}

- (int) updateDistanceAndGetPriority:(float)time distance:(float)distance
{
    if (distance > 1500)
        return INT_MAX;
    
    // 1 level of priorities
    if (time < 6 || distance < 75 || self.type == AIT_SPEED_LIMIT)
        return [self.class getPriority:self.type];

    if (self.type == AIT_SPEED_CAMERA && (time < 15 || distance < 150))
        return [self.class getPriority:self.type];

    // 2nd level
    if (time < 7 || distance < 100)
        return [self.class getPriority:self.type] + [self.class getPriority:AIT_MAXIMUM];
    
    return INT_MAX;
}

+ (int) getPriority:(EOAAlarmInfoType)type
{
    return (int)type + 1;
}

+ (NSString* ) getVisualName:(EOAAlarmInfoType)type
{
    switch (type) {
        case AIT_SPEED_CAMERA:
            return OALocalizedString(@"traffic_warning_speed_camera");
        case AIT_SPEED_LIMIT:
            return OALocalizedString(@"traffic_warning_speed_limit");
        case AIT_BORDER_CONTROL:
            return OALocalizedString(@"traffic_warning_border_control");
        case AIT_RAILWAY:
            return OALocalizedString(@"traffic_warning_railways");
        case AIT_TRAFFIC_CALMING:
            return OALocalizedString(@"traffic_warning_calming");
        case AIT_TOLL_BOOTH:
            return OALocalizedString(@"traffic_warning_payment");
        case AIT_STOP:
            return OALocalizedString(@"traffic_warning_stop");
        case AIT_PEDESTRIAN:
            return OALocalizedString(@"traffic_warning_pedestrian");
        case AIT_HAZARD:
            return OALocalizedString(@"traffic_warning_hazard");
        case AIT_MAXIMUM:
            return OALocalizedString(@"traffic_warning");
            
        default:
            break;
    }
}

@end

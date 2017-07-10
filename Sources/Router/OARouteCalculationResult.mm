//
//  OARouteCalculationResult.m
//  OsmAnd
//
//  Created by Alexey Kulish on 30/06/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OARouteCalculationResult.h"
#import "OAAlarmInfo.h"
#import "OARouteDirectionInfo.h"
#import "OALocationPoint.h"
#import "OAMapStyleSettings.h"
#import "OARouteCalculationParams.h"
#import "Localization.h"
#import "OALocationServices.h"
#import "OAAppSettings.h"
#import "OARoutingHelper.h"
#import "OAUtilities.h"

#include <CommonCollections.h>
#include <commonOsmAndCore.h>
#include <routeSegmentResult.h>

#define distanceClosestToIntermediate 400.0

@implementation OARouteCalculationResult
{
    // could not be null and immodifiable!
    NSMutableArray<CLLocation *> *_locations;
    NSMutableArray<OARouteDirectionInfo *> *_directions;
    NSMutableArray<OAAlarmInfo *> *_alarmInfo;
    std::vector<std::shared_ptr<RouteSegmentResult>> _segments;
    NSString *_errorMessage;
    NSMutableArray<NSNumber *> *_listDistance;
    NSMutableArray<NSNumber *> *_intermediatePoints;
    float _routingTime;
    
    int _cacheCurrentTextDirectionInfo;
    NSMutableArray<OARouteDirectionInfo *> *_cacheAgreggatedDirections;
    NSMutableArray<id<OALocationPoint>> *_locationPoints;
    
    // Note always currentRoute > get(currentDirectionInfo).routeOffset,
    //         but currentRoute <= get(currentDirectionInfo+1).routeOffset
    int _currentDirectionInfo;
    int _currentRoute;
    int _nextIntermediate;
    int _currentWaypointGPX;
    int _lastWaypointGPX;
    OAMapVariantType _appMode;
}


- (instancetype) init
{
    self = [super init];
    if (self)
    {
        _cacheCurrentTextDirectionInfo = -1;
        _locationPoints = [NSMutableArray array];

        _currentDirectionInfo = 0;
        _currentRoute = 0;
        _nextIntermediate = 0;
        _currentWaypointGPX = 0;
        _lastWaypointGPX = 0;
    }
    return self;
}

- (instancetype) initWithErrorMessage:(NSString *)errorMessage
{
    self = [[OARouteCalculationResult alloc] init];
    if (self)
    {
        _errorMessage = errorMessage;
        _routingTime = 0;
        _intermediatePoints = [NSMutableArray array];
        _locations = [NSMutableArray array];
        _listDistance = [NSMutableArray array];
        _directions = [NSMutableArray array];
        _alarmInfo = [NSMutableArray array];
    }
    return self;
}

/**
 * PREPARATION
 * Check points for duplicates (it is very bad for routing) - cloudmade could return it
 */
+ (void) checkForDuplicatePoints:(NSMutableArray<CLLocation *> *)locations directions:(NSMutableArray<OARouteDirectionInfo *> *)directions
{
    NSMutableIndexSet *del = [NSMutableIndexSet indexSet];
    for (int i = 0; i < locations.count - 1;)
    {
        if ([locations[i] distanceFromLocation:locations[i + 1]] == 0)
        {
            [del addIndex:i];
            if (directions) {
                for (OARouteDirectionInfo *info in directions)
                {
                    if (info.routePointOffset > i) {
                        info.routePointOffset--;
                    }
                }
            }
        } else {
            i++;
        }
    }
    [locations removeObjectsAtIndexes:del];
}

/**
 * PREPARATION
 * Remove unnecessary go straight from CloudMade.
 * Remove also last direction because it will be added after.
 */
- (void) removeUnnecessaryGoAhead:(NSMutableArray<OARouteDirectionInfo *> *)directions
{
    NSMutableIndexSet *del = [NSMutableIndexSet indexSet];
    if (directions && directions.count > 1)
    {
        for (int i = 1; i < directions.count;)
        {
            OARouteDirectionInfo *r = directions[i];
            if (r.turnType->getValue() == TurnType::C)
            {
                OARouteDirectionInfo *prev = directions[i - 1];
                prev.averageSpeed = ((prev.distance + r.distance) / (prev.distance / prev.averageSpeed + r.distance / r.averageSpeed));
                prev.distance = prev.distance + r.distance;
                [del addIndex:i];
            } else {
                i++;
            }
        }
    }
    [directions removeObjectsAtIndexes:del];
}

+ (void) addMissingTurnsToRoute:(NSArray<CLLocation *> *)locations originalDirections:(NSMutableArray<OARouteDirectionInfo *> *)originalDirections start:(CLLocation *)start end:(CLLocation *)end mode:(OAMapVariantType)mode leftSide:(BOOL)leftSide
{
    if (locations.count == 0)
        return;
    
    // speed m/s
    float speed = [OAMapStyleSettings getDefaultSpeedByVariantType:mode];
    int minDistanceForTurn = [OAMapStyleSettings getMinDistanceForTurnByVariantType:mode];
    NSMutableArray<OARouteDirectionInfo *> *computeDirections = [NSMutableArray array];
    
    NSMutableArray<NSNumber *> *listDistance = [NSMutableArray arrayWithCapacity:locations.count];
    listDistance[locations.count - 1] = @(0);
    for (int i = (int)locations.count - 1; i > 0; i--)
    {
        listDistance[i - 1] = [NSNumber numberWithInt:round([locations[i - 1] distanceFromLocation:locations[i]])];
        listDistance[i - 1] = [NSNumber numberWithInt:[listDistance[i - 1] intValue] + [listDistance[i] intValue]];
    }
    
    int previousLocation = 0;
    int prevBearingLocation = 0;
    OARouteDirectionInfo *previousInfo = [[OARouteDirectionInfo alloc] initWithAverageSpeed:speed turnType:TurnType::ptrStraight()];
    previousInfo.routePointOffset = 0;
    previousInfo.descriptionRoute = OALocalizedString(@"route_head");
    [computeDirections addObject:previousInfo];
    
    int distForTurn = 0;
    double previousBearing = 0;
    int startTurnPoint = 0;
    
    for (int i = 1; i < locations.count - 1; i++)
    {
        CLLocation *next = locations[i + 1];
        CLLocation *current = locations[i];
        double bearing = [current bearingTo:next];
        // try to get close to current location if possible
        while (prevBearingLocation < i - 1)
        {
            if ([locations[prevBearingLocation + 1] distanceFromLocation:current] > 70) {
                prevBearingLocation ++;
            } else {
                break;
            }
        }
        
        if (distForTurn == 0)
        {
            // measure only after turn
            previousBearing = [locations[prevBearingLocation] bearingTo:current];
            startTurnPoint = i;
        }
        
        std::shared_ptr<TurnType> type = nullptr;
        NSString *description = nil;
        float delta = previousBearing - bearing;
        while (delta < 0) {
            delta += 360;
        }
        while (delta > 360) {
            delta -= 360;
        }
        
        distForTurn += [locations[i] distanceFromLocation:locations[i + 1]];
        if (i < locations.count - 1 &&  distForTurn < minDistanceForTurn)
        {
            // For very smooth turn we try to accumulate whole distance
            // simply skip that turn needed for situation
            // 1) if you are going to have U-turn - not 2 left turns
            // 2) if there is a small gap between roads (turn right and after 4m next turn left) - so the direction head
            continue;
        }
        
        if (delta > 45 && delta < 315)
        {
            if (delta < 60)
            {
                type = TurnType::ptrValueOf(TurnType::TSLL, leftSide);
                description = OALocalizedString(@"route_tsll");
            }
            else if (delta < 120)
            {
                type = TurnType::ptrValueOf(TurnType::TL, leftSide);
                description = OALocalizedString(@"route_tl");
            }
            else if (delta < 150)
            {
                type = TurnType::ptrValueOf(TurnType::TSHL, leftSide);
                description = OALocalizedString(@"route_tshl");
            }
            else if (delta < 210)
            {
                type = TurnType::ptrValueOf(TurnType::TU, leftSide);
                description = OALocalizedString(@"route_tu");
            }
            else if (delta < 240)
            {
                description = OALocalizedString(@"route_tshr");
                type = TurnType::ptrValueOf(TurnType::TSHR, leftSide);
            }
            else if (delta < 300)
            {
                description = OALocalizedString(@"route_tr");
                type = TurnType::ptrValueOf(TurnType::TR, leftSide);
            }
            else
            {
                description = OALocalizedString(@"route_tslr");
                type = TurnType::ptrValueOf(TurnType::TSLR, leftSide);
            }
            
            // calculate for previousRoute
            previousInfo.distance = [listDistance[previousLocation] intValue] - [listDistance[i] intValue];
            type->setTurnAngle(360 - delta);
            previousInfo = [[OARouteDirectionInfo alloc] initWithAverageSpeed:speed turnType:type];
            previousInfo.descriptionRoute = description;
            previousInfo.routePointOffset = startTurnPoint;
            [computeDirections addObject:previousInfo];
            previousLocation = startTurnPoint;
            prevBearingLocation = i; // for bearing using current location
        }
        // clear dist for turn
        distForTurn = 0;
    }
    
    previousInfo.distance = [listDistance[previousLocation] intValue];
    if (originalDirections.count == 0)
    {
        [originalDirections addObjectsFromArray:computeDirections];
    }
    else
    {
        int currentDirection = 0;
        // one more
        for (int i = 0; i <= originalDirections.count && currentDirection < computeDirections.count; i++)
        {
            while (currentDirection < computeDirections.count) {
                int distanceAfter = 0;
                if (i < originalDirections.count) {
                    OARouteDirectionInfo *resInfo = originalDirections[i];
                    int r1 = computeDirections[currentDirection].routePointOffset;
                    int r2 = resInfo.routePointOffset;
                    distanceAfter = [listDistance[resInfo.routePointOffset] intValue];
                    float dist = [locations[r1] distanceFromLocation:locations[r2]];
                    // take into account that move roundabout is special turn that could be very lengthy
                    if (dist < 100)
                    {
                        // the same turn duplicate
                        currentDirection++;
                        continue; // while cycle
                    }
                    else if (computeDirections[currentDirection].routePointOffset > resInfo.routePointOffset)
                    {
                        // check it at the next point
                        break;
                    }
                }
                
                // add turn because it was missed
                OARouteDirectionInfo *toAdd = computeDirections[currentDirection];
                
                if (i > 0) {
                    // update previous
                    OARouteDirectionInfo *previous = originalDirections[i - 1];
                    toAdd.averageSpeed = previous.averageSpeed;
                }
                toAdd.distance = [listDistance[toAdd.routePointOffset] intValue] - distanceAfter;
                if (i < originalDirections.count) {
                    [originalDirections insertObject:toAdd atIndex:i];
                } else {
                    [originalDirections addObject:toAdd];
                }
                i++;
                currentDirection++;
            }
        }
    }
    
    int sum = 0;
    for (int i = (int)originalDirections.count - 1; i >= 0; i--)
    {
        originalDirections[i].afterLeftTime = sum;
        sum += [originalDirections[i] getExpectedTime];
    }
}

/**
 * PREPARATION
 * If beginning is too far from start point, then introduce GO Ahead
 * @param end
 */
+ (void) introduceFirstPointAndLastPoint:(NSMutableArray<CLLocation *> *)locations directions:(NSMutableArray<OARouteDirectionInfo *> *)directions segs:(std::vector<std::shared_ptr<RouteSegmentResult>>&)segs start:(CLLocation *)start end:(CLLocation *)end
{
    if (locations.count > 0 && [locations[0] distanceFromLocation:start] > 50)
    {
        // add start point
        [locations insertObject:start atIndex:0];
        if (segs.size() > 0)
        {
            segs.insert(segs.begin(), segs[0]);
        }
        if (directions && directions.count > 0)
        {
            for (OARouteDirectionInfo *i in directions)
            {
                i.routePointOffset++;
            }
            OARouteDirectionInfo *info = [[OARouteDirectionInfo alloc] initWithAverageSpeed:directions[0].averageSpeed turnType:TurnType::ptrStraight()];
            info.routePointOffset = 0;
            // info.setDescriptionRoute(ctx.getString( R.string.route_head));//; //$NON-NLS-1$
            [directions insertObject:info atIndex:0];
        }
        [self.class checkForDuplicatePoints:locations directions:directions];
    }
    OARouteDirectionInfo *lastDirInf = directions.count > 0 ? directions[directions.count - 1] : nil;
    if ((!lastDirInf || lastDirInf.routePointOffset < locations.count - 1) && locations.count - 1 > 0)
    {
        int type = TurnType::C;
        CLLocation *prevLast = locations[locations.count - 2];
        double lastBearing = [prevLast bearingTo:locations[locations.count - 1]];
        double bearingToEnd = [prevLast bearingTo:end];
        double diff = degreesDiff(lastBearing, bearingToEnd);
        if(abs(diff) > 10)
            type = diff > 0 ? TurnType::KL : TurnType::KR;
        
        // Wrong AvgSpeed for the last turn can cause significantly wrong total travel time if calculated route ends on a GPX route segment (then last turn is where GPX is joined again)
        OARouteDirectionInfo *info = [[OARouteDirectionInfo alloc] initWithAverageSpeed:lastDirInf ? lastDirInf.averageSpeed : 1 turnType:TurnType::ptrValueOf(type, false)];
        info.distance = 0;
        info.afterLeftTime = 0;
        info.routePointOffset = (int)locations.count - 1;
        [directions addObject:info];
    }
}

/**
 * PREPARATION
 * At the end always update listDistance local vars and time
 */
+ (void) updateListDistanceTime:(NSMutableArray<NSNumber *> *)listDistance locations:(NSArray<CLLocation *> *)locations
{
    if (listDistance.count > 0)
    {
        listDistance[locations.count - 1] = @0;
        for (int i = (int)locations.count - 1; i > 0; i--)
        {
            listDistance[i - 1] = @((int) round([locations[i - 1] distanceFromLocation:locations[i]]));
            listDistance[i - 1] = @(listDistance[i - 1].intValue + listDistance[i].intValue);
        }
    }
}

/**
 * PREPARATION
 * At the end always update listDistance local vars and time
 */
+ (void) updateDirectionsTime:(NSMutableArray<OARouteDirectionInfo *> *)directions listDistance:(NSMutableArray<NSNumber *> *)listDistance
{
    int sum = 0;
    for (int i = (int)directions.count - 1; i >= 0; i--)
    {
        directions[i].afterLeftTime = sum;
        directions[i].distance = listDistance[directions[i].routePointOffset].intValue;
        if (i < directions.count - 1) {
            directions[i].distance -= listDistance[directions[i + 1].routePointOffset].intValue;
        }
        sum += [directions[i] getExpectedTime];
    }
}

+ (double) getDistanceToLocation:(NSArray<CLLocation *> *)locations p:(CLLocation *)p currentLocation:(int)currentLocation
{
    return [p distanceFromLocation:[[CLLocation alloc] initWithLatitude:locations[currentLocation].coordinate.latitude longitude:locations[currentLocation].coordinate.longitude]];
}

+ (void) calculateIntermediateIndexes:(NSArray<CLLocation *> *)locations intermediates:(NSArray<CLLocation *> *)intermediates localDirections:(NSMutableArray<OARouteDirectionInfo *> *)localDirections intermediatePoints:(NSMutableArray<NSNumber *> *)intermediatePoints
{
    if (intermediates && localDirections)
    {
        NSMutableArray<NSNumber *> *interLocations = [NSMutableArray arrayWithCapacity:intermediates.count];
        int currentIntermediate = 0;
        int currentLocation = 0;
        double distanceThreshold = 25;
        double prevDistance = distanceThreshold * 4;
        while((currentIntermediate < intermediates.count || prevDistance > distanceThreshold) && currentLocation < locations.count)
        {
            if (currentIntermediate < intermediates.count &&
                [self.class getDistanceToLocation:locations p:intermediates[currentIntermediate] currentLocation:currentLocation] < distanceClosestToIntermediate)
            {
                prevDistance = [self.class getDistanceToLocation:locations p:intermediates[currentIntermediate] currentLocation:currentLocation];
                interLocations[currentIntermediate] = @(currentLocation);
                currentIntermediate++;
            } else if (currentIntermediate > 0 && prevDistance > distanceThreshold && [self.class getDistanceToLocation:locations p:intermediates[currentIntermediate - 1] currentLocation:currentLocation] < prevDistance)
            {
                prevDistance = [self.class getDistanceToLocation:locations p:intermediates[currentIntermediate - 1] currentLocation:currentLocation];
                interLocations[currentIntermediate - 1] = @(currentLocation);
            }
            currentLocation ++;
        }
        int currentDirection = 0;
        currentIntermediate = 0;
        while (currentIntermediate < intermediates.count && currentDirection < localDirections.count)
        {
            int locationIndex = localDirections[currentDirection].routePointOffset;
            if (locationIndex >= interLocations[currentIntermediate].intValue)
            {
                // split directions
                if (locationIndex > interLocations[currentIntermediate].intValue && [self.class getDistanceToLocation:locations p:intermediates[currentIntermediate] currentLocation:locationIndex] > 50)
                {
                    OARouteDirectionInfo *toSplit = localDirections[currentDirection];
                    OARouteDirectionInfo *info = [[OARouteDirectionInfo alloc] initWithAverageSpeed:localDirections[currentDirection].averageSpeed turnType:TurnType::ptrStraight()];
                    info.ref = toSplit.ref;
                    info.streetName = toSplit.streetName;
                    info.destinationName = toSplit.destinationName;
                    info.routePointOffset = interLocations[currentIntermediate].intValue;
                    info.descriptionRoute = OALocalizedString(@"route_head");
                    [localDirections insertObject:info atIndex:currentDirection];
                }
                intermediatePoints[currentIntermediate] = @(currentDirection);
                currentIntermediate++;
            }
            currentDirection ++;
        }
    }
}

+ (void) attachAlarmInfo:(NSMutableArray<OAAlarmInfo *> *)alarms res:(std::shared_ptr<RouteSegmentResult>)res intId:(int)intId locInd:(int)locInd
{
    if (res->object->pointTypes.size() > intId) {
        const auto& pointTypes = res->object->pointTypes[intId];
        auto reg = res->object->region;
        for (int r = 0; r < pointTypes.size(); r++) {
            auto& typeRule = reg->quickGetEncodingRule(pointTypes[r]);
            auto x31 = res->object->pointsX[intId];
            auto y31 = res->object->pointsY[intId];
            CLLocation *loc = [[CLLocation alloc] initWithLatitude:get31LatitudeY(y31) longitude:get31LongitudeX(x31)];
            OAAlarmInfo *info = [OAAlarmInfo createAlarmInfo:typeRule locInd:locInd coordinate:loc.coordinate];
            if (info)
                [alarms addObject:info];
        }
    }
}

+ (NSString *) toString:(std::shared_ptr<TurnType>)type shortName:(BOOL)shortName
{
    if (type->isRoundAbout())
    {
        if (shortName) {
            return [NSString stringWithFormat:OALocalizedString(@"route_roundabout_short"), type->getExitOut()];
        } else {
            return [NSString stringWithFormat:OALocalizedString(@"route_roundabout"), type->getExitOut()];
        }
    } else if (type->getValue() == TurnType::C) {
        return OALocalizedString(@"route_head");
    } else if (type->getValue() == TurnType::TSLL) {
        return OALocalizedString(@"route_tsll");
    } else if (type->getValue() == TurnType::TL) {
        return OALocalizedString(@"route_tl");
    } else if (type->getValue() == TurnType::TSHL) {
        return OALocalizedString(@"route_tshl");
    } else if (type->getValue() == TurnType::TSLR) {
        return OALocalizedString(@"route_tslr");
    } else if (type->getValue() == TurnType::TR) {
        return OALocalizedString(@"route_tr");
    } else if (type->getValue() == TurnType::TSHR) {
        return OALocalizedString(@"route_tshr");
    } else if (type->getValue() == TurnType::TU) {
        return OALocalizedString(@"route_tu");
    } else if (type->getValue() == TurnType::TRU) {
        return OALocalizedString(@"route_tu");
    } else if (type->getValue() == TurnType::KL) {
        return OALocalizedString(@"route_kl");
    } else if (type->getValue() == TurnType::KR) {
        return OALocalizedString(@"route_kr");
    }
    return @"";
}

/**
 * PREPARATION
 */
+ (std::vector<std::shared_ptr<RouteSegmentResult>>) convertVectorResult:(NSMutableArray<OARouteDirectionInfo *> *)directions locations:(NSMutableArray<CLLocation *> *)locations list:(std::vector<std::shared_ptr<RouteSegmentResult>>&)list alarms:(NSMutableArray<OAAlarmInfo *> *)alarms
{
    float prevDirectionTime = 0;
    float prevDirectionDistance = 0;
    double lastHeight = RouteDataObject::HEIGHT_UNDEFINED;
    std::vector<std::shared_ptr<RouteSegmentResult>> segmentsToPopulate;
    for (int routeInd = 0; routeInd < list.size(); routeInd++)
    {
        auto s = list[routeInd];
        const auto& vls = s->object->calculateHeightArray();
        BOOL plus = s->getStartPointIndex() < s->getEndPointIndex();
        int i = s->getStartPointIndex();
        int prevLocationSize = (int)locations.count;
        while (true)
        {
            auto lat = get31LatitudeY(s->object->pointsY[i]);
            auto lon = get31LongitudeX(s->object->pointsX[i]);
            if (i == s->getEndPointIndex() && routeInd != list.size() - 1)
                break;
            
            NSNumber *alt = nil;
            if (i * 2 + 1 < vls.size())
            {
                float h = vls[2 * i + 1];
                alt = @(h);
                if (lastHeight == RouteDataObject::HEIGHT_UNDEFINED && locations.count > 0) {
                    
                    for (int i = 0; i < locations.count; i++)
                    {
                        CLLocation *l = locations[i];
                        if (l.verticalAccuracy < 0) {
                            locations[i] = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(l.coordinate.latitude, l.coordinate.longitude) altitude:h horizontalAccuracy:0 verticalAccuracy:0 course:l.course speed:l.speed timestamp:l.timestamp];
                        }
                    }
                }
                lastHeight = h;
            }
            if (alt)
                [locations addObject:[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon) altitude:alt.doubleValue horizontalAccuracy:0 verticalAccuracy:0 timestamp:[NSDate date]]];
            else
                [locations addObject:[[CLLocation alloc] initWithLatitude:lat longitude:lon]];

            [self.class attachAlarmInfo:alarms res:s intId:i locInd:(int)locations.count];
            segmentsToPopulate.push_back(s);
            if (i == s->getEndPointIndex() )
                break;
            
            if (plus)
                i++;
            else
                i--;
        }
        auto turn = s->turnType;
        
        if (turn)
        {
            OARouteDirectionInfo *info = [[OARouteDirectionInfo alloc] initWithAverageSpeed:s->segmentSpeed turnType:turn];
            if (routeInd  < list.size())
            {
                int lind = routeInd;
                if (turn->isRoundAbout())
                {
                    int roundAboutEnd = prevLocationSize ;
                    // take next name for roundabout (not roundabout name)
                    while (lind < list.size() - 1 && list[lind]->object->roundabout())
                    {
                        roundAboutEnd += abs(list[lind]->getEndPointIndex() - list[lind]->getStartPointIndex());
                        lind++;
                    }
                    // Consider roundabout end.
                    info.routeEndPointOffset = roundAboutEnd;
                }
                auto next = list[lind];
                auto locale = std::string([[OAAppSettings sharedManager].settingPrefMapLanguage UTF8String]);
                BOOL transliterate = [OAAppSettings sharedManager].settingMapLanguageTranslit;
                info.ref = [NSString stringWithUTF8String:next->object->getRef(locale, transliterate, next->isForwardDirection()).c_str()];
                info.streetName = [NSString stringWithUTF8String:next->object->getName(locale, transliterate).c_str()];
                info.destinationName = [NSString stringWithUTF8String:next->object->getDestinationName(locale, transliterate, next->isForwardDirection()).c_str()];
            }
            
            NSString *description = [[NSString stringWithFormat:@"%@ %@", [self.class toString:turn shortName:false],  [OARoutingHelper formatStreetName:info.streetName ref:info.ref destination:info.destinationName towards:OALocalizedString(@"towards")]] trim];
            
            if (s->object->pointNames.size() > s->getStartPointIndex())
            {
                const auto& pointNames = s->object->pointNames[s->getStartPointIndex()];
                if (!pointNames.empty())
                {
                    for (int t = 0; t < pointNames.size(); t++)
                    {
                        description = [description trim];
                        description = [description stringByAppendingString:[NSString stringWithFormat:@" %@", [NSString stringWithUTF8String:pointNames[t].c_str()]]];
                    }
                }
            }
            info.descriptionRoute = description;
            info.routePointOffset = prevLocationSize;
            if (directions.count > 0 && prevDirectionTime > 0 && prevDirectionDistance > 0)
            {
                OARouteDirectionInfo *prev = directions[directions.count - 1];
                prev.averageSpeed = (prevDirectionDistance / prevDirectionTime);
                prevDirectionDistance = 0;
                prevDirectionTime = 0;
            }
            [directions addObject:info];
        }
        prevDirectionDistance += s->distance;
        prevDirectionTime += s->segmentTime;
    }
    if (directions.count > 0 && prevDirectionTime > 0 && prevDirectionDistance > 0)
    {
        OARouteDirectionInfo *prev = directions[directions.count - 1];
        prev.averageSpeed = (prevDirectionDistance / prevDirectionTime);
    }
    return segmentsToPopulate;
}

- (instancetype) initWithLocations:(NSArray<CLLocation *> *)list directions:(NSArray<OARouteDirectionInfo *> *)directions params:(OARouteCalculationParams *)params waypoints:(NSArray<id<OALocationPoint>> *)waypoints addMissingTurns:(BOOL)addMissingTurns
{
    self = [[OARouteCalculationResult alloc] init];
    if (self)
    {
        _routingTime = 0;
        _errorMessage = nil;
        _intermediatePoints = [NSMutableArray arrayWithCapacity:params.intermediates.count];
        NSMutableArray<CLLocation *> *locations = [NSMutableArray arrayWithArray:list];
        NSMutableArray<OARouteDirectionInfo *> *localDirections = [NSMutableArray arrayWithArray:directions];
        if (locations.count > 0)
            [self.class checkForDuplicatePoints:locations directions:localDirections];
        
        if (waypoints) {
            [_locationPoints addObjectsFromArray:waypoints];
        }
        if (addMissingTurns)
        {
            [self removeUnnecessaryGoAhead:localDirections];
            [self.class addMissingTurnsToRoute:locations originalDirections:localDirections start:params.start end:params.end mode:params.mode leftSide:params.leftSide];
            // if there is no closest points to start - add it
            std::vector<std::shared_ptr<RouteSegmentResult>> segs;
            [self.class introduceFirstPointAndLastPoint:locations directions:localDirections segs:segs start:params.start end:params.end];
        }
        _appMode = params.mode;
        _locations = locations;
        _segments = std::vector<std::shared_ptr<RouteSegmentResult>>();
        _listDistance = [NSMutableArray arrayWithCapacity:locations.count];
        [self.class updateListDistanceTime:_listDistance locations:_locations];
        _alarmInfo = [NSMutableArray array];
        [self.class calculateIntermediateIndexes:_locations intermediates:params.intermediates localDirections:localDirections intermediatePoints:_intermediatePoints];
        _directions = localDirections;
        [self.class updateDirectionsTime:_directions listDistance:_listDistance];
    }
    return self;
}

- (instancetype) initWithSegmentResults:(std::vector<std::shared_ptr<RouteSegmentResult>>&)list start:(CLLocation *)start end:(CLLocation *)end intermediates:(NSArray<CLLocation *> *)intermediates leftSide:(BOOL)leftSide routingTime:(float)routingTime waypoints:(NSArray<id<OALocationPoint>> *)waypoints mode:(OAMapVariantType)mode
{
    self = [[OARouteCalculationResult alloc] init];
    if (self)
    {
        _routingTime = routingTime;
        if (waypoints)
            [_locationPoints addObjectsFromArray:waypoints];
        
        NSMutableArray<OARouteDirectionInfo *> *computeDirections = [NSMutableArray array];
        _errorMessage = nil;
        _intermediatePoints = [NSMutableArray arrayWithCapacity:!intermediates ? 0 : intermediates.count];
        NSMutableArray<CLLocation *> *locations = [NSMutableArray array];
        NSMutableArray<OAAlarmInfo *> *alarms = [NSMutableArray array];
        std::vector<std::shared_ptr<RouteSegmentResult>> segments = [self.class convertVectorResult:computeDirections locations:locations list:list alarms:alarms];
        [self.class introduceFirstPointAndLastPoint:locations directions:computeDirections segs:segments start:start end:end];
        
        _locations = locations;
        _segments = segments;
        _listDistance = [NSMutableArray arrayWithCapacity:locations.count];
        [self.class calculateIntermediateIndexes:_locations intermediates:intermediates localDirections:computeDirections intermediatePoints:_intermediatePoints];;
        [self.class updateListDistanceTime:_listDistance locations:_locations];;
        _appMode = mode;
        
        _directions = computeDirections;
        [self.class updateDirectionsTime:_directions listDistance:_listDistance];;
        _alarmInfo = alarms;
    }
    return self;
}

@end
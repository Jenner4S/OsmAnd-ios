//
//  OADebugSettings.m
//  OsmAnd
//
//  Created by AntonRogachevskiy on 10/16/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OAAppSettings.h"
#import "OsmAndApp.h"
#import "Localization.h"

@implementation OAAppSettings

@synthesize settingShowMapRulet=_settingShowMapRulet, settingMapLanguage=_settingMapLanguage, settingAppMode=_settingAppMode;
@synthesize mapSettingShowFavorites=_mapSettingShowFavorites, settingPrefMapLanguage=_settingPrefMapLanguage;
@synthesize settingMapLanguageShowLocal=_settingMapLanguageShowLocal, settingMapLanguageTranslit=_settingMapLanguageTranslit;

+ (OAAppSettings*)sharedManager
{
    static OAAppSettings *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[OAAppSettings alloc] init];
    });
    return _sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _trackIntervalArray = @[@0, @1, @2, @3, @5, @10, @15, @30, @60, @90, @120, @180, @300];
        
        _mapLanguages = @[@"af", @"ar", @"az", @"be", @"bg", @"bn", @"br", @"bs", @"ca", @"ceb", @"cs", @"cy", @"da", @"de", @"el", @"eo", @"es", @"et", @"eu", @"id", @"fa", @"fi", @"fr", @"fy", @"ga", @"gl", @"he", @"hi", @"hr", @"ht", @"hu", @"hy", @"is", @"it", @"ja", @"ka", @"kn", @"ko", @"ku", @"la", @"lb", @"lt", @"lv", @"mk", @"ml", @"mr", @"ms", @"nds", @"new", @"nl", @"nn", @"no", @"nv", @"os", @"pl", @"pt", @"ro", @"ru", @"sc", @"sh", @"sk", @"sl", @"sq", @"sr", @"sv", @"sw", @"ta", @"te", @"th", @"tl", @"tr", @"uk", @"vi", @"vo", @"zh"];
        
        NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
        BOOL isMetricSystem = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue] && ![locale.localeIdentifier isEqualToString:@"en_GB"];
        
        // Common Settings
        _settingMapLanguage = [[NSUserDefaults standardUserDefaults] objectForKey:settingMapLanguageKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:settingMapLanguageKey] : 0;
                
        _settingPrefMapLanguage = [[NSUserDefaults standardUserDefaults] objectForKey:settingPrefMapLanguageKey];
        _settingMapLanguageShowLocal = [[NSUserDefaults standardUserDefaults] objectForKey:settingMapLanguageShowLocalKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:settingMapLanguageShowLocalKey] : NO;
        _settingMapLanguageTranslit = [[NSUserDefaults standardUserDefaults] objectForKey:settingMapLanguageTranslitKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:settingMapLanguageTranslitKey] : NO;

        _settingShowMapRulet = [[NSUserDefaults standardUserDefaults] objectForKey:settingShowMapRuletKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:settingShowMapRuletKey] : YES;
        _settingAppMode = [[NSUserDefaults standardUserDefaults] objectForKey:settingAppModeKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:settingAppModeKey] : 0;

        _settingMetricSystem = [[NSUserDefaults standardUserDefaults] objectForKey:settingMetricSystemKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:settingMetricSystemKey] : (isMetricSystem ? 0 : 1);
        _settingShowZoomButton = YES;//[[NSUserDefaults standardUserDefaults] objectForKey:settingZoomButtonKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:settingZoomButtonKey] : YES;
        _settingGeoFormat = [[NSUserDefaults standardUserDefaults] objectForKey:settingGeoFormatKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:settingGeoFormatKey] : 0;
        _settingMapArrows = [[NSUserDefaults standardUserDefaults] objectForKey:settingMapArrowsKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:settingMapArrowsKey] : MAP_ARROWS_LOCATION;
        
        _settingShowAltInDriveMode = [[NSUserDefaults standardUserDefaults] objectForKey:settingMapShowAltInDriveModeKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:settingMapShowAltInDriveModeKey] : NO;

        // Map Settings
        _mapSettingShowFavorites = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingShowFavoritesKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:mapSettingShowFavoritesKey] : NO;
        _mapSettingVisibleGpx = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingVisibleGpxKey] ? [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingVisibleGpxKey] : @[];

        _mapSettingTrackRecording = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingTrackRecordingKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:mapSettingTrackRecordingKey] : NO;
        _mapSettingSaveTrackInterval = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingSaveTrackIntervalKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:mapSettingSaveTrackIntervalKey] : SAVE_TRACK_INTERVAL_DEFAULT;
        _mapSettingSaveTrackIntervalGlobal = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingSaveTrackIntervalGlobalKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:mapSettingSaveTrackIntervalGlobalKey] : SAVE_TRACK_INTERVAL_DEFAULT;

        _mapSettingShowRecordingTrack = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingShowRecordingTrackKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:mapSettingShowRecordingTrackKey] : NO;
        _mapSettingSaveTrackIntervalApproved = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingSaveTrackIntervalApprovedKey] ? [[NSUserDefaults standardUserDefaults] boolForKey:mapSettingSaveTrackIntervalApprovedKey] : NO;
        _mapSettingActiveRouteFileName = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingActiveRouteFileNameKey];
        _mapSettingActiveRouteVariantType = [[NSUserDefaults standardUserDefaults] objectForKey:mapSettingActiveRouteVariantTypeKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:mapSettingActiveRouteVariantTypeKey] : 0;

        _selectedPoiFilters = [[NSUserDefaults standardUserDefaults] objectForKey:selectedPoiFiltersKey] ? [[NSUserDefaults standardUserDefaults] objectForKey:selectedPoiFiltersKey] : @[];

        _discountId = [[NSUserDefaults standardUserDefaults] objectForKey:discountIdKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:discountIdKey] : 0;
        _discountShowNumberOfStarts = [[NSUserDefaults standardUserDefaults] objectForKey:discountShowNumberOfStartsKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:discountShowNumberOfStartsKey] : 0;
        _discountTotalShow = [[NSUserDefaults standardUserDefaults] objectForKey:discountTotalShowKey] ? [[NSUserDefaults standardUserDefaults] integerForKey:discountTotalShowKey] : 0;
        _discountShowDatetime = [[NSUserDefaults standardUserDefaults] objectForKey:discountShowDatetimeKey] ? [[NSUserDefaults standardUserDefaults] doubleForKey:discountShowDatetimeKey] : 0;

    }
    return self;
}

// Common Settings
-(void)setSettingShowMapRulet:(BOOL)settingShowMapRulet {
    _settingShowMapRulet = settingShowMapRulet;
    [[NSUserDefaults standardUserDefaults] setBool:_settingShowMapRulet forKey:settingShowMapRuletKey];
}

-(void)setSettingMapLanguage:(int)settingMapLanguage {
    _settingMapLanguage = settingMapLanguage;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingMapLanguage forKey:settingMapLanguageKey];
    [[[OsmAndApp instance] mapSettingsChangeObservable] notifyEvent];
}

-(void)setSettingPrefMapLanguage:(NSString *)settingPrefMapLanguage
{
    _settingPrefMapLanguage = settingPrefMapLanguage;
    [[NSUserDefaults standardUserDefaults] setObject:_settingPrefMapLanguage forKey:settingPrefMapLanguageKey];
    [[[OsmAndApp instance] mapSettingsChangeObservable] notifyEvent];
}

-(void)setSettingMapLanguageShowLocal:(BOOL)settingMapLanguageShowLocal
{
    _settingMapLanguageShowLocal = settingMapLanguageShowLocal;
    [[NSUserDefaults standardUserDefaults] setBool:_settingMapLanguageShowLocal forKey:settingMapLanguageShowLocalKey];
}

-(void)setSettingMapLanguageTranslit:(BOOL)settingMapLanguageTranslit
{
    _settingMapLanguageTranslit = settingMapLanguageTranslit;
    [[NSUserDefaults standardUserDefaults] setBool:_settingMapLanguageTranslit forKey:settingMapLanguageTranslitKey];
}

-(void)setSettingAppMode:(int)settingAppMode {
    _settingAppMode = settingAppMode;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingAppMode forKey:settingAppModeKey];
    [[[OsmAndApp instance] dayNightModeObservable] notifyEvent];
}

-(void)setSettingMetricSystem:(int)settingMetricSystem {
    _settingMetricSystem = settingMetricSystem;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingMetricSystem forKey:settingMetricSystemKey];
}

-(void)setSettingShowZoomButton:(BOOL)settingShowZoomButton {
    _settingShowZoomButton = settingShowZoomButton;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingShowZoomButton forKey:settingZoomButtonKey];
}

-(void)setSettingGeoFormat:(int)settingGeoFormat {
    _settingGeoFormat = settingGeoFormat;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingGeoFormat forKey:settingGeoFormatKey];
}

-(void)setSettingMapArrows:(int)settingMapArrows {
    _settingMapArrows = settingMapArrows;
    [[NSUserDefaults standardUserDefaults] setInteger:_settingMapArrows forKey:settingMapArrowsKey];
}

-(void)setSettingShowAltInDriveMode:(BOOL)settingShowAltInDriveMode {
    _settingShowAltInDriveMode = settingShowAltInDriveMode;
    [[NSUserDefaults standardUserDefaults] setBool:_settingShowAltInDriveMode forKey:settingMapShowAltInDriveModeKey];
}

// Map Settings
-(void)setMapSettingShowFavorites:(BOOL)mapSettingShowFavorites {
    
    //if (_mapSettingShowFavorites == mapSettingShowFavorites)
    //    return;
    
    _mapSettingShowFavorites = mapSettingShowFavorites;
    [[NSUserDefaults standardUserDefaults] setBool:_mapSettingShowFavorites forKey:mapSettingShowFavoritesKey];

    OsmAndAppInstance app = [OsmAndApp instance];
    if (_mapSettingShowFavorites) {
        if (![app.data.mapLayersConfiguration isLayerVisible:kFavoritesLayerId]) {
            [app.data.mapLayersConfiguration setLayer:kFavoritesLayerId
                                           Visibility:YES];
        }
    } else {
        if ([app.data.mapLayersConfiguration isLayerVisible:kFavoritesLayerId]) {
            [app.data.mapLayersConfiguration setLayer:kFavoritesLayerId
                                           Visibility:NO];
        }
    }
}

-(void)setMapSettingTrackRecording:(BOOL)mapSettingTrackRecording
{
    _mapSettingTrackRecording = mapSettingTrackRecording;
    [[NSUserDefaults standardUserDefaults] setBool:_mapSettingTrackRecording forKey:mapSettingTrackRecordingKey];
    [[[OsmAndApp instance] trackStartStopRecObservable] notifyEvent];
}

-(void)setMapSettingSaveTrackInterval:(int)mapSettingSaveTrackInterval
{
    _mapSettingSaveTrackInterval = mapSettingSaveTrackInterval;
    [[NSUserDefaults standardUserDefaults] setInteger:_mapSettingSaveTrackInterval forKey:mapSettingSaveTrackIntervalKey];
}

-(void)setMapSettingSaveTrackIntervalGlobal:(int)mapSettingSaveTrackIntervalGlobal
{
    _mapSettingSaveTrackIntervalGlobal = mapSettingSaveTrackIntervalGlobal;
    [[NSUserDefaults standardUserDefaults] setInteger:_mapSettingSaveTrackIntervalGlobal forKey:mapSettingSaveTrackIntervalGlobalKey];
    [self setMapSettingSaveTrackInterval:_mapSettingSaveTrackIntervalGlobal];
}

-(void)setMapSettingVisibleGpx:(NSArray *)mapSettingVisibleGpx
{
    _mapSettingVisibleGpx = mapSettingVisibleGpx;
    [[NSUserDefaults standardUserDefaults] setObject:_mapSettingVisibleGpx forKey:mapSettingVisibleGpxKey];
}

-(void)setSelectedPoiFilters:(NSArray<NSString *> *)selectedPoiFilters
{
    _selectedPoiFilters = selectedPoiFilters;
    [[NSUserDefaults standardUserDefaults] setObject:_selectedPoiFilters forKey:selectedPoiFiltersKey];
}

-(void)setMapSettingShowRecordingTrack:(BOOL)mapSettingShowRecordingTrack
{
    _mapSettingShowRecordingTrack = mapSettingShowRecordingTrack;
    [[NSUserDefaults standardUserDefaults] setBool:_mapSettingShowRecordingTrack forKey:mapSettingShowRecordingTrackKey];
}

-(void)setMapSettingSaveTrackIntervalApproved:(BOOL)mapSettingSaveTrackIntervalApproved
{
    _mapSettingSaveTrackIntervalApproved = mapSettingSaveTrackIntervalApproved;
    [[NSUserDefaults standardUserDefaults] setBool:_mapSettingSaveTrackIntervalApproved forKey:mapSettingSaveTrackIntervalApprovedKey];
}

-(void)setMapSettingActiveRouteFileName:(NSString *)mapSettingActiveRouteFileName
{
    _mapSettingActiveRouteFileName = mapSettingActiveRouteFileName;
    [[NSUserDefaults standardUserDefaults] setObject:_mapSettingActiveRouteFileName forKey:mapSettingActiveRouteFileNameKey];
}

-(void)setMapSettingActiveRouteVariantType:(int)mapSettingActiveRouteVariantType
{
    _mapSettingActiveRouteVariantType = mapSettingActiveRouteVariantType;
    [[NSUserDefaults standardUserDefaults] setInteger:_mapSettingActiveRouteVariantType forKey:mapSettingActiveRouteVariantTypeKey];
}

-(void)setDiscountId:(NSInteger)discountId
{
    _discountId = discountId;
    [[NSUserDefaults standardUserDefaults] setInteger:discountId forKey:discountIdKey];
}

-(void)setDiscountShowNumberOfStarts:(NSInteger)discountShowNumberOfStarts
{
    _discountShowNumberOfStarts = discountShowNumberOfStarts;
    [[NSUserDefaults standardUserDefaults] setInteger:discountShowNumberOfStarts forKey:discountShowNumberOfStartsKey];
}

-(void)setDiscountTotalShow:(NSInteger)discountTotalShow
{
    _discountTotalShow = discountTotalShow;
    [[NSUserDefaults standardUserDefaults] setInteger:discountTotalShow forKey:discountTotalShowKey];
}

-(void)setDiscountShowDatetime:(double)discountShowDatetime
{
    _discountShowDatetime = discountShowDatetime;
    [[NSUserDefaults standardUserDefaults] setInteger:discountShowDatetime forKey:discountShowDatetimeKey];
}

-(void)showGpx:(NSString *)fileName
{
    if (![_mapSettingVisibleGpx containsObject:fileName]) {
        NSMutableArray *arr = [NSMutableArray arrayWithArray:_mapSettingVisibleGpx];
        [arr addObject:fileName];
        self.mapSettingVisibleGpx = arr;
    }
}

-(void)hideGpx:(NSString *)fileName
{
    if ([_mapSettingVisibleGpx containsObject:fileName]) {
        NSMutableArray *arr = [NSMutableArray arrayWithArray:_mapSettingVisibleGpx];
        [arr removeObject:fileName];
        self.mapSettingVisibleGpx = arr;
    }
}

- (NSString *)getFormattedTrackInterval:(int)value
{
    NSString *res;
    if (value == 0)
        res = OALocalizedString(@"rec_interval_minimum");
    else if (value > 90)
        res = [NSString stringWithFormat:@"%d %@", (int)(value / 60.0), OALocalizedString(@"units_minutes_short")];
    else
        res = [NSString stringWithFormat:@"%d %@", value, OALocalizedString(@"units_seconds_short")];
    return res;
}

@end

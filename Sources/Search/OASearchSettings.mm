//
//  OASearchSettings.m
//  OsmAnd
//
//  Created by Alexey Kulish on 11/01/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OASearchSettings.h"

@interface OASearchSettings ()

@property (nonatomic) int pRadiusLevel;
@property (nonatomic) CLLocation *pOriginalLocation;
@property (nonatomic) int pTotalLimit;
@property (nonatomic) NSString *pLang;
@property (nonatomic) BOOL pTransliterateIfMissing;

@end

@implementation OASearchSettings
{
    NSArray<NSString *> *_resourceIds;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.pRadiusLevel = 1;
        self.pTotalLimit = -1;
    }
    return self;
}

- (instancetype)initWithSettings:(OASearchSettings *)s
{
    self = [self init];
    if (self)
    {
        if (s)
        {
            self.pRadiusLevel = s.pRadiusLevel;
            self.pLang = s.pLang;
            self.pTotalLimit = s.pTotalLimit;
            self.pOriginalLocation = s.pOriginalLocation;
            [self setOfflineIndexes:[s getOfflineIndexes]];
        }
    }
    return self;
}

- (instancetype)initWithIndexes:(NSArray<NSString *> *)resourceIds;
{
    self = [self init];
    if (self)
    {
        [self setOfflineIndexes:resourceIds];
    }
    return self;
}

- (NSArray<NSString *> *) getOfflineIndexes;
{
    return _resourceIds;
}

- (void) setOfflineIndexes:(NSArray<NSString *> *)resourceIds;
{
    _resourceIds = resourceIds;
}

- (int) getRadiusLevel
{
    return self.pRadiusLevel;
}

- (NSString *) getLang
{
    return self.pLang;
}

- (OASearchSettings *) setLang:(NSString *)lang transliterateIfMissing:(BOOL)transliterateIfMissing
{
    OASearchSettings *s = [[OASearchSettings alloc] initWithSettings:self];
    s.pLang = lang;
    s.pTransliterateIfMissing = transliterateIfMissing;
    return s;
}

- (OASearchSettings *) setRadiusLevel:(int)radiusLevel
{
    OASearchSettings *s = [[OASearchSettings alloc] initWithSettings:self];
    s.pRadiusLevel = radiusLevel;
    return s;
}

- (int) getTotalLimit
{
    return self.pTotalLimit;
}

- (OASearchSettings *) setTotalLimit:(int)totalLimit
{
    OASearchSettings *s = [[OASearchSettings alloc] initWithSettings:self];
    s.pTotalLimit = totalLimit;
    return s;
}

- (CLLocation *) getOriginalLocation
{
    return self.pOriginalLocation;
}

- (OASearchSettings *) setOriginalLocation:(CLLocation *)l
{
    OASearchSettings *s = [[OASearchSettings alloc] initWithSettings:self];
    s.pOriginalLocation = l;
    return s;
}

- (BOOL) isTransliterate
{
    return self.pTransliterateIfMissing;
}

@end

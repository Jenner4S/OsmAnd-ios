//
//  OAPOILayer.h
//  OsmAnd
//
//  Created by Alexey Kulish on 11/06/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OASymbolMapLayer.h"

@class OAPOIUIFilter;

@interface OAPOILayer : OASymbolMapLayer

- (void) showPoiOnMap:(NSString *)category type:(NSString *)type filter:(NSString *)filter keyword:(NSString *)keyword;
- (void) showPoiOnMap:(OAPOIUIFilter *)uiFilter keyword:(NSString *)keyword;
- (void) hidePoi;

@end

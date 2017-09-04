//
//  OAFileNameTranslationHelper.m
//  OsmAnd
//
//  Created by Alexey Kulish on 02/09/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OAFileNameTranslationHelper.h"

@implementation OAFileNameTranslationHelper

+ (NSString *) getVoiceName:(NSString *)fileName
{
    NSString *nm = [[fileName stringByReplacingOccurrencesOfString:@"-" withString:@"_"] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    if ([nm hasSuffix:@"_tts"] || [nm hasSuffix:@"-tts"])
        nm = [nm substringToIndex:nm.length - 4];
    
    NSString *name = [[NSLocale currentLocale] displayNameForKey:NSLocaleIdentifier value:nm];
    if (name)
        return [name capitalizedStringWithLocale:[NSLocale currentLocale]];
    else
        return fileName;
}

@end

//
//  OAUtilities.m
//  OsmAnd
//
//  Created by Alexey Pelykh on 6/5/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OANativeUtilities.h"

#import <UIKit/UIKit.h>

#include <QString>

#include <SkImageDecoder.h>
#include <SkCGUtils.h>

@implementation OANativeUtilities

+ (std::shared_ptr<SkBitmap>)skBitmapFromPngResource:(NSString *)resourceName
{
    if ([UIScreen mainScreen].scale > 1.0f)
        resourceName = [resourceName stringByAppendingString:@"@2x"];
    else if ([UIScreen mainScreen].scale > 2.0f)
        resourceName = [resourceName stringByAppendingString:@"@3x"];

    const auto resourcePath = [[NSBundle mainBundle] pathForResource:resourceName
                                                              ofType:@"png"];
    if (resourcePath == nil)
        return nullptr;

    const std::unique_ptr<SkImageDecoder> pngDecoder(CreatePNGImageDecoder());
    std::shared_ptr<SkBitmap> outputBitmap(new SkBitmap());
    if (!pngDecoder->DecodeFile(qPrintable(QString::fromNSString(resourcePath)), outputBitmap.get()))
        return nullptr;
    return outputBitmap;
}

+ (NSMutableArray*)QListOfStringsToNSMutableArray:(const QList<QString>&)list
{
    NSMutableArray* array = [[NSMutableArray alloc] initWithCapacity:list.size()];
    for(const auto& item : list)
        [array addObject:item.toNSString()];
    return array;
}

+ (Point31)convertFromPointI:(OsmAnd::PointI)input
{
    Point31 output;
    output.x = input.x;
    output.y = input.y;
    return output;
}

+ (OsmAnd::PointI)convertFromPoint31:(Point31)input
{
    OsmAnd::PointI output;
    output.x = input.x;
    output.y = input.y;
    return output;
}

+ (UIImage *) skBitmapToUIImage:(const SkBitmap&) skBitmap
{
    if (skBitmap.isNull())
        return nil;
    
    // First convert SkBitmap to CGImageRef.
    CGImageRef cgImage = SkCreateCGImageRefWithColorspace(skBitmap, NULL);
    // Now convert to UIImage.
    UIImage *img = [UIImage imageWithCGImage:cgImage
                                       scale:[UIScreen mainScreen].scale
                                 orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    
    return img;
}

@end

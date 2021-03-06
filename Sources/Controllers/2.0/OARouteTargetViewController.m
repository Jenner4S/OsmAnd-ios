//
//  OARouteTargetViewController.m
//  OsmAnd
//
//  Created by Alexey Kulish on 31/08/2017.
//  Copyright © 2017 OsmAnd. All rights reserved.
//

#import "OARouteTargetViewController.h"
#import "Localization.h"
#import "OARootViewController.h"

@interface OARouteTargetViewController ()

@end

@implementation OARouteTargetViewController

- (instancetype) initWithTarget:(BOOL)target
{
    self = [super init];
    if (self)
    {
        _target = target;
    }
    return self;
}

- (NSAttributedString *) getAttributedTypeStr
{
    if (_target)
        return [[NSAttributedString alloc] initWithString:OALocalizedString(@"select_route_finish_on_map")];
    else
        return [[NSAttributedString alloc] initWithString:OALocalizedString(@"select_route_start_on_map")];
}

- (BOOL) supportMapInteraction
{
    return YES;
}

- (BOOL) supportFullScreen
{
    return YES;
}

-(BOOL) hasTopToolbar
{
    return YES;
}

- (BOOL) shouldShowToolbar:(BOOL)isViewVisible;
{
    return YES;
}

- (BOOL) hasContent
{
    return NO;
}

- (void) applyLocalization
{
    [self.buttonCancel setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [self.buttonCancel setImage:[UIImage imageNamed:@"ic_close.png"] forState:UIControlStateNormal];
    [self.buttonCancel setTintColor:[UIColor whiteColor]];
    self.buttonCancel.titleEdgeInsets = UIEdgeInsetsMake(0.0, 12.0, 0.0, 0.0);
    self.buttonCancel.imageEdgeInsets = UIEdgeInsetsMake(0.0, -12.0, 0.0, 0.0);
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    self.titleView.text = OALocalizedString(@"shared_string_select_on_map");
}

- (void) cancelPressed
{
    //if (self.delegate)
    //    [self.delegate btnCancelPressed];
    
    [[OARootViewController instance].mapPanel showRouteInfo];
}

@end

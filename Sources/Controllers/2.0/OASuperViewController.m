//
//  OASuperViewController.m
//  OsmAnd
//
//  Created by Anton Rogachevskiy on 06.11.14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import "OASuperViewController.h"

@interface OASuperViewController ()

@end

@implementation OASuperViewController

- (void) viewDidLoad
{
    [super viewDidLoad];
    [self applyLocalization];
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) applyLocalization
{
    // override point
}

#pragma mark - Actions

- (IBAction) backButtonClicked:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}


- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (BOOL) prefersStatusBarHidden
{
    return NO;
}

@end

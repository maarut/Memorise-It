//
//  MCConstants.m
//  Memorise It
//
//  Created by Maarut Chandegra on 05/01/2017.
//  Copyright © 2017 Maarut Chandegra. All rights reserved.
//

#import "MCConstants.h"
#import <GoogleMobileAds/GoogleMobileAds.h>

NSString *const kAdMobAppId = ADMOB_APP_ID;
NSString *const kAdMobAdUnitId = ADMOB_ADUNIT_ID;

@implementation MCConstants

static NSArray<NSString *> *kAdMobTestDevices;

+ (NSArray<NSString *> *) adMobTestDevices
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kAdMobTestDevices =
            [[ADMOB_TEST_DEVICES componentsSeparatedByString:@" "] arrayByAddingObject: kGADSimulatorID];
    });
    return kAdMobTestDevices;
}

@end

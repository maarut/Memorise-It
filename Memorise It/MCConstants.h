//
//  MCConstants.h
//  Memorise It
//
//  Created by Maarut Chandegra on 05/01/2017.
//  Copyright © 2017 Maarut Chandegra. All rights reserved.
//
#import <Foundation/Foundation.h>

extern NSString *const kAdMobAppId;
extern NSString *const kAdMobAdUnitId;

@interface MCConstants: NSObject
+(NSArray<NSString *> *)adMobTestDevices;
@end

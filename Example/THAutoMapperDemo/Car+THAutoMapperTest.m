//
//  CAR+THAutoMapperTest.m
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/6/14.
//
//

#import "Car+THAutoMapperTest.h"

@implementation Car (THAutoMapperTest)

+ (NSString *)remoteIndexKey
{
    return @"__carId";
}

- (NSDictionary *)propertyMappingOverrides
{
    // Return a dictionary with the remote key mapped to the Core Data key path
    return @{@"_cus_tom_mapp_ing": @"custom_attribute"};
}

@end

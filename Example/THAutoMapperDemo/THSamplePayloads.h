//
//  THSamplePayloads.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 4/20/14.
//
//

#import <Foundation/Foundation.h>

@interface THSamplePayloads : NSObject

// Single
+ (NSDictionary *)singleUserEntityPayloadWithClassNamePrefixed;
+ (NSDictionary *)singleUserEntityPayloadWithoutClassNamePrefixed;

// Multiple
+ (NSArray *)multipleUserEntityPayloadWithoutClassNamePrefixed;
+ (NSArray *)multipleUserEntityPayloadWithClassNamePrefixed;

// Multiple with a single sub entity
+ (NSArray *)multipleUsersWithSubentityPayloadWithClassNamePrefixed;
+ (NSArray *)multipleUsersWithSubentityPayloadWithoutClassNamePrefixed;

// Multiple with a multiple sub entities
+ (NSArray *)multipleUsersWithMultipleSubentitiesPayloadWithClassNamePrefixed;
+ (NSArray *)multipleUsersWithMultipleSubentitiesPayloadWithoutClassNamePrefixed;

// Assoications through only uniqueIds
+ (NSDictionary *)objectWithToManyAssoicationsThroughUniqueIds;
+ (NSDictionary *)objectWithToOneAssoicationThroughUniqueIds;

// Testing Null Values
+ (NSDictionary *)objectWithNullValues;

// Testing Remote Naming Conventions
+ (NSDictionary *)objectCamelCaseNamingConvention;
+ (NSDictionary *)objectPascalCaseNamingConvention;

// Mapping Overrides
+ (NSDictionary *)objectRemoteIndexKeyOverride;
+ (NSDictionary *)objectPropertyOverride;

@end

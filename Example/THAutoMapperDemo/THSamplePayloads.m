//
//  THSamplePayloads.m
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 4/20/14.
//
//

#import "THSamplePayloads.h"

static NSDictionary *sampleJSONPayload;

@implementation THSamplePayloads

+ (NSDictionary *)testJSON
{
    if (!sampleJSONPayload) {
        NSURL *sampleJSONURL = [[NSBundle mainBundle] URLForResource:@"SampleJSON" withExtension:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:[sampleJSONURL path]];
        sampleJSONPayload = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"stop");
    }
    return sampleJSONPayload;
}

+ (NSDictionary *)singleUserEntityPayloadWithClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"singleUserEntityPayloadWithClassNamePrefixed"];
}

+ (NSDictionary *)singleUserEntityPayloadWithoutClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"singleUserEntityPayloadWithoutClassNamePrefixed"];
}

+ (NSArray *)multipleUserEntityPayloadWithoutClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersPayloadWithoutClassNamePrefixed"];
}

+ (NSArray *)multipleUserEntityPayloadWithClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersPayloadWithClassNamePrefixed"];
}

+ (NSArray *)multipleUsersWithSubentityPayloadWithClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersWithSubentityPayloadWithClassNamePrefixed"];
}

+ (NSArray *)multipleUsersWithSubentityPayloadWithoutClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersWithSubentityPayloadWithoutClassNamePrefixed"];
}

+ (NSArray *)multipleUsersWithMultipleSubentitiesPayloadWithClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersWithMultipleSubentitiesPayloadWithClassNamePrefixed"];
}

+ (NSArray *)multipleUsersWithMultipleSubentitiesPayloadWithoutClassNamePrefixed
{
    return [[self testJSON] objectForKey:@"multipleUsersWithMultipleSubentitiesPayloadWithoutClassNamePrefixed"];
}

+ (NSDictionary *)objectWithToManyAssoicationsThroughUniqueIds
{
    return [[self testJSON] objectForKey:@"objectWithToManyAssoicationsThroughUniqueIds"];
}

+ (NSDictionary *)objectWithToOneAssoicationThroughUniqueIds
{
    return [[self testJSON] objectForKey:@"objectWithToOneAssoicationThroughUniqueIds"];
}

+ (NSDictionary *)objectWithNullValues
{
    return [[self testJSON] objectForKey:@"objectWithNullValues"];
}

+ (NSDictionary *)objectCamelCaseNamingConvention
{
    return [[self testJSON] objectForKey:@"objectCamelCaseNamingConvention"];
}

+ (NSDictionary *)objectPascalCaseNamingConvention
{
    return [[self testJSON] objectForKey:@"objectPascalCaseNamingConvention"];
}

+ (NSDictionary *)objectRemoteIndexKeyOverride
{
    return [[self testJSON] objectForKey:@"objectRemoteIndexKeyOverride"];
}

+ (NSDictionary *)objectPropertyOverride
{
    return [[self testJSON] objectForKey:@"objectPropertyOverride"];
}

@end

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
        sampleJSONPayload = [NSDictionary dictionaryWithContentsOfURL:sampleJSONURL];
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

@end

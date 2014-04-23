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

@end

//
//  THSamplePayloads.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 4/20/14.
//
//

#import <Foundation/Foundation.h>

@interface THSamplePayloads : NSObject

+ (NSDictionary *)singleUserEntityPayloadWithClassNamePrefixed;
+ (NSDictionary *)singleUserEntityPayloadWithoutClassNamePrefixed;

@end

//
//  THAutoMapperDeserialization.m
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/4/14.
//
//

#import "THAutoMapperDeserialization.h"

#pragma mark - Object Deserialization

/**
 *  Object deserialization
 *
 *  This pattern allows for THAutoMapper to be customizied in how it handles the deserialization of object.
 *  By default, NSObject will return itself, which will be acceptable in most casses. In the case of NSDate,
 *  this behavior is clearly undesirable. An implementation to handle the deserialization of dates is show below.
 */

@implementation NSObject (THAutoMapperSupport)

+ (id)deserialize:(id)value
{
	return value;
}

@end


#pragma mark - Date Formatting (NSDate Deserialization)

/**
 *  Default date formatting will parse according to RFC3339; http://www.ietf.org/rfc/rfc3339.txt
 *
 *  THAutoMapper will allow for custom date parsing as well through the use of class categories. Simply
 *  extend NSDate, and define a class method '+ (NSDate *)deserialize'.
 *
 *  Example of this pattern is shown below.
 */

static NSDateFormatter *__THAutoMapperDateFormatter;

@implementation NSDate (THAutoMapperSupport)

+ (NSDate *)deserialize:(id)value {
	return ((value == [NSNull null]) || ![value isKindOfClass:[NSString class]]) ? nil : [self RFC3339DeserializationFromString:value];
}

+ (NSDate *)RFC3339DeserializationFromString:(NSString *)dateStr
{
    if (!__THAutoMapperDateFormatter) {
        __THAutoMapperDateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [__THAutoMapperDateFormatter setLocale:enUSPOSIXLocale];
        [__THAutoMapperDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [__THAutoMapperDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    
    return [__THAutoMapperDateFormatter dateFromString:dateStr];
}

@end



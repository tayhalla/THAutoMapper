//
//  THAutoMapperDeserialization.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/4/14.
//
//

#import <Foundation/Foundation.h>

/**
 *  Foward declaration of NSObject deserialization category.
 */
@interface NSObject (THAutoMapperSupport)

+ (id)deserialize:(id)value;

@end


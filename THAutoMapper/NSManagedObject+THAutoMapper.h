//
//  NSManagedObject+GathrCoreDataSupport.h
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

typedef enum THAutoMapperParseMethod {
    THAutoMapperParseWithoutClassPrefix = 0,
    THAutoMapperParseWithLowercasedClassPrefix = 1,
    THAutoMapperParseWithCapitalizedClassPrefix = 2
} THAutoMapperParseMethod;

@interface NSManagedObject (GathrCoreDataSupport)

+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod;

- (void)updateInstanceWithJSONResponse:(NSDictionary *)jsonResponse error:(NSError **)error;
- (BOOL)existsOnServer;

@end

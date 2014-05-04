//
//  NSManagedObject+GathrCoreDataSupport.h
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

// THAutoMapper Standard Warnings Macros
#define THLog(fmt, ...) NSLog((@"THAutoMapper Warning: " fmt), ##__VA_ARGS__)
#define THRequiredNilPropertyWarning(attr) THLog(@"A NULL value for a non-optional property (%@) was passed in the provided payload.\nTHAutoMapper will skip.", attr)
#define THPropertyMismatchWarning(attr) THLog(@"Unable to map the (%@) remote property to a local property.\nTHAutoMapper will skip.", attr)

typedef enum THAutoMapperParseMethod {
    THAutoMapperParseWithoutClassPrefix = 0,
    THAutoMapperParseWithClassPrefix = 1
} THAutoMapperParseMethod;

@interface NSManagedObject (GathrCoreDataSupport)

+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod;

- (void)updateInstanceWithJSONResponse:(NSDictionary *)jsonResponse error:(NSError **)error;
- (BOOL)existsOnServer;

@end

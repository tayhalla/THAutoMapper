//
//  NSManagedObject+GathrCoreDataSupport.h
//  GatherApp
//
//  Created by Taylor Halliday on 4/28/14.
//  Copyright (c) 2014 Taylor Halliday. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

/**
 *  Debug macros for letting the user know when a potential error has occured.
 */
#define THLog(fmt, ...) NSLog((@"THAutoMapper Warning: " fmt), ##__VA_ARGS__)
#define THRequiredNilPropertyWarning(attr) THLog(@"A NULL value for a non-optional property (%@) was passed in the provided payload.\nTHAutoMapper will skip.", attr)
#define THPropertyMismatchWarning(attr) THLog(@"Unable to map the (%@) remote property to a local property.\nTHAutoMapper will skip.", attr)

/**
 *  Enumerator for the different parsing methods available.
 */
typedef NS_ENUM(NSUInteger, THAutoMapperParseMethod) {
    /**
     * *** DEFAULT OPTION ***
     * This parsing method assumes that the JSON payload is NOT prefixed
     * with a class name. EX: a user object's incomming json payload
     * { "firstName" : "Taylor",
     *   "lastName"  : "Halliday"}
     *
     */
    THAutoMapperParseWithoutClassPrefix,
    /**
     * This parsing method assumes that the JSON payload is prefixed
     * with a class name. EX: a user object's incomming json payload
     * { "user": {
     *     "firstName" : "Taylor",
     *     "lastName"  : "Halliday"
     *   }
     * }
     */
    THAutoMapperParseWithClassPrefix
};

/**
 *  THAutoMapper will translate JSON payloads into objects and properties for your core data instances.
 */
@interface NSManagedObject (GathrCoreDataSupport)


/**
 *  Updates a given NSManagedObject subclass instance with a JSON dictionary.
 *  NOTE: This method does not take in a seperate ManagedObjectContext (MOC) because it assumes
 *  the context to be used is the one that is already retained by the object performing this selector.
 *
 *  @param jsonResponse JSON dictionary containing the attributes for the object.
 *  @param error        Error Object
 */
- (void)updateInstanceWithJSONResponse:(NSDictionary *)jsonResponse error:(NSError **)error;


/**
 *  Creates a NSManagedObject for a given class, provided a JSON dictionary. Cast as necessary.
 *
 *  @param jsonPayload  JSON dictionary containing the attributes for the object.
 *  @param context      NSManagedObjectContext to be used for object generation
 *  @param error        Error Object
 *
 *  @return A new or existing NSManagedObject for the given JSON payload
 */
+ (instancetype)createInstanceWithJSONResponse:(NSDictionary *)jsonPayload
                                       context:(NSManagedObjectContext *)context
                                         error:(NSError **)error;


/**
 *  Batch creation method. Only to be used on the specific subclass of NSManagedObject. 
 *  All members of the array are excepted to be of the same top-level class.
 *
 *  @param jsonResponse Array of JSON objects. Expected to be of the same top-level class.
 *  @param context      NSManagedObjectContext to be used for object generation
 *  @param error        Error object
 *
 *  @return An array of the newly created NSManagedObject subclass objects.
 */
+ (NSArray *)updateBatchWithJSONResponse:(NSArray *)jsonResponse
                                 context:(NSManagedObjectContext *)context
                                   error:(NSError **)error;


/**
 *  Sets the JSON Parsing method to be used by THAutoMapper
 *
 *  @param parsingMethod The parsing method. Options are present in the Enum delcaration.
 */
+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod;


@end

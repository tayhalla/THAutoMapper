//
//  NSManagedObject+GathrCoreDataSupport.m
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#import "NSManagedObject+GathrCoreDataSupport.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *__sentinelPropertyName = nil;
static BOOL *__topLevelClassNameInPayload = NO;

typedef enum THAutoMapperParseMethod {
    THAutoMapperParseWithoutClassPrefix,
    THAutoMapperParseWithClassPrefix
} THAutoMapperParseMethod;

@implementation NSManagedObject (GathrCoreDataSupport)

- (Class)topLevelClassForPayload:(NSDictionary *)payload
{
    // JSON objects prefixed with class name and is only key
    NSString *responseObjectName = [[payload allKeys] lastObject];
    NSString *result = [self camelizeString:responseObjectName];
    return NSClassFromString([result capitalizedString]);
}

- (BOOL)topLevelClassParity:(NSDictionary *)paylaod
{
    return self.class == [self topLevelClassForPayload:paylaod];
}

- (BOOL)updateInstanceWithJSONResponse:(NSDictionary *)payload
                                 error:(NSError **)error
{
    if ([self topLevelClassParity:payload]) {
        // Grabbing the properties of both the response and CD entity
        NSString *classKey = [NSStringFromClass([self class]) lowercaseString];
        NSDictionary *responseProperties = [payload objectForKey:classKey];
        NSDictionary *managedObjectAttributes = [[self entity] attributesByName];
        if ([responseProperties objectForKey:@"is_alive"] && ![[responseProperties objectForKey:@"is_alive"] boolValue]) {
            [self.managedObjectContext deleteObject:self];
            return YES;
        }
        // Here we go
        for (NSString *attribute in responseProperties) {
            // Making the property look like an objective-c camel
            NSString *attributeCamalized = [self camelizeString:[self convertProperty:attribute andClassName:classKey]];

            // Using a CD entity method here - NSAttributeDescription - to get the prop class
            NSAttributeDescription *attrDesc = [managedObjectAttributes objectForKey:attributeCamalized];

            // Making sure we're still on the same page
            if (attrDesc) {

                Class propertyClass = NSClassFromString([attrDesc attributeValueClassName]);
                id value = [responseProperties objectForKey:attribute];

                // Setting the prop while calling the 'deserialize' catagory method
                if ([value isKindOfClass:[NSNull class]]) value = nil;
                if (![attrDesc isOptional] && !value) continue;
                    
                // 'deserialize' is a category I have on NSObject and certain other objects
                // where I want a certain return string format - i.e. NSDates serialize
                // back to a predefined string format I have.
                [self willChangeValueForKey:attributeCamalized];
                [self setValue:[propertyClass deserialize:value] forKey:attributeCamalized];
                [self didChangeValueForKey:attributeCamalized];
    
            } else {
                // stop here for unrecognized attributes
            }
        }
        
        // Build Relationships
        NSDictionary *relationships = [[self entity] relationshipsByName];
        [relationships enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            id relationObject = [responseProperties objectForKey:(NSString *)key];
            if (relationObject != nil) {
                NSEntityDescription *entity = [(NSRelationshipDescription *)obj destinationEntity];
                NSString *entityName = [entity name];
                Class klass = NSClassFromString(entityName);
                if ([relationObject isKindOfClass:[NSArray class]]) {
                    // Relation type is to-Many
                    NSArray *relationArray = (NSArray *)relationObject;
                    NSMutableSet *children = [[NSMutableSet alloc] initWithCapacity:relationArray.count];
                    for (id childObject in relationArray) {
                        NSManagedObject *managedObject;
                        if ([childObject isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *childDict = (NSDictionary *)childObject;
                            managedObject = [klass entityForServerSidePayload:childDict context:self.managedObjectContext];
                            if (managedObject) {
                                NSDictionary *childPayload = @{[entityName lowercaseString] : childDict};
                                [managedObject updateInstanceWithJSONResponse:childPayload error:error];
                                [children addObject:managedObject];
                            }
                        } else if ([childObject isKindOfClass:[NSNumber class]]) {
                            managedObject = [klass entityForServerSidePayload:@{@"id" : childObject} context:self.managedObjectContext];
                            [children addObject:managedObject];
                        }
                    }
                    
                    // Accessing to-many proxy set
                    NSMutableSet *proxySet = [self mutableSetValueForKey:key];
                    
                    // Generate Union Set
                    NSMutableSet *childrenUnion = [children mutableCopy];
                    [childrenUnion minusSet:proxySet];
                    
                    //Generate Minus Set
                    NSMutableSet *childrenMinus = [proxySet mutableCopy];
                    [childrenMinus minusSet:children];
                    
                    // Implementing Union Set Mutation on To-Many Relation
                    [self willChangeValueForKey:key withSetMutation:NSKeyValueUnionSetMutation usingObjects:childrenUnion];
                    [proxySet unionSet:childrenUnion];
                    [self didChangeValueForKey:key withSetMutation:NSKeyValueUnionSetMutation usingObjects:childrenUnion];

                    // Implementing Minus Set Mutation on To-Many Relation
                    [self willChangeValueForKey:key withSetMutation:NSKeyValueMinusSetMutation usingObjects:childrenMinus];
                    [proxySet minusSet:childrenMinus];
                    [self didChangeValueForKey:key withSetMutation:NSKeyValueMinusSetMutation usingObjects:childrenMinus];

                } else if ([relationObject isKindOfClass:[NSDictionary class]] || [relationObject isKindOfClass:[NSNumber class]] || (relationObject == [NSNull null])) {
                    // Relation type is to-one
                    id managedObject = nil;
                    if (relationObject != [NSNull null] && [relationObject isKindOfClass:[NSDictionary class]]) {
                        managedObject = [klass entityForServerSidePayload:(NSDictionary *)relationObject context:self.managedObjectContext];
                        if (managedObject) {
                            NSDictionary *childPayload = @{[entityName lowercaseString] : relationObject};
                            [managedObject updateInstanceWithJSONResponse:childPayload error:error];
                        }
                    } else if (relationObject != [NSNull null] && [relationObject isKindOfClass:[NSNumber class]]) {
                        managedObject = [klass entityForServerSidePayload:@{@"id" : relationObject} context:self.managedObjectContext];
                    }
                    // Commiting Changes w/ KVO Compliant Code
                    [self willChangeValueForKey:key];
                    [self setPrimitiveValue:managedObject forKey:key];
                    [self didChangeValueForKey:key];
                }
            }
        }];
        return YES;
    } else {
        NSDictionary *details = @{NSLocalizedDescriptionKey : @"class mismatch"};
        *error = [NSError errorWithDomain:@"managedObject JSON encoding" code:400 userInfo:details];
        return NO;
    }
}

- (BOOL)existsOnServer
{
    Class class = [self class];
    NSString *classString = [NSStringFromClass(class) lowercaseString];
    NSString *memberIDSelector = [classString stringByAppendingString:@"Id"];
    SEL selector = NSSelectorFromString(memberIDSelector);
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSNumber *result = [self performSelector:selector];
    #pragma clang diagnostic pop
    return [result intValue] == 0 ? NO : YES;
}

#pragma mark -
#pragma mark Private Instance Calls

- (id)propertyClass:(NSString *)className {
	return NSClassFromString([className capitalizedString]);
}

+ (id)entityForServerSidePayload:(NSDictionary *)payload
                         context:(NSManagedObjectContext *)context
{
    NSNumber *uniqueId = [payload objectForKey:@"id"];
    BOOL isAlive = [payload objectForKey:@"is_alive"] ? [[payload objectForKey:@"is_alive"] boolValue] : YES;
    
    NSManagedObject *returnObject;
    
    const char *className = class_getName(self);
    NSString *classString = [NSString stringWithUTF8String:className];
    NSEntityDescription *entity = [NSEntityDescription entityForName:classString inManagedObjectContext:context];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[entity name]];
    NSString *lowercaseEntityName = [[entity name] lowercaseString];
    NSPredicate *pred;
    
    // I need to unique against Photo UIDs since they can be existent prior to assigning of a ID by the server.
    if (self == [Photo class] && [payload objectForKey:@"asset_uid"]) {
        NSString *assetUID = [payload objectForKey:@"asset_uid"];
        pred = [NSPredicate predicateWithFormat:@"assetUid == %@", assetUID];
    } else {
        NSString *strPred = [NSString stringWithFormat:@"%@Id == %@", lowercaseEntityName, uniqueId];
        pred = [NSPredicate predicateWithFormat:strPred];
    }
    
    [request setPredicate:pred];
    [request setFetchLimit:1];
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:request error:&error];
    NSAssert(results, @"core data failure");
    if ([results count] == 0 && isAlive) {
        returnObject = [NSEntityDescription insertNewObjectForEntityForName:classString inManagedObjectContext:context];
    } else {
        returnObject = [results lastObject];
    }
    
    // Set ID
    NSString *idSetter = [NSString stringWithFormat:@"set%@Id:", [entity name]];
    SEL selector = NSSelectorFromString(idSetter);
    if ([returnObject respondsToSelector:selector])
    {
        SuppressPerformSelectorLeakWarning(
            [returnObject performSelector:selector withObject:uniqueId];
        );
    }

    return returnObject;
}
    
    
/*
 String Manipulations
*/

- (NSString *)capitalizeFirstLetterInString:(NSString *)string
{
    return [string stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                        withString:[[string substringToIndex:1] capitalizedString]];
}

- (NSString *)camelizeString:(NSString *)string
{
    unichar *buffer = calloc([string length], sizeof(unichar));
    [string getCharacters:buffer];
    NSMutableString *underscored = [NSMutableString string];
    
    BOOL capitalizeNext = NO;
    NSCharacterSet *delimiters = [self camelcaseDelimiters];
    for (int i = 0; i < [string length]; i++) {
        NSString *currChar = [NSString stringWithCharacters:buffer+i length:1];
        if([delimiters characterIsMember:buffer[i]]) {
            capitalizeNext = YES;
        } else {
            if(capitalizeNext) {
                [underscored appendString:[currChar uppercaseString]];
                capitalizeNext = NO;
            } else {
                [underscored appendString:currChar];
            }
        }
    }
    free(buffer);
    return underscored;
}

- (NSCharacterSet *)camelcaseDelimiters {
    return [NSCharacterSet characterSetWithCharactersInString:@"-_"];
}

- (NSString *)convertProperty:(NSString *)propertyName andClassName:(NSString *)className {
    if([propertyName isEqualToString:@"id"]) {
        propertyName = [NSString stringWithFormat:@"%@_id",className];
    }
    return propertyName;
}

#pragma mark - THAutoMapper Configuration

/*
 Setter for JSON Parsing Method
 */
+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod
{
    switch (parsingMethod) {
        case THAutoMapperParseWithClassPrefix:
            __topLevelClassNameInPayload = YES;
            break;
        case THAutoMapperParseWithClassPrefix:
            __topLevelClassNameInPayload = NO;
            break;
        default:
            break;
    }
}

/*
 Getter for JSON Parsing Method
 
 DEFAULT is THAutoMapperParseWithoutClassPrefix
 */
+ (THAutoMapperParseMethod)JSONParsingMethod
{
    switch (__topLevelClassNameInPayload) {
        case YES:
            return THAutoMapperParseWithClassPrefix;
            break;
        case NO:
            return THAutoMapperParseWithoutClassPrefix;
            break;
        default:
            break;
    }
}

+ (void)setSentinelPropertyName:(NSString *)propertyName
{
    if (__sentinelPropertyName != propertyName) {
        __sentinelPropertyName = propertyName;
    }
    
}


@end

//
//  NSManagedObject+GathrCoreDataSupport.m
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#define SuppressPerformSelectorLeakWarning(criticalArea) \
do { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    criticalArea; \
    _Pragma("clang diagnostic pop") \
} while (0)

#import "NSManagedObject+GathrCoreDataSupport.h"
#import <objc/runtime.h>
#import <objc/message.h>

// THAutoMapper Standard Warnings Macros
#define THLog(fmt, ...) NSLog((@"THAutoMapper Warning: " fmt), ##__VA_ARGS__)
#define THRequiredNilPropertyWarning(attr) THLog(@"A NULL value for a non-optional property (%@) was passed in the provided payload.\nTHAutoMapper will skip.", attr)
#define THPropertyMismatchWarning(attr) THLog(@"A NULL value for a non-optional property (%@) was passed in the provided payload.\nTHAutoMapper will skip.", attr)

typedef enum THAutoMapperParseMethod {
    THAutoMapperParseWithoutClassPrefix,
    THAutoMapperParseWithClassPrefix,
    THAutoMapperParseWithCapitalizedClassPrefix,
} THAutoMapperParseMethod;

static NSString *__sentinelPropertyName = nil;
static NSInteger __topLevelClassNameInPayload = THAutoMapperParseWithoutClassPrefix;

@implementation NSManagedObject (GathrCoreDataSupport)

- (void)updateInstanceWithJSONResponse:(NSDictionary *)payload
                                 error:(NSError **)error
{
    if ([self topLevelClassParity:payload]) {
        
        // Retrieve remote payload properties
        NSDictionary *remoteObjectProperties = [self remoteObjectPropertiesForPayload:payload];
        
        // Check for sentinel value, and delete object if present
        if ([remoteObjectProperties objectForKey:[self sentinelKeyForClass]])
            return [self.managedObjectContext deleteObject:self];
        
        // Retrieve managed object properties
        NSDictionary *managedObjectAttributes = [[self entity] attributesByName];
        
        // Map remote properties
        [self mapPayloadProperties:remoteObjectProperties
                toObjectProperties:managedObjectAttributes
                             error:error];

        // Build / Map relationships
        [self buildRelationshipsWithPayload:remoteObjectProperties
                                      error:error];
    } else {
        
        // Ohh Snap! Class parity was required and didn't match!
        NSDictionary *details = @{NSLocalizedDescriptionKey : @"Class mismatch in top level JSON"};
        *error = [NSError errorWithDomain:@"THAutoMapper" code:400 userInfo:details];
        return;
    }
}

- (Class)topLevelClassForPayload:(NSDictionary *)payload
{
    // JSON objects prefixed with class name and is only key
    NSString *responseObjectName = [[payload allKeys] lastObject];
    NSString *result = [self camelizeClass:responseObjectName];
    return NSClassFromString([result capitalizedString]);
}

- (BOOL)topLevelClassParity:(NSDictionary *)paylaod
{
    return self.class == [self topLevelClassForPayload:paylaod];
}

- (NSDictionary *)remoteObjectPropertiesForPayload:(NSDictionary *)payload
{
    switch (__topLevelClassNameInPayload) {
        case THAutoMapperParseWithoutClassPrefix:
            return payload;
            break;
        case THAutoMapperParseWithClassPrefix:
            return payload[NSStringFromClass([self class])];
            break;
        case THAutoMapperParseWithCapitalizedClassPrefix:
            return payload[[NSStringFromClass([self class]) capitalizedString]];
            break;
        default:
            return nil;
            break;
    }
}

- (NSString *)sentinelKeyForClass
{
    return __sentinelPropertyName;
}

- (void)mapPayloadProperties:(NSDictionary *)payload
          toObjectProperties:(NSDictionary *)objProperties
                       error:(NSError **)error
{
    for (NSString *attribute in payload) {

        // Preforming any needed normalization of the property string
        NSString *attributeCamalized = [self normalizeRemoteProperty:attribute];
        
        // Checking for presenece of property in the object
        NSAttributeDescription *attrDesc = [objProperties objectForKey:attributeCamalized];
        
        // Making sure we're still on the same page
        if (attrDesc) {
            
            Class propertyClass = NSClassFromString([attrDesc attributeValueClassName]);
            id value = [payload objectForKey:attribute];
            
            // Setting the prop while calling the 'deserialize' catagory method
            if ([value isKindOfClass:[NSNull class]]) value = nil;
            if (![attrDesc isOptional] && !value) {
                THRequiredNilPropertyWarning(attribute);
                continue;
            }
            
            // 'deserialize' is a category I have on NSObject and certain other objects
            // where I want a certain return string format - i.e. NSDates serialize
            // back to a predefined string format I have.
            [self willChangeValueForKey:attributeCamalized];
            [self setValue:[self deserializeProperty:attributeCamalized withClass:propertyClass] forKey:attributeCamalized];
            [self didChangeValueForKey:attributeCamalized];
            
        } else {
            // stop here for unrecognized attributes
        }
    }
    
}

- (void)buildRelationshipsWithPayload:(NSDictionary *)payload
                                error:(NSError **)error
{
    // Build Relationships
    NSDictionary *relationships = [[self entity] relationshipsByName];
    [relationships enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id relationObject = [payload objectForKey:(NSString *)key];
        if (relationObject != nil) {
            NSEntityDescription *entity = [(NSRelationshipDescription *)obj destinationEntity];
            NSString *entityName = [entity name];
            Class klass = NSClassFromString(entityName);
            
            if ([relationObject isKindOfClass:[NSArray class]]) {
                // Relation type is to-Many
            } else if ([relationObject isKindOfClass:[NSDictionary class]] || [relationObject isKindOfClass:[NSNumber class]]) {
                // Relation type is to-one
            }
        }
    }];
}

- (void)buildToOneRelationshipWithObject:(id)entityPayload class:(Class)klass keyPath:(NSString *)keyPath error:(NSError **)error
{
    id managedObject = nil;
    if ([entityPayload isKindOfClass:[NSDictionary class]]) {
        managedObject = [klass entityForServerSidePayload:(NSDictionary *)entityPayload context:self.managedObjectContext];
        if (managedObject) {
            NSDictionary *childPayload = @{[NSStringFromClass(klass) lowercaseString] : entityPayload};
            [managedObject updateInstanceWithJSONResponse:childPayload error:error];
        }
    } else if ([entityPayload isKindOfClass:[NSNumber class]]) {
        managedObject = [klass entityForServerSidePayload:@{@"id" : entityPayload} context:self.managedObjectContext];
    }
    // Commiting Changes w/ KVO Compliant Code
    [self willChangeValueForKey:keyPath];
    [self setPrimitiveValue:managedObject forKey:keyPath];
    [self didChangeValueForKey:keyPath];
}



- (void)buildToManyRelationship
{
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
}

- (BOOL)existsOnServer
{
    Class class = [self class];
    NSString *classString = [NSStringFromClass(class) lowercaseString];
    NSString *memberIDSelector = [classString stringByAppendingString:@"Id"];
    SEL selector = NSSelectorFromString(memberIDSelector);
    NSNumber *result;
    SuppressPerformSelectorLeakWarning(result = [self performSelector:selector]);
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
//    if (self == [Photo class] && [payload objectForKey:@"asset_uid"]) {
//        NSString *assetUID = [payload objectForKey:@"asset_uid"];
//        pred = [NSPredicate predicateWithFormat:@"assetUid == %@", assetUID];
//    } else {
//        NSString *strPred = [NSString stringWithFormat:@"%@Id == %@", lowercaseEntityName, uniqueId];
//        pred = [NSPredicate predicateWithFormat:strPred];
//    }
    
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

- (NSString *)camelizeClass:(NSString *)fromClass
{
    return [[self camelizeProperty:fromClass] capitalizedString];
}

- (NSString *)camelizeProperty:(NSString *)fromProperty
{
    return [NSString stringWithString:[self camelizedStringWithFromSting:fromProperty toString:[[NSMutableString alloc] init]]];
}

- (NSMutableString *)camelizedStringWithFromSting:(NSString *)fromString toString:(NSMutableString *)toString
{
    if ([fromString length] == 0) return toString;
    if ([[self camelcaseDelimiters] characterIsMember:[fromString characterAtIndex:0]]) {
        return [self camelizedStringWithFromSting:[[fromString substringFromIndex:1] capitalizedString] toString:toString];
    }
    [toString appendString:[fromString substringToIndex:1]];
    return [self camelizedStringWithFromSting:[fromString substringFromIndex:1] toString:toString];
}

- (NSCharacterSet *)camelcaseDelimiters {
    return [NSCharacterSet characterSetWithCharactersInString:@"-_"];
}

- (NSString *)normalizeRemoteProperty:(NSString *)remoteProperty {
    if([remoteProperty isEqualToString:[self classIndexPropertyName]]) {
        remoteProperty = [NSString stringWithFormat:@"%@_id", NSStringFromClass([self class])];
    }
    return remoteProperty;
}

- (NSString *)classIndexPropertyName
{
    return @"id";
}

#pragma mark - DeSerialize Property

- (id)deserializeProperty:(id)property withClass:(Class)klass
{
    SEL deserializeSelector = NSSelectorFromString(@"deserialize");
    if ([klass respondsToSelector:deserializeSelector]) {
        SuppressPerformSelectorLeakWarning(return [klass performSelector:deserializeSelector withObject:property];);
    }
    return property;
}

#pragma mark - THAutoMapper Configuration

/*
 Setter for JSON Parsing Method
 */
+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod
{
    if (__topLevelClassNameInPayload != parsingMethod) {
        __topLevelClassNameInPayload = parsingMethod;
    }
}

/*
 Getter for JSON Parsing Method
 
 DEFAULT is THAutoMapperParseWithoutClassPrefix
 */
+ (THAutoMapperParseMethod)JSONParsingMethod
{
    return __topLevelClassNameInPayload;
}

+ (void)setSentinelPropertyName:(NSString *)propertyName
{
    if (__sentinelPropertyName != propertyName) {
        __sentinelPropertyName = propertyName;
    }
}


@end

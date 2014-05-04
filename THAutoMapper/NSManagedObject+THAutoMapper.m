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

#import "NSManagedObject+THAutoMapper.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation NSManagedObject (GathrCoreDataSupport)

static NSString *__sentinelPropertyName = nil;
static NSInteger __topLevelClassNameInPayload;

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
    return (__topLevelClassNameInPayload == THAutoMapperParseWithoutClassPrefix) || self.class == [self topLevelClassForPayload:paylaod];
}

- (NSDictionary *)remoteObjectPropertiesForPayload:(NSDictionary *)payload
{
    switch (__topLevelClassNameInPayload) {
        case THAutoMapperParseWithoutClassPrefix:
            return payload;
            break;
        case THAutoMapperParseWithCapitalizedClassPrefix: {
            return NSStringFromClass([self class]);
            return payload;
            break;
        }
        default:
            return nil;
            break;
    }
    return payload[[self remoteClassName]];
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
        NSString *normalizedAttribute = [self normalizeRemoteProperty:attribute];
        NSAttributeDescription *attrDesc = [objProperties objectForKey:normalizedAttribute];
        
        if (attrDesc) {
            Class propertyClass = NSClassFromString([attrDesc attributeValueClassName]);
            id value = [payload objectForKey:attribute];
            
            if ([value isKindOfClass:[NSNull class]]) value = nil;
            if (![attrDesc isOptional] && !value) {
                THRequiredNilPropertyWarning(attribute);
                continue;
            }
            
            [self willChangeValueForKey:normalizedAttribute];
            [self setValue:value forKey:normalizedAttribute];
            [self didChangeValueForKey:normalizedAttribute];
        } else {
            THPropertyMismatchWarning(normalizedAttribute);
        }
    }
}

- (void)buildRelationshipsWithPayload:(NSDictionary *)payload
                                error:(NSError **)error
{
    NSDictionary *relationships = [[self entity] relationshipsByName];
    [relationships enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        id relation = [payload objectForKey:(NSString *)key];
        if (relation) {
            NSEntityDescription *entity = [(NSRelationshipDescription *)obj destinationEntity];
            NSString *entityName = [entity name];
            if ([relation isKindOfClass:[NSArray class]]) {
                [self buildToManyRelationship:relation
                                        class:NSClassFromString(entityName)
                                      keyPath:entityName
                                        error:error];
            } else if ([relation isKindOfClass:[NSDictionary class]] || [relation isKindOfClass:[NSNumber class]]) {
                [self buildToOneRelationshipWithObject:relation
                                                 class:NSClassFromString(entityName)
                                               keyPath:entityName 
                                                 error:error];
            }
        }
    }];
}

- (void)buildToOneRelationshipWithObject:(id)entityPayload
                                   class:(Class)klass
                                 keyPath:(NSString *)keyPath
                                   error:(NSError **)error
{
    id managedObject;
    if ([entityPayload isKindOfClass:[NSDictionary class]]) {
        managedObject = [klass entityForServerSidePayload:(NSDictionary *)entityPayload context:self.managedObjectContext];
        if (managedObject) {
            [managedObject updateInstanceWithJSONResponse:[self childPayloadForPayload:entityPayload]
                                                    error:error];
        }
    } else if ([entityPayload isKindOfClass:[NSNumber class]]) {
        managedObject = [klass entityForServerSidePayload:@{@"id" : entityPayload}
                                                  context:self.managedObjectContext];
    }
    
    [self willChangeValueForKey:keyPath];
    [self setPrimitiveValue:managedObject forKey:keyPath];
    [self didChangeValueForKey:keyPath];
}

- (void)buildToManyRelationship:(NSArray *)toManyRelation
                          class:(Class)klass
                        keyPath:(NSString *)keyPath
                          error:(NSError **)error
{
    NSMutableSet *children = [[NSMutableSet alloc] init];
    for (id childObject in toManyRelation) {
        NSManagedObject *managedObject;
        if ([childObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *childInfo = (NSDictionary *)childObject;
            managedObject = [klass entityForServerSidePayload:childInfo context:self.managedObjectContext];
            if (managedObject) {
                [managedObject updateInstanceWithJSONResponse:[self childPayloadForPayload:childInfo] error:error];
                [children addObject:managedObject];
            }
        } else if ([childObject isKindOfClass:[NSNumber class]]) {
            managedObject = [klass entityForServerSidePayload:@{[self remoteIndexKey] : childObject} context:self.managedObjectContext];
            [children addObject:managedObject];
        }
    }
    
    // Accessing to-many proxy set
    NSMutableSet *proxySet = [self mutableSetValueForKey:keyPath];
    
    // Generate Union Set
    NSMutableSet *childrenUnion = [children mutableCopy];
    [childrenUnion minusSet:proxySet];
    
    //Generate Minus Set
    NSMutableSet *childrenMinus = [proxySet mutableCopy];
    [childrenMinus minusSet:children];
    
    // Implementing Union Set Mutation on To-Many Relation
    [self willChangeValueForKey:keyPath withSetMutation:NSKeyValueUnionSetMutation usingObjects:childrenUnion];
    [proxySet unionSet:childrenUnion];
    [self didChangeValueForKey:keyPath withSetMutation:NSKeyValueUnionSetMutation usingObjects:childrenUnion];
    
    // Implementing Minus Set Mutation on To-Many Relation
    [self willChangeValueForKey:keyPath withSetMutation:NSKeyValueMinusSetMutation usingObjects:childrenMinus];
    [proxySet minusSet:childrenMinus];
    [self didChangeValueForKey:keyPath withSetMutation:NSKeyValueMinusSetMutation usingObjects:childrenMinus];
}

- (NSDictionary *)childPayloadForPayload:(NSDictionary *)payload
{
    switch (__topLevelClassNameInPayload) {
        case THAutoMapperParseWithoutClassPrefix:
            return payload;
            break;
        case THAutoMapperParseWithClassPrefix:
            return @{[self remoteClassName] : payload};
            break;
        default:
            return nil;
            break;
    }
}

- (NSString *)remoteClassName
{
    switch (__topLevelClassNameInPayload) {
        case THAutoMapperParseWithClassPrefix:
            return [NSStringFromClass([self class]) lowercaseString];
            break;
        case THAutoMapperParseWithoutClassPrefix:
            return nil;
            break;
        default:
            return nil;
            break;
    }
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

- (id)entityForServerSidePayload:(NSDictionary *)payload
                         context:(NSManagedObjectContext *)context
{
    NSNumber *indexedId = payload[[self remoteIndexKey]];
    BOOL isAlive = ![payload objectForKey:[self sentinelKeyForClass]];
    
    NSManagedObject *returnObject;
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[entity name]];
    
    NSString *strPred       = [NSString stringWithFormat:@"%@ == %@", [self localIndexKey], indexedId];
    NSPredicate *predicate  = [NSPredicate predicateWithFormat:strPred];
    
    [request setPredicate:predicate];
    [request setFetchLimit:1];
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:request error:&error];
    NSAssert(results, @"core data failure");
    if ([results count] == 0 && isAlive) {
        returnObject = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
        [returnObject setValue:indexedId forKey:[self localIndexKey]];
    } else {
        returnObject = [results lastObject];
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
    if([remoteProperty isEqualToString:[self remoteIndexKey]]) {
        remoteProperty = [NSString stringWithFormat:@"%@Id", [NSStringFromClass([self class]) lowercaseString]];
    }
    return remoteProperty;
}

- (NSString *)remoteIndexKey
{
    return @"id";
}

- (NSString *)localIndexKey
{
    return [NSString stringWithFormat:@"%@%@", NSStringFromClass([self class]), [[self remoteIndexKey] capitalizedString]];
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

/*
 NSNumber encodings
 https://developer.apple.com/library/mac/documentation/cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 */


@end

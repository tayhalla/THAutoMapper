//
//  NSManagedObject+GathrCoreDataSupport.m
//  GatherApp
//
//  Created by Taylor Halliday on 4/28/14.
//  Copyright (c) 2014 Taylor Halliday. All rights reserved.
//

#define SuppressPerformSelectorLeakWarning(criticalArea) \
do { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    criticalArea; \
    _Pragma("clang diagnostic pop") \
} while (0)

#import "NSManagedObject+THAutoMapper.h"
#import "THAutoMapperDeserialization.h"
#import <objc/runtime.h>
#import <objc/message.h>


@implementation NSManagedObject (GathrCoreDataSupport)

static NSString *__sentinelPropertyName = nil;
static THAutoMapperParseMethod __topLevelClassNameInPayload;
static THAutoMapperRemoteNaming __remoteNamingConvention;

#pragma mark - Class Methods

+ (NSArray *)updateBatchWithJSONResponse:(NSArray *)jsonResponse
                                 context:(NSManagedObjectContext *)context
                                   error:(NSError **)error
{
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    for (id payloadObject in jsonResponse) {
        if ([payloadObject isKindOfClass:[NSDictionary class]]) {
            [returnArray addObject:[self createInstanceWithJSONResponse:payloadObject context:context error:error]];
        } else if ([payloadObject isKindOfClass:[NSArray class]]) {
            [returnArray addObject:[self updateBatchWithJSONResponse:payloadObject context:context error:error]];
        } else {
            // Ohh Snap! Something weird is in this array!
            NSDictionary *details = @{NSLocalizedDescriptionKey : @"Illegal member in the JSONResponse provided. Must contain either Dictionaries or Arrays"};
            *error = [NSError errorWithDomain:@"THAutoMapper" code:400 userInfo:details];
            return nil;
        }
    }
    return returnArray;
}

+ (instancetype)createInstanceWithJSONResponse:(NSDictionary *)jsonPayload
                                       context:(NSManagedObjectContext *)context
                                         error:(NSError **)error
{
    NSManagedObject *instance = [self entityForServerSidePayload:[self remoteObjectPropertiesForPayload:jsonPayload] context:context];
    [instance updateInstanceWithJSONResponse:jsonPayload error:error];
    return instance;
}

#pragma mark - Instance Methods

- (void)updateInstanceWithJSONResponse:(NSDictionary *)payload
                                 error:(NSError **)error
{
    if ([self topLevelClassParity:payload]) {
        
        // Retrieve remote payload properties
        NSDictionary *remoteObjectProperties = [[self class] remoteObjectPropertiesForPayload:payload];
        
        // Check for sentinel value, and delete object if present
        if ([remoteObjectProperties objectForKey:[[self class] sentinelKeyForClass]]){
            return [self.managedObjectContext deleteObject:self];
        }
        
        // Retrieve managed object properties
        NSDictionary *managedObjectAttributes = [[self entity] attributesByName];
        NSDictionary *relationships           = [[self entity] relationshipsByName];

        // Map remote properties
        [self mapPayloadProperties:remoteObjectProperties
                toObjectProperties:managedObjectAttributes
                     relationships:relationships
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

+ (NSDictionary *)remoteObjectPropertiesForPayload:(NSDictionary *)payload
{
    if (__topLevelClassNameInPayload == THAutoMapperParseWithoutClassPrefix) {
        return payload;
    }
    return payload[[self remoteClassName]];
}

+ (NSString *)sentinelKeyForClass
{
    return __sentinelPropertyName;
}

- (void)mapPayloadProperties:(NSDictionary *)payload
          toObjectProperties:(NSDictionary *)objProperties
               relationships:(NSDictionary *)relationships
                       error:(NSError **)error
{
    [payload enumerateKeysAndObjectsUsingBlock:^(NSString *attributeKey, id attributeValue, BOOL *stop) {
        
        NSString *normalizedAttribute                  = [[self class] normalizeRemoteProperty:attributeKey];
        NSAttributeDescription *attrDescription        = [objProperties objectForKey:normalizedAttribute];
        NSRelationshipDescription *relationDescription = [relationships objectForKey:normalizedAttribute];

        if (attrDescription) {
            [self mapValue:attributeValue toAttributeKey:normalizedAttribute withAttrDescription:attrDescription];
        } else if (relationDescription) {
            [self buildRelationshipsWithRelationshipDescription:relationDescription payloadRelation:attributeValue error:error];
        } else {
            THPropertyMismatchWarning(normalizedAttribute);
        }
    }];
}

- (void)mapValue:(id)value toAttributeKey:(NSString *)normalizedAttribute withAttrDescription:(NSAttributeDescription *)attrDescription
{
    Class propertyClass = NSClassFromString([attrDescription attributeValueClassName]);
    
    if ([value isKindOfClass:[NSNull class]]) value = nil;
    if (![attrDescription isOptional] && !value) {
        THRequiredNilPropertyWarning(normalizedAttribute);
    } else {
        [self willChangeValueForKey:normalizedAttribute];
        [self setValue:[propertyClass deserialize:value] forKey:normalizedAttribute];
        [self didChangeValueForKey:normalizedAttribute];
    }
}

- (void)buildRelationshipsWithRelationshipDescription:(NSRelationshipDescription *)relationshipDescription payloadRelation:(id)payload error:(NSError **)error
{
    if ([relationshipDescription isToMany]) {
        [self buildToManyRelationship:payload
                                class:NSClassFromString([[relationshipDescription destinationEntity] name])
                              keyPath:[relationshipDescription name]
                                error:error];
    } else {
        [self buildToOneRelationshipWithObject:payload
                                         class:NSClassFromString([[relationshipDescription destinationEntity] name])
                                       keyPath:[relationshipDescription name]
                                         error:error];
    }
}

- (void)buildToOneRelationshipWithObject:(id)entityPayload
                                   class:(Class)klass
                                 keyPath:(NSString *)keyPath
                                   error:(NSError **)error
{
    id managedObject;
    if ([entityPayload isKindOfClass:[NSDictionary class]]) {
        managedObject = [klass entityForServerSidePayload:(NSDictionary *)entityPayload context:self.managedObjectContext];
        [managedObject updateInstanceWithJSONResponse:[klass childPayloadForPayload:entityPayload]
                                                error:error];
    } else if ([entityPayload isKindOfClass:[NSNumber class]]) {
        managedObject = [klass entityForServerSidePayload:@{[klass remoteIndexKey] : entityPayload}
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
                [managedObject updateInstanceWithJSONResponse:[klass childPayloadForPayload:childInfo] error:error];
                [children addObject:managedObject];
            }
        } else if ([childObject isKindOfClass:[NSNumber class]]) {
            [children addObject:[klass entityForServerSidePayload:@{[[self class] remoteIndexKey] : childObject} context:self.managedObjectContext]];
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

+ (NSDictionary *)childPayloadForPayload:(NSDictionary *)payload
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

+ (NSString *)remoteClassName
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

#pragma mark -
#pragma mark Private Instance Calls

+ (id)propertyClass:(NSString *)className {
	return NSClassFromString([className capitalizedString]);
}

+ (id)entityForServerSidePayload:(NSDictionary *)payload
                         context:(NSManagedObjectContext *)context
{
    NSNumber *indexedId = payload[[self remoteIndexKey]];
    if ([payload objectForKey:[self sentinelKeyForClass]]) return nil;
    
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[entity name]];
    
    if (indexedId) {
        NSString *strPred       = [NSString stringWithFormat:@"%@ == %@", [self localIndexKey], indexedId];
        NSPredicate *predicate  = [NSPredicate predicateWithFormat:strPred];
        [request setPredicate:predicate];
    }
    
    [request setFetchLimit:1];
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:request error:&error];
    NSManagedObject *returnObject;
    NSAssert(results, @"core data failure");
    if ([results count] == 0) {
        returnObject = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([self class]) inManagedObjectContext:context];
        if (indexedId) [returnObject setValue:indexedId forKey:[self localIndexKey]];
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

+ (NSString *)normalizeRemoteProperty:(NSString *)remoteProperty {
    if ([remoteProperty isEqualToString:[self remoteIndexKey]]) {
        return [NSString stringWithFormat:@"%@Id", [NSStringFromClass([self class]) lowercaseString]];
    } else {
        return [self convertRemoteKeyToLocalPropertyValue:remoteProperty];
    }
}

+ (NSString *)convertRemoteKeyToLocalPropertyValue:(NSString *)remoteKey
{
    if (!remoteKey || remoteKey.length == 0) {
        return remoteKey;
    } else {
        if (__remoteNamingConvention == THAutoMapperRemoteNamingUnderscore) {
            return [self convertUnderscoredProperty:remoteKey];
        } else if (__remoteNamingConvention == THAutoMapperRemoteNamingPascalCase) {
            return [self convertPascalCaseProperty:remoteKey];
        } else {
            return remoteKey;
        }
    }
}

+ (NSString *)convertUnderscoredProperty:(NSString *)underscoredProperty
{
    NSArray *components = [underscoredProperty componentsSeparatedByString:@"_"];
    NSMutableString *output = [NSMutableString string];
    
    BOOL firstLetterOfPropertyReached = NO;
    for (NSUInteger i = 0; i < components.count; i++) {
        if ([components[i] length] == 0) continue;
        if (i == 0 || !firstLetterOfPropertyReached) {
            [output appendString:components[i]];
            firstLetterOfPropertyReached = YES;
        } else {
            [output appendString:[components[i] capitalizedString]];
        }
    }
    
    return [NSString stringWithString:output];
}

+ (NSString *)convertPascalCaseProperty:(NSString *)property
{
    NSRange firstCharacter = {0, 1};
    NSString *firstLetter = [[property substringWithRange:firstCharacter] lowercaseString];
    
    if (property.length > 1) {
        NSRange theRest = {1, property.length - 1};
        return [NSMutableString stringWithFormat:@"%@%@", firstLetter, [property substringWithRange:theRest]];
    } else {
        return firstLetter;
    }
}

- (NSDictionary *)propertyMappingOverrides
{
    return @{};
}

+ (NSString *)remoteIndexKey
{
    return @"id";
}

+ (NSString *)localIndexKey
{
    return [NSString stringWithFormat:@"%@Id", [NSStringFromClass([self class]) lowercaseString]];
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

+ (void)setJSONParsingMethod:(THAutoMapperParseMethod)parsingMethod
{
    if (__topLevelClassNameInPayload != parsingMethod) {
        __topLevelClassNameInPayload = parsingMethod;
    }
}

+ (THAutoMapperParseMethod)JSONParsingMethod
{
    return __topLevelClassNameInPayload;
}

+ (void)setRemoteNamingConvention:(THAutoMapperRemoteNaming)namingConvention
{
    if (__remoteNamingConvention != namingConvention) {
        __remoteNamingConvention = namingConvention;
    }
}

+ (THAutoMapperRemoteNaming)remoteNamingConvention
{
    return __remoteNamingConvention;
}

+ (void)setSentinelPropertyName:(NSString *)propertyName
{
    if (__sentinelPropertyName != propertyName) {
        __sentinelPropertyName = propertyName;
    }
}

+ (NSString *)sentinelPropertyName:(NSString *)propertyName
{
    return __sentinelPropertyName;
}

/*
 NSNumber encodings
 https://developer.apple.com/library/mac/documentation/cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 */

@end


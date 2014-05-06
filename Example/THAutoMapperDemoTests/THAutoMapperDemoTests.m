//
//  THAutoMapperDemoTests.m
//  THAutoMapperDemoTests
//
//  Created by Taylor Halliday on 4/8/14.
//
//

#import <XCTest/XCTest.h>
#import "Dog.h"
#import "User.h"
#import "THAppDelegate.h"
#import "THSamplePayloads.h"
#import "NSManagedObject+THAutoMapper.h"
#import "User+THAutoMapperTest.h"
#import "Dog.h"
#import "Cat.h"

@interface THAutoMapperDemoTests : XCTestCase

@property (nonatomic, strong) THAppDelegate *appDelegate;
@property (nonatomic, strong) NSManagedObjectContext *context;

@end

@implementation THAutoMapperDemoTests

- (void)setUp
{
    [super setUp];
    self.appDelegate = (THAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.context = self.appDelegate.managedObjectContext;
}

- (void)tearDown
{
    [super tearDown];
    [self flushAllModels];
}

- (void)saveManagedObjectContext
{
    NSError *saveError;
    [self.context save:&saveError];
    XCTAssertNil(saveError, @"There was an error in the core data save");
}

- (void)flushAllModels
{
    [self deleteAllUsers];
    [self deleteAllDogs];
    [self saveManagedObjectContext];
}

- (void)deleteAllUsers
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"User"];
    [fetchRequest setIncludesPropertyValues:NO];
    NSError *fetchError;
    NSArray *users = [self.context executeFetchRequest:fetchRequest error:&fetchError];
    for (User *user in users) {
        [self.context deleteObject:user];
    }
}

- (void)deleteAllDogs
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Dog"];
    [fetchRequest setIncludesPropertyValues:NO];
    NSError *fetchError;
    NSArray *dogs = [self.context executeFetchRequest:fetchRequest error:&fetchError];
    for (Dog *dog in dogs) {
        [self.context deleteObject:dog];
    }
}

- (void)testSingleUserEntityPayloadWithClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithClassPrefix];
    User *user = (User *)[NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:self.context];
    NSDictionary *testDictionary = [THSamplePayloads singleUserEntityPayloadWithClassNamePrefixed];
    NSError *updateError;
    [user updateInstanceWithJSONResponse:testDictionary error:&updateError];
    [self saveManagedObjectContext];
    
    NSDictionary *prefixedDictionary = testDictionary[@"user"];
    XCTAssertNil(updateError, @"There was an error with the update process");
    XCTAssertEqualObjects(user.firstName, prefixedDictionary[@"firstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, prefixedDictionary[@"lastName"], @"User last name was not saved correctly");
    NSLog(@"%s", [user.height objCType]);
    XCTAssert([user.height floatValue] == [prefixedDictionary[@"height"] floatValue], @"User height was not saved correctly");
    XCTAssertEqualObjects(user.userId, prefixedDictionary[@"id"], @"User ID was not saved correctly");
}

- (void)testSingleUserEntityPayloadWithoutClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    
    User *user = (User *)[NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:self.context];
    NSDictionary *testDictionary = [THSamplePayloads singleUserEntityPayloadWithoutClassNamePrefixed];
    NSError *updateError;
    [user updateInstanceWithJSONResponse:testDictionary error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    XCTAssertEqualObjects(user.firstName, testDictionary[@"firstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDictionary[@"lastName"], @"User last name was not saved correctly");
    XCTAssert([user.height floatValue] == [testDictionary[@"height"] floatValue], @"User height was not saved correctly");
    XCTAssertEqualObjects(user.userId, testDictionary[@"id"], @"User id name was not saved correctly");
}

- (void)testMultipleUserEntityPayloadWithoutClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUserEntityPayloadWithoutClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"lastName"], @"User last name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"id"], @"User id name was not saved correctly");
    }
}

- (void)testMultipleUserEntityPayloadWithClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUserEntityPayloadWithClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"user"][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"user"][@"lastName"], @"User last name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"user"][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"user"][@"id"], @"User id name was not saved correctly");
    }
}

- (void)testMultipleUsersAndSubEntitiesPayloadWithoutClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUsersWithSubentityPayloadWithoutClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"lastName"], @"User first name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"id"], @"User id name was not saved correctly");
        XCTAssertEqualObjects(user.dog.birthday, [self RFC3339DeserializationFromString:testArray[i][@"dog"][@"birthday"]], @"Dog birthday was not saved correctly");
        XCTAssertEqualObjects(user.dog.breed, testArray[i][@"dog"][@"breed"], @"Dog breed was not saved correctly");
        XCTAssertEqualObjects(user.dog.dogId, testArray[i][@"dog"][@"id"], @"Dog id was not saved correctly");
        XCTAssertEqualObjects(user.dog.mutt, testArray[i][@"dog"][@"mutt"], @"Dog mutt was not saved correctly");
        XCTAssertEqualObjects(user.dog.name, testArray[i][@"dog"][@"name"], @"Dog name was not saved correctly");
        XCTAssert([user.dog.weight floatValue] == [testArray[i][@"dog"][@"weight"] floatValue], @"Dog weight was not saved correctly");
    }
}

- (void)testMultipleUsersAndSubEntitiesPayloadWithClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUsersWithSubentityPayloadWithClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"user"][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"user"][@"lastName"], @"User first name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"user"][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"user"][@"id"], @"User id name was not saved correctly");
        XCTAssertEqualObjects(user.dog.birthday, [self RFC3339DeserializationFromString:testArray[i][@"user"][@"dog"][@"birthday"]], @"Dog birthday was not saved correctly");
        XCTAssertEqualObjects(user.dog.breed, testArray[i][@"user"][@"dog"][@"breed"], @"Dog breed was not saved correctly");
        XCTAssertEqualObjects(user.dog.dogId, testArray[i][@"user"][@"dog"][@"id"], @"Dog id was not saved correctly");
        XCTAssertEqualObjects(user.dog.mutt, testArray[i][@"user"][@"dog"][@"mutt"], @"Dog mutt was not saved correctly");
        XCTAssertEqualObjects(user.dog.name, testArray[i][@"user"][@"dog"][@"name"], @"Dog name was not saved correctly");
        XCTAssert([user.dog.weight floatValue] == [testArray[i][@"user"][@"dog"][@"weight"] floatValue], @"Dog weight was not saved correctly");
    }
}

- (void)testMultipleUsersWithMultipleSubentitiesPayloadWithClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUsersWithMultipleSubentitiesPayloadWithClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"user"][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"user"][@"lastName"], @"User first name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"user"][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"user"][@"id"], @"User id name was not saved correctly");
        XCTAssertEqualObjects([[user.cats anyObject] birthday], [self RFC3339DeserializationFromString:[testArray[i][@"user"][@"cats"] lastObject][@"birthday"]], @"Cat birthday was not saved correctly");
        XCTAssertEqualObjects([[user.cats anyObject] name], [testArray[i][@"user"][@"cats"] lastObject][@"name"], @"Cat name was not saved correctly");
        XCTAssert([[[user.cats anyObject] weight] floatValue] == [[testArray[i][@"user"][@"cats"] lastObject][@"weight"] floatValue], @"Cat weight was not saved correctly");
    }
}

- (void)testMultipleUsersWithMultipleSubentitiesPayloadWithoutClassNamePrefixed
{
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    
    NSArray *testArray = [THSamplePayloads multipleUsersWithMultipleSubentitiesPayloadWithoutClassNamePrefixed];
    NSError *updateError = nil;
    NSArray *responseBatch = [User updateBatchWithJSONResponse:testArray context:self.context error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    for (int i = 0; i < testArray.count; i++) {
        User *user = responseBatch[i];
        NSLog(@"%@", user.firstName);
        XCTAssertEqualObjects(user.firstName, testArray[i][@"firstName"], @"User first name was not saved correctly");
        XCTAssertEqualObjects(user.lastName, testArray[i][@"lastName"], @"User first name was not saved correctly");
        XCTAssert([user.height floatValue] == [testArray[i][@"height"] floatValue], @"User height was not saved correctly");
        XCTAssertEqualObjects(user.userId, testArray[i][@"id"], @"User id name was not saved correctly");
        XCTAssertEqualObjects([[user.cats anyObject] birthday], [self RFC3339DeserializationFromString:[testArray[i][@"cats"] lastObject][@"birthday"]], @"Cat birthday was not saved correctly");
        XCTAssertEqualObjects([[user.cats anyObject] name], [testArray[i][@"cats"] lastObject][@"name"], @"Cat name was not saved correctly");
        XCTAssert([[[user.cats anyObject] weight] floatValue] == [[testArray[i][@"cats"] lastObject][@"weight"] floatValue], @"Cat weight was not saved correctly");
    }
}

#pragma mark - Associations through index key instead of dictionary

/**
 *  Some web servers prefer to send a list of unique ids instead of full object
 *  dictionaries for speed and size of payload. THAutoMapper should handle
 *
 *  EX: { "user" : { "firstName" : "Tay", "cats" : [33,34,56,21] } }
 *
 */

- (void)testObjectWithToOneAssoicationThroughUniqueIds
{
    NSDictionary *testDict = [THSamplePayloads objectWithToOneAssoicationThroughUniqueIds];
    NSError *updateError = nil;
    User *user = [User createInstanceWithJSONResponse:testDict context:self.context error:&updateError];
    [self saveManagedObjectContext];
    XCTAssertEqualObjects(user.firstName, testDict[@"firstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDict[@"lastName"], @"User first name was not saved correctly");
    XCTAssert([user.height floatValue] == [testDict[@"height"] floatValue], @"User height was not saved correctly");
    XCTAssertEqualObjects(user.userId, testDict[@"id"], @"User id name was not saved correctly");
    XCTAssertEqualObjects(user.birthday, [self RFC3339DeserializationFromString:testDict[@"birthday"]], @"User birthday was not saved correctly");
    XCTAssertEqualObjects([user.dog dogId], testDict[@"dog"], @"Dog ID name was not saved correctly");
}

- (void)testObjectWithToManyAssoicationsThroughUniqueIds
{
    NSDictionary *testDict = [THSamplePayloads objectWithToManyAssoicationsThroughUniqueIds];
    NSError *updateError = nil;
    User *user = [User createInstanceWithJSONResponse:testDict context:self.context error:&updateError];
    [self saveManagedObjectContext];
    XCTAssertEqualObjects(user.firstName, testDict[@"firstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDict[@"lastName"], @"User first name was not saved correctly");
    XCTAssert([user.height floatValue] == [testDict[@"height"] floatValue], @"User height was not saved correctly");
    XCTAssertEqualObjects(user.userId, testDict[@"id"], @"User id name was not saved correctly");
    XCTAssertEqualObjects(user.birthday, [self RFC3339DeserializationFromString:testDict[@"birthday"]], @"User birthday was not saved correctly");

    NSArray *catIds = testDict[@"cats"];
    
    // Ensuring the same number of cats
    XCTAssert(user.cats.count == [catIds count]);
    
    // Checking for ID membership. Combined with the count test, this checks for full membership
    
    for (Cat *kitty in user.cats) {
        XCTAssertTrue([catIds containsObject:kitty.catId], @"Could not find Cat Id in payload");
    }
}

#pragma mark - Testing nil/Null values

- (void)testObjectWithNullValues
{
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    
    NSDictionary *testDict = [THSamplePayloads objectWithNullValues];
    NSError *updateError = nil;
    User *user = [User createInstanceWithJSONResponse:testDict context:self.context error:&updateError];
    [self saveManagedObjectContext];
    XCTAssertEqualObjects(user.firstName, testDict[@"firstName"], @"User first name was not saved correctly");
    XCTAssertNil(user.lastName, @"User last name is not nil");
    XCTAssertNil(user.height, @"User height is not nil");
    XCTAssertEqualObjects(user.userId, testDict[@"id"], @"User id name was not saved correctly");
    XCTAssertEqualObjects(user.birthday, [self RFC3339DeserializationFromString:testDict[@"birthday"]], @"User birthday was not saved correctly");
}

#pragma mark - Testing naming conventions

- (void)testObjectWithCamelCaseRemoteNamingConvention
{
    [User setRemoteNamingConvention:THAutoMapperRemoteNamingUnderscore];
    NSDictionary *testDict = [THSamplePayloads objectCamelCaseNamingConvention];
    NSError *updateError = nil;
    User *user = [User createInstanceWithJSONResponse:testDict context:self.context error:&updateError];
    [self saveManagedObjectContext];
    XCTAssertEqualObjects(user.firstName, testDict[@"first_name"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDict[@"_last__name_"], @"User last name was not saved correctly");
    XCTAssert([user.height floatValue] == [testDict[@"__height"] floatValue], @"User height is not nil");
    XCTAssertEqualObjects(user.userId, testDict[@"id"], @"User id name was not saved correctly");
    XCTAssertEqualObjects(user.birthday, [self RFC3339DeserializationFromString:testDict[@"__birthday__"]], @"User birthday was not saved correctly");
}

- (void)testObjectWithPascalCaseRemoteNamingConvention
{
    [User setRemoteNamingConvention:THAutoMapperRemoteNamingPascalCase];
    NSDictionary *testDict = [THSamplePayloads objectPascalCaseNamingConvention];
    NSError *updateError = nil;
    User *user = [User createInstanceWithJSONResponse:testDict context:self.context error:&updateError];
    [self saveManagedObjectContext];
    XCTAssertEqualObjects(user.firstName, testDict[@"FirstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDict[@"LastName"], @"User last name was not saved correctly");
    XCTAssert([user.height floatValue] == [testDict[@"Height"] floatValue], @"User height is not nil");
    XCTAssertEqualObjects(user.userId, testDict[@"id"], @"User id name was not saved correctly");
    XCTAssertEqualObjects(user.birthday, [self RFC3339DeserializationFromString:testDict[@"Birthday"]], @"User birthday was not saved correctly");
}


#pragma mark - Private Helpers

/**
 *  ISO8601 Date Helper
 */

- (NSDate *)RFC3339DeserializationFromString:(NSString *)dateStr
{
    static NSDateFormatter *__THAutoMapperDateFormatter;
    if (!__THAutoMapperDateFormatter) {
        __THAutoMapperDateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [__THAutoMapperDateFormatter setLocale:enUSPOSIXLocale];
        [__THAutoMapperDateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [__THAutoMapperDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    }
    
    return [__THAutoMapperDateFormatter dateFromString:dateStr];
}


/*
 ToDo
 Property Name Overides
 Index Key Overide
 Sclarar Value
 Transient Values
 */

@end

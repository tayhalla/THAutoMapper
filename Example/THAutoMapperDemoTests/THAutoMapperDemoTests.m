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
    [User setJSONParsingMethod:THAutoMapperParseWithoutClassPrefix];
    User *user = (User *)[NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:self.context];
    NSDictionary *testDictionary = [THSamplePayloads singleUserEntityPayloadWithClassNamePrefixed];
    NSError *updateError;
    [user updateInstanceWithJSONResponse:testDictionary error:&updateError];
    [self saveManagedObjectContext];
    
    XCTAssertNil(updateError, @"There was an error with the update process");
    XCTAssertEqualObjects(user.firstName, testDictionary[@"firstName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.lastName, testDictionary[@"lastName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.height, testDictionary[@"height"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.userId, testDictionary[@"id"], @"User first name was not saved correctly");
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
    XCTAssertEqualObjects(user.lastName, testDictionary[@"lastName"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.height, testDictionary[@"height"], @"User first name was not saved correctly");
    XCTAssertEqualObjects(user.userId, testDictionary[@"id"], @"User first name was not saved correctly");
}

@end

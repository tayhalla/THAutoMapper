//
//  User.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 4/20/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "NSManagedObject+THAutoMapper.h"

@interface User : NSManagedObject

@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSString * userId;
@property (nonatomic, retain) NSSet *dog;
@end

@interface User (CoreDataGeneratedAccessors)

- (void)addDogObject:(NSManagedObject *)value;
- (void)removeDogObject:(NSManagedObject *)value;
- (void)addDog:(NSSet *)values;
- (void)removeDog:(NSSet *)values;

@end

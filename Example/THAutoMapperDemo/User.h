//
//  User.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/6/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Cat, Dog;

@interface User : NSManagedObject

@property (nonatomic, retain) NSDate * birthday;
@property (nonatomic, retain) NSString * firstName;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSString * lastName;
@property (nonatomic, retain) NSNumber * userId;
@property (nonatomic, retain) NSSet *cats;
@property (nonatomic, retain) Dog *dog;
@end

@interface User (CoreDataGeneratedAccessors)

- (void)addCatsObject:(Cat *)value;
- (void)removeCatsObject:(Cat *)value;
- (void)addCats:(NSSet *)values;
- (void)removeCats:(NSSet *)values;

@end

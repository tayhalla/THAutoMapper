//
//  Cat.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/5/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class User;

@interface Cat : NSManagedObject

@property (nonatomic, retain) NSDate * birthday;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * weight;
@property (nonatomic, retain) NSNumber * catId;
@property (nonatomic, retain) User *owner;

@end

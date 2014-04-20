//
//  Dog.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 4/20/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class User;

@interface Dog : NSManagedObject

@property (nonatomic, retain) NSDate * birthday;
@property (nonatomic, retain) NSString * breed;
@property (nonatomic, retain) NSNumber * dogId;
@property (nonatomic, retain) NSString * favoriteChow;
@property (nonatomic, retain) NSString * favoriteToy;
@property (nonatomic, retain) NSNumber * mutt;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * weight;
@property (nonatomic, retain) User *owner;

@end

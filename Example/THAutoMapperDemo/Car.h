//
//  Car.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/6/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Car : NSManagedObject

@property (nonatomic, retain) NSNumber * carId;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * make;
@property (nonatomic, retain) NSNumber * year;

@end

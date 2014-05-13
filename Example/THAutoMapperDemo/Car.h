//
//  Car.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/12/14.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Car : NSManagedObject

@property (nonatomic, retain) NSNumber * carId;
@property (nonatomic, retain) NSString * make;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * year;
@property (nonatomic, retain) NSString * custom_attribute;

@end

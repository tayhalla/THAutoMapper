//
//  NSManagedObject+GathrCoreDataSupport.h
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface NSManagedObject (GathrCoreDataSupport)

- (void)updateInstanceWithJSONResponse:(NSDictionary *)jsonResponse error:(NSError **)error;
- (BOOL)existsOnServer;

@end

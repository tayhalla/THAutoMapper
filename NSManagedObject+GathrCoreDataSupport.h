//
//  NSManagedObject+GathrCoreDataSupport.h
//  GatherApp
//
//  Created by Taylor Halliday on 2/28/13.
//  Copyright (c) 2013 GatherInc. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import "GathrCoreData.h"
#import "Serialize.h"
#import "AppDelegate.h"
#import "GatherCredentialStore.h"
#import "SVProgressHUD.h"
#import "NSObject+PropertySupport.h"

@interface NSManagedObject (GathrCoreDataSupport)

- (BOOL)updateInstanceWithJSONResponse:(NSDictionary *)jsonResponse error:(NSError **)error;
- (BOOL)existsOnServer;

@end

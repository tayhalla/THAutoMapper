//
//  THAutoMapperOptionsAndHelpers.h
//  THAutoMapperDemo
//
//  Created by Taylor Halliday on 5/5/14.
//
//

#ifndef THAutoMapperDemo_THAutoMapperOptionsAndHelpers_h
#define THAutoMapperDemo_THAutoMapperOptionsAndHelpers_h

/**
 *  Debug macros for letting the user know when a potential error has occured.
 */
#define THLog(fmt, ...) NSLog((@"THAutoMapper Warning: " fmt), ##__VA_ARGS__)
#define THRequiredNilPropertyWarning(attr) THLog(@"A NULL value for a non-optional property (%@) was passed in the provided payload.\nTHAutoMapper will skip.", attr)
#define THPropertyMismatchWarning(attr) THLog(@"Unable to map the (%@) remote property to a local property.\nTHAutoMapper will skip.", attr)

/**
 *  Enumerator for remote naming conventions
 */
typedef NS_ENUM(NSUInteger, THAutoMapperRemoteNaming) {
    /**
     * *** DEFAULT OPTION ***
     * This parsing method assumes that the JSON payload's properties
     * are in camelCase.
     *
     * Ex: iAmACamelCaseProperty
     */
    THAutoMapperRemoteNamingCamelCase,
    /**
     * This parsing method assumes that the JSON payload's properties
     * are in PascalCase.
     *
     * Ex: PascalCaseIsFun
     */
    THAutoMapperRemoteNamingPascalCase,
    /**
     * This parsing method assumes that the JSON payload's properties
     * are in under_score conventions.
     *
     * Ex: ruby_loves_underscores
     */
    THAutoMapperRemoteNamingUnderscore
};

/**
 *  Enumerator for the different parsing methods available.
 */
typedef NS_ENUM(NSUInteger, THAutoMapperParseMethod) {
    /**
     * *** DEFAULT OPTION ***
     * This parsing method assumes that the JSON payload is NOT prefixed
     * with a class name. EX: a user object's incomming json payload
     * { "firstName" : "Taylor",
     *   "lastName"  : "Halliday"}
     *
     */
    THAutoMapperParseWithoutClassPrefix,
    /**
     * This parsing method assumes that the JSON payload is prefixed
     * with a class name. EX: a user object's incomming json payload
     * { "user": {
     *     "firstName" : "Taylor",
     *     "lastName"  : "Halliday"
     *   }
     * }
     */
    THAutoMapperParseWithClassPrefix
};

#endif

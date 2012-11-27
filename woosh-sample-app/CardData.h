//
//  CardData.h
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CardData : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *value;

+ (CardData *) initWithValue:(NSString *)name value:(NSString *)value;

@end

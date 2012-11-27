//
//  CardData.m
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "CardData.h"

@implementation CardData

@synthesize name;
@synthesize value;

+ (CardData *) initWithValue:(NSString *)key value:(NSString *)val {
    CardData *instance = [[CardData alloc] init];
    
    [instance setName:key];
    [instance setValue:val];
    
    return instance;
}

@end

//
//  Woosh.h
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WooshSynchronizationDelegate <NSObject>

@optional
- (void) synchronizeBegan;
- (void) synchronizeEnded;

@end

@interface Woosh : NSObject

@property NSMutableData *receivedData;
@property NSURLConnection *connection;

@property NSMutableDictionary *systemProperties;

// these are the models that the Woosh client-side library keeps
// all entities are kept as dictionaries
@property (strong, nonatomic) NSMutableArray *cards;
@property (strong, nonatomic) NSMutableArray *cardData;
@property (strong, nonatomic) NSMutableArray *offers;
@property (strong, nonatomic) NSMutableArray *scans;

// this is the currently selected card
// TODO refactor this to not be a global variable - but it works in this app
@property (strong, nonatomic) NSMutableDictionary *selectedCard;

// the user's most recent location
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;

@property (retain) id<WooshSynchronizationDelegate> delegate;


// the singleton Woosh services instance
+ (Woosh *) woosh;

// utility method for generating Woosh-format date-time strings from an NSDate
- (NSString *) dateAsDateTimeString:(NSDate *)date;
- (NSDate *) stringAsDateTime:(NSString *)date;

- (NSString *) username;

- (NSMutableArray *) nonDeletedCards;

// allows a user to publish a Woosh card
- (void) publishCard:(NSString *)name data:(NSArray *)data;

// allows a user to make an offer for a Woosh card
- (void) makeOffer:(NSDictionary *)card;

// perform a scan (an 'up woosh')
- (void) scan;

// tells the Woosh service to synchornize with the Woosh servers
- (void) synchronize;


@end

//
//  Woosh.m
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "Woosh.h"
#import "CardData.h"

@implementation Woosh

static NSDateFormatter *dateTimeFormatter;

static int DEFAULT_OFFER_PERIOD = 300;            // seconds

@synthesize cards;
@synthesize cardData;
@synthesize offers;

@synthesize selectedCard;

@synthesize latitude;
@synthesize longitude;

@synthesize systemProperties;

+ (Woosh *) woosh {
	static Woosh *instance;
	
	@synchronized(self) {
		if ( !instance ) {
			
			// create the singleton instance
			instance = [[Woosh alloc] init];

            // this prototype does not use client-side persistence so this is commented out for now
            
//            // initialise the local TouchDB server and database
//            CouchTouchDBServer* server = [CouchTouchDBServer sharedInstance];
//            if (server.error) {
//                NSLog(@"TouchDB server start-up failed! %@", server.error);
//            }
            
//            // initialise the local storage mechanism
//            mainDb = [server databaseNamed:@"main-db"];  // db name must be lowercase!
            
//            NSError* error;
//            if ( ![mainDb ensureCreated:&error] ) {
//                NSLog(@"TouchDB database creation failed! %@", [error localizedDescription]);
//            }
            
            dateTimeFormatter = [[NSDateFormatter alloc] init];
			[dateTimeFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSz"];
            
            // initialise the data models
            instance.cards = [NSMutableArray array];
            instance.cardData = [NSMutableArray array];
            instance.offers = [NSMutableArray array];
            instance.scans = [NSMutableArray array];
        }
	}
	
	return instance;
}

- (NSString *) dateAsDateTimeString:(NSDate *)date {
	return [dateTimeFormatter stringFromDate:date];
}

- (NSDate *) stringAsDateTime:(NSString *)date {
    return [dateTimeFormatter dateFromString:date];
}

- (NSString *) username {
    return [self.systemProperties objectForKey:@"username"];
}

+ (NSString *) uuid {
	CFUUIDRef uuidObj = CFUUIDCreate(nil);
	
	NSString *uuidString = (__bridge NSString *) CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	
	return uuidString;
}

- (NSMutableArray *) nonDeletedCards {
    // return non-deleted cards
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *c in self.cards) {
        if ([[c objectForKey:@"deleted"] caseInsensitiveCompare:@"false"] == NSOrderedSame) {
            [result addObject:c];
        }
    }
    return result;
}

- (NSMutableDictionary *) newWooshEntity {
    NSString *now = [[Woosh woosh] dateAsDateTimeString:[NSDate date]];
    
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            @"-1", @"clientVersion",
            now, @"lastUpdated",
            @"false", @"deleted",
            [Woosh uuid], @"clientId",
            nil];
}


- (void) publishCard:(NSString *)name data:(NSArray *)data {
    NSMutableDictionary *newCard = [[Woosh woosh] newWooshEntity];
    NSString *cardId = [newCard objectForKey:@"clientId"];
    
    // populate the dictionary with required for a Woosh card
    [newCard setObject:name forKey:@"name"];
    
    // for each data item, create a CardData entity for the server to hold against the card
    NSMutableDictionary *cardDataDict = nil;
    for (CardData* datum in data) {
        cardDataDict = [[Woosh woosh] newWooshEntity];
        
        [cardDataDict setObject:datum.name forKey:@"name"];
        [cardDataDict setObject:datum.value forKey:@"data"];
        [cardDataDict setObject:cardId forKey:@"card"];
        
        // store the card data locally
        [self.cardData addObject:cardDataDict];
    }
    
    // add the card data to the card dictionary
    [newCard setObject:cardDataDict forKey:@"data"];
    
    // store the card locally
    [self.cards addObject:newCard];
}

- (void) makeOffer:(NSDictionary *)card {
    NSMutableDictionary *newOffer = [[Woosh woosh] newWooshEntity];

    // create the WKT representation of the user's current location
    NSString *wktLocationString = [NSString stringWithFormat:@"POINT(%.6f %.6f)", self.latitude, self.longitude];
    
    NSDate *now = [NSDate date];
    
    [newOffer setObject:[card objectForKey:@"clientId"] forKey:@"card"];
    [newOffer setObject:[self dateAsDateTimeString:now] forKey:@"offerStart"];
    [newOffer setObject:[self dateAsDateTimeString:[now dateByAddingTimeInterval:DEFAULT_OFFER_PERIOD]] forKey:@"offerEnd"];
    [newOffer setObject:wktLocationString forKey:@"offerRegion"];
    
    // store the offer
    [self.offers addObject:newOffer];
}

- (void) scan {

    NSMutableDictionary *newScan = [[Woosh woosh] newWooshEntity];
    
    // create the WKT representation of the user's current location
    NSString *wktLocationString = [NSString stringWithFormat:@"POINT(%.6f %.6f)", self.latitude, self.longitude];
    
    [newScan setObject:[self dateAsDateTimeString:[NSDate date]] forKey:@"scannedAt"];
    [newScan setObject:wktLocationString forKey:@"location"];
    
    // store the offer
    [self.scans addObject:newScan];

}

- (void) synchronize {
    
    // note that this is a sub-optimal entity sync method as currently it has to locate out-of-sync
    // entities within the various in-memory document dictionarys
    // a much better solution would be to use a document store like CouchDB and use map functions
    // to find all out-of-date documents
    
    // the first thing that we do is notify any delegates that we are starting the sync op
    if (self.delegate != nil) {
        if ( [self.delegate respondsToSelector:@selector(synchronizeBegan)] ) {
            [self.delegate synchronizeBegan];            
        }
    }
    
    NSString *lastUpdated = [systemProperties objectForKey:@"lastUpdated"];
    NSDate *lastUpdatedAsDate = [self stringAsDateTime:lastUpdated];

    // create the data payload that we want to post
    NSMutableDictionary *allOutOfSyncEntities = [NSMutableDictionary dictionary];

    // ----
    // find out of sync card entities
    // ----
    NSMutableArray *outOfDateCards = [NSMutableArray array];
    for (NSDictionary *card in self.cards) {
        NSDate *cardLastUpdated = [self stringAsDateTime:[card objectForKey:@"lastUpdated"]];
        
        if ( [cardLastUpdated compare:lastUpdatedAsDate] == NSOrderedDescending ) {
            [outOfDateCards addObject:card];
        }
    }
    [allOutOfSyncEntities setObject:outOfDateCards forKey:@"cards"];
    // ----

    
    // ----
    // find out of sync card data entities
    // ----
    NSMutableArray *outOfDateCardData = [NSMutableArray array];
    for (NSDictionary *datum in self.cardData) {
        NSDate *cardDataLastUpdated = [self stringAsDateTime:[datum objectForKey:@"lastUpdated"]];
        
        if ( [cardDataLastUpdated compare:lastUpdatedAsDate] == NSOrderedDescending ) {
            [outOfDateCardData addObject:datum];
        }
    }
    [allOutOfSyncEntities setObject:outOfDateCardData forKey:@"carddata"];
    // ----


    // ----
    // find out of sync offer entities
    // ----
    NSMutableArray *outOfDateOffers = [NSMutableArray array];
    for (NSDictionary *offer in self.offers) {
        NSDate *offerLastUpdated = [self stringAsDateTime:[offer objectForKey:@"lastUpdated"]];
        
        if ( [offerLastUpdated compare:lastUpdatedAsDate] == NSOrderedDescending ) {
            [outOfDateOffers addObject:offer];
        }
    }
    [allOutOfSyncEntities setObject:outOfDateOffers forKey:@"offers"];
    // ----

    
    // ----
    // find out of sync scan entities
    // ----
    NSMutableArray *outOfDateScans = [NSMutableArray array];
    for (NSDictionary *scan in self.scans) {
        NSDate *scanLastUpdated = [self stringAsDateTime:[scan objectForKey:@"lastUpdated"]];
        
        if ( [scanLastUpdated compare:lastUpdatedAsDate] == NSOrderedDescending ) {
            [outOfDateScans addObject:scan];
        }
    }
    [allOutOfSyncEntities setObject:outOfDateScans forKey:@"scans"];
    // ----

    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:allOutOfSyncEntities options:NSJSONWritingPrettyPrinted error:nil];
    NSString *payload = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
	NSString *endpoint = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"SyncEndpoint"];
    NSString *schemaEndpoint = [endpoint stringByAppendingPathComponent:@"data"];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:schemaEndpoint]
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:60.0];
    
    NSString *post = [NSString stringWithFormat:@"v=1.0&p=0&ts=%@&payload=%@", lastUpdated, payload];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    
    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:postData];
    
    self.connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
    
    if (self.connection != nil) {
        self.receivedData = [NSMutableData data];
    }
    
    [self.connection start];
    
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {

    // deal with the authentication challenge
    
    if ([challenge previousFailureCount] > 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Authentication Error"
                                                        message:@"Invalid credentials provided."
                                                       delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
    } else {
        
        // we answer the challenge with the username and password provided by the user at login
        NSString *username = [systemProperties objectForKey:@"username"];
        NSString *password = [systemProperties objectForKey:@"password"];
        
        NSURLCredential *cred = [[NSURLCredential alloc] initWithUser:username password:password                                                                            persistence:NSURLCredentialPersistenceForSession];
        
        [[challenge sender] useCredential:cred forAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSLog(@"Succeeded! Received %d bytes of data", [self.receivedData length]);
    
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:self.receivedData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
    
    if (error != nil) {
        NSLog(@"%@", [error localizedDescription]);
        NSLog(@"%@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
        return;
    }
    
    if ( [[json allKeys] containsObject:@"identity"] ) {
        
        NSString *username = [[json objectForKey:@"identity"] objectForKey:@"name"];
        NSString *lastUpdated = [[json objectForKey:@"identity"] objectForKey:@"lastUpdated"];
        
        NSString *result = [NSString stringWithFormat:@"Name: %@\r\nLast Login: %@", username, lastUpdated];
        
        UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Who Am I?"
                                                       message:result
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [view show];
        
    } else if ([[json allKeys] containsObject:@"schema"]) {
        
        NSString *result = [NSString stringWithUTF8String:[self.receivedData bytes]];
        
        UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Current Schema"
                                                       message:result
                                                      delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
        [view show];
        
    } else {
        
        NSString *result = [NSString stringWithUTF8String:[self.receivedData bytes]];
        NSLog(@"Synchronization cycle result:");
        NSLog(@"%@", result);
        
        // grab the server last updated time and set it on the local system properties dictionary
        NSString *lastUpdated = [json objectForKey:@"updateTime"];
        [systemProperties setValue:lastUpdated forKey:@"lastUpdated"];

        // we've got a new last updated time so persist it to storage
        NSURL *documentPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *systemPropertiesPath = [documentPath URLByAppendingPathComponent:@"woosh.plist"];
                
        // now process anything that came in from the server

        // first we deal with cards
        NSArray *cardsFromServer = [[json objectForKey:@"entities"] objectForKey:@"cards"];
        for (NSDictionary *serverCard in cardsFromServer) {
            NSString *serverCardId = [serverCard objectForKey:@"clientId"];
            
            // perform a merge between the server and client card sets
            
            // search for an existing client card for the server card that we are currently processing
            NSDictionary *foundClientCard = nil;
            for (NSDictionary *clientCard in self.cards) {
                NSString *clientCardId = [clientCard objectForKey:@"clientId"];
                
                if ([clientCardId caseInsensitiveCompare:serverCardId] == NSOrderedSame) {
                    foundClientCard = clientCard;
                }
            }
            
            // depending on the result of that search perform the relevant action
            if (foundClientCard == nil) {

                // if we did not find a matching client card then this card is new - add it to the list of cards
                [self.cards addObject:serverCard];

            } else {
                
                // we found a matching card - so now look at the version and store whichever is highest
                NSUInteger serverCardVersion = [[serverCard objectForKey:@"clientVersion"] intValue];
                NSUInteger clientCardVersion = [[foundClientCard objectForKey:@"clientVersion"] intValue];
                
                if (serverCardVersion >= clientCardVersion) {
                
                    // if the server card version is higher then remove to old client card and replace it
                    [self.cards removeObject:foundClientCard];
                    [self.cards addObject:serverCard];
                
                } else {
                    
                    // if the server version is lower then do nohing (the more up-to-date client card will
                    // be transmitted in the next synchronization cycle
                    NSLog(@"Info: the Woosh servers sent an out-of-card card, ignoring.");
                    
                }
            }
        }
        
        // next we deal with card data (this is a little more complex because we need to tie the card data objects
        // to their respective cards)
        NSArray *cardDataFromServer = [[json objectForKey:@"entities"] objectForKey:@"carddata"];
        for (NSDictionary *serverCardData in cardDataFromServer) {
            NSString *serverCardDataId = [serverCardData objectForKey:@"clientId"];
            
            // perform a merge between the server and client card data sets
            
            // search for an existing client card for the server card that we are currently processing
            NSDictionary *foundClientCardData = nil;
            for (NSDictionary *clientCardData in self.cardData) {
                NSString *clientCardDataId = [clientCardData objectForKey:@"clientId"];
                
                if ([clientCardDataId caseInsensitiveCompare:serverCardDataId] == NSOrderedSame) {
                    foundClientCardData = clientCardData;
                }
            }
            
            // depending on the result of that search perform the relevant action
            if (foundClientCardData == nil) {
                
                // if we did not find a matching client card then this card is new - add it to the list of cards
                [self.cardData addObject:serverCardData];
                foundClientCardData = serverCardData;
                
            } else {
                
                // we found a matching card - so now look at the version and store whichever is highest
                NSUInteger serverCardDataVersion = [[serverCardData objectForKey:@"clientVersion"] intValue];
                NSUInteger clientCardDataVersion = [[foundClientCardData objectForKey:@"clientVersion"] intValue];
                
                if (serverCardDataVersion >= clientCardDataVersion) {
                    
                    // if the server card version is higher then remove to old client card and replace it
                    [self.cardData removeObject:foundClientCardData];
                    [self.cardData addObject:serverCardData];
                    
                } else {
                    
                    // if the server version is lower then do nohing (the more up-to-date client card will
                    // be transmitted in the next synchronization cycle
                    NSLog(@"Info: the Woosh servers sent an out-of-card card data entity, ignoring.");
                    
                }
            }
            
            // when dealing with card data we need to associate it directly with it's parent card
            NSString *cardDataCardId = [foundClientCardData objectForKey:@"card"];
            for (NSMutableDictionary *c in self.cards) {
                NSString *cardId = [c objectForKey:@"clientId"];
                
                if ([cardDataCardId caseInsensitiveCompare:cardId] == NSOrderedSame) {
                    [c setObject:foundClientCardData forKey:@"data"];
                }
                
            }
        }

        // write system properties to disk
        [systemProperties writeToURL:systemPropertiesPath atomically:NO];
    }
    
    // clear the received data for the next response
    self.receivedData = [NSData data];

    // the very last thing we do is notify any delegates that we're done
    if (self.delegate != nil) {
        if ( [self.delegate respondsToSelector:@selector(synchronizeEnded)] ) {
            [self.delegate synchronizeEnded];
        }
    }
    
}

@end

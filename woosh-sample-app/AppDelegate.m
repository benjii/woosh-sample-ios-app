//
//  AppDelegate.m
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "AppDelegate.h"
#import "Woosh.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSURL *documentPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *systemPropertiesPath = [documentPath URLByAppendingPathComponent:@"woosh.plist"];
    
    // log some interesting output
    NSLog(@"Application directory: %@", [documentPath path]);
    
    NSMutableDictionary *props = nil;
    
    if ( [[NSFileManager defaultManager] fileExistsAtPath:[systemPropertiesPath path]] ) {
        
        // properties file does exist - read it.
        props = [NSMutableDictionary dictionaryWithContentsOfFile:[systemPropertiesPath path]];

        // this both instantiates the Woosh services and sets it's system properties
        [[Woosh woosh] setSystemProperties:props];
        
    } else {

        // properties file does not exist - create it
        NSString *lastUpdated = [[Woosh woosh] dateAsDateTimeString:[NSDate distantPast]];
        NSMutableDictionary *props = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObject:lastUpdated]
                                                                        forKeys:[NSArray arrayWithObject:@"lastUpdated"]];

        
        // flush the system properties file to disk
        [props writeToURL:systemPropertiesPath atomically:NO];

        // this both instantiates the Woosh services and sets it's system properties
        [[Woosh woosh] setSystemProperties:props];

        // if the properties file does not exist then neither will authentication credentials
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Secure Service" message:@"You must login to use Woosh." delegate:self cancelButtonTitle:nil otherButtonTitles:@"Login", nil];
        
        alert.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
        
        [alert show];
    }
    
    // start the location manager
    self.locationManager = [[CLLocationManager alloc] init];
    
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager startUpdatingLocation];
    
    // return that the application started without error
    return YES;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {

    CLLocation *mostRecentLocation = [locations objectAtIndex:[locations count] - 1];
    
    // store the location in the Woosh service singleton
    [[Woosh woosh] setLatitude:mostRecentLocation.coordinate.latitude];
    [[Woosh woosh] setLatitude:mostRecentLocation.coordinate.longitude];

}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 0) {
        NSString *username = [[alertView textFieldAtIndex:0] text];
        NSString *password = [[alertView textFieldAtIndex:1] text];

        NSURL *documentPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
        NSURL *systemPropertiesPath = [documentPath URLByAppendingPathComponent:@"woosh.plist"];

        NSMutableDictionary *props = [[Woosh woosh] systemProperties];
        
        // set the username and password on the system properties dictionary
        [props setObject:username forKey:@"username"];
        [props setObject:password forKey:@"password"];

        // flush the system properties file to disk
        [props writeToURL:systemPropertiesPath atomically:NO];
        
        // now that we are authenticated, perform a synchronize with the Woosh servers to get all user data
        [[Woosh woosh] synchronize];
        
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application {

}

- (void)applicationWillEnterForeground:(UIApplication *)application {

}

- (void)applicationDidBecomeActive:(UIApplication *)application {

}

- (void)applicationWillTerminate:(UIApplication *)application {
    
    // flush system properties to disk
    NSString *documentPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSString *systemPropertiesPath = [documentPath stringByAppendingPathComponent:@"woosh.plist"];
    
    [[[Woosh woosh] systemProperties] writeToFile:systemPropertiesPath atomically:YES];

}

@end

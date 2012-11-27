//
//  MainViewController.h
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "FlipsideViewController.h"
#import "Woosh.h"

@interface MainViewController : UIViewController <FlipsideViewControllerDelegate, UIPopoverControllerDelegate, UIAlertViewDelegate, UITableViewDataSource, UITableViewDelegate, WooshSynchronizationDelegate>

// the flip side of the main window
@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;

@property (strong, nonatomic) UITableView *mainCardView;


// toolbar button actions
-(void) addCardButtonTapped:(id)sender;
-(void) deleteAllButtonTapped:(id)sender;
-(void) wooshUpButtonTapped:(id)sender;

@end

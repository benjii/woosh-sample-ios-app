//
//  FlipsideViewController.m
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "FlipsideViewController.h"
#import "Woosh.h"


@interface FlipsideViewController ()

@end

@implementation FlipsideViewController

- (void)awakeFromNib {
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 480.0);
    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {

    // grab the selected card and it's data
    NSMutableDictionary *card = [Woosh woosh].selectedCard;
    NSMutableDictionary *data = [card objectForKey:@"data"];

    // set the card label to contain the data (message) on the card
    [self.lblCardData setText:[data objectForKey:@"data"]];

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction) done:(id)sender {
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (IBAction) offer:(id)sender {
    
    // make an offer on the selected card
    [[Woosh woosh] makeOffer:[[Woosh woosh] selectedCard]];
    
    // the user has just made an offer, so send it to the Woosh servers
    [[Woosh woosh] synchronize];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Offer Made" message:@"Your offer is now available." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
}

@end

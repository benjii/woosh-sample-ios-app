//
//  MainViewController.m
//  woosh-sample-app
//
//  Created by Ben on 18/11/2012.
//  Copyright (c) 2012 Luminos. All rights reserved.
//

#import "MainViewController.h"

#import "Woosh.h"
#import "CardData.h"


@interface MainViewController ()

@end

@implementation MainViewController

static int ADD_CARD_ALERT = 1;
static int DELETE_ALL_ALERT = 2;


- (void)viewDidLoad {
    [super viewDidLoad];

    // this is the frame for the toolbar
    CGRect toolbarFrame = CGRectMake(0, [[UIScreen mainScreen] bounds].size.height - 66, [[UIScreen mainScreen] bounds].size.width, 44);

    // this is the frame to hold the table view
    CGRect tableFrame = CGRectMake(0, 0, [[UIScreen mainScreen] bounds].size.width, [[UIScreen mainScreen] bounds].size.height - 66);

	// place a toolar on the screen with a 'woosh up' button (this is a temporary stand-in for sensor-based wooshing)
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:toolbarFrame];

    UIBarButtonItem *addCardButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addCardButtonTapped:)];
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *deleteAllButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteAllButtonTapped:)];
    UIBarButtonItem *scanButton = [[UIBarButtonItem alloc] initWithTitle:@"Woosh Up" style:UIBarButtonItemStyleDone target:self action:@selector(wooshUpButtonTapped:)];
    
    // set toolbar items and ensure that the toolbar will auto-size to the scrren
    [toolbar setItems:[NSArray arrayWithObjects:addCardButton, space, deleteAllButton, space, scanButton, nil]];
    [toolbar sizeToFit];

    // add the toolbar to the screen
    [self.view addSubview:toolbar];

    // add a table view - this will show a list of 'cards' - tapping on one will show the card in full
    self.mainCardView = [[UITableView alloc] initWithFrame:tableFrame];
    [self.mainCardView setDelegate:self];
    [self.mainCardView setDataSource:self];
    
    [self.view addSubview:self.mainCardView];
    
    // we are interested in synchronization events, so set the delegate here
    [[Woosh woosh] setDelegate:self];
    
    // perform a synchronize
    if ([[Woosh woosh] username] != nil) {
        [[Woosh woosh] synchronize];        
        [self.mainCardView reloadData];
    }

}

-(void) deleteAllButtonTapped:(id)sender {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Warning!" message:@"Are you sure that you want to delete all of your existing cards?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Yes", nil];
    
    [alert setTag:DELETE_ALL_ALERT];
    [alert show];
    
}

-(void) wooshUpButtonTapped:(id)sender {
    NSLog(@"Woosh Up button tapped.");
    
    // when we detect a woosh we perform a scan for offers on any cards that are in range
    [[Woosh woosh] scan];

    // send the woosh to the server
    [[Woosh woosh] synchronize];
    
    // log hoqw many cards the user has
    NSLog(@"Card count: %d", [[[Woosh woosh] nonDeletedCards] count]);
}

- (void) synchronizeEnded {
    // now that we have scanned for offers, reload the main card view
    [self.mainCardView reloadData];    
}

-(void) addCardButtonTapped:(id)sender {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Add Woosh Card" message:@"Type the text that you want on your new Woosh Card" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Create", nil];

    alert.alertViewStyle = UIAlertViewStylePlainTextInput;

    [alert setTag:ADD_CARD_ALERT];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (alertView.tag == ADD_CARD_ALERT) {

        if (buttonIndex == 1) {
            NSString *message = [[alertView textFieldAtIndex:0] text];
            
            NSLog(@"Entered: %@", message);
            
            NSString *now = [[Woosh woosh] dateAsDateTimeString:[NSDate date]];
            NSString *username = [[Woosh woosh] username];
            NSString *cardName = [NSString stringWithFormat:@"From %@ @ %@", username, now];
            
            // create a card with data - it will be automatically stored locally and sent to the Woosh servers
            CardData *data = [CardData initWithValue:@"default" value:[NSString stringWithFormat:@"%@ says: %@", username, message]];
            [[Woosh woosh] publishCard:cardName data:[NSArray arrayWithObject:data]];
            
            // push the card to the woosh servers
            [[Woosh woosh] synchronize];
            
            // display the card in the table view
            [self.mainCardView reloadData];
        }
        
    } else if (alertView.tag == DELETE_ALL_ALERT) {

        if (buttonIndex == 1) {
            
            // flag all of the existing cards and card data as deleted and synchronize
            NSString *now = [[Woosh woosh] dateAsDateTimeString:[NSDate date]];
            NSArray *cards = [[Woosh woosh] nonDeletedCards];
            
            for (NSMutableDictionary *c in cards) {
                int newClientVersion = [[c objectForKey:@"clientVersion"] intValue] + 1;
                
                [c setObject:@"true" forKey:@"deleted"];
                [c setObject:now forKey:@"lastUpdated"];
                [c setObject:[NSString stringWithFormat:@"%d", newClientVersion] forKey:@"clientVersion"];
            }
            
            // synchronize the changes to the server
            [[Woosh woosh] synchronize];
        }
        
    }
    
}

// table view datasource and delegate methods
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *cardDict = [[[Woosh woosh] nonDeletedCards] objectAtIndex:indexPath.row];

    // TODO only render non-deleted cards
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];

    // configure the cell
    [cell.textLabel setText:[cardDict objectForKey:@"name"]];
    [cell.textLabel setFont:[UIFont fontWithName:@"Helvetica" size:17]];
    [cell.textLabel setNumberOfLines:2];
    [cell.textLabel setLineBreakMode:NSLineBreakByCharWrapping];
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[Woosh woosh] nonDeletedCards] count];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {

    // set the selected card based upon what the user tapped
    [[Woosh woosh] setSelectedCard:[[[Woosh woosh] nonDeletedCards] objectAtIndex:indexPath.row]];
    
    if (self.flipsidePopoverController) {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    } else {
        [self performSegueWithIdentifier:@"showAlternate" sender:nil];
    }

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([[Woosh woosh] username] != nil) {
        return [NSString stringWithFormat:@"Logged in as: %@", [[Woosh woosh] username]];
    } else {
        return nil;        
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller {
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    }
    
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.flipsidePopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showAlternate"]) {
        [[segue destinationViewController] setDelegate:self];
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            UIPopoverController *popoverController = [(UIStoryboardPopoverSegue *)segue popoverController];
            self.flipsidePopoverController = popoverController;
            popoverController.delegate = self;
        }
    }
}

- (IBAction)togglePopover:(id)sender
{
    if (self.flipsidePopoverController) {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    } else {
        [self performSegueWithIdentifier:@"showAlternate" sender:sender];
    }
}

@end

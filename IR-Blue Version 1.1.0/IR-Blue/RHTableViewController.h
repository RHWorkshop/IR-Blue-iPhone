//
//  RHTableViewController.h
//  IR-Blue
//
//  Created by Andy Rawson on 5/29/13.
//  Copyright (c) 2013 RH Workshop. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RHViewController.h"

@interface RHTableViewController : UITableViewController <UIAlertViewDelegate>
- (IBAction)colorPaletteStepper:(UIStepper *)sender;
- (IBAction)showTemperatureSwitch:(UISwitch *)sender;
- (IBAction)smoothOverlaySwitch:(UISwitch *)sender;
- (IBAction)temperatureUnitsStepper:(UIStepper *)sender;
- (IBAction)transparencyStepper:(UIStepper *)sender;
- (IBAction)calibrateButton:(UIButton *)sender;
- (IBAction)resetCalibration:(UIButton *)sender;
- (IBAction)resetAllSettings:(UIButton *)sender;


@property (weak, nonatomic) IBOutlet UILabel *temperatureUnitsLabel;
@property (weak, nonatomic) IBOutlet UILabel *colorPaletteLabel;
@property (weak, nonatomic) IBOutlet UIStepper *colorPaletteStepperProperty;
@property (weak, nonatomic) IBOutlet UISwitch *showTemperatureSwitchProperty;
@property (weak, nonatomic) IBOutlet UISwitch *smoothOverlaySwitchProperty;
@property (weak, nonatomic) IBOutlet UIStepper *temperatureUnitsStepperProperty;
@property (weak, nonatomic) IBOutlet UISwitch *autoRangeSwitchProperty;
@property (weak, nonatomic) IBOutlet UIStepper *transparencyStepperProperty;
@property (weak, nonatomic) IBOutlet UILabel *transparencyLabel;

@end

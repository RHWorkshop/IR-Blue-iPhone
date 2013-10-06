//
//  RHTableViewController.m
//  IR-Blue
//
//  Created by Andy Rawson on 5/29/13.
//  Copyright (c) 2013 RH Workshop. All rights reserved.
//

#import "RHTableViewController.h"
#import "SWRevealViewController.h"

@interface RHTableViewController ()

@end

@implementation RHTableViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOpenSettings:) name:@"openSettings" object:nil];
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setDefaultSettings];
    
    [self loadSettings];
    
    
}

-(void)handleOpenSettings:(NSNotification *)note  {
    [self loadSettings];
}

- (void)loadSettings {
    // set the Palette label text
    [self setPaletteLabel];
    
    // set the Palette stepper value
    self.colorPaletteStepperProperty.Value = [self getSettingInt:@"colorType"];
    
    // set the show temperature switch state
    if ([self getSettingInt:@"showTemp"]) {
        [self.showTemperatureSwitchProperty setOn:YES];
    }
    else {
        [self.showTemperatureSwitchProperty setOn:NO];
    }
        
    
    //set the smooth overlay switch state
    if ([self getSettingInt:@"smoothOverlay"]) {
        [self.smoothOverlaySwitchProperty setOn:YES];
    }
    else {
        [self.smoothOverlaySwitchProperty setOn:NO];
    }
    
    //set the temp units label text
    [self setTempUnitsLabel];
    
    //set the temp units stepper value
    self.temperatureUnitsStepperProperty.Value = [self getSettingInt:@"tempType"];
    
    //set the auto ranging switch state
    if ([self getSettingInt:@"autoRanging"]) {
        [self.autoRangeSwitchProperty setOn:YES];
    }
    else {
        [self.autoRangeSwitchProperty setOn:NO];
    }
    
    //set the transparency stepper value
    self.transparencyStepperProperty.Value = [self getSettingDouble:@"transparency"];
    
    //set the transparency label text
    [self.transparencyLabel setText:[NSString stringWithFormat:@"%.2lf",[self getSettingDouble:@"transparency"]]];
    
}

-(void)setTempUnitsLabel {
    //set the temp units label text
    switch ([self getSettingInt:@"tempType"]) {
            
        case 0:
            [self.temperatureUnitsLabel setText:@"˚F"];
            break;
        case 1:
            [self.temperatureUnitsLabel setText:@"˚C"];
            break;
        case 2:
            [self.temperatureUnitsLabel setText:@"˚K"];
            break;
            
        default:
            [self.temperatureUnitsLabel setText:@"˚F"];
            break;
    }
}

-(void)setPaletteLabel {
    switch ([self getSettingInt:@"colorType"]) {
            
        case 0:
            [self.colorPaletteLabel setText:@"RGB"];
            break;
        case 1:
            [self.colorPaletteLabel setText:@"Redlight"];
            break;
        case 2:
            [self.colorPaletteLabel setText:@"B&W"];
            break;
            
        default:
            [self.colorPaletteLabel setText:@"RGB"];
            break;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Settings

- (void)setDefaultSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaultSettings" ofType:@"plist"]]];
}

- (void)saveSettingInt:(NSString *)settingName :(int) settingValue  {
    
    // settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // set the value
    [defaults setInteger:settingValue forKey:settingName];
    
    // save it
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"settingsChanged" object:self];
    
}

- (int)getSettingInt:(NSString *)settingName {
    
    // settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Get the value
    return [defaults integerForKey:settingName];
    
}

- (void)saveSettingDouble:(NSString *)settingName :(double) settingValue  {
    
    // settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // set the value
    [defaults setDouble:settingValue forKey:settingName];
    
    // save it
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"settingsChanged" object:self];
    
}

- (double)getSettingDouble:(NSString *)settingName {
    
    // settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Get the value
    return [defaults doubleForKey:settingName];
    
}


#pragma mark - Actions

- (IBAction)colorPaletteStepper:(UIStepper *)sender {
 
    NSLog(@"Overlay Color %f",sender.value);
    [self saveSettingInt:@"colorType" :sender.value];
    [self setPaletteLabel];
    
}

- (IBAction)showTemperatureSwitch:(UISwitch *)sender {
    
    NSLog(@"Show Temperature %i",sender.on);
    [self saveSettingInt:@"showTemp" :sender.on];
    
}

- (IBAction)smoothOverlaySwitch:(UISwitch *)sender {
    
    NSLog(@"Smooth Overlay %i",sender.on);
    [self saveSettingInt:@"smoothOverlay" :sender.on];
    
}

- (IBAction)temperatureUnitsStepper:(UIStepper *)sender {

    NSLog(@"Temperature Type %f",sender.value);
    [self saveSettingInt:@"tempType" :sender.value];
    [self setTempUnitsLabel];
}

- (IBAction)autoRangeSwitch:(UISwitch *)sender {

    NSLog(@"Auto Ranging %i",sender.on);
    [self saveSettingInt:@"autoRanging" :sender.on];
    
}

- (IBAction)transparencyStepper:(UIStepper *)sender {
    NSLog(@"Transparency %f",sender.value);
    [self saveSettingDouble:@"transparency" :sender.value];
    //set the transparency label text
    [self.transparencyLabel setText:[NSString stringWithFormat:@"%.2lf",[self getSettingDouble:@"transparency"]]];
}

- (IBAction)calibrateButton:(UIButton *)sender {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"runCalibration" object:self];
    
    
}

- (IBAction)resetCalibration:(UIButton *)sender {
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Reset Calibration" message:@"Reset Calibration to Default?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Reset" , nil];
    
    [message setTag:1];
    [message show];
    
}

- (IBAction)resetAllSettings:(UIButton *)sender
{
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Reset Settings" message:@"Reset all user settings to Default?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Reset" , nil];

    [message setTag:0];
    [message show];
}

#pragma mark - Other Stuff

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
    {
        if ([alertView tag] == 0) {
            //reset all settings to defaults
            if (buttonIndex) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"resetSettings" object:self];
                
            }
            
        }
        
        else if ([alertView tag] == 1) {
            //reset calibration
            if (buttonIndex) {
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"resetCalibration" object:self];
                
            }
              
        }
        
    }

- (void)viewDidUnload {
    [self setTemperatureUnitsLabel:nil];
    [self setColorPaletteLabel:nil];
    [self setColorPaletteStepperProperty:nil];
    [self setShowTemperatureSwitchProperty:nil];
    [self setSmoothOverlaySwitchProperty:nil];
    [self setTemperatureUnitsStepperProperty:nil];
    [self setAutoRangeSwitchProperty:nil];
    [self setTransparencyStepperProperty:nil];
    [self setTransparencyLabel:nil];
    [super viewDidUnload];
}
@end

//
//  RHViewController.h
//  TIPIC-BLE
//
//  Created by Andy Rawson on 10/4/12.
//  Copyright (c) 2012 RH Workshop. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPUImage.h"
#import "MLX90620Math.h"
#import "RHAppDelegate.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "Brsp.h"



@interface RHViewController : UIViewController <CBCentralManagerDelegate, BrspDelegate, CBPeripheralDelegate, GPUImageVideoCameraDelegate, UIAlertViewDelegate> {

    GPUImageStillCamera *stillCamera;
    GPUImageOutput<GPUImageInput> *filter;
    GPUImageAlphaBlendFilter *blendFilter;
    NSMutableArray *_commandQueue;  //An array of commands queued for sending to BRSP
    BrspMode _lastMode;
    
}

-(void)stopCamera;

- (IBAction)leftButton:(id)sender;
- (IBAction)downButton:(UIButton *)sender;
- (IBAction)rightButton:(UIButton *)sender;
- (IBAction)saveButtonAction:(id)sender;
- (IBAction)upButton:(UIButton *)sender;
- (IBAction)blurButton:(UIButton *)sender;
- (IBAction)alignButton:(UIButton *)sender;
- (IBAction)autoButton:(UIButton *)sender;
- (IBAction)rangeMinus:(UIButton *)sender;
- (IBAction)rangePlus:(UIButton *)sender;
- (IBAction)midPlusButton:(UIButton *)sender;
- (IBAction)midMinusButton:(UIButton *)sender;
- (IBAction)colorButton:(UIButton *)sender;
- (IBAction)showTempButton:(UIButton *)sender;
- (IBAction)statusLabelButton:(UIButton *)sender;
- (IBAction)settingsButton:(id)sender;


@property (weak, nonatomic) IBOutlet UIButton *autoButtonProperty;
@property (weak, nonatomic) IBOutlet UILabel *centerTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *highTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *lowTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectingLabel;
@property (weak, nonatomic) IBOutlet UILabel *manualLowLabel;
@property (weak, nonatomic) IBOutlet UILabel *manualHighLabel;
@property (weak, nonatomic) IBOutlet UILabel *tempTypeLabel;
@property (strong, nonatomic) Brsp *brspObject;
@property (strong, nonatomic) NSMutableString *brspBuffer1;
@property (strong, nonatomic) NSMutableString *brspBuffer2;
@property (weak, nonatomic) IBOutlet UIButton *upButtonProperty;
@property (weak, nonatomic) IBOutlet UIButton *saveButtonProperty;
@property (weak, nonatomic) IBOutlet UIButton *leftButtonProperty;
@property (weak, nonatomic) IBOutlet UIButton *rightButtonProperty;
@property (weak, nonatomic) IBOutlet UIButton *downButtonProperty;
@property (weak, nonatomic) IBOutlet UIButton *settingsButtonProperty;
@property (weak, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeRight;
@property (weak, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeLeft;



@end

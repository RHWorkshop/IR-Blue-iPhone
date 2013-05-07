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
#import <CoreBluetooth/CoreBluetooth.h>

@interface RHViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralDelegate, GPUImageVideoCameraDelegate> {
GPUImageStillCamera *stillCamera;
GPUImageOutput<GPUImageInput> *filter;
    GPUImageAlphaBlendFilter *blendFilter;
}
- (IBAction)saveButtonAction:(id)sender;
- (IBAction)blurButton:(UIButton *)sender;
- (IBAction)autoButton:(UIButton *)sender;
- (IBAction)rangeMinus:(UIButton *)sender;
- (IBAction)rangePlus:(UIButton *)sender;
- (IBAction)midPlusButton:(UIButton *)sender;
- (IBAction)midMinusButton:(UIButton *)sender;
- (IBAction)colorButton:(UIButton *)sender;
- (IBAction)showTempButton:(UIButton *)sender;
@property (weak, nonatomic) IBOutlet UIButton *autoButtonProperty;
@property (weak, nonatomic) IBOutlet UILabel *centerTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *highTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *lowTempLabel;
@property (weak, nonatomic) IBOutlet UILabel *connectingLabel;



@end

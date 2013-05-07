//
//  RHAppDelegate.h
//  TIPIC-BLE
//
//  Created by Andy Rawson on 10/4/12.
//  Copyright (c) 2012 RH Workshop. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface RHAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CBCentralManager *cbCentral;
@property (strong, nonatomic) CBPeripheral *activePeripheral;

//Returns a pointer to the shared AppDelegate
+(RHAppDelegate*)app;

@end

//
//  BLEThermalSensor.m
//  TIPIC-BLE
//
//  Created by Andy Rawson on 10/8/12.
//  Copyright (c) 2012 RH Workshop. All rights reserved.
//

#import "BLEThermalSensor.h"

@interface BLEThermalSensor()
{
    CBCentralManager *centralManager;
    NSMutableString *mString;
}
@end

@implementation BLEThermalSensor

#pragma mark - BLE Central Manager Delegate 
-(void)centralManagerDidUpdateState:(CBCentralManager *)central {
    [mString appendString:@"centralManagerDidUpdateState\n"];
}



@end

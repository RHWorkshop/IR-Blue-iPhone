//
//  MLX90620Math.h
//  IRPhoneCamera
//
//  Created by Andy Rawson on 8/25/12.
//  Copyright (c) 2012 RH Workshop. 
//

#import <Foundation/Foundation.h>

@interface MLX90620Math : NSObject


-(double)GetTo :(int) sensorReading :(int) sensorID;
-(double)GetTa :(double) PTAT_data :(int) Vcp_data;
-(void)setup :(NSArray*) eepromDataArray;


@end

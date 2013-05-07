//
//  MLX90620Math.m
//  IRPhoneCamera
//
//  Created by Andy Rawson on 8/25/12.
//  Copyright (c) 2012 RH Workshop. 
//


#import "MLX90620Math.h"

#define Ta_0 25

@interface MLX90620Math () {

    double Vth, Kt1, Kt2, Ta, Vcp, a0, E, acp, Vcp_Off_Comp, Vir_TGC_Comp;

    int TGC, Acp, Bcp, acp_L, acp_H, Bi_Scale, a0_L, a0_H, a0_Scale, DaScale, E_L, E_H, Vth_L, Vth_H, Kt1_L, Kt1_H, Kt2_L, Kt2_H;

    NSMutableArray *AiData;
    NSMutableArray *BiData;
    NSMutableArray *DaData;
    NSMutableArray *eepromData;
    NSMutableArray *aData;
    
}
@end

@implementation MLX90620Math 

#pragma mark - Setup

-(void)setup:(NSArray*)eepromDataArray {

    // Set all the EEPROM settings needed to calculate temperature from the data
    AiData = [[NSMutableArray alloc] init];
    BiData = [[NSMutableArray alloc] init];
    DaData = [[NSMutableArray alloc] init];
    aData = [[NSMutableArray alloc] init];
    eepromData = [[NSMutableArray alloc] init];
    [eepromData addObjectsFromArray:eepromDataArray];
    
    [AiData addObjectsFromArray:[eepromData subarrayWithRange:NSMakeRange(0, 64)]];
    [BiData addObjectsFromArray:[eepromData subarrayWithRange:NSMakeRange(64, 64)]];
    [DaData addObjectsFromArray:[eepromData subarrayWithRange:NSMakeRange(128, 64)]];
    Acp = [[eepromData objectAtIndex:212] intValue];
    Bcp = [[eepromData objectAtIndex:213] intValue];
    acp_L = [[eepromData objectAtIndex:214] intValue];
    acp_H = [[eepromData objectAtIndex:215] intValue];
    Bi_Scale = [[eepromData objectAtIndex:217] intValue];
    a0_L = [[eepromData objectAtIndex:224] intValue];
    a0_H = [[eepromData objectAtIndex:225] intValue];
    a0_Scale = [[eepromData objectAtIndex:226] intValue];
    DaScale = [[eepromData objectAtIndex:227] intValue];
    E_L = [[eepromData objectAtIndex:228] intValue];
    E_H = [[eepromData objectAtIndex:229] intValue];
    Vth_L = [[eepromData objectAtIndex:218] intValue];
    Vth_H = [[eepromData objectAtIndex:219] intValue];
    Kt1_L = [[eepromData objectAtIndex:220] intValue];
    Kt1_H = [[eepromData objectAtIndex:221] intValue];
    Kt2_L = [[eepromData objectAtIndex:222] intValue];
    Kt2_H = [[eepromData objectAtIndex:223] intValue];
    Vth = [self GetVth];
    Kt1 = [self GetKt1];
    Kt2 = [self GetKt2];
    //acp = [self Getacp];
    a0 = [self Geta0];
    E = [self GetE];
    TGC = [[eepromData objectAtIndex:216] intValue];
    
    [self setupaData];
    
}

-(void)setupaData {
    
    for (int i = 0; i < 64; i++) {
        NSString *sDai = [DaData objectAtIndex:i];
        double Dai = sDai.intValue;
        double ra;
        
        ra = a0/pow(2, a0_Scale) + Dai/pow(2, DaScale);
        
        [aData addObject:[NSNumber numberWithDouble:ra]];
    }
}

#pragma mark - Build Values

-(double)Geta0 {
    double ra0;
    double rawa0;
    rawa0 = (256 * a0_H) + a0_L;
    
    ra0 = rawa0;
    
    return ra0;
}

-(double)GetE {
    double rE;
    double rawE;
    rawE = (256 * E_H) + E_L;

    rE = rawE/32768;
    
    return rE;
}

-(double)GetVth {
    double rVth;
    double rawVth;
    rawVth = (256 * Vth_H) + Vth_L;
    
    if (rawVth > 32767) {
        rVth = rawVth - 65536;
    }
    else {
        rVth = rawVth;
    }
    return rVth;
}


-(double)GetKt1 {
    double rKt1;
    double rawKt1;    
    rawKt1 = (256 * Kt1_H) + Kt1_L;
    if (rawKt1 > 32767) {
        rKt1 = rawKt1 - 65536;
        rKt1 = -rKt1/1024;
    }
    else {
        rKt1 = rawKt1/1024;
    }
    return rKt1;
}

-(double)GetKt2 {
    double rKt2;
    double rawKt2;
    rawKt2 = (256 * Kt2_H) + Kt2_L;
    if (rawKt2 > 32767) {
        rKt2 = rawKt2 - 65536;
        rKt2 = rKt2/1048576;
    }
    else {
        rKt2 = rawKt2/1048576;
    }
    return rKt2;
}

#pragma mark - Main Functions

// Tambient calculation - Ta
-(double)GetTa:(double)PTAT_data:(int)Vcp_data
 {
    double rTa = 0;
    Vcp = Vcp_data;
    Vcp_Off_Comp = [self GetVcp_Off_Comp];
     
    rTa = (-Kt1 + pow((((Kt1*Kt1)-4*(Kt2*(Vth - PTAT_data)))),0.5)) / (2*Kt2) + 25;
     Ta = rTa;
    return rTa;
}

// Vcp_Off_Comp
-(double)GetVcp_Off_Comp{
    double rVcp_Off_Comp;
    
    rVcp_Off_Comp = Vcp - (Acp + (Bcp/pow(2, Bi_Scale) * (Ta - Ta_0)));
    
    return rVcp_Off_Comp;
}

// Vir_Off_Comp
-(double)GetVir_Off_Comp:(int)sensorReading:(int)sensorID {
    double rVir_Off_Comp;
    int Aii = [[AiData objectAtIndex:sensorID] intValue];
    int Bii = [[BiData objectAtIndex:sensorID] intValue];
    if (Bii > 127) Bii = Bii - 256;
    if (Aii > 127) Aii = Aii - 256;
    
    rVir_Off_Comp = sensorReading - (Aii + (Bii/pow(2, Bi_Scale) * (Ta - Ta_0)));
    
    return rVir_Off_Comp;
}

// Vir_TGC_Comp
-(double)GetVir_TGC_Comp:(int)sensorReading:(int)sensorID {
    double rVir_TGC_Comp;
    double iVir_Off_Comp = [self GetVir_Off_Comp:sensorReading :sensorID];
    
    rVir_TGC_Comp = iVir_Off_Comp - (TGC / 32)*Vcp_Off_Comp;
    
    return rVir_TGC_Comp;
}

// Vir_Compensated
-(double)GetVir_Compensated:(int)sensorReading:(int)sensorID {
    double rVir_Compensated;
    double iVir_TGC_Comp = [self GetVir_TGC_Comp:sensorReading:sensorID];
    
    rVir_Compensated = iVir_TGC_Comp/E;
    
    return rVir_Compensated;
}

// Object Temperature Calculation - To
-(double)GetTo:(int)sensorReading:(int)sensorID {
    double rTo = 0;
    double iVir = [self GetVir_Compensated:(int)sensorReading:(int)sensorID];
    double ia = [[aData objectAtIndex:sensorID] doubleValue];
    
    rTo = (pow(iVir/ia + pow((Ta + 273.15),4),0.25))-273.15;
    
    return rTo;
}

@end

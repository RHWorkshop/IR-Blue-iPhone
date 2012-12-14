//
//  RHViewController.m
//  TIPIC-BLE
//
//  Created by Andy Rawson on 10/4/12.
//  Copyright (c) 2012 RH Workshop. All rights reserved.
//

#import "RHViewController.h"


@interface RHViewController ()

// Check iPhone device types
#define IS_IPHONE ( [[[UIDevice currentDevice] model] isEqualToString:@"iPhone"] )
#define IS_IPOD   ( [[[UIDevice currentDevice ] model] isEqualToString:@"iPod touch"] )
#define IS_HEIGHT_GTE_568 [[UIScreen mainScreen ] bounds].size.height >= 568.0f
#define IS_IPHONE_5 ( IS_IPHONE && IS_HEIGHT_GTE_568 )

// Temperature color mapping defaults
#define DEFAULT_HIGH_TEMP 90
#define DEFAULT_LOW_TEMP 65
#define DEFAULT_OPACITY 1 // not really used right now
#define DEFAULT_BLENDMIX 0.8 //opacity of the color overlay
#define DEFAULT_COLOR_TYPE 1 //1 color, 2 saturation, 3 grey

// List of sensors, bluetooth characteristic xgatt_sensor_type tells the application which one to use
#define SENSOR_TYPE_MLX90620 1
#define SENSOR_TYPE_GRID_EYE 0

// average the 4 center readings or just use the upper right center reading
#define CENTER_TEMP 0

// The UUID of the Thermal Imaging Service and Characteristics
#define BLE_SERVICE_ID @"928f41ba-6e8b-4b17-90ba-3e81fcefb6d0" // Thermal Imaging Sensor Service
#define BLE_IR_TEMP_ID @"05144cc7-e844-4516-a7c2-dc0afb613b7e" // xgatt_read_temp
#define BLE_EEPROM_ID @"35a8129a-a34a-421c-82bb-9a5723164b3e"  // xgatt_read_eeprom
#define BLE_TEMP1_ID @"b9f76bcf-56f3-4c4e-8cf1-b774945f53fa"   // xgatt_read_temp1
#define BLE_TEMP2_ID @"6de465d5-7c07-4e26-a9d0-c3f444277aca"   // xgatt_read_temp2
#define BLE_TEMP3_ID @"4491508d-9295-4c90-a6fe-92b222717611"   // xgatt_read_temp3
#define BLE_TEMP4_ID @"6ba26639-73c4-4426-86c1-b6eded9c64fa"   // xgatt_read_temp4
#define BLE_SENSOR_TYPE @"15a539e4-db0f-4870-90f0-42b29ca75b3d" // xgatt_sensor_type


// offset for problem sensor
#define OFFSET_0	0 //30
#define OFFSET_1	0 //27
#define OFFSET_2	0 //28
#define OFFSET_3	0 //32
#define OFFSET_4	0 //26
#define OFFSET_5	0 //22
#define OFFSET_6	0 //20
#define OFFSET_7	0 //24


{
    NSTimer *updateTimer;
    int tempPointHeight;
    int tempPointWidth;
    int tempPositionXOffset;
    int tempPositionYOffset;
    int sensorFOV;
    NSString *tempData;
    NSMutableArray *eepromData;
    NSMutableArray *sensorData;
    NSMutableArray *pastSensorData;
    NSMutableArray *workingSensorData;
    NSMutableArray *irOffset;
    NSMutableArray *iSensorData;
    NSMutableArray *bleServices;
    
    int autoRanging;
    int blurOverlay;
    int showTemp;
    double centerTemp;
    double centerTemp1;
    double centerTemp2;
    double centerTemp3;
    double centerTemp4;
    int autoHighTemp;
    int autoLowTemp;
    int colorType;
    double highTemp;
    double lowTemp;
    double opacity;
    double blendFilterMix;
    double Ta;
    double Vth;
    double Kt1;
    double Kt2;
    BOOL waiting;
    NSString *useHost;
    int readingCount;
    int readingType;
    int newData;
    GPUImageView *filterView;
    int sublayerCount;
    
    MLX90620Math *math;
    
    CBCentralManager *centralManager;
    CBPeripheral *blePeripheral;
    CBService *bleThermalImagingService;
    CBCharacteristic *bleIRData;
    CBCharacteristic *bleEEPROMData;
    CBCharacteristic *bleTemp;
    CBCharacteristic *bleTemp1;
    CBCharacteristic *bleTemp2;
    CBCharacteristic *bleTemp3;
    CBCharacteristic *bleTemp4;
    CBCharacteristic *bleSensorType;
    UIColor *colorArrayTemp[64];
    int currentSensor;
}
@end

@implementation RHViewController
// GPUImageStillCamera *stillCamera;
// GPUImageOutput<GPUImageInput> *filter;
// GPUImageHarrisCornerDetectionFilter *hFilter;

#pragma mark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [[self connectingLabel] setHidden:0];
    [self initializeThings];
    [self startCamera];
    
    // Temp fake data init
    //[self getEEPROMData];
    //updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
    
    // BLE Setup
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    //peripheral = [[CBPeripheral alloc] init];
    //bleThermalImagingService = [[CBService alloc] init];
    [self doScan];    
}

- (void)initializeThings
{

    tempPointWidth = 40; // Individual sensor point width
    tempPointHeight = 40; // Individual sensor point height
    tempPositionXOffset = 100; // Where to start drawing
    tempPositionYOffset = 280; // Where to start drawing
    readingCount = 0;
    readingType = 1; // Read EEPROM data first
    newData = 0; // Is new IR data available
    
    waiting = NO;
    //PTAT = 6848; // Default; Set from Sensor RAM
    sensorData = [[NSMutableArray alloc] init];
    eepromData = [[NSMutableArray alloc] init];
    bleServices = [[NSMutableArray alloc] init];
    pastSensorData = [[NSMutableArray alloc] init];
    workingSensorData = [[NSMutableArray alloc] init];
    
    lowTemp = DEFAULT_LOW_TEMP;
    highTemp = DEFAULT_HIGH_TEMP;
    autoHighTemp = DEFAULT_HIGH_TEMP;
    autoLowTemp = DEFAULT_LOW_TEMP;
    autoRanging = 1;
    blurOverlay = 1;
    showTemp = 1;
    opacity = DEFAULT_OPACITY;
    blendFilterMix = DEFAULT_BLENDMIX;
    colorType = DEFAULT_COLOR_TYPE;
    
}

- (NSArray*)getColorArrayTemp {
    if (colorArrayTemp[1] != nil) {
    NSArray* a = [NSArray arrayWithObjects:colorArrayTemp count:64];
    return a;
    }
    else return nil;
}

- (void)startCamera
{
    
    stillCamera = [[GPUImageStillCamera alloc] init];
    
    stillCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
    [stillCamera forceProcessingAtSize:CGSizeMake(720.0, 480.0)];
    filter = [[GPUImageHarrisCornerDetectionFilter alloc] init];
    [filter forceProcessingAtSize:CGSizeMake(720.0, 480.0)];
    filterView = (GPUImageView *)self.view;
    
    
    filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    
    [stillCamera addTarget:filter];
    
    GPUImageCrosshairGenerator *crosshairGenerator = [[GPUImageCrosshairGenerator alloc] init];
    CGFloat sensorSize = 42;
    crosshairGenerator.crosshairWidth = sensorSize;
    [crosshairGenerator setBackgroundColorRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    [crosshairGenerator forceProcessingAtSize:CGSizeMake(720.0, 480.0)];

    __weak RHViewController *blockSelf = self;
    [(GPUImageHarrisCornerDetectionFilter *)filter setCornersDetectedBlock:^(GLfloat* cornerArray, NSUInteger cornersDetected, CMTime frameTime) {

        RHViewController *strongSelf = blockSelf;
        NSArray* a = [NSArray arrayWithArray:[strongSelf getColorArrayTemp]];
        UIColor* colorArrayLocal[64];
        if (a.count > 0) {
            for (int i = 0; i < 64; i++) {
                colorArrayLocal[i] = [a objectAtIndex:i];
            }
        }
        
        GLfloat* myArray = calloc(128 * 4, sizeof(GLfloat));
        CGFloat scaledSensorHeight = (sensorSize/240);
        CGFloat scaledSensorWidth = (sensorSize/360);
        CGFloat startC = 0.5 - (scaledSensorWidth * 12);
        CGFloat startR = 0.5 - (scaledSensorHeight * 2);
        int rowCount = 0;
        int colCount = 0;
        for (int i = 0; i < 64; i++) {
            myArray[i*2] = (CGFloat)(startC + (colCount * scaledSensorWidth));
            myArray[i*2+1] = (CGFloat)(startR - (rowCount * scaledSensorHeight));
            //NSLog(@"array: %f, %f",(startC + (rowCount * scaledSensorWidth)),(startR + (colCount * scaledSensorWidth)));
            
            if (rowCount <3) {
                rowCount++;
            }
            else {
                rowCount = 0;
                colCount++;
            }
        }
        //set the colors
        GLfloat *colorArray;
        colorArray = calloc(256 * 4, sizeof(GLfloat));
        if (colorArrayLocal[1] != nil) {
            
        
        for (int i = 0; i < 64; i++) {

            CGFloat red;
            CGFloat green;
            CGFloat blue;
            CGFloat alpha;
            [colorArrayLocal[i] getRed:&red green:&green blue:&blue alpha:&alpha];
            
            colorArray[i*4] = red;
            colorArray[i*4+1] = green;
            colorArray[i*4+2] = blue;
            colorArray[i*4+3] = alpha;
            //NSLog(@"%i, %f, %f, %f, %f",i,red, green,blue,alpha);
        }
        }
        
        // fake color data for testing without the sensor
        //GLfloat *colorArray;
        //colorArray = calloc(256 * 4, sizeof(GLfloat));
        
//            for (uint32_t i = 0; i < 256; i = i +4) {
//                colorArray[i] = 0;
//                colorArray[i+1] = (i*.01)+.3;
//                colorArray[i+2] = 0;
//                colorArray[i+3] = 1;
//            }
//        colorArray[4] = 0;
//        colorArray[5] = 1;
//        colorArray[8] = 0;
//        colorArray[9] = .5;
//        colorArray[24] = 0;
//        colorArray[25] = .8;
//        colorArray[26] = .6;
//        colorArray[40] = 0;
//        colorArray[41] = 1;
//        colorArray[42] = 1;

        
        [crosshairGenerator renderCrosshairsFromArray:myArray count:64 colors:colorArray frameTime:frameTime];
            
    }];
 

    GPUImageGaussianBlurFilter *gFilter = [[GPUImageGaussianBlurFilter alloc] init];
    gFilter.blurSize = 4;
    [gFilter forceProcessingAtSize:CGSizeMake(720.0, 480.0)];
    blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    blendFilter.mix = blendFilterMix;
    [blendFilter forceProcessingAtSize:CGSizeMake(720.0, 480.0)];
    
    GPUImageGammaFilter *gammaFilter = [[GPUImageGammaFilter alloc] init];
    [gammaFilter forceProcessingAtSize:CGSizeMake(720.0, 480.0)];
    
    
    // Add the camera to the blend filter
    [stillCamera addTarget:gammaFilter];
    [gammaFilter addTarget:blendFilter];
    
        // Add the temperature overlay and blur it if needed
    if (blurOverlay) {
        [crosshairGenerator addTarget:gFilter];
        [gFilter addTarget:blendFilter];
    }
    else {
        [crosshairGenerator addTarget:blendFilter];
    }
    
    [blendFilter prepareForImageCapture];
    
    [blendFilter addTarget:filterView];
    
    [stillCamera startCameraCapture];

    
}

-(void) stopCamera {
    [stillCamera stopCameraCapture];
}

#pragma mark - Temperature and Data Handeling

-(void)updateColors {
    NSString *sVcp = [sensorData objectAtIndex:65];
    sVcp = [sVcp stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/r/n/r/n"]];
    int PTAT = [[sensorData objectAtIndex:64] intValue];
    int Vcp = sVcp.intValue;
    //NSLog(@"PTAT: %i VCP: %i", PTAT, Vcp);
    Ta = [math GetTa:PTAT:Vcp];
    int currentHighTemp = 0;
    int currentLowTemp = 120;
    
    [workingSensorData removeAllObjects];
    [workingSensorData addObjectsFromArray:pastSensorData];
    [pastSensorData removeAllObjects];
    
    
    for (int i = 0; i < 64; i++) {

        double temp = [[sensorData objectAtIndex:i] intValue];
        double ttemp = 0;
        temp = [math GetTo:temp:i];
        temp = (temp * 9 / 5) + 32; //convert C to F
        
        // smooth out small fluctuations in temp
        [pastSensorData addObject:[NSString stringWithFormat:@"%f", temp]];
        if (workingSensorData.count > 5) {
          ttemp = [[workingSensorData objectAtIndex:i] intValue];  
        }         
        if ((temp == ttemp + 1) || (temp == ttemp - 1)) {
            temp = ttemp;
        }
        
        
        // fix for sensor problem
        switch (i) {
            case 0:
                temp = temp + OFFSET_0;
                break;
            case 1:
                temp = temp + OFFSET_1;
                break;
            case 2:
                temp = temp + OFFSET_2;
                break;
            case 3:
                temp = temp + OFFSET_3;
                break;
            case 4:
                temp = temp + OFFSET_4;
                break;
            case 5:
                temp = temp + OFFSET_5;
                break;
            case 6:
                temp = temp + OFFSET_6;
                break;
            case 7:
                temp = temp + OFFSET_7;
                break;
            case 29:
                centerTemp1 = temp;
                break;
            case 30:
                centerTemp2 = temp;
                break;
            case 33:
                centerTemp3 = temp;
                break;
            case 34:
                centerTemp4 = temp;
                break;
            default:

                break;
        }
        switch (colorType) {
            case 1:
                colorArrayTemp[i] = [self mapTempToColor:temp];
                break;
            case 2:
                colorArrayTemp[i] = [self mapTempToSaturation:temp];
                break;
            case 3:
                colorArrayTemp[i] = [self mapTempToGreyscale:temp];
                break;
                
            default:
                break;
        }
        //NSLog(@"%i, %i, %@", i, temp, colorArrayTemp[i]);
        
        if (temp > currentHighTemp){
            currentHighTemp = temp;
        }
        if (temp < currentLowTemp) {
            currentLowTemp = temp;
        }
        
    }
    if ((currentHighTemp - currentLowTemp) < 25) {
        autoHighTemp = currentHighTemp + ((25 - (currentHighTemp - currentLowTemp))/2);
        autoLowTemp = currentLowTemp - ((25 - (currentHighTemp - currentLowTemp))/2);
    }
    else {
    autoHighTemp = currentHighTemp;
    autoLowTemp = currentLowTemp;
    }
    
    self.highTempLabel.text = [NSString stringWithFormat:@"High %d", currentHighTemp];
    self.lowTempLabel.text = [NSString stringWithFormat:@"Low %d", currentLowTemp];
    
    if (CENTER_TEMP) {
    centerTemp = (centerTemp1 + centerTemp2 + centerTemp3 + centerTemp4)/4;
    }
    else {
        centerTemp = centerTemp3;
    }
    self.centerTempLabel.text = [NSString stringWithFormat:@"%f", centerTemp];
}


// Map the temperature to color value
-(float) map:(float)inMin:(float)inMax:(float)outMin:(float)outMax:(float)inValue {
    float result = 0;
    result = outMin + (outMax - outMin) * (inValue - inMin) / (inMax - inMin);
    return result;
}

- (UIColor *)mapTempToColor:(int)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat hue;
    if (autoRanging) {
       hue = [self map:autoLowTemp :autoHighTemp :0.75 :0.0 :tempValue];  //  0.0 to 1.0
    }
    else {
        hue = [self map:lowTemp :highTemp :0.75 :0.0 :tempValue];  //  0.0 to 1.0
    }
    if (hue >0.75) hue = 0.75;
    else if (hue < 0.0) hue = 0.0;
    CGFloat saturation = 1;
    CGFloat brightness = 1;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:opacity];
}

- (UIColor *)mapTempToSaturation:(int)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat saturation;
    if (autoRanging) {
        saturation = [self map:autoLowTemp :autoHighTemp :1.0 :0.0 :tempValue];  //  0.0 to 1.0
    }
    else {
        saturation = [self map:lowTemp :highTemp :1.0 :0.0 :tempValue];  //  0.0 to 1.0
    }
    if (saturation > 1.0) saturation = 1.0;
    else if (saturation < 0.0) saturation = 0.0;
    CGFloat hue = 1;
    CGFloat brightness = 0.5;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:opacity];
}

- (UIColor *)mapTempToGreyscale:(int)tempValue {
    // Adjust the ratio to scale the colors that represent temp data
    CGFloat brightness;
    if (autoRanging) {
        brightness = [self map:autoLowTemp :autoHighTemp :0.0 :1.0 :tempValue];  //  0.0 to 1.0
    }
    else {
        brightness = [self map:lowTemp :highTemp :0.0 :1.0 :tempValue];  //  0.0 to 1.0
    }
    if (brightness >1) brightness = 1;
    else if (brightness < 0.0) brightness = 0.0;
    CGFloat hue = 0.17;
    CGFloat saturation = 0.1;
    
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:opacity];
}

- (void) processEEPROMData {
    if (eepromData.count == 255) {
        
        math = [[MLX90620Math alloc] init];
         
        //setup the math from the EEPROM
        [math setup:eepromData];
    }
    else {
        NSLog(@"No EEPROM data received");
    }
}

#pragma mark - MLX90620 CALayer stuff

- (void) update:(NSMutableArray*)sensorDataArray {
    //check if we are saving a snapshot
    //if (!processingTouchEvent) {
        //check if a full sensorData frame is available
        //NSLog(@"ir data count %i",sensorData.count);
        if (sensorData.count == 66) {
            
            // Choose the Layer to place the tempdata
            CALayer *myLayer = filterView.layer;
            
            NSString *sVcp = [sensorDataArray objectAtIndex:65];
            sVcp = [sVcp stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/r/n/r/n"]];
            int PTAT = [[sensorDataArray objectAtIndex:64] intValue];
            int Vcp = sVcp.intValue;
            //NSLog(@"PTAT: %i VCP: %i", PTAT, Vcp);
            Ta = [math GetTa:PTAT:Vcp];
            int rowCount = 0;
            int columnCount = 0;
            int row = tempPositionXOffset + (tempPointHeight * 2);
            int column = tempPositionYOffset - (tempPointWidth * 7.5);
            int irDataLoops = 64;
            //NSLog(@"Ta = %f", Ta);
            
            if (myLayer.sublayers.count < 5) {
                sublayerCount = myLayer.sublayers.count;
                // Loop through the 64 temp readings and add layers to the View
                
                for (int i = 0; i < irDataLoops; i = i+1) {
                    int temp = [[sensorDataArray objectAtIndex:i] intValue];
                    temp = [math GetTo:temp:i];
                    temp = (temp * 9 / 5) + 32; //convert C to F
                    
                    if (i == 34) {
                        // add the single displayed numeric temp reading
                        CATextLayer *sublayer = [CATextLayer layer];
                        sublayer.fontSize = 20;
                        sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                        sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                        sublayer.opacity = 1;
                        //sublayer.drawsAsynchronously = YES;
                        [sublayer removeAllAnimations];
                        sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight );
                        
                        [myLayer addSublayer:sublayer];
                    }
                    else {
                        //make new layers then add
                        CATextLayer *sublayer = [CATextLayer layer];
                        //CALayer *sublayer = [CALayer layer];
                        sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                        sublayer.opacity = 1;
                        sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                        //sublayer.drawsAsynchronously = YES;
                        [sublayer removeAllAnimations];
                        sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight);
                        [myLayer addSublayer:sublayer];
                    }// end checking for text point
                    
                    // Manage the row and column counts
                    if (rowCount < 3) {
                        rowCount++;
                        row = row - tempPointHeight;
                    }
                    else {
                        rowCount = 0;
                        column = column + tempPointWidth;
                        columnCount++;
                        row = tempPositionXOffset + (tempPointHeight * 2);
                    }
                } //end for loop
                
                
            } //end if checking for existing layers
            
            else {
                // Loop through the 64 temp readings and update the layers
                for (int i = 0; i < irDataLoops; i = i+1) {
                    
                    int temp = [[sensorDataArray objectAtIndex:i] intValue];
                    //NSLog(@"Reading: %d  Raw Data: %f",i,temp);
                    temp = [math GetTo:temp:i];
                    temp = (temp * 9 / 5) + 32; // convert C to F
                    //NSLog(@"Reading: %d  Temp: %f",i,temp);
                    if (i == 34) {
                        // change the single displayed numeric temp reading
                        CATextLayer *sublayer = [myLayer.sublayers objectAtIndex:i+sublayerCount];
                        sublayer.fontSize = 20;
                        sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                        sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
                    }
                    else {
                        CATextLayer *sublayer = [myLayer.sublayers objectAtIndex:i+sublayerCount];
                        sublayer.fontSize = 20;
                        sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                        //CALayer *sublayer = [myLayer.sublayers objectAtIndex:i];
                        sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
                    }
                    
                    
                    // Manage the row and column counts
                    if (rowCount < 3) {
                        rowCount++;
                        row = row - tempPointHeight;
                    }
                    else {
                        rowCount = 0;
                        column = column + tempPointWidth;
                        columnCount++;
                        row = tempPositionXOffset - (tempPointHeight * 1);
                    }
                    
                } //end for loop
            } //end else
            
        }// end if sensordata count
   // } // end if touch event check
}

// check for or collect new IR Data here - not used
-(void)timerMethod {
    
    [blePeripheral readValueForCharacteristic:bleIRData];
 
}


-(void)getEEPROMData {
    // Parse the EEPROM data and run initial calculations
    [self processEEPROMData];
    
}

#pragma mark - Other Stuff

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    //Dispose of any resources that can be recreated.
}

#pragma mark - BLE Central Manager Delegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {

    [self displayState];
}

-(void)displayState {
    NSString * str;
    switch (centralManager.state) {
        case CBCentralManagerStateUnknown:
            str = @"Unknown\n";
            break;
        case CBCentralManagerStateUnsupported:
            str = @"Unsupported\n";
            break;
        case CBCentralManagerStateUnauthorized:
            str = @"Unauthorized\n";
            break;
        case CBCentralManagerStateResetting:
            str = @"Resetting\n";
            break;
        case CBCentralManagerStatePoweredOn:
            str = @"PoweredOn\n";
            break;
        case CBCentralManagerStatePoweredOff:
            str = @"PoweredOff\n";
            break;
    }
    NSLog(@"CentralManager State is %@",str);
}

// Start scanning for the Device
- (void)doScan {
    
    CBUUID * ThermalImagingUUID = [CBUUID UUIDWithString:BLE_SERVICE_ID];
    [centralManager scanForPeripheralsWithServices:[NSArray arrayWithObject:ThermalImagingUUID] options:nil];
    NSLog(@"Started Scanning");
}

// Found a Device, connect to it
-(void) centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI{
    NSMutableString * mStr = [[NSMutableString alloc] initWithString:@"Discovered\n"];
    [mStr appendFormat:@"name: %@\n", peripheral.name];
    [mStr appendFormat:@"%@\n", CFUUIDCreateString(NULL, peripheral.UUID)];
    [mStr appendFormat:@"RSSI: %@\n", RSSI];
    [centralManager stopScan];
    [mStr appendString:@"Scan Stopped\n"];
    
    NSLog(@"Peripheral %@",mStr);
    
    
    blePeripheral = peripheral;
    [self connectperipheral];
}

// Connect to the Device
- (void)connectperipheral {
    if (blePeripheral == nil) {
        NSString *message = @"Unable to find Device, please make sure it is turned on";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Device" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
        return;
    }
    else {
    [blePeripheral setDelegate:self];
    
    NSLog(@"Connecting to:\n%@\n", CFUUIDCreateString(NULL, blePeripheral.UUID));
    [centralManager connectPeripheral:blePeripheral options:nil];
    }
}

// Connected to the Device, now discover the services
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    //peripheral = peripheral;
    
    CBUUID * ThermalImagingUUID = [CBUUID UUIDWithString:BLE_SERVICE_ID];
    [blePeripheral discoverServices:[NSArray arrayWithObject:ThermalImagingUUID]];
    NSLog(@"isConnected: %i\n", peripheral.isConnected);
    
    [[self connectingLabel] setHidden:1];
    }

// Found the Service we are looking for, get the Characteristics from it
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    bleThermalImagingService = peripheral.services.lastObject;
    NSLog(@"Services found: %u\n", peripheral.services.count);
    [self getAllCharacteristicsFromThermalImagingService:blePeripheral];

}

// Get the Characteristics
-(void) getAllCharacteristicsFromThermalImagingService:(CBPeripheral *)peripheral {
    CBUUID * eeUUID = [CBUUID UUIDWithString:BLE_EEPROM_ID];
    CBUUID * irUUID = [CBUUID UUIDWithString:BLE_IR_TEMP_ID];
    CBUUID * ttUUID = [CBUUID UUIDWithString:BLE_SENSOR_TYPE];
    
    [peripheral discoverCharacteristics:[NSArray arrayWithObjects:eeUUID,irUUID,ttUUID, nil] forService:bleThermalImagingService];
    
}

// Got the Characteristics, assign them and either read the EEPROM from the ML90620 or start reading the data from the Grid-Eye
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *bleCharacteristic in service.characteristics) {
        if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_EEPROM_ID]])
        {
            bleEEPROMData = bleCharacteristic;            
            NSLog(@"Found EEPROM Characteristic");
        }
        else if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_IR_TEMP_ID]])
        {
            bleIRData = bleCharacteristic;
            NSLog(@"Found IR Temp Array Characteristic");
        }
        else if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_SENSOR_TYPE]])
        {
            bleSensorType = bleCharacteristic;
            NSLog(@"Found Sensor Type Characteristic");
        }
    }

        [blePeripheral readValueForCharacteristic:bleSensorType];
    

}

// Fail!
-(void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {

    NSLog(@"Connection failed:\n%@\n", [error localizedDescription]);
    [[self connectingLabel] setHidden:0];
    [self doScan];
}

// Disconnected
-(void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected\n");
    [[self connectingLabel] setHidden:0];
    [self doScan];
}

// Got a new value, finish setup or read sensor data
-(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_IR_TEMP_ID]]) {
        // figure out which sensor is used and process the data
        if (currentSensor == SENSOR_TYPE_MLX90620) {
            
            //NSLog(@"Got Temp Data %@", characteristic.value);
 
            [sensorData removeAllObjects];

            //NSData *da = [NSData dataWithBytes:bytes length:length];
    
            for (int i = 0; i < 66; i++) {
            
                // convert to signed integer
                int *intBytes = (NSInteger*)[[characteristic.value subdataWithRange:NSMakeRange(i*2, 2)] bytes];
                int raw = CFSwapInt16LittleToHost(*intBytes);
                if (raw > 32767) {
                    raw = raw - 65536;
                }
                //NSLog(@"Raw %i: %i",i, raw);
           
                [sensorData addObject:[NSString stringWithFormat:@"%d", raw]];
            }
            // update the display overlay
            //[self update:sensorData];
            [self updateColors];
            //take another reading
            [blePeripheral readValueForCharacteristic:bleIRData];
        }
        
        else if (currentSensor == SENSOR_TYPE_GRID_EYE) {
            // update the display overlay
            [self UpdateGridEye:characteristic.value];
        }
        
    }
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_EEPROM_ID]])
    {
        NSLog(@"Got EEPROM Data %@", characteristic.value);
        
        for (int i = 0; i < 255; i++) {
            // convert hex to integer
            int intPtr = *(int *)[[characteristic.value subdataWithRange:NSMakeRange(i, 1)] bytes];
            
            [eepromData addObject:[NSString stringWithFormat:@"%d", intPtr]];
            
        }
        
        [self processEEPROMData];
        //[blePeripheral readValueForCharacteristic:bleEEPROMData];
        //[blePeripheral setNotifyValue:YES forCharacteristic:bleTemp1];
        //[blePeripheral setNotifyValue:YES forCharacteristic:bleTemp2];
        //[blePeripheral setNotifyValue:YES forCharacteristic:bleTemp3];
        //[blePeripheral setNotifyValue:YES forCharacteristic:bleTemp4];
        [blePeripheral readValueForCharacteristic:bleIRData];
    }
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_SENSOR_TYPE]]) {
        int *type = (NSInteger*)[characteristic.value bytes];
        currentSensor = *type;
        if (currentSensor == SENSOR_TYPE_MLX90620) {
            [blePeripheral readValueForCharacteristic:bleEEPROMData];
        }
        else if (currentSensor == SENSOR_TYPE_GRID_EYE) {
            [blePeripheral readValueForCharacteristic:bleTemp];
        }
    }
}

#pragma mark - Grid-Eye Section

-(void)UpdateGridEye:(NSData*)gridEyeData {
    // Choose the Layer to place the tempdata
    CALayer *myLayer = filterView.layer;
    
    int rowCount = 0;
    int columnCount = 0;
    int row = tempPositionXOffset + (tempPointHeight * 2);
    int column = tempPositionYOffset - (tempPointWidth * 7.5);
    int irDataLoops = 64;
    //NSLog(@"Ta = %f", Ta);
    
    if (myLayer.sublayers.count < 5) {
        // Loop through the 64 temp readings and add layers to the View
        
        for (int i = 0; i < irDataLoops; i = i+1) {
            int temp = *(int *)[[gridEyeData subdataWithRange:NSMakeRange(i, 1)] bytes];
           
            temp = (temp * 9 / 5) + 32; //convert C to F
            
            if (i == 34) {
                // add the single displayed numeric temp reading
                CATextLayer *sublayer = [CATextLayer layer];
                sublayer.fontSize = 20;
                sublayer.string = [NSString stringWithFormat:@"%d", temp]  ;
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                sublayer.opacity = 1;
                //sublayer.drawsAsynchronously = YES;
                [sublayer removeAllAnimations];
                sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight );
                
                [myLayer addSublayer:sublayer];
            }
            else {
                //make new layers then add
                //CATextLayer *sublayer = [CATextLayer layer];
                CALayer *sublayer = [CALayer layer];
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor ;
                sublayer.opacity = 1;
                //sublayer.drawsAsynchronously = YES;
                [sublayer removeAllAnimations];
                sublayer.frame = CGRectMake(column, row, tempPointWidth, tempPointHeight);
                
                [myLayer addSublayer:sublayer];
            }// end checking for text point
            
            // Manage the row and column counts
            if (rowCount < 3) {
                rowCount++;
                row = row - tempPointHeight;
            }
            else {
                rowCount = 0;
                column = column + tempPointWidth;
                columnCount++;
                row = tempPositionXOffset + (tempPointHeight * 2);
            }
        } //end for loop
        
        
    } //end if checking for existing layers
    
    else {
        // Loop through the 64 temp readings and update the layers
        for (int i = 0; i < irDataLoops; i = i+1) {
            int temp = *(int *)[[gridEyeData subdataWithRange:NSMakeRange(i, 1)] bytes];
            
            NSLog(@"Reading: %d  Raw Data: %d",i,temp);
            temp = [math GetTo:temp:i];
            temp = (temp * 9 / 5) + 32; // convert C to F
            NSLog(@"Reading: %d  Temp: %d",i,temp);
            if (i == 34) {
                // change the single displayed numeric temp reading
                CATextLayer *sublayer = [myLayer.sublayers objectAtIndex:i];
                //sublayer.fontSize = 20;
                //sublayer.string = [NSString stringWithFormat:@"%f", temp]  ;
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
            }
            else {
                CALayer *sublayer = [myLayer.sublayers objectAtIndex:i];
                sublayer.backgroundColor = [self mapTempToColor:temp].CGColor;
            }
            
            
            // Manage the row and column counts
            if (rowCount < 3) {
                rowCount++;
                row = row - tempPointHeight;
            }
            else {
                rowCount = 0;
                column = column + tempPointWidth;
                columnCount++;
                row = tempPositionXOffset - (tempPointHeight * 1);
            }
            
        } //end for loop
    } //end else
    
// end if sensordata count
// } // end if touch event check



    [blePeripheral readValueForCharacteristic:bleTemp];
}

#pragma mark - IBActions

- (IBAction)saveButtonAction:(id)sender {

  
    [stillCamera capturePhotoAsImageProcessedUpToFilter:blendFilter withCompletionHandler:^(UIImage *processedImage, NSError *error){

UIImageWriteToSavedPhotosAlbum(processedImage, self, nil, nil);

        {
            return;
        }
    }];
}

- (IBAction)blurButton:(UIButton *)sender {
    if (blurOverlay) {
        blurOverlay = 0;
    }
    else {
        blurOverlay = 1;
    }
    [self stopCamera];
    [self startCamera];
    NSLog(@"Blur Overlay %i",blurOverlay);
}

- (IBAction)autoButton:(UIButton *)sender {
    
    if (autoRanging) {
        autoRanging = 0;
        [[self autoButtonProperty] setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];

    }
    else {
        autoHighTemp = DEFAULT_HIGH_TEMP;
        autoLowTemp = DEFAULT_LOW_TEMP;
        autoRanging = 1;
        [[self autoButtonProperty] setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        
    }
    NSLog(@"Auto Ranging %i",autoRanging);
}

- (IBAction)rangeMinus:(UIButton *)sender {
    lowTemp = lowTemp + 1;
    highTemp = highTemp -1;
    NSLog(@"Low: %f, High: %f",lowTemp,highTemp);
}

- (IBAction)rangePlus:(UIButton *)sender {
    lowTemp = lowTemp - 1;
    highTemp = highTemp + 1;
    NSLog(@"Low: %f, High: %f",lowTemp,highTemp);
}

- (IBAction)midPlusButton:(UIButton *)sender {
    lowTemp = lowTemp + 1;
    highTemp = highTemp + 1;
    NSLog(@"Low: %f, High: %f",lowTemp,highTemp);
}

- (IBAction)midMinusButton:(UIButton *)sender {
    lowTemp = lowTemp - 1;
    highTemp = highTemp - 1;
    NSLog(@"Low: %f, High: %f",lowTemp,highTemp);
}

- (IBAction)colorButton:(UIButton *)sender {
    if (colorType == 3) {
        colorType = 1;
    }
    else {
        colorType++;
    }
    NSLog(@"Overlay Color %i",colorType);
}

- (IBAction)showTempButton:(UIButton *)sender {
    if (showTemp) {
        showTemp = 0;
        [[self centerTempLabel] setHidden:1];
    }
    else {
        showTemp = 1;
        [[self centerTempLabel] setHidden:0];
    }
    NSLog(@"Show Center Temp %i",showTemp);
}


@end

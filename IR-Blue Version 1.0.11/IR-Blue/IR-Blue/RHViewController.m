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
#define DEFAULT_OPACITY 1 // not used right now
#define DEFAULT_BLENDMIX 0.8 //opacity of the color overlay
#define DEFAULT_COLOR_TYPE 1 //1 color, 2 saturation, 3 grey
#define DEFAULT_TEMPERATURE_DISPLAY 0 // 0 F, 1 C, 2 K

// List of sensors, bluetooth characteristic xgatt_sensor_type tells the application which one to use
#define SENSOR_TYPE_MLX90620 1
#define SENSOR_TYPE_GRID_EYE 0

// average the 4 center readings or just use the upper right center reading
#define CENTER_TEMP 0

// Bluegiga BLE-112 UUIDs
// The UUID of the Thermal Imaging Service and Characteristics
#define BLE112_SERVICE_ID @"928f41ba-6e8b-4b17-90ba-3e81fcefb6d0" // Thermal Imaging Sensor Service
#define BLE112_IR_TEMP_ID @"05144cc7-e844-4516-a7c2-dc0afb613b7e" // xgatt_read_temp
#define BLE112_EEPROM_ID @"35a8129a-a34a-421c-82bb-9a5723164b3e"  // xgatt_read_eeprom
#define BLE112_TEMP1_ID @"b9f76bcf-56f3-4c4e-8cf1-b774945f53fa"   // xgatt_read_temp1
#define BLE112_TEMP2_ID @"6de465d5-7c07-4e26-a9d0-c3f444277aca"   // xgatt_read_temp2
#define BLE112_TEMP3_ID @"4491508d-9295-4c90-a6fe-92b222717611"   // xgatt_read_temp3
#define BLE112_TEMP4_ID @"6ba26639-73c4-4426-86c1-b6eded9c64fa"   // xgatt_read_temp4
#define BLE112_SENSOR_TYPE @"15a539e4-db0f-4870-90f0-42b29ca75b3d" // xgatt_sensor_type


// BlueRadios BR-LE4.0-D2
// The UUID of the Thermal Imaging Service and Characteristics
#define BRSP_BLUERADIOS_BLE_UUID @"84F5D868-F36F-1859-7E03-195B16AF790B"
#define BRSP_SERVICE_UUID @"DA2B84F1-6279-48DE-BDC0-AFBEA0226079"
#define BRSP_INFOCHARACTERISTIC_UUID @"99564A02-DC01-4D3C-B04E-3BB1EF0571B2"
#define BRSP_MODECHARACTERISTIC_UUID @"A87988B9-694C-479C-900E-95DFA6C00A24"
#define BRSP_RXCHARACTERISTIC_UUID @"BF03260C-7205-4C25-AF43-93B1C299D159"
#define BRSP_TXCHARACTERISTIC_UUID @"18CDA784-4BD3-4370-85BB-BFED91EC86AF"
#define BRSP_CTSCHARACTERISTIC_UUID @"0A1934F5-24B8-4F13-9842-37BB167C6AFF"
#define BRSP_RTSCHARACTERISTIC_UUID @"FDD6B4D3-046D-4330-BDEC-1FD0C90CB43B"


{
    NSTimer *updateTimer;
    int showTempType;
    int tempPointHeight;
    int tempPointWidth;
    int tempPositionXOffset;
    int tempPositionYOffset;
    double irDataXOffset;
    double irDataYOffset;
    int receivingBRSPDataType;
    int sensorFOV;
    double screenWidth;
    double screenHeight;
    NSString *tempData;
    NSMutableArray *eepromData;
    NSMutableArray *sensorData;
    NSMutableArray *pastSensorData;
    NSMutableArray *workingSensorData;
    NSMutableArray *irOffset;
    NSMutableArray *iSensorData;
    NSMutableArray *bleServices;

    int cameraStatus;
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
    
    //CBCentralManager *centralManager;
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
@synthesize brspObject;
@synthesize brspBuffer1;
@synthesize brspBuffer2;

#pragma mark - Initialization

- (void)viewDidLoad
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [RHAppDelegate app].cbCentral = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    [[self centerTempLabel] setText:@"Connecting"];
    
    [self initializeThings];
    [self startCamera];
    
    // Temp fake data init for testing
    //[self getEEPROMData];
    //updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
    
    [self doScan];
}

- (void)viewWillAppear:(BOOL)animated {


    [super viewWillAppear:animated];
}


- (void)initializeThings
{

    screenHeight = 480.0;  //screen camera preview size height
    screenWidth = 720.0;  //screen camera preview size width
    tempPointWidth = 40; // Individual sensor point width
    tempPointHeight = 40; // Individual sensor point height
    tempPositionXOffset = 100; // Where to start drawing
    tempPositionYOffset = 280; // Where to start drawing
    irDataXOffset = 0; //alignment X offset
    irDataYOffset = 0; //alignment Y offset
    readingCount = 0;
    readingType = 1; // Read EEPROM data first
    newData = 0; // Is new IR data available
    showTempType = DEFAULT_TEMPERATURE_DISPLAY; // 0 is Fahrenheit, 1 is Celsius, 2 is Kelvin
    receivingBRSPDataType = 0; // keep track of the data type coming in on BRSP connection
    
    waiting = NO;
    sensorData = [[NSMutableArray alloc] init];
    eepromData = [[NSMutableArray alloc] init];
    bleServices = [[NSMutableArray alloc] init];
    pastSensorData = [[NSMutableArray alloc] init];
    workingSensorData = [[NSMutableArray alloc] init];
    brspBuffer1 = [[NSMutableString alloc] init];
    brspBuffer2 = [[NSMutableString alloc] init];
    
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
    
    
    //setup alignment buttons
    [[self upButtonProperty] setHidden:true];
    [[self rightButtonProperty] setHidden:true];
    [[self leftButtonProperty] setHidden:true];
    [[self downButtonProperty] setHidden:true];
    
    
    
}

- (NSArray*)getColorArrayTemp {
    if (colorArrayTemp[63] != nil) {
    NSArray* a = [NSArray arrayWithObjects:colorArrayTemp count:64];
    return a;
    }
    else return nil;
}

-(double)getXOffset {
    return irDataXOffset;
}

-(double)getYOffset {
    return irDataYOffset;
}

- (void)startCamera
{
    
    stillCamera = [[GPUImageStillCamera alloc] init];
    
    stillCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
    [stillCamera forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];
    filter = [[GPUImageHarrisCornerDetectionFilter alloc] init];
    [filter forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];
    filterView = (GPUImageView *)self.view;
    
    
    filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    
    [stillCamera addTarget:filter];
    
    GPUImageCrosshairGenerator *crosshairGenerator = [[GPUImageCrosshairGenerator alloc] init];
    //CGFloat sensorSize = 21; // 30˚FOV Sensor
    CGFloat sensorSize = 42;  // 60˚ FOV Sensor
    crosshairGenerator.crosshairWidth = sensorSize;
    [crosshairGenerator setBackgroundColorRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    [crosshairGenerator forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];

    __weak RHViewController *blockSelf = self;

    
    [(GPUImageHarrisCornerDetectionFilter *)filter setCornersDetectedBlock:^(GLfloat* cornerArray, NSUInteger cornersDetected, CMTime frameTime) {

        RHViewController *strongSelf = blockSelf;
        
        
        NSArray* a = [NSArray arrayWithArray:[strongSelf getColorArrayTemp]];
        double xOffset = [strongSelf getXOffset];
        double yOffset = [strongSelf getYOffset];
        
        UIColor* colorArrayLocal[64];
        if (a.count > 0) {
            for (int i = 0; i < 64; i++) {
                colorArrayLocal[i] = [a objectAtIndex:i];
            }
        }
        
        GLfloat* myArray = calloc(128 * 4, sizeof(GLfloat));
        CGFloat scaledSensorHeight = (sensorSize/240);
        CGFloat scaledSensorWidth = (sensorSize/360);
        CGFloat startC = 0.5 - (scaledSensorWidth * 12) + xOffset;
        CGFloat startR = 0.5 - (scaledSensorHeight * 2) + yOffset;
        int rowCount = 0;
        int colCount = 0;
        // build the Sensor data grid
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
        

        
        [crosshairGenerator renderCrosshairsFromArray:myArray count:64 colors:colorArray frameTime:frameTime];
            
    }];
 

    GPUImageGaussianBlurFilter *gFilter = [[GPUImageGaussianBlurFilter alloc] init];
    gFilter.blurSize = 4;
    [gFilter forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];
    blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
    blendFilter.mix = blendFilterMix;
    [blendFilter forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];
    
    GPUImageGammaFilter *gammaFilter = [[GPUImageGammaFilter alloc] init];
    [gammaFilter forceProcessingAtSize:CGSizeMake(screenWidth, screenHeight)];
    
    
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
    cameraStatus = 1;
    
}

-(void) stopCamera {
    [stillCamera stopCameraCapture];
    cameraStatus = 0;
}

-(void) restartCamera {
    if (!cameraStatus) {
        [stillCamera startCameraCapture];
    }

}

-(void)appWillResignActive //:(NSNotification*)note
{
    [self stopCamera];
    glFinish();
    NSLog(@"App paused, camera stopped");
}

-(void)appDidBecomeActive //:(NSNotification*)note
{
    [self restartCamera];
    NSLog(@"App resumed, camera started");
}

-(void)appWillTerminate:(NSNotification*)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    
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
        
        
        // Average the center temp from center 4 pixels. Needs more work using lower right center pixel for now
        switch (i) {

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
    
    [self updateLabelText:currentHighTemp :currentLowTemp];

}

-(void) updateLabelText :(int) highTempValue :(int) lowTempValue {
    switch (showTempType) {
        case 0: // Fahrenheit
            centerTemp = centerTemp3;
            break;
        case 1: // Celsius
            highTempValue = (highTempValue  -  32) * 5 / 9;
            lowTempValue = (lowTempValue  -  32) * 5 / 9;
            centerTemp = (centerTemp3 - 32) * 5 / 9;
            break;
        case 2: // Kelvin
            highTempValue = ((highTempValue - 32) * 5 / 9) + 273 ;
            lowTempValue = ((lowTempValue - 32) * 5 / 9) + 273 ;
            centerTemp = ((centerTemp3 - 32) * 5 / 9) + 273 ;
            break;
            
        default:
            break;
    }
        self.highTempLabel.text = [NSString stringWithFormat:@"High %d", highTempValue];
    self.lowTempLabel.text = [NSString stringWithFormat:@"Low %d", lowTempValue];
    
    //if (CENTER_TEMP) {
    //centerTemp = (centerTemp1 + centerTemp2 + centerTemp3 + centerTemp4)/4;
    //}
    //else {
    //    centerTemp = centerTemp3;
    //}
   
    [[self centerTempLabel] setText:[NSString stringWithFormat:@"%.1lf", centerTemp]];
    
}

-(void) updateStatusLabel {

    
    switch (showTempType) {
        case 0: // Fahrenheit
            [[self connectingLabel] setTitle:@"˚F" forState:UIControlStateNormal];
            break;
        case 1: // Celsius
            [[self connectingLabel] setTitle:@"˚C" forState:UIControlStateNormal];
            break;
        case 2: // Kelvin
            [[self connectingLabel] setTitle:@"˚K" forState:UIControlStateNormal];
            break;
            
        default:
            break;
    }
    
    [[self connectingLabel].titleLabel setFont:[UIFont boldSystemFontOfSize:24]];
}

// Map the temperature to color value
-(float) map :(float) inMin :(float) inMax :(float) outMin :(float) outMax :(float) inValue {
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

- (UIColor *)mapTempToIron:(int)tempValue { //not used yet, still working on it.
    
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

- (void) startDemoMode {
    NSLog(@"Starting Demo Mode");
}

#pragma mark - MLX90620 CALayer stuff


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
    NSLog(@"Got a Memory Warning");
    //Dispose of any resources that can be recreated.
}


#pragma mark - BLE Central Manager Delegate

-(void)centralManagerDidUpdateState:(CBCentralManager *)central {

    [self displayState];
}

-(void)displayState {
    NSString * str;
    switch ([RHAppDelegate app].cbCentral.state) {
        case CBCentralManagerStateUnknown:
            str = @"Unknown\n";
            break;
        case CBCentralManagerStateUnsupported:
            {
            str = @"Unsupported\n";
            NSString *message = @"This App requires an Apple device that supports Bluetooth 4. ";
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bluetooth 4 unsupported" message: message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
                [self startDemoMode];
            break; }
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
    
    CBUUID * ThermalImagingUUID = [CBUUID UUIDWithString:BLE112_SERVICE_ID];
    CBUUID * BRSPServiceUUID = [CBUUID UUIDWithString:BRSP_SERVICE_UUID];
    [[RHAppDelegate app].cbCentral scanForPeripheralsWithServices:[NSArray arrayWithObjects:ThermalImagingUUID, BRSPServiceUUID, nil] options:nil];
    NSLog(@"Started Scanning");
}

// Found a Device, connect to it
-(void) centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI{
    NSMutableString * mStr = [[NSMutableString alloc] initWithString:@"Discovered\n"];
    [mStr appendFormat:@"name: %@\n", peripheral.name];
    //[mStr appendFormat:@"%@\n", CFUUIDCreateString(NULL, peripheral.UUID)];
    
    [mStr appendFormat:@"RSSI: %@\n", RSSI];
    [[RHAppDelegate app].cbCentral stopScan];
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
    
    //NSLog(@"Connecting to:\n%@\n", CFUUIDCreateString(NULL, blePeripheral.UUID));
    [[RHAppDelegate app].cbCentral connectPeripheral:blePeripheral options:nil];
    }
}

// Connected to the Device, now discover the services
- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    //peripheral = peripheral;
    if ([peripheral.name isEqual: @"IR-Blue-DM"]) {
        NSLog(@"Found an IR-Blue-DM");
        
    
        [RHAppDelegate app].cbCentral.delegate = self;
        
        //init the object with default buffer sizes of 1024 bytes
        //    self.brspObject = [[Brsp alloc] initWithPeripheral:peripheral];
        //init with custom buffer sizes
        self.brspObject = [[Brsp alloc] initWithPeripheral:peripheral InputBufferSize:512 OutputBufferSize:512];
        
        //It is important to set this delegate before calling [Brsp open]
        self.brspObject.delegate = self;
        
        [self.brspObject open]; //call the open function to prepare the brsp service
    }
    else {
        CBUUID * ThermalImagingUUID = [CBUUID UUIDWithString:BLE112_SERVICE_ID];
        [blePeripheral discoverServices:[NSArray arrayWithObject:ThermalImagingUUID]];
        
    }
    
    NSLog(@"isConnected: %i\n", peripheral.isConnected);
    
    
    [self updateStatusLabel];
    
}


// Found the Service we are looking for, get the Characteristics from it
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    bleThermalImagingService = peripheral.services.lastObject;
    NSLog(@"Services found: %u\n", peripheral.services.count);
    [self getAllCharacteristicsFromThermalImagingService:blePeripheral];

}

// Get the Characteristics
-(void) getAllCharacteristicsFromThermalImagingService:(CBPeripheral *)peripheral {
    CBUUID * eeUUID = [CBUUID UUIDWithString:BLE112_EEPROM_ID];
    CBUUID * irUUID = [CBUUID UUIDWithString:BLE112_IR_TEMP_ID];
    CBUUID * ttUUID = [CBUUID UUIDWithString:BLE112_SENSOR_TYPE];
    
    [peripheral discoverCharacteristics:[NSArray arrayWithObjects:eeUUID,irUUID,ttUUID, nil] forService:bleThermalImagingService];
    
}

// Got the Characteristics, assign them and either read the EEPROM from the MLX90620 or start reading the data from the Grid-Eye
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *bleCharacteristic in service.characteristics) {
        if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_EEPROM_ID]])
        {
            bleEEPROMData = bleCharacteristic;            
            NSLog(@"Found EEPROM Characteristic");
        }
        else if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_IR_TEMP_ID]])
        {
            bleIRData = bleCharacteristic;
            NSLog(@"Found IR Temp Array Characteristic");
        }
        else if([bleCharacteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_SENSOR_TYPE]])
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
    [[self centerTempLabel] setText:@"Connecting"];
    [self doScan];
}

// Disconnected
-(void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected\n");
    [[self centerTempLabel] setText:@"Connecting"];
    [self doScan];
}

// Got a new value, finish setup or read sensor data
-(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_IR_TEMP_ID]]) {
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
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_EEPROM_ID]])
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
    else if([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE112_SENSOR_TYPE]]) {
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
            
            //NSLog(@"Reading: %d  Raw Data: %d",i,temp);
            temp = [math GetTo:temp:i];
            temp = (temp * 9 / 5) + 32; // convert C to F
            //NSLog(@"Reading: %d  Temp: %d",i,temp);
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

#pragma mark - BrspDelegate

- (void)brsp:(Brsp*)brsp OpenStatusChanged:(BOOL)isOpen {
        NSLog(@"OpenStatusChanged == %d", isOpen);
    if (isOpen) {
        //The BRSP object is ready to be used
        
        //Print the security level of the brsp service to console
        NSLog(@"BRSP Security Level is %d", brspObject.securityLevel);
        
        //Start the Data
        [self startBRSPData];
        
    } else {
        //brsp object has been closed
        NSLog(@"BRSP Closed");
    }
}
- (void)brsp:(Brsp*)brsp SendingStatusChanged:(BOOL)isSending {
    //This is a good place to change BRSP mode
    //If we are on the last command in the queue and we are no longer sending, change the mode back to previous value
    if (isSending == NO && _commandQueue.count == 1)
    {
        if (_lastMode == brspObject.brspMode)
            return;  //Nothing to do here
        //Change mode back to previous setting
        NSError *error = [brspObject changeBrspMode:_lastMode];
        if (error)
            NSLog(@"%@", error);
    }
}
- (void)brspDataReceived:(Brsp*)brsp {
    //If there are items in the _commandQueue array, assume this data is part of a command response
    if (_commandQueue.count > 0)
    {

    }
    else
    {
        //The data comming in is not from a sent command
        //process the data and remove from the input buffer using a readString
        [self processBRSPData:[brspObject readString]];
    }
}

- (void)brsp:(Brsp*)brsp ErrorReceived:(NSError*)error {
    NSLog(@"BRSP Error: %@", error.description);
}

- (void)brspModeChanged:(Brsp*)brsp BRSPMode:(BrspMode)mode {
        NSLog(@"BRSP Mode changed to %d", mode);
    switch (mode) {
        case BrspModeData:
            // do something if needed
            break;
        case BrspModeRemoteCommand:
            // do something if needed
            break;
            
        default:
            break;
    }
}



#pragma mark - BRSP Commands

//-(void)waitForBRSP {
//    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(startBRSPData) userInfo:nil repeats:NO];
//}

- (void)startBRSPData {
    
    //if (brspObject.brspMode != BrspModeData)
        
        //[self.brspObject changeBrspMode:BrspModeData]; //change brsp mode to data

    NSError *error = [self.brspObject writeString:@"R001"]; // start data flow command 
    if (error)
        NSLog(@"BRSP Data Error: %@", error.description);

}

//Flips the brsp mode between data and remote command
- (IBAction)changeMode:(id)sender {
    BrspMode newMode = (self.brspObject.brspMode==BrspModeData) ? BrspModeRemoteCommand : BrspModeData;
    
    NSError *error = [brspObject changeBrspMode:newMode];
    if (error)
        NSLog(@"%@", error);
}

//Returns the data portion from a command response string.  (String between the 3rd and 4th "\r\n"
-(NSString*)parseCommandData:(NSString*)fullCommandResponse {
    NSArray *array = [fullCommandResponse componentsSeparatedByString:@"\r\n"];
    if (array && array.count > 3)
        return [array objectAtIndex:3];
    else
        return @"";
}

//Outputs the next command in the _sentCommands array with the response and removes it from the array
-(void)outputCommandWithResponse:(NSString*)response {

}

-(void)sendCommand:(NSString *)str {
    if (![[str substringFromIndex:str.length-1] isEqualToString:@"\r"])
        str = [NSString stringWithFormat:@"%@\r", str];  //Append a carriage return
    //Write as string
    NSError *writeError = [self.brspObject writeString:str];
    if (writeError)
        NSLog(@"%@", writeError.description);
}

-(void)processBRSPData:(NSString *)str {
    if (!str || !str.length) return;  //Nothing to do
    

    switch (receivingBRSPDataType)
    {
        case 0:
        {
            // add new data to last examined chunk (if any)
            [brspBuffer1 appendString:str];
            
            // try to locate the open tag inside the tmpBuffer
            NSRange range = [brspBuffer1 rangeOfString:@"E" options:NSCaseInsensitiveSearch];
            
            // if found, store the portion after the start tag into buffer
            if(range.location != NSNotFound) {
                range.length = [brspBuffer1 length] - range.location + 1; // 5 is length of start tag...
                if (range.length > 2) {
                    [brspBuffer2 setString:[brspBuffer1 substringWithRange:range]];
                }
                receivingBRSPDataType = 1; // set status to 1 so we know recording started
                NSLog(@"EEPROM Start");
            } else {
                // store last examined chunk
                [brspBuffer1 setString:str];
            }
        }
            break;
        case 1:
        {
            [brspBuffer2 appendString:str];
            NSRange range = [brspBuffer2 rangeOfString:@"EX" options:NSCaseInsensitiveSearch];
            if(range.location != NSNotFound) {
                range.length = [brspBuffer2 length] - range.location;
                [brspBuffer2 deleteCharactersInRange:range];
                receivingBRSPDataType = 2;
                
                //process EEPROM Data
                //NSArray *eepromDataArray = [brspBuffer2 componentsSeparatedByString:@" "];
                for (int i = 0; i < 765; i = i + 3) {
                    
                    NSString *eepromDataPoint = [brspBuffer2 substringWithRange:NSMakeRange(i, 3)];
                    [eepromData addObject:eepromDataPoint];
                }
                

                NSLog(@"EEPROM Array %@", brspBuffer2);
                NSLog(@"EEPROM Array %@ Count %lu", eepromData, (unsigned long)eepromData.count);
                [self processEEPROMData];

                
                NSLog(@"EEPROM End");
                // 
                [brspBuffer1 setString:@""];
                [brspBuffer2 setString:@""];
            }
        }
            break;
        case 2:
        {
            // add new data to last examined chunk (if any)
            [brspBuffer1 appendString:str];
            brspBuffer1 = [[brspBuffer1 stringByReplacingOccurrencesOfString:@"\n" withString:@""] mutableCopy];
            // try to locate the open tag inside the tmpBuffer
            NSRange range = [brspBuffer1 rangeOfString:@"R" options:NSCaseInsensitiveSearch];
            
            // if found, store the portion after the start tag into buffer
            if(range.location != NSNotFound) {
                //NSLog(@"Buffer 1: %@", brspBuffer1);
                
                range.length = [brspBuffer1 length] - range.location + 1; // 5 is length of start tag...
                if (range.length > 2) {
                    //[brspBuffer2 setString:[brspBuffer1 substringWithRange:range]];
                    brspBuffer1 = [[brspBuffer1 stringByReplacingOccurrencesOfString:@"R" withString:@""] mutableCopy];
                }
                receivingBRSPDataType = 3; // set status to 1 so we know recording started
                //NSLog(@"Found IR Data Start");
            } else {
                // store last examined chunk
                [brspBuffer1 setString:str];
            }
        }
            break;
        case 3:
        {
            [brspBuffer2 appendString:str];
            NSRange range = [brspBuffer2 rangeOfString:@"X" options:NSCaseInsensitiveSearch];
            if(range.location != NSNotFound) {
                range.length = [brspBuffer2 length] - range.location;
                [brspBuffer2 deleteCharactersInRange:range];
                receivingBRSPDataType = 2;
                //NSLog(@"Found IR Data End");
                //NSLog(@"Buffer 2: %@", brspBuffer2);
                
                brspBuffer2 = [[brspBuffer2 stringByReplacingOccurrencesOfString:@"I" withString:@""] mutableCopy];
                NSError *error = nil;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"  +" options:NSRegularExpressionCaseInsensitive error:&error];
                NSString *irData = [regex stringByReplacingMatchesInString:brspBuffer2 options:0 range:NSMakeRange(0, [brspBuffer2 length]) withTemplate:@" "];
                //NSLog(@"Buffer 2: %@", irData);
                
                NSArray *irDataArray = [irData componentsSeparatedByString:@" "];
                
                [sensorData removeAllObjects];
                
                //NSLog(@"Array %@", irDataArray);
                [sensorData addObjectsFromArray:irDataArray]; // update the sensor data array
                
                // make the data compatible between iPhone and Android
                if ([[sensorData objectAtIndex:0] length] == 18) {
                    [sensorData addObject:[[sensorData objectAtIndex:0] substringWithRange:NSMakeRange(3, 6)]]; //add PTAT to end of Array
                    [sensorData addObject:[[sensorData objectAtIndex:0] substringWithRange:NSMakeRange(12, 6)]]; //add CPIX to end of Array
                    [sensorData removeObjectAtIndex:0]; //remove the PTAT and CPIX from the front
                    
                    //NSLog(@"Array %@", sensorData);
                    
                    [self updateColors]; // update the screen
                }
 

                
                [brspBuffer1 setString:@""];
                
                [brspBuffer2 setString:@""];
            }
        }
            break;
        case 4:
        {
            
        }
            break;
            
        default:
            break;
    }

}


#pragma mark - IBActions

- (IBAction)leftButton:(id)sender {
    irDataXOffset = irDataXOffset - .01;
    
    //move the temp text label
    CGRect textFieldFrame=self.centerTempLabel.frame;
    textFieldFrame.origin.x-=2;
    self.centerTempLabel.frame=textFieldFrame;
}

- (IBAction)downButton:(UIButton *)sender {
    irDataYOffset = irDataYOffset + .01;
    
    //move the temp text label
    CGRect textFieldFrame=self.centerTempLabel.frame;
    textFieldFrame.origin.y+=2;
    self.centerTempLabel.frame=textFieldFrame;
}

- (IBAction)rightButton:(UIButton *)sender {
    irDataXOffset = irDataXOffset + .01;
    
    //move the temp text label
    CGRect textFieldFrame=self.centerTempLabel.frame;
    textFieldFrame.origin.x+=2;
    self.centerTempLabel.frame=textFieldFrame;
}

- (IBAction)upButton:(UIButton *)sender {
    irDataYOffset = irDataYOffset - .01;
    
    //move the temp text label
    CGRect textFieldFrame=self.centerTempLabel.frame;
    textFieldFrame.origin.y-=2;
    self.centerTempLabel.frame=textFieldFrame;
}

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

- (IBAction)alignButton:(UIButton *)sender {
    if ([self upButtonProperty].hidden) {
        [[self upButtonProperty] setHidden:false];
        [[self rightButtonProperty] setHidden:false];
        [[self leftButtonProperty] setHidden:false];
        [[self downButtonProperty] setHidden:false];
    }
    else {
    [[self upButtonProperty] setHidden:true];
    [[self rightButtonProperty] setHidden:true];
    [[self leftButtonProperty] setHidden:true];
    [[self downButtonProperty] setHidden:true];
    }
}

- (IBAction)autoButton:(UIButton *)sender {
    
    if (autoRanging) {
        autoRanging = 0;
        [[self autoButtonProperty] setTitleColor:[UIColor redColor] forState:UIControlStateNormal];

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

- (IBAction)statusLabelButton:(UIButton *)sender {
    switch (showTempType) {
        case 0:
            showTempType = 1;
            break;
        case 1:
            showTempType = 2;
            break;
        case 2:
            showTempType = 0;
            break;
            
        default:
            break;
    }
    
    [self updateStatusLabel]; //update the status label
    
    
}


@end

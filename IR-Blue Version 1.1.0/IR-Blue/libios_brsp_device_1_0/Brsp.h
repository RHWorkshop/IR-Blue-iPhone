//
//  Brsp.h
//  ios_brsp_lib
//
//  Created by Michael Testa on 11/1/12.
//  Copyright (c) 2012 BlueRadios, Inc. All rights reserved.
//

//The BRSP service UUID.  Use this in a CBCentralManager scan to filter
#define BRSP_SERVICE_UUID @"DA2B84F1-6279-48DE-BDC0-AFBEA0226079"

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class Brsp;

enum {
    BrspModeIdle = 0,
    BrspModeData = 1,
    BrspModeRemoteCommand = 2,
    BrspModeFirmwareUpdate = 4, //Not implemented yet
};
typedef NSUInteger BrspMode;

@protocol BrspDelegate <NSObject>

@required
/**
 Called when the open status has changed after a call to either open or close.
 No writes etc will work until this method is called with an isOpen status of YES.
 @param brsp    The Brsp object generating this event
 @param isOpen  YES == Open
 */
- (void)brsp:(Brsp*)brsp OpenStatusChanged:(BOOL)isOpen;
/**
 Called when the isSending changes
 @param brsp        The Brsp object generating this event
 @param isSending   YES == Sending
 @see   Brsp.isSending
 */
- (void)brsp:(Brsp*)brsp SendingStatusChanged:(BOOL)isSending;

@optional
/**
 Called when data is received from the peripheral. (inputBuffer written to)
 All data can be retreived from the input buffer via read functions.
 @param brsp    The Brsp object generating this event
 */
- (void)brspDataReceived:(Brsp*)brsp;

/**
 Used to pass on CBPeripheral errors that may occur
 @param brsp    The Brsp object generating this event
 @param error   NSError object containing the error
 */
- (void)brsp:(Brsp*)brsp ErrorReceived:(NSError*)error;

/**
 Called when the BRSP mode changes.
 @param brsp    The Brsp object generating this event
 @param mode    BrspMode of the Brsp Peripheral
 */
- (void)brspModeChanged:(Brsp*)brsp BRSPMode:(BrspMode)mode;

@end

/**
 Class used to interact with the BlueRadios BRSP service on a peripheral 
 */
@interface Brsp : NSObject <CBPeripheralDelegate>

/**
 The delegate used for BrspDelegate events.
 */
@property (nonatomic, weak) id <BrspDelegate> delegate;
/**
 The current BRSP mode of the peripheral.
 Default mode is BrspModeData (Even when peripheral is nil or not connected)
 */
@property (nonatomic, readonly) BrspMode brspMode;
/**
 A pointer to the CBPeripheral object that is associated with this device.
 */
@property (nonatomic, readonly) CBPeripheral *peripheral;
/**
 An integer indicating the level of security enforced by the BRSP service on the opened port
 0 == None, 1 == Unauthenticated Pairing With Encryption, 2 == Authenticated Pairing With Encryption, 99 = Unknown
 */
@property (nonatomic, readonly) NSUInteger securityLevel;
/**
 BRSP open/closed status
 YES = Open
 */
@property (nonatomic, readonly) BOOL isOpen;
/**
 YES if output buffer is not empty.  
 @note  Operations such as changing the BRSP mode can only be done when not sending
 */
@property (nonatomic, readonly) BOOL isSending;
/**
 Total capacity of the input buffer in bytes
 */
@property (nonatomic, readonly) NSUInteger inputBufferSize;
/**
 Total capacity of the output buffer in bytes
 */
@property (nonatomic, readonly) NSUInteger outputBufferSize;
/**
 Number of bytes in the input buffer
 */
@property (nonatomic, readonly) NSUInteger inputBufferCount;
/**
 Number of bytes in the output buffer
 */
@property (nonatomic, readonly) NSUInteger outputBufferCount;
/**
 Number of bytes that can be written to the buffer via write functions
 */
@property (nonatomic, readonly) NSUInteger outputBufferAvailableBytes;

/**
 A Convenience function that returns a CBUUID for the brsp Service
 @return CBUUID object for service "DA2B84F1-6279-48DE-BDC0-AFBEA0226079"
 */
+ (CBUUID *) brspServiceUUID;

/**
 Initializer for this class
 @param peripheral The CBPeripheral object to be used
 @return self
 @note  Changes peripheral.delegate to self.  If peripheral.delegate is set another object, initWithPeripheral and open will have to be called again
 to reinitialize.
 @note  The default input and output buffer sizes are 1024 bytes
 */
- (id)initWithPeripheral:(CBPeripheral*)peripheral;

/**
 An alternate initializer for this class which sets the input and output buffer sizes.
 Use this if the default buffer sizes are not adequate
 @param peripheral  The CBPeripheral object to be used
 @param in_size     The fixed input buffer size to use
 @param out_size    The fixed output buffer size to use
 @return self
 @note  Changes peripheral.delegate to self.  If peripheral.delegate is set another object, initWithPeripheral and open will have to be called again
 to reinitialize.
 @note  The default input and output buffer sizes are 1024 bytes
 */
- (id)initWithPeripheral:(CBPeripheral*)peripheral InputBufferSize:(NSUInteger)in_size OutputBufferSize:(NSUInteger)out_size;

/**
 Changes BRSP mode.
 @param mode    An int used to set the mode of a peripheral.
                1 = data mode, 2 = remote command mode
 @return        An NSError object containing an error caused by an invalid state while attempting to change the mode.
                If successful, return will be nil.
 */
- (NSError*)changeBrspMode:(BrspMode)mode;

/**
 Opens a BRSP connection. (Prepares peipheral for using the BRSP service, characteristics, and notifications)
 */
- (void)open;

/**
 Closes a BRSP connection. (Turns off notifications, etc)
 */
- (void)close;

/**
 Discards all unread data from the receive buffer.
 */
- (void)flushInputBuffer;

/**
 Discards unread data from the start of the input buffer by a number of bytes.
 This is useful when using the peek functions.
 @param     byteCount    Number of bytes to remove
 */
- (void)flushInputBuffer:(NSUInteger)byteCount;

/**
 Discards all unsent data from the transmit buffer.
 */
- (void)flushOutputBuffer;

/**
 Reads bytes without removing them from the input buffer
 @param     byteCount    Number of bytes to read
 @return    Bytes requested as NSData
 @note      If byteCount is greater than the inputBufferCount, function will return all bytes
 @note      If byteCount is 0 or inputBuffer is empty, function will return nil
 @note      All reads are performed synchronously
 */
- (NSData *)peekBytes:(NSUInteger)byteCount;

/**
 Reads bytes without removing them from the input buffer
 @param     byteCount    Number of bytes to read
 @return    Bytes requested as NSString decoded using NSUTF8StringEncoding
 @note      If byteCount is greater than the inputBufferCount, function will return all bytes
 @note      If byteCount == 0 or inputBuffer is empty, will return an empty string
 @note      All reads are performed synchronously
 */
- (NSString *)peekString:(NSUInteger)byteCount;

/**
 Reads all bytes without removing them from the input buffer
 @return    Bytes requested as NSData
 @note      If inputBuffer is empty, function will return nil
 @see       peekBytes:
 */
- (NSData *)peekBytes;

/**
 Reads all bytes without removing them from the input buffer
 @return    Bytes requested as NSString decoded using NSUTF8StringEncoding
 @note      If inputBuffer is empty, will return an empty string
 @see       peekString:
 */
- (NSString *)peekString;

/**
 Reads and removes bytes from the input buffer
 @param     byteCount    Number of bytes to read
 @return    Bytes requested as NSData
 @note      If byteCount is greater than the inputBufferCount, function will return all bytes
 @note      If byteCount is 0 or inputBuffer is empty, will return nil
 @note      All reads are performed synchronously
  */
- (NSData *)readBytes:(NSUInteger)byteCount;

/**
 Reads and removes bytes from the input buffer
 @param     byteCount    Number of bytes to read
 @return    Bytes requested as NSString decoded using NSUTF8StringEncoding
 @note      If byteCount is greater than the inputBufferCount, function will return all bytes
 @note      If byteCount == 0 or inputBuffer is empty, will return an empty string
 @note      All reads are performed synchronously
 */
- (NSString *)readString:(NSUInteger)byteCount;

/**
 Reads and removes all bytes from the input buffer
 @return    Bytes requested as NSData
 @note      If inputBuffer is empty, function will return nil
 @see       readBytes:
 */
- (NSData *)readBytes;

/**
 Reads and removes all bytes from the input buffer
 @return    Bytes requested as NSString decoded using NSUTF8StringEncoding
 @note      If inputBuffer is empty, will return an empty string
 @see       readString:
 */
- (NSString *)readString;

/**
 Writes bytes to the output buffer and starts sending them to the brsp peripheral
 @param     bytes    NSData containing the bytes to send
 @return    An NSError object containing an error caused by an invalid state, not enough buffer space etc.
            If successful, return will be nil.
 @note      All writes to the target peripheral are performed asynchronously.
 */
- (NSError *)writeBytes:(NSData*)bytes;

/**
 Writes a string the output buffer and starts sending to the brsp peripheral
 @param     str     NSString containing the text to send
 @return    An NSError object containing an error caused by an invalid state, not enough buffer space etc.
            If successful, return will be nil.
 @note      Bytes are encoded using NSUTF8StringEncoding
 @note      All writes to the target peripheral are performed asynchronously.
 */
- (NSError *)writeString:(NSString*)str;

@end

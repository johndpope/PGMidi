//
//  PGMidiMessage.h
//  PGMidi
//
//  Created by Yaniv De Ridder on 27/01/13.
//
//

#import <CoreMIDI/CoreMIDI.h>
#import <Foundation/Foundation.h>

#define PGMIDINoteOffStatus 0x80			
#define PGMIDINoteOnStatus 0x90
#define PGMIDIControlChangeStatus 0xB0
#define PGMIDIPitchWheelStatus 0xE0

typedef struct
{
    UInt8 bytes[3];
} MIDIMessageStruct;

@interface PGMidiMessage : NSObject

@property (nonatomic) int status;
@property (nonatomic) int channel;
@property (nonatomic) int value1; //Note, CC, LSB
@property (nonatomic) int value2; //Velocity, Value, MSB

@property (nonatomic) MIDITimeStamp triggerTimeStamp; //time at which the note is triggered

+(PGMidiMessage*) noteOn:(int)note withVelocity:(int)velocity withChannel:(int)channel;
+(PGMidiMessage*) noteOff:(int)note withVelocity:(int)velocity withChannel:(int)channel;
+(PGMidiMessage*) controlChange:(int)cc withValue:(int)value withChannel:(int)channel;
+(PGMidiMessage*) pitchWheel:(int)lsb withMSB:(int)msb withChannel:(int)channel;

-(id) initWithStatus:(int)status withChannel:(int)channel withValue1:(int)value1 withValue2:(int)value2;

/*
 Please note that this is really Note and CC messages as we do not check for value2 equality.
 */
-(BOOL) isEqualToMessage:(PGMidiMessage*)message;

//Used to get the Bytes to send to CoreMIDI
-(MIDIMessageStruct) toBytes;

@end

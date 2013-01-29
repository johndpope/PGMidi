//
//  PGMidiMessage.m
//  PGMidi
//
//  Created by Yaniv De Ridder on 27/01/13.
//
//

#import "PGMidiMessage.h"

@implementation PGMidiMessage

@synthesize status,channel,value1,value2,triggerTimeStamp,receivedTimeStamp,quantizedNoteOffStrategy;

+(PGMidiMessage*) noteOn:(int)note withVelocity:(int)velocity withChannel:(int)_channel
{
    return [[PGMidiMessage alloc] initWithStatus:PGMIDINoteOnStatus withChannel:_channel withValue1:note withValue2:velocity];
}

+(PGMidiMessage*) noteOff:(int)note withVelocity:(int)velocity withChannel:(int)_channel
{
    return [PGMidiMessage noteOff:note withVelocity:velocity withChannel:_channel withQuantizedNoteOffStrategy:QuantizedNoteOffStrategyNone];
}

+(PGMidiMessage*) noteOff:(int)note withVelocity:(int)velocity withChannel:(int)_channel withQuantizedNoteOffStrategy:(QuantizedNoteOffStrategy)strategy
{
    PGMidiMessage* message = [[PGMidiMessage alloc] initWithStatus:PGMIDINoteOffStatus withChannel:_channel withValue1:note withValue2:velocity];
    message.quantizedNoteOffStrategy = strategy;
    
    return message;
}

+(PGMidiMessage*) controlChange:(int)cc withValue:(int)value withChannel:(int)_channel
{
    return [[PGMidiMessage alloc] initWithStatus:PGMIDIControlChangeStatus withChannel:_channel withValue1:cc withValue2:value];
}

+(PGMidiMessage*) pitchWheel:(int)lsb withMSB:(int)msb withChannel:(int)_channel
{
    return [[PGMidiMessage alloc] initWithStatus:PGMIDIPitchWheelStatus withChannel:_channel withValue1:lsb withValue2:msb];
}

-(id) initWithStatus:(int)_status withChannel:(int)_channel withValue1:(int)_value1 withValue2:(int)_value2
{
    self = [super init];
    
    if (self)
    {
        status = _status;
        channel = _channel;
        value1 = _value1;
        value2 = _value2;
        
        triggerTimeStamp = 0;
        receivedTimeStamp = 0;
    }
    
    return self;
}

-(BOOL) isEqualToMessage:(PGMidiMessage*)message
{
    if(message.status == status && message.channel == channel && message.value1 == value1)
        return YES;
    
    return NO;
}

-(MIDIMessageStruct) toBytes
{
    MIDIMessageStruct message  = { {(UInt8)(status+channel-1), (UInt8)value1, (UInt8)value2} };
    
    return message;
}

@end

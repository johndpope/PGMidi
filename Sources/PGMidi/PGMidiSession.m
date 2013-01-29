//
//  PGMidiSession.m
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//  Modified by Yaniv De Ridder
//

#import "PGMidiSession.h"

@interface QuantizedBlock : NSObject

@property (atomic,copy) void(^block)();
@property (nonatomic) double interval;
@property (nonatomic) int extraBars;
@property (nonatomic) BOOL executeOnMainThread;

@end

@implementation QuantizedBlock

@synthesize block, interval, extraBars,executeOnMainThread;

@end

#include <mach/mach.h>
#include <mach/mach_time.h>

//These definitions taken directly from VVOpenSource (https://code.google.com/p/vvopensource/) Thank you!

//	these are all STATUS MESSAGES: all status mesages have bit 7 set.  ONLY status msgs have bit 7 set to 1!
//	these status messages go to a specific channel (these are voice messages)
#define VVMIDINoteOffVal 0x80			//	+2 data bytes
#define VVMIDINoteOnVal 0x90			//	+2 data bytes
#define VVMIDIAfterTouchVal 0xA0		//	+2 data bytes
#define VVMIDIControlChangeVal 0xB0		//	+2 data bytes
#define VVMIDIProgramChangeVal 0xC0		//	+1 data byte
#define VVMIDIChannelPressureVal 0xD0	//	+1 data byte
#define VVMIDIPitchWheelVal 0xE0		//	+2 data bytes
//	these status messages go anywhere/everywhere
//	0xF0 - 0xF7		system common messages
#define VVMIDIBeginSysexDumpVal 0xF0	//	signals the start of a sysex dump; unknown amount of data to follow
#define VVMIDIMTCQuarterFrameVal 0xF1	//	+1 data byte, rep. time code; 0-127
#define VVMIDISongPosPointerVal 0xF2	//	+ 2 data bytes, rep. 14-bit val; this is MIDI beat on which to start song.
#define VVMIDISongSelectVal 0xF3		//	+1 data byte, rep. song number; 0-127
#define VVMIDIUndefinedCommon1Val 0xF4
#define VVMIDIUndefinedCommon2Val 0xF5
#define VVMIDITuneRequestVal 0xF6		//	no data bytes!
#define VVMIDIEndSysexDumpVal 0xF7		//	signals the end of a sysex dump
//	0xF8 - 0xFF		system realtime messages
#define VVMIDIClockVal	 0xF8			//	no data bytes! 24 of these per. quarter note/96 per. measure.
#define VVMIDITickVal 0xF9				//	no data bytes! when master clock playing back, sends 1 tick every 10ms.
#define VVMIDIStartVal 0xFA				//	no data bytes!
#define VVMIDIContinueVal 0xFB			//	no data bytes!
#define VVMIDIStopVal 0xFC				//	no data bytes!
#define VVMIDIUndefinedRealtime1Val 0xFD
#define VVMIDIActiveSenseVal 0xFE		//	no data bytes! sent every 300 ms. to make sure device is active
#define VVMIDIResetVal	 0xFF			//	no data bytes! never received/don't send!

@implementation PGMidiSession
{
	double currentClockTime;
	double previousClockTime;
	
	int num96notes;
	
	NSMutableArray *quantizedBlockQueue;
    
    double intervalInNanoseconds;
    double tickDelta;
    
    NSMutableArray* quantizedNoteQueue;
}

@synthesize midi, delegate, bpm, playing;

static PGMidiSession *shared = nil;

+ (PGMidiSession *) sharedSession
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [[PGMidiSession alloc] init];
	});
	
	return shared;
}

- (id) init
{
	self = [super init];
	if (self)
	{
		quantizedBlockQueue = [[NSMutableArray alloc] init];
		
		midi = [[PGMidi alloc] init];
		midi.automaticSourceDelegate = self;
        [midi enableNetwork:YES];
		
		bpm = -1; //signifies no MIDI clock in
        
        //prepare queue with 20 slots (to avoid unecessary memory allocation in the high priority thread later on)
        quantizedNoteQueue = [[NSMutableArray alloc] initWithCapacity:20];
	}
    
	return self;
}

//==============================================================================
#pragma mark PGMidiSessionDelegate 

- (void) midiSource:(PGMidiSource *)source midiReceived:(const MIDIPacketList *)packetList
{
	MIDIPacket *packet = (MIDIPacket*)&packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
		Byte *data = packet->data;
        int statusByte = data[0];
        int status = statusByte >= 0xf0 ? statusByte : statusByte & 0xF0;
		
        if (status == VVMIDIClockVal)
        {
			if (playing)
			{
                /* every MIDI clock packet sent is a 96th note. */
                /* 0 is the downbeat of 1 */
                if (num96notes == 0)
                {
                    for (QuantizedBlock *qb in quantizedBlockQueue)
                    {
                        qb.extraBars--;
                    }
                    //NSLog(@"tick");
                }
                
                for (NSUInteger j = 0; j < quantizedBlockQueue.count; j++)
                {
                    QuantizedBlock *qb = quantizedBlockQueue[j];
                    int interval = (int)(qb.interval*96);
                    if (num96notes % interval == 0 && qb.extraBars <= 0)
                    {
                        //run the block on the main thread to allow UI updates etc
                        if(qb.executeOnMainThread)
                            dispatch_async(dispatch_get_main_queue(), qb.block);
                        else
                            qb.block();
                        
                        [quantizedBlockQueue removeObjectAtIndex:j];
                        j--;
                    }
                }
				
				num96notes = (num96notes + 1) % 96;
			}
			
			/* BPM calculation, taken from http://stackoverflow.com/questions/13562714/calculate-accurate-bpm-from-midi-clock-in-objc-with-coremidi */
            previousClockTime = currentClockTime;
            currentClockTime = packet->timeStamp;
			
            if(previousClockTime > 0 && currentClockTime > 0)
            {
                tickDelta = currentClockTime-previousClockTime;
                intervalInNanoseconds = [self convertTimeInNanoseconds:(Float64)tickDelta];
                bpm = (1000000 / intervalInNanoseconds / 24) * 60;
            }
        }
		else if (status == VVMIDINoteOnVal)
		{
			dispatch_async(dispatch_get_main_queue(), ^
						   {
							   [delegate midiSource:source sentNote:data[1] velocity:data[2]];
						   });
		}
		else if (status == VVMIDIControlChangeVal)
		{
			dispatch_async(dispatch_get_main_queue(), ^
						   {
							   [delegate midiSource:source sentCC:data[1] value:data[2]];
						   });
		}
		else if (status == VVMIDIStartVal)
		{
			playing = YES;
			//reset to 0 -- the immediate next MIDI clock signal will be the downbeat of 1
			num96notes = 0;
            intervalInNanoseconds = 0;
		}
		else if (status == VVMIDIStopVal)
		{
			playing = NO;
            intervalInNanoseconds = 0;
		}
		
        packet = MIDIPacketNext(packet);
    }
}

//==============================================================================
#pragma mark Quantized Perform 

- (void) performBlockOnMainThread:(void (^)(void))block quantizedToInterval:(double)bars
{
	QuantizedBlock *qb = [self createQuantizedBlock:block quantizedToInterval:bars];
    [qb setExecuteOnMainThread:YES];
    [quantizedBlockQueue addObject:qb];
}

- (void) performBlock:(void (^)(void))block quantizedToInterval:(double)bars
{
	QuantizedBlock *qb = [self createQuantizedBlock:block quantizedToInterval:bars];
    [quantizedBlockQueue addObject:qb];
}

//==============================================================================
#pragma mark MIDI Output API

- (void)sendMidiMessage:(PGMidiMessage*)message
{   
    [message setReceivedTimeStamp:mach_absolute_time()];
    
    //If the trigger time stamp is defined then use it.
    if(message.triggerTimeStamp > 0)
    {
        [midi sendBytes:[message toBytes].bytes size:sizeof([message toBytes].bytes) withTime:message.triggerTimeStamp];
    }
    //otherwise we simply trigger the midi message straight away
    else
    {
        [midi sendBytes:[message toBytes].bytes size:sizeof([message toBytes].bytes)];
    }
}

- (void)sendMidiMessage:(PGMidiMessage*)message afterDelay:(NSTimeInterval)delay
{
    message.triggerTimeStamp = mach_absolute_time() + (delay * NSEC_PER_SEC);
    
    [self sendMidiMessage:message];
}

- (void) sendMidiMessage:(PGMidiMessage *)message quantizedToFraction:(double)quantize
{
    //Calculate trigger timestamp
    [message setTriggerTimeStamp:[self calculateMIDITimeStampWithQuantize:quantize]];
    
    for(NSUInteger i=0;i<[quantizedNoteQueue count];i++)
    {
        PGMidiMessage* currentMessage = [quantizedNoteQueue objectAtIndex:i];
        
        //check if the current note was already triggered during the current tick interval
        //We dont want to send multiple times the same note within the same interval.
        if([currentMessage isEqualToMessage:message])
            return;
        
        //Note On of the current Note Off found in the same interval
        //To avoid not hearing the note because the note on and off are going to be triggered at the exact same time
        //-> Apply note off strategy:
        //  1. We take the interval between when the note on was triggered and now and apply the same interval
        //  2. We defer the Note Off until the next quantize step
        if(message.status == PGMIDINoteOffStatus &&
           currentMessage.status == PGMIDINoteOnStatus &&
           currentMessage.channel == message.channel &&
           currentMessage.value1 == currentMessage.value1)
        {
            if(message.quantizedNoteOffStrategy == QuantizedNoteOffStrategySameLength)
            {
                message.triggerTimeStamp += (mach_absolute_time() - currentMessage.receivedTimeStamp);
            }
            else if(message.quantizedNoteOffStrategy == QuantizedNoteOffStrategyOneStep)
            {
                message.triggerTimeStamp = currentMessage.triggerTimeStamp + (tickDelta*quantize*96);//[self calculateMIDITimeStampWithQuantize:quantize withStepDelay:1];
            }
            else if(message.quantizedNoteOffStrategy == QuantizedNoteOffStrategyNone)
            {
                //Nothing
            }

            break;
        }
    }
    
    //Send Message to CoreMIDI
    [self sendMidiMessage:message];
    
    
    //if(message.status == PGMIDINoteOffStatus)
    //    return;
    
    //Add the note that was just queued in CoreMIDI in the quantize queue
    [quantizedNoteQueue addObject:message];
    
    //Delete the note from the queue as soon as it's triggered
    //This is an approximate call because the note triggered by CoreMIDI at a given interval will be much more accurate
    [self performBlock:^{
        [quantizedNoteQueue removeObject:message];
    } quantizedToInterval:quantize];
    
    //dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(message.triggerTimeStamp - mach_absolute_time()));
    //dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
    //          {
    //              [quantizedNoteQueue removeObject:message];
    //          });
}

//==============================================================================
#pragma mark Internal Utils

- (QuantizedBlock*) createQuantizedBlock:(void (^)(void))block quantizedToInterval:(double)bars
{
    QuantizedBlock *qb = [[QuantizedBlock alloc] init];
	qb.block = block;
	qb.extraBars = (int)bars; //truncate to a whole number
	qb.interval =  bars-qb.extraBars; //get the decimal part
	if (qb.interval == 0)
		qb.interval = 1; //if the interval is on a 1 downbeat it'll be 0
	NSLog(@"after %d bars, will run at the %d (currently on %d)",qb.extraBars,(int)(qb.interval*96),num96notes);
    
    return qb;
}

//Calculate MIDI timestamp at which the note should be triggered according to the quantize division
//This is using the MIDI timestamp we got from each clock message and  the interval between 2 clock message for better accuracy.
- (MIDITimeStamp) calculateMIDITimeStampWithQuantize:(double)quantize
{
    return [self calculateMIDITimeStampWithQuantize:quantize withStepDelay:0];
}

- (MIDITimeStamp) calculateMIDITimeStampWithQuantize:(double)quantize withStepDelay:(double)stepDelay
{
    double ticks = quantize*96;
    double remainingTicks = ticks - fmod(num96notes,ticks) + (ticks*stepDelay);
    double triggerTimeStamp = currentClockTime + tickDelta * remainingTicks;
    
    return (MIDITimeStamp)triggerTimeStamp;
}

//Using Float64 to avoid integer overflow
//UINT64_MAX / mach_timebase_info.denom = 3074.457E+9 nanoseconds = 51 minutes
-(uint64_t) convertTimeInNanoseconds:(Float64)time
{
    const int64_t kOneThousand = 1000;
    static mach_timebase_info_data_t s_timebase_info;
	
    if (s_timebase_info.denom == 0)
    {
        (void) mach_timebase_info(&s_timebase_info);
    }
	
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one thousand to get nanoseconds
    return (uint64_t)((time * s_timebase_info.numer) / (kOneThousand * s_timebase_info.denom));
}


@end

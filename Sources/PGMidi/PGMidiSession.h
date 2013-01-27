//
//  PGMidiSession.h
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//
//

#import <Foundation/Foundation.h>
#import "PGMidi.h"

/*
 PGMidiSession is an addition to PGMidi specifically designed for use with a DAW.
 
 How do I use this class?
 It's simple, and requires no client-side setup! You can go right into these (although setting a delegate first thing is preferred to instantiate the singleton and give it time to connect to MIDI sources/destinations).
 
 Sending a note/CC:
	 [[PGMidiSession sharedSession] sendNoteOn:36 withChannel:1 withVelocity:127];
     [[PGMidiSession sharedSession] sendNoteOff:36 withChannel:1 withVelocity:127];
	 [[PGMidiSession sharedSession] sendNote:36 withChannel:1 withVelocity:120 withLength:1];
	 [[PGMidiSession sharedSession] sendCC:5 withChannel:1 withValue:127];
 
 Accessing BPM:
	 [PGMidiSession sharedSession].bpm
 
 Receiving MIDI data:
	 Set [PGMidiSession sharedSession].delegate to a PGMidiSourceDelegate and implement the two delegate methods!
 
 Quantization (the main reason I wrote this class):
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:1];    // Prints "HI" on the next downbeat of a new bar
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:0.25]; // Prints "HI" on the next quarter note
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:1.25]; // Waits till the next bar, then prints "HI" on the next quarter note
 
 
 Troubleshooting:
 
 For quantization and BPM to work, the iOS device must be receiving a MIDI clock signal. For quantization, the iOS device has to "see" a MIDI START signal (ie, in a DAW, the play button). It won't work if it's already playing when the device connects.
 
 If you're having trouble setting this whole thing up, remember you can connect your device via network session in Audio MIDI Setup.app, under Network in the MIDI window.
 */

@protocol PGMidiSessionDelegate;

@interface PGMidiSession : NSObject <PGMidiSourceDelegate>

@property (nonatomic, PGMIDI_DELEGATE_PROPERTY) id<PGMidiSessionDelegate> delegate;
@property (nonatomic, strong) PGMidi *midi;
@property (nonatomic) double bpm;
@property (nonatomic, getter = isPlaying) BOOL playing;

+ (PGMidiSession *) sharedSession;

/* 
 The methods below are used to send Control Change or Note.
 The channel argument is a value between 1 and 16
 */
- (void) sendCC:(int32_t)cc withChannel:(int32_t)channel withValue:(int32_t)value;
- (void) sendPitchWheel:(int)channel withLSBValue:(int)lsb withMSBValue:(int)msb;

- (void) sendNoteOn:(int32_t)note withChannel:(int32_t)channel withVelocity:(int32_t)velocity;
- (void) sendNoteOn:(int)note withChannel:(int)channel withVelocity:(int)velocity quantizedToInterval:(double)quantize;

- (void) sendNoteOff:(int32_t)note withChannel:(int32_t)channel withVelocity:(int32_t)velocity;

- (void) sendNote:(int32_t)note withChannel:(int32_t)channel withVelocity:(int32_t)velocity withLength:(NSTimeInterval)length;

/* 
 In case you need to update some UI elements at a givent quantization division, this will do the trick..
 */
- (void) performBlockOnMainThread:(void (^)(void))block quantizedToInterval:(double)numBarsOrFraction;

/*
 In case you need to perform some logic at a given quantization division in the high priority thread.
 Be careful to not use Blocking IO. 
 
 Quantization accuracy of this method is great for local processing but would not be the best to send midi events as it doesn't account for the latency.
 If you want to send a note at a given quantization division, use sendNoteOn:withChannel:withVelocity:quantizedToInterval instead as it will use CoreMIDI
 timestamp and let CoreMIDI deal with the latency which is very precise and theorically result to a 0ms latency as the midi message is sent in advance 
 to be triggered at a given time in the future.
 */
- (void) performBlock:(void (^)(void))block quantizedToInterval:(double)bars;

@end

@protocol PGMidiSessionDelegate <NSObject>

- (void) midiSource:(PGMidiSource *)source sentNote:(int)note velocity:(int)vel;
- (void) midiSource:(PGMidiSource *)source sentCC:(int)cc value:(int)val;

@end

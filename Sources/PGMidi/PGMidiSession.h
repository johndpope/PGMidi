//
//  PGMidiSession.h
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//  Modified by Yaniv De Ridder
//

#import <Foundation/Foundation.h>
#import "PGMidi.h"
#import "PGMidiMessage.h"

/*
 PGMidiSession is an addition to PGMidi specifically designed for use with a DAW.
 
 How do I use this class?
 It's simple, and requires no client-side setup! You can go right into these (although setting a delegate first thing is preferred to instantiate the singleton and give it time to connect to MIDI sources/destinations).
 
 Sending note on/off:
 
 [[PGMidiSession sharedSession] sendMidiMessage:[PGMidiMessage noteOn:0 withVelocity:127 withChannel:1]];
 [[PGMidiSession sharedSession] sendMidiMessage:[PGMidiMessage noteOff:0 withVelocity:127 withChannel:1]];
 
 Sending CC or PitchWheel:
 
 [[PGMidiSession sharedSession] sendMidiMessage:[PGMidiMessage controlChange:0 withValue:60 withChannel:1]];
 [[PGMidiSession sharedSession] sendMidiMessage:[PGMidiMessage pitchWheel:60 withMSB:0 withChannel:1]];
 
 Accessing BPM:
 [PGMidiSession sharedSession].bpm
 
 Receiving MIDI data:
 Set [PGMidiSession sharedSession].delegate to a PGMidiSourceDelegate and implement the two delegate methods!
 
 Quantization:
 
 performBlock and performBlockOnMainThread methods let you trigger a block at a given quantization fraction.
 Must only be used to trigger UI in sync with the BPM/Quantize or to do internal logic but should NOT be used to trigger midi messages.
 To trigger midi messages please use sendMidiMessage:quantizedToFraction
 
 You can perform on the main thread (most likely for UI stuff)
 
 [[PGMidiSession sharedSession] performBlockOnMainThread:^{ NSLog(@"HI"); } quantizedToInterval:1];    // Prints "HI" on the next downbeat of a new bar
 [[PGMidiSession sharedSession] performBlockOnMainThread:^{ NSLog(@"HI"); } quantizedToInterval:0.25]; // Prints "HI" on the next quarter note
 [[PGMidiSession sharedSession] performBlockOnMainThread:^{ NSLog(@"HI"); } quantizedToInterval:1.25]; // Waits till the next bar, then prints "HI" on the next quarter note
 
 Or you can perform straight in the high priority thread used by CoreMIDI
 
 [[PGMidiSession sharedSession] performBlock:^{ ... } quantizedToInterval:1];
 
 
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

- (void)sendMidiMessage:(PGMidiMessage*)message;
- (void)sendMidiMessage:(PGMidiMessage*)message afterDelay:(NSTimeInterval)delay;
- (void)sendMidiMessage:(PGMidiMessage*)message quantizedToFraction:(double)quantize;

/*
 In case you need to update some UI elements at a givent quantization division, this will do the trick..
 */
- (void) performBlockOnMainThread:(void (^)(void))block quantizedToInterval:(double)bars repeat:(BOOL)repeat;

/*
 In case you need to perform some logic at a given quantization division in the high priority thread.
 Be careful to not use Blocking IO.
 
 Quantization accuracy of this method is great for local processing but would not be the best to send midi events as it doesn't account for the latency.
 If you want to send a note at a given quantization division, use sendNoteOn:withChannel:withVelocity:quantizedToInterval instead as it will use CoreMIDI
 timestamp and let CoreMIDI deal with the latency which is very precise and theorically result to a 0ms latency as the midi message is sent in advance
 to be triggered at a given time in the future.
 */
- (void) performBlock:(void (^)(void))block quantizedToInterval:(double)bars repeat:(BOOL)repeat;

@end

@protocol PGMidiSessionDelegate <NSObject>

//- (void) midiSource:(PGMidiSource *)source messageReceived:(PGMidiMessage*)message;

- (void) midiClockStart;
- (void) midiClockStop;

@end

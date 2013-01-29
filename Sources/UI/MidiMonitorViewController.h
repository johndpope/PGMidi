//
//  MidiMonitorViewController.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PGMidi;

@interface MidiMonitorViewController : UIViewController
{
    UILabel    *countLabel;
    UITextView *textView;
    UIButton *sendButton;

    // PGMidi *midi;
}

#if ! __has_feature(objc_arc)

@property (nonatomic,retain) IBOutlet UILabel    *countLabel;
@property (nonatomic,retain) IBOutlet UITextView *textView;
@property (nonatomic,retain) IBOutlet UIButton *sendButton;


//@property (nonatomic,assign) PGMidi *midi;

#else

@property (nonatomic,strong) IBOutlet UILabel    *countLabel;
@property (nonatomic,strong) IBOutlet UITextView *textView;
@property (nonatomic,strong) IBOutlet UIButton *sendButton;

//@property (nonatomic,strong) PGMidi *midi;

#endif

- (IBAction) clearTextView;
- (IBAction) listAllInterfaces;
- (IBAction) sendMidiData;


- (IBAction) sendNoteOn0;
- (IBAction) sendNoteOff0;
- (IBAction) sendNoteOn1;
- (IBAction) sendNoteOff1;
- (IBAction) sendNoteOn2;
- (IBAction) sendNoteOff2;

@end


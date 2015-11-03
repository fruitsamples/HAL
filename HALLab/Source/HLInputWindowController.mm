/*	Copyright: 	© Copyright 2003 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*=============================================================================
	HLInputWindowController.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLInputWindowController.h"

//	Local Includes
#import "HLApplicationDelegate.h"
#import	"HLDeviceMenuController.h"

//	PublicUtility Includes
#import "CAAudioHardwareDevice.h"
#import "CAAudioHardwareSystem.h"
#import "CAAudioTimeStamp.h"
#import "CAAutoDisposer.h"
#import "CADebugMacros.h"
#import "CAException.h"
#import "CAHostTimeBase.h"
#import "CAStreamBasicDescription.h"

//	System Includes
#import <string.h>

//#define Log_IOTimes	1

//=============================================================================
//	HLInputWindowController
//=============================================================================

@implementation HLInputWindowController

-(id)	initWithApplicationDelegate:	(HLApplicationDelegate*)inApplicationDelegate
{
	CATry;
	
	//	initialize the super class
    [super initWithWindowNibName: @"InputWindow"];
	
	//	initialize the tinks
	mAudioDeviceIOProcTink = new CATink<AudioDeviceIOProc>((AudioDeviceIOProc)HLInputWindowControllerAudioDeviceIOProc);
	mAudioDevicePropertyListenerTink = new CATink<AudioDevicePropertyListenerProc>((AudioDevicePropertyListenerProc)HLInputWindowControllerAudioDevicePropertyListenerProc);
	mAudioStreamPropertyListenerTink = new CATink<AudioStreamPropertyListenerProc>((AudioStreamPropertyListenerProc)HLInputWindowControllerAudioStreamPropertyListenerProc);
	
	//	initialize the basic stuff
	mApplicationDelegate = inApplicationDelegate;
	
	//	initialize the device stuff
	mDeviceNumberStreams = 0;
	mDeviceStreamFormats = NULL;
	mDeviceIsDoingIO = false;
	[self SetupDevice: CAAudioHardwareSystem::GetDefaultDevice(kAudioDeviceSectionInput, false)];
	
	mNumberEvents = 1024;
	mEvents = new _IOEventInfo[mNumberEvents];
	memset(mEvents, 0, mNumberEvents * sizeof(_IOEventInfo));
	
	CACatch;
	
	return self;
}

-(void)	windowDidLoad
{
	CATry;
	
	//	get the device
	mDevice = [mDeviceMenuController GetSelectedAudioDevice];
	
	//	update the device UI
	[self UpdateDeviceInfo];
	
	//	make a string to print the time for the 0 time for the time display in the telemetry
	Float64 theTimeInMilliseconds = [mApplicationDelegate GetNotificationStartTime] / 1000000.0;
	NSString* theStartTimeString = [[NSString alloc] initWithFormat: @"%f: Absolute Start Time (milliseconds)\n", theTimeInMilliseconds];
	
	//	add it to the telemetry
	int theLength = [[mTelemetryTextView textStorage] length];
	[[mTelemetryTextView textStorage] replaceCharactersInRange: NSMakeRange(theLength, 0) withString: theStartTimeString];
	[theStartTimeString release];
	
	[mStartDelayPopUp selectItemAtIndex: 0];

	CACatch;
}

-(void)	dealloc
{
	CATry;
	
	[self StopIO];
	[self TeardownDevice: mDevice];
	
	delete mAudioDeviceIOProcTink;
	delete mAudioDevicePropertyListenerTink;
	delete mAudioStreamPropertyListenerTink;
	
	CACatch;

	[super dealloc];
}

-(AudioDeviceID)	GetAudioDeviceID
{
	return [mDeviceMenuController GetSelectedAudioDevice];
}

-(bool)	IsDoingIO
{
	return mDeviceIsDoingIO;
}

-(void)	windowWillClose:	(NSNotification*)inNotification
{
	//	the window is closing, so arrange to get cleaned up
	[mApplicationDelegate DestroyInputWindow: self];
}

-(IBAction)	DeviceInfoButtonAction:	(id)inSender
{
	CATry;
	
	if(mDevice != 0)
	{
		[mApplicationDelegate ShowDeviceWindow: mDevice];
	}
	
	CACatch;
}

-(IBAction)	StartHardwareButtonAction:	(id)inSender
{
	CATry;
	
	if(mDevice != 0)
	{
		CAAudioHardwareDevice theDevice(mDevice);
		theDevice.StartIOProc(NULL);
		[self AppendTelemetry: [[NSString alloc] initWithString: @"starting up the device"]];
	}
	
	CACatch;
}

-(IBAction)	StopHardwareButtonAction:	(id)inSender
{
	CATry;
	
	if(mDevice != 0)
	{
		CAAudioHardwareDevice theDevice(mDevice);
		theDevice.StopIOProc(NULL);
		[self AppendTelemetry: [[NSString alloc] initWithString: @"stopping the device"]];
	}
	
	CACatch;
}

-(IBAction)	StartIOButtonAction:	(id)inSender
{
	CATry;
	
	if((mDevice != 0) && !mDeviceIsDoingIO)
	{
		[self StartIO];
	}
	
	CACatch;
}

-(IBAction)	StopIOButtonAction:	(id)inSender
{
	CATry;
	
	if((mDevice != 0) && mDeviceIsDoingIO)
	{
		[self StopIO];
	}
	
	CACatch;
}

-(void)	UpdateDeviceInfo
{
	CATry;
	
	if(mDevice != 0)
	{
		CAAudioHardwareDevice theDevice(mDevice);
		
		//	update the text fields
		[mDeviceSampleRateTextField setDoubleValue: theDevice.GetNominalSampleRate()];
		[mDeviceNumberChannelsTextField setIntValue: theDevice.GetTotalNumberChannels(kAudioDeviceSectionInput)];
		[mDeviceBufferSizeTextField setIntValue: theDevice.GetIOBufferSize()];
	}
	else
	{
		//	no device, so clear out the fields
		[mDeviceSampleRateTextField setStringValue: @""];
		[mDeviceNumberChannelsTextField setStringValue: @""];
		[mDeviceBufferSizeTextField setStringValue: @""];
	}
	
	CACatch;
}

-(void)	AppendTelemetry:	(NSString*)inTelemetry
{
	//	write out the time stamp
	UInt64 theTime = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime());
	theTime -= [mApplicationDelegate GetNotificationStartTime];
	Float64 theTimeInMilliseconds = theTime / 1000000.0;
	NSString* theTimeString = [[NSString alloc] initWithFormat: @"%f: ", theTimeInMilliseconds];
	
	int theLength = [[mTelemetryTextView textStorage] length];
	[[mTelemetryTextView textStorage] replaceCharactersInRange: NSMakeRange(theLength, 0) withString: theTimeString];
	
	[theTimeString release];

	//	write out the telemetry
	theLength = [[mTelemetryTextView textStorage] length];
	[[mTelemetryTextView textStorage] replaceCharactersInRange: NSMakeRange(theLength, 0) withString: inTelemetry];
	
	//	write out the newline
	theLength = [[mTelemetryTextView textStorage] length];
	[[mTelemetryTextView textStorage] replaceCharactersInRange: NSMakeRange(theLength, 0) withString: @"\n"];
	
	//	release the string
	[inTelemetry release];
}

-(Float64)	GetStartDelay
{
	Float64 theAnswer = 0;
	
	//	retrieve the selected item
	NSMenuItem* theSelectedItem = [mStartDelayPopUp selectedItem];
	if(theSelectedItem != NULL)
	{
		//	the tag of the selected items is the number of milliseconds
		theAnswer = [theSelectedItem tag] / 1000.0;
	}
	
	return theAnswer;
}

-(void)	SetupDevice:	(AudioDeviceID)inDevice
{
	//	This routine is for configuring the IO device and installing
	//	IOProcs and listeners. The strategy for this window is to only
	//	respond to changes in the device. If the user wants to change
	//	things about the device that affect IO, it will be done in the
	//  device info window.
	CATry;
	
	if(inDevice != 0)
	{
		[self AppendTelemetry: [[NSString alloc] initWithString: @"setting up device"]];
		
		//	make a device object
		CAAudioHardwareDevice theDevice(inDevice);
		
		//	get the format information
		mDeviceNumberStreams = theDevice.GetNumberStreams(kAudioDeviceSectionInput);
		mDeviceStreamFormats = (AudioStreamBasicDescription*)calloc(mDeviceNumberStreams, sizeof(AudioStreamBasicDescription));
		theDevice.GetCurrentIOProcFormats(kAudioDeviceSectionInput, mDeviceNumberStreams, mDeviceStreamFormats);
		
		//	install the IO proc
		theDevice.AddIOProc((AudioDeviceIOProc)mAudioDeviceIOProcTink, self);
		
		//	turn off all the output streams
		CATry;
		UInt32 theNumberOutputStreams = theDevice.GetNumberStreams(kAudioDeviceSectionOutput);
		CAAutoFree<bool> theOutputStreamUsage(theNumberOutputStreams);
		for(UInt32 theOutputStreamIndex = 0; theOutputStreamIndex < theNumberOutputStreams; ++theOutputStreamIndex)
		{
			theOutputStreamUsage[theOutputStreamIndex] = false;
		}
		theDevice.SetIOProcStreamUsage((AudioDeviceIOProc)mAudioDeviceIOProcTink, kAudioDeviceSectionOutput, theOutputStreamUsage);
		CACatch;
		
		//	turn on all the input streams
		CATry;
		UInt32 theNumberInputStreams = theDevice.GetNumberStreams(kAudioDeviceSectionInput);
		CAAutoFree<bool> theInputStreamUsage(theNumberInputStreams);
		for(UInt32 theInputStreamIndex = 0; theInputStreamIndex < theNumberInputStreams; ++theInputStreamIndex)
		{
			theInputStreamUsage[theInputStreamIndex] = true;
		}
		theDevice.SetIOProcStreamUsage((AudioDeviceIOProc)mAudioDeviceIOProcTink, kAudioDeviceSectionInput, theInputStreamUsage);
		CACatch;
		
		//	install a listener for the device dying
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyDeviceIsAlive, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
		
		//	install a listener for IO overloads
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDeviceProcessorOverload, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
		
		//	install a listener for buffer size changes
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyBufferFrameSize, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
		
		//	install a listener for sample rate changes
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyNominalSampleRate, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
		
		//	install a listener for stream layout changes
		theDevice.AddPropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyStreamConfiguration, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink, self);
	}
	
	CACatch;
}

-(void)	TeardownDevice:	(AudioDeviceID)inDevice
{
	CATry;
	
	if(inDevice != 0)
	{
		[self AppendTelemetry: [[NSString alloc] initWithString: @"tearing down device"]];
		
		//	make a device object
		CAAudioHardwareDevice theDevice(inDevice);
		
		//	get rid of the format info
		mDeviceNumberStreams = 0;
		free(mDeviceStreamFormats);
		
		//	remove the IO proc
		theDevice.RemoveIOProc((AudioDeviceIOProc)mAudioDeviceIOProcTink);
		
		//	remove the listener for the device dying
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyDeviceIsAlive, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
		
		//	remove the listener for IO overloads
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDeviceProcessorOverload, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
		
		//	remove the listener for buffer size changes
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyBufferFrameSize, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
		
		//	remove the listener for sample rate changes
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyNominalSampleRate, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
		
		//	remove the listener for stream layout changes
		theDevice.RemovePropertyListener(kAudioPropertyWildcardChannel, kAudioDeviceSectionInput, kAudioDevicePropertyStreamConfiguration, (AudioDevicePropertyListenerProc)mAudioDevicePropertyListenerTink);
	}

	CACatch;
}

-(void)	StartIO
{
	CATry;
	
	if((mDevice != 0) && !mDeviceIsDoingIO)
	{
		[self AppendTelemetry: [[NSString alloc] initWithString: @"starting IO"]];
		mIOCounter = 0;
		memset(mEvents, 0, mNumberEvents * sizeof(_IOEventInfo));
		
		//	make a device object
		CAAudioHardwareDevice theDevice(mDevice);
		
		//	get the start delay (in seconds)
		Float64 theStartDelaySeconds = [self GetStartDelay];
		
		if(theStartDelaySeconds > 0.0)
		{
			//	there is a start delay, calculate when to start
			
			//	get the current time (in samples)
			AudioTimeStamp theCurrentTime = CAAudioTimeStamp::kZero;
			theCurrentTime.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
			theDevice.GetCurrentTime(theCurrentTime);
			
			//	append the current time
			NSString* theString = [[NSString alloc] initWithFormat: @"        current time: (%9.0f, %12qd)", theCurrentTime.mSampleTime, theCurrentTime.mHostTime];
			[self AppendTelemetry: theString];
			
			//	add the start delay
			AudioTimeStamp theStartHostTime = CAAudioTimeStamp::kZero;
			theStartHostTime.mHostTime = theCurrentTime.mHostTime + AudioConvertNanosToHostTime(static_cast<UInt64>(theStartDelaySeconds * 1000000000.0));
			theStartHostTime.mFlags = kAudioTimeStampHostTimeValid;
			
			//	convert that to a sample time too
			AudioTimeStamp theStartTime = CAAudioTimeStamp::kZero;
			theStartTime.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
			theDevice.TranslateTime(theStartHostTime, theStartTime);
			
			//	append the info about when we want to start
			theString = [[NSString alloc] initWithFormat: @"requested start time: (%9.0f, %12qd)", theStartTime.mSampleTime, theStartTime.mHostTime];
			[self AppendTelemetry: theString];
			
			//	start the IO proc
			theDevice.StartIOProcAtTime((AudioDeviceIOProc)mAudioDeviceIOProcTink, theStartTime, true, false);
			
			//	append the info about when the HAL says we will start
			theString = [[NSString alloc] initWithFormat: @"      HAL start time: (%9.0f, %12qd)", theStartTime.mSampleTime, theStartTime.mHostTime];
			[self AppendTelemetry: theString];
		}
		else
		{
			//	no start delay, so just start the IO proc
			theDevice.StartIOProc((AudioDeviceIOProc)mAudioDeviceIOProcTink);
		}
		
		//	the device is doing IO, so start the spinner
		[mIsDoingIOIndicator startAnimation: self];

		mDeviceIsDoingIO = true;
	}
	
	CACatch;
}

-(void)	StopIO
{
	CATry;
	
	if((mDevice != 0) && mDeviceIsDoingIO)
	{
		[self AppendTelemetry: [[NSString alloc] initWithString: @"stopping IO"]];

		//	make a device object
		CAAudioHardwareDevice theDevice(mDevice);
		
		mDeviceIsDoingIO = false;
		
		//	the device is doing IO, so stop the spinner
		[mIsDoingIOIndicator stopAnimation: self];
	
		//	stop the IO proc
		theDevice.StopIOProc((AudioDeviceIOProc)mAudioDeviceIOProcTink);
		
		//	open a new file
		#if Log_IOTimes
		FILE* theFile = fopen("/tmp/foo.txt", "w+");
		if(theFile != NULL)
		{
			//  iterate through the IO info
			for(UInt32 theEventIndex = 0; theEventIndex < mIOCounter; ++theEventIndex)
			{
				fprintf(theFile, "%qd\t%f\t%qd\t%f\t%qd\t%f\t%qd\r", CAHostTimeBase::ConvertToNanos(mEvents[theEventIndex].mEventTime), mEvents[theEventIndex].mDeviceSampleTime, CAHostTimeBase::ConvertToNanos(mEvents[theEventIndex].mDeviceHostTime), mEvents[theEventIndex].mNowSampleTime, CAHostTimeBase::ConvertToNanos(mEvents[theEventIndex].mNowHostTime), mEvents[theEventIndex].mInputSampleTime, CAHostTimeBase::ConvertToNanos(mEvents[theEventIndex].mInputHostTime));
			}
			
			//	close the file
			fclose(theFile);
		}
		#endif
	}
	
	CACatch;
}

-(AudioDeviceID)	GetInitialSelectedDevice:	(HLDeviceMenuController*)inDeviceMenuControl
{
	//	the initial selection of the device menu is the default output device
	return CAAudioHardwareSystem::GetDefaultDevice(true, false);
}

-(void)	SelectedDeviceChanged:	(HLDeviceMenuController*)inDeviceMenuControl
		OldDevice:				(AudioDeviceID)inOldDeviceID
		NewDevice:				(AudioDeviceID)inNewDeviceID
{
	//	save the IO state
	bool wasDoingIO = mDeviceIsDoingIO;
	
	//	stop IO
	[self StopIO];
	
	//	teardown the current device
	[self TeardownDevice: inOldDeviceID];
	
	mDevice = inNewDeviceID;

	//	setup the new device
	[self SetupDevice: inNewDeviceID];
	
	//	update the device info
	[self UpdateDeviceInfo];
	
	//	restart IO
	if(wasDoingIO)
	{
		[self StartIO];
	}
}

-(BOOL)	ShouldDeviceBeInMenu:	(HLDeviceMenuController*)inDeviceMenuControl
		Device:					(AudioDeviceID)inDeviceID
{
	CAAudioHardwareDevice theDevice(inDeviceID);
	
	BOOL theAnswer = NO;
	
	if(theDevice.HasSection(kAudioDeviceSectionInput))
	{
		theAnswer = YES;
	}
	
	return theAnswer;
}

@end

OSStatus	HLInputWindowControllerAudioDeviceIOProc(AudioDeviceID inDevice, const AudioTimeStamp* inNow, const AudioBufferList* inInputData, const AudioTimeStamp* inInputTime, AudioBufferList* outOutputData, const AudioTimeStamp* inOutputTime, HLInputWindowController* inInputWindowController)
{
	CATry;
	
	CAAudioHardwareDevice theDevice(inDevice);
	
	if((inInputTime != NULL) && (inInputWindowController->mIOCounter == 0))
	{
		//	append the info about when really started
		NSString* theString = [[NSString alloc] initWithFormat: @"     real start time: (%9.0f, %12qd)", inInputTime->mSampleTime, inInputTime->mHostTime];
		[inInputWindowController performSelectorOnMainThread: @selector(AppendTelemetry:) withObject: theString waitUntilDone: NO];
	}
	
	//  save the IO info
	#if Log_IOTimes
	if(inInputWindowController->mIOCounter < inInputWindowController->mNumberEvents)
	{
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mEventTime = CAHostTimeBase::GetCurrentTime();
		
		//  get the current time from the device
		AudioTimeStamp theCurrentTime;
		memset(&theCurrentTime, 0, sizeof(AudioTimeStamp));
		theCurrentTime.mFlags = kAudioTimeStampSampleHostTimeValid;
		theDevice.GetCurrentTime(theCurrentTime);
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mDeviceSampleTime = theCurrentTime.mSampleTime;
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mDeviceHostTime = theCurrentTime.mHostTime;
		
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mNowSampleTime = inNow->mSampleTime;
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mNowHostTime = inNow->mHostTime;
		
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mInputSampleTime = inInputTime->mSampleTime;
		inInputWindowController->mEvents[inInputWindowController->mIOCounter].mInputHostTime = inInputTime->mHostTime;
	
		++inInputWindowController->mIOCounter;
	}
	#endif
		
	CACatch;
	
	return 0;
}

OSStatus	HLInputWindowControllerAudioDevicePropertyListenerProc(AudioDeviceID inDevice, UInt32 inChannel, Boolean inIsInput, AudioDevicePropertyID inPropertyID, HLInputWindowController* inInputWindowController)
{
	CATry;
	
	//	only react to master channel, output section notifications here
	if((inDevice == [inInputWindowController GetAudioDeviceID]) && (inChannel == 0) && (inIsInput == 0))
	{
		bool isDoingIO;
		CAAudioHardwareDevice theDevice(inDevice);
		NSString* theTelemetry = NULL;
		bool deferTelemetry = false;
	
		switch(inPropertyID)
		{
			case kAudioDevicePropertyDeviceIsAlive:
				{
					theTelemetry = [[NSString alloc] initWithString: @"device has died"];
	
					//	the device is dead, so stop IO if necessary
					isDoingIO = [inInputWindowController IsDoingIO];
					if(isDoingIO)
					{
						[inInputWindowController StopIO];
					}
					
					//	teardown the device
					[inInputWindowController TeardownDevice: inDevice];
					
					//	change the IO device to the default device
					[inInputWindowController SetupDevice: CAAudioHardwareSystem::GetDefaultDevice(kAudioDeviceSectionOutput, false)];
					
					//	restart IO, if necessary
					if(isDoingIO)
					{
						[inInputWindowController StartIO];
					}
					
					//	update the info
					[inInputWindowController UpdateDeviceInfo];
				}
				break;
				
			case kAudioDeviceProcessorOverload:
				{
					theTelemetry = [[NSString alloc] initWithString: @"overload"];
					deferTelemetry = true;
				}
				break;
				
			case kAudioDevicePropertyBufferFrameSize:
				theTelemetry = [[NSString alloc] initWithString: @"buffer size changed"];
				[inInputWindowController UpdateDeviceInfo];
				break;
				
			case kAudioDevicePropertyNominalSampleRate:
				theTelemetry = [[NSString alloc] initWithString: @"sample rate changed"];
				
				//	the device's format has changed, so stop IO if necessary
				isDoingIO = [inInputWindowController IsDoingIO];
				if(isDoingIO)
				{
					[inInputWindowController StopIO];
				}
				
				//	teardown the device
				[inInputWindowController TeardownDevice: inDevice];
				
				//	rebuild the device
				[inInputWindowController SetupDevice: inDevice];
				
				//	restart IO, if necessary
				if(isDoingIO)
				{
					[inInputWindowController StartIO];
				}
				
				//	update the info
				[inInputWindowController UpdateDeviceInfo];
				break;
				
			case kAudioDevicePropertyStreamConfiguration:
				theTelemetry = [[NSString alloc] initWithString: @"stream configuration changed"];
				
				//	the device's format has changed, so stop IO if necessary
				isDoingIO = [inInputWindowController IsDoingIO];
				if(isDoingIO)
				{
					[inInputWindowController StopIO];
				}
				
				//	teardown the device
				[inInputWindowController TeardownDevice: inDevice];
				
				//	rebuild the device
				[inInputWindowController SetupDevice: inDevice];
				
				//	restart IO, if necessary
				if(isDoingIO)
				{
					[inInputWindowController StartIO];
				}
				
				//	update the info
				[inInputWindowController UpdateDeviceInfo];
				break;
		};
	
		if(theTelemetry != NULL)
		{
			if(deferTelemetry)
			{
				[inInputWindowController performSelectorOnMainThread: @selector(AppendTelemetry:) withObject: theTelemetry waitUntilDone: NO];
			}
			else
			{
				[inInputWindowController AppendTelemetry: theTelemetry];
			}
		}
	}
	
	CACatch;

	return 0;
}

OSStatus	HLInputWindowControllerAudioStreamPropertyListenerProc(AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, HLInputWindowController* inInputWindowController)
{
	CATry;
	
	CACatch;
	
	return 0;
}

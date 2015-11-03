/*	Copyright: 	© Copyright 2003 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under AppleÕs
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
	HLTimeWindowController.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLTimeWindowController.h"

//	Local Includes
#import "HLApplicationDelegate.h"
#import "HLDeviceMenuController.h"

//	PublicUtility Includes
#import "CAAudioHardwareDevice.h"
#import "CAAudioHardwareSystem.h"
#import "CAAudioTimeStamp.h"
#import "CADebugMacros.h"
#import "CAException.h"

//=============================================================================
//	HLTimeWindowController
//=============================================================================

@implementation HLTimeWindowController

-(id)	initWithApplicationDelegate:	(HLApplicationDelegate*)inApplicationDelegate
{
    [super initWithWindowNibName: @"TimeWindow"];
	mUpdateTimer = NULL;
	mApplicationDelegate = inApplicationDelegate;
	return self;
}

-(void)	windowDidLoad
{
	[self UpdateTime: NULL];
}

-(void)	windowWillClose:	(NSNotification*)inNotification
{
	[self StopUpdatingTime: self];
	
	//	the window is closing, so arrange to get cleaned up
	[mApplicationDelegate DestroyTimeWindow: self];
}

-(void)	dealloc
{
	[self StopUpdatingTime: self];
	[super dealloc];
}

-(AudioDeviceID)	GetInitialSelectedDevice:	(HLDeviceMenuController*)inDeviceMenuControl
{
	AudioDeviceID theAnswer = CAAudioHardwareSystem::GetDefaultDevice(false, false);
	if(theAnswer == 0)
	{
		theAnswer = CAAudioHardwareSystem::GetDefaultDevice(true, false);
	}
	if(theAnswer == 0)
	{
		theAnswer = CAAudioHardwareSystem::GetDefaultDevice(false, true);
	}
	return theAnswer;
}

-(void)	SelectedDeviceChanged:	(HLDeviceMenuController*)inDeviceMenuControl
		OldDevice:				(AudioDeviceID)inOldDeviceID
		NewDevice:				(AudioDeviceID)inNewDeviceID
{
	[self UpdateTime: NULL];
}

-(BOOL)	ShouldDeviceBeInMenu:	(HLDeviceMenuController*)inDeviceMenuControl
		Device:					(AudioDeviceID)inDeviceID
{
	return YES;
}

-(IBAction)	DeviceInfoButtonAction:	(id)inSender
{
	CATry;
	
	AudioDeviceID theDeviceID = [mDeviceMenuController GetSelectedAudioDevice];
	
	if(theDeviceID != 0)
	{
		[mApplicationDelegate ShowDeviceWindow: theDeviceID];
	}
	
	CACatch;
}

-(IBAction)	UpdateRatePopUpAction:	(id)inSender
{
	CATry;
	
	[self StartUpdatingTime: inSender];
	
	CACatch;
}

-(void)		UpdateTime:	(NSTimer*)inTimer
{
	AudioDeviceID theDeviceID = [mDeviceMenuController GetSelectedAudioDevice];
	AudioTimeStamp theCurrentTime = CAAudioTimeStamp::kZero;
	AudioTimeStamp theNearestStartTime = CAAudioTimeStamp::kZero;
	bool isRunning = false;
	if(theDeviceID != 0)
	{
		CAAudioHardwareDevice theDevice(theDeviceID);
		
		//	get the current time
		CATry;
		theDevice.GetCurrentTime(theCurrentTime);
		CACatch;
		
		//	get the nearest start time
		CATry;
		theNearestStartTime = theCurrentTime;
		theDevice.GetNearestStartTime(theNearestStartTime, true, false);
		CACatch;
		
		//	get the IsRunning status
		isRunning = theDevice.IsRunning();
	}
	
	//	fill out the current time
	NSString* theString = [NSString stringWithFormat: @"%10.0f %16qd", theCurrentTime.mSampleTime, theCurrentTime.mHostTime];
	[mCurrentTimeTextField setStringValue: theString];
	
	//	fill out the nearest start time
	theString = [NSString stringWithFormat: @"%10.0f %16qd", theNearestStartTime.mSampleTime, theNearestStartTime.mHostTime];
	[mNearestStartTimeTextField setStringValue: theString];
	
	//	fill out the IsRunning status
	if(isRunning)
	{
		[mIsRunningTextField setStringValue: @"Yes"];
	}
	else
	{
		[mIsRunningTextField setStringValue: @"No"];
	}
	
	//	make sure things match up
	if((isRunning && (theCurrentTime.mHostTime == 0)) || (!isRunning && (theCurrentTime.mHostTime != 0)))
	{
		printf("HLTimeWindow::-(void)UpdateTime: IsRunning state doesn't match the GetCurrentTime state\n");
	}
}

-(void)		StartUpdatingTime:	(id)inSender
{
	//	get the update inteval
	Float64 theUpdateInterval = [self GetUpdateInterval];
	
	if(theUpdateInterval > 0.0)
	{
		if(mUpdateTimer != NULL)
		{
			//	stop the old timer
			[mUpdateTimer invalidate];
			[mUpdateTimer release];
		}
		
		//	start the new timer
		mUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval: theUpdateInterval target: self selector: @selector(UpdateTime:) userInfo: NULL repeats: YES] retain];
	}
	else
	{
		[self StopUpdatingTime: self];
	}
}

-(void)		StopUpdatingTime:	(id)inSender
{
	if(mUpdateTimer != NULL)
	{
		[mUpdateTimer invalidate];
		[mUpdateTimer release];
		mUpdateTimer = NULL;
	}
	if(mUpdateRatePopUp != NULL)
	{
		UInt32 theItemIndex = [mUpdateRatePopUp indexOfItemWithTag: 0];
		[mUpdateRatePopUp selectItemAtIndex: theItemIndex];
	}
}

-(Float64)	GetUpdateInterval
{
	Float64 theAnswer = 0;
	
	//	retrieve the selected item
	NSMenuItem* theSelectedItem = [mUpdateRatePopUp selectedItem];
	if(theSelectedItem != NULL)
	{
		theAnswer = [theSelectedItem tag] / 8.0;
	}
	
	return theAnswer;
}

@end

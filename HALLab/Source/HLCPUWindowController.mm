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
	HLCPUWindowController.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLCPUWindowController.h"

//	Local Includes
#import "HLCPULoadHistory.h"
#import "HLCPULoadHistoryView.h"
#import "HLCPUInfo.h"

//	PublicUtility Includes
#import "CADebugMacros.h"
#import "CAException.h"

//=============================================================================
//	HLCPUWindowController
//=============================================================================

@implementation HLCPUWindowController

-(id)	initWithApplicationDelegate:	(HLApplicationDelegate*)inApplicationDelegate
{
	//	initialize the super class
    [super initWithWindowNibName: @"CPUWindow"];
	
	mCPULoadHistoryUpdateFrequencyPopUp = NULL;
	mCPULoadHistoryPixelsPerItemPopUp = NULL;
	mCPULoadHistoryView = NULL;
	mApplicationDelegate = inApplicationDelegate;
	mCPULoadHistoryUpdateTimer = NULL;
	mCPULoadHistory = NULL;
	
	return self;
}

-(void)	windowDidLoad
{
	CATry;
	
	mCPULoadHistory = new HLCPULoadHistory([self CalculateCPULoadHistoryLength]);
	mCPULoadHistory->UpdateCPULoads();
	[self StartUpdatingCPULoadHistory];
	
	CACatch;
}

-(void)	windowDidResize: (NSNotification*)inNotification
{
	mCPULoadHistory->SetHistoryLength([self CalculateCPULoadHistoryLength]);
	[mCPULoadHistoryView setNeedsDisplay: YES];
}

-(void)	dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self name: NSViewBoundsDidChangeNotification object: mCPULoadHistoryView];
	[self StopUpdatingCPULoadHistory];
	delete mCPULoadHistory;
	[super dealloc];
}

-(IBAction)	CPULoadHistoryUpdateFrequencyPopUpAction:	(id)inSender
{
	[self StopUpdatingCPULoadHistory];
	[self StartUpdatingCPULoadHistory];
}

-(IBAction)	CPULoadHistoryPixelsPerItemPopUpAction:	(id)inSender
{
	mCPULoadHistory->SetHistoryLength([self CalculateCPULoadHistoryLength]);
	[mCPULoadHistoryView setNeedsDisplay: YES];
}

-(void)		StartUpdatingCPULoadHistory
{
	if(mCPULoadHistoryUpdateTimer == NULL)
	{
		Float64 theUpdateFrequency = [self GetCPULoadHistoryUpdateFrequency];
		mCPULoadHistoryUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval: theUpdateFrequency target: self selector: @selector(CPULoadHistoryUpdateTimerFired:) userInfo: NULL repeats: YES] retain];
	}
}

-(void)		StopUpdatingCPULoadHistory
{
	if(mCPULoadHistoryUpdateTimer != NULL)
	{
		[mCPULoadHistoryUpdateTimer invalidate];
		[mCPULoadHistoryUpdateTimer release];
		mCPULoadHistoryUpdateTimer = NULL;
	}
}

-(void)		CPULoadHistoryUpdateTimerFired:	(NSTimer*)inTimer
{
	if(mCPULoadHistory != NULL)
	{
		mCPULoadHistory->UpdateCPULoads();
		[mCPULoadHistoryView setNeedsDisplay: YES];
	}
}

-(UInt32)	CalculateCPULoadHistoryLength
{
	//	get the width of each CPU display in pixels
	Float32 theCPUWidth = [mCPULoadHistoryView CalculateCPUWidth];
	
	//	get the number of pixels per history item
	Float32 thePixelsPerHistoryItem = [self GetCPULoadHistoryPixelsPerItem];
	
	//	calculate the number of history items that will fit
	UInt32 theNumberHistoryItems = static_cast<UInt32>(theCPUWidth / thePixelsPerHistoryItem);
	
	return theNumberHistoryItems;
}

-(Float32)	GetCPULoadHistoryPixelsPerItem
{
	Float32 theAnswer = 1;
	
	if(mCPULoadHistoryPixelsPerItemPopUp != NULL)
	{
		NSMenuItem* theSelectedItem = [mCPULoadHistoryPixelsPerItemPopUp selectedItem];
		if(theSelectedItem != NULL)
		{
			//	the selected item's tag is the pixels per history item
			theAnswer = [theSelectedItem tag];
		}
	}
	
	return theAnswer;
}

-(Float64)	GetCPULoadHistoryUpdateFrequency
{
	Float64 theAnswer = 1;
	
	if(mCPULoadHistoryUpdateFrequencyPopUp != NULL)
	{
		NSMenuItem* theSelectedItem = [mCPULoadHistoryUpdateFrequencyPopUp selectedItem];
		if(theSelectedItem != NULL)
		{
			//	the selected item's tag is the duration in seconds as a 16.16 fixed point number
			UInt32 theSourceID = [theSelectedItem tag];
			theAnswer = static_cast<Float64>(theSourceID >> 16);
			theAnswer += static_cast<Float64>(theSourceID & 0x0000FFFF) / static_cast<Float64>(0x00010000);
		}
	}
	
	return theAnswer;
}

-(UInt32)	GetCPULoadHistoryLength
{
	UInt32 theAnswer = 1;
	
	if(mCPULoadHistory != NULL)
	{
		theAnswer = mCPULoadHistory->GetHistoryLength() - 1;
	}
	
	return theAnswer;
}

-(Float64)	GetCPULoad:		(UInt32)inCPUIndex
			ForCPUState:	(UInt32)inCPUState
			ForItemIndex:	(UInt32)inItemIndex;
{
	Float64 theAnswer = 0;
	
	if(mCPULoadHistory != NULL)
	{
		theAnswer = mCPULoadHistory->GetCPULoad(inCPUIndex, inCPUState, inItemIndex);
	}
	
	return theAnswer;
}

@end

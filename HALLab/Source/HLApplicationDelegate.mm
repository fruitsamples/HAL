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
	HLApplicationDelegate.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLApplicationDelegate.h"

//	Internal Includes
#import	"HLCPUWindowController.h"
#import "HLDeviceWindowController.h"
#import "HLFilePlayerWindowController.h"
#import "HLInputWindowController.h"
#import "HLIOCycleTelemetryWindowController.h"
#import "HLFileSystem.h"
#import "HLSystemWindowController.h"
#import "HLTimeWindowController.h"

//=============================================================================
//	HLApplicationDelegate
//=============================================================================

@implementation HLApplicationDelegate

-(id)	init
{
	[super init];
	HLFileSystem::Initialize();
	mSystemWindowController = NULL;
	mCPUWindowController = NULL;
	mDeviceWindowControllerMap = new HLDeviceWindowControllerMap;
	mFilePlayerWindowControllerList = new HLFilePlayerWindowControllerList;
	mInputWindowControllerList = new HLInputWindowControllerList;
	mIOCycleTelemetryWindowControllerList = new HLIOCycleTelemetryWindowControllerList;
	mTimeWindowControllerList = new HLTimeWindowControllerList;
	mNotificationStartTime = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime());
	return self;
}

-(void)	dealloc
{
	HLTimeWindowControllerList::iterator theTimeIterator = mTimeWindowControllerList->begin();
	while(theTimeIterator != mTimeWindowControllerList->end())
	{
		HLTimeWindowController* theWindowController = *theTimeIterator;
		[theWindowController dealloc];
		std::advance(theTimeIterator, 1);
	}
	
	HLIOCycleTelemetryWindowControllerList::iterator theIOCycleTelemetryIterator = mIOCycleTelemetryWindowControllerList->begin();
	while(theIOCycleTelemetryIterator != mIOCycleTelemetryWindowControllerList->end())
	{
		HLIOCycleTelemetryWindowController* theWindowController = *theIOCycleTelemetryIterator;
		[theWindowController dealloc];
		std::advance(theIOCycleTelemetryIterator, 1);
	}
	
	HLFilePlayerWindowControllerList::iterator theFilePlayerIterator = mFilePlayerWindowControllerList->begin();
	while(theFilePlayerIterator != mFilePlayerWindowControllerList->end())
	{
		HLFilePlayerWindowController* theWindowController = *theFilePlayerIterator;
		[theWindowController dealloc];
		std::advance(theFilePlayerIterator, 1);
	}
	
	HLInputWindowControllerList::iterator theInputIterator = mInputWindowControllerList->begin();
	while(theInputIterator != mInputWindowControllerList->end())
	{
		HLInputWindowController* theWindowController = *theInputIterator;
		[theWindowController dealloc];
		std::advance(theInputIterator, 1);
	}
	
	HLDeviceWindowControllerMap::iterator theDeviceWindowIterator = mDeviceWindowControllerMap->begin();
	while(theDeviceWindowIterator != mDeviceWindowControllerMap->end())
	{
		HLDeviceWindowController* theWindowController = theDeviceWindowIterator->second;
		[theWindowController dealloc];
		std::advance(theDeviceWindowIterator, 1);
	}
	
	delete mDeviceWindowControllerMap;
	[mCPUWindowController dealloc];
	[mSystemWindowController dealloc];
	[super dealloc];
}

-(UInt64)	GetNotificationStartTime
{
	return mNotificationStartTime;
}

-(IBAction)	ShowSystemWindow:	(id)inSender
{
	if(mSystemWindowController == NULL)
	{
		mSystemWindowController = [[HLSystemWindowController alloc] initWithApplicationDelegate: self];
	}
	
    [mSystemWindowController showWindow: inSender];
}

-(IBAction)	ShowCPUWindow:	(id)inSender
{
	if(mCPUWindowController == NULL)
	{
		mCPUWindowController = [[HLCPUWindowController alloc] initWithApplicationDelegate: self];
	}
	
    [mCPUWindowController showWindow: inSender];
}

-(void)	ShowDeviceWindow:	(AudioDeviceID)inDeviceID
{
	//	look for the WindowController in the map
	HLDeviceWindowController* theWindowController = NULL;
	HLDeviceWindowControllerMap::iterator theIterator = mDeviceWindowControllerMap->find(inDeviceID);
	if(theIterator != mDeviceWindowControllerMap->end())
	{
		//	found it
		theWindowController = theIterator->second;
	}
	else
	{
		//	it isn't there, so make a new one
		theWindowController = [[HLDeviceWindowController alloc] initWithDevice: inDeviceID  ApplicationDelegate: self];
		
		//	and stick it in the map
		mDeviceWindowControllerMap->insert(HLDeviceWindowControllerMap::value_type(inDeviceID, theWindowController));
	}
    [theWindowController showWindow: self];
}

-(void)	DestroyDeviceWindow:	(AudioDeviceID)inDeviceID
{
	HLDeviceWindowControllerMap::iterator theIterator = mDeviceWindowControllerMap->find(inDeviceID);
	if(theIterator != mDeviceWindowControllerMap->end())
	{
		HLDeviceWindowController* theWindowController = theIterator->second;
		[theWindowController release];
		mDeviceWindowControllerMap->erase(theIterator);
	}
}

-(IBAction)	NewFilePlayerWindow:	(id)inSender
{
	//	allocate a new HLFilePlayerWindowController
	HLFilePlayerWindowController* theWindowController = [[HLFilePlayerWindowController alloc] initWithApplicationDelegate: self];
	
	//	stick it in the list
	mFilePlayerWindowControllerList->push_back(theWindowController);
	
	//	show the window
    [theWindowController showWindow: inSender];
}

-(void)	DestroyFilePlayerWindow:	(HLFilePlayerWindowController*)inFilePlayerWindowController
{
	bool wasFound = false;
	HLFilePlayerWindowControllerList::iterator theFilePlayerIterator = mFilePlayerWindowControllerList->begin();
	while(!wasFound && (theFilePlayerIterator != mFilePlayerWindowControllerList->end()))
	{
		HLFilePlayerWindowController* theWindowController = *theFilePlayerIterator;
		if(theWindowController == inFilePlayerWindowController)
		{
			wasFound = true;
			mFilePlayerWindowControllerList->erase(theFilePlayerIterator);
			[theWindowController release];
		}
		else
		{
			std::advance(theFilePlayerIterator, 1);
		}
	}
}

-(IBAction)	NewInputWindow:	(id)inSender
{
	//	allocate a new HLInputWindowController
	HLInputWindowController* theWindowController = [[HLInputWindowController alloc] initWithApplicationDelegate: self];
	
	//	stick it in the list
	mInputWindowControllerList->push_back(theWindowController);
	
	//	show the window
    [theWindowController showWindow: inSender];
}

-(void)	DestroyInputWindow:	(HLInputWindowController*)inInputWindowController
{
	bool wasFound = false;
	HLInputWindowControllerList::iterator theInputIterator = mInputWindowControllerList->begin();
	while(!wasFound && (theInputIterator != mInputWindowControllerList->end()))
	{
		HLInputWindowController* theWindowController = *theInputIterator;
		if(theWindowController == inInputWindowController)
		{
			wasFound = true;
			mInputWindowControllerList->erase(theInputIterator);
			[theWindowController release];
		}
		else
		{
			std::advance(theInputIterator, 1);
		}
	}
}

-(IBAction)	NewIOCycleTelemetryWindow:	(id)inSender
{
	//	allocate a new HLIOCycleTelemetryWindowController
	HLIOCycleTelemetryWindowController* theWindowController = [[HLIOCycleTelemetryWindowController alloc] initWithApplicationDelegate: self];
	
	//	stick it in the list
	mIOCycleTelemetryWindowControllerList->push_back(theWindowController);
	
	//	show the window
    [theWindowController showWindow: inSender];
}

-(void)	DestroyIOCycleTelemetryWindow:	(HLIOCycleTelemetryWindowController*)inIOCycleTelemetryWindowController
{
	bool wasFound = false;
	HLIOCycleTelemetryWindowControllerList::iterator theIOCycleTelemetryIterator = mIOCycleTelemetryWindowControllerList->begin();
	while(!wasFound && (theIOCycleTelemetryIterator != mIOCycleTelemetryWindowControllerList->end()))
	{
		HLIOCycleTelemetryWindowController* theWindowController = *theIOCycleTelemetryIterator;
		if(theWindowController == inIOCycleTelemetryWindowController)
		{
			wasFound = true;
			mIOCycleTelemetryWindowControllerList->erase(theIOCycleTelemetryIterator);
			[theWindowController release];
		}
		else
		{
			std::advance(theIOCycleTelemetryIterator, 1);
		}
	}
}

-(IBAction)	NewTimeWindow:	(id)inSender
{
	//	allocate a new HLTimeWindowController
	HLTimeWindowController* theWindowController = [[HLTimeWindowController alloc] initWithApplicationDelegate: self];
	
	//	stick it in the list
	mTimeWindowControllerList->push_back(theWindowController);
	
	//	show the window
    [theWindowController showWindow: inSender];
}

-(void)	DestroyTimeWindow:	(HLTimeWindowController*)inTimeWindowController
{
	bool wasFound = false;
	HLTimeWindowControllerList::iterator theTimeIterator = mTimeWindowControllerList->begin();
	while(!wasFound && (theTimeIterator != mTimeWindowControllerList->end()))
	{
		HLTimeWindowController* theWindowController = *theTimeIterator;
		if(theWindowController == inTimeWindowController)
		{
			wasFound = true;
			mTimeWindowControllerList->erase(theTimeIterator);
			[theWindowController release];
		}
		else
		{
			std::advance(theTimeIterator, 1);
		}
	}
}

-(void)	applicationDidFinishLaunching:	(NSNotification*)inNotification
{
    [self ShowSystemWindow: self];
}

@end

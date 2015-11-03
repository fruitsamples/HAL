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
#import "AppController.h"

#include "AudioThruEngine.h"

@implementation AppController

AudioThruEngine	*gThruEngine = NULL;

void	CheckErr(OSStatus err)
{
	if (err) {
		printf("error %-4.4s %ld\n", (char *)&err, err);
		throw 1;
	}
}

- (id)init
{
	mInputDeviceList = new AudioDeviceList(true);
	mOutputDeviceList = new AudioDeviceList(false);
	return self;
}

- (void)dealloc
{
	delete mInputDeviceList;
	delete mOutputDeviceList;
}

- (void)updateThruLatency
{
	[mTotalLatencyText setIntValue:gThruEngine->GetThruLatency()];
}

static void	BuildDeviceMenu(AudioDeviceList *devlist, NSPopUpButton *menu, AudioDeviceID initSel)
{
	[menu removeAllItems];
	
	AudioDeviceList::DeviceList &thelist = devlist->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		[menu addItemWithTitle: [NSString stringWithCString: (*i).mName]];
		if (initSel == (*i).mID)
			[menu selectItemAtIndex: index];
	}
}

- (void)awakeFromNib
{
	AudioDeviceID inputDevice, outputDevice;
	UInt32 propsize;

	id deleg = [[NSApplication sharedApplication] delegate];
	[[NSApplication sharedApplication] setDelegate:self];
	
	propsize = sizeof(AudioDeviceID);
	CheckErr (AudioHardwareGetProperty(kAudioHardwarePropertyDefaultInputDevice, &propsize, &inputDevice));

	propsize = sizeof(AudioDeviceID);
	CheckErr (AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &propsize, &outputDevice));
	
	BuildDeviceMenu(mInputDeviceList, mInputDevices, inputDevice);
	BuildDeviceMenu(mOutputDeviceList, mOutputDevices, outputDevice);
	
	gThruEngine = new AudioThruEngine;
	gThruEngine->SetDevices(inputDevice, outputDevice);
	[self bufferSizeChanged:self];
	
	gThruEngine->Start();
	[self updateThruLatency];
	
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.75 target:self selector:@selector(updateActualLatency:) 
		userInfo:nil repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (gThruEngine)
		gThruEngine->Stop();
}

- (void)updateActualLatency:(NSTimer *)timer
{
	double thruTime = gThruEngine->GetThruTime();
	NSString *msg = [NSString stringWithFormat: @"%.0f", thruTime];
	[mMeasuredLatencyText setStringValue: msg];
	
	char *errmsg = gThruEngine->GetErrorMessage();
	msg = [NSString stringWithCString: errmsg];
	[mErrorText setStringValue: msg];
}

- (IBAction)toggleThru:(id)sender
{
	bool enabled = [sender intValue];
	gThruEngine->EnableThru(enabled);
}

- (IBAction)bufferSizeChanged:(id)sender
{
	UInt32 size = [mBufferSizeField intValue];
	gThruEngine->SetBufferSize(size);
	[self updateThruLatency];
}

- (IBAction)inputDeviceSelected:(id)sender
{
	int val = [mInputDevices indexOfSelectedItem];
	gThruEngine->SetInputDevice( (mInputDeviceList->GetList())[val].mID );
	[self updateThruLatency];
}

- (IBAction)inputSourceSelected:(id)sender
{
}

- (IBAction)outputDeviceSelected:(id)sender
{
	int val = [mOutputDevices indexOfSelectedItem];
	gThruEngine->SetOutputDevice( (mOutputDeviceList->GetList())[val].mID );
	[self updateThruLatency];
}

- (IBAction)outputSourceSelected:(id)sender
{
}

- (IBAction)inputLoadChanged:(id)sender
{
	gThruEngine->SetInputLoad( [sender floatValue] / 100. );
	[mInputLoadText setIntValue:[sender intValue]];
}

- (IBAction)outputLoadChanged:(id)sender
{
	gThruEngine->SetOutputLoad( [sender floatValue] / 100. );
	[mOutputLoadText setIntValue:[sender intValue]];
}

- (IBAction)extraLatencyChanged:(id)sender
{
	int val = [sender intValue];
	gThruEngine->SetExtraLatency(val);
	[self updateThruLatency];
}

- (IBAction)restart:(id)sender
{
	gThruEngine->SetInputLoad(0);
	gThruEngine->SetOutputLoad(0);

	gThruEngine->Stop();

	[mInputLoadSlider setFloatValue: 0.];
	[mOutputLoadSlider setFloatValue: 0.];
	[mInputLoadText setIntValue:0];
	[mOutputLoadText setIntValue:0];
	sleep(1);

	gThruEngine->Start();
	
}

@end

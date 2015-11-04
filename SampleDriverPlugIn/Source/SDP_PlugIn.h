/*	Copyright � 2007 Apple Inc. All Rights Reserved.
	
	Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
			Apple Inc. ("Apple") in consideration of your agreement to the
			following terms, and your use, installation, modification or
			redistribution of this Apple software constitutes acceptance of these
			terms.  If you do not agree with these terms, please do not use,
			install, modify or redistribute this Apple software.
			
			In consideration of your agreement to abide by the following terms, and
			subject to these terms, Apple grants you a personal, non-exclusive
			license, under Apple's copyrights in this original Apple software (the
			"Apple Software"), to use, reproduce, modify and redistribute the Apple
			Software, with or without modifications, in source and/or binary forms;
			provided that if you redistribute the Apple Software in its entirety and
			without modifications, you must retain this notice and the following
			text and disclaimers in all such redistributions of the Apple Software. 
			Neither the name, trademarks, service marks or logos of Apple Inc. 
			may be used to endorse or promote products derived from the Apple
			Software without specific prior written permission from Apple.  Except
			as expressly stated in this notice, no other rights or licenses, express
			or implied, are granted by Apple herein, including but not limited to
			any patent rights that may be infringed by your derivative works or by
			other works in which the Apple Software may be incorporated.
			
			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
			MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
			THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
			FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
			OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
			
			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
			OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
			SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
			INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
			MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
			AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
			STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
			POSSIBILITY OF SUCH DAMAGE.
*/
/*==================================================================================================
	SDP_PlugIn.h

==================================================================================================*/
#if !defined(__SDP_PlugIn_h__)
#define __SDP_PlugIn_h__

//==================================================================================================
//	Includes
//==================================================================================================

//	Super Class Includes
#include "HP_DriverPlugIn.h"

//==================================================================================================
//	Types
//==================================================================================================

class CACFMachPort;

//==================================================================================================
//	SDP_PlugIn
//==================================================================================================

class SDP_PlugIn
:
	public HP_DriverPlugIn
{

//	Constants
public:
	enum
	{
		kSampleDriverPlugInDevicePropertyFoo	= 'Foo!'
	};

//	Construction/Destruction
public:
					SDP_PlugIn(const AudioDriverPlugInHostInfo& inHostInfo);
	virtual			~SDP_PlugIn();

//	Operations
public:
	virtual bool	DeviceHasProperty(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const;
	virtual UInt32	DeviceGetPropertyDataSize(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const;
	virtual bool	DeviceIsPropertyWritable(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID) const;
	virtual void	DeviceGetPropertyData(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32& ioPropertyDataSize, void* outPropertyData) const;
	virtual void	DeviceSetPropertyData(UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);
	
	virtual bool	StreamHasProperty(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const;
	virtual UInt32	StreamGetPropertyDataSize(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const;
	virtual bool	StreamIsPropertyWritable(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID) const;
	virtual void	StreamGetPropertyData(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32& ioPropertyDataSize, void* outPropertyData) const;
	virtual void	StreamSetPropertyData(io_object_t inIOAudioStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);

//	Implementation
private:
	static UInt32	GetFoo(io_object_t inIOAudioEngine);
	static void		SetFoo(io_object_t inIOAudioEngine, UInt32 inFoo);
	static void		MachPortCallBack(CFMachPortRef inCFMachPort, void* inMessage, CFIndex inSize, SDP_PlugIn* inPlugIn);

	io_connect_t	mEngineConnection;
	CACFMachPort*	mConnectionNotificationPort;
	
};

#endif

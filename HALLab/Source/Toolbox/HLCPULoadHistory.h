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
	HLCPULoadHistory.h

=============================================================================*/
#if !defined(__HLCPULoadHistory_h__)
#define __HLCPULoadHistory_h__

//=============================================================================
//	Includes
//=============================================================================

//	System Includes
#include <CoreAudio/CoreAudioTypes.h>

//	Standard Library Includes
#include <string.h>

//	Mach Includes
extern "C"
{
	#include <mach/mach.h>
}

//=============================================================================
//	HLCPULoadHistoryItem
//=============================================================================

struct HLCPULoadHistoryItem
{

	Float64	mLoads[CPU_STATE_MAX];
	
	HLCPULoadHistoryItem() { memset(mLoads, 0, CPU_STATE_MAX * sizeof(Float64)); mLoads[CPU_STATE_IDLE] = 1.0; }

};

typedef HLCPULoadHistoryItem*	HLCPULoadHistoryItemList;

//=============================================================================
//	HLCPULoadHistory
//=============================================================================

class HLCPULoadHistory
{

//	Construction/Destruction
public:
								HLCPULoadHistory(UInt32 inHistoryLength);
	virtual						~HLCPULoadHistory();

//	Operations
public:
	UInt32						GetHistoryLength() const;
	void						SetHistoryLength(UInt32 inHistoryLength);
	
	Float64						GetCPULoad(UInt32 inCPUIndex, UInt32 inCPUState, UInt32 inItemIndex) const;
	
	void						UpdateCPULoads();
	void						ResetCPULoads();

//	Implementation
private:
	UInt32						GetHistoryItemIndex(UInt32 inAbsoluteIndex) const { return (mOldestIndex + inAbsoluteIndex) % mHistoryLength; }
	
	natural_t					mNumberCPUs;
	UInt32						mOldestIndex;
	UInt32						mHistoryLength;
	HLCPULoadHistoryItemList*	mHistoryLists;
	processor_cpu_load_info_t	mOldRawCPULoads;
	mach_msg_type_number_t		mOldRawCPULoadsSize;

};

#endif

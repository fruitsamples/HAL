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
	HLCPULoadHistory.cpp

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#include "HLCPULoadHistory.h"

//	PublicUtility Includes
#include "CADebugMacros.h"
#include "CAException.h"

//	Standard Library Includes
#include <algorithm>

//=============================================================================
//	HLCPULoadHistory
//=============================================================================

static inline void	HLCPULoadHistory_GetCPULoads(natural_t& outNumberCPUs, processor_cpu_load_info_t& outCPULoads, mach_msg_type_number_t& outCPULoadsSize)
{
	kern_return_t theError = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &outNumberCPUs, (processor_info_array_t*)&outCPULoads, &outCPULoadsSize);
	ThrowIfKernelError(theError, CAException(theError), "HLCPULoadHistory_GetCPULoads: got an error getting the CPU load");
}

static inline void	HLCPULoadHistory_FreeCPULoads(processor_cpu_load_info_t inCPULoads, mach_msg_type_number_t inCPULoadsSize)
{
    vm_deallocate(mach_task_self(), (vm_address_t)inCPULoads, inCPULoadsSize);
}

HLCPULoadHistory::HLCPULoadHistory(UInt32 inHistoryLength)
:
	mNumberCPUs(0),
	mOldestIndex(0),
	mHistoryLength(inHistoryLength),
	mHistoryLists(NULL),
	mOldRawCPULoads(NULL),
	mOldRawCPULoadsSize(0)
{
	//	get the number of CPUs
	processor_cpu_load_info_t theCPULoads;
	mach_msg_type_number_t theCPULoadsSize;
	HLCPULoadHistory_GetCPULoads(mNumberCPUs, theCPULoads, theCPULoadsSize);
	HLCPULoadHistory_FreeCPULoads(theCPULoads, theCPULoadsSize);
	
	//	allocate the histories
	mHistoryLists = new HLCPULoadHistoryItemList[mNumberCPUs];
	for(UInt32 theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
	{
		mHistoryLists[theCPUIndex] = new HLCPULoadHistoryItem[mHistoryLength];
	}
}

HLCPULoadHistory::~HLCPULoadHistory()
{
	//	deallocate the histories
	for(UInt32 theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
	{
		delete[] mHistoryLists[theCPUIndex];
	}
	delete mHistoryLists;
	
	if(mOldRawCPULoads != NULL)
	{
		HLCPULoadHistory_FreeCPULoads(mOldRawCPULoads, mOldRawCPULoadsSize);
	}
}

UInt32	HLCPULoadHistory::GetHistoryLength() const
{
	return mHistoryLength;
}

void	HLCPULoadHistory::SetHistoryLength(UInt32 inHistoryLength)
{
	if(inHistoryLength != mHistoryLength)
	{
		UInt32 theCPUIndex;
		UInt32 theNewCPUHistoryIndex;
		UInt32 theCPUHistoryIndex;
		HLCPULoadHistoryItemList theNewCPUHistory;
		HLCPULoadHistoryItemList theCPUHistory;
		
		//	allocate the new histories
		HLCPULoadHistoryItemList* theNewHistoryLists = new HLCPULoadHistoryItemList[mNumberCPUs];
		for(theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
		{
			theNewHistoryLists[theCPUIndex] = new HLCPULoadHistoryItem[inHistoryLength];
		}
		
		//	copy the old data
		if(mHistoryLength <= inHistoryLength)
		{
			for(theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
			{
				theNewCPUHistory = theNewHistoryLists[theCPUIndex];
				theCPUHistory = mHistoryLists[theCPUIndex];
				
				for(theNewCPUHistoryIndex = 0; theNewCPUHistoryIndex < mHistoryLength; ++theNewCPUHistoryIndex)
				{
					theCPUHistoryIndex = GetHistoryItemIndex(theNewCPUHistoryIndex);
					theNewCPUHistory[theNewCPUHistoryIndex] = theCPUHistory[theCPUHistoryIndex];
				}
			}
		}
		else
		{
			for(theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
			{
				theNewCPUHistory = theNewHistoryLists[theCPUIndex];
				theCPUHistory = mHistoryLists[theCPUIndex];
				
				UInt32 theNumberOverflow = mHistoryLength - inHistoryLength;
				
				for(theNewCPUHistoryIndex = 0; theNewCPUHistoryIndex < inHistoryLength; ++theNewCPUHistoryIndex)
				{
					theCPUHistoryIndex = GetHistoryItemIndex(theNewCPUHistoryIndex + theNumberOverflow);
					theNewCPUHistory[theNewCPUHistoryIndex] = theCPUHistory[theCPUHistoryIndex];
				}
			}
		}
				
		//	deallocate the old histories
		for(UInt32 theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
		{
			delete[] mHistoryLists[theCPUIndex];
		}
		delete mHistoryLists;
		
		//	and assign the new ones
		mHistoryLists = theNewHistoryLists;
	
		//	and set the values
		if(mHistoryLength <= inHistoryLength)
		{
			mOldestIndex = mHistoryLength;
		}
		else
		{
			mOldestIndex = 0;
		}
		mHistoryLength = inHistoryLength;
	}
}

Float64	HLCPULoadHistory::GetCPULoad(UInt32 inCPUIndex, UInt32 inCPUState, UInt32 inItemIndex) const
{
	Float64 theAnswer = 0.0;
	HLCPULoadHistoryItemList theCPUHistory = mHistoryLists[inCPUIndex];
	
	UInt32 theHistoryItemIndex = GetHistoryItemIndex(inItemIndex);
	theAnswer = theCPUHistory[theHistoryItemIndex].mLoads[inCPUState];
	
	return theAnswer;
}

void	HLCPULoadHistory::UpdateCPULoads()
{
	//	get the raw loads
	natural_t theNumberCPUs;
	processor_cpu_load_info_t theNewRawCPULoads;
	mach_msg_type_number_t theNewRawCPULoadsSize;
	HLCPULoadHistory_GetCPULoads(theNumberCPUs, theNewRawCPULoads, theNewRawCPULoadsSize);
	
	//	iterate through and update the saved loads
	for(UInt32 theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
	{
		UInt32 theStateIndex;
		HLCPULoadHistoryItemList theCPUHistory = mHistoryLists[theCPUIndex];
		HLCPULoadHistoryItem* theOldestItem = &(theCPUHistory[mOldestIndex]);
		
		//	calculate the raw deltas and raw duration
		UInt32 theNewRawDuration = 0;
		UInt32 theNewRawCPULoadDeltas[CPU_STATE_MAX];
		for(theStateIndex = 0; theStateIndex < CPU_STATE_MAX; ++theStateIndex)
		{
			if(mOldRawCPULoads != NULL)
			{
				theNewRawCPULoadDeltas[theStateIndex] = theNewRawCPULoads[theCPUIndex].cpu_ticks[theStateIndex] - mOldRawCPULoads[theCPUIndex].cpu_ticks[theStateIndex];
			}
			else
			{
				theNewRawCPULoadDeltas[theStateIndex] = theNewRawCPULoads[theCPUIndex].cpu_ticks[theStateIndex];
			}
			theNewRawDuration += theNewRawCPULoadDeltas[theStateIndex];
		}
	
		//	calculate the loads
		for(UInt32 theStateIndex = 0; theStateIndex < CPU_STATE_MAX; ++theStateIndex)
		{
			theOldestItem->mLoads[theStateIndex] = static_cast<Float64>(theNewRawCPULoadDeltas[theStateIndex]) / static_cast<Float64>(theNewRawDuration);
		}
	}
	
	//	the next index is the oldest now
	mOldestIndex = (mOldestIndex + 1) % mHistoryLength;
	
	//	free the old raw CPU loads and save the new ones
	if(mOldRawCPULoads != NULL)
	{
		HLCPULoadHistory_FreeCPULoads(mOldRawCPULoads, mOldRawCPULoadsSize);
	}
	mOldRawCPULoads = theNewRawCPULoads;
	mOldRawCPULoadsSize = theNewRawCPULoadsSize;
}

void	HLCPULoadHistory::ResetCPULoads()
{
	for(UInt32 theCPUIndex = 0; theCPUIndex < mNumberCPUs; ++theCPUIndex)
	{
		memset(mHistoryLists[theCPUIndex], 0, mHistoryLength * sizeof(HLCPULoadHistoryItem));
	}
	mOldestIndex = 0;
	if(mOldRawCPULoads != NULL)
	{
		HLCPULoadHistory_FreeCPULoads(mOldRawCPULoads, mOldRawCPULoadsSize);
		mOldRawCPULoads = NULL;
		mOldRawCPULoadsSize = 0;
	}
}

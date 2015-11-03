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
	AudioThruEngine.cpp
	
=============================================================================*/

#include "AudioThruEngine.h"
#include "AudioRingBuffer.h"
#include <unistd.h>

#define USE_AUDIODEVICEREAD 0
#if USE_AUDIODEVICEREAD
AudioBufferList *gInputIOBuffer = NULL;
#endif

#define kSecondsInRingBuffer 2.

AudioThruEngine::AudioThruEngine() : 
	mRunning(false),
	mThruing(false),
	mBufferSize(512),
	mExtraLatencyFrames(0),
	mInputLoad(0.),
	mOutputLoad(0.)
{
	mErrorMessage[0] = '\0';
	mInputBuffer = new AudioRingBuffer(4, 88200);
}

AudioThruEngine::~AudioThruEngine()
{
	SetDevices(kAudioDeviceUnknown, kAudioDeviceUnknown);
	delete mInputBuffer;
}

void	AudioThruEngine::SetDevices(AudioDeviceID input, AudioDeviceID output)
{
	Stop();
	
	if (input != kAudioDeviceUnknown)
		mInputDevice.Init(input, true);
	if (output != kAudioDeviceUnknown)
		mOutputDevice.Init(output, false);
}

void	AudioThruEngine::SetInputDevice(AudioDeviceID input)
{
	Stop();
	mInputDevice.Init(input, true);
	SetBufferSize(mBufferSize);
	mInputBuffer->Clear();
	Start();
}

void	AudioThruEngine::SetOutputDevice(AudioDeviceID output)
{
	Stop();
	mOutputDevice.Init(output, false);
	SetBufferSize(mBufferSize);
	Start();
}

void	AudioThruEngine::SetBufferSize(UInt32 size)
{
	bool wasRunning = Stop();
	mBufferSize = size;
	mInputDevice.SetBufferSize(size);
	mOutputDevice.SetBufferSize(size);
	if (wasRunning) Start();
}

void	AudioThruEngine::SetExtraLatency(SInt32 frames)
{
	mExtraLatencyFrames = frames;
	if (mRunning)
		ComputeThruOffset();
}


void	AudioThruEngine::Start()
{
	if (mRunning) return;
	if (!mInputDevice.Valid() || !mOutputDevice.Valid()) {
		printf("invalid device\n");
		return;
	}

	// $$$ should do some checks on the format/sample rate matching
	if (mInputDevice.mFormat.mSampleRate != mOutputDevice.mFormat.mSampleRate) {
		sprintf(mErrorMessage, "Error - sample rate mismatch: %f / %f\n", mInputDevice.mFormat.mSampleRate, mOutputDevice.mFormat.mSampleRate);
		return;
	}
	if (mInputDevice.mFormat.mChannelsPerFrame != mOutputDevice.mFormat.mChannelsPerFrame
	|| mInputDevice.mFormat.mBytesPerFrame != mOutputDevice.mFormat.mBytesPerFrame) {
		sprintf(mErrorMessage, "Error - format mismatch: %ld / %ld channels, %ld / %ld bytes per frame\n",
			mInputDevice.mFormat.mChannelsPerFrame, mOutputDevice.mFormat.mChannelsPerFrame,
			mInputDevice.mFormat.mBytesPerFrame, mOutputDevice.mFormat.mBytesPerFrame);
		return;
	}
	mErrorMessage[0] = '\0';
	mInputBuffer->Allocate(mInputDevice.mFormat.mBytesPerFrame, UInt32(kSecondsInRingBuffer * mInputDevice.mFormat.mSampleRate));
	mSampleRate = mInputDevice.mFormat.mSampleRate;
	
	mRunning = true;
	
#if USE_AUDIODEVICEREAD
	UInt32 streamListSize;
	verify_noerr (AudioDeviceGetPropertyInfo(gInputDevice, 0, true, kAudioDevicePropertyStreams, &streamListSize, NULL));
	UInt32 nInputStreams = streamListSize / sizeof(AudioStreamID);
	
	propsize = offsetof(AudioBufferList, mBuffers[nInputStreams]);
	gInputIOBuffer = (AudioBufferList *)malloc(propsize);
	verify_noerr (AudioDeviceGetProperty(gInputDevice, 0, true, kAudioDevicePropertyStreamConfiguration, &propsize, gInputIOBuffer));
	gInputIOBuffer->mBuffers[0].mData = malloc(gInputIOBuffer->mBuffers[0].mDataByteSize);
	
	verify_noerr (AudioDeviceSetProperty(gInputDevice, NULL, 0, true, kAudioDevicePropertyRegisterBufferList, propsize, gInputIOBuffer));
#endif
	
	mInputProcState = kStarting;
	mOutputProcState = kStarting;
	
	verify_noerr (AudioDeviceAddIOProc(mInputDevice.mID, InputIOProc, this));
	verify_noerr (AudioDeviceStart(mInputDevice.mID, InputIOProc));
	
	verify_noerr (AudioDeviceAddIOProc(mOutputDevice.mID, OutputIOProc, this));
	verify_noerr (AudioDeviceStart(mOutputDevice.mID, OutputIOProc));
	
	while (mInputProcState != kRunning || mOutputProcState != kRunning)
		usleep(1000);
	
//	usleep(12000);
	ComputeThruOffset();
}

void	AudioThruEngine::ComputeThruOffset()
{
	if (!mRunning) {
		mActualThruLatency = 0;
		mInToOutSampleOffset = 0;
		return;
	}
//	AudioTimeStamp inputTime, outputTime;
//	verify_noerr (AudioDeviceGetCurrentTime(mInputDevice.mID, &inputTime));
//	verify_noerr (AudioDeviceGetCurrentTime(mOutputDevice.mID, &outputTime));
	
//	printf(" in host: %20.0f  samples: %20.f  safety: %7ld  buffer: %4ld\n", Float64(inputTime.mHostTime), inputTime.mSampleTime,
//		mInputDevice.mSafetyOffset, mInputDevice.mBufferSizeFrames);
//	printf("out host: %20.0f  samples: %20.f  safety: %7ld  buffer: %4ld\n", Float64(outputTime.mHostTime), outputTime.mSampleTime,
//		mOutputDevice.mSafetyOffset, mOutputDevice.mBufferSizeFrames);
	mActualThruLatency = SInt32(mInputDevice.mSafetyOffset + /*2 * */ mInputDevice.mBufferSizeFrames +
						mOutputDevice.mSafetyOffset + mOutputDevice.mBufferSizeFrames) + mExtraLatencyFrames;
	mInToOutSampleOffset = mActualThruLatency + mIODeltaSampleCount;
//	printf("thru latency: %.0f frames, inToOutOffset: %0.f frames\n", latency, mInToOutSampleOffset);
}

// return whether we were running
bool	AudioThruEngine::Stop()
{
	if (!mRunning) return false;
	mRunning = false;
	
	mInputProcState = kStopRequested;
	mOutputProcState = kStopRequested;
	
	while (mInputProcState != kOff || mOutputProcState != kOff)
		usleep(5000);
	
	AudioDeviceRemoveIOProc(mInputDevice.mID, InputIOProc);
	AudioDeviceRemoveIOProc(mOutputDevice.mID, OutputIOProc);
	
	return true;
}



// Input IO Proc
// Receiving input for 1 buffer + safety offset into the past
OSStatus AudioThruEngine::InputIOProc (	AudioDeviceID			inDevice,
										const AudioTimeStamp*	inNow,
										const AudioBufferList*	inInputData,
										const AudioTimeStamp*	inInputTime,
										AudioBufferList*		outOutputData,
										const AudioTimeStamp*	inOutputTime,
										void*					inClientData)
{
	AudioThruEngine *This = (AudioThruEngine *)inClientData;
	
	switch (This->mInputProcState) {
	case kStarting:
		This->mInputProcState = kRunning;
		break;
	case kStopRequested:
		AudioDeviceStop(inDevice, InputIOProc);
		This->mInputProcState = kOff;
		return noErr;
	default:
		break;
	}

	This->mLastInputSampleCount = inInputTime->mSampleTime;
	This->mInputBuffer->Store((const Byte *)inInputData->mBuffers[0].mData, 
								This->mInputDevice.mBufferSizeFrames,
								UInt64(inInputTime->mSampleTime));
	
	This->ApplyLoad(This->mInputLoad);
	return noErr;
}

// Output IO Proc
// Rendering output for 1 buffer + safety offset into the future
OSStatus AudioThruEngine::OutputIOProc (	AudioDeviceID			inDevice,
											const AudioTimeStamp*	inNow,
											const AudioBufferList*	inInputData,
											const AudioTimeStamp*	inInputTime,
											AudioBufferList*		outOutputData,
											const AudioTimeStamp*	inOutputTime,
											void*					inClientData)
{
	AudioThruEngine *This = (AudioThruEngine *)inClientData;
	
	switch (This->mOutputProcState) {
	case kStarting:
		if (This->mInputProcState == kRunning) {
			This->mOutputProcState = kRunning;
			This->mIODeltaSampleCount = inOutputTime->mSampleTime - This->mLastInputSampleCount;
		}
		return noErr;
	case kStopRequested:
		AudioDeviceStop(inDevice, OutputIOProc);
		This->mOutputProcState = kOff;
		return noErr;
	default:
		break;
	}

	if (This->mThruing) {
		double delta = This->mInputBuffer->Fetch((Byte *)outOutputData->mBuffers[0].mData,
								This->mOutputDevice.mBufferSizeFrames,
								UInt64(inOutputTime->mSampleTime - This->mInToOutSampleOffset));
		This->mThruTime = delta;
		
		This->ApplyLoad(This->mOutputLoad);
		
#if USE_AUDIODEVICEREAD
		AudioTimeStamp readTime;
		
		readTime.mFlags = kAudioTimeStampSampleTimeValid;
		readTime.mSampleTime = inNow->mSampleTime - gInputSafetyOffset - gOutputSampleCount;
		
		verify_noerr(AudioDeviceRead(gInputDevice.mID, &readTime, gInputIOBuffer));
		memcpy(outOutputData->mBuffers[0].mData, gInputIOBuffer->mBuffers[0].mData, outOutputData->mBuffers[0].mDataByteSize);
#endif
	} else
		This->mThruTime = 0.;
	
	return noErr;
}

void	AudioThruEngine::ApplyLoad(double load)
{
	double loadNanos = (load * mBufferSize / mSampleRate) /* seconds */ * 1000000000.;
	
	UInt64 now = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime());
	UInt64 waitUntil = UInt64(now + loadNanos);
	
	while (now < waitUntil) {
		now = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime());
	}
}


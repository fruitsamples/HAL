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
	HLCPULoadHistoryView.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLCPULoadHistoryView.h"

//	Local Includes
#import "HLCPUInfo.h"

//=============================================================================
//	HLCPULoadHistoryView
//=============================================================================

@implementation HLCPULoadHistoryView

-(id)	initWithFrame:	(NSRect)inFrame
{
	mDataSource = NULL;
	mTotalLoadColor = [[NSColor colorWithCalibratedHue: 0.0 saturation: 0.0 brightness: 0.0 alpha: 1.0] retain];
	mDrawTotalLoad = false;
	mTotalLoadPath = [[NSBezierPath alloc] init];
	
	mUserLoadColor = [[NSColor colorWithCalibratedHue: 1.0 / 3.0 saturation: 0.75 brightness: 0.75 alpha: 1.0] retain];
	mDrawUserLoad = true;
	mUserLoadPath = [[NSBezierPath alloc] init];
	
	mSystemLoadColor = [[NSColor colorWithCalibratedHue: 0.0 saturation: 0.75 brightness: 0.75 alpha: 1.0] retain];
	mDrawSystemLoad = true;
	mSystemLoadPath = [[NSBezierPath alloc] init];
	
	mNiceLoadColor = [[NSColor colorWithCalibratedHue: 2.0 / 3.0 saturation: 0.75 brightness: 0.75 alpha: 1.0] retain];
	mDrawNiceLoad = true;
	mNiceLoadPath = [[NSBezierPath alloc] init];
	
	return [super initWithFrame: inFrame];
}

-(void)	awakeFromNib
{
	//	update the window
	[[self window] setExcludedFromWindowsMenu: YES];
}

-(void)	dealloc
{
	[mTotalLoadColor release];
	[mTotalLoadPath release];
	[mUserLoadColor release];
	[mUserLoadPath release];
	[mSystemLoadColor release];
	[mSystemLoadPath release];
	[mNiceLoadColor release];
	[mNiceLoadPath release];
	[super dealloc];
}

-(BOOL)	isOpaque
{
    return NO;
}

#define	kCPULoadHistoryViewCPUSpacing	2.0

-(Float32)	CalculateCPUWidth
{
	//	get the bounds rect
	NSRect theBounds = [self bounds];
	
	//	get the number of CPUs
	UInt32 theNumberCPUs = HLCPUInfo::GetNumberCPUs();
	
	//	caluclate the width
	Float32 theCPUWidth = (theBounds.size.width - (kCPULoadHistoryViewCPUSpacing * (theNumberCPUs - 1))) / theNumberCPUs;
	
	return theCPUWidth;
}

-(void)	drawRect:	(NSRect)inRect
{
	//	get the bounds rect
	NSRect theBounds = [self bounds];
	
	//	get the number of CPUs
	UInt32 theNumberCPUs = HLCPUInfo::GetNumberCPUs();
	
	//	fill the exposed rect
	[[NSColor whiteColor] set];
	//NSRectFill(inRect);
	
	//	calculate the width of each CPU rect
	Float32 theCPUWidth = [self CalculateCPUWidth];
	
	//	do the drawing for each CPU
	for(UInt32 theCPUIndex = 0; theCPUIndex < theNumberCPUs; ++theCPUIndex)
	{
		//	calculate the bounds for this CPU
		NSRect theCPUBounds = theBounds;
		theCPUBounds.origin.x += (theCPUWidth * theCPUIndex) + (kCPULoadHistoryViewCPUSpacing * theCPUIndex);
		theCPUBounds.size.width = theCPUWidth;
		
		//	draw the load for this CPU if necessary
		if(NSIntersectsRect(inRect, theCPUBounds))
		{
			//	frame the bounds
			[[NSColor blackColor] set];
			NSFrameRectWithWidth(theCPUBounds, 1.0);
			
			//	inset the bounds
			theCPUBounds.origin.x += 1.0;
			theCPUBounds.origin.y += 1.0;
			theCPUBounds.size.width -= 2.0;
			theCPUBounds.size.height -= 2.0;
			
			//	draw the CPU load
			[self DrawCPU: theCPUIndex InRect: theCPUBounds];
		}
	}
}

#define	kCPULoadHistoryViewLineWidth	1.0

-(void)	DrawCPU:	(UInt32)inCPUIndex
		InRect:		(NSRect)inCPUBounds
{
	//	empty out the paths
	[mTotalLoadPath removeAllPoints];
	[mUserLoadPath removeAllPoints];
	[mSystemLoadPath removeAllPoints];
	[mNiceLoadPath removeAllPoints];
	
	//	set the path properties
	[mTotalLoadPath setLineWidth: kCPULoadHistoryViewLineWidth];
	[mUserLoadPath setLineWidth: kCPULoadHistoryViewLineWidth];
	[mSystemLoadPath setLineWidth: kCPULoadHistoryViewLineWidth];
	[mNiceLoadPath setLineWidth: kCPULoadHistoryViewLineWidth];
	
	//	get the number of points
	UInt32 theNumberBars = [mDataSource GetCPULoadHistoryLength];
	
	//	calculate how far apart they are
	Float32 theBarWidth = inCPUBounds.size.width / theNumberBars;
	
	//	calculate the maximum bar height for convenience
	Float32 theBarHeight = inCPUBounds.size.height;
	
	//	move the paths to the starting points
	NSPoint thePoint;
	Float64 theTotalLoad = 0;
	Float64 theNiceLoad = 0;
	Float64 theSystemLoad = 0;
	Float64 theUserLoad = 0;
	
	if(mDrawTotalLoad)
	{
		thePoint = inCPUBounds.origin;
		theTotalLoad = 1.0 - [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_IDLE ForItemIndex: 0];
		thePoint.y += theTotalLoad * theBarHeight;
		[mTotalLoadPath moveToPoint: inCPUBounds.origin];
		[mTotalLoadPath lineToPoint: thePoint];
	}
	
	if(mDrawNiceLoad)
	{
		thePoint = inCPUBounds.origin;
		theNiceLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_NICE ForItemIndex: 0];
		thePoint.y += theNiceLoad * theBarHeight;
		[mNiceLoadPath moveToPoint: inCPUBounds.origin];
		[mNiceLoadPath lineToPoint: thePoint];
	}
	
	if(mDrawSystemLoad)
	{
		thePoint = inCPUBounds.origin;
		theSystemLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_SYSTEM ForItemIndex: 0];
		thePoint.y += (theSystemLoad + theNiceLoad) * theBarHeight;
		[mSystemLoadPath moveToPoint: inCPUBounds.origin];
		[mSystemLoadPath lineToPoint: thePoint];
	}
	
	if(mDrawUserLoad)
	{
		thePoint = inCPUBounds.origin;
		theUserLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_USER ForItemIndex: 0];
		thePoint.y += (theUserLoad + theSystemLoad + theNiceLoad) * theBarHeight;
		[mUserLoadPath moveToPoint: inCPUBounds.origin];
		[mUserLoadPath lineToPoint: thePoint];
	}
	
	//	add a point for each history item
	for(UInt32 theBarIndex = 0; theBarIndex < theNumberBars; ++theBarIndex)
	{
		Float32 theXOffset = theBarIndex * theBarWidth;
		theXOffset += theBarWidth / 2.0;
		thePoint.x = inCPUBounds.origin.x + theXOffset;
		
		if(mDrawTotalLoad)
		{
			theTotalLoad = 1.0 - [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_IDLE ForItemIndex: theBarIndex];
			thePoint.y = inCPUBounds.origin.y + (theTotalLoad * theBarHeight);
			[mTotalLoadPath lineToPoint: thePoint];
		}
		
		if(mDrawNiceLoad)
		{
			theNiceLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_NICE ForItemIndex: theBarIndex];
			thePoint.y = inCPUBounds.origin.y + (theNiceLoad * theBarHeight);
			[mNiceLoadPath lineToPoint: thePoint];
		}
		
		if(mDrawSystemLoad)
		{
			theSystemLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_SYSTEM ForItemIndex: theBarIndex];
			thePoint.y = inCPUBounds.origin.y + ((theSystemLoad + theNiceLoad) * theBarHeight);
			[mSystemLoadPath lineToPoint: thePoint];
		}
		
		if(mDrawUserLoad)
		{
			theUserLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_USER ForItemIndex: theBarIndex];
			thePoint.y = inCPUBounds.origin.y + ((theUserLoad + theSystemLoad + theNiceLoad) * theBarHeight);
			[mUserLoadPath lineToPoint: thePoint];
		}
	}
	
	//	finish off the lines
	if(mDrawTotalLoad)
	{
		theTotalLoad = 1.0 - [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_IDLE ForItemIndex: (theNumberBars - 1)];
		thePoint.x = inCPUBounds.origin.x + inCPUBounds.size.width;
		thePoint.y = inCPUBounds.origin.y + (theTotalLoad * theBarHeight);
		[mTotalLoadPath lineToPoint: thePoint];
		thePoint.y = inCPUBounds.origin.y;
		[mTotalLoadPath lineToPoint: thePoint];
		[mTotalLoadPath closePath];
	}
		
	if(mDrawNiceLoad)
	{
		theNiceLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_NICE ForItemIndex: (theNumberBars - 1)];
		thePoint.x = inCPUBounds.origin.x + inCPUBounds.size.width;
		thePoint.y = inCPUBounds.origin.y + (theNiceLoad * theBarHeight);
		[mNiceLoadPath lineToPoint: thePoint];
		thePoint.y = inCPUBounds.origin.y;
		[mNiceLoadPath lineToPoint: thePoint];
		[mNiceLoadPath closePath];
	}
		
	if(mDrawSystemLoad)
	{
		theSystemLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_SYSTEM ForItemIndex: (theNumberBars - 1)];
		thePoint.x = inCPUBounds.origin.x + inCPUBounds.size.width;
		thePoint.y = inCPUBounds.origin.y + ((theSystemLoad + theNiceLoad) * theBarHeight);
		[mSystemLoadPath lineToPoint: thePoint];
		thePoint.y = inCPUBounds.origin.y;
		[mSystemLoadPath lineToPoint: thePoint];
		[mSystemLoadPath closePath];
	}
		
	if(mDrawUserLoad)
	{
		theUserLoad = [mDataSource GetCPULoad: inCPUIndex ForCPUState: CPU_STATE_USER ForItemIndex: (theNumberBars - 1)];
		thePoint.x = inCPUBounds.origin.x + inCPUBounds.size.width;
		thePoint.y = inCPUBounds.origin.y + ((theUserLoad + theSystemLoad + theNiceLoad) * theBarHeight);
		[mUserLoadPath lineToPoint: thePoint];
		thePoint.y = inCPUBounds.origin.y;
		[mUserLoadPath lineToPoint: thePoint];
		[mUserLoadPath closePath];
	}
		
	//	stroke the lines
	if(mDrawTotalLoad)
	{
		[mTotalLoadColor set];
		[mTotalLoadPath fill];
	}
	
	if(mDrawUserLoad)
	{
		[mUserLoadColor set];
		[mUserLoadPath fill];
	}
	
	if(mDrawSystemLoad)
	{
		[mSystemLoadColor set];
		[mSystemLoadPath fill];
	}
	
	if(mDrawNiceLoad)
	{
		[mNiceLoadColor set];
		[mNiceLoadPath fill];
	}
}

@end

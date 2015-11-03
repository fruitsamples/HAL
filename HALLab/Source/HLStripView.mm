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
	HLStripView.mm

=============================================================================*/

//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#import "HLStripView.h"

//=============================================================================
//	HLStripView
//=============================================================================

@implementation HLStripView

-(id)	initWithFrame:	(NSRect)inFrame
{
	mIsHorizontal = true;
	mNumberStrips = 1;
	return [super initWithFrame: inFrame];
}

-(void)	awakeFromNib
{
	//	get the frame
	NSRect theFrame = [self frame];
	
	//	figure out if strips are horizontally oriented
	mIsHorizontal = theFrame.size.width > theFrame.size.height;
}

-(void)	dealloc
{
	[super dealloc];
}

-(BOOL)	isFlipped
{
	return YES;
}

-(UInt32)	GetNumberStrips
{
	return mNumberStrips;
}

-(void)		SetNumberStrips:	(UInt32)inNumberStrips
{
	if(inNumberStrips != mNumberStrips)
	{
		[self setNeedsDisplay: YES];
		
		//	iterate through the subviews, and set them to be the proper size
		NSArray* theSubviews = [self subviews];
		UInt32 theNumberSubviews = [theSubviews count];
		Float32 theNewSize = 0;
		for(UInt32 theSubviewIndex = 0; theSubviewIndex < theNumberSubviews; ++theSubviewIndex)
		{
			//	get the subview (which is assumed to be an NSMatrix)
			NSMatrix* theMatrix = [theSubviews objectAtIndex: theSubviewIndex];
			
			//	tell it how many cells to have
			if(inNumberStrips > mNumberStrips)
			{
				if(mIsHorizontal)
				{
					UInt32 theNumberRowsToAdd = inNumberStrips - mNumberStrips;
					while(theNumberRowsToAdd > 0)
					{
						[theMatrix addRow];
						--theNumberRowsToAdd;
					}
				}
				else
				{
					UInt32 theNumberColumnsToAdd = inNumberStrips - mNumberStrips;
					while(theNumberColumnsToAdd > 0)
					{
						[theMatrix addColumn];
						--theNumberColumnsToAdd;
					}
				}
			}
			else
			{
				if(mIsHorizontal)
				{
					UInt32 theNumberRowsToRemove = mNumberStrips - inNumberStrips;
					while(theNumberRowsToRemove > 0)
					{
						UInt32 theNumberRows = [theMatrix numberOfRows];
						[theMatrix removeRow: theNumberRows - 1];
						--theNumberRowsToRemove;
					}
				}
				else
				{
					UInt32 theNumberColumnsToRemove = mNumberStrips - inNumberStrips;
					while(theNumberColumnsToRemove > 0)
					{
						UInt32 theNumberColumns = [theMatrix numberOfColumns];
						[theMatrix removeColumn: theNumberColumns - 1];
						--theNumberColumnsToRemove;
					}
				}
			}
			
			//	make it the right size
			[theMatrix sizeToCells];
		
			//	mark it for redraw
			[theMatrix setNeedsDisplay: YES];
			
			//	get it's frame
			NSRect theMatrixFrame = [theMatrix frame];
			
			//	keep track of the biggest the view is going to need to be
			if(mIsHorizontal)
			{
				theNewSize = std::max(theNewSize, theMatrixFrame.size.height);
			}
			else
			{
				theNewSize = std::max(theNewSize, theMatrixFrame.size.width);
			}
		}
		
		//	resize the view to hold the matrices
		NSRect theFrame = [self frame];
		if(mIsHorizontal)
		{
			theFrame.size.height = theNewSize;
		}
		else
		{
			theFrame.size.width = theNewSize;
		}
		[self setFrameSize: theFrame.size];
		
		[self setNeedsDisplay: YES];
		mNumberStrips = inNumberStrips;
	}
}

-(UInt32)	GetSelectedStripIndex:	(UInt32)inControl
{
	UInt32 theAnswer = 0;
	
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the selected cell
		NSCell* theCell = [theMatrix selectedCell];
		
		//	get the row and column that the cell is in
		int theRow = 0;
		int theColumn = 0;
		[theMatrix getRow: &theRow column: &theColumn ofCell: theCell];
		
		//	set the return value
		if(mIsHorizontal)
		{
			theAnswer = theRow;
		}
		else
		{
			theAnswer = theColumn;
		}
	}
	
	return theAnswer;
}

-(void)		SetEnabled:				(UInt32)inControl
			ForChannel:				(UInt32)inChannel
			Value:					(BOOL)inIsEnabled
{
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	get the return value
			[theCell setEnabled: inIsEnabled];
		}
	}
}

-(bool)		GetBoolValue:	(UInt32)inControl
			ForChannel:		(UInt32)inChannel
{
	bool theAnswer = false;
	
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	get the return value
			theAnswer = [theCell intValue] != 0;
		}
	}
	
	return theAnswer;
}

-(void)		SetBoolValue:		(bool)inValue
			ForControl:			(UInt32)inControl
			ForChannel:			(UInt32)inChannel
{
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	set the value
			[theCell setIntValue: (inValue ? 1 : 0)];
		}
	}
}

-(int)	GetIntValue:		(UInt32)inControl
		ForChannel:			(UInt32)inChannel
{
	int theAnswer = 0;
	
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	get the return value
			theAnswer = [theCell intValue];
		}
	}
	
	return theAnswer;
}

-(void)		SetIntValue:		(int)inValue
			ForControl:			(UInt32)inControl
			ForChannel:			(UInt32)inChannel
{
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	set the value
			[theCell setIntValue: inValue];
		}
	}
}

-(Float32)	GetFloatValue:		(UInt32)inControl
			ForChannel:			(UInt32)inChannel
{
	Float32 theAnswer = false;
	
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	get the return value
			theAnswer = [theCell floatValue];
		}
	}
	
	return theAnswer;
}

-(void)		SetFloatValue:		(Float32)inValue
			ForControl:			(UInt32)inControl
			ForChannel:			(UInt32)inChannel
{
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	set the value
			[theCell setFloatValue: inValue];
		}
	}
}

-(NSString*)	GetStringValue:		(UInt32)inControl
				ForChannel:			(UInt32)inChannel
{
	NSString* theAnswer = NULL;
	
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	get the return value
			theAnswer = [theCell stringValue];
		}
	}
	
	return theAnswer;
}

-(void)		SetStringValue:		(NSString*)inValue
			ForControl:			(UInt32)inControl
			ForChannel:			(UInt32)inChannel
{
	//	figure out which matrix we're talking about
	NSMatrix* theMatrix = [self viewWithTag: inControl];
	if(theMatrix != NULL)
	{
		//	get the indicated cell
		NSCell* theCell = NULL;
		if(mIsHorizontal)
		{
			theCell = [theMatrix cellAtRow: inChannel column: 0];
		}
		else
		{
			theCell = [theMatrix cellAtRow: 0 column: inChannel];
		}
		
		if(theCell != NULL)
		{
			//	set the value
			[theCell setStringValue: inValue];
		}
	}
}

@end

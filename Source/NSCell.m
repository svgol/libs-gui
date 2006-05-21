/** <title>NSCell</title>

   <abstract>The abstract cell class</abstract>

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996
   Modifications:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: August 1998
   Rewrite:  Multiple authors
   Date: 1999
   Editing, formatters: Nicola Pero <nicola@brainstorm.co.uk>
   Date: 2000

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#include "config.h"
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSException.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSFormatter.h>
#include <Foundation/NSRunLoop.h>
#include <GNUstepBase/GSCategories.h>

#include "AppKit/AppKitExceptions.h"
#include "AppKit/NSAttributedString.h"
#include "AppKit/NSApplication.h"
#include "AppKit/NSControl.h"
#include "AppKit/NSCell.h"
#include "AppKit/NSClipView.h"
#include "AppKit/NSColor.h"
#include "AppKit/NSCursor.h"
#include "AppKit/NSEvent.h"
#include "AppKit/NSFont.h"
#include "AppKit/NSGraphics.h"
#include "AppKit/NSImage.h"
#include "AppKit/NSMenu.h"
#include "AppKit/NSParagraphStyle.h"
#include "AppKit/NSTextView.h"
#include "AppKit/NSTextContainer.h"
#include "AppKit/NSView.h"
#include "AppKit/NSWindow.h"
#include "GNUstepGUI/GSDrawFunctions.h"

static Class	colorClass;
static Class	cellClass;
static Class	fontClass;
static Class	imageClass;

static NSColor	*txtCol;
static NSColor	*dtxtCol;
static NSColor	*shadowCol;

@interface	NSCell (PrivateColor)
+ (void) _systemColorsChanged: (NSNotification*)n;
@end


@implementation	NSCell (PrivateColor)
+ (void) _systemColorsChanged: (NSNotification*)n
{
  ASSIGN (txtCol, [colorClass controlTextColor]);
  ASSIGN (dtxtCol, [colorClass disabledControlTextColor]);
  ASSIGN (shadowCol, [colorClass controlDarkShadowColor]);
}
@end


/**
 *<p> TODO Desctiption</p>
 */

@implementation NSCell

/*
 * Class methods
 */
+ (void) initialize
{
  if (self == [NSCell class])
    {
      [self setVersion: 1];
      colorClass = [NSColor class];
      cellClass = [NSCell class];
      fontClass = [NSFont class];
      imageClass = [NSImage class];
      /*
       * Watch for changes to system colors, and simulate an initial change
       * in order to set up our defaults.
       */
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	   selector: @selector(_systemColorsChanged:)
	       name: NSSystemColorsDidChangeNotification
	     object: nil];
      [self _systemColorsChanged: nil];
    }
}

+ (NSMenu*)defaultMenu
{
  return nil;
}

/**<p>This class method returns NO. This method should be overrided by 
   subclasses.</p>
 */
+ (BOOL) prefersTrackingUntilMouseUp
{
  return NO;
}

/*
 * Instance methods
 */
- (id) init
{
  return [self initTextCell: @""];
}

/**<p>Initializes and returns a new NSCell with a NSImage <var>anImage</var>. 
   This method sets the image position to <ref type="type" 
   id="NSCellImagePosition">NSImageOnly</ref> and the cell's type to
   <ref type="type" id="NSCellType">NSImageCellType</ref>.</p>
   <p>See Also: -initTextCell: </p>
 */
- (id) initImageCell: (NSImage*)anImage
{
  _cell.type = NSImageCellType;
  _cell_image = RETAIN (anImage);
  _cell.image_position = NSImageOnly;
  _font = RETAIN ([fontClass systemFontOfSize: 0]);

  // Implicitly set by allocation:
  //
  //_font = nil;
  //_cell.contents_is_attributed_string = NO;
  //_cell.is_highlighted = NO;
  //_cell.is_disabled = NO;
  //_cell.is_editable = NO;
  //_cell.is_rich_text = NO;
  //_cell.imports_graphics = NO;
  //_cell.shows_first_responder = NO;
  //_cell.refuses_first_responder = NO;
  //_cell.sends_action_on_end_editing = NO;
  //_cell.is_bordered = NO;
  //_cell.is_bezeled = NO;
  //_cell.is_scrollable = NO;
  //_cell.is_selectable = NO;
  //_cell.state = 0;
  _action_mask = NSLeftMouseUpMask;
  _menu = [isa defaultMenu];

  return self;
}
/**<p>Initializes and returns a new NSCell with a NSString aString. 
   This method sets the cell's type to <ref type="type" id="NSCellType">
   NSTextCellType</ref>.</p>
   <p>See Also: -initImageCell: </p>
 */
- (id) initTextCell: (NSString*)aString
{
  _cell.type = NSTextCellType;
  _contents = RETAIN (aString);
  _font = RETAIN ([fontClass systemFontOfSize: 0]);

  // Implicitly set by allocation:
  //
  //_cell.contents_is_attributed_string = NO;
  //_cell_image = nil;
  //_cell.image_position = NSNoImage;
  //_cell.is_disabled = NO;
  //_cell.state = 0;
  //_cell.is_highlighted = NO;
  //_cell.is_editable = NO;
  //_cell.is_bordered = NO;
  //_cell.is_bezeled = NO;
  //_cell.is_scrollable = NO;
  //_cell.is_selectable = NO;
  _action_mask = NSLeftMouseUpMask;
  _menu = [isa defaultMenu];

  return self;
}

- (void) dealloc
{
  TEST_RELEASE (_contents);
  TEST_RELEASE (_cell_image);
  TEST_RELEASE (_font);
  TEST_RELEASE (_represented_object);
  TEST_RELEASE (_objectValue);
  TEST_RELEASE (_formatter);
  TEST_RELEASE (_menu);

  [super dealloc];
}

/*
 * Setting the NSCell's Value
 */
- (id) objectValue
{
  if (_cell.has_valid_object_value)
    {
      return _objectValue;
    }
  else
    {
      return nil;
    }
}

- (BOOL) hasValidObjectValue
{
  return _cell.has_valid_object_value;
}

/**<p>Returns the NSCell's value as a double. </p>
 *<p>See Also: -setDoubleValue: </p>
 */
- (double) doubleValue
{
  if ((_cell.has_valid_object_value == YES) &&
      ([_objectValue respondsToSelector: @selector(doubleValue)]))
    {
      return [_objectValue doubleValue];
    }
  else
    {
      return [[self stringValue] doubleValue];
    }
}

/**<p>Returns the cell's value as a float. </p>
 *<p>See Also: -setFloatValue: </p>
 */
- (float) floatValue
{
  if ((_cell.has_valid_object_value == YES) &&
      ([_objectValue respondsToSelector: @selector(floatValue)]))
    {
      return [_objectValue floatValue];
    }
  else
    {
      return [[self stringValue] floatValue];
    }
}

/**<p>Returns the cell's value as an int. </p>
 *<p>See Also: -setIntValue:</p>
 */
- (int) intValue
{
  if ((_cell.has_valid_object_value == YES) &&
      ([_objectValue respondsToSelector: @selector(intValue)]))
    {
      return [_objectValue intValue];
    }
  else
    {
      return [[self stringValue] intValue];
    }
}

/**<p>Returns the cell's value as a NSString.</p>
 *<p>See Also: -setStringValue: </p>
 */
- (NSString*) stringValue
{
  if (_cell.contents_is_attributed_string == NO)
    {
      // If we have a formatter this is also the string of the _objectValue
      return _contents;
    }
  else
    {
      return [(NSAttributedString *)_contents string];
    }
}

- (void) setObjectValue: (id)object 
{
  id newContents;
  
  ASSIGN (_objectValue, object);
  
  if (_formatter == nil) 
    {
      if ([object isKindOfClass: [NSString class]] == YES)
	{
	  newContents = object;
	  _cell.contents_is_attributed_string = NO;
	  _cell.has_valid_object_value = YES;
	}
      if ([object isKindOfClass: [NSAttributedString class]] == YES)
        {
          newContents = object;
          _cell.contents_is_attributed_string = YES;
	  _cell.has_valid_object_value = YES;
        }
      else
	{
	  newContents = [_objectValue description];
	  _cell.contents_is_attributed_string = NO;
	  _cell.has_valid_object_value = YES;
	}
  }
  else
    {
      newContents = [_formatter stringForObjectValue: _objectValue];
      _cell.contents_is_attributed_string = NO;
      if (newContents != nil)
        {
	  _cell.has_valid_object_value = YES;
	}
      else
        {
	  _cell.has_valid_object_value = NO;
	}
    }

  ASSIGN (_contents, newContents);
}


/**<p>Sets the NSCell's value to aDouble.</p>
 *<p>See Also: -doubleValue</p> 
 */
- (void) setDoubleValue: (double)aDouble
{
  NSNumber *number;

  // NB: GNUstep can set a double value for an image cell

  number = [NSNumber numberWithDouble: aDouble];
  [self setObjectValue: number];
}

/**
 *<p>Sets the NSCell's value to a aFloat. This used for example in 
 NSSliderCell</p>
 *<p>See Also: -floatValue</p> 
 */
- (void) setFloatValue: (float)aFloat
{
  NSNumber *number;

  // NB: GNUstep can set a float value for an image cell. 
  // NSSliderCell is an example of it! 

  number = [NSNumber numberWithFloat: aFloat];
  [self setObjectValue: number];
}


/**
 *<p>Sets the NSCell's value to anInt.</p>
 *<p>See Also: -intValue</p> 
 */
- (void) setIntValue: (int)anInt
{
  NSNumber *number;

  // NB: GNUstep can set an int value for an image cell. 

  number = [NSNumber numberWithInt: anInt];
  [self setObjectValue: number];
}

/**<p>Sets the cell's value to a NSString. 
   The NSCell's type is set to NSTextCellType if needed</p>
   <p>See Also: -stringValue</p> 
 */
- (void) setStringValue: (NSString*)aString
{
  NSString *string = aString;

  /* We warn about nil for compatibiliy with MacOS X, which refuses
     nil.  */
  if (string == nil)
    {
      NSDebugMLLog (@"MacOSXCompatibility", 
		    @"Attempt to use nil as string value");
    }

  if (_cell.type != NSTextCellType)
    {
      [self setType: NSTextCellType];
    }
  _cell.contents_is_attributed_string = NO;

  if (_formatter == nil)
    {
      ASSIGN (_contents, string);
      ASSIGN (_objectValue, string);
      _cell.has_valid_object_value = YES;
    }
  else
    {
      id newObjectValue;
      
      if ([_formatter getObjectValue: &newObjectValue 
		      forString: string 
		      errorDescription: NULL])
	{
	  [self setObjectValue: newObjectValue];
	}
      else
	{
	  _cell.has_valid_object_value = NO;
	  ASSIGN (_contents, string);
	}
    }
}

/**<p>Returns some NSCell's attributes for the specified <ref type="type"
   id="NSCellAttribute">NSCellAttribute</ref></p>
   <p>See Also: -setCellAttribute:to:</p>
 */
- (int) cellAttribute: (NSCellAttribute)aParameter
{
  switch (aParameter)
    {
    case NSCellDisabled: return _cell.is_disabled;
    case NSCellState: return _cell.state;
    case NSCellEditable: return _cell.is_editable;
    case NSCellHighlighted: return _cell.is_highlighted;
    case NSCellIsBordered: return _cell.is_bordered;
    case NSCellAllowsMixedState: return _cell.allows_mixed_state; 

      /*
	case NSPushInCell: return 0; 
	case NSChangeGrayCell: return 0; 
	case NSCellLightsByContents: return 0; 
	case NSCellLightsByGray: return 0; 
	case NSChangeBackgroundCell: return 0; 
	case NSCellLightsByBackground: return 0; 
	case NSCellChangesContents: return 0;  
	case NSCellIsInsetButton: return 0;  
      */
    case NSCellHasOverlappingImage: 
      {
	return _cell.image_position == NSImageOverlaps;
      }
    case NSCellHasImageHorizontal: 
      {
	return (_cell.image_position == NSImageRight) 
	  || (_cell.image_position == NSImageLeft);
      }
    case NSCellHasImageOnLeftOrBottom: 
      {
	return (_cell.image_position == NSImageBelow) 
	  || (_cell.image_position == NSImageLeft);
      }
    default:
      {
	NSWarnLog (@"cell attribute %d not supported", aParameter);
	break;
      }
    }
  
  return 0;
}


/**<p>TODO</p>
 *<p>See Also: -cellAttribute:</p>
 */
- (void) setCellAttribute: (NSCellAttribute)aParameter  to: (int)value
{
  switch (aParameter)
    {
    case NSCellDisabled:
      {
	_cell.is_disabled = value;
	break;
      }
    case NSCellState:
      {
	_cell.state = value;
	break;
      }
    case NSCellEditable:
      {
	_cell.is_editable = value;
	break;
      }
    case NSCellHighlighted:
      {
	_cell.is_highlighted = value;
	break;
      }
    case NSCellHasOverlappingImage:
      {
	if (value)
	  {
	    _cell.image_position = NSImageOverlaps;
	  }
	else
	  {
	    if (_cell.image_position == NSImageOverlaps)
	      {
		_cell.image_position = NSImageLeft;
	      }
	  }
	break;
      }
    case NSCellHasImageHorizontal:
      {
	if (value)
	  {
	    if (_cell.image_position != NSImageLeft
		&& _cell.image_position != NSImageRight)
	      {
		_cell.image_position = NSImageLeft;
	      }
	  }
	else
	  {
	    if (_cell.image_position == NSImageLeft)
	      {
		_cell.image_position = NSImageAbove;
	      }
	    else if (_cell.image_position == NSImageRight)
	      {
		_cell.image_position = NSImageBelow;
	      }
	  }
	break;
      }
    case NSCellHasImageOnLeftOrBottom:
      {
	if (value)
	  {
	    if (_cell.image_position == NSImageAbove)
	      {
		_cell.image_position = NSImageBelow;
	      }
	    else
	      {
		_cell.image_position = NSImageLeft;
	      }
	  }
	else
	  {
	    if (_cell.image_position == NSImageBelow)
	      {
		_cell.image_position = NSImageAbove;
	      }
	    else
	      {
		_cell.image_position = NSImageRight;
	      }
	  }
	break;
      }
      /*
    case NSCellChangesContents:
      _cell. = value;
      break;
    case NSCellIsInsetButton:
      _cell. = value;
      break;
*/
    case NSCellIsBordered:
      {
	_cell.is_bordered = value;
	break;
      }
    case NSCellAllowsMixedState:
      {
	_cell.allows_mixed_state = value;
	break;
      }
    default:
      {
	NSWarnLog (@"cell attribute %d not supported", aParameter);
	break;
      }
    }
}

/**<p>Sets the NSCell's type. See <ref type="type" id="NSCellType">NSCellType
   </ref>.If the cell is set to NSTextCellType, the cell is given
   a default title and is reset to the default system font.</p>
   <p>See Also: -type</p>
*/
- (void) setType: (NSCellType)aType
{
  if (_cell.type == aType)
    {
      return;
    }
  
  _cell.type = aType;
  switch (_cell.type)
    {
      case NSTextCellType:
	{
	  ASSIGN (_contents, @"title");
	  _cell.contents_is_attributed_string = NO;
	  /* Doc says we have to reset the font too. */
	  ASSIGN (_font, [fontClass systemFontOfSize: 0]);
	  break;
	}
      case NSImageCellType:
	{
	  TEST_RELEASE (_cell_image);
	  _cell_image = nil;
	  break;
	}
    }
}

/**<p>Returns the cell's type. Returns NSNullCellType if the
  cell's type flag is set to NSImageCellType and if the cell's image 
  is nil. See <ref type="type" id="NSCellType">NSCellType</ref> for more 
  information.</p><p>See Also -setType:</p>
 */
- (NSCellType) type
{
  if (_cell.type == NSImageCellType && _cell_image == nil)
    return NSNullCellType;
    
  return _cell.type;
}


/**<p>Returns whether the NSCell can respond to mouse events.</p>
 *<p>See Also: -setEnabled:</p>
 */
- (BOOL) isEnabled
{
  return !_cell.is_disabled;
}

/**<p>Sets whether the NSCell can respond to mouse events</p>
 <p>See Also: -isEnabled</p>
 */
- (void) setEnabled: (BOOL)flag
{
  _cell.is_disabled = !flag;  
}

/**<p>Returns whether the NSCell has a bezeled border. By default a NSCell
   has no bezeled border</p><p>See Also: -setBezeled:</p>
 */
- (BOOL) isBezeled
{
  return _cell.is_bezeled;
}

/**<p>Returns whether the NSCell has a border. By default a NSCell has 
   border</p><p>See Also: -setBordered: -setBezeled: -isBezeled</p>
 */
- (BOOL) isBordered
{
  return _cell.is_bordered;
}

/**<p>Returns whether the cell is opaque. Return NO by default</p>
 */
- (BOOL) isOpaque
{
  return NO;
}

/**<p>Sets whether the cell has a bezeled border. 
 If the cell has a bezeled border, the bordered  flag is turn off.
 By default a NSCell has no bezeled border</p>
 <p>See Also: -isBezeled -setBordered: -isBordered</p>
 */
- (void) setBezeled: (BOOL)flag
{
  _cell.is_bezeled = flag;
  if (_cell.is_bezeled)
    {
      _cell.is_bordered = NO;
    }
}

/**<p>Sets whether the cell has a border.  If the cell has a border, 
 the bezeled flag is turn off. By default a NSCell has no border</p>
 <p>See Also: -isBordered -setBezeled: -isBezeled</p>
 */
- (void) setBordered: (BOOL)flag
{
  _cell.is_bordered = flag;
  if (_cell.is_bordered)
    {
      _cell.is_bezeled = NO;
    }
}

/**<p>Sets the NSCell's state.  Please use always symbolic constants when
   calling this method. The integer values could be changed in the this
   implementation. (Currently they match the Cocoa values but they are
   quite strange)</p> <p>See Also: -state</p>
 */
- (void) setState: (int)value
{
  /* We do exactly as in macosx when value is not NSOnState,
   * NSOffState, NSMixedState, even if their behaviour (value < 0 ==>
   * NSMixedState) is a bit strange.  We could decide to do
   * differently in the future, so please use always symbolic
   * constants when calling this method, this way your code won't be
   * broken by changes. */
  if (value > 0 || (value < 0 && _cell.allows_mixed_state == NO))
    {
      _cell.state = NSOnState;
    }
  else if (value == 0)
    {
      _cell.state = NSOffState;
    }
  else 
    {
      _cell.state = NSMixedState;
    }
}

/**<p>Returns the NSCell's state</p>
 <p>See Also: -setState: </p>
*/
- (int) state
{
  return _cell.state;
}

- (BOOL) allowsMixedState
{
  return _cell.allows_mixed_state;
}

- (void) setAllowsMixedState: (BOOL)flag
{
  _cell.allows_mixed_state = flag;
  if (!flag && _cell.state == NSMixedState)
    {
      [self setNextState];
    }
}

- (int) nextState
{
  switch (_cell.state)
    {
      case NSOnState:
	{
	  return NSOffState;
	}
      case NSOffState:
	{
	  if (_cell.allows_mixed_state)
	    {
	      return NSMixedState;
	    }
	  else
	    {
	      return NSOnState;
	    }
	}
      case NSMixedState:
      default:
	{
	  return NSOnState;
	}
    }
}

- (void) setNextState
{
  [self setState: [self nextState]];
}

/**<p>Returns the alignment of the text used in the NSCell. See 
   <ref type="type" id="NSTextAlignment">NSTextAlignment</ref> for more
   informations. By default the text alignment is <ref type="type" 
   id="NSTextAlignment">NSJustifiedTextAlignment</ref></p>
   <p>See Also: -setAlignment:</p>
 */
- (NSTextAlignment) alignment
{
  return _cell.text_align;
}

/** <p>Returns the font of the text used in the NSCell</p>
    <p>See Also: -setFont:</p>
 */
- (NSFont*) font
{
  return _font;
}

/**<p>Returns whether the cell is editable.By default a NSCell is not editable.
   </p><p>See Also: -setEditable:</p>
 */
- (BOOL) isEditable
{
  return _cell.is_editable;
}

/**<p>Returns whether the cell is selectable. This method returns YES if 
   the cell is selectable or editable. NO otherwise</p>
   <p>See Also: -setSelectable: -isEditable -setEditable: </p>
 */
- (BOOL) isSelectable
{
  return _cell.is_selectable || _cell.is_editable;
}

/**<p>Returns whether the NSCell is scrollable. By default a NSCell is not
   scrollable</p><p>See Also: -setScrollable:</p>
 */
- (BOOL) isScrollable
{
  return _cell.is_scrollable;
}

/**<p>Sets the alignment of the text. See <ref type="type" 
   id="NSTextAlignment">NSTextAlignment</ref>.</p><p>See Also: -alignment </p>
 */
- (void) setAlignment: (NSTextAlignment)mode
{
  // This does not have any influence on attributed strings
  _cell.text_align = mode;
}

/**<p>Sets whether the NSCell's text is editable.</p>
   <p>See Also: -isEditable -setSelectable: -isSelectable</p>
*/
- (void) setEditable: (BOOL)flag
{
  /*
   * The cell_editable flag is also checked to see if the cell is
   * selectable so turning edit on also turns selectability on (until
   * edit is turned off again).  
   */
  _cell.is_editable = flag;
}

/**<p>Sets the text font. The NSCell's type is set to NSTextCellType if needed
   </p><p>See Also: -font -setType: -type</p>
 */
- (void) setFont: (NSFont*)fontObject
{
  if (_cell.type != NSTextCellType)
    {
      [self setType: NSTextCellType];
    }

  // This does not have any influence on attributed strings
  ASSIGN (_font, fontObject);
}

/**<p>Sets whether the cell selectable. Making a cell unselectable also
 * makes it uneditable until a -setEditable: re-enables it.</p>
 *<p>See Also: -isSelectable -setEditable: -isEditable</p>
 */
- (void) setSelectable: (BOOL)flag
{
  _cell.is_selectable = flag;

  if (!flag)
    _cell.is_editable = NO;
}

/**<p>Sets whether the NCell is scrollable. By default a NSCell is not
   scrollable</p><p>See Also: -isSelectable</p>
 */
- (void) setScrollable: (BOOL)flag
{
  _cell.is_scrollable = flag;
}

- (void) setWraps: (BOOL)flag
{
  _cell.wraps = flag;  

  if (flag)
    {
      _cell.is_scrollable = NO;
    }
}

- (BOOL) wraps
{
  return _cell.wraps;
}

- (void) setAttributedStringValue: (NSAttributedString*)attribStr
{
  /* Hmm.  FIXME.  Not sure what to do here. */
  if (_formatter != nil)
    {
      id newObjectValue;
      
      if ([_formatter getObjectValue: &newObjectValue 
		      forString: [attribStr string] 
		      errorDescription: NULL] == YES)
	{
	  [self setObjectValue: newObjectValue];
	  /* What about the attributed string ?  We are loosing it. */
	  return;
	}
    }

  /* In all other cases */
  ASSIGN (_contents, attribStr);
  _cell.has_valid_object_value = NO;
  _cell.contents_is_attributed_string = YES;
}

- (NSAttributedString*) attributedStringValue
{
  if (_formatter != nil)
    {
      NSDictionary *attributes;
      NSAttributedString *attrStr;

      attributes = [self _nonAutoreleasedTypingAttributes];
      attrStr = [_formatter attributedStringForObjectValue: _objectValue 
			    withDefaultAttributes: attributes];
      RELEASE(attributes);
      if (attrStr != nil)
	{
	  return attrStr;
	}
    }

  /* In all other cases */
  if (_cell.contents_is_attributed_string)
    {
      return (NSAttributedString *)_contents;
    }
  else
    {
      NSDictionary *dict;
      NSAttributedString *attrStr;

      dict = [self _nonAutoreleasedTypingAttributes];
      attrStr = [[NSAttributedString alloc] initWithString: _contents 
					    attributes: dict];
      RELEASE(dict);
      return AUTORELEASE(attrStr);
    }
}

- (void) setAllowsEditingTextAttributes: (BOOL)flag
{
  _cell.is_rich_text = flag;
  if (!flag)
    _cell.imports_graphics = NO;
}

- (BOOL) allowsEditingTextAttributes
{
  return _cell.is_rich_text;
}

- (void) setImportsGraphics: (BOOL)flag
{
  _cell.imports_graphics = flag;
  if (flag)
    _cell.is_rich_text = YES;
}

- (BOOL) importsGraphics
{
  return _cell.imports_graphics;
}

- (NSText*) setUpFieldEditorAttributes: (NSText*)textObject
{
  [textObject setString: @""];
  [textObject setTextColor: [self textColor]];
  if (_cell.contents_is_attributed_string == NO)
    {
      /* TODO: Manage scrollable attribute */
      [textObject setFont: _font];
      [textObject setAlignment: _cell.text_align];
    }
  else
    {
      /* FIXME/TODO.  What do we do if we are an attributed string.  
	 Think about what happens when the user ends editing. 
	 Allows editing text attributes... Formatter... TODO. */
    }
  [textObject setEditable: _cell.is_editable];
  [textObject setSelectable: _cell.is_selectable || _cell.is_editable];
  [textObject setRichText: _cell.is_rich_text];
  [textObject setImportsGraphics: _cell.imports_graphics];
  [textObject setSelectedRange: NSMakeRange(0, 0)];
  [textObject scrollRangeToVisible: NSMakeRange(0, 0)];

  return textObject;
}

- (NSString*) title
{
  return [self stringValue];
}

- (void) setTitle: (NSString*)aString
{
  [self setStringValue: aString];
}

/**<p>Implemented by subclasses to return the action method.
   The NSCell implementaiton returns NULL.</p>
 <p>See Also: -setAction: -setTarget: -target</p>
 */
- (SEL) action
{
  return NULL;
}

/** <p>Implemented by subclasses to set the action method. 
    The NSCell implementation raises a NSInternalInconsistencyException</p>
 <p>See Also: -action -setTarget: -target</p>
*/
- (void) setAction: (SEL)aSelector
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to set an action in an NSCell"];
}

/**<p>Implemented by subclasses to set the target object.
   The NSCell implementation raises a NSInternalInconsistencyException</p>
   <p>See Also: -target -setAction: -action</p>
 */
- (void) setTarget: (id)anObject
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to set a target in an NSCell"];
}

/**<p>Implemented by subclass to return the target object. 
   The NSCell implementation returns nil</p>
   <p>See Also: -setTarget: -setAction: -action</p>
 */
- (id) target
{
  return nil;
}

/**<p>Returns whether the cell can continuously send its action messages.</p>
   <p>See Also: -setContinuous:</p>
 */
- (BOOL) isContinuous
{
  // Some subclasses should redefine this with NSLeftMouseDraggedMask
  return (_action_mask & NSPeriodicMask) != 0;
}

/**<p>Sets whether the cell can continuously send its action messages.</p>
 *<p>See Also: -isContinuous</p>
 */
- (void) setContinuous: (BOOL)flag
{
  // Some subclasses should redefine this with NSLeftMouseDraggedMask
  if (flag)
    {
      _action_mask |= NSPeriodicMask;
    }
  else 
    {
      _action_mask &= ~NSPeriodicMask;
    }
}

/**<p>TODO Explain</p>
 */
- (int) sendActionOn: (int)mask
{
  unsigned int previousMask = _action_mask;

  _action_mask = mask;

  return previousMask;
}

/**<p>Returns the NSCell's image if the NSCell's type is <ref type="type" 
   id="NSCellType">NSImageCellType</ref>,
   returns nil otherwise.</p>
   <p>See Also: -setImage: -setType: -type</p>
 */
- (NSImage*) image
{
  if (_cell.type == NSImageCellType)
    {
      return _cell_image;
    }
  else
    return nil;
}

/**<p>Sets the NSCell's image to anImage. This method sets the cell's type 
   to NSImageCellType if needed. Raises an NSInvalidArgumentException if
   the anImage is not an NSImage (sub)class. The new image is retained and the
   old one is released</p><p>See Also: -image</p>
 */
- (void) setImage: (NSImage*)anImage
{
  if (anImage) 
    {
      NSAssert ([anImage isKindOfClass: imageClass],
		NSInvalidArgumentException);
    }
  
  if (_cell.type != NSImageCellType)
    {
      [self setType: NSImageCellType];
    }
  
  ASSIGN (_cell_image, anImage);
}

/**<p>Implemented by sublclasses to assigns the tag <var>anInt</var>.
    The NSCell implementation raises an NSInvalidArgumentException.</p>
    <p>See Also: -tag</p>
 */
- (void) setTag: (int)anInt
{
  [NSException raise: NSInternalInconsistencyException
	      format: @"attempt to set a tag in an NSCell"];
}

/**<p>Implemented by subclasses to Return the tag. 
   The NSCell implementation returns -1 </p><p>See Also: -setTag:</p>
 */
- (int) tag
{
  return -1;
}

/*
 * Formatting Data
 */
- (void) setFloatingPointFormat: (BOOL)autoRange
			   left: (unsigned int)leftDigits
			  right: (unsigned int)rightDigits
{
  // TODO: Pass this on to the formatter to handle
}

- (void) setFormatter: (NSFormatter*)newFormatter 
{
  ASSIGN (_formatter, newFormatter);
}

- (id) formatter
{
  return _formatter;
}

/**<p> TODO</p>
 */
- (int) entryType
{
  return _cell.entry_type;
}

/** <p>TODO</p>
 */
- (void) setEntryType: (int)aType
{
  [self setType: NSTextCellType];
  // TODO: This should select a suitable formatter
  _cell.entry_type = aType;
}

- (BOOL) isEntryAcceptable: (NSString*)aString
{
  if (_formatter != nil)
    {
      id newObjectValue;
      
      return [_formatter getObjectValue: &newObjectValue 
			 forString: aString 
			 errorDescription: NULL];
    }
  else 
    {
      return YES;
    }
}

/*
 * Menu
 */
- (void) setMenu: (NSMenu*)aMenu 
{
  ASSIGN (_menu, aMenu);
}

- (NSMenu*) menu
{
  return _menu;
}

- (NSMenu*) menuForEvent: (NSEvent*)anEvent 
		  inRect: (NSRect)cellFrame 
		  ofView: (NSView*)aView
{
  return [self menu];
}

/**
 * Compares the reciever to another to another NSCell.
 * The argument must be an NSCell sublclass and have
 * the NSCellType NSTextCellType.  Returns the result
 * of the comparison of each cell's stringValue.
 */
- (NSComparisonResult) compare: (id)otherCell
{
  if ([otherCell isKindOfClass: cellClass] == NO)
    {
      [NSException raise: NSBadComparisonException
		   format: @"NSCell comparison with non-NSCell"];
    }
  if (_cell.type != NSTextCellType
      || ((NSCell*)otherCell)->_cell.type != NSTextCellType)
    {
      [NSException raise: NSBadComparisonException
		   format: @"Comparison between non-text cells"];
    }
  /* We shouldn't access instance variables directly as subclasses
     may override stringValue to retrieve the value from somewhere else.  */
  return [[self stringValue] compare: [(NSCell*)otherCell stringValue]];
}

/*
 * respond to keyboard
 */
- (BOOL) acceptsFirstResponder
{
  return _cell.is_disabled == NO && _cell.refuses_first_responder == NO;
}

- (void) setShowsFirstResponder: (BOOL)flag 
{
  _cell.shows_first_responder = flag;
}

- (BOOL) showsFirstResponder
{
  return _cell.shows_first_responder;
}

- (void) setTitleWithMnemonic: (NSString*)aString
{
  unsigned int location = [aString rangeOfString: @"&"].location;

  [self setTitle: [aString stringByReplacingString: @"&"
				 withString: @""]];
  // TODO: We should underline this character
  [self setMnemonicLocation: location];
}

- (NSString*) mnemonic
{
  unsigned int location = [self mnemonicLocation];
  NSString *c = [self title];

  if ((location == NSNotFound) || location >= [c length])
    return @"";

  return [c substringWithRange: NSMakeRange (location, 1)];
}

- (void) setMnemonicLocation: (unsigned int)location 
{
  _mnemonic_location = location;
}

- (unsigned int) mnemonicLocation
{
  return _mnemonic_location;
}

/* Apple Compatibility method - do not use - please test whether the
   cell is enabled or disabled instead. */
- (BOOL) refusesFirstResponder
{
  return _cell.refuses_first_responder;
}

/* Apple Compatibility method - do not use - please disable the cell
   instead. */
- (void) setRefusesFirstResponder: (BOOL)flag
{
  _cell.refuses_first_responder = flag;
}

/**
 * Simulates a single click in the cell (only works with controls which have
 * no more than one cell). This method is deprecated,
 * performClickWithFrame:inView: is the right method to use now.
 */
- (void) performClick: (id)sender
{
  NSView *cv = [self controlView];

  if (cv != nil) 
    [self performClickWithFrame: [cv bounds] inView: cv];
}

/**
 * Simulates a single click in the cell.
 * The display of the cell with this event
 * occurs in the area delimited by <var>cellFrame</var> within
 * <var>controlView</var>.
 */
- (void) performClickWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
  SEL action = [self action];

  if (_cell.is_disabled == YES)
    {
      return;
    }

  if (controlView != nil)
    {  
      NSWindow *cvWin = [controlView window];

      [controlView lockFocus];
      
      [self setNextState];
      [self highlight: YES withFrame: cellFrame inView: controlView];
      [cvWin flushWindow];
      
      // Wait approx 1/10 seconds
      [[NSRunLoop currentRunLoop] 
	runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
      
      [self highlight: NO withFrame: cellFrame inView: controlView];
      [cvWin flushWindow];
      
      [controlView unlockFocus];

      if (action)
	{
	  NS_DURING
	    {
	      [(NSControl*)controlView sendAction: action to: [self target]];
	    }
	  NS_HANDLER
	    {
	      [localException raise];
	    }
	  NS_ENDHANDLER
	}
    }
  else  // We have no control view.  The best we can do is the following. 
    {
      if (action)
	{
	  [self setNextState];

	  NS_DURING
	    {
	      [[NSApplication sharedApplication] sendAction: action
						 to: [self target]
						 from: self];
	    }
	  NS_HANDLER
	    {
	      [localException raise];
	    }
	  NS_ENDHANDLER
	}
    }
}

/*
 * Deriving values from other objects (not necessarily cells)
 */
- (void) takeObjectValueFrom: (id)sender
{
  [self setObjectValue: [sender objectValue]];
}

/** <p>Sets the NSCell's double value to sender's double value</p>
    <p>See Also: -setDoubleValue:</p>
 */
- (void) takeDoubleValueFrom: (id)sender
{
  [self setDoubleValue: [sender doubleValue]];
}

/** <p>Sets the NSCell's float value to sender's float value</p>
    <p>See Also: -setFloatValue:</p>
 */
- (void) takeFloatValueFrom: (id)sender
{
  [self setFloatValue: [sender floatValue]];
}

/** <p>Sets the NSCell's int value to sender's int value</p>
    <p>See Also: -setIntValue:</p>
 */
- (void) takeIntValueFrom: (id)sender
{
  [self setIntValue: [sender intValue]];
}

/** <p>Sets the NSCell's NSString value to sender's NSSting value</p>
    <p>See Also: -setStringValue:</p>
 */
- (void) takeStringValueFrom: (id)sender
{
  [self setStringValue: [sender stringValue]];
}

/** <p>Returns the NSCell's represented object</p>
    <p>See Also: -setRepresentedObject:</p>
 */
- (id) representedObject
{
  return _represented_object;
}

/** <p>Sets the NSCell's represented object to <var>anObject</var>.
    anObject will be retain.</p><p>See Also: -representedObject</p>
 */
- (void) setRepresentedObject: (id)anObject
{
  /* Ahm - not nice - the RETAIN here could cause retain cycles - anyway. */
  ASSIGN (_represented_object, anObject);
}

/** <p>Returns YES. Subclasses should overrided this method if you want
    stop tracking the mouse. This method is call in the
    -trackMouse:inRect:ofView:untilMouseUp: main loop.</p>
    <p>See Also: -trackMouse:inRect:ofView:untilMouseUp:</p>
 */
- (BOOL) continueTracking: (NSPoint)lastPoint
		       at: (NSPoint)currentPoint
		   inView: (NSView*)controlView
{
  return YES;
}

/**<p>Returns the mouse flags. This flags are usally sets in 
   the -trackMouse:inRect:ofView:untilMouseUp: method</p>
 */
- (int) mouseDownFlags
{ 
  return _mouse_down_flags;
}

/**<p>Gets the NSCell's <var>delay</var> and the <var>interval</var>
   parameters used when NSCell sends continouly action messages.
   The NSCell implementation sets both <var>delay</var> and <var>interval</var>
   to 0.1.</p>
   <p>See Also: -trackMouse:inRect:ofView:untilMouseUp:</p>
 */
- (void) getPeriodicDelay: (float*)delay interval: (float*)interval
{
  *delay = 0.1;
  *interval = 0.1;
}

/**<p>Returns whether tracking starts. The NSCell implementation
   returns YES when the <var>startPoint</var> is into the control view
   retangle, NO otherwise. This method is call at the early stage of
   -trackMouse:inRect:ofView:untilMouseUp:</p><p>See Also:
   [NSView-mouse:inRect:] -trackMouse:inRect:ofView:untilMouseUp:
   </p>
 */
- (BOOL) startTrackingAt: (NSPoint)startPoint inView: (NSView*)controlView
{
  // If the point is in the view then yes start tracking
  if ([controlView mouse: startPoint inRect: [controlView bounds]])
    return YES;
  else
    return NO;
}

/**<p>TODO</p>
 */
- (void) stopTracking: (NSPoint)lastPoint
		   at: (NSPoint)stopPoint
	       inView: (NSView*)controlView
	    mouseIsUp: (BOOL)flag
{
}

- (BOOL) trackMouse: (NSEvent*)theEvent
	     inRect: (NSRect)cellFrame
	     ofView: (NSView*)controlView
       untilMouseUp: (BOOL)flag
{
  NSApplication	*theApp = [NSApplication sharedApplication];
  unsigned	event_mask = NSLeftMouseDownMask | NSLeftMouseUpMask
    | NSMouseMovedMask | NSLeftMouseDraggedMask | NSOtherMouseDraggedMask
    | NSRightMouseDraggedMask;
  NSPoint	location = [theEvent locationInWindow];
  NSPoint	point = [controlView convertPoint: location fromView: nil];
  float		delay;
  float		interval;
  id		target = [self target];
  SEL		action = [self action];
  NSPoint	last_point = point;
  BOOL		done;
  BOOL		mouseWentUp;

  NSDebugLLog(@"NSCell", @"cell start tracking in rect %@ initial point %f %f",
	     NSStringFromRect(cellFrame), point.x, point.y);

  _mouse_down_flags = [theEvent modifierFlags];
  if (![self startTrackingAt: point inView: controlView])
    return NO;

  if (![controlView mouse: point inRect: cellFrame])
    return NO;	// point is not in cell

  if ((_action_mask & NSLeftMouseDownMask) 
      && [theEvent type] == NSLeftMouseDown)
    [(NSControl*)controlView sendAction: action to: target];

  if (_action_mask & NSPeriodicMask)
    {
      [self getPeriodicDelay: &delay interval: &interval];
      [NSEvent startPeriodicEventsAfterDelay: delay withPeriod: interval];
      event_mask |= NSPeriodicMask;
    }

  NSDebugLLog(@"NSCell", @"cell get mouse events\n");
  mouseWentUp = NO;
  done = NO;
  while (!done)
    {
      NSEventType	eventType;
      BOOL		pointIsInCell;
      unsigned		periodCount = 0;

      theEvent = [theApp nextEventMatchingMask: event_mask
				     untilDate: nil
				        inMode: NSEventTrackingRunLoopMode
				       dequeue: YES];
      eventType = [theEvent type];

      if (eventType != NSPeriodic || periodCount == 4)
	{
	  last_point = point;
	  if (eventType == NSPeriodic)
	    {
	      NSWindow	*w = [controlView window];

	      /*
	       * Too many periodic events in succession - 
	       * update the mouse location and reset the counter.
	       */
	      location = [w mouseLocationOutsideOfEventStream];
	      periodCount = 0;
	    }
	  else
	    {
	      location = [theEvent locationInWindow];
	    }
	  point = [controlView convertPoint: location fromView: nil];
	  NSDebugLLog(@"NSCell", @"location %f %f\n", location.x, location.y);
	  NSDebugLLog(@"NSCell", @"point %f %f\n", point.x, point.y);
	}
      else
	{
	  periodCount++;
	  NSDebugLLog (@"NSCell", @"cell got a periodic event");
	}

      if (![controlView mouse: point inRect: cellFrame])
	{
	  NSDebugLLog(@"NSCell", @"point not in cell frame\n");

	  pointIsInCell = NO;	
	  if (flag == NO) 
	    {
	      NSDebugLLog(@"NSCell", @"cell return immediately\n");
	      done = YES;
	    }
	}
      else
	{
	  pointIsInCell = YES;
	}

      if (!done && ![self continueTracking: last_point 	// should continue
					at: point 	// tracking?
				    inView: controlView])
	{
	  NSDebugLLog(@"NSCell", @"cell stop tracking\n");
	  done = YES;
	}
      
      // Did the mouse go up?
      if (eventType == NSLeftMouseUp)
	{
	  NSDebugLLog(@"NSCell", @"cell mouse went up\n");
	  mouseWentUp = YES;
	  done = YES;
	}
      else
	{
	  if (pointIsInCell && ((eventType == NSLeftMouseDragged
			  && (_action_mask & NSLeftMouseDraggedMask))
			  || ((eventType == NSPeriodic)
			  && (_action_mask & NSPeriodicMask))))
	    [(NSControl*)controlView sendAction: action to: target];
	}
    }

  // Hook called when stop tracking
  [self stopTracking: last_point
		  at: point
	      inView: controlView
	   mouseIsUp: mouseWentUp];

  if (_action_mask & NSPeriodicMask)
    [NSEvent stopPeriodicEvents];

  if (mouseWentUp)
    {
      [self setNextState];
      if ((_action_mask & NSLeftMouseUpMask))
	[(NSControl*)controlView sendAction: action to: target];
    }

  // Return YES only if the mouse went up within the cell
  if (mouseWentUp && (flag || [controlView mouse: point inRect: cellFrame]))
    {
      NSDebugLLog(@"NSCell", @"mouse went up in cell\n");
      return YES;
    }

  NSDebugLLog(@"NSCell", @"mouse did not go up in cell\n");
  return NO;				// Otherwise return NO
}

/** <p>TODO</p>
 */
- (void) resetCursorRect: (NSRect)cellFrame inView: (NSView*)controlView
{
  if (_cell.type == NSTextCellType && _cell.is_disabled == NO
    && (_cell.is_selectable == YES || _cell.is_editable == YES))
    {
      static NSCursor	*cursor = nil;
      NSRect	rect;

      if (cursor== nil)
	{
	  cursor = RETAIN([NSCursor IBeamCursor]);
	}
      rect = NSIntersectionRect(cellFrame, [controlView visibleRect]);
      /*
       * Here we depend on an undocumented feature of NSCursor which may or
       * may not exist in OPENSTEP or MacOS-X ...
       * If we add a cursor rect to a view and don't set it to be set on
       * either entry to or exit from the view, we push it on entry and
       * pop it from the cursor stack on exit.
       */
      [controlView addCursorRect: rect cursor: cursor];
    }
}

/**<p>Implemented by subclasses to returns the key equivalent. 
   The NSCell implementation returns an empty NSString. </p>
 */
- (NSString*) keyEquivalent
{
  return @"";
}

/**<p>Does nothing. This method is used by subclasses to recalculate sizes</p>
   <p>It is usally called from a NSControl object</p>
   <p>See Also: [NSControl-calcSize]</p>
 */
- (void) calcDrawInfo: (NSRect)aRect
{
}

/**Returns the minimun size needed to display the NSCell.
   This size is calculate by adding : 
   <list>
   <item> the borders (plain or bezeled) size</item>
   <item> the spacing between the border and inside the cell</item>
   <item> the TODO ... if the cell is type  of NSTextCellType 
   or the image size if the cell has a NSImageCellType type.</item>
   </list>
  <p>This method  returns NSZeroSize if the cell has a NSNullCellType type
   (Cocoa returns a very big size instead).
   </p>
 */
- (NSSize) cellSize
{
  NSSize borderSize, s;
  
  // Get border size
  if (_cell.is_bordered)
    borderSize = _sizeForBorderType (NSLineBorder);
  else if (_cell.is_bezeled)
    borderSize = _sizeForBorderType (NSBezelBorder);
  else
    borderSize = NSZeroSize;

  // Add spacing between border and inside 
  if (_cell.is_bordered || _cell.is_bezeled)
    {
      borderSize.height += 1;
      borderSize.width  += 3;
    }

  // Get Content Size
  switch (_cell.type)
    {
      case NSTextCellType:
	{
	  NSAttributedString *attrStr;

	  attrStr = [self attributedStringValue];
	  if ([attrStr length] != 0)
	    {
	      s = [attrStr size];
	    }
	  else
	    {
	      s = [self _sizeText: @"A"];
	    }
	}
	break;

      case NSImageCellType:
	if (_cell_image == nil)
	  {
	    s = NSZeroSize;
	  }
	else
	  {
	    s = [_cell_image size];
	  }
	break;

      default:
      case NSNullCellType:
	//  macosx instead returns a 'very big size' here; we return NSZeroSize
	s = NSZeroSize;
	break;
    }

  // Add in border size
  s.width += 2 * borderSize.width;
  s.height += 2 * borderSize.height;
  
  return s;
}

/**<p>TODO. Currently the GNUstep implementation returns -cellSize</p>
   <p>See Also: -cellSize</p>
 */
- (NSSize) cellSizeForBounds: (NSRect)aRect
{
  if (_cell.type == NSTextCellType)
    {
      // TODO: Resize the text to fit
    }

  return [self cellSize];
}

/**<p>TODO</p>
 */
- (NSRect) drawingRectForBounds: (NSRect)theRect
{
  NSSize borderSize;

  // Get border size
  if (_cell.is_bordered)
    borderSize = _sizeForBorderType (NSLineBorder);
  else if (_cell.is_bezeled)
    borderSize = _sizeForBorderType (NSBezelBorder);
  else
    borderSize = NSZeroSize;

  return NSInsetRect(theRect, borderSize.width, borderSize.height);
}

/**<p>The GNUstep implementation returns -drawingRectForBounds:</p>
 */
- (NSRect) imageRectForBounds: (NSRect)theRect
{
  return [self drawingRectForBounds: theRect];
}

/** <p>TODO</p>
 */
- (NSRect) titleRectForBounds: (NSRect)theRect
{
  if (_cell.type == NSTextCellType)
    {
      NSRect frame = [self drawingRectForBounds: theRect];
      
      // Add spacing between border and inside 
      if (_cell.is_bordered || _cell.is_bezeled)
	{
	  frame.origin.x += 3;
	  frame.size.width -= 6;
	  frame.origin.y += 1;
	  frame.size.height -= 2;
	}
      return frame;
    }
  else
    {
      return theRect;
    }
}

- (void) setControlSize: (NSControlSize)controlSize
{
  // FIXME
}

- (NSControlSize) controlSize
{
  // FIXME
  return NSRegularControlSize;
}

- (void) setControlTint: (NSControlTint)controlTint
{
  // FIXME 
}

- (NSControlTint) controlTint
{
  // FIXME
  return NSDefaultControlTint;
}

/**<p>This method is used by subclasses to specified the control view.
   This method returns nil.</p>
 */
- (NSView*) controlView
{
  return nil;
}

/** <p>This drawing is minimal and with no background,
 * to make it easier for subclass to customize drawing. </p>
 */
- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView*)controlView
{
  cellFrame = [self drawingRectForBounds: cellFrame];

  //FIXME: Check if this is also neccessary for images,
  // Add spacing between border and inside 
  if (_cell.is_bordered || _cell.is_bezeled)
    {
      cellFrame.origin.x += 3;
      cellFrame.size.width -= 6;
      cellFrame.origin.y += 1;
      cellFrame.size.height -= 2;
    }

  switch (_cell.type)
    {
      case NSTextCellType:
        {
	  [self _drawAttributedText: [self attributedStringValue]
		inFrame: cellFrame];
	}
	break;

      case NSImageCellType:
	if (_cell_image)
	  {
	    NSSize size;
	    NSPoint position;

	    size = [_cell_image size];
	    position.x = MAX(NSMidX(cellFrame) - (size.width/2.),0.);
	    position.y = MAX(NSMidY(cellFrame) - (size.height/2.),0.);
	    /*
	     * Images are always drawn with their bottom-left corner
	     * at the origin so we must adjust the position to take
	     * account of a flipped view.
	     */
	    if ([controlView isFlipped])
	      position.y += size.height;
	    [_cell_image compositeToPoint: position operation: NSCompositeSourceOver];
	  }
	 break;

      case NSNullCellType:
         break;
    }

  if (_cell.shows_first_responder)
    NSDottedFrameRect(cellFrame);

  // NB: We don't do any highlighting to make it easier for subclasses
  // to reuse this code while doing their own custom highlighting and
  // prettyfying
}

/**<p>Draws the cell in <var>controlView</var></p>
 */
- (void) drawWithFrame: (NSRect)cellFrame inView: (NSView*)controlView
{
  // do nothing if cell's frame rect is zero
  if (NSIsEmptyRect(cellFrame))
    return;

  // draw the border if needed
  if (_cell.is_bordered)
    {
      [shadowCol set];
      NSFrameRect(cellFrame);
    }
  else if (_cell.is_bezeled)
    {
      [GSDrawFunctions drawWhiteBezel: cellFrame : NSZeroRect];
    }

  [self drawInteriorWithFrame: cellFrame inView: controlView];
}

/**<p>Sets whether the NSCell is highlighted.</p>
   <p>See Also: -isHighlighted</p>
 */
- (void) setHighlighted: (BOOL) flag
{
  _cell.is_highlighted = flag;
}

/**<p>Returns whether the cell is highlighted. By default NO</p>
   <p>See Also: -setHighlighted:</p>
 */
- (BOOL) isHighlighted
{
  return _cell.is_highlighted;
}

/**
 *<p>TODO explain</p>
 */

- (void) highlight: (BOOL)lit
	 withFrame: (NSRect)cellFrame
	    inView: (NSView*)controlView
{
  if (_cell.is_highlighted != lit)
    {
      _cell.is_highlighted = lit;
      /*
       * NB: This has a visible effect only if subclasses override
       * drawWithFrame:inView: to draw something special when the
       * cell is highlighted. 
       * NSCell simply draws border+text/image and makes no highlighting, 
       * for easier subclassing.
       */
      if ([self isOpaque] == NO)
	{
	  /* FIXME - This looks like potentially generating an
	   * infinite loop!  The control asking the cell to draw
	   * itself in the rect, the cell asking the control to draw
	   * the rect, the control asking the cell to draw itself in
	   * the rect, the cell ...
	   *
	   * I think we should remove it.  The control is responsible
	   * for using the cell to draw, not vice versa.
	   */
	  [controlView displayRect: cellFrame];
	}
      [self drawWithFrame: cellFrame inView: controlView];
    }
}

- (NSColor*) highlightColorWithFrame: (NSRect)cellFrame
			      inView: (NSView *)controlView
{
  return [NSColor selectedControlColor];
}

- (void) _setupTextWithFrame: (NSRect)aRect
		      inView: (NSView*)controlView
		      editor: (NSText*)textObject
{
  NSRect titleRect = [self titleRectForBounds: aRect];
  /* See comments in NSStringDrawing.m about the choice of maximum size. */
  NSSize maxSize = NSMakeSize(1e6, titleRect.size.height);
  NSClipView *cv = [[NSClipView alloc] 
		       initWithFrame: titleRect];
  NSTextContainer *ct = [(NSTextView*)textObject textContainer];

  [controlView addSubview: cv];
  RELEASE(cv);
  [cv setAutoresizesSubviews: NO];
  [cv setDocumentView: textObject];
  [textObject setFrame: NSMakeRect(0, 0, maxSize.width, maxSize.height)];
  [textObject setHorizontallyResizable: NO];
  [textObject setVerticallyResizable: NO];
  [textObject setMaxSize: maxSize];
  [textObject setMinSize: titleRect.size];
  [ct setContainerSize: maxSize];
  [ct setHeightTracksTextView: NO];
  [ct setWidthTracksTextView: NO];
}

/*
 * Editing Text
 */
/** <p>.This method does nothing if a the <var>controlView</var> is nil,
    if text object does not exist or if the cell's type is not <ref type="type"
    id="NSCellType">NSTextCellType</ref></p>
 */
- (void) editWithFrame: (NSRect)aRect
		inView: (NSView*)controlView
		editor: (NSText*)textObject
	      delegate: (id)anObject
		 event: (NSEvent*)theEvent
{
  if (!controlView || !textObject || (_cell.type != NSTextCellType))
    return;

  [self _setupTextWithFrame: aRect
	inView: controlView
	editor: textObject];

  if (_formatter != nil)
    {
      NSString *contents; 

      contents = [_formatter editingStringForObjectValue: _objectValue];
      if (contents == nil)
	{
	  contents = _contents;
	}
      [textObject setText: contents];
    }
  else
    {
      if (_cell.contents_is_attributed_string == NO)
	{
	  [textObject setText: _contents];
	}
      else
	{
	  /* FIXME/TODO make sure this is correct. */
	  [textObject setText: [(NSAttributedString *)_contents string]];
	}
    }
  [textObject sizeToFit];
  
  [textObject setDelegate: anObject];
  [[controlView window] makeFirstResponder: textObject];

  if ([theEvent type] == NSLeftMouseDown)
    {
      [textObject mouseDown: theEvent];
    }
}

/**<p>Ends any text editing. This method sets the text object's delegate 
   to nil, and remove the NSClipView and the text object used for editing</p>
 <p>See Also:  -editWithFrame:inView:editor:delegate:event:</p>
 */
- (void) endEditing: (NSText*)textObject
{
  NSClipView *clipView;

  [textObject setDelegate: nil];
  clipView = (NSClipView*)[textObject superview];
  [textObject removeFromSuperview];
  [clipView removeFromSuperview];
}

/** <p> TODO.This method does nothing if a the <var>controlView</var> is nil,
    if text object does not exist or if the cell's type is not <ref type="type"
    id="NSCellType">NSTextCellType</ref> </p>
 */
- (void) selectWithFrame: (NSRect)aRect
		  inView: (NSView*)controlView
		  editor: (NSText*)textObject
		delegate: (id)anObject
		   start: (int)selStart
		  length: (int)selLength
{
  if (!controlView || !textObject || (_cell.type != NSTextCellType))
    return;

  [self _setupTextWithFrame: aRect
	inView: controlView
	editor: textObject];

  if (_formatter != nil)
    {
      NSString *contents; 

      contents = [_formatter editingStringForObjectValue: _objectValue];
      if (contents == nil)
	{
	  contents = _contents;
	}
      [textObject setText: contents];
    }
  else
    {
      if (_cell.contents_is_attributed_string == NO)
	{
	  [textObject setText: _contents];
	}
      else
	{
	  /* FIXME/TODO make sure this is correct. */
	  [textObject setText: [(NSAttributedString *)_contents string]];
	}
    }

  [textObject sizeToFit];
  [textObject setSelectedRange: NSMakeRange (selStart, selLength)];
  [textObject scrollRangeToVisible: NSMakeRange(selStart, selLength)];
  [textObject setDelegate: anObject];
  [[controlView window] makeFirstResponder: textObject];
}

- (BOOL) sendsActionOnEndEditing 
{
  return _cell.sends_action_on_end_editing;
}

- (void) setSendsActionOnEndEditing: (BOOL)flag
{
  _cell.sends_action_on_end_editing = flag;
}

/*
 * Copying
 */
- (id) copyWithZone: (NSZone*)zone
{
  NSCell *c = (NSCell*)NSCopyObject (self, 0, zone);

  /* Hmmm. */
  c->_contents = [_contents copyWithZone: zone];
  /* Because of performance issues (and because so the doc says) only
     pointers to the objects are copied.  We need to RETAIN them all
     though. */
  TEST_RETAIN (_font);
  TEST_RETAIN (_objectValue);
  TEST_RETAIN (_menu);
  TEST_RETAIN (_cell_image);
  TEST_RETAIN (_formatter);
  TEST_RETAIN (_represented_object);

  return c;
}

/*
 * NSCoding protocol
 */
- (void) encodeWithCoder: (NSCoder*)aCoder
{
  BOOL flag;
  unsigned int tmp_int;

  [aCoder encodeObject: _contents];
  [aCoder encodeObject: _cell_image];
  [aCoder encodeObject: _font];
  [aCoder encodeObject: _objectValue];
  flag = _cell.contents_is_attributed_string;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_highlighted;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_disabled;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_editable;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_rich_text;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.imports_graphics;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.shows_first_responder;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.refuses_first_responder;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.sends_action_on_end_editing;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_bordered;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_bezeled;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_scrollable;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.is_selectable;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  // This used to be is_continuous, which has been replaced.
  /* Ayers 20.03.2003: But we must continue to encode it for backward
     compatibility or current releases will have undefined behavior when
     decoding archives (i.e. .gorm files) encoded by this version. */
  flag = [self isContinuous];
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.allows_mixed_state;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  flag = _cell.wraps;
  [aCoder encodeValueOfObjCType: @encode(BOOL) at: &flag];
  tmp_int = _cell.text_align;
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
  tmp_int = _cell.type;
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
  tmp_int = _cell.image_position;
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
  tmp_int = _cell.entry_type;
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
  tmp_int = _cell.state;
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &_mnemonic_location];
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &_mouse_down_flags];
  [aCoder encodeValueOfObjCType: @encode(unsigned int) at: &_action_mask];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_formatter];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_menu];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_represented_object];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  if ([aDecoder allowsKeyedCoding])
    {
      NSString *contents = [aDecoder decodeObjectForKey: @"NSContents"];

      self = [self initTextCell: contents];

      if ([aDecoder containsValueForKey: @"NSCellFlags"])
        {
	  unsigned long cFlags;

	  cFlags = [aDecoder decodeIntForKey: @"NSCellFlags"];

	  // This bit flag is the other way around!
	  [self setWraps: ((cFlags & 0x40) != 0x40)];
	  [self setScrollable: ((cFlags & 0x100000) == 0x100000)];
	  // Strange that this is not a simple bit flag
	  [self setSelectable: ((cFlags & 0x200001) == 0x200001)];
	  [self setBezeled: ((cFlags & 0x400000) == 0x400000)];
	  [self setBordered: ((cFlags & 0x800000) == 0x800000)];
	  if ((cFlags & 0x4000000) == 0x4000000)
	    {
	      [self setType: NSTextCellType];
	    }

	  [self setContinuous: ((cFlags & 0x40000) == 0x40000)];
	  [self setEditable: ((cFlags & 0x10000000) == 0x10000000)];
	  // This bit flag is the other way around!
	  [self setEnabled: ((cFlags & 0x20000000) != 0x20000000)];
	  [self setHighlighted: ((cFlags & 0x40000000) == 0x40000000)];
	  [self setState: ((cFlags & 0x80000000) == 0x80000000)?NSOnState:NSOffState];
	}
      if ([aDecoder containsValueForKey: @"NSCellFlags2"])
        {
	  int cFlags2;
      
	  cFlags2 = [aDecoder decodeIntForKey: @"NSCellFlags2"];
	  [self setSendsActionOnEndEditing: (cFlags2 & 0x400000)];
	  [self setAllowsMixedState: ((cFlags2 & 0x1000000) == 0x1000000)];
	  [self setRefusesFirstResponder: ((cFlags2 & 0x2000000) == 0x2000000)];
	  if ((cFlags2 & 0x4000000) == 0x4000000)
	    {
	      [self setAlignment: NSRightTextAlignment];
	    }
	  if ((cFlags2 & 0x8000000) == 0x8000000)
	    {
	      [self setAlignment: NSCenterTextAlignment];
	    }
	  if ((cFlags2 & 0xC000000) == 0xC000000)
	    {
	      [self setAlignment: NSJustifiedTextAlignment];
	    }
	  if ((cFlags2 & 0x10000000) == 0x10000000)
	    {
	      [self setAlignment: NSNaturalTextAlignment];
	    }

	  [self setImportsGraphics: ((cFlags2 & 0x20000000) == 0x20000000)];
	  [self setAllowsEditingTextAttributes: ((cFlags2 & 0x40000000) == 0x40000000)];
	}
      if ([aDecoder containsValueForKey: @"NSSupport"])
        {
	  NSFont *support = [aDecoder decodeObjectForKey: @"NSSupport"];

	  [self setFont: support];
	}
      if ([aDecoder containsValueForKey: @"NSFormatter"])
        {
	  NSFormatter *formatter = [aDecoder decodeObjectForKey: @"NSFormatter"];

	  [self setFormatter: formatter];
	}
    }
  else
    {
      BOOL flag;
      unsigned int tmp_int;
      id formatter, menu;

      [aDecoder decodeValueOfObjCType: @encode(id) at: &_contents];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &_cell_image];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &_font];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &_objectValue];
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.contents_is_attributed_string = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_highlighted = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_disabled = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_editable = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_rich_text = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.imports_graphics = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.shows_first_responder = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.refuses_first_responder = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.sends_action_on_end_editing = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_bordered = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_bezeled = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_scrollable = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.is_selectable = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      // This used to be is_continuous, which has been replaced.
      //_cell.is_continuous = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.allows_mixed_state = flag;
      [aDecoder decodeValueOfObjCType: @encode(BOOL) at: &flag];
      _cell.wraps = flag;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
      _cell.text_align = tmp_int;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
      _cell.type = tmp_int;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
      _cell.image_position = tmp_int;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
      _cell.entry_type = tmp_int;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &tmp_int];
      _cell.state = tmp_int;
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) 
		                   at: &_mnemonic_location];
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) 
		                   at: &_mouse_down_flags];
      [aDecoder decodeValueOfObjCType: @encode(unsigned int) at: &_action_mask];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &formatter];
      [self setFormatter: formatter];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &menu];
      [self setMenu: menu];
      [aDecoder decodeValueOfObjCType: @encode(id) at: &_represented_object];

      if (_formatter != nil)
        {
	  NSString *contents;

	  contents = [_formatter stringForObjectValue: _objectValue];
	  if (contents != nil)
	    {
	      _cell.has_valid_object_value = YES;
	      ASSIGN (_contents, contents);
	      _cell.contents_is_attributed_string = NO;
	    }
	}
    }
  return self;
}
@end

@implementation NSCell (PrivateMethods)

- (NSColor*) textColor
{
  if (_cell.is_disabled)
    return dtxtCol;
  else
    return txtCol;    
}

/* This method is an exception and returns a non-autoreleased
   dictionary, so that calling methods can deallocate it immediately
   using release.  Otherwise if many cells are drawn/their size
   computed, we pile up hundreds or thousands of these objects before they 
   are deallocated at the end of the run loop. */
- (NSDictionary*) _nonAutoreleasedTypingAttributes
{
  NSDictionary *attr;
  NSColor *color;
  NSMutableParagraphStyle *paragraphStyle;

  color = [self textColor];
  /* Note: there are only 6 possible paragraph styles for cells.  
     TODO: Create them once at the beginning, and reuse them for the whole 
     app lifetime. */
  paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

  if (_cell.wraps)
    {
      [paragraphStyle setLineBreakMode: NSLineBreakByWordWrapping];
    }
  else
    {
      [paragraphStyle setLineBreakMode: NSLineBreakByClipping];
    }   

  [paragraphStyle setAlignment: _cell.text_align];

  attr = [[NSDictionary alloc] initWithObjectsAndKeys: 
			       _font, NSFontAttributeName,
			       color, NSForegroundColorAttributeName,
			       paragraphStyle, NSParagraphStyleAttributeName,
			       nil];
  RELEASE (paragraphStyle);
  return attr;
}

- (NSSize) _sizeText: (NSString*)title
{
  NSSize size;
  NSDictionary *dict;

  if (title == nil)
    {
      return NSMakeSize (0,0);
    }

  dict = [self _nonAutoreleasedTypingAttributes];
  size = [title sizeWithAttributes: dict];
  RELEASE (dict);
  return size;
}

/**
 * Private internal method to display an attributed string.
 */
- (void) _drawAttributedText: (NSAttributedString*)aString 
		     inFrame: (NSRect)aRect
{
  NSSize titleSize;

  if (aString == nil)
    return;

  titleSize = [aString size];

  /** Important: text should always be vertically centered without
   * considering descender [as if descender did not exist].
   * This is particularly important for single line texts.
   * Please make sure the output remains always correct.
   */
  aRect.origin.y = NSMidY (aRect) - titleSize.height/2; 
  aRect.size.height = titleSize.height;

  [aString drawInRect: aRect];
}

- (void) _drawText: (NSString*)aString  inFrame: (NSRect)cellFrame
{
  NSSize titleSize;
  NSDictionary *attributes;

  if (aString == nil)
    return;

  attributes = [self _nonAutoreleasedTypingAttributes];
  titleSize = [aString sizeWithAttributes: attributes];

  /** Important: text should always be vertically centered without
   * considering descender [as if descender did not exist].
   * This is particularly important for single line texts.
   * Please make sure the output remains always correct.
   */
  cellFrame.origin.y = NSMidY (cellFrame) - titleSize.height/2; 
  cellFrame.size.height = titleSize.height;

  [aString drawInRect: cellFrame  withAttributes: attributes];
  RELEASE (attributes);
}

- (BOOL) _sendsActionOn:(int)eventTypeMask
{
  return (_action_mask & eventTypeMask);
}

@end

/*
 * Global function which should go somewhere else
 */
inline NSSize 
_sizeForBorderType (NSBorderType aType)
{
  // Returns the size of a border
  switch (aType)
    {
      case NSLineBorder:
	return NSMakeSize(1, 1);
      case NSGrooveBorder:
      case NSBezelBorder:
	return NSMakeSize(2, 2);
      case NSNoBorder: 
      default:
	return NSZeroSize;
    }
}

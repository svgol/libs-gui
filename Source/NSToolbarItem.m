/* 
   NSToolbarItem.m

   The Toolbar item class.
   
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>,
            Fabien Vallon <fabien.vallon@fr.alcove.com>,
	    Quentin Mathe <qmathe@club-internet.fr>
   Date: May 2002
   
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
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDebug.h>

#include "AppKit/NSApplication.h"
#include "AppKit/NSToolbarItem.h"
#include "AppKit/NSMenu.h"
#include "AppKit/NSMenuItem.h"
#include "AppKit/NSImage.h"
#include "AppKit/NSButton.h"
#include "AppKit/NSFont.h"
#include "AppKit/NSEvent.h"
#include "GNUstepGUI/GSToolbar.h"
#include "GNUstepGUI/GSToolbarView.h"

/*
 * Each NSToolbarItem object are coupled with a backView which is their representation 
 * on the screen.
 * backView for the standard toolbar item (without custom view) are NSButton subclass
 * called GSToolbarButton.
 * backView for the toolbar item with a custom view are NSView subclass called
 * GSToolbarBackView.
 * GSToolbarButton and GSToolbarBackView are adjusted according to their content and
 * their title when the method layout is called.
 * The predefined GNUstep toolbar items are implemented with a class cluster pattern :
 * initWithToolbarItemIdentifier: returns differents concrete subclass in accordance
 * with the item identifier.
 */

@interface GSToolbar (GNUstepPrivate)
- (GSToolbarView *) _toolbarView;
@end

@interface NSToolbarItem (GNUstepPrivate)
- (NSView *) _backView;
- (NSMenuItem *) _defaultMenuFormRepresentation;
- (BOOL) _isFlexibleSpace;
- (BOOL) _isModified;
- (void) _layout;
- (void) _setToolbar: (GSToolbar *)toolbar;
@end

@interface GSToolbarView (GNUstepPrivate)
- (void) _reload;
@end

/*
 * NSButton subclass is the toolbar buttons _backView
 */
@interface GSToolbarButton : NSButton
{
  NSToolbarItem *_toolbarItem;
  SEL _toolbarItemAction;
}

- (id) initWithToolbarItem: (NSToolbarItem *)toolbarItem;
- (void) layout;
- (void) setToolbarItemAction: (SEL)action;
- (NSToolbarItem *) toolbarItem;
- (SEL) toolbarItemAction;
@end

@implementation GSToolbarButton
- (id) initWithToolbarItem: (NSToolbarItem *)toolbarItem
{ 
  self = [super initWithFrame: NSMakeRect(_ItemBackViewX, _ItemBackViewY, _ItemBackViewDefaultWidth, _ItemBackViewDefaultHeight)];
  if (self != nil)
    {
      ASSIGN(_toolbarItem, toolbarItem);
    }
  return self;   
}

- (void) layout
{
  float textWidth, layoutedWidth = -1, layoutedHeight = -1;
  NSAttributedString *attrStr;
  NSDictionary *attr;
  NSFont *font = [NSFont systemFontOfSize: 11]; // [NSFont smallSystemFontSize] or better should NSControlContentFontSize

  // Adjust the layout in accordance with NSToolbarSizeMode

  switch ([[_toolbarItem toolbar] sizeMode])
    {
      case NSToolbarSizeModeDefault:
	layoutedWidth = _ItemBackViewDefaultWidth;
	layoutedHeight = _ItemBackViewDefaultHeight;
	[[_toolbarItem image] setSize: NSMakeSize(32, 32)];
	break;
      case NSToolbarSizeModeRegular:
        layoutedWidth = _ItemBackViewRegularWidth;
        layoutedHeight = _ItemBackViewRegularHeight;
	[[_toolbarItem image] setSize: NSMakeSize(32, 32)];
	break;
      case NSToolbarSizeModeSmall:
        layoutedWidth = _ItemBackViewSmallWidth;
	layoutedHeight = _ItemBackViewSmallHeight;
	[[_toolbarItem image] setSize: NSMakeSize(24, 24)];
	// Not use [self image] here because it can return nil, when image position is
	// set to NSNoImage. Even if NSToolbarDisplayModeTextOnly is not true anymore
	// -setImagePosition: is only called below, then [self image] can still returns 
	// nil.
	font = [NSFont systemFontOfSize: 9];
	break;
      default:
	; // invalid
    }
    
  [[self cell] setFont: font];
             
  // Adjust the layout in accordance with the label
	
  attr = [NSDictionary dictionaryWithObject: font forKey: @"NSFontAttributeName"];
  attrStr = [[NSAttributedString alloc] initWithString: [_toolbarItem label] attributes: attr];
      
  textWidth = [attrStr size].width + 2 * _InsetItemTextX;
  if (layoutedWidth != -1 && textWidth > layoutedWidth) 
     layoutedWidth = textWidth;
     
  // Adjust the layout in accordance with NSToolbarDisplayMode
  
  switch ([[_toolbarItem toolbar] displayMode])
    {
      case NSToolbarDisplayModeDefault:
        [self setImagePosition: NSImageAbove];
        break;
      case NSToolbarDisplayModeIconAndLabel:
        [self setImagePosition: NSImageAbove];
        break;
      case NSToolbarDisplayModeIconOnly:
        [self setImagePosition: NSImageOnly];
        layoutedHeight -= [attrStr size].height + _InsetItemTextY;
	layoutedWidth -= [attrStr size].height + _InsetItemTextY;
	break;
      case NSToolbarDisplayModeLabelOnly:
        [self setImagePosition: NSNoImage];
        layoutedHeight = [attrStr size].height + _InsetItemTextY * 2;
	break;
      default:
	; // invalid
    }
      
  // Set the frame size to use the new layout
  
  [self setFrameSize: NSMakeSize(layoutedWidth, layoutedHeight)];
   
}

- (BOOL) sendAction: (SEL)action to: (id)target
{ 
  if (_toolbarItemAction)
    {
      return [NSApp sendAction: _toolbarItemAction to: target from: _toolbarItem];
    }
  else
    {
      return NO;
    }
}

- (NSToolbarItem *) toolbarItem
{
  return _toolbarItem;
}

- (void) setToolbarItemAction: (SEL) action
{
  _toolbarItemAction = action;
}

- (SEL) toolbarItemAction
{
  return _toolbarItemAction;
}

@end

/*
 * Back view used to enclose toolbar item's custom view
 */
@interface GSToolbarBackView : NSView
{
  NSToolbarItem *_toolbarItem;
  BOOL _enabled;
  BOOL _showLabel;
  NSFont *_font;
}

- (id) initWithToolbarItem: (NSToolbarItem *)toolbarItem;
- (NSToolbarItem *) toolbarItem;
- (void) setEnabled: (BOOL)enabled;
@end

@implementation GSToolbarBackView

- (id)initWithToolbarItem: (NSToolbarItem *)toolbarItem
{  
  self = [super initWithFrame: NSMakeRect(_ItemBackViewX, _ItemBackViewY, _ItemBackViewDefaultWidth,
  _ItemBackViewDefaultHeight)];
  
  if (self != nil)
    {  
      ASSIGN(_toolbarItem, toolbarItem);
    }
  
  return self;
}

- (void)drawRect: (NSRect)rect
{
  NSAttributedString *attrString;
  NSDictionary *attr;
  NSColor *color;
  int textX;
  
  [super drawRect: rect]; // We draw _view which is a subview
  
  if (_enabled)
    {
      color = [NSColor blackColor];
    }
  else
    {
      color = [NSColor disabledControlTextColor];
    }
    
  if (_showLabel)
    {
      // we draw the label
      attr = [NSDictionary dictionaryWithObjectsAndKeys: _font, 
                                                         @"NSFontAttributeName", 
							 color,
                                                         @"NSForegroundColorAttributeName",
							 nil];
      attrString = [[NSAttributedString alloc] initWithString: [_toolbarItem label] attributes: attr];
      textX = (([self frame].size.width - _InsetItemTextX) - [attrString size].width) / 2;
      [attrString drawAtPoint: NSMakePoint(textX, _InsetItemTextY)];
    }
}

- (void) layout
{
  NSView *view = [_toolbarItem view];
  float insetItemViewY;
  float textWidth, layoutedWidth = -1, layoutedHeight = -1;
  NSAttributedString *attrStr;
  NSDictionary *attr;
  
  _font = [NSFont systemFontOfSize: 11]; // [NSFont smallSystemFontSize] or better should be NSControlContentFontSize
  
  if ([view superview] == nil) // Show the view to eventually hide it later
    [self addSubview: view];
    
  // Adjust the layout in accordance with NSToolbarSizeMode
  
  switch ([[_toolbarItem toolbar] sizeMode])
    {
      case NSToolbarSizeModeDefault:
	layoutedWidth = _ItemBackViewDefaultWidth;
	layoutedHeight = _ItemBackViewDefaultHeight;
	if ([view frame].size.height > 32)
	  [view removeFromSuperview];
	break;
      case NSToolbarSizeModeRegular:
        layoutedWidth = _ItemBackViewRegularWidth;
        layoutedHeight = _ItemBackViewRegularHeight;
	if ([view frame].size.height > 32)
	  [view removeFromSuperview];
	break;
      case NSToolbarSizeModeSmall:
        layoutedWidth = _ItemBackViewSmallWidth;
	layoutedHeight = _ItemBackViewSmallHeight;
	_font = [NSFont systemFontOfSize: 9];
	if ([view frame].size.height > 24)
	  [view removeFromSuperview];
	break;
      default:
	NSLog(@"Invalid NSToolbarSizeMode"); // invalid
    } 
  
  // Adjust the layout in accordance with the label
 
  attr = [NSDictionary dictionaryWithObject: _font forKey: @"NSFontAttributeName"];
  attrStr = [[NSAttributedString alloc] initWithString: [_toolbarItem label] attributes: attr];
      
  textWidth = [attrStr size].width + 2 * _InsetItemTextX;
  if (textWidth > layoutedWidth)
    layoutedWidth = textWidth;
    
  // Adjust the layout in accordance with NSToolbarDisplayMode
  
  _enabled = YES;
  _showLabel = YES; 
  // this boolean variable is used to known when it's needed to draw the label in the -drawRect:
  // method.
   
  switch ([[_toolbarItem toolbar] displayMode])
    {
      case NSToolbarDisplayModeDefault:
        break; // Nothing to do
      case NSToolbarDisplayModeIconAndLabel:
        break; // Nothing to do
      case NSToolbarDisplayModeIconOnly:
        _showLabel = NO;
        layoutedHeight -= [attrStr size].height + _InsetItemTextY;
	break;
      case NSToolbarDisplayModeLabelOnly:
        _enabled = NO;
        layoutedHeight = [attrStr size].height + _InsetItemTextY * 2;
	if ([view superview] != nil)
	  [view removeFromSuperview];
	break;
      default:
	; // invalid
    }
   
  // If the view is visible... 
  // Adjust the layout in accordance with the view width in the case it is needed
  
  if ([view superview] != nil)
    { 
    if (layoutedWidth < [view frame].size.width + 2 * _InsetItemViewX)
      layoutedWidth = [view frame].size.width + 2 * _InsetItemViewX; 
    }
  
  // Set the frame size to use the new layout
  
  [self setFrameSize: NSMakeSize(layoutedWidth, layoutedHeight)];
  
  // If the view is visible...
  // Adjust the view position in accordance with the new layout
  
  if ([view superview] != nil)
    {
      if (_showLabel)
        {
          insetItemViewY = ([self frame].size.height 
	    - [view frame].size.height - [attrStr size].height - _InsetItemTextX) / 2
	    + [attrStr size].height + _InsetItemTextX;
	}
      else
        {
	  insetItemViewY = ([self frame].size.height - [view frame].size.height) / 2;
	}
	
      [view setFrameOrigin: 
        NSMakePoint((layoutedWidth - [view frame].size.width) / 2, insetItemViewY)];
    }
}

- (NSToolbarItem *)toolbarItem
{
  return _toolbarItem;
}

- (void) setEnabled: (BOOL)enabled
{
  id view = [_toolbarItem view];
 
  _enabled = enabled;
  if ([view respondsToSelector: @selector(setEnabled:)])
  {
    [view setEnabled: enabled];
  }
}

@end

/*
 *
 * Standard toolbar items.
 *
 */

// ---- NSToolbarSeparatorItemIdentifier
@interface GSToolbarSeparatorItem : NSToolbarItem
{
}
@end

@implementation GSToolbarSeparatorItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  NSImage *image = [NSImage imageNamed: @"common_ToolbarSeparatorItem"];

  self = [super initWithItemIdentifier: itemIdentifier];
  [(NSButton *)[self _backView] setImagePosition: NSImageOnly];
  [(NSButton *)[self _backView] setImage: image];
  // We bypass the toolbar item accessor to set the image in order to have it (48 * 48) not resized
   
  [[self _backView] setFrameSize: NSMakeSize(30, _ItemBackViewDefaultHeight)];
  
  return self;
}

- (NSMenuItem *) _defaultMenuFormRepresentation 
{
  return nil; // override the default implementation in order to do nothing
}

- (void) _layout 
{
  // override the default implementation in order to do nothing
}
@end

// ---- NSToolbarSpaceItemIdentifier
@interface GSToolbarSpaceItem : NSToolbarItem
{
}
@end

@implementation GSToolbarSpaceItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{ 
  self = [super initWithItemIdentifier: itemIdentifier];
  [self setLabel: @""];
  
  return self;
}

- (NSMenuItem *) _defaultMenuFormRepresentation 
{
  return nil;// override the default implementation in order to do nothing
}

- (void) _layout 
{
  // override the default implementation in order to do nothing
}
@end

// ---- NSToolbarFlexibleSpaceItemIdentifier
@interface GSToolbarFlexibleSpaceItem : NSToolbarItem
{
}
@end

@implementation GSToolbarFlexibleSpaceItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  self = [super initWithItemIdentifier: itemIdentifier];
  [self setLabel: @""];
  [self _layout];
  
  return self;
}

- (NSMenuItem *) _defaultMenuFormRepresentation 
{
  return nil;// override the default implementation in order to do nothing
}

- (void) _layout 
{
  NSView *backView = [self _backView];
  
  [backView setFrameSize: NSMakeSize(0, [backView frame].size.height)];
  
  // override the default implementation in order to reset the _backView to a zero width
}
@end

// ---- NSToolbarShowColorsItemIdentifier
@interface GSToolbarShowColorsItem : NSToolbarItem
{
}
@end

@implementation GSToolbarShowColorsItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  NSImage *image = [NSImage imageNamed: @"common_ToolbarShowColorsItem"];

  self = [super initWithItemIdentifier: itemIdentifier];
  [self setImage: image];
  [self setLabel: @"Colors"];

  // set action...
  [self setTarget: nil]; // goes to first responder..
  [self setAction: @selector(orderFrontColorPanel:)];

  return self;
}
@end

// ---- NSToolbarShowFontsItemIdentifier
@interface GSToolbarShowFontsItem : NSToolbarItem
{
}
@end

@implementation GSToolbarShowFontsItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  NSImage *image = [NSImage imageNamed: @"common_ToolbarShowFontsItem"];

  self = [super initWithItemIdentifier: itemIdentifier];
  [self setImage: image];
  [self setLabel: @"Fonts"];

  // set action...
  [self setTarget: nil]; // goes to first responder..
  [self setAction: @selector(orderFrontFontPanel:)];

  return self;
}
@end

// ---- NSToolbarCustomizeToolbarItemIdentifier
@interface GSToolbarCustomizeToolbarItem : NSToolbarItem
{
}
@end

@implementation GSToolbarCustomizeToolbarItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  NSImage *image = [NSImage imageNamed: @"common_ToolbarCustomizeToolbarItem"];
  
  self = [super initWithItemIdentifier: itemIdentifier];
  [self setImage: image];
  [self setLabel: @"Customize"];

  // set action...
  [self setTarget: nil]; // goes to first responder..
  [self setAction: @selector(runCustomizationPalette:)];

  return self;
}
@end

// ---- NSToolbarPrintItemIdentifier
@interface GSToolbarPrintItem : NSToolbarItem
{
}
@end

@implementation GSToolbarPrintItem
- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  NSImage *image = [NSImage imageNamed: @"common_Printer"];

  self = [super initWithItemIdentifier: itemIdentifier];
  [self setImage: image];
  [self setLabel: @"Print..."];

  // set action...
  [self setTarget: nil]; // goes to first responder..
  [self setAction: @selector(print:)];

  return self;
}
@end


@implementation NSToolbarItem
- (BOOL) allowsDuplicatesInToolbar
{
  return _allowsDuplicatesInToolbar;
}

- (NSImage *)image
{
  if(_flags._image)
    {
      return _image;
    }
  return nil;
}

- (id) initWithItemIdentifier: (NSString *)itemIdentifier
{
  GSToolbarButton *button;
  NSButtonCell *cell;
  
  if ((self = [super init]) != nil)
    {   
    
      // GNUstep predefined toolbar items
       
      if ([itemIdentifier isEqualToString: @"NSToolbarSeparatorItemIdentifier"] 
           && ![self isKindOfClass:[GSToolbarSeparatorItem class]])
        {
          [self release];
          self = [[GSToolbarSeparatorItem alloc] initWithItemIdentifier: itemIdentifier];
        }
    
      else if ([itemIdentifier isEqualToString: @"NSToolbarSpaceItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarSpaceItem class]])
        {
          [self release];
          self = [[GSToolbarSpaceItem alloc] initWithItemIdentifier: itemIdentifier];
        }
    
      else if ([itemIdentifier isEqualToString: @"NSToolbarFlexibleSpaceItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarFlexibleSpaceItem class]])
        {
          [self release];
          self = [[GSToolbarFlexibleSpaceItem alloc] initWithItemIdentifier: itemIdentifier];
        }
    
      else if ([itemIdentifier isEqualToString: @"NSToolbarShowColorsItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarShowColorsItem class]])
        {
          [self release];
          self = [[GSToolbarShowColorsItem alloc] initWithItemIdentifier: itemIdentifier];
        }
    
      else if ([itemIdentifier isEqualToString: @"NSToolbarShowFontsItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarShowFontsItem class]])
        {
          [self release];
          self = [[GSToolbarShowFontsItem alloc] initWithItemIdentifier: itemIdentifier];
        }
    
      else if ([itemIdentifier isEqualToString: @"NSToolbarCustomizeToolbarItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarCustomizeToolbarItem class]])
        {
          [self release];
          self = [[GSToolbarCustomizeToolbarItem alloc] initWithItemIdentifier: itemIdentifier];
        }
     
      else if ([itemIdentifier isEqualToString: @"NSToolbarPrintItemIdentifier"] 
                && ![self isKindOfClass:[GSToolbarPrintItem class]])
        {
          [self release];
          self = [[GSToolbarPrintItem alloc] initWithItemIdentifier: itemIdentifier];
        }
	
      // Normal toolbar items
      else
        {
      
          ASSIGN(_itemIdentifier, itemIdentifier);
      
          button = [[GSToolbarButton alloc] initWithToolbarItem: self];
          cell = [button cell];
	  [button setTitle: @""];
	  [button setEnabled: NO];
          [button setBordered: NO];
          [button setImagePosition: NSImageAbove];
	  [cell setBezeled: YES];
          [cell setHighlightsBy: NSChangeGrayCellMask | NSChangeBackgroundCellMask];
          [cell setFont: [NSFont systemFontOfSize: 11]]; // [NSFont smallSystemFontSize] or better should be controlContentFontSize

          [_backView release];
          _backView = button;
        }
        
      // gets
      _flags._isEnabled  = [_backView respondsToSelector: @selector(isEnabled)];
      _flags._tag        = YES;
      _flags._action     = [_backView respondsToSelector: @selector(toolbarItemAction)];	
      _flags._target     = [_backView respondsToSelector: @selector(target)];
      _flags._image      = [_backView respondsToSelector: @selector(image)];
      // sets
      _flags._setEnabled = [_backView respondsToSelector: @selector(setEnabled:)];
      _flags._setTag     = YES;
      _flags._setAction  = [_backView respondsToSelector: @selector(setToolbarItemAction:)];
      _flags._setTarget  = [_backView respondsToSelector: @selector(setTarget:)];
      _flags._setImage   = [_backView respondsToSelector: @selector(setImage:)];
    
    }
  
  return self;
}

- (BOOL) isEnabled
{
  if(_flags._isEnabled)
    {
      return [(id)_backView isEnabled];
    }
  return NO;
}

- (NSString *) itemIdentifier
{
  return _itemIdentifier;
}

- (NSString *) label
{
  NSMenuItem *menuItem = [self menuFormRepresentation];
  
  if ([[self toolbar] displayMode] == NSToolbarDisplayModeLabelOnly && menuItem != nil)
    {
      return [menuItem title];
    }
  else
    {
      return _label;
    }
}

- (NSSize) maxSize
{
  return _maxSize;
}

- (NSMenuItem *) menuFormRepresentation
{
  return _menuFormRepresentation;
}

- (NSSize) minSize
{
  return _minSize;
}

- (NSString *) paletteLabel
{
  return _paletteLabel;
}

- (void) setAction: (SEL)action
{
  if(_flags._setAction)
    {
      if ([_backView isKindOfClass: [GSToolbarButton class]])
        [(GSToolbarButton *)_backView setToolbarItemAction: action];
	if (action != NULL)
	  {
	    [self setEnabled: YES];
	  }
	else
	  {
	    [self setEnabled: NO];
	  }
    }
}

- (void) setEnabled: (BOOL)enabled
{
  if(_flags._setEnabled)
    [(id)_backView setEnabled: enabled];
}

- (void) setImage: (NSImage *)image
{
  if(_flags._setImage)
    {  
      ASSIGN(_image, image);  
      
      [_image setScalesWhenResized: YES];
      //[_image setSize: NSMakeSize(32, 32)];
      
      if ([_backView isKindOfClass: [NSButton class]])
        [(NSButton *)_backView setImage: _image];
    }
}

- (void) setLabel: (NSString *)label
{
  ASSIGN(_label, label);
  
  if ([_backView isKindOfClass: [NSButton class]])
    [(NSButton *)_backView setTitle:_label];

  _modified = YES;
  if (_toolbar != nil)
    [[_toolbar _toolbarView] _reload];
}

- (void) setMaxSize: (NSSize)maxSize
{
  _maxSize = maxSize;
}

- (void) setMenuFormRepresentation: (NSMenuItem *)menuItem
{
  ASSIGN(_menuFormRepresentation, menuItem);
}

- (void) setMinSize: (NSSize)minSize
{
  _minSize = minSize;
}

- (void) setPaletteLabel: (NSString *)paletteLabel
{
  ASSIGN(_paletteLabel, paletteLabel);
}

- (void) setTag: (int)tag
{
  if(_flags._tag)
    [_backView setTag: tag];
}

- (void) setTarget: (id)target
{
   if(_flags._target)
     {
       if ([_backView isKindOfClass: [NSButton class]])
         [(NSButton *)_backView setTarget: target];
     }
}

- (void) setToolTip: (NSString *)toolTip
{
  ASSIGN(_toolTip, toolTip);
}

- (void) setView: (NSView *)view
{
  ASSIGN(_view, view);
  
  if (_view == nil)
    {
      // gets
      _flags._isEnabled  = [_backView respondsToSelector: @selector(isEnabled)];
      _flags._action     = [_backView respondsToSelector: @selector(toolbarItemAction)];
      _flags._target     = [_backView respondsToSelector: @selector(target)];
      _flags._image      = [_backView respondsToSelector: @selector(image)];
      // sets
      _flags._setEnabled = [_backView respondsToSelector: @selector(setEnabled:)];
      _flags._setAction  = [_backView respondsToSelector: @selector(setToolbarItemAction:)];
      _flags._setTarget  = [_backView respondsToSelector: @selector(setTarget:)];
      _flags._setImage   = [_backView respondsToSelector: @selector(setImage:)];
    }
  else
    {
      // gets
      _flags._isEnabled  = [_view respondsToSelector: @selector(isEnabled)];
      _flags._action     = [_view respondsToSelector: @selector(action)];
      _flags._target     = [_view respondsToSelector: @selector(target)];
      _flags._image      = [_backView respondsToSelector: @selector(image)];
      // sets
      _flags._setEnabled = [_view respondsToSelector: @selector(setEnabled:)];
      _flags._setAction  = [_view respondsToSelector: @selector(setAction:)];
      _flags._setTarget  = [_view respondsToSelector: @selector(setTarget:)];
      _flags._setImage   = [_backView respondsToSelector: @selector(setImage:)];
    }
  
  [_backView release];
  _backView = [[GSToolbarBackView alloc] initWithToolbarItem: self];
}

- (int) tag
{
  if(_flags._tag)
    return [_backView tag];

  return 0;
}

- (NSString *) toolTip
{
  return _toolTip;
}

- (GSToolbar *) toolbar
{
  return _toolbar;
}

- (void) validate
{
  // validate by default, we know that all of the
  // "standard" items are correct.
  NSMenuItem *menuItem = [self menuFormRepresentation];
  id target = [self target];
  
  if ([[self toolbar] displayMode] == NSToolbarDisplayModeLabelOnly && menuItem != nil)
    {
      if ([target respondsToSelector: @selector(validateMenuItem:)])
        [self setEnabled: [target validateMenuItem: menuItem]];
    }
  else
    {
      if ([target respondsToSelector: @selector(validateToolbarItem:)])
        [self setEnabled: [target validateToolbarItem: self]];
    } 
}

- (NSView *) view
{
  return _view;
}

// Private or package like visibility methods

- (NSView *) _backView
{
  return _backView;
}

- (NSMenuItem *) _defaultMenuFormRepresentation
{
  NSMenuItem *menuItem;
  
  menuItem = [[NSMenuItem alloc] initWithTitle: [self label]  
                                        action: [self action] 
                                 keyEquivalent: @""];
  [menuItem setTarget: [self target]];
  AUTORELEASE(menuItem);
  
  return menuItem;
}

- (void) _layout
{
  [(id)_backView layout];
}

- (BOOL) _isModified
{
  return _modified;
}

- (BOOL) _isFlexibleSpace
{
  return [self isKindOfClass: [GSToolbarFlexibleSpaceItem class]];
}

- (void) _setToolbar: (GSToolbar *)toolbar
{
  ASSIGN(_toolbar, toolbar);
}

// NSValidatedUserInterfaceItem protocol
- (SEL) action
{
  if(_flags._action)
    {
      if ([_backView isKindOfClass: [GSToolbarButton class]])
        return [(GSToolbarButton *)_backView toolbarItemAction];
    }
  return 0;
}

- (id) target
{
  if(_flags._target)
    {
      if ([_backView isKindOfClass: [NSButton class]])
        return [(NSButton *)_backView target];
    }

  return nil;
}

// NSCopying protocol
- (id) copyWithZone: (NSZone *)zone 
{
  NSToolbarItem *new = [[NSToolbarItem allocWithZone: zone] initWithItemIdentifier: _itemIdentifier];

  // copy all items individually...
  [new setTarget: [self target]];
  [new setAction: [self action]];
  [new setView: [self view]];
  [new setToolTip: [[self toolTip] copyWithZone: zone]];
  [new setTag: [self tag]];
  [new setImage: [[self image] copyWithZone: zone]];
  [new setEnabled: [self isEnabled]];
  [new setPaletteLabel: [[self paletteLabel] copyWithZone: zone]];
  [new setMinSize: NSMakeSize(_minSize.width, _minSize.height)];
  [new setMaxSize: NSMakeSize(_maxSize.width, _maxSize.height)];

  return self;
}

@end

/* Implementation of class NSGridView
   Copyright (C) 2020 Free Software Foundation, Inc.
   
   By: Gregory John Casamento
   Date: 08-08-2020

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import <Foundation/NSArray.h>
#import "AppKit/NSGridView.h"
#import "GSFastEnumeration.h"

@implementation NSGridView

+ (void) initialize
{
  if (self == [NSGridView class])
    {
      [self setVersion: 1];
    }
}

- (void) _refreshCells
{
  NSUInteger i = 0;
  NSUInteger num_col = [self numberOfColumns];
  // NSUInteger num_rows = [self numberOfRows];
  NSRect f = [self frame];
  CGFloat current_x = 0.0, current_y = f.size.height;
  NSMutableArray *colWidths = [NSMutableArray array];
  NSMutableArray *rowHeights = [NSMutableArray array];
  
  FOR_IN(NSGridCell*, c, _cells)
    {
      NSView *v = [c contentView];
      if (v != nil)
        {
          NSUInteger ri = 0, ci = 0;
          
          // Get row and column index...
          ci = i % num_col;
          ri = i / num_col;
          
          // Get the row and col...
          NSGridRow *row = [self rowAtIndex: ri];
          NSGridColumn *col = [self columnAtIndex: ci];
          
          // Do the math for the frame...
          NSRect rect = [v frame];
          // NOTE: I am not sure why this is needed, the row and column heights are coming in via the nib
          // as VERY small numbers (1.175... e-38) (see PR for this work, I have attached the XML nib there)
          // so it is necessary to figure out the width of each column so that things can be properly spaced.
          if (ci == 0)
            {
              current_y -= rect.size.height;
              current_x = 0.0;
              [rowHeights addObject: [NSNumber numberWithFloat: rect.size.height]];
            }

          if (ri == 0)
            {
              [colWidths addObject: [NSNumber numberWithFloat: rect.size.width]];
              NSLog(@"colWidths = %@", colWidths);
            }
          
          current_y -= [c yPlacement] - [row topPadding];
          current_x += [c xPlacement] + [col leadingPadding] + [col width];
          rect.origin.x = current_x;
          rect.origin.y = current_y;
          [v setFrame: rect];
          current_x += [col trailingPadding] + [col width] + [[colWidths objectAtIndex: ci] floatValue] + _columnSpacing;
          current_y -= [row bottomPadding] - [row height]; // - _rowSpacing; // add paddings after view...
          [self addSubview: v];

          // inc
          i++;
        }
    }
  END_FOR_IN(_cells)
}

- (instancetype) initWithFrame: (NSRect)frameRect
{
  self = [super initWithFrame: frameRect];

  if (self != nil)
    {
      _rows = [[NSMutableArray alloc] init];
      _columns = [[NSMutableArray alloc] init];
      _cells = [[NSMutableArray alloc] init];
    }

  [self _refreshCells];
  
  return self;
}

- (instancetype) initWithViews: (NSArray *)rows
{
  self = [self initWithFrame: NSZeroRect];

  NSUInteger c = 0;
  NSUInteger r = 0;

  if (self != nil)
    {
      _cells = [[NSMutableArray alloc] init];
      FOR_IN(NSArray*, row, rows)
        {
          NSArray *columns = [row objectAtIndex: c];
          FOR_IN(NSArray*, column, columns)
            {
              NSView *v = [column objectAtIndex: c];
              NSGridCell *cell = [[NSGridCell alloc] init];
              [cell setContentView: v];
              [_cells addObject: cell];
              c++;
            }
          END_FOR_IN(columns);
          r++;
        }
      END_FOR_IN(rows);
    }

  _rows = [[NSMutableArray alloc] initWithCapacity: r];
  _columns = [[NSMutableArray alloc] initWithCapacity: c];

  NSUInteger i = 0;
  for (i = 0; i < r; i++)
    {
      [_rows addObject: [[NSGridRow alloc] init]];
    }
  for (i = 0; i < r; i++)
    {
      [_columns addObject: [[NSGridColumn alloc] init]];
    }
  [self _refreshCells];
  
  return self;
}

+ (instancetype) gridViewWithNumberOfColumns: (NSInteger)columnCount rows: (NSInteger)rowCount
{
  NSUInteger r = 0;
  NSUInteger c = 0;
  NSMutableArray *rows = [[NSMutableArray alloc] initWithCapacity: rowCount];
  
  for (r = 0; r < rowCount; r++)
    {
      NSMutableArray *col = [[NSMutableArray alloc] initWithCapacity: columnCount];
      for (c = 0; c < columnCount; c++)
        {
          NSGridCell *gc = [[NSGridCell alloc] init];
          [col addObject: gc];
          RELEASE(gc);
        }
      [rows addObject: col];
    }

  return AUTORELEASE([self gridViewWithViews: rows]);
}

+ (instancetype) gridViewWithViews: (NSArray *)rows
{
  return [[self alloc] initWithViews: rows];
}

- (NSInteger) numberOfRows
{
  return [_rows count];
}

- (NSInteger) numberOfColumns
{
  return [_columns count];
}

- (NSGridRow *) rowAtIndex: (NSInteger)index
{
  return [_rows objectAtIndex: index];
}

- (NSInteger) indexOfRow: (NSGridRow *)row
{
  return [_rows indexOfObject: row];
}

- (NSGridColumn *) columnAtIndex: (NSInteger)index
{
  return [_columns objectAtIndex: index];
}

- (NSInteger) indexOfColumn: (NSGridColumn *)column
{
  return [_columns indexOfObject: column];
}

- (NSGridCell *) cellAtColumnIndex: (NSInteger)columnIndex rowIndex: (NSInteger)rowIndex
{
  NSUInteger idx = rowIndex * [self numberOfColumns] + columnIndex;
  return [_cells objectAtIndex: idx];
}

- (NSGridCell *) cellForView: (NSView*)view
{
  NSGridCell *result = nil;

  FOR_IN(NSGridCell*, c, _cells)
    {
      NSView *v = [c contentView];
      if (v == view)
        {
          result = c;
          break;
        }
    }
  END_FOR_IN(_cells);

  return result;
}

- (NSGridRow *) addRowWithViews: (NSArray *)views
{
  return [self insertRowAtIndex: [_rows count]
                      withViews: views];
}

- (NSGridRow *) insertRowAtIndex: (NSInteger)index withViews: (NSArray *)views
{
  NSGridRow *gr = [[NSGridRow alloc] init];

  // Insert the row and release...
  [_rows insertObject: gr atIndex: index];
  RELEASE(gr);

  // Insert views...
  FOR_IN(NSView*, v, views)
    {
      NSGridCell *c = [[NSGridCell alloc] init];
      [c setContentView: v];
      RELEASE(v);
      // [gr _addCell: c];
    }
  END_FOR_IN(views);
  
  // Refresh...
  [self _refreshCells];
  return gr;
}

- (void) moveRowAtIndex: (NSInteger)fromIndex toIndex: (NSInteger)toIndex
{
  [self _refreshCells];
}

- (void) removeRowAtIndex: (NSInteger)index
{
  [_rows removeObjectAtIndex: index];
  [self _refreshCells];
}

- (NSGridColumn *) addColumnWithViews: (NSArray*)views
{
  return [self insertColumnAtIndex: [_columns count]
                         withViews: views];
}

- (NSGridColumn *) insertColumnAtIndex: (NSInteger)index withViews: (NSArray *)views
{
  NSGridColumn *gc = [[NSGridColumn alloc] init];  
  [self _refreshCells];
  return gc;
}

- (void) moveColumnAtIndex: (NSInteger)fromIndex toIndex: (NSInteger)toIndex
{
  [self _refreshCells]; 
}

- (void) removeColumnAtIndex: (NSInteger)index
{
  [_columns removeObjectAtIndex: index];
  [self _refreshCells];
}

- (NSGridCellPlacement) xPlacement
{
  return _xPlacement;
}

- (void) setXPlacement: (NSGridCellPlacement)x;
{
  _xPlacement = x;
}

- (NSGridCellPlacement) yPlacement;
{
  return _yPlacement;
}

- (void) setYPlacement: (NSGridCellPlacement)y;
{
  _yPlacement = y;
}

- (NSGridRowAlignment) rowAlignment;
{
  return _rowAlignment;
}

- (void) setRowAlignment: (NSGridRowAlignment)a;
{
  _rowAlignment = a;
}

- (CGFloat) rowSpacing
{
  return _rowSpacing;
}

- (void) setRowSpacing: (CGFloat)f
{
  _rowSpacing = f;
}

- (CGFloat) columnSpacing
{
  return _columnSpacing;
}

- (void) setColumnSpacing: (CGFloat)f
{
  _columnSpacing = f;
}
  
- (void) mergeCellsInHorizontalRange: (NSRange)hRange verticalRange: (NSRange)vRange
{
  [self _refreshCells]; 
}

// coding
- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _rowAlignment
                    forKey: @"NSGrid_alignment"];
      [coder encodeFloat: _columnSpacing
                  forKey: @"NSGrid_columnSpacing"];
      [coder encodeObject: _columns
                   forKey: @"NSGrid_columns"];
      [coder encodeFloat: _rowSpacing
                  forKey: @"NSGrid_rowSpacing"];
      [coder encodeObject: _rows
                   forKey: @"NSGrid_rows"];
      [coder encodeInteger: _xPlacement
                    forKey: @"NSGrid_xPlacement"];
      [coder encodeInteger: _yPlacement forKey: @"NSGrid_yPlacement"];
      [coder encodeObject: _cells
                   forKey: @"NSGrid_cells"];
    }
  else
    {
      [coder encodeValueOfObjCType:@encode(NSUInteger)
                                at:&_rowAlignment];
      [coder encodeObject: _columns];
      [coder encodeObject: _rows];
      [coder encodeObject: _cells];
      [coder encodeValueOfObjCType:@encode(CGFloat)
                                at:&_columnSpacing];
      [coder encodeValueOfObjCType:@encode(CGFloat)
                                at:&_rowSpacing];
      [coder encodeValueOfObjCType:@encode(NSUInteger)
                                at:&_xPlacement];
      [coder encodeValueOfObjCType:@encode(NSUInteger)
                                at:&_yPlacement];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      NSLog(@"%@ %@",NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSGrid_alignment"])
            {
              _rowAlignment = (NSGridRowAlignment)[coder decodeIntegerForKey: @"NSGrid_alignment"];
              NSDebugLog(@"_rowAlignment = %ld", _rowAlignment);
            }
          if ([coder containsValueForKey: @"NSGrid_columns"])
            {
              ASSIGN(_columns, [coder decodeObjectForKey: @"NSGrid_columns"]);
              NSDebugLog(@"_columns = %@", _columns);
            }
          if ([coder containsValueForKey: @"NSGrid_rows"])
            {
              ASSIGN(_rows, [coder decodeObjectForKey: @"NSGrid_rows"]);
              NSDebugLog(@"_rows = %@", _rows);
            }
          if ([coder containsValueForKey: @"NSGrid_cells"])
            {
              ASSIGN(_cells, [coder decodeObjectForKey: @"NSGrid_cells"]);
              NSDebugLog(@"_cells = %@", _cells);
            }
          if ([coder containsValueForKey: @"NSGrid_columnSpacing"])
            {
              _columnSpacing = [coder decodeFloatForKey: @"NSGrid_columnSpacing"];
              NSDebugLog(@"_columnSpacing = %f", _columnSpacing);
            }
          if ([coder containsValueForKey: @"NSGrid_rowSpacing"])
            {
              _rowSpacing = [coder decodeFloatForKey: @"NSGrid_rowSpacing"];
              NSDebugLog(@"_rowSpacing = %f", _rowSpacing);
            }
          if ([coder containsValueForKey: @"NSGrid_xPlacement"])
            {
              _xPlacement = [coder decodeIntegerForKey: @"NSGrid_xPlacement"];
              NSDebugLog(@"_xPlacement = %ld", _xPlacement);
            }
          if ([coder containsValueForKey: @"NSGrid_yPlacement"])
            {
              _yPlacement = [coder decodeIntegerForKey: @"NSGrid_yPlacement"];
              NSDebugLog(@"_yPlacement = %ld", _yPlacement);
            }
        }
      else
        {
          [coder decodeValueOfObjCType:@encode(NSUInteger)
                                    at:&_rowAlignment];
          ASSIGN(_columns, [coder decodeObject]);
          ASSIGN(_rows, [coder decodeObject]);
          ASSIGN(_cells, [coder decodeObject]);
          [coder decodeValueOfObjCType:@encode(CGFloat)
                                    at:&_columnSpacing];
          [coder decodeValueOfObjCType:@encode(CGFloat)
                                    at:&_rowSpacing];
          [coder decodeValueOfObjCType:@encode(NSUInteger)
                                    at:&_xPlacement];
          [coder decodeValueOfObjCType:@encode(NSUInteger)
                                    at:&_yPlacement];
        }
    }
  
  [self _refreshCells];
  
  return self;
}

- (void) dealloc
{
  RELEASE(_columns);
  RELEASE(_rows);
  RELEASE(_cells);
  [super dealloc];
}

@end

/// Cell ///
@implementation NSGridCell

+ (void) initialize
{
  if (self == [NSGridCell class])
    {
      [self setVersion: 1];
    }
}
 
- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      [self setContentView: [[self class] emptyContentView]]; 
    }
  return self;
}

- (NSView *) contentView
{
  return _contentView;
}

- (void) setContentView: (NSView *)v
{
  ASSIGN(_contentView, v);
}
  
+ (NSView *) emptyContentView
{
  return AUTORELEASE([[NSView alloc] initWithFrame: NSZeroRect]);
}

// Weak references to row/column
- (NSGridRow *) row
{
  return _owningRow;
}

- (NSGridColumn *) column
{
  return _owningColumn;
}

// Placement
- (NSGridCellPlacement) xPlacement
{
  return _xPlacement;
}

- (void) setXPlacement: (NSGridCellPlacement)x
{
  _xPlacement = x;
}

- (NSGridCellPlacement) yPlacement
{
  return _yPlacement;
}

- (void) setYPlacement: (NSGridCellPlacement)y
{
  _yPlacement = y;
}

- (NSGridRowAlignment) rowAlignment
{
  return _rowAlignment;
}

- (void) setRowAlignment: (NSGridRowAlignment)a
{
  _rowAlignment = a;
}

// Constraints
- (NSArray *) customPlacementConstraints
{
  return nil;
}

// coding
- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _contentView
                   forKey: @"NSGrid_content"];
      [coder encodeObject: _mergeHead
                   forKey: @"NSGrid_mergeHead"];
      [coder encodeObject: _owningRow
                   forKey: @"NSGrid_owningRow"]; // weak
      [coder encodeObject: _owningColumn
                   forKey: @"NSGrid_owningColumn"]; // weak
      [coder encodeInteger: _xPlacement
                    forKey: @"NSGrid_xPlacement"];
      [coder encodeInteger: _yPlacement
                    forKey: @"NSGrid_yPlacement"];
      [coder encodeInteger: _rowAlignment
                    forKey: @"NSGrid_alignment"];
    }
  else
    {
      [coder encodeObject: [self contentView]];
      [coder encodeObject: _mergeHead];
      [coder encodeObject: _owningRow];
      [coder encodeObject: _owningColumn];
      [coder encodeValueOfObjCType:@encode(NSInteger)
                                at: &_xPlacement];
      [coder encodeValueOfObjCType:@encode(NSInteger)
                                at: &_yPlacement];
      [coder encodeValueOfObjCType:@encode(NSInteger)
                                at: &_rowAlignment];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super init];
  if (self != nil)
    {
      NSDebugLog(@"%@ %@",NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSGrid_content"])
            {
              [self setContentView: [coder decodeObjectForKey: @"NSGrid_content"]];
              // NSDebugLog(@"contentView = %@", [self contentView]);
            }
          if ([coder containsValueForKey: @"NSGrid_mergeHead"])
            {
              _mergeHead = [coder decodeObjectForKey: @"NSGrid_mergeHead"];
            }
          if ([coder containsValueForKey: @"NSGrid_owningRow"])
            {
              _owningRow = [coder decodeObjectForKey: @"NSGrid_owningRow"]; // weak
              NSDebugLog(@"_owningRow = %@", _owningRow);
              // [_owningRow _addCell: self];
            }
          if ([coder containsValueForKey: @"NSGrid_owningColumn"])
            {
              _owningColumn = [coder decodeObjectForKey: @"NSGrid_owningColumn"]; // weak
              NSDebugLog(@"_owningColumn = %@", _owningColumn);
              // [_owningColumn _addCell: self];
            }
          if ([coder containsValueForKey: @"NSGrid_xPlacement"])
            {
              _xPlacement = [coder decodeIntegerForKey: @"NSGrid_xPlacement"];
            }      
          if ([coder containsValueForKey: @"NSGrid_yPlacement"])
            {
              _yPlacement = [coder decodeIntegerForKey: @"NSGrid_yPlacement"];
            }  
          if ([coder containsValueForKey: @"NSGrid_alignment"])
            {
              _rowAlignment = [coder decodeIntegerForKey: @"NSGrid_alignment"];
            }      
        }
      else
        {
          [self setContentView: [coder decodeObject]];
          ASSIGN(_mergeHead, [coder decodeObject]);
          _owningRow = [coder decodeObject]; // weak
          // [_owningRow _addCell: self];
          _owningColumn = [coder decodeObject]; // weak
          // [_owningRow _addCell: self];
          [coder decodeValueOfObjCType: @encode(NSInteger)
                                    at: &_xPlacement];
          [coder decodeValueOfObjCType:@encode(NSInteger)
                                    at: &_yPlacement];
          [coder decodeValueOfObjCType:@encode(NSInteger)
                                    at: &_rowAlignment];
        }
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_contentView);
  RELEASE(_mergeHead);
  [super dealloc];
}

@end

/// Column ///
@implementation NSGridColumn

+ (void) initialize
{
  if (self == [NSGridColumn class])
    {
      [self setVersion: 1];
    }
}

- (NSGridView *) gridView
{
  return _gridView;
}

- (NSInteger) numberOfCells
{
  return 0; // refer to gridView here... [_cells count];
}

- (NSGridCell *) cellAtIndex:(NSInteger)index
{
  return nil; // refer to gridview here... [_cells objectAtIndex: index];
}

- (NSGridCellPlacement) xPlacement
{
  return _xPlacement;
}

- (void) setXPlacement: (NSGridCellPlacement)x
{
  _xPlacement = x;
}

- (CGFloat) width
{
  return _width;
}

- (void) setWidth: (CGFloat)f
{
  _width = f;
}

- (CGFloat) leadingPadding
{
  return _leadingPadding;
}

- (void) setLeadingPadding: (CGFloat)f
{
  _leadingPadding = f;
}

- (CGFloat) trailingPadding
{
  return _trailingPadding;
}

- (void) setTrailingPadding: (CGFloat)f
{
  _trailingPadding = f;
}

- (BOOL) isHidden
{
  return _isHidden;
}

- (void) mergeCellsInRange: (NSRange)range
{
}

// coding
- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeBool: _isHidden
                 forKey: @"NSGrid_hidden"];
      [coder encodeFloat: _leadingPadding
                  forKey: @"NSGrid_leadingPadding"];
      [coder encodeObject: _gridView
                   forKey: @"NSGrid_owningGrid"]; // weak
      [coder encodeFloat: _trailingPadding
                  forKey: @"NSGrid_trailingPadding"];
      [coder encodeFloat: _width
                  forKey: @"NSGrid_width"];
      [coder encodeInteger: _xPlacement
                    forKey: @"NSGrid_xPlacement"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(BOOL)
                                at: &_isHidden];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_leadingPadding];
      [coder encodeObject: _gridView];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_trailingPadding];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_width];
      [coder encodeValueOfObjCType: @encode(NSInteger)
                                at: &_xPlacement];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super init];
  if (self != nil)
    {
      NSDebugLog(@"%@ %@",NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      // _cells = [[NSMutableArray alloc] initWithCapacity: 10];
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSGrid_hidden"])
            {
              _isHidden = [coder decodeBoolForKey: @"NSGrid_hidden"];
            }
          if ([coder containsValueForKey: @"NSGrid_leadingPadding"])
            {
              _leadingPadding = [coder decodeFloatForKey: @"NSGrid_leadingPadding"];
            }
          if ([coder containsValueForKey: @"NSGrid_owningGrid"])
            {
              _gridView = [coder decodeObjectForKey: @"NSGrid_owningGrid"]; // weak
            }
          if ([coder containsValueForKey: @"NSGrid_trailingPadding"])
            {
              _trailingPadding = [coder decodeFloatForKey: @"NSGrid_trailingPadding"];
            }
          if ([coder containsValueForKey: @"NSGrid_width"])
            {
              _width = [coder decodeFloatForKey: @"NSGrid_width"];
              NSLog(@"_width = %f", _width);
            }
          if ([coder containsValueForKey: @"NSGrid_xPlacement"])
            {
              _xPlacement = [coder decodeIntegerForKey: @"NSGrid_xPlacement"];
            }      
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(BOOL)
                                    at: &_isHidden];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_leadingPadding];
          _gridView = [coder decodeObject]; 
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_trailingPadding];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_width];
          [coder decodeValueOfObjCType: @encode(NSInteger)
                                    at: &_xPlacement];
        }
    }
  return self;
}

@end

/// Row ///
@implementation NSGridRow

+ (void) initialize
{
  if (self == [NSGridRow class])
    {
      [self setVersion: 1];
    }
}

- (void) setGridView: (NSGridView *)gridView
{
  _gridView = gridView; // weak reference...
}

- (NSGridView *) gridView
{
  return _gridView;
}

- (NSInteger) numberOfCells
{
  return 0; // reference gridview here... [_cells count];
}

- (NSGridCell *) cellAtIndex:(NSInteger)index
{
  return nil; // reference gridview here... [_cells objectAtIndex: index];
}

- (NSGridCellPlacement) yPlacement
{
  return _yPlacement;
}

- (void) setYPlacement: (NSGridCellPlacement)y
{
  _yPlacement = y;
}

- (CGFloat) height
{
  return _height;
}

- (void) setHeight: (CGFloat)f
{
  _height = f;
}

- (CGFloat) topPadding
{
  return _topPadding;
}

- (void) setTopPadding: (CGFloat)f
{
  _topPadding = f;
}

- (CGFloat) bottomPadding
{
  return _bottomPadding;
}

- (void) setBottomPadding: (CGFloat)f
{
  _bottomPadding = f;
}

- (BOOL) isHidden
{
  return _isHidden;
}

- (void) setHidden: (BOOL)flag
{
  _isHidden = flag;
}

- (void) mergeCellsInRange: (NSRange)range
{
}

// coding
- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeBool: _isHidden forKey: @"NSGrid_hidden"];
      [coder encodeFloat: _bottomPadding forKey: @"NSGrid_bottomPadding"];
      [coder encodeObject: _gridView forKey: @"NSGrid_owningGrid"];
      [coder encodeFloat: _topPadding forKey: @"NSGrid_topPadding"];
      [coder encodeFloat: _height forKey: @"NSGrid_height"];
      [coder encodeFloat: _yPlacement forKey: @"NSGrid_yPlacement"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(BOOL)
                                at: &_isHidden];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_bottomPadding];
      [coder encodeObject: _gridView];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_topPadding];
      [coder encodeValueOfObjCType: @encode(CGFloat)
                                at: &_height];
      [coder encodeValueOfObjCType: @encode(NSInteger)
                                at: &_yPlacement];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super init];
  if (self != nil)
    {
      NSDebugLog(@"%@ %@",NSStringFromClass([self class]), NSStringFromSelector(_cmd));
      // _cells = [[NSMutableArray alloc] initWithCapacity: 10];
      if ([coder allowsKeyedCoding])
        {
          if ([coder containsValueForKey: @"NSGrid_hidden"])
            {
              _isHidden = [coder decodeBoolForKey: @"NSGrid_hidden"];
            }
          if ([coder containsValueForKey: @"NSGrid_bottomPadding"])
            {
              _bottomPadding = [coder decodeFloatForKey: @"NSGrid_bottomPadding"];
            }
          if ([coder containsValueForKey: @"NSGrid_owningGrid"])
            {
              _gridView = [coder decodeObjectForKey: @"NSGrid_owningGrid"];
            }
          if ([coder containsValueForKey: @"NSGrid_topPadding"])
            {
              _topPadding = [coder decodeFloatForKey: @"NSGrid_topPadding"];
            }
          if ([coder containsValueForKey: @"NSGrid_height"])
            {
              _height = [coder decodeFloatForKey: @"NSGrid_height"];
              NSLog(@"_height = %f", _height);
            }
          if ([coder containsValueForKey: @"NSGrid_yPlacement"])
            {
              _yPlacement = [coder decodeFloatForKey: @"NSGrid_yPlacement"];
            }
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(BOOL)
                                    at: &_isHidden];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_bottomPadding];
          _gridView = [coder decodeObject]; 
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_topPadding];
          [coder decodeValueOfObjCType: @encode(CGFloat)
                                    at: &_height];
          [coder decodeValueOfObjCType: @encode(NSInteger)
                                    at: &_yPlacement];
        }
    }
  return self;
}

@end

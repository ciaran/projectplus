#import <Cocoa/Cocoa.h>
#import "TextMate.h"
#import "ProjectPlus.h"

@interface TMLabels : NSObject
{
}
+ (void)setColour:(int)colourIndex forPath:(NSString*)path;
+ (int)colourIndexForPath:(NSString*)path;
+ (NSColor*)colourForPath:(NSString*)path;
+ (float)labelOpacity;
+ (BOOL)useLabels;
+ (void)drawLabelIndex:(int)colourIndex inRect:(NSRect)rect;
@end

void Interpolate (void* info, float const* inData, float *outData)
{
   NSColor** cols = (NSColor**)info;

   float from[4], to[4];
   [cols[0] getComponents:&from[0]];
   [cols[1] getComponents:&to[0]];

   float a = inData[0];
   for(int i = 0; i < 4; i++)
      outData[i] = (1.0f-a)*from[i] + a*to[i];
}

@interface NSColor (HexColor)
+ (NSColor*)colorWithRRGGBB:(uint32_t)value;
@end

@implementation NSColor (HexColor)
+ (NSColor*)colorWithRRGGBB:(uint32_t)value
{
   float red   = ((value & 0xFF0000) >> 16) / 255.0f;
   float green = ((value & 0x00FF00) >>  8) / 255.0f;
   float blue  = ((value & 0x0000FF) >>  0) / 255.0f;
   return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0f];
}
@end

@interface NSBezierPath (RoundedRectangle)
+ (NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;
@end

@implementation NSBezierPath (RoundedRectangle)
+ (NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius
{
   NSBezierPath* path = [self bezierPath];
   // radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
   NSRect rect = NSInsetRect(aRect, radius, radius);
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
   [path closePath];
   return path;
}

- (void)fillWithGradientFrom:(NSColor*)startCol to:(NSColor*)endCol
{
   struct CGFunctionCallbacks callbacks = { 0, Interpolate, NULL };

   NSColor* cols[2] = { startCol, endCol };
   CGFunctionRef function = CGFunctionCreate(
      &cols[0],   // void *info,
      1,          // size_t domainDimension,
      NULL,       // float const* domain,
      4,          // size_t rangeDimension,
      NULL,       // float const* range,
      &callbacks  // CGFunctionCallbacks const* callbacks
   );

   CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();

   NSRect bounds = [self bounds];
   float srcX = NSMinX(bounds), srcY = NSMinY(bounds);
   float dstX = NSMinX(bounds), dstY = NSMaxY(bounds);
   CGShadingRef shading = CGShadingCreateAxial(
      cspace,                    // CGColorSpaceRef colorspace,
      CGPointMake(srcX, srcY),   // CGPoint start,
      CGPointMake(dstX, dstY),   // CGPoint end,
      function,                  // CGFunctionRef function,
      false,                     // bool extendStart,
      false                      // bool extendEnd
   );

   [NSGraphicsContext saveGraphicsState];
   [self addClip];
   CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
   CGContextDrawShading(context, shading);
   [NSGraphicsContext restoreGraphicsState];

   CGShadingRelease(shading);
   CGColorSpaceRelease(cspace);
   CGFunctionRelease(function);
}
@end


#define LIST_OFFSET    5
#define ICON_SIZE     15

#define DEFAULT_COLOUR_OPACITY 0.5

struct Colour {
	NSString *name;
	NSColor *colour;
} colours[] = {
	{@"None",	nil},
	{@"Gray",	[NSColor grayColor]},
	{@"Green",	[NSColor greenColor]},
	{@"Purple",	[NSColor purpleColor]},
	{@"Blue",	[NSColor blueColor]},
	{@"Yellow",	[NSColor yellowColor]},
	{@"Red",		[NSColor redColor]},
	{@"Orange",	[NSColor orangeColor]},
};

@implementation NSOutlineView (LabeledOutlineView)
- (void)drawLabelForRow:(int)rowNumber
{
	NSDictionary *item = [self itemAtRow:rowNumber];
	if (item) {
		NSString *path = [item objectForKey:@"filename"];
		if (!path) path = [item objectForKey:@"sourceDirectory"];

		int labelColorIndex = [TMLabels colourIndexForPath:path];
		if (labelColorIndex > 0) {
			NSRect r = NSIntegralRect(NSInsetRect([self rectOfRow:rowNumber], 2.0f, 0.0f));
			r.origin.y += 0.0f;
			r.size.height -= 1.0f;

			if([self isRowSelected:rowNumber])
				r.size.width = 15.0f;

			[TMLabels drawLabelIndex:labelColorIndex inRect:r];
		}
	}
}

- (void)drawSelectedLabelForRow:(int)rowNumber
{
	NSDictionary *item = [self itemAtRow:rowNumber];
	if (item) {
		NSString *path = [item objectForKey:@"filename"];
		if (!path) path = [item objectForKey:@"sourceDirectory"];

		int labelColorIndex = [TMLabels colourIndexForPath:path];
		if (labelColorIndex > 0) {
			NSRect r = NSIntegralRect(NSInsetRect([self rectOfRow:rowNumber], 2.0f, 0.0f));
			r.origin.y += 1.0f;
			r.size.height = 12;

			r.size.width = 15.0f;

			NSRect rect = [self rectOfRow:rowNumber];
			rect.origin.x = LIST_OFFSET + [self levelForRow:rowNumber] * ICON_SIZE + 1;
			rect.origin.y += 2;
			rect.size.width  = 12;
			rect.size.height = 12;

			[TMLabels drawLabelIndex:labelColorIndex inRect:rect];
		}
	}
}

- (void)labeledHighlightSelectionInClipRect:(NSRect)clipRect
{
	if([TMLabels useLabels])
	{
		NSRange rows = [self rowsInRect:clipRect];

		int rowNumber = rows.location;
		while (rowNumber <= rows.location + rows.length)
			[self drawLabelForRow:rowNumber++];
	}

	[self labeledHighlightSelectionInClipRect:clipRect];
	
	if([TMLabels useLabels])
	{
		NSRange     visibleRowIndexes   = [self rowsInRect:clipRect];
		NSIndexSet *selectedRowIndexes  = [self selectedRowIndexes];
	
		int row;
		int endRow;
	
		for (row = visibleRowIndexes.location, endRow = row + visibleRowIndexes.length; row < endRow ; row++) {
			if ([selectedRowIndexes containsIndex: row])
				[self drawSelectedLabelForRow:row];
		}
	}
}
@end

@implementation NSButton (ProjectContextMenu)
- (NSArray*)selectedItems
{
	NSOutlineView *outlineView = [self valueForKey:@"outlineView"];
	NSIndexSet *selectedRows = [outlineView selectedRowIndexes];
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:[selectedRows count]];

	int rowIndex = [selectedRows firstIndex];
	do {
		[items addObject:[outlineView itemAtRow:rowIndex]];
	} while ((rowIndex = [selectedRows indexGreaterThanIndex:rowIndex]) != NSNotFound);

	return items;
}

- (BOOL)myValidateMenuItem:(id <NSMenuItem>)menuItem
{
	if ([menuItem action] == @selector(setColourLabel:)) {
		NSArray *items = [self selectedItems];
		unsigned int itemCount = [items count];

		[menuItem setState:NSOffState];

		for (unsigned int index = 0; index < itemCount; index += 1) {
			NSDictionary *item = [items objectAtIndex:index];
			NSString *path = [item objectForKey:@"filename"];
			if (!path) path = [item objectForKey:@"sourceDirectory"];

			if ([TMLabels colourIndexForPath:path] == [menuItem tag]) {
				[menuItem setState:NSOnState];
				break;
			}
		}
		return YES;
	}

	return [self myValidateMenuItem:menuItem];
}

- (void)setColourLabel:(id)sender
{
	NSArray *items = [self selectedItems];
	unsigned int itemCount = [items count];

	for (unsigned int index = 0; index < itemCount; index += 1) {
		NSDictionary *item = [items objectAtIndex:index];
		NSString *path = [item objectForKey:@"filename"];
		if (!path) path = [item objectForKey:@"sourceDirectory"];

		if (path)
			[TMLabels setColour:[sender tag] forPath:path];
	}
	
	[[self valueForKey:@"outlineView"] display];
}

- (void)labeledAwakeFromNib
{
	[self labeledAwakeFromNib];
	
	if(not [TMLabels useLabels])
		return;
	
	if(not [[self window] isKindOfClass:NSClassFromString(@"NSDrawerWindow")])
		return;

	NSMenu *menu = (NSMenu*)[self valueForKey:@"actionMenu"];
	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *colourMenu = [[NSMenuItem alloc] initWithTitle:@"Colour Label" action:nil keyEquivalent:@""];
	{
		NSMenu *colourSubMenu = [[NSMenu alloc] init];

		int colourCount = sizeof(colours) / sizeof(Colour);
		for (int index = 0; index < colourCount; index++) {
			Str255 str = { };
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:(noErr == GetLabel(index, NULL, str) ? [NSString stringWithCString:(char*)str] : colours[index].name)
                                                       action:@selector(setColourLabel:)
                                                keyEquivalent:@""];
			[item setTarget:self];
			[item setTag:index];
			if (colours[index].colour) {
				NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(32, 16)];
				{
					[image lockFocus];
					[TMLabels drawLabelIndex:index inRect:NSMakeRect(0, 0, 32, 16)];
					[image unlockFocus];
					[item setImage:image];
				}
				[image release];
			}
			[colourSubMenu addItem:item];
			[item release];
		}
	
		[colourMenu setSubmenu:colourSubMenu];
		[colourSubMenu release];
	}
	[menu addItem:colourMenu];
	[colourMenu release];
}
@end




@implementation TMLabels
+ (void)load
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
											[NSNumber numberWithFloat:DEFAULT_COLOUR_OPACITY],@"TMLabels Opacity",
											[NSNumber numberWithBool:YES],@"ProjectPlus Labels Enabled",
											nil]];
	
	[OakOutlineView jr_swizzleMethod:@selector(highlightSelectionInClipRect:) withMethod:@selector(labeledHighlightSelectionInClipRect:) error:NULL];

	[OakMenuButton jr_swizzleMethod:@selector(awakeFromNib) withMethod:@selector(labeledAwakeFromNib) error:NULL];
	[OakMenuButton jr_swizzleMethod:@selector(validateMenuItem:) withMethod:@selector(myValidateMenuItem:) error:NULL];
	
	[[ProjectPlus sharedInstance] watchDefaultsKey:@"ProjectPlus Labels Enabled"];
}

+ (int)colourIndexForPath:(NSString*)path
{
	OSStatus ret;
	OSErr err;
	FSRef ref;
	FSCatalogInfo info;
	UInt16 flags;
	int colour;

	ret = FSPathMakeRef ((UInt8*)[path UTF8String], &ref, NULL);

	if (ret != noErr)
		return nil;

	err = FSGetCatalogInfo (&ref, kFSCatInfoNodeFlags | kFSCatInfoFinderInfo, &info, NULL, NULL, NULL);

	if (err != noErr)
		return nil;

	if (info.nodeFlags & kFSNodeIsDirectoryMask) {
		FolderInfo *pinfo = (FolderInfo*)&info.finderInfo;

		flags = pinfo->finderFlags;
	} else {
		FileInfo *pinfo = (FileInfo*)&info.finderInfo;

		flags = pinfo->finderFlags;
	}

	colour = (flags & kColor) >> 1;

	return colour;
}

+ (NSColor*)colourForPath:(NSString*)path
{
	return colours[[self colourIndexForPath:path]].colour;
}

+ (void)setColour:(int)colourIndex forPath:(NSString*)path
{
	OSStatus ret;
	OSErr err;
	FSRef ref;
	FSCatalogInfo info;

	ret = FSPathMakeRef ((UInt8*)[path UTF8String], &ref, NULL);

	if (ret != noErr)
		return;

	err = FSGetCatalogInfo (&ref, kFSCatInfoNodeFlags | kFSCatInfoFinderInfo, &info, NULL, NULL, NULL);

	if (err != noErr)
		return;

	if (info.nodeFlags & kFSNodeIsDirectoryMask) {
		FolderInfo *pinfo = (FolderInfo*)&info.finderInfo;

		pinfo->finderFlags = (pinfo->finderFlags & ~kColor) | (colourIndex << 1);
	} else {
		FileInfo *pinfo = (FileInfo*)&info.finderInfo;

		pinfo->finderFlags = (pinfo->finderFlags & ~kColor) | (colourIndex << 1);
	}

	FSSetCatalogInfo (&ref, kFSCatInfoFinderInfo, &info);
}

+ (float)labelOpacity
{
	float opacity = [[NSUserDefaults standardUserDefaults] floatForKey:@"TMLabels Opacity"];
	
	if (opacity == 0)
		opacity = DEFAULT_COLOUR_OPACITY;

	return opacity;
}

+ (BOOL)useLabels
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Labels Enabled"];
}

+ (void)drawLabelIndex:(int)colourIndex inRect:(NSRect)rect
{
	// color names: Gray, Green, Purple, Blue, Yellow, Red, Orange
	// static uint32_t const startCol[] = { 0xCFCFCF, 0xD4EE9C, 0xDDBDEA, 0xACD0FE, 0xF8F79C, 0xB2B2B2, 0xF9D194 };
	static uint32_t const startCol[] = { 0xCFCFCF, 0xD4EE9C, 0xDDBDEA, 0xACD0FE, 0xF8F79C, 0xFFA09B, 0xF9D194 };
	static uint32_t const stopCol[]  = { 0xA8A8A8, 0xAFDC49, 0xC186D7, 0x5B9CFE, 0xECDF4A, 0xFC605C, 0xF6AC46 };

	NSBezierPath* path = [NSBezierPath bezierPathWithRoundRectInRect:rect radius:8.0f];
	NSColor *from      = [[NSColor colorWithRRGGBB:startCol[colourIndex-1]] colorWithAlphaComponent:[TMLabels labelOpacity]];
	NSColor *to        = [[NSColor colorWithRRGGBB:stopCol[colourIndex-1]] colorWithAlphaComponent:[TMLabels labelOpacity]];
	[path fillWithGradientFrom:from to:to];
}
@end

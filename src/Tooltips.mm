@implementation NSWindowController (Tooltips)
- (NSString*)outlineView:(NSOutlineView*)anOutlineView toolTipForCell:(NSCell*)aCell rect:(NSRectPointer)aRectPointer tableColumn:(NSTableColumn*)aTableColumn item:(id)anId mouseLocation:(NSPoint)aPoint
{
	NSString *tip = nil;

	if([[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Tooltips Enabled"])
	{
		NSString *name = [anId objectForKey:@"displayName"];
		NSSize nameSize = [name sizeWithAttributes:nil];

		if (nameSize.width < aRectPointer->size.width)
			name = nil;

		tip = name;
	}
	return tip;
}
@end

@interface ProjectPlus_Tooltips : NSObject
@end

@implementation ProjectPlus_Tooltips
+ (void)load
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:@"ProjectPlus Tooltips Enabled"]];
}
@end
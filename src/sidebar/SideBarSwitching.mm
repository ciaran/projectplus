#import "TextMate.h"
#import "CWTMSplitView.h"

@interface SideBarSwitching : NSObject
+ (BOOL)useSidebar;
+ (BOOL)sidebarOnRight;
@end

@interface NSWindowController (OakProjectController_Methods)
- (void)openProjectDrawer:(id)sender;
@end

@implementation NSWindowController (OakProjectController_SideBarSwitching)
- (BOOL)sidebarIsClosed
{
	CWTMSplitView* splitView = [[self window] contentView];
	return [splitView isSubviewCollapsed:[splitView drawerView]];
}

- (void)setSidebarIsClosed:(BOOL)closed
{
	CWTMSplitView* splitView = [[self window] contentView];
	[splitView setSubview:[splitView drawerView] isCollapsed:closed];
	[splitView resizeSubviewsWithOldSize:[splitView bounds].size];
}

- (void)SideBarSwitching_windowDidLoad
{
	[self SideBarSwitching_windowDidLoad];
	
	if(not [SideBarSwitching useSidebar])
		return;

	NSWindow* window     = [self window];
	NSDrawer* drawer     = [[window drawers] objectAtIndex:0];
	NSView* drawerView   = [[drawer contentView] retain];
	NSView* documentView = [[window contentView] retain];

	[drawer setContentView:nil];
	[window setContentView:nil];

	CWTMSplitView* splitView = [[CWTMSplitView alloc] initWithFrame:[documentView frame]];
	{
		[splitView setVertical:YES];
		[splitView setDelegate:self];
		[splitView setSideBarOnRight:[SideBarSwitching sidebarOnRight]];

		if(not [SideBarSwitching sidebarOnRight])
			[splitView addSubview:drawerView];
		[splitView addSubview:documentView];
		if([SideBarSwitching sidebarOnRight])
			[splitView addSubview:drawerView];
		[window setContentView:splitView];
	}
	[splitView release];

	[documentView release];
	[drawerView release];
	
	// Restoring from project
	NSDictionary *project = [NSDictionary dictionaryWithContentsOfFile:[self valueForKey:@"filename"]];
	if(project)
	{
		int sidebarWidth  = [[project objectForKey:@"fileHierarchyDrawerWidth"] intValue];
		int documentWidth = [splitView bounds].size.width - [splitView dividerThickness] - sidebarWidth;
		int height        = [splitView bounds].size.height;
		[[splitView drawerView] setFrameSize:NSMakeSize(sidebarWidth, height)];
		[[splitView documentView] setFrameSize:NSMakeSize(documentWidth, height)];
		
		BOOL closed = NO;
		NSNumber* flag = [project objectForKey:@"showFileHierarchyPanel"];
		if(flag)
			closed = ! [flag boolValue];

		[self setSidebarIsClosed:closed];
	}
	
	[drawer close];
}

- (void)SideBarSwitching_openProjectDrawer:(id)sender
{
	CWTMSplitView* splitView = [[self window] contentView];
	if(not [splitView isKindOfClass:[CWTMSplitView class]])
	{
		[self SideBarSwitching_openProjectDrawer:sender];
		return;
	}

	[self setSidebarIsClosed:NO];
}

- (void)SideBarSwitching_toggleGroupsAndFilesDrawer:(id)sender
{
	CWTMSplitView* splitView = [[self window] contentView];
	if(not [splitView isKindOfClass:[CWTMSplitView class]])
	{
		[self SideBarSwitching_toggleGroupsAndFilesDrawer:sender];
		return;
	}

	BOOL close = ! [splitView isSubviewCollapsed:[splitView drawerView]];
	
	[self setSidebarIsClosed:close];
}

- (BOOL)SideBarSwitching_validateMenuItem:(id <NSMenuItem>)item;
{
	BOOL valid = [self SideBarSwitching_validateMenuItem:item];
	
	if(valid && [[[self window] contentView] isKindOfClass:[CWTMSplitView class]] && [item action] == @selector(toggleGroupsAndFilesDrawer:))
	{
		if([self sidebarIsClosed])
			[item setTitle:@"Show Project Panel"];
		else
			[item setTitle:@"Hide Project Panel"];
	}
	
	return valid;
}

- (float)splitView:(CWTMSplitView*)splitview constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + [splitview minLeftWidth]);
}

- (float)splitView:(CWTMSplitView*)splitview constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - [splitview minRightWidth]);
}


- (void)splitView:(id)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if(![sender isKindOfClass:[CWTMSplitView class]])
		return;
	float newHeight = [sender frame].size.height;
	float newWidth  = [sender frame].size.width - [[sender drawerView] frame].size.width - [sender dividerThickness];

	NSRect newFrame = [[sender drawerView] frame];
	newFrame.size.height = newHeight;
	[[sender drawerView] setFrame:newFrame];

	newFrame = [[sender documentView] frame];
	newFrame.size.width = newWidth;
	newFrame.size.height = newHeight;
	[[sender documentView] setFrame:newFrame];
	
	[sender adjustSubviews];
}

// ======================================
// = Saving to project file =
// ======================================
- (BOOL)SideBarSwitching_writeToFile:(NSString*)fileName
{
	BOOL result = [self SideBarSwitching_writeToFile:fileName];
	if(result && [[[self window] contentView] isKindOfClass:[CWTMSplitView class]] && [SideBarSwitching useSidebar])
	{
		NSMutableDictionary *project = [NSMutableDictionary dictionaryWithContentsOfFile:fileName];
		CWTMSplitView* splitView     = [[self window] contentView];
		[project setObject:[NSNumber numberWithBool:! [self sidebarIsClosed]] forKey:@"showFileHierarchyPanel"];
		[project setObject:[NSNumber numberWithInt:[[splitView drawerView] bounds].size.width] forKey:@"fileHierarchyDrawerWidth"];
		result = [project writeToFile:fileName atomically:NO];
	}
	return result;
}
@end

@implementation SideBarSwitching
+ (void)load
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES],@"ProjectPlus Sidebar Enabled",
			[NSNumber numberWithBool:NO], @"ProjectPlus Sidebar on Right",
			nil]];

	[OakProjectController jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(SideBarSwitching_windowDidLoad) error:NULL];
	[OakProjectController jr_swizzleMethod:@selector(openProjectDrawer:) withMethod:@selector(SideBarSwitching_openProjectDrawer:) error:NULL];
	[OakProjectController jr_swizzleMethod:@selector(toggleGroupsAndFilesDrawer:) withMethod:@selector(SideBarSwitching_toggleGroupsAndFilesDrawer:) error:NULL];
	[OakProjectController jr_swizzleMethod:@selector(writeToFile:) withMethod:@selector(SideBarSwitching_writeToFile:) error:NULL];
	[OakProjectController jr_swizzleMethod:@selector(validateMenuItem:) withMethod:@selector(SideBarSwitching_validateMenuItem:) error:NULL];
}

+ (BOOL)useSidebar
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar Enabled"];
}

+ (BOOL)sidebarOnRight
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Sidebar on Right"];
}
@end

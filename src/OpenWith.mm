#include <Carbon/Carbon.h>
#include <CoreFoundation/CoreFoundation.h>
#import "TextMate.h"

@interface OpenWith : NSObject
+ (BOOL)useOpenWith;
+ (NSArray*)applicationsForURL:(NSURL*)URL;
@end

@implementation NSButton (OakMenuButton_OpenWith)
- (void)OpenWith_awakeFromNib
{
	[self OpenWith_awakeFromNib];
	
	if(not [OpenWith useOpenWith])
		return;

	if(not [[self window] isKindOfClass:NSClassFromString(@"NSDrawerWindow")])
		return;

	NSMenu *menu = [self valueForKey:@"actionMenu"];

	NSArray* items = [menu itemArray];
	for(int index = 0; index < [items count]; index++)
	{
		if([[items objectAtIndex:index] action] == @selector(openFileWithFinder:))
		{
			NSMenuItem *openWithMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open With…" action:nil keyEquivalent:@""];
			{
				NSMenu *openWithSubMenu = [[NSMenu alloc] init];
				[openWithSubMenu setDelegate:self];

				[openWithMenuItem setSubmenu:openWithSubMenu];
				[openWithSubMenu release];
			}
			[menu insertItem:openWithMenuItem atIndex:index+1];
			[openWithMenuItem release];
			break;
		}
	}

}

- (NSURL*)URLForOpeningApp
{
	NSOutlineView* outlineView = [self valueForKey:@"outlineView"];
	NSDictionary* item         = [outlineView itemAtRow:[outlineView selectedRow]];
	NSString* path             = nil;
	if([item objectForKey:@"filename"])
		path = [item objectForKey:@"filename"];
	else if([item objectForKey:@"sourceDirectory"])
		path = [item objectForKey:@"sourceDirectory"];
	return [NSURL fileURLWithPath:path];
}

- (int)numberOfItemsInMenu:(NSMenu*)menu
{
	return [[OpenWith applicationsForURL:[self URLForOpeningApp]] count];
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(int)index shouldCancel:(BOOL)flag
{
	NSURL* URL = [[OpenWith applicationsForURL:[self URLForOpeningApp]] objectAtIndex:index];
	NSString* title;
	LSCopyDisplayNameForURL((CFURLRef)URL, (CFStringRef*)&title);
	[item setTitle:title];
	[title release];
	[item setTarget:self];
	[item setTag:index];
	NSImage* icon = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
	{
		[icon lockFocus];
		[[[NSWorkspace sharedWorkspace] iconForFile:[URL path]] drawInRect:NSMakeRect(0, 0, 16, 16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[item setImage:icon];
		[icon unlockFocus];
	}
	[icon release];
	[item setAction:@selector(openSelectedItemWith:)];
	
	return YES;
}

- (void)openSelectedItemWith:(id <NSMenuItem>)sender
{
	NSString* filePath = [[self URLForOpeningApp] path];
	NSString* appPath = [[[OpenWith applicationsForURL:[self URLForOpeningApp]] objectAtIndex:[sender tag]] path];
	[[NSWorkspace sharedWorkspace] openFile:filePath withApplication:appPath];
}

- (BOOL)OpenWith_validateMenuItem:(id <NSMenuItem>)item
{
	if([item action] == @selector(openSelectedItemWith:))
		return YES;

	return [self OpenWith_validateMenuItem:item];
}
@end

static NSMutableDictionary* applicationBindings = [[NSMutableDictionary alloc] init];

@implementation OpenWith
+ (void)load
{
	[OakMenuButton jr_swizzleMethod:@selector(awakeFromNib) withMethod:@selector(OpenWith_awakeFromNib) error:NULL];
	[OakMenuButton jr_swizzleMethod:@selector(validateMenuItem:) withMethod:@selector(OpenWith_validateMenuItem:) error:NULL];
}

+ (BOOL)useOpenWith
{
	return YES;
}

+ (NSArray*)applicationsForURL:(NSURL*)URL
{
	if(! [applicationBindings objectForKey:URL])
	{
		NSArray* apps = (NSArray*)LSCopyApplicationURLsForURL((CFURLRef)URL, kLSRolesAll);
		[applicationBindings setObject:(NSArray*)apps forKey:URL];
		[apps release];
	}
	return [applicationBindings objectForKey:URL];
}
@end

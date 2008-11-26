#import "SCMIcons.h"

#define USE_THREADING

@interface BzrIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary* projectStatuses;
	BOOL refreshingProject;
}
+ (BzrIcons*)sharedInstance;
@end

static BzrIcons *SharedInstance;

@implementation BzrIcons
// ==================
// = Setup/Teardown =
// ==================
+ (BzrIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[[self new] autorelease]];
}

- (NSString*)scmName;
{
	return @"Bazaar";
}

- (id)init
{
	if(SharedInstance)
	{
		[self release];
	}
	else if(self = SharedInstance = [[super init] retain])
	{
		projectStatuses = [NSMutableDictionary new];
	}
	return SharedInstance;
}

- (void)dealloc
{
	[projectStatuses release];
	[super dealloc];
}

- (NSString*)bzrPath;
{
	return [[SCMIcons sharedInstance] pathForVariable:@"TM_BZR" paths:[NSArray arrayWithObjects:@"/opt/local/bin/bzr",@"/usr/local/bin/bzr",@"/usr/bin/bzr",nil]];
}

- (NSString*)launchExecutable:(NSString*)exePath inPath:(NSString*)workingPath withArguments:(NSArray*)arguments;
{
	NSTask* task = [[NSTask new] autorelease];
	[task setLaunchPath:exePath];
	[task setCurrentDirectoryPath:workingPath];
	[task setArguments:arguments];

	NSPipe *pipe = [NSPipe pipe];
	[task setStandardOutput: pipe];
	[task setStandardError:[NSPipe pipe]];

	NSFileHandle *file = [pipe fileHandleForReading];

	[task launch];

	NSData *data = [file readDataToEndOfFile];

	[task waitUntilExit];

	if([task terminationStatus] != 0)
		return nil;

	return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath;
{
	NSString* exePath = [self bzrPath];
	if(!exePath || ![[NSFileManager defaultManager] fileExistsAtPath:exePath])
		return;

	@try
	{
		NSString* lsResult = [self launchExecutable:exePath inPath:projectPath withArguments:[NSArray arrayWithObjects:@"ls", @"--versioned", @"--null", path, nil]];
		NSArray* lsLines   = [lsResult componentsSeparatedByString:@"\0"];
		if(!lsResult)
		{
			// Prevent repeated calling
			[projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
			return;
		}

		if([lsLines count] > 1)
		{
			NSMutableDictionary* project = [[NSMutableDictionary alloc] initWithCapacity:[lsLines count]-1];
			for(int index = 0; index < [lsLines count]; index++)
			{
				NSString* filename = [lsLines objectAtIndex:index];
				[project setObject:[NSNumber numberWithInt:SCMIconsStatusVersioned] forKey:filename];
			}
			[projectStatuses setObject:project forKey:projectPath];
			[project release];
		}

		NSString* statusResult = [self launchExecutable:exePath inPath:projectPath withArguments:[NSArray arrayWithObjects:@"status", @"-S", path, nil]];
		if(!statusResult)
		{
			// Prevent repeated calling
			[projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
			return;
		}

		NSArray* statusLines = [statusResult componentsSeparatedByString:@"\n"];
		if([statusLines count] > 1)
		{
			NSMutableDictionary* project = [[NSMutableDictionary alloc] initWithCapacity:[statusLines count]-1];

			for(int index = 0; index < [statusLines count]; index++)
			{
				NSString* line = [statusLines objectAtIndex:index];
				if([line length] > 3)
				{
					const char* versioningStatusChar = [[line substringToIndex:1] UTF8String];
					const char* contentsStatusChar   = [[line substringWithRange:NSMakeRange(1, 1)] UTF8String];
					NSString* filename               = [projectPath stringByAppendingPathComponent:[line substringFromIndex:4]];
					SCMIconsStatus status            = SCMIconsStatusUnknown;
					switch(*contentsStatusChar)
					{
						case 'N': status = SCMIconsStatusAdded; break;
						case 'M': status = SCMIconsStatusModified; break;
					}
					if(status == SCMIconsStatusUnknown)
					{
						switch(*versioningStatusChar)
						{
							case '+': status = SCMIconsStatusVersioned; break;
							case 'C': status = SCMIconsStatusConflicted; break;
						}
					}
					[project setObject:[NSNumber numberWithInt:status] forKey:filename];
				}
			}
			[projectStatuses setObject:project forKey:projectPath];
			[project release];
		}
	}
	@catch(NSException* exception)
	{
		NSLog(@"%s %@: launch path \"%@\"", _cmd, exception, exePath);
	}
}

- (void)executeLsFilesForProject:(NSString*)projectPath;
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	[self executeLsFilesUnderPath:nil inProject:projectPath];
	[self performSelectorOnMainThread:@selector(redisplayStatuses) withObject:nil waitUntilDone:NO];
	[pool release];
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
{
	if(reload || ![projectStatuses objectForKey:projectPath])
		[self executeLsFilesUnderPath:path inProject:projectPath];

	NSNumber* status = [[projectStatuses objectForKey:projectPath] objectForKey:path];
	if(status)
		return (SCMIconsStatus)[status intValue];
	else
		return SCMIconsStatusUnknown;
}

- (void)redisplayStatuses;
{
	refreshingProject = YES;
	[[SCMIcons sharedInstance] redisplayProjectTrees];
	refreshingProject = NO;
}

- (void)reloadStatusesForProject:(NSString*)projectPath;
{
#ifdef USE_THREADING
	[NSThread detachNewThreadSelector:@selector(executeLsFilesForProject:) toTarget:self withObject:projectPath];
#else
	[projectStatuses removeObjectForKey:projectPath];
	[self executeLsFilesUnderPath:nil inProject:projectPath];
#endif
}
@end

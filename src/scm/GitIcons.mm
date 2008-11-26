#import "SCMIcons.h"

#define USE_THREADING

@interface GitIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary* projectStatuses;
}
+ (GitIcons*)sharedInstance;
@end

static GitIcons *SharedInstance;

@implementation GitIcons
// ==================
// = Setup/Teardown =
// ==================
+ (GitIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[self sharedInstance]];
}

- (NSString*)scmName;
{
	return @"Git";
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

- (NSString*)gitPath;
{
	return [[SCMIcons sharedInstance] pathForVariable:@"TM_GIT" paths:[NSArray arrayWithObjects:@"/opt/local/bin/git",@"/usr/local/bin/git",@"/usr/bin/git",nil]];
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath;
{
	NSString* exePath = [self gitPath];
	if(!exePath || ![[NSFileManager defaultManager] fileExistsAtPath:exePath])
		return;

	@try
	{
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:projectPath];
		if(path)
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", nil]];
		else
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", path, nil]];

		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		[task setStandardError:[NSPipe pipe]]; // Prevent errors from being printed to the Console

		NSFileHandle *file = [pipe fileHandleForReading];

		[task launch];

		NSData *data = [file readDataToEndOfFile];

		[task waitUntilExit];

		if([task terminationStatus] != 0)
		{
			// Prevent repeated calling
			[projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
			return;
		}

		NSString *string = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];

		NSArray* lines               = [string componentsSeparatedByString:@"\0"];
		NSMutableDictionary* project = [[NSMutableDictionary alloc] initWithCapacity:([lines count]>0) ? ([lines count]-1) : 0];
		if([lines count] > 1)
		{
			for(int index = 0; index < [lines count]; index++)
			{
				NSString* line = [lines objectAtIndex:index];
				if([line length] > 3)
				{
					const char* statusChar = [[line substringToIndex:1] UTF8String];
					NSString* filename     = [projectPath stringByAppendingPathComponent:[line substringFromIndex:2]];
					SCMIconsStatus status = SCMIconsStatusUnknown;
					switch(*statusChar)
					{
						case 'H': status = SCMIconsStatusVersioned; break;
						case 'C': status = SCMIconsStatusModified; break;
					}
					[project setObject:[NSNumber numberWithInt:status] forKey:filename];
				}
			}
		}
		[projectStatuses setObject:project forKey:projectPath];
		[project release];
	}
	@catch(NSException* exception)
	{
		NSLog(@"%s %@: launch path \"%@\"", _cmd, exception, exePath);
		[projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
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
	[[SCMIcons sharedInstance] redisplayProjectTrees];
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

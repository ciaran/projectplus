#import "SCMIcons.h"

#define USE_THREADING

@interface HgIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary* projectStatuses;
	BOOL refreshingProject;
}
+ (HgIcons*)sharedInstance;
@end

static HgIcons *SharedInstance;

@implementation HgIcons
// ==================
// = Setup/Teardown =
// ==================
+ (HgIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[self sharedInstance]];
}

- (NSString*)scmName;
{
	return @"Mercurial";
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

- (NSString*)hgPath;
{
	return [[SCMIcons sharedInstance] pathForVariable:@"TM_HG" paths:[NSArray arrayWithObjects:@"/opt/local/bin/hg",@"/usr/local/bin/hg",@"/usr/bin/hg",nil]];
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath;
{
	NSString* exePath = [self hgPath];
	if(!exePath || ![[NSFileManager defaultManager] fileExistsAtPath:exePath])
		return;

	@try
	{
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:projectPath];
		if(path)
			[task setArguments:[NSArray arrayWithObjects:@"status", @"-A", @"-0", nil]];
		else
			[task setArguments:[NSArray arrayWithObjects:@"status", @"-A", @"-0", path, nil]];

		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		[task setStandardError:[NSPipe pipe]];

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

		NSString *string             = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
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
						case 'C': status = SCMIconsStatusVersioned; break;
						case 'M': status = SCMIconsStatusModified; break;
						case 'A': status = SCMIconsStatusAdded; break;
						case 'R': status = SCMIconsStatusDeleted; break;
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

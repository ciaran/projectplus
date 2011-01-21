#import "SCMIcons.h"

#define USE_THREADING

@interface FossilIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary* projectStatuses;
	BOOL refreshingProject;
}
+ (FossilIcons*)sharedInstance;
@end

static FossilIcons *SharedInstance;

@implementation FossilIcons
// ==================
// = Setup/Teardown =
// ==================
+ (FossilIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[self sharedInstance]];
}

- (NSString*)scmName;
{
	return @"Fossil";
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

- (NSString*)fossilPath;
{
	return [[SCMIcons sharedInstance] pathForVariable:@"TM_FOSSIL" paths:[NSArray arrayWithObjects:@"/opt/local/bin/fossil",@"/usr/local/bin/fossil",@"/usr/bin/fossil",nil]];
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath;
{
	NSString* exePath = [self fossilPath];
	if(!exePath || ![[NSFileManager defaultManager] fileExistsAtPath:exePath])
		return;

	@try
	{
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:projectPath];
    [task setArguments:[NSArray arrayWithObjects:@"ls", @"-l", nil]];

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
		NSArray* lines               = [string componentsSeparatedByString:@"\n"];
		NSMutableDictionary* project = [[NSMutableDictionary alloc] initWithCapacity:([lines count]>0) ? ([lines count]-1) : 0];
		if([lines count] > 1)
		{
			for(int index = 0; index < [lines count]; index++)
			{
				NSString* line = [lines objectAtIndex:index];
				if([line length] > 3)
				{
          long statusEndIndex = [line rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].location;
					NSString *statusString = [line substringToIndex:statusEndIndex];
          NSString *filename = [projectPath stringByAppendingPathComponent:[[line substringFromIndex:statusEndIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
//          if (path) {
//            if (![filename hasPrefix:path]) {
//              continue; /* we're only interested in files inside path */
//            }
//          }
          const char* statusChar = [[statusString substringToIndex:1] UTF8String];
					SCMIconsStatus status = SCMIconsStatusUnknown;
					switch(*statusChar)
					{
            case 'U': /* UNCHANGED */
              status = SCMIconsStatusVersioned;
              break;
						case 'E': /* EDITED */
            case 'R': /* RENAMED */
              status = SCMIconsStatusModified;
              break;
						case 'A': /* ADDED */
              status = SCMIconsStatusAdded;
              break;
						case 'D': /* DELETED */
              status = SCMIconsStatusDeleted;
              break;
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

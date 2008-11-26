#import "SCMIcons.h"
#import "svn_client.h"
#import "svn_cmdline.h"
#import "svn_pools.h"

struct svn_pool_t
{
	svn_pool_t ()                        { pool = svn_pool_create(NULL);        }
	svn_pool_t (apr_pool_t* parent_pool) { pool = svn_pool_create(parent_pool); }
	~svn_pool_t ()                       { svn_pool_destroy(pool); pool = NULL; }
	operator bool () const               { return pool != 0;                    }
	operator apr_pool_t* () const        { return pool;                         }

private:
	apr_pool_t* pool;
};

@interface SVNIcons : NSObject <SCMIconDelegate>
+ (SVNIcons*)sharedInstance;
@end

NSString* message_for_error (svn_error_t* error)
{
	NSMutableString* message = [NSMutableString string];

	for(svn_error_t* itr = error; itr; itr = itr->child)
		[message appendFormat:@"%s\n", error->message];

	return message;
}

@interface SVNIcons (Private)
- (svn_wc_status_kind)svnStatusForPath:(NSString*)path;

#if 0
- (BOOL)addPath:(NSString*)path;
- (BOOL)renamePath:(NSString*)origPath toPath:(NSString*)newPath;
- (BOOL)deletePaths:(NSArray*)paths;
#endif
@end

apr_pool_t* pool;
svn_client_ctx_t* ctx;
NSMutableDictionary* statusForFiles;

#if 0
@implementation NSWindowController (SVNAppSwitching)
- (void)showAddToRepositorySheet:(NSArray*)unversionedFilePaths;
{
	NSAlert* addSheet = [NSAlert new];
	[addSheet setMessageText:@"Add to repository?"];
	[addSheet addButtonWithTitle:@"OK"];
	[addSheet addButtonWithTitle:@"Cancel"];
	[addSheet setInformativeText:[NSString stringWithFormat:@"Would you also like to add the new file%@ to your SVN repository?", [unversionedFilePaths count] == 1 ? @"" : @"s"]];
	[addSheet beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(fileAddingAlertDidEnd:returnCode:contextInfo:) contextInfo:unversionedFilePaths];
	[addSheet release];
}

- (void)SVN_insertItemsBeforeSelection:(id)items;
{
	[self SVN_insertItemsBeforeSelection:items];

	NSMutableArray* unversionedFilePaths = [NSMutableArray new]; // released in the didEndSelector

	for(NSEnumerator* itemEnum = [items objectEnumerator]; NSDictionary* item = [itemEnum nextObject]; )
	{
		NSString* filename = [item objectForKey:@"filename"];
		if(!filename)
			filename = [item objectForKey:@"sourceDirectory"];

		svn_wc_status_kind status = [[SVNIcons sharedInstance] statusForPath:filename];
		if(status == svn_wc_status_unversioned)
			[unversionedFilePaths addObject:filename];
	}

	if([unversionedFilePaths count] > 0)
		[self performSelector:@selector(showAddToRepositorySheet:) withObject:unversionedFilePaths afterDelay:0.0];
	else
		[unversionedFilePaths release];
}

- (void)fileAddingAlertDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(NSArray*)filepaths;
{
	if(returnCode == NSAlertFirstButtonReturn) // "OK"
	{
		for(NSEnumerator* fileEnum = [filepaths objectEnumerator]; NSString* file = [fileEnum nextObject]; )
			[[SVNIcons sharedInstance] addPath:file];
	}

	[filepaths release];
}


============
= Renaming =
============
- (void)SVN_outlineView:(id)outlineView setObjectValue:(id)newName forTableColumn:(id)column byItem:(id)item;
{
	NSString* filename = [item objectForKey:@"filename"];
	if(!filename)
		filename = [item objectForKey:@"sourceDirectory"];
	NSString* newFilename = [[filename stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"%@",newName];
	BOOL didSVNRename     = NO;
	svn_wc_status_kind status = [[SVNIcons sharedInstance] statusForPath:filename];

	if(! [filename isEqualToString:newFilename] && status != svn_wc_status_unversioned && status != svn_wc_status_ignored && status != svn_wc_status_none)
	{
		int choice = NSRunAlertPanel(@"Rename in repository?", @"Would you also like to rename this file in your SVN repository?", @"OK", @"Cancel", nil);
		if(choice == NSAlertDefaultReturn) // "OK"
		{
			if([[SVNIcons sharedInstance] renamePath:filename toPath:newFilename])
				didSVNRename = YES;
			else
				NSLog(@"SVNMate: Rename %@ → %@ failed – status: %d. Proceeding with filesystem rename.", filename, newFilename, status);
		}
	}

	if(!didSVNRename)
		[self SVN_outlineView:outlineView setObjectValue:newName forTableColumn:column byItem:item];
}

============
= Deleting =
============
- (void)SVN_removeProjectFilesWarningDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(void*)context;
{
	[[alert window] orderOut:nil];

	NSMutableArray* versionedFilePaths = [NSMutableArray new]; // released in the didEndSelector
	NSIndexSet* selectedRowIndexes     = [[self valueForKey:@"outlineView"] selectedRowIndexes];

	unsigned int bufSize = [selectedRowIndexes count];
	unsigned int* buf    = new unsigned int[bufSize];
	NSRange range        = NSMakeRange([selectedRowIndexes firstIndex], [selectedRowIndexes lastIndex]);
	[selectedRowIndexes getIndexes:buf maxCount:bufSize inIndexRange:&range];
	for(unsigned int i = 0; i != bufSize; i++)
	{
		unsigned int index = buf[i];
		id item = [[self valueForKey:@"outlineView"] itemAtRow:index];
		NSString* filename = [item objectForKey:@"filename"];
		if(!filename)
			filename = [item objectForKey:@"sourceDirectory"];

		svn_wc_status_kind status = [[SVNIcons sharedInstance] statusForPath:filename];
		if(status != svn_wc_status_unversioned && status != svn_wc_status_ignored && status != svn_wc_status_none)
		{
			[versionedFilePaths addObject:filename];
		}
	}
	delete[] buf;

	if([versionedFilePaths count] > 0)
	{
		NSAlert* removeSheet = [[NSAlert alloc] init];
		[removeSheet setMessageText:@"Remove from repository?"];
		[removeSheet addButtonWithTitle:@"OK"];
		[removeSheet addButtonWithTitle:@"Cancel"];
		[removeSheet setInformativeText:[NSString stringWithFormat:@"Would you also like to remove the selected file%@ from your SVN repository?", [versionedFilePaths count] == 1 ? @"" : @"s"]];
		[removeSheet beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(fileRemovalAlertDidEnd:returnCode:contextInfo:) contextInfo:versionedFilePaths];
		[removeSheet release];
	}
	else
	{
		[versionedFilePaths release];
		[self SVN_removeProjectFilesWarningDidEnd:alert returnCode:returnCode contextInfo:context];
	}
}

- (void)fileRemovalAlertDidEnd:(NSAlert*)alert returnCode:(int)returnCode contextInfo:(NSArray*)contextInfo;
{
	if(returnCode == NSAlertFirstButtonReturn) // "OK"
	{
		[[SVNIcons sharedInstance] deletePaths:contextInfo];
	}
	else // Do standard delete
		[self SVN_removeProjectFilesWarningDidEnd:alert returnCode:returnCode contextInfo:contextInfo];

	[contextInfo release];
}

@end
#endif

static SVNIcons* SharedInstance;

@implementation SVNIcons
// ==================
// = Setup/Teardown =
// ==================
+ (SVNIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[[self new] autorelease]];
}

- (NSString*)scmName;
{
	return @"Subversion";
}

- (id)init
{
	if(SharedInstance)
	{
		[self release];
	}
	else if(self = SharedInstance = [[super init] retain])
	{
		if(svn_cmdline_init("SVNIcons", stderr) != EXIT_SUCCESS)
			return NULL;

		pool = svn_pool_create(NULL);
		svn_error_t* err = svn_client_create_context(&ctx, pool); // This could fail, but rather than handling errors we will check for ctx above
		if(err)
		{
			svn_error_clear(err);
			ctx = NULL;
		}
		statusForFiles = [[NSMutableDictionary alloc] init];
	}
	return SharedInstance;
}

- (void)dealloc
{
	[statusForFiles release];
	svn_pool_destroy(pool);
	pool = NULL;
	[super dealloc];
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
{
	svn_wc_status_kind status = [self svnStatusForPath:path];

	switch(status)
	{
		case svn_wc_status_none:         return SCMIconsStatusUnknown;
		case svn_wc_status_normal:       return SCMIconsStatusVersioned;
		case svn_wc_status_modified:     return SCMIconsStatusModified;
		case svn_wc_status_added:        return SCMIconsStatusAdded;
		case svn_wc_status_deleted:      return SCMIconsStatusDeleted;
		case svn_wc_status_conflicted:   return SCMIconsStatusConflicted;
		default:                         return SCMIconsStatusUnversioned;
	}
}

// =============
// = SVN stuff =
// =============
static void status_func(void* baton, const char* path, svn_wc_status2_t* status)
{
	[statusForFiles setObject:[NSNumber numberWithInt:status->text_status] forKey:(NSString*)baton];
}

- (svn_wc_status_kind)svnStatusForPath:(NSString*)path
{
	svn_wc_status_kind status = svn_wc_status_none;

	if(path && pool)
	{
		svn_pool_t subpool(pool);
		if(subpool)
		{
			svn_opt_revision_t rev;
			rev.kind = svn_opt_revision_head;

			// (result_rev,  path,  revision,  status_func, status_baton, recurse, get_all, update, no_ignore, ignore_externals, ctx, pool)
			svn_error_t* err = svn_client_status2(NULL, [path UTF8String], &rev, status_func, path, false, false, false, false, true, ctx, subpool);

			if(err)
				svn_error_clear(err);
			else if([statusForFiles objectForKey:path])
			{
				status = (svn_wc_status_kind)[[statusForFiles objectForKey:path] intValue];
				[statusForFiles removeObjectForKey:path];
			}
			else
				status = svn_wc_status_normal;
		}
	}

	return status;
}

#if 0
- (BOOL)renamePath:(NSString*)origPath toPath:(NSString*)newPath
{
	if(!origPath || !newPath) return NO;

	if(!pool)
		return NO;

	apr_pool_t* subpool;

	subpool = svn_pool_create(pool);
	if(!subpool)
		return NO;

	svn_error_t* err = svn_client_move4(NULL, [origPath UTF8String], [newPath UTF8String], YES, ctx, subpool);

	svn_pool_destroy(subpool);

	if(err)
	{
		if(NSString* error = message_for_error(err)])
			NSRunAlertPanel(@"Error", error, @"OK", nil, nil);
		svn_error_clear(err);
		return NO;
	}

	return YES;
}

- (BOOL)addPath:(NSString*)path;
{
	if(!path)
		return NO;

	if(!pool)
		return NO;

	apr_pool_t* subpool;

	subpool = svn_pool_create(pool);
	if(!subpool)
		return NO;

	svn_error_t* err = svn_client_add([path UTF8String], FALSE, ctx, subpool);

	svn_pool_destroy(subpool);

	if(err)
	{
		if(NSString* error = message_for_error(err))
			NSRunAlertPanel(@"Error", error, @"OK", nil, nil);
		svn_error_clear(err);
		return NO;
	}

	return YES;
}

- (BOOL)deletePaths:(NSArray*)paths;
{
	if(!paths)
		return NO;

	if(!pool)
		return NO;

	apr_pool_t* subpool;

	subpool = svn_pool_create(pool);
	if(!subpool)
		return NO;
	
	apr_array_header_t* files          = apr_array_make(subpool, 1, sizeof(const char*));
	APR_ARRAY_PUSH(files, const char*) = [[paths objectAtIndex:0] UTF8String];
	svn_error_t* err                   = svn_client_delete2(NULL, files, true, ctx, subpool);

	svn_pool_destroy(subpool);

	if(err)
	{
		if(NSString* error = message_for_error(err))
			NSRunAlertPanel(@"Error", error, @"OK", nil, nil);
		svn_error_clear(err);
		return NO;
	}
	

	return YES;
}
#endif
@end

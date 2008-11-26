#import <Cocoa/Cocoa.h>
#import "TextMate.h"

enum SCMIconsStatus {
	SCMIconsStatusVersioned = 1,
	SCMIconsStatusModified,
	SCMIconsStatusAdded,
	SCMIconsStatusDeleted,
	SCMIconsStatusConflicted,
	SCMIconsStatusUnversioned,
	SCMIconsStatusUnknown,
};

@protocol SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
- (NSString*)scmName;
@end
// Optional methods:
// - (void)reloadStatusesForProject:(NSString*)projectPath;

@interface SCMIcons : NSWindowController
{
	NSMutableArray* delegates;
	NSMutableArray* iconPacks;
	IBOutlet NSArrayController* iconPacksController;
}
+ (SCMIcons*)sharedInstance;

- (void)redisplayProjectTrees;

- (void)registerSCMDelegate:(id <SCMIconDelegate>)delegate;

- (void)loadIconPacks;
- (NSDictionary*)iconPack;
- (NSImage*)overlayIcon:(NSString*)name;

- (void)setSelectedIconPackIndex:(int)index;

- (NSString*)pathForVariable:(NSString*)shellVariableName paths:(NSArray*)paths;
@end

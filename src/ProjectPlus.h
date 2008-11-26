#import <Cocoa/Cocoa.h>
#import "Sparkle/SUUpdater.h"

extern NSString* ProjectPlus_redrawRequired;

@protocol TMPlugInController
- (float)version;
@end

@interface ProjectPlus : NSObject
{
	NSImage* icon;
	BOOL quickLookAvailable;
	IBOutlet NSView *preferencesView;
	IBOutlet NSTabView* preferencesTabView;

	IBOutlet SUUpdater* sparkleUpdater;
}
+ (ProjectPlus*)sharedInstance;
- (id)initWithPlugInController:(id <TMPlugInController>)aController;

- (IBAction)notifyOutlineViewsAsDirty:(id)sender;
- (void)watchDefaultsKey:(NSString*)keyPath;

- (NSView*)preferencesView;
- (NSImage*)iconImage;
@end
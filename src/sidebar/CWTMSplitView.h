#import "KFSplitView.h"

@interface CWTMSplitView : KFSplitView
{
	BOOL sidebarOnRight;
}
- (BOOL)sideBarOnRight;
- (void)setSideBarOnRight:(BOOL)onRight;

- (NSView*)drawerView;
- (NSView*)documentView;

- (float)minLeftWidth;
- (float)minRightWidth;
@end

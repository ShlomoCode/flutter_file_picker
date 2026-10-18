#import <Foundation/Foundation.h>
#import "DirectoryAccess.h"

// Called only after startAccessingSecurityScopedResource succeeds on the
// original picker URL. Returns the picker's initial reference.
NSString * _Nullable FPInsertDirectoryLease(NSURL * _Nonnull originalURL);

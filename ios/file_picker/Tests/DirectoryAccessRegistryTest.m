#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <stdatomic.h>
#import "DirectoryAccessRegistry.h"

@interface LeaseTestURL : NSURL {
    atomic_int _stopCount;
}
@property (nonatomic, copy) NSString *selectedPath;
@property (nonatomic, readonly) int stopCount;
- (instancetype)initWithPath:(NSString *)path;
@end

@implementation LeaseTestURL
- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithString:[@"file://" stringByAppendingString:path]];
    if (self != nil) {
        _selectedPath = [path copy];
        atomic_init(&_stopCount, 0);
    }
    return self;
}
- (NSString *)path { return _selectedPath; }
- (void)stopAccessingSecurityScopedResource { atomic_fetch_add(&_stopCount, 1); }
- (int)stopCount { return atomic_load(&_stopCount); }
@end

static void Require(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"Directory lease registry test failed: %@", message);
        abort();
    }
}

int main(void) {
    @autoreleasepool {
        LeaseTestURL *url = [[LeaseTestURL alloc] initWithPath:@"/external/folder"];
        NSString *token = FPInsertDirectoryLease(url);
        Require(token.length == 64, @"insertion returns a token");
        const char *key = token.UTF8String;
        Require(!file_picker_directory_access_retain_v1(key, "/external/other"), @"wrong root rejected");
        Require(!file_picker_directory_access_retain_v1("unknown", "/external/folder"), @"unknown token rejected");
        Require(file_picker_directory_access_retain_v1(key, "/external/folder"), @"worker retain succeeds");
        file_picker_directory_access_release_v1(key); // picker releases its reference
        Require(url.stopCount == 0, @"worker keeps the original scope alive");
        file_picker_directory_access_release_v1(key); // worker exits
        Require(url.stopCount == 1, @"final release stops once");
        Require(!file_picker_directory_access_retain_v1(key, "/external/folder"), @"expired token rejected");
        file_picker_directory_access_release_v1(key);
        Require(url.stopCount == 1, @"expired token does not stop twice");

        LeaseTestURL *concurrentURL = [[LeaseTestURL alloc] initWithPath:@"/parallel/folder"];
        NSString *concurrentToken = FPInsertDirectoryLease(concurrentURL);
        Require(concurrentToken != nil, @"concurrent lease inserted");
        const char *concurrentKey = concurrentToken.UTF8String;
        dispatch_apply(2000, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
            @autoreleasepool {
                Require(file_picker_directory_access_retain_v1(concurrentKey, "/parallel/folder"), @"concurrent retain succeeds");
                file_picker_directory_access_release_v1(concurrentKey);
            }
        });
        Require(concurrentURL.stopCount == 0, @"concurrent workers cannot stop base lease");
        file_picker_directory_access_release_v1(concurrentKey);
        Require(concurrentURL.stopCount == 1, @"base release stops once after workers");
        Require(!file_picker_directory_access_retain_v1(concurrentKey, "/parallel/folder"), @"concurrent lease expired");
        NSLog(@"Directory lease registry ownership checks passed");
    }
    return 0;
}

#import "DirectoryAccessRegistry.h"
#import <Security/SecRandom.h>
#import <string.h>

@interface FPDirectoryLease : NSObject
@property (nonatomic, strong) NSURL *originalURL;
@property (nonatomic) NSUInteger refCount;
@end

@implementation FPDirectoryLease
@end

static NSLock *FPDirectoryLeaseLock(void) {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSLock alloc] init]; });
    return lock;
}

static NSMutableDictionary<NSString *, FPDirectoryLease *> *FPDirectoryLeases(void) {
    static NSMutableDictionary<NSString *, FPDirectoryLease *> *leases;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ leases = [[NSMutableDictionary alloc] init]; });
    return leases;
}

static NSString *FPValidatedToken(const char *token) {
    if (token == NULL || strnlen(token, 65) != 64) return nil;
    for (NSUInteger index = 0; index < 64; index++) {
        char character = token[index];
        if (!((character >= '0' && character <= '9') ||
              (character >= 'a' && character <= 'f'))) return nil;
    }
    return [[NSString alloc] initWithBytes:token length:64 encoding:NSASCIIStringEncoding];
}

static NSString *FPNewToken(void) {
    unsigned char bytes[32];
    if (SecRandomCopyBytes(kSecRandomDefault, sizeof(bytes), bytes) != errSecSuccess) return nil;
    static const char hex[] = "0123456789abcdef";
    char characters[64];
    for (NSUInteger index = 0; index < sizeof(bytes); index++) {
        characters[index * 2] = hex[bytes[index] >> 4];
        characters[index * 2 + 1] = hex[bytes[index] & 15];
    }
    return [[NSString alloc] initWithBytes:characters length:sizeof(characters) encoding:NSASCIIStringEncoding];
}

NSString *FPInsertDirectoryLease(NSURL *originalURL) {
    NSString *token = FPNewToken();
    if (token == nil) return nil;
    FPDirectoryLease *lease = [[FPDirectoryLease alloc] init];
    lease.originalURL = originalURL;
    lease.refCount = 1;
    NSLock *lock = FPDirectoryLeaseLock();
    [lock lock];
    while (FPDirectoryLeases()[token] != nil) {
        token = FPNewToken();
        if (token == nil) break;
    }
    if (token != nil) FPDirectoryLeases()[token] = lease;
    [lock unlock];
    return token;
}

bool file_picker_directory_access_retain_v1(const char *token, const char *expected_root_path) {
    @autoreleasepool {
        NSString *key = FPValidatedToken(token);
        if (key == nil || expected_root_path == NULL) return false;
        size_t length = strnlen(expected_root_path, 4097);
        if (length == 0 || length > 4096 || expected_root_path[0] != '/') return false;
        NSString *path = [[NSString alloc] initWithBytes:expected_root_path length:length encoding:NSUTF8StringEncoding];
        if (path == nil) return false;
        NSLock *lock = FPDirectoryLeaseLock();
        [lock lock];
        FPDirectoryLease *lease = FPDirectoryLeases()[key];
        BOOL valid = lease != nil && lease.refCount < NSUIntegerMax &&
                     [lease.originalURL.path isEqualToString:path];
        if (valid) lease.refCount++;
        [lock unlock];
        return valid;
    }
}

void file_picker_directory_access_release_v1(const char *token) {
    @autoreleasepool {
        NSString *key = FPValidatedToken(token);
        if (key == nil) return;
        NSURL *urlToStop = nil;
        NSLock *lock = FPDirectoryLeaseLock();
        [lock lock];
        FPDirectoryLease *lease = FPDirectoryLeases()[key];
        if (lease != nil) {
            lease.refCount--;
            if (lease.refCount == 0) {
                urlToStop = lease.originalURL;
                [FPDirectoryLeases() removeObjectForKey:key];
            }
        }
        [lock unlock];
        if (urlToStop != nil) [urlToStop stopAccessingSecurityScopedResource];
    }
}

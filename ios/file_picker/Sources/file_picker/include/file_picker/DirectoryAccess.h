#ifndef FILE_PICKER_DIRECTORY_ACCESS_H
#define FILE_PICKER_DIRECTORY_ACCESS_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Retain a live, process-local directory lease for asynchronous native work.
/// Returns false for an unknown/expired token or a root path different from
/// the original selected URL's path. Every successful retain requires one
/// release after the worker has exited. Inputs must be UTF-8; root path is
/// at most 4096 bytes. Treat the token as opaque and process-local.
__attribute__((visibility("default"))) bool file_picker_directory_access_retain_v1(
    const char *token, const char *expected_root_path);

/// Balance one successful retain, or release the picker's initial reference.
/// Each owner must release its own reference exactly once: repeated release
/// while other references remain can release another owner's reference.
/// Unknown or fully expired tokens are ignored. The final release stops the
/// original security scope exactly once.
__attribute__((visibility("default"))) void file_picker_directory_access_release_v1(
    const char *token);

#ifdef __cplusplus
}
#endif

#endif

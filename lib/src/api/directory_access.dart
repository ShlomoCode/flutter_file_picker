/// A selected directory and its optional process-local access lease.
class DirectoryAccess {
  const DirectoryAccess({required this.path, this.accessToken});

  /// The absolute path of the selected directory.
  final String path;

  /// A token for the original iOS picker URL's live security scope.
  ///
  /// The token is valid only in this process. Native workers can retain it with
  /// `file_picker_directory_access_retain_v1` before starting asynchronous work
  /// and must balance each successful retain with
  /// `file_picker_directory_access_release_v1` after that work exits. The
  /// caller must release the initial reference exactly once with
  /// `FilePicker.releaseDirectoryAccess` when it no longer needs the directory.
  /// A null token means the picker did not start a security scope; access to
  /// [path] then depends on the operating system's ordinary permissions.
  final String? accessToken;
}

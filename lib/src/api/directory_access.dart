import 'dart:typed_data';

/// A selected directory and optional platform data needed to access it.
class DirectoryAccess {
  const DirectoryAccess({required this.path, this.bookmark});

  /// The absolute path of the selected directory.
  final String path;

  /// An iOS minimal bookmark for the original security-scoped directory URL.
  ///
  /// Native consumers must resolve the bookmark and manage security-scoped
  /// access for their file operations, including any access started implicitly
  /// during resolution. Coordinate file operations and release access when done.
  /// The picker does not retain access after returning. Other platforms return
  /// `null` and retain the behavior of the existing directory path picker.
  final Uint8List? bookmark;
}

import 'package:file_picker/file_picker.dart';
import 'package:file_picker_darwin/file_picker_darwin.dart';
import 'package:android_file_picker/android_file_picker.dart';
// Deprecated in favor of package:material_ui, which needs a newer Flutter than
// CI's oldest one. Migrating is tracked in #2210.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'file_picker_results.dart';

typedef OnRemoveAndroidFile =
    void Function(int index, AndroidPlatformFile androidPlatformFile);

class PickedFilesResults extends StatelessWidget {
  const PickedFilesResults({
    super.key,
    required this.pickedFiles,
    required this.onRemoveAndroidFile,
  });

  final List<PlatformFile> pickedFiles;
  final OnRemoveAndroidFile onRemoveAndroidFile;

  @override
  Widget build(BuildContext context) {
    return FilePickerResultsList(
      itemCount: pickedFiles.length,
      itemBuilder: (BuildContext context, int index) {
        final pickedFile = pickedFiles[index];
        final AndroidPlatformFile? androidPlatformFile =
            pickedFile is AndroidPlatformFile ? pickedFile : null;

        final Widget? trailingWidget = androidPlatformFile == null
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: () =>
                    onRemoveAndroidFile(index, androidPlatformFile),
              );
        // On web, PlatformFile.path is always null (web files have no
        // filesystem path), so fall back to the blob/data URI instead.
        final path = pickedFile.path ?? pickedFile.uri.toString();
        final assetIdentifier = pickedFile is DarwinPlatformFile
            ? pickedFile.assetIdentifier
            : null;
        final safAccess = androidPlatformFile?.safHandle?.accessMode.name;
        final details = [
          path,
          if (assetIdentifier != null) 'Asset: $assetIdentifier',
          if (safAccess != null) 'SAF access: $safAccess',
        ];

        return ListTile(
          leading: Text(
            index.toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          title: Text('File path (SAF Grant: ${androidPlatformFile != null}):'),
          subtitle: Text(details.join('\n')),
          trailing: trailingWidget,
        );
      },
    );
  }
}

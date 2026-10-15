import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// The `webOptions` for `saveFile()` on the web, choosing between a download
/// and the browser's save dialog.
WebOptions filePickerWebOptions({required bool useDialog}) =>
    FilePickerWebOptions(
      saveMode: useDialog ? WebSaveFileMode.dialog : WebSaveFileMode.download,
    );

/// Whether this browser supports the save dialog.
bool get supportsSaveDialog => supportsShowSaveFileDialog;

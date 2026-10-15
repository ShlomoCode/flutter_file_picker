import 'package:file_picker/file_picker.dart';

/// The `webOptions` for `saveFile()` on platforms other than the web, which
/// ignore them. `package:file_picker_web` can only be imported on the web.
WebOptions filePickerWebOptions({required bool useDialog}) =>
    const WebOptions();

/// Whether `saveFile()` can use the browser's save dialog, which only exists on
/// the web.
bool get supportsSaveDialog => false;

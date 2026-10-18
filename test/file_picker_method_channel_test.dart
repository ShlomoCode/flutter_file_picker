@TestOn('vm')
library;

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannel channel = MethodChannel(
      'miguelruivo.flutter.plugins.filepicker', const StandardMethodCodec());
  final List<MethodCall> log = <MethodCall>[];

  group('MethodChannelFilePicker', () {
    late MethodChannelFilePicker picker;

    setUp(() {
      picker = MethodChannelFilePicker();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'custom') {
          return [
            {
              'path': '/tmp/test.txt',
              'name': 'test.txt',
              'size': 1024,
              'bytes': null,
            }
          ];
        }
        return null;
      });
      log.clear();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('iOS directory lease flows through the public API', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'dirWithAccess') {
          return {'path': '/external/folder', 'accessToken': 'live-token'};
        }
        return null;
      });
      final previous = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      try {
        final access = await FilePicker.getDirectoryAccess();
        expect(access!.path, '/external/folder');
        expect(access.accessToken, 'live-token');
        await FilePicker.releaseDirectoryAccess(accessToken: access.accessToken!);
        expect(log.map((call) => call.method), ['dirWithAccess', 'releaseDirectoryAccess']);
        expect(log.last.arguments, {'accessToken': 'live-token'});
      } finally {
        FilePickerPlatform.instance = previous;
      }
    });

    test('pickFiles calls invokeMethod with correct arguments', () async {
      await picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      expect(log, hasLength(1));
      expect(log.first.method, 'custom');
      expect(log.first.arguments, {
        'allowMultipleSelection': false,
        'allowedExtensions': ['pdf'],
        'withData': false,
        'compressionQuality': 0,
      });
    });

    test('pickFiles throws ArgumentError for invalid custom extension usage',
        () async {
      expect(
        () => picker.pickFiles(
          type: FileType.any,
          allowedExtensions: ['pdf'],
        ),
        throwsArgumentError,
      );
    });
  });
}

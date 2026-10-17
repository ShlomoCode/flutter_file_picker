@TestOn('vm')
library;

import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:file_picker/file_picker.dart';
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

    test('iOS directory access preserves bookmark bytes through the public API',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final bookmark = Uint8List.fromList([0, 127, 128, 255]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return {'path': '/external/folder', 'bookmark': bookmark};
      });
      final previous = FilePickerPlatform.instance;
      FilePickerPlatform.instance = picker;
      try {
        final result = await FilePicker.getDirectoryAccess();
        expect(result!.path, '/external/folder');
        expect(result.bookmark, bookmark);
        expect(log.single.method, 'dirWithBookmark');
      } finally {
        FilePickerPlatform.instance = previous;
      }
    });

    test('iOS directory access cancellation returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await picker.getDirectoryAccess(), isNull);
      expect(log.single.method, 'dirWithBookmark');
    });

    test(
        'iOS bookmark failure propagates and the existing picker stays path-only',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        if (call.method == 'dirWithBookmark') {
          throw PlatformException(code: 'directory_bookmark_failed');
        }
        return '/existing/path';
      });
      await expectLater(
          picker.getDirectoryAccess(),
          throwsA(isA<PlatformException>().having(
              (error) => error.code, 'code', 'directory_bookmark_failed')));
      expect(await picker.getDirectoryPath(), '/existing/path');
      expect(log.map((call) => call.method), ['dirWithBookmark', 'dir']);
    });

    test('other platforms use the existing directory method without a bookmark',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return '/existing/path';
      });
      final result = await picker.getDirectoryAccess();
      expect(result!.path, '/existing/path');
      expect(result.bookmark, isNull);
      expect(log.single.method, 'dir');
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

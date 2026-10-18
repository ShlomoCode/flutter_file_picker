@TestOn('vm')
library;

import 'dart:async';

import 'package:file_picker/src/platform/file_picker_method_channel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannel channel = MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
    const StandardMethodCodec(),
  );
  final List<MethodCall> log = <MethodCall>[];

  group('MethodChannelFilePicker', () {
    late MethodChannelFilePicker picker;

    setUp(() {
      picker = MethodChannelFilePicker();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'custom') {
          return [
            {
              'path': '/tmp/test.txt',
              'name': 'test.txt',
              'size': 1024,
              'bytes': null,
            },
          ];
        }
        return null;
      });
      log.clear();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test(
      'iOS directory access returns a lease and releases it through the public API',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'dirWithAccess') {
            return {
              'path': '/external/folder',
              'accessToken': 'live-token',
            };
          }
          return null;
        });
        final previous = FilePickerPlatform.instance;
        FilePickerPlatform.instance = picker;
        try {
          final result = await FilePicker.getDirectoryAccess();
          expect(result!.path, '/external/folder');
          expect(result.accessToken, 'live-token');
          await FilePicker.releaseDirectoryAccess(
            accessToken: result.accessToken!,
          );
          expect(log.map((call) => call.method), [
            'dirWithAccess',
            'releaseDirectoryAccess',
          ]);
          expect(log.last.arguments, {'accessToken': 'live-token'});
        } finally {
          FilePickerPlatform.instance = previous;
        }
      },
    );

    test('iOS directory access cancellation returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await picker.getDirectoryAccess(), isNull);
      expect(log.single.method, 'dirWithAccess');
    });

    test(
      'iOS release can be sent while another picker request is pending',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final pendingPick = Completer<Map<String, Object?>?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'dirWithAccess') return pendingPick.future;
          return null;
        });
        final pick = picker.getDirectoryAccess();
        await Future<void>.delayed(Duration.zero);
        await picker.releaseDirectoryAccess(accessToken: 'earlier-token');
        expect(log.map((call) => call.method), [
          'dirWithAccess',
          'releaseDirectoryAccess',
        ]);
        pendingPick.complete(null);
        expect(await pick, isNull);
      },
    );

    test(
      'iOS lease picker failure propagates and the existing picker stays path-only',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'dirWithAccess') {
            throw PlatformException(code: 'directory_picker_failed');
          }
          return '/existing/path';
        });
        await expectLater(
          picker.getDirectoryAccess(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'directory_picker_failed',
            ),
          ),
        );
        expect(await picker.getDirectoryPath(), '/existing/path');
        expect(log.map((call) => call.method), ['dirWithAccess', 'dir']);
      },
    );

    test('iOS can return a path without a security scope', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return {'path': '/app-owned/folder', 'accessToken': null};
      });
      final result = await picker.getDirectoryAccess();
      expect(result!.path, '/app-owned/folder');
      expect(result.accessToken, isNull);
    });

    test(
      'other platforms use the existing directory method without a token',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          return '/existing/path';
        });
        final result = await picker.getDirectoryAccess();
        expect(result!.path, '/existing/path');
        expect(result.accessToken, isNull);
        await picker.releaseDirectoryAccess(accessToken: 'unused');
        expect(log.single.method, 'dir');
      },
    );

    test('pickFiles calls invokeMethod with correct arguments', () async {
      await picker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

      expect(log, hasLength(1));
      expect(log.first.method, 'custom');
      expect(log.first.arguments, {
        'allowMultipleSelection': false,
        'allowedExtensions': ['pdf'],
        'withData': false,
        'compressionQuality': 0,
      });
    });

    test(
      'pickFiles throws ArgumentError for invalid custom extension usage',
      () async {
        expect(
          () => picker.pickFiles(type: FileType.any, allowedExtensions: ['pdf']),
          throwsArgumentError,
        );
      },
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/printer_debug_log_helper.dart';

void main() {
  group('PrinterDebugLogHelper.append', () {
    test('skips logging on non-android platforms', () async {
      var called = false;

      await PrinterDebugLogHelper.append(
        scope: 'test',
        message: 'hello',
        isAndroidOverride: false,
        invokeMethod: (method, [arguments]) async {
          called = true;
          return true;
        },
      );

      expect(called, isFalse);
    });

    test('invokes appendDebugLog on android', () async {
      String? calledMethod;
      Map<String, dynamic>? calledArgs;

      await PrinterDebugLogHelper.append(
        scope: 'printer',
        message: 'start',
        data: {'bytes': 123},
        isAndroidOverride: true,
        invokeMethod: (method, [arguments]) async {
          calledMethod = method;
          calledArgs = (arguments as Map).cast<String, dynamic>();
          return true;
        },
      );

      expect(calledMethod, 'appendDebugLog');
      expect(calledArgs?['scope'], 'printer');
      expect(calledArgs?['message'], 'start');
      expect((calledArgs?['data'] ?? '').toString(), contains('"bytes":"123"'));
    });
  });

  group('PrinterDebugLogHelper.getLogFilePath', () {
    test('returns empty path on non-android platforms', () async {
      final path = await PrinterDebugLogHelper.getLogFilePath(
        isAndroidOverride: false,
      );

      expect(path, isEmpty);
    });

    test('returns channel value on android', () async {
      final path = await PrinterDebugLogHelper.getLogFilePath(
        isAndroidOverride: true,
        invokeMethod: (method, [arguments]) async {
          expect(method, 'getDebugLogPath');
          return '/storage/emulated/0/Android/data/com.example/files/log.log';
        },
      );

      expect(path, contains('/storage/emulated/0/Android/data/'));
    });
  });

  group('PrinterDebugLogHelper.clearLogFile', () {
    test('returns false on non-android platforms', () async {
      final cleared = await PrinterDebugLogHelper.clearLogFile(
        isAndroidOverride: false,
      );

      expect(cleared, isFalse);
    });

    test('returns true when channel confirms clear', () async {
      final cleared = await PrinterDebugLogHelper.clearLogFile(
        isAndroidOverride: true,
        invokeMethod: (method, [arguments]) async {
          expect(method, 'clearDebugLog');
          return true;
        },
      );

      expect(cleared, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/printer_platform_helper.dart';

void main() {
  group('PrinterPlatformHelper.supportsNativePrinter', () {
    test('returns override value when explicitly provided', () {
      expect(
        PrinterPlatformHelper.supportsNativePrinter(
          isWindowsOverride: true,
          isAndroidOverride: false,
        ),
        isTrue,
      );
      expect(
        PrinterPlatformHelper.supportsNativePrinter(
          isWindowsOverride: false,
          isAndroidOverride: true,
        ),
        isTrue,
      );
      expect(
        PrinterPlatformHelper.supportsNativePrinter(
          isWindowsOverride: false,
          isAndroidOverride: false,
        ),
        isFalse,
      );
    });
  });

  group('PrinterPlatformHelper.supportsCashDrawer', () {
    test('is windows-only', () {
      expect(PrinterPlatformHelper.supportsCashDrawer(isWindowsOverride: true),
          isTrue);
      expect(PrinterPlatformHelper.supportsCashDrawer(isWindowsOverride: false),
          isFalse);
    });
  });

  group('PrinterPlatformHelper.canUsePrinterManager', () {
    test('requires supported platform and non-null printer manager', () {
      expect(
        PrinterPlatformHelper.canUsePrinterManager(
          Object(),
          isWindowsOverride: true,
          isAndroidOverride: false,
        ),
        isTrue,
      );
      expect(
        PrinterPlatformHelper.canUsePrinterManager(
          Object(),
          isWindowsOverride: false,
          isAndroidOverride: true,
        ),
        isTrue,
      );
      expect(
        PrinterPlatformHelper.canUsePrinterManager(
          null,
          isWindowsOverride: true,
          isAndroidOverride: false,
        ),
        isFalse,
      );
      expect(
        PrinterPlatformHelper.canUsePrinterManager(
          Object(),
          isWindowsOverride: false,
          isAndroidOverride: false,
        ),
        isFalse,
      );
    });
  });
}

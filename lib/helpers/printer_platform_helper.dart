import 'dart:io';

class PrinterPlatformHelper {
  const PrinterPlatformHelper._();

  /// Hardware receipt printing supports:
  /// - Windows native printer port flow
  /// - Android paired Bluetooth receipt printers
  static bool supportsNativePrinter({
    bool? isWindowsOverride,
    bool? isAndroidOverride,
  }) {
    final isWindows = isWindowsOverride ?? Platform.isWindows;
    final isAndroid = isAndroidOverride ?? Platform.isAndroid;
    return isWindows || isAndroid;
  }

  /// Cash drawer pulse command is still only supported by Windows flow.
  static bool supportsCashDrawer({bool? isWindowsOverride}) {
    return isWindowsOverride ?? Platform.isWindows;
  }

  static bool canUsePrinterManager(
    Object? printerManager, {
    bool? isWindowsOverride,
    bool? isAndroidOverride,
  }) {
    return supportsNativePrinter(
          isWindowsOverride: isWindowsOverride,
          isAndroidOverride: isAndroidOverride,
        ) &&
        printerManager != null;
  }
}

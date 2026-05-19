import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main activity initializes logging/bootstrap early without forcing sdk warmup on launch', () {
    final source = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('override fun onCreate(savedInstanceState: Bundle?)'));
    expect(source, contains('bootstrapNativePrinterEnvironment(trigger = "onCreate")'));
    expect(source, contains('bootstrapNativePrinterEnvironment(trigger = "configureFlutterEngine")'));
    expect(source, contains('private fun bootstrapNativePrinterEnvironment('));
    expect(source, contains('initializeBixolonVendorLogging()'));
    expect(source, contains('LogService.InitDebugLog('));
    expect(source, contains('Bixolon vendor logging initialized'));
    expect(source, contains('Unhandled exception logger installed'));
    expect(source, contains('Sample-compat StrictMode enabled'));
    expect(source, contains('BuildConfig.BIXOLON_MATRIX_ID'));
    expect(source, contains('BuildConfig.BIXOLON_SAMPLE_COMPAT'));
    expect(source, contains('BuildConfig.BIXOLON_MATRIX_TARGET_SDK'));
    expect(source, contains('override fun onDestroy()'));
    expect(source, contains('bixolonSdkPrinter.shutdown()'));
    expect(source, isNot(contains('warmUpBixolonSdkOnMainThread()')));
  });
}

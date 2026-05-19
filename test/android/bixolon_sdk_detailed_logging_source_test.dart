import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bixolon sdk printer logs lifecycle steps and structured failure details',
      () {
    final sdkSource = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/BixolonSdkPrinter.kt',
    ).readAsStringSync();

    expect(sdkSource, contains('data class BixolonPrintResult('));
    expect(sdkSource, contains('logger(LOG_SCOPE, "Config openFile/newFile"'));
    expect(sdkSource, contains('"POSPrinter.open"'));
    expect(sdkSource, contains('"POSPrinter.open success"'));
    expect(sdkSource, contains('logger(LOG_SCOPE, "POSPrinter.claim"'));
    expect(sdkSource, contains('"POSPrinter.claim success"'));
    expect(sdkSource, contains('"POSPrinter.setDeviceEnabled(true)"'));
    expect(sdkSource, contains('"POSPrinter.setDeviceEnabled(true) success"'));
    expect(sdkSource, contains('"POSPrinter.setAsyncMode", "enabled=false"'));
    expect(sdkSource, contains('logger(LOG_SCOPE, "POSPrinter.printNormal"'));
    expect(sdkSource, contains('"POSPrinter.printNormal success"'));
    expect(
      sdkSource,
      contains('message = t.message ?: t::class.java.simpleName'),
    );
    expect(sdkSource, contains('details = t.stackTraceToString()'));
  });

  test(
      'main activity persists sdk failure details and avoids RFCOMM fallback in sdk mode',
      () {
    final activitySource = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt',
    ).readAsStringSync();

    expect(
      activitySource,
      contains('Bixolon SDK print failed; not falling back to RFCOMM'),
    );
    expect(
      activitySource,
      contains('errorCode = sdkResult.errorCode.ifBlank { "BIXOLON_SDK_FAILED" }'),
    );
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bixolon sdk printer logs config-loader file boundaries and storage snapshots', () {
    final sdkSource = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/BixolonSdkPrinter.kt',
    ).readAsStringSync();

    expect(sdkSource, contains('fun warmUp(): BixolonPrintResult'));
    expect(sdkSource, contains('private fun ensureSdkPrepared()'));
    expect(sdkSource, contains('private fun ensurePrinterSession('));
    expect(sdkSource, contains('SDK warm-up dispatching to main thread'));
    expect(sdkSource, contains('SDK warm-up success'));
    expect(sdkSource, contains('SDK_LOGICAL_NAME_SPP_R310'));
    expect(sdkSource, contains('POSPrinter constructor start'));
    expect(sdkSource, contains('POSPrinter constructor success'));
    expect(sdkSource, contains('POSPrinter listener registration success'));
    expect(sdkSource, contains('BXLConfigLoader constructor start'));
    expect(sdkSource, contains('BXLConfigLoader constructor success'));
    expect(sdkSource, contains('BXLConfigLoader.openFile start'));
    expect(sdkSource, contains('BXLConfigLoader.openFile success'));
    expect(sdkSource, contains('BXLConfigLoader.openFile failed'));
    expect(sdkSource, contains('BXLConfigLoader.newFile start'));
    expect(sdkSource, contains('BXLConfigLoader.newFile success'));
    expect(sdkSource, contains('BXLConfigLoader.saveFile start'));
    expect(sdkSource, contains('BXLConfigLoader.saveFile success'));
    expect(sdkSource, contains('private fun logConfigEnvironment('));
    expect(sdkSource, contains('private fun logSdkRuntimeState('));
    expect(sdkSource, contains('"SDK runtime state"'));
    expect(sdkSource, contains('"SDK native library dir entries"'));
    expect(sdkSource, contains('"SDK reflective probes"'));
    expect(sdkSource, contains('sdkProbeClassLoader()'));
    expect(sdkSource, contains('safeClassProbe("com.bxl.config.editor.BXLConfigLoader")'));
    expect(sdkSource, isNot(contains('Class.forName(className, false, context.javaClass.classLoader)')));
    expect(sdkSource, contains('bxlLibExists='));
    expect(sdkSource, contains('"Config interesting files"'));
    expect(sdkSource, contains('private fun collectInterestingFiles('));
    expect(sdkSource, contains('POSPrinter.setAsyncMode", "enabled=false"'));
    expect(sdkSource, contains('"POSPrinter.printNormal success"'));
    expect(sdkSource, contains('Reusing active printer session'));
    expect(sdkSource, contains('Printer session established'));
    expect(sdkSource, contains('closeActiveSessionQuietly(reason = "print_failure")'));
    expect(sdkSource, contains('private fun resolveModelName(): String'));
    expect(sdkSource, contains('deviceServiceVersion='));
  });
}

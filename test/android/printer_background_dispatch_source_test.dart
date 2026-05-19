import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android printer bridge dispatches print work to background thread', () {
    final activity = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt',
    )
        .readAsStringSync();

    expect(activity, contains('dispatchPrintInBackground('));
    expect(activity, contains('private val printExecutor = Executors.newSingleThreadExecutor()'));
    expect(activity, contains('private val printInProgress = AtomicBoolean(false)'));
    expect(activity, contains('printExecutor.execute {'));
    expect(activity, contains('executePrintRequest('));
    expect(activity, contains('runOnUiThread'));
    expect(activity, contains('preferBixolonSdk'));
    expect(activity, contains('textPayload: String'));
    expect(
      activity,
      contains('val shouldTryBixolonSdk = preferBixolonSdk && isLikelyBixolonModel'),
    );
  });
}

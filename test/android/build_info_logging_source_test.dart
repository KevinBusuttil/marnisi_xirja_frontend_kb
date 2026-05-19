import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android printer log writes app build identity on startup', () {
    final source = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('message = "App build info"'));
    expect(source, contains('append(",versionName=")'));
    expect(source, contains('append(",versionCode=")'));
    expect(source, contains('append(",androidSdk=")'));
  });
}

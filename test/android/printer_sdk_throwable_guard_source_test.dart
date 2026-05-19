import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android printer bridge guards SDK fatal throwables before process kill', () {
    final source = File(
      'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt',
    ).readAsStringSync();

    expect(source, contains('message = "Attempting Bixolon SDK print path"'));
    expect(
      source,
      contains('message = "Bixolon SDK print failed; not falling back to RFCOMM"'),
    );
    expect(source, contains('catch (t: Throwable)'));
    expect(source, contains('errorCode = "PRINT_FATAL_THROWABLE"'));
    expect(source, contains('private fun summarizeThrowable(t: Throwable): String'));
  });
}

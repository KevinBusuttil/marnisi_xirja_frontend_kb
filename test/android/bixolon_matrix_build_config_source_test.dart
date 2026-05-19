import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android build config defines bixolon matrix flavors', () {
    final source = File('android/app/build.gradle').readAsStringSync();

    expect(source, contains('flavorDimensions += "bixolonMatrix"'));
    expect(source, contains('matrixa'));
    expect(source, contains('matrixb'));
    expect(source, contains('matrixc'));
    expect(source, contains('sampleparity'));
    expect(source, contains('BIXOLON_SAMPLE_COMPAT'));
    expect(source, contains('BIXOLON_MATRIX_ID'));
    expect(source, contains('BIXOLON_MATRIX_TARGET_SDK'));
    expect(source, contains('sampleParity'));
    expect(source, contains('targetSdk = 31'));
  });
}

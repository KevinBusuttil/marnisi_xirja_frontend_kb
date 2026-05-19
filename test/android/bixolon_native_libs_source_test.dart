import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bixolon sdk native libs are packaged for all supported android abis', () {
    final projectRoot = Directory.current.path;
    final requiredLibs = <String>[
      'android/app/src/main/jniLibs/armeabi-v7a/libbxl_common.so',
      'android/app/src/main/jniLibs/arm64-v8a/libbxl_common.so',
      'android/app/src/main/jniLibs/x86/libbxl_common.so',
      'android/app/src/main/jniLibs/x86_64/libbxl_common.so',
    ];

    for (final relativePath in requiredLibs) {
      final file = File('$projectRoot/$relativePath');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Missing required native library: $relativePath',
      );
    }
  });
}

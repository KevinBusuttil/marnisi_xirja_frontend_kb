import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matrix manifest overlays include sample parity flags and permissions', () {
    final matrixB = File('android/app/src/matrixb/AndroidManifest.xml');
    final matrixC = File('android/app/src/matrixc/AndroidManifest.xml');
    final sampleParity = File('android/app/src/sampleparity/AndroidManifest.xml');

    expect(matrixB.existsSync(), isTrue);
    expect(matrixC.existsSync(), isTrue);
    expect(sampleParity.existsSync(), isTrue);

    final matrixBSource = matrixB.readAsStringSync();
    final matrixCSource = matrixC.readAsStringSync();
    final sampleParitySource = sampleParity.readAsStringSync();

    for (final source in [matrixBSource, matrixCSource]) {
      expect(source, contains('android.permission.BLUETOOTH_ADVERTISE'));
      expect(source, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(source, contains('android.permission.ACCESS_FINE_LOCATION'));
      expect(source, contains('android.permission.READ_EXTERNAL_STORAGE'));
      expect(source, contains('android.permission.WRITE_EXTERNAL_STORAGE'));
      expect(source, contains('android:largeHeap="true"'));
      expect(source, contains('org.apache.http.legacy'));
    }

    expect(sampleParitySource, contains('android.hardware.usb.host'));
    expect(sampleParitySource, contains('android.hardware.bluetooth_le'));
    expect(sampleParitySource, contains('android.permission.CHANGE_WIFI_MULTICAST_STATE'));
    expect(sampleParitySource, contains('android.permission.ACCESS_WIFI_STATE'));
    expect(sampleParitySource, contains('android.permission.CHANGE_WIFI_STATE'));
    expect(sampleParitySource, contains('android.permission.CHANGE_NETWORK_STATE'));
    expect(sampleParitySource, contains('android.permission.BLUETOOTH_ADVERTISE'));
    expect(sampleParitySource, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(sampleParitySource, contains('android.permission.WRITE_EXTERNAL_STORAGE'));
    expect(sampleParitySource, contains('android:largeHeap="true"'));
    expect(sampleParitySource, contains('org.apache.http.legacy'));
  });
}

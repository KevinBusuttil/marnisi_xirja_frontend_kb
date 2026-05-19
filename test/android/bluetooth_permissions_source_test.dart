import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android bluetooth print flow declares sdk parity permissions and requests scan + connect permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.BLUETOOTH_CONNECT'));
    expect(manifest, contains('android.permission.BLUETOOTH_SCAN'));

    final activity = File(
            'android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt')
        .readAsStringSync();
    expect(activity, contains('requestBluetoothRuntimePermissions'));
    expect(activity, contains('Manifest.permission.BLUETOOTH_CONNECT'));
    expect(activity, contains('Manifest.permission.BLUETOOTH_SCAN'));
    expect(activity, contains('Manifest.permission.READ_EXTERNAL_STORAGE'));
    expect(activity, contains('Manifest.permission.WRITE_EXTERNAL_STORAGE'));
    expect(activity, contains('Manifest.permission.ACCESS_COARSE_LOCATION'));
    expect(activity, contains('Manifest.permission.ACCESS_FINE_LOCATION'));
    expect(activity, isNot(contains('permissions += Manifest.permission.BLUETOOTH_ADVERTISE')));
    expect(activity, contains('cancelDiscoverySafely(adapter)'));
  });
}

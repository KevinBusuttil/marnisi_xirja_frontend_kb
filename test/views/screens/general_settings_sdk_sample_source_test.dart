import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('general settings exposes sdk sample print action', () {
    final source = File(
      'lib/views/screens/general_settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Run SDK Sample Print'));
    expect(source, contains('Printing SDK Sample...'));
    expect(source, contains('AndroidPrinterDiscovery.printSdkSampleReceipt('));
  });
}

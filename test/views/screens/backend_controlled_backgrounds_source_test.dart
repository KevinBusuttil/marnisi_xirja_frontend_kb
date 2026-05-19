import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('target screens use backend-controlled app background widget', () {
    const screens = <String>[
      'lib/views/screens/general_settings_screen.dart',
      'lib/views/screens/inventory_screen.dart',
      'lib/views/screens/sales_history_screen.dart',
      'lib/views/screens/sales_register_pos_screen 2.dart',
    ];

    for (final screenPath in screens) {
      final source = File(screenPath).readAsStringSync();
      expect(source, contains('MarnisiAppBackground'));
      expect(
          source, isNot(contains('DashboardBackgroundStyle.imageAssetPath')));
    }
  });
}

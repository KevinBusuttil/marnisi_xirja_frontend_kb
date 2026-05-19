import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard cash-style cards use euro symbol icon instead of dollar icon',
      () {
    final sourceFile = File('lib/views/screens/dashboard_screen.dart');
    final source = sourceFile.readAsStringSync();

    expect(source, isNot(contains('Icons.attach_money_rounded')));

    final euroMatches = RegExp(r'Icons\.euro_symbol').allMatches(source).length;
    expect(euroMatches, greaterThanOrEqualTo(3));
  });
}

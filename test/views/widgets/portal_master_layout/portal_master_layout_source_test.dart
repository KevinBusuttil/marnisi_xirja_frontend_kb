import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portal header does not expose language selector action', () {
    final sourceFile =
        File('lib/views/widgets/portal_master_layout/portal_master_layout.dart');
    final source = sourceFile.readAsStringSync();

    expect(source, isNot(contains('_changeLanguageButton(')));
    expect(source, isNot(contains('Icons.translate_rounded')));
  });
}


import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/portal_header_time_helper.dart';

void main() {
  group('PortalHeaderTimeHelper.formatElapsed', () {
    test('formats elapsed duration without seconds', () {
      final value = PortalHeaderTimeHelper.formatElapsed(
          const Duration(hours: 2, minutes: 5, seconds: 59));
      expect(value, '02:05');
    });

    test('supports elapsed values above 24 hours', () {
      final value = PortalHeaderTimeHelper.formatElapsed(
          const Duration(hours: 27, minutes: 3));
      expect(value, '27:03');
    });
  });

  group('PortalHeaderTimeHelper.formatDateTimeWithoutSeconds', () {
    test('formats dd/MM/yyyy HH:mm', () {
      final value = PortalHeaderTimeHelper.formatDateTimeWithoutSeconds(
        DateTime(2026, 5, 11, 9, 7, 44),
      );
      expect(value, '11/05/2026 09:07');
    });
  });
}

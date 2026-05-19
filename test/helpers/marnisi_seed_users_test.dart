import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/marnisi_seed_users.dart';

void main() {
  group('marnisiSeedUsers', () {
    test('contains the expected fallback personal IDs', () {
      final ids = marnisiSeedUsers.map((user) => user.personalId).toSet();
      expect(ids, {'11111', '22222', '33333', '44444'});
    });

    test('maps fields correctly to local DB rows', () {
      final row = marnisiSeedUsers.first.toLocalDbRow();
      expect(row['user_personnel_id'], '11111');
      expect(row['user_email'], 'marnisi.admin.north@example.com');
      expect(row['user_group'], 'Vineyard Admin');
    });
  });
}

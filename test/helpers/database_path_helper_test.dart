import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/database_path_helper.dart';

void main() {
  group('resolveDatabasePath', () {
    test('uses mobile database directory on mobile platforms', () {
      final path = resolveDatabasePath(
        isMobile: true,
        dbName: 'posdb.db',
        mobileDatabasesPath: '/data/user/0/com.example.app/databases',
        executableDir: '/unused',
      );

      expect(
        path,
        '/data/user/0/com.example.app/databases/posdb.db',
      );
    });

    test('throws when mobile directory is missing for mobile platforms', () {
      expect(
        () => resolveDatabasePath(
          isMobile: true,
          dbName: 'posdb.db',
          mobileDatabasesPath: '',
          executableDir: '/unused',
        ),
        throwsArgumentError,
      );
    });

    test('uses executable directory on desktop platforms', () {
      final path = resolveDatabasePath(
        isMobile: false,
        dbName: 'posdb.db',
        executableDir: '/opt/xirja',
      );

      expect(path, '/opt/xirja/posdb.db');
    });
  });
}

import 'package:path/path.dart';

String resolveDatabasePath({
  required bool isMobile,
  required String dbName,
  String? mobileDatabasesPath,
  required String executableDir,
}) {
  if (isMobile) {
    final dbBase = mobileDatabasesPath?.trim() ?? '';
    if (dbBase.isEmpty) {
      throw ArgumentError('mobileDatabasesPath is required for mobile platforms');
    }
    return join(dbBase, dbName);
  }

  return join(executableDir, dbName);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/app_build_info.dart';

void main() {
  test('AppBuildInfo.displayVersion has expected v<name>+<number> format', () {
    final version = AppBuildInfo.displayVersion();
    expect(version.startsWith('v'), isTrue);
    expect(version.contains('+'), isTrue);
  });
}

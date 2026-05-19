import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/dashboard_background_style.dart';

void main() {
  group('DashboardBackgroundStyle', () {
    test('points to a non-empty dashboard image asset', () {
      expect(DashboardBackgroundStyle.imageAssetPath, isNotEmpty);
      expect(
        DashboardBackgroundStyle.imageAssetPath,
        equals('assets/images/marnisi_home_bg.jpg'),
      );
    });

    test('uses a visible overlay for foreground readability', () {
      expect(DashboardBackgroundStyle.overlayColor.opacity, greaterThan(0.0));
      expect(DashboardBackgroundStyle.overlayColor.opacity, lessThan(1.0));
    });
  });
}

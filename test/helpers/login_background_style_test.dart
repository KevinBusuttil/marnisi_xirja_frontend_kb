import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/login_background_style.dart';

void main() {
  group('LoginBackgroundStyle', () {
    test('points to a non-empty login image asset', () {
      expect(LoginBackgroundStyle.imageAssetPath, isNotEmpty);
      expect(
        LoginBackgroundStyle.imageAssetPath,
        equals('assets/images/marnisi_home_bg.jpg'),
      );
    });

    test('uses a visible overlay and blur amount', () {
      expect(LoginBackgroundStyle.blurSigma, greaterThan(0));
      expect(LoginBackgroundStyle.overlayColor.opacity, greaterThan(0));
    });
  });
}

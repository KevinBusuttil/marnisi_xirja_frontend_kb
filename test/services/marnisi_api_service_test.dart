import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/services/marnisi_api_service.dart';

void main() {
  group('MarnisiSessionContext role gates', () {
    test('canAdminMutate true for vineyard admin', () {
      const context = MarnisiSessionContext(
        user: 'admin@example.com',
        roles: ['Vineyard Admin'],
        vineyards: [],
        defaultVineyard: '',
      );

      expect(context.canAdminMutate, isTrue);
      expect(context.canStaffMutate, isTrue);
      expect(context.isViewerOnly, isFalse);
    });

    test('viewer is read-only', () {
      const context = MarnisiSessionContext(
        user: 'viewer@example.com',
        roles: ['Viewer'],
        vineyards: [],
        defaultVineyard: '',
      );

      expect(context.canAdminMutate, isFalse);
      expect(context.canStaffMutate, isFalse);
      expect(context.isViewerOnly, isTrue);
    });

    test('staff can mutate booking operations', () {
      const context = MarnisiSessionContext(
        user: 'staff@example.com',
        roles: ['Vineyard Staff'],
        vineyards: [],
        defaultVineyard: '',
      );

      expect(context.canAdminMutate, isFalse);
      expect(context.canStaffMutate, isTrue);
      expect(context.isViewerOnly, isFalse);
    });
  });

  test('context keeps optional ui asset paths', () {
    const context = MarnisiSessionContext(
      user: 'admin@example.com',
      roles: ['Vineyard Admin'],
      vineyards: [],
      defaultVineyard: "Marnisi M'Xlokk",
      loginBackgroundImagePath: '/files/login-bg.jpg',
      appBackgroundImagePath: '/files/app-bg.jpg',
    );

    expect(context.loginBackgroundImagePath, '/files/login-bg.jpg');
    expect(context.appBackgroundImagePath, '/files/app-bg.jpg');
  });
}

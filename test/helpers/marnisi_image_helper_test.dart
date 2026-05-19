import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarnisiImageHelper.resolveItemImagePath', () {
    test('keeps flutter asset path unchanged', () {
      final value = MarnisiImageHelper.resolveItemImagePath(
        rawPath: 'assets/items/3.png',
        apiBaseUrl: 'http://146.190.236.171',
      );
      expect(value, 'assets/items/3.png');
    });

    test('expands relative backend file path using api base url', () {
      final value = MarnisiImageHelper.resolveItemImagePath(
        rawPath: '/files/item-1.jpg',
        apiBaseUrl: 'http://146.190.236.171',
      );
      expect(value, 'http://146.190.236.171/files/item-1.jpg');
    });

    test('uses default item asset when value is missing', () {
      final value = MarnisiImageHelper.resolveItemImagePath(
        rawPath: '',
        apiBaseUrl: 'http://146.190.236.171',
      );
      expect(value, MarnisiImageHelper.fallbackItemAssetPath);
    });
  });

  group('MarnisiImageHelper.persistBackgroundPaths', () {
    test('stores resolved backend image URLs in preferences', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.apiBaseUrl: 'http://146.190.236.171',
      });

      await MarnisiImageHelper.persistBackgroundPaths(
        loginBackgroundPath: '/files/login-bg.jpg',
        appBackgroundPath: '/files/app-bg.jpg',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MarnisiImageHelper.loginBackgroundPrefsKey),
        'http://146.190.236.171/files/login-bg.jpg',
      );
      expect(
        prefs.getString(MarnisiImageHelper.appBackgroundPrefsKey),
        'http://146.190.236.171/files/app-bg.jpg',
      );
    });

    test('stores local asset background paths as-is', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.apiBaseUrl: 'http://146.190.236.171',
      });

      await MarnisiImageHelper.persistBackgroundPaths(
        loginBackgroundPath: 'assets/images/login.jpg',
        appBackgroundPath: 'assets/images/app.jpg',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(MarnisiImageHelper.loginBackgroundPrefsKey),
        'assets/images/login.jpg',
      );
      expect(
        prefs.getString(MarnisiImageHelper.appBackgroundPrefsKey),
        'assets/images/app.jpg',
      );
    });

    test('removes saved background paths when backend returns empty values',
        () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.apiBaseUrl: 'http://146.190.236.171',
        MarnisiImageHelper.loginBackgroundPrefsKey:
            'http://146.190.236.171/files/old-login.jpg',
        MarnisiImageHelper.appBackgroundPrefsKey:
            'http://146.190.236.171/files/old-app.jpg',
      });

      await MarnisiImageHelper.persistBackgroundPaths(
        loginBackgroundPath: '',
        appBackgroundPath: '',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(MarnisiImageHelper.loginBackgroundPrefsKey),
        isFalse,
      );
      expect(
        prefs.containsKey(MarnisiImageHelper.appBackgroundPrefsKey),
        isFalse,
      );
    });
  });

  group('MarnisiImageHelper.networkImageHeadersForPath', () {
    test('adds cookie header for private file URLs', () {
      final headers = MarnisiImageHelper.networkImageHeadersForPath(
        path: 'http://146.190.236.171/private/files/item.jpg',
        sessionCookie: 'sid=abc123',
      );
      expect(headers, {'Cookie': 'sid=abc123'});
    });

    test('returns empty headers for public file URLs', () {
      final headers = MarnisiImageHelper.networkImageHeadersForPath(
        path: 'http://146.190.236.171/files/item.jpg',
        sessionCookie: 'sid=abc123',
      );
      expect(headers, isEmpty);
    });

    test('returns empty headers when cookie is missing', () {
      final headers = MarnisiImageHelper.networkImageHeadersForPath(
        path: '/private/files/item.jpg',
        sessionCookie: '',
      );
      expect(headers, isEmpty);
    });
  });

  group('MarnisiImageHelper.readSessionCookie', () {
    test('reads saved session cookie from preferences', () async {
      SharedPreferences.setMockInitialValues({
        MarnisiImageHelper.sessionCookiePrefsKey: 'sid=marnisi-session',
      });

      final cookie = await MarnisiImageHelper.readSessionCookie();
      expect(cookie, 'sid=marnisi-session');
    });
  });
}

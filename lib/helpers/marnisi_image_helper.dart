import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/api_base_url_helper.dart';

class MarnisiImageHelper {
  static const String fallbackItemAssetPath = 'assets/items/1.png';
  static const String loginBackgroundPrefsKey = 'MARNISI_LOGIN_BG_URL';
  static const String appBackgroundPrefsKey = 'MARNISI_APP_BG_URL';
  static const String sessionCookiePrefsKey = 'marnisi_sid_cookie';

  static String resolveItemImagePath({
    required String? rawPath,
    required String apiBaseUrl,
  }) {
    final resolved = _resolvePath(
      rawPath: rawPath,
      apiBaseUrl: apiBaseUrl,
    );
    if (resolved.isEmpty) {
      return fallbackItemAssetPath;
    }
    return resolved;
  }

  static bool isNetworkImagePath(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://');
  }

  static bool isAssetImagePath(String path) {
    return path.trim().startsWith('assets/');
  }

  static bool isPrivateFilePath(String path) {
    final normalized = path.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.startsWith('/private/files/')) {
      return true;
    }
    return normalized.contains('/private/files/');
  }

  static Map<String, String> networkImageHeadersForPath({
    required String path,
    required String sessionCookie,
  }) {
    final cookie = sessionCookie.trim();
    if (cookie.isEmpty || !isPrivateFilePath(path)) {
      return const <String, String>{};
    }
    return <String, String>{
      'Cookie': cookie,
    };
  }

  static Future<String> readSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(sessionCookiePrefsKey) ?? '').trim();
  }

  static Future<void> persistBackgroundPaths({
    required String? loginBackgroundPath,
    required String? appBackgroundPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final apiBaseUrl = (prefs.getString(StorageKeys.apiBaseUrl) ??
            prefs.getString('apiBaseUrl') ??
            '')
        .trim();

    final resolvedLogin = _resolvePath(
      rawPath: loginBackgroundPath,
      apiBaseUrl: apiBaseUrl,
    );
    final resolvedApp = _resolvePath(
      rawPath: appBackgroundPath,
      apiBaseUrl: apiBaseUrl,
    );

    if (resolvedLogin.isNotEmpty) {
      await prefs.setString(loginBackgroundPrefsKey, resolvedLogin);
    } else {
      await prefs.remove(loginBackgroundPrefsKey);
    }

    if (resolvedApp.isNotEmpty) {
      await prefs.setString(appBackgroundPrefsKey, resolvedApp);
    } else {
      await prefs.remove(appBackgroundPrefsKey);
    }
  }

  static Future<String?> readLoginBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = (prefs.getString(loginBackgroundPrefsKey) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  static Future<String?> readAppBackgroundPath() async {
    final prefs = await SharedPreferences.getInstance();
    final value = (prefs.getString(appBackgroundPrefsKey) ?? '').trim();
    return value.isEmpty ? null : value;
  }

  static String _resolvePath({
    required String? rawPath,
    required String apiBaseUrl,
  }) {
    final source = (rawPath ?? '').trim();
    if (source.isEmpty) {
      return '';
    }

    if (isAssetImagePath(source) || isNetworkImagePath(source)) {
      return source;
    }

    if (source.startsWith('/files/') ||
        source.startsWith('/private/files/') ||
        source.startsWith('/assets/')) {
      final origin = ApiBaseUrlHelper.normalizeForStorage(apiBaseUrl);
      if (origin.isNotEmpty) {
        return '$origin$source';
      }
    }

    return source;
  }
}

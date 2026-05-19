import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/api_base_url_helper.dart';

void main() {
  group('ApiBaseUrlHelper.normalizeForStorage', () {
    test('normalizes host and port to http origin', () {
      final value =
          ApiBaseUrlHelper.normalizeForStorage('146.190.236.171:8000');
      expect(value, 'http://146.190.236.171:8000');
    });

    test('strips path from full URL input', () {
      final value = ApiBaseUrlHelper.normalizeForStorage(
        'http://146.190.236.171/desk/vineyard-item',
      );
      expect(value, 'http://146.190.236.171');
    });

    test('preserves https scheme', () {
      final value = ApiBaseUrlHelper.normalizeForStorage(
        'https://marnisi.example.com/desk',
      );
      expect(value, 'https://marnisi.example.com');
    });

    test('returns empty string for invalid input', () {
      expect(ApiBaseUrlHelper.normalizeForStorage(''), '');
      expect(ApiBaseUrlHelper.normalizeForStorage('ftp://example.com'), '');
      expect(ApiBaseUrlHelper.normalizeForStorage('not a valid url'), '');
    });
  });

  group('ApiBaseUrlHelper.buildEndpointUrl', () {
    test('builds endpoint URL from bare host input', () {
      final value = ApiBaseUrlHelper.buildEndpointUrl(
        baseInput: '146.190.236.171',
        endpointPath: '/api/method/xirja_marnisi.api.bridge.get_all_stores',
      );
      expect(
        value,
        'http://146.190.236.171/api/method/xirja_marnisi.api.bridge.get_all_stores',
      );
    });

    test('adds slash when endpoint path does not start with slash', () {
      final value = ApiBaseUrlHelper.buildEndpointUrl(
        baseInput: 'https://marnisi.example.com',
        endpointPath: 'api/method/xirja_marnisi.api.bridge.get_all_stores',
      );
      expect(
        value,
        'https://marnisi.example.com/api/method/xirja_marnisi.api.bridge.get_all_stores',
      );
    });

    test('throws when base host is invalid', () {
      expect(
        () => ApiBaseUrlHelper.buildEndpointUrl(
          baseInput: 'ftp://example.com',
          endpointPath: '/api/method/test',
        ),
        throwsException,
      );
    });
  });
}

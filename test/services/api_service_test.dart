import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'apiBaseUrl': '127.0.0.1:8080',
    });
  });

  group('ApiService.sendData', () {
    test('uses configured host and returns confirmations on 200', () async {
      Uri? capturedUrl;
      final api = ApiService(
        endpointPath: '/api/method/test',
        httpClient: MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode({
              'message': {
                'confirmations': [
                  {'sale_num': 'xar-1', 'status': 'synchronized'}
                ]
              }
            }),
            200,
          );
        }),
      );

      final messages = <String>[];
      final response = await api.sendData([
        {'sales_num': 'xar-1'}
      ], messages.add);

      expect(capturedUrl.toString(), 'http://127.0.0.1:8080/api/method/test');
      expect(response, isNotNull);
      expect(response!.single['sale_num'], 'xar-1');
      expect(messages, ['Data sent successfully']);
    });

    test('returns null and offline message on client exception', () async {
      final api = ApiService(
        endpointPath: '/api/method/test',
        httpClient: MockClient((_) async {
          throw http.ClientException('network unreachable');
        }),
      );

      final messages = <String>[];
      final response = await api.sendData([
        {'sales_num': 'xar-2'}
      ], messages.add);

      expect(response, isNull);
      expect(messages.single, 'Server unreachable. Saved locally.');
    });

    test('returns null and offline message on timeout', () async {
      final api = ApiService(
        endpointPath: '/api/method/test',
        requestTimeout: const Duration(milliseconds: 20),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
      );

      final messages = <String>[];
      final response = await api.sendData([
        {'sales_num': 'xar-3'}
      ], messages.add);

      expect(response, isNull);
      expect(messages.single, 'Server unreachable. Saved locally.');
    });

    test('normalizes full URL inputs and strips page paths', () async {
      SharedPreferences.setMockInitialValues({
        'apiBaseUrl': 'http://146.190.236.171/desk/vineyard-item',
      });

      Uri? capturedUrl;
      final api = ApiService(
        endpointPath: '/api/method/test',
        httpClient: MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode({
              'message': {
                'confirmations': [
                  {'sale_num': 'xar-4', 'status': 'synchronized'}
                ]
              }
            }),
            200,
          );
        }),
      );

      final response = await api.sendData([
        {'sales_num': 'xar-4'}
      ], (_) {});

      expect(capturedUrl.toString(), 'http://146.190.236.171/api/method/test');
      expect(response, isNotNull);
    });
  });

  group('ApiService.postArgs and fetchMessage', () {
    test('postArgs unwraps frappe message map', () async {
      final api = ApiService(
        endpointPath: '/api/method/test',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          final decoded = jsonDecode(request.body) as Map<String, dynamic>;
          expect(decoded.containsKey('args'), isTrue);
          return http.Response(
            jsonEncode({
              'message': {
                'status': 'success',
                'count': 2,
              }
            }),
            200,
          );
        }),
      );

      final result = await api.postArgs({'vineyard': 'VYD-NORTH'});

      expect(result['status'], 'success');
      expect(result['count'], 2);
    });

    test('fetchMessage unwraps frappe message map', () async {
      final api = ApiService(
        endpointPath: '/api/method/test-get',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          return http.Response(
            jsonEncode({
              'message': {
                'user': 'marnisi.admin@example.com',
                'roles': ['Vineyard Admin']
              }
            }),
            200,
          );
        }),
      );

      final result = await api.fetchMessage();

      expect(result['user'], 'marnisi.admin@example.com');
      expect((result['roles'] as List).single, 'Vineyard Admin');
    });
  });
}

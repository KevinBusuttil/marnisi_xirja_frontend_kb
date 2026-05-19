import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/api_base_url_helper.dart';

/// Class manage shared static preferences to get server name and endpoints
/// paramethers:
/// * [endpoint] path to send or get data
/// * [logger] manage logs
///

class ApiService {
  final String endpointPath;
  final logger = Logger(printer: PrettyPrinter());
  final Duration requestTimeout;
  final http.Client _httpClient;
  static const String _sessionCookieKey = 'marnisi_sid_cookie';

  ApiService({
    required this.endpointPath,
    Duration? requestTimeout,
    http.Client? httpClient,
  })  : requestTimeout = requestTimeout ?? const Duration(seconds: 8),
        _httpClient = httpClient ?? http.Client();

  static const String _offlineMessage = 'Server unreachable. Saved locally.';
  static const String _serverNoResponseMessage =
      'An error occurred: Server does not respond';

  Future<Map<String, String>> _jsonHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final cookie = await _getSessionCookie();
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{};
    final cookie = await _getSessionCookie();
    if (cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  Future<String> _getSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = prefs.getString(_sessionCookieKey)?.trim() ?? '';
    return cookie;
  }

  Future<void> _saveSessionCookie(http.Response response) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.trim().isEmpty) return;

    String? sidCookie;
    for (final part in setCookie.split(',')) {
      final candidate = part.trim();
      if (candidate.startsWith('sid=')) {
        sidCookie = candidate.split(';').first.trim();
        break;
      }
    }

    sidCookie ??= setCookie.split(';').first.trim();
    if (!sidCookie.startsWith('sid=')) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionCookieKey, sidCookie);
  }

  /// get host setted in configuration
  Future<String> _getHost() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? apiBaseUrl = prefs.getString('apiBaseUrl')?.trim();
    if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
      return apiBaseUrl;
    }

    final String? namespacedApiBaseUrl =
        prefs.getString(StorageKeys.apiBaseUrl)?.trim();
    return namespacedApiBaseUrl ?? '';
  }

  /// set the base path to get data
  Future<String> _getApiUrl() async {
    final host = await _getHost();
    return ApiBaseUrlHelper.buildEndpointUrl(
      baseInput: host,
      endpointPath: endpointPath,
    );
  }

  /// get the data from the server
  Future<Map<String, dynamic>> fetchData() async {
    final String apiUrl = await _getApiUrl();
    final headers = await _getHeaders();

    // Print cURL
    _printCurlCommand(
      method: 'GET',
      url: apiUrl,
      headers: headers,
    );

    try {
      final response = await _httpClient
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      log('🔍 API URL: $apiUrl');
      log('📡 Status: ${response.statusCode}');
      log('📦 Response: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to load data - ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Failed to load data - request timed out');
    } on http.ClientException catch (e) {
      throw Exception('Failed to load data - connection error: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> fetchMessage({
    Function(String message)? showSnackbar,
  }) async {
    final String apiUrl = await _getApiUrl();
    final headers = await _getHeaders();

    _printCurlCommand(
      method: 'GET',
      url: apiUrl,
      headers: headers,
    );

    try {
      final response = await _httpClient
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      if (response.statusCode == 200) {
        return _extractMessageMap(response.body);
      }
      throw Exception('Failed to load data - ${response.statusCode}');
    } on TimeoutException {
      showSnackbar?.call(_offlineMessage);
      throw Exception('Failed to load data - request timed out');
    } on http.ClientException catch (e) {
      showSnackbar?.call(_offlineMessage);
      throw Exception('Failed to load data - connection error: ${e.message}');
    }
  }

  // /// send data to the server
  Future<List<dynamic>?> sendData(
    List<Map<String, dynamic>> data,
    Function(String message) showSnackbar,
  ) async {
    try {
      String apiUrl = await _getApiUrl();
      String jsonOutput = jsonEncode({"sales": data});
      final headers = await _jsonHeaders();

      // Print cURL
      _printCurlCommand(
        method: 'POST',
        url: apiUrl,
        headers: headers,
        body: jsonOutput,
      );

      final response = await _httpClient
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: jsonOutput,
          )
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        List<dynamic> confirmations = responseData['message']['confirmations'];
        showSnackbar('Data sent successfully');
        return confirmations;
      } else if (response.statusCode == 400) {
        var responseData = jsonDecode(response.body);
        showSnackbar('Failed to process data: ${responseData['message']}');
      } else {
        showSnackbar('Failed to send data: ${response.statusCode}');
      }
    } on TimeoutException {
      showSnackbar(_offlineMessage);
    } on http.ClientException {
      showSnackbar(_offlineMessage);
    } catch (e) {
      showSnackbar(_serverNoResponseMessage);
    }

    return null; // Return null if the request fails
  }

  Future<Map<String, dynamic>?> postData(
    List<Map<String, dynamic>> data,
    Function(String message) showSnackbar,
  ) async {
    try {
      String apiUrl = await _getApiUrl();
      final headers = await _jsonHeaders();

      // 🔹 Convert list[0] (your single customer map) to JSON string
      String argsJson = jsonEncode(data.first);

      // 🔹 Wrap inside {"args": "..."}
      String requestBody = jsonEncode({"args": argsJson});

      log("Request Body: $requestBody");

      // Print cURL
      _printCurlCommand(
        method: 'POST',
        url: apiUrl,
        headers: headers,
        body: requestBody,
      );

      final response = await _httpClient
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: requestBody,
          )
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        showSnackbar('Data sent successfully');
        return responseData['message']; // return Map
      } else if (response.statusCode == 400) {
        var responseData = jsonDecode(response.body);
        showSnackbar('Failed to process data: ${responseData['message']}');
      } else {
        showSnackbar('Failed to send data: ${response.statusCode}');
      }
    } on TimeoutException {
      showSnackbar(_offlineMessage);
    } on http.ClientException {
      showSnackbar(_offlineMessage);
    } catch (e) {
      showSnackbar(_serverNoResponseMessage);
      log("Error in postData: $e");
    }

    return null; // Return null if the request fails
  }

  Future<Map<String, dynamic>> postArgs(
    Map<String, dynamic> args, {
    Function(String message)? showSnackbar,
  }) async {
    final requestBody = jsonEncode({"args": jsonEncode(args)});
    return _postAndExtractMessageMap(
      requestBody: requestBody,
      showSnackbar: showSnackbar,
    );
  }

  Future<Map<String, dynamic>> postBody(
    Map<String, dynamic> body, {
    Function(String message)? showSnackbar,
  }) async {
    final requestBody = jsonEncode(body);
    return _postAndExtractMessageMap(
      requestBody: requestBody,
      showSnackbar: showSnackbar,
    );
  }

  Future<Map<String, dynamic>> _postAndExtractMessageMap({
    required String requestBody,
    Function(String message)? showSnackbar,
  }) async {
    try {
      final String apiUrl = await _getApiUrl();
      final headers = await _jsonHeaders();

      _printCurlCommand(
        method: 'POST',
        url: apiUrl,
        headers: headers,
        body: requestBody,
      );

      final response = await _httpClient
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: requestBody,
          )
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      if (response.statusCode == 200) {
        return _extractMessageMap(response.body);
      }

      final decoded = _decodeBody(response.body);
      final serverMessage = _extractServerErrorMessage(decoded);
      throw Exception(
          serverMessage ?? 'Failed to send data: ${response.statusCode}');
    } on TimeoutException {
      showSnackbar?.call(_offlineMessage);
      throw Exception('Request timed out');
    } on http.ClientException catch (e) {
      showSnackbar?.call(_offlineMessage);
      throw Exception('Connection error: ${e.message}');
    } catch (e) {
      showSnackbar?.call(_serverNoResponseMessage);
      rethrow;
    }
  }

  /// retrieve last invoice num - obsolete
  Future<Map<String, dynamic>?> sendStoreId(
    String defaultStore, // Single store name to send
    String defaultRegister, // Single store name to send
    Function(String message) showSnackbar, // Callback to show a snackbar
  ) async {
    try {
      // Fetch API URL
      String apiUrl = await _getApiUrl();
      final headers = await _jsonHeaders();

      // Convert the single store name to JSON format
      String jsonOutput = jsonEncode(
          {"default_store": defaultStore, "default_register": defaultRegister});

      // Send the POST request
      final response = await _httpClient
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: jsonOutput,
          )
          .timeout(requestTimeout);
      await _saveSessionCookie(response);

      // Handle the response
      if (response.statusCode == 200) {
        // Successfully sent data, now parse the response
        var responseData = jsonDecode(response.body);
        // print("Response Data: $responseData");

        // Directly assign the inner message to a Map
        Map<String, dynamic>? confirmations =
            responseData['message']['message'];

        if (confirmations != null) {
          showSnackbar('Data sent successfully');
          var data = confirmations['confirmations'][0];
          // print("Confirmations Map: $data");
          return data;
        } else {
          showSnackbar('Failed to process data: Confirmations not found');
        }
      } else if (response.statusCode == 400) {
        // Server returned a bad request
        var responseData = jsonDecode(response.body);
        showSnackbar('Failed to process data: ${responseData['message']}');
      } else {
        // Handle other HTTP response statuses
        showSnackbar('Failed to send data: ${response.statusCode}');
      }
    } on TimeoutException {
      showSnackbar(_offlineMessage);
    } on http.ClientException {
      showSnackbar(_offlineMessage);
    } catch (e) {
      // Handle any errors that occurred during the request
      showSnackbar(_serverNoResponseMessage);
    }

    return null; // Return null if the request fails
  }

  /// 🔸 Helper: Print cURL Command
  void _printCurlCommand({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) {
    final buffer = StringBuffer();
    buffer.write("🌀 CURL COMMAND:\n");
    buffer.write("curl -X $method '$url'");

    // Headers
    headers?.forEach((key, value) {
      buffer.write(" \\\n  -H '$key: $value'");
    });

    // Body
    if (body != null && body.isNotEmpty) {
      final safeBody = body.replaceAll("'", r"'\''"); // escape single quotes
      buffer.write(" \\\n  -d '$safeBody'");
    }

    log(buffer.toString());
  }

  Map<String, dynamic> _extractMessageMap(String responseBody) {
    final decoded = _decodeBody(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid response format from server');
    }

    final message = decoded['message'];
    if (message is Map<String, dynamic>) {
      return message;
    }

    // Some endpoints may return a map directly without "message".
    return decoded;
  }

  dynamic _decodeBody(String responseBody) {
    try {
      return json.decode(responseBody);
    } catch (_) {
      return {};
    }
  }

  String? _extractServerErrorMessage(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    if (message is Map<String, dynamic>) {
      final nested = message['message'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested;
      }
      final exception = message['exception'];
      if (exception is String && exception.trim().isNotEmpty) {
        return exception;
      }
    }
    final exception = decoded['exception'];
    if (exception is String && exception.trim().isNotEmpty) {
      return exception;
    }
    return null;
  }
}

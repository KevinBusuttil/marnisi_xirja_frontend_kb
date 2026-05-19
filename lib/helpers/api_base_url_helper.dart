class ApiBaseUrlHelper {
  static final RegExp _hostPattern = RegExp(r'^[a-z0-9.-]+$');

  static String normalizeForStorage(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return '';
    }

    final uri = _parseLenient(raw);
    if (uri == null || uri.host.isEmpty) {
      return '';
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return '';
    }

    final host = uri.host.toLowerCase();
    if (!_hostPattern.hasMatch(host)) {
      return '';
    }

    if (uri.hasPort) {
      return '$scheme://$host:${uri.port}';
    }
    return '$scheme://$host';
  }

  static bool isValid(String input) {
    return normalizeForStorage(input).isNotEmpty;
  }

  static String buildEndpointUrl({
    required String baseInput,
    required String endpointPath,
  }) {
    final origin = normalizeForStorage(baseInput);
    if (origin.isEmpty) {
      throw Exception('Host not found in SharedPreferences');
    }

    final normalizedPath =
        endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    return '$origin$normalizedPath';
  }

  static Uri? _parseLenient(String raw) {
    final direct = Uri.tryParse(raw);
    if (direct != null && direct.host.isNotEmpty && direct.scheme.isNotEmpty) {
      return direct;
    }

    return Uri.tryParse('http://$raw');
  }
}

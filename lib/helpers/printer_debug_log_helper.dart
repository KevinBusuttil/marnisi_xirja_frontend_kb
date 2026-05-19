import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PrinterDebugLogHelper {
  const PrinterDebugLogHelper._();

  static const MethodChannel _channel = MethodChannel('xirja/printers');

  static bool _isAndroidPlatform() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static String _serializeData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return '';
    }
    final sanitized = <String, dynamic>{};
    data.forEach((key, value) {
      final asText = (value ?? '').toString();
      sanitized[key] = asText.length > 500
          ? '${asText.substring(0, 500)}…(truncated)'
          : asText;
    });
    return jsonEncode(sanitized);
  }

  static Future<void> append({
    required String scope,
    required String message,
    Map<String, dynamic>? data,
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ?? _isAndroidPlatform();
    if (!isAndroid) {
      return;
    }

    final invoker = invokeMethod ?? _channel.invokeMethod;
    final payload = <String, dynamic>{
      'scope': scope,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'data': _serializeData(data),
    };

    try {
      await invoker('appendDebugLog', payload);
    } catch (_) {
      // Never block payment/printing flow due to logger failures.
    }
  }

  static Future<String> getLogFilePath({
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ?? _isAndroidPlatform();
    if (!isAndroid) {
      return '';
    }
    final invoker = invokeMethod ?? _channel.invokeMethod;
    try {
      final path = await invoker('getDebugLogPath');
      return (path ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static Future<bool> clearLogFile({
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ?? _isAndroidPlatform();
    if (!isAndroid) {
      return false;
    }
    final invoker = invokeMethod ?? _channel.invokeMethod;
    try {
      final result = await invoker('clearDebugLog');
      return result == true;
    } catch (_) {
      return false;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:web_admin/helpers/printer_debug_log_helper.dart';

class AndroidPrinterDiscovery {
  const AndroidPrinterDiscovery._();

  static const String defaultPrinterName = 'Default Printer';
  // Use Bixolon SDK first for supported models; fallback is handled natively.
  static const bool _preferBixolonSdk = true;
  static const MethodChannel _channel = MethodChannel('xirja/printers');
  static final RegExp _macAddressRegex = RegExp(
    r'([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5})',
  );

  static Future<List<String>> getAvailablePrinters({
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ?? _isAndroidPlatform();
    await PrinterDebugLogHelper.append(
      scope: 'AndroidPrinterDiscovery.getAvailablePrinters',
      message: 'Request received',
      data: {
        'isAndroid': isAndroid,
      },
    );
    if (!isAndroid) {
      return const <String>[defaultPrinterName];
    }

    try {
      final invoker = invokeMethod ?? _channel.invokeMethod;
      final raw = await invoker('getPairedBluetoothPrinters');
      final printers = _normalizePrinterEntries(raw);
      await PrinterDebugLogHelper.append(
        scope: 'AndroidPrinterDiscovery.getAvailablePrinters',
        message: 'Paired printers resolved',
        data: {
          'count': printers.length,
          'printers': printers.join(' | '),
        },
      );
      return printers;
    } on PlatformException {
      await PrinterDebugLogHelper.append(
        scope: 'AndroidPrinterDiscovery.getAvailablePrinters',
        message: 'PlatformException while reading paired printers',
      );
      return const <String>[defaultPrinterName];
    } on MissingPluginException {
      await PrinterDebugLogHelper.append(
        scope: 'AndroidPrinterDiscovery.getAvailablePrinters',
        message: 'MissingPluginException while reading paired printers',
      );
      return const <String>[defaultPrinterName];
    }
  }

  @visibleForTesting
  static List<String> normalizePrinterEntriesForTest(dynamic raw) {
    return _normalizePrinterEntries(raw);
  }

  static bool _isAndroidPlatform() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static List<String> _normalizePrinterEntries(dynamic raw) {
    final printers = <String>[];
    final seen = <String>{};

    if (raw is List) {
      for (final entry in raw) {
        final normalized = _normalizePrinterEntry(entry);
        if (normalized.isEmpty || !seen.add(normalized)) {
          continue;
        }
        printers.add(normalized);
      }
    }

    if (printers.isEmpty) {
      return const <String>[defaultPrinterName];
    }

    return printers;
  }

  static Future<void> printRawReceipt({
    required String selectedPrinter,
    required String receiptText,
    required List<int> dataBytes,
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final isAndroid = isAndroidOverride ?? _isAndroidPlatform();
    await PrinterDebugLogHelper.append(
      scope: 'AndroidPrinterDiscovery.printRawReceipt',
      message: 'Print request received',
      data: {
        'isAndroid': isAndroid,
        'selectedPrinter': selectedPrinter,
        'payloadBytes': dataBytes.length,
        'textChars': receiptText.length,
      },
    );
    if (!isAndroid) {
      return;
    }

    final printerAddress = _extractPrinterAddress(selectedPrinter);
    if (printerAddress == null || printerAddress.isEmpty) {
      throw const FormatException('Invalid Bluetooth printer address.');
    }

    if (dataBytes.isEmpty) {
      throw const FormatException('Receipt payload is empty.');
    }

    final invoker = invokeMethod ?? _channel.invokeMethod;
    final printerName = _extractPrinterName(selectedPrinter);
    await PrinterDebugLogHelper.append(
      scope: 'AndroidPrinterDiscovery.printRawReceipt',
      message: 'Dispatching print request to method channel',
      data: {
        'printerAddress': printerAddress,
        'printerName': printerName,
      },
    );
    await invoker(
      'printRawReceipt',
      <String, dynamic>{
        'printerAddress': printerAddress,
        'printerName': printerName,
        'preferBixolonSdk': _preferBixolonSdk,
        'text': receiptText,
        'data': Uint8List.fromList(dataBytes),
      },
    );
    await PrinterDebugLogHelper.append(
      scope: 'AndroidPrinterDiscovery.printRawReceipt',
      message: 'Method channel print call succeeded',
      data: {
        'printerAddress': printerAddress,
        'printerName': printerName,
        'payloadBytes': dataBytes.length,
      },
    );
  }

  static Future<void> printSdkSampleReceipt({
    required String selectedPrinter,
    Future<dynamic> Function(String method, [dynamic arguments])? invokeMethod,
    bool? isAndroidOverride,
  }) async {
    final now = DateTime.now().toIso8601String();
    final sampleText = '''
MARNISI BIXOLON SDK SAMPLE
Generated: $now
------------------------------
1 x Sample Item        EUR 1.00
TOTAL                  EUR 1.00
Payment: Card BOV
THANK YOU
''';
    final samplePayload = Uint8List.fromList(sampleText.codeUnits);
    await PrinterDebugLogHelper.append(
      scope: 'AndroidPrinterDiscovery.printSdkSampleReceipt',
      message: 'Dispatching SDK sample receipt print',
      data: {
        'selectedPrinter': selectedPrinter,
        'payloadBytes': samplePayload.length,
      },
    );
    await printRawReceipt(
      selectedPrinter: selectedPrinter,
      receiptText: sampleText,
      dataBytes: samplePayload,
      invokeMethod: invokeMethod,
      isAndroidOverride: isAndroidOverride,
    );
  }

  @visibleForTesting
  static String? extractPrinterAddressForTest(String selectedPrinter) {
    return _extractPrinterAddress(selectedPrinter);
  }

  @visibleForTesting
  static String extractPrinterNameForTest(String selectedPrinter) {
    return _extractPrinterName(selectedPrinter);
  }

  static String _normalizePrinterEntry(dynamic entry) {
    if (entry is Map) {
      final name = (entry['name'] ?? '').toString().trim();
      final address = (entry['address'] ?? '').toString().trim();
      if (name.isNotEmpty && address.isNotEmpty) {
        return '$name ($address)';
      }
      if (name.isNotEmpty) {
        return name;
      }
      if (address.isNotEmpty) {
        return address;
      }
      return '';
    }

    final value = (entry ?? '').toString().trim();
    return value;
  }

  static String? _extractPrinterAddress(String selectedPrinter) {
    final value = selectedPrinter.trim();
    if (value.isEmpty || value == defaultPrinterName) {
      return null;
    }

    final match = _macAddressRegex.firstMatch(value);
    if (match != null) {
      return match.group(1)?.toUpperCase();
    }
    return value;
  }

  static String _extractPrinterName(String selectedPrinter) {
    final value = selectedPrinter.trim();
    if (value.isEmpty || value == defaultPrinterName) {
      return '';
    }

    final openingIndex = value.lastIndexOf('(');
    final closingIndex = value.lastIndexOf(')');
    if (openingIndex > 0 && closingIndex > openingIndex) {
      return value.substring(0, openingIndex).trim();
    }
    return value;
  }
}

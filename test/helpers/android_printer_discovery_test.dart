import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/android_printer_discovery.dart';

void main() {
  group('AndroidPrinterDiscovery.getAvailablePrinters', () {
    test('returns default printer on non-android platforms', () async {
      final printers = await AndroidPrinterDiscovery.getAvailablePrinters(
        isAndroidOverride: false,
      );

      expect(printers, [AndroidPrinterDiscovery.defaultPrinterName]);
    });

    test('normalizes paired printer entries from channel response', () async {
      final printers = await AndroidPrinterDiscovery.getAvailablePrinters(
        isAndroidOverride: true,
        invokeMethod: (_, [__]) async => [
          {'name': 'Thermal BT', 'address': 'AA:BB:CC:DD:EE:01'},
          {'name': 'Thermal BT', 'address': 'AA:BB:CC:DD:EE:01'},
          {'name': '', 'address': 'AA:BB:CC:DD:EE:02'},
          'Standalone Printer',
        ],
      );

      expect(
        printers,
        [
          'Thermal BT (AA:BB:CC:DD:EE:01)',
          'AA:BB:CC:DD:EE:02',
          'Standalone Printer',
        ],
      );
    });

    test('returns default printer when method channel fails', () async {
      final printers = await AndroidPrinterDiscovery.getAvailablePrinters(
        isAndroidOverride: true,
        invokeMethod: (_, [__]) async =>
            throw PlatformException(code: 'BLUETOOTH_PERMISSION_DENIED'),
      );

      expect(printers, [AndroidPrinterDiscovery.defaultPrinterName]);
    });
  });

  test('normalization fallback handles empty payload', () {
    expect(
      AndroidPrinterDiscovery.normalizePrinterEntriesForTest([]),
      [AndroidPrinterDiscovery.defaultPrinterName],
    );
  });

  group('AndroidPrinterDiscovery.printRawReceipt', () {
    test('extracts bluetooth address from selected printer label', () {
      expect(
        AndroidPrinterDiscovery.extractPrinterAddressForTest(
          'BIXOLON SPP-R310 (AA:BB:CC:DD:EE:FF)',
        ),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('keeps plain printer name for legacy saved selections', () {
      expect(
        AndroidPrinterDiscovery.extractPrinterAddressForTest(
            'BIXOLON SPP-R310'),
        'BIXOLON SPP-R310',
      );
    });

    test('extracts printer name from selected printer label', () {
      expect(
        AndroidPrinterDiscovery.extractPrinterNameForTest(
          'BIXOLON SPP-R310 (AA:BB:CC:DD:EE:FF)',
        ),
        'BIXOLON SPP-R310',
      );
    });

    test('returns plain printer name when no address suffix is present', () {
      expect(
        AndroidPrinterDiscovery.extractPrinterNameForTest('BIXOLON SPP-R310'),
        'BIXOLON SPP-R310',
      );
    });

    test('returns empty printer name for default placeholder selection', () {
      expect(
        AndroidPrinterDiscovery.extractPrinterNameForTest(
          AndroidPrinterDiscovery.defaultPrinterName,
        ),
        '',
      );
    });

    test('invokes channel with parsed address and payload on android',
        () async {
      String? calledMethod;
      Map<String, dynamic>? calledArguments;

      await AndroidPrinterDiscovery.printRawReceipt(
        selectedPrinter: 'BIXOLON SPP-R310 (AA:BB:CC:DD:EE:FF)',
        receiptText: 'Test receipt text',
        dataBytes: const [0x1B, 0x40, 0x0A],
        isAndroidOverride: true,
        invokeMethod: (method, [arguments]) async {
          calledMethod = method;
          calledArguments = (arguments as Map).cast<String, dynamic>();
          return true;
        },
      );

      expect(calledMethod, 'printRawReceipt');
      expect(calledArguments, isNotNull);
      expect(calledArguments!['printerAddress'], 'AA:BB:CC:DD:EE:FF');
      expect(calledArguments!['printerName'], 'BIXOLON SPP-R310');
      expect(calledArguments!['preferBixolonSdk'], isTrue);
      expect(calledArguments!['text'], 'Test receipt text');
      expect(calledArguments!['data'], const [0x1B, 0x40, 0x0A]);
    });

    test('throws when selected printer has no bluetooth address', () async {
      expect(
        () => AndroidPrinterDiscovery.printRawReceipt(
          selectedPrinter: AndroidPrinterDiscovery.defaultPrinterName,
          receiptText: 'some text',
          dataBytes: const [0x1B],
          isAndroidOverride: true,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('prints SDK sample receipt using same android print channel',
        () async {
      String? calledMethod;
      Map<String, dynamic>? calledArguments;

      await AndroidPrinterDiscovery.printSdkSampleReceipt(
        selectedPrinter: 'SPP-R310 (AA:BB:CC:DD:EE:FF)',
        isAndroidOverride: true,
        invokeMethod: (method, [arguments]) async {
          calledMethod = method;
          calledArguments = (arguments as Map).cast<String, dynamic>();
          return true;
        },
      );

      expect(calledMethod, 'printRawReceipt');
      expect(calledArguments, isNotNull);
      expect(calledArguments!['printerAddress'], 'AA:BB:CC:DD:EE:FF');
      expect(calledArguments!['printerName'], 'SPP-R310');
      expect(calledArguments!['preferBixolonSdk'], isTrue);
      final textPayload = calledArguments!['text'] as String;
      expect(textPayload, contains('MARNISI BIXOLON SDK SAMPLE'));
      expect(textPayload, contains('Payment: Card BOV'));
      // data bytes should mirror the text content
      final payload = List<int>.from(calledArguments!['data'] as List<int>);
      final payloadText = String.fromCharCodes(payload);
      expect(payloadText, contains('MARNISI BIXOLON SDK SAMPLE'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/receipt_printer_capabilities.dart';
import 'package:web_admin/services/printer_invoice_service.dart';

void main() {
  group('PrinterManagerInvoice.normalizeDiscountForReceipt', () {
    test('always returns positive discount display value', () {
      expect(PrinterManagerInvoice.normalizeDiscountForReceipt(8.6), 8.6);
      expect(PrinterManagerInvoice.normalizeDiscountForReceipt(-8.6), 8.6);
    });
  });

  group('PrinterManagerInvoice.buildReceiptTotalsBlock', () {
    test('renders discount before subtotal and without negative sign', () {
      final block = PrinterManagerInvoice.buildReceiptTotalsBlock(
        subTotal: 138.47,
        tax: 24.93,
        total: 163.40,
        discount: 8.60,
        boldOn: '<b>',
        boldOff: '</b>',
      );

      final discountIndex =
          block.indexOf('Discount                        EUR');
      final subTotalIndex =
          block.indexOf('SubTotal                        EUR');
      final taxIndex = block.indexOf('Tax                             EUR');
      final totalIndex = block.indexOf(' Total                           EUR');

      expect(discountIndex, greaterThanOrEqualTo(0));
      expect(subTotalIndex, greaterThan(discountIndex));
      expect(taxIndex, greaterThan(subTotalIndex));
      expect(totalIndex, greaterThan(taxIndex));
      expect(block, contains('EUR   8.60'));
      expect(block, isNot(contains('-8.60')));
    });
  });

  group('ReceiptPrinterCapabilities - SPP-R310 (Android Bluetooth)', () {
    test('sppR310Capabilities has no cutter and no cash drawer', () {
      expect(sppR310Capabilities.supportsCutter, isFalse);
      expect(sppR310Capabilities.supportsCashDrawer, isFalse);
    });

    test('sppR310Capabilities receipt ending does not contain cutter command',
        () {
      const escPosCutPaper = '\x1D\x56\x41\x00';
      final content = PrinterManagerInvoice.generateReceiptEndingForTest(
          sppR310Capabilities);
      expect(content, isNot(contains(escPosCutPaper)));
    });

    test(
        'sppR310Capabilities receipt ending does not contain cash drawer command',
        () {
      const openCashDrawer = '\x1B\x70\x00\x19\xFA';
      final content = PrinterManagerInvoice.generateReceiptEndingForTest(
          sppR310Capabilities);
      expect(content, isNot(contains(openCashDrawer)));
    });
  });

  group('ReceiptPrinterCapabilities - Windows native printer', () {
    test('windowsNativeCapabilities has cutter and cash drawer', () {
      expect(windowsNativeCapabilities.supportsCutter, isTrue);
      expect(windowsNativeCapabilities.supportsCashDrawer, isTrue);
    });

    test('windowsNativeCapabilities receipt ending contains cutter command',
        () {
      const escPosCutPaper = '\x1D\x56\x41\x00';
      final content = PrinterManagerInvoice.generateReceiptEndingForTest(
          windowsNativeCapabilities);
      expect(content, contains(escPosCutPaper));
    });

    test(
        'windowsNativeCapabilities receipt ending contains cash drawer command',
        () {
      const openCashDrawer = '\x1B\x70\x00\x19\xFA';
      final content = PrinterManagerInvoice.generateReceiptEndingForTest(
          windowsNativeCapabilities);
      expect(content, contains(openCashDrawer));
    });
  });
}

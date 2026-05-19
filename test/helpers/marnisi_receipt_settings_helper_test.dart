import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/helpers/marnisi_receipt_settings_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarnisiReceiptSettings.fromMap', () {
    test('uses defaults when map is empty', () {
      final settings = MarnisiReceiptSettings.fromMap(const {});

      expect(settings.receiptLineWidth, 48);
      expect(settings.receiptCurrencyLabel, 'EUR');
      expect(settings.showVatAnalysis, isTrue);
      expect(settings.thankYouLine, 'Thanks for your custom.');
    });

    test('parses backend overrides and normalizes values', () {
      final settings = MarnisiReceiptSettings.fromMap({
        'receipt_line_width': '42',
        'receipt_currency_label': 'USD',
        'show_vat_analysis': '0',
        'show_client_details': false,
        'show_store_header': 'no',
        'show_cash_summary': 'true',
        'show_opening_hours': 0,
        'vat_message_line': 'VAT included',
      });

      expect(settings.receiptLineWidth, 42);
      expect(settings.receiptCurrencyLabel, 'USD');
      expect(settings.showVatAnalysis, isFalse);
      expect(settings.showClientDetails, isFalse);
      expect(settings.showStoreHeader, isFalse);
      expect(settings.showCashSummary, isTrue);
      expect(settings.showOpeningHours, isFalse);
      expect(settings.vatMessageLine, 'VAT included');
    });
  });

  group('MarnisiReceiptSettingsHelper cache', () {
    test('persists and reads parsed settings from shared preferences',
        () async {
      SharedPreferences.setMockInitialValues({});

      await MarnisiReceiptSettingsHelper.persistFromBackend({
        'receipt_line_width': 40,
        'receipt_currency_label': 'CHF',
        'show_vat_analysis': false,
      });

      final settings = await MarnisiReceiptSettingsHelper.read();
      expect(settings.receiptLineWidth, 40);
      expect(settings.receiptCurrencyLabel, 'CHF');
      expect(settings.showVatAnalysis, isFalse);
      expect(settings.thankYouLine, 'Thanks for your custom.');
    });

    test('falls back to defaults when cached JSON is malformed', () async {
      SharedPreferences.setMockInitialValues({
        MarnisiReceiptSettingsHelper.receiptSettingsPrefsKey: '{',
      });

      final settings = await MarnisiReceiptSettingsHelper.read();
      expect(settings.receiptLineWidth, 48);
      expect(settings.receiptCurrencyLabel, 'EUR');
    });
  });
}

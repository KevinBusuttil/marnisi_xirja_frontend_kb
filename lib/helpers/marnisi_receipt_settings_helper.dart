import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MarnisiReceiptSettings {
  static const int _defaultLineWidth = 48;

  final int receiptLineWidth;
  final String receiptCurrencyLabel;
  final bool showStoreHeader;
  final bool showClientDetails;
  final bool showCashSummary;
  final bool showVatAnalysis;
  final bool showOpeningHours;
  final bool showLoyaltySection;
  final String vatMessageLine;
  final String fiscalMessageLine;
  final String thankYouLine;
  final String giftReceiptTitle;
  final String giftReceiptFooter;

  const MarnisiReceiptSettings({
    this.receiptLineWidth = _defaultLineWidth,
    this.receiptCurrencyLabel = 'EUR',
    this.showStoreHeader = true,
    this.showClientDetails = true,
    this.showCashSummary = true,
    this.showVatAnalysis = true,
    this.showOpeningHours = true,
    this.showLoyaltySection = true,
    this.vatMessageLine = 'All items Include VAT.',
    this.fiscalMessageLine = 'This is a Fiscal Receipt.',
    this.thankYouLine = 'Thanks for your custom.',
    this.giftReceiptTitle = 'Gift Receipt',
    this.giftReceiptFooter = 'Enjoy your custom',
  });

  factory MarnisiReceiptSettings.fromMap(Map<String, dynamic> map) {
    return MarnisiReceiptSettings(
      receiptLineWidth: _parsePositiveInt(
        map['receipt_line_width'],
        fallback: _defaultLineWidth,
      ),
      receiptCurrencyLabel: _parseText(
        map['receipt_currency_label'],
        fallback: 'EUR',
      ),
      showStoreHeader: _parseBool(
        map['show_store_header'],
        fallback: true,
      ),
      showClientDetails: _parseBool(
        map['show_client_details'],
        fallback: true,
      ),
      showCashSummary: _parseBool(
        map['show_cash_summary'],
        fallback: true,
      ),
      showVatAnalysis: _parseBool(
        map['show_vat_analysis'],
        fallback: true,
      ),
      showOpeningHours: _parseBool(
        map['show_opening_hours'],
        fallback: true,
      ),
      showLoyaltySection: _parseBool(
        map['show_loyalty_section'],
        fallback: true,
      ),
      vatMessageLine: _parseText(
        map['vat_message_line'],
        fallback: 'All items Include VAT.',
      ),
      fiscalMessageLine: _parseText(
        map['fiscal_message_line'],
        fallback: 'This is a Fiscal Receipt.',
      ),
      thankYouLine: _parseText(
        map['thank_you_line'],
        fallback: 'Thanks for your custom.',
      ),
      giftReceiptTitle: _parseText(
        map['gift_receipt_title'],
        fallback: 'Gift Receipt',
      ),
      giftReceiptFooter: _parseText(
        map['gift_receipt_footer'],
        fallback: 'Enjoy your custom',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receipt_line_width': receiptLineWidth,
      'receipt_currency_label': receiptCurrencyLabel,
      'show_store_header': showStoreHeader,
      'show_client_details': showClientDetails,
      'show_cash_summary': showCashSummary,
      'show_vat_analysis': showVatAnalysis,
      'show_opening_hours': showOpeningHours,
      'show_loyalty_section': showLoyaltySection,
      'vat_message_line': vatMessageLine,
      'fiscal_message_line': fiscalMessageLine,
      'thank_you_line': thankYouLine,
      'gift_receipt_title': giftReceiptTitle,
      'gift_receipt_footer': giftReceiptFooter,
    };
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() != 0;
    }

    final text = (value ?? '').toString().trim().toLowerCase();
    if (text.isEmpty) {
      return fallback;
    }
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on';
  }

  static int _parsePositiveInt(dynamic value, {required int fallback}) {
    final parsed = int.tryParse((value ?? '').toString().trim());
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return parsed;
  }

  static String _parseText(dynamic value, {required String fallback}) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

class MarnisiReceiptSettingsHelper {
  static const String receiptSettingsPrefsKey = 'MARNISI_RECEIPT_SETTINGS_JSON';

  static Future<void> persistFromBackend(
    Map<String, dynamic>? settings,
  ) async {
    if (settings == null || settings.isEmpty) {
      return;
    }

    final parsed = MarnisiReceiptSettings.fromMap(settings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      receiptSettingsPrefsKey,
      jsonEncode(parsed.toMap()),
    );
  }

  static Future<MarnisiReceiptSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(receiptSettingsPrefsKey) ?? '').trim();
    if (raw.isEmpty) {
      return const MarnisiReceiptSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MarnisiReceiptSettings.fromMap(decoded);
      }
      if (decoded is Map) {
        return MarnisiReceiptSettings.fromMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // Fallback to defaults when cache is malformed.
    }

    return const MarnisiReceiptSettings();
  }
}

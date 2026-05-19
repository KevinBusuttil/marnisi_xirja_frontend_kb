import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/helpers/android_printer_discovery.dart';
import 'package:web_admin/helpers/loyalty_receipt_helper.dart';
import 'package:web_admin/helpers/marnisi_receipt_settings_helper.dart';
import 'package:web_admin/helpers/printer_debug_log_helper.dart';
import 'package:web_admin/helpers/printer_platform_helper.dart';
import 'package:web_admin/helpers/receipt_printer_capabilities.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/helpers/printer_port_helper.dart';

/// Class manages print format for invoices
///
class PrinterManagerInvoice {
  late String selectedPrinter;
  final Function(String, String) showDialog;
  final Function(String, dynamic) clearOrder;
  final Function onClear;
  final logger = Logger(printer: PrettyPrinter());

  PrinterManagerInvoice({
    required this.showDialog,
    this.clearOrder = _emptyClearOrder,
    this.onClear = _emptyOnClear,
  });

  static void _emptyOnClear() {}
  static void _emptyClearOrder(String title, dynamic message) {}

  Future<void> _appendPrintDebug(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    await PrinterDebugLogHelper.append(
      scope: 'PrinterManagerInvoice',
      message: message,
      data: data,
    );
  }

  /// load the printer
  Future<void> loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    selectedPrinter = prefs.getString('selectedPrinter') ?? '';
    await _appendPrintDebug(
      'Loaded selected printer from preferences',
      data: {
        'selectedPrinter': selectedPrinter,
      },
    );
    if (selectedPrinter.isEmpty) {
      showDialog('Error', 'No printer selected.');
      await _appendPrintDebug('No printer selected');
    }
  }

  Future<String> generateInvoicePreview({
    String isCopyReceipt = '',
    required String payMethod,
    double change = 0.0,
    double cashTendered = 0.0,
    required List<Map<String, dynamic>> orderItems,
    required double subTotal,
    required double tax,
    required double total,
    required double discount,
    required String orderNumber,
    required String vatNum,
    required String employeeNum,
    String clientNum = "",
    String clientName = "",
    String loyaltyCardNum = "",
    double loyaltyPointsused = 0.0,
    double loyaltyRewardAmount = 0.0,
    double loyaltyPointsBalance = 0.0,
    bool showLoyaltyDetails = true,
    String formattedDate = '',
    String formattedTime = '',
  }) async {
    // If date/time not provided
    formattedDate = formattedDate.isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : formattedDate;
    formattedTime = formattedTime.isEmpty
        ? DateFormat('kk:mm:ss').format(DateTime.now())
        : formattedTime;

    // 🚀 Get actual store information
    final storeInfo = await _getStoreInfo();

    if (storeInfo == null) {
      return 'Store information missing';
    }
    final receiptSettings = await MarnisiReceiptSettingsHelper.read();

    // For preview, use Windows capabilities (full hardware commands for display preview context)
    return _generateInvoiceContent(
      capabilities: windowsNativeCapabilities,
      settings: receiptSettings,
      isCopyReceipt: isCopyReceipt,
      storeName: storeInfo['stores_name'] ?? '',
      storeAddress: storeInfo['stores_address'] ?? '',
      storeCountry: storeInfo['stores_country'] ?? '',
      storePhoneNum: storeInfo['stores_phone_num'] ?? '',
      storeRegNum: storeInfo['stores_registration_num'] ?? '',
      storeBCRS: storeInfo['stores_bcrs_code'] ?? '',
      storeOpeningHours: storeInfo['stores_opening_hours'] ?? '',
      orderNumber: orderNumber,
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      orderItems: orderItems,
      subTotal: subTotal,
      tax: tax,
      total: total,
      discount: discount,
      change: change,
      cashTendered: cashTendered,
      payMethod: payMethod,
      vatNum: vatNum,
      clientNum: clientNum,
      employeeNum: employeeNum,
      clientName: clientName,
      loyaltyCardNum: loyaltyCardNum,
      loyaltyPointsused: loyaltyPointsused,
      loyaltyRewardAmount: loyaltyRewardAmount,
      loyaltyPointsBalance: loyaltyPointsBalance,
      showLoyaltyDetails: showLoyaltyDetails,
    );
  }

  /// print receipt
  Future<void> printReceipt({
    String isCopyReceipt = '',
    required String payMethod,
    double change = 0.0,
    double cashTendered = 0.0,
    String formattedDate = '',
    String formattedTime = '',
    required List<Map<String, dynamic>> orderItems,
    required double subTotal,
    required double tax,
    required double total,
    required double discount,
    required String orderNumber,
    required String vatNum,
    required String employeeNum,
    String clientNum = "",
    String clientName = "",
    String loyaltyCardNum = "",
    double loyaltyPointsused = 0.0,
    double loyaltyRewardAmount = 0.0,
    double loyaltyPointsBalance = 0.0,
    bool showLoyaltyDetails = true,
  }) async {
    await _appendPrintDebug(
      'printReceipt start',
      data: {
        'orderNumber': orderNumber,
        'payMethod': payMethod,
        'orderItemsCount': orderItems.length,
        'subTotal': subTotal,
        'tax': tax,
        'total': total,
        'discount': discount,
      },
    );
    await loadSelectedPrinter();
    if (selectedPrinter.isEmpty) {
      await _appendPrintDebug('printReceipt aborted: selected printer empty');
      return;
    }

    /// Get date and time if not provided
    formattedDate = formattedDate.isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : formattedDate;
    formattedTime = formattedTime.isEmpty
        ? DateFormat('kk:mm:ss').format(DateTime.now())
        : formattedTime;

    final storeInfo = await _getStoreInfo();

    if (storeInfo == null) {
      showDialog('Error', 'Store information is missing.');
      await _appendPrintDebug(
          'printReceipt aborted: store information missing');
      return;
    }
    final receiptSettings = await MarnisiReceiptSettingsHelper.read();

    final capabilities = PrinterPlatformHelper.supportsCashDrawer()
        ? windowsNativeCapabilities
        : sppR310Capabilities;

    /// generate invoice content
    final invoiceContent = _generateInvoiceContent(
      capabilities: capabilities,
      settings: receiptSettings,
      isCopyReceipt: isCopyReceipt,
      storeName: storeInfo['stores_name'] ?? '',
      storeAddress: storeInfo['stores_address'] ?? '',
      storeCountry: storeInfo['stores_country'] ?? '',
      storePhoneNum: storeInfo['stores_phone_num'] ?? '',
      storeRegNum: storeInfo['stores_registration_num'] ?? '',
      storeBCRS: storeInfo['stores_bcrs_code'] ?? '',
      storeOpeningHours: storeInfo['stores_opening_hours'] ?? '',
      orderNumber: orderNumber,
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      orderItems: orderItems,
      subTotal: subTotal,
      tax: tax,
      total: total,
      discount: discount,
      change: change,
      cashTendered: cashTendered,
      payMethod: payMethod,
      vatNum: vatNum,
      clientNum: clientNum,
      employeeNum: employeeNum,
      clientName: clientName,
      loyaltyCardNum: loyaltyCardNum,
      loyaltyPointsused: loyaltyPointsused,
      loyaltyRewardAmount: loyaltyRewardAmount,
      loyaltyPointsBalance: loyaltyPointsBalance,
      showLoyaltyDetails: showLoyaltyDetails,
    );
    await _appendPrintDebug(
      'Invoice content generated',
      data: {
        'length': invoiceContent.length,
      },
    );

    if (PrinterPlatformHelper.supportsCashDrawer()) {
      await _appendPrintDebug('Using native cash drawer printer path');
      final printerPortManager = PrinterPortManager();
      if (!await _initializePrinter(printerPortManager)) return;
      await _sendToPrinter(
          printerPortManager, invoiceContent, change, payMethod);
      debugPrint(invoiceContent);
      return;
    }

    if (!PrinterPlatformHelper.supportsNativePrinter()) {
      showDialog('Message', 'Printing is not supported on this platform.');
      await _appendPrintDebug(
        'printReceipt aborted: platform does not support native printer',
      );
      return;
    }

    try {
      final sanitizedContent = _sanitizeForBluetoothPrinter(invoiceContent);
      final dataBytes = utf8.encode(sanitizedContent);
      await _appendPrintDebug(
        'Prepared sanitized bluetooth payload',
        data: {
          'sanitizedLength': sanitizedContent.length,
          'payloadBytes': dataBytes.length,
          'selectedPrinter': selectedPrinter,
        },
      );
      await AndroidPrinterDiscovery.printRawReceipt(
        selectedPrinter: selectedPrinter,
        receiptText: sanitizedContent,
        dataBytes: dataBytes,
      );
      await _appendPrintDebug(
        'Bluetooth print call completed',
        data: {
          'payloadBytes': dataBytes.length,
          'selectedPrinter': selectedPrinter,
        },
      );
      _onPrintCompleted(change, payMethod);
      debugPrint(invoiceContent);
    } on FormatException catch (e, st) {
      showDialog('Message', e.message);
      await _appendPrintDebug(
        'FormatException during printReceipt',
        data: {'error': e.message, 'stack': st.toString()},
      );
    } on PlatformException catch (e, st) {
      showDialog('Message', e.message ?? 'Could not send data to printer.');
      logger.e('Android print platform exception: $e');
      await _appendPrintDebug(
        'PlatformException during printReceipt',
        data: {
          'code': e.code,
          'message': e.message ?? '',
          'details': (e.details ?? '').toString(),
          'stack': st.toString(),
        },
      );
    } catch (e, st) {
      showDialog('Message', 'Printing failed: $e');
      logger.e('Unexpected Android print error: $e');
      await _appendPrintDebug(
        'Unexpected error during printReceipt',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  /// print gift receipt
  Future<void> printGiftReceipt({
    required String payMethod,
    double change = 0.0,
    String formattedDate = '',
    String formattedTime = '',
    required List<Map<String, dynamic>> orderItems,
    double subTotal = 0,
    double tax = 0,
    double total = 0,
    double discount = 0,
    required String orderNumber,
    required String vatNum,
    required String employeeNum,
    String clientNum = "",
    String clientName = "",
  }) async {
    await _appendPrintDebug(
      'printGiftReceipt start',
      data: {
        'orderNumber': orderNumber,
        'payMethod': payMethod,
        'orderItemsCount': orderItems.length,
      },
    );
    await loadSelectedPrinter();
    if (selectedPrinter.isEmpty) {
      await _appendPrintDebug(
          'printGiftReceipt aborted: selected printer empty');
      return;
    }

    /// Get date and time if not provided
    formattedDate = formattedDate.isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : formattedDate;
    formattedTime = formattedTime.isEmpty
        ? DateFormat('kk:mm:ss').format(DateTime.now())
        : formattedTime;

    final storeInfo = await _getStoreInfo();

    if (storeInfo == null) {
      showDialog('Error', 'Store information is missing.');
      await _appendPrintDebug(
          'printGiftReceipt aborted: store information missing');
      return;
    }
    final receiptSettings = await MarnisiReceiptSettingsHelper.read();

    final capabilities = PrinterPlatformHelper.supportsCashDrawer()
        ? windowsNativeCapabilities
        : sppR310Capabilities;

    /// generate invoice content
    final invoiceContent = _generateGiftReceipt(
      capabilities: capabilities,
      settings: receiptSettings,
      storeName: storeInfo['stores_name'] ?? '',
      storeAddress: storeInfo['stores_address'] ?? '',
      storeCountry: storeInfo['stores_country'] ?? '',
      storePhoneNum: storeInfo['stores_phone_num'] ?? '',
      storeRegNum: storeInfo['stores_registration_num'] ?? '',
      storeBCRS: storeInfo['stores_bcrs_code'] ?? '',
      storeOpeningHours: storeInfo['stores_opening_hours'] ?? '',
      orderNumber: orderNumber,
      formattedDate: formattedDate,
      formattedTime: formattedTime,
      orderItems: orderItems,
      vatNum: vatNum,
      clientNum: clientNum,
      employeeNum: employeeNum,
      clientName: clientName,
    );
    await _appendPrintDebug(
      'Gift receipt content generated',
      data: {
        'length': invoiceContent.length,
      },
    );

    if (PrinterPlatformHelper.supportsCashDrawer()) {
      await _appendPrintDebug('Using native cash drawer gift printer path');
      final printerPortManager = PrinterPortManager();
      if (!await _initializePrinter(printerPortManager)) return;
      await _sendToPrinter(
          printerPortManager, invoiceContent, change, payMethod);
      return;
    }

    if (!PrinterPlatformHelper.supportsNativePrinter()) {
      showDialog('Message', 'Printing is not supported on this platform.');
      await _appendPrintDebug(
        'printGiftReceipt aborted: platform does not support native printer',
      );
      return;
    }

    try {
      final sanitizedContent = _sanitizeForBluetoothPrinter(invoiceContent);
      final dataBytes = utf8.encode(sanitizedContent);
      await _appendPrintDebug(
        'Prepared sanitized bluetooth gift payload',
        data: {
          'sanitizedLength': sanitizedContent.length,
          'payloadBytes': dataBytes.length,
          'selectedPrinter': selectedPrinter,
        },
      );
      await AndroidPrinterDiscovery.printRawReceipt(
        selectedPrinter: selectedPrinter,
        receiptText: sanitizedContent,
        dataBytes: dataBytes,
      );
      await _appendPrintDebug(
        'Bluetooth gift print call completed',
        data: {
          'payloadBytes': dataBytes.length,
          'selectedPrinter': selectedPrinter,
        },
      );
      _onPrintCompleted(change, payMethod);
    } on FormatException catch (e, st) {
      showDialog('Message', e.message);
      await _appendPrintDebug(
        'FormatException during printGiftReceipt',
        data: {'error': e.message, 'stack': st.toString()},
      );
    } on PlatformException catch (e, st) {
      showDialog('Message', e.message ?? 'Could not send data to printer.');
      logger.e('Android gift print platform exception: $e');
      await _appendPrintDebug(
        'PlatformException during printGiftReceipt',
        data: {
          'code': e.code,
          'message': e.message ?? '',
          'details': (e.details ?? '').toString(),
          'stack': st.toString(),
        },
      );
    } catch (e, st) {
      showDialog('Message', 'Printing failed: $e');
      logger.e('Unexpected Android gift print error: $e');
      await _appendPrintDebug(
        'Unexpected error during printGiftReceipt',
        data: {'error': e.toString(), 'stack': st.toString()},
      );
    }
  }

  /// get store information from the db
  Future<Map<String, dynamic>?> _getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String storeName = prefs.getString('selectedStore') ?? '';
    final dbHelper = SqlLiteService();
    return await dbHelper.getInfoStore(storeName);
  }

  /// start the printer
  Future<bool> _initializePrinter(PrinterPortManager printerPortManager) async {
    await _appendPrintDebug(
      'Initializing printer port manager',
      data: {'selectedPrinter': selectedPrinter},
    );
    printerPortManager.initializeComPort();

    /// open printer
    if (!printerPortManager.openPrinter(selectedPrinter)) {
      showDialog('Message', 'The printer could not be opened.');
      printerPortManager.closeComPort();
      await _appendPrintDebug('openPrinter failed');
      return false;
    }

    /// start document
    if (!printerPortManager.startDocument()) {
      showDialog('Message', 'Could not start document.');
      _closePrinter(printerPortManager);
      await _appendPrintDebug('startDocument failed');
      return false;
    }

    await _appendPrintDebug('Printer initialized successfully');
    return true;
  }

  /// Send data to printer
  Future<void> _sendToPrinter(PrinterPortManager printerPortManager,
      String content, double change, String payMethod) async {
    final dataBytes = utf8.encode(content);
    await _appendPrintDebug(
      'Sending data to printer port manager',
      data: {'payloadBytes': dataBytes.length, 'payMethod': payMethod},
    );

    if (!printerPortManager.writeData(dataBytes)) {
      showDialog('Message', 'Could not write to the printer.');
      _closePrinter(printerPortManager);
      await _appendPrintDebug('writeData failed');
      return;
    }

    /// finish doucment and close printer
    if (!printerPortManager.endPage() || !printerPortManager.endDocument()) {
      showDialog('Message', 'Could not complete printing.');
      _closePrinter(printerPortManager);
      await _appendPrintDebug('endPage/endDocument failed');
      return;
    }

    _closePrinter(printerPortManager);
    await _appendPrintDebug('Print completed on printer port manager');
    _onPrintCompleted(change, payMethod);
  }

  void _onPrintCompleted(double change, String payMethod) {
    clearOrder(
      'Confirmation',
      Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center text
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 18.0, color: Colors.white),
              children: <TextSpan>[
                TextSpan(text: 'Order confirmed - $payMethod\n'),
                TextSpan(
                  text: 'Change: €${change.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 24.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    onClear();
  }

  String _sanitizeForBluetoothPrinter(String input) {
    return input
        .replaceAll('€', 'EUR')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  /// close printer and port
  void _closePrinter(PrinterPortManager printerPortManager) {
    printerPortManager.closePrinter();
    printerPortManager.closeComPort();
  }

  /// Generate invoice content
  String _generateInvoiceContent({
    required ReceiptPrinterCapabilities capabilities,
    required MarnisiReceiptSettings settings,
    String isCopyReceipt = '',
    required String storeName,
    required String storeAddress,
    required String storeCountry,
    required String storePhoneNum,
    required String storeRegNum,
    required String storeBCRS,
    required String storeOpeningHours,
    required String orderNumber,
    required String formattedDate,
    required String formattedTime,
    required List<Map<String, dynamic>> orderItems,
    required double subTotal,
    required double tax,
    required double total,
    required double discount,
    double change = 0.0,
    double cashTendered = 0.0,
    required String payMethod,
    required String vatNum,
    required String employeeNum,
    String clientNum = "",
    String clientName = "",
    String loyaltyCardNum = "",
    double loyaltyPointsused = 0.0,
    double loyaltyRewardAmount = 0.0,
    double loyaltyPointsBalance = 0.0,
    bool showLoyaltyDetails = true,
  }) {
    final productosContent = _generateItemsContent(orderItems);
    final currencyLabel = settings.receiptCurrencyLabel;
    final divider = '-' * settings.receiptLineWidth;
    final copyLabel = isCopyReceipt.trim();
    final showCashSummary =
        settings.showCashSummary && (cashTendered > 0 || change > 0);
    final shouldShowLoyaltySection = settings.showLoyaltySection &&
        LoyaltyReceiptHelper.shouldShowLoyaltySection(
          showLoyaltyDetails: showLoyaltyDetails,
          loyaltyCardNum: loyaltyCardNum,
          loyaltyPointsUsed: loyaltyPointsused,
          loyaltyRewardAmount: loyaltyRewardAmount,
          loyaltyPointsBalance: loyaltyPointsBalance,
        );
    const bon = '\x1B\x45\x01'; // bold on
    const boff = '\x1B\x45\x00'; // bold off
    const escPosCutPaper = '\x1D\x56\x41\x00';
    const openCashDrawer = '\x1B\x70\x00\x19\xFA';
    final totalsBlock = PrinterManagerInvoice.buildReceiptTotalsBlock(
      subTotal: subTotal,
      tax: tax,
      total: total,
      discount: discount,
      boldOn: bon,
      boldOff: boff,
    );

    final buffer = StringBuffer();

    if (settings.showStoreHeader) {
      buffer.writeln(_centerText(storeName, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeAddress, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeCountry, settings.receiptLineWidth));
      buffer.writeln(_centerText(storePhoneNum, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeRegNum, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeBCRS, settings.receiptLineWidth));
    }

    if (copyLabel.isNotEmpty) {
      buffer.writeln(_centerText(copyLabel, settings.receiptLineWidth));
    }

    buffer.writeln();
    buffer.writeln(divider);
    buffer.writeln('Receipt:${orderNumber.padRight(22)} Date: $formattedDate');
    if (settings.showClientDetails) {
      buffer.writeln(
          'Client VAT Num:${vatNum.padRight(15)} Time: $formattedTime');
    } else {
      buffer.writeln('Time: $formattedTime');
    }
    buffer.writeln(divider);

    if (settings.showClientDetails) {
      buffer.writeln(
          'Client Num:${clientNum.padRight(18)}  Employee: $employeeNum');
      buffer.writeln('Client Name: $clientName');
    } else {
      buffer.writeln('Employee: $employeeNum');
    }

    buffer.writeln(divider);
    buffer.writeln('Qty  Name                VAT    Price    Total');
    buffer.writeln(divider);
    buffer.writeln(productosContent);
    buffer.writeln(divider);

    buffer.writeln(
      _formatTotalLine(
        label: 'SubTotal',
        amount: subTotal,
        currencyLabel: currencyLabel,
        bon: bon,
        boff: boff,
      ),
    );
    buffer.writeln(
      _formatTotalLine(
        label: 'Tax',
        amount: tax,
        currencyLabel: currencyLabel,
        bon: bon,
        boff: boff,
      ),
    );
    buffer.writeln(
      _formatTotalLine(
        label: 'Discount',
        amount: discount * -1,
        currencyLabel: currencyLabel,
        bon: bon,
        boff: boff,
      ),
    );
    buffer.writeln(
      _formatTotalLine(
        label: 'Total',
        amount: total,
        currencyLabel: currencyLabel,
        bon: bon,
        boff: boff,
      ),
    );
    buffer.writeln(' Pay: $payMethod');

    if (showCashSummary) {
      buffer.writeln(
        _formatAmountLine(
          label: 'Cash Tendered',
          amount: cashTendered,
          currencyLabel: currencyLabel,
        ),
      );
      buffer.writeln(
        _formatAmountLine(
          label: 'Change Given',
          amount: change,
          currencyLabel: currencyLabel,
        ),
      );
    }

    if (shouldShowLoyaltySection) {
      buffer.writeln(' Loyalty Card Number:                  $loyaltyCardNum');
      buffer.writeln(
          ' Loyalty reward amount:                $loyaltyRewardAmount');
      buffer
          .writeln(' Loyalty Points Used:                  $loyaltyPointsused');
      buffer.writeln(
          ' Loyalty Points Balance:               $loyaltyPointsBalance');
    }

    if (settings.showVatAnalysis) {
      buffer.writeln();
      buffer.writeln(divider);
      buffer.writeln(' VAT Analysis');
      buffer.writeln(
        _formatAmountLine(
          label: 'Base  0%',
          amount: 0,
          currencyLabel: currencyLabel,
        ),
      );
      buffer.writeln(
        _formatAmountLine(
          label: 'Base  5%',
          amount: 0,
          currencyLabel: currencyLabel,
        ),
      );
      buffer.writeln(
        _formatAmountLine(
          label: 'Base 18%',
          amount: tax,
          currencyLabel: currencyLabel,
        ),
      );
    }

    if (settings.vatMessageLine.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('            ${settings.vatMessageLine}');
    }

    if (settings.fiscalMessageLine.trim().isNotEmpty) {
      buffer.writeln('            ${settings.fiscalMessageLine}');
    }

    if (settings.showOpeningHours && storeOpeningHours.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('\t\t${storeOpeningHours.replaceAll(';', '\n\t\t')}');
    }

    if (settings.thankYouLine.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('            ${settings.thankYouLine}');
    }

    buffer.writeln();
    if (capabilities.supportsCutter) {
      buffer.writeln(escPosCutPaper);
    }
    if (capabilities.supportsCashDrawer) {
      buffer.writeln(openCashDrawer);
    }
    if (!capabilities.supportsCutter && !capabilities.supportsCashDrawer) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _generateGiftReceipt({
    required ReceiptPrinterCapabilities capabilities,
    required MarnisiReceiptSettings settings,
    required String storeName,
    required String storeAddress,
    required String storeCountry,
    required String storePhoneNum,
    required String storeRegNum,
    required String storeBCRS,
    required String storeOpeningHours,
    required String orderNumber,
    required String formattedDate,
    required String formattedTime,
    required List<Map<String, dynamic>> orderItems,
    required String vatNum,
    String clientNum = "",
    required String employeeNum,
    String clientName = "",
  }) {
    final productosContent = _generateGiftItemsContent(orderItems);
    final divider = '-' * settings.receiptLineWidth;
    final giftMessage = settings.giftReceiptTitle;
    const escPosCutPaper = '\x1D\x56\x41\x00';
    const openCashDrawer = '\x1B\x70\x00\x19\xFA';

    final buffer = StringBuffer();
    if (settings.showStoreHeader) {
      buffer.writeln(_centerText(storeName, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeAddress, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeCountry, settings.receiptLineWidth));
      buffer.writeln(_centerText(storePhoneNum, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeRegNum, settings.receiptLineWidth));
      buffer.writeln(_centerText(storeBCRS, settings.receiptLineWidth));
    }

    buffer.writeln();
    buffer.writeln(_centerText(giftMessage, settings.receiptLineWidth));
    buffer.writeln(divider);
    buffer.writeln('Receipt:${orderNumber.padRight(22)} Date: $formattedDate');
    if (settings.showClientDetails) {
      buffer.writeln(
          'Client VAT Num:${vatNum.padRight(15)} Time: $formattedTime');
    } else {
      buffer.writeln('Time: $formattedTime');
    }
    buffer.writeln(divider);
    if (settings.showClientDetails) {
      buffer.writeln(
          'Client Num:${clientNum.padRight(18)}  Employee: $employeeNum');
      buffer.writeln('Client Name: $clientName');
    } else {
      buffer.writeln('Employee: $employeeNum');
    }
    buffer.writeln(divider);
    buffer.writeln('Qty  Name');
    buffer.writeln(divider);
    buffer.writeln(productosContent);
    buffer.writeln(divider);
    buffer.writeln();
    buffer.writeln(_centerText(giftMessage, settings.receiptLineWidth));

    if (settings.showOpeningHours && storeOpeningHours.trim().isNotEmpty) {
      buffer.writeln('\t\t${storeOpeningHours.replaceAll(';', '\n\t\t')}');
    }

    if (settings.giftReceiptFooter.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln('            ${settings.giftReceiptFooter}');
    }

    buffer.writeln();
    if (capabilities.supportsCutter) {
      buffer.writeln(escPosCutPaper);
    }
    if (capabilities.supportsCashDrawer) {
      buffer.writeln(openCashDrawer);
    }
    if (!capabilities.supportsCutter && !capabilities.supportsCashDrawer) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }

  //**************************** */
  /// Generate items content
  /// ************************** */
  String _generateItemsContent(List<Map<String, dynamic>> orderItems) {
    String content = '';

    for (var item in orderItems) {
      // Generate the main line of the article
      content += _generateLine(
        qty: item['item_qty'] ?? 0,
        title: item['item_name'] ?? '',
        vat: item['item_tax_group'] ?? '',
        price: item['item_price'] ?? 0.0,
      );

      // Add discount if applicable
      if ((item['item_disc_amount'] ?? 0) > 0) {
        content += _generateDiscountLine(
          discountPct: item['item_disc_perct'] ?? 0.0,
          discountAmount: item['item_disc_amount'],
        );
      }

      // Add additional if any
      if (item['item_supplementary'] != null &&
          item['item_supplementary'] is List) {
        for (var supplementary in item['item_supplementary']) {
          content += _generateLine(
            qty: supplementary['sup_item_qty'] ?? 0,
            title: supplementary['sup_item_name'] ?? '',
            vat: supplementary['sup_item_tax_group'] ?? '',
            price: supplementary['sup_item_price'] ?? 0.0,
          );
        }
      }
    }

    return content;
  }

  // String _generateLine({
  //   required int qty,
  //   required String title,
  //   required String vat,
  //   required double price,
  // }) {
  //   // Truncate title and calculate subtotal
  //   final truncatedTitle = _truncate(title, 20);
  //   final subtotal = price * qty;

  //   // Generate formatted line
  //   return '\n${qty.toString().padLeft(3, ' ')} '
  //       '${truncatedTitle.padRight(20)} '
  //       '${vat.padLeft(5)}  '
  //       '${price.toStringAsFixed(2).padLeft(7)} '
  //       '${subtotal.toStringAsFixed(2).padLeft(7)}';
  // }

  String _generateLine({
    required int qty,
    required String title,
    required String vat,
    required double price,
  }) {
    // SAFETY: keep total line width < 48 chars
    const int titleWidth = 18;

    final safeTitle = _truncate(title, titleWidth);
    final subtotal = price * qty;

    return '\n'
        '${qty.toString().padLeft(3)} '
        '${safeTitle.padRight(titleWidth)} '
        '${vat.padLeft(4)} '
        '${price.toStringAsFixed(2).padLeft(7)} '
        '${subtotal.toStringAsFixed(2).padLeft(7)}';
  }

  String _generateDiscountLine({
    required double discountPct,
    required double discountAmount,
  }) {
    final safeDiscount =
        PrinterManagerInvoice.normalizeDiscountForReceipt(discountAmount);
    return '\n    Discount ${discountPct.toStringAsFixed(0)}% '
        '${safeDiscount.toStringAsFixed(2).padLeft(30)}';
  }

  String _truncate(String text, int maxLength) {
    return (text.length > maxLength) ? text.substring(0, maxLength) : text;
  }

  /// ************************** */
  /// Generate gifts items content
  /// ************************** */
  String _generateGiftItemsContent(List<Map<String, dynamic>> orderItems) {
    String content = '';
    for (var item in orderItems) {
      int qty = item['item_qty'] ?? 0;
      String title = item['item_name'];
      if (title.length > 40) title = title.substring(0, 40);
      content += '\n${qty.toString().padLeft(2, '0')} ${title.padRight(40)} ';
    }
    return content;
  }

  String _centerText(String text, int lineWidth) {
    if (text.length >= lineWidth) {
      return text;
    }
    int padding = ((lineWidth - text.length) / 2).floor();
    return ' ' * padding + text;
  }

  String _formatTotalLine({
    required String label,
    required double amount,
    required String currencyLabel,
    required String bon,
    required String boff,
  }) {
    return '$bon ${label.padRight(31)}${currencyLabel.padLeft(3)} ${amount.toStringAsFixed(2).padLeft(6)}$boff';
  }

  String _formatAmountLine({
    required String label,
    required double amount,
    required String currencyLabel,
  }) {
    return ' ${label.padRight(30)} ${currencyLabel.padLeft(3)} ${amount.toStringAsFixed(2).padLeft(6)}';
  }

  static double normalizeDiscountForReceipt(dynamic discountAmount) {
    if (discountAmount is num) {
      return discountAmount.toDouble().abs();
    }
    return 0.0;
  }

  /// Generates a minimal receipt ending string applying [capabilities].
  /// This method is exposed only for unit testing the capability-conditional
  /// cutter/cash-drawer logic. Production code uses [_generateInvoiceContent]
  /// and [_generateGiftReceipt] directly, which embed equivalent logic.
  static String generateReceiptEndingForTest(
      ReceiptPrinterCapabilities capabilities) {
    const escPosCutPaper = '\x1D\x56\x41\x00';
    const openCashDrawer = '\x1B\x70\x00\x19\xFA';
    final buffer = StringBuffer();
    buffer.writeln('Receipt body');
    if (capabilities.supportsCutter) {
      buffer.writeln(escPosCutPaper);
    }
    if (capabilities.supportsCashDrawer) {
      buffer.writeln(openCashDrawer);
    }
    if (!capabilities.supportsCutter && !capabilities.supportsCashDrawer) {
      buffer.writeln();
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String buildReceiptTotalsBlock({
    required double subTotal,
    required double tax,
    required double total,
    required double discount,
    required String boldOn,
    required String boldOff,
  }) {
    final safeDiscount = normalizeDiscountForReceipt(discount);
    return [
      '$boldOn Discount                        EUR ${safeDiscount.toStringAsFixed(2).padLeft(6)}$boldOff',
      '$boldOn SubTotal                        EUR ${subTotal.toStringAsFixed(2).padLeft(6)}$boldOff',
      '$boldOn Tax                             EUR ${tax.toStringAsFixed(2).padLeft(6)}$boldOff',
      '$boldOn Total                           EUR ${total.toStringAsFixed(2).padLeft(6)}$boldOff',
    ].join('\n');
  }

  /// open drawer
  Future<void> openCashDrawer() async {
    if (!PrinterPlatformHelper.supportsCashDrawer()) {
      return;
    }

    await loadSelectedPrinter();
    if (selectedPrinter.isEmpty) return;

    final printerPortManager = PrinterPortManager();

    if (!await _initializePrinter(printerPortManager)) return;

    final command = _generateCommand();
    final dataBytes = utf8.encode(command);

    if (!printerPortManager.writeData(dataBytes)) {
      showDialog('Message', 'Could not write to the printer.');
      _closePrinter(printerPortManager);
      return;
    }
    _closePrinter(printerPortManager);
  }

  String _generateCommand() {
    const openCashDrawer = '\x1B\x70\x00\x19\xFA';
    return openCashDrawer;
  }
}

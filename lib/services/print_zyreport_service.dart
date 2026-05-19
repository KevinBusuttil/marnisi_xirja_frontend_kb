import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/helpers/android_printer_discovery.dart';
import 'package:web_admin/helpers/printer_platform_helper.dart';
import 'package:web_admin/helpers/printer_port_helper.dart';
import 'package:web_admin/helpers/receipt_printer_capabilities.dart';

/// Class PrinterManagerReport manages print format for reports
///

class PrinterManagerReport {
  late String selectedPrinter;
  final Function(String, String) showDialog;
  PrinterManagerReport({
    required this.showDialog,
  });

  Future<void> loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    selectedPrinter = prefs.getString('selectedPrinter') ?? '';

    if (selectedPrinter.isEmpty) {
      showDialog('Error', 'No printer selected.');
    }
  }

  Future<void> printReport({
    required String typeReport,
    required String storeId,
    required String employeeId,
    required String registerId,
    required String shiftNum,
    required String startShiftDate,
    required String startShiftTime,
    required String endShiftDate,
    required String endShiftTime,
    required double subTotal,
    double giftCard = 0.0,
    double returns = 0.0,
    required double tax,
    double discounts = 0.0,
    double rounded = 0.0,
    double toAccount = 0.0,
    double income = 0.0,
    double expenses = 0.0,
    int salesQtyTxn = 0,
    int customerSales = 0,
    int logon = 0,
    int openDrawer = 0,
    double tenderTotal = 0.0,
    double change = 0.0,
    double startingAmount = 0.0,
    double added = 0.0,
    double removed = 0.0,
    double bankDrop = 0.0,
    double safeDrop = 0.0,
    double counted = 0.0,
    double over = 0.0,
    double cardBOVAdd = 0.0,
    double cardBOVCollected = 0.0,
    double cardBOVRemoved = 0.0,
    int cardBOVQtyTxn = 0,
    double cashAdd = 0.0,
    double cashCollected = 0.0,
    double cashRemoved = 0.0,
    int cashQtyTxn = 0,
    double vouchersAdd = 0.0,
    double vouchersCollected = 0.0,
    double vouchersRemoved = 0.0,
    int vouchersQtyTxn = 0,
    double chequesAdd = 0.0,
    double chequesCollected = 0.0,
    double chequesRemoved = 0.0,
    int chequesQtyTxn = 0,
    double stripeAdd = 0.0,
    double stripeCollected = 0.0,
    double stripeRemoved = 0.0,
    int stripeQtyTxn = 0,
    double onAccountAdd = 0.0,
    double onAccountCollected = 0.0,
    double onAccountRemoved = 0.0,
    int onAccountQtyTxn = 0,
    double bankTransferAdd = 0.0,
    double bankTransferCollected = 0.0,
    double bankTransferRemoved = 0.0,
    int bankTransferQtyTxn = 0,
  }) async {
    await loadSelectedPrinter();
    if (selectedPrinter.isEmpty) {
      return;
    }

    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String dateTime = DateFormat('kk:mm:ss').format(DateTime.now());

    String safeText(String input) {
      return input
          .replaceAll('€', 'EUR')
          .replaceAll('ö', 'o')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('’', "'")
          .replaceAll('‘', "'")
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    }

    final capabilities = PrinterPlatformHelper.supportsCashDrawer()
        ? windowsNativeCapabilities
        : sppR310Capabilities;

    /// Generate invoice content
    String invoiceContent = _generateInvoiceContent(
      capabilities: capabilities,
      typeReport: typeReport,
      storeId: storeId,
      date: date,
      dateTime: dateTime,
      employeeId: employeeId,
      registerId: registerId,
      shiftNum: shiftNum,
      startShiftDate: startShiftDate,
      startShiftTime: startShiftTime,
      endShiftDate: endShiftDate,
      endShiftTime: endShiftTime,
      subTotal: subTotal,
      giftCard: giftCard,
      returns: returns,
      tax: tax,
      discounts: discounts,
      rounded: rounded,
      toAccount: toAccount,
      income: income,
      expenses: expenses,
      salesQtyTxn: salesQtyTxn,
      customerSales: customerSales,
      logon: logon,
      openDrawer: openDrawer,
      tenderTotal: tenderTotal,
      change: change,
      startingAmount: startingAmount,
      added: added,
      removed: removed,
      bankDrop: bankDrop,
      safeDrop: safeDrop,
      counted: counted,
      over: over,
      cardBOVAdd: cardBOVAdd,
      cardBOVCollected: cardBOVCollected,
      cardBOVRemoved: cardBOVRemoved,
      cardBOVQtyTxn: cardBOVQtyTxn,
      cashAdd: cashAdd,
      cashCollected: cashCollected,
      cashRemoved: cashRemoved,
      cashQtyTxn: cashQtyTxn,
      vouchersAdd: vouchersAdd,
      vouchersCollected: vouchersCollected,
      vouchersRemoved: vouchersRemoved,
      vouchersQtyTxn: vouchersQtyTxn,
      chequesAdd: chequesAdd,
      chequesCollected: chequesCollected,
      chequesRemoved: chequesRemoved,
      chequesQtyTxn: chequesQtyTxn,
      stripeAdd: stripeAdd,
      stripeCollected: stripeCollected,
      stripeRemoved: stripeRemoved,
      stripeQtyTxn: stripeQtyTxn,
      onAccountAdd: onAccountAdd,
      onAccountCollected: onAccountCollected,
      onAccountRemoved: onAccountRemoved,
      onAccountQtyTxn: onAccountQtyTxn,
      bankTransferAdd: bankTransferAdd,
      bankTransferCollected: bankTransferCollected,
      bankTransferRemoved: bankTransferRemoved,
      bankTransferQtyTxn: bankTransferQtyTxn,
    );

    invoiceContent = safeText(invoiceContent);

    // 🔹 Log invoice before printing
    debugPrint('--- INVOICE CONTENT (START) ---');
    debugPrint(invoiceContent);
    debugPrint('--- INVOICE CONTENT (END) ---');

    final dataBytes = ascii.encode(invoiceContent);

    if (!PrinterPlatformHelper.supportsNativePrinter()) {
      showDialog('Message', 'Printing is not supported on this platform.');
      return;
    }

    if (!PrinterPlatformHelper.supportsCashDrawer()) {
      try {
        await AndroidPrinterDiscovery.printRawReceipt(
          selectedPrinter: selectedPrinter,
          receiptText: invoiceContent,
          dataBytes: dataBytes,
        );
      } on FormatException catch (e) {
        showDialog('Message', e.message);
      } on PlatformException catch (e) {
        showDialog('Message', e.message ?? 'Could not send data to printer.');
      } catch (e) {
        showDialog('Message', 'Printing failed: $e');
      }
      return;
    }

    final printerPortManager = PrinterPortManager();

    /// Initialize COM port
    printerPortManager.initializeComPort();

    /// Open the printer
    if (!printerPortManager.openPrinter(selectedPrinter)) {
      showDialog('Message', 'The printer could not be opened.');
      printerPortManager.closeComPort();
      return;
    }

    /// Start document
    if (!printerPortManager.startDocument()) {
      showDialog('Message', 'Could not start document.');
      printerPortManager.closePrinter();
      printerPortManager.closeComPort();
      return;
    }

    /// Start new page
    if (!printerPortManager.startPage()) {
      showDialog('Message', 'Could not start the page.');
      printerPortManager.endDocument();
      printerPortManager.closePrinter();
      printerPortManager.closeComPort();
      return;
    }

    /// Send data to printer
    if (!printerPortManager.writeData(dataBytes)) {
      showDialog('Message', 'Could not be written to the printer.');
      printerPortManager.endPage();
      printerPortManager.endDocument();
      printerPortManager.closePrinter();
      printerPortManager.closeComPort();
      return;
    }

    /// End page printer
    if (!printerPortManager.endPage()) {
      showDialog('Message', 'Could not finish the page.');
      printerPortManager.endDocument();
      printerPortManager.closePrinter();
      printerPortManager.closeComPort();
      return;
    }

    /// Finish document
    if (!printerPortManager.endDocument()) {
      showDialog('Message', 'The document could not be finalized.');
      printerPortManager.closePrinter();
      printerPortManager.closeComPort();
      return;
    }

    printerPortManager.closePrinter();

    /// Close COM port
    printerPortManager.closeComPort();

    // clearOrder('Confirmation', 'Order confirmed - $payMethod');
    // onClear();
  }

  String _generateInvoiceContent({
    required ReceiptPrinterCapabilities capabilities,
    required String typeReport,
    required String storeId,
    required String date,
    required String dateTime,
    required String employeeId,
    required String registerId,
    required String shiftNum,
    required String startShiftDate,
    required String startShiftTime,
    required String endShiftDate,
    required String endShiftTime,
    required double subTotal,
    double giftCard = 0.0,
    double returns = 0.0,
    required double tax,
    double discounts = 0.0,
    double rounded = 0.0,
    double toAccount = 0.0,
    double income = 0.0,
    double expenses = 0.0,
    int salesQtyTxn = 0,
    int customerSales = 0,
    int logon = 0,
    int openDrawer = 0,
    double tenderTotal = 0.0,
    double change = 0.0,
    double startingAmount = 0.0,
    double added = 0.0,
    double removed = 0.0,
    double bankDrop = 0.0,
    double safeDrop = 0.0,
    double counted = 0.0,
    double over = 0.0,
    double cardBOVAdd = 0.0,
    double cardBOVCollected = 0.0,
    double cardBOVRemoved = 0.0,
    int cardBOVQtyTxn = 0,
    double cashAdd = 0.0,
    double cashCollected = 0.0,
    double cashRemoved = 0.0,
    int cashQtyTxn = 0,
    double vouchersAdd = 0.0,
    double vouchersCollected = 0.0,
    double vouchersRemoved = 0.0,
    int vouchersQtyTxn = 0,
    double chequesAdd = 0.0,
    double chequesCollected = 0.0,
    double chequesRemoved = 0.0,
    int chequesQtyTxn = 0,
    double stripeAdd = 0.0,
    double stripeCollected = 0.0,
    double stripeRemoved = 0.0,
    int stripeQtyTxn = 0,
    double onAccountAdd = 0.0,
    double onAccountCollected = 0.0,
    double onAccountRemoved = 0.0,
    int onAccountQtyTxn = 0,
    double bankTransferAdd = 0.0,
    double bankTransferCollected = 0.0,
    double bankTransferRemoved = 0.0,
    int bankTransferQtyTxn = 0,
  }) {
    const escPosCutPaper = '\x1D\x56\x41\x00';
    const openCashDrawer = '\x1B\x70\x00\x19\xFA';

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('-----------------------------------------------');
    buffer.writeln(typeReport);
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('Store ID: ${storeId.padRight(11)}          Date: ${date.padLeft(2)}');
    buffer.writeln('Employee: ${employeeId.padRight(14)}       Time: ${dateTime.padLeft(2)}');
    buffer.writeln('Register number: $registerId');
    buffer.writeln('');
    buffer.writeln('Shift Number: .........');
    buffer.writeln('Start Date: ${startShiftDate.padRight(2)}    End Date: ${endShiftDate.padLeft(2)}');
    buffer.writeln('Start Time: ${startShiftTime.padRight(11)}   End Time: ${endShiftTime.padLeft(2)}');
    buffer.writeln('');
    buffer.writeln('Total Amounts');
    buffer.writeln('-----------------------------------------------');
    buffer.writeln('Sales:                               EUR ${subTotal.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Gift Cards:                          EUR ${giftCard.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Returns:                             EUR ${returns.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Taxes:                               EUR ${tax.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Discounts:                           EUR ${discounts.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Rounded:                             EUR ${rounded.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('To account:                          EUR ${toAccount.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Income:                              EUR ${income.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Expense:                             EUR ${expenses.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Statistics');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('Sales:                                  ${salesQtyTxn.toString().padLeft(7)}');
    buffer.writeln('Customer Sales:                         ${customerSales.toString().padLeft(7)}');
    buffer.writeln('LogOn:                                  ${logon.toString().padLeft(7)}');
    buffer.writeln('Open drawer:                            ${openDrawer.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Tender Totals');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('Tendered:                            EUR ${tenderTotal.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Change:                              EUR ${change.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Start amount:                        EUR ${startingAmount.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Added:                               EUR ${added.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Removed:                             EUR ${removed.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Bank drop:                           EUR ${bankDrop.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Safe drop:                           EUR ${safeDrop.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Counted:                             EUR ${counted.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Over:                                EUR ${over.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Tenders');
    buffer.writeln('------------------------------------------------');
    buffer.writeln('Pay card-BOV (Added):                EUR ${cardBOVAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay card-BOV (Collected):            EUR ${cardBOVCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay card-BOV (Removed):              EUR ${cardBOVRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay card-BOV (Transactions):         EUR ${cardBOVQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay cash (Added):                    EUR ${cashAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay cash (Collected):                EUR ${cashCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay cash (Removed):                  EUR ${cashRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay cash (Transactions):             EUR ${cashQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay Vouchers (Added):                EUR ${vouchersAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Vouchers (Collected):            EUR ${vouchersCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Vouchers (Removed):              EUR ${vouchersRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Vouchers (Transactions):         EUR ${vouchersQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay Cheques (Added):                 EUR ${chequesAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Cheques (Collected):             EUR ${chequesCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Cheques (Removed):               EUR ${chequesRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Cheques (Transactions):          EUR ${chequesQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay Stripe (Added):                  EUR ${stripeAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Stripe (Collected):              EUR ${stripeCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Stripe (Removed):                EUR ${stripeRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Stripe (Transactions):           EUR ${stripeQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay on Account (Added):              EUR ${onAccountAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay on Account (Collected):          EUR ${onAccountCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay on Account (Removed):            EUR ${onAccountRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay on Account (Transactions):       EUR ${onAccountQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
    buffer.writeln('Pay Bank Transfer (Added):           EUR ${bankTransferAdd.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Bank Transfer (Collected):       EUR ${bankTransferCollected.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Bank Transfer (Removed):         EUR ${bankTransferRemoved.toStringAsFixed(2).padLeft(7)}');
    buffer.writeln('Pay Bank Transfer (Transactions):    EUR ${bankTransferQtyTxn.toString().padLeft(7)}');
    buffer.writeln('');
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

  void testGenerateInvoice({
    required String typeReport,
    required String storeId,
    required String employeeId,
    required String registerId,
    required String shiftNum,
    required String startShiftDate,
    required String startShiftTime,
    required String endShiftDate,
    required String endShiftTime,
    required double subTotal,
    double giftCard = 0.0,
    double returns = 0.0,
    required double tax,
    double discounts = 0.0,
    double rounded = 0.0,
    double toAccount = 0.0,
    double income = 0.0,
    double expenses = 0.0,
    int salesQtyTxn = 0,
    int customerSales = 0,
    int logon = 0,
    int openDrawer = 0,
    double tenderTotal = 0.0,
    double change = 0.0,
    double startingAmount = 0.0,
    double added = 0.0,
    double removed = 0.0,
    double bankDrop = 0.0,
    double safeDrop = 0.0,
    double counted = 0.0,
    double over = 0.0,
    double cardBOVAdd = 0.0,
    double cardBOVCollected = 0.0,
    double cardBOVRemoved = 0.0,
    int cardBOVQtyTxn = 0,
    double cashAdd = 0.0,
    double cashCollected = 0.0,
    double cashRemoved = 0.0,
    int cashQtyTxn = 0,
    double vouchersAdd = 0.0,
    double vouchersCollected = 0.0,
    double vouchersRemoved = 0.0,
    int vouchersQtyTxn = 0,
    double chequesAdd = 0.0,
    double chequesCollected = 0.0,
    double chequesRemoved = 0.0,
    int chequesQtyTxn = 0,
    double stripeAdd = 0.0,
    double stripeCollected = 0.0,
    double stripeRemoved = 0.0,
    int stripeQtyTxn = 0,
    double onAccountAdd = 0.0,
    double onAccountCollected = 0.0,
    double onAccountRemoved = 0.0,
    int onAccountQtyTxn = 0,
    double bankTransferAdd = 0.0,
    double bankTransferCollected = 0.0,
    double bankTransferRemoved = 0.0,
    int bankTransferQtyTxn = 0,
  }) {
    String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String dateTime = DateFormat('kk:mm:ss').format(DateTime.now());

    String content = _generateInvoiceContent(
      capabilities: windowsNativeCapabilities,
      typeReport: typeReport,
      storeId: storeId,
      date: date,
      dateTime: dateTime,
      employeeId: employeeId,
      registerId: registerId,
      shiftNum: shiftNum,
      startShiftDate: startShiftDate,
      startShiftTime: startShiftTime,
      endShiftDate: endShiftDate,
      endShiftTime: endShiftTime,
      subTotal: subTotal,
      giftCard: giftCard,
      returns: returns,
      tax: tax,
      discounts: discounts,
      rounded: rounded,
      toAccount: toAccount,
      income: income,
      expenses: expenses,
      salesQtyTxn: salesQtyTxn,
      customerSales: customerSales,
      logon: logon,
      openDrawer: openDrawer,
      tenderTotal: tenderTotal,
      change: change,
      startingAmount: startingAmount,
      added: added,
      removed: removed,
      bankDrop: bankDrop,
      safeDrop: safeDrop,
      counted: counted,
      over: over,
      cardBOVAdd: cardBOVAdd,
      cardBOVCollected: cardBOVCollected,
      cardBOVRemoved: cardBOVRemoved,
      cardBOVQtyTxn: cardBOVQtyTxn,
      cashAdd: cashAdd,
      cashCollected: cashCollected,
      cashRemoved: cashRemoved,
      cashQtyTxn: cashQtyTxn,
      vouchersAdd: vouchersAdd,
      vouchersCollected: vouchersCollected,
      vouchersRemoved: vouchersRemoved,
      vouchersQtyTxn: vouchersQtyTxn,
      chequesAdd: chequesAdd,
      chequesCollected: chequesCollected,
      chequesRemoved: chequesRemoved,
      chequesQtyTxn: chequesQtyTxn,
      stripeAdd: stripeAdd,
      stripeCollected: stripeCollected,
      stripeRemoved: stripeRemoved,
      stripeQtyTxn: stripeQtyTxn,
      onAccountAdd: onAccountAdd,
      onAccountCollected: onAccountCollected,
      onAccountRemoved: onAccountRemoved,
      onAccountQtyTxn: onAccountQtyTxn,
      bankTransferAdd: bankTransferAdd,
      bankTransferCollected: bankTransferCollected,
      bankTransferRemoved: bankTransferRemoved,
      bankTransferQtyTxn: bankTransferQtyTxn,
    );

    // 🔥 Log the invoice
    debugPrint("\n📄 -------- TEST REPORT START --------\n", wrapWidth: 1024);
    debugPrint(content, wrapWidth: 1024);
    debugPrint("\n📄 -------- TEST REPORT END --------\n", wrapWidth: 1024);
  }
}

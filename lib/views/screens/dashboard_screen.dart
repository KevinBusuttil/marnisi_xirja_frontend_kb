// import 'dart:ffi';
// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/constants/payment_methods.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/settings_selection_helper.dart';
import 'package:web_admin/helpers/dashboard_background_style.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/theme/theme_extensions/app_color_scheme.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:web_admin/helpers/app_focus_helper.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/print_zyreport_service.dart';
import 'package:web_admin/helpers/txn_helper.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _dataTableHorizontalScrollController = ScrollController();
  // String _userLevel = '';
  double _totalSales = 0;
  double _totalCashAvailable = 0;
  double _openCashAmountSaved = 0;
  String _textToolTipAmount =
      "You need to generate Z report to eneable this feature";
  int _defaultOpenCashAmountMin = 0;
  int _defaultOpenCashAmountMax = 0;
  bool _enableAmountTextField = false;
  final bool _enableDrawCashTextField = true;
  String? defaultPrinter;
  bool _isLoading = false;

  //controllers forms
  var _isFormLoadingOpenCash = false;
  var _isFormLoadingDrawCash = false;
  final _formKeyOpenCashAmount = GlobalKey<FormBuilderState>();
  final _formKeyDrawAmount = GlobalKey<FormBuilderState>();
  String? _appBackgroundPath;

  //********************* */
  //sqlflite instance
  //******************* */
  final _dbHelper = SqlLiteService(); // load database helper

  @override
  void initState() {
    super.initState();
    _loadAppBackground();
    _openCashStatus();
    _checkDefaultSettings();
    _getTotalSales();
    _getTotalCashAvailable();
    // _printAllSharedPreferences();
  }

  Future<void> _loadAppBackground() async {
    final path = await MarnisiImageHelper.readAppBackgroundPath();
    if (!mounted) return;
    setState(() {
      _appBackgroundPath = path;
    });
  }

  final logger = Logger(printer: PrettyPrinter());
  // logger.d("Debug message");
  // logger.i("Info message");
  // logger.w("Warning message");
  // logger.e("Error message");
  // logger.v("Verbose message");

  //************************************************** */
  //print all shared preferences
  //************************************************* */
  // Future<void> _printAllSharedPreferences() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   final Set<String> keys = prefs.getKeys();

  //   // print(prefs.getInt('startTime'));
  //   //print all shared keys
  //   for (String key in keys) {
  //     final value = prefs.get(key);
  //     logger.t('$key: $value');
  //   }
  // }

//******************************** */
  //FETCH ITEMS FROM FRAPPE
  //******************************** */

  Future<void> _loadItems(BuildContext context) async {
    final SqlLiteService dbHelper = SqlLiteService();
    final ApiService apiHelperGetProducts =
        ApiService(endpointPath: ApiRoutes.getProducts);
    final prefs = await SharedPreferences.getInstance();
    final apiBaseUrl = (prefs.getString(StorageKeys.apiBaseUrl) ??
            prefs.getString('apiBaseUrl') ??
            '')
        .trim();

    try {
      final db = await dbHelper.database;

      // Fetch data from the API
      Map<String, dynamic> data = await apiHelperGetProducts.fetchData();
      List<dynamic> message = data['message'];

      // print(message[0]);
      logger.d("Database initialized");

      // get all id's from the current local db
      List<Map<String, dynamic>> existingItems =
          await db.query('items', columns: ['item_id']);
      Set<String> existingItemsIds =
          existingItems.map((item) => item['item_id'].toString()).toSet();

      await db.transaction((txn) async {
        Set<String> receivedItemsIds = {};

        for (var item in message) {
          String itemId = item['item_id'].toString();
          receivedItemsIds.add(itemId);
          final resolvedImagePath = MarnisiImageHelper.resolveItemImagePath(
            rawPath: (item['item_img_path'] ?? '').toString(),
            apiBaseUrl: apiBaseUrl,
          );

          //check the item exists
          List<Map<String, dynamic>> existingItems = await txn.query(
            'items',
            where: 'item_id = ?',
            whereArgs: [itemId],
          );

          if (existingItems.isNotEmpty) {
            var existingItem = existingItems.first;

            //update items if is necessary
            if (existingItem['item_img'] != resolvedImagePath ||
                existingItem['item_store'] != item['item_store'] ||
                existingItem['item_brand'] != item['item_brand'] ||
                existingItem['item_description'] != item['item_description'] ||
                existingItem['item_barcode'] != item['item_barcode'] ||
                existingItem['item_name'] != item['item_name'] ||
                existingItem['item_qty'] != item['item_qty'] ||
                existingItem['item_price'] != item['item_price'] ||
                existingItem['item_category'] != item['item_category'] ||
                existingItem['item_unit'] != item['item_unit'] ||
                existingItem['item_tax_group'] != item['item_tax_group'] ||
                existingItem['item_tax_pct'] != item['item_tax_pct']) {
              await txn.update(
                'items',
                {
                  'item_img': resolvedImagePath,
                  'item_store': item['item_store'],
                  'item_brand': item['item_brand'],
                  'item_description': item['item_description'],
                  'item_barcode': item['item_barcode'],
                  'item_name': item['item_name'],
                  'item_qty': item['item_qty'],
                  'item_price': item['item_price'],
                  'item_category': item['item_category'],
                  'item_unit': item['item_unit'],
                  'item_tax_group': item['item_tax_group'],
                  'item_tax_pct': item['item_tax_pct']
                },
                where: 'item_id = ?',
                whereArgs: [itemId],
              );
            }
          } else {
            //insert new items
            await txn.insert('items', {
              'item_img': resolvedImagePath,
              'item_description': item['item_description'] ?? '-',
              'item_store': item['item_store'] ?? '-',
              'item_brand': item['item_brand'] ?? '-',
              'item_id': item['item_id'] ?? '-',
              'item_barcode': item['item_barcode'] ?? '000000',
              'item_name': item['item_name'] ?? '-',
              'item_qty': item['item_qty'] ?? 0,
              'item_price': item['item_price'] ?? 0,
              'item_category': item['item_category'] ?? '-',
              'item_unit': item['item_unit'] ?? '-',
              'item_tax_group': item['item_tax_group'] ?? '-',
              'item_tax_pct': item['item_tax_pct'] ?? 0.0,
            });
          }

          //add supp items if exist
          if (item['item_suppItems'] != null &&
              item['item_suppItems'].isNotEmpty) {
            // delete if is necessary
            await txn.delete(
              'supp_items',
              where: 'supp_parent_id = ?',
              whereArgs: [itemId],
            );

            //insert new suppItems
            for (var suppItem in item['item_suppItems']) {
              await txn.insert('supp_items', {
                'supp_parent_id': itemId,
                'supp_id': suppItem['supp_id'] ?? '-',
                'supp_name': suppItem['supp_name'] ?? '-',
                'supp_qty': suppItem['supp_qty'] ?? 0,
                'supp_price': suppItem['supp_price'] ?? 0.0,
                'supp_uom': suppItem['supp_unit'] ?? '-',
                'supp_tax_group': suppItem['supp_tax_group'] ?? '-',
                'supp_tax_pct': suppItem['supp_tax_pct'] ?? 0.0,
              });
            }
          }
        }

        //delete items removed
        for (String itemId in existingItemsIds) {
          if (!receivedItemsIds.contains(itemId)) {
            await txn.delete(
              'items',
              where: 'item_id = ?',
              whereArgs: [itemId],
            );
            await txn.delete(
              'supp_items',
              where: 'supp_parent_id = ?',
              whereArgs: [itemId],
            );
          }
        }
      });

      _showSnackBar('Price list updated');

      // logger.d('Items and suppItems insert/update/delete ok');
    } catch (e, stackTrace) {
      //logger.e('Error loading data: $e');
      _showSnackBar('Error occurred: $e');
      logger.d(stackTrace);
    }
  }

  //************************************************** */
  //sync sales data
  //************************************************* */
  Future<void> sendSalesData(BuildContext context) async {
    if (!mounted) return; // Early exit if the widget is not mounted

    try {
      var getData = await _dbHelper.getAllSalesWithItemsToSync();

      final ApiService apiSendData =
          ApiService(endpointPath: ApiRoutes.postProducts);

      log("Request body of post all sales: $getData");

      List<dynamic>? confirmations =
          await apiSendData.sendData(getData, (message) {
        // Context used within the async callback; ensure it's valid
        if (context.mounted) {
          _showSnackBar(message);
        }
      });

      if (!mounted)
        return; // Check if the widget is still mounted after async operation

      logger.d(confirmations);

      if (confirmations != null) {
        for (var confirmation in confirmations) {
          String salesNum = confirmation['sale_num'];
          String status = confirmation['status'];
          String loyaltyCardNum = confirmation['loy_cust_card_num'] ?? '';

          // Update the sales_sync_frappe field in the sales table
          await _dbHelper.frappeSyncConfirmation(
              salesNum, status, loyaltyCardNum);

          if (!mounted) return; // Check after each async operation in the loop
        }

        await _dbHelper.purgeSyncedSalesOlderThan(retentionDays: 7);

        // Safe to use context here because it's guarded by mounted check
        _showSnackBar('All information was synced to the server');
      } else {
        _showSnackBar('No confirmations received or failed to send data.');
      }
    } catch (e) {
      _showSnackBar('Error occurred: $e ');
      // print(e);
    }
  }

  //************************************************** */
  //check total amount sold
  //************************************************* */
  Future<void> _getTotalSales() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(StorageKeys.userId);
    int? storedTimeMillis = prefs.getInt('startTime');
    String formatteDate = '';

    if (storedTimeMillis != null) {
      DateTime storedStartTime =
          DateTime.fromMillisecondsSinceEpoch(storedTimeMillis);
      DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      formatteDate = dateFormat.format(storedStartTime);
    }

    final double totalSales =
        await _dbHelper.getTotalSales(userId!, formatteDate);
    setState(() {
      _totalSales = totalSales.abs();
    });
  }

  //************************************************** */
  //check cash  amount available
  //************************************************* */
  Future<void> _getTotalCashAvailable() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? openCashAmount = prefs.getDouble(StorageKeys.openCashAmount) ?? 0.0;
    String? userId = prefs.getString(StorageKeys.userId);
    int? storedTimeMillis = prefs.getInt('startTime');

    String formatteDate = '';

    if (storedTimeMillis != null) {
      DateTime storedStartTime =
          DateTime.fromMillisecondsSinceEpoch(storedTimeMillis);
      DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      formatteDate = dateFormat.format(storedStartTime);
    }

    final double sumCashAvailable =
        await _dbHelper.getTotalAmount(userId!, 'Cash', formatteDate);

    setState(() {
      _openCashAmountSaved = openCashAmount;
      _totalCashAvailable = sumCashAvailable.abs() + _openCashAmountSaved;
    });
  }

  //************************************************** */
  //create X Z report
  //************************************************* */

  //print invoice
  late PrinterManagerReport printerManager;

  Future<bool?> _showDialog(String title, String message,
      {bool showCancel = false}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
            if (showCancel)
              TextButton(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
          ],
        );
      },
    );
  }

  // ##################################
  // generate z and x report
  // ##################################

  Future<void> _generateXZReport(String typeReport) async {
    final goRouter = GoRouter.of(context);
    final prefs = await SharedPreferences.getInstance();

    String userCode = prefs.getString(StorageKeys.userId).toString();
    String storeId = SettingsSelectionHelper.resolveSelectedStore(
      primaryValue: prefs.getString(StorageKeys.selectedStore),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedStoreKey),
    );
    String registerId = SettingsSelectionHelper.resolveSelectedRegister(
      primaryValue: prefs.getString(StorageKeys.selectedRegister),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedRegisterKey),
    );
    int? storedTimeMillis = prefs.getInt('startTime');
    String startShiftDate = '';
    String startShiftTime = '';
    String startShiftFullDate = '';

    if (storedTimeMillis != null) {
      DateTime storedStartTime =
          DateTime.fromMillisecondsSinceEpoch(storedTimeMillis);
      startShiftFullDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(storedStartTime);
      //startShiftFullDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse('2024-09-26 09:06:02'));
      startShiftDate = startShiftFullDate.split(' ')[0];
      startShiftTime = startShiftFullDate.split(' ')[1];
    }

    String endShiftDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String endShiftTime = DateFormat('HH:mm:ss').format(DateTime.now());
    double? startingAmount = prefs.getDouble(StorageKeys.openCashAmount);

    final double cashCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.cash, startShiftFullDate);
    final double cardBovCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.cardBov, startShiftFullDate);
    final double voucherCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.staffVaucher, startShiftFullDate);
    final double chequeCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.cheque, startShiftFullDate);
    final double chequeBovCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.chequeBOV, startShiftFullDate);
    final double stripeCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.stripe, startShiftFullDate);
    final double onAccountCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.onAccount, startShiftFullDate);
    final double bankTransferCollected = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.bankTransfer, startShiftFullDate);
    final double totalDiscounts = await _dbHelper.getTotalAmount(
        userCode, PaymentMethods.gifCard, startShiftFullDate);

    final double subtotal = await _dbHelper.getTotals(
        'sales_subtotal', userCode, startShiftFullDate);
    final double tax =
        await _dbHelper.getTotals('sales_tax', userCode, startShiftFullDate);
    final double total =
        await _dbHelper.getTotals('sales_total', userCode, startShiftFullDate);
    final double discounts = await _dbHelper.getTotals(
        'sales_discount', userCode, startShiftFullDate);
    final double returns = await _dbHelper.getTotalReturnsCombinedReceipt(
        'si_total', userCode, startShiftFullDate);
    // final double returns = await _dbHelper.getTotalReturns('sales_total', userCode, startShiftFullDate);
    final int totalTxn = await _dbHelper.getCountTnx(
        'sales_total', userCode, startShiftFullDate);

    final int totalTxnCash = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.cash);
    final int totalTxnBov = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.cardBov);
    final int totalTxnVaucher = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.staffVaucher);
    final int totalTxnCheque = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.cheque);
    final int totalTxnStripe = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.stripe);

    final int totalTxnOnAccount = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.onAccount);
    final int totalTxnBankTransfer = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.bankTransfer);
    // final int totalTxnLoyality =
    //     await _dbHelper.getCountTnxMethod(userCode, startShiftFullDate, PaymentMethods.loyality);
    final int totalTxnChequeBov = await _dbHelper.getCountTnxMethod(
        userCode, startShiftFullDate, PaymentMethods.chequeBOV);

    DateTime endTime = DateTime.now();
    setState(() {
      defaultPrinter = prefs.getString('selectedPrinter');
    });

    debugPrint('----- $typeReport GENERATED -----\n'
        'Employee: $userCode\n'
        'Store: $storeId | Register: $registerId\n'
        'Shift Start: $startShiftFullDate\n'
        'Shift End: $endShiftDate $endShiftTime\n'
        'Totals:\n'
        '  Subtotal: $subtotal\n'
        '  Tax: $tax\n'
        '  Discounts: $discounts\n'
        '  Returns: $returns\n'
        '  Total: $total\n'
        '  Tender Total: $total\n\n'
        'Payment Summary:\n'
        '  Cash: $cashCollected (Txn: $totalTxnCash)\n'
        '  Card BOV: $cardBovCollected (Txn: $totalTxnBov)\n'
        '  Voucher: $voucherCollected (Txn: $totalTxnVaucher)\n'
        '  Cheque: ${chequeCollected + chequeBovCollected} (Txn: ${totalTxnCheque + totalTxnChequeBov})\n'
        '  Stripe: $stripeCollected (Txn: $totalTxnStripe)\n'
        '  On Account: $onAccountCollected (Txn: $totalTxnOnAccount)\n'
        '  Bank Transfer: $bankTransferCollected (Txn: $totalTxnBankTransfer)\n\n'
        'Starting Amount: ${startingAmount ?? 0.0}\n'
        '-------------------------------------------');

    printerManager = PrinterManagerReport(
      showDialog: _showDialog,
    );

    printerManager.printReport(
      typeReport: typeReport,
      storeId: storeId,
      employeeId: userCode,
      registerId: registerId,
      shiftNum: 'shiftNum',
      startShiftDate: startShiftDate,
      startShiftTime: startShiftTime,
      endShiftDate: endShiftDate,
      endShiftTime: endShiftTime,
      subTotal: subtotal,
      giftCard: totalDiscounts,
      returns: returns,
      tax: tax,
      discounts: discounts,
      rounded: 0.0,
      toAccount: 0.0,
      income: 0.0,
      expenses: 0.0,
      salesQtyTxn: totalTxn,
      customerSales: 0,
      logon: 0,
      openDrawer: 0,
      tenderTotal: total,
      change: 0.0,
      startingAmount: startingAmount ?? 0.0,
      added: 0.0,
      removed: 0.0,
      bankDrop: 0.0,
      safeDrop: 0.0,
      counted: 0.0,
      over: 0.0,
      cardBOVAdd: 0.0,
      cardBOVCollected: cardBovCollected,
      cardBOVRemoved: 0.0,
      cardBOVQtyTxn: totalTxnBov,
      cashAdd: startingAmount ?? 0.0,
      cashCollected: cashCollected,
      cashRemoved: 0.0,
      cashQtyTxn: totalTxnCash,
      vouchersAdd: 0.0,
      vouchersCollected: voucherCollected,
      vouchersRemoved: 0.0,
      vouchersQtyTxn: totalTxnVaucher,
      chequesAdd: 0.0,
      chequesCollected: chequeBovCollected + chequeCollected,
      chequesRemoved: 0.0,
      chequesQtyTxn: totalTxnChequeBov + totalTxnCheque,
      stripeAdd: 0.0,
      stripeCollected: stripeCollected,
      stripeRemoved: 0.0,
      stripeQtyTxn: totalTxnStripe,
      onAccountAdd: 0.0,
      onAccountCollected: onAccountCollected,
      onAccountRemoved: 0.0,
      onAccountQtyTxn: totalTxnOnAccount,
      bankTransferAdd: 0.0,
      bankTransferCollected: bankTransferCollected,
      bankTransferRemoved: 0.0,
      bankTransferQtyTxn: totalTxnBankTransfer,
    );

    if (typeReport == 'Z-Report') {
      await TxnHelper.saveTxn(
        txnReceiptNum: '',
        txnAmount: 0.0,
        txnType: Event.printZReport,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );
      await TxnHelper.saveTxn(
        txnReceiptNum: '',
        txnAmount: 0.0,
        txnType: Event.generateZReport,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );
      await _dbHelper.updateShiftOut(userCode, endTime);

      await prefs.setDouble(StorageKeys.openCashAmount, 0.0);

      await TxnHelper.saveTxn(
        txnReceiptNum: '',
        txnAmount: 0.0,
        txnType: Event.logOut,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );
      goRouter.go(RouteUri.logout);
    } else {
      await TxnHelper.saveTxn(
        txnReceiptNum: '',
        txnAmount: 0.0,
        txnType: Event.printXReport,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );
      await TxnHelper.saveTxn(
        txnReceiptNum: '',
        txnAmount: 0.0,
        txnType: Event.generateXReport,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );
    }
  }

  //************************************************** */
  //check if the initial amount of cash has been set
  //************************************************* */

  Future<void> _openCashStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    double? cashStatus = prefs.getDouble(StorageKeys.openCashAmount);

    if (cashStatus == null || cashStatus == 0.0) {
      _enableAmountTextField = true;
      _textToolTipAmount = "Press 'Start' after you add the amount.";
    }
  }

  //************************************************** */
  //open the cash  with the amount setted in config
  //************************************************* */
  Future<void> _doOpenCash({
    required UserDataProvider userDataProvider,
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    AppFocusHelper.instance.requestUnfocus();

    if (_formKeyOpenCashAmount.currentState?.validate() ?? false) {
      // Validation passed.
      _formKeyOpenCashAmount.currentState!.save();
      setState(() => _isFormLoadingOpenCash = true);

      double? openCashAmount;
      try {
        final value =
            _formKeyOpenCashAmount.currentState?.value['openCashAmount'];

        if (value == null || value.isEmpty) {
          throw const FormatException("Cash amount cannot be empty");
        }

        openCashAmount = double.parse(value);

        // Save the value to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(StorageKeys.openCashAmount, openCashAmount);
      } catch (e) {
        setState(() => _isFormLoadingOpenCash = false);
        //onError.call('Invalid cash amount. Please enter a valid number.');
        return;
      }

      try {
        // Save transaction
        await TxnHelper.saveTxn(
          txnReceiptNum: '',
          txnAmount: openCashAmount,
          txnType: Event.setCashQty,
          txnStatus: PostingStatus.pending,
          txnLocalStatus: LocalEvent.pending,
        );
        onSuccess.call();
      } catch (e) {
        onError.call('An error occurred. Please try again. $e');
        await TxnHelper.saveTxn(
          txnReceiptNum: '',
          txnAmount: 0.0,
          txnType: Event.setCashQty,
          txnStatus: PostingStatus.pending,
          txnLocalStatus: LocalEvent.pending,
        );
      } finally {
        setState(() => _isFormLoadingOpenCash = false);
      }
    } else {
      //onError.call('Form validation failed. Please check the input fields.');
    }
  }

  //load cash amount to show it evaluate if the amount is correct
  Future<void> _checkDefaultSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int openCashAmountMin = prefs.getInt('openCashAmountMin') ?? 10;
    int openCashAmountMax = prefs.getInt('openCashAmountMax') ?? 500;
    double openCashAmount = prefs.getDouble(StorageKeys.openCashAmount) ?? 0.0;
    String selectedStoreId = SettingsSelectionHelper.resolveSelectedStore(
      primaryValue: prefs.getString(StorageKeys.selectedStore),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedStoreKey),
    );
    String selectedRegisterId = SettingsSelectionHelper.resolveSelectedRegister(
      primaryValue: prefs.getString(StorageKeys.selectedRegister),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedRegisterKey),
    );

    if (openCashAmountMin == 0) {
      if (mounted) {
        _showMessageDialog(
          context,
          "Alert",
          "Please set the minimum 'Open Cash Amount' in general settings",
          isError: true,
        ).then((_) {
          GoRouter.of(context).go(RouteUri.generalSettings);
        });
      }
    } else if (openCashAmountMax == 0) {
      if (mounted) {
        _showMessageDialog(
          context,
          "Alert",
          "Please set maximum 'Open Cash Amount' in general settings",
          isError: true,
        ).then((_) {
          GoRouter.of(context).go(RouteUri.generalSettings);
        });
      }
    } else if (selectedStoreId == '') {
      if (mounted) {
        _showMessageDialog(
          context,
          "Alert",
          "Please set the default 'Store' in general settings",
          isError: true,
        ).then((_) {
          GoRouter.of(context).go(RouteUri.generalSettings);
        });
      }
    } else if (selectedRegisterId == '') {
      if (mounted) {
        _showMessageDialog(
          context,
          "Alert",
          "Please set the default 'Register' in general settings",
          isError: true,
        ).then((_) {
          GoRouter.of(context).go(RouteUri.generalSettings);
        });
      }
    } else if (openCashAmount == 0.0) {
      if (mounted) {
        _showMessageDialog(
          context,
          "Alert",
          "Please set the default initial cash amount ",
          isError: true,
        );
      }
    }
    setState(() {
      _defaultOpenCashAmountMin = openCashAmountMin;
      _defaultOpenCashAmountMax = openCashAmountMax;
      _openCashAmountSaved = openCashAmount;
    });
  }

//   Future<void> _checkDefaultSettings() async {
//   SharedPreferences prefs = await SharedPreferences.getInstance();
//   int openCashAmountMin = prefs.getInt('openCashAmountMin') ?? 10;
//   int openCashAmountMax = prefs.getInt('openCashAmountMax') ?? 500;
//   double openCashAmount = prefs.getDouble(StorageKeys.openCashAmount) ?? 0.0;
//   String selectedStoreId = prefs.getString('selectedStore') ?? '';
//   String selectedRegisterId = prefs.getString('selectedRegister') ?? '';

//   // Instead of blocking, just warn
//   if (openCashAmountMin == 0) {
//     debugPrint("⚠️ Minimum cash amount not set. Using default 10.");
//     openCashAmountMin = 10;
//   }
//   if (openCashAmountMax == 0) {
//     debugPrint("⚠️ Maximum cash amount not set. Using default 500.");
//     openCashAmountMax = 500;
//   }
//   if (selectedStoreId.isEmpty) {
//     debugPrint("⚠️ No default store set.");
//     // Optionally assign a placeholder
//     selectedStoreId = "TEMP_STORE";
//   }
//   if (selectedRegisterId.isEmpty) {
//     debugPrint("⚠️ No default register set.");
//     selectedRegisterId = "TEMP_REGISTER";
//   }
//   if (openCashAmount == 0.0) {
//     debugPrint("⚠️ Open cash amount is zero.");
//   }

//   setState(() {
//     _defaultOpenCashAmountMin = openCashAmountMin;
//     _defaultOpenCashAmountMax = openCashAmountMax;
//     _openCashAmountSaved = openCashAmount;
//   });
// }

  //error message
  void _onCashOpenError(BuildContext context, String message) {
    final dialog = AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      desc: message,
      width: kDialogWidth,
      btnOkText: 'Error',
      btnOkOnPress: () {},
    );

    dialog.show();
  }

  //redirect when the transaction is completed to register screen
  void _onCashOPen(BuildContext context) {
    GoRouter.of(context).go(RouteUri.salesRegister);
  }

  //************************* */
  //Draw Cash
  //************************* */
  Future<void> _doDrawCash({
    required UserDataProvider userDataProvider,
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    AppFocusHelper.instance.requestUnfocus();

    if (_formKeyDrawAmount.currentState?.validate() ?? false) {
      // Validation passed.
      _formKeyDrawAmount.currentState!.save();

      setState(() => _isFormLoadingDrawCash = true);
      try {
        onSuccess.call();
      } catch (e) {
        onError.call('An error occurred. Please try again. $e');
        // print(e);
      } finally {
        setState(() => _isFormLoadingDrawCash = false);
      }
    }
  }

  //*************************************** */
  // Dialog to validate user to draw cash
  //*************************************** */
  Future<void> _showAdminPasswordDialog(BuildContext context) async {
    final formKeyAdmin = GlobalKey<FormBuilderState>();

    //show the dialog to get the admin password
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Admin Authentication"),
          content: FormBuilder(
            key: formKeyAdmin,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please enter the admin password:"),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'adminPassword',
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true, // Para ocultar la contraseña
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                if (formKeyAdmin.currentState?.saveAndValidate() ?? false) {
                  final enteredPassword =
                      formKeyAdmin.currentState?.value['adminPassword'];

                  // check the admin password
                  if (_checkAdminPassword(enteredPassword)) {
                    Navigator.of(context).pop(); //close the dialog
                    _showAmountInputDialog(
                        context); //show the second dialog to get the qty
                  } else {
                    //error dialog
                    _showMessageDialog(context, "Error",
                        "Incorrect admin password. Please try again.",
                        isError: true);
                  }
                }
              },
            ),
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
              },
            ),
          ],
        );
      },
    );
  }

  //validate user rights
  bool _checkAdminPassword(String? password) {
    const correctPassword = "admin123"; // tast validation
    return password == correctPassword;
  }

  //set the amount to draw
  Future<void> _showAmountInputDialog(BuildContext context) async {
    final formKeyAmount = GlobalKey<FormBuilderState>();

    // second dialog to get the amount to draw
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Amount to Draw"),
          content: FormBuilder(
            key: formKeyAmount,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'amountConfirmation',
                  decoration: const InputDecoration(
                    labelText: 'Confirm Amount',
                    border: OutlineInputBorder(),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        '€',
                        style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18),
                      ),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.numeric(),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () async {
                if (formKeyAmount.currentState?.saveAndValidate() ?? false) {
                  final drawAmountStr =
                      _formKeyDrawAmount.currentState?.value['drawCashAmount'];
                  final confirmDrawAmountStr =
                      formKeyAmount.currentState?.value['amountConfirmation'];

                  final drawAmount = double.tryParse(drawAmountStr ?? '0');
                  final confirmDrawAmount =
                      double.tryParse(confirmDrawAmountStr ?? '0');

                  if (drawAmount == null || confirmDrawAmount == null) {
                    _showMessageDialog(context, "Error",
                        "Invalid amount entered. Please try again.",
                        isError: true);
                    return;
                  }

                  if (drawAmount != confirmDrawAmount) {
                    _showMessageDialog(context, "Error",
                        "The amount does not match. Try again.");
                  } else if ((_totalCashAvailable - drawAmount) <
                      _openCashAmountSaved) {
                    _showMessageDialog(context, "Error",
                        "The final total cash amount cannot be less than €$_openCashAmountSaved. Try again.");
                  } else {
                    Navigator.of(context).pop();
                    _showMessageDialog(
                        context, "Confirmation", "Operation successful.",
                        isError: false);

                    // Save transaction
                    await TxnHelper.saveTxn(
                      txnReceiptNum: '',
                      txnAmount: drawAmount * -1,
                      txnType: Event.drawCash,
                      txnStatus: PostingStatus.pending,
                      txnLocalStatus: LocalEvent.pending,
                    );

                    setState(() {
                      _totalCashAvailable -=
                          drawAmount; // Update total cash available
                    });

                    // if (!mounted) return;
                  }
                }
              },
            ),
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
            ),
          ],
        );
      },
    );
  }

  //standar dialog
  Future<void> _showMessageDialog(
      BuildContext context, String title, String message,
      {bool isError = false, VoidCallback? onOkPressed}) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
                if (onOkPressed != null) {
                  onOkPressed();
                }
              },
            ),
          ],
        );
      },
    );
  }

  //message snackbar
  void _showSnackBar(String message, {bool withConfirmation = false}) {
    final snackBar = SnackBar(
      content: Text(
        withConfirmation ? 'Are you sure you want to proceed?' : message,
        style: withConfirmation ? const TextStyle(color: Colors.white) : null,
      ),

      backgroundColor: withConfirmation
          ? const Color.fromARGB(255, 255, 17, 1)
          : null, //default color
      action: withConfirmation
          ? SnackBarAction(
              label: 'CONFIRM',
              textColor: Colors.yellow,
              onPressed: () {
                // action to execute after the user confirm
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
                //set here extra actions
              },
            )
          : null,
      duration: Duration(seconds: withConfirmation ? 5 : 5), // adjust duration
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  void dispose() {
    _dataTableHorizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final appColorScheme = Theme.of(context).extension<AppColorScheme>()!;
    final size = MediaQuery.of(context).size;
    final summaryCardCrossAxisCount =
        (size.width >= kScreenWidthResponsive ? 3 : 3);

    return PortalMasterLayout(
      body: Stack(
        children: [
          Positioned.fill(
            child: MarnisiImageHelper.isNetworkImagePath(
                    (_appBackgroundPath ?? '').trim())
                ? Image.network(
                    _appBackgroundPath!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        DashboardBackgroundStyle.imageAssetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration:
                                ContainerBackgroundTheme.myGradientDecoration,
                          );
                        },
                      );
                    },
                  )
                : Image.asset(
                    _appBackgroundPath?.isNotEmpty == true
                        ? _appBackgroundPath!
                        : DashboardBackgroundStyle.imageAssetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration:
                            ContainerBackgroundTheme.myGradientDecoration,
                      );
                    },
                  ),
          ),
          Positioned.fill(
            child: Container(
              color: DashboardBackgroundStyle.overlayColor,
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(kDefaultPadding),
            children: [
              Text(
                'Dashboard',
                style: themeData.textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final summaryCardWidth = ((constraints.maxWidth -
                            (kDefaultPadding *
                                (summaryCardCrossAxisCount - 1))) /
                        summaryCardCrossAxisCount);
                    return Wrap(
                      direction: Axis.horizontal,
                      spacing: kDefaultPadding,
                      runSpacing: kDefaultPadding,
                      children: [
                        SummaryCard(
                          title: "Open Cash",
                          value: FormBuilder(
                            key: _formKeyOpenCashAmount,
                            autovalidateMode: AutovalidateMode.disabled,
                            child: SizedBox(
                              height: 100,
                              child: Tooltip(
                                message: _textToolTipAmount,
                                margin: const EdgeInsets.all(2.0),
                                child: FormBuilderTextField(
                                  name: 'openCashAmount',
                                  enabled: _enableAmountTextField,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10.0, horizontal: 10.0),
                                    labelText: 'Initial amount',
                                    helperText: '',
                                    hintText: 'Amount',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide(),
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        '€',
                                        style: TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 255, 255),
                                            fontSize: 18),
                                      ),
                                    ),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 1.0, horizontal: 4.0),
                                      child: TextButton(
                                        onPressed: (_isFormLoadingOpenCash
                                            ? null
                                            : () => _doOpenCash(
                                                  userDataProvider: context
                                                      .read<UserDataProvider>(),
                                                  onSuccess: () =>
                                                      _onCashOPen(context),
                                                  onError: (message) =>
                                                      _onCashOpenError(
                                                          context, message),
                                                )),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: const Color.fromARGB(
                                              255, 94, 23, 7),
                                        ),
                                        child: const Text(
                                          'Start',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  enableSuggestions: false,
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.numeric(),
                                    (val) {
                                      if (val != null &&
                                          double.tryParse(val) != null) {
                                        double value = double.parse(val);
                                        if (value < _defaultOpenCashAmountMin) {
                                          return 'Minimum amount to open cash is  €$_defaultOpenCashAmountMin';
                                        } else if (value >
                                            _defaultOpenCashAmountMax) {
                                          return 'Maximum amount to open cash is  €$_defaultOpenCashAmountMax';
                                        }
                                      }
                                      return null;
                                    },
                                  ]),
                                  // onSaved: () => (),
                                ),
                              ),
                            ),
                          ),
                          icon: Icons.euro_symbol,
                          backgroundColor:
                              const Color.fromARGB(255, 57, 57, 57),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: 'Logged User',
                          value: Selector<UserDataProvider, String>(
                            selector: (context, provider) => provider.username,
                            builder: (context, value, child) {
                              return SizedBox(
                                width: 200,
                                child: Tooltip(
                                  message: value,
                                  child: Text(value,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 20,
                                      )),
                                ),
                              );
                            },
                          ),
                          icon: Icons.group_add_rounded,
                          backgroundColor:
                              const Color.fromARGB(255, 120, 102, 71),
                          textColor: appColorScheme.buttonTextBlack,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Current Total Sales",
                          value: '€ ${_totalSales.toStringAsFixed(2)}',
                          icon: Icons.ssid_chart_rounded,
                          backgroundColor:
                              const Color.fromARGB(190, 120, 102, 71),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "X Report",
                          value: Tooltip(
                            message: 'Generate X report',
                            margin: const EdgeInsets.all(2.0),
                            child: TextButton(
                              onPressed: () {
                                _generateXZReport('X-Report');
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    const Color.fromARGB(218, 142, 31, 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal:
                                        40.0), // Padding interno del botón
                              ),
                              child: const Text(
                                'Generate',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          icon: Icons.euro_symbol,
                          backgroundColor:
                              const Color.fromARGB(255, 57, 57, 57),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Sync Price List",
                          value: Tooltip(
                            message: 'Get Latest Price List',
                            margin: const EdgeInsets.all(2.0),
                            child: TextButton(
                              onPressed: () async {
                                // Mostrar el diálogo modal con el indicador de progreso
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );

                                // Esperar a que _loadItems termine antes de continuar
                                await _loadItems(context);

                                // Cerrar el diálogo modal una vez que la función termine
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    const Color.fromARGB(218, 142, 31, 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20.0, horizontal: 40.0),
                              ),
                              child: const Text(
                                'Sync',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          icon: Icons.cloud_download,
                          backgroundColor:
                              const Color.fromARGB(255, 120, 102, 71),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Draw Cash",
                          value: FormBuilder(
                            key: _formKeyDrawAmount,
                            autovalidateMode: AutovalidateMode.disabled,
                            child: SizedBox(
                              height: 100,
                              child: Tooltip(
                                message: "Recollect cash, needs admin rights.",
                                margin: const EdgeInsets.all(2.0),
                                child: FormBuilderTextField(
                                  name: 'drawCashAmount',
                                  enabled: _enableDrawCashTextField,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10.0, horizontal: 10.0),
                                    labelText: 'Amount to Draw',
                                    helperText: '',
                                    hintText: 'Amount',
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.always,
                                    border: const OutlineInputBorder(
                                      borderSide: BorderSide(),
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: Text(
                                        '€',
                                        style: TextStyle(
                                            color: Color.fromARGB(
                                                255, 255, 255, 255),
                                            fontSize: 18),
                                      ),
                                    ),
                                    suffixIcon: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 1.0, horizontal: 4.0),
                                      child: TextButton(
                                        onPressed: (_isFormLoadingDrawCash
                                            ? null
                                            : () => _doDrawCash(
                                                  userDataProvider: context
                                                      .read<UserDataProvider>(),
                                                  onSuccess: () =>
                                                      _showAdminPasswordDialog(
                                                          context),
                                                  onError: (message) =>
                                                      _onCashOpenError(
                                                          context, message),
                                                )),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: const Color.fromARGB(
                                              255, 94, 23, 7),
                                        ),
                                        child: const Text(
                                          'Draw',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    // FilteringTextInputFormatter.digitsOnly,
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  enableSuggestions: false,
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    FormBuilderValidators.numeric(),
                                  ]),
                                  // onSaved: () => (),
                                ),
                              ),
                            ),
                          ),
                          icon: Icons.shop_2_sharp,
                          backgroundColor:
                              const Color.fromARGB(255, 108, 78, 56),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Z Report",
                          value: Tooltip(
                            message:
                                'Generate Z report, this action closes the current session after print',
                            margin: const EdgeInsets.all(2.0),
                            child: _isLoading
                                ? const CircularProgressIndicator() // Muestra el indicador de carga mientras _isLoading es true
                                : TextButton(
                                    onPressed: () async {
                                      bool? acceptAction = await _showDialog(
                                        'Message',
                                        'This action close your current shift',
                                        showCancel: true,
                                      );
                                      if (acceptAction == true) {
                                        setState(() {
                                          _isLoading =
                                              true; // Activa el loading
                                        });

                                        try {
                                          await sendSalesData(
                                              context); // Espera a que se complete
                                          _generateXZReport(
                                              'Z-Report'); // Llama a la siguiente función
                                        } finally {
                                          setState(() {
                                            _isLoading =
                                                false; // Desactiva el loading al finalizar
                                          });
                                        }
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor:
                                          const Color.fromARGB(218, 142, 31, 6),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 20.0,
                                          horizontal:
                                              40.0), // Padding interno del botón
                                    ),
                                    child: const Text(
                                      'Generate',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                          ),
                          icon: Icons.euro_symbol,
                          backgroundColor:
                              const Color.fromARGB(255, 57, 57, 57),
                          textColor: Theme.of(context).colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Sync Data",
                          value: Tooltip(
                            message: 'Sync all data with the remote server',
                            margin: const EdgeInsets.all(2.0),
                            child: TextButton(
                              onPressed: () {
                                sendSalesData(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor:
                                    const Color.fromARGB(218, 142, 31, 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20.0, horizontal: 40.0),
                              ),
                              child: const Text(
                                'Send',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          icon: Icons.shopping_cart_checkout,
                          backgroundColor:
                              const Color.fromARGB(255, 120, 102, 71),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                        SummaryCard(
                          title: "Cash Available",
                          value: '€ ${_totalCashAvailable.toStringAsFixed(2)}',
                          icon: Icons.show_chart_outlined,
                          backgroundColor:
                              const Color.fromARGB(255, 108, 78, 56),
                          textColor: themeData.colorScheme.onPrimary,
                          iconColor: Colors.black12,
                          width: summaryCardWidth,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: kDefaultPadding),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//Widget to set string or another widget as value (dynamic)
class SummaryCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final double width;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.backgroundColor = const Color.fromARGB(255, 101, 87, 63),
    required this.textColor,
    required this.iconColor,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget titleWidget;

    //evalute if the var value is a widget or String
    if (value is String) {
      titleWidget = Text(
        value as String,
        style: textTheme.headlineSmall!.copyWith(
          color: textColor,
        ),
        overflow: TextOverflow.ellipsis,
      );
    } else if (value is Widget) {
      titleWidget = value as Widget;
    } else {
      throw ArgumentError('title must be either a String or a Widget');
    }

    return SizedBox(
      height: 180,
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: backgroundColor,
        child: Stack(
          children: [
            Positioned(
              top: kDefaultPadding * 0.5,
              right: kDefaultPadding * 0.5,
              child: Icon(
                icon,
                size: 80.0,
                color: iconColor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(kDefaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.left,
                    style: textTheme.headlineSmall!.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Divider(
                    color: Color.fromARGB(255, 255, 255, 255),
                    thickness: 1,
                    height: 10,
                    indent: 5,
                    endIndent: 80,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Align(
                        alignment: Alignment.center,
                        child: titleWidget,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

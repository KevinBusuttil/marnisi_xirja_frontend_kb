// ignore_for_file: use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/helpers/loyalty_receipt_helper.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/helpers/printer_platform_helper.dart';
import 'package:web_admin/helpers/sales_history_helper.dart';
import 'package:web_admin/theme/theme_extensions/app_button_theme.dart';
import 'package:web_admin/theme/theme_extensions/app_data_table_theme.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/printer_invoice_service.dart';
import 'package:web_admin/helpers/txn_helper.dart';
import 'package:web_admin/views/widgets/card_elements.dart';
import 'package:web_admin/views/widgets/marnisi_app_background.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';

class SalesHistory extends StatefulWidget {
  const SalesHistory({super.key});

  @override
  State<SalesHistory> createState() => _SalesHistoryState();
}

class _SalesHistoryState extends State<SalesHistory> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormBuilderState>();
  final SqlLiteService _dbSqlLiteHelper = SqlLiteService();
  String? defaultPrinter;
  // late PrinterManagerInvoice printerManager;
  PrinterManagerInvoice? printerManager;
  final logger = Logger(printer: PrettyPrinter());

  late DataSource _dataSource;
  bool _isLoading = true;
  String? _errorMessage;
  bool _deepSearchEnabled = false;
  String _historyScopeLabel = 'Local (last 7 days)';

  // store all data returned
  List<Map<String, dynamic>> _allSalesData = [];

  @override
  void initState() {
    super.initState();
    _loadSelectedPrinter();
    _loadSalesData();

    ///print receipt according the row
    _dataSource = DataSource(
      onPrintDocument: (data) {
        _handleOrder(data);
      },
      onGiftReceipt: (data) {
        _showGiftReceiptDialog("Gift Receipt", data, showCancel: true);
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  //load sales from db
  Future<void> _loadSalesData() async {
    try {
      await _dbSqlLiteHelper.purgeSyncedSalesOlderThan(retentionDays: 7);
      final salesData = await _fetchSalesData();
      setState(() {
        _isLoading = false;
        _historyScopeLabel = 'Local (last 7 days)';
        _allSalesData = salesData; // save all data
        _dataSource.updateData(salesData);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // fetch data from db
  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    final dbHelper = _dbSqlLiteHelper;
    final prefs = await SharedPreferences.getInstance();
    final selectedStore = (prefs.getString('selectedStore') ?? '').trim();
    final salesData = await dbHelper.getAllSalesHistory();

    final scopedSales = selectedStore.isEmpty
        ? salesData
        : salesData
            .where((sale) =>
                (sale['sales_store'] ?? '').toString().trim() == selectedStore)
            .toList(growable: false);

    return scopedSales.map((sale) {
      // check the items is a list
      final items = (sale['items'] as List<dynamic>?) ?? [];
      final payMthds = (sale['sale_pay_methods'] as List<dynamic>?) ?? [];
      final change = SalesHistoryHelper.asDouble(sale['sales_change']);
      final cashTendered = SalesHistoryHelper.cashTenderedFromPayments(
        payMthds.whereType<Map<String, dynamic>>().toList(),
        change: change,
      );

      return {
        'sales_num': sale['sales_num'],
        'date': sale['sales_date'],
        'time': sale['sales_time'],
        'subtotal':
            double.parse(sale['sales_subtotal'].toString()).toStringAsFixed(2),
        'tax': double.parse(sale['sales_tax'].toString()).toStringAsFixed(2),
        'total':
            double.parse(sale['sales_total'].toString()).toStringAsFixed(2),
        'discounted_subtotal': sale['sales_discounted_subtotal'],
        'discounted_tax': sale['sales_discounted_tax'],
        'items': items, // list of items
        'cashier': sale['sales_cashier'],
        'status': sale['sales_status'],
        'payMthds': payMthds,
        'discount': sale['sales_discount'] ?? 0,
        'change': change,
        'cash_tendered': cashTendered,
        'loy_cust_card_num': sale['loy_cust_card_num'] ?? "",
        'loy_points_used': sale['loy_points_used'] ?? 0.0,
        'loy_points_earned': sale['loy_points_earned'] ?? 0.0,
        'balance_points': sale['balance_points'] ?? 0.0,
      };
    }).toList();
  }

//old flow to filter data
  // void _filterSalesData() {
  //   final formData = _formKey.currentState?.value;

  //   if (formData == null) return;

  //   final saleNum = formData['sale_num']?.toString().toLowerCase();
  //   final saleDate = formData['sale_date'] != null ? DateFormat('yyyy-MM-dd').format(formData['sale_date']) : null;
  //   final itemCode = formData['item_code']?.toString().toLowerCase();
  //   final itemName = formData['item_name']?.toString().toLowerCase();

  //   // filter always over _allSalesData, not over _dataSource._data
  //   final filteredData = _allSalesData.where((sale) {
  //     final saleNumMatch = saleNum == null || sale['sales_num'].toString().toLowerCase().contains(saleNum);
  //     final saleDateMatch = saleDate == null || sale['date'].toString().contains(saleDate);

  //     // search inside items
  //    // final items = sale['items'] as List<dynamic>;

  //       final items = sale['items'] != null
  //     ? jsonDecode(sale['items'])
  //     : [];

  //     final itemCodeMatch =
  //         itemCode == null || items.any((item) => item['item_id'].toString().toLowerCase().contains(itemCode));
  //     final itemNameMatch =
  //         itemName == null || items.any((item) => item['item_name'].toString().toLowerCase().contains(itemName));

  //     return saleNumMatch && saleDateMatch && itemCodeMatch && itemNameMatch;
  //   }).toList();

  //   setState(() {
  //     _dataSource.updateData(filteredData);
  //   });
  // }

  Future<void> _searchSalesData() async {
    final formState = _formKey.currentState;
    if (formState == null) return;

    final formData = formState.value;
    final saleNum = (formData['sale_num'] ?? '').toString().trim();
    final itemCode = (formData['item_code'] ?? '').toString().trim();
    final itemName = (formData['item_name'] ?? '').toString().trim();
    final DateTime? fromDate = formData['date_from'];
    final DateTime? toDate = formData['date_to'];

    if (_deepSearchEnabled) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final remoteResults = await _fetchRemoteSalesData(
          saleNum: saleNum,
          itemCode: itemCode,
          itemName: itemName,
          fromDate: fromDate,
          toDate: toDate,
        );
        setState(() {
          _historyScopeLabel = 'Deep Search (server)';
          _dataSource.updateData(remoteResults);
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
      return;
    }

    final filteredData = SalesHistoryHelper.filterSales(
      _allSalesData,
      SalesHistoryFilterCriteria(
        saleNum: saleNum,
        itemCode: itemCode,
        itemName: itemName,
        fromDate: fromDate,
        toDate: toDate,
      ),
    );

    setState(() {
      _historyScopeLabel = 'Local (last 7 days)';
      _dataSource.updateData(filteredData);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteSalesData({
    required String saleNum,
    required String itemCode,
    required String itemName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedStore = (prefs.getString('selectedStore') ?? '').trim();
    final api = ApiService(endpointPath: ApiRoutes.getSalesHistory);
    final args = <String, dynamic>{
      if (saleNum.isNotEmpty) 'sale_num': saleNum,
      if (itemCode.isNotEmpty) 'item_code': itemCode,
      if (itemName.isNotEmpty) 'item_name': itemName,
      if (fromDate != null)
        'from_date': DateFormat('yyyy-MM-dd').format(fromDate),
      if (toDate != null) 'to_date': DateFormat('yyyy-MM-dd').format(toDate),
      if (selectedStore.isNotEmpty) 'sales_store': selectedStore,
      'limit': 1000,
    };

    final response = await api.postData([args], (message) {
      logger.d(message);
    });

    if (response == null) {
      throw Exception('No response from server');
    }

    if (response['status'] != 'success') {
      throw Exception(
          response['message'] ?? 'Failed to load remote sales history');
    }

    final sales = (response['sales'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return sales.map((sale) {
      final items = (sale['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final payMthds = (sale['sale_pay_methods'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final change = SalesHistoryHelper.asDouble(sale['sales_change']);
      final cashTendered = SalesHistoryHelper.cashTenderedFromPayments(
        payMthds,
        change: change,
      );

      return {
        'sales_num': sale['sales_num'],
        'date': sale['sales_date'],
        'time': sale['sales_time'],
        'subtotal': SalesHistoryHelper.asDouble(sale['sales_subtotal'])
            .toStringAsFixed(2),
        'tax':
            SalesHistoryHelper.asDouble(sale['sales_tax']).toStringAsFixed(2),
        'total':
            SalesHistoryHelper.asDouble(sale['sales_total']).toStringAsFixed(2),
        'discounted_subtotal': sale['sales_discounted_subtotal'],
        'discounted_tax': sale['sales_discounted_tax'],
        'items': items,
        'cashier': sale['sales_cashier'],
        'status': sale['sales_status'] ?? 'Complete',
        'payMthds': payMthds,
        'discount': SalesHistoryHelper.asDouble(sale['sales_discount']),
        'change': change,
        'cash_tendered': cashTendered,
        'loy_cust_card_num': sale['loy_cust_card_num'] ?? "",
        'loy_points_used': SalesHistoryHelper.asDouble(sale['loy_points_used']),
        'loy_points_earned':
            SalesHistoryHelper.asDouble(sale['loy_points_earned']),
        'balance_points': SalesHistoryHelper.asDouble(sale['balance_points']),
      };
    }).toList();
  }

  //select default printer
  // Future<void> _loadSelectedPrinter() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     defaultPrinter = prefs.getString('selectedPrinter');
  //   });

  //   if (defaultPrinter == null || defaultPrinter!.isEmpty) {
  //     bool? confirmed = await _showDialog('Alert', 'No printer selected.');
  //     // if (confirmed == true && mounted) {
  //     //   GoRouter.of(context).go(RouteUri.generalSettings);
  //     // }
  //   } else {
  //     printerManager = PrinterManagerInvoice(
  //       showDialog: _showDialog,
  //     );
  //   }
  // }

// select default printer
  Future<void> _loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      defaultPrinter = prefs.getString('selectedPrinter');
    });

    if (defaultPrinter == null || defaultPrinter!.isEmpty) {
      //  set a fallback default instead of showing popup
      setState(() {
        defaultPrinter = "Default Printer"; // or dummy printer name
      });

      // also persist so it won’t break on next load
      await prefs.setString('selectedPrinter', defaultPrinter!);

      if (PrinterPlatformHelper.supportsNativePrinter()) {
        printerManager = PrinterManagerInvoice(
          showDialog: _showDialog,
        );
      } else {
        printerManager = null;
      }
    } else {
      if (PrinterPlatformHelper.supportsNativePrinter()) {
        printerManager = PrinterManagerInvoice(
          showDialog: _showDialog,
        );
      } else {
        printerManager = null;
      }
    }
  }

  //select the payment methods
  // String _getPayMthdsTxn(data) {
  //   List<dynamic> payMthsTxn = data['payMthds'];
  //   String allPaymentNames = '';
  //   for (var method in payMthsTxn) {
  //     allPaymentNames += method['payment_name'] + ', ';
  //   }
  //   if (allPaymentNames.isNotEmpty) {
  //     allPaymentNames = allPaymentNames.substring(0, allPaymentNames.length - 2);
  //   }
  //   return allPaymentNames;
  // }

  String _getPayMthdsTxn(Map<String, dynamic> data) {
    final List<dynamic> payMthsTxn = (data['payMthds'] as List<dynamic>?) ?? [];

    if (payMthsTxn.isEmpty) {
      return '-';
    }

    return payMthsTxn
        .map((e) => e['payment_name']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .join(', ');
  }

  bool _hasLoyaltyDetails(Map<String, dynamic> data) {
    return LoyaltyReceiptHelper.hasLoyaltyData(
      loyaltyCardNum: (data['loy_cust_card_num'] ?? '').toString(),
      loyaltyPointsUsed: SalesHistoryHelper.asDouble(data['loy_points_used']),
      loyaltyRewardAmount:
          SalesHistoryHelper.asDouble(data['loy_points_earned']),
      loyaltyPointsBalance: SalesHistoryHelper.asDouble(data['balance_points']),
    );
  }

  //print receipt
  void _handleOrder(data) async {
    try {
      if (data.isEmpty) {
        await _showDialog('Message', 'There is no data to print',
            showCancel: false);
        return;
      } else {
        bool? confirmed = await _showDialog(
            'Message', 'Would you like to print the invoice?',
            showCancel: true);
        if (confirmed == true) {
          if (defaultPrinter == null || defaultPrinter!.isEmpty) {
            _showDialog('Message', 'There is no default printer',
                showCancel: true);
            if (mounted) {
              // GoRouter.of(context).go(RouteUri.generalSettings);
            }
            return;
          }
//////
          if (!PrinterPlatformHelper.supportsNativePrinter()) {
            await _showDialog(
              'Message',
              'Printing is not supported on this platform.',
              showCancel: false,
            );
            return;
          }

          printerManager = PrinterManagerInvoice(
            showDialog: (title, message) async => false,
          );

          var payMthdsTxn = _getPayMthdsTxn(data);
          final showLoyaltyDetails = _hasLoyaltyDetails(data);
          final receiptTotals = SalesHistoryHelper.resolveReceiptTotals(
            items: data['items'] as List<dynamic>? ?? const [],
            discountedSubTotal: data['discounted_subtotal'] == null
                ? null
                : SalesHistoryHelper.asDouble(data['discounted_subtotal']),
            discountedTax: data['discounted_tax'] == null
                ? null
                : SalesHistoryHelper.asDouble(data['discounted_tax']),
            fallbackSubTotal: SalesHistoryHelper.asDouble(data['subtotal']),
            fallbackTax: SalesHistoryHelper.asDouble(data['tax']),
          );

          await TxnHelper.saveTxn(
            txnReceiptNum: '',
            txnAmount: 0.0,
            txnType: Event.printInv,
            txnStatus: PostingStatus.pending,
            txnLocalStatus: LocalEvent.pending,
          );

          await printerManager!.printReceipt(
            isCopyReceipt: 'COPY OF THE RECEIPT',
            payMethod: payMthdsTxn,
            cashTendered: SalesHistoryHelper.asDouble(data['cash_tendered']),
            change: SalesHistoryHelper.asDouble(data['change']),
            formattedDate: data['date'],
            formattedTime: data['time'],
            orderItems: data['items'],
            subTotal: receiptTotals.subTotal,
            tax: receiptTotals.tax,
            total: double.parse(data['total']),
            discount: data['discount'] ?? 0,
            orderNumber: data['sales_num'],
            vatNum: '-',
            clientNum: '-',
            employeeNum: data['cashier'],
            clientName: '-',
            loyaltyCardNum: data['loy_cust_card_num'] ?? '',
            loyaltyPointsused: data['loy_points_used'] ?? 0.0,
            loyaltyRewardAmount: data['loy_points_earned'] ?? 0.0,
            loyaltyPointsBalance: data['balance_points'] ?? 0.0,
            showLoyaltyDetails: showLoyaltyDetails,
          );

          final receipt = buildReceiptForDebug(
            isCopyReceipt: 'COPY OF THE RECEIPT',
            payMethod: payMthdsTxn,
            cashTendered: SalesHistoryHelper.asDouble(data['cash_tendered']),
            change: SalesHistoryHelper.asDouble(data['change']),
            formattedDate: data['date'],
            formattedTime: data['time'],
            orderItems: data['items'],
            subTotal: receiptTotals.subTotal,
            tax: receiptTotals.tax,
            total: double.parse(data['total']),
            discount: data['discount'] ?? 0,
            orderNumber: data['sales_num'],
            employeeNum: data['cashier'],
            loyaltyCardNum: data['loy_cust_card_num'] ?? '',
            loyaltyPointsused: data['loy_points_used'] ?? 0.0,
            loyaltyRewardAmount: data['loy_points_earned'] ?? 0.0,
            loyaltyPointsBalance: data['balance_points'] ?? 0.0,
          );

          // 🔥 PRINT TO DEBUG CONSOLE
          debugPrint(receipt);
        } else {
          // Handle order cancellation
        }
      }
    } catch (e) {
      await _showDialog('Error', 'An error occurred: $e', showCancel: false);
    }
  }

  //*************************************** */
  // Dialog box item selector to print
  //*************************************** */
  Future<bool?> _showGiftReceiptDialog(String title, Map<String, dynamic> data,
      {bool showCancel = false}) {
    //Map to store item selection (true for selected)
    Map<int, bool> selectedItems = {};

    // Initialize the selection map with all items deselected
    for (var i = 0; i < data['items'].length; i++) {
      selectedItems[i] = false; // Starts unselected
    }

    bool selectAll = false; // Status to select or deselect all items

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              title: Text(title),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height *
                      0.8, // Limit the maximum size of the dialog
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Num: ${data['sales_num']}'),
                      Text('Date: ${data['date']}'),
                      Text('Time: ${data['time']}'),
                      Text('Subtotal: €${data['subtotal']}'),
                      Text('Tax: €${data['tax']}'),
                      Text('Total: €${data['total']}'),
                      const SizedBox(
                        width: 700,
                        child: Divider(
                          color: Color.fromARGB(255, 167, 164, 164),
                          thickness: 1.0,
                          height: 10,
                        ),
                      ),
                      const SizedBox(height: 10), //separator
                      const Text('Items:',
                          style: TextStyle(fontWeight: FontWeight.bold)),

                      // Tabla de los items
                      Table(
                        columnWidths: const {
                          0: FixedColumnWidth(70), // Column checkbox
                          1: FixedColumnWidth(50), // Column qty
                          2: FlexColumnWidth(100), // Column name item
                          3: FixedColumnWidth(80), // Column price
                        },
                        border: TableBorder.all(color: Colors.grey),
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          // Table header with checkbox to select all
                          TableRow(
                            decoration: const BoxDecoration(color: Colors.grey),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Checkbox(
                                  value: selectAll,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      selectAll = value!;
                                      // Select or deselect all items
                                      for (var i = 0;
                                          i < data['items'].length;
                                          i++) {
                                        selectedItems[i] = selectAll;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text('Qty',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text('Item Name',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Text('Price',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          // Rows of the articles
                          ...data['items']
                              .asMap()
                              .entries
                              .map<TableRow>((entry) {
                            int index = entry.key;
                            var item = entry.value;

                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Checkbox(
                                    value: selectedItems[index],
                                    onChanged: (bool? value) {
                                      setState(() {
                                        selectedItems[index] = value!;
                                        // Update selectAll if any item is deselected
                                        if (!value) {
                                          selectAll = false;
                                        } else {
                                          // Check if all are selected
                                          selectAll = selectedItems.values
                                              .every(
                                                  (isSelected) => isSelected);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('${item['item_qty']}',
                                      textAlign: TextAlign.center),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('${item['item_name']}',
                                      textAlign: TextAlign.left),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                      '€${double.parse(item['item_price'].toString()).toStringAsFixed(2)}',
                                      textAlign: TextAlign.right),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Cashier: ${data['cashier']}'),
                      Text('Status: ${data['status']}'),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("Print"),
                  onPressed: () async {
                    // Create a new map with the selected items
                    List<Map<String, dynamic>> selectedItemsList = [];

                    selectedItems.forEach((index, isSelected) {
                      if (isSelected) {
                        selectedItemsList.add(data['items'][index]);
                      }
                    });

                    // ######################
                    // call printer
                    // ######################

                    logger.d('Selected Items: $selectedItemsList');
                    try {
                      if (selectedItemsList.isEmpty) {
                        await _showDialog(
                            'Message', 'Please select items to print',
                            showCancel: false);
                      } else {
                        bool? confirmed = await _showDialog('Message',
                            'Would you like to print the gift invoice?',
                            showCancel: true);
                        if (confirmed == true) {
                          if (defaultPrinter == null ||
                              defaultPrinter!.isEmpty) {
                            _showDialog(
                                'Message', 'There is no default printer',
                                showCancel: true);
                            return;
                          }

                          await TxnHelper.saveTxn(
                            txnReceiptNum: '',
                            txnAmount: 0.0,
                            txnType: Event.printInv,
                            txnStatus: PostingStatus.pending,
                            txnLocalStatus: LocalEvent.pending,
                          );

                          if (!PrinterPlatformHelper.canUsePrinterManager(
                              printerManager)) {
                            await _showDialog(
                              'Message',
                              'Printing is not supported on this platform.',
                              showCancel: false,
                            );
                            return;
                          }

                          await printerManager!.printGiftReceipt(
                            payMethod: 'payMethod',
                            formattedDate: data['date'],
                            formattedTime: data['time'],
                            orderItems: selectedItemsList,
                            orderNumber: data['sales_num'],
                            vatNum: '-',
                            clientNum: '-',
                            employeeNum: data['cashier'],
                            clientName: '-',
                          );

                          Navigator.of(context).pop(true);
                        } else {
                          // Handle order cancellation
                        }
                      }
                    } catch (e) {
                      await _showDialog('Error', 'An error occurred: $e',
                          showCancel: false);
                    }

                    // Navigator.of(context).pop(true);
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
      },
    );
  }

  String _padRight(String? text, int width) {
    final value = text ?? '';
    return value.length >= width
        ? value.substring(0, width)
        : value.padRight(width);
  }

  String _padLeft(String? text, int width) {
    final value = text ?? '';
    return value.length >= width
        ? value.substring(0, width)
        : value.padLeft(width);
  }

  String _totalLine(String label, double? value, {bool bold = false}) {
    final amount = (value ?? 0).toStringAsFixed(2);
    final line = '${_padRight(label, 20)}${_padLeft(amount, 12)}';
    return bold ? '>> $line <<' : line;
  }

  String buildReceiptForDebug({
    required String isCopyReceipt,
    required String payMethod,
    required double cashTendered,
    required double change,
    required String formattedDate,
    required String formattedTime,
    required List orderItems,
    required double? subTotal,
    required double? tax,
    required double? total,
    required double? discount,
    required String orderNumber,
    required String employeeNum,
    required String loyaltyCardNum,
    required double? loyaltyPointsused,
    required double? loyaltyRewardAmount,
    required double? loyaltyPointsBalance,
  }) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('================================');
    buffer.writeln('      Print Receipt          ');
    buffer.writeln(isCopyReceipt);
    buffer.writeln('================================');

    buffer.writeln('Invoice #: $orderNumber');
    buffer.writeln('Date: $formattedDate   Time: $formattedTime');
    buffer.writeln('Cashier: $employeeNum');
    buffer.writeln('--------------------------------');

    buffer.writeln(
      '${_padRight("Item", 16)}'
      '${_padLeft("Qty", 6)}'
      '${_padLeft("Amt", 10)}',
    );
    buffer.writeln('--------------------------------');

    for (var item in orderItems) {
      buffer.writeln(
        '${_padRight(item['item_name']?.toString(), 16)}'
        '${_padLeft(item['item_qty']?.toString() ?? '0', 6)}'
        '${_padLeft((item['item_price'] ?? 0).toStringAsFixed(2), 10)}',
      );
    }

    buffer.writeln('--------------------------------');
    buffer.writeln(_totalLine('Discount', (discount ?? 0).abs()));
    buffer.writeln(_totalLine('Subtotal', subTotal));
    buffer.writeln(_totalLine('Tax', tax));
    buffer.writeln('--------------------------------');
    buffer.writeln(_totalLine('TOTAL', total, bold: true));
    buffer.writeln('--------------------------------');

    buffer.writeln('Payment Method: $payMethod');
    if (cashTendered > 0 || change > 0) {
      buffer.writeln(_totalLine('Cash Tendered', cashTendered));
      buffer.writeln(_totalLine('Change Given', change));
    }

    if (loyaltyCardNum.isNotEmpty ||
        (loyaltyPointsused ?? 0) > 0 ||
        (loyaltyRewardAmount ?? 0) > 0 ||
        (loyaltyPointsBalance ?? 0) > 0) {
      buffer.writeln('--------------------------------');
      buffer.writeln('Loyalty Card: $loyaltyCardNum');
      buffer.writeln('Points Used: $loyaltyPointsused');
      buffer.writeln('Points Earned: $loyaltyRewardAmount');
      buffer.writeln('Points Balance: $loyaltyPointsBalance');
    }

    buffer.writeln('================================');
    buffer.writeln(' Thank you for shopping with us ');
    buffer.writeln('================================');

    return buffer.toString();
  }

  //*************************************** */
  // Dialog box
  //*************************************** */
  Future<bool?> _showDialog(String title, String message,
      {bool showCancel = false}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
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

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final appDataTableTheme = themeData.extension<AppDataTableTheme>()!;

    return PortalMasterLayout(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MarnisiAppBackground(),
          ),
          ListView(
            padding: const EdgeInsets.all(kDefaultPadding),
            children: [
              Text(
                'Order History',
                style: themeData.textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardBody(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: kDefaultPadding * 2.0),
                              child: FormBuilder(
                                key: _formKey,
                                autovalidateMode: AutovalidateMode.disabled,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    direction: Axis.horizontal,
                                    spacing: kDefaultPadding,
                                    runSpacing: kDefaultPadding,
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 200.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: kDefaultPadding * 1.5),
                                          child: FormBuilderDateTimePicker(
                                            name: 'date_from',
                                            inputType: InputType.date,
                                            decoration: InputDecoration(
                                              labelText: 'From Date',
                                              hintText: 'Start date',
                                              border:
                                                  const OutlineInputBorder(),
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              isDense: true,
                                              suffixIcon: IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _formKey.currentState
                                                      ?.fields['date_from']
                                                      ?.didChange(null);
                                                },
                                              ),
                                            ),
                                            format: DateFormat('yyyy-MM-dd'),
                                            initialDatePickerMode:
                                                DatePickerMode.day,
                                            initialEntryMode:
                                                DatePickerEntryMode
                                                    .calendarOnly,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: kDefaultPadding * 1.5),
                                          child: FormBuilderDateTimePicker(
                                            name: 'date_to',
                                            inputType: InputType.date,
                                            decoration: InputDecoration(
                                              labelText: 'To Date',
                                              hintText: 'End date',
                                              border:
                                                  const OutlineInputBorder(),
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              isDense: true,
                                              suffixIcon: IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _formKey.currentState
                                                      ?.fields['date_to']
                                                      ?.didChange(null);
                                                },
                                              ),
                                            ),
                                            format: DateFormat('yyyy-MM-dd'),
                                            initialDatePickerMode:
                                                DatePickerMode.day,
                                            initialEntryMode:
                                                DatePickerEntryMode
                                                    .calendarOnly,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: kDefaultPadding * 1.5),
                                          child: FormBuilderTextField(
                                            name: 'sale_num',
                                            decoration: InputDecoration(
                                              labelText: 'Sale Num',
                                              hintText: 'Select Sale Num',
                                              border:
                                                  const OutlineInputBorder(),
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              isDense: true,
                                              suffixIcon: IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  // Limpiar la selección del campo de texto
                                                  _formKey.currentState
                                                      ?.fields['sale_num']
                                                      ?.didChange('');
                                                },
                                              ),
                                            ),
                                            // onChanged: (_) {
                                            //   _clearOtherFields('sale_num');
                                            // },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: kDefaultPadding * 1.5),
                                          child: FormBuilderTextField(
                                            name: 'item_code',
                                            decoration: InputDecoration(
                                                labelText: 'Item Code',
                                                hintText: 'Select Item Code',
                                                border:
                                                    const OutlineInputBorder(),
                                                floatingLabelBehavior:
                                                    FloatingLabelBehavior
                                                        .always,
                                                isDense: true,
                                                suffixIcon: IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  onPressed: () {
                                                    _formKey.currentState
                                                        ?.fields['item_code']
                                                        ?.didChange('');
                                                  },
                                                )),

                                            // onChanged: (_) {
                                            //   _clearOtherFields('item_code');
                                            // },
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              right: kDefaultPadding * 1.5),
                                          child: FormBuilderTextField(
                                            name: 'item_name',
                                            decoration: InputDecoration(
                                              labelText: 'Item Name',
                                              hintText: 'Select Item Name',
                                              border:
                                                  const OutlineInputBorder(),
                                              floatingLabelBehavior:
                                                  FloatingLabelBehavior.always,
                                              isDense: true,
                                              suffixIcon: IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  _formKey.currentState
                                                      ?.fields['item_name']
                                                      ?.didChange('');
                                                },
                                              ),
                                            ),
                                            // onChanged: (_) {
                                            //   _clearOtherFields('item_name');
                                            // },
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        style: themeData
                                            .extension<AppButtonTheme>()!
                                            .infoElevated,
                                        onPressed: () async {
                                          if (_formKey.currentState!
                                              .saveAndValidate()) {
                                            await _searchSalesData();
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: kDefaultPadding * 0.5),
                                              child: Icon(
                                                Icons.search,
                                                size: (themeData.textTheme
                                                        .labelLarge!.fontSize! +
                                                    4.0),
                                              ),
                                            ),
                                            const Text('Search'),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Deep Search (server)'),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value: _deepSearchEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _deepSearchEnabled = value;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: kDefaultPadding * 2.0),
                              child: Text(
                                'Source: $_historyScopeLabel',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                // _errorMessage != null
                                //    ? Center(child: Text('Error: $_errorMessage'))
                                //     : SizedBox( // old code used to be lke this... Remove this commented code after testing.
                                : _errorMessage != null
                                    ? Center(
                                        child: Text('Error: $_errorMessage'))
                                    : _dataSource.rowCount == 0
                                        ? const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(20),
                                              child: Text(
                                                'No orders available for the selected filters',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                            ),
                                          )
                                        : SizedBox(
                                            width: double.infinity,
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                final double dataTableWidth =
                                                    max(kScreenWidthMd,
                                                        constraints.maxWidth);

                                                return Scrollbar(
                                                  controller: _scrollController,
                                                  thumbVisibility: true,
                                                  trackVisibility: true,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    controller:
                                                        _scrollController,
                                                    child: SizedBox(
                                                      width: dataTableWidth,
                                                      child: Theme(
                                                        data:
                                                            themeData.copyWith(
                                                          cardTheme:
                                                              appDataTableTheme
                                                                  .cardTheme,
                                                          dataTableTheme: AppDataTableTheme
                                                                  .fromTheme(
                                                                      ThemeData
                                                                          .dark())
                                                              .dataTableThemeData,
                                                        ),
                                                        child: SizedBox(
                                                          child:
                                                              PaginatedDataTable(
                                                            source: _dataSource,
                                                            rowsPerPage: 20,
                                                            showCheckboxColumn:
                                                                true,
                                                            showFirstLastButtons:
                                                                true,
                                                            columns: const [
                                                              DataColumn(
                                                                  label: Text(
                                                                      'No.'),
                                                                  numeric:
                                                                      true),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Date')),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Loyalty Card No.')),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Subtotal'),
                                                                  numeric:
                                                                      true),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'TAX'),
                                                                  numeric:
                                                                      true),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Total'),
                                                                  numeric:
                                                                      true),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Status')),
                                                              DataColumn(
                                                                  label: Text(
                                                                      'Actions')),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                          ],
                        ),
                      ),
                    ],
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

const kDefaultPadding = 5.0;

class DataSource extends DataTableSource {
  final void Function(Map<String, dynamic> data) onPrintDocument;
  final void Function(Map<String, dynamic> data) onGiftReceipt;
  final logger = Logger(printer: PrettyPrinter());
  List<Map<String, dynamic>> _data;

  DataSource({
    required this.onPrintDocument,
    required this.onGiftReceipt,
    List<Map<String, dynamic>> data = const [],
  }) : _data = data;

  void updateData(List<Map<String, dynamic>> newData) {
    _data = newData;
    notifyListeners();
  }

  @override
  DataRow? getRow(int index) {
    final data = _data[index];
    final actions = <String>[
      'Print',
      if (!MarnisiPosRestrictions.hideGiftReceiptAction) 'Gift Receipt',
    ];

    return DataRow.byIndex(index: index, cells: [
      DataCell(Text(data['sales_num'].toString())),
      DataCell(Text(data['date'].toString())),
      DataCell(Text(data['loy_cust_card_num']?.toString() ?? '--')),
      DataCell(Text('€${data['subtotal'].toString()}')),
      DataCell(Text('€${data['tax'].toString()}')),
      DataCell(Text('€${data['total'].toString()}')),
      DataCell(Text(data['status'].toString())),
      DataCell(Builder(
        builder: (context) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: kDefaultPadding),
                child: DropdownButton<String>(
                  value: null, // empty value
                  hint: const Text("Select action"),
                  icon: const Icon(Icons.arrow_drop_down),
                  onChanged: (String? newValue) {
                    if (newValue == 'Print') {
                      onPrintDocument.call(data);
                    } else if (newValue == 'Gift Receipt' &&
                        !MarnisiPosRestrictions.hideGiftReceiptAction) {
                      onGiftReceipt.call(data);
                    } else if (newValue == 'name_option') {
                      logger.d('set here new option');
                    }
                  },
                  //add here extra options--------
                  items: actions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      )),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _data.length;

  @override
  int get selectedRowCount => 0;
}

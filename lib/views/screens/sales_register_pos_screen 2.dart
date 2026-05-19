// ignore_for_file: use_build_context_synchronously
// import 'package:web_admin/services/cash_managment_helper.dart';

import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/sales_status.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/cash_managment_helper.dart';
import 'package:web_admin/helpers/loyalty_receipt_helper.dart';
import 'package:web_admin/helpers/item_search_filter_helper.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/helpers/payment_flow_helper.dart';
import 'package:web_admin/helpers/payment_method_display_helper.dart';
import 'package:web_admin/helpers/pos_tablet_layout_helper.dart';
import 'package:web_admin/helpers/printer_debug_log_helper.dart';
import 'package:web_admin/helpers/printer_platform_helper.dart';
import 'package:web_admin/helpers/sales_pricing_calculator.dart';
import 'package:web_admin/helpers/sales_history_helper.dart';
import 'package:web_admin/helpers/store_loyalty_policy.dart';
import 'package:web_admin/helpers/tour_register_helper.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:web_admin/views/components/dialog_add_customer.dart';
import 'package:web_admin/views/components/dialog_pay_returns.dart';
import 'package:web_admin/models/cliente.dart';
import 'package:web_admin/models/order.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/marnisi_api_service.dart';
import 'package:web_admin/services/printer_invoice_service.dart';
import 'package:web_admin/helpers/txn_helper.dart';
import 'package:web_admin/views/components/dialog_discount.dart';
import 'package:web_admin/views/components/dialog_paymenth.dart';
import 'package:web_admin/views/widgets/sales_register_pos/item.dart';
import 'package:web_admin/views/widgets/sales_register_pos/item_order.dart';
import 'package:web_admin/views/widgets/sales_register_pos/payment_btn.dart';
import 'package:web_admin/views/widgets/sales_register_pos/search_field.dart';
import 'package:web_admin/views/components/top_title.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/views/widgets/marnisi_app_background.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';
import 'package:web_admin/views/components/virtual_numpad.dart';

class PosSystem extends StatefulWidget {
  const PosSystem({super.key});

  @override
  State<PosSystem> createState() => _PosSystemState();
}

class _PosSystemState extends State<PosSystem>
    with SingleTickerProviderStateMixin {
  final Order _order = Order();
  final Client _client = Client();
  final logger = Logger(printer: PrettyPrinter());
  final FocusNode _searchFocusNode = FocusNode();
  final _dbHelper = SqlLiteService();
  final MarnisiApiService _marnisiApi = const MarnisiApiService();

  final TextEditingController _customerMobileController =
      TextEditingController();
  Map<String, dynamic>? _selectedCustomer;
  bool? cashStatus;
  String? defaultPrinter;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> orderItems = [];
  late final DialogPayAndReturns _dialogPayAndReturns;
  late final DialogNewCustomer _dialogNewCustomer;
  late final DialogLoyaltyRedeem _dialogLoyaltyRedeem;
  late AnimationController _controller;
  late Animation<double> _animation;
  // late PrinterManagerInvoice printerManager;
  PrinterManagerInvoice? printerManager;
  List<String> enabledPaymentMethods = [];
  bool _isLoadingLoyaltyData = false;
  StoreLoyaltyPolicy _storeLoyaltyPolicy = const StoreLoyaltyPolicy(
    enabled: false,
    allowEarn: false,
    allowRedeem: false,
    showCustomerUi: false,
    showPointsUi: false,
    showReceiptDetails: false,
  );
  final TextEditingController _searchController = TextEditingController();
  bool isOffline = false;
  bool _isSaleProcessing = false;
  String _saleProcessingMessage =
      'Syncing order with server...\nThis can take up to 8 seconds.';
  String _sessionCookie = '';
  Timer? _recentChangeTimer;
  double _recentPrintedChange = 0.0;
  double _recentPrintedCashTendered = 0.0;
  String _activeTourBookingId = '';
  String _activeTourBookingNo = '';

  void _setSaleProcessing(bool isProcessing, {String? message}) {
    if (!mounted) return;
    setState(() {
      _isSaleProcessing = isProcessing;
      if (message != null) {
        _saleProcessingMessage = message;
      }
    });
  }

  void _showRecentChange({
    required double change,
    required double cashTendered,
  }) {
    _recentChangeTimer?.cancel();
    setState(() {
      _recentPrintedChange = SalesPricingCalculator.round2(change);
      _recentPrintedCashTendered = SalesPricingCalculator.round2(cashTendered);
    });
    _recentChangeTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(() {
        _recentPrintedChange = 0.0;
        _recentPrintedCashTendered = 0.0;
      });
    });
  }

  @override
  void dispose() {
    _recentChangeTimer?.cancel();
    _controller.dispose();
    super.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _customerMobileController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dialogPayAndReturns = DialogPayAndReturns();
    _dialogNewCustomer = DialogNewCustomer();
    _dialogLoyaltyRedeem = DialogLoyaltyRedeem();

    /// controller to animate balance pending to pay
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
    //..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _searchFocusNode.requestFocus();
    _initializeData();
    _loadPaymentMethods();
    initPrinterManager();
    _loadStoreLoyaltyPolicy();
  }

  void initPrinterManager() {
    if (PrinterPlatformHelper.supportsNativePrinter()) {
      printerManager = PrinterManagerInvoice(
        showDialog: (title, message) async => false,
      );
    } else {
      printerManager = null; // no attempt to load Windows DLLs
      debugPrint("🖨️ Printer disabled on unsupported platform.");
    }
  }

  Future<void> _loadStoreLoyaltyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('selectedStore');
    if (storeId == null || storeId.isEmpty) {
      setState(() {
        _storeLoyaltyPolicy = const StoreLoyaltyPolicy();
      });
      await _loadLoyCust();
      return;
    }

    final policyRow = await _dbHelper.getStoreLoyaltyPolicy(storeId);
    final nextPolicy = StoreLoyaltyPolicy.fromStoreRow(policyRow);

    setState(() {
      _storeLoyaltyPolicy = nextPolicy;
      if (!_storeLoyaltyPolicy.canCaptureCustomer) {
        _selectedCustomer = null;
        _client.clientName = '';
        _client.clientNum = '';
        _customerMobileController.clear();
      }
    });

    if (nextPolicy.canCaptureCustomer) {
      await _loadLoyCust();
    }
  }

  bool _saleHasLoyaltyData() {
    return (_client.clientNum ?? '').trim().isNotEmpty ||
        _order.loyaltyPointsUsed > 0 ||
        _order.loyaltyPointsEarned > 0 ||
        _order.loyaltyPointsBalance > 0;
  }

//******************************** */
//FETCH CUSTOMERS FROM FRAPPE
//******************************** */

  Future<void> _loadLoyCust() async {
    final ApiService apiGetLoyCust =
        ApiService(endpointPath: ApiRoutes.getLoyUsers);
    final SqlLiteService dbHelper = SqlLiteService();
    final db = await dbHelper.database;

    try {
      logger.d("Getting Loyalty customers from server...");

      // Fetch all existing local customers to compare against remote data
      List<Map<String, dynamic>> existingCust = await db.query('loy_custx');

      // Fetch remote customers from the API
      Map<String, dynamic> data = await apiGetLoyCust.fetchData();
      List<dynamic> message = data['message'];

      // Get a set of remote and local customer IDs (using card number as the unique ID)
      Set<String> remoteCustIds =
          message.map((item) => item['loy_cust_card_num'].toString()).toSet();
      Set<String> localCustIds = existingCust
          .map((item) => item['loy_custx_card_num'].toString())
          .toSet();

      await db.transaction((txn) async {
        // Process each customer record received from the API
        for (var item in message) {
          String custId = item['loy_cust_card_num']?.toString() ?? '';
          if (custId.isEmpty)
            continue; // Skip records without a valid card number

          // Prepare the data map for insert or update to avoid code repetition
          final String firstName = item['loy_cust_first_name'] ?? '';
          final String lastName = item['loy_cust_last_name'] ?? '';

          Map<String, dynamic> customerData = {
            'loy_custx_card_num': item['loy_cust_card_num'],
            'loy_custx_first_name': firstName,
            'loy_custx_last_name': lastName,
            'loy_custx_name': _getFormattedName(firstName, lastName),
            'loy_custx_email': item['loy_cust_email'],
            'loy_custx_address': item['loy_cust_primary_address'],
            'loy_custx_city': item['loy_cust_city'],
            'loy_custx_mobile': item['loy_cust_mobile'],
            'loy_custx_balance': item['loy_cust_balance'] ?? '0',
            'loy_custx_points': item['loy_cust_points'] ?? 0,
            'loy_custx_scheme': item['loy_cust_scheme'],
            'loy_custx_frozen': item['loy_cust_frozen'] ?? 0,
            'loy_custx_sync_frappe':
                'synchronized', // Mark as synced from remote
          };

          // Check if the customer already exists in the local database
          List<Map<String, dynamic>> existingRecords = await txn.query(
            'loy_custx',
            where: 'loy_custx_card_num = ?',
            whereArgs: [custId],
          );

          if (existingRecords.isNotEmpty) {
            // Record exists, check if an update is necessary by comparing hashes
            String newHash = _calculateHash(item); // Hash from fresh API data
            String existingHash =
                _calculateHash(existingRecords.first); // Hash from data in DB

            if (existingHash != newHash) {
              // Data has changed, so update the record
              await txn.update(
                'loy_custx',
                customerData,
                where: 'loy_custx_card_num = ?',
                whereArgs: [custId],
              );
            }
          } else {
            // Record does not exist, insert it as a new customer
            await txn.insert('loy_custx', customerData);
          }
        }

        // Identify local customer IDs that are missing from the remote server's response
        Set<String> missingCustIds = localCustIds.difference(remoteCustIds);

        // Handle customers that exist locally but not remotely
        for (String custId in missingCustIds) {
          var localItem = existingCust
              .firstWhere((item) => item['loy_custx_card_num'] == custId);

          // Only delete records that were previously synchronized from the server.
          // This preserves any new customers created locally that haven't been synced yet.
          if (localItem['loy_custx_sync_frappe'] == 'synchronized') {
            await txn.delete(
              'loy_custx',
              where: 'loy_custx_card_num = ?',
              whereArgs: [custId],
            );
          }
        }
      });

      logger.d('Loyalty customers database is up to date.');
    } catch (e, stackTrace) {
      logger.e('Error loading loyalty customer data: $e');
      logger.d(stackTrace);
    }
  }
// Future<void> _loadLoyCust({bool showSnackbar = false}) async {
//   if (mounted) {
//     setState(() {
//       _isLoadingLoyaltyData = true;
//     });
//   }

//   final ApiService apiGetLoyCust = ApiService(endpointPath: ApiRoutes.getLoyUsers);
//   final SqlLiteService dbHelper = SqlLiteService();
//   final db = await dbHelper.database;

//   try {
//     logger.d("Getting Loyalty customers from server...");

//     // 1. Fetch all existing local customers to compare against remote data
//     List<Map<String, dynamic>> existingCust = await db.query('loy_custx');

//     // 2. Fetch remote customers from the API
//     // Assuming fetchData() returns Map<String, dynamic> and the data is in the 'message' key
//     Map<String, dynamic> data = await apiGetLoyCust.fetchData();
//     List<dynamic> message = (data['message'] as List<dynamic>?) ?? [];

//     // 3. Get a set of remote and local customer IDs (using card number as the unique ID)
//     Set<String> remoteCustIds = message.map((item) => item['loy_cust_card_num'].toString()).toSet();
//     Set<String> localCustIds = existingCust.map((item) => item['loy_custx_card_num'].toString()).toSet();

//     await db.transaction((txn) async {
//       // Process each customer record received from the API
//       for (var item in message) {
//         String custId = item['loy_cust_card_num']?.toString() ?? '';
//         if (custId.isEmpty) continue;

//         // Prepare the data map for insert or update
//         final String firstName = item['loy_cust_first_name'] ?? '';
//         final String lastName = item['loy_cust_last_name'] ?? '';
//         final String remoteHash = _calculateHash(item as Map<String, dynamic>);

//         Map<String, dynamic> customerData = {
//           'loy_custx_card_num': item['loy_cust_card_num'],
//           'loy_custx_first_name': firstName,
//           'loy_custx_last_name': lastName,
//           'loy_custx_name': _getFormattedName(firstName, lastName),
//           'loy_custx_email': item['loy_cust_email'],
//           'loy_custx_address': item['loy_cust_primary_address'],
//           'loy_custx_city': item['loy_cust_city'],
//           'loy_custx_mobile': item['loy_cust_mobile'],
//           'loy_custx_balance': item['loy_cust_balance'] ?? '0',
//           'loy_custx_points': item['loy_cust_points'] ?? 0,
//           'loy_custx_scheme': item['loy_cust_scheme'],
//           'loy_custx_frozen': item['loy_cust_frozen'] ?? 0,
//           'loy_custx_sync_frappe': 'synchronized',
//           'loy_custx_hash': remoteHash, // Store the hash for future comparison
//         };

//         // Check if the customer already exists locally
//         List<Map<String, dynamic>> existingRecords = await txn.query(
//           'loy_custx',
//           columns: ['loy_custx_card_num', 'loy_custx_sync_frappe', 'loy_custx_hash'],
//           where: 'loy_custx_card_num = ?',
//           whereArgs: [custId],
//         );

//         if (existingRecords.isNotEmpty) {
//           final String? existingHash = existingRecords.first['loy_custx_hash'] as String?;

//           // Compare hashes to check if an update is necessary
//           if (existingHash != remoteHash) {
//             await txn.update(
//               'loy_custx',
//               customerData,
//               where: 'loy_custx_card_num = ?',
//               whereArgs: [custId],
//             );
//           }
//         } else {
//           // Record does not exist, insert it as a new customer
//           await txn.insert('loy_custx', customerData);
//         }
//       }

//       // 4. Identify and delete local records missing from the remote server
//       Set<String> missingCustIds = localCustIds.difference(remoteCustIds);

//       for (String custId in missingCustIds) {
//         var localItem = existingCust.firstWhere((item) => item['loy_custx_card_num'] == custId);

//         // Only delete records marked as 'synchronized'
//         if (localItem['loy_custx_sync_frappe'] == 'synchronized') {
//           await txn.delete(
//             'loy_custx',
//             where: 'loy_custx_card_num = ?',
//             whereArgs: [custId],
//           );
//         }
//       }
//     });

//     logger.d('Loyalty customers database is up to date.');

//     // 5. Read the finalized list from the database and update UI state
//     List<Map<String, dynamic>> finalizedCustomers = await db.query('loy_custx');
//     if (mounted) {
//       setState(() {
//         _allLoyaltyCustomers = finalizedCustomers;
//         // Re-filter the list based on the current search query
//         final String currentSearch = _searchController.text.toLowerCase();
//         _filteredLoyaltyCustomers = currentSearch.isEmpty
//             ? finalizedCustomers
//             : finalizedCustomers
//                 .where((c) =>
//                     (c['loy_custx_name'] ?? '').toLowerCase().contains(currentSearch) ||
//                     (c['loy_custx_card_num'] ?? '').toLowerCase().contains(currentSearch))
//                 .toList();
//         _isLoadingLoyaltyData = false;
//       });
//     }

//     if (showSnackbar && mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Loyalty customer list refreshed successfully.'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//     }
//   } catch (e, stackTrace) {
//     logger.e('Error loading loyalty customer data: $e');
//     logger.d(stackTrace);
//     if (mounted) {
//       setState(() {
//         _isLoadingLoyaltyData = false;
//       });
//     }
//     if (showSnackbar && mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Failed to refresh data. Error: $e'),
//             backgroundColor: Colors.red),
//       );
//     }
//   }
// }

  /// Helper function to combine first and last names into a full name.
// String _getFormattedName(String? firstName, String? lastName) {
//   final fName = firstName?.trim() ?? '';
//   final lName = lastName?.trim() ?? '';
//   if (fName.isNotEmpty && lName.isNotEmpty) {
//     return '$fName $lName';
//   }
//   return fName.isNotEmpty ? fName : lName;
// }
  String _getFormattedName(String firstName, String lastName) {
    // Placeholder implementation:
    return '$firstName $lastName'.trim();
  }

  /// Creates a consistent string representation (hash) of a customer's data.
  /// check if a customer's details have changed without
  /// comparing every single field.
// String _calculateHash(Map<String, dynamic> item) {
//   // Check for both API keys ('loy_cust_first_name') and DB keys ('loy_custx_first_name')
//   String firstName = item['loy_cust_first_name'] ?? item['loy_custx_first_name'] ?? '';
//   String lastName = item['loy_cust_last_name'] ?? item['loy_custx_last_name'] ?? '';
//   String email = item['loy_cust_email'] ?? item['loy_custx_email'] ?? '';
//   String address = item['loy_cust_primary_address'] ?? item['loy_custx_address'] ?? '';
//   String city = item['loy_cust_city'] ?? item['loy_custx_city'] ?? '';
//   String mobile = item['loy_cust_mobile'] ?? item['loy_custx_mobile'] ?? '';
//   String balance = (item['loy_cust_balance'] ?? item['loy_custx_balance'] ?? '0').toString();
//   String points = (item['loy_cust_points'] ?? item['loy_custx_points'] ?? 0).toString();
//   String scheme = item['loy_cust_scheme'] ?? item['loy_custx_scheme'] ?? '';
//   String frozen = (item['loy_cust_frozen'] ?? item['loy_custx_frozen'] ?? 0).toString();

//   // Concatenate all relevant fields into a single string
//   return '$firstName|$lastName|$email|$address|$city|$mobile|$balance|$points|$scheme|$frozen';
// }

  String _calculateHash(Map<String, dynamic> data) {
    // Placeholder: combine key fields into a string for comparison.
    // NOTE: This should be made more robust in production.
    return (data['loy_cust_first_name'] ?? '') +
        (data['loy_cust_last_name'] ?? '') +
        (data['loy_cust_balance'] ?? '0').toString() +
        (data['loy_cust_points'] ?? '0').toString();
  }

  Future<void> _initializeData() async {
    try {
      await _dbHelper.purgeSyncedSalesOlderThan(retentionDays: 7);
    } catch (e) {
      logger.w('Retention cleanup skipped: $e');
    }
    _loadItems();
    _loadOrderNum();
    await openCashStatus(context);
    _loadUserCode();
  }

  Future<String> _resolveSelectedVineyard() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('selectedStore') ?? '').trim();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? fallback;
  }

  void _showInfoSnackbar(
    String message, {
    Color backgroundColor = const Color.fromARGB(255, 38, 39, 48),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: const EdgeInsets.all(4.0),
        backgroundColor: backgroundColor,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<Map<String, dynamic>> _buildTourRegisterLines({
    required String vineyard,
    required int participantsCount,
    required List<dynamic> packageWines,
  }) async {
    final vineyardItems = await _marnisiApi.listItems(vineyard: vineyard);
    final byDocName = <String, Map<String, dynamic>>{};
    for (final row in vineyardItems) {
      final docName = (row['name'] ?? '').toString();
      if (docName.isNotEmpty) {
        byDocName[docName] = row;
      }
    }

    final lines = <Map<String, dynamic>>[];
    final missingItemRefs = <String>[];
    final apiBaseUrl = await _resolveApiBaseUrl();

    for (final wineRef in packageWines) {
      if (wineRef is! Map<String, dynamic>) continue;
      final vineyardItemRef = (wineRef['vineyard_item'] ?? '').toString();
      if (vineyardItemRef.isEmpty) continue;

      final itemRow = byDocName[vineyardItemRef];
      if (itemRow == null) {
        missingItemRefs.add(vineyardItemRef);
        continue;
      }

      final qty = TourRegisterHelper.resolveLineQty(
        participantsCount: participantsCount,
        tastingQtyPerGuest: wineRef['tasting_qty_per_guest'],
      );
      final netPrice = _toDouble(itemRow['sell_price']);
      final taxPct = 18.0;
      final itemCode = (itemRow['item_code'] ?? '').toString();
      if (itemCode.isEmpty) continue;
      final grossPrice = double.parse(
          (netPrice + (netPrice * taxPct / 100)).toStringAsFixed(2));

      lines.add({
        'item_img': MarnisiImageHelper.resolveItemImagePath(
          rawPath: (itemRow['image_path'] ?? '').toString(),
          apiBaseUrl: apiBaseUrl,
        ),
        'item_name': (itemRow['item_name'] ?? itemCode).toString(),
        'item_qty': qty,
        'item_unit': (itemRow['unit'] ?? 'Bottle').toString(),
        'item_price': grossPrice,
        'original_price': netPrice,
        'item_id': '$vineyard::$itemCode',
        'item_barcode': itemCode,
        'item_category': (itemRow['category'] ?? '').toString(),
        'item_tax_group': 'VAT',
        'item_tax_pct': taxPct,
        'box_color': const Color.fromARGB(255, 120, 102, 71),
        'item_supplementary': <Map<String, dynamic>>[],
      });
    }

    return {
      'lines': lines,
      'missing_item_refs': missingItemRefs,
    };
  }

  Future<bool> _loadTourIntoRegister({
    required String vineyard,
    required String bookingId,
    required String bookingNo,
  }) async {
    if (_order.balance > 0) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message:
            'Please finish the current transaction before loading a tour order.',
        showCancel: false,
      );
      return false;
    }

    if (orderItems.isNotEmpty) {
      final bool? confirmed = await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Replace Current Order',
        message:
            'Current cart items will be replaced by tour tasting items. Continue?',
        showCancel: true,
      );
      if (confirmed != true) {
        return false;
      }
    }

    final bookingData = await _marnisiApi.getBooking(bookingId: bookingId);
    final booking =
        (bookingData['booking'] as Map<String, dynamic>? ?? const {});
    final packageWines =
        (bookingData['package_wines'] as List<dynamic>? ?? const []);
    final participants = _toInt(booking['participants_count'], fallback: 1);
    final status = TourRegisterHelper.normalizeStatus(
      (booking['status'] ?? '').toString(),
    );

    if (status != 'CHECKED_IN') {
      _showInfoSnackbar(
        'Booking must be CHECKED_IN before loading into register.',
        backgroundColor: Colors.orange,
      );
      return false;
    }

    final payload = await _buildTourRegisterLines(
      vineyard: vineyard,
      participantsCount: participants,
      packageWines: packageWines,
    );
    final lines = (payload['lines'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final missing = (payload['missing_item_refs'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(growable: false);

    if (lines.isEmpty) {
      _showInfoSnackbar(
        'No package wines could be loaded for this booking.',
        backgroundColor: Colors.orange,
      );
      return false;
    }

    setState(() {
      _order.balance = 0;
      _order.payMthdsCache.clear();
      _order.paymentMethodId = '';
      _order.paymentMthdsTxnNames = '';
      _order.discount = 0;
      _order.discountPct = 0;
      _order.loyaltyPointsUsed = 0;
      _order.loyaltyPointsEarned = 0;
      _order.loyaltyPointsBalance = 0;
      _selectedCustomer = null;
      _client.clientName = '';
      _client.clientNum = '';
      _customerMobileController.clear();
      orderItems = List<Map<String, dynamic>>.from(lines);
      _order.lines = orderItems.length;
      _activeTourBookingId = bookingId;
      _activeTourBookingNo = bookingNo;
      updateValues();
    });

    if (missing.isNotEmpty) {
      _showInfoSnackbar(
        'Loaded tour items with ${missing.length} missing package references.',
        backgroundColor: Colors.orange,
      );
    } else {
      _showInfoSnackbar(
        'Tour $bookingNo loaded. You can edit quantities before billing.',
        backgroundColor: const Color.fromARGB(255, 27, 155, 20),
      );
    }

    return true;
  }

  Future<bool> _setBookingStatus({
    required String bookingId,
    required String status,
    String cancelReason = '',
  }) async {
    try {
      await _marnisiApi.updateBookingStatus(
        bookingId: bookingId,
        status: status,
        cancelReason: cancelReason,
      );
      return true;
    } catch (e) {
      _showInfoSnackbar(
        'Booking update failed: $e',
        backgroundColor: Colors.red,
      );
      return false;
    }
  }

  Future<bool> _startTourAndLoadToRegister({
    required String vineyard,
    required Map<String, dynamic> booking,
  }) async {
    final bookingId = (booking['name'] ?? '').toString();
    final bookingNo = (booking['booking_no'] ?? bookingId).toString();
    final currentStatus = TourRegisterHelper.normalizeStatus(
        (booking['status'] ?? '').toString());

    if (bookingId.isEmpty || !TourRegisterHelper.canStart(currentStatus)) {
      return false;
    }

    if (currentStatus == 'DRAFT') {
      final confirmed = await _setBookingStatus(
        bookingId: bookingId,
        status: 'CONFIRMED',
      );
      if (!confirmed) return false;
    }

    final checkedIn = await _setBookingStatus(
      bookingId: bookingId,
      status: 'CHECKED_IN',
    );
    if (!checkedIn) return false;

    await _loadItems();
    return _loadTourIntoRegister(
      vineyard: vineyard,
      bookingId: bookingId,
      bookingNo: bookingNo,
    );
  }

  Future<void> _openTourListDialog() async {
    final vineyard = await _resolveSelectedVineyard();
    if (vineyard.isEmpty) {
      _showInfoSnackbar(
        'Please select a vineyard/store first in Settings.',
        backgroundColor: Colors.orange,
      );
      return;
    }

    List<Map<String, dynamic>> bookings = const [];
    bool loading = true;
    String error = '';
    bool busy = false;

    Future<void> refresh(StateSetter setDialogState) async {
      setDialogState(() {
        loading = true;
        error = '';
      });
      try {
        final data = await _marnisiApi.listBookings(vineyard: vineyard);
        setDialogState(() {
          bookings = data;
        });
      } catch (e) {
        setDialogState(() {
          error = e.toString();
        });
      } finally {
        setDialogState(() {
          loading = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            if (loading && bookings.isEmpty && error.isEmpty) {
              unawaited(refresh(setDialogState));
            }

            Future<void> runAction(Future<void> Function() action) async {
              if (busy) return;
              setDialogState(() => busy = true);
              try {
                await action();
                if (dialogContext.mounted) {
                  await refresh(setDialogState);
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => busy = false);
                }
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Tour List')),
                  IconButton(
                    onPressed: (loading || busy)
                        ? null
                        : () => unawaited(refresh(setDialogState)),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              content: SizedBox(
                width: 980,
                height: 460,
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error.isNotEmpty
                        ? Center(child: Text(error))
                        : bookings.isEmpty
                            ? const Center(
                                child:
                                    Text('No bookings for selected vineyard.'),
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Booking')),
                                    DataColumn(label: Text('Guest')),
                                    DataColumn(label: Text('Participants')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: bookings.map((row) {
                                    final status =
                                        TourRegisterHelper.normalizeStatus(
                                            (row['status'] ?? '').toString());
                                    final bookingId =
                                        (row['name'] ?? '').toString();
                                    final bookingNo =
                                        (row['booking_no'] ?? bookingId)
                                            .toString();
                                    final actionWidgets = <Widget>[];

                                    void appendAction(Widget widget) {
                                      if (actionWidgets.isNotEmpty) {
                                        actionWidgets
                                            .add(const SizedBox(width: 8));
                                      }
                                      actionWidgets.add(widget);
                                    }

                                    final secondaryButtonStyle =
                                        OutlinedButton.styleFrom(
                                      minimumSize: const Size(102, 38),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );

                                    final primaryButtonStyle =
                                        FilledButton.styleFrom(
                                      minimumSize: const Size(120, 38),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    );

                                    if (status == 'DRAFT') {
                                      appendAction(
                                        OutlinedButton(
                                          style: secondaryButtonStyle,
                                          onPressed: busy
                                              ? null
                                              : () => unawaited(
                                                    runAction(() async {
                                                      await _setBookingStatus(
                                                        bookingId: bookingId,
                                                        status: 'CONFIRMED',
                                                      );
                                                    }),
                                                  ),
                                          child: const Text('Confirm'),
                                        ),
                                      );
                                    }

                                    if (TourRegisterHelper.canStart(status)) {
                                      appendAction(
                                        FilledButton(
                                          style: primaryButtonStyle,
                                          onPressed: busy
                                              ? null
                                              : () => unawaited(
                                                    runAction(() async {
                                                      final loaded =
                                                          await _startTourAndLoadToRegister(
                                                        vineyard: vineyard,
                                                        booking: row,
                                                      );
                                                      if (loaded &&
                                                          dialogContext
                                                              .mounted) {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                      }
                                                    }),
                                                  ),
                                          child: const Text('Start Tour'),
                                        ),
                                      );
                                    }

                                    if (status == 'CHECKED_IN') {
                                      appendAction(
                                        OutlinedButton(
                                          style: secondaryButtonStyle,
                                          onPressed: busy
                                              ? null
                                              : () => unawaited(
                                                    runAction(() async {
                                                      final loaded =
                                                          await _loadTourIntoRegister(
                                                        vineyard: vineyard,
                                                        bookingId: bookingId,
                                                        bookingNo: bookingNo,
                                                      );
                                                      if (loaded &&
                                                          dialogContext
                                                              .mounted) {
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop();
                                                      }
                                                    }),
                                                  ),
                                          child: const Text('Load'),
                                        ),
                                      );
                                    }

                                    if (TourRegisterHelper.canComplete(
                                        status)) {
                                      appendAction(
                                        OutlinedButton(
                                          style: secondaryButtonStyle,
                                          onPressed: busy
                                              ? null
                                              : () => unawaited(
                                                    runAction(() async {
                                                      final completed =
                                                          await _setBookingStatus(
                                                        bookingId: bookingId,
                                                        status: 'COMPLETED',
                                                      );
                                                      if (completed &&
                                                          _activeTourBookingId ==
                                                              bookingId) {
                                                        setState(() {
                                                          _activeTourBookingId =
                                                              '';
                                                          _activeTourBookingNo =
                                                              '';
                                                        });
                                                      }
                                                    }),
                                                  ),
                                          child: const Text('Complete'),
                                        ),
                                      );
                                    }

                                    if (status != 'COMPLETED' &&
                                        status != 'CANCELLED') {
                                      appendAction(
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFFF7B0B5),
                                            side: const BorderSide(
                                              color: Color(0xFF8D3A45),
                                            ),
                                            minimumSize: const Size(96, 38),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => unawaited(
                                                    runAction(() async {
                                                      await _setBookingStatus(
                                                        bookingId: bookingId,
                                                        status: 'CANCELLED',
                                                        cancelReason:
                                                            'Cancelled from register',
                                                      );
                                                    }),
                                                  ),
                                          child: const Text('Cancel'),
                                        ),
                                      );
                                    }

                                    return DataRow(
                                      cells: [
                                        DataCell(Text(bookingNo)),
                                        DataCell(Text((row['guest_name'] ?? '')
                                            .toString())),
                                        DataCell(Text(
                                            (row['participants_count'] ?? 0)
                                                .toString())),
                                        DataCell(Text(status)),
                                        DataCell(
                                          SizedBox(
                                            width: 360,
                                            child: actionWidgets.isEmpty
                                                ? const Text('-')
                                                : Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: actionWidgets,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(growable: false),
                                ),
                              ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      busy ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _hasCashPaymentInCurrentSale() {
    return _order.payMthdsCache.any((payment) {
      final payId = payment['pay_txn_id']?.toString() ?? '';
      final amount =
          double.tryParse(payment['pay_txn_amount']?.toString() ?? '0') ?? 0.0;
      return payId == '1' && amount > 0;
    });
  }

  void updateOrderItems(List<Map<String, dynamic>> newItems) {
    if (_order.balance > 0) {
      _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message:
            'Please finish the current transaction,for loading stored transactions',
        showCancel: false,
      );
      return;
    }
    setState(() {
      orderItems.clear();
      orderItems = newItems;
      _order.lines = orderItems.length;
      updateValues();
    });
  }

//************************************************** */
  //Select the customer
//************************************************** */
//Select the customer
  Future<void> _searchAndSetCustomer(String cardNumber) async {
    if (!_storeLoyaltyPolicy.canCaptureCustomer) {
      return;
    }

    // NEW: 1. Attempt to fetch customer details from the remote API first.
    final Map<String, dynamic>? remoteCustomer =
        await _fetchLoyaltyUserRemote(cardNumber);

    if (remoteCustomer != null) {
      // Remote customer found, set state with live data
      setState(() {
        // The assignment to _selectedCustomer is safe since it's inside the null check.
        _selectedCustomer = remoteCustomer;
        _client.clientName = remoteCustomer['loy_custx_name'];
        _client.clientNum = remoteCustomer['loy_custx_card_num'];
        _customerMobileController.clear();
        FocusScope.of(context).unfocus(); // Hide keyboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            padding: EdgeInsets.all(4.0),
            backgroundColor: Colors.green,
            content: Text(
                'Customer Selected: ${remoteCustomer['loy_custx_name']} - Points: ${remoteCustomer['loy_custx_points']}'),
            duration: const Duration(seconds: 3),
          ),
        );
      });
      return; // Exit function after successful remote fetch.
    }

    if (remoteCustomer == null) {
      setState(() {
        isOffline = true;
        logger.w("You are offline");
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          padding: EdgeInsets.all(4.0),
          backgroundColor: Colors.orange, // Indicate local data
          content: Text('Check Internet Connection'),
          duration: Duration(seconds: 3),
        ),
      );

      // Existing/Fallback Logic: 2. Search local database if remote fetch failed.
      final customer = await _dbHelper.getCustByCardNumber(cardNumber);

      if (customer != null) {
        setState(() {
          _selectedCustomer = customer;
          // Use the combined name from the database
          _client.clientName = customer['loy_custx_name'];
          // Use the card number as the customer identifier in the order
          _client.clientNum = customer['loy_custx_card_num'];
          _customerMobileController.clear();
          FocusScope.of(context).unfocus(); // Hide keyboard
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              padding: EdgeInsets.all(4.0),
              backgroundColor: Colors.orange, // Indicate local data
              content: Text(
                  'Customer Selected (Local/Cached): ${customer['loy_custx_name']}'),
              duration: const Duration(seconds: 3),
            ),
          );
        });
      } else {
        // Customer not found locally, show dialog to create a new one
        bool? customerCreated = await _dialogNewCustomer.showDialogBox(
          context: context,
          title: 'New Customer',
          mobileNumber: cardNumber, // Pass the entered number to the dialog
        );
        if (customerCreated == true) {
          // If customer was created successfully, search again to load them to the transaction
          _searchAndSetCustomer(cardNumber);
        }
      }
    }
  }
// Future<void> _searchAndSetCustomer(String cardNumber) async {
//     // if (cardNumber.trim().isEmpty) {
//     //   _dialogPayAndReturns.showDialogBox(
//     //     context: context,
//     //     title: 'Info',
//     //     message: 'Please enter a Loyalty Card number.',
//     //     showCancel: false,
//     //   );
//     //   return;
//     // }

//     // CHANGE: We now call a new method to search by the card number column.
//     final customer = await _dbHelper.getCustByCardNumber(cardNumber);

//     if (customer != null) {
//       setState(() {
//         _selectedCustomer = customer;
//         // Use the combined name from the database
//         _client.clientName = customer['loy_custx_name'];
//         // Use the card number as the customer identifier in the order
//         _client.clientNum = customer['loy_custx_card_num'];
//         _customerMobileController.clear();
//         FocusScope.of(context).unfocus(); // Hide keyboard
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text('Customer Selected: ${customer['loy_custx_name']}'),
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       });
//     } else {
//       // Customer not found, show dialog to create a new one
//       bool? customerCreated = await _dialogNewCustomer.showDialogBox(
//         context: context,
//         title: 'New Customer',
//         mobileNumber: cardNumber, // Pass the entered number to the dialog
//       );
//       if (customerCreated == true) {
//         // If customer was created successfully, search again to load them to the transaction
//         _searchAndSetCustomer(cardNumber);
//       }
//     }
//   }

// Helper function to fetch loyalty user data from the remote server
// Place this function inside the _PosSystemState class, for example, after _calculateHash.
  Future<Map<String, dynamic>?> _fetchLoyaltyUserRemote(
      String cardNumber) async {
    // 1. Define the API endpoint path.
    final ApiService apiService =
        ApiService(endpointPath: ApiRoutes.getLoyUsersByCardNum);

    // 2. Prepare the double-encoded request body as per the API documentation:
    // { "args": "{\"loy_cust_card_num\":\"[cardNumber]\"}" }
    // NOTE: This uses string construction to avoid requiring a separate import for 'dart:convert',
    // assuming ApiService handles the final JSON encoding of the Map payload.
    final Map<String, dynamic> requestBody = {
      "loy_cust_card_num": cardNumber,
    };

    logger.d("Attempting remote fetch for loyalty card: $cardNumber");

    try {
      // Assuming ApiService has a method (e.g., postData) for sending a custom POST payload
      // and returning the full JSON response body as a Map.
      // Replace 'postData' with the actual generic POST method of your ApiService if different.
      final Map<String, dynamic>? response =
          await apiService.postData([requestBody], (msg) => logger.d(msg));

      if (response == null) {
        logger.w('Remote API returned null response for card: $cardNumber');
        return null;
      }

      // 3. Check for the success status and the 'user' object in the response.
      if (response['status'] == 'success' && response['user'] != null) {
        log("Response: $response");

        final Map<String, dynamic> remoteUser = response['user'];

        logger
            .d('Remote loyalty user found: ${remoteUser['loy_cust_card_num']}');

        final String firstName = remoteUser['loy_cust_first_name'] ?? '';
        final String lastName = remoteUser['loy_cust_last_name'] ?? '';

        return {
          'loy_custx_card_num': remoteUser['loy_cust_card_num'],
          'loy_custx_first_name': firstName,
          'loy_custx_last_name': lastName,
          'loy_custx_name':
              _getFormattedName(firstName, lastName), // Use existing helper
          'loy_custx_email': remoteUser['loy_cust_email'],
          'loy_custx_address': remoteUser['loy_cust_primary_address'],
          'loy_custx_city': remoteUser['loy_cust_city'],
          'loy_custx_mobile': remoteUser['loy_cust_mobile'],
          // Cast numerical/balance fields safely
          'loy_custx_balance':
              remoteUser['loy_cust_balance']?.toString() ?? '0',
          'loy_custx_points': remoteUser['loy_cust_points'] ?? 0,
          'loy_custx_scheme': remoteUser['loy_cust_scheme'],
          'loy_custx_frozen': remoteUser['loy_cust_frozen'] ?? 0,
          // The existing code has a synchronization flag that can be added here
          'loy_custx_sync_frappe': 'synchronized',
        };
      } else {
        logger.w(
            'Remote loyalty user not found or API returned an error status for card: $cardNumber');
        return null;
      }
    } catch (e) {
      logger.e('Error fetching loyalty user from remote API: $e');
      // Return null on failure to trigger local database lookup/new customer dialog
      return null;
    }
  }

//************************************************** */
  /// check if the customer has been set
//************************************************* */

  bool _isCustomerSelected() {
    if (!_storeLoyaltyPolicy.canRedeem) {
      _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Info',
        message: 'Loyalty redemption is disabled for this store.',
        showCancel: false,
      );
      return false;
    }

    if (_client.clientNum == null || _client.clientNum!.trim().isEmpty) {
      _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Info',
        message: 'Please enter a Loyalty Card number.',
        showCancel: false,
      );
      return false;
    }
    return true;
  }

//************************************************** */
  /// check if the initial amount of cash has been set
//************************************************* */

  Future<void> openCashStatus(BuildContext context) async {
    final cashManagementService = CashManagementHelper();
    final cashStatus = await cashManagementService.getOpenCashAmount();

    if (cashStatus == null || cashStatus == 0.0) {
      await _handleEmptyCashStatus(context);
    }
  }

  Future<void> _handleEmptyCashStatus(BuildContext context) async {
    final bool? confirmed = await _dialogPayAndReturns.showDialogBox(
      context: context,
      title: 'Alert',
      message:
          'Please set the default starting cash amount to register products',
    );

    if (confirmed == true && context.mounted) {
      GoRouter.of(context).go(RouteUri.home);
    }
  }

//********************* */
  ///  sqlflite methods
//******************* */
//read items from sqllite
  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedStore = (prefs.getString('selectedStore') ?? '').trim();
    var data = await _dbHelper.queryItemsByStore(selectedStore);
    final sessionCookie = await MarnisiImageHelper.readSessionCookie();

    if (mounted) {
      setState(() {
        _items = data;
        _sessionCookie = sessionCookie;
      });
    }

    try {
      await _refreshItemsCacheFromServer();
      data = await _dbHelper.queryItemsByStore(selectedStore);
      if (!mounted) return;
      setState(() {
        _items = data;
        _sessionCookie = sessionCookie;
      });
    } catch (e) {
      logger.w('Item refresh from server failed: $e');
    }
  }

  Future<void> _refreshItemsCacheFromServer() async {
    final apiHelperGetProducts =
        ApiService(endpointPath: ApiRoutes.getProducts);
    final db = await _dbHelper.database;
    final apiBaseUrl = await _resolveApiBaseUrl();

    final response = await apiHelperGetProducts.fetchData();
    final remoteItems = (response['message'] as List<dynamic>? ?? const []);

    final existingItems = await db.query('items', columns: ['item_id']);
    final existingIds =
        existingItems.map((item) => (item['item_id'] ?? '').toString()).toSet();

    await db.transaction((txn) async {
      final receivedIds = <String>{};

      for (final row in remoteItems) {
        if (row is! Map<String, dynamic>) continue;

        final itemId = (row['item_id'] ?? '').toString().trim();
        if (itemId.isEmpty) continue;
        receivedIds.add(itemId);

        final found = await txn.query(
          'items',
          where: 'item_id = ?',
          whereArgs: [itemId],
        );

        final payload = <String, dynamic>{
          'item_img': MarnisiImageHelper.resolveItemImagePath(
            rawPath: (row['item_img_path'] ?? '').toString(),
            apiBaseUrl: apiBaseUrl,
          ),
          'item_store': row['item_store'] ?? '',
          'item_brand': row['item_brand'] ?? '',
          'item_description': row['item_description'] ?? '',
          'item_barcode': row['item_barcode'] ?? itemId,
          'item_name': row['item_name'] ?? itemId,
          'item_qty': row['item_qty'] ?? 0,
          'item_price': row['item_price'] ?? 0,
          'item_category': row['item_category'] ?? '',
          'item_unit': row['item_unit'] ?? 'Bottle',
          'item_tax_group': row['item_tax_group'] ?? 'VAT',
          'item_tax_pct': row['item_tax_pct'] ?? 18.0,
        };

        if (found.isEmpty) {
          await txn.insert('items', {
            'item_id': itemId,
            ...payload,
          });
        } else {
          await txn.update(
            'items',
            payload,
            where: 'item_id = ?',
            whereArgs: [itemId],
          );
        }

        await txn.delete(
          'supp_items',
          where: 'supp_parent_id = ?',
          whereArgs: [itemId],
        );
      }

      for (final staleId in existingIds.difference(receivedIds)) {
        await txn.delete(
          'items',
          where: 'item_id = ?',
          whereArgs: [staleId],
        );
        await txn.delete(
          'supp_items',
          where: 'supp_parent_id = ?',
          whereArgs: [staleId],
        );
      }
    });
  }

  Future<String> _resolveApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(StorageKeys.apiBaseUrl) ??
            prefs.getString('apiBaseUrl') ??
            '')
        .trim();
  }

  // #################################
  //Handle Loyalty Redeem Button Press

  Future<void> _handleLoyaltyRedeem() async {
    if (!_storeLoyaltyPolicy.canRedeem) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Info',
        message: 'Loyalty redemption is disabled for this store.',
        showCancel: false,
      );
      return;
    }

    // 1. Check if customer is selected
    if (!_isCustomerSelected()) {
      // Dialog is shown inside _isCustomerSelected
      return;
    }

    // 2. Check for items
    if (orderItems.isEmpty) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Info',
        message: 'There are no items in the order',
        showCancel: false,
      );
      return;
    }

    // 3. Get values
    final double availablePoints = double.tryParse(
            _selectedCustomer?['loy_custx_points']?.toString() ?? '0') ??
        0;
    final double amountDue = _order.balance > 0 ? _order.balance : _order.total;
    //final double maxRedeemablePoints = (availablePoints < amountDue ? availablePoints : amountDue).floorToDouble(); // Use min
    final double maxRedeemablePoints = double.parse(
        (availablePoints < amountDue ? availablePoints : amountDue)
            .toStringAsFixed(2)); // Use min, and enforce two decimal precision

    // 4. Show redeem dialog
    final double? pointsToRedeem = await _dialogLoyaltyRedeem.showDialogBox(
      context: context,
      availablePoints: availablePoints,
      maxRedeemableAmount: maxRedeemablePoints,
    );

    // 5. Process redemption
    if (pointsToRedeem != null && pointsToRedeem > 0) {
      _order.paymentMethodId = '4';
      updateBalance(pointsToRedeem);

      // Append payment method name for receipt
      String paymentMethodName =
          await _dbHelper.getPayMthdName('4') ?? 'Loyalty Redeem';
      if (_order.paymentMthdsTxnNames.isNotEmpty) {
        _order.paymentMthdsTxnNames += ', ';
      }
      _order.paymentMthdsTxnNames += paymentMethodName;

      // 6. If payment is complete, trigger final sale logic
      if (_order.balance == 0) {
        await _triggerSaleCompletion();
      }
    }
  }

//   Future<void> _triggerSaleCompletion() async {
//   if (defaultPrinter == null || defaultPrinter!.isEmpty) {
//     // Logic to set default printer...
//   }

//   if (Platform.isWindows || Platform.isMacOS) {
//     printerManager = PrinterManagerInvoice(
//       showDialog: (title, message) async => false,
//     );
//   } else {
//     printerManager = null;
//     logger.w("Printer Manager skipped: Running on non-Windows platform (${Platform.operatingSystem}).");
//   }

//   // ✅ Wait for all payment methods to be registered before syncing
//   await Future.delayed(const Duration(milliseconds: 200));

//   // bool isSyncSuccessful = false;
//   // try {
//   //   isSyncSuccessful = await _syncSaleRealTime();
//   // } catch (e) {
//   //   logger.e('Critical error in sync process: $e');
//   //   isSyncSuccessful = false;
//   // }

//   // 1. Check if a loyalty customer is selected.
//   final String? clientNum = _client.clientNum;
//   final bool isCustomerSelected = clientNum != null && clientNum.trim().isNotEmpty;

//   bool isSyncSuccessful = false;

//   if (isCustomerSelected) {
//     // 2. If customer is selected, attempt real-time sync.
//     try {
//       isSyncSuccessful = await _syncSaleRealTime();
//     } catch (e) {
//       logger.e('Critical error in sync process: $e');
//       isSyncSuccessful = false;
//     }
//   } else {

//     // 3. If NO customer is selected, skip sync and force local save.
//     logger.i("No loyalty card selected. Skipping real-time sync, saving to local DB for later manual sync.");
//     isSyncSuccessful = false;
//   }
//   if (isSyncSuccessful) {
//     await TxnHelper.saveTxn(
//       txnReceiptNum: _order.orderNumber,
//       txnAmount: 0.0,
//       txnType: Event.printInv,
//       txnStatus: PostingStatus.pending,
//       txnLocalStatus: LocalEvent.pending,
//     );

//     if (printerManager != null) {
//   // 🔹 Generate full invoice preview
//   final fullReceiptContent =await printerManager!.generateInvoicePreview(
//     isCopyReceipt: '',
//     payMethod: _order.paymentMthdsTxnNames,
//     orderItems: orderItems,
//     subTotal: _order.subTotal,
//     tax: _order.tax,
//     total: _order.total - _order.discount,
//     discount: _order.discount,
//     orderNumber: _order.orderNumber,
//     vatNum: _client.vatNum,
//     clientNum: _client.clientNum,
//     employeeNum: _order.cashierCode,
//     clientName: _client.clientName,
//     loyaltyCardNum: _client.clientNum,
//     loyaltyPointsused: _order.loyaltyPointsUsed,
//     loyaltyRewardAmount: _order.loyaltyPointsEarned,
//   );

//   // 🔹 Log the full formatted invoice
//   logger.i('\n===== FULL INVOICE PREVIEW =====\n$fullReceiptContent\n===============================\n');

//   // 🖨 Print after preview log
//   printerManager!.printReceipt(
//     payMethod: _order.paymentMthdsTxnNames,
//     change: _order.change,
//     orderItems: orderItems,
//     subTotal: _order.subTotal,
//     tax: _order.tax,
//     total: _order.total - _order.discount,
//     discount: _order.discount,
//     orderNumber: _order.orderNumber,
//     vatNum: _client.vatNum,
//     clientNum: _client.clientNum,
//     employeeNum: _order.cashierCode,
//     clientName: _client.clientName,
//     loyaltyCardNum: _client.clientNum ?? "",
//     loyaltyPointsused: _order.loyaltyPointsUsed,
//     loyaltyRewardAmount: _order.loyaltyPointsEarned,
//   );
// }

//     if (printerManager != null) {
//       // Use the logger to output the receipt details in a readable format
//         log('--- RECEIPT CONTENT LOG (START) ---');
//         log('Order Number: ${_order.orderNumber}');
//         log('Cashier: ${_order.cashierCode}');
//         log('Client: ${_client.clientName ?? 'N/A'} (VAT: ${_client.vatNum ?? 'N/A'})');
//         log('-----------------------------------');

//         // Log individual items
//         for (var item in orderItems) {
//           logger.i('${item['item_name']} (Qty: ${item['item_qty']}) @ Price: ${item['item_price']}');
//         }

//         log('-----------------------------------');
//         log('SUBTOTAL: ${_order.subTotal.toStringAsFixed(2)}');
//         log('DISCOUNT: ${_order.discount.toStringAsFixed(2)}');
//         log('TAX (VAT): ${_order.tax.toStringAsFixed(2)}');
//         log('TOTAL DUE: ${(_order.total - _order.discount).toStringAsFixed(2)}');
//         log('-----------------------------------');
//         log('PAYMENT: ${_order.paymentMthdsTxnNames}');
//         log('CHANGE: ${_order.change.toStringAsFixed(2)}');
//         log('LOYALTY CARD NUMBER: ${_client.clientNum}');
//         log('LOYALTY POINTS USED: ${_order.loyaltyPointsUsed}');
//         log('LOYALTY REWARD AMOUNT: ${_order.loyaltyPointsEarned}');
//         log('--- RECEIPT CONTENT LOG (END) ---');

//       printerManager!.printReceipt(
//         payMethod: _order.paymentMthdsTxnNames,
//         change: _order.change,
//         orderItems: orderItems,
//         subTotal: _order.subTotal,
//         tax: _order.tax,
//         total: _order.total - _order.discount,
//         discount: _order.discount,
//         orderNumber: _order.orderNumber,
//         vatNum: _client.vatNum,
//         clientNum: _client.clientNum,
//         employeeNum: _order.cashierCode,
//         clientName: _client.clientName,
//         loyaltyCardNum: _client.clientNum ?? "",
//         loyaltyPointsused: _order.loyaltyPointsUsed,
//         loyaltyRewardAmount: _order.loyaltyPointsEarned,
//       );
//     } else {
//       logger.w('Skipping receipt print: Printer Manager not initialized on this platform.');
//     }

//     _order.paymentMthdsTxnNames = '';
//     setState(() {
//       _loadOrderNum();
//     });

//     _clearOrder('Message', 'Order Saved', saveTxn: false);
//   }

//   else {

//     // 🔁 Generate new order number BEFORE saving locally to prevent duplicate sales_num
//     setState(() {
//       _loadOrderNum();
//       logger.w("⚠ New Order Number generated before local save: ${_order.orderNumber}");
//     });
//     // 1. Save the sale data to the local database.
//     //await _saveSaleToLocalDb();
//      await _saveSaleItems(orderItems);
//       await _saveOrderData(SalesStatusConst.salesComplete);

//     // 2. Clear the order, showing a success message and saving a pending transaction (saveTxn: true).
//     await _clearOrder('Message', 'Order Saved', saveTxn: true);

//     logger.i('Sale saved to local DB. Pending manual synchronization on the dashboard.');
//   }
// }

  /// Revised _triggerSaleCompletion with improved logic flow
  Future<void> _triggerSaleCompletion() async {
    if (_isSaleProcessing) return;

    _setSaleProcessing(
      true,
      message: 'Syncing order with server...\nThis can take up to 8 seconds.',
    );

    final String saleNum = _order.orderNumber;
    try {
      if (defaultPrinter == null || defaultPrinter!.isEmpty) {
        // Logic to set default printer...
      }

      final previewPrinterManager = PrinterManagerInvoice(
        showDialog: (title, message) async => false,
      );
      printerManager = PrinterPlatformHelper.supportsNativePrinter()
          ? previewPrinterManager
          : null;
      if (printerManager == null) {
        logger.w(
          "Hardware printer skipped: Unsupported platform (${Platform.operatingSystem}). Receipt preview will still be logged.",
        );
      }

      // ✅ Wait for all payment methods to be registered before syncing
      await Future.delayed(const Duration(milliseconds: 200));
      final resolvedPayMethodDisplay = PaymentMethodDisplayHelper.resolveDisplayText(
        _order.payMthdsCache,
        fallback: _order.paymentMthdsTxnNames,
      );
      _order.paymentMthdsTxnNames = resolvedPayMethodDisplay;
      await PrinterDebugLogHelper.append(
        scope: 'SalesRegister._triggerSaleCompletion',
        message: 'Sale completion started',
        data: {
          'orderNumber': _order.orderNumber,
          'balance': _order.balance,
          'total': _order.total,
          'payMethods': resolvedPayMethodDisplay,
          'paymentsCache': _order.payMthdsCache,
        },
      );

      bool isSyncSuccessful = false;

      try {
        isSyncSuccessful = await _syncSaleRealTime(saleNum);
      } catch (e) {
        logger.e('Critical error in sync process: $e');
        isSyncSuccessful = false;
      }

      if (!isSyncSuccessful) {
        _setSaleProcessing(
          true,
          message: 'Server not reachable.\nSaving order locally...',
        );
      } else {
        _setSaleProcessing(
          true,
          message: 'Server synced.\nRecording sale and printing receipt...',
        );
      }

      final bool hasCashPayment = _hasCashPaymentInCurrentSale();
      final receiptTotals =
          SalesPricingCalculator.calculateOrderTotals(orderItems);
      final double changeForReceipt = SalesPricingCalculator.round2(
        _order.change > 0 ? _order.change : 0.0,
      );
      final double cashTenderedForReceipt =
          SalesHistoryHelper.cashTenderedFromLocalPayments(
        _order.payMthdsCache,
        change: changeForReceipt,
      );
      final String localSyncStatus = isSyncSuccessful ? 'synchronized' : '';

      // 1️⃣ Record sale locally first.
      await _saveOrderData(
        SalesStatusConst.salesComplete,
        saleNum,
        syncStatus: localSyncStatus,
      );

      // 2️⃣ Persist sale items with the same sale number.
      await _saveSaleItems(orderItems, saleNum);

      await TxnHelper.saveTxn(
        txnReceiptNum: saleNum,
        txnAmount: 0.0,
        txnType: Event.printInv,
        txnStatus: PostingStatus.pending,
        txnLocalStatus: LocalEvent.pending,
      );

      _setSaleProcessing(
        true,
        message: 'Sale recorded.\nPrinting receipt...',
      );

      // 🔹 Generate full invoice preview (always, including Android/tablet)
      final fullReceiptContent =
          await previewPrinterManager.generateInvoicePreview(
        isCopyReceipt: '',
        payMethod: resolvedPayMethodDisplay,
        change: changeForReceipt,
        cashTendered: cashTenderedForReceipt,
        orderItems: orderItems,
        subTotal: _order.subTotal,
        tax: _order.tax,
        total: _order.total,
        discount: _order.discount,
        orderNumber: saleNum,
        vatNum: _client.vatNum,
        clientNum: _client.clientNum,
        employeeNum: _order.cashierCode,
        clientName: _client.clientName,
        loyaltyCardNum: _client.clientNum,
        loyaltyPointsused: _order.loyaltyPointsUsed,
        loyaltyRewardAmount: _order.loyaltyPointsEarned,
        loyaltyPointsBalance: _order.loyaltyPointsBalance,
        showLoyaltyDetails: _storeLoyaltyPolicy.shouldShowLoyaltyOnReceipt &&
            _saleHasLoyaltyData(),
      );

      logger.i(
        '\n===== FULL INVOICE PREVIEW =====\n$fullReceiptContent\n===============================\n',
      );

      if (PrinterPlatformHelper.canUsePrinterManager(printerManager)) {
        // 🖨 PRINT ONCE — THIS IS THE ONLY PRINT
        await printerManager!.printReceipt(
          payMethod: resolvedPayMethodDisplay,
          change: changeForReceipt,
          cashTendered: cashTenderedForReceipt,
          orderItems: orderItems,
          subTotal: receiptTotals.subTotalAfterDiscount,
          tax: receiptTotals.taxAfterDiscount,
          total: _order.total,
          discount: _order.discount,
          orderNumber: saleNum,
          vatNum: _client.vatNum,
          clientNum: _client.clientNum,
          employeeNum: _order.cashierCode,
          clientName: _client.clientName,
          loyaltyCardNum: _client.clientNum ?? "",
          loyaltyPointsused: _order.loyaltyPointsUsed,
          loyaltyRewardAmount: _order.loyaltyPointsEarned,
          loyaltyPointsBalance: _order.loyaltyPointsBalance,
          showLoyaltyDetails: _storeLoyaltyPolicy.shouldShowLoyaltyOnReceipt &&
              _saleHasLoyaltyData(),
        );

        if (hasCashPayment) {
          await printerManager!.openCashDrawer();
        }
      } else {
        logger.w('Hardware printing skipped; preview logged to console.');
      }

      if (hasCashPayment && changeForReceipt > 0) {
        _showRecentChange(
          change: changeForReceipt,
          cashTendered: cashTenderedForReceipt,
        );
      }
      _order.paymentMthdsTxnNames = '';

      await _clearOrder('Message', 'Order Saved',
          saveTxn: !isSyncSuccessful, showMessage: false);

      setState(() {
        _loadOrderNum();
      });

      if (!isSyncSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Order Saved Locally'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _setSaleProcessing(false);
    }
  }

// Future<void> _triggerSaleCompletion() async {
//   if (defaultPrinter == null || defaultPrinter!.isEmpty) {
//     // Logic to set default printer...
//   }

//   if (Platform.isWindows || Platform.isMacOS) {
//     printerManager = PrinterManagerInvoice(
//       showDialog: (title, message) async => false,
//     );
//   } else {
//     printerManager = null;
//     logger.w("Printer Manager skipped: Running on non-Windows platform (${Platform.operatingSystem}).");
//   }

//   await Future.delayed(const Duration(milliseconds: 200));

//   final String? clientNum = _client.clientNum;
//   final bool isCustomerSelected = clientNum != null && clientNum.trim().isNotEmpty;

//   bool isSyncSuccessful = false;

//   if (isCustomerSelected) {
//     try {
//       isSyncSuccessful = await _syncSaleRealTime();
//     } catch (e) {
//       logger.e('Critical error in sync process: $e');
//       isSyncSuccessful = false;
//     }
//   } else {
//     logger.i("No loyalty card selected. Skipping real-time sync, proceeding with local save.");
//   }

//   //  ALWAYS SAVE LOCALLY (already your behavior)
//   if (!isSyncSuccessful) {
//     setState(() {
//       _loadOrderNum();
//       logger.w("⚠ New Order Number generated before local save: ${_order.orderNumber}");
//     });

//     await _saveSaleItems(orderItems);
//     await _saveOrderData(SalesStatusConst.salesComplete);
//   }

//   // ======================================================
//   //  PRINT RECEIPT — ALWAYS
//   // ======================================================
//   if (printerManager != null) {
//     final fullReceiptContent = await printerManager!.generateInvoicePreview(
//       isCopyReceipt: '',
//       payMethod: _order.paymentMthdsTxnNames,
//       orderItems: orderItems,
//       subTotal: _order.subTotal,
//       tax: _order.tax,
//       total: _order.total - _order.discount,
//       discount: _order.discount,
//       orderNumber: _order.orderNumber,
//       vatNum: _client.vatNum,
//       clientNum: _client.clientNum,
//       employeeNum: _order.cashierCode,
//       clientName: _client.clientName,
//       loyaltyCardNum: _client.clientNum ?? '',
//       loyaltyPointsused: _order.loyaltyPointsUsed,
//       loyaltyRewardAmount: _order.loyaltyPointsEarned,
//     );

//     logger.i('\n===== FULL INVOICE PREVIEW =====\n$fullReceiptContent\n===============================\n');

//     printerManager!.printReceipt(
//       payMethod: _order.paymentMthdsTxnNames,
//       change: _order.change,
//       orderItems: orderItems,
//       subTotal: _order.subTotal,
//       tax: _order.tax,
//       total: _order.total - _order.discount,
//       discount: _order.discount,
//       orderNumber: _order.orderNumber,
//       vatNum: _client.vatNum,
//       clientNum: _client.clientNum,
//       employeeNum: _order.cashierCode,
//       clientName: _client.clientName,
//       loyaltyCardNum: _client.clientNum ?? '',
//       loyaltyPointsused: _order.loyaltyPointsUsed,
//       loyaltyRewardAmount: _order.loyaltyPointsEarned,
//     );
//   } else {
//     logger.w('Skipping receipt print: Printer Manager not initialized.');
//   }

//   _order.paymentMthdsTxnNames = '';
//   setState(() {
//     _loadOrderNum();
//   });

//  await _clearOrder('Message', 'Order Saved', saveTxn: !isSyncSuccessful, showMessage: false);

//         if(!isSyncSuccessful) {
//           ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       backgroundColor: Colors.green,
//                       content: Text('Order Saved Locally'),
//                       duration: Duration(seconds: 3),
//                     ),
//                   );
//         }
//         }

// #################################
  /// NEW: Real-Time Sale Sync to API (Returns Success/Failure)
// #################################

  Future<bool> _syncSaleRealTime(String saleNum) async {
    final prefs = await SharedPreferences.getInstance();

    // DEBUG STEP: Log the raw payment cache contents to see what is missing
    logger.d("Raw Pay Methods Cache: ${_order.payMthdsCache}");

    // 1. & 3. Calculate loyalty points used AND format Payment Methods simultaneously
    // We use a single loop to calculate loyalty points and correctly format all payment types.

    double loyaltyPointUsed = 0;
    List<Map<String, dynamic>> salePayMethods = [];

    for (var payment in _order.payMthdsCache) {
      String tenderTypeId = payment['pay_txn_id'].toString();
      // Safely parse the payment amount as a double
      double amount =
          double.tryParse(payment['pay_txn_amount'].toString()) ?? 0.0;
      String paymentName = payment['pay_txn_name'];

      // Check for Loyalty IDs ('4' or '14' as per the provided backend payload examples)
      // and accumulate the monetary value of points used for the top-level 'loy_points_used' field.
      if (_storeLoyaltyPolicy.canRedeem &&
          (tenderTypeId == '4' || tenderTypeId == '14')) {
        loyaltyPointUsed += amount;
      }

      // Create the base map for the payment method
      Map<String, dynamic> payMethodEntry = {
        "tender_type_id": tenderTypeId,
        "payment_name": paymentName,
        // FIX: Set amount_tendered to the numeric double for ALL payment types
        // (Cash, Card, Loyalty) to match the backend's desired cURL payload structure (e.g., "amount_tendered": 9).
        "amount_tendered": double.parse(amount.toStringAsFixed(2)),
      };

      salePayMethods.add(payMethodEntry);
    }

    // NEW DEBUG STEP: Log the formatted list to check against the successful cURL
    logger.d("Formatted Sale Pay Methods: $salePayMethods");
    logger.d("Calculated Loyalty Points Used: $loyaltyPointUsed");
    _order.loyaltyPointsUsed =
        double.parse(loyaltyPointUsed.toStringAsFixed(2));

    // 2. Format Items (Retaining your original item formatting logic)
    List<Map<String, dynamic>> saleItems = [];
    for (var item in orderItems) {
      final preparedItem = _prepareItemData(item, saleNum);
      saleItems.add({
        "si_sale_num": preparedItem['si_sale_num'],
        "si_id": preparedItem['si_id'],
        "si_name": preparedItem['si_name'],
        "si_unit": preparedItem['si_unit'],
        "si_barcode": preparedItem['si_barcode'],
        "si_category": preparedItem['si_category'],
        "si_qty": preparedItem['si_qty'],
        "si_price": preparedItem['si_price'],
        "si_tax_pct": preparedItem['si_tax_pct'],
        "si_subtotal": preparedItem['si_subtotal'],
        "si_tax": preparedItem['si_tax'],
        "si_total": preparedItem['si_total'],
        "si_discount_amount": preparedItem['si_discount'] ?? 0,
        "si_discount_percent": preparedItem['si_disc_pct'] ?? 0,
      });

      // Add supplementary items (Retaining your original logic)
      if (item['item_supplementary'] != null &&
          item['item_supplementary'] is List) {
        for (var supItem in item['item_supplementary']) {
          final preparedSupItem = _prepareSupplementaryData(supItem, saleNum);
          saleItems.add({
            "si_sale_num": preparedSupItem['si_sale_num'],
            "si_id": preparedSupItem['si_id'],
            "si_name": preparedSupItem['si_name'],
            "si_unit": preparedSupItem['si_unit'],
            "si_barcode": preparedSupItem['si_barcode'],
            "si_category": preparedSupItem['si_category'],
            "si_qty": preparedSupItem['si_qty'],
            "si_price": preparedSupItem['si_price'],
            "si_tax_pct": preparedSupItem['si_tax_pct'],
            "si_subtotal": preparedSupItem['si_subtotal'],
            "si_tax": preparedSupItem['si_tax'],
            "si_total": preparedSupItem['si_total'],
            "si_discount_amount": preparedSupItem['si_discount'] ?? 0,
            "si_discount_percent": preparedSupItem['si_disc_pct'] ?? 0,
          });
        }
      }
    }

    final receiptTotals =
        SalesPricingCalculator.calculateOrderTotals(orderItems);

    // 4. Construct main sale object
    Map<String, dynamic> saleData = {
      "sales_num": saleNum,
      "sale_id": _order.saleId,
      "sales_date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
      "sales_time": DateFormat('HH:mm:ss').format(DateTime.now()),
      // Ensure all main totals are correctly formatted as doubles (numerics)
      "sales_subtotal": double.parse(_order.subTotal.toStringAsFixed(2)),
      "sales_tax": double.parse(_order.tax.toStringAsFixed(2)),
      "sales_discounted_subtotal":
          double.parse(receiptTotals.subTotalAfterDiscount.toStringAsFixed(2)),
      "sales_discounted_tax":
          double.parse(receiptTotals.taxAfterDiscount.toStringAsFixed(2)),
      "sales_total": double.parse(_order.total.toStringAsFixed(2)),
      "sales_discount_amount": _order.discount,
      "sales_discount_percent": _order.discountPct,
      "sales_change": double.parse(_order.change.toStringAsFixed(2)),
      "sales_cash_tendered": _calculateCashTenderedAmount(),
      "sales_cashier": _order.cashierCode,
      "sales_store": prefs.getString('selectedStore'),
      "sales_registerId": prefs.getString('selectedRegister'),
      "items": saleItems,
      "sale_pay_methods": salePayMethods, // Contains ALL payments
    };

    // Conditionally add loyalty fields only if they exist/were used
    if ((_storeLoyaltyPolicy.canEarn || _storeLoyaltyPolicy.canRedeem) &&
        _client.clientNum != null &&
        _client.clientNum!.isNotEmpty) {
      //&& loyaltyPointUsed > 0) {
      saleData["loy_cust_card_num"] = _client.clientNum;
    }
    if (_storeLoyaltyPolicy.canRedeem && loyaltyPointUsed > 0) {
      // This value remains, correctly holding the monetary value of points used.
      saleData["loy_points_used"] =
          double.parse(loyaltyPointUsed.toStringAsFixed(2));
    }
    List<Map<String, dynamic>> salesListPayload = [saleData];

    // 5. Send data
    try {
      final ApiService apiSendData =
          ApiService(endpointPath: ApiRoutes.postProducts);

      logger.d("Sending real-time sale: ${salesListPayload.toString()}");

      // NOTE: This call relies on the fix previously applied to ApiService.sendData
      // to handle non-null confirmations on 200 status codes.
      List<dynamic>? confirmations =
          await apiSendData.sendData(salesListPayload, (message) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        }
      });

      if (confirmations != null) {
        logger.i("API Response (Confirmations List): $confirmations");
      }
      if (confirmations != null && confirmations.isNotEmpty) {
        final confirmation = confirmations.first;
        String salesNum = confirmation['sale_num'];
        String status = confirmation['status'];

        final mergedLoyalty = LoyaltyReceiptHelper.mergeWithConfirmation(
          confirmation: confirmation,
          currentUsed: _order.loyaltyPointsUsed,
          currentEarned: _order.loyaltyPointsEarned,
          currentBalance: _order.loyaltyPointsBalance,
        );
        final pointsUsed = mergedLoyalty.pointsUsed;
        final pointsEarned = mergedLoyalty.pointsEarned;
        final balancePoints = mergedLoyalty.pointsBalance;

        // Assign
        _order.loyaltyPointsUsed = double.parse(pointsUsed.toStringAsFixed(2));
        _order.loyaltyPointsEarned =
            double.parse(pointsEarned.toStringAsFixed(2));
        _order.loyaltyPointsBalance =
            double.parse(balancePoints.toStringAsFixed(2));

        // Optional logging of points info
        if (pointsUsed > 0 || pointsEarned > 0) {
          logger.i(
              "Loyalty Points Confirmed - Used: $pointsUsed, Earned: $pointsEarned");
        }

        // Build response text
        if (pointsUsed > 0 || pointsEarned > 0) {
          String pointsInfo = ' (Confirmed: ';
          if (pointsUsed > 0)
            pointsInfo += 'Used: ${pointsUsed.toStringAsFixed(2)} pts';
          if (pointsEarned > 0) {
            if (pointsUsed > 0) pointsInfo += ', ';
            pointsInfo += 'Earned: ${pointsEarned.toStringAsFixed(2)} pts';
          }
          pointsInfo += ')';
          // _order.paymentMthdsTxnNames += pointsInfo;
        }
        logger.d("Real-time sync confirmed for $salesNum with status $status");
        logger.d("Real-time sync API Response: $confirmations");
        return true;
      } else {
        logger.w(
            "Real-time sync failed or returned no confirmation. Response: $confirmations");
        return false;
      }
    } catch (e) {
      logger.e("Error during real-time sync: $e.");
      return false;
    }
  }

  // Future<bool> _syncSaleRealTime() async {
  //   final prefs = await SharedPreferences.getInstance();

  //   // 1. Format Payment Methods
  //   List<Map<String, dynamic>> salePayMethods =
  //       _order.payMthdsCache.map((payment) {
  //     return {
  //       "tender_type_id": payment['pay_txn_id'],
  //       "payment_name": payment['pay_txn_name'],
  //       "amount_tendered": payment['pay_txn_amount'],
  //     };
  //   }).toList();

  //   // 2. Format Items
  //   List<Map<String, dynamic>> saleItems = [];
  //   for (var item in orderItems) {
  //     final preparedItem = _prepareItemData(item, _order.orderNumber);
  //     saleItems.add({
  //       "si_sale_num": preparedItem['si_sale_num'],
  //       "si_id": preparedItem['si_id'],
  //       "si_name": preparedItem['si_name'],
  //       "si_unit": preparedItem['si_unit'],
  //       "si_barcode": preparedItem['si_barcode'],
  //       "si_category": preparedItem['si_category'],
  //       "si_qty": preparedItem['si_qty'],
  //       "si_price": preparedItem['si_price'], // price before tax
  //       "si_subtotal": preparedItem['si_subtotal'],
  //       "si_tax": preparedItem['si_tax'],
  //       "si_total": preparedItem['si_total'], // subtotal + tax
  //       "si_discount_amount": preparedItem['si_discount'] ?? 0,
  //       "si_discount_percent": preparedItem['si_disc_pct'] ?? 0,
  //     });

  //     // Add supplementary items
  //     if (item['item_supplementary'] != null &&
  //         item['item_supplementary'] is List) {
  //       for (var supItem in item['item_supplementary']) {
  //         final preparedSupItem =
  //             _prepareSupplementaryData(supItem, _order.orderNumber);
  //         saleItems.add({
  //           "si_sale_num": preparedSupItem['si_sale_num'],
  //           "si_id": preparedSupItem['si_id'],
  //           "si_name": preparedSupItem['si_name'],
  //           "si_unit": preparedSupItem['si_unit'],
  //           "si_barcode": preparedSupItem['si_barcode'],
  //           "si_category": preparedSupItem['si_category'],
  //           "si_qty": preparedSupItem['si_qty'],
  //           "si_price": preparedSupItem['si_price'],
  //           "si_subtotal": preparedSupItem['si_subtotal'],
  //           "si_tax": preparedSupItem['si_tax'],
  //           "si_total": preparedSupItem['si_total'],
  //           "si_discount_amount": preparedSupItem['si_discount'] ?? 0,
  //           "si_discount_percent": preparedSupItem['si_disc_pct'] ?? 0,
  //         });
  //       }
  //     }
  //   }

  //   // 3. Check for loyalty points used
  //   double loyaltyPointsUsed = 0;
  //   for (var payment in salePayMethods) {
  //     if (payment['tender_type_id'].toString() == '14') { // '14' is loyalty points ID
  // loyaltyPointsUsed += (payment['amount_tendered'] as double? ?? 0.0);
  // }
  //   }

  //   // 4. Construct main sale object
  //   Map<String, dynamic> saleData = {
  //     "sales_num": _order.orderNumber,
  //     "sale_id": _order.saleId,
  //     "sales_date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
  //     "sales_time": DateFormat('HH:mm:ss').format(DateTime.now()),
  //     "sales_subtotal": double.parse(_order.subTotal.toStringAsFixed(3)),
  //     "sales_tax": double.parse(_order.tax.toStringAsFixed(3)),
  //     "sales_total": double.parse((_order.total - _order.discount).toStringAsFixed(3)),
  //     "sales_discount_amount": _order.discount,
  //     "sales_discount_percent": _order.discountPct,
  //     "sales_cashier": _order.cashierCode,
  //     "sales_store": prefs.getString('selectedStore'),
  //     "sales_registerId": prefs.getString('selectedRegister'),
  //     "items": saleItems,
  //     "sale_pay_methods": salePayMethods,
  //   };

  //   if (_client.clientNum != null && _client.clientNum!.isNotEmpty) {
  //     saleData["loy_cust_card_num"] = _client.clientNum;
  //   }
  //   if (loyaltyPointsUsed > 0) {
  //     saleData["loy_points_used"] = loyaltyPointsUsed;
  //   }

  //   List<Map<String, dynamic>> salesListPayload = [saleData];

  //   // 5. Send data
  //   try {
  //     final ApiService apiSendData = ApiService(
  //         endpointPath: ApiRoutes.postProducts);
  //     logger.d("Sending real-time sale: ${salesListPayload.toString()}");

  //     List<dynamic>? confirmations =
  //         await apiSendData.sendData(salesListPayload, (message) {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context)
  //             .showSnackBar(SnackBar(content: Text(message)));
  //       }
  //     });

  //     if (confirmations != null && confirmations.isNotEmpty) {
  //       final confirmation = confirmations.first;
  //       String salesNum = confirmation['sale_num'];
  //       String status = confirmation['status'];

  //       // FIX 2: Extract loyalty points from confirmation and append to the
  //       // payment name string for visibility on the receipt/in logs.
  //       final double pointsUsed = (confirmation['loy_points_used'] as num? ?? 0.0).toDouble();
  //       final double pointsEarned = (confirmation['loy_points_earned'] as num? ?? 0.0).toDouble();

  //       if (pointsUsed > 0 || pointsEarned > 0) {
  //         String pointsInfo = ' (Confirmed: ';
  //         if (pointsUsed > 0) {
  //           pointsInfo += 'Used: ${pointsUsed.toStringAsFixed(0)} pts';
  //         }
  //         if (pointsEarned > 0) {
  //           if (pointsUsed > 0) pointsInfo += ', '; // Add separator if both exist
  //           pointsInfo += 'Earned: ${pointsEarned.toStringAsFixed(0)} pts';
  //         }
  //         pointsInfo += ')';
  //         _order.paymentMthdsTxnNames += pointsInfo;
  //       }

  //       logger.d("Real-time sync confirmed for $salesNum with status $status");
  //       return true; // <-- SUCCESS PATH 1
  //     } else {
  //       logger.w("Real-time sync failed or returned no confirmation.");
  //       return false; // <-- FAILURE PATH 1 (Empty/Bad response)
  //     }
  //   } catch (e) {
  //     logger.e("Error during real-time sync: $e.");
  //     return false; // <-- FAILURE PATH 2 (API Exception/Network Error)
  //   }

  // }

  //load payment methods
  Future<void> _loadPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString('selectedStore');

    if (storeId == null) {
      return;
    }
    List<String> paymentMethods =
        await _dbHelper.getAvailablePaymentMethods(storeId);

    setState(() {
      enabledPaymentMethods = paymentMethods;
    });
  }

//*********************** */
  /// Virtual numpad
//*********************** */
  //final TextEditingController _searchController = TextEditingController(text: "");
  String _searchTerm = '';

  //search values search box
  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text;
    });
  }

  void _onValueChanged(String value) {
    setState(() {
      _searchController.text += value;
      _onSearchChanged();
      _searchFocusNode.requestFocus();
    });
  }

  /// delete values search box
  void _onDelete() {
    setState(() {
      if (_searchController.text.isNotEmpty) {
        _searchController.text = _searchController.text
            .substring(0, _searchController.text.length - 1);
      } else {
        _searchTerm = '';
        _searchController.text = _searchTerm;
      }
      _searchFocusNode.requestFocus();
    });
  }

  /// clear values search box
  Future<void> _clearSearchBox() async {
    setState(() {
      _searchTerm = '';
      _searchController.text = _searchTerm;
      _searchFocusNode.requestFocus();
    });
  }

  void _onSearchSubmitted() {
    List<Map<String, dynamic>> filteredItems = _searchTerm.isEmpty
        ? []
        : _items
            .where((item) => item['item_barcode']!
                .toLowerCase()
                .contains(_searchTerm.toLowerCase()))
            .toList();

    if (filteredItems.isNotEmpty) {
      var item = filteredItems.first;
      _addItemToOrder(
        item['item_img']!,
        item['item_name']!,
        1,
        item['item_price']!,
        item['item_unit']!,
        item['item_id']!,
        item['item_barcode']!,
        item['item_category']!,
        item['item_tax_group']!,
        item['item_tax_pct']!,
      );
      _clearSearchBox();
      _searchFocusNode.requestFocus();
    } else {
      _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message: 'Item not found',
        showCancel: false,
      );
      _clearSearchBox();
      _searchFocusNode.requestFocus();
    }
  }

// ************************
  /// Receipt info
// **********************
  Future<void> _loadOrderNum() async {
    final prefs = await SharedPreferences.getInstance();
    final store = prefs.getString('selectedStore') ?? '';

    _order.prefix = (store.length >= 3)
        ? store.substring(store.length - 3)
        : 'DEF'; // 'DEF' como prefijo predeterminado

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _order.orderNumber =
        '${_order.prefix}-${timestamp.toString().padLeft(16, '0')}';

    logger.d('Generated order number: ${_order.orderNumber}');
  }

  Future<void> _loadUserCode() async {
    await Future.delayed(Duration.zero);
    if (mounted) {
      final userData = Provider.of<UserDataProvider>(context, listen: false);
      setState(() {
        _order.cashierCode = userData.userCode;
      });
    }
  }

// ********************************
  /// Process order
// ********************************
  Future<void> _loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      defaultPrinter = prefs.getString('selectedPrinter');
    });

    if (defaultPrinter == null || defaultPrinter!.isEmpty) {
      bool? confirmed = await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message: 'Item not found',
        showCancel: false,
      );

      if (confirmed == true && mounted) {
        GoRouter.of(context).go(RouteUri.generalSettings);
      }
    } else {
      printerManager = PrinterManagerInvoice(
        showDialog: (title, message,
            {showCancel = false, showTextField = false, isReturn = false}) {
          return _dialogPayAndReturns.showDialogBox(
            context: context,
            title: title,
            message: message,
            showCancel: showCancel,
            showTextField: showTextField,
            isReturn: isReturn,
          );
        },
        clearOrder: _clearOrder,
        onClear: _clearSearchBox,
      );
    }
  }

  ////
  void _handleOrder(String payMethod) async {
    await PrinterDebugLogHelper.append(
      scope: 'SalesRegister._handleOrder',
      message: 'Payment button tapped',
      data: {
        'payMethod': payMethod,
        'itemsCount': orderItems.length,
        'currentBalance': _order.balance,
        'orderTotal': _order.total,
      },
    );
    _order.paymentMethodId = payMethod;
    String paymentMethodName = await _dbHelper.getPayMthdName(payMethod) ?? '';
    double tempBalance = _order.balance;
    _clearSearchBox();

    void appendPaymentMethodName() {
      if (paymentMethodName.isEmpty) {
        return;
      }
      if (_order.paymentMthdsTxnNames.isNotEmpty) {
        _order.paymentMthdsTxnNames += ', ';
      }
      _order.paymentMthdsTxnNames += paymentMethodName;
      tempBalance = _order.balance;
    }

    try {
      if (orderItems.isEmpty) {
        await PrinterDebugLogHelper.append(
          scope: 'SalesRegister._handleOrder',
          message: 'Payment aborted because no items are in cart',
          data: {'payMethod': payMethod},
        );
        await _dialogPayAndReturns.showDialogBox(
          context: context,
          title: 'Info',
          message: 'There are no items in the order',
          showCancel: false,
        );
        return;
      } else {
        if (payMethod != '1') {
          await PrinterDebugLogHelper.append(
            scope: 'SalesRegister._handleOrder',
            message: 'Using non-cash direct payment path',
            data: {'payMethod': payMethod},
          );
          final pendingAmount = PaymentFlowHelper.resolvePendingAmount(
            totalPay: _order.total,
            balance: _order.balance,
          );

          if (pendingAmount.abs() < 0.01) {
            return;
          }

          final enteredAmount =
              pendingAmount < 0 ? pendingAmount.abs() : pendingAmount;

          updateBalance(
            enteredAmount,
            isReturn: pendingAmount < 0,
          );

          if (_order.balance != tempBalance) {
            appendPaymentMethodName();
          }

          if (_order.balance.abs() < 0.01) {
            _order.balance = 0;
            await PrinterDebugLogHelper.append(
              scope: 'SalesRegister._handleOrder',
              message: 'Balance zero after non-cash, triggering completion',
              data: {'payMethod': payMethod},
            );
            await _triggerSaleCompletion();
          } else {
            logger.i(
                "Partial payment recorded. Waiting for next payment method...");
          }
          return;
        }

        // bool? confirmed = await _dialogPayAndReturns.showDialogBox(
        //   context: context,
        //   title: 'Payment',
        //   message: 'Please add the amount to pay',
        //   showTextField: true,
        //   isReturn: false,
        //   isCash: _order.paymentMethodId == '1' ? true : false,
        //   updateBalance: updateBalance,
        //   getBalance: () => _order.balance,
        //   totalPay: _order.total - _order.discount,
        //   showCancel: true,
        //   onAdditionalInfoEntered: (clientName, vatNum) {
        //     _client.clientName = clientName;
        //     _client.vatNum = vatNum;
        //   },
        // );
        bool? confirmed = await _dialogPayAndReturns.showDialogBox(
          context: context,
          title: 'Payment',
          message: 'Please add the amount to pay',
          showTextField: true,
          isReturn: false,
          isCash: payMethod == '1' ? true : false, // Use local variable
          // WRAP THE CALLBACK TO FORCE THE ID
          updateBalance: (double amount, {bool isReturn = false}) {
            _order.paymentMethodId =
                payMethod; // Force ID to stay as '10' (or whatever was clicked)
            updateBalance(amount, isReturn: isReturn);
          },
          getBalance: () => _order.balance,
          getChange: () => _order.change,
          totalPay: _order.total,
          showCancel: true,
          onAdditionalInfoEntered: (clientName, vatNum) {
            _client.clientName = clientName;
            _client.vatNum = vatNum;
          },
        );
        if (confirmed != true) {
          await PrinterDebugLogHelper.append(
            scope: 'SalesRegister._handleOrder',
            message: 'Cash dialog cancelled',
            data: {'payMethod': payMethod},
          );
          return;
        }

        if (_order.balance != tempBalance) {
          appendPaymentMethodName();
        }

//         if (confirmed == true) {
// //           // if (defaultPrinter == null || defaultPrinter!.isEmpty) {
// //           //   await _dialogPayAndReturns.showDialogBox(
// //           //     context: context,
// //           //     title: 'Message',
// //           //     message: 'There is no default printer',
// //           //     showCancel: false,
// //           //   );

// //           //   if (mounted) {
// //           //     GoRouter.of(context).go(RouteUri.generalSettings);
// //           //   }
// //           //   return;
// //           // }

// //  if (defaultPrinter == null || defaultPrinter!.isEmpty) {
// //     setState(() {
// //       defaultPrinter = "Default Printer";
// //     });
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.setString('selectedPrinter', defaultPrinter!);

// //             // //  initialize with empty/dummy dialog if required
// //             // printerManager = PrinterManagerInvoice(
// //             //   showDialog: (title, message) async {
// //             //     // fallback: do nothing or log
// //             //     return false;
// //             //   },
// //             // );
// //             if (Platform.isWindows) {
// //             printerManager = PrinterManagerInvoice(
// //               showDialog: (title, message) async => false,
// //             );
// //           } else {
// //             // Provide a fake implementation so you don’t need null checks
// //             printerManager = PrinterManagerInvoice(
// //               showDialog: (title, message) async {
// //                 debugPrint("🖨️ Fake printer on non-Windows. Skipping print.");
// //                 return false;
// //               },
// //             );
// //           }
// //   }
// //           await _saveSaleItems(orderItems);
// //           await _saveOrderData(SalesStatusConst.salesComplete);
// //           await TxnHelper.saveTxn(
// //             txnReceiptNum: _order.orderNumber,
// //             txnAmount: 0.0,
// //             txnType: Event.printInv,
// //             txnStatus: PostingStatus.pending,
// //             txnLocalStatus: LocalEvent.pending,
// //           );

// //           printerManager!.printReceipt(
// //             payMethod: _order.paymentMthdsTxnNames,
// //             change: _order.change,
// //             orderItems: orderItems,
// //             subTotal: _order.subTotal,
// //             tax: _order.tax,
// //             total: _order.total - _order.discount,
// //             discount: _order.discount,
// //             orderNumber: _order.orderNumber,
// //             vatNum: _client.vatNum,
// //             clientNum: _client.clientNum,
// //             employeeNum: _order.cashierCode,
// //             clientName: _client.clientName,
// //           );

// //           _order.paymentMthdsTxnNames = '';

// //           setState(() {
// //             _loadOrderNum();
// //           });

// //       //using it on temporary basis to clear the cart after paying in cash
// //         _clearOrder('Message', 'Order Saved', saveTxn: true);
//       await _triggerSaleCompletion();
//         }

        // ✅ Only finalize the sale when the balance is fully paid
        if (_order.balance.abs() < 0.01) {
          _order.balance = 0; // normalize
          await PrinterDebugLogHelper.append(
            scope: 'SalesRegister._handleOrder',
            message: 'Balance zero after cash path, triggering completion',
            data: {'payMethod': payMethod},
          );
          await _triggerSaleCompletion();
        } else {
          // Allow adding more payment methods (e.g., Loyalty, Card, etc.)
          logger.i(
              "Partial payment recorded. Waiting for next payment method...");
        }
      }
    } catch (e) {
      await PrinterDebugLogHelper.append(
        scope: 'SalesRegister._handleOrder',
        message: 'Unhandled payment flow exception',
        data: {
          'payMethod': payMethod,
          'error': e.toString(),
        },
      );
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message: 'An error occurred: $e',
        showCancel: false,
      );
    }
  }

// #################################
  /// store pending sale
// #################################
  void _storePendingTxn() async {
    try {
      if (orderItems.isEmpty) {
        await _dialogPayAndReturns.showDialogBox(
          context: context,
          title: 'Message',
          message: 'There are no items in the order',
          showCancel: false,
        );
        return;
      } else {
        bool? confirmed = await _dialogPayAndReturns.showDialogBox(
          context: context,
          title: 'Message',
          message: 'Would you like save this transaction?',
          showCancel: true,
        );
        if (confirmed == true) {
          await _saveOrderData(
            SalesStatusConst.salesPending,
            _order.orderNumber,
          );
          await _saveSaleItems(orderItems, _order.orderNumber);
          await TxnHelper.saveTxn(
            txnReceiptNum: '',
            txnAmount: 0.0,
            txnType: Event.pendingTxn,
            txnStatus: PostingStatus.pending,
            txnLocalStatus: LocalEvent.pending,
          );

          setState(() {
            _loadOrderNum();
            _clearOrder('Message', 'Order Saved', saveTxn: true);
          });

          orderItems = [];
        } else {
          // Handle order cancellation
        }
      }
    } catch (e) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message: 'An error occurred: $e',
        showCancel: false,
      );
    }
  }

// ###########################
  /// save pending transaction
// ###########################
  Future<void> _saveOrderData(
    String txnStatus,
    String saleNum, {
    String syncStatus = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> sale = {
      'sales_num': saleNum,
      'sales_timeStamp':
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'sales_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'sales_time': DateFormat('HH:mm:ss').format(DateTime.now()),
      'sales_employee': _order.cashierCode,
      'sales_store_id': prefs.getString('selectedStore'),
      'sales_register_id': prefs.getString('selectedRegister'),
      'sales_subtotal': double.parse(_order.subTotal.toStringAsFixed(3)),
      'sales_tax': double.parse(_order.tax.toStringAsFixed(3)),
      'sales_total': double.parse(_order.total.toStringAsFixed(3)),
      'sales_discount': _order.discount,
      'sales_disc_pct': _order.discountPct,
      'sales_change': double.parse(_order.change.toStringAsFixed(3)),
      'sales_status': txnStatus,
      'sales_sync_frappe': syncStatus,
      //  if (_client.clientNum != null && _client.clientNum!.isNotEmpty)
      'loy_cust_card_num':
          (_storeLoyaltyPolicy.canEarn || _storeLoyaltyPolicy.canRedeem)
              ? _client.clientNum
              : '',
      'loy_points_used':
          _storeLoyaltyPolicy.canRedeem ? _order.loyaltyPointsUsed : 0.0,
      'loy_points_earned':
          _storeLoyaltyPolicy.canEarn ? _order.loyaltyPointsEarned : 0.0,
      'balance_points':
          (_storeLoyaltyPolicy.canEarn || _storeLoyaltyPolicy.canRedeem)
              ? _order.loyaltyPointsBalance
              : 0.0,
    };

    // ###########################
    /// Save the transaction
    // ###########################
    await TxnHelper.saveTxn(
      txnReceiptNum: saleNum,
      txnAmount: _order.total,
      txnType: Event.sales,
      txnStatus: PostingStatus.pending,
      txnLocalStatus: LocalEvent.pending,
    );

    await _dbHelper.saveSale(sale);

    logger.d('🧾 COMPLETE SALE DATA → '
        'sale=$sale, '
        'payments=${_order.payMthdsCache}');

// changes - 15 jan
    // for (var payment in _order.payMthdsCache) {
    //   await _dbHelper.savePaymentMthd(payment);
    // }
    for (var payment in _order.payMthdsCache) {
      await _dbHelper.savePaymentMthd({
        ...payment,
        'pay_txn_sale_num': _order.orderNumber,
      });
    }
  }

// ###########################
  /// save order items
// ##########################
  Future<void> _saveSaleItems(
    List<Map<String, dynamic>> orderItems,
    String saleNum,
  ) async {
    // final hasNegativeQty = orderItems.any((item) {
    //   final itemQty = int.tryParse(item['item_qty'].toString()) ?? 0;
    //   return itemQty < 0;
    // });

    // _order.orderNumber = '${_order.orderNumber}${hasNegativeQty ? 'R' : ''}';
    final hasNegativeQty = orderItems.any((item) {
      final qty = int.tryParse(item['item_qty'].toString()) ?? 0;
      return qty < 0;
    });

    // final saleNum =
    //     '${_order.orderNumber}${hasNegativeQty ? 'R' : ''}';

    // _order.orderNumber = saleNum;

    for (var item in orderItems) {
      try {
        //   final itemData = _prepareItemData(item, _order.orderNumber);
        final itemData = _prepareItemData(item, saleNum);

        // 🔥 ADD ASSERT HERE (DEBUG MODE ONLY)
        assert(
          _order.orderNumber == itemData['si_sale_num'],
          '❌ SALE & ITEM SALE NUM MISMATCH '
          '(sale=${_order.orderNumber}, item=${itemData['si_sale_num']})',
        );

        // 🔍 ALSO LOG (works in release too)
        logger.w(
          '🔎 ITEM SAVE → SALE=$saleNum, '
          'ITEM_SALE=${itemData['si_sale_num']}',
        );

        final result = await _dbHelper.saveItemsSale(itemData);
        logger.d(' PARENT ITEM INSERTED, rowId=$result');

        logger.d('🧾 save items sale $saleNum → $itemData');

        if (item['item_supplementary'] != null &&
            item['item_supplementary'] is List) {
          for (var supplementary in item['item_supplementary']) {
            //   final supplementaryData = _prepareSupplementaryData(supplementary, _order.orderNumber);
            final supplementaryData =
                _prepareSupplementaryData(supplementary, saleNum);

            // 🔥 SAME CHECK FOR SUPPLEMENTARY
            assert(
              _order.orderNumber == supplementaryData['si_sale_num'],
              '❌ SALE & SUPP ITEM SALE NUM MISMATCH '
              '(sale=${_order.orderNumber}, supp=${supplementaryData['si_sale_num']})',
            );

            logger.w(
              '🔎 SUPP SAVE → SALE=${_order.orderNumber}, '
              'ITEM_SALE=${supplementaryData['si_sale_num']}',
            );

            await _dbHelper.saveItemsSale(supplementaryData);

            logger.d(
                '🧾 save supplementary data ${_order.orderNumber} → $supplementaryData');
          }
        } else {
          logger.d(
              'No supplementary items found or the structure is invalid for item: ${item['item_name']}');
        }

        logger.d('🧾 SALE ITEMS FOR ${_order.orderNumber} → $orderItems');
      } catch (e) {
        logger.e('Failed to save item: ${item['item_name']}, error: $e');
      }
    }
  }

  Map<String, dynamic> _prepareItemData(
      Map<String, dynamic> item, String saleNum) {
    final itemPriceGross = SalesPricingCalculator.asDouble(item['item_price']);
    final itemQty = int.tryParse(item['item_qty'].toString()) ?? 0;
    final itemTaxPct = SalesPricingCalculator.asDouble(item['item_tax_pct']);
    final itemDiscount =
        SalesPricingCalculator.asDouble(item['item_disc_amount']);

    final lineTotals = SalesPricingCalculator.calculateMainLine(
      unitGrossPrice: itemPriceGross,
      qty: itemQty,
      taxPct: itemTaxPct,
      discountGross: itemDiscount,
    );

    final unitNetBeforeDiscount = itemTaxPct <= 0
        ? itemPriceGross
        : SalesPricingCalculator.round2(
            itemPriceGross / (1 + (itemTaxPct / 100)),
          );

    return {
      'si_sale_num': saleNum,
      'si_id': item['item_id'],
      'si_name': item['item_name'],
      'si_unit': item['item_unit'],
      'si_code': item['item_id'],
      'si_barcode': item['item_barcode'],
      'si_category': item['item_category'],
      'si_qty': itemQty,
      'si_price': unitNetBeforeDiscount,
      'si_tax_pct': itemTaxPct,
      'si_subtotal': lineTotals.netAfterDiscount,
      'si_tax': lineTotals.taxAfterDiscount,
      'si_total': lineTotals.grossAfterDiscount,
      'si_discount': lineTotals.discountGross,
      'si_disc_pct': item['item_disc_perct'] ?? 0.0,
    };
  }

  Map<String, dynamic> _prepareSupplementaryData(
      Map<String, dynamic> supplementary, String saleNum) {
    final supItemPrice = supplementary['sup_item_price'];
    final supItemQty = supplementary['sup_item_qty'];
    final subtotal = supItemPrice * supItemQty;

    return {
      'si_sale_num': saleNum,
      //  'si_id': supplementary['sup_item_id'],
      // Fix : first item disappear in print receipt
      'si_id': 'SUP_${supplementary['sup_item_id']}',
      'si_name': supplementary['sup_item_name'],
      'si_unit': supplementary['sup_item_unit'],
      // 'si_code': supplementary['sup_item_id'],
      // Fix : first item disappear in print receipt
      'si_code': 'SUP_${supplementary['sup_item_id']}',

      'si_barcode': supplementary['sup_item_barcode'],
      'si_category': supplementary['sup_item_category'],
      'si_qty': supItemQty,
      'si_price': supItemPrice,
      'si_tax_pct': supplementary['sup_item_tax_pct'],
      'si_subtotal': subtotal,
      'si_tax': 0.0,
      'si_total': subtotal,
      'si_discount': 0.0,
      'si_disc_pct': 0.0,
    };
  }

// ##################
  /// add items to order
// ##################
  Future<void> _addItemToOrder(
    String image,
    String name,
    int qty,
    double price,
    String unit,
    String code,
    String barcode,
    String category,
    String taxGroup,
    double taxPct,
  ) async {
    _order.paymentMthdsTxnNames = '';

    // Check if a transaction is in progress
    if (_order.balance > 0) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: 'Error',
        message:
            'It is not possible to add new items until you finish the current transaction. \nPlease cancel or finish the current transaction to add new items.',
        showCancel: false,
      );
      return;
    }

    // Get the supplementary item, if any
    Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(code);

    setState(() {
      // Add the main item
      orderItems.add({
        'item_img': image,
        'item_name': name,
        'item_qty': qty,
        'item_unit': unit,
        'item_price':
            double.parse((price + (price * taxPct / 100)).toStringAsFixed(2)),
        'original_price': double.parse(price.toString()),
        'item_id': code,
        'item_barcode': barcode,
        'item_category': category,
        'item_tax_group': taxGroup,
        'item_tax_pct': taxPct,
        'box_color': const Color.fromARGB(255, 120, 102, 71),
        'item_supplementary': [
          if (suppItem != null)
            {
              'sup_item_name': suppItem['supp_name'],
              'sup_item_qty': qty,
              'sup_item_unit': suppItem['supp_uom'],
              'sup_item_price': suppItem['supp_price'],
              'sup_item_id': suppItem['supp_id'],
              'sup_item_barcode': '',
              'sup_item_category': '',
              'sup_item_tax_group': "0%",
              'sup_item_tax_pct': suppItem['supp_tax_pct'],
              'box_color': const Color.fromARGB(255, 120, 102, 71),
            }
        ],
      });
      _order.lines++;
      // Update totals
      updateValues();
      logger.d(orderItems);
    });
  }

// #########################
  /// remove items from order
// ########################
  Future<void> _removeItemFromOrder(int originalIndex) async {
    _order.paymentMthdsTxnNames = '';
    logger.d('item seleccionado:$orderItems');
    String selectedItem = orderItems[originalIndex]['item_id'];
    int mainItemQty = orderItems[originalIndex]['item_qty'];
    logger.d('id_item: $selectedItem');
    logger.d('main item qty: $mainItemQty');

    Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(selectedItem);
    logger.d('all info supp_item: $suppItem');

    String? suppItemId = suppItem?['supp_id'];
    logger.d('id_suppItem: $suppItemId');

    var foundIndexSuppItem =
        orderItems.indexWhere((item) => item['item_id'] == suppItemId);

    if (foundIndexSuppItem != -1) {
      var foundItem = orderItems[foundIndexSuppItem];
      var itemSuppQty = foundItem['item_qty'];

      int newSuppItemQty = itemSuppQty - mainItemQty;

      if (newSuppItemQty <= 0) {
        orderItems.removeAt(foundIndexSuppItem);
        logger.d('SuppItem remove due the new qty is  0');
        _order.lines--;
      } else {
        orderItems[foundIndexSuppItem]['item_qty'] = newSuppItemQty;
        logger.d('supp item found in index: $foundIndexSuppItem');
        logger.d('New item quantity supp: $newSuppItemQty');
      }
    } else {
      logger.d('item not found');
    }

    var recalculatedIndex =
        orderItems.indexWhere((item) => item['item_id'] == selectedItem);

    if (recalculatedIndex != -1) {
      orderItems.removeAt(recalculatedIndex);
      logger.d('new item index: $recalculatedIndex');
    }

    setState(() {
      updateValues();
      _order.discount = _calculateDiscount();
      _order.lines--;
    });

    _searchFocusNode.requestFocus();
  }

// #########################
  /// Update quantity manually
// #########################
  void _updateQuantityAtIndex(int index, String newQty) async {
    setState(() {
      if (index >= 0 && index < orderItems.length) {
        int? parsedQty = int.tryParse(newQty);
        if (parsedQty != null) {
          final item = orderItems[index];
          String selectedItemId = item['item_id'];

          int oldQty = item['item_qty'];
          int qtyDifference = parsedQty - oldQty;

          // Update item quantity
          orderItems[index]['item_qty'] = parsedQty;

          // Update the supplementary items
          _updateSupplementaryItems(selectedItemId, qtyDifference);
        } else {
          _dialogPayAndReturns.showDialogBox(
            context: context,
            title: 'Error',
            message: 'Please enter a valid quantity....',
            showCancel: false,
          );
        }
      } else {
        _dialogPayAndReturns.showDialogBox(
          context: context,
          title: 'Error',
          message: 'Invalid Item',
          showCancel: false,
        );
      }

      // Update the total values
      updateValues();
    });
  }

  void _updateSupplementaryItems(
      String primaryItemId, int qtyDifference) async {
    // Get the related supplementary item
    Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(primaryItemId);
    String? suppItemId = suppItem?['supp_id'];

    if (suppItemId != null) {
      List<int> supplementaryIndexes = [];
      for (int i = 0; i < orderItems.length; i++) {
        if (orderItems[i]['item_id'] == suppItemId) {
          supplementaryIndexes.add(i);
        }
      }

      setState(() {
        for (int index in supplementaryIndexes) {
          orderItems[index]['item_qty'] += qtyDifference;
          logger.d(
              'Updated amount and color of supplementary item in index $index: ${orderItems[index]['item_qty']}');
        }
        updateValues();
      });
    }
  }

  // ###############
  /// update totals
  // ###############
  void updateValues() {
    final discountableGross = orderItems.fold<double>(
      0.0,
      (sum, item) => sum + SalesPricingCalculator.itemDiscountableGross(item),
    );
    _order.subTotal = _calculateSubTotal();
    _order.tax = _calculateTax();
    _order.total = _calculateTotal();
    _order.discount = _calculateDiscount();
    _order.discountPct = discountableGross <= 0
        ? 0.0
        : SalesPricingCalculator.round2(
            (_order.discount / discountableGross) * 100,
          );
    // if (_order.total == 0) {
    //   _clearOrder('Message', 'Order empty', saveTxn: true);
    // }
    _searchFocusNode.requestFocus();
  }

  // ###############
  /// clear order
  // ###############
  Future<void> _clearOrder(String title, dynamic message,
      {bool saveTxn = false, bool showMessage = false}) async {
    _order.balance = 0;
    _order.payMthdsCache.clear();
    if (orderItems.isEmpty) {
      await _dialogPayAndReturns.showDialogBox(
        context: context,
        title: title,
        message: 'There are no items',
        showCancel: false,
      );
      return;
    } else {
      setState(() {
        orderItems.clear();
        _order.subTotal = 0;
        _order.tax = 0;
        _order.total = 0;
        _order.change = 0;
        _order.lines = 0;
        _order.discount = 0;
        _order.discountPct = 0;
        _order.paymentMethodId = '';
        _order.paymentMthdsTxnNames = '';
        _order.loyaltyPointsUsed = 0;
        _order.loyaltyPointsEarned = 0;
        _order.loyaltyPointsBalance = 0;
        _activeTourBookingId = '';
        _activeTourBookingNo = '';
        // MODIFIED: Also clear selected customer
        _selectedCustomer = null;
        _client.clientName = '';
        _client.clientNum = '';
      });

      if (showMessage) {
        await _dialogPayAndReturns.showDialogBox(
          context: context,
          title: title,
          message: message,
          showCancel: false,
        );
      }
      _searchFocusNode.requestFocus();

      if (saveTxn) {
        await TxnHelper.saveTxn(
          txnReceiptNum: '',
          txnAmount: 0.0,
          txnType: Event.voided,
          txnStatus: PostingStatus.pending,
          txnLocalStatus: LocalEvent.pending,
        );
      }
    }
  }

  // #########################
  /// calculate the subtotal
  // #########################
  // double _calculateSubTotal() {
  //   double subTotal = 0.0;

  //   for (var item in orderItems) {
  //     // Calculate the subtotal of the main item
  //     double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
  //     int qty = item['item_qty'];
  //     subTotal += double.parse((price * qty).toStringAsFixed(2));

  //     // Calculate the subtotal of the complementary items (if any)
  //     final supplementaryData = item['item_supplementary'];
  //     if (supplementaryData != null) {
  //       if (supplementaryData is List) {
  //         for (var supItem in supplementaryData) {
  //           double supPrice = supItem['sup_item_price']! / (1 + (supItem['sup_item_tax_pct'] / 100));
  //           int supQty = supItem['sup_item_qty'];
  //           subTotal += double.parse((supPrice * supQty).toStringAsFixed(2));
  //         }
  //       } else if (supplementaryData is Map) {
  //         double supPrice = supplementaryData['sup_item_price']! / (1 + (supplementaryData['sup_item_tax_pct'] / 100));
  //         int supQty = supplementaryData['sup_item_qty'];
  //         subTotal += double.parse((supPrice * supQty).toStringAsFixed(2));
  //       }
  //     }
  //   }

  //   return subTotal;
  // }

//   double _calculateSubTotal() {
//   double itemsTotalWithoutTax = 0.0;
//   double refundableItemsTotal = 0.0;

//   for (var item in orderItems) {
//    // double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
//     int qty = item['item_qty'];

//     // Add discounted price only
//     double discount = item['item_disc_amount'] ?? 0.0;
//     itemsTotalWithoutTax += double.parse(((price * qty) - discount).toStringAsFixed(2));

//     // Add supplementary if refundable (no tax/discount on this)
//     final supplementaryData = item['item_supplementary'];
//     if (supplementaryData != null) {
//       if (supplementaryData is List) {
//         for (var supItem in supplementaryData) {
//           refundableItemsTotal += double.parse((supItem['sup_item_price'] * supItem['sup_item_qty']).toStringAsFixed(2));
//         }
//       } else if (supplementaryData is Map) {
//         refundableItemsTotal += double.parse(
//             (supplementaryData['sup_item_price'] * supplementaryData['sup_item_qty']).toStringAsFixed(2));
//       }
//     }
//   }

//   return double.parse((itemsTotalWithoutTax + refundableItemsTotal).toStringAsFixed(2));
// }

  double _calculateSubTotal() {
    return SalesPricingCalculator.calculateOrderTotals(orderItems).subTotal;
  }

  //##################
  /// calculate the tax
  //#################
  // double _calculateTax() {
  //   double totalTax = 0.0;
  //   for (var item in orderItems) {
  //     double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
  //     double taxPct = item['item_tax_pct']!;
  //     int qty = item['item_qty']!;
  //     totalTax += double.parse((((price * taxPct) * qty) / 100).toStringAsFixed(2));
  //   }

  //   return totalTax;
  // }
//   double _calculateTax() {
//   double totalTax = 0.0;

//   for (var item in orderItems) {
//     double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
//     double taxPct = item['item_tax_pct']!;
//     int qty = item['item_qty'];

//     double discount = item['item_disc_amount'] ?? 0.0;

//     // Apply tax ONLY on discounted price
//     double discountedPrice = (price * qty) - discount;
//     totalTax += double.parse(((discountedPrice * taxPct) / 100).toStringAsFixed(2));
//   }

//   return totalTax;
// }

  double _calculateTax() {
    return SalesPricingCalculator.calculateOrderTotals(orderItems).tax;
  }

  // ##############################
  /// calculate total items in order
  // ##############################
  // double _calculateTotal() {
  //   return _order.subTotal + _calculateTax();
  // }
  double _calculateTotal() {
    return SalesPricingCalculator.calculateOrderTotals(orderItems).total;
  }

  // ###################
  /// calculate discount
  //####################
  double _calculateDiscount() {
    return SalesPricingCalculator.calculateOrderTotals(orderItems).discount;
  }

  //########################################
  /// Manage the payment methods
  //########################################
  // Future<void> addPaymentMethod(String payMethod, double total, {bool isReturn = false}) async {
  //   String? paymentMethodName = await _dbHelper.getPayMthdName(payMethod);

  //   Map<String, dynamic> newPaymentMethod = {
  //     'pay_txn_sale_num': _order.orderNumber,
  //     'pay_txn_id': payMethod,
  //     'pay_txn_name': paymentMethodName,
  //     'pay_txn_amount': total,
  //   };

  //   _order.payMthdsCache.add(newPaymentMethod);

  // log("Add Payment Method: $newPaymentMethod");
  // }

  Future<void> addPaymentMethod(String payMethod, double total,
      {bool isReturn = false}) async {
    String? paymentMethodName = await _dbHelper.getPayMthdName(payMethod);

    Map<String, dynamic> newPaymentMethod = {
      'pay_txn_sale_num': _order.orderNumber,
      'pay_txn_id': payMethod,
      'pay_txn_name': paymentMethodName,
      'pay_txn_amount': total.toStringAsFixed(2)
    };

    // ✅ Append if not duplicate
    bool alreadyExists = _order.payMthdsCache.any((p) =>
        p['pay_txn_id'] == payMethod &&
        p['pay_txn_amount'] == total.toStringAsFixed(2) &&
        p['pay_txn_sale_num'] == _order.orderNumber);

    if (!alreadyExists) {
      _order.payMthdsCache.add(newPaymentMethod);
      log("Add Payment Method: $newPaymentMethod");
    } else {
      log("Payment Method already exists: $newPaymentMethod");
    }
  }

  double _calculateCashTenderedAmount() {
    return SalesHistoryHelper.cashTenderedFromLocalPayments(
      _order.payMthdsCache,
      change: _order.change,
    );
  }

  // ################################
  /// calculate balance pending to pay
  // ################################
  void updateBalance(double newPaidAmount, {bool isReturn = false}) {
    if (_order.paymentMethodId.trim().isEmpty) {
      return;
    }

    setState(() {
      final result = PaymentFlowHelper.applyPayment(
        orderTotal: _calculateTotal(),
        currentBalance: _order.balance,
        enteredAmount: newPaidAmount,
        paymentMethodId: _order.paymentMethodId,
      );

      _order.balance = result.newBalance;
      _order.change = result.change;

      addPaymentMethod(
        _order.paymentMethodId,
        result.paymentAmount,
        isReturn: result.paymentAmount < 0 || isReturn,
      );

      logger.d(
        'Balance: ${_order.balance}, Paid: $newPaidAmount, '
        'Payment: ${result.paymentAmount}, Change: ${_order.change}',
      );
    });
  }

// void updateBalance(double newPaidAmount, {bool isReturn = false}) {
//   // Initialize balance once
//   if (_order.balance == 0) {
//     _order.balance =
//         double.parse((_calculateTotal() - _order.discount).toStringAsFixed(2));
//   }

//   setState(() {
//     final double paid =
//         double.parse(newPaidAmount.toStringAsFixed(2));
//     final double pending =
//         double.parse(_order.balance.toStringAsFixed(2));

//     /// ✅ ONLY CASH CAN GIVE CHANGE
//     final bool canGiveChange = _order.paymentMethodId == '1';

//     if (paid >= pending) {
//       final double usedAmount = pending;

//       _order.change =
//           (canGiveChange && paid > pending) ? (paid - pending) : 0.0;

//       addPaymentMethod(
//         _order.paymentMethodId,
//         isReturn ? -usedAmount : usedAmount,
//         isReturn: isReturn,
//       );

//       _order.balance = 0;
//     } else {
//       // Partial payment
//       _order.balance = pending - paid;

//       addPaymentMethod(
//         _order.paymentMethodId,
//         isReturn ? -paid : paid,
//         isReturn: isReturn,
//       );

//       _order.change = 0.0;
//     }

//     logger.d(
//       'Payment=${_order.paymentMethodId}, '
//       'Paid=$paid, Pending=${_order.balance}, Change=${_order.change}',
//     );
//   });
// }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = context.read<UserDataProvider>();

    if (userDataProvider.isUserLoggedIn()) {
      return PortalMasterLayout(
        body: _content(context),
      );
    } else {
      return PublicMasterLayout(
        body: _content(context),
      );
    }
  }

  Widget _content(BuildContext context) {
    //set the search criterial
    final filteredItems = ItemSearchFilterHelper.filterSalesItems(
      items: _items,
      searchTerm: _searchTerm,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.maxHeight;
        final compactHeight =
            PosTabletLayoutHelper.isCompactHeight(viewportHeight);

        return Stack(
          children: [
            const Positioned.fill(
              child: MarnisiAppBackground(),
            ),
            SafeArea(
              top: false,
              bottom: true,
              minimum: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  // first row top header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6, //set the width
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 5, 0, 0),
                              child: TopTitle(
                                title: 'Items Available - ${_items.length}',
                                action:
                                    (const SizedBox.shrink()), //widget empty
                                showButtons: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      //
                      Expanded(
                        flex: 6, //set the width
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                              child: TopTitle(
                                title: _activeTourBookingNo.isEmpty
                                    ? 'Order # ${_order.orderNumber}'
                                    : 'Order # ${_order.orderNumber} | Tour: ${_activeTourBookingNo}',
                                subTitle: '',
                                action:
                                    (const SizedBox.shrink()), //widget empty
                                showButtons: true,
                                onReplyButtonPressed: _storePendingTxn,
                                onUpdateOrderItems: updateOrderItems,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // second row => items list | items order
                  //  items list
                  Expanded(
                    flex: PosTabletLayoutHelper.itemsSectionFlex(
                      compactHeight: compactHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4, //set the width
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;
                                final crossAxisCount = width >= 1300
                                    ? 4
                                    : width >= 960
                                        ? 3
                                        : 2;

                                return GridView.builder(
                                  itemCount: filteredItems.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: 0.82,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemBuilder: (_, index) {
                                    final item = filteredItems[index];
                                    return ItemTile(
                                      image: item['item_img']!,
                                      title: item['item_name']!,
                                      networkImageHeaders: MarnisiImageHelper
                                          .networkImageHeadersForPath(
                                        path:
                                            (item['item_img'] ?? '').toString(),
                                        sessionCookie: _sessionCookie,
                                      ),
                                      price: double.parse(
                                        ((item['item_price'] ?? 0) +
                                                ((item['item_price'] ?? 0) *
                                                        (item['item_tax_pct'] ??
                                                            0)) /
                                                    100)
                                            .toStringAsFixed(2),
                                      ),
                                      unit: item['item_unit'] ?? 'unit',
                                      code: item['item_id']!,
                                      onTap: () => _addItemToOrder(
                                          item['item_img']!,
                                          item['item_name']!,
                                          1,
                                          item['item_price']!,
                                          item['item_unit']!,
                                          item['item_id']!,
                                          item['item_barcode']!,
                                          item['item_category'] ?? '--',
                                          item['item_tax_group'] ?? '--',
                                          item['item_tax_pct']!),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          //item order
                          Expanded(
                            flex: 4, //set the width
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                              child: ListView.builder(
                                itemCount: orderItems.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final orderItem =
                                      orderItems[orderItems.length - 1 - index];
                                  return ItemOrder(
                                    index: index,
                                    data: orderItem,
                                    onRemove: () => _removeItemFromOrder(
                                        orderItems.length - 1 - index),
                                    onQtyChanged: (newQty) =>
                                        _updateQuantityAtIndex(
                                            orderItems.length - 1 - index,
                                            newQty),
                                    clearOrder: () => _clearOrder(
                                        'Alert', 'Order Cleared',
                                        saveTxn: true),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // const SizedBox(height: 1), // separator optional
                  //third row => keypad | options buttons | total box order
                  //keypad
                  Expanded(
                    flex: PosTabletLayoutHelper.toolsSectionFlex(
                      compactHeight: compactHeight,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2, //set the width
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 2.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color.fromARGB(255, 31, 32, 41),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final compactNumpad =
                                      constraints.maxHeight < 540;
                                  final searchBarHeight =
                                      PosTabletLayoutHelper.searchBarHeight(
                                    compactHeight: compactNumpad,
                                  );
                                  final quickActionBarHeight =
                                      PosTabletLayoutHelper
                                          .quickActionBarHeight(
                                    compactHeight: compactNumpad,
                                  );

                                  return Column(
                                    children: [
                                      SizedBox(
                                        height: searchBarHeight,
                                        child: SearchWidget(
                                          searchController: _searchController,
                                          searchFocusNode: _searchFocusNode,
                                          onChanged: (value) {
                                            setState(() {
                                              _searchTerm = value;
                                            });
                                          },
                                          onSubmitted: _onSearchSubmitted,
                                          hintText: 'Search Item',
                                        ),
                                      ),
                                      SizedBox(
                                        height: quickActionBarHeight,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextButton(
                                                onPressed: _clearSearchBox,
                                                child: const Text(
                                                  'CE',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: TextButton.icon(
                                                icon: const Icon(
                                                  Icons.arrow_back,
                                                  size: 14,
                                                ),
                                                label: const Text(''),
                                                onPressed: _onDelete,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Expanded(
                                        child: VirtualNumpad(
                                          controller: _searchController,
                                          focusNode: _searchFocusNode,
                                          onEnterPressed: _onSearchSubmitted,
                                          onValueChanged: _onValueChanged,
                                          compactMode: compactNumpad,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        //add new customer
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color.fromARGB(255, 31, 32, 41),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Centre vertically
                                crossAxisAlignment: CrossAxisAlignment
                                    .stretch, // expand the buttom
                                children: [
                                  if (!MarnisiPosRestrictions
                                      .hideTourListButton)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        backgroundColor: const Color.fromARGB(
                                            255, 25, 93, 128),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _openTourListDialog,
                                      child: const FittedBox(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.event_note_outlined),
                                            SizedBox(width: 6),
                                            Text('Tour List'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (!MarnisiPosRestrictions
                                          .hideTourListButton &&
                                      !MarnisiPosRestrictions
                                          .hideDiscountButton)
                                    const SizedBox(height: 5),
                                  if (!MarnisiPosRestrictions
                                      .hideDiscountButton)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 20),
                                        backgroundColor: const Color.fromARGB(
                                            255, 27, 155, 20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const FittedBox(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.discount),
                                            Text(' Discount'),
                                            SizedBox(width: 5),
                                          ],
                                        ),
                                      ),
                                      onPressed: () async {
                                        List<Map<String, dynamic>>?
                                            updatedItems = await showDialog<
                                                List<Map<String, dynamic>>>(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return DiscountDialog(
                                                title: 'Apply Discount',
                                                data: orderItems,
                                                showCancel: true,
                                                onApplyDiscount:
                                                    (double discountAmount,
                                                        double discountPct) {
                                                  setState(() {
                                                    _order.discount =
                                                        discountAmount;
                                                    _order.discountPct =
                                                        discountPct;
                                                  });
                                                });
                                          },
                                        );
                                        if (updatedItems != null) {
                                          setState(() {
                                            orderItems = updatedItems;
                                            updateValues();

                                            logger.d("items:");
                                            logger.d(orderItems);
                                            for (var item in orderItems) {
                                              logger.d(
                                                  '${item['item_name']}: ${item['item_disc_amount']}');
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  if (!MarnisiPosRestrictions
                                      .hideDiscountButton)
                                    const SizedBox(height: 5),

                                  if (_storeLoyaltyPolicy.canCaptureCustomer)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 50,
                                              child: TextField(
                                                controller:
                                                    _customerMobileController,
                                                keyboardType:
                                                    TextInputType.phone,
                                                style: const TextStyle(
                                                    color: Colors.white),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Loyalty Card Number',
                                                    labelStyle: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 12),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      borderSide:
                                                          const BorderSide(
                                                              color:
                                                                  Colors.white),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 8.0)),
                                                onSubmitted: (value) =>
                                                    _searchAndSetCustomer(
                                                        value),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 51, 53, 71),
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: IconButton(
                                              icon: const Icon(Icons.search,
                                                  color: Colors.white),
                                              onPressed: () =>
                                                  _searchAndSetCustomer(
                                                      _customerMobileController
                                                          .text),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 5), //separator
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 20),
                                      backgroundColor:
                                          const Color.fromARGB(255, 77, 7, 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (!PrinterPlatformHelper
                                              .supportsCashDrawer() ||
                                          printerManager == null) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Cash drawer is supported only on Windows printer setup.'),
                                          ),
                                        );
                                        return;
                                      }
                                      await printerManager!.openCashDrawer();
                                    },
                                    child: const FittedBox(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.open_in_browser),
                                          Text(' Open Drawer'),
                                          SizedBox(width: 5),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5), //separator
                                ],
                              ),
                            ),
                          ),
                        ),
                        //total box order
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color.fromARGB(255, 31, 32, 41),
                              ),
                              child: Column(
                                children: [
                                  // const Spacer(),
                                  // const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Lines: ${_order.lines.toString()}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 12),
                                      ),
                                      Text(
                                        'SUBTOTAL: € ${_order.subTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 224, 224, 11),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.transparent,
                                          padding: const EdgeInsets.fromLTRB(
                                              1, 1, 1, 1),
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const FittedBox(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                ' Payment History',
                                                style: TextStyle(
                                                    color: Colors.blue),
                                              ),
                                            ],
                                          ),
                                        ),
                                        onPressed: () async {
                                          logger.d(_order.payMthdsCache);
                                          if (_order.payMthdsCache.isNotEmpty) {
                                            await showDialog<
                                                List<Map<String, dynamic>>>(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return PaymentHDialog(
                                                  title: 'Payment History',
                                                  data: _order.payMthdsCache,
                                                  showCancel: true,
                                                );
                                              },
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'There are no payments.')),
                                            );
                                          }
                                        },
                                      ),
                                      Text(
                                        'TAX: € ${_order.tax.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 224, 224, 11),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    height: 1,
                                    width: double.infinity,
                                    color: Colors.white,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'DISC: €- ${_order.discount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 40, 231, 30),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        // 'AMOUNT DUE: € ${(_order.total - _order.discount < 0 ? 0 : (_order.total - _order.discount)).toStringAsFixed(2)}',
                                        'AMOUNT DUE: € ${_order.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 224, 224, 11),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),

                                  if (_recentPrintedChange > 0) ...[
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      height: 1,
                                      width: double.infinity,
                                      color: Colors.white,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'CASH: € ${_recentPrintedCashTendered.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 86, 207, 91),
                                            fontSize: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'CHANGE: € ${_recentPrintedChange.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 86, 207, 91),
                                            fontSize: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  if (double.parse(
                                          _order.balance.toStringAsFixed(2)) >
                                      0) ...[
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      height: 1,
                                      width: double.infinity,
                                      color: Colors.white,
                                    ),
                                    FadeTransition(
                                      opacity: _animation,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            'AMOUNT PENDING TO PAY: € ${_order.balance.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color.fromARGB(
                                                    255, 255, 0, 0),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    height: 1,
                                    width: double.infinity,
                                    color: Colors.white,
                                  ),
                                  // --- MODIFIED: Customer display is now dynamic ---
                                  // Row(
                                  //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  //   children: [
                                  //     Expanded(
                                  //       child: Text(
                                  //         'Customer: ${_selectedCustomer?['loy_custx_name'] ?? '--'}',
                                  //         style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
                                  //         overflow: TextOverflow.ellipsis,
                                  //       ),
                                  //     ),
                                  //     if (_selectedCustomer != null)
                                  //       SizedBox(
                                  //         height: 24,
                                  //         width: 24,
                                  //         child: IconButton(
                                  //           padding: EdgeInsets.zero,
                                  //           icon: const Icon(Icons.close, color: Colors.red, size: 16),
                                  //           onPressed: () {
                                  //             setState(() {
                                  //               _selectedCustomer = null;
                                  //               _client.clientName = '';
                                  //               _client.clientNum = '';
                                  //               _customerMobileController.clear();
                                  //             });
                                  //           },
                                  //         ),
                                  //       )
                                  //   ],
                                  // ),

                                  if (_storeLoyaltyPolicy.canCaptureCustomer)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  Colors.transparent,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      1, 1, 1, 1),
                                              backgroundColor:
                                                  Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: FittedBox(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Customer: ${_selectedCustomer?['loy_custx_name'] ?? '--'}',
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (_selectedCustomer != null)
                                                    IconButton(
                                                      padding: EdgeInsets.zero,
                                                      icon: const Icon(
                                                          Icons.close,
                                                          color: Colors.red,
                                                          size: 16),
                                                      onPressed: () {
                                                        setState(() {
                                                          _selectedCustomer =
                                                              null;
                                                          _client.clientName =
                                                              '';
                                                          _client.clientNum =
                                                              '';
                                                          _customerMobileController
                                                              .clear();
                                                        });
                                                      },
                                                    ),
                                                ],
                                              ),
                                            ),
                                            onPressed: () {
                                              // You can open a dialog with customer details
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_storeLoyaltyPolicy.canShowPointsSummary)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Balance Points: ${_selectedCustomer?['loy_custx_points'] ?? 0}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 10),
                                        ),
                                        Text(
                                          'Shopping Points: ${_selectedCustomer?['loy_custx_balance'] ?? 0}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  // ----------------------------------------------------
                                  // const Spacer(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const Spacer(), //optional
                  // bottom row =>  payment buttons | free space
                  SizedBox(
                    height: PosTabletLayoutHelper.bottomActionBarHeight(
                      compactHeight: compactHeight,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 10,
                          child: Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Evaluate if the payment method is enabled

                                if (MarnisiPosRestrictions.showPaymentMethod(
                                    '1'))
                                  PaymentButton(
                                    buttonText: 'Cash',
                                    buttonColor:
                                        const Color.fromARGB(255, 36, 87, 5),
                                    action: () {
                                      _handleOrder('1');
                                    },
                                  ),

                                PaymentButton(
                                  buttonText: 'Card\nBOV',
                                  buttonColor:
                                      const Color.fromARGB(255, 132, 3, 3),
                                  action: () {
                                    //  if (_isCustomerSelected()) {
                                    _handleOrder('7');
                                    //    }
                                  },
                                ),

                                if (enabledPaymentMethods.contains('2') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '2'))
                                  PaymentButton(
                                    buttonText: 'Cheque\nBOV',
                                    buttonColor:
                                        const Color.fromARGB(255, 4, 12, 125),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('2');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('8') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '8'))
                                  PaymentButton(
                                    buttonText: 'Other\nCheque',
                                    buttonColor:
                                        const Color.fromARGB(255, 4, 12, 125),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('8');
                                      //  }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('10') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '10'))
                                  PaymentButton(
                                    buttonText: 'Staff\nVoucher',
                                    buttonColor:
                                        const Color.fromARGB(255, 105, 110, 10),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('10');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('9') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '9'))
                                  PaymentButton(
                                    buttonText: 'Gift\nCard',
                                    buttonColor:
                                        const Color.fromARGB(255, 105, 110, 10),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('9');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('12') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '12'))
                                  PaymentButton(
                                    buttonText: 'Stripe',
                                    buttonColor:
                                        const Color.fromARGB(255, 13, 87, 123),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('12');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('3') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '3'))
                                  PaymentButton(
                                    buttonText: 'On\nAccount',
                                    buttonColor:
                                        const Color.fromARGB(255, 73, 5, 69),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('3');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('13') &&
                                    MarnisiPosRestrictions.showPaymentMethod(
                                        '13'))
                                  PaymentButton(
                                    buttonText: 'Bank\nTransfer',
                                    buttonColor:
                                        const Color.fromARGB(255, 7, 148, 117),
                                    action: () {
                                      //  if (_isCustomerSelected()) {
                                      _handleOrder('13');
                                      //    }
                                    },
                                  ),

                                if (enabledPaymentMethods.contains('4') &&
                                    _storeLoyaltyPolicy.canRedeem)
                                  PaymentButton(
                                      buttonText: 'Loyalty\nRedeem',
                                      buttonColor:
                                          const Color.fromARGB(255, 139, 62, 4),
                                      action: () {
                                        // () {}),
                                        if (_isCustomerSelected() &&
                                            isOffline == false) {
                                          _handleLoyaltyRedeem();
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              padding: EdgeInsets.all(4.0),
                                              backgroundColor: Colors
                                                  .orange, // Indicate local data
                                              content: Text(
                                                  "Can't accept loyalty payments while being offline, please select some other payment method”"),
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }),

                                // You can add more conditions here for other buttons if needed
                                PaymentButton(
                                    buttonText: 'Cancel',
                                    buttonColor:
                                        const Color.fromARGB(255, 223, 10, 10),
                                    action: () => _clearOrder(
                                        'Message', 'Order Cancel',
                                        saveTxn: true)),

                                // // You can add more conditions here for other buttons if needed
                                // PaymentButton(
                                //     buttonText: 'Cancel',
                                //     buttonColor: const Color.fromARGB(255, 223, 10, 10),
                                //     action: () => _clearOrder('Message', 'Order Cancel', saveTxn: true)),
                              ],
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 0,
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Column(
                              children: [],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSaleProcessing) _buildSaleProcessingOverlay(),
          ],
        );
      },
    );
  }

  Widget _buildSaleProcessingOverlay() {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 31, 32, 41),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _saleProcessingMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DialogLoyaltyRedeem {
  final TextEditingController _pointsController = TextEditingController();

  Future<double?> showDialogBox({
    required BuildContext context,
    required double availablePoints,
    required double maxRedeemableAmount,
  }) {
    _pointsController.clear();
    return showDialog<double?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Redeem Loyalty Points'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Points:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      availablePoints.toStringAsFixed(2),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Max Redemption Limit:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      '€${maxRedeemableAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter points to redeem',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(null); // Return null
              },
            ),
            ElevatedButton(
              child: const Text('OK'),
              onPressed: () {
                final double? enteredPoints =
                    double.tryParse(_pointsController.text);

                if (enteredPoints == null || enteredPoints <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        padding: EdgeInsets.all(4.0),
                        content: Text('Please enter a valid amount.'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                if (enteredPoints > availablePoints) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        padding: EdgeInsets.all(4.0),
                        content:
                            Text('Entered points exceed available points.'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                if (enteredPoints > maxRedeemableAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        padding: EdgeInsets.all(4.0),
                        content: Text(
                            'Entered points exceed max redemption limit for this sale.'),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                // Validation passed
                Navigator.of(dialogContext)
                    .pop(enteredPoints); // Return the amount
              },
            ),
          ],
        );
      },
    );
  }
}

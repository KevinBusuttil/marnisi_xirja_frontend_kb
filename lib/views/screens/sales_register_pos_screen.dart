// // ignore_for_file: use_build_context_synchronously
// // import 'package:web_admin/services/cash_managment_helper.dart';

// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:logger/logger.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:web_admin/api_endpoints/routes_api.dart';
// import 'package:web_admin/app_router.dart';
// import 'package:web_admin/constants/sales_status.dart';
// import 'package:web_admin/helpers/cash_managment_helper.dart';
// import 'package:web_admin/services/api_service.dart';
// import 'package:web_admin/views/components/dialog_add_customer.dart';
// import 'package:web_admin/views/components/dialog_loy_payment.dart';
// import 'package:web_admin/views/components/dialog_pay_returns.dart';
// import 'package:web_admin/models/cliente.dart';
// import 'package:web_admin/models/order.dart';
// import 'package:web_admin/services/database_service.dart';
// import 'package:web_admin/services/printer_invoice_service.dart';
// import 'package:web_admin/helpers/txn_helper.dart';
// import 'package:web_admin/views/components/dialog_discount.dart';
// import 'package:web_admin/views/components/dialog_paymenth.dart';
// import 'package:web_admin/views/widgets/sales_register_pos/item.dart';
// import 'package:web_admin/views/widgets/sales_register_pos/item_order.dart';
// import 'package:web_admin/views/widgets/sales_register_pos/payment_btn.dart';
// import 'package:web_admin/views/widgets/sales_register_pos/search_field.dart';
// import 'package:web_admin/views/components/top_title.dart';
// import 'package:web_admin/providers/user_data_provider.dart';
// import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
// import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
// import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';
// import 'package:web_admin/views/components/virtual_numpad.dart';


// class PosSystem extends StatefulWidget {
//   const PosSystem({super.key});

//   @override
//   State<PosSystem> createState() => _PosSystemState();
// }

// class _PosSystemState extends State<PosSystem> with SingleTickerProviderStateMixin {
//   final Order _order = Order();
//   final Client _client = Client();
//   final logger = Logger(printer: PrettyPrinter());
//   final FocusNode _searchFocusNode = FocusNode();
//   final _dbHelper = SqlLiteService();

//   // --- MODIFIED: Added state variables for customer selection ---
//   final TextEditingController _customerMobileController = TextEditingController();
//   Map<String, dynamic>? _selectedCustomer;
//   // -----------------------------------------------------------

//   bool? cashStatus;
//   String? defaultPrinter;
//   List<Map<String, dynamic>> _items = [];
//   List<Map<String, dynamic>> orderItems = [];

//   late final DialogPayAndReturns _dialogPayAndReturns;
//   late final DialogNewCustomer _dialogNewCustomer;
//   late final DialogLoyPayment _dialogLoyPayment;
//   late final DialogLoyaltyRedeem _dialogLoyaltyRedeem;
//   late AnimationController _controller;
//   late Animation<double> _animation;
//  // late PrinterManagerInvoice printerManager;
//  PrinterManagerInvoice? printerManager;
//   List<String> enabledPaymentMethods = [];
  

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//     _searchFocusNode.dispose();
//     _searchController.dispose();
//     _customerMobileController.dispose(); 
   
//   }

//   @override
//   void initState() {
//     super.initState();
//     _dialogPayAndReturns = DialogPayAndReturns();
//     _dialogNewCustomer = DialogNewCustomer();
//     _dialogLoyPayment = DialogLoyPayment();
//     _dialogLoyaltyRedeem = DialogLoyaltyRedeem();

//     /// controller to animate balance pending to pay
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 1000),
//       vsync: this,
//     )..forward();
//     //..repeat(reverse: true);

//     _animation = CurvedAnimation(
//       parent: _controller,
//       curve: Curves.easeInOut,
//     );
//     _searchFocusNode.requestFocus();
//     _initializeData();
//     _loadPaymentMethods();
//      initPrinterManager();
//      _loadLoyCust();
//   }

// void initPrinterManager() {
//   if (Platform.isWindows) {
//     printerManager = PrinterManagerInvoice(
//       showDialog: (title, message) async => false,
//     );
//   } else {
//     printerManager = null; // no attempt to load Windows DLLs
//     debugPrint("🖨️ Printer disabled on non-Windows platforms.");
//   }
// }

// //******************************** */
// //FETCH CUSTOMERS FROM FRAPPE
// //******************************** */

// Future<void> _loadLoyCust() async {
//   final ApiService apiGetLoyCust = ApiService(endpointPath: ApiRoutes.getLoyUsers);
//   final SqlLiteService dbHelper = SqlLiteService();
//   final db = await dbHelper.database;

//   try {
//     logger.d("Getting Loyalty customers from server...");

//     // Fetch all existing local customers to compare against remote data
//     List<Map<String, dynamic>> existingCust = await db.query('loy_custx');

//     // Fetch remote customers from the API
//     Map<String, dynamic> data = await apiGetLoyCust.fetchData();
//     List<dynamic> message = data['message'];

//     // Get a set of remote and local customer IDs (using card number as the unique ID)
//     Set<String> remoteCustIds = message.map((item) => item['loy_cust_card_num'].toString()).toSet();
//     Set<String> localCustIds = existingCust.map((item) => item['loy_custx_card_num'].toString()).toSet();

//     await db.transaction((txn) async {
//       // Process each customer record received from the API
//       for (var item in message) {
//         String custId = item['loy_cust_card_num']?.toString() ?? '';
//         if (custId.isEmpty) continue; // Skip records without a valid card number

//         // Prepare the data map for insert or update to avoid code repetition
//         final String firstName = item['loy_cust_first_name'] ?? '';
//         final String lastName = item['loy_cust_last_name'] ?? '';

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
//           'loy_custx_sync_frappe': 'synchronized', // Mark as synced from remote
//         };

//         // Check if the customer already exists in the local database
//         List<Map<String, dynamic>> existingRecords = await txn.query(
//           'loy_custx',
//           where: 'loy_custx_card_num = ?',
//           whereArgs: [custId],
//         );

//         if (existingRecords.isNotEmpty) {
//           // Record exists, check if an update is necessary by comparing hashes
//           String newHash = _calculateHash(item); // Hash from fresh API data
//           String existingHash = _calculateHash(existingRecords.first); // Hash from data in DB

//           if (existingHash != newHash) {
//             // Data has changed, so update the record
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

//       // Identify local customer IDs that are missing from the remote server's response
//       Set<String> missingCustIds = localCustIds.difference(remoteCustIds);

//       // Handle customers that exist locally but not remotely
//       for (String custId in missingCustIds) {
//         var localItem = existingCust.firstWhere((item) => item['loy_custx_card_num'] == custId);

//         // Only delete records that were previously synchronized from the server.
//         // This preserves any new customers created locally that haven't been synced yet.
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
//   } catch (e, stackTrace) {
//     logger.e('Error loading loyalty customer data: $e');
//     logger.d(stackTrace);
//   }
// }


// /// Helper function to combine first and last names into a full name.
// String _getFormattedName(String? firstName, String? lastName) {
//   final fName = firstName?.trim() ?? '';
//   final lName = lastName?.trim() ?? '';
//   if (fName.isNotEmpty && lName.isNotEmpty) {
//     return '$fName $lName';
//   }
//   return fName.isNotEmpty ? fName : lName;
// }

// /// Creates a consistent string representation (hash) of a customer's data.
// /// check if a customer's details have changed without
// /// comparing every single field.
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

//   Future<void> _initializeData() async {
//     _loadItems();
//     _loadOrderNum();
//       await openCashStatus(context);
//     _loadUserCode();
//   }

//   void updateOrderItems(List<Map<String, dynamic>> newItems) {
//     if (_order.balance > 0) {
//       _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message: 'Please finish the current transaction,for loading stored transactions',
//         showCancel: false,
//       );
//       return;
//     }
//     setState(() {
//       orderItems.clear();
//       orderItems = newItems;
//       _order.lines = orderItems.length;
//       updateValues();
//     });
//   }

// //Select the customer
// Future<void> _searchAndSetCustomer(String cardNumber) async {
//     if (cardNumber.trim().isEmpty) {
//       _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Info',
//         message: 'Please enter a Loyalty Card number.',
//         showCancel: false,
//       );
//       return;
//     }

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

// //************************************************** */
//   /// check if the customer has been set
// //************************************************* */

//   bool _isCustomerSelected() {
//     if (_client.clientNum == null || _client.clientNum!.trim().isEmpty) {
//       _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Info',
//         message: 'Please enter a Loyalty Card number.',
//         showCancel: false,
//       );
//       return false;
//     }
//     return true;
//   }

// //************************************************** */
//   /// check if the initial amount of cash has been set
// //************************************************* */

//   Future<void> openCashStatus(BuildContext context) async {
//     final cashManagementService = CashManagementHelper();
//     final cashStatus = await cashManagementService.getOpenCashAmount();

//     if (cashStatus == null || cashStatus == 0.0) {
//       await _handleEmptyCashStatus(context);
//     }
//   }

//   Future<void> _handleEmptyCashStatus(BuildContext context) async {
//     final bool? confirmed = await _dialogPayAndReturns.showDialogBox(
//       context: context,
//       title: 'Alert',
//       message: 'Please set the default starting cash amount to register products',
//     );

//     if (confirmed == true && context.mounted) {
//       GoRouter.of(context).go(RouteUri.home);
//     }
//   }

// //********************* */
//   ///  sqlflite methods
// //******************* */
// //read items from sqllite
//   void _loadItems() async {
//     final data = await _dbHelper.queryAllItems();
//     setState(() {
//       _items = data;
//     });
//   }


//   // #################################
//   //Handle Loyalty Redeem Button Press
  
//   Future<void> _handleLoyaltyRedeem() async {
//     // 1. Check if customer is selected
//     if (!_isCustomerSelected()) {
//       // Dialog is shown inside _isCustomerSelected
//       return;
//     }

//     // 2. Check for items
//     if (orderItems.isEmpty) {
//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Info',
//         message: 'There are no items in the order',
//         showCancel: false,
//       );
//       return;
//     }

//     // 3. Get values
//     final double availablePoints = double.tryParse(
//             _selectedCustomer?['loy_custx_points']?.toString() ?? '0') ??
//         0;
//     final double amountDue = _order.balance > 0
//         ? _order.balance
//         : (_order.total - _order.discount);
//     final double maxRedeemablePoints =
//         (availablePoints < amountDue ? availablePoints : amountDue).floorToDouble(); // Use min

//     // 4. Show redeem dialog
//     final double? pointsToRedeem = await _dialogLoyaltyRedeem.showDialogBox(
//       context: context,
//       availablePoints: availablePoints,
//       maxRedeemableAmount: maxRedeemablePoints,
//     );

//     // 5. Process redemption
//     if (pointsToRedeem != null && pointsToRedeem > 0) {
//       _order.paymentMethodId = '14'; 
//       updateBalance(pointsToRedeem);

//       // Append payment method name for receipt
//       String paymentMethodName =
//           await _dbHelper.getPayMthdName('4') ?? 'Loyalty Redeem';
//       if (_order.paymentMthdsTxnNames.isNotEmpty) {
//         _order.paymentMthdsTxnNames += ', ';
//       }
//       _order.paymentMthdsTxnNames += paymentMethodName;

//       // 6. If payment is complete, trigger final sale logic
//       if (_order.balance == 0) {
//         await _triggerSaleCompletion();
//       }
//     }
//   }
 

//   // Centralized Sale Completion Logic (Real-Time Only)
  
//   Future<void> _triggerSaleCompletion() async {
//     // 1. Initialize printerManager only if needed
//     if (defaultPrinter == null || defaultPrinter!.isEmpty) {
//       // Logic to set default printer...
//     }

//     // Set up the printer manager strictly based on the platform
//     if (Platform.isWindows) {
//         printerManager = PrinterManagerInvoice(
//             showDialog: (title, message) async => false,
//         );
//     } else {
//         // Explicitly set to null or a mock object for non-Windows platforms
//         // to avoid loading Windows-only dependencies.
//         printerManager = null; // Or use a reliable MockPrinterManager
//         logger.w("Printer Manager skipped: Running on non-Windows platform (${Platform.operatingSystem}).");
//     }

//     // 2. Attempt to sync sale to server in real-time
//     bool isSyncSuccessful = false;
//     try {
//       isSyncSuccessful = await _syncSaleRealTime();
//     } catch (e) {
//       logger.e('Critical error in sync process: $e');
//       isSyncSuccessful = false;
//     }

//     // 3. Process result
//     if (isSyncSuccessful) {
//       // --- SUCCESS PATH ---
//       // API call WORKED. Now we print and clear.

//       // 3a. Save print job transaction (Local log is fine)
//       await TxnHelper.saveTxn(
//         txnReceiptNum: _order.orderNumber,
//         txnAmount: 0.0,
//         txnType: Event.printInv,
//         txnStatus: PostingStatus.pending,
//         txnLocalStatus: LocalEvent.pending,
//       );

//       // 3b. Print receipt - CHECK FOR NULL/VALID MANAGER BEFORE CALLING
//       if (printerManager != null) { 
//           printerManager!.printReceipt(
//             payMethod: _order.paymentMthdsTxnNames,
//             change: _order.change,
//             orderItems: orderItems,
//             subTotal: _order.subTotal,
//             tax: _order.tax,
//             total: _order.total - _order.discount,
//             discount: _order.discount,
//             orderNumber: _order.orderNumber,
//             vatNum: _client.vatNum,
//             clientNum: _client.clientNum,
//             employeeNum: _order.cashierCode,
//             clientName: _client.clientName,
//           );
//       } else {
//           logger.w('Skipping receipt print: Printer Manager not initialized on this platform.');
//       }


//       // 3c. Clear up for next sale
//       _order.paymentMthdsTxnNames = '';
//       setState(() {
//         _loadOrderNum();
//       });

//       _clearOrder('Message', 'Order Saved', saveTxn: false);

//     } else {
//       // --- FAILURE PATH ---
//       // API call FAILED. Show an error and DO NOT clear the order.
//       logger.e('Real-time sync failed. Sale was NOT saved.');
//       if (mounted) {
//          await _dialogPayAndReturns.showDialogBox(
//             context: context,
//             title: 'Sync Error',
//             message: 'Failed to send sale to server. Please check connection and try payment again. The sale has NOT been saved.',
//             showCancel: false,
//             );
//       }

//     }
//   }


// // Helper function to extract loyalty points used from payment methods
// double _extractLoyaltyPointsUsed() {
//   try {
//     // FIX: Use the correct field name: _order.payMthdsCache
//     final loyaltyPayment = _order.payMthdsCache.firstWhere( 
//       (p) => p['tender_type_id'] == '14', // '14' is the correct Loyalty Tender ID
//     );
//     // The amount tendered is the points used
//     return (loyaltyPayment['amount_tendered'] as num?)?.toDouble() ?? 0.0;
//   } catch (e) {
//     return 0.0; 
//   }
// }
// // package:web_admin/views/screens/sales_register_pos_screen.dart

// // #################################
// // /// Corrected Real-Time Sale Sync to API
// // // #################################
// Future<bool> _syncSaleRealTime() async {
//   final prefs = await SharedPreferences.getInstance();
  
//   // DEBUG STEP: Log the raw payment cache contents to see what is missing
//   logger.d("Raw Pay Methods Cache: ${_order.payMthdsCache}");

//   // 1. Format Payment Methods 
//   // This transformation ensures that all tenders in the cache are correctly mapped.
//   List<Map<String, dynamic>> salePayMethods =
//     _order.payMthdsCache.map((payment) {
//   return {
//     // Ensure tender_type_id is explicitly a String
//     "tender_type_id": payment['pay_txn_id'].toString(), 
//     "payment_name": payment['pay_txn_name'],
//     // Ensure amount_tendered is explicitly a double/num
//     "amount_tendered": (payment['pay_txn_amount'] as num).toDouble(), 
//   };
// }).toList();
  
//   // NEW DEBUG STEP: Log the formatted list to check against the successful cURL
//   logger.d("Formatted Sale Pay Methods: $salePayMethods");


//   // 2. Format Items (Retaining your original item formatting logic)
//   List<Map<String, dynamic>> saleItems = [];
//   for (var item in orderItems) { // Assuming orderItems is accessible here
//     final preparedItem = _prepareItemData(item, _order.orderNumber); // Assuming _prepareItemData exists
//     saleItems.add({
//       "si_sale_num": preparedItem['si_sale_num'],
//       "si_id": preparedItem['si_id'],
//       "si_name": preparedItem['si_name'],
//       "si_unit": preparedItem['si_unit'],
//       "si_barcode": preparedItem['si_barcode'],
//       "si_category": preparedItem['si_category'],
//       "si_qty": preparedItem['si_qty'],
//       "si_price": preparedItem['si_price'], 
//       "si_subtotal": preparedItem['si_subtotal'],
//       "si_tax": preparedItem['si_tax'],
//       "si_total": preparedItem['si_total'], 
//       "si_discount_amount": preparedItem['si_discount'] ?? 0,
//       "si_discount_percent": preparedItem['si_disc_pct'] ?? 0,
//     });

//     // Add supplementary items (Retaining your original logic)
//     if (item['item_supplementary'] != null && item['item_supplementary'] is List) {
//       for (var supItem in item['item_supplementary']) {
//         final preparedSupItem = _prepareSupplementaryData(supItem, _order.orderNumber); // Assuming _prepareSupplementaryData exists
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
//     if (payment['tender_type_id'].toString() == '14') { 
//       loyaltyPointsUsed += (payment['amount_tendered'] as num? ?? 0.0);
//     }
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
//     "sale_pay_methods": salePayMethods, // Contains ALL payments from cache
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
      
//       // Extract loyalty points from confirmation
//       final double pointsUsed = (confirmation['loy_points_used'] as num? ?? 0.0).toDouble();
//       final double pointsEarned = (confirmation['loy_points_earned'] as num? ?? 0.0).toDouble();

//       if (pointsUsed > 0 || pointsEarned > 0) {
//         String pointsInfo = ' (Confirmed: ';
//         if (pointsUsed > 0) {
//           pointsInfo += 'Used: ${pointsUsed.toStringAsFixed(0)} pts';
//         }
//         if (pointsEarned > 0) {
//           if (pointsUsed > 0) pointsInfo += ', ';
//           pointsInfo += 'Earned: ${pointsEarned.toStringAsFixed(0)} pts';
//         }
//         pointsInfo += ')';
//         _order.paymentMthdsTxnNames += pointsInfo;
//       }

//       logger.d("Real-time sync confirmed for $salesNum with status $status");
//       logger.d("Real-time sync API Response: $confirmations"); 
//       return true; 
//     } else {
//       logger.w("Real-time sync failed or returned no confirmation. Response: $confirmations");
//       return false; 
//     }
//   } catch (e) {
//     logger.e("Error during real-time sync: $e.");
//     return false; 
//   }
// }
//   // // #################################
//   // /// NEW: Real-Time Sale Sync to API (Returns Success/Failure)
//   // // #################################
//   // Future<bool> _syncSaleRealTime() async {
//   //   final prefs = await SharedPreferences.getInstance();

//   //   // 1. Format Payment Methods
//   //   List<Map<String, dynamic>> salePayMethods =
//   //       _order.payMthdsCache.map((payment) {
//   //     return {
//   //       "tender_type_id": payment['pay_txn_id'],
//   //       "payment_name": payment['pay_txn_name'],
//   //       "amount_tendered": payment['pay_txn_amount'],
//   //     };
//   //   }).toList();

//   //   // 2. Format Items
//   //   List<Map<String, dynamic>> saleItems = [];
//   //   for (var item in orderItems) {
//   //     final preparedItem = _prepareItemData(item, _order.orderNumber);
//   //     saleItems.add({
//   //       "si_sale_num": preparedItem['si_sale_num'],
//   //       "si_id": preparedItem['si_id'],
//   //       "si_name": preparedItem['si_name'],
//   //       "si_unit": preparedItem['si_unit'],
//   //       "si_barcode": preparedItem['si_barcode'],
//   //       "si_category": preparedItem['si_category'],
//   //       "si_qty": preparedItem['si_qty'],
//   //       "si_price": preparedItem['si_price'], // price before tax
//   //       "si_subtotal": preparedItem['si_subtotal'],
//   //       "si_tax": preparedItem['si_tax'],
//   //       "si_total": preparedItem['si_total'], // subtotal + tax
//   //       "si_discount_amount": preparedItem['si_discount'] ?? 0,
//   //       "si_discount_percent": preparedItem['si_disc_pct'] ?? 0,
//   //     });

//   //     // Add supplementary items
//   //     if (item['item_supplementary'] != null &&
//   //         item['item_supplementary'] is List) {
//   //       for (var supItem in item['item_supplementary']) {
//   //         final preparedSupItem =
//   //             _prepareSupplementaryData(supItem, _order.orderNumber);
//   //         saleItems.add({
//   //           "si_sale_num": preparedSupItem['si_sale_num'],
//   //           "si_id": preparedSupItem['si_id'],
//   //           "si_name": preparedSupItem['si_name'],
//   //           "si_unit": preparedSupItem['si_unit'],
//   //           "si_barcode": preparedSupItem['si_barcode'],
//   //           "si_category": preparedSupItem['si_category'],
//   //           "si_qty": preparedSupItem['si_qty'],
//   //           "si_price": preparedSupItem['si_price'],
//   //           "si_subtotal": preparedSupItem['si_subtotal'],
//   //           "si_tax": preparedSupItem['si_tax'],
//   //           "si_total": preparedSupItem['si_total'],
//   //           "si_discount_amount": preparedSupItem['si_discount'] ?? 0,
//   //           "si_discount_percent": preparedSupItem['si_disc_pct'] ?? 0,
//   //         });
//   //       }
//   //     }
//   //   }

//   //   // 3. Check for loyalty points used
//   //   double loyaltyPointsUsed = 0;
//   //   for (var payment in salePayMethods) {
//   //     if (payment['tender_type_id'].toString() == '14') { // '14' is loyalty points ID
//   // loyaltyPointsUsed += (payment['amount_tendered'] as double? ?? 0.0);
//   // }
//   //   }

//   //   // 4. Construct main sale object
//   //   Map<String, dynamic> saleData = {
//   //     "sales_num": _order.orderNumber,
//   //     "sale_id": _order.saleId,
//   //     "sales_date": DateFormat('yyyy-MM-dd').format(DateTime.now()),
//   //     "sales_time": DateFormat('HH:mm:ss').format(DateTime.now()),
//   //     "sales_subtotal": double.parse(_order.subTotal.toStringAsFixed(3)),
//   //     "sales_tax": double.parse(_order.tax.toStringAsFixed(3)),
//   //     "sales_total": double.parse((_order.total - _order.discount).toStringAsFixed(3)),
//   //     "sales_discount_amount": _order.discount,
//   //     "sales_discount_percent": _order.discountPct,
//   //     "sales_cashier": _order.cashierCode,
//   //     "sales_store": prefs.getString('selectedStore'),
//   //     "sales_registerId": prefs.getString('selectedRegister'),
//   //     "items": saleItems,
//   //     "sale_pay_methods": salePayMethods,
//   //   };

//   //   if (_client.clientNum != null && _client.clientNum!.isNotEmpty) {
//   //     saleData["loy_cust_card_num"] = _client.clientNum;
//   //   }
//   //   if (loyaltyPointsUsed > 0) {
//   //     saleData["loy_points_used"] = loyaltyPointsUsed;
//   //   }

//   //   List<Map<String, dynamic>> salesListPayload = [saleData];

//   //   // 5. Send data
//   //   try {
//   //     final ApiService apiSendData = ApiService(
//   //         endpointPath: ApiRoutes.postProducts);
//   //     logger.d("Sending real-time sale: ${salesListPayload.toString()}");


//   //     List<dynamic>? confirmations =
//   //         await apiSendData.sendData(salesListPayload, (message) {
//   //       if (mounted) {
//   //         ScaffoldMessenger.of(context)
//   //             .showSnackBar(SnackBar(content: Text(message)));
//   //       }
//   //     });

//   //     if (confirmations != null && confirmations.isNotEmpty) {
//   //       final confirmation = confirmations.first;
//   //       String salesNum = confirmation['sale_num'];
//   //       String status = confirmation['status'];

//   //       // FIX 2: Extract loyalty points from confirmation and append to the
//   //       // payment name string for visibility on the receipt/in logs.
//   //       final double pointsUsed = (confirmation['loy_points_used'] as num? ?? 0.0).toDouble();
//   //       final double pointsEarned = (confirmation['loy_points_earned'] as num? ?? 0.0).toDouble();

//   //       if (pointsUsed > 0 || pointsEarned > 0) {
//   //         String pointsInfo = ' (Confirmed: ';
//   //         if (pointsUsed > 0) {
//   //           pointsInfo += 'Used: ${pointsUsed.toStringAsFixed(0)} pts';
//   //         }
//   //         if (pointsEarned > 0) {
//   //           if (pointsUsed > 0) pointsInfo += ', '; // Add separator if both exist
//   //           pointsInfo += 'Earned: ${pointsEarned.toStringAsFixed(0)} pts';
//   //         }
//   //         pointsInfo += ')';
//   //         _order.paymentMthdsTxnNames += pointsInfo;
//   //       }

//   //       logger.d("Real-time sync confirmed for $salesNum with status $status");
//   //       return true; // <-- SUCCESS PATH 1
//   //     } else {
//   //       logger.w("Real-time sync failed or returned no confirmation.");
//   //       return false; // <-- FAILURE PATH 1 (Empty/Bad response)
//   //     }
//   //   } catch (e) {
//   //     logger.e("Error during real-time sync: $e.");
//   //     return false; // <-- FAILURE PATH 2 (API Exception/Network Error)
//   //   }
    
//   // }


//   //load payment methods
//   Future<void> _loadPaymentMethods() async {
//     final prefs = await SharedPreferences.getInstance();
//     final storeId = prefs.getString('selectedStore');

//     if (storeId == null) {
//       return;
//     }
//     List<String> paymentMethods = await _dbHelper.getAvailablePaymentMethods(storeId);

//     setState(() {
//       enabledPaymentMethods = paymentMethods;
//     });
//   }

// //*********************** */
//   /// Virtual numpad
// //*********************** */
//   final TextEditingController _searchController = TextEditingController(text: "");
//   String _searchTerm = '';

//   //search values search box
//   void _onSearchChanged() {
//     setState(() {
//       _searchTerm = _searchController.text;
//     });
//   }

//   void _onValueChanged(String value) {
//     setState(() {
//       _searchController.text += value;
//       _onSearchChanged();
//       _searchFocusNode.requestFocus();
//     });
//   }

//   /// delete values search box
//   void _onDelete() {
//     setState(() {
//       if (_searchController.text.isNotEmpty) {
//         _searchController.text = _searchController.text.substring(0, _searchController.text.length - 1);
//       } else {
//         _searchTerm = '';
//         _searchController.text = _searchTerm;
//       }
//       _searchFocusNode.requestFocus();
//     });
//   }

//   /// clear values search box
//   Future<void> _clearSearchBox() async {
//     setState(() {
//       _searchTerm = '';
//       _searchController.text = _searchTerm;
//       _searchFocusNode.requestFocus();
//     });
//   }

//   void _onSearchSubmitted() {
//     List<Map<String, dynamic>> filteredItems = _searchTerm.isEmpty
//         ? []
//         : _items.where((item) => item['item_barcode']!.toLowerCase().contains(_searchTerm.toLowerCase())).toList();

//     if (filteredItems.isNotEmpty) {
//       var item = filteredItems.first;
//       _addItemToOrder(
//         item['item_img']!,
//         item['item_name']!,
//         1,
//         item['item_price']!,
//         item['item_unit']!,
//         item['item_id']!,
//         item['item_barcode']!,
//         item['item_category']!,
//         item['item_tax_group']!,
//         item['item_tax_pct']!,
//       );
//       _clearSearchBox();
//       _searchFocusNode.requestFocus();
//     } else {
//       _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message: 'Item not found',
//         showCancel: false,
//       );
//       _clearSearchBox();
//       _searchFocusNode.requestFocus();
//     }
//   }

// // ************************
//   /// Receipt info
// // **********************
//   Future<void> _loadOrderNum() async {
//     final prefs = await SharedPreferences.getInstance();
//     final store = prefs.getString('selectedStore') ?? '';

//     _order.prefix =
//         (store.length >= 3) ? store.substring(store.length - 3) : 'DEF'; // 'DEF' como prefijo predeterminado

//     final timestamp = DateTime.now().millisecondsSinceEpoch;
//     _order.orderNumber = '${_order.prefix}-${timestamp.toString().padLeft(16, '0')}';

//     logger.d('Generated order number: ${_order.orderNumber}');
//   }

//   Future<void> _loadUserCode() async {
//     await Future.delayed(Duration.zero);
//     if (mounted) {
//       final userData = Provider.of<UserDataProvider>(context, listen: false);
//       setState(() {
//         _order.cashierCode = userData.userCode;
//       });
//     }
//   }

// // ********************************
//   /// Process order
// // ********************************
//   Future<void> _loadSelectedPrinter() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       defaultPrinter = prefs.getString('selectedPrinter');
//     });

//     if (defaultPrinter == null || defaultPrinter!.isEmpty) {
//       bool? confirmed = await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message: 'Item not found',
//         showCancel: false,
//       );

//       if (confirmed == true && mounted) {
//         GoRouter.of(context).go(RouteUri.generalSettings);
//       }
//     } else {
//       printerManager = PrinterManagerInvoice(
//         showDialog: (title, message, {showCancel = false, showTextField = false, isReturn = false}) {
//           return _dialogPayAndReturns.showDialogBox(
//             context: context,
//             title: title,
//             message: message,
//             showCancel: showCancel,
//             showTextField: showTextField,
//             isReturn: isReturn,
//           );
//         },
//         clearOrder: _clearOrder,
//         onClear: _clearSearchBox,
//       );
//     }
//   }

//   ////
//   void _handleOrder(String payMethod) async {
//     _order.paymentMethodId = payMethod;
//     String paymentMethodName = await _dbHelper.getPayMthdName(payMethod) ?? '';
//     double tempBalance = _order.balance;
//     _clearSearchBox();

//     try {
      
//       if (orderItems.isEmpty) {
//         await _dialogPayAndReturns.showDialogBox(
//           context: context,
//           title: 'Info',
//           message: 'There are no items in the order',
//           showCancel: false,
//         );
//         return;
//       } else {
//         bool? confirmed = await _dialogPayAndReturns.showDialogBox(
//           context: context,
//           title: 'Payment',
//           message: 'Please add the amount to pay',
//           showTextField: true,
//           isReturn: false,
//           isCash: _order.paymentMethodId == '1' ? true : false,
//           updateBalance: updateBalance,
//           getBalance: () => _order.balance,
//           totalPay: _order.total - _order.discount,
//           showCancel: true,
//           onAdditionalInfoEntered: (clientName, vatNum) {
//             _client.clientName = clientName;
//             _client.vatNum = vatNum;
//           },
//         );
//         if (_order.balance != tempBalance) {
//           if (paymentMethodName.isNotEmpty) {
//             if (_order.paymentMthdsTxnNames.isNotEmpty) {
//               _order.paymentMthdsTxnNames += ', ';
//             }
//             _order.paymentMthdsTxnNames += paymentMethodName;
//             tempBalance = _order.balance;
//           }
//         } else {
//           _order.paymentMthdsTxnNames += paymentMethodName;
//         }

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
//         else {
//           //handle cancel
//         }
//       }
//     } catch (e) {
//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message: 'An error occurred: $e',
//         showCancel: false,
//       );
//     }
//   }

// // // #################################
// //   /// loyalty payment
// // // #################################
// //   void _handelLoyPayment(String payMethod) async {
// //     _order.paymentMethodId = payMethod;
// //     String paymentMethodName = await _dbHelper.getPayMthdName(payMethod) ?? '';
// //     double tempBalance = _order.balance;
// //     _clearSearchBox();

// //     try {
// //       if (orderItems.isEmpty) {
// //         await _dialogLoyPayment.showDialogBox(
// //           context: context,
// //           title: 'Message',
// //           message: 'There are no items in the order',
// //           showCancel: true,
// //         );
// //         return;
// //       } else {
// //         bool? confirmed = await _dialogLoyPayment.showDialogBox(
// //           context: context,
// //           title: 'Message',
// //           message: 'Please introduce the customer ID',
// //           showTextField: true,
// //           isReturn: false,
// //           updateBalance: updateBalance,
// //           getBalance: () => _order.balance,
// //           showCancel: true,
// //         );
// //         logger.d(paymentMethodName);
// //         if (_order.balance != tempBalance) {
// //           if (paymentMethodName.isNotEmpty) {
// //             if (_order.paymentMthdsTxnNames.isNotEmpty) {
// //               _order.paymentMthdsTxnNames += ', ';
// //             }
// //             _order.paymentMthdsTxnNames += paymentMethodName;
// //             tempBalance = _order.balance;
// //           }
// //         }
// //         logger.d(_order.paymentMthdsTxnNames);
// //         if (confirmed == true) {
// //           if (defaultPrinter == null || defaultPrinter!.isEmpty) {
// //             await _dialogLoyPayment.showDialogBox(
// //               context: context,
// //               title: 'Message',
// //               message: 'There is no default printer',
// //               showCancel: false,
// //             );

// //             if (mounted) {
// //               GoRouter.of(context).go(RouteUri.generalSettings);
// //             }
// //             return;
// //           }

// //           await _saveOrderData(SalesStatusConst.salesComplete);
// //           await _saveSaleItems(orderItems);
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
// //         } else {
// //           //handle cancel
// //         }
// //       }
// //     } catch (e) {
// //       await _dialogPayAndReturns.showDialogBox(
// //         context: context,
// //         title: 'Error',
// //         message: 'An error occurred: $e',
// //         showCancel: false,
// //       );
// //     }
// //   }

// // #################################
//   /// store pending sale
// // #################################
//   void _storePendingTxn() async {
//     try {
//       if (orderItems.isEmpty) {
//         await _dialogPayAndReturns.showDialogBox(
//           context: context,
//           title: 'Message',
//           message: 'There are no items in the order',
//           showCancel: false,
//         );
//         return;
//       } else {
//         bool? confirmed = await _dialogPayAndReturns.showDialogBox(
//           context: context,
//           title: 'Message',
//           message: 'Would you like save this transaction?',
//           showCancel: true,
//         );
//         if (confirmed == true) {
//           await _saveOrderData(SalesStatusConst.salesPending);
//           await _saveSaleItems(orderItems);
//           await TxnHelper.saveTxn(
//             txnReceiptNum: '',
//             txnAmount: 0.0,
//             txnType: Event.pendingTxn,
//             txnStatus: PostingStatus.pending,
//             txnLocalStatus: LocalEvent.pending,
//           );

//           setState(() {
//             _loadOrderNum();
//             _clearOrder('Message', 'Order Saved', saveTxn: true);
//           });

//           orderItems = [];
//         } else {
//           // Handle order cancellation
//         }
//       }
//     } catch (e) {
//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message: 'An error occurred: $e',
//         showCancel: false,
//       );
//     }
//   }

// // ###########################
//   /// save pending transaction
// // ###########################
//   Future<void> _saveOrderData(String txnStatus) async {
//     final prefs = await SharedPreferences.getInstance();

//     Map<String, dynamic> sale = {
//       'sales_num': _order.orderNumber,
//       'sales_timeStamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//       'sales_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
//       'sales_time': DateFormat('HH:mm:ss').format(DateTime.now()),
//       'sales_employee': _order.cashierCode,
//       'sales_store_id': prefs.getString('selectedStore'),
//       'sales_register_id': prefs.getString('selectedRegister'),
//       'sales_subtotal': double.parse(_order.subTotal.toStringAsFixed(3)),
//       'sales_tax': double.parse(_order.tax.toStringAsFixed(3)),
//       'sales_total': double.parse(_order.total.toStringAsFixed(3)),
//       'sales_discount': _order.discount,
//       'sales_disc_pct': _order.discountPct,
//       'sales_status': txnStatus,
//       'loy_cust_card_num': _client.clientNum,
//     };

//     // ###########################
//     /// Save the transaction
//     // ###########################
//     await TxnHelper.saveTxn(
//       txnReceiptNum: _order.orderNumber,
//       txnAmount: _order.total,
//       txnType: Event.sales,
//       txnStatus: PostingStatus.pending,
//       txnLocalStatus: LocalEvent.pending,
//     );

//     await _dbHelper.saveSale(sale);

//     for (var payment in _order.payMthdsCache) {
//       await _dbHelper.savePaymentMthd(payment);
//     }
//     _order.payMthdsCache.clear();
//   }

// // ###########################
//   /// save order items
// // ##########################
//   Future<void> _saveSaleItems(List<Map<String, dynamic>> orderItems) async {
//     final hasNegativeQty = orderItems.any((item) {
//       final itemQty = int.tryParse(item['item_qty'].toString()) ?? 0;
//       return itemQty < 0;
//     });

//     _order.orderNumber = '${_order.orderNumber}${hasNegativeQty ? 'R' : ''}';

//     for (var item in orderItems) {
//       try {
//         final itemData = _prepareItemData(item, _order.orderNumber);
//         await _dbHelper.saveItemsSale(itemData);

//         if (item['item_supplementary'] != null && item['item_supplementary'] is List) {
//           for (var supplementary in item['item_supplementary']) {
//             final supplementaryData = _prepareSupplementaryData(supplementary, _order.orderNumber);
//             await _dbHelper.saveItemsSale(supplementaryData);
//           }
//         } else {
//           logger.d('No supplementary items found or the structure is invalid for item: ${item['item_name']}');
//         }
//       } catch (e) {
//         logger.e('Failed to save item: ${item['item_name']}, error: $e');
//       }
//     }
//   }

//   Map<String, dynamic> _prepareItemData(Map<String, dynamic> item, String orderNumber) {
//     final itemPrice = item['item_price'];
//     final itemQty = int.tryParse(item['item_qty'].toString()) ?? 0;
//     final itemTaxPct = item['item_tax_pct'];
//     final itemSubtotal = double.parse(((itemPrice / (1 + (itemTaxPct / 100))) * itemQty).toStringAsFixed(3));
//     final itemTax = double.parse(((itemSubtotal * itemTaxPct) / 100).toStringAsFixed(3));
//     final itemTotal = double.parse((itemSubtotal + itemTax).toStringAsFixed(3));

//     return {
//       'si_sale_num': orderNumber,
//       'si_id': item['item_id'],
//       'si_name': item['item_name'],
//       'si_unit': item['item_unit'],
//       'si_code': item['item_id'],
//       'si_barcode': item['item_barcode'],
//       'si_category': item['item_category'],
//       'si_qty': itemQty,
//       'si_price': itemSubtotal / itemQty,
//       'si_tax_pct': itemTaxPct,
//       'si_subtotal': itemSubtotal,
//       'si_tax': itemTax,
//       'si_total': itemTotal,
//       'si_discount': item['item_disc_amount'] ?? 0.0,
//       'si_disc_pct': item['item_disc_perct'] ?? 0.0,
//     };
//   }

//   Map<String, dynamic> _prepareSupplementaryData(Map<String, dynamic> supplementary, String orderNumber) {
//     final supItemPrice = supplementary['sup_item_price'];
//     final supItemQty = supplementary['sup_item_qty'];
//     final subtotal = supItemPrice * supItemQty;

//     return {
//       'si_sale_num': orderNumber,
//       'si_id': supplementary['sup_item_id'],
//       'si_name': supplementary['sup_item_name'],
//       'si_unit': supplementary['sup_item_unit'],
//       'si_code': supplementary['sup_item_id'],
//       'si_barcode': supplementary['sup_item_barcode'],
//       'si_category': supplementary['sup_item_category'],
//       'si_qty': supItemQty,
//       'si_price': supItemPrice,
//       'si_tax_pct': supplementary['sup_item_tax_pct'],
//       'si_subtotal': subtotal,
//       'si_tax': 0.0,
//       'si_total': subtotal,
//       'si_discount': 0.0,
//       'si_disc_pct': 0.0,
//     };
//   }

// // ##################
//   /// add items to order
// // ##################
//   Future<void> _addItemToOrder(
//     String image,
//     String name,
//     int qty,
//     double price,
//     String unit,
//     String code,
//     String barcode,
//     String category,
//     String taxGroup,
//     double taxPct,
//   ) async {
//     _order.paymentMthdsTxnNames = '';

//     // Check if a transaction is in progress
//     if (_order.balance > 0) {
//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: 'Error',
//         message:
//             'It is not possible to add new items until you finish the current transaction. \nPlease cancel or finish the current transaction to add new items.',
//         showCancel: false,
//       );
//       return;
//     }

//     // Get the supplementary item, if any
//     Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(code);

//     setState(() {
//       // Add the main item
//       orderItems.add({
//         'item_img': image,
//         'item_name': name,
//         'item_qty': qty,
//         'item_unit': unit,
//         'item_price': double.parse((price + (price * taxPct / 100)).toStringAsFixed(2)),
//         'item_id': code,
//         'item_barcode': barcode,
//         'item_category': category,
//         'item_tax_group': taxGroup,
//         'item_tax_pct': taxPct,
//         'box_color': const Color.fromARGB(255, 120, 102, 71),
//         'item_supplementary': [
//           if (suppItem != null)
//             {
//               'sup_item_name': suppItem['supp_name'],
//               'sup_item_qty': qty,
//               'sup_item_unit': suppItem['supp_uom'],
//               'sup_item_price': suppItem['supp_price'],
//               'sup_item_id': suppItem['supp_id'],
//               'sup_item_barcode': '',
//               'sup_item_category': '',
//               'sup_item_tax_group': "0%",
//               'sup_item_tax_pct': suppItem['supp_tax_pct'],
//               'box_color': const Color.fromARGB(255, 120, 102, 71),
//             }
//         ],
//       });
//       _order.lines++;
//       // Update totals
//       updateValues();
//       logger.d(orderItems);
//     });
//   }

// // #########################
//   /// remove items from order
// // ########################
//   Future<void> _removeItemFromOrder(int originalIndex) async {
//     _order.paymentMthdsTxnNames = '';
//     logger.d('item seleccionado:$orderItems');
//     String selectedItem = orderItems[originalIndex]['item_id'];
//     int mainItemQty = orderItems[originalIndex]['item_qty'];
//     logger.d('id_item: $selectedItem');
//     logger.d('main item qty: $mainItemQty');

//     Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(selectedItem);
//     logger.d('all info supp_item: $suppItem');

//     String? suppItemId = suppItem?['supp_id'];
//     logger.d('id_suppItem: $suppItemId');

//     var foundIndexSuppItem = orderItems.indexWhere((item) => item['item_id'] == suppItemId);

//     if (foundIndexSuppItem != -1) {
//       var foundItem = orderItems[foundIndexSuppItem];
//       var itemSuppQty = foundItem['item_qty'];

//       int newSuppItemQty = itemSuppQty - mainItemQty;

//       if (newSuppItemQty <= 0) {
//         orderItems.removeAt(foundIndexSuppItem);
//         logger.d('SuppItem remove due the new qty is  0');
//         _order.lines--;
//       } else {
//         orderItems[foundIndexSuppItem]['item_qty'] = newSuppItemQty;
//         logger.d('supp item found in index: $foundIndexSuppItem');
//         logger.d('New item quantity supp: $newSuppItemQty');
//       }
//     } else {
//       logger.d('item not found');
//     }

//     var recalculatedIndex = orderItems.indexWhere((item) => item['item_id'] == selectedItem);

//     if (recalculatedIndex != -1) {
//       orderItems.removeAt(recalculatedIndex);
//       logger.d('new item index: $recalculatedIndex');
//     }

//     setState(() {
//       updateValues();
//       _order.discount = _calculateDiscount();
//       _order.lines--;
//     });

//     _searchFocusNode.requestFocus();
//   }

// // #########################
//   /// Update quantity manually
// // #########################
//   void _updateQuantityAtIndex(int index, String newQty) async {
//     setState(() {
//       if (index >= 0 && index < orderItems.length) {
//         int? parsedQty = int.tryParse(newQty);
//         if (parsedQty != null) {
//           final item = orderItems[index];
//           String selectedItemId = item['item_id'];

//           int oldQty = item['item_qty'];
//           int qtyDifference = parsedQty - oldQty;

//           // Update item quantity
//           orderItems[index]['item_qty'] = parsedQty;

//           // Update the supplementary items
//           _updateSupplementaryItems(selectedItemId, qtyDifference);
//         } else {
//           _dialogPayAndReturns.showDialogBox(
//             context: context,
//             title: 'Error',
//             message: 'Please enter a valid quantity....',
//             showCancel: false,
//           );
//         }
//       } else {
//         _dialogPayAndReturns.showDialogBox(
//           context: context,
//           title: 'Error',
//           message: 'Invalid Item',
//           showCancel: false,
//         );
//       }

//       // Update the total values
//       updateValues();
//     });
//   }

//   void _updateSupplementaryItems(String primaryItemId, int qtyDifference) async {
//     // Get the related supplementary item
//     Map<String, dynamic>? suppItem = await _dbHelper.getSuppItem(primaryItemId);
//     String? suppItemId = suppItem?['supp_id'];

//     if (suppItemId != null) {
//       List<int> supplementaryIndexes = [];
//       for (int i = 0; i < orderItems.length; i++) {
//         if (orderItems[i]['item_id'] == suppItemId) {
//           supplementaryIndexes.add(i);
//         }
//       }

//       setState(() {
//         for (int index in supplementaryIndexes) {
//           orderItems[index]['item_qty'] += qtyDifference;
//           logger.d('Updated amount and color of supplementary item in index $index: ${orderItems[index]['item_qty']}');
//         }
//         updateValues();
//       });
//     }
//   }

//   // ###############
//   /// update totals
//   // ###############
//   void updateValues() {
//     _order.subTotal = _calculateSubTotal();
//     _order.tax = _calculateTax();
//     _order.total = _calculateTotal();
//     // if (_order.total == 0) {
//     //   _clearOrder('Message', 'Order empty', saveTxn: true);
//     // }
//     _searchFocusNode.requestFocus();
//   }

//   // ###############
//   /// clear order
//   // ###############
//   Future<void> _clearOrder(String title, dynamic message, {bool saveTxn = false, bool showMessage = false}) async {
//     _order.balance = 0;
//     _order.payMthdsCache.clear();
//     if (orderItems.isEmpty) {
//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: title,
//         message: 'There are no items',
//         showCancel: false,
//       );
//       return;
//     } else {
//       setState(() {
//         orderItems.clear();
//         _order.subTotal = 0;
//         _order.tax = 0;
//         _order.total = 0;
//         _order.lines = 0;
//         _order.discount = 0;
//         _order.discountPct = 0;
//         // MODIFIED: Also clear selected customer
//         _selectedCustomer = null;
//         _client.clientName = '';
//         _client.clientNum = '';
//       });

//       await _dialogPayAndReturns.showDialogBox(
//         context: context,
//         title: title,
//         message: message,
//         showCancel: false,
//       );
//       _searchFocusNode.requestFocus();

//       if (saveTxn) {
//         await TxnHelper.saveTxn(
//           txnReceiptNum: '',
//           txnAmount: 0.0,
//           txnType: Event.voided,
//           txnStatus: PostingStatus.pending,
//           txnLocalStatus: LocalEvent.pending,
//         );
//       }
//     }
//   }

//   // #########################
//   /// calculate the subtotal
//   // #########################
//   double _calculateSubTotal() {
//     double subTotal = 0.0;

//     for (var item in orderItems) {
//       // Calculate the subtotal of the main item
//       double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
//       int qty = item['item_qty'];
//       subTotal += double.parse((price * qty).toStringAsFixed(2));

//       // Calculate the subtotal of the complementary items (if any)
//       final supplementaryData = item['item_supplementary'];
//       if (supplementaryData != null) {
//         if (supplementaryData is List) {
//           for (var supItem in supplementaryData) {
//             double supPrice = supItem['sup_item_price']! / (1 + (supItem['sup_item_tax_pct'] / 100));
//             int supQty = supItem['sup_item_qty'];
//             subTotal += double.parse((supPrice * supQty).toStringAsFixed(2));
//           }
//         } else if (supplementaryData is Map) {
//           double supPrice = supplementaryData['sup_item_price']! / (1 + (supplementaryData['sup_item_tax_pct'] / 100));
//           int supQty = supplementaryData['sup_item_qty'];
//           subTotal += double.parse((supPrice * supQty).toStringAsFixed(2));
//         }
//       }
//     }

//     return subTotal;
//   }

//   //##################
//   /// calculate the tax
//   //#################
//   double _calculateTax() {
//     double totalTax = 0.0;
//     for (var item in orderItems) {
//       double price = item['item_price']! / (1 + (item['item_tax_pct'] / 100));
//       double taxPct = item['item_tax_pct']!;
//       int qty = item['item_qty']!;
//       totalTax += double.parse((((price * taxPct) * qty) / 100).toStringAsFixed(2));
//     }

//     return totalTax;
//   }

//   // ##############################
//   /// calculate total items in order
//   // ##############################
//   double _calculateTotal() {
//     return _order.subTotal + _calculateTax();
//   }

//   // ###################
//   /// calculate discount
//   //####################
//   double _calculateDiscount() {
//     double totalDiscount = 0.0;
//     for (var item in orderItems) {
//       if (item['item_disc_amount'] != null) {
//         totalDiscount += item['item_disc_amount'];
//       }
//     }
//     return totalDiscount;
//   }

//   //########################################
//   /// Manage the payment methods
//   //########################################
//   Future<void> addPaymentMethod(String payMethod, double total, {bool isReturn = false}) async {
//     String? paymentMethodName = await _dbHelper.getPayMthdName(payMethod);

//     Map<String, dynamic> newPaymentMethod = {
//       'pay_txn_sale_num': _order.orderNumber,
//       'pay_txn_id': payMethod,
//       'pay_txn_name': paymentMethodName,
//       'pay_txn_amount': total,
//     };

//     _order.payMthdsCache.add(newPaymentMethod);
//   }

//   // ################################
//   /// calculate balance pending to pay
//   // ################################
//   void updateBalance(double newPaidAmount, {bool isReturn = false}) {
//     if (_order.balance == 0) {
//       _order.balance = double.parse((_calculateTotal() - _order.discount).toStringAsFixed(2));
//     }

//     // print(newPaidAmount);
//     // print(balance);

//     setState(() {
//       double formattedNewPaidAmount = double.parse(newPaidAmount.toStringAsFixed(2));
//       double formattedBalance = double.parse(_order.balance.toStringAsFixed(2));

//       if (formattedNewPaidAmount == formattedBalance) {
//         // full payment
//         _order.change = 0;
//         addPaymentMethod(
//           _order.paymentMethodId,
//           isReturn ? -formattedBalance : formattedBalance,
//           isReturn: isReturn,
//         );
//         _clearSearchBox();
//         _order.balance = 0;
//       } else if (formattedNewPaidAmount > formattedBalance) {
//         // ovepayment
//         _order.change = formattedNewPaidAmount - formattedBalance;
//         addPaymentMethod(
//           _order.paymentMethodId,
//           isReturn ? -formattedBalance : formattedBalance,
//           isReturn: isReturn,
//         );
//         _clearSearchBox();
//         _order.balance = 0;
//       } else {
//         // patial payment
//         _order.balance -= formattedNewPaidAmount;
//         addPaymentMethod(
//           _order.paymentMethodId,
//           isReturn ? -formattedNewPaidAmount : formattedNewPaidAmount,
//           isReturn: isReturn,
//         );
//         _clearSearchBox();
//         _order.change = 0;
//       }

//       logger.d('Balance: ${_order.balance}, New Paid Amount: $newPaidAmount, Change: ${_order.change}');
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final userDataProvider = context.read<UserDataProvider>();

//     if (userDataProvider.isUserLoggedIn()) {
//       return PortalMasterLayout(
//         body: _content(context),
//       );
//     } else {
//       return PublicMasterLayout(
//         body: _content(context),
//       );
//     }
//   }

//   Widget _content(BuildContext context) {
//     //set the search criterial
//     List<Map<String, dynamic>> filteredItems = _searchTerm.isEmpty
//         ? []
//         : _items
//             .where((item) =>
//                 item['item_barcode'].toLowerCase().contains(_searchTerm.toLowerCase()) ||
//                 item['item_name'].toLowerCase().contains(_searchTerm.toLowerCase()))
//             .toList();

//     return Container(
//       decoration: ContainerBackgroundTheme.myGradientDecoration,
//       child: Column(
//         children: [
//           // first row top header
//           Row(
//             mainAxisAlignment: MainAxisAlignment.start,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Expanded(
//                 flex: 6, //set the width
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(5, 5, 0, 0),
//                       child: TopTitle(
//                         title: 'Items Available - ${_items.length}',
//                         action: (const SizedBox.shrink()), //widget empty
//                         showButtons: false,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               //
//               Expanded(
//                 flex: 6, //set the width
//                 child: Column(
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
//                       child: TopTitle(
//                         title: 'Order # ${_order.orderNumber}',
//                         subTitle: '',
//                         action: (const SizedBox.shrink()), //widget empty
//                         showButtons: true,
//                         onReplyButtonPressed: _storePendingTxn,
//                         onUpdateOrderItems: updateOrderItems,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           // second row => items list | items order
//           //  items list
//           Expanded(
//             flex: 18, // set the hight
//             child: Padding(
//               padding: const EdgeInsets.all(4.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.start,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(
//                     flex: 4, //set the width
//                     child: GridView.count(
//                       crossAxisCount: 1, //qty items per line
//                       childAspectRatio: 8, // calculate height per cell
//                       children: filteredItems.map((item) {
//                         return ItemTile(
//                           image: item['item_img']!,
//                           title: item['item_name']!,
//                           price: double.parse(((item['item_price'] ?? 0) +
//                                   ((item['item_price'] ?? 0) * (item['item_tax_pct'] ?? 0)) / 100)
//                               .toStringAsFixed(2)),
//                           unit: item['item_unit'] ?? 'unit',
//                           code: item['item_id']!,
//                           onTap: () => _addItemToOrder(
//                               item['item_img']!,
//                               item['item_name']!,
//                               1,
//                               item['item_price']!,
//                               item['item_unit']!,
//                               item['item_id']!,
//                               item['item_barcode']!,
//                               item['item_category'] ?? '--',
//                               item['item_tax_group'] ?? '--',
//                               item['item_tax_pct']!),
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                   //item order
//                   Expanded(
//                     flex: 4, //set the width
//                     child: Padding(
//                       padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
//                       child: ListView.builder(
//                         itemCount: orderItems.length,
//                         itemBuilder: (BuildContext context, int index) {
//                           final orderItem = orderItems[orderItems.length - 1 - index];
//                           return ItemOrder(
//                             index: index,
//                             data: orderItem,
//                             onRemove: () => _removeItemFromOrder(orderItems.length - 1 - index),
//                             onQtyChanged: (newQty) => _updateQuantityAtIndex(orderItems.length - 1 - index, newQty),
//                             clearOrder: () => _clearOrder('Alert', 'Order Cleared', saveTxn: true),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // const SizedBox(height: 1), // separator optional
//           //third row => keypad | options buttons | total box order
//           //keypad
//           Expanded(
//             flex: 12, // set the hight
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.start,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   flex: 2, //set the width
//                   child: Container(
//                     width: double.infinity,
//                     margin: const EdgeInsets.only(top: 2.0),
//                     decoration: BoxDecoration(
//                       borderRadius: BorderRadius.circular(14),
//                       color: const Color.fromARGB(255, 31, 32, 41),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(0),
//                       child: Column(
//                         children: [
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: SizedBox(
//                                   height: 30,
//                                   child: SearchWidget(
//                                     searchController: _searchController,
//                                     searchFocusNode: _searchFocusNode,
//                                     onChanged: (value) {
//                                       setState(() {
//                                         _searchTerm = value;
//                                       });
//                                     },
//                                     onSubmitted: _onSearchSubmitted,
//                                     hintText: 'Search Item',
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: Padding(
//                                   padding: const EdgeInsets.all(0),
//                                   child: SizedBox(
//                                     height: 40,
//                                     child: TextButton(
//                                       onPressed: () {
//                                         _clearSearchBox();
//                                       },
//                                       child: const Text(
//                                         'CE',
//                                         style: TextStyle(fontSize: 14, color: Colors.white),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: SizedBox(
//                                   height: 40,
//                                   child: TextButton.icon(
//                                     icon: const Icon(
//                                       Icons.arrow_back,
//                                       size: 14,
//                                     ),
//                                     label: const Text(''),
//                                     onPressed: () {
//                                       _onDelete();
//                                     },
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: VirtualNumpad(
//                                   controller: _searchController,
//                                   focusNode: _searchFocusNode,
//                                   onEnterPressed: _onSearchSubmitted,
//                                   onValueChanged: _onValueChanged,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 //add new customer
//                 Expanded(
//                   flex: 2,
//                   child: Padding(
//                     padding: const EdgeInsets.all(2.0),
//                     child: Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(14),
//                         color: const Color.fromARGB(255, 31, 32, 41),
//                       ),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center, // Centre vertically
//                         crossAxisAlignment: CrossAxisAlignment.stretch, // expand the buttom
//                         children: [
//                           ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 20),
//                               backgroundColor: const Color.fromARGB(255, 27, 155, 20),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                             child: const FittedBox(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.discount),
//                                   Text(' Discount'),
//                                   SizedBox(width: 5),
//                                 ],
//                               ),
//                             ),
//                             onPressed: () async {
//                               List<Map<String, dynamic>>? updatedItems = await showDialog<List<Map<String, dynamic>>>(
//                                 context: context,
//                                 builder: (BuildContext context) {
//                                   return DiscountDialog(
//                                       title: 'Apply Discount',
//                                       data: orderItems,
//                                       showCancel: true,
//                                       onApplyDiscount: (double discountAmount, double discountPct) {
//                                         setState(() {
//                                           _order.discount = discountAmount;
//                                           _order.discountPct = discountPct;
//                                         });
//                                       });
//                                 },
//                               );
//                               if (updatedItems != null) {
//                                 setState(() {
//                                   orderItems = updatedItems;
//                                   _order.subTotal = _calculateSubTotal();
//                                   _order.tax = _calculateTax();
//                                   _order.total = _calculateTotal();

//                                   logger.d("items:");
//                                   logger.d(orderItems);
//                                   for (var item in orderItems) {
//                                     logger.d('${item['item_name']}: ${item['item_disc_amount']}');
//                                   }
//                                 });
//                               }
//                             },
//                           ),
//                           const SizedBox(height: 5), //separator
                          
//                            // --- MODIFIED: Replaced 'Add Customer' button with a TextField and Search Icon ---
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 4.0),
//                             child: Row(
//                               children: [
//                                 Expanded(
//                                   child: SizedBox(
//                                     height: 50,
//                                     child: TextField(
//                                       controller: _customerMobileController,
//                                       keyboardType: TextInputType.phone,
//                                       style: const TextStyle(color: Colors.white),
//                                       decoration: InputDecoration(
//                                         labelText: 'Loyalty Card Number',
//                                         labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
//                                         border: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(10),
//                                         ),
//                                         focusedBorder: OutlineInputBorder(
//                                           borderRadius: BorderRadius.circular(10),
//                                           borderSide: const BorderSide(color: Colors.white),
//                                         ),
//                                         contentPadding: const EdgeInsets.symmetric(horizontal: 8.0)
//                                       ),
//                                       onSubmitted: (value) => _searchAndSetCustomer(value),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Container(
//                                   decoration: BoxDecoration(
//                                      color: const Color.fromARGB(255, 51, 53, 71),
//                                      borderRadius: BorderRadius.circular(10)
//                                   ),
//                                   child: IconButton(
//                                     icon: const Icon(Icons.search, color: Colors.white),
//                                     onPressed: () => _searchAndSetCustomer(_customerMobileController.text),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           // ---------------------------------------------------------------------------------

//                           const SizedBox(height: 5), //separator
//                           ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 20),
//                               backgroundColor: const Color.fromARGB(255, 77, 7, 20),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                             ),
//                             onPressed: () {
//                               printerManager!.openCashDrawer();
//                             },
//                             child: const FittedBox(
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.open_in_browser),
//                                   Text(' Open Drawer'),
//                                   SizedBox(width: 5),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           const SizedBox(height: 5), //separator
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//                 //total box order
//                 Expanded(
//                   flex: 4,
//                   child: Padding(
//                     padding: const EdgeInsets.all(2.0),
//                     child: Container(
//                       padding: const EdgeInsets.all(10),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(14),
//                         color: const Color.fromARGB(255, 31, 32, 41),
//                       ),
//                       child: Column(
//                         children: [
//                           // const Spacer(),
//                           // const Spacer(),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 'Lines: ${_order.lines.toString()}',
//                                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
//                               ),
//                               Text(
//                                 'SUBTOTAL: € ${_order.subTotal.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Color.fromARGB(255, 224, 224, 11),
//                                     fontSize: 12),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 5),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               TextButton(
//                                 style: TextButton.styleFrom(
//                                   foregroundColor: Colors.transparent,
//                                   padding: const EdgeInsets.fromLTRB(1, 1, 1, 1),
//                                   backgroundColor: Colors.transparent,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),
//                                 child: const FittedBox(
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Text(
//                                         ' Payment History',
//                                         style: TextStyle(color: Colors.blue),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 onPressed: () async {
//                                   logger.d(_order.payMthdsCache);
//                                   if (_order.payMthdsCache.isNotEmpty) {
//                                     await showDialog<List<Map<String, dynamic>>>(
//                                       context: context,
//                                       builder: (BuildContext context) {
//                                         return PaymentHDialog(
//                                           title: 'Payment History',
//                                           data: _order.payMthdsCache,
//                                           showCancel: true,
//                                         );
//                                       },
//                                     );
//                                   } else {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(content: Text('There are no payments.')),
//                                     );
//                                   }
//                                 },
//                               ),
//                               Text(
//                                 'TAX: € ${_order.tax.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Color.fromARGB(255, 224, 224, 11),
//                                     fontSize: 12),
//                               ),
//                             ],
//                           ),
//                           Container(
//                             margin: const EdgeInsets.symmetric(vertical: 10),
//                             height: 1,
//                             width: double.infinity,
//                             color: Colors.white,
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.end,
//                             children: [
//                               Text(
//                                 'DISC: €- ${_order.discount.toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontWeight: FontWeight.bold, color: Color.fromARGB(255, 40, 231, 30), fontSize: 12),
//                               ),
//                             ],
//                           ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.end,
//                             children: [
//                               Text(
//                                 // 'AMOUNT DUE: € ${(_order.total - _order.discount < 0 ? 0 : (_order.total - _order.discount)).toStringAsFixed(2)}',
//                                 'AMOUNT DUE: € ${(_order.total - _order.discount).toStringAsFixed(2)}',
//                                 style: const TextStyle(
//                                     fontWeight: FontWeight.bold,
//                                     color: Color.fromARGB(255, 224, 224, 11),
//                                     fontSize: 12),
//                               ),
//                             ],
//                           ),

//                           if (double.parse(_order.balance.toStringAsFixed(2)) > 0) ...[
//                             Container(
//                               margin: const EdgeInsets.symmetric(vertical: 10),
//                               height: 1,
//                               width: double.infinity,
//                               color: Colors.white,
//                             ),
//                             FadeTransition(
//                               opacity: _animation,
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.end,
//                                 children: [
//                                   Text(
//                                     'AMOUNT PENDING TO PAY: € ${_order.balance.toStringAsFixed(2)}',
//                                     style: const TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         color: Color.fromARGB(255, 255, 0, 0),
//                                         fontSize: 12),
//                                   ),
//                                 ],
//                               ),
//                             )
//                           ],
//                           Container(
//                             margin: const EdgeInsets.symmetric(vertical: 10),
//                             height: 1,
//                             width: double.infinity,
//                             color: Colors.white,
//                           ),
//                            // --- MODIFIED: Customer display is now dynamic ---
//                           // Row(
//                           //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           //   children: [
//                           //     Expanded(
//                           //       child: Text(
//                           //         'Customer: ${_selectedCustomer?['loy_custx_name'] ?? '--'}',
//                           //         style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
//                           //         overflow: TextOverflow.ellipsis,
//                           //       ),
//                           //     ),
//                           //     if (_selectedCustomer != null)
//                           //       SizedBox(
//                           //         height: 24,
//                           //         width: 24,
//                           //         child: IconButton(
//                           //           padding: EdgeInsets.zero,
//                           //           icon: const Icon(Icons.close, color: Colors.red, size: 16),
//                           //           onPressed: () {
//                           //             setState(() {
//                           //               _selectedCustomer = null;
//                           //               _client.clientName = '';
//                           //               _client.clientNum = '';
//                           //               _customerMobileController.clear();
//                           //             });
//                           //           },
//                           //         ),
//                           //       )
//                           //   ],
//                           // ),

//                                                   Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                           children: [
//                             Expanded(
//                               child: TextButton(
//                                 style: TextButton.styleFrom(
//                                   foregroundColor: Colors.transparent,
//                                   padding: const EdgeInsets.fromLTRB(1, 1, 1, 1),
//                                   backgroundColor: Colors.transparent,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(10),
//                                   ),
//                                 ),
//                                 child: FittedBox(
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Text(
//                                         'Customer: ${_selectedCustomer?['loy_custx_name'] ?? '--'}',
//                                         style: const TextStyle(
//                                           color: Colors.blue,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 12,
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                       if (_selectedCustomer != null)
//                                         IconButton(
//                                 padding: EdgeInsets.zero,
//                                 icon: const Icon(Icons.close, color: Colors.red, size: 16),
//                                 onPressed: () {
//                                   setState(() {
//                                     _selectedCustomer = null;
//                                     _client.clientName = '';
//                                     _client.clientNum = '';
//                                     _customerMobileController.clear();
//                                   });
//                                 },
//                               ),
//                                     ],
//                                   ),
//                                 ),
//                                 onPressed: () {
//                                   // You can open a dialog with customer details
//                                 },
//                               ),
//                             ),    
//                           ],
//                         ),
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 'Balance Points: ${_selectedCustomer?['loy_custx_points'] ?? 0}',
//                                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
//                               ),
//                               Text(
//                                 'Shopping Points: ${_selectedCustomer?['loy_custx_balance'] ?? 0}',
//                                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10),
//                               ),
//                             ],
//                           ),
//                           // ----------------------------------------------------
//                           // const Spacer(),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // const Spacer(), //optional
//           // bottom row =>  payment buttons | free space
//           SizedBox(
//             height: 60, // Adjust the height of the bottom row as you need
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Expanded(
//                   flex: 10,
//                   child: Padding(
//                     padding: const EdgeInsets.all(5.0),
//                     child: ListView(
//                       scrollDirection: Axis.horizontal,
//                       children: [
//                         // Evaluate if the payment method is enabled

//                         PaymentButton(
//                             buttonText: 'Cash',
//                             buttonColor: const Color.fromARGB(255, 36, 87, 5),
//                             action:() {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('1');
//                                     }},),

//                         PaymentButton(
//                             buttonText: 'Card\nBOV',
//                             buttonColor: const Color.fromARGB(255, 132, 3, 3),
//                             action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('7');
//                                     }},),


//                         if (enabledPaymentMethods.contains('2'))
//                           PaymentButton(
//                               buttonText: 'Cheque\nBOV',
//                               buttonColor: const Color.fromARGB(255, 4, 12, 125),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('2');
//                                     }},),


//                         if (enabledPaymentMethods.contains('8'))
//                           PaymentButton(
//                               buttonText: 'Other\nCheque',
//                               buttonColor: const Color.fromARGB(255, 4, 12, 125),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('8');
//                                     }},),


//                         if (enabledPaymentMethods.contains('10'))
//                           PaymentButton(
//                               buttonText: 'Staff\nVoucher',
//                               buttonColor: const Color.fromARGB(255, 105, 110, 10),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('10');
//                                     }},),


//                         if (enabledPaymentMethods.contains('9'))
//                           PaymentButton(
//                               buttonText: 'Gift\nCard',
//                               buttonColor: const Color.fromARGB(255, 105, 110, 10),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('9');
//                                     }},),


//                         if (enabledPaymentMethods.contains('12'))
//                           PaymentButton(
//                               buttonText: 'Stripe',
//                               buttonColor: const Color.fromARGB(255, 13, 87, 123),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('12');
//                                     }},),


//                         if (enabledPaymentMethods.contains('3'))
//                           PaymentButton(
//                               buttonText: 'On\nAccount',
//                               buttonColor: const Color.fromARGB(255, 73, 5, 69),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('3');
//                                     }},),


//                         if (enabledPaymentMethods.contains('13'))
//                           PaymentButton(
//                               buttonText: 'Bank\nTransfer',
//                               buttonColor: const Color.fromARGB(255, 7, 148, 117),
//                               action: () {
//                                   if (_isCustomerSelected()) {
//                                     _handleOrder('13');
//                                     }},),


//                         if (enabledPaymentMethods.contains('4'))
//                           PaymentButton(
//                               buttonText: 'Loyalty\nRedem',
//                               buttonColor: const Color.fromARGB(255, 139, 62, 4),
//                               action:
//                               // () {}),
//                                () => _handleLoyaltyRedeem()),

//                         // You can add more conditions here for other buttons if needed
//                         PaymentButton(
//                             buttonText: 'Cancel',
//                             buttonColor: const Color.fromARGB(255, 223, 10, 10),
//                             action: () => _clearOrder('Message', 'Order Cancel', saveTxn: true)),

//                         // // You can add more conditions here for other buttons if needed
//                         // PaymentButton(
//                         //     buttonText: 'Cancel',
//                         //     buttonColor: const Color.fromARGB(255, 223, 10, 10),
//                         //     action: () => _clearOrder('Message', 'Order Cancel', saveTxn: true)),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const Expanded(
//                   flex: 0,
//                   child: Padding(
//                     padding: EdgeInsets.all(5.0),
//                     child: Column(
//                       children: [],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }


// class DialogLoyaltyRedeem {
//   final TextEditingController _pointsController = TextEditingController();

//   Future<double?> showDialogBox({
//     required BuildContext context,
//     required double availablePoints,
//     required double maxRedeemableAmount,
//   }) {
//     _pointsController.clear();
//     return showDialog<double?>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: const Text('Redeem Loyalty Points'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Available Points:',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                     Text(
//                       availablePoints.toStringAsFixed(0),
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 10),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       'Max Redemption Limit:',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                     Text(
//                       '€${maxRedeemableAmount.toStringAsFixed(2)}',
//                       style:
//                           TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 20),
//                 TextField(
//                   controller: _pointsController,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     labelText: 'Enter points to redeem',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop(null); // Return null
//               },
//             ),
//             ElevatedButton(
//               child: const Text('OK'),
//               onPressed: () {
//                 final double? enteredPoints =
//                     double.tryParse(_pointsController.text);
                
//                 if (enteredPoints == null || enteredPoints <= 0) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                         content: Text('Please enter a valid amount.'),
//                         backgroundColor: Colors.red),
//                   );
//                   return;
//                 }
                
//                 if (enteredPoints > availablePoints) {
//                    ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                         content: Text('Entered points exceed available points.'),
//                         backgroundColor: Colors.red),
//                   );
//                   return;
//                 }

//                 if (enteredPoints > maxRedeemableAmount) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                         content: Text('Entered points exceed max redemption limit for this sale.'),
//                         backgroundColor: Colors.red),
//                   );
//                   return;
//                 }

//                 // Validation passed
//                 Navigator.of(dialogContext).pop(enteredPoints); // Return the amount
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }




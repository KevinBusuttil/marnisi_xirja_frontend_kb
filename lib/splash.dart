import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/helpers/marnisi_seed_users.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:logger/logger.dart';

/// Class SplashWidget
///
/// methods:
/// * [initstate] call loadData() to fetch data from Frappe.
///   * [_printAllSharedPreferences] load default printer preferences
///   * [delayed] set timer in seconds to show the splash
/// * [_printAllSharedPreferences] show a debug console with all preferences set
/// * [clearSharedPreferences] call this method to clean all shared prefences
/// * [_loadUsers] check if the app has setted an endpoint to fetch data, if not, create a temporal user 11111
///                * this method call all endpoints to fetch the data after the user set the URL
///                * update, delete, an create users
/// * [_loadItems,_loadStores,_loadRegisters, _loadPayMthds,_loadLoyCust] update, delete, and create info according to the fetched information
/// * [_calculateHash] create hash to comparate fields

class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    loadData();
    _printAllSharedPreferences();
    //splash load
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        GoRouter.of(context).go(RouteUri.login);
      }
    });
  }

  final logger = Logger(printer: PrettyPrinter());
  // logger.d("Debug message");
  // logger.i("Info message");
  // logger.w("Warning message");
  // logger.e("Error message");
  // logger.v("Verbose message");

  Future<void> loadData() async {
    log("hferi");
    _loadUsers(context);
  }

  //************************************************** */
  //print all shared preferences
  //************************************************* */
  Future<void> _printAllSharedPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> keys = prefs.getKeys();

    // print(prefs.getInt('startTime'));
    //print all shared keys
    for (String key in keys) {
      final value = prefs.get(key);
      logger.t('$key: $value');
    }
  }

  //clear preferences
  Future<void> clearSharedPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      _showSnackBar(context, 'No data detected; Updating data...',
          withConfirmation: false);
    }
  }

  //******************************** */
  //FETCH USERS FROM FRAPPE
  //******************************** */

  Future<void> _loadUsers(BuildContext context) async {
    final ApiService apiHelperGetUsers =
        ApiService(endpointPath: ApiRoutes.getUsers);

    final SqlLiteService dbHelper = SqlLiteService();
    final db = await dbHelper.database;

    try {
      //logger.d("Database initialized");

      //check if exist users in the db
      List<Map<String, dynamic>> existingUsers =
          await db.query('users', columns: ['user_personnel_id']);

      if (existingUsers.isEmpty) {
        clearSharedPreferences();
        // if no users exist, seed fallback personal IDs for offline login
        for (final user in marnisiSeedUsers) {
          await db.insert('users', user.toLocalDbRow());
        }

        //logger.d('Inserted test user into database because no users were found');

        await db.insert('stores', {
          'stores_id': MarnisiPosRestrictions.lockedStoreId,
          'stores_contact_address': 'address',
          'stores_contact': 'contact',
          'stores_invent_id': MarnisiPosRestrictions.lockedStoreId,
          'stores_invent_location': 'local',
          'stores_loyalty_enabled': 1,
          'stores_loyalty_allow_earn': 1,
          'stores_loyalty_allow_redeem': 1,
          'stores_loyalty_show_customer_ui': 1,
          'stores_loyalty_show_points_ui': 1,
          'stores_loyalty_show_receipt_details': 1,
        });

        //  logger.d('Inserted test store into database because no users were found');

        await db.insert('registers', {
          'registers_id': MarnisiPosRestrictions.lockedRegisterId,
          'registers_name': 'Main Register',
          'registers_store_id': MarnisiPosRestrictions.lockedStoreId,
        });
        // Keep syncing remote data if backend is reachable; fallback rows remain
        // only when network/API is unavailable.
        existingUsers = await db.query('users', columns: ['user_personnel_id']);
        // logger.d('Inserted test register into database because no users were found');
      }
      // logger.d('Fetching users data...');
      await Future.wait([
        _loadItems(),
        _loadStores(),
        _loadRegisters(),
        _loadPayMthds(),
      ]);
      // _loadLoyCust();

      Map<String, dynamic> data = await apiHelperGetUsers.fetchData();
      List<dynamic> message = data['message'];

      //get all ids available
      Set<String> existingUsersIds = existingUsers
          .map((item) => item['user_personnel_id'].toString())
          .toSet();

      await db.transaction((txn) async {
        Set<String> receivedUsersIds = {};

        for (var item in message) {
          String userId = item['retail_personnel_id'].toString();
          receivedUsersIds.add(userId);

          List<Map<String, dynamic>> existingUsers = await txn.query(
            'users',
            where: 'user_personnel_id = ?',
            whereArgs: [item['retail_personnel_id']],
          );

          if (existingUsers.isNotEmpty) {
            var existingUser = existingUsers.first;

            if (existingUser['user_group'] != item['retail_user_group'] ||
                existingUser['user_first_name'] !=
                    item['retail_user_first_name'] ||
                existingUser['user_last_name'] !=
                    item['retail_user_last_name'] ||
                existingUser['user_email'] != item['retail_user_email']) {
              await txn.update(
                'users',
                {
                  'user_group': item['retail_user_group'],
                  'user_email': item['retail_user_email'],
                  'user_first_name': item['retail_user_first_name'],
                  'user_last_name': item['retail_user_last_name']
                },
                where: 'user_personnel_id = ?',
                whereArgs: [item['retail_personnel_id']],
              );
            }
          } else {
            await txn.insert('users', {
              'user_personnel_id': item['retail_personnel_id'] ?? '',
              'user_group': item['retail_user_group'] ?? '',
              'user_email': item['retail_user_email'] ?? '',
              'user_first_name': item['retail_user_first_name'] ?? '',
              'user_last_name': item['retail_user_last_name'] ?? '',
            });
          }
        }

        // remove delete items
        for (String itemId in existingUsersIds) {
          if (!receivedUsersIds.contains(itemId)) {
            await txn.delete(
              'users',
              where: 'user_personnel_id = ?',
              whereArgs: [itemId],
            );
          }
        }
      });

      // logger.d('Users insert/update ok');
    } catch (e, stackTrace) {
      // logger.e('Error loading data: $e');
      logger.d(stackTrace);
    }
  }

  //******************************** */
  //FETCH CUSTOMERS FROM FRAPPE
  //******************************** */

//   Future<void> _loadLoyCust() async {
//     final ApiService apiGetLoyCust = ApiService(endpointPath: ApiRoutes.getLoyUsers);
//     final SqlLiteService dbHelper = SqlLiteService();
//     final db = await dbHelper.database;

//     try {
//       logger.d("Get Loyalty customers");

//       // Fetch existing local users
//       List<Map<String, dynamic>> existingCust =
//           await db.query('loy_custx', columns: ['loy_custx_id', 'loy_custx_sync_frappe']);

//       // Fetch remote users
//       Map<String, dynamic> data = await apiGetLoyCust.fetchData();
//       List<dynamic> message = data['message'];

//       // Get remote IDs and local IDs
//       Set<String> remoteCustIds = message.map((item) => item['loy_cust_id'].toString()).toSet();
//       Set<String> localCustIds = existingCust.map((item) => item['loy_custx_id'].toString()).toSet();

//       await db.transaction((txn) async {
//         Set<String> receivedCustsIds = {};

//         // Process remote data
//         for (var item in message) {
//           String custId = item['loy_cust_id'].toString();
//           receivedCustsIds.add(custId);

//           List<Map<String, dynamic>> existingCusts = await txn.query(
//             'loy_custx',
//             where: 'loy_custx_id = ?',
//             whereArgs: [custId],
//           );

//           // Calculate hashes
//           String newHash = _calculateHash(item);
//           String existingHash = existingCusts.isNotEmpty ? _calculateHash(existingCusts.first) : '';

//           if (existingCusts.isNotEmpty && existingHash != newHash) {
//             // Update only if hashes differ
//             await txn.update(
//               'loy_custx',
//               {
//                // 'loy_custx_id': item['loy_cust_id'],
//                 'loy_custx_card_num': item['loy_cust_card_num'] ?? item['loy_cust_id'],
//                // 'loy_custx_type': item['loy_cust_cust_type'] ?? '',
//                 'loy_custx_first_name': item['loy_cust_first_name'] ?? '',
//                 'loy_custx_last_name': item['loy_cust_last_name'] ?? '',
//                // 'loy_custx_name': item['loy_cust_name'] ?? '',
//                 'loy_custx_email': item['loy_cust_email'] ?? '',
//                 'loy_custx_address': item['loy_cust_primary_address'] ?? '',
//                 'loy_custx_city': item['loy_cust_city'] ?? '',
//                 'loy_custx_mobile': item['loy_cust_mobile'] ?? '',
//                 'loy_custx_balance': item['loy_cust_balance'] ?? '',
//                 'loy_custx_points': item['loy_cust_points'] ?? '',
//                 'loy_custx_scheme': item['loy_cust_scheme'] ?? '',
//                // 'loy_custx_group': item['loy_cust_group'] ?? '',
//                 'loy_custx_frozen': item['loy_cust_frozen'] ?? 0,
//              //   'loy_custx_sync_frappe': 'synchronized'
//               },
//               where: 'loy_custx_id = ?',
//               whereArgs: [custId],
//             );
//           } else if (existingCusts.isEmpty) {
//             // Insert new record
//             await txn.insert('loy_custx', {
//             //  'loy_custx_id': item['loy_cust_id'],
//               'loy_custx_card_num': item['loy_cust_card_num'] ?? item['loy_cust_id'],
//             //  'loy_custx_type': item['loy_cust_cust_type'] ?? '',
//               'loy_custx_first_name': item['loy_cust_first_name'] ?? '',
//               'loy_custx_last_name': item['loy_cust_last_name'] ?? '',
//            //   'loy_custx_name': item['loy_cust_name'] ?? '',
//               'loy_custx_email': item['loy_cust_email'] ?? '',
//               'loy_custx_address': item['loy_cust_primary_address'] ?? '',
//               'loy_custx_city': item['loy_cust_city'] ?? '',
//               'loy_custx_mobile': item['loy_cust_mobile'] ?? '',
//               'loy_custx_balance': item['loy_cust_balance'] ?? '',
//               'loy_custx_points': item['loy_cust_points'] ?? '',
//               'loy_custx_scheme': item['loy_cust_scheme'] ?? '',
//              // 'loy_custx_group': item['loy_cust_group'] ?? '',
//               'loy_custx_frozen': item['loy_cust_frozen'] ?? 0,
//            //   'loy_custx_sync_frappe': 'synchronized'
//             });
//           }
//         }

//         // Sync unsynchronized local items
//         // for (var item in existingCust) {
//         //   if (item['loy_custx_sync_frappe'] != 'synchronized') {
//         //     // Sync item with remote server
//         //     bool syncSuccess = await apiGetLoyCust.syncLocalCustomer(item);
//         //     final ApiService apiGetLoyCust = ApiService(endpointPath: ApiRoutes.getLoyUsers);

//         //     if (syncSuccess) {
//         //       // Mark as synchronized if successful
//         //       await txn.update(
//         //         'loy_custx',
//         //         {'loy_custx_sync_frappe': 'synchronized'},
//         //         where: 'loy_custx_id = ?',
//         //         whereArgs: [item['loy_custx_id']],
//         //       );
//         //     }
//         //   }
//         // }

//         // Identify local IDs missing on the remote server
//         Set<String> missingCustIds = localCustIds.difference(remoteCustIds);

//         // Handle missing IDs
//         for (String itemId in missingCustIds) {
//           var localItem = existingCust.firstWhere((item) => item['loy_custx_id'] == itemId);

//           if (localItem['loy_custx_sync_frappe'] == 'synchronized') {
//             // Delete synchronized records missing in remote
//             await txn.delete(
//               'loy_custx',
//               where: 'loy_custx_id = ?',
//               whereArgs: [itemId],
//             );
//           }
//         }
//       });

//       logger.d('Customers insert/update ok');
//     } catch (e, stackTrace) {
//       logger.e('Error loading data: $e');
//       logger.d(stackTrace);
//     }
//   }

// // Function to calculate hash
//   String _calculateHash(Map<String, dynamic> data) {
//     return data.entries
//         .where((entry) => entry.value != null) // Ignore null values
//         .map((entry) => '${entry.key}:${entry.value}')
//         .join('|');
//   }

  //******************************** */
  //FETCH ITEMS FROM FRAPPE
  //******************************** */

  Future<void> _loadItems() async {
    final SqlLiteService dbHelper = SqlLiteService();
    final ApiService apiHelperGetProducts =
        ApiService(endpointPath: ApiRoutes.getProducts);

    final db = await dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final apiBaseUrl = (prefs.getString(StorageKeys.apiBaseUrl) ??
            prefs.getString('apiBaseUrl') ??
            '')
        .trim();

    try {
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

          // always refresh supplementary rows to avoid stale deposits
          await txn.delete(
            'supp_items',
            where: 'supp_parent_id = ?',
            whereArgs: [itemId],
          );

          // insert fresh supplementary rows, if any
          if (item['item_suppItems'] != null &&
              item['item_suppItems'].isNotEmpty) {
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

      // logger.d('Items and suppItems insert/update/delete ok');
    } catch (e, stackTrace) {
      //logger.e('Error loading data: $e');
      logger.d(stackTrace);
    }
  }

  //******************************** */
  //FETCH STORES FROM FRAPPE
  //******************************** */

  Future<void> _loadStores() async {
    final SqlLiteService dbHelper = SqlLiteService();
    final ApiService apiHelperGetStores =
        ApiService(endpointPath: ApiRoutes.getStores);
    final db = await dbHelper.database;
    try {
      // Fetch data from the API
      Map<String, dynamic> data = await apiHelperGetStores.fetchData();
      List<dynamic> message = data['message'];

      // Get all store IDs from the current local db
      List<Map<String, dynamic>> existingStores =
          await db.query('stores', columns: ['stores_id']);
      Set<String> existingStoreIds =
          existingStores.map((store) => store['stores_id'].toString()).toSet();

      await db.transaction((txn) async {
        Set<String> receivedStoreIds = {};

        for (var item in message) {
          String storeId = item['store_id'].toString();
          receivedStoreIds.add(storeId);

          // Check if the store already exists in the 'stores' table
          List<Map<String, dynamic>> existingStore = await txn.query(
            'stores',
            where: 'stores_id = ?',
            whereArgs: [storeId],
          );

          // Update store if necessary
          if (existingStore.isNotEmpty) {
            var store = existingStore.first;

            if (store['stores_name'] != item['store_name'] ||
                store['stores_address'] != item['store_address'] ||
                store['stores_country'] != item['store_country'] ||
                store['stores_phone_num'] != item['store_phone_num'] ||
                store['stores_registration_num'] !=
                    item['store_registration_num'] ||
                store['stores_channel_type'] != item['store_channel_type'] ||
                store['stores_legal_entity'] != item['store_legal_entity'] ||
                store['stores_vat_group'] != item['store_vat_group'] ||
                store['stores_default_customer'] !=
                    item['store_default_customer'] ||
                store['stores_contact_address'] !=
                    item['store_contact_address'] ||
                store['stores_contact'] != item['store_contact'] ||
                store['stores_invent_location'] !=
                    item['store_invent_location_id'] ||
                store['stores_bcrs_code'] != item['store_bcrs_code'] ||
                store['stores_opening_hours'] != item['store_opening_hours'] ||
                store['stores_loyalty_enabled'] !=
                    item['store_loyalty_enabled'] ||
                store['stores_loyalty_allow_earn'] !=
                    item['store_loyalty_allow_earn'] ||
                store['stores_loyalty_allow_redeem'] !=
                    item['store_loyalty_allow_redeem'] ||
                store['stores_loyalty_show_customer_ui'] !=
                    item['store_loyalty_show_customer_ui'] ||
                store['stores_loyalty_show_points_ui'] !=
                    item['store_loyalty_show_points_ui'] ||
                store['stores_loyalty_show_receipt_details'] !=
                    item['store_loyalty_show_receipt_details']) {
              await txn.update(
                'stores',
                {
                  'stores_name': item['store_name'],
                  'stores_address': item['store_address'],
                  'stores_country': item['store_country'],
                  'stores_phone_num': item['store_phone_num'],
                  'stores_registration_num': item['store_registration_num'],
                  'stores_channel_type': item['store_channel_type'],
                  'stores_legal_entity': item['store_legal_entity'],
                  'stores_vat_group': item['store_vat_group'],
                  'stores_default_customer': item['store_default_customer'],
                  'stores_contact_address': item['store_contact_address'],
                  'stores_contact': item['store_contact'],
                  'stores_invent_location': item['store_invent_location_id'],
                  'stores_bcrs_code': item['store_bcrs_code'],
                  'stores_opening_hours': item['store_opening_hours'],
                  'stores_loyalty_enabled': item['store_loyalty_enabled'] ?? 1,
                  'stores_loyalty_allow_earn':
                      item['store_loyalty_allow_earn'] ?? 1,
                  'stores_loyalty_allow_redeem':
                      item['store_loyalty_allow_redeem'] ?? 1,
                  'stores_loyalty_show_customer_ui':
                      item['store_loyalty_show_customer_ui'] ?? 1,
                  'stores_loyalty_show_points_ui':
                      item['store_loyalty_show_points_ui'] ?? 1,
                  'stores_loyalty_show_receipt_details':
                      item['store_loyalty_show_receipt_details'] ?? 1,
                },
                where: 'stores_id = ?',
                whereArgs: [storeId],
              );
            }
          } else {
            // Insert new store if it doesn't exist
            await txn.insert('stores', {
              'stores_id': storeId,
              'stores_name': item['store_name'] ?? '',
              'stores_address': item['store_address'] ?? '',
              'stores_country': item['store_country'] ?? '',
              'stores_phone_num': item['store_phone_num'] ?? '',
              'stores_registration_num': item['store_registration_num'] ?? '',
              'stores_channel_type': item['store_channel_type'] ?? '',
              'stores_legal_entity': item['store_legal_entity'] ?? '',
              'stores_vat_group': item['store_vat_group'] ?? '',
              'stores_default_customer': item['store_default_customer'] ?? '',
              'stores_contact_address': item['store_contact_address'] ?? '',
              'stores_contact': item['store_contact'] ?? '',
              'stores_invent_location': item['store_invent_location_id'] ?? '',
              'stores_bcrs_code': item['store_bcrs_code'] ?? '',
              'stores_opening_hours': item['store_opening_hours'] ?? '',
              'stores_loyalty_enabled': item['store_loyalty_enabled'] ?? 1,
              'stores_loyalty_allow_earn':
                  item['store_loyalty_allow_earn'] ?? 1,
              'stores_loyalty_allow_redeem':
                  item['store_loyalty_allow_redeem'] ?? 1,
              'stores_loyalty_show_customer_ui':
                  item['store_loyalty_show_customer_ui'] ?? 1,
              'stores_loyalty_show_points_ui':
                  item['store_loyalty_show_points_ui'] ?? 1,
              'stores_loyalty_show_receipt_details':
                  item['store_loyalty_show_receipt_details'] ?? 1,
            });
          }

          // Handle the payment methods for this store (store_py_mthds_ava)
          List<dynamic> paymentMethodIds =
              item['store_py_mthds_ava']; // List of payment method IDs
          logger.d('Payment methods for store $storeId: $paymentMethodIds');

          // Get existing payment methods for this store
          List<Map<String, dynamic>> existingPaymentMethods = await txn.query(
            'stores_py_ava',
            where: 'stores_py_id = ?',
            whereArgs: [storeId],
          );
          logger.d(
              'Existing payment methods for store $storeId: $existingPaymentMethods');

          // Check for changes in existing methods or new methods
          for (var paymentMethodId in paymentMethodIds) {
            String paymentMethodIdStr = paymentMethodId.toString();

            // Check if the payment method already exists for this store
            List<Map<String, dynamic>> existingPaymentMethod = await txn.query(
              'stores_py_ava',
              where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
              whereArgs: [storeId, paymentMethodIdStr],
            );

            if (existingPaymentMethod.isEmpty) {
              // If payment method doesn't exist, insert it
              await txn.insert('stores_py_ava', {
                'stores_py_id': storeId,
                'stores_py_ava_mthd_id': paymentMethodIdStr,
              });
            } else {
              // If payment method exists and name or other details are different, update it
              await txn.update(
                'stores_py_ava',
                {
                  'stores_py_ava_mthd_id':
                      '$paymentMethodId', // Update the name or any field if needed
                },
                where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
                whereArgs: [storeId, paymentMethodIdStr],
              );
            }
          }

          //Delete payment methods that are no longer present in the received data
          for (var existingPaymentMethod in existingPaymentMethods) {
            String paymentMethodId =
                existingPaymentMethod['stores_py_ava_mthd_id'].toString();

            // If the payment method is no longer in the received list, delete it
            if (!paymentMethodIds.contains(paymentMethodId)) {
              await txn.delete(
                'stores_py_ava',
                where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
                whereArgs: [storeId, paymentMethodId],
              );
            }
          }
        }

        // Remove deleted stores if necessary
        for (String storeId in existingStoreIds) {
          if (!receivedStoreIds.contains(storeId)) {
            await txn.delete(
              'stores',
              where: 'stores_id = ?',
              whereArgs: [storeId],
            );

            // Optionally, delete payment methods for this store
            // await txn.delete(
            //   'stores_py_ava',
            //   where: 'stores_py_id = ?',
            //   whereArgs: [storeId],
            // );
          }
        }
      });

      logger.d('Stores and payment methods insert/update/delete ok');
    } catch (e, stackTrace) {
      logger.d('Error loading data: $e');
      logger.d(stackTrace);
    }
  }

  //******************************** */
  //FETCH REGISTER FROM FRAPPE
  //******************************** */

  Future<void> _loadRegisters() async {
    final SqlLiteService dbHelper = SqlLiteService();
    final ApiService apiHelperGetRegisters =
        ApiService(endpointPath: ApiRoutes.getRegisters);
    final db = await dbHelper.database;
    try {
      // Fetch data from the API
      // logger.d('Fetching registers data...');
      Map<String, dynamic> data = await apiHelperGetRegisters.fetchData();
      List<dynamic> message = data['message'];

      // logger.d("Database initialized");

      // get all id's from the current local db
      List<Map<String, dynamic>> existingRegisters =
          await db.query('registers', columns: ['registers_id']);
      Set<String> existingRegisterIds = existingRegisters
          .map((register) => register['registers_id'].toString())
          .toSet();

      await db.transaction((txn) async {
        Set<String> receivedRegisterIds = {};

        //check the item exists
        for (var item in message) {
          String registerId = item['register_id'].toString();
          receivedRegisterIds.add(registerId);

          List<Map<String, dynamic>> existingRegister = await txn.query(
            'registers',
            where: 'registers_id = ?',
            whereArgs: [registerId],
          );

          if (existingRegister.isNotEmpty) {
            var register = existingRegister.first;

            if (register['registers_id'] != item['register_id'] ||
                register['registers_name'] != item['register_name'] ||
                register['registers_store_id'] != item['store_id']) {
              await txn.update(
                'registers',
                {
                  'registers_id': item['register_id'],
                  'registers_name': item['register_name'],
                  'registers_store_id': item['store_id'],
                },
                where: 'registers_id = ?',
                whereArgs: [registerId],
              );
            }
          } else {
            //insert new items
            await txn.insert('registers', {
              'registers_id': registerId,
              'registers_name': item['register_name'] ?? '',
              'registers_store_id': item['store_id'] ?? '',
            });
          }
        }

        // Check items deleted
        for (String registerId in existingRegisterIds) {
          if (!receivedRegisterIds.contains(registerId)) {
            await txn.delete(
              'registers',
              where: 'registers_id = ?',
              whereArgs: [registerId],
            );
          }
        }
      });

      // logger.d('Registers insert/update/delete ok');
    } catch (e, stackTrace) {
      logger.e('Error loading data: $e');
      logger.d(stackTrace);
    }
  }

  //******************************** */
  //FETCH PAYMETHODS
  //******************************** */

  Future<void> _loadPayMthds() async {
    final SqlLiteService dbHelper = SqlLiteService();
    final ApiService apiHelperGetPayMthds =
        ApiService(endpointPath: ApiRoutes.getPayMthds);
    final db = await dbHelper.database;
    try {
      // Fetch data from the API
      Map<String, dynamic> data = await apiHelperGetPayMthds.fetchData();
      List<dynamic> message = data['message'];

      // logger.d("Database initialized");

      // get all id's from the current local db
      List<Map<String, dynamic>> existingPayMthds =
          await db.query('pay_mthds', columns: ['pay_mthds_id']);
      Set<String> existingPayMthdsIds = existingPayMthds
          .map((payMthd) => payMthd['pay_mthds_id'].toString())
          .toSet();

      await db.transaction((txn) async {
        Set<String> receivedPayMthdsIds = {};

        for (var item in message) {
          String payMthdId = item['payment_type_id'].toString();
          receivedPayMthdsIds.add(payMthdId);

          //check the item exists
          List<Map<String, dynamic>> existingPayMthd = await txn.query(
            'pay_mthds',
            where: 'pay_mthds_id = ?',
            whereArgs: [payMthdId],
          );

          if (existingPayMthd.isNotEmpty) {
            var payMthd = existingPayMthd.first;

            //update items if is necessary
            if (payMthd['pay_mthds_id'] != item['payment_type_id'] ||
                payMthd['pay_mthds_name'] != item['payment_type_name']) {
              await txn.update(
                'pay_mthds',
                {
                  'pay_mthds_id': item['payment_type_id'],
                  'pay_mthds_name': item['payment_type_name'],
                },
                where: 'pay_mthds_id = ?',
                whereArgs: [payMthdId],
              );
            }
          } else {
            //insert new items
            await txn.insert('pay_mthds', {
              'pay_mthds_id': payMthdId,
              'pay_mthds_name': item['payment_type_name'] ?? '',
            });
          }
        }

        // Check items deleted
        for (String payMthdId in existingPayMthdsIds) {
          if (!receivedPayMthdsIds.contains(payMthdId)) {
            await txn.delete(
              'pay_mthds',
              where: 'pay_mthds_id = ?',
              whereArgs: [payMthdId],
            );
          }
        }
      });

      // logger.d('Pay Methods insert/update/delete ok');
    } catch (e, stackTrace) {
      // logger.e('Error loading data: $e');
      logger.d(stackTrace);
    }
  }

  //message snackbar
  void _showSnackBar(BuildContext context, String message,
      {bool withConfirmation = false}) {
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

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.fromARGB(255, 71, 1, 1),
            Color.fromARGB(255, 124, 13, 24)
          ]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.white,
                fontSize: 32,
              ),
            ),
            const SizedBox(
                height: 20), // Agrega espacio entre el texto y la imagen
            SvgPicture.asset(
              'assets/images/CassarCamilleriLogo.svg',
              height: 300.0,
            ),
          ],
        ),
      ),
    );
  }
}

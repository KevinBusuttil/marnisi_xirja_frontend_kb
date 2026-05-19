import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/helpers/marnisi_seed_users.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:web_admin/services/database_service.dart';

class StartupSyncService {
  final SqlLiteService _dbHelper;
  final Logger _logger;

  StartupSyncService({
    SqlLiteService? dbHelper,
    Logger? logger,
  })  : _dbHelper = dbHelper ?? SqlLiteService(),
        _logger = logger ?? Logger(printer: PrettyPrinter());

  Future<void> syncAllData() async {
    try {
      final db = await _dbHelper.database;
      await _ensureFallbackSeedData(db);

      await Future.wait([
        _syncItems(),
        _syncStores(),
        _syncRegisters(),
        _syncPaymentMethods(),
      ]);
      await _syncUsers();
    } catch (e, stackTrace) {
      _logger.e('Startup master sync failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _ensureFallbackSeedData(Database db) async {
    final existingUsers =
        await db.query('users', columns: ['user_personnel_id'], limit: 1);
    if (existingUsers.isNotEmpty) return;

    for (final user in marnisiSeedUsers) {
      await db.insert('users', user.toLocalDbRow());
    }

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

    await db.insert('registers', {
      'registers_id': MarnisiPosRestrictions.lockedRegisterId,
      'registers_name': 'Main Register',
      'registers_store_id': MarnisiPosRestrictions.lockedStoreId,
    });
  }

  Future<void> _syncUsers() async {
    final api = ApiService(endpointPath: ApiRoutes.getUsers);
    final db = await _dbHelper.database;

    final data = await api.fetchData();
    final message = (data['message'] as List?) ?? const [];

    final existingUsers =
        await db.query('users', columns: ['user_personnel_id']);
    final existingIds =
        existingUsers.map((e) => e['user_personnel_id'].toString()).toSet();

    await db.transaction((txn) async {
      final receivedIds = <String>{};

      for (final dynamic rawItem in message) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final userId = item['retail_personnel_id'].toString();
        receivedIds.add(userId);

        final existing = await txn.query(
          'users',
          where: 'user_personnel_id = ?',
          whereArgs: [item['retail_personnel_id']],
        );

        if (existing.isNotEmpty) {
          final current = existing.first;
          if (current['user_group'] != item['retail_user_group'] ||
              current['user_first_name'] != item['retail_user_first_name'] ||
              current['user_last_name'] != item['retail_user_last_name'] ||
              current['user_email'] != item['retail_user_email']) {
            await txn.update(
              'users',
              {
                'user_group': item['retail_user_group'],
                'user_email': item['retail_user_email'],
                'user_first_name': item['retail_user_first_name'],
                'user_last_name': item['retail_user_last_name'],
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

      for (final userId in existingIds) {
        if (!receivedIds.contains(userId)) {
          await txn.delete(
            'users',
            where: 'user_personnel_id = ?',
            whereArgs: [userId],
          );
        }
      }
    });
  }

  Future<void> _syncItems() async {
    final api = ApiService(endpointPath: ApiRoutes.getProducts);
    final db = await _dbHelper.database;
    final prefs = await SharedPreferences.getInstance();
    final apiBaseUrl = (prefs.getString(StorageKeys.apiBaseUrl) ??
            prefs.getString('apiBaseUrl') ??
            '')
        .trim();

    final data = await api.fetchData();
    final message = (data['message'] as List?) ?? const [];

    final existingItems = await db.query('items', columns: ['item_id']);
    final existingItemIds =
        existingItems.map((item) => item['item_id'].toString()).toSet();

    await db.transaction((txn) async {
      final receivedItemIds = <String>{};

      for (final dynamic rawItem in message) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final itemId = item['item_id'].toString();
        receivedItemIds.add(itemId);
        final resolvedImagePath = MarnisiImageHelper.resolveItemImagePath(
          rawPath: (item['item_img_path'] ?? '').toString(),
          apiBaseUrl: apiBaseUrl,
        );

        final existing = await txn.query(
          'items',
          where: 'item_id = ?',
          whereArgs: [itemId],
        );

        if (existing.isNotEmpty) {
          final current = existing.first;
          if (current['item_img'] != resolvedImagePath ||
              current['item_store'] != item['item_store'] ||
              current['item_brand'] != item['item_brand'] ||
              current['item_description'] != item['item_description'] ||
              current['item_barcode'] != item['item_barcode'] ||
              current['item_name'] != item['item_name'] ||
              current['item_qty'] != item['item_qty'] ||
              current['item_price'] != item['item_price'] ||
              current['item_category'] != item['item_category'] ||
              current['item_unit'] != item['item_unit'] ||
              current['item_tax_group'] != item['item_tax_group'] ||
              current['item_tax_pct'] != item['item_tax_pct']) {
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
                'item_tax_pct': item['item_tax_pct'],
              },
              where: 'item_id = ?',
              whereArgs: [itemId],
            );
          }
        } else {
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

        await txn.delete(
          'supp_items',
          where: 'supp_parent_id = ?',
          whereArgs: [itemId],
        );

        final supplementary = item['item_suppItems'];
        if (supplementary is List) {
          for (final dynamic rawSupp in supplementary) {
            if (rawSupp is! Map) continue;
            final supp = rawSupp.cast<String, dynamic>();
            await txn.insert('supp_items', {
              'supp_parent_id': itemId,
              'supp_id': supp['supp_id'] ?? '-',
              'supp_name': supp['supp_name'] ?? '-',
              'supp_qty': supp['supp_qty'] ?? 0,
              'supp_price': supp['supp_price'] ?? 0.0,
              'supp_uom': supp['supp_unit'] ?? '-',
              'supp_tax_group': supp['supp_tax_group'] ?? '-',
              'supp_tax_pct': supp['supp_tax_pct'] ?? 0.0,
            });
          }
        }
      }

      for (final itemId in existingItemIds) {
        if (!receivedItemIds.contains(itemId)) {
          await txn.delete('items', where: 'item_id = ?', whereArgs: [itemId]);
          await txn.delete(
            'supp_items',
            where: 'supp_parent_id = ?',
            whereArgs: [itemId],
          );
        }
      }
    });
  }

  Future<void> _syncStores() async {
    final api = ApiService(endpointPath: ApiRoutes.getStores);
    final db = await _dbHelper.database;

    final data = await api.fetchData();
    final message = (data['message'] as List?) ?? const [];

    final existingStores = await db.query('stores', columns: ['stores_id']);
    final existingStoreIds =
        existingStores.map((store) => store['stores_id'].toString()).toSet();

    await db.transaction((txn) async {
      final receivedStoreIds = <String>{};

      for (final dynamic rawItem in message) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final storeId = item['store_id'].toString();
        receivedStoreIds.add(storeId);

        final existingStore = await txn.query(
          'stores',
          where: 'stores_id = ?',
          whereArgs: [storeId],
        );

        if (existingStore.isNotEmpty) {
          final store = existingStore.first;
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
            'stores_loyalty_allow_earn': item['store_loyalty_allow_earn'] ?? 1,
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

        final paymentMethodIds = item['store_py_mthds_ava'] is List
            ? (item['store_py_mthds_ava'] as List)
            : const [];

        final existingPaymentMethods = await txn.query(
          'stores_py_ava',
          where: 'stores_py_id = ?',
          whereArgs: [storeId],
        );

        for (final dynamic rawPaymentMethodId in paymentMethodIds) {
          final paymentMethodIdStr = rawPaymentMethodId.toString();
          final existingPaymentMethod = await txn.query(
            'stores_py_ava',
            where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
            whereArgs: [storeId, paymentMethodIdStr],
          );

          if (existingPaymentMethod.isEmpty) {
            await txn.insert('stores_py_ava', {
              'stores_py_id': storeId,
              'stores_py_ava_mthd_id': paymentMethodIdStr,
            });
          } else {
            await txn.update(
              'stores_py_ava',
              {'stores_py_ava_mthd_id': paymentMethodIdStr},
              where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
              whereArgs: [storeId, paymentMethodIdStr],
            );
          }
        }

        for (final existingPaymentMethod in existingPaymentMethods) {
          final paymentMethodId =
              existingPaymentMethod['stores_py_ava_mthd_id'].toString();
          if (!paymentMethodIds.contains(paymentMethodId)) {
            await txn.delete(
              'stores_py_ava',
              where: 'stores_py_id = ? AND stores_py_ava_mthd_id = ?',
              whereArgs: [storeId, paymentMethodId],
            );
          }
        }
      }

      for (final storeId in existingStoreIds) {
        if (!receivedStoreIds.contains(storeId)) {
          await txn
              .delete('stores', where: 'stores_id = ?', whereArgs: [storeId]);
        }
      }
    });
  }

  Future<void> _syncRegisters() async {
    final api = ApiService(endpointPath: ApiRoutes.getRegisters);
    final db = await _dbHelper.database;

    final data = await api.fetchData();
    final message = (data['message'] as List?) ?? const [];

    final existingRegisters =
        await db.query('registers', columns: ['registers_id']);
    final existingRegisterIds = existingRegisters
        .map((register) => register['registers_id'].toString())
        .toSet();

    await db.transaction((txn) async {
      final receivedRegisterIds = <String>{};

      for (final dynamic rawItem in message) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final registerId = item['register_id'].toString();
        receivedRegisterIds.add(registerId);

        final existingRegister = await txn.query(
          'registers',
          where: 'registers_id = ?',
          whereArgs: [registerId],
        );

        if (existingRegister.isNotEmpty) {
          final register = existingRegister.first;
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
          await txn.insert('registers', {
            'registers_id': registerId,
            'registers_name': item['register_name'] ?? '',
            'registers_store_id': item['store_id'] ?? '',
          });
        }
      }

      for (final registerId in existingRegisterIds) {
        if (!receivedRegisterIds.contains(registerId)) {
          await txn.delete(
            'registers',
            where: 'registers_id = ?',
            whereArgs: [registerId],
          );
        }
      }
    });
  }

  Future<void> _syncPaymentMethods() async {
    final api = ApiService(endpointPath: ApiRoutes.getPayMthds);
    final db = await _dbHelper.database;

    final data = await api.fetchData();
    final message = (data['message'] as List?) ?? const [];

    final existingPayMethods =
        await db.query('pay_mthds', columns: ['pay_mthds_id']);
    final existingPayMethodIds =
        existingPayMethods.map((pm) => pm['pay_mthds_id'].toString()).toSet();

    await db.transaction((txn) async {
      final receivedPayMethodIds = <String>{};

      for (final dynamic rawItem in message) {
        if (rawItem is! Map) continue;
        final item = rawItem.cast<String, dynamic>();
        final payMethodId = item['payment_type_id'].toString();
        receivedPayMethodIds.add(payMethodId);

        final existingPayMethod = await txn.query(
          'pay_mthds',
          where: 'pay_mthds_id = ?',
          whereArgs: [payMethodId],
        );

        if (existingPayMethod.isNotEmpty) {
          final payMethod = existingPayMethod.first;
          if (payMethod['pay_mthds_id'] != item['payment_type_id'] ||
              payMethod['pay_mthds_name'] != item['payment_type_name']) {
            await txn.update(
              'pay_mthds',
              {
                'pay_mthds_id': item['payment_type_id'],
                'pay_mthds_name': item['payment_type_name'],
              },
              where: 'pay_mthds_id = ?',
              whereArgs: [payMethodId],
            );
          }
        } else {
          await txn.insert('pay_mthds', {
            'pay_mthds_id': payMethodId,
            'pay_mthds_name': item['payment_type_name'] ?? '',
          });
        }
      }

      for (final payMethodId in existingPayMethodIds) {
        if (!receivedPayMethodIds.contains(payMethodId)) {
          await txn.delete(
            'pay_mthds',
            where: 'pay_mthds_id = ?',
            whereArgs: [payMethodId],
          );
        }
      }
    });
  }
}

import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/marnisi_receipt_settings_helper.dart';
import 'package:web_admin/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MarnisiSessionContext {
  final String user;
  final List<String> roles;
  final List<Map<String, dynamic>> vineyards;
  final String defaultVineyard;
  final String loginBackgroundImagePath;
  final String appBackgroundImagePath;

  const MarnisiSessionContext({
    required this.user,
    required this.roles,
    required this.vineyards,
    required this.defaultVineyard,
    this.loginBackgroundImagePath = '',
    this.appBackgroundImagePath = '',
  });

  bool get canAdminMutate {
    final roleSet = roles.toSet();
    return roleSet.contains('System Manager') ||
        roleSet.contains('Super Admin') ||
        roleSet.contains('Vineyard Admin');
  }

  bool get canStaffMutate {
    final roleSet = roles.toSet();
    return canAdminMutate || roleSet.contains('Vineyard Staff');
  }

  bool get isViewerOnly {
    return !canStaffMutate;
  }
}

class MarnisiApiService {
  const MarnisiApiService();

  ApiService _api(String endpointPath) =>
      ApiService(endpointPath: endpointPath);

  Future<Map<String, dynamic>> _postArgsWithSessionRetry(
    String endpointPath,
    Map<String, dynamic> args,
  ) {
    return _withSessionRetry(() => _api(endpointPath).postArgs(args));
  }

  Future<Map<String, dynamic>> _fetchMessageWithSessionRetry(
    String endpointPath,
  ) {
    return _withSessionRetry(() => _api(endpointPath).fetchMessage());
  }

  Future<T> _withSessionRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      if (!_isAuthError(error)) {
        rethrow;
      }

      final reauthenticated = await _reauthenticateWithStoredPersonalId();
      if (!reauthenticated) {
        rethrow;
      }
      return action();
    }
  }

  static bool _isAuthError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('403') ||
        text.contains('not permitted') ||
        text.contains('permission') ||
        text.contains('session');
  }

  Future<bool> _reauthenticateWithStoredPersonalId() async {
    final prefs = await SharedPreferences.getInstance();
    final personalId = (prefs.getString(StorageKeys.userId) ?? '').trim();
    if (personalId.isEmpty) {
      return false;
    }

    try {
      await _api(ApiRoutes.marnisiLoginWithPersonalId).postArgs({
        'personal_id': personalId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    required String usr,
    required String pwd,
  }) {
    return _api(ApiRoutes.marnisiLogin).postBody({
      'usr': usr,
      'pwd': pwd,
    });
  }

  Future<Map<String, dynamic>> loginWithPersonalId({
    required String personalId,
  }) {
    return _api(ApiRoutes.marnisiLoginWithPersonalId).postArgs({
      'personal_id': personalId,
    });
  }

  Future<MarnisiSessionContext> getContext() async {
    final response =
        await _fetchMessageWithSessionRetry(ApiRoutes.marnisiGetContext);

    final roles = (response['roles'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);

    final vineyards = (response['vineyards'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final uiAssets =
        (response['ui_assets'] as Map<String, dynamic>?) ?? const {};
    final receiptSettings =
        (response['receipt_settings'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};

    await MarnisiImageHelper.persistBackgroundPaths(
      loginBackgroundPath:
          (uiAssets['login_background_image'] ?? '').toString(),
      appBackgroundPath: (uiAssets['app_background_image'] ?? '').toString(),
    );
    if (receiptSettings.isNotEmpty) {
      await MarnisiReceiptSettingsHelper.persistFromBackend(receiptSettings);
    } else {
      try {
        await getReceiptSettings();
      } catch (_) {
        // Keep local defaults when backend endpoint is not available.
      }
    }

    return MarnisiSessionContext(
      user: (response['user'] ?? '').toString(),
      roles: roles,
      vineyards: vineyards,
      defaultVineyard: (response['default_vineyard'] ?? '').toString(),
      loginBackgroundImagePath:
          (uiAssets['login_background_image'] ?? '').toString(),
      appBackgroundImagePath:
          (uiAssets['app_background_image'] ?? '').toString(),
    );
  }

  Future<Map<String, dynamic>> getReceiptSettings() async {
    final response =
        await _fetchMessageWithSessionRetry(ApiRoutes.marnisiReceiptSettings);
    final settings = (response['settings'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    await MarnisiReceiptSettingsHelper.persistFromBackend(settings);
    return settings;
  }

  Future<List<Map<String, dynamic>>> listAssignedVineyards() async {
    final response = await _postArgsWithSessionRetry(
      ApiRoutes.marnisiListAssignedVineyards,
      {},
    );
    return (response['vineyards'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listItems({
    required String vineyard,
    String search = '',
    bool? enabled,
    bool lowStock = false,
  }) async {
    final payload = <String, dynamic>{
      'vineyard': vineyard,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (enabled != null) 'enabled': enabled,
      if (lowStock) 'low_stock': 1,
    };

    final response =
        await _postArgsWithSessionRetry(ApiRoutes.marnisiItemList, payload);
    return (response['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createItem({
    required String vineyard,
    required String itemCode,
    required String itemName,
    String category = '',
    String brand = '',
    double sellPrice = 0,
    double stockQty = 0,
    double lowStockThreshold = 0,
    String unit = 'Bottle',
    String imagePath = 'assets/items/1.png',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiItemCreate, {
      'vineyard': vineyard,
      'item_code': itemCode,
      'item_name': itemName,
      'category': category,
      'brand': brand,
      'sell_price': sellPrice,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'image_path': imagePath,
      'is_enabled': 1,
    });
  }

  Future<Map<String, dynamic>> updateItem({
    required String itemId,
    required String itemName,
    String category = '',
    String brand = '',
    double sellPrice = 0,
    double lowStockThreshold = 0,
    String unit = 'Bottle',
    String imagePath = 'assets/items/1.png',
    String notes = '',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiItemUpdate, {
      'item_id': itemId,
      'item_name': itemName,
      'category': category,
      'brand': brand,
      'sell_price': sellPrice,
      'low_stock_threshold': lowStockThreshold,
      'unit': unit,
      'image_path': imagePath,
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> setItemEnabled({
    required String itemId,
    required bool enabled,
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiItemSetEnabled, {
      'item_id': itemId,
      'enabled': enabled,
    });
  }

  Future<Map<String, dynamic>> adjustStock({
    required String itemId,
    required String mode,
    double? setQty,
    double? deltaQty,
    String reason = '',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiItemAdjustStock, {
      'item_id': itemId,
      'mode': mode,
      if (setQty != null) 'set_qty': setQty,
      if (deltaQty != null) 'delta_qty': deltaQty,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> listItemMovements({
    required String vineyard,
    String? itemId,
    int limit = 100,
  }) async {
    final response = await _postArgsWithSessionRetry(
      ApiRoutes.marnisiItemMovements,
      {
        'vineyard': vineyard,
        if (itemId != null && itemId.isNotEmpty) 'item_id': itemId,
        'limit': limit,
      },
    );
    return (response['movements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listPackages({
    required String vineyard,
  }) async {
    final response = await _postArgsWithSessionRetry(
      ApiRoutes.marnisiPackageList,
      {
        'vineyard': vineyard,
      },
    );
    return (response['packages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> upsertPackage({
    String? packageId,
    required String vineyard,
    required String packageName,
    required String packageTier,
    required double pricePerPerson,
    required int maxGroupSize,
    required List<Map<String, dynamic>> wines,
    bool isActive = true,
    String description = '',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiPackageUpsert, {
      if (packageId != null && packageId.isNotEmpty) 'package_id': packageId,
      'vineyard': vineyard,
      'package_name': packageName,
      'package_tier': packageTier,
      'price_per_person': pricePerPerson,
      'max_group_size': maxGroupSize,
      'is_active': isActive,
      'description': description,
      'wines': wines,
    });
  }

  Future<List<Map<String, dynamic>>> listBookings({
    required String vineyard,
    String status = '',
    String fromDate = '',
    String toDate = '',
  }) async {
    final response = await _postArgsWithSessionRetry(
      ApiRoutes.marnisiBookingList,
      {
        'vineyard': vineyard,
        if (status.trim().isNotEmpty) 'status': status.trim(),
        if (fromDate.trim().isNotEmpty) 'from_date': fromDate.trim(),
        if (toDate.trim().isNotEmpty) 'to_date': toDate.trim(),
      },
    );
    return (response['bookings'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createBooking({
    required String vineyard,
    required String tourPackage,
    required String tourType,
    required int participantsCount,
    required String guestName,
    String guestPhone = '',
    String guestEmail = '',
    String scheduledAt = '',
    String notes = '',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiBookingCreate, {
      'vineyard': vineyard,
      'tour_package': tourPackage,
      'tour_type': tourType,
      'participants_count': participantsCount,
      'guest_name': guestName,
      'guest_phone': guestPhone,
      'guest_email': guestEmail,
      if (scheduledAt.trim().isNotEmpty) 'scheduled_at': scheduledAt,
      if (notes.trim().isNotEmpty) 'notes': notes,
    });
  }

  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    String cancelReason = '',
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiBookingUpdateStatus, {
      'booking_id': bookingId,
      'status': status,
      if (cancelReason.trim().isNotEmpty) 'cancel_reason': cancelReason,
    });
  }

  Future<Map<String, dynamic>> getBooking({
    required String bookingId,
  }) {
    return _postArgsWithSessionRetry(ApiRoutes.marnisiBookingGet, {
      'booking_id': bookingId,
    });
  }
}

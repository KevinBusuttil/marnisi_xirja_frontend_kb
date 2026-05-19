class StoreLoyaltyPolicy {
  final bool enabled;
  final bool allowEarn;
  final bool allowRedeem;
  final bool showCustomerUi;
  final bool showPointsUi;
  final bool showReceiptDetails;

  const StoreLoyaltyPolicy({
    this.enabled = true,
    this.allowEarn = true,
    this.allowRedeem = true,
    this.showCustomerUi = true,
    this.showPointsUi = true,
    this.showReceiptDetails = true,
  });

  factory StoreLoyaltyPolicy.fromStoreRow(Map<String, dynamic>? row) {
    if (row == null) {
      return const StoreLoyaltyPolicy();
    }

    final enabled = _asBool(row['stores_loyalty_enabled'], defaultValue: true);
    var allowEarn =
        _asBool(row['stores_loyalty_allow_earn'], defaultValue: true);
    var allowRedeem =
        _asBool(row['stores_loyalty_allow_redeem'], defaultValue: true);
    var showCustomerUi = _asBool(
      row['stores_loyalty_show_customer_ui'],
      defaultValue: true,
    );
    var showPointsUi = _asBool(
      row['stores_loyalty_show_points_ui'],
      defaultValue: true,
    );
    var showReceiptDetails = _asBool(
      row['stores_loyalty_show_receipt_details'],
      defaultValue: true,
    );

    if (!enabled) {
      allowEarn = false;
      allowRedeem = false;
      showCustomerUi = false;
      showPointsUi = false;
      showReceiptDetails = false;
    }

    return StoreLoyaltyPolicy(
      enabled: enabled,
      allowEarn: allowEarn,
      allowRedeem: allowRedeem,
      showCustomerUi: showCustomerUi,
      showPointsUi: showPointsUi,
      showReceiptDetails: showReceiptDetails,
    );
  }

  bool get canCaptureCustomer =>
      enabled && showCustomerUi && (allowEarn || allowRedeem);

  bool get canShowPointsSummary => enabled && showPointsUi;

  bool get canRedeem => enabled && allowRedeem;

  bool get canEarn => enabled && allowEarn;

  bool get shouldShowLoyaltyOnReceipt => enabled && showReceiptDetails;

  static bool _asBool(dynamic value, {required bool defaultValue}) {
    if (value == null || value == '') {
      return defaultValue;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return ['1', 'true', 'yes', 'y', 'on']
        .contains(value.toString().trim().toLowerCase());
  }
}

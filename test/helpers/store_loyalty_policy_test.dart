import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/store_loyalty_policy.dart';

void main() {
  group('StoreLoyaltyPolicy.fromStoreRow', () {
    test('uses fully enabled defaults when row is null', () {
      final policy = StoreLoyaltyPolicy.fromStoreRow(null);

      expect(policy.enabled, isTrue);
      expect(policy.allowEarn, isTrue);
      expect(policy.allowRedeem, isTrue);
      expect(policy.showCustomerUi, isTrue);
      expect(policy.showPointsUi, isTrue);
      expect(policy.showReceiptDetails, isTrue);
      expect(policy.canCaptureCustomer, isTrue);
      expect(policy.canShowPointsSummary, isTrue);
      expect(policy.shouldShowLoyaltyOnReceipt, isTrue);
    });

    test('disables all loyalty capabilities when store toggle is off', () {
      final policy = StoreLoyaltyPolicy.fromStoreRow({
        'stores_loyalty_enabled': 0,
        'stores_loyalty_allow_earn': 1,
        'stores_loyalty_allow_redeem': 1,
        'stores_loyalty_show_customer_ui': 1,
        'stores_loyalty_show_points_ui': 1,
        'stores_loyalty_show_receipt_details': 1,
      });

      expect(policy.enabled, isFalse);
      expect(policy.allowEarn, isFalse);
      expect(policy.allowRedeem, isFalse);
      expect(policy.showCustomerUi, isFalse);
      expect(policy.showPointsUi, isFalse);
      expect(policy.showReceiptDetails, isFalse);
      expect(policy.canCaptureCustomer, isFalse);
      expect(policy.canShowPointsSummary, isFalse);
      expect(policy.shouldShowLoyaltyOnReceipt, isFalse);
    });

    test('supports earn-only stores with customer lookup enabled', () {
      final policy = StoreLoyaltyPolicy.fromStoreRow({
        'stores_loyalty_enabled': 1,
        'stores_loyalty_allow_earn': 1,
        'stores_loyalty_allow_redeem': 0,
        'stores_loyalty_show_customer_ui': 1,
        'stores_loyalty_show_points_ui': 0,
        'stores_loyalty_show_receipt_details': 0,
      });

      expect(policy.enabled, isTrue);
      expect(policy.canEarn, isTrue);
      expect(policy.canRedeem, isFalse);
      expect(policy.canCaptureCustomer, isTrue);
      expect(policy.canShowPointsSummary, isFalse);
      expect(policy.shouldShowLoyaltyOnReceipt, isFalse);
    });
  });
}

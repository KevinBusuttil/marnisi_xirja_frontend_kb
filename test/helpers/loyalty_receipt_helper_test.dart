import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/loyalty_receipt_helper.dart';

void main() {
  group('LoyaltyReceiptHelper.hasLoyaltyData', () {
    test('returns true when loyalty card number is present', () {
      final hasData = LoyaltyReceiptHelper.hasLoyaltyData(
        loyaltyCardNum: 'LC-123',
      );

      expect(hasData, isTrue);
    });

    test('returns true when loyalty points are present', () {
      final hasData = LoyaltyReceiptHelper.hasLoyaltyData(
        loyaltyPointsUsed: 10,
      );

      expect(hasData, isTrue);
    });

    test('returns false when loyalty payload is empty', () {
      final hasData = LoyaltyReceiptHelper.hasLoyaltyData();

      expect(hasData, isFalse);
    });
  });

  group('LoyaltyReceiptHelper.shouldShowLoyaltySection', () {
    test('requires both config toggle and loyalty data', () {
      final hiddenByConfig = LoyaltyReceiptHelper.shouldShowLoyaltySection(
        showLoyaltyDetails: false,
        loyaltyCardNum: 'LC-999',
      );
      final visible = LoyaltyReceiptHelper.shouldShowLoyaltySection(
        showLoyaltyDetails: true,
        loyaltyPointsUsed: 5,
      );

      expect(hiddenByConfig, isFalse);
      expect(visible, isTrue);
    });
  });

  group('LoyaltyReceiptHelper.mergeWithConfirmation', () {
    test('uses confirmation values when present', () {
      final merged = LoyaltyReceiptHelper.mergeWithConfirmation(
        confirmation: const {
          'loy_points_used': '10.5',
          'loy_points_earned': 3,
          'balance_points': '42.75',
        },
        currentUsed: 1,
        currentEarned: 1,
        currentBalance: 1,
      );

      expect(merged.pointsUsed, 10.5);
      expect(merged.pointsEarned, 3.0);
      expect(merged.pointsBalance, 42.75);
    });

    test('falls back to current values when confirmation fields are missing',
        () {
      final merged = LoyaltyReceiptHelper.mergeWithConfirmation(
        confirmation: const {'status': 'synchronized'},
        currentUsed: 12.0,
        currentEarned: 4.0,
        currentBalance: 30.0,
      );

      expect(merged.pointsUsed, 12.0);
      expect(merged.pointsEarned, 4.0);
      expect(merged.pointsBalance, 30.0);
    });
  });
}

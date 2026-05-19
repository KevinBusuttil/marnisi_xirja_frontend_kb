class LoyaltyReceiptHelper {
  static bool hasLoyaltyData({
    String loyaltyCardNum = '',
    double loyaltyPointsUsed = 0.0,
    double loyaltyRewardAmount = 0.0,
    double loyaltyPointsBalance = 0.0,
  }) {
    return loyaltyCardNum.trim().isNotEmpty ||
        loyaltyPointsUsed > 0 ||
        loyaltyRewardAmount > 0 ||
        loyaltyPointsBalance > 0;
  }

  static bool shouldShowLoyaltySection({
    required bool showLoyaltyDetails,
    String loyaltyCardNum = '',
    double loyaltyPointsUsed = 0.0,
    double loyaltyRewardAmount = 0.0,
    double loyaltyPointsBalance = 0.0,
  }) {
    return showLoyaltyDetails &&
        hasLoyaltyData(
          loyaltyCardNum: loyaltyCardNum,
          loyaltyPointsUsed: loyaltyPointsUsed,
          loyaltyRewardAmount: loyaltyRewardAmount,
          loyaltyPointsBalance: loyaltyPointsBalance,
        );
  }

  static double parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static LoyaltyReceiptValues mergeWithConfirmation({
    required Map<String, dynamic> confirmation,
    double currentUsed = 0.0,
    double currentEarned = 0.0,
    double currentBalance = 0.0,
  }) {
    return LoyaltyReceiptValues(
      pointsUsed: parseDouble(
        confirmation['loy_points_used'],
        fallback: currentUsed,
      ),
      pointsEarned: parseDouble(
        confirmation['loy_points_earned'],
        fallback: currentEarned,
      ),
      pointsBalance: parseDouble(
        confirmation['balance_points'],
        fallback: currentBalance,
      ),
    );
  }
}

class LoyaltyReceiptValues {
  final double pointsUsed;
  final double pointsEarned;
  final double pointsBalance;

  const LoyaltyReceiptValues({
    required this.pointsUsed,
    required this.pointsEarned,
    required this.pointsBalance,
  });
}

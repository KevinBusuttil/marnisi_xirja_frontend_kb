class PaymentBalanceResult {
  final double newBalance;
  final double change;
  final double paymentAmount;

  const PaymentBalanceResult({
    required this.newBalance,
    required this.change,
    required this.paymentAmount,
  });
}

class PaymentFlowHelper {
  static double round2(double value) => double.parse(value.toStringAsFixed(2));

  static double resolvePendingAmount({
    required double totalPay,
    double? balance,
  }) {
    final currentBalance = balance ?? 0.0;
    if (currentBalance.abs() > 0.009) {
      return round2(currentBalance);
    }
    return round2(totalPay);
  }

  static bool isPayoutPending({
    required double totalPay,
    double? balance,
  }) {
    return resolvePendingAmount(totalPay: totalPay, balance: balance) < 0;
  }

  static double normalizeEnteredAmount(
    String rawAmount, {
    required double pendingAmount,
  }) {
    final parsed = double.tryParse(rawAmount.trim()) ?? 0.0;
    if (pendingAmount < 0) {
      return round2(parsed.abs());
    }
    return round2(parsed);
  }

  static bool isEnteredAmountValid({
    required String rawAmount,
    required double pendingAmount,
  }) {
    final amount = normalizeEnteredAmount(
      rawAmount,
      pendingAmount: pendingAmount,
    );
    if (amount <= 0) {
      return false;
    }
    if (pendingAmount < 0 && amount > round2(pendingAmount.abs()) + 0.01) {
      return false;
    }
    return true;
  }

  static String initialAmountText({
    required double totalPay,
    double? balance,
  }) {
    final pending = resolvePendingAmount(totalPay: totalPay, balance: balance);
    return round2(pending.abs()).toStringAsFixed(2);
  }

  static double calculateCashPreviewChange({
    required bool isCash,
    required double pendingAmount,
    required double enteredAmount,
  }) {
    if (!isCash || pendingAmount <= 0) {
      return 0.0;
    }
    if (enteredAmount <= pendingAmount) {
      return 0.0;
    }
    return round2(enteredAmount - pendingAmount);
  }

  static PaymentBalanceResult applyPayment({
    required double orderTotal,
    required double currentBalance,
    required double enteredAmount,
    required String paymentMethodId,
  }) {
    final pending = resolvePendingAmount(
      totalPay: orderTotal,
      balance: currentBalance,
    );
    final paid = round2(enteredAmount);
    final canGiveChange = paymentMethodId == '1';

    if (pending < 0) {
      final payoutDue = round2(pending.abs());
      if (paid >= payoutDue) {
        return PaymentBalanceResult(
          newBalance: 0.0,
          change: 0.0,
          paymentAmount: round2(-payoutDue),
        );
      }
      return PaymentBalanceResult(
        newBalance: round2(-(payoutDue - paid)),
        change: 0.0,
        paymentAmount: round2(-paid),
      );
    }

    if (paid >= pending) {
      final usedAmount = pending;
      final change =
          (canGiveChange && paid > pending) ? round2(paid - pending) : 0.0;
      return PaymentBalanceResult(
        newBalance: 0.0,
        change: change,
        paymentAmount: round2(usedAmount),
      );
    }

    return PaymentBalanceResult(
      newBalance: round2(pending - paid),
      change: 0.0,
      paymentAmount: paid,
    );
  }
}

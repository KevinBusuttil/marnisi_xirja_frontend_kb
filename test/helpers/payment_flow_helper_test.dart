import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/payment_flow_helper.dart';

void main() {
  group('PaymentFlowHelper.resolvePendingAmount', () {
    test('uses order total when no active balance exists', () {
      final pending = PaymentFlowHelper.resolvePendingAmount(
        totalPay: 12.34,
        balance: 0,
      );

      expect(pending, 12.34);
    });

    test('keeps active negative balance for payout flow', () {
      final pending = PaymentFlowHelper.resolvePendingAmount(
        totalPay: -2.11,
        balance: -1.50,
      );

      expect(pending, -1.50);
    });
  });

  group('PaymentFlowHelper.input handling', () {
    test('initial amount text uses absolute value for payout', () {
      final text = PaymentFlowHelper.initialAmountText(
        totalPay: -0.15,
        balance: 0,
      );

      expect(text, '0.15');
    });

    test('accepts negative typed input by normalizing payout amount', () {
      final pending = PaymentFlowHelper.resolvePendingAmount(
        totalPay: -0.15,
        balance: 0,
      );

      expect(
        PaymentFlowHelper.normalizeEnteredAmount(
          '-0.15',
          pendingAmount: pending,
        ),
        0.15,
      );
      expect(
        PaymentFlowHelper.isEnteredAmountValid(
          rawAmount: '-0.15',
          pendingAmount: pending,
        ),
        true,
      );
    });

    test('rejects payout amount above refund due', () {
      final pending = PaymentFlowHelper.resolvePendingAmount(
        totalPay: -0.15,
        balance: 0,
      );

      expect(
        PaymentFlowHelper.isEnteredAmountValid(
          rawAmount: '1.00',
          pendingAmount: pending,
        ),
        false,
      );
    });
  });

  group('PaymentFlowHelper.applyPayment', () {
    test('calculates change for normal cash overpayment', () {
      final result = PaymentFlowHelper.applyPayment(
        orderTotal: 10.00,
        currentBalance: 0,
        enteredAmount: 20.00,
        paymentMethodId: '1',
      );

      expect(result.newBalance, 0.0);
      expect(result.change, 10.0);
      expect(result.paymentAmount, 10.0);
    });

    test('processes full payout on return with negative amount due', () {
      final result = PaymentFlowHelper.applyPayment(
        orderTotal: -2.11,
        currentBalance: 0,
        enteredAmount: 2.11,
        paymentMethodId: '1',
      );

      expect(result.newBalance, 0.0);
      expect(result.change, 0.0);
      expect(result.paymentAmount, -2.11);
    });

    test('supports partial payout and keeps remaining negative balance', () {
      final result = PaymentFlowHelper.applyPayment(
        orderTotal: -2.11,
        currentBalance: 0,
        enteredAmount: 1.00,
        paymentMethodId: '1',
      );

      expect(result.newBalance, -1.11);
      expect(result.change, 0.0);
      expect(result.paymentAmount, -1.0);
    });
  });
}

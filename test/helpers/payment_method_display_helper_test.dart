import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/payment_method_display_helper.dart';

void main() {
  group('PaymentMethodDisplayHelper.resolveDisplayText', () {
    test('returns ordered distinct payment names from payment cache', () {
      final resolved = PaymentMethodDisplayHelper.resolveDisplayText([
        {'pay_txn_name': 'Card BOV'},
        {'pay_txn_name': 'Cash'},
        {'pay_txn_name': 'Card BOV'},
      ]);

      expect(resolved, 'Card BOV, Cash');
    });

    test('falls back when cache names are empty', () {
      final resolved = PaymentMethodDisplayHelper.resolveDisplayText(
        [
          {'pay_txn_name': ''},
          {'pay_txn_name': null},
        ],
        fallback: 'Card BOV',
      );

      expect(resolved, 'Card BOV');
    });
  });
}

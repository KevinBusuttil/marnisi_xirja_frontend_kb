import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/sales_pricing_calculator.dart';

void main() {
  group('SalesPricingCalculator.calculateMainLine', () {
    test('applies discount on VAT-inclusive line total', () {
      final line = SalesPricingCalculator.calculateMainLine(
        unitGrossPrice: 118.0,
        qty: 1,
        taxPct: 18.0,
        discountGross: 10.0,
      );

      expect(line.grossBeforeDiscount, 118.0);
      expect(line.discountGross, 10.0);
      expect(line.grossAfterDiscount, 108.0);
      expect(line.netBeforeDiscount, 100.0);
      expect(line.taxBeforeDiscount, 18.0);
      expect(line.netAfterDiscount, 91.53);
      expect(line.taxAfterDiscount, 16.47);
    });

    test('clamps discount to line gross', () {
      final line = SalesPricingCalculator.calculateMainLine(
        unitGrossPrice: 50.0,
        qty: 1,
        taxPct: 18.0,
        discountGross: 100.0,
      );

      expect(line.discountGross, 50.0);
      expect(line.grossAfterDiscount, 0.0);
      expect(line.netBeforeDiscount, 42.37);
      expect(line.taxBeforeDiscount, 7.63);
      expect(line.netAfterDiscount, 0.0);
      expect(line.taxAfterDiscount, 0.0);
    });

    test('does not create negative discount for returned line', () {
      final line = SalesPricingCalculator.calculateMainLine(
        unitGrossPrice: 2.01,
        qty: -1,
        taxPct: 18.0,
        discountGross: 0.0,
      );

      expect(line.grossBeforeDiscount, -2.01);
      expect(line.discountGross, 0.0);
      expect(line.grossAfterDiscount, -2.01);
      expect(line.netBeforeDiscount, -1.70);
      expect(line.taxBeforeDiscount, -0.31);
      expect(line.netAfterDiscount, -1.70);
      expect(line.taxAfterDiscount, -0.31);
    });

    test('ignores manual discount input on returned line', () {
      final line = SalesPricingCalculator.calculateMainLine(
        unitGrossPrice: 2.01,
        qty: -1,
        taxPct: 18.0,
        discountGross: 1.0,
      );

      expect(line.discountGross, 0.0);
      expect(line.grossAfterDiscount, -2.01);
    });
  });

  group('SalesPricingCalculator.calculateOrderTotals', () {
    test('returns consistent subtotal/tax/total/discount', () {
      final order = [
        {
          'item_price': 118.0,
          'item_qty': 1,
          'item_tax_pct': 18.0,
          'item_disc_amount': 10.0,
          'item_supplementary': [
            {'sup_item_price': 2.0, 'sup_item_qty': 1}
          ],
        },
        {
          'item_price': 59.0,
          'item_qty': 2,
          'item_tax_pct': 18.0,
          'item_disc_amount': 5.0,
          'item_supplementary': [],
        },
      ];

      final totals = SalesPricingCalculator.calculateOrderTotals(order);

      expect(totals.subTotal, 202.0);
      expect(totals.tax, 36.0);
      expect(totals.total, 223.0);
      expect(totals.discount, 15.0);
      expect(totals.subTotalAfterDiscount, 189.29);
      expect(totals.taxAfterDiscount, 33.71);
      expect(totals.grossBeforeDiscount, 238.0);
      expect(
        SalesPricingCalculator.round2(
          totals.grossBeforeDiscount - totals.discount,
        ),
        totals.total,
      );
      expect(
        SalesPricingCalculator.round2(
          totals.subTotalAfterDiscount + totals.taxAfterDiscount,
        ),
        223.0,
      );
    });

    test('returns full refund with supplementary and zero discount', () {
      final order = [
        {
          'item_price': 2.01,
          'item_qty': -1,
          'item_tax_pct': 18.0,
          'item_disc_amount': 0.0,
          'item_supplementary': [
            {'sup_item_price': 0.10, 'sup_item_qty': -1}
          ],
        },
      ];

      final totals = SalesPricingCalculator.calculateOrderTotals(order);

      expect(totals.subTotal, -1.80);
      expect(totals.tax, -0.31);
      expect(totals.total, -2.11);
      expect(totals.discount, 0.0);
      expect(totals.subTotalAfterDiscount, -1.80);
      expect(totals.taxAfterDiscount, -0.31);
      expect(totals.grossBeforeDiscount, -2.11);
      expect(
        SalesPricingCalculator.round2(
          totals.grossBeforeDiscount - totals.discount,
        ),
        totals.total,
      );
    });
  });

  group('SalesPricingCalculator.allocateDiscountProportionally', () {
    test('allocates total discount proportionally and keeps exact sum', () {
      final allocations = SalesPricingCalculator.allocateDiscountProportionally(
        bases: [100.0, 50.0],
        totalDiscount: 10.0,
      );

      expect(allocations, [6.67, 3.33]);
      expect(
        SalesPricingCalculator.round2(
          allocations.fold<double>(0.0, (sum, v) => sum + v),
        ),
        10.0,
      );
    });

    test('returns zero allocations for zero base', () {
      final allocations = SalesPricingCalculator.allocateDiscountProportionally(
        bases: [0.0, 0.0],
        totalDiscount: 10.0,
      );

      expect(allocations, [0.0, 0.0]);
    });
  });
}

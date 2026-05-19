import 'package:flutter_test/flutter_test.dart';
import 'package:web_admin/helpers/sales_history_helper.dart';

void main() {
  group('SalesHistoryHelper.filterSales', () {
    final sales = <Map<String, dynamic>>[
      {
        'sales_num': 'ABC-001',
        'date': '2026-03-10',
        'items': [
          {
            'item_id': 'ITM-1',
            'item_code': 'ITM-1',
            'item_barcode': '123',
            'item_name': 'Sparkling Water',
          }
        ],
      },
      {
        'sales_num': 'ABC-002',
        'date': '2026-02-25',
        'items': [
          {
            'item_id': 'ITM-2',
            'item_code': 'ITM-2',
            'item_barcode': '456',
            'item_name': 'Still Water',
          }
        ],
      },
    ];

    test('matches by sale number and date range', () {
      final filtered = SalesHistoryHelper.filterSales(
        sales,
        SalesHistoryFilterCriteria(
          saleNum: 'abc-001',
          fromDate: DateTime(2026, 3, 1),
          toDate: DateTime(2026, 3, 31),
        ),
      );

      expect(filtered.length, 1);
      expect(filtered.first['sales_num'], 'ABC-001');
    });

    test('matches by item code and item name', () {
      final filtered = SalesHistoryHelper.filterSales(
        sales,
        const SalesHistoryFilterCriteria(
          itemCode: '456',
          itemName: 'still',
        ),
      );

      expect(filtered.length, 1);
      expect(filtered.first['sales_num'], 'ABC-002');
    });

    test('respects single-ended date ranges', () {
      final fromOnly = SalesHistoryHelper.filterSales(
        sales,
        SalesHistoryFilterCriteria(fromDate: DateTime(2026, 3, 1)),
      );
      final toOnly = SalesHistoryHelper.filterSales(
        sales,
        SalesHistoryFilterCriteria(toDate: DateTime(2026, 2, 28)),
      );

      expect(fromOnly.length, 1);
      expect(fromOnly.first['sales_num'], 'ABC-001');
      expect(toOnly.length, 1);
      expect(toOnly.first['sales_num'], 'ABC-002');
    });
  });

  group('SalesHistoryHelper.cashTenderedFromPayments', () {
    test('returns cash used plus change', () {
      final tendered = SalesHistoryHelper.cashTenderedFromPayments(
        [
          {
            'tender_type_id': '1',
            'payment_name': 'Cash',
            'amount_tendered': 70.0,
          },
          {
            'tender_type_id': '7',
            'payment_name': 'Card',
            'amount_tendered': 30.0,
          },
        ],
        change: 10.0,
      );

      expect(tendered, 80.0);
    });

    test('ignores change when no cash payment exists', () {
      final tendered = SalesHistoryHelper.cashTenderedFromPayments(
        [
          {
            'tender_type_id': '7',
            'payment_name': 'Card',
            'amount_tendered': 30.0,
          },
        ],
        change: 10.0,
      );

      expect(tendered, 0.0);
    });

    test('computes tendered correctly from local payment rows', () {
      final tendered = SalesHistoryHelper.cashTenderedFromLocalPayments(
        [
          {
            'pay_txn_id': '1',
            'pay_txn_name': 'Cash',
            'pay_txn_amount': '77.96',
          },
          {
            'pay_txn_id': '7',
            'pay_txn_name': 'Card',
            'pay_txn_amount': '20.00',
          },
        ],
        change: 22.04,
      );

      expect(tendered, 100.0);
    });
  });

  group('SalesHistoryHelper.resolveReceiptTotals', () {
    test('uses discounted header values when present', () {
      final totals = SalesHistoryHelper.resolveReceiptTotals(
        items: const [],
        discountedSubTotal: 138.47,
        discountedTax: 24.93,
        fallbackSubTotal: 145.76,
        fallbackTax: 26.24,
      );

      expect(totals.subTotal, 138.47);
      expect(totals.tax, 24.93);
    });

    test('recomputes discounted values from item lines when missing', () {
      final totals = SalesHistoryHelper.resolveReceiptTotals(
        items: [
          {
            'item_price': 118.0,
            'item_qty': 1,
            'item_tax_pct': 18.0,
            'item_disc_amount': 10.0,
          },
          {
            'item_price': 59.0,
            'item_qty': 2,
            'item_tax_pct': 18.0,
            'item_disc_amount': 5.0,
          },
        ],
        fallbackSubTotal: 200.0,
        fallbackTax: 35.0,
      );

      expect(totals.subTotal, 187.29);
      expect(totals.tax, 33.71);
    });

    test('preserves provided discounted subtotal and computes missing tax', () {
      final totals = SalesHistoryHelper.resolveReceiptTotals(
        items: [
          {
            'item_price': 172.0,
            'item_qty': 1,
            'item_tax_pct': 18.0,
            'item_disc_amount': 8.6,
          },
        ],
        discountedSubTotal: 138.47,
      );

      expect(totals.subTotal, 138.47);
      expect(totals.tax, 24.93);
    });
  });
}

import 'package:web_admin/helpers/sales_pricing_calculator.dart';

class SalesHistoryFilterCriteria {
  final String saleNum;
  final String itemCode;
  final String itemName;
  final DateTime? fromDate;
  final DateTime? toDate;

  const SalesHistoryFilterCriteria({
    this.saleNum = '',
    this.itemCode = '',
    this.itemName = '',
    this.fromDate,
    this.toDate,
  });
}

class ReceiptTotals {
  final double subTotal;
  final double tax;

  const ReceiptTotals({
    required this.subTotal,
    required this.tax,
  });
}

class SalesHistoryHelper {
  static double asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static List<Map<String, dynamic>> filterSales(
    List<Map<String, dynamic>> sales,
    SalesHistoryFilterCriteria criteria,
  ) {
    final saleNumNeedle = criteria.saleNum.trim().toLowerCase();
    final itemCodeNeedle = criteria.itemCode.trim().toLowerCase();
    final itemNameNeedle = criteria.itemName.trim().toLowerCase();

    return sales.where((sale) {
      final saleNum = sale['sales_num']?.toString().toLowerCase() ?? '';
      final saleDate = sale['date']?.toString() ?? '';
      final List<dynamic> items = (sale['items'] as List<dynamic>?) ?? [];

      final saleNumMatch =
          saleNumNeedle.isEmpty || saleNum.contains(saleNumNeedle);
      final dateMatch = _isDateInRange(
        saleDate: saleDate,
        fromDate: criteria.fromDate,
        toDate: criteria.toDate,
      );

      final itemCodeMatch = itemCodeNeedle.isEmpty ||
          items.any((item) {
            if (item is! Map) {
              return false;
            }
            final id = item['item_id']?.toString().toLowerCase() ?? '';
            final code = item['item_code']?.toString().toLowerCase() ?? '';
            final barcode =
                item['item_barcode']?.toString().toLowerCase() ?? '';
            return id.contains(itemCodeNeedle) ||
                code.contains(itemCodeNeedle) ||
                barcode.contains(itemCodeNeedle);
          });

      final itemNameMatch = itemNameNeedle.isEmpty ||
          items.any((item) {
            if (item is! Map) {
              return false;
            }
            final name = item['item_name']?.toString().toLowerCase() ?? '';
            return name.contains(itemNameNeedle);
          });

      return saleNumMatch && dateMatch && itemCodeMatch && itemNameMatch;
    }).toList();
  }

  static bool _isDateInRange({
    required String saleDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    if (fromDate == null && toDate == null) {
      return true;
    }
    final parsedDate = DateTime.tryParse(saleDate);
    if (parsedDate == null) {
      return false;
    }

    final normalizedSaleDate =
        DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final normalizedFrom = fromDate == null
        ? null
        : DateTime(fromDate.year, fromDate.month, fromDate.day);
    final normalizedTo =
        toDate == null ? null : DateTime(toDate.year, toDate.month, toDate.day);

    if (normalizedFrom != null && normalizedSaleDate.isBefore(normalizedFrom)) {
      return false;
    }
    if (normalizedTo != null && normalizedSaleDate.isAfter(normalizedTo)) {
      return false;
    }
    return true;
  }

  static bool isCashPayment(Map<String, dynamic> payment) {
    final tenderTypeId = payment['tender_type_id']?.toString() ?? '';
    final paymentName = payment['payment_name']?.toString().toLowerCase() ?? '';
    return tenderTypeId == '1' || paymentName.contains('cash');
  }

  static double cashTenderedFromPayments(
    List<dynamic> payMethods, {
    double change = 0.0,
  }) {
    bool hasCashPayment = false;
    final cashUsed = payMethods.fold<double>(0.0, (sum, method) {
      if (method is! Map<String, dynamic>) {
        return sum;
      }
      if (!isCashPayment(method)) {
        return sum;
      }
      hasCashPayment = true;
      return sum + asDouble(method['amount_tendered']);
    });

    final normalizedChange = change > 0 ? change : 0.0;
    if (!hasCashPayment) {
      return double.parse(cashUsed.toStringAsFixed(2));
    }
    return double.parse((cashUsed + normalizedChange).toStringAsFixed(2));
  }

  static double cashTenderedFromLocalPayments(
    List<Map<String, dynamic>> payMethods, {
    double change = 0.0,
  }) {
    final normalized = payMethods
        .map((method) => <String, dynamic>{
              'tender_type_id': method['pay_txn_id'],
              'payment_name': method['pay_txn_name'],
              'amount_tendered': method['pay_txn_amount'],
            })
        .toList();

    return cashTenderedFromPayments(normalized, change: change);
  }

  static ReceiptTotals resolveReceiptTotals({
    required List<dynamic> items,
    double? discountedSubTotal,
    double? discountedTax,
    double? fallbackSubTotal,
    double? fallbackTax,
  }) {
    final normalizedItems =
        items.whereType<Map<String, dynamic>>().toList(growable: false);

    if (discountedSubTotal != null && discountedTax != null) {
      return ReceiptTotals(
        subTotal: double.parse(discountedSubTotal.toStringAsFixed(2)),
        tax: double.parse(discountedTax.toStringAsFixed(2)),
      );
    }

    if (normalizedItems.isNotEmpty) {
      final totals =
          SalesPricingCalculator.calculateOrderTotals(normalizedItems);
      return ReceiptTotals(
        subTotal: discountedSubTotal ?? totals.subTotalAfterDiscount,
        tax: discountedTax ?? totals.taxAfterDiscount,
      );
    }

    return ReceiptTotals(
      subTotal: double.parse(
        (discountedSubTotal ?? fallbackSubTotal ?? 0.0).toStringAsFixed(2),
      ),
      tax: double.parse(
        (discountedTax ?? fallbackTax ?? 0.0).toStringAsFixed(2),
      ),
    );
  }
}

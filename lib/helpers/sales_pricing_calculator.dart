import 'dart:math' as math;

class LinePricingBreakdown {
  final double grossBeforeDiscount;
  final double discountGross;
  final double grossAfterDiscount;
  final double netBeforeDiscount;
  final double taxBeforeDiscount;
  final double netAfterDiscount;
  final double taxAfterDiscount;

  const LinePricingBreakdown({
    required this.grossBeforeDiscount,
    required this.discountGross,
    required this.grossAfterDiscount,
    required this.netBeforeDiscount,
    required this.taxBeforeDiscount,
    required this.netAfterDiscount,
    required this.taxAfterDiscount,
  });
}

class OrderPricingBreakdown {
  final double subTotal;
  final double tax;
  final double total;
  final double discount;
  final double subTotalAfterDiscount;
  final double taxAfterDiscount;
  final double grossBeforeDiscount;

  const OrderPricingBreakdown({
    required this.subTotal,
    required this.tax,
    required this.total,
    required this.discount,
    required this.subTotalAfterDiscount,
    required this.taxAfterDiscount,
    required this.grossBeforeDiscount,
  });
}

class SalesPricingCalculator {
  static double round2(double value) => double.parse(value.toStringAsFixed(2));

  static double asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static int asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  static LinePricingBreakdown calculateMainLine({
    required double unitGrossPrice,
    required int qty,
    required double taxPct,
    double discountGross = 0.0,
  }) {
    final grossBefore = round2(unitGrossPrice * qty);
    // Returns (negative gross) should never auto-create negative discounts.
    final maxDiscountableGross = math.max(grossBefore, 0.0);
    final clampedDiscount = round2(
      math.min(math.max(discountGross, 0.0), maxDiscountableGross),
    );
    final grossAfter = round2(grossBefore - clampedDiscount);

    if (taxPct <= 0) {
      return LinePricingBreakdown(
        grossBeforeDiscount: grossBefore,
        discountGross: clampedDiscount,
        grossAfterDiscount: grossAfter,
        netBeforeDiscount: grossBefore,
        taxBeforeDiscount: 0.0,
        netAfterDiscount: grossAfter,
        taxAfterDiscount: 0.0,
      );
    }

    final netBefore = round2(grossBefore / (1 + (taxPct / 100)));
    final taxBefore = round2(grossBefore - netBefore);
    final netAfter = round2(grossAfter / (1 + (taxPct / 100)));
    final taxAfter = round2(grossAfter - netAfter);

    return LinePricingBreakdown(
      grossBeforeDiscount: grossBefore,
      discountGross: clampedDiscount,
      grossAfterDiscount: grossAfter,
      netBeforeDiscount: netBefore,
      taxBeforeDiscount: taxBefore,
      netAfterDiscount: netAfter,
      taxAfterDiscount: taxAfter,
    );
  }

  static double supplementaryGross(Map<String, dynamic> supplementary) {
    final price = asDouble(supplementary['sup_item_price']);
    final qty = asInt(supplementary['sup_item_qty']);
    return round2(price * qty);
  }

  static double itemDiscountableGross(Map<String, dynamic> item) {
    final unitGross = asDouble(item['item_price']);
    final qty = asInt(item['item_qty']);
    return round2(unitGross * qty);
  }

  static OrderPricingBreakdown calculateOrderTotals(
      List<Map<String, dynamic>> orderItems) {
    double subTotal = 0.0;
    double tax = 0.0;
    double subTotalAfterDiscount = 0.0;
    double taxAfterDiscount = 0.0;
    double discount = 0.0;
    double supplementary = 0.0;

    for (final item in orderItems) {
      final line = calculateMainLine(
        unitGrossPrice: asDouble(item['item_price']),
        qty: asInt(item['item_qty']),
        taxPct: asDouble(item['item_tax_pct']),
        discountGross: asDouble(item['item_disc_amount']),
      );

      subTotal += line.netBeforeDiscount;
      tax += line.taxBeforeDiscount;
      subTotalAfterDiscount += line.netAfterDiscount;
      taxAfterDiscount += line.taxAfterDiscount;
      discount += line.discountGross;

      final supplementaryData = item['item_supplementary'];
      if (supplementaryData is List) {
        for (final sup in supplementaryData) {
          if (sup is Map<String, dynamic>) {
            supplementary += supplementaryGross(sup);
          }
        }
      } else if (supplementaryData is Map<String, dynamic>) {
        supplementary += supplementaryGross(supplementaryData);
      }
    }

    subTotal = round2(subTotal + supplementary);
    tax = round2(tax);
    subTotalAfterDiscount = round2(subTotalAfterDiscount + supplementary);
    taxAfterDiscount = round2(taxAfterDiscount);
    discount = round2(discount);
    final total = round2(subTotalAfterDiscount + taxAfterDiscount);
    final grossBeforeDiscount = round2(subTotal + tax);

    return OrderPricingBreakdown(
      subTotal: subTotal,
      tax: tax,
      total: total,
      discount: discount,
      subTotalAfterDiscount: subTotalAfterDiscount,
      taxAfterDiscount: taxAfterDiscount,
      grossBeforeDiscount: grossBeforeDiscount,
    );
  }

  static List<double> allocateDiscountProportionally({
    required List<double> bases,
    required double totalDiscount,
  }) {
    final roundedBases = bases.map(round2).toList();
    final baseCents = roundedBases
        .map((value) => math.max((value * 100).round(), 0))
        .toList();

    final totalBaseCents = baseCents.fold<int>(0, (sum, value) => sum + value);
    if (totalBaseCents <= 0) {
      return List<double>.filled(bases.length, 0.0);
    }

    final requestedDiscountCents =
        math.max((round2(totalDiscount) * 100).round(), 0);
    int discountCents = math.min(requestedDiscountCents, totalBaseCents);
    if (discountCents <= 0) {
      return List<double>.filled(bases.length, 0.0);
    }

    final provisional = List<int>.filled(baseCents.length, 0);
    final fractions = List<double>.filled(baseCents.length, 0.0);
    int used = 0;

    for (int i = 0; i < baseCents.length; i++) {
      if (baseCents[i] <= 0) {
        continue;
      }

      final raw = (discountCents * baseCents[i]) / totalBaseCents;
      provisional[i] = raw.floor();
      fractions[i] = raw - provisional[i];
      provisional[i] = math.min(provisional[i], baseCents[i]);
      used += provisional[i];
    }

    int remainder = discountCents - used;
    final order = List<int>.generate(baseCents.length, (i) => i)
      ..sort((a, b) => fractions[b].compareTo(fractions[a]));

    for (final idx in order) {
      if (remainder <= 0) {
        break;
      }
      if (provisional[idx] < baseCents[idx]) {
        provisional[idx] += 1;
        remainder -= 1;
      }
    }

    return provisional.map((value) => value / 100).toList();
  }
}

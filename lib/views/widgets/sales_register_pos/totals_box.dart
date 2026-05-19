import 'package:flutter/material.dart';

class TotalsBox extends StatelessWidget {
  const TotalsBox({
    super.key,
    required this.lines,
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final double lines;
  final double subTotal;
  final double discount;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lines: €${lines.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
            Text(
              'Subtotal: €${subTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Disc: €${discount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
            Text(
              'TAX: €${tax.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          height: 2,
          width: double.infinity,
          color: Colors.white,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'AMOUNT DUE: € ${total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
            ),
          ],
        ),
        const Spacer(),
        const Spacer(),
      ],
    );
  }
}

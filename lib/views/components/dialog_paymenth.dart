import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Class DiscountDialog manages discount dlgbox
/// parameters:
/// * [title] title of the msgbox
/// * [data] list of maps for showing items info on the order
/// * [onApplyDiscount] lambda function with 2 parameters to update discount and discount percent
/// * [showCancel] eneable or disable cancel button

class PaymentHDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;

  final bool showCancel;

  const PaymentHDialog({
    super.key,
    required this.title,
    required this.data,
    this.showCancel = false,
  });

  @override
  PaymentHDialogState createState() => PaymentHDialogState();
}

class PaymentHDialogState extends State<PaymentHDialog> {
  late List<Map<String, dynamic>> tempData;
  double totalPaid = 0.0;

  @override
  void initState() {
    super.initState();

    /// Initialise the temporal data from the original data.
    tempData = List<Map<String, dynamic>>.from(widget.data);
    Logger().d(widget.data[0]);

    totalPaid = _calculateTotalPaid();

    String? getPayTxnName(Map<String, dynamic> item) {
      return item['pay_txn_name']?.toString();
    }

    if (widget.data.isNotEmpty) {
      String? payTxnName = getPayTxnName(widget.data[0]);
      Logger().d(payTxnName ?? 'pay_txn_name not found.');
    } else {
      Logger().d('list "widget.data" is empty.');
    }
  }

  double _calculateTotalPaid() {
    return tempData.fold(0.0, (sum, item) {
      double amount = 0.0;
      if (item['pay_txn_amount'] is num) {
        amount = (item['pay_txn_amount'] as num).toDouble();
      } else if (item['pay_txn_amount'] is String) {
        amount = double.tryParse(item['pay_txn_amount']) ?? 0.0;
      }
      return sum + amount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildTotalDiscountTable(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (widget.showCancel)
          TextButton(
            child: const Text("Close"),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
      ],
    );
  }

  Widget _buildTotalDiscountTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const Text('Total Discount:', style: TextStyle(fontWeight: FontWeight.bold)),
        Table(
          columnWidths: const {
            0: FixedColumnWidth(200),
            1: FixedColumnWidth(200),
          },
          border: TableBorder.all(color: Colors.grey),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Fila de encabezado
            const TableRow(
              decoration: BoxDecoration(color: Color.fromARGB(255, 57, 57, 57)),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Method', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            // Filas dinámicas basadas en `tempData`
            ...tempData.map((item) {
              return TableRow(
                decoration: const BoxDecoration(color: Color.fromARGB(255, 66, 66, 66)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(item['pay_txn_name']?.toString() ?? 'N/A'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('€ ${item['pay_txn_amount']?.toString() ?? '0.00'}'),
                  ),
                ],
              );
            }),
          ],
        ),
        const SizedBox(height: 30),
        // Puedes ajustar estos textos según tus necesidades
        Text(
          'Total paid: €${totalPaid.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        // const Text(
        //   'Pending to paid: €',
        //   style: TextStyle(fontWeight: FontWeight.bold),
        // ),
      ],
    );
  }
}

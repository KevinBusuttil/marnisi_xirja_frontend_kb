import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:web_admin/helpers/sales_pricing_calculator.dart';

/// Class DiscountDialog manages discount dlgbox
/// parameters:
/// * [title] title of the msgbox
/// * [data] list of maps for showing items info on the order
/// * [onApplyDiscount] lambda function with 2 parameters to update discount and discount percent
/// * [showCancel] eneable or disable cancel button

class DiscountDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final Function(double discountAmount, double discountPct) onApplyDiscount;
  final bool showCancel;

  const DiscountDialog({
    super.key,
    required this.title,
    required this.data,
    required this.onApplyDiscount,
    this.showCancel = false,
  });

  @override
  DiscountDialogState createState() => DiscountDialogState();
}

class DiscountDialogState extends State<DiscountDialog> {
  late List<Map<String, dynamic>> tempData;
  String discountMode = "Total";
  double totalTempDiscount = 0.0;
  double subtotalTemp = 0.0;
  double totalDiscount = 0.0;
  double totalPct = 0.0;
  double discountTotalAmount = 0.0;
  double discountPerItems = 0.0;
  bool valueOrPercentDisc = true;
  late TextEditingController _discountControllerTotal;
  late Map<int, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _discountControllerTotal = TextEditingController(text: '0.00');
    _controllers = {};

    /// Initialise the temporal data from the original data.
    tempData = List<Map<String, dynamic>>.from(widget.data);

    /// Initialises all necessary values in tempData
    for (var i = 0; i < tempData.length; i++) {
      tempData[i]['temp_discount_value'] = 0.0;
      tempData[i]['temp_item_price'] = tempData[i]['item_price'] ?? 0.0;
    }

    // /// Calculate the subtotal after initializing all tempData values
    // subtotalTemp = tempData.fold(0.0, (sum, item) {
    //   double tempItemPrice = item['temp_item_price'] ?? 0.0;

    //   var suppItem = item["item_supplementary"]?.isNotEmpty == true ? item["item_supplementary"][0] : {};
    //   double suppItemPrice = suppItem['sup_item_price'] ?? 0.0;

    //   int itemQty = item['item_qty'] ?? 0;
    //   return sum + ((tempItemPrice + suppItemPrice) * itemQty);
    // });
    subtotalTemp = tempData.fold(0.0, (sum, item) {
      return sum + SalesPricingCalculator.itemDiscountableGross(item);
    });
  }

  @override
  void dispose() {
    _discountControllerTotal.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              _buildDiscountModeDropdown(),
              const SizedBox(height: 10),
              if (discountMode == "Total") _buildTotalDiscountTable(),
              if (discountMode == "Items") _buildItemsDiscountTable(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text("Apply"),
          onPressed: () {
            _applyDiscount();
            final discountAmount =
                SalesPricingCalculator.round2(discountPerItems);
            final discountPct = subtotalTemp <= 0
                ? 0.0
                : SalesPricingCalculator.round2(
                    (discountAmount / subtotalTemp) * 100,
                  );

            //Call the callback with new values
            widget.onApplyDiscount(discountAmount, discountPct);
            Navigator.of(context).pop(tempData);
          },
        ),
        if (widget.showCancel)
          TextButton(
            child: const Text("Cancel"),
            onPressed: () {
              Navigator.of(context).pop(null);
            },
          ),
      ],
    );
  }

  Widget _buildDiscountModeDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Choose Discount Mode: ",
            style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: discountMode,
            items: const [
              DropdownMenuItem(
                value: "Total",
                child: Text("Total Discount"),
              ),
              DropdownMenuItem(
                value: "Items",
                child: Text("Discount per Item"),
              ),
            ],
            onChanged: (String? newValue) {
              setState(() {
                discountMode = newValue!;
                _discountControllerTotal.text = '';
                _controllers = {};
                if (discountMode == "Items") {
                  for (var item in tempData) {
                    item['isPercentDiscount'] = true;
                  }
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalDiscountTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total Discount:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Table(
          columnWidths: const {
            0: FixedColumnWidth(200),
            1: FixedColumnWidth(200),
            2: FixedColumnWidth(200),
          },
          border: TableBorder.all(color: Colors.grey),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color.fromARGB(255, 57, 57, 57)),
              children: [
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Total Price',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Type of discount',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Value',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text('€${subtotalTemp.toStringAsFixed(2)}'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    alignment: Alignment.center,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<bool>(
                        value: valueOrPercentDisc,
                        items: const [
                          DropdownMenuItem(
                            value: true,
                            child: Text("% Discount"),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text("€ Discount"),
                          ),
                        ],
                        onChanged: (bool? value) {
                          setState(() {
                            valueOrPercentDisc = value!;
                            totalDiscount = 0.0;
                            _discountControllerTotal.text = '0.00';
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: TextFormField(
                      controller: _discountControllerTotal,
                      textAlign: TextAlign.right,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) {
                        setState(() {
                          totalDiscount = double.tryParse(value) ?? 0.0;

                          if (valueOrPercentDisc) {
                            if (totalDiscount > 100) {
                              totalDiscount = 0;
                              totalPct = 0;
                            }
                            discountTotalAmount = SalesPricingCalculator.round2(
                              subtotalTemp * (totalDiscount / 100),
                            );
                            totalPct = totalDiscount;
                          } else {
                            if (totalDiscount > subtotalTemp) {
                              totalDiscount = 0;
                            }
                            discountTotalAmount =
                                SalesPricingCalculator.round2(totalDiscount);
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Total after Discount: €${(subtotalTemp - discountTotalAmount).toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildItemsDiscountTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Discount per Item:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(
          width: 800,
          child: Divider(
            color: Color.fromARGB(255, 167, 164, 164),
            thickness: 1.0,
            height: 10,
          ),
        ),
        const SizedBox(height: 10),
        Table(
          columnWidths: const {
            0: FixedColumnWidth(50),
            1: FlexColumnWidth(150),
            2: FixedColumnWidth(80),
            3: FixedColumnWidth(130),
            4: FixedColumnWidth(80),
            5: FixedColumnWidth(80),
          },
          border: TableBorder.all(color: Colors.grey),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header row (ensure it has 6 cells)
            const TableRow(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 57, 57, 57),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Qty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Item Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Disc Type',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Value',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'New Price',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            /// Dynamic rows (ensure each has 6 cells)
            ...tempData.asMap().entries.map<TableRow>((entry) {
              var item = entry.value;
              int index = entry.key;
              final lineGross =
                  SalesPricingCalculator.itemDiscountableGross(item);

              if (!_controllers.containsKey(index)) {
                _controllers[index] = TextEditingController();
              }

              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: Text('${item['item_qty']}',
                        textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
                    child: Text(' ${item['item_name']}',
                        textAlign: TextAlign.left),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
                    child: Text("€ ${lineGross.toStringAsFixed(2)}"),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      alignment: Alignment.center,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<bool>(
                          value: item['isPercentDiscount'] ?? true,
                          items: const [
                            DropdownMenuItem(
                              value: true,
                              child: Text("% Discount"),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text("€ Discount"),
                            ),
                          ],
                          onChanged: (bool? value) {
                            setState(() {
                              item['isPercentDiscount'] = value!;

                              // Clear the text field when changing selection
                              _controllers[index]
                                  ?.clear(); // Clears the TextFormField

                              // Reset discount value and price
                              item['temp_discount_value'] = 0.0;
                              item['temp_item_price'] = lineGross;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
                    child: TextFormField(
                      controller: _controllers[index],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (value) {
                        setState(() {
                          double discountValue = double.tryParse(value) ?? 0.0;
                          final originalGross = lineGross;

                          if (item['isPercentDiscount']) {
                            // Apply discount as percentage
                            final discountAmount =
                                originalGross * (discountValue / 100);
                            final safeDiscount = SalesPricingCalculator.round2(
                              math.min(
                                  math.max(discountAmount, 0.0), originalGross),
                            );
                            item['temp_discount_value'] = safeDiscount;
                            item['temp_item_price'] =
                                SalesPricingCalculator.round2(
                              originalGross - safeDiscount,
                            );
                          } else {
                            // Apply discount as fixed value
                            final safeDiscount = SalesPricingCalculator.round2(
                              math.min(
                                  math.max(discountValue, 0.0), originalGross),
                            );
                            item['temp_discount_value'] = safeDiscount;
                            item['temp_item_price'] =
                                SalesPricingCalculator.round2(
                              originalGross - safeDiscount,
                            );
                          }

                          totalTempDiscount = tempData.fold<double>(
                            0,
                            (sum, row) =>
                                sum +
                                SalesPricingCalculator.asDouble(
                                  row['temp_discount_value'],
                                ),
                          );

                          if (totalTempDiscount < 0) {
                            totalTempDiscount = 0;
                          }
                        });
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 1.0),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(3, 0, 3, 0),
                    child: Text(
                      "€ ${(lineGross - SalesPricingCalculator.asDouble(item['temp_discount_value'])).toStringAsFixed(2)}",
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  void _applyDiscount() {
    discountPerItems = 0.0; // Reset discountPerItems

    if (discountMode == "Total") {
      final bases = tempData
          .map((item) => SalesPricingCalculator.itemDiscountableGross(item))
          .toList();
      final allocations = SalesPricingCalculator.allocateDiscountProportionally(
        bases: bases,
        totalDiscount: discountTotalAmount,
      );

      for (var i = 0; i < tempData.length; i++) {
        final lineGross = bases[i];
        final lineDiscount = allocations[i];
        widget.data[i]['item_disc_amount'] = lineDiscount;
        widget.data[i]['item_disc_perct'] = lineGross <= 0
            ? 0.0
            : SalesPricingCalculator.round2((lineDiscount / lineGross) * 100);
        discountPerItems += lineDiscount;
      }

      discountPerItems = SalesPricingCalculator.round2(discountPerItems);
      return;
    }

    for (var i = 0; i < tempData.length; i++) {
      final lineGross =
          SalesPricingCalculator.itemDiscountableGross(tempData[i]);
      final lineDiscount = SalesPricingCalculator.round2(
        SalesPricingCalculator.asDouble(tempData[i]['temp_discount_value']),
      );

      final safeDiscount = SalesPricingCalculator.round2(
        math.min(math.max(lineDiscount, 0.0), lineGross),
      );

      widget.data[i]['item_disc_amount'] = safeDiscount;
      widget.data[i]['item_disc_perct'] = lineGross <= 0
          ? 0.0
          : SalesPricingCalculator.round2((safeDiscount / lineGross) * 100);
      discountPerItems += safeDiscount;
    }

    discountPerItems = SalesPricingCalculator.round2(discountPerItems);
  }
}

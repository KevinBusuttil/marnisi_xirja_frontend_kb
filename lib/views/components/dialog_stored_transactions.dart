import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:web_admin/services/database_service.dart';

class DialogStoreTransactions extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final bool showCancel;

  const DialogStoreTransactions({
    super.key,
    required this.title,
    required this.data,
    this.showCancel = false,
  });

  @override
  DialogStoreTransactionsState createState() => DialogStoreTransactionsState();
}

class DialogStoreTransactionsState extends State<DialogStoreTransactions> {
  int? _expandedIndex;
  final _dbHelper = SqlLiteService();
  final logger = Logger(printer: PrettyPrinter());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildExpandableTable(),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (widget.showCancel)
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExpandableTable() {
    return Column(
      children: [
        // Fila de títulos para las columnas
        Table(
          columnWidths: const {
            0: FixedColumnWidth(50),
            1: FixedColumnWidth(120),
            2: FixedColumnWidth(200),
            3: FixedColumnWidth(100),
            4: FixedColumnWidth(70),
            5: FixedColumnWidth(70),
          },
          border: TableBorder.all(color: const Color.fromARGB(50, 255, 254, 255)),
          children: const [
            TableRow(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 57, 57, 57),
              ),
              children: [
                SizedBox.shrink(), // Espacio para el botón de expandir
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Date',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Sale Num',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Total',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox.shrink(),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Cuerpo expandible de la tabla
        ...widget.data.asMap().entries.map<Widget>((entry) {
          int index = entry.key;
          Map<String, dynamic> transaction = entry.value;

          return Column(
            children: [
              Table(
                columnWidths: const {
                  0: FixedColumnWidth(50),
                  1: FixedColumnWidth(120),
                  2: FixedColumnWidth(200),
                  3: FixedColumnWidth(100),
                  4: FixedColumnWidth(70),
                  5: FixedColumnWidth(70),
                },
                border: TableBorder.all(color: const Color.fromARGB(50, 255, 255, 255)),
                children: [
                  TableRow(
                    children: [
                      IconButton(
                        icon: Icon(
                          _expandedIndex == index ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _expandedIndex = _expandedIndex == index ? null : index;
                          });
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          transaction['sale_date'],
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          transaction['sale_num'],
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '€${transaction['sale_total'].toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(transaction['items']);
                        },
                        child: const Text(
                          'Load',
                          style: TextStyle(color: Color.fromARGB(255, 20, 202, 120)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _deleteTransaction(index);
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  color: const Color.fromARGB(255, 57, 57, 57),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8.0),
                      Table(
                        columnWidths: const {
                          0: FixedColumnWidth(300),
                          1: FixedColumnWidth(70),
                          2: FixedColumnWidth(70),
                          3: FixedColumnWidth(70),
                        },
                        border: TableBorder.all(color: const Color.fromARGB(50, 255, 255, 255)),
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color.fromARGB(255, 57, 57, 57)),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Item Name',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Price',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Total',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          ...List.generate(
                            (transaction['items'] as List<Map<String, dynamic>>).length,
                            (itemIndex) {
                              var item = (transaction['items'] as List<Map<String, dynamic>>)[itemIndex];
                              return TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      item['item_name'],
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      '${item['item_qty']}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      '€${item['item_price']}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      '€${item['item_total']}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                crossFadeState: _expandedIndex == index ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          );
        }),
      ],
    );
  }

  void _deleteTransaction(int index) {
    // Get the transaction ID before you remove it from the list
    final String transactionNum = widget.data[index]['sale_num'].toString();

    setState(() {
      widget.data.removeAt(index);
    });
    try {
      _dbHelper.deleteStoreTxn(transactionNum);
      logger.d("Transacción con ID $transactionNum eliminada de la base de datos.");
    } catch (e) {
      logger.d("Error al eliminar la transacción con ID $transactionNum: $e");
    }
  }
}

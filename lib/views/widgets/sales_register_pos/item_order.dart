import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class ItemOrder extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final VoidCallback onRemove;
  final Function(String) onQtyChanged;
  final Function() clearOrder;

  const ItemOrder({
    super.key,
    required this.index,
    required this.data,
    required this.onRemove,
    required this.onQtyChanged,
    required this.clearOrder,
  });

  @override
  State<ItemOrder> createState() => _ItemOrderState();
}

class _ItemOrderState extends State<ItemOrder> {
  late TextEditingController _controller;
  final logger = Logger(printer: PrettyPrinter());
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.data['item_qty'].toString());
    _focusNode.addListener(_onFocusChange);
    widget.data['box_color'] ??= const Color.fromARGB(255, 120, 102, 71); // Initialize color if not already set
  }

  @override
  void didUpdateWidget(covariant ItemOrder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data['item_qty'].toString() != _controller.text) {
      _controller.text = widget.data['item_qty'].toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Update the amount only when focus is lost
      updateQuantity();
    }
  }

  void updateQuantity() {
    final parsedValue = int.tryParse(_controller.text);
    if (parsedValue != null) {
      if (parsedValue == 0) {
        widget.onRemove();
      } else {
        // Update the quantity of the main item
        widget.onQtyChanged(parsedValue.toString());

        //Update the amount of additional items
        final supplementaryData = widget.data['item_supplementary'];
        if (supplementaryData != null) {
          if (supplementaryData is List) {
            for (var item in supplementaryData) {
              // Adjust the amount of the supplement to the same value as the principal
              item['sup_item_qty'] = parsedValue;
            }
          } else if (supplementaryData is Map) {
            // Adjust the amount of the single supplement
            supplementaryData['sup_item_qty'] = parsedValue;
          }
        }
      }
    } else {
      // Restore the quantity of the main item if the entry is not valid
      _controller.text = widget.data['item_qty'].toString();
    }

    // update UI
    setState(() {});
  }

  void changeQuantity(int change) {
    setState(() {
      final parsedValue = int.tryParse(_controller.text) ?? widget.data['item_qty'];
      final updatedValue = parsedValue + change;
      if (updatedValue <= 0) {
        logger.d('Quantity is zero or less, triggering onRemove');
        widget.onRemove();
      } else {
        _controller.text = updatedValue.toString();
        widget.onQtyChanged(updatedValue.toString());

        // Update supplementary items quantity
        final supplementaryData = widget.data['item_supplementary'];
        if (supplementaryData != null) {
          if (supplementaryData is List) {
            for (var item in supplementaryData) {
              item['sup_item_qty'] = (item['sup_item_qty'] ?? 0) + change;
            }
          } else if (supplementaryData is Map) {
            supplementaryData['sup_item_qty'] = (supplementaryData['sup_item_qty'] ?? 0) + change;
          }
        }
      }
    });
  }

  void toggleBoxColorAndUpdateData() {
    setState(() {
      // Toggle the main item's color
      widget.data['box_color'] = widget.data['box_color'] == const Color.fromARGB(255, 120, 102, 71)
          ? const Color.fromARGB(130, 255, 47, 0)
          : const Color.fromARGB(255, 120, 102, 71);

      // Toggle the main item's quantity
      widget.data['item_qty'] = -(widget.data['item_qty']);
      _controller.text = widget.data['item_qty'].toString();
      widget.onQtyChanged(widget.data['item_qty'].toString());

      // Toggle supplementary items
      final supplementaryData = widget.data['item_supplementary'];
      if (supplementaryData != null) {
        if (supplementaryData is List) {
          for (var item in supplementaryData) {
            // Initialize color if not already set
            item['box_color'] ??= const Color.fromARGB(255, 120, 102, 71);

            // Toggle quantity and color
            item['sup_item_qty'] = -(item['sup_item_qty']);
            item['box_color'] = item['box_color'] == const Color.fromARGB(255, 120, 102, 71)
                ? const Color.fromARGB(130, 255, 47, 0)
                : const Color.fromARGB(255, 120, 102, 71);
          }
        } else if (supplementaryData is Map) {
          supplementaryData['box_color'] ??= const Color.fromARGB(255, 120, 102, 71);

          // Toggle quantity and color
          supplementaryData['sup_item_qty'] = -(supplementaryData['sup_item_qty']);
          supplementaryData['box_color'] = supplementaryData['box_color'] == const Color.fromARGB(255, 120, 102, 71)
              ? const Color.fromARGB(130, 255, 47, 0)
              : const Color.fromARGB(255, 120, 102, 71);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMainItemTile(),
        if (widget.data['item_supplementary'] != null) ..._buildSupplementaryItems(widget.data['item_supplementary']),
      ],
    );
  }

  Widget _buildMainItemTile() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 5, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: widget.data['box_color'],
      ),
      child: ListTile(
        leading: _returnIconBtn(),
        title: _buildTitleRow(),
        subtitle: _buildQuantityControls(),
        trailing: _buildPriceAndRemove(),
      ),
    );
  }

  Widget _returnIconBtn() {
    return Tooltip(
      message: 'Return',
      child: IconButton(
        icon: const Icon(Icons.assignment_return, color: Colors.yellow, size: 25),
        onPressed: toggleBoxColorAndUpdateData,
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Tooltip(
            message: 'Item Name: ${widget.data['item_name']}',
            child: Text(
              widget.data['item_name'].toUpperCase(),
              style: const TextStyle(
                color: Color.fromARGB(255, 223, 219, 219),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
        Tooltip(
          message: 'Cod: ${widget.data['item_id']}',
          child: Text(
            'Cod: ${widget.data['item_id']}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w100,
              fontSize: 8,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.white, size: 16),
          onPressed: widget.data['item_qty'] < 0 ? null : () => changeQuantity(-1),
        ),
        SizedBox(
          width: 50,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 0),
            ),
            keyboardType: TextInputType.number,
            enabled: widget.data['item_qty'] >= 0, // Disable if quantity is negative
            focusNode: _focusNode,
            onSubmitted: (_) => updateQuantity(),
            //onChanged: (_) => updateQuantity(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 16),
          onPressed: widget.data['item_qty'] < 0 ? null : () => changeQuantity(1),
        ),
        const Spacer(),
        Text(
          'Unit: ${widget.data['item_unit']}',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPriceAndRemove() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '€ ${widget.data['item_price']}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          icon: const Icon(Icons.remove_circle, color: Color.fromARGB(255, 255, 17, 0), size: 25),
          onPressed: widget.onRemove,
        ),
      ],
    );
  }

  List<Widget> _buildSupplementaryItems(dynamic supplementaryData) {
    final items = supplementaryData is List ? supplementaryData : [supplementaryData];

    return items.map((item) {
      return Container(
        margin: const EdgeInsets.fromLTRB(30, 0, 5, 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: item['box_color'] ?? const Color.fromARGB(255, 120, 102, 71),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: 'Supplementary Item Name: ${item['sup_item_name']}',
                      child: Text(
                        item['sup_item_name'].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '€ ${item['sup_item_price']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 50)
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Qty: ${item['sup_item_qty']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Unit: ${item['sup_item_unit']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 50)
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

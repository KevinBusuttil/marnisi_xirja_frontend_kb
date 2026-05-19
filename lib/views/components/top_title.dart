import 'package:flutter/material.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/views/components/dialog_stored_transactions.dart';

class TopTitle extends StatefulWidget {
  final String title;
  final String subTitle;
  final Widget action;
  final bool showButtons;
  final VoidCallback? onReplyButtonPressed;
  final Function(List<Map<String, dynamic>>)? onUpdateOrderItems;

  const TopTitle({
    super.key,
    required this.title,
    this.subTitle = '',
    required this.action,
    this.showButtons = false,
    this.onReplyButtonPressed,
    this.onUpdateOrderItems,
  });

  @override
  TopTitleState createState() => TopTitleState();
}

class TopTitleState extends State<TopTitle> {
  final _dbHelper = SqlLiteService();
  List<Map<String, dynamic>>? orderItems;
  bool isLoading = false;
  String? errorMessage;

  Future<void> _fetchPendingTransactions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await _dbHelper.getAllPendingTxn();
      if (!mounted) return;

      setState(() {
        orderItems = data;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading items: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnackBarMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showPendingTransactionsDialog() async {
    if (!mounted || orderItems == null || orderItems!.isEmpty) return;

    // Show the dialog and wait for items to be selected
    final selectedItems = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (BuildContext context) {
        return DialogStoreTransactions(
          title: 'Pending Transactions',
          data: orderItems!,
          showCancel: true,
        );
      },
    );

    // If the user selected items and pressed "Load
    if (selectedItems != null) {
      _updateOrderWithSelectedItems(selectedItems);
    }
  }

  void _updateOrderWithSelectedItems(List<Map<String, dynamic>> items) {
    if (widget.onUpdateOrderItems != null) {
      widget.onUpdateOrderItems!(items);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color.fromARGB(255, 31, 32, 41),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 5, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (widget.subTitle.isNotEmpty)
                    Text(
                      widget.subTitle,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.showButtons)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.save),
                  color: Colors.white,
                  onPressed: () {
                    if (widget.onReplyButtonPressed != null) {
                      widget.onReplyButtonPressed!();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.reply_all_rounded),
                  color: Colors.white,
                  onPressed: () async {
                    await _fetchPendingTransactions();
                    if (!mounted) return;
                    if (isLoading) {
                      _showSnackBarMessage('Loading pending transactions...');
                    } else if (errorMessage != null) {
                      _showSnackBarMessage(errorMessage!);
                    } else if (orderItems == null || orderItems!.isEmpty) {
                      _showSnackBarMessage('No data available');
                    } else {
                      await _showPendingTransactionsDialog();
                    }
                  },
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: widget.action,
          ),
        ],
      ),
    );
  }
}

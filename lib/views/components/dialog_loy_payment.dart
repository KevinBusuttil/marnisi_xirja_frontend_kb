import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:web_admin/services/database_service.dart';

/// Class to manage dialog boxes
/// about payment methods a returns
///
/// Arguments:
/// * [context] reference to current context.
/// * [title]  tittle of the msg box.
/// * [message]  message could be a dynamic type.
/// * [showCancel]  show cancel button.
/// * [showTextField]  show a text field
/// * [isReturn]  show the customization to manage returns.
/// * [updateBalance]  receive a lambda function to update new amount pending to pay
/// * [getBalance]  receive the transaction balance.
/// * [onAdditionalInfoEntered]  show the text field to get the custom receipt info.

class DialogLoyPayment {
  Future<bool?> showDialogBox({
    required BuildContext context,
    required String title,
    required dynamic message,
    bool showCancel = false,
    bool showTextField = false,
    bool isReturn = false,
    Function(double, {bool isReturn})? updateBalance,
    double Function()? getBalance,
    Function(String)? updatePaymentMethod,
    Function(String, String)? onAdditionalInfoEntered,
  }) {
    final dbSqlLiteHelper = SqlLiteService();
    final logger = Logger(printer: PrettyPrinter());
    late final Map<String, dynamic>? userData;

    final TextEditingController customerID = TextEditingController();
    bool showError = false;

    /// Check if the message is a String or Widget
    Widget contentWidget;
    if (message is String) {
      contentWidget = Text(message);
    } else if (message is Widget) {
      contentWidget = message;
    } else {
      throw ArgumentError('Message should be a widget or string');
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool showAdditionalInfo = false;
        String warningMsg = '';
        String userName = '';
        int userPoints = 0;
        String userCash = '';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  contentWidget,
                  if (showTextField) ...[
                    const SizedBox(height: 16.0),
                    TextField(
                      controller: customerID,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Customer ID',
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9A-Z]*')),
                      ],
                    ),
                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            warningMsg,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16.0),

                  /// Separator
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      child: const Text("Get Info"),
                      onPressed: () async {
                        String value = customerID.text;
                        if (value.isEmpty) {
                          setState(() {
                            showError = true;
                            warningMsg = "Please set the customer ID";
                            showAdditionalInfo = false; // Ensure the section is hidden
                          });
                          return;
                        }
                        userData = await dbSqlLiteHelper.getCustxId(customerID.text);
                        logger.d(userData);
                        if (userData != null) {
                          setState(() {
                            showError = false;
                            warningMsg = "";
                            userName = userData?['loy_custx_name'];
                            userPoints = userData?['loy_custx_points'];
                            userCash = userData!['loy_custx_points'].toString();
                            showAdditionalInfo = true;
                          });
                        } else {
                          setState(() {
                            showError = true;
                            warningMsg = "User not found";
                            showAdditionalInfo = false; // Hide the section
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (showAdditionalInfo)
                    Column(
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Table Section
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 600, // Adjust this value to fit the box size you need
                            minWidth: 400, // Optional: Minimum width constraint
                          ),
                          child: Table(
                            border: TableBorder.all(
                                color: const Color.fromARGB(255, 138, 136, 136)), // Add borders to the table
                            columnWidths: const {
                              0: FlexColumnWidth(1), // Points column
                              1: FlexColumnWidth(1), // Amount column
                              2: FlexColumnWidth(1), // Button column
                            },

                            children: [
                              // Table Header
                              const TableRow(
                                decoration: BoxDecoration(color: Color.fromARGB(49, 39, 39, 39)),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Points',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Amount',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      '',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              // Single Table Row
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(userPoints.toString()), // Replace with dynamic Points value
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text('€ $userCash'), // Replace with dynamic Amount value
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextButton(
                                      onPressed: () {
                                        int points = userData?['loy_custx_points'];
                                        double? payAmount = points.toDouble();

                                        /// balance update
                                        if (updateBalance != null) {
                                          updateBalance(payAmount);
                                        }

                                        if (getBalance != null && getBalance() > 0) {
                                          Navigator.of(context).pop(false);
                                          return;
                                        }
                                        Navigator.of(context).pop(true);
                                      },
                                      child: const Text('Use'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                ],
              ),
              actions: <Widget>[
                if (showCancel)
                  TextButton(
                    child: const Text("Cancel"),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

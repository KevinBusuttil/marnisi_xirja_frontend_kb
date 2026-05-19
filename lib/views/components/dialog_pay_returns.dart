import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_admin/helpers/payment_flow_helper.dart';

/// Class to manage dialog boxes
/// show dialogbox according the parameters
/// dialogbox to make the payment
/// dialogbox to show simple message
/// dialogbox to make returns
///
/// Arguments:
/// * [context] reference to current context.
/// * [title]  tittle of the msg box.
/// * [message]  message could be a dynamic type.
/// * [showCancel]  show cancel button.
/// * [showTextField]  show a text field if you need receive data from the user.
/// * [isReturn]  show the customization to manage returns.
/// * [isCash] show buttons on the bottom of the textfield to fill with prefixed values
/// * [updateBalance]  receive a lambda function to calculate new balance a store payment methods.
/// * [getBalance]  receive the transaction balance.
/// * [onAdditionalInfoEntered] receive a lambda function to update customer info

class DialogPayAndReturns {
  Future<bool?> showDialogBox({
    required BuildContext context,
    required String title,
    required dynamic message,
    bool showCancel = false,
    bool showTextField = false,
    bool isReturn = false,
    bool isCash = false,
    Function(double, {bool isReturn})? updateBalance,
    double Function()? getBalance,
    double Function()? getChange,
    double totalPay = 0,
    Function(String)? updatePaymentMethod,
    Function(String, String)? onAdditionalInfoEntered,
  }) {
    final TextEditingController amountController = TextEditingController();
    final FocusNode amountFocusNode = FocusNode();
    final TextEditingController customName = TextEditingController();
    final TextEditingController customVat = TextEditingController();
    bool showError = false;
    // double previewChange = 0.0;

    //buttons style
    final ButtonStyle generalButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: const Color.fromARGB(255, 58, 124, 4), // Color de fondo
      foregroundColor: Colors.white, // Color del texto
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0), //
      ),
    );

    /// Check if the message is a String or Widget
    Widget contentWidget;
    if (message is String) {
      contentWidget = Text(message);
    } else if (message is Widget) {
      contentWidget = message;
    } else {
      throw ArgumentError('Message should be a widget or string');
    }

    amountController.text = PaymentFlowHelper.initialAmountText(
      totalPay: totalPay,
      balance: getBalance?.call(),
    );

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool showAdditionalInfo = false;
        bool checkBox1 = false;
        bool checkBox2 = false;
        String warningMsg = '';
        double previewChange = 0.0;

        double pendingToPay() {
          return PaymentFlowHelper.resolvePendingAmount(
            totalPay: totalPay,
            balance: getBalance?.call(),
          );
        }

        void updatePreview() {
          final pending = pendingToPay();
          final entered = PaymentFlowHelper.normalizeEnteredAmount(
            amountController.text,
            pendingAmount: pending,
          );
          previewChange = PaymentFlowHelper.calculateCashPreviewChange(
            isCash: isCash,
            pendingAmount: pending,
            enteredAmount: entered,
          );
        }

        return StatefulBuilder(
          builder: (context, setState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (showTextField) {
                FocusScope.of(context).requestFocus(amountFocusNode);
              }
            });
            void handleOkAction() {
              String value = amountController.text.trim();
              final pending = pendingToPay();
              final isPayout = pending < 0;
              final payAmount = PaymentFlowHelper.normalizeEnteredAmount(
                value,
                pendingAmount: pending,
              );

              if (!PaymentFlowHelper.isEnteredAmountValid(
                rawAmount: value,
                pendingAmount: pending,
              )) {
                setState(() {
                  showError = true;
                  warningMsg = isPayout
                      ? "Please set a valid payout amount"
                      : "Please set the amount";
                });
                return;
              }

              if (updateBalance != null) {
                updateBalance(payAmount, isReturn: isReturn);
              }

              // if (getBalance != null && getBalance() > 0) {
              //   Navigator.of(context).pop(false);
              //   return;
              // }
              // 3️⃣ If there is STILL balance pending → keep dialog open
              if ((getBalance?.call() ?? 0) > 0) {
                setState(() {}); // refresh UI (change / balance)
                return;
              }

              previewChange = 0.0;

              if (onAdditionalInfoEntered != null) {
                onAdditionalInfoEntered(customName.text, customVat.text);
              }

              Navigator.of(context).pop(true);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  contentWidget,
                  if (showTextField) ...[
                    const SizedBox(height: 16.0),

                    /// Separator
                    // TextField(
                    //   controller: amountController,
                    //   focusNode: amountFocusNode,
                    //   keyboardType: TextInputType.number,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Amount',
                    //   ),
                    //   inputFormatters: <TextInputFormatter>[
                    //     FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*')),
                    //   ],
                    //   onSubmitted: (_) => handleOkAction(),
                    // ),

                    TextField(
                      controller: amountController,
                      focusNode: amountFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^[0-9]*\.?[0-9]*')),
                      ],
                      onSubmitted: (_) => handleOkAction(),
                      // onChanged: (value) {
                      //   final amount = double.tryParse(value) ?? 0.0;

                      //   if (amount > 0 && updateBalance != null) {
                      //     updateBalance(amount, isReturn: isReturn);
                      //     setState(() {}); // 🔥 refresh to show change
                      //   }
                      // },
                      onChanged: (_) {
                        setState(updatePreview); // ✅ SAFE
                      },
                    ),

                    const SizedBox(height: 8.0),
                    if (isCash) ...{
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            style: generalButtonStyle,
                            onPressed: () {
                              setState(() {
                                amountController.text = '5';
                                updatePreview();
                              });
                            },
                            child: const Text(' €5'),
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton(
                            style: generalButtonStyle,
                            onPressed: () {
                              setState(() {
                                amountController.text = '10';
                                updatePreview();
                              });
                            },
                            child: const Text(' €10'),
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton(
                            style: generalButtonStyle,
                            onPressed: () {
                              setState(() {
                                amountController.text = '20';
                                updatePreview();
                              });
                            },
                            child: const Text(' €20'),
                          ),
                          const SizedBox(width: 2),
                          ElevatedButton(
                            style: generalButtonStyle,
                            onPressed: () {
                              setState(() {
                                amountController.text = '50';
                                updatePreview();
                              });
                            },
                            child: const Text(' €50'),
                          ),
                        ],
                      ),
                    },
                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            warningMsg,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ),
                    if (isReturn) ...[
                      CheckboxListTile(
                        title: const Text('Cash'),
                        value: checkBox1,
                        onChanged: (bool? value) {
                          setState(() {
                            checkBox1 = value ?? false;
                            checkBox2 = !checkBox1;
                            updatePaymentMethod!('1');
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('Card BOV'),
                        value: checkBox2,
                        onChanged: (bool? value) {
                          setState(() {
                            checkBox2 = value ?? false;
                            checkBox1 = !checkBox2;
                            updatePaymentMethod!('7');
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16.0),

                    //                     if ((getChange?.call() ?? 0) > 0) ...[
                    //   const SizedBox(height: 10),
                    //   Align(
                    //     alignment: Alignment.centerRight,
                    //     child: Text(
                    //       'Change: € ${getChange!().toStringAsFixed(2)}',
                    //       style: const TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         color: Colors.green,
                    //         fontSize: 14,
                    //       ),
                    //     ),
                    //   ),
                    // ],
                    if (isCash &&
                        (previewChange > 0 || (getChange?.call() ?? 0) > 0) &&
                        pendingToPay() > 0) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Change: € ${(previewChange > 0 ? previewChange : (getChange?.call() ?? 0)).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ],

                    /// Separator
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            showAdditionalInfo = !showAdditionalInfo;
                          });
                        },
                        child: const Text("Add Info"),
                      ),
                    ),
                    if (showAdditionalInfo)
                      Column(
                        children: [
                          const SizedBox(height: 8.0),
                          TextField(
                            controller: customName,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9 ]')),
                            ],
                          ),
                          TextField(
                            controller: customVat,
                            decoration: const InputDecoration(
                              labelText: 'VAT Number',
                            ),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9 ]')),
                            ],
                          ),
                        ],
                      ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    if (showTextField) {
                      if (isReturn) {
                        /// Validation for return
                        if (!(checkBox1 || checkBox2)) {
                          setState(() {
                            showError = true;
                            warningMsg = "Please set the payment method";
                          });
                          return;
                        }
                      }

                      /// balance update
                      handleOkAction();
                      // if (updateBalance != null) {
                      //   updateBalance(payAmount, isReturn: isReturn);
                      // }

                      // if (getBalance != null && getBalance() > 0) {
                      //   Navigator.of(context).pop(false);
                      //   return;
                      // }
                      // Navigator.of(context).pop(true);
                    } else {
                      Navigator.of(context).pop(true);
                    }

                    if (onAdditionalInfoEntered != null) {
                      onAdditionalInfoEntered(customName.text, customVat.text);
                    }
                  },
                ),
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

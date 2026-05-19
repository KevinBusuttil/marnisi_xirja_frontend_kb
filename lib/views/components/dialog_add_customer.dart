// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:web_admin/services/database_service.dart';
// /// Class to insert new customers
// /// return a widget dialogbox and insert new customer in the DB after validate data
// /// Arguments:
// /// * [context] reference to current context.
// /// * [title]  title of the msg box.
// /// * [mobileNumber] (Optional) Pre-fills the mobile number field.

// class DialogNewCustomer {
//   Future<bool?> showDialogBox({
//     required BuildContext context,
//     required String title,
//     String? mobileNumber, // MODIFIED: Added optional mobile number parameter
//   }) {
//     final dbSqlLiteHelper = SqlLiteService();
//     final GlobalKey<FormState> formKey = GlobalKey<FormState>();

//     // Controllers for the form fields
//     final TextEditingController newCustId = TextEditingController(text: mobileNumber);
//     final TextEditingController newCustName = TextEditingController();
//     final TextEditingController newCustSurName = TextEditingController();
//     final TextEditingController newCustMail = TextEditingController();
//     final TextEditingController newCustAddress = TextEditingController();
//     final TextEditingController newCustCity = TextEditingController();
//     // MODIFIED: Initialize mobile controller with the passed number
//     final TextEditingController newCustMobile = TextEditingController(text: mobileNumber);

//     String errorMessage = '';

//     return showDialog<bool>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         return StatefulBuilder(
//           builder: (BuildContext context, void Function(void Function()) setState) {
//             return AlertDialog(
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
//               title: Text(title),
//               content: SingleChildScrollView(
//                 child: SizedBox(
//                   width: 500,
//                   child: Form(
//                     key: formKey,
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: <Widget>[
//                         _buildRow(
//                           _buildTextField(
//                             controller: newCustId,
//                             label: 'Loyalty Card Number',
//                             keyboardType: TextInputType.text, // MODIFIED: Changed keyboard type
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9]*')),
//                             validator: (value) => _validateRequiredField(value, 'ID'),
//                           ),
//                           const SizedBox(),
//                         ),
//                         _buildRow(
//                           _buildTextField(
//                             controller: newCustName,
//                             label: 'Name',
//                             keyboardType: TextInputType.text,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z\s]*')),
//                             validator: (value) => _validateRequiredField(value, 'Name'),
//                           ),
//                           _buildTextField(
//                             controller: newCustSurName,
//                             label: 'Surname',
//                             keyboardType: TextInputType.text,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z\s]*')),
//                             validator: (value) => _validateRequiredField(value, 'Surname'),
//                           ),
//                         ),
//                         _buildRow(
//                           _buildTextField(
//                             controller: newCustMail,
//                             label: 'Email',
//                             keyboardType: TextInputType.emailAddress,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._%+-@]')),
//                             validator: _validateEmail,
//                           ),
//                         ),
//                         _buildRow(
//                           _buildTextField(
//                             controller: newCustAddress,
//                             label: 'Address',
//                             keyboardType: TextInputType.streetAddress,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9\s,.-]*')),
//                             validator: (value) => _validateRequiredField(value, 'Address'),
//                           ),
//                         ),
//                         _buildRow(
//                           _buildTextField(
//                             controller: newCustCity,
//                             label: 'City',
//                             keyboardType: TextInputType.text,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z\s]*')),
//                             validator: (value) => _validateRequiredField(value, 'City'),
//                           ),
//                           _buildTextField(
//                             controller: newCustMobile,
//                             label: 'Mobile Number',
//                             keyboardType: TextInputType.phone,
//                             inputFormatter: FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*')),
//                             validator: _validateMobileNumber,
//                           ),
//                         ),
//                         const SizedBox(height: 20),
//                         if (errorMessage.isNotEmpty)
//                           Text(
//                             errorMessage,
//                             style: const TextStyle(color: Colors.red, fontSize: 14),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   child: const Text("OK"),
//                   onPressed: () async {
//                     if (formKey.currentState!.validate()) {
//                       final isRegistered = await dbSqlLiteHelper.getCustxId(newCustId.text);

//                       if (isRegistered != null) {
//                         setState(() {
//                           errorMessage = 'User with ID ${newCustId.text} is already registered!';
//                         });
//                       } else {
//                         final data = _getCustomerData(
//                           newCustId: newCustId.text,
//                           newCustName: newCustName.text,
//                           newCustSurName: newCustSurName.text,
//                           newCustMail: newCustMail.text,
//                           newCustAddress: newCustAddress.text,
//                           newCustCity: newCustCity.text,
//                           newCustMobile: newCustMobile.text,
//                         );
//                         await dbSqlLiteHelper.saveNewCust(data);

//                         if (dialogContext.mounted) {
//                           Navigator.of(dialogContext).pop(true);
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text('User with ID ${newCustId.text} has been registered!'),
//                               duration: const Duration(seconds: 3),
//                             ),
//                           );
//                         }
//                       }
//                     }
//                   },
//                 ),
//                 TextButton(
//                   child: const Text("Cancel"),
//                   onPressed: () {
//                     if (dialogContext.mounted) {
//                       Navigator.of(dialogContext).pop(false);
//                     }
//                   },
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildRow(Widget leftField, [Widget? rightField]) {
//     return Row(
//       children: [
//         Expanded(child: leftField),
//         // const SizedBox(width: 10),
//         if (rightField != null) ...[
//           const SizedBox(width: 20), // Add spacing only if rightField is not null
//           Expanded(child: rightField),
//         ],
//       ],
//     );
//   }

//   String? _validateRequiredField(String? value, String fieldName) {
//     if (value == null || value.isEmpty) {
//       return '$fieldName is required';
//     }
//     return null;
//   }

//   String? _validateEmail(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Email is required';
//     }
//     final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
//     if (!emailRegex.hasMatch(value)) {
//       return 'Enter a valid email';
//     }
//     return null;
//   }

//   String? _validateMobileNumber(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Mobile number is required';
//     }
//     // if (value.length != 10) {
//     //   return 'Mobile number must be 10 digits';
//     // }
//     return null;
//   }

//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     required TextInputType keyboardType,
//     required TextInputFormatter inputFormatter,
//     required String? Function(String?) validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       keyboardType: keyboardType,
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: const TextStyle(
//           color: Color.fromARGB(255, 253, 253, 252),
//         ),
//         errorStyle: const TextStyle(
//           color: Color.fromARGB(255, 219, 32, 51),
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//       inputFormatters: [inputFormatter],
//       validator: validator,
//     );
//   }

//   Map<String, dynamic> _getCustomerData({
//     required String newCustId,
//     required String newCustName,
//     required String newCustSurName,
//     required String newCustMail,
//     required String newCustAddress,
//     required String newCustCity,
//     required String newCustMobile,
//   }) {
//     return {
//       'loy_custx_id': newCustId,
//       'loy_custx_card_num': newCustId,
//       'loy_custx_type': 'Person',
//       'loy_custx_first_name': newCustName,
//       'loy_custx_last_name': newCustSurName,
//       'loy_custx_name': '$newCustName $newCustSurName',
//       'loy_custx_email': newCustMail,
//       'loy_custx_address': newCustAddress,
//       'loy_custx_city': newCustCity,
//       'loy_custx_mobile': newCustMobile,
//       'loy_custx_balance': 0,
//       'loy_custx_points': 0,
//       'loy_custx_scheme': '',
//       'loy_custx_group': 'LY-SILVER',
//       'loy_custx_frozen': 0,
//       'loy_custx_sync_frappe': 'pending',
//     };
//   }
// }

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_admin/api_endpoints/routes_api.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/api_service.dart';

/// Class to insert new customers
/// return a widget dialogbox and insert new customer in the DB after validate data
/// Arguments:
/// * [context] reference to current context.
/// * [title]  title of the msg box.
/// * [mobileNumber] (Optional) Pre-fills the mobile number field.

class DialogNewCustomer {
  Future<bool?> showDialogBox({
    required BuildContext context,
    required String title,
    String? mobileNumber, // MODIFIED: Added optional mobile number parameter
  }) {
    final dbSqlLiteHelper = SqlLiteService();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    // Controllers for the form fields
    final TextEditingController newCustId =
        TextEditingController(text: mobileNumber);
    final TextEditingController newCustName = TextEditingController();
    final TextEditingController newCustSurName = TextEditingController();
    final TextEditingController newCustMail = TextEditingController();
    final TextEditingController newCustAddress = TextEditingController();
    final TextEditingController newCustCity = TextEditingController();
    // MODIFIED: Initialize mobile controller with the passed number
    final TextEditingController newCustMobile =
        TextEditingController(text: mobileNumber);

    String errorMessage = '';
    bool isLoading = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context,
              void Function(void Function()) setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0)),
              title: Text(title),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildRow(
                          _buildTextField(
                            controller: newCustId,
                            label: 'Loyalty Card Number',
                            keyboardType: TextInputType.text,
                            inputFormatter: FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z0-9]*')),
                            validator: (value) =>
                                _validateRequiredField(value, 'ID'),
                          ),
                          const SizedBox(),
                        ),
                        _buildRow(
                          _buildTextField(
                            controller: newCustName,
                            label: 'Name',
                            keyboardType: TextInputType.text,
                            inputFormatter: FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z\s]*')),
                            validator: (value) =>
                                _validateRequiredField(value, 'Name'),
                          ),
                          _buildTextField(
                            controller: newCustSurName,
                            label: 'Surname',
                            keyboardType: TextInputType.text,
                            inputFormatter: FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z\s]*')),
                            validator: (value) =>
                                _validateRequiredField(value, 'Surname'),
                          ),
                        ),
                        _buildRow(
                          _buildTextField(
                            controller: newCustMail,
                            label: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            inputFormatter:
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'[a-zA-Z0-9._%+-@]')),
                            validator: _validateEmail,
                          ),
                        ),
                        _buildRow(
                          _buildTextField(
                            controller: newCustAddress,
                            label: 'Address',
                            keyboardType: TextInputType.streetAddress,
                            inputFormatter:
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'^[a-zA-Z0-9\s,.-]*')),
                            validator: (value) =>
                                _validateRequiredField(value, 'Address'),
                          ),
                        ),
                        _buildRow(
                          _buildTextField(
                            controller: newCustCity,
                            label: 'City',
                            keyboardType: TextInputType.text,
                            inputFormatter: FilteringTextInputFormatter.allow(
                                RegExp(r'^[a-zA-Z\s]*')),
                            validator: (value) =>
                                _validateRequiredField(value, 'City'),
                          ),
                          _buildTextField(
                            controller: newCustMobile,
                            label: 'Mobile Number',
                            keyboardType: TextInputType.phone,
                            inputFormatter: FilteringTextInputFormatter.allow(
                                RegExp(r'^[0-9]*')),
                            validator: _validateMobileNumber,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (errorMessage.isNotEmpty)
                          Text(
                            errorMessage,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
  TextButton(
    child: const Text("OK"),
    onPressed: isLoading
        ? null
        : () async {
            if (formKey.currentState!.validate()) {
              setState(() {
                isLoading = true;
                errorMessage = '';
              });

              // Prepare API data (List<Map>)
              final List<Map<String, dynamic>> apiData = [
                {
                  "loy_cust_card_num": newCustId.text,
                  "loy_cust_first_name": newCustName.text,
                  "loy_cust_last_name": newCustSurName.text,
                  "loy_cust_email": newCustMail.text,
                  "loy_cust_city": newCustCity.text,
                  "loy_cust_scheme": 'SILVER',
                  "loy_cust_mobile": newCustMobile.text,
                }
              ];

              void showSnackbar(String message) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            try {
              final apiService = ApiService(endpointPath: ApiRoutes.createLoyUser);
              final Map<String, dynamic>? response =
                  await apiService.postData(apiData, showSnackbar);

              if (response != null && response['status'] == 'success') {
                final createdUser = response['user'];

                final localDbData = _getCustomerDataFromApiResponse(
                  Map<String, dynamic>.from(createdUser),
                );

                await dbSqlLiteHelper.saveNewCust(localDbData);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                  showSnackbar('User ${newCustId.text} has been registered!');
                }
              } else {
                setState(() {
                  errorMessage = 'Failed: ${response?['status'] ?? 'Unknown error'}';
                });
              }
            } catch (e) {
              log('Error creating customer: $e');
              setState(() {
                errorMessage = 'Failed to connect to the server. Please try again.';
              });
            } finally {
              setState(() {
                isLoading = false;
              });
            }}},
  ),
      TextButton(
        onPressed: isLoading
            ? null
            : () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(false);
                }
              },
        child: const Text("Cancel"),
      ),
            ],
            );
          },
        );
      },
    );
  }

  Widget _buildRow(Widget leftField, [Widget? rightField]) {
    return Row(
      children: [
        Expanded(child: leftField),
        if (rightField != null) ...[
          const SizedBox(width: 20),
          Expanded(child: rightField),
        ],
      ],
    );
  }

  String? _validateRequiredField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validateMobileNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number is required';
    }
    return null;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required TextInputFormatter inputFormatter,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color.fromARGB(255, 253, 253, 252),
        ),
        errorStyle: const TextStyle(
          color: Color.fromARGB(255, 219, 32, 51),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputFormatters: [inputFormatter],
      validator: validator,
    );
  }

  Map<String, dynamic> _getCustomerDataFromApiResponse(
      Map<String, dynamic> user) {
    return {
      'loy_custx_id': user['loy_cust_card_num'],
      'loy_custx_card_num': user['loy_cust_card_num'],
      'loy_custx_type': 'Person',
      'loy_custx_first_name': user['loy_cust_first_name'],
      'loy_custx_last_name': user['loy_cust_last_name'],
      'loy_custx_name':
          '${user['loy_cust_first_name']} ${user['loy_cust_last_name']}',
      'loy_custx_email': user['loy_cust_email'],
      'loy_custx_address': '',
      'loy_custx_city': user['loy_cust_city'],
      'loy_custx_mobile': user['loy_cust_mobile'],
      'loy_custx_balance': 0,
      'loy_custx_points': 0,
      'loy_custx_scheme': user['loy_cust_scheme'] ?? '',
      'loy_custx_group': 'LY-SILVER',
      'loy_custx_frozen': 0,
      'loy_custx_sync_frappe': 'pending',
    };
  }
}

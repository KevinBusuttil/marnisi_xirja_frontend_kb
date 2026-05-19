// import 'dart:convert';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:http/http.dart' as http;

// import 'package:awesome_dialog/awesome_dialog.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_form_builder/flutter_form_builder.dart';
// import 'package:form_builder_validators/form_builder_validators.dart';
// import 'package:go_router/go_router.dart';
// import 'package:provider/provider.dart';
// import 'package:web_admin/app_router.dart';
// import 'package:web_admin/constants/dimens.dart';
// import 'package:web_admin/generated/l10n.dart';
// import 'package:web_admin/providers/user_data_provider.dart';
// import 'package:web_admin/theme/theme_extensions/app_button_theme.dart';
// import 'package:web_admin/utils/app_focus_helper.dart';
// import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';
// import 'package:web_admin/environment.dart';
// import 'package:web_admin/api_endpoints/routes_api.dart';

// class RegisterScreen extends StatefulWidget {
//   const RegisterScreen({super.key});

//   @override
//   State<RegisterScreen> createState() => _RegisterScreenState();
// }

// class _RegisterScreenState extends State<RegisterScreen> {
//   final _passwordTextEditingController = TextEditingController();
//   final _formKey = GlobalKey<FormBuilderState>();
//   final _formData = FormData();
//   var _isFormLoading = false;

// // async function to register a new user
//   Future<void> _doRegisterAsync({
//     required UserDataProvider userDataProvider,
//     required void Function(String message) onSuccess,
//     required void Function(String message) onError,
//   }) async {
//     AppFocusHelper.instance.requestUnfocus();

//     if (_formKey.currentState?.validate() ?? false) {
//       // Validation passed.
//       _formKey.currentState!.save();
//       setState(() => _isFormLoading = true);

//       try {
//         String baseUrl = env.apiBaseUrl;
//         const path = ApiRoutes.newUser;
//         final url = Uri.http(baseUrl, path);
//         final response = await http.post(
//           url,
//           body: json.encode(_formKey.currentState?.value),
//           headers: {"Content-Type": "application/json"},
//         );

//         final responseData = json.decode(response.body);
//         var message = responseData['response']['message'];
//         var statusKey = responseData['response']['success_key'];

//         if (statusKey == 1) {
//           onSuccess.call(message ?? 'Registration successful. Please check your email for further instructions.');
//         } else {
//           onError.call(message ?? 'An error occurred. Please try again.');
//         }
//       } catch (error) {
//         onError.call('An unexpected error occurred. Please try again!!. \n$error');
//       } finally {
//         setState(() => _isFormLoading = false);
//       }
//     }
//   }

//   // method to show a dialog when registration is successful
//   void _onRegisterSuccess(BuildContext context, String message) {
//     final dialog = AwesomeDialog(
//       context: context,
//       dialogType: DialogType.success,
//       desc: message,
//       width: kDialogWidth,
//       btnOkText: Lang.of(context).loginNow,
//       btnOkOnPress: () => GoRouter.of(context).go(RouteUri.login),
//     );
//     dialog.show();
//   }

//   // method to show a dialog when registration is unsuccessful
//   void _onRegisterError(BuildContext context, String message) {
//     final dialog = AwesomeDialog(
//       context: context,
//       dialogType: DialogType.error,
//       desc: message,
//       width: kDialogWidth,
//       btnOkText: 'OK',
//       btnOkOnPress: () {},
//     );

//     dialog.show();
//   }

//   @override
//   void dispose() {
//     _passwordTextEditingController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final lang = Lang.of(context);
//     final themeData = Theme.of(context);

//     return PublicMasterLayout(
//       body: SingleChildScrollView(
//         child: Align(
//           alignment: Alignment.topCenter,
//           child: Container(
//             padding: const EdgeInsets.only(top: kDefaultPadding * 5.0),
//             constraints: const BoxConstraints(maxWidth: 400.0),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16.0),
//               child: Card(
//                 color: const Color.fromARGB(255, 58, 1, 1),
//                 clipBehavior: Clip.antiAlias,
//                 child: Padding(
//                   padding: const EdgeInsets.all(kDefaultPadding),
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: kDefaultPadding),
//                         child: SvgPicture.asset(
//                           'assets/images/CassarCamilleriLogo.svg',
//                           height: 120.0,
//                         ),
//                       ),
//                       Text(
//                         lang.appTitle,
//                         style: themeData.textTheme.headlineMedium!.copyWith(
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: kDefaultPadding * 2.0),
//                         child: Text(
//                           lang.registerANewAccount,
//                           style: themeData.textTheme.titleMedium,
//                         ),
//                       ),
//                       FormBuilder(
//                         key: _formKey,
//                         autovalidateMode: AutovalidateMode.disabled,
//                         child: Column(
//                           children: [
//                             // Full name
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
//                               child: FormBuilderTextField(
//                                 name: 'name',
//                                 decoration: InputDecoration(
//                                   labelText: lang.name,
//                                   hintText: lang.name,
//                                   helperText: 'Provide full name  ',
//                                   border: const OutlineInputBorder(),
//                                   floatingLabelBehavior: FloatingLabelBehavior.always,
//                                 ),
//                                 enableSuggestions: false,
//                                 validator: FormBuilderValidators.required(),
//                                 onSaved: (value) => (_formData.name = value ?? ''),
//                               ),
//                             ),
//                             //surname
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
//                               child: FormBuilderTextField(
//                                 name: 'surname',
//                                 decoration: InputDecoration(
//                                   labelText: lang.surname,
//                                   hintText: lang.surname,
//                                   helperText: 'Provide your surname  ',
//                                   border: const OutlineInputBorder(),
//                                   floatingLabelBehavior: FloatingLabelBehavior.always,
//                                 ),
//                                 enableSuggestions: false,
//                                 validator: FormBuilderValidators.required(),
//                                 onSaved: (value) => (_formData.surname = value ?? ''),
//                               ),
//                             ),
//                             //email
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
//                               child: FormBuilderTextField(
//                                 name: 'email',
//                                 decoration: InputDecoration(
//                                   labelText: lang.email,
//                                   hintText: lang.email,
//                                   border: const OutlineInputBorder(),
//                                   floatingLabelBehavior: FloatingLabelBehavior.always,
//                                 ),
//                                 keyboardType: TextInputType.emailAddress,
//                                 validator: FormBuilderValidators.required(),
//                                 onSaved: (value) => (_formData.email = value ?? ''),
//                               ),
//                             ),
//                             //password
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
//                               child: FormBuilderTextField(
//                                 name: 'password',
//                                 decoration: InputDecoration(
//                                   labelText: lang.password,
//                                   hintText: lang.password,
//                                   helperText: lang.passwordHelperText,
//                                   border: const OutlineInputBorder(),
//                                   floatingLabelBehavior: FloatingLabelBehavior.always,
//                                 ),
//                                 enableSuggestions: false,
//                                 obscureText: true,
//                                 controller: _passwordTextEditingController,
//                                 validator: FormBuilderValidators.compose([
//                                   FormBuilderValidators.required(),
//                                   FormBuilderValidators.minLength(6),
//                                   FormBuilderValidators.maxLength(18),
//                                 ]),
//                                 onSaved: (value) => (_formData.password = value ?? ''),
//                               ),
//                             ),
//                             //retype password
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding * 2.0),
//                               child: FormBuilderTextField(
//                                 name: 'retypePassword',
//                                 decoration: InputDecoration(
//                                   labelText: lang.retypePassword,
//                                   hintText: lang.retypePassword,
//                                   border: const OutlineInputBorder(),
//                                   floatingLabelBehavior: FloatingLabelBehavior.always,
//                                 ),
//                                 enableSuggestions: false,
//                                 obscureText: true,
//                                 validator: FormBuilderValidators.compose([
//                                   FormBuilderValidators.required(),
//                                   (value) {
//                                     if (_formKey.currentState?.fields['password']?.value != value) {
//                                       return lang.passwordNotMatch;
//                                     }

//                                     return null;
//                                   },
//                                 ]),
//                               ),
//                             ),
//                             //register button
//                             Padding(
//                               padding: const EdgeInsets.only(bottom: kDefaultPadding),
//                               child: SizedBox(
//                                 height: 40.0,
//                                 width: double.infinity,
//                                 child: ElevatedButton(
//                                   style: themeData.extension<AppButtonTheme>()!.primaryElevated,
//                                   onPressed: (_isFormLoading
//                                       ? null
//                                       : () => _doRegisterAsync(
//                                             userDataProvider: context.read<UserDataProvider>(),
//                                             onSuccess: (message) => _onRegisterSuccess(context, message),
//                                             onError: (message) => _onRegisterError(context, message),
//                                           )),
//                                   child: Text(lang.register),
//                                 ),
//                               ),
//                             ),
//                             SizedBox(
//                               height: 40.0,
//                               width: double.infinity,
//                               child: OutlinedButton(
//                                 style: themeData.extension<AppButtonTheme>()!.secondaryOutlined,
//                                 onPressed: () => GoRouter.of(context).go(RouteUri.login),
//                                 child: Text(lang.backToLogin),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       // loading indicator
//                       if (_isFormLoading)
//                         const Center(
//                           child: CircularProgressIndicator(),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class FormData {
//   String name = '';
//   String surname = '';
//   String email = '';
//   String password = '';
// }

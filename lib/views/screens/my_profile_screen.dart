import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:provider/provider.dart';

import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/generated/l10n.dart';
import 'package:web_admin/theme/theme_extensions/app_button_theme.dart';
import 'package:web_admin/theme/theme_extensions/app_container_theme.dart';
import 'package:web_admin/helpers/app_focus_helper.dart';
import 'package:web_admin/views/widgets/card_elements.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';
import 'package:web_admin/providers/user_data_provider.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _formData = FormData();
  final String _address = 'address';
  final String _phoneNum = '0000000';

  Future<bool>? _future;

  Future<bool> _getDataAsync() async {
    await Future.delayed(const Duration(seconds: 1), () {
      _formData.userProfileImageUrl = '';
      if (mounted) {
        _formData.username = Provider.of<UserDataProvider>(context, listen: false).username;
        _formData.email = Provider.of<UserDataProvider>(context, listen: false).userCode;
      }
    });

    return true;
  }

  void _doSave(BuildContext context) {
    AppFocusHelper.instance.requestUnfocus();

    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();

      final lang = Lang.of(context);

      final dialog = AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        title: lang.recordSavedSuccessfully,
        width: kDialogWidth,
        btnOkText: 'OK',
        btnOkOnPress: () {},
      );

      dialog.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final themeData = Theme.of(context);

    return PortalMasterLayout(
      body: Container(
        decoration: ContainerBackgroundTheme.myGradientDecoration,
        child: ListView(
          padding: const EdgeInsets.all(kDefaultPadding),
          children: [
            Text(
              lang.myProfile,
              style: themeData.textTheme.headlineMedium,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CardHeader(
                      title: lang.myProfile,
                    ),
                    CardBody(
                      child: FutureBuilder<bool>(
                        initialData: null,
                        future: (_future ??= _getDataAsync()),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            if (snapshot.hasData && snapshot.data!) {
                              return _content(context);
                            }
                          } else if (snapshot.hasData && snapshot.data!) {
                            return _content(context);
                          }

                          return Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                            child: SizedBox(
                              height: 40.0,
                              width: 40.0,
                              child: CircularProgressIndicator(
                                backgroundColor: themeData.scaffoldBackgroundColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final lang = Lang.of(context);
    final themeData = Theme.of(context);

    return FormBuilder(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
            child: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 101, 87, 63),
                  backgroundImage: NetworkImage(_formData.userProfileImageUrl),
                  radius: 60.0,
                ),
                Positioned(
                  top: 0.0,
                  right: 0.0,
                  child: SizedBox(
                    height: 40.0,
                    width: 40.0,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: themeData.extension<AppButtonTheme>()!.secondaryElevated.copyWith(
                            shape: WidgetStateProperty.all(const CircleBorder()),
                            padding: WidgetStateProperty.all(EdgeInsets.zero),
                          ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 20.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: kDefaultPadding * 1.5),
            child: FormBuilderTextField(
              name: 'username',
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Full Name',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              initialValue: _formData.username,
              validator: FormBuilderValidators.required(),
              onSaved: (value) => (_formData.username = value ?? ''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: kDefaultPadding * 2.0),
            child: FormBuilderTextField(
              name: 'email',
              decoration: const InputDecoration(
                labelText: 'User Code',
                hintText: 'Code',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              initialValue: _formData.email,
              keyboardType: TextInputType.emailAddress,
              validator: FormBuilderValidators.compose(
                [
                  FormBuilderValidators.required(),
                  FormBuilderValidators.email(),
                ],
              ),
              onSaved: (value) => (_formData.email = value ?? ''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: kDefaultPadding * 2.0),
            child: FormBuilderTextField(
              name: 'address',
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Address',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              initialValue: _address,
              keyboardType: TextInputType.streetAddress,
              validator: FormBuilderValidators.compose(
                [
                  FormBuilderValidators.required(),
                  FormBuilderValidators.minLength(10),
                ],
              ),
              onSaved: (value) => (_formData.email = value ?? ''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: kDefaultPadding * 2.0),
            child: FormBuilderTextField(
              name: 'phoneNum',
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Phone Number',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              initialValue: _phoneNum,
              keyboardType: TextInputType.phone,
              validator: FormBuilderValidators.compose(
                [
                  FormBuilderValidators.required(),
                  FormBuilderValidators.numeric(),
                  FormBuilderValidators.minLength(7),
                  FormBuilderValidators.maxLength(10),
                ],
              ),
              onSaved: (value) => (_formData.email = value ?? ''),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 40.0,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                ),
                //themeData.extension<AppButtonTheme>()!.successElevated,
                onPressed: () => _doSave(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: kDefaultPadding * 0.5),
                      child: Icon(
                        Icons.save_rounded,
                        size: (themeData.textTheme.labelLarge!.fontSize! + 4.0),
                      ),
                    ),
                    Text(lang.save),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FormData {
  String userProfileImageUrl = '';
  String username = '';
  String email = '';
}

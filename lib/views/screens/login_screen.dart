import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/generated/l10n.dart';
import 'package:web_admin/helpers/marnisi_image_helper.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/providers/user_data_provider.dart';
import 'package:web_admin/theme/theme_extensions/app_button_theme.dart';
import 'package:web_admin/helpers/app_focus_helper.dart';
import 'package:web_admin/helpers/login_background_style.dart';
import 'package:web_admin/helpers/settings_selection_helper.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/marnisi_api_service.dart';
import 'package:web_admin/helpers/txn_helper.dart';
import 'package:web_admin/views/widgets/public_master_layout/public_master_layout.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final SqlLiteService _dbHelper = SqlLiteService();
  final MarnisiApiService _marnisiApi = const MarnisiApiService();
  final _formData = FormData();
  DateTime _startTime = DateTime.now();

  var _isFormLoading = false;

  String? apiBaseUrl;
  String? selectedRegisterId;
  String? selectedStoreId;
  String? _loginBackgroundPath;

  @override
  void initState() {
    super.initState();
    _loadPersistedLoginBackground();
  }

  final logger = Logger(printer: PrettyPrinter());
  // logger.d("Debug message");
  // logger.i("Info message");
  // logger.w("Warning message");
  // logger.e("Error message");
  // logger.t("Verbose message");

  Future<void> _loadPersistedLoginBackground() async {
    final path = await MarnisiImageHelper.readLoginBackgroundPath();
    if (!mounted) return;
    setState(() {
      _loginBackgroundPath = path;
    });
  }

  Future<void> _ensureLockedStoreAndRegister() async {
    if (!MarnisiPosRestrictions.lockStoreAndRegisterSelection) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final stores = MarnisiPosRestrictions.restrictStoreOptions(
      await _dbHelper.getStores(),
    );
    if (stores.isEmpty) {
      return;
    }
    final selectedStore = stores.first;
    for (final key in SettingsSelectionHelper.selectedStoreWriteKeys()) {
      await prefs.setString(key, selectedStore);
    }

    final registers = MarnisiPosRestrictions.restrictRegisterOptions(
      (await _dbHelper.getRegisters(selectedStore))
          .map((entry) => entry.toString())
          .toList(growable: false),
    );
    if (registers.isEmpty) {
      return;
    }
    final selectedRegister = registers.first;
    for (final key in SettingsSelectionHelper.selectedRegisterWriteKeys()) {
      await prefs.setString(key, selectedRegister);
    }
  }

  Future<void> _doLoginAsync({
    required UserDataProvider userDataProvider,
    required VoidCallback onSuccess,
    required void Function(String message) onError,
  }) async {
    AppFocusHelper.instance.requestUnfocus();

    if (_formKey.currentState?.validate() ?? false) {
      // Validation passed.
      _formKey.currentState!.save();

      setState(() => _isFormLoading = true);

      try {
        Map<String, dynamic>? user = await _dbHelper.validateUser(
          _formData.userId,
        );

        if (user != null) {
          await userDataProvider.setUserDataAsync(
            username: '${user['user_first_name']}  ${user['user_last_name']}',
            userProfileImageUrl: user['user_img'],
            userCode: user['user_personnel_id'],
            userLevel: user['user_group'],
          );

          //save transaction event
          await TxnHelper.saveTxn(
            txnReceiptNum: '',
            txnAmount: 0.0,
            txnType: Event.logon,
            txnStatus: PostingStatus.pending,
            txnLocalStatus: LocalEvent.pending,
          );

          onSuccess.call();
        } else {
          onError.call('Invalid username or password.');
        }
      } catch (e) {
        onError.call('An error occurred. Please try again. $e');
      } finally {
        setState(() => _isFormLoading = false);
      }
    }
  }

  Future<void> _onLoginSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getString(StorageKeys.userId);

    logger.i(userCode);

    if (userCode != null) {
      var sessionData = await _dbHelper.checkSessionOpen(userCode);
      logger.d(sessionData);

      if (sessionData == null) {
        // there is not open session create new one
        _startTime = DateTime.now();
        await prefs.setInt('startTime', _startTime.millisecondsSinceEpoch);
        String formattedDate =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(_startTime);

        Map<String, dynamic> data = {
          'shift_num': 001, // set the counter
          'shift_personnel_id': userCode,
          'shift_in': formattedDate,
          'shift_out': '',
        };

        await _dbHelper.saveShiftTime(data);
        logger.i('New session record created for user: $userCode');
      } else {
        // there is a session load the time
        final savedStartTimeString = sessionData['shift_in'];
        if (savedStartTimeString != null) {
          DateTime savedStartTime =
              DateFormat('yyyy-MM-dd HH:mm:ss').parse(savedStartTimeString);
          await prefs.setInt(
              'startTime', savedStartTime.millisecondsSinceEpoch);
          _startTime = savedStartTime;
        }
        logger.i(
            'User: $userCode has an open session. Session start time loaded: $_startTime');
      }
    }

    final host = (prefs.getString('apiBaseUrl') ??
            prefs.getString(StorageKeys.apiBaseUrl) ??
            '')
        .trim();
    if (host.isEmpty) {
      if (!mounted) return;
      GoRouter.of(context).go(RouteUri.generalSettings);
      return;
    }

    final personalId = (userCode ?? _formData.userId).trim();
    try {
      await _marnisiApi.loginWithPersonalId(personalId: personalId);
      final sessionContext = await _marnisiApi.getContext();
      await MarnisiImageHelper.persistBackgroundPaths(
        loginBackgroundPath: sessionContext.loginBackgroundImagePath,
        appBackgroundPath: sessionContext.appBackgroundImagePath,
      );
      await _loadPersistedLoginBackground();
      await _ensureLockedStoreAndRegister();
    } catch (e) {
      if (!mounted) return;
      _onLoginError(
        context,
        'Backend login failed for Personal ID $personalId. Please verify server URL and seed data. Error: $e',
      );
      GoRouter.of(context).go(RouteUri.generalSettings);
      return;
    }

    final selectedStore = SettingsSelectionHelper.resolveSelectedStore(
      primaryValue: prefs.getString(StorageKeys.selectedStore),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedStoreKey),
    );
    final selectedRegister = SettingsSelectionHelper.resolveSelectedRegister(
      primaryValue: prefs.getString(StorageKeys.selectedRegister),
      legacyValue:
          prefs.getString(SettingsSelectionHelper.legacySelectedRegisterKey),
    );

    if (selectedStore.isEmpty || selectedRegister.isEmpty) {
      if (!mounted) return;
      GoRouter.of(context).go(RouteUri.generalSettings);
      return;
    }

    if (!mounted) return;
    GoRouter.of(context).go(RouteUri.home);
  }

  void _onLoginError(BuildContext context, String message) {
    final dialog = AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      desc: message,
      width: kDialogWidth,
      btnOkText: 'OK',
      btnOkOnPress: () {},
    );

    dialog.show();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final themeData = Theme.of(context);

    return PublicMasterLayout(
      body: Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                  Color(0xFF7A7A7A), BlendMode.saturation),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: LoginBackgroundStyle.blurSigma,
                  sigmaY: LoginBackgroundStyle.blurSigma,
                  tileMode: TileMode.clamp,
                ),
                child: MarnisiImageHelper.isNetworkImagePath(
                        (_loginBackgroundPath ?? '').trim())
                    ? Image.network(
                        _loginBackgroundPath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            LoginBackgroundStyle.imageAssetPath,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Image.asset(
                        _loginBackgroundPath?.isNotEmpty == true
                            ? _loginBackgroundPath!
                            : LoginBackgroundStyle.imageAssetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: LoginBackgroundStyle.overlayColor),
          ),
          SingleChildScrollView(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.only(top: kDefaultPadding * 5.0),
                constraints: const BoxConstraints(maxWidth: 400.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Card(
                    color: const Color.fromRGBO(58, 1, 1, 0.9),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(kDefaultPadding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: kDefaultPadding),
                            child: SvgPicture.asset(
                              'assets/images/CassarCamilleriLogo.svg',
                              height: 120.0,
                            ),
                          ),
                          Text(
                            lang.appPosTitle,
                            style: themeData.textTheme.headlineMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: kDefaultPadding * 2.0),
                          FormBuilder(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.disabled,
                            child: Column(
                              children: [
                                //login using id number
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: kDefaultPadding * 1.5),
                                  child: FormBuilderTextField(
                                    name: 'idnumber',
                                    decoration: InputDecoration(
                                      helperText: '*',
                                      labelText: lang.personalNumber,
                                      hintText: lang.personalNumber,
                                      border: const OutlineInputBorder(),
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                    ),
                                    enableSuggestions: false,
                                    obscureText: true,
                                    validator: FormBuilderValidators.compose([
                                      FormBuilderValidators.required(),
                                    ]),
                                    onSaved: (value) =>
                                        (_formData.userId = value ?? ''),
                                  ),
                                ),

                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: kDefaultPadding),
                                  child: SizedBox(
                                    height: 40.0,
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: themeData
                                          .extension<AppButtonTheme>()!
                                          .primaryElevated,
                                      onPressed: (_isFormLoading
                                          ? null
                                          : () => _doLoginAsync(
                                                userDataProvider: context
                                                    .read<UserDataProvider>(),
                                                onSuccess: () =>
                                                    _onLoginSuccess(),
                                                onError: (message) =>
                                                    _onLoginError(
                                                        context, message),
                                              )),
                                      child: Text(lang.login),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Show loading indicator if form is loading.
                          if (_isFormLoading)
                            const Center(
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                  ),
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
  String userId = '';
  String password = '';
}

// import 'package:web_admin/api_endpoints/routes_api.dart';
// import 'package:web_admin/utils/api_helper.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/app_router.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/helpers/android_printer_discovery.dart';
import 'package:web_admin/helpers/api_base_url_helper.dart';
import 'package:web_admin/helpers/app_build_info.dart';
import 'package:web_admin/helpers/marnisi_pos_restrictions.dart';
import 'package:web_admin/helpers/settings_selection_helper.dart';
import 'package:web_admin/helpers/store_selection_helper.dart';
import 'package:web_admin/services/database_service.dart';
import 'package:web_admin/services/startup_sync_service.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/views/widgets/marnisi_app_background.dart';
import 'package:web_admin/views/widgets/portal_master_layout/portal_master_layout.dart';

class GeneralSettings extends StatefulWidget {
  const GeneralSettings({super.key});

  @override
  State<GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends State<GeneralSettings> {
  // Controllers and Focus Nodes
  final TextEditingController _controllerUrlApi = TextEditingController();
  final TextEditingController _controllerOpenCashMax = TextEditingController();
  final TextEditingController _controllerOpenCashMin = TextEditingController();
  final FocusNode _focusNodeUrlApi = FocusNode();
  final FocusNode _focusNodeOpenCashMin = FocusNode();
  final FocusNode _focusNodeOpenCashMax = FocusNode();

  final SqlLiteService _dbHelper = SqlLiteService();

  List<String> printersList = [];
  List<String> storesList = [];
  List<String> registerList = [];

  String? selectedPrinter;
  String? previousSelectedPrinter;
  String? selectedStoreId;
  String? previousSelectedStore;
  String? selectedRegisterId;
  String? previousSelectedRegister;

  String? apiBaseUrlError;
  String? openCashAmountErrorMin;
  String? openCashAmountErrorMax;

  String? previousUrlApi;
  int? previousOpenCashAmountMin;
  int? previousOpenCashAmountMax;
  bool _isApplyingSettings = false;
  bool _isRunningSdkSamplePrint = false;

  @override
  void initState() {
    super.initState();
    initializeSettings();
  }

  Future<void> initializeSettings() async {
    try {
      await _loadSavedSettings();

      await loadStores();

      _focusNodeUrlApi.addListener(() => _onFocusChange(_focusNodeUrlApi,
          _controllerUrlApi, 'apiBaseUrl', isValidApiBaseUrl));
      _focusNodeOpenCashMin.addListener(() => _onFocusChange(
          _focusNodeOpenCashMin,
          _controllerOpenCashMin,
          'openCashAmountMin',
          isValidAmount));
      _focusNodeOpenCashMax.addListener(() => _onFocusChange(
          _focusNodeOpenCashMax,
          _controllerOpenCashMax,
          'openCashAmountMax',
          isValidAmount));
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error initializing settings: $e');
      }
    }
    await loadPrinters();
  }

  // Future<void> checkNumReceipt() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final ApiHelper getCurrentReceiptNum = ApiHelper(endpointPath: ApiRoutes.getLastReceiptNumStore);
  //   String? defaultStore = prefs.getString('selectedStore');
  //   String? defaultRegiser = prefs.getString('selectedRegister');
  //   int? localReceiptNum = await _dbHelper.getLastSaleNum() ?? 0;
  //   int? remoteReceiptNum = 0;

  //   if (defaultStore != null || defaultStore != "") {
  //     Map<String, dynamic>? confirmations =
  //         await getCurrentReceiptNum.sendStoreId(defaultStore ?? '', defaultRegiser ?? '', (message) {
  //       if (context.mounted) {
  //         _showSnackBar(context, 'Checking receipt index....');
  //       }
  //     });
  //     remoteReceiptNum = remoteReceiptNum = confirmations?['sale_index_receipt'];
  //   }
  //   // print(remoteReceiptNum);
  //   if (localReceiptNum == 0 && remoteReceiptNum != null) {
  //     // print(remoteReceiptNum);

  //     if (remoteReceiptNum <= localReceiptNum) {
  //       if (mounted) {
  //         _showSnackBar(context, 'Local reciept number is wrong, please clean the current store DB');
  //         return;
  //       }
  //     } else {
  //       await _dbHelper.saleRestoreIndex(remoteReceiptNum);
  //     }
  //   }
  // }

  //*************************************** */
  // Dialog admin user
  //*************************************** */
  bool _checkAdminPassword(String? password) {
    const correctPassword = "admin123"; // test validation
    return password == correctPassword;
  }

  Future<void> _showAdminPasswordDialog() async {
    final formKeyAdmin = GlobalKey<FormBuilderState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // disable close the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Admin Authentication"),
          content: FormBuilder(
            key: formKeyAdmin,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please enter the admin password:"),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'adminPassword',
                  decoration: const InputDecoration(
                    labelText: 'Admin Password',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                        errorText: 'Password is required'),
                  ]),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                if (formKeyAdmin.currentState?.saveAndValidate() ?? false) {
                  final enteredPassword =
                      formKeyAdmin.currentState?.value['adminPassword'];
                  if (_checkAdminPassword(enteredPassword)) {
                    Navigator.of(context)
                        .pop(); //close the dialog if the passwrod is right
                  } else {
                    //show message if the user insert wrong password
                    setState(() {
                      formKeyAdmin.currentState?.invalidateField(
                        name: 'adminPassword',
                        errorText: 'Incorrect password',
                      );
                    });
                  }
                }
              },
            ),
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                GoRouter.of(context).go(RouteUri.dashboard);
              },
            ),
          ],
        );
      },
    );
  }

  //*************************************** */
  //Clear all shared preferences
  // - asking confirmation to delete configs
  //*************************************** */
  Future<void> clearSharedPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    bool confirmed = await _showSnackBar(
        context, 'Are you sure you want to clear the preferences?',
        withConfirmation: true);
    if (!mounted) return;
    if (confirmed) {
      await prefs.clear();
      await _loadSavedSettings();
      await loadStores();
      if (mounted) {
        await _showSnackBar(context, 'Preferences cleared successfully');
      }
    } else {
      if (mounted) {
        await _showSnackBar(context, 'Action canceled');
      }
    }
  }

  //*************************************** */
  // - Load stores from db
  // - Load registers depens of the store
  // - Load Printers available
  //*************************************** */
  Future<void> loadStores() async {
    try {
      final stores = MarnisiPosRestrictions.restrictStoreOptions(
        StoreSelectionHelper.buildStoreOptions(
          await _dbHelper.getStores(),
        ),
      );
      final resolvedStore = StoreSelectionHelper.resolveSelectedStore(
        storeOptions: stores,
        preferredStoreId: MarnisiPosRestrictions.lockStoreAndRegisterSelection
            ? (stores.isNotEmpty ? stores.first : null)
            : selectedStoreId,
      );

      setState(() {
        storesList = stores;
        selectedStoreId = resolvedStore;
        registerList.clear();
      });

      if (resolvedStore != null && resolvedStore.isNotEmpty) {
        await saveSelectedStore(resolvedStore);
        await loadRegisters(resolvedStore);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error loading stores: $e');
      }
    }
  }

  Future<void> loadRegisters(String storeId) async {
    try {
      final registers = MarnisiPosRestrictions.restrictRegisterOptions(
        (await _dbHelper.getRegisters(storeId))
            .map((id) => id.toString())
            .toList(growable: false),
      );
      setState(() {
        registerList.clear();
        registerList.addAll(registers);

        if (MarnisiPosRestrictions.lockStoreAndRegisterSelection &&
            registerList.isNotEmpty) {
          selectedRegisterId = registerList.first;
        } else if (registerList.contains(selectedRegisterId) &&
            selectedRegisterId != '') {
          selectedRegisterId = selectedRegisterId;
        } else {
          selectedRegisterId = '';
        }
      });

      if (MarnisiPosRestrictions.lockStoreAndRegisterSelection &&
          registerList.isNotEmpty) {
        await saveSelectedRegister(registerList.first);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error loading registers: $e');
      }
    }
  }

  // Future<void> loadPrinters() async {
  //   printersList = getAvailablePrinters();
  //   await loadSelectedPrinter();
  //   if (printersList.isNotEmpty && selectedPrinter == null) {
  //     setState(() {
  //       selectedPrinter = printersList.first;
  //     });
  //   }
  // }

  Future<void> loadPrinters() async {
    final availablePrinters =
        await AndroidPrinterDiscovery.getAvailablePrinters();
    await loadSelectedPrinter();

    setState(() {
      printersList = availablePrinters;
      if (selectedPrinter == null || !printersList.contains(selectedPrinter)) {
        selectedPrinter = printersList.first;
      }
    });
  }

  //*************************************** */
  // load saved configs
  // - printer
  // - store
  // - register
  // - openCashAmountMin
  // - openCashAmountMax
  // - apiBaseUrl (endpoint to get data)
  //*************************************** */

  Future<void> loadSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedPrinter = prefs.getString('selectedPrinter');
      previousSelectedPrinter = selectedPrinter;
    });
  }

  Future<void> loadSelectedStore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedStoreId = SettingsSelectionHelper.resolveSelectedStore(
        primaryValue: prefs.getString(StorageKeys.selectedStore),
        legacyValue:
            prefs.getString(SettingsSelectionHelper.legacySelectedStoreKey),
      );
      previousSelectedStore = selectedStoreId;
    });
  }

  Future<void> loadSelectedRegister() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedRegisterId = SettingsSelectionHelper.resolveSelectedRegister(
        primaryValue: prefs.getString(StorageKeys.selectedRegister),
        legacyValue:
            prefs.getString(SettingsSelectionHelper.legacySelectedRegisterKey),
      );
      previousSelectedRegister = selectedRegisterId;
    });
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controllerOpenCashMin.text =
          prefs.getInt('openCashAmountMin')?.toString() ?? '0';
      _controllerOpenCashMax.text =
          prefs.getInt('openCashAmountMax')?.toString() ?? '0';
      _controllerUrlApi.text = (prefs.getString('apiBaseUrl') ??
              prefs.getString(StorageKeys.apiBaseUrl) ??
              '')
          .trim();

      previousOpenCashAmountMin = prefs.getInt('openCashAmountMin');
      previousOpenCashAmountMax = prefs.getInt('openCashAmountMax');
      previousUrlApi = _controllerUrlApi.text;

      selectedStoreId = SettingsSelectionHelper.resolveSelectedStore(
        primaryValue: prefs.getString(StorageKeys.selectedStore),
        legacyValue:
            prefs.getString(SettingsSelectionHelper.legacySelectedStoreKey),
      );
      selectedRegisterId = SettingsSelectionHelper.resolveSelectedRegister(
        primaryValue: prefs.getString(StorageKeys.selectedRegister),
        legacyValue:
            prefs.getString(SettingsSelectionHelper.legacySelectedRegisterKey),
      );
    });
  }

  //*************************************** */
  // save configs selected on shared preferences
  // - printer
  // - stores
  // - registers
  //*************************************** */

  Future<void> saveSelectedPrinter(String? printer) async {
    if (printer != null && printer != previousSelectedPrinter) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPrinter', printer);
      setState(() {
        previousSelectedPrinter = printer;
      });
    }
  }

  Future<void> saveSelectedStore(String? store) async {
    if (store != null && store.trim().isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final normalizedStore =
          MarnisiPosRestrictions.lockStoreAndRegisterSelection
              ? (storesList.isNotEmpty ? storesList.first : store.trim())
              : store.trim();

      for (final key in SettingsSelectionHelper.selectedStoreWriteKeys()) {
        await prefs.setString(key, normalizedStore);
      }

      // Obtener información de la tienda desde la base de datos
      var storeInfo = await _dbHelper.getStoreInfo(normalizedStore);

      var storeLoc = storeInfo?['location'] ?? '';
      var storeLegalEntity = storeInfo?['legalEntity'] ?? '';

      // Guardar información adicional de la tienda en preferencias
      await prefs.setString(StorageKeys.selStoreLoc, storeLoc);
      await prefs.setString(
          StorageKeys.selectedStoreIdentity, storeLegalEntity);

      // Verificar si el widget sigue montado antes de llamar a setState y usar BuildContext
      if (!mounted) return; // Detenemos la ejecución si el widget fue destruido

      setState(() {
        selectedStoreId = normalizedStore;
        previousSelectedStore = normalizedStore;
      });
    }
  }

  Future<void> saveSelectedRegister(String? register) async {
    if (register != null) {
      final prefs = await SharedPreferences.getInstance();
      final normalizedRegister =
          MarnisiPosRestrictions.lockStoreAndRegisterSelection
              ? (registerList.isNotEmpty ? registerList.first : register.trim())
              : register.trim();
      for (final key in SettingsSelectionHelper.selectedRegisterWriteKeys()) {
        await prefs.setString(key, normalizedRegister);
      }
      setState(() {
        selectedRegisterId = normalizedRegister;
        previousSelectedRegister = normalizedRegister;
      });
    }
  }

  //*************************************** */
  // Validate fields
  //*************************************** */
  bool isValidAmount(String text) {
    return int.tryParse(text) != null;
  }

  bool isValidApiBaseUrl(String input) {
    return ApiBaseUrlHelper.isValid(input);
  }

  void _updateErrorState(String key, bool isValid) {
    switch (key) {
      case 'openCashAmountMin':
        openCashAmountErrorMin = isValid ? null : 'Value error';
        break;
      case 'openCashAmountMax':
        openCashAmountErrorMax = isValid ? null : 'Value error';
        break;
      case 'apiBaseUrl':
        apiBaseUrlError = isValid ? null : 'Invalid domain or IP address';
        break;
    }
  }

  bool _validateSettingsForm() {
    final minText = _controllerOpenCashMin.text.trim();
    final maxText = _controllerOpenCashMax.text.trim();
    final apiText = _controllerUrlApi.text.trim();

    final minValid = isValidAmount(minText);
    final maxValid = isValidAmount(maxText);
    final apiValid = isValidApiBaseUrl(apiText);

    setState(() {
      _updateErrorState('openCashAmountMin', minValid);
      _updateErrorState('openCashAmountMax', maxValid);
      _updateErrorState('apiBaseUrl', apiValid);
    });

    if (!minValid || !maxValid || !apiValid) {
      return false;
    }

    final minAmount = int.parse(minText);
    final maxAmount = int.parse(maxText);
    if (minAmount >= maxAmount) {
      _showSnackBar(
          context, 'Minimum amount must be less than maximum amount.');
      return false;
    }

    return true;
  }

  Future<void> _applySettingsAndSync() async {
    if (_isApplyingSettings) return;
    if (!_validateSettingsForm()) return;

    final normalizedApiBaseUrl =
        ApiBaseUrlHelper.normalizeForStorage(_controllerUrlApi.text);
    if (normalizedApiBaseUrl.isEmpty) {
      _showSnackBar(context, 'Invalid server URL.');
      return;
    }

    final minAmount = int.parse(_controllerOpenCashMin.text.trim());
    final maxAmount = int.parse(_controllerOpenCashMax.text.trim());
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _isApplyingSettings = true;
    });

    try {
      await prefs.setString('apiBaseUrl', normalizedApiBaseUrl);
      await prefs.setString(StorageKeys.apiBaseUrl, normalizedApiBaseUrl);
      await prefs.setInt('openCashAmountMin', minAmount);
      await prefs.setInt('openCashAmountMax', maxAmount);
      await saveSelectedPrinter(selectedPrinter);

      final pendingStoreId = (selectedStoreId ?? '').trim();
      if (pendingStoreId.isNotEmpty) {
        await saveSelectedStore(pendingStoreId);
      }

      final pendingRegisterId = (selectedRegisterId ?? '').trim();
      if (pendingRegisterId.isNotEmpty) {
        await saveSelectedRegister(pendingRegisterId);
      }

      await StartupSyncService().syncAllData();

      await loadStores();

      String resolvedStoreId = (selectedStoreId ?? '').trim();
      if (resolvedStoreId.isEmpty && storesList.isNotEmpty) {
        resolvedStoreId = storesList.first;
        selectedStoreId = resolvedStoreId;
      }

      if (resolvedStoreId.isNotEmpty) {
        await loadRegisters(resolvedStoreId);
        await saveSelectedStore(resolvedStoreId);
      }

      String resolvedRegisterId = (selectedRegisterId ?? '').trim();
      if (resolvedRegisterId.isEmpty && registerList.isNotEmpty) {
        resolvedRegisterId = registerList.first;
        selectedRegisterId = resolvedRegisterId;
      }

      if (resolvedRegisterId.isNotEmpty) {
        await saveSelectedRegister(resolvedRegisterId);
      }

      await _loadSavedSettings();

      if (mounted) {
        _showSnackBar(
          context,
          'Settings saved successfully. Latest backend data synced.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'Settings saved but sync failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingSettings = false;
        });
      }
    }
  }

  Future<void> _runSdkSamplePrint() async {
    final printer = (selectedPrinter ?? '').trim();
    if (printer.isEmpty ||
        printer == AndroidPrinterDiscovery.defaultPrinterName) {
      if (mounted) {
        _showSnackBar(
          context,
          'Select a Bluetooth printer first, then run SDK sample print.',
        );
      }
      return;
    }

    setState(() {
      _isRunningSdkSamplePrint = true;
    });

    try {
      await AndroidPrinterDiscovery.printSdkSampleReceipt(
        selectedPrinter: printer,
      );
      if (mounted) {
        _showSnackBar(
          context,
          'SDK sample print sent. Check printer output and debug log file.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          context,
          'SDK sample print failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningSdkSamplePrint = false;
        });
      }
    }
  }

  //*************************************** */
  // get the status of fields focus
  //*************************************** */
  Future<void> _onFocusChange(
      FocusNode focusNode,
      TextEditingController controller,
      String key,
      bool Function(String) validator) async {
    if (!focusNode.hasFocus) {
      String text = controller.text;
      bool isValid = validator(text);
      setState(() {
        _updateErrorState(key, isValid);
      });
    }
  }

  //*************************************** */
  // shackbar
  // dialog
  //*************************************** */
  Future<bool> _showSnackBar(BuildContext context, String message,
      {bool withConfirmation = false}) {
    final Completer<bool> completer = Completer<bool>();

    final snackBar = SnackBar(
      content: Text(
        message,
        style: withConfirmation ? const TextStyle(color: Colors.white) : null,
      ),
      backgroundColor: withConfirmation
          ? const Color.fromARGB(255, 255, 17, 1)
          : null, //default color
      action: withConfirmation
          ? SnackBarAction(
              label: 'CONFIRM',
              textColor: Colors.yellow,
              onPressed: () {
                // when user click return true
                completer.complete(true);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            )
          : null,
      duration: Duration(seconds: withConfirmation ? 8 : 2), //duration
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);

    //if not clicked return false
    if (!withConfirmation) {
      completer.complete(false);
    }

    return completer.future;
  }

  //standar dialog
  Future<void> _showMessageDialog(
      BuildContext context, String title, String message,
      {bool confirmation = false, bool restart = false}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // no loose the focus of the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: restart ? const Text("Restart") : const Text("Ok"),
              onPressed: () {
                if (restart) {
                  GoRouter.of(context).go(RouteUri.splash);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controllerUrlApi.dispose();
    _controllerOpenCashMin.dispose();
    _controllerOpenCashMax.dispose();
    _focusNodeUrlApi.dispose();
    _focusNodeOpenCashMin.dispose();
    _focusNodeOpenCashMax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PortalMasterLayout(
      body: Stack(
        children: [
          const Positioned.fill(
            child: MarnisiAppBackground(),
          ),
          ListView(
            padding: const EdgeInsets.all(kDefaultPadding),
            children: [
              Text(
                'General Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 250,
                                child: Text(
                                  'POS App Version',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AppBuildInfo.displayVersion(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 250,
                                height: 80,
                                child: Text(
                                  'Default IP sync server',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: TextField(
                                  controller: _controllerUrlApi,
                                  focusNode: _focusNodeUrlApi,
                                  decoration: InputDecoration(
                                    labelText: 'Enter server IP or Domain',
                                    border: const OutlineInputBorder(),
                                    errorText: apiBaseUrlError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 250,
                                child: Text(
                                  'Select the default printer',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: printersList.contains(selectedPrinter)
                                      ? selectedPrinter
                                      : null,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedPrinter = newValue;
                                    });
                                  },
                                  items: printersList
                                      .map<DropdownMenuItem<String>>(
                                          (String printer) {
                                    return DropdownMenuItem<String>(
                                      value: printer,
                                      child: Text(printer),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 250,
                                child: Text(
                                  'Open Cash Amount',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: TextField(
                                        controller: _controllerOpenCashMin,
                                        focusNode: _focusNodeOpenCashMin,
                                        decoration: InputDecoration(
                                          labelText: 'Minimum Amount',
                                          border: const OutlineInputBorder(),
                                          errorText: openCashAmountErrorMin,
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _controllerOpenCashMax,
                                        focusNode: _focusNodeOpenCashMax,
                                        decoration: InputDecoration(
                                          labelText: 'Maximum Amount',
                                          border: const OutlineInputBorder(),
                                          errorText: openCashAmountErrorMax,
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: <TextInputFormatter>[
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 250,
                                child: Text(
                                  'Set Store and Register',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value:
                                            storesList.contains(selectedStoreId)
                                                ? selectedStoreId
                                                : null,
                                        onChanged: MarnisiPosRestrictions
                                                .lockStoreAndRegisterSelection
                                            ? null
                                            : (String? storeId) async {
                                                setState(() {
                                                  selectedStoreId = storeId;
                                                  registerList.clear();
                                                  selectedRegisterId = '';
                                                });

                                                if (storeId != null &&
                                                    storeId.isNotEmpty) {
                                                  await loadRegisters(storeId);
                                                  setState(() {});
                                                }
                                              },
                                        items: storesList
                                            .map<DropdownMenuItem<String>>(
                                                (String store) {
                                          return DropdownMenuItem<String>(
                                            value: store,
                                            child: Text(store),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: registerList
                                                .contains(selectedRegisterId)
                                            ? selectedRegisterId
                                            : null,
                                        hint: Text(MarnisiPosRestrictions
                                                .lockStoreAndRegisterSelection
                                            ? 'Auto-selected register'
                                            : 'Choose Register'),
                                        onChanged: MarnisiPosRestrictions
                                                .lockStoreAndRegisterSelection
                                            ? null
                                            : (String? registerId) {
                                                setState(() {
                                                  selectedRegisterId =
                                                      registerId ?? '';
                                                });
                                              },
                                        items: [
                                          if (!MarnisiPosRestrictions
                                              .lockStoreAndRegisterSelection)
                                            const DropdownMenuItem<String>(
                                              value: '',
                                              child: Text('Choose Register'),
                                            ),
                                          ...registerList
                                              .toSet()
                                              .map<DropdownMenuItem<String>>(
                                                  (String register) {
                                            return DropdownMenuItem<String>(
                                              value: register,
                                              child: Text(register),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 250,
                                height: 48,
                                child: Text(
                                  'Actions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              SizedBox(
                                width: 400,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextButton(
                                            onPressed: _isApplyingSettings ||
                                                    _isRunningSdkSamplePrint
                                                ? null
                                                : () {
                                                    clearSharedPreferences();
                                                  },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      218, 142, 31, 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14.0,
                                                      horizontal: 16.0),
                                            ),
                                            child: const Text(
                                              'Reset Configs',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: _isApplyingSettings ||
                                                    _isRunningSdkSamplePrint
                                                ? null
                                                : _applySettingsAndSync,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 19, 102, 43),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14.0,
                                                      horizontal: 16.0),
                                            ),
                                            child: Text(
                                              _isApplyingSettings
                                                  ? 'Saving...'
                                                  : 'Save',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: _isApplyingSettings ||
                                                _isRunningSdkSamplePrint
                                            ? null
                                            : _runSdkSamplePrint,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: Colors.white70,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14.0,
                                            horizontal: 16.0,
                                          ),
                                        ),
                                        child: Text(
                                          _isRunningSdkSamplePrint
                                              ? 'Printing SDK Sample...'
                                              : 'Run SDK Sample Print',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

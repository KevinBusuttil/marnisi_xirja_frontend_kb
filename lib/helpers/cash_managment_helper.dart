import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';

///
class CashManagementHelper {
  Future<double?> getOpenCashAmount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(StorageKeys.openCashAmount);
  }
}

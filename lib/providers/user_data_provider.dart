import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';

/// Class UserDataProvider manage shared temp preferences of the user loged
/// after user logoff these data is removed from shared preferences
/// arguments:
/// * [_userProfileImageUrl] path to get the default usr img
/// * [_username]
/// * [_userCode]
/// * [_userLevel]
/// * [_openCashAmount] qty money open cashier machine

class UserDataProvider extends ChangeNotifier {
  var _userProfileImageUrl = '';
  var _username = '';
  var _userCode = '';
  var _userLevel = '';
  var _openCashAmount = 0.0;

  String get userProfileImageUrl => _userProfileImageUrl;
  String get username => _username;
  String get userCode => _userCode;
  String get userLevel => _userLevel;
  double get openCash => _openCashAmount;

  Future<void> loadAsync() async {
    try {
      final sharedPref = await SharedPreferences.getInstance();

      _username = sharedPref.getString(StorageKeys.userName) ?? '';
      _userCode = sharedPref.getString(StorageKeys.userId) ?? '';
      _userProfileImageUrl = sharedPref.getString(StorageKeys.userProfileImageUrl) ?? '';
      _userLevel = sharedPref.getString(StorageKeys.userLevel) ?? '';
      _openCashAmount = sharedPref.getDouble(StorageKeys.openCashAmount) ?? 0.0;
      notifyListeners();
    } catch (e) {
      // print('Error loading user data: $e');
    }
  }

  Future<void> setUserDataAsync({
    String? userProfileImageUrl,
    String? username,
    String? userCode,
    String? userLevel,
    double? openCash,
  }) async {
    try {
      final sharedPref = await SharedPreferences.getInstance();
      var shouldNotify = false;

      if (userProfileImageUrl != null && userProfileImageUrl != _userProfileImageUrl) {
        _userProfileImageUrl = userProfileImageUrl;
        await sharedPref.setString(StorageKeys.userProfileImageUrl, _userProfileImageUrl);
        shouldNotify = true;
      }

      if (username != null && username != _username) {
        _username = username;
        await sharedPref.setString(StorageKeys.userName, _username);
        shouldNotify = true;
      }

      if (userCode != null && userCode != _userCode) {
        _userCode = userCode;
        await sharedPref.setString(StorageKeys.userId, _userCode);
        shouldNotify = true;
      }

      if (userLevel != null && userLevel != _userLevel) {
        _userLevel = userLevel;
        await sharedPref.setString(StorageKeys.userLevel, _userLevel);
        shouldNotify = true;
      }

      if (openCash != null && openCash != _openCashAmount) {
        _openCashAmount = openCash;
        await sharedPref.setDouble(StorageKeys.openCashAmount, _openCashAmount);
        shouldNotify = true;
      }

      if (shouldNotify) {
        notifyListeners();
      }
    } catch (e) {
      // print('Error setting user data: $e');
    }
  }

  Future<void> clearUserDataAsync() async {
    try {
      final sharedPref = await SharedPreferences.getInstance();

      await sharedPref.remove(StorageKeys.userName);
      await sharedPref.remove(StorageKeys.userProfileImageUrl);
      await sharedPref.remove(StorageKeys.userId);
      await sharedPref.remove(StorageKeys.userLevel);
      // await sharedPref.remove(StorageKeys.openCash);

      _username = '';
      _userProfileImageUrl = '';
      _userCode = '';
      _userLevel = '';
      // _openCash = 0;

      notifyListeners();
    } catch (e) {
      // print('Error clearing user data: $e');
    }
  }

  bool isUserLoggedIn() {
    return _username.isNotEmpty;
  }
}

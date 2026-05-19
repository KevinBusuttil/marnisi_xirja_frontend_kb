import 'package:flutter/material.dart';

/// class AppFocusHelper manage activity of the widgets
/// * [AppFocusHelper] private costructor

class AppFocusHelper {
  AppFocusHelper._();

  static final AppFocusHelper _instance = AppFocusHelper._();

  static AppFocusHelper get instance => _instance;

  void requestUnfocus() => WidgetsBinding.instance.focusManager.primaryFocus?.unfocus();
}

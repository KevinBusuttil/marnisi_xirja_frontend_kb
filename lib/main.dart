/*Reference folders:
 - api_endpoints: include all api endpoints
 - constants:    
 - generated:
 - l10n:
 - providers:
    - app_preferences_provider.dart:
    - user_data_provider.dart: include information about user returned from the server
 - theme:
 - views:
    - screens: all applications' screens
    - widgets: all applications' widgets
*/

/*
 Dev specs
 - Android Studio (version 2023.3)
 - Java version OpenJDK Runtime Environment (build 21.0.3+-12282718-b509.11)
 - Flutter (Channel stable, 3.24.3)
*/

import 'dart:io';

import 'package:logger/logger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:web_admin/root_app.dart';
import 'package:flutter/material.dart';
import 'package:web_admin/environment.dart';
import 'package:web_admin/helpers/app_detect_platform_helper.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

void main() async {
  // check if flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  final logger = Logger(printer: PrettyPrinter());

  // Initialize FFI for sqflite on desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // prevent multiple instances
  bool isSingleInstance = await WindowsSingleInstance.ensureSingleInstance(
        ['UniqueAppInstanceKey'], // list with unique key
        'UniqueAppInstanceKey', // key to check unique instance
      ) ??
      true; // If null, assume true to prevent errors

  //if is the unique instance runs the app
  if (!isSingleInstance) {
    logger.d('another app is running.');
    return;
  }

  final platformDetector = PlatformDetector();

  Environment.init(
    plataformType: platformDetector.detectPlatform(),
  );

  // run the application
  runApp(const RootApp());
}

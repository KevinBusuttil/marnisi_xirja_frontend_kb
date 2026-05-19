import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
import 'package:web_admin/constants/dimens.dart';
import 'package:web_admin/theme/theme_extensions/app_button_theme.dart';
import 'package:web_admin/theme/theme_extensions/app_color_scheme.dart';
import 'package:web_admin/theme/theme_extensions/app_data_table_theme.dart';
import 'package:web_admin/theme/theme_extensions/app_sidebar_theme.dart';

const Color kPrimaryColor = Color.fromARGB(235, 127, 10, 10);
const Color kSecondaryColor = Color.fromARGB(255, 251, 251, 251);
const Color kErrorColor = Color.fromARGB(255, 255, 255, 255);
const Color kSuccessColor = Color.fromARGB(255, 255, 255, 255);
const Color kInfoColor = Color.fromARGB(255, 224, 230, 231);
const Color kWarningColor = Color.fromARGB(255, 255, 255, 255);

const Color kTextColor = Color.fromARGB(255, 255, 255, 255);

const Color kScreenBackgroundColor = Color.fromARGB(255, 255, 255, 255);

class AppThemeData {
  AppThemeData._();

  static final AppThemeData _instance = AppThemeData._();

  static AppThemeData get instance => _instance;

  ThemeData light() {
    final themeData = ThemeData(
      useMaterial3: false,
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: kScreenBackgroundColor,
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF343A40)),
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: kPrimaryColor,
        onPrimary: Colors.white,
        secondary: kSecondaryColor,
        onSecondary: Colors.white,
        error: kErrorColor,
        onError: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
      ),
    );

    final appColorScheme = AppColorScheme(
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      error: kErrorColor,
      success: kSuccessColor,
      info: kInfoColor,
      warning: kWarningColor,
      hyperlink: const Color(0xFF0074CC),
      buttonTextBlack: kTextColor,
      buttonTextDisabled: kTextColor.withOpacity(0.38),
    );

    final appSidebarTheme = AppSidebarTheme(
      backgroundColor: themeData.drawerTheme.backgroundColor!,
      foregroundColor: const Color(0xFFC2C7D0),
      sidebarWidth: 250.0,
      sidebarLeftPadding: kDefaultPadding,
      sidebarTopPadding: kDefaultPadding,
      sidebarRightPadding: kDefaultPadding,
      sidebarBottomPadding: kDefaultPadding,
      headerUserProfileRadius: 20.0,
      headerUsernameFontSize: 14.0,
      headerTextButtonFontSize: 14.0,
      menuFontSize: 14.0,
      menuBorderRadius: 5.0,
      menuLeftPadding: 0.0,
      menuTopPadding: 2.0,
      menuRightPadding: 0.0,
      menuBottomPadding: 2.0,
      menuHoverColor: Colors.white.withOpacity(0.2),
      menuSelectedFontColor: Colors.white,
      menuSelectedBackgroundColor: appColorScheme.primary,
      menuExpandedBackgroundColor: Colors.white.withOpacity(0.1),
      menuExpandedHoverColor: Colors.white.withOpacity(0.1),
      menuExpandedChildLeftPadding: 4.0,
      menuExpandedChildTopPadding: 2.0,
      menuExpandedChildRightPadding: 4.0,
      menuExpandedChildBottomPadding: 2.0,
    );

    return themeData.copyWith(
      textTheme: themeData.textTheme.apply(
        bodyColor: kTextColor,
        displayColor: kTextColor,
      ),
      extensions: [
        AppButtonTheme.fromAppColorScheme(appColorScheme),
        appColorScheme,
        AppDataTableTheme.fromTheme(themeData),
        appSidebarTheme,
      ],
    );
  }

  ThemeData dark() {
    final themeData = ThemeData.dark(useMaterial3: false).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      drawerTheme: const DrawerThemeData(backgroundColor: Color.fromARGB(255, 52, 1, 1)),
      appBarTheme: const AppBarTheme(
        iconTheme: IconThemeData(color: Color.fromARGB(255, 142, 135, 135)),
        backgroundColor: kPrimaryColor,
        foregroundColor: Color.fromARGB(255, 255, 255, 255),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
      ),
    );

    final appColorScheme = AppColorScheme(
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      error: kErrorColor,
      success: kSuccessColor,
      info: kInfoColor,
      warning: kWarningColor,
      hyperlink: const Color.fromARGB(255, 152, 131, 96),
      buttonTextBlack: kTextColor,
      buttonTextDisabled: const Color.fromARGB(255, 0, 0, 0).withOpacity(0),
    );

    final appSidebarTheme = AppSidebarTheme(
      backgroundColor: themeData.drawerTheme.backgroundColor!,
      foregroundColor: const Color.fromARGB(255, 242, 240, 240),
      sidebarWidth: 250.0,
      sidebarLeftPadding: kDefaultPadding,
      sidebarTopPadding: kDefaultPadding,
      sidebarRightPadding: kDefaultPadding,
      sidebarBottomPadding: kDefaultPadding,
      headerUserProfileRadius: 20.0,
      headerUsernameFontSize: 14.0,
      headerTextButtonFontSize: 14.0,
      menuFontSize: 14.0,
      menuBorderRadius: 5.0,
      menuLeftPadding: 0.0,
      menuTopPadding: 2.0,
      menuRightPadding: 0.0,
      menuBottomPadding: 2.0,
      menuHoverColor: Colors.white.withOpacity(0.2),
      menuSelectedFontColor: Colors.white,
      menuSelectedBackgroundColor: appColorScheme.primary,
      menuExpandedBackgroundColor: Colors.transparent,
      menuExpandedHoverColor: const Color.fromARGB(255, 235, 165, 95).withOpacity(0.0),
      menuExpandedChildLeftPadding: 16.0,
      menuExpandedChildTopPadding: 2.0,
      menuExpandedChildRightPadding: 4.0,
      menuExpandedChildBottomPadding: 2.0,
    );

    return themeData.copyWith(
      extensions: [
        AppButtonTheme.fromAppColorScheme(appColorScheme),
        appColorScheme,
        AppDataTableTheme.fromTheme(themeData),
        appSidebarTheme,
      ],
    );
  }
}

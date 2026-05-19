import 'package:flutter/material.dart';

class AppDataTableTheme extends ThemeExtension<AppDataTableTheme> {
  final CardThemeData cardTheme;
  final DataTableThemeData dataTableThemeData;

  const AppDataTableTheme({
    required this.cardTheme,
    required this.dataTableThemeData,
  });

  factory AppDataTableTheme.fromTheme(ThemeData themeData) {
    return AppDataTableTheme(
      cardTheme: themeData.cardTheme.copyWith(
        color: const Color.fromARGB(65, 32, 31, 31),
        elevation: 0.0,
      ),
      dataTableThemeData: themeData.dataTableTheme.copyWith(
        headingRowColor: WidgetStateProperty.all(const Color.fromARGB(255, 126, 117, 106)),
        headingTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  ThemeExtension<AppDataTableTheme> copyWith({
    CardThemeData? cardTheme,
    DataTableThemeData? dataTableThemeData,
  }) {
    return AppDataTableTheme(
      cardTheme: cardTheme ?? this.cardTheme,
      dataTableThemeData: dataTableThemeData ?? this.dataTableThemeData,
    );
  }

  @override
  ThemeExtension<AppDataTableTheme> lerp(ThemeExtension<AppDataTableTheme>? other, double t) {
    if (other is! AppDataTableTheme) {
      return this;
    }

    return AppDataTableTheme(
      cardTheme: other.cardTheme,
      dataTableThemeData: other.dataTableThemeData,
    );
  }
}


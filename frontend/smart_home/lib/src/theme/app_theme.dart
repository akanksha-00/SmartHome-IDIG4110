import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const background = Color(0xFFF5F5F7);
    const text = Color(0xFF202027);
    const amber = Color(0xFF9B5F00);
    final scheme = ColorScheme.fromSeed(
      seedColor: amber,
      brightness: Brightness.light,
    ).copyWith(
        primary: amber,
        surface: Colors.white,
        onSurface: text,
        outline: const Color(0xFFD6D6DE));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
          backgroundColor: background, foregroundColor: text, elevation: 0),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: background,
        selectedIconTheme: IconThemeData(color: amber),
        unselectedIconTheme: IconThemeData(color: Color(0xFF64646E)),
        selectedLabelTextStyle: TextStyle(color: amber, fontSize: 18),
        unselectedLabelTextStyle:
            TextStyle(color: Color(0xFF64646E), fontSize: 18),
        indicatorColor: Color(0xFFF5E8CE),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFFD6D6DE))),
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFFD6D6DE), thickness: 1),
    );
  }

  static ThemeData dark() {
    const background = Color(0xFF09090B);
    const surface = Color(0xFF121217);
    const elevatedSurface = Color(0xFF1A1A22);
    const amber = Color(0xFFF2A93B);
    const text = Color(0xFFF4F1EA);
    const mutedText = Color(0xFF8C8B93);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: amber,
      brightness: Brightness.dark,
    ).copyWith(
      primary: amber,
      onPrimary: Colors.black,
      secondary: const Color(0xFFD98B2B),
      surface: surface,
      onSurface: text,
      outline: const Color(0xFF2A2A32),
    );

    return ThemeData(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: background,
        selectedIconTheme: IconThemeData(color: amber),
        unselectedIconTheme: IconThemeData(color: mutedText),
        selectedLabelTextStyle: TextStyle(color: amber, fontSize: 18),
        unselectedLabelTextStyle: TextStyle(color: mutedText, fontSize: 18),
        indicatorColor: elevatedSurface,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFF2A2A32)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF24242B),
        thickness: 1,
      ),
    );
  }
}

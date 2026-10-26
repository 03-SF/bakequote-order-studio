import 'package:flutter/material.dart';

abstract final class BakeColors {
  static const cream = Color(0xFFFFF9F5);
  static const rose = Color(0xFFB65F75);
  static const strongRose = Color(0xFF93465D);
  static const blush = Color(0xFFF5E4E8);
  static const cocoa = Color(0xFF35292D);
  static const muted = Color(0xFF75666B);
  static const border = Color(0xFFEADDE0);
}

ThemeData bakeTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: BakeColors.rose).copyWith(
      primary: BakeColors.strongRose,
      secondary: BakeColors.rose,
      surface: Colors.white,
      onSurface: BakeColors.cocoa,
      onSurfaceVariant: BakeColors.muted,
      outlineVariant: BakeColors.border,
    ),
    scaffoldBackgroundColor: BakeColors.cream,
    fontFamily: 'Manrope',
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: BakeColors.cream),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BakeColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: BakeColors.blush,
    ),
  );
}

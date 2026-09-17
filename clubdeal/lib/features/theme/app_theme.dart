import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF091A11);
  static const surface = Color(0xFF0F2318);
  static const surface2 = Color(0xFF152D1F);
  static const surface3 = Color(0xFF1C3829);

  static const cream = Color(0xFFF4E8C1);
  static const cream2 = Color(0xFFD9C98A);
  static const muted = Color(0xFF8A7D5A);

  static const green = Color(0xFF3FAD76);
  static const green2 = Color(0xFF2E8C60);
  static const gold = Color(0xFFD4A843);

  static const success = Color(0xFF41C47A);
  static const warning = Color(0xFFE0A030);
  static const error = Color(0xFFD94F4F);
  static const info = Color(0xFF4A90D9);

  static const border = Color(0x1AF4E8C1);
  static const borderStrong = Color(0x33F4E8C1);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        secondary: AppColors.gold,
        surface: AppColors.surface,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.green),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

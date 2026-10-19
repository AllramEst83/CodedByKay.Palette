import 'package:flutter/material.dart';

/// Dark slate/indigo theme matching the legacy web app (Tailwind slate + indigo).
class AppColors {
  const AppColors._();

  static const Color slate950 = Color(0xFF020617);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color indigo600 = Color(0xFF4F46E5);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color rose400 = Color(0xFFFB7185);
}

const String monoFont = 'JetBrainsMono';
const String sansFont = 'PlusJakartaSans';

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo600,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.indigo500,
    onPrimary: Colors.white,
    surface: AppColors.slate900,
    onSurface: AppColors.slate200,
    surfaceContainerHighest: AppColors.slate800,
    outline: AppColors.slate700,
    error: AppColors.rose400,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.slate950,
    fontFamily: sansFont,
    cardTheme: CardThemeData(
      color: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.slate700),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    sliderTheme: const SliderThemeData(showValueIndicator: ShowValueIndicator.onDrag),
  );
}

import 'package:flutter/material.dart';

const Color kBrand = Color(0xFF6D5EF5);
const Color kBrandAlt = Color(0xFFEC5BA6);

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: brightness,
  ).copyWith(
    surface: isDark ? const Color(0xFF0D0D14) : const Color(0xFFF6F6FB),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: StadiumBorder(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
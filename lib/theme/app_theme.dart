// lib/theme/app_theme.dart
//
// Single source of truth for colors, spacing, and text styles.
// Screens should pull from here instead of hardcoding Colors.teal / etc,
// so the app can be re-themed or made consistent in one place.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00695C); // teal.shade800
  static const Color primaryLight = Color(0xFF009688); // teal.shade500
  static const Color primarySurface = Color(0xFFE0F2F1); // teal.shade50

  static const Color background = Color(0xFFF5F5F5); // grey.shade100
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFEEEEEE); // grey.shade200

  static const Color textPrimary = Color(0xDD000000); // black87
  static const Color textSecondary = Color(0xFF757575); // grey.shade600
  static const Color textMuted = Color(0xFF9E9E9E); // grey.shade500

  static const Color urgent = Color(0xFFEF6C00); // orange.shade800
  static const Color urgentSurface = Color(0xFFFFF3E0); // orange.shade50
  static const Color success = Color(0xFF2E7D32); // green.shade800
  static const Color error = Color(0xFFC62828); // red.shade800

  // Rarity tier accent colors, reused anywhere a tier badge is shown.
  static const Map<String, Color> rarityTiers = {
    'Common': Color(0xFF757575),
    'Rare': Color(0xFF1565C0),
    'Epic': Color(0xFF6A1B9A),
    'Legendary': Color(0xFFEF6C00),
  };

  static Color rarityColor(String? tier) => rarityTiers[tier] ?? rarityTiers['Common']!;
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(16));
}

class AppTextStyles {
  AppTextStyles._();

  static const String brandFont = 'Outfit';

  static const TextStyle brand = TextStyle(
    fontFamily: brandFont,
    fontWeight: FontWeight.w900,
    fontSize: 24,
    letterSpacing: 1.2,
    color: AppColors.primary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.radiusMd,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.radiusSm,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusSm),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.radiusSm),
      ),
    );
  }
}

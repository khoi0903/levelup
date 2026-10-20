import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _build(AppPalette.light);

  static ThemeData get darkTheme => _build(AppPalette.dark);

  static ThemeData _build(AppPalette c) {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      c.isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: c.brightness,
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.accentLink,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.buttonFill,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: c.border, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusButton),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.cardNormalBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          side: BorderSide(color: c.cardNormalBorder, width: 1.0),
        ),
      ),
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        foregroundColor: c.textPrimary,
        systemOverlayStyle:
            c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface),
      snackBarTheme: c.isDark
          ? SnackBarThemeData(
              backgroundColor: c.textPrimary,
              contentTextStyle: TextStyle(color: c.background),
            )
          : null,
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          side: BorderSide(color: c.border, width: 1.0),
        ),
        backgroundColor: c.cardNormalBg,
        selectedColor: c.cardSelectedBg,
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: c.textSecondary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: c.primary,
        ),
      ),
    );
  }
}


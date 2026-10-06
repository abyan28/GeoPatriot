import 'package:flutter/material.dart';

import 'camera_tokens.dart';

class AppTheme {
  AppTheme._();

  /// Tema terang aplikasi GeoPatriot.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CameraTokens.brandOchre,
        primary: CameraTokens.brandOchre,
        secondary: CameraTokens.petrolBlue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  /// Tema gelap utama aplikasi GeoPatriot (Deep Navy & Warm Ochre).
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CameraTokens.navyBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CameraTokens.brandOchre,
        brightness: Brightness.dark,
        surface: CameraTokens.navySurface,
        primary: CameraTokens.brandOchre,
        onPrimary: CameraTokens.navyBackground,
        secondary: CameraTokens.petrolBlue,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: CameraTokens.navyBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: CameraTokens.navySurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: CameraTokens.petrolBlue.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CameraTokens.navySurface,
        modalBackgroundColor: CameraTokens.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CameraTokens.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: CameraTokens.petrolBlue.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
      ),
    );
  }
}


// ==============================================================
//  FaceInsight – lib/core/theme/app_theme.dart
//  Central theme: dark palette + cyan/blue accent matching designs
// ==============================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Background layers ──────────────────────────────────────
  static const Color bgDeep      = Color(0xFF0A0E1A); // deepest bg
  static const Color bgPrimary   = Color(0xFF0D1117); // main bg
  static const Color bgCard      = Color(0xFF131929); // card bg
  static const Color bgCardAlt   = Color(0xFF161D2E); // slightly lighter card

  // ── Accent (cyan → blue gradient) ──────────────────────────
  static const Color accentCyan  = Color(0xFF00D4FF);
  static const Color accentBlue  = Color(0xFF0088FF);
  static const Color accentTeal  = Color(0xFF00B4D8);

  // ── Text ───────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A9BB8);
  static const Color textMuted     = Color(0xFF4A5568);

  // ── Status colors (matching screenshot result badges) ──────
  static const Color statusLow      = Color(0xFF00D084); // green  – Low
  static const Color statusModerate  = Color(0xFFFFA500); // orange – Moderate
  static const Color statusGood      = Color(0xFF00BFFF); // blue   – Good
  static const Color statusExcellent = Color(0xFF9B59B6); // purple – Excellent

  // ── Border / divider ───────────────────────────────────────
  static const Color border      = Color(0xFF1E2D45);
  static const Color borderGlow  = Color(0xFF00D4FF);

  // ── Gradient shorthands ────────────────────────────────────
  static const LinearGradient cyanBlueGradient = LinearGradient(
    colors: [accentCyan, accentBlue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [bgDeep, bgPrimary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    fontFamily: 'SF Pro Display', // fallback to system sans-serif
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.accentCyan,
      secondary: AppColors.accentBlue,
      surface:   AppColors.bgCard,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: AppColors.accentCyan,
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.5,
      ),
    ),
  );
}
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0F766E);
  static const ink = Color(0xFF10272A);
  static const canvas = Color(0xFFF2F7F6);
  static const muted = Color(0xFF5B7377);
  static const line = Color(0xFFCFE0DD);
  static const card = Color(0xFFFFFFFF);
  static const syncedBg = Color(0xFFDCFCE7);
  static const syncedFg = Color(0xFF166534);
  static const siteChipBg = Color(0xFFDBEAFE);
  static const siteChipFg = Color(0xFF1E40AF);
  static const openFg = Color(0xFF92400E);
  static const openBg = Color(0xFFFEF3C7);
  static const progressFg = Color(0xFF1E40AF);
  static const progressBg = Color(0xFFDBEAFE);
  static const doneFg = Color(0xFF166534);
  static const doneBg = Color(0xFFDCFCE7);
  static const danger = Color(0xFFB91C1C);
}

class AppTheme {
  static const seed = AppColors.primary;
  static const ink = AppColors.ink;

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.card,
        ).copyWith(
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          error: AppColors.danger,
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.light,
      fontFamily: 'Plus Jakarta Sans',
    );
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          color: AppColors.ink,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.ink,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppColors.ink,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: AppColors.ink),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.line.withValues(alpha: 0.65)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(color: AppColors.line, thickness: 1),
    );
  }
}

Color statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'IN_PROGRESS':
      return AppColors.progressFg;
    case 'COMPLETED':
      return AppColors.doneFg;
    default:
      return AppColors.openFg;
  }
}

Color statusBackground(String status) {
  switch (status) {
    case 'IN_PROGRESS':
      return AppColors.progressBg;
    case 'COMPLETED':
      return AppColors.doneBg;
    default:
      return AppColors.openBg;
  }
}

Color appInk(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface;
}

Color appMuted(BuildContext context) {
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

Color appAccent(BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

Color appOutline(BuildContext context) {
  return Theme.of(context).colorScheme.outline;
}

Color appDanger(BuildContext context) {
  return Theme.of(context).colorScheme.error;
}

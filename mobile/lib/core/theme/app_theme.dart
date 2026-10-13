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

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: dark ? const Color(0xFF7DCDC4) : AppColors.primary,
      onPrimary: dark ? const Color(0xFF003733) : Colors.white,
      surface: dark ? const Color(0xFF15201E) : AppColors.card,
    );
    final scheme = generatedScheme.copyWith(
      onSurface: dark ? const Color(0xFFE8F1EF) : AppColors.ink,
      onSurfaceVariant: dark ? const Color(0xFFB7C9C5) : AppColors.muted,
      outline: dark ? const Color(0xFF82938F) : AppColors.line,
      outlineVariant: dark ? const Color(0xFF53635F) : AppColors.line,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Plus Jakarta Sans',
    );
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101817)
          : AppColors.canvas,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
          color: dark ? scheme.onSurface : AppColors.ink,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: dark ? scheme.onSurface : AppColors.ink,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: dark ? scheme.onSurface : AppColors.ink,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: dark ? scheme.onSurface : AppColors.ink,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: dark ? scheme.onSurface : AppColors.ink,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: dark ? scheme.onSurface : AppColors.ink,
        titleTextStyle: base.textTheme.headlineSmall?.copyWith(
          color: dark ? scheme.onSurface : AppColors.ink,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? scheme.surface : AppColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: dark
                ? scheme.outlineVariant.withValues(alpha: 0.4)
                : AppColors.line.withValues(alpha: 0.65),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? scheme.surface : AppColors.card,
        hintStyle: TextStyle(
          color: dark ? scheme.onSurfaceVariant : AppColors.muted,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? scheme.outlineVariant : AppColors.line,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? scheme.outlineVariant : AppColors.line,
          ),
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
        side: BorderSide(color: dark ? scheme.outlineVariant : AppColors.line),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: dark
            ? scheme.outlineVariant.withValues(alpha: 0.7)
            : AppColors.line,
        thickness: 1,
      ),
    );
  }

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);
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
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSurface
      : AppColors.ink;
}

Color appMuted(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSurfaceVariant
      : AppColors.muted;
}

Color appAccent(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.primary
      : AppColors.primary;
}

Color appOutline(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.outline
      : AppColors.line;
}

Color appDanger(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.error
      : AppColors.danger;
}

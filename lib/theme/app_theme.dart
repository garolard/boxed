import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Calm, premium dark theme. Single accent color (violet) for primary
/// actions; everything else lives in a restrained neutral palette. Brand
/// colors for platforms are used directly as solid fills in their own
/// widgets (pills/badges) and never as rainbow gradients on text or chips.
class AppColors {
  // Surfaces
  static const Color bg = Color(0xFF0E0E16);
  static const Color surface = Color(0xFF16161F);
  static const Color surfaceHi = Color(0xFF1F1F2B);
  static const Color surfaceHi2 = Color(0xFF2A2A38);

  // Text
  static const Color textPrimary = Color(0xFFF5F5F7);
  static const Color textSecondary = Color(0xFFB4B4BE);
  static const Color textMuted = Color(0xFF7A7A85);

  // Accent — used sparingly for primary actions and key indicators.
  static const Color accent = Color(0xFFA78BFA);
  static const Color accentMuted = Color(0xFF8B7BC8);
  static const Color accentGlow = Color(0xFF6D4FE0);

  // Semantic (kept calm, no neon reds/greens)
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFE57373);
  static const Color warning = Color(0xFFE6B450);

  /// Subtle vertical gradient used as the app background.
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12121C), Color(0xFF0B0B14)],
  );
}

class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final display = GoogleFonts.bungeeTextTheme();
    final body = GoogleFonts.interTextTheme();
    final text = body.copyWith(
      displayLarge: display.displayLarge?.copyWith(color: scheme.onSurface),
      displayMedium: display.displayMedium?.copyWith(color: scheme.onSurface),
      displaySmall: display.displaySmall?.copyWith(color: scheme.onSurface),
      headlineLarge: display.headlineLarge?.copyWith(color: scheme.onSurface),
      headlineMedium: display.headlineMedium?.copyWith(color: scheme.onSurface),
      headlineSmall: display.headlineSmall?.copyWith(color: scheme.onSurface),
      titleLarge: body.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: scheme.onSurface),
      bodyMedium: body.bodyMedium?.copyWith(color: scheme.onSurface),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: AppColors.bg,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.bungee(
          fontSize: 20,
          letterSpacing: 1.2,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
          textStyle: GoogleFonts.bungee(fontSize: 14, letterSpacing: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(99),
          ),
          textStyle: GoogleFonts.bungee(fontSize: 14, letterSpacing: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHi,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: Color(0x33A78BFA),
        circularTrackColor: Color(0x33A78BFA),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        _AppGradient(bgGradient: AppColors.bgGradient),
      ],
    );
  }
}

class _AppGradient extends ThemeExtension<_AppGradient> {
  final LinearGradient bgGradient;
  const _AppGradient({required this.bgGradient});

  @override
  _AppGradient copyWith({LinearGradient? bgGradient}) =>
      _AppGradient(bgGradient: bgGradient ?? this.bgGradient);

  @override
  _AppGradient lerp(ThemeExtension<_AppGradient>? other, double t) {
    if (other is! _AppGradient) return this;
    return _AppGradient(bgGradient: bgGradient);
  }
}

extension AppGradientContext on BuildContext {
  LinearGradient get appBackgroundGradient =>
      Theme.of(this).extension<_AppGradient>()!.bgGradient;
}

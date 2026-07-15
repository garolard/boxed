import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised colors, gradients and ThemeData for the app.
/// Vibe: neon arcade meets collectible card — saturated gradients, glow,
/// glass surfaces, and a hint of pixel/retro in the typography.
class AppColors {
  // Brand
  static const Color brandMagenta = Color(0xFFFF2E93);
  static const Color brandCyan = Color(0xFF00E5FF);
  static const Color brandYellow = Color(0xFFFFD600);
  static const Color brandPurple = Color(0xFF7C4DFF);
  static const Color brandOrange = Color(0xFFFF6E40);
  static const Color brandGreen = Color(0xFF00E676);

  // Backgrounds
  static const Color darkBg = Color(0xFF0E0B1F);
  static const Color darkSurface = Color(0xFF181236);
  static const Color darkSurfaceHi = Color(0xFF221A45);
  static const Color lightBg = Color(0xFFFFF6F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHi = Color(0xFFFFF0E5);

  /// Multi-stop gradient used as the brand background.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C4DFF),
      Color(0xFFFF2E93),
      Color(0xFFFFD600),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  /// Softer gradient used in the dark theme background.
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B0E3A),
      Color(0xFF2A0E45),
      Color(0xFF0E0B1F),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Soft warm gradient for the light theme.
  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF6F0),
      Color(0xFFFFE9DD),
      Color(0xFFFFD9C5),
    ],
    stops: [0.0, 0.6, 1.0],
  );
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandMagenta,
      brightness: Brightness.light,
      primary: AppColors.brandMagenta,
      secondary: AppColors.brandCyan,
      tertiary: AppColors.brandYellow,
      surface: AppColors.lightSurface,
    );
    return _build(scheme, AppColors.lightBackgroundGradient, Brightness.light);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandMagenta,
      brightness: Brightness.dark,
      primary: AppColors.brandMagenta,
      secondary: AppColors.brandCyan,
      tertiary: AppColors.brandYellow,
      surface: AppColors.darkSurface,
    );
    return _build(scheme, AppColors.darkBackgroundGradient, Brightness.dark);
  }

  static ThemeData _build(
    ColorScheme scheme,
    LinearGradient bgGradient,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final display = GoogleFonts.bungeeTextTheme();
    final bodyBase = isDark ? GoogleFonts.interTextTheme() : GoogleFonts.interTextTheme();
    final text = bodyBase.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
        color: scheme.onSurface,
      ),
      displayMedium: display.displayMedium?.copyWith(
        color: scheme.onSurface,
      ),
      displaySmall: display.displaySmall?.copyWith(
        color: scheme.onSurface,
      ),
      headlineLarge: display.headlineLarge?.copyWith(color: scheme.onSurface),
      headlineMedium: display.headlineMedium?.copyWith(color: scheme.onSurface),
      headlineSmall: display.headlineSmall?.copyWith(color: scheme.onSurface),
      titleLarge: bodyBase.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: bodyBase.bodyLarge?.copyWith(color: scheme.onSurface),
      bodyMedium: bodyBase.bodyMedium?.copyWith(color: scheme.onSurface),
      bodySmall: bodyBase.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.7),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: scheme.onSurface),
        titleTextStyle: GoogleFonts.bungee(
          fontSize: 22,
          letterSpacing: 1.0,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurfaceHi.withValues(alpha: 0.8)
            : Colors.white,
        side: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
        labelStyle: TextStyle(
          color: scheme.onSurface,
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.bungee(
            fontSize: 11,
            letterSpacing: 1.0,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.7),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.7),
            size: 26,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceHi : Colors.white,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.15),
        circularTrackColor: scheme.primary.withValues(alpha: 0.15),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      extensions: <ThemeExtension<dynamic>>[
        _AppGradient(bgGradient: bgGradient),
      ],
    );
  }
}

/// Exposes the background gradient via the theme so any widget can pull it.
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

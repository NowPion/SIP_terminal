import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 设计系统 tokens —— ui-ux-pro-max「Minimal & Direct」
/// 本文件是全 App 唯一允许出现色值字面量的地方。
abstract final class DsColors {
  // Light
  static const primary = Color(0xFF171717);
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF404040);
  static const accent = Color(0xFFA16207); // CTA 金棕，白底对比 ≥4.5
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFFE8ECF0);
  static const border = Color(0xFFE5E5E5);
  static const destructive = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const onSurface = Color(0xFF171717);
  static const onSurfaceMuted = Color(0xFF525252);

  // Dark
  static const dPrimary = Color(0xFFFAFAFA);
  static const dOnPrimary = Color(0xFF171717);
  static const dAccent = Color(0xFFEAB308);
  static const dBackground = Color(0xFF0A0A0A);
  static const dSurface = Color(0xFF171717);
  static const dMuted = Color(0xFF262626);
  static const dBorder = Color(0xFF333333);
  static const dDestructive = Color(0xFFF87171);
  static const dSuccess = Color(0xFF4ADE80);
  static const dOnSurface = Color(0xFFFAFAFA);
  static const dOnSurfaceMuted = Color(0xFFA3A3A3);
}

ThemeData buildLightTheme() => _theme(_lightScheme);
ThemeData buildDarkTheme() => _theme(_darkScheme);

final _lightScheme = ColorScheme.light(
  primary: DsColors.primary,
  onPrimary: DsColors.onPrimary,
  secondary: DsColors.secondary,
  tertiary: DsColors.accent,
  error: DsColors.destructive,
  surface: DsColors.surface,
  onSurface: DsColors.onSurface,
  surfaceContainerHighest: DsColors.muted,
  outline: DsColors.border,
);

final _darkScheme = ColorScheme.dark(
  primary: DsColors.dPrimary,
  onPrimary: DsColors.dOnPrimary,
  secondary: DsColors.dOnSurfaceMuted,
  tertiary: DsColors.dAccent,
  error: DsColors.dDestructive,
  surface: DsColors.dSurface,
  onSurface: DsColors.dOnSurface,
  surfaceContainerHighest: DsColors.dMuted,
  outline: DsColors.dBorder,
);

ThemeData _theme(ColorScheme s) {
  final base = ThemeData(useMaterial3: true, colorScheme: s);
  final inter = GoogleFonts.interTextTheme();
  const radius = BorderRadius.all(Radius.circular(16));
  return base.copyWith(
    textTheme: inter.apply(bodyColor: s.onSurface, displayColor: s.onSurface),
    scaffoldBackgroundColor: s.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: s.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: inter.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.surface,
      indicatorColor: s.surfaceContainerHighest,
      labelTextStyle: WidgetStatePropertyAll(
        inter.labelSmall!.copyWith(
          fontWeight: FontWeight.w500,
          color: s.onSurface,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.tertiary, // CTA 用 accent
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        textStyle: inter.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: s.onSurface,
        side: BorderSide(color: s.outline),
        minimumSize: const Size(64, 52),
        shape: const RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.brightness == Brightness.light
          ? DsColors.muted
          : DsColors.dMuted,
      hintStyle: inter.bodyMedium?.copyWith(
        color: s.onSurface.withValues(alpha: .45),
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: s.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: s.outline),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dividerTheme: DividerThemeData(color: s.outline, thickness: 1),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// 语义色/辅助文本色挂在 scheme 上（不属于 Material scheme 的 token），
/// 页面一律 `scheme.success` / `scheme.onSurfaceMuted` 取色，禁止直接 import DsColors。
extension DsSchemeX on ColorScheme {
  Color get success =>
      brightness == Brightness.light ? DsColors.success : DsColors.dSuccess;

  Color get onSurfaceMuted => brightness == Brightness.light
      ? DsColors.onSurfaceMuted
      : DsColors.dOnSurfaceMuted;
}

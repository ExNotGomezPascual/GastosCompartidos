import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta tomada de las diapositivas.
class AppColors {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF16233D);
  static const border = Color(0xFF2A3852);
  static const navBg = Color(0xFF0E1A30);
  static const frame = Color(0xFF1A2740);
  static const text = Color(0xFFEAF1F8);
  static const muted = Color(0xFF9FB0C6);
  static const accent = Color(0xFF5EE6B4);
  static const coral = Color(0xFFFF8A6B);
  static const violet = Color(0xFF9B8CFF);
  static const amber = Color(0xFFFFC978);

  /// Colores de avatar: el índice 0 es "Tú".
  static const avatars = [
    accent, violet, coral, amber,
    Color(0xFF6EC1FF), Color(0xFFFF7FB5), Color(0xFFB8E36B), Color(0xFFFFA65C),
  ];

  static Color avatar(int index) => avatars[index % avatars.length];
}

const kSans = 'Arimo';
const kMono = 'Cousine';

TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color color = AppColors.text, double? height, double? spacing}) =>
    TextStyle(fontFamily: kSans, fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

TextStyle bold(double size, {Color color = AppColors.text, double? height, double? spacing}) =>
    sans(size, weight: FontWeight.w700, color: color, height: height, spacing: spacing);

/// Etiqueta en mayúsculas con fuente monoespaciada (estilo Consolas).
TextStyle mono(double size, {Color color = AppColors.muted, double spacing = .08}) =>
    TextStyle(fontFamily: kMono, fontSize: size, color: color, letterSpacing: size * spacing);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.bg,
    secondary: AppColors.violet,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.coral,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: kSans,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: sans(16, color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.coral)),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionHandleColor: AppColors.accent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: bold(19),
      contentTextStyle: sans(15, color: AppColors.muted, height: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: sans(14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerBackgroundColor: AppColors.bg,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: bold(15)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.bg : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.border),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

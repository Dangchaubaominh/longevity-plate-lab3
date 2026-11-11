import 'package:flutter/material.dart';

/// Token lấy từ design/figma-completion/design-system-v2/TOKENS.json của Lab 2.
abstract final class AppColors {
  static const background = Color(0xFFFAF8F2);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF24523C);
  static const onPrimary = Color(0xFFFFFFFF);
  static const text = Color(0xFF172D24);
  static const muted = Color(0xFF4B6256);
  static const error = Color(0xFFB3261E);
  static const border = Color(0xFF6B766F);
  static const selected = Color(0xFFE6EFE8);
  static const disabled = Color(0xFFE3E7E3);
  static const pressed = Color(0xFF183E2B);
  static const errorSurface = Color(0xFFFBE9E7);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const control = 8.0;
  static const card = 12.0;
  static const dialog = 16.0;
}

abstract final class AppText {
  static const title = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const heading = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );
  static const label = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );
  static const caption = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );
}

const cardShadow = [
  BoxShadow(color: Color(0x1F172D24), offset: Offset(0, 2), blurRadius: 6),
];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.error,
    outline: AppColors.border,
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineSmall: AppText.title,
      titleLarge: AppText.heading,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      labelLarge: AppText.label,
      bodySmall: AppText.caption,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.heading,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.muted,
        textStyle: AppText.label,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        textStyle: AppText.label,
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.primary,
        textStyle: AppText.label,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: AppText.body.copyWith(color: AppColors.muted),
      contentPadding: const EdgeInsets.all(AppSpace.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.selected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppText.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              )
            : AppText.caption,
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

import 'package:flutter/material.dart';
import 'package:universal_bible/core/design/app_tokens.dart';

/// "Calm study" themes (docs/UI_OVERHAUL.md): explicit ColorSchemes built
/// from AppTokens — no fromSeed. Inter is the app-wide UI font; scripture
/// and display styles opt into Literata explicitly via AppTypography.
class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        inkPrimary: AppColorsLight.inkPrimary,
        paper: AppColorsLight.paper,
        paperElevated: AppColorsLight.paperElevated,
        chromeSurface: AppColorsLight.chromeSurface,
        inkText: AppColorsLight.inkText,
        inkTextSecondary: AppColorsLight.inkTextSecondary,
        hairline: AppColorsLight.hairline,
        selectionWash: AppColorsLight.selectionWash,
        danger: AppColorsLight.danger,
        onPrimary: Colors.white,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        inkPrimary: AppColorsDark.inkPrimary,
        paper: AppColorsDark.paper,
        paperElevated: AppColorsDark.paperElevated,
        chromeSurface: AppColorsDark.chromeSurface,
        inkText: AppColorsDark.inkText,
        inkTextSecondary: AppColorsDark.inkTextSecondary,
        hairline: AppColorsDark.hairline,
        selectionWash: AppColorsDark.selectionWash,
        danger: AppColorsDark.danger,
        onPrimary: AppColorsDark.paper,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color inkPrimary,
    required Color paper,
    required Color paperElevated,
    required Color chromeSurface,
    required Color inkText,
    required Color inkTextSecondary,
    required Color hairline,
    required Color selectionWash,
    required Color danger,
    required Color onPrimary,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: inkPrimary,
      onPrimary: onPrimary,
      // Secondary maps to the same ink family — one accent, per the
      // "ink, not color" principle.
      secondary: inkPrimary,
      onSecondary: onPrimary,
      primaryContainer: selectionWash,
      onPrimaryContainer: inkText,
      secondaryContainer: selectionWash,
      onSecondaryContainer: inkText,
      error: danger,
      onError: onPrimary,
      surface: paper,
      onSurface: inkText,
      onSurfaceVariant: inkTextSecondary,
      surfaceContainerLowest: paperElevated,
      surfaceContainerLow: chromeSurface,
      surfaceContainer: chromeSurface,
      surfaceContainerHigh: paperElevated,
      surfaceContainerHighest: paperElevated,
      outline: inkTextSecondary,
      outlineVariant: hairline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: inkText,
      onInverseSurface: paper,
      inversePrimary: paper,
    );

    final base = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      // Inter is the functional UI font app-wide; scripture/display styles
      // opt into Literata via AppTypography.
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: paper,
    );

    return base.copyWith(
      dividerTheme: DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: paper,
        foregroundColor: inkText,
        titleTextStyle: AppTypography.title.copyWith(color: inkText),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: paperElevated,
        contentTextStyle: AppTypography.uiBody.copyWith(color: inkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: BorderSide(color: hairline),
        ),
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        titleTextStyle: AppTypography.title.copyWith(
          color: inkText,
          fontSize: 18,
        ),
        contentTextStyle: AppTypography.uiBody.copyWith(color: inkText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperElevated,
        hintStyle: AppTypography.uiBody.copyWith(color: inkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          borderSide: BorderSide(color: inkPrimary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: inkText,
          textStyle: AppTypography.uiLabel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: inkPrimary,
          foregroundColor: onPrimary,
          textStyle: AppTypography.uiLabel.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkText,
          side: BorderSide(color: hairline),
          textStyle: AppTypography.uiLabel,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s12,
          ),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: inkPrimary,
        inactiveTrackColor: hairline,
        thumbColor: inkPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onPrimary
              : inkTextSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? inkPrimary : hairline,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inkText,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        textStyle: AppTypography.caption.copyWith(color: paper),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: inkTextSecondary,
        textColor: inkText,
      ),
      iconTheme: IconThemeData(color: inkTextSecondary),
    );
  }
}

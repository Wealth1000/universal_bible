import 'package:flutter/material.dart';

/// Design tokens for the "calm study" visual language (docs/UI_OVERHAUL.md).
/// Single source of truth — screens must not hardcode colors, sizes, or
/// spacing. Semantics: warm paper reading surfaces, deep ink accent,
/// Literata for scripture/display, Inter for functional UI.
abstract final class AppColorsLight {
  static const inkPrimary = Color(0xFF2E434C);
  static const inkPrimaryHover = Color(0xFF3D5563);
  static const paper = Color(0xFFFAF7F2);
  static const paperElevated = Color(0xFFFFFFFF);
  static const chromeSurface = Color(0xFFF1EDE6);
  static const inkText = Color(0xFF2A2A26);
  static const inkTextSecondary = Color(0xFF6B675F);
  static const hairline = Color(0xFFE2DDD3);
  static const selectionWash = Color(0xFFEFE9DB);
  static const wordsOfChrist = Color(0xFFA63A2E);
  static const danger = Color(0xFFB3432E);
  static const success = Color(0xFF4E6E58);
}

abstract final class AppColorsDark {
  static const inkPrimary = Color(0xFF9FB4BF);
  static const inkPrimaryHover = Color(0xFFB4C6CF);
  static const paper = Color(0xFF211F1C);
  static const paperElevated = Color(0xFF2A2724);
  static const chromeSurface = Color(0xFF1B1917);
  static const inkText = Color(0xFFE8E3DA);
  static const inkTextSecondary = Color(0xFF9C968A);
  static const hairline = Color(0xFF3A3630);
  static const selectionWash = Color(0xFF3B3628);
  static const wordsOfChrist = Color(0xFFD9836F);
  static const danger = Color(0xFFD9776A);
  static const success = Color(0xFF8FAE97);
}

/// Brightness-resolved access for widgets that can't go through ColorScheme
/// (e.g. selection wash, red-letter).
abstract final class AppColors {
  static Color inkPrimary(Brightness b) => b == Brightness.dark
      ? AppColorsDark.inkPrimary
      : AppColorsLight.inkPrimary;
  static Color paper(Brightness b) =>
      b == Brightness.dark ? AppColorsDark.paper : AppColorsLight.paper;
  static Color paperElevated(Brightness b) => b == Brightness.dark
      ? AppColorsDark.paperElevated
      : AppColorsLight.paperElevated;
  static Color chromeSurface(Brightness b) => b == Brightness.dark
      ? AppColorsDark.chromeSurface
      : AppColorsLight.chromeSurface;
  static Color inkText(Brightness b) =>
      b == Brightness.dark ? AppColorsDark.inkText : AppColorsLight.inkText;
  static Color inkTextSecondary(Brightness b) => b == Brightness.dark
      ? AppColorsDark.inkTextSecondary
      : AppColorsLight.inkTextSecondary;
  static Color hairline(Brightness b) =>
      b == Brightness.dark ? AppColorsDark.hairline : AppColorsLight.hairline;
  static Color selectionWash(Brightness b) => b == Brightness.dark
      ? AppColorsDark.selectionWash
      : AppColorsLight.selectionWash;
  static Color wordsOfChrist(Brightness b) => b == Brightness.dark
      ? AppColorsDark.wordsOfChrist
      : AppColorsLight.wordsOfChrist;
  static Color danger(Brightness b) =>
      b == Brightness.dark ? AppColorsDark.danger : AppColorsLight.danger;
  static Color success(Brightness b) =>
      b == Brightness.dark ? AppColorsDark.success : AppColorsLight.success;
}

abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

abstract final class AppRadius {
  static const double small = 6;
  static const double medium = 10;
  static const double large = 16;
}

abstract final class AppLayout {
  /// Max width of the scripture reading column.
  static const double readerColumnWidth = 680;

  /// Max width of content pages (search, bookmarks, notes, settings).
  static const double contentWidth = 720;

  /// Reader top bar height.
  static const double topBarHeight = 56;
}

abstract final class AppFonts {
  static const scripture = 'Literata';
  static const ui = 'Inter';
}

/// Text styles that aren't covered by ThemeData.textTheme (scripture and
/// reference styles) or need explicit reuse across widgets. Color is left
/// to callers (theme-dependent).
abstract final class AppTypography {
  /// Chapter-header book name.
  static const display = TextStyle(
    fontFamily: AppFonts.scripture,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Page titles (AppBars).
  static const title = TextStyle(
    fontFamily: AppFonts.scripture,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  /// Verse text. Font size comes from the user setting.
  static TextStyle scripture(double fontSize) => TextStyle(
        fontFamily: AppFonts.scripture,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        height: 1.7,
      );

  /// Verse references, "Chapter N", small caps-ish labels.
  static const scriptureRef = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );

  /// Buttons, list titles, form labels.
  static const uiLabel = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Descriptions, secondary content.
  static const uiBody = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Metadata, counts, dates, rail labels.
  static const caption = TextStyle(
    fontFamily: AppFonts.ui,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

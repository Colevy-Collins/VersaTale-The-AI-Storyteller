// lib/theme/app_palettes.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Enumerates the available color + font palettes.
enum AppPalette {
  sereneSky,
  parchmentTale,
  midnightInk,
}

/// Bundles a ColorScheme and TextTheme for easy lookup.
class AppTheme {
  final ColorScheme colors;
  final TextTheme text;

  AppTheme({
    required this.colors,
    required this.text,
  });
}

/// Mapping from each AppPalette value to its AppTheme.
/// Use a non-const map since ColorScheme.light/dark and GoogleFonts themes
/// are not compile-time constants.
final Map<AppPalette, AppTheme> kThemes = {
  AppPalette.sereneSky: AppTheme(
    colors: ColorScheme.light(
      primary:     const Color(0xFF7FBFC5),
      surface:     const Color(0xFFECF0F3),
      background:  const Color(0xFFE3F2FD),
      secondary:   const Color(0xFFFFB74D),
      onPrimary:    Colors.white,
      onSurface:    Colors.black,
      onBackground: Colors.black,
      onSecondary:  Colors.black,
    ),
    text: GoogleFonts.kottaOneTextTheme(),
  ),

  AppPalette.parchmentTale: AppTheme(
    colors: ColorScheme.light(
      primary:     const Color(0xFFBCAAA4),
      surface:     const Color(0xFFFAF3E0),
      background:  const Color(0xFFFFFBE6),
      secondary:   const Color(0xFF8D6E63),
      onPrimary:    Colors.white,
      onSurface:    Colors.black,
      onBackground: Colors.black,
      onSecondary:  Colors.black,
    ),
    // Poetsen One currently isn't provided as a dedicated method,
    // so use GoogleFonts.getTextTheme with its font family name.
    text: GoogleFonts.kottaOneTextTheme(),
  ),

  AppPalette.midnightInk: AppTheme(
    colors: ColorScheme.dark(
      primary:     const Color(0xFF212121),
      surface:     const Color(0xFF424242),
      background:  const Color(0xFF303030),
      secondary:   const Color(0xFF448AFF),
      onPrimary:    Colors.white,
      onSurface:    Colors.white,
      onBackground: Colors.white,
      onSecondary:  Colors.white,
    ),
    text: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
  ),
};
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All colour palettes currently shipped with the app.
/// If you delete one later, leave its enum value but remove it from `kThemes`.
/// That way old profile records still parse, then safely fall back at runtime.
enum AppPalette { sereneSky, parchmentTale, midnightInk, sunsetPeach, forestMoss }

/* ──────────────────────────────────────────────────────────────── */
/*  Defaults + helpers                                             */
/* ──────────────────────────────────────────────────────────────── */

const AppPalette kDefaultPalette = AppPalette.sereneSky;
const String     kDefaultFont    = 'Kotta One';

/// List of families offered in the UI.
/// Any profile that stores a name **not** in this list falls back to `kDefaultFont`.
const List<String> kAvailableFonts = [
  'Kotta One',
  'Fredoka',
  'Roboto',
];

/// True if [name] is one of the fonts above (case-sensitive).
bool isKnownFont(String? name) => name != null && kAvailableFonts.contains(name);

/// Human-readable labels (e.g. “Midnight Ink”).
extension AppPaletteLabel on AppPalette {
  String get label => name
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}')
      .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
}

/// A palette is only its `ColorScheme` – text colours are derived later.
class AppTheme {
  const AppTheme({required this.colors});
  final ColorScheme colors;
  bool get needsLightIcons => colors.primary.computeLuminance() < 0.4;
}

/* ──────────────────────────────────────────────────────────────── */
/*  Palette definitions                                            */
/* ──────────────────────────────────────────────────────────────── */

final Map<AppPalette, AppTheme> kThemes = {
  /* 1 ▪ Serene Sky */
  AppPalette.sereneSky: const AppTheme(
    colors: ColorScheme.light(
      primary: Color(0xFF5EB1C5),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCAEAF2),
      onPrimaryContainer: Color(0xFF002631),
      secondary: Color(0xFFFFA94D),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFFFFE0C2),
      onSecondaryContainer: Color(0xFF301A00),
      tertiary: Color(0xFF297373),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFAAF0F0),
      onTertiaryContainer: Color(0xFF002020),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      background: Color(0xFFE6F6FF),
      onBackground: Colors.black,
      surface: Color(0xFFF1F5F9),
      onSurface: Colors.black,
      surfaceVariant: Color(0xFFE1E8EC),
      onSurfaceVariant: Color(0xFF42484C),
      outline: Color(0xFF73777A),
      inverseSurface: Color(0xFF2E3133),
      inversePrimary: Color(0xFF62CFF2),
    ),
  ),

  /* 2 ▪ Parchment Tale */
  AppPalette.parchmentTale: const AppTheme(
    colors: ColorScheme.light(
      primary: Color(0xFFA68A79),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEEE1D7),
      onPrimaryContainer: Color(0xFF3B281C),
      secondary: Color(0xFF8D6746),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE6C6AB),
      onSecondaryContainer: Color(0xFF341E0A),
      tertiary: Color(0xFF57462B),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFDED0B4),
      onTertiaryContainer: Color(0xFF1B1405),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      background: Color(0xFFFFF9E7),
      onBackground: Colors.black,
      surface: Color(0xFFFFF4DE),
      onSurface: Colors.black,
      surfaceVariant: Color(0xFFE7DCCF),
      onSurfaceVariant: Color(0xFF4C453C),
      outline: Color(0xFF7F7668),
      inverseSurface: Color(0xFF2D2B26),
      inversePrimary: Color(0xFFCAA38A),
    ),
  ),

  /* 3 ▪ Midnight Ink */
  AppPalette.midnightInk: const AppTheme(
    colors: ColorScheme.dark(
      primary: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3C3C3C),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFF4D8FFF),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF00325C),
      onSecondaryContainer: Colors.white,
      tertiary: Color(0xFF00C4B4),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF003732),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      errorContainer: Color(0xFF8C1D18),
      onErrorContainer: Colors.white,
      background: Color(0xFF2E2E2E),
      onBackground: Colors.white,
      surface: Color(0xFF3C3C3C),
      onSurface: Colors.white,
      surfaceVariant: Color(0xFF4B4B4B),
      onSurfaceVariant: Color(0xFFC5C5C5),
      outline: Color(0xFF919191),
      inverseSurface: Color(0xFFE0E0E0),
      inversePrimary: Color(0xFF6EC2FF),
    ),
  ),

  /* 4 ▪ Sunset Peach */
  AppPalette.sunsetPeach: const AppTheme(
    colors: ColorScheme.light(
      primary: Color(0xFFFF8F66),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFD6C7),
      onPrimaryContainer: Color(0xFF421101),
      secondary: Color(0xFFFFC971),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFFFFEFD2),
      onSecondaryContainer: Color(0xFF2A1700),
      tertiary: Color(0xFFEDAE49),
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFFFFE2B3),
      onTertiaryContainer: Color(0xFF321E00),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      background: Color(0xFFFFF7EC),
      onBackground: Colors.black,
      surface: Color(0xFFFFF1E6),
      onSurface: Colors.black,
      surfaceVariant: Color(0xFFF0D9CC),
      onSurfaceVariant: Color(0xFF50443C),
      outline: Color(0xFF84746A),
      inverseSurface: Color(0xFF2F2823),
      inversePrimary: Color(0xFFFFB389),
    ),
  ),

  /* 5 ▪ Forest Moss */
  AppPalette.forestMoss: const AppTheme(
    colors: ColorScheme.light(
      primary: Color(0xFF6B8F71),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCEE3CF),
      onPrimaryContainer: Color(0xFF0F2619),
      secondary: Color(0xFFA3C4A8),
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFFD6E8D8),
      onSecondaryContainer: Color(0xFF132716),
      tertiary: Color(0xFF556B2F),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD7E8A9),
      onTertiaryContainer: Color(0xFF192500),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      background: Color(0xFFF5F9F5),
      onBackground: Colors.black,
      surface: Color(0xFFE9F1EA),
      onSurface: Colors.black,
      surfaceVariant: Color(0xFFD9E3DA),
      onSurfaceVariant: Color(0xFF444B46),
      outline: Color(0xFF6F776F),
      inverseSurface: Color(0xFF272C28),
      inversePrimary: Color(0xFF8FB79A),
    ),
  ),
};

/* ──────────────────────────────────────────────────────────────── */
/*  Font helpers                                                   */
/* ──────────────────────────────────────────────────────────────── */

TextTheme textThemeFromFont(String family, TextTheme base) {
  try {
    switch (family) {
      case 'Fredoka':
        return GoogleFonts.getTextTheme('Fredoka', base);
      case 'Roboto':
        return GoogleFonts.robotoTextTheme(base);
      default:
        return GoogleFonts.getTextTheme(family, base);
    }
  } catch (e) {
    // Falls back to default font if Google Fonts throws (e.g. invalid name).
    debugPrint('⚠️  Unknown font “$family” – using $kDefaultFont');
    return GoogleFonts.getTextTheme(kDefaultFont, base);
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'app_palettes.dart';
import '../services/story_service.dart';

class ThemeNotifier extends ChangeNotifier {
  /* current selections */
  AppPalette _palette    = kDefaultPalette;
  String     _fontFamily = kDefaultFont;

  /* public getters */
  AppPalette get currentPalette => _palette;
  String     get currentFont    => _fontFamily;

  /*──────────────────── ThemeData builder ─────────────────*/
  ThemeData get theme {
    final scheme = kThemes[_palette]!.colors;

    /* 1 ▪ text theme in Google Font, recoloured */
    final textTheme = GoogleFonts.getTextTheme(_fontFamily).apply(
      displayColor: scheme.onSurface,
      bodyColor   : scheme.onSurface,
    );

    /* 2 ▪ pick a high‑contrast accent for buttons */
    Color accent() {
      final candidate = scheme.brightness == Brightness.dark
          ? scheme.secondary   // dark palettes → secondary (bright)
          : scheme.primary;    // light palettes → primary

      // fall back to solid black / white if accent fails 4.5:1
      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance();
        final l2 = b.computeLuminance();
        return ((l1 > l2) ? (l1 + .05) / (l2 + .05) : (l2 + .05) / (l1 + .05));
      }

      return contrast(candidate, scheme.surface) >= 4.5
          ? candidate
          : scheme.onSurface;
    }

    final accentColor   = accent();
    final accentFgColor =
    ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    /* 3 ▪ global button styles */
    final btnFg = MaterialStateProperty.all(accentColor);

    return ThemeData.from(
      colorScheme : scheme,
      textTheme   : textTheme,
      useMaterial3: true,
    ).copyWith(
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(foregroundColor: btnFg),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(foregroundColor: btnFg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(accentColor),
          foregroundColor: MaterialStateProperty.all(accentFgColor),
        ),
      ),
    );
  }

  /*──────────────── profile loading / updates ─────────────*/
  void loadFromProfile(Map<String, dynamic> json) {
    final palKey = json['preferredPalette'] as String?;
    final font   = json['preferredFont']   as String?;

    if (palKey != null &&
        AppPalette.values.any((p) => p.name == palKey) &&
        kThemes.containsKey(
          AppPalette.values.firstWhere((p) => p.name == palKey),
        )) {
      _palette = AppPalette.values.firstWhere((p) => p.name == palKey);
    } else if (palKey != null) {
      debugPrint('⚠️ Unknown palette “$palKey” – using $kDefaultPalette');
    }

    if (font != null && isKnownFont(font)) {
      _fontFamily = font;
    } else if (font != null) {
      debugPrint('⚠️ Unknown font “$font” – using $kDefaultFont');
    }

    notifyListeners();
  }

  Future<void> updatePalette(AppPalette p, StoryService api) async {
    if (!kThemes.containsKey(p)) return;
    _palette = p;
    notifyListeners();
    await api.updateUserTheme(
      paletteKey: p.name,
      fontFamily: _fontFamily,
    );
  }

  Future<void> updateFont(String fam, StoryService api) async {
    if (!isKnownFont(fam)) return;
    _fontFamily = fam;
    notifyListeners();
    await api.updateUserTheme(
      paletteKey: _palette.name,
      fontFamily: fam,
    );
  }
}

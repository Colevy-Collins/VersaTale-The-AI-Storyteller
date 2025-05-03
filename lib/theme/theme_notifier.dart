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

  /*──────────────────  ThemeData  ──────────────────*/
  ThemeData get theme {
    final scheme = kThemes[_palette]!.colors;

    /*  text theme in the chosen Google Font, repaint ALL styles  */
    final textTheme = GoogleFonts.getTextTheme(_fontFamily).apply(
      displayColor: scheme.onSurface,
      bodyColor   : scheme.onSurface,
    );

    /*  global TextButton style that always contrasts  */
    final txtBtn = TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.secondary,   // visible in every palette
      ),
    );

    return ThemeData.from(
      colorScheme : scheme,
      textTheme   : textTheme,
      useMaterial3: true,
    ).copyWith(textButtonTheme: txtBtn);
  }

  /*──────────────────  profile loading  ──────────────────*/
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

    notifyListeners();             // rebuild MaterialApp
  }

  /*──────────────────  update helpers  ──────────────────*/
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

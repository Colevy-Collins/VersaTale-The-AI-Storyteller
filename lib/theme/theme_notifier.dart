import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'app_palettes.dart';
import '../services/story_service.dart';

/// Provides the current palette & font to the whole app and guarantees
/// sane defaults when user data references values no longer present.
class ThemeNotifier extends ChangeNotifier {
  /* current selections (start with defaults) */
  AppPalette _palette    = kDefaultPalette;
  String     _fontFamily = kDefaultFont;

  /* getters for UI */
  AppPalette get currentPalette => _palette;
  String     get currentFont    => _fontFamily;

  /* ── ThemeData (always safe) ── */
  ThemeData get theme {
    final scheme = kThemes[_palette]?.colors ?? kThemes[kDefaultPalette]!.colors;
    final base   = scheme.brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    final text = textThemeFromFont(_fontFamily, base).apply(
      bodyColor   : scheme.onBackground,
      displayColor: scheme.onBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme : scheme,
      textTheme   : text,
      fontFamily  : _fontFamily,
    );
  }

  /* ── load profile with validation ── */
  void loadFromProfile(Map<String, dynamic> json) {
    final palKey = json['preferredPalette'] as String?;
    final font   = json['preferredFont']   as String?;

    // Palette validation
    if (palKey != null &&
        AppPalette.values.any((p) => p.name == palKey) &&
        kThemes.containsKey(AppPalette.values.firstWhere((p) => p.name == palKey))) {
      _palette = AppPalette.values.firstWhere((p) => p.name == palKey);
    } else if (palKey != null) {
      debugPrint('⚠️  Unknown palette “$palKey” – using $kDefaultPalette');
      _palette = kDefaultPalette;
    }

    // Font validation
    if (isKnownFont(font)) {
      _fontFamily = font!;
    } else if (font != null) {
      debugPrint('⚠️  Unknown font “$font” – using $kDefaultFont');
      _fontFamily = kDefaultFont;
    }

    notifyListeners();
  }

  /* ── update helpers (ignore invalid data) ── */
  Future<void> updatePalette(AppPalette p, StoryService api) async {
    if (!kThemes.containsKey(p)) return; // ignore removed palette
    _palette = p;
    notifyListeners();
    await api.updateUserTheme(paletteKey: p.name, fontFamily: _fontFamily);
  }

  Future<void> updateFont(String fam, StoryService api) async {
    if (!isKnownFont(fam)) return;       // ignore removed font
    _fontFamily = fam;
    notifyListeners();
    await api.updateUserTheme(paletteKey: _palette.name, fontFamily: fam);
  }
}

// lib/theme/theme_notifier.dart

import 'package:flutter/material.dart';
import 'app_palettes.dart';
import '../services/story_service.dart';

/// A ChangeNotifier that holds the current palette and font,
/// allows updating them (and persisting to the backend),
/// and exposes a ThemeData that rebuilds the app when modified.
class ThemeNotifier extends ChangeNotifier {
  // Default values if the user hasn't chosen yet
  AppPalette _palette = AppPalette.sereneSky;
  String     _fontFamily = 'Kotta One';

  /// Expose the current palette and font for UI selectors.
  AppPalette get currentPalette => _palette;
  String     get currentFont    => _fontFamily;

  /// Build a ThemeData based on the selected palette & font.
  ThemeData get theme {
    final appTheme = kThemes[_palette]!;
    return ThemeData(
      colorScheme: appTheme.colors,
      textTheme:   appTheme.text.apply(fontFamily: _fontFamily),
      useMaterial3: true,
    );
  }

  /// Load palette & font from a profile JSON returned by getUserProfile().
  void loadFromProfile(Map<String, dynamic> json) {
    final palKey = json['preferredPalette'] as String?;
    if (palKey != null) {
      _palette = AppPalette.values.firstWhere(
            (p) => p.name == palKey,
        orElse: () => _palette,
      );
    }
    final font = json['preferredFont'] as String?;
    if (font != null) {
      _fontFamily = font;
    }
    notifyListeners();
  }

  /// Update the palette, notify listeners, and persist the choice.
  Future<void> updatePalette(AppPalette p, StoryService api) async {
    _palette = p;
    notifyListeners();
    await api.updateUserTheme(
      paletteKey: p.name,
      fontFamily: _fontFamily,
    );
  }

  /// Update the font, notify listeners, and persist the choice.
  Future<void> updateFont(String family, StoryService api) async {
    _fontFamily = family;
    notifyListeners();
    await api.updateUserTheme(
      paletteKey: _palette.name,
      fontFamily: family,
    );
  }
}

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Brand colors per platform — used as solid pill fills so each owned game
/// still nods at its console, without turning the UI into a rainbow.
class PlatformPalette {
  /// Saturated brand color (good for icons, borders, accents).
  static Color of(String? shortName) {
    if (shortName == null) return AppColors.accent;
    return _map[shortName.toUpperCase().trim()] ?? AppColors.accent;
  }

  /// Darker body color used as the solid fill of pills/badges. Pairs with
  /// the brand color as a thin top-border/accent and white text.
  static Color bodyOf(String? shortName) {
    if (shortName == null) return AppColors.surfaceHi;
    return _bodyMap[shortName.toUpperCase().trim()] ?? AppColors.surfaceHi;
  }

  static const Map<String, Color> _map = {
    // Nintendo
    'NES': Color(0xFFE57373),
    'SNES': Color(0xFFB39DDB),
    'N64': Color(0xFF81C784),
    'NGC': Color(0xFF9575CD),
    'WII': Color(0xFF64B5F6),
    'WII U': Color(0xFF4FC3F7),
    'SWITCH': Color(0xFFE57373),
    'GB': Color(0xFFAED581),
    'GBC': Color(0xFFAED581),
    'GBA': Color(0xFFB39DDB),
    'NDS': Color(0xFFF06292),
    '3DS': Color(0xFFE57373),
    // Sony
    'PS1': Color(0xFF64B5F6),
    'PS2': Color(0xFF42A5F5),
    'PS3': Color(0xFF7E57C2),
    'PS4': Color(0xFF3F51B5),
    'PS5': Color(0xFF5C6BC0),
    'PSP': Color(0xFF7E57C2),
    'VITA': Color(0xFF7E57C2),
    // Microsoft
    'XBOX': Color(0xFF81C784),
    'X360': Color(0xFF66BB6A),
    'XONE': Color(0xFF66BB6A),
    'XSX': Color(0xFF66BB6A),
    // Sega
    'SMS': Color(0xFF4DB6AC),
    'MD': Color(0xFF4DB6AC),
    'SATURN': Color(0xFF7986CB),
    'DC': Color(0xFFFFB74D),
    'GG': Color(0xFF7986CB),
    // Misc
    '2600': Color(0xFFFFB74D),
    'NG': Color(0xFFE57373),
    'PC': Color(0xFF90A4AE),
  };

  // Dark, slightly-tinted body for the pill background.
  static const Map<String, Color> _bodyMap = {
    'NES': Color(0xFF3A1F1F),
    'SNES': Color(0xFF2A2235),
    'N64': Color(0xFF1F3022),
    'NGC': Color(0xFF26223A),
    'WII': Color(0xFF1F2A38),
    'WII U': Color(0xFF1F2A38),
    'SWITCH': Color(0xFF3A1F1F),
    'GB': Color(0xFF25331F),
    'GBC': Color(0xFF25331F),
    'GBA': Color(0xFF2A2235),
    'NDS': Color(0xFF3A1F2A),
    '3DS': Color(0xFF3A1F1F),
    'PS1': Color(0xFF1F2A38),
    'PS2': Color(0xFF1F2A38),
    'PS3': Color(0xFF221F38),
    'PS4': Color(0xFF1F2238),
    'PS5': Color(0xFF1F2238),
    'PSP': Color(0xFF221F38),
    'VITA': Color(0xFF221F38),
    'XBOX': Color(0xFF1F3022),
    'X360': Color(0xFF1F3022),
    'XONE': Color(0xFF1F3022),
    'XSX': Color(0xFF1F3022),
    'SMS': Color(0xFF1F302E),
    'MD': Color(0xFF1F302E),
    'SATURN': Color(0xFF222538),
    'DC': Color(0xFF3A2F1F),
    'GG': Color(0xFF222538),
    '2600': Color(0xFF3A2F1F),
    'NG': Color(0xFF3A1F1F),
    'PC': Color(0xFF1F2A30),
  };
}

/// A single accent color for genre chips, picked deterministically per
/// genre name. Each chip is rendered with a dark base, a colored border and
/// white text so it stays readable on any background.
class GenrePalette {
  static const List<Color> _accents = [
    Color(0xFFE57373), // soft red
    Color(0xFFFFB74D), // soft amber
    Color(0xFFFFD54F), // soft yellow
    Color(0xFFAED581), // soft green
    Color(0xFF4DD0E1), // soft cyan
    Color(0xFF64B5F6), // soft blue
    Color(0xFF9575CD), // soft purple
    Color(0xFFF06292), // soft pink
    Color(0xFFBA68C8), // soft magenta
    Color(0xFF4DB6AC), // soft teal
    Color(0xFFFF8A65), // soft orange
    Color(0xFFA1887F), // soft brown
  ];

  static Color of(String? name) {
    if (name == null) return _accents[0];
    return _accents[name.hashCode.abs() % _accents.length];
  }
}

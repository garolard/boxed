import 'package:flutter/material.dart';

/// Brand colors per platform — used for badges, gradients and accents so each
/// owned game visually nods at the console it belongs to.
class PlatformPalette {
  /// Primary color for a given platform short name (case-insensitive).
  /// Falls back to a neutral magenta when unknown.
  static Color of(String? shortName) {
    if (shortName == null) return const Color(0xFFFF2E93);
    final key = shortName.toUpperCase().trim();
    return _map[key] ?? const Color(0xFFFF2E93);
  }

  /// Soft complementary color used for gradient ends.
  static Color accentOf(String? shortName) {
    if (shortName == null) return const Color(0xFF00E5FF);
    final key = shortName.toUpperCase().trim();
    return _accentMap[key] ?? const Color(0xFF00E5FF);
  }

  /// Returns a horizontal gradient for the given platform.
  static LinearGradient gradientOf(String? shortName) {
    return LinearGradient(
      colors: [of(shortName), accentOf(shortName)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static const Map<String, Color> _map = {
    // Nintendo — red/grey/blue family
    'NES': Color(0xFFE60012),
    'SNES': Color(0xFF7A4FB3),
    'N64': Color(0xFF1A8B4E),
    'NGC': Color(0xFF5A2D81),
    'WII': Color(0xFF009AC7),
    'WII U': Color(0xFF009AC7),
    'SWITCH': Color(0xFFE60012),
    'GB': Color(0xFF8FAB33),
    'GBC': Color(0xFF8FAB33),
    'GBA': Color(0xFF6B2BA1),
    'NDS': Color(0xFFB3003B),
    '3DS': Color(0xFFD62828),

    // Sony — blue family
    'PS1': Color(0xFF2D6CDF),
    'PS2': Color(0xFF1B4FB0),
    'PS3': Color(0xFF1B1B3A),
    'PS4': Color(0xFF003791),
    'PS5': Color(0xFF0070D1),
    'PSP': Color(0xFF1B1B3A),
    'VITA': Color(0xFF1B1B3A),

    // Microsoft — green family
    'XBOX': Color(0xFF4CAF50),
    'X360': Color(0xFF107C10),
    'XONE': Color(0xFF107C10),
    'XSX': Color(0xFF107C10),

    // Sega — teal/blue family
    'SMS': Color(0xFF1F8A70),
    'MD': Color(0xFF1F8A70),
    'SATURN': Color(0xFF26396F),
    'DC': Color(0xFFFF7F00),
    'GG': Color(0xFF26396F),

    // Misc
    '2600': Color(0xFFCC5500),
    'NG': Color(0xFFCC0000),
    'PC': Color(0xFF4F6D8F),
  };

  static const Map<String, Color> _accentMap = {
    'NES': Color(0xFFFFC233),
    'SNES': Color(0xFFFF6FB5),
    'N64': Color(0xFF4DE694),
    'NGC': Color(0xFFB17CFF),
    'WII': Color(0xFF7FE0FF),
    'WII U': Color(0xFF7FE0FF),
    'SWITCH': Color(0xFFFF4D6D),
    'GB': Color(0xFFC7E26B),
    'GBC': Color(0xFFB6FFB6),
    'GBA': Color(0xFFB17CFF),
    'NDS': Color(0xFFFF7F8A),
    '3DS': Color(0xFFFF8C8C),
    'PS1': Color(0xFF7FB7FF),
    'PS2': Color(0xFF7FB7FF),
    'PS3': Color(0xFF5C5CC2),
    'PS4': Color(0xFF5BA0FF),
    'PS5': Color(0xFF7FB7FF),
    'PSP': Color(0xFF5C5CC2),
    'VITA': Color(0xFF5C5CC2),
    'XBOX': Color(0xFF7DDB7D),
    'X360': Color(0xFF4DE694),
    'XONE': Color(0xFF4DE694),
    'XSX': Color(0xFF4DE694),
    'SMS': Color(0xFF7DDBB6),
    'MD': Color(0xFF7DDBB6),
    'SATURN': Color(0xFF7FB7FF),
    'DC': Color(0xFFFFC233),
    'GG': Color(0xFF7FB7FF),
    '2600': Color(0xFFFFC233),
    'NG': Color(0xFFFF6B6B),
    'PC': Color(0xFF9FC3E8),
  };
}

/// Vivid colors for genre chips, so lists feel varied and rich.
class GenrePalette {
  static const _colors = <Color>[
    Color(0xFFFF2E93), // magenta
    Color(0xFF00E5FF), // cyan
    Color(0xFFFFD600), // yellow
    Color(0xFF7C4DFF), // purple
    Color(0xFF00E676), // green
    Color(0xFFFF6E40), // orange
    Color(0xFF448AFF), // blue
    Color(0xFFFF1744), // red
    Color(0xFF1DE9B6), // teal
    Color(0xFFD500F9), // violet
    Color(0xFFFF4081), // pink
    Color(0xFF18FFFF), // aqua
  ];

  static Color of(String? name) {
    if (name == null) return _colors[0];
    return _colors[name.hashCode.abs() % _colors.length];
  }
}

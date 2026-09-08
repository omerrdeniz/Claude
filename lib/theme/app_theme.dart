import 'package:flutter/material.dart';

/// Central colour and typography definitions.
///
/// The game is played on a dark stage so that note beams and particle effects
/// carry the contrast; everything else is defined relative to that.
abstract final class AppTheme {
  static const Color background = Color(0xFF0B0B14);
  static const Color surface = Color(0xFF15152A);
  static const Color accent = Color(0xFF6C5CE7);
  static const Color accentSoft = Color(0xFF9C8CFF);
  static const Color textPrimary = Color(0xFFF2F2F7);
  static const Color textMuted = Color(0xFF9A9AB0);

  /// One hue per beam, low to high. Pitch reads as colour as well as
  /// position, which is what lets the player follow a line without
  /// looking straight at it.
  static const List<Color> beamColors = [
    Color(0xFF7B5CFF), // violet
    Color(0xFF4C8DFF), // blue
    Color(0xFF2ED3C6), // teal
    Color(0xFFFF6BB5), // pink
  ];

  static Color beamColor(int beam) => beamColors[beam % beamColors.length];

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accentSoft,
        surface: surface,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}

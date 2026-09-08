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

  /// One hue per beam, low to high — a cool-to-warm ramp, so pitch reads as
  /// colour as well as position and the player can follow a line without
  /// looking straight at it.
  ///
  /// There are six because six is the most beams any layout uses. Repeating a
  /// hue would put two different pitches in the same colour and quietly undo
  /// the whole point of colouring them.
  static const List<Color> beamColors = [
    Color(0xFF7B5CFF), // violet
    Color(0xFF5B7CFF), // indigo
    Color(0xFF3FA9FF), // blue
    Color(0xFF2ED3C6), // teal
    Color(0xFFFFB25C), // amber
    Color(0xFFFF6BB5), // pink
  ];

  /// The colour of [beam] out of [beamCount], spread across the ramp so the
  /// outer beams keep the extreme hues however many there are.
  static Color beamColor(int beam, [int beamCount = 4]) {
    if (beamCount <= 1) return beamColors[beamColors.length ~/ 2];
    final position = beam.clamp(0, beamCount - 1) / (beamCount - 1);
    final index = (position * (beamColors.length - 1)).round();
    return beamColors[index];
  }

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

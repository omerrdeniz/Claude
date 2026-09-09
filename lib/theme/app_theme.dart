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

  /// How many fingers a moment needs, as colour.
  ///
  /// This is the one thing the player has to read ahead of time, and reading
  /// it from the count of dots is too slow at speed. One colour per chord
  /// size, shared by every note in that chord, says "one finger" or "three
  /// fingers" at a glance and before the hand has to be there.
  static const List<Color> chordColors = [
    Color(0xFF9B6BFF), // one finger — violet
    Color(0xFFFFC048), // two — amber
    Color(0xFF3FA9FF), // three — blue
    Color(0xFF3DD68C), // four or more — green
  ];

  static Color chordColor(int fingers) =>
      chordColors[(fingers - 1).clamp(0, chordColors.length - 1)];

  /// Kept for the keyboard's key highlight and other accents.
  static const List<Color> beamColors = chordColors;

  static Color colorAcross(double across) =>
      chordColors[(across.clamp(0.0, 1.0) * (chordColors.length - 1)).round()];

  static Color beamColor(int beam, [int beamCount = 4]) => colorAcross(
      beamCount <= 1 ? 0.5 : beam.clamp(0, beamCount - 1) / (beamCount - 1));

  /// Bundled with the app, so text renders identically everywhere and needs
  /// no network — the web build otherwise fetches its font from a CDN.
  static const String fontFamily = 'Inter';

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: fontFamily),
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accentSoft,
        surface: surface,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }
}

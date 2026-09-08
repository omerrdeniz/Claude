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

  /// Pitch as colour, lowest to highest.
  ///
  /// The stops climb the colour wheel in one direction — blue through violet
  /// and magenta to a warm pink — so blending between any two of them stays
  /// vivid. A ramp that crosses the wheel the other way passes through olive
  /// on its way from teal to amber, and a note the colour of mud reads as a
  /// mistake rather than a pitch.
  static const List<Color> beamColors = [
    Color(0xFF4C6BFF), // blue
    Color(0xFF7B5CFF), // violet
    Color(0xFFA855F7), // purple
    Color(0xFFD94FB0), // magenta
    Color(0xFFFF5C8A), // pink
    Color(0xFFFF8A6B), // coral
  ];

  /// The colour at [across] of the pitch range, 0 lowest and 1 highest.
  ///
  /// Blended through HSV rather than RGB: mixing two saturated colours by
  /// their channels drains the life out of whatever sits between them.
  static Color colorAcross(double across) {
    final position = across.clamp(0.0, 1.0) * (beamColors.length - 1);
    final index = position.floor().clamp(0, beamColors.length - 2);
    return HSVColor.lerp(
      HSVColor.fromColor(beamColors[index]),
      HSVColor.fromColor(beamColors[index + 1]),
      position - index,
    )!
        .toColor();
  }

  /// The colour of [beam] out of [beamCount].
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

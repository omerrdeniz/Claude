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

  /// The ground a song falls back on when there is nothing to read a key
  /// from — an empty song, or a screen drawn before one is loaded. Every
  /// song that has notes gets its own; see [groundOf] in `song_ground.dart`,
  /// which replaced the hand-written table that used to live here.
  static const Ground defaultGround = Ground(
    top: Color(0xFF13132A),
    bottom: Color(0xFF08080F),
    glow: accent,
  );

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

/// The colours a piece is played on.
///
/// Every song used to be played on the same dark violet field. Eight songs on
/// one background is eight songs in one room; the piece should bring its own
/// light with it. Held as three colours rather than a picture so the ground
/// can be a shader — see `shaders/stage.frag`.
class Ground {
  const Ground({required this.top, required this.bottom, required this.glow});

  /// The far end of the stage, where the notes come from.
  final Color top;

  /// Underfoot, past the line.
  final Color bottom;

  /// The pool of light the notes land in.
  final Color glow;

  @override
  bool operator ==(Object other) =>
      other is Ground &&
      other.top == top &&
      other.bottom == bottom &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(top, bottom, glow);
}

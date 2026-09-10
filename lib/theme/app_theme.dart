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

  /// The default ground: the dark violet field the game has always used.
  static const Ground defaultGround = Ground(
    top: Color(0xFF13132A),
    bottom: Color(0xFF08080F),
    glow: accent,
  );

  /// The light each piece is played in.
  ///
  /// Eight songs on one background is eight songs in one room. A piece has a
  /// temperature — Satie is cold and still, Joplin is a warm room with people
  /// in it, Chopin is night — and the ground is the cheapest place to say so.
  ///
  /// Chosen, not derived. A rule from the notes (low means warm, high means
  /// cold, say) would be defensible and would get every one of them wrong:
  /// the Bach and the nocturne sit in much the same register and could not be
  /// further apart in what they are.
  ///
  /// Kept dark. The notes are bright and saturated and have to stay the
  /// brightest thing on the screen; a ground that competes with them is a
  /// ground that has to go.
  static const Map<String, Ground> _grounds = {
    // Cold, still, nocturnal.
    'gnossienne-1': Ground(
        top: Color(0xFF0E2226), bottom: Color(0xFF04090B), glow: Color(0xFF2FBFB8)),
    // Candlelight.
    'canon-in-d': Ground(
        top: Color(0xFF241A0F), bottom: Color(0xFF0B0705), glow: Color(0xFFE8A33D)),
    'canon-run-test': Ground(
        top: Color(0xFF241A0F), bottom: Color(0xFF0B0705), glow: Color(0xFFE8A33D)),
    // Daylight, and pleased about it.
    'ode-to-joy': Ground(
        top: Color(0xFF1E1A2E), bottom: Color(0xFF08070F), glow: Color(0xFFFFC65C)),
    // Clean and cool, like the piece.
    'prelude-in-c': Ground(
        top: Color(0xFF101A2A), bottom: Color(0xFF05080D), glow: Color(0xFF5B9BD5)),
    // Night.
    'nocturne-op9-no2': Ground(
        top: Color(0xFF141033), bottom: Color(0xFF05040F), glow: Color(0xFF7B6BE8)),
    // A warm room with people in it.
    'entertainer': Ground(
        top: Color(0xFF2A1710), bottom: Color(0xFF0D0705), glow: Color(0xFFFF8A3D)),
    // Rose, and a little sad.
    'fur-elise': Ground(
        top: Color(0xFF22132A), bottom: Color(0xFF0A050C), glow: Color(0xFFC96BE8)),
  };

  static Ground groundFor(String songId) =>
      _grounds[songId] ?? defaultGround;

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

import 'dart:ui';

/// Where everything sits on the playfield.
///
/// Deliberately plain. A tap counts wherever it lands, so the picture has no
/// mechanical job to do beyond showing *when* a note is due and roughly how
/// high or low it sounds. Anything more decorative risks teaching the player a
/// rule the game does not have — which is exactly what lanes, and then a fan
/// of rays, each did in turn.
///
/// Notes fall straight down and pitch sets their place across the screen,
/// continuously: neighbouring pitches sit side by side rather than snapping
/// into columns. Travel is linear in time, because a note covering equal
/// distance in equal time is what lets the eye predict the beat.
class StageGeometry {
  const StageGeometry({
    required this.size,
    required this.beamCount,
    this.hitLineFraction = 0.68,
    this.margin = 0.09,
  })  : assert(beamCount > 0),
        assert(hitLineFraction > 0 && hitLineFraction < 1);

  final Size size;

  /// Only used to group a chord onto separate fingers; the player never aims
  /// at a beam.
  final int beamCount;

  /// Height of the hit line, as a fraction of the screen. Two thirds down
  /// leaves the approach visible while keeping the line clear of the thumbs.
  final double hitLineFraction;

  /// Kept clear at each edge, so an outermost note is not clipped or hidden
  /// under the hand holding the phone.
  final double margin;

  double get hitLineY => size.height * hitLineFraction;

  double yAt(double progress) => hitLineY * progress;

  /// Where a note at [across] sits — 0 the lowest pitch in the song, 1 the
  /// highest.
  double xAtPosition(double across, [double progress = 1]) =>
      size.width * (margin + across.clamp(0.0, 1.0) * (1 - margin * 2));

  Offset positionAtPosition(double across, double progress) =>
      Offset(xAtPosition(across), yAt(progress));

  /// The centre of [beam] as a position across the screen.
  double acrossOfBeam(int beam) =>
      beamCount <= 1 ? 0.5 : (beam + 0.5) / beamCount;

  Offset positionAt(int beam, double progress) =>
      positionAtPosition(acrossOfBeam(beam), progress);

  double xAt(int beam, double progress) => positionAt(beam, progress).dx;

  /// How far apart notes would be if the width were divided evenly.
  double get beamSpacing => size.width * (1 - margin * 2) / beamCount;

  double beamWidthAt(double progress) => beamSpacing;

  /// Notes swell as they approach, then shrink once past the line so a note
  /// that has had its moment stops looking like one still waiting.
  double noteRadiusAt(double progress) {
    // Bounded by both dimensions: a wide, short screen has room across but not
    // down, and notes sized only by width would collide as they travel.
    final maxRadius =
        (beamSpacing * 0.3).clamp(10.0, 34.0).clamp(10.0, size.height * 0.05);
    if (progress <= 1) {
      return lerpDouble(maxRadius * 0.3, maxRadius, progress.clamp(0.0, 1.0))!;
    }
    return lerpDouble(maxRadius, maxRadius * 0.5,
        ((progress - 1) / 0.2).clamp(0.0, 1.0))!;
  }

  /// Progress of a tap that is [beatsAway] beats from being played, given a
  /// view that looks [window] beats ahead. 1 means it is on the line.
  static double progressFor(double beatsAway, double window) =>
      1 - beatsAway / window;
}

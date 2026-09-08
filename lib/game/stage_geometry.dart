import 'dart:ui';

/// Where everything sits on the playfield.
///
/// Position is continuous, not divided into lanes. A note's place across the
/// screen comes straight from its pitch, so a rising line climbs smoothly to
/// the right instead of jumping between columns — and since a tap counts
/// wherever it lands, a lane boundary would be drawing a rule the game does
/// not actually enforce.
///
/// Kept apart from the painting so the layout can be reasoned about and tested
/// on its own — a note that lands on the wrong pixel is a gameplay bug, not a
/// cosmetic one.
///
/// Beams are drawn in perspective: they converge toward a point above the
/// screen, so notes appear to travel out of the distance toward the player.
/// Movement along that path stays linear in time — a note covering equal
/// distance in equal time is what lets the eye predict the beat, and easing it
/// would quietly break the player's timing.
class StageGeometry {
  const StageGeometry({
    required this.size,
    required this.beamCount,
    this.hitLineFraction = 0.68,
    this.convergence = 0.42,
  })  : assert(beamCount > 0),
        assert(hitLineFraction > 0 && hitLineFraction < 1);

  final Size size;
  final int beamCount;

  /// Height of the hit line, as a fraction of the screen. Two thirds down
  /// leaves the approach visible while keeping the line clear of the thumbs.
  final double hitLineFraction;

  /// How far the beams squeeze together at the top: 0 is no perspective,
  /// 1 collapses them to a point.
  final double convergence;

  double get hitLineY => size.height * hitLineFraction;

  double get beamSpacing => size.width / beamCount;

  /// How spread out the beams are at [progress], where 0 is the top of the
  /// screen and 1 is the hit line.
  double spreadAt(double progress) =>
      lerpDouble(1 - convergence, 1.0, progress.clamp(0.0, 1.4))!;

  /// Vertical position of a note at [progress].
  double yAt(double progress) => hitLineY * progress;

  /// Horizontal centre of [beam] at [progress].
  double xAt(int beam, double progress) => xAtPosition(
      beamCount <= 1 ? 0.5 : (beam + 0.5) / beamCount, progress);

  /// Horizontal position of anything at [across] (0 far left, 1 far right).
  ///
  /// The margin keeps the outermost notes clear of the screen edge, where a
  /// glow would be clipped and a finger has nothing to aim at.
  double xAtPosition(double across, double progress) {
    const margin = 0.08;
    final placed = margin + across.clamp(0.0, 1.0) * (1 - margin * 2);
    return size.width / 2 +
        (placed - 0.5) * size.width * spreadAt(progress);
  }

  Offset positionAt(int beam, double progress) =>
      Offset(xAt(beam, progress), yAt(progress));

  Offset positionAtPosition(double across, double progress) =>
      Offset(xAtPosition(across, progress), yAt(progress));

  /// Width of a beam at [progress].
  double beamWidthAt(double progress) => beamSpacing * spreadAt(progress);

  /// Notes swell as they approach, which reads as coming closer — then shrink
  /// once past the line, so a note that has had its moment stops looking like
  /// one still waiting to be played.
  double noteRadiusAt(double progress) {
    // Bounded by both dimensions: a wide, short screen has room across but not
    // down, and notes sized only by beam width would collide as they travel.
    final maxRadius =
        (beamSpacing * 0.3).clamp(10.0, 34.0).clamp(10.0, size.height * 0.05);
    if (progress <= 1) {
      return lerpDouble(maxRadius * 0.35, maxRadius, progress.clamp(0.0, 1.0))!;
    }
    return lerpDouble(maxRadius, maxRadius * 0.5,
        ((progress - 1) / 0.2).clamp(0.0, 1.0))!;
  }

  /// Progress of a tap that is [beatsAway] beats from being played, given a
  /// view that looks [window] beats ahead. 1 means it is on the line.
  static double progressFor(double beatsAway, double window) =>
      1 - beatsAway / window;
}

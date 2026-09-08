import 'dart:math' as math;
import 'dart:ui';

/// Where everything sits on the playfield.
///
/// The stage is a fan: notes are born at a point off the top of the screen and
/// fly outward along rays, growing as they come, until they cross the arc where
/// they are due. Pitch sets the angle of the ray — low to the left, high to the
/// right — and it is continuous, so neighbouring pitches ride neighbouring
/// paths rather than snapping into columns.
///
/// Kept apart from the painting so the layout can be reasoned about and tested
/// on its own: a note that arrives in the wrong place is a gameplay bug, not a
/// cosmetic one.
///
/// Travel is linear in time. A note covering equal distance in equal time is
/// what lets the eye predict the beat; easing it would quietly break the
/// player's timing.
class StageGeometry {
  const StageGeometry({
    required this.size,
    required this.beamCount,
    this.hitLineFraction = 0.68,
    this.spreadFraction = 0.92,
  })  : assert(beamCount > 0),
        assert(hitLineFraction > 0 && hitLineFraction < 1);

  final Size size;

  /// Only used for grouping a chord onto separate fingers; the player does not
  /// aim at beams.
  final int beamCount;

  /// Where the arc crosses the centre of the screen, as a fraction of height.
  /// Two thirds down leaves the approach visible while keeping the arc clear
  /// of the thumbs.
  final double hitLineFraction;

  /// How much of the width the fan covers where it crosses the arc.
  final double spreadFraction;

  double get hitLineY => size.height * hitLineFraction;

  /// Distance from the origin to the arc.
  ///
  /// Set so the origin sits above the top of the screen: the notes should look
  /// like they come from somewhere beyond it, not from a point inside the
  /// picture.
  double get hitRadius => hitLineY * 1.45;

  /// The point every note flies out of.
  Offset get origin => Offset(size.width / 2, hitLineY - hitRadius);

  /// Half the angle of the fan, in radians.
  ///
  /// Capped, because the arc sags by roughly half the width times the tangent
  /// of half this angle: let it open too far on a wide, short screen and the
  /// middle of the arc drops most of the way down the picture.
  static const double maxSpreadAngle = 30 * math.pi / 180;

  double get spreadAngle => math.min(
      maxSpreadAngle, math.atan((size.width * spreadFraction / 2) / hitRadius));

  /// The angle of a note at [across] — 0 the lowest pitch in the song, 1 the
  /// highest.
  double angleAt(double across) =>
      lerpDouble(-spreadAngle, spreadAngle, across.clamp(0.0, 1.0))!;

  /// Where a note at [across] sits when it is [progress] of the way out, 1
  /// being the arc.
  Offset positionAtPosition(double across, double progress) {
    final angle = angleAt(across);
    final radius = hitRadius * progress;
    return origin + Offset(math.sin(angle) * radius, math.cos(angle) * radius);
  }

  /// Horizontal position of anything at [across], for laying out beams.
  double xAtPosition(double across, double progress) =>
      positionAtPosition(across, progress).dx;

  /// The centre of [beam] treated as a position across the fan.
  double acrossOfBeam(int beam) =>
      beamCount <= 1 ? 0.5 : (beam + 0.5) / beamCount;

  Offset positionAt(int beam, double progress) =>
      positionAtPosition(acrossOfBeam(beam), progress);

  double xAt(int beam, double progress) => positionAt(beam, progress).dx;

  /// Vertical position on the centre line, kept for the arc and for tails.
  double yAt(double progress) => origin.dy + hitRadius * progress;

  /// How far apart notes are along the arc, if the fan were divided evenly.
  double get beamSpacing => size.width * spreadFraction / beamCount;

  double beamWidthAt(double progress) => beamSpacing * progress.clamp(0.2, 1.4);

  /// Notes swell as they approach, which reads as coming closer — then shrink
  /// once past the arc, so a note that has had its moment stops looking like
  /// one still waiting to be played.
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
  /// view that looks [window] beats ahead. 1 means it is on the arc.
  static double progressFor(double beatsAway, double window) =>
      1 - beatsAway / window;
}

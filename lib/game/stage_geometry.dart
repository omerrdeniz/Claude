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
    this.hitLineFraction = 0.68,
  }) : assert(hitLineFraction > 0 && hitLineFraction < 1);

  final Size size;

  /// Height of the hit line, as a fraction of the screen. Two thirds down
  /// leaves the approach visible while keeping the line clear of the thumbs.
  final double hitLineFraction;

  double get hitLineY => size.height * hitLineFraction;

  double yAt(double progress) => hitLineY * progress;

  /// Where a note sits horizontally. [across] is already a screen fraction,
  /// placed by the chart within whichever hand's zone the note belongs to.
  double xAtPosition(double across, [double progress = 1]) =>
      size.width * across.clamp(0.0, 1.0);

  Offset positionAtPosition(double across, double progress) =>
      Offset(xAtPosition(across), yAt(progress));

  /// How big a note is drawn. The same wherever it is on its way down.
  ///
  /// Notes used to swell as they approached and shrink once past the line.
  /// It read as depth, but a note changing size while it travels is one more
  /// thing moving in a picture whose whole job is to say *when* — and the
  /// player said as much. Distance is carried by fading instead, which the
  /// eye reads without the shape moving under it.
  ///
  /// Bounded by both dimensions: a wide, short screen has room across but not
  /// down, and notes sized only by width would collide as they travel. Small
  /// enough, too, that three of them fit side by side in one hand's zone,
  /// which is what a triad needs.
  double get noteRadius =>
      (size.width * 0.055).clamp(9.0, 26.0).clamp(9.0, size.height * 0.048);

  /// Progress of a tap that is [beatsAway] beats from being played, given a
  /// view that looks [window] beats ahead. 1 means it is on the line.
  static double progressFor(double beatsAway, double window) =>
      1 - beatsAway / window;

  /// Opens out the notes of a chord so they can be told apart.
  ///
  /// Where a note sits comes from its pitch, and a close chord — a third, a
  /// triad — puts its notes within a few percent of the screen of each other.
  /// Drawn at that spacing they overlapped into one smudge and the player
  /// could not see how many fingers the moment wanted.
  ///
  /// Only the minimum is enforced. A chord already spread out — an octave, a
  /// tenth — is left exactly where its pitches put it, so the picture still
  /// says which note is higher and by how much. Order is never changed, and
  /// nothing is pushed out of [zoneStart]..[zoneEnd], which is the hand's own
  /// half of the screen.
  ///
  /// [places] must be sorted. Returns positions in the same order.
  static List<double> spreadChord(
    List<double> places, {
    required double minGap,
    required double zoneStart,
    required double zoneEnd,
  }) {
    if (places.length < 2) return List.of(places);
    final out = List.of(places);

    for (var i = 1; i < out.length; i++) {
      final least = out[i - 1] + minGap;
      if (out[i] < least) out[i] = least;
    }

    // Pushing right may have run the top note out of the hand's half; bring
    // the whole chord back rather than let one note stray into the other's.
    final overflow = out.last - zoneEnd;
    if (overflow > 0) {
      for (var i = 0; i < out.length; i++) {
        out[i] -= overflow;
      }
    }

    if (out.first < zoneStart) {
      // More notes than the zone can hold apart. Share it out evenly: some
      // overlap is then unavoidable, and even overlap reads better than a
      // pile at one end.
      final step = (zoneEnd - zoneStart) / (out.length - 1);
      for (var i = 0; i < out.length; i++) {
        out[i] = zoneStart + i * step;
      }
    }
    return out;
  }

  /// The top of a held note's bar, or null when there is nothing worth
  /// drawing.
  ///
  /// The bar stops short of where the note actually ends, by enough to clear
  /// whatever is struck next. The note itself lasts exactly as long as it is
  /// written — that is the sound — but drawn end to end the bars ran into the
  /// note above them and a hand full of held notes read as one long ladder.
  /// This is a gap in the picture only.
  ///
  /// [headY] is the bottom of the bar, [tailY] the top it would reach without
  /// the clearance; both grow downwards, so the tail is the smaller number.
  static double? holdBarTop(double headY, double tailY, double radius) {
    if (tailY >= headY) return null;
    final clearance = radius * holdBarClearance;
    final top = tailY + clearance > headY ? headY : tailY + clearance;
    // Shorter than the bar is wide would be a stub, not a bar.
    return headY - top < radius * holdBarWidth ? null : top;
  }

  /// How much room the bar leaves for the next note, in note radii.
  static const double holdBarClearance = 1.6;

  /// Half the bar's thickness, in note radii.
  static const double holdBarWidth = 0.72;

  /// Where a note's head is drawn, given how far along it is.
  ///
  /// An ordinary note keeps going and leaves. A held one stops at the line
  /// and stays there for as long as the finger is meant to be down, its bar
  /// shortening behind it as the end of the note catches up. Carrying on past
  /// the line would say the note was over while it was still being asked for.
  static double headProgressFor(double progress, {required bool isHold}) =>
      isHold && progress > 1 ? 1.0 : progress;
}

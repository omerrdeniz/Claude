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
  /// Only the minimum is enforced, and it is enforced by **stretching the
  /// whole chord**, not by pushing notes apart one at a time. The difference
  /// is the point: a hand's zone is about three notes wide, so almost every
  /// interval used to be flattened to the same least gap and a fifth looked
  /// like a second. Scaling about the middle keeps the ratios — in the
  /// Gnossienne's opening C4-F4-C5 the two gaps stay five to seven — and a
  /// chord already spread out is left exactly where its pitches put it.
  ///
  /// Order is never changed, and nothing is pushed out of
  /// [zoneStart]..[zoneEnd], which is the hand's own half of the screen.
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

    // Stretch the whole chord about its middle, by whatever the closest pair
    // needs, so every gap grows by the same factor and the chord keeps its
    // own shape. Pushing each note out to a fixed least gap instead — which
    // is what this did — made every interval the same width on screen: a
    // third and a fifth both came out at the minimum, and the player saw it
    // ("iki do arasında baya mesafe var ama 3 top da yan yana duruyor").
    var tightest = double.infinity;
    for (var i = 1; i < out.length; i++) {
      final gap = out[i] - out[i - 1];
      if (gap < tightest) tightest = gap;
    }
    if (tightest > 0 && tightest < minGap) {
      final stretch = minGap / tightest;
      final middle = (out.first + out.last) / 2;
      for (var i = 0; i < out.length; i++) {
        out[i] = middle + (out[i] - middle) * stretch;
      }
    } else if (tightest <= 0) {
      // Two notes in the same place is not a chord with proportions to keep.
      for (var i = 1; i < out.length; i++) {
        final least = out[i - 1] + minGap;
        if (out[i] < least) out[i] = least;
      }
    }

    // Stretching may have run the chord out of the hand's half at either end;
    // slide the whole of it back rather than let one note stray into the
    // other hand's, and rather than reshape it — a chord that fits keeps its
    // proportions wherever it has to sit.
    final over = out.last - zoneEnd;
    if (over > 0) {
      for (var i = 0; i < out.length; i++) {
        out[i] -= over;
      }
    }
    final under = zoneStart - out.first;
    if (under > 0) {
      for (var i = 0; i < out.length; i++) {
        out[i] += under;
      }
    }

    if (out.last > zoneEnd) {
      // Only now is it really too wide: more notes than the zone can hold
      // apart. Share it out evenly — some overlap is then unavoidable, and
      // even overlap reads better than a pile at one end.
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
    return headY - top < radius * holdBarLeast ? null : top;
  }

  /// Whether a tail reaching [length] pixels behind its head is worth drawing
  /// as a hold at all.
  ///
  /// Asked of the tail at its longest — before the head reaches the line,
  /// where the gap between head and tail is the whole of it. Under this a
  /// touch is drawn as an ordinary note: it flows past the line and leaves,
  /// with no bar and no pause.
  ///
  /// Sounding long and *being drawn* long are not the same thing, and this is
  /// the second. A note's bar is drawn only as far as the next thing its hand
  /// is asked for (see [Tap.drawnEndBeat]), so a note that rings for two
  /// seconds under a hand that is wanted again in a quarter of one has a tail
  /// a quarter of a second long — and drawn as a hold it was a lump under the
  /// note saying "stay", for a stay too short to make. The player found these
  /// in Satie's first Gnossienne. The sound is untouched: it still rings its
  /// written length, and a hand forced off it still keeps it (see
  /// [Tap.sustains]).
  static bool holdReadsAsBar(double length, double radius) =>
      length >= (holdBarClearance + holdBarLeast) * radius;

  /// How much room the bar leaves for the next note, in note radii.
  static const double holdBarClearance = 1.6;

  /// Half the bar's thickness, in note radii.
  static const double holdBarWidth = 0.72;

  /// The shortest bar worth drawing, in note radii.
  ///
  /// Twice the bar's own thickness. It used to be half of it — a bar wider
  /// than it was long, which is a lump behind the note rather than a line
  /// leading away from it, and reads as neither a hold nor a tap.
  static const double holdBarLeast = holdBarWidth * 4;

  /// Where a note's head is drawn, given how far along it is.
  ///
  /// An ordinary note keeps going and leaves. A held one stops at the line
  /// and stays there for as long as the finger is meant to be down, its bar
  /// shortening behind it as the end of the note catches up. Carrying on past
  /// the line would say the note was over while it was still being asked for.
  static double headProgressFor(double progress, {required bool isHold}) =>
      isHold && progress > 1 ? 1.0 : progress;
}

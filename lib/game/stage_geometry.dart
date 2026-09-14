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
  const StageGeometry({required this.size, this.hitLineFraction = 0.68})
    : assert(hitLineFraction > 0 && hitLineFraction < 1);

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

  /// How wide a note is drawn.
  ///
  /// Narrower than it is tall, and narrower than the disc it replaced. Where
  /// a note sits comes from its pitch, so the width of a note is the width of
  /// the smallest interval the screen can show apart — and a disc as wide as
  /// it was tall meant a hand's zone held three notes and no more. Measured
  /// over the library, ninety-three of every hundred gaps inside a chord were
  /// being stretched to clear it; at this width, a quarter of them are drawn
  /// at the distance the music actually has.
  double get noteWidth => noteRadius * 2 * _noteWidthShare;

  /// As a share of what the disc's width was, so the number means what it
  /// says: a note is a little over half as wide as the note it replaced.
  static const double _noteWidthShare = 0.6;

  /// The least a chord's notes may be apart, in pixels: a note's width and
  /// daylight enough to read as two things.
  double get noteGap => noteWidth + noteRadius * 0.3;

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

  /// The top of a held note's bar, or null when the note has run out.
  ///
  /// The bar stops short of where the note actually ends, by enough to clear
  /// whatever is struck next. The note itself lasts exactly as long as it is
  /// written — that is the sound — but drawn end to end the bars ran into the
  /// note above them and a hand full of held notes read as one long ladder.
  /// This is a gap in the picture only.
  ///
  /// **The gap gives way as the bar runs out.** A fixed one is the difference
  /// between a gap and a bar that ends early, and the last of a held note is
  /// exactly where the player is looking: the bar is what says *keep your
  /// finger down*, so it has to reach the moment it stops being true. Near
  /// the end the clearance is never more than half of what is left, so the
  /// bar shrinks to nothing at the note's own end rather than stopping short
  /// of it.
  ///
  /// There is no shortest bar here. There used to be — a bar under two note
  /// widths long was dropped — and on a note being held that is a third of a
  /// second of the hold with no bar for it: the tail vanished while it was
  /// still sixty pixels long and the player was still holding, which is
  /// exactly how it was reported. Whether a touch is worth drawing as a hold
  /// at all is [holdReadsAsBar], asked once of the whole tail; asking it
  /// again of the stub that is left says something else entirely.
  ///
  /// [headY] is the bottom of the bar, [tailY] the top it would reach without
  /// the clearance; both grow downwards, so the tail is the smaller number.
  /// [clearance] is how much room to leave, in pixels — the painter works it
  /// out, because it is the larger of a distance and a length of time and
  /// only the painter knows how those convert.
  static double? holdBarTop(double headY, double tailY, double clearance) {
    if (tailY >= headY) return null;
    final span = headY - tailY;
    return tailY + (span < clearance * 2 ? span / 2 : clearance);
  }

  /// How long a hand needs to come off one note and land on the next, in
  /// seconds.
  ///
  /// The bar says *stay here*, and it used to say it right up to the moment
  /// the next note was due — which is an instruction no hand can follow: the
  /// finger has to leave early enough to arrive. The player asked for the
  /// gap: *"parmağı kaldır ve tekrar bas için bir süre geçiyor."*
  ///
  /// In seconds and not in note radii, because it is a fact about the hand.
  /// [holdBarClearance] stays as a floor underneath it so the bar never runs
  /// into the next note on a screen where this comes to very little. The
  /// sound is untouched: the note rings its written length either way.
  static const double holdBarLiftSeconds = 0.16;

  /// Whether a tail lasting [seconds] is worth drawing as a hold at all.
  ///
  /// Under this a touch is drawn as an ordinary note: it flows past the line
  /// and leaves, with no bar and no pause.
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
  ///
  /// **In seconds, and that took two goes to get right.** It was in pixels,
  /// on the reasoning that a note takes a fixed 1.9 seconds to come down the
  /// screen, so a length on the screen *is* a length of time. That is true of
  /// one screen. The note is sized from the width and the line sits at 68% of
  /// the height, so the same rule came to 0.30 seconds at 390×844 and 0.34 in
  /// a browser with its toolbars showing — and the player, told the cut was
  /// at three tenths, was looking at a phone where it was not. A stay the
  /// hand has no time to make is a fact about the music and the player's
  /// hand. It has nothing to do with how tall the window is.
  static bool holdReadsAsBar(double seconds) => seconds >= holdLeastSeconds;

  /// The shortest stay worth asking for, in seconds.
  ///
  /// Four tenths, settled by looking at the whole library rather than at one
  /// piece. Every tail in it, sorted: a crowd under a third of a second, then
  /// fourteen at exactly 0.300 — all of them Satie's — then nothing at all
  /// until 0.35, then twenty between 0.35 and 0.45, then the rest.
  ///
  /// Those fourteen were tried at three tenths, at the player's own request,
  /// and were the ones that came back as *"bu kuyruklar çok kısa"*: on the
  /// screen the game is actually played on they draw a bar barely longer than
  /// the note is tall, which is a lump behind the note rather than a line
  /// leading away from it. Four tenths costs nothing beyond them — the band
  /// from 0.35 to 0.40 is empty — and takes the shortest bar drawn from a
  /// tenth over one note tall to two thirds over.
  ///
  /// **This is a drawing decision and only a drawing decision.** A touch
  /// under it keeps [Tap.isHold] and [Tap.sustains], sounds for exactly as
  /// long as it is written, and goes on ringing when the hand leaves it —
  /// which it must, because a tail is short only where the same hand is
  /// wanted elsewhere. `test/stage_geometry_test.dart` holds that over the
  /// whole library.
  static const double holdLeastSeconds = 0.4;

  /// The least room the bar leaves for the next note, in note radii — a
  /// floor under [holdBarLiftSeconds], which is usually the larger of the
  /// two.
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

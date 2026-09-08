/// How well a tap landed.
enum Verdict { perfect, great, good, miss }

extension VerdictLabel on Verdict {
  String get label => switch (this) {
        Verdict.perfect => 'Mükemmel',
        Verdict.great => 'İyi',
        Verdict.good => 'Tamam',
        Verdict.miss => 'Kaçtı',
      };

  /// Points before the combo multiplier.
  int get points => switch (this) {
        Verdict.perfect => 100,
        Verdict.great => 70,
        Verdict.good => 40,
        Verdict.miss => 0,
      };
}

/// Turns timing error into a verdict.
///
/// The windows are generous by rhythm-game standards, and deliberately so.
/// This game never plays a wrong note — the player only controls *when* — so
/// the punishment for being slightly off should be a smaller number, not a
/// broken performance. A tap that finds nothing at all feels broken rather
/// than strict, which is worth more than the precision it costs.
class Judge {
  const Judge({
    this.perfectMs = 55,
    this.greatMs = 115,
    this.goodMs = 210,
  })  : assert(perfectMs < greatMs),
        assert(greatMs < goodMs);

  final double perfectMs;
  final double greatMs;
  final double goodMs;

  /// Past this, a tap is not treated as belonging to the note at all.
  double get windowMs => goodMs;

  Verdict verdictFor(double errorMs) {
    final error = errorMs.abs();
    if (error <= perfectMs) return Verdict.perfect;
    if (error <= greatMs) return Verdict.great;
    if (error <= goodMs) return Verdict.good;
    return Verdict.miss;
  }

  /// How close the tap was, 1 for dead on and 0 at the edge of the window.
  /// Used to shape the sound, so a tight performance also sounds firmer.
  double quality(double errorMs) =>
      (1 - errorMs.abs() / goodMs).clamp(0.0, 1.0);
}

/// Running score for one performance.
class Scoreboard {
  int score = 0;
  int combo = 0;
  int bestCombo = 0;

  final Map<Verdict, int> counts = {for (final v in Verdict.values) v: 0};

  /// Missing breaks the streak; anything else extends it.
  ///
  /// The multiplier is what makes a long clean run worth chasing — it is the
  /// same reason the original's players talk about streaks rather than scores.
  void register(Verdict verdict) {
    counts[verdict] = counts[verdict]! + 1;
    if (verdict == Verdict.miss) {
      combo = 0;
      return;
    }
    combo++;
    if (combo > bestCombo) bestCombo = combo;
    score += verdict.points * multiplier;
  }

  /// Grows in steps rather than continuously, so the player can feel it
  /// happen rather than watch a number creep.
  int get multiplier {
    if (combo >= 50) return 4;
    if (combo >= 25) return 3;
    if (combo >= 10) return 2;
    return 1;
  }

  int get notesPlayed => counts.values.reduce((a, b) => a + b);

  /// Share of the available points earned, ignoring the multiplier.
  double get accuracy {
    if (notesPlayed == 0) return 0;
    final earned = counts.entries
        .map((e) => e.key.points * e.value)
        .reduce((a, b) => a + b);
    return earned / (notesPlayed * Verdict.perfect.points);
  }

  String get grade {
    if (notesPlayed == 0) return '-';
    final a = accuracy;
    if (a >= 0.95) return 'S';
    if (a >= 0.85) return 'A';
    if (a >= 0.70) return 'B';
    if (a >= 0.50) return 'C';
    return 'D';
  }

  void reset() {
    score = 0;
    combo = 0;
    bestCombo = 0;
    for (final v in Verdict.values) {
      counts[v] = 0;
    }
  }
}

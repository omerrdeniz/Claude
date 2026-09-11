import 'chart.dart';
import 'judgement.dart';

/// Everything the player chooses on the song list, as one value.
///
/// One object rather than six parameters, because each of them used to be
/// carried by hand through `SongListScreen` → `SongTile` → `PlayScreen`,
/// with a default at every stop. Forgetting one did not fail: it quietly
/// fell back to the default, and the game ignored what the player had
/// chosen. That happened twice, and the guard against it was a test.
///
/// Now the defaults live here and nowhere else, `PlayScreen` requires the
/// whole object, and a seventh setting is added in this file alone.
/// Forgetting to carry one is no longer possible rather than merely tested
/// for.
class PlaySettings {
  const PlaySettings({
    this.difficulty = Difficulty.normal,
    this.speed = 1.0,
    this.tolerance = TimingTolerance.wide,
    this.quantize = true,
    this.fillMissed = false,
    this.latencyOffsetMs = 0,
  });

  final Difficulty difficulty;

  /// Fraction of the written tempo to play at.
  ///
  /// Full speed by default: the songs are written at the tempo they are
  /// actually played at and should sound that way on the first press. Slowing
  /// down is a practice tool, one tap away, for the pieces that outrun a hand
  /// — which at their real tempo, Chopin's and Beethoven's both do.
  final double speed;

  /// How forgiving the judging is.
  ///
  /// Forgiving by default: the game should flatter a beginner before it tests
  /// one.
  final TimingTolerance tolerance;

  /// Whether notes sound on their beat rather than under the finger.
  ///
  /// On by default, for the same reason as [tolerance].
  final bool quantize;

  /// Whether a note nobody plays sounds anyway, quietly.
  ///
  /// Off by default. It closes the holes a missed note leaves, but the price
  /// is that a player who stops playing hears the song play itself — and
  /// "nothing plays itself" is this game's oldest rule. Offered, not assumed.
  final bool fillMissed;

  /// The player's own calibration, in milliseconds, on top of what the device
  /// reports about its own audio delay.
  ///
  /// Positive means their taps are treated as that much earlier — which is
  /// what to reach for when everything registers as late.
  ///
  /// It has to be adjustable because no device tells the truth about this.
  /// A browser reports what it knows about; it cannot know about Bluetooth
  /// headphones, and it says nothing about the player's own hand, which
  /// reliably arrives a little after the eye says to move.
  final double latencyOffsetMs;

  PlaySettings copyWith({
    Difficulty? difficulty,
    double? speed,
    TimingTolerance? tolerance,
    bool? quantize,
    bool? fillMissed,
    double? latencyOffsetMs,
  }) =>
      PlaySettings(
        difficulty: difficulty ?? this.difficulty,
        speed: speed ?? this.speed,
        tolerance: tolerance ?? this.tolerance,
        quantize: quantize ?? this.quantize,
        fillMissed: fillMissed ?? this.fillMissed,
        latencyOffsetMs: latencyOffsetMs ?? this.latencyOffsetMs,
      );
}

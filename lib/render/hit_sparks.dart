/// What a hit leaves behind on the line.
///
/// The game's whole promise is that touching the screen makes music, and for
/// a long time the only sign that it had worked was one side of the screen
/// glowing faintly and a word appearing. Landing a note and landing fifty in
/// a row looked the same. This is the difference.
///
/// Deliberately plain data with a clock: no Flutter, no painting, no random
/// numbers. What it looks like is the painter's business, and a spark that
/// behaves the same every time is one that can be tested.
class Spark {
  Spark({
    required this.across,
    required this.voices,
    required this.quality,
  });

  /// Where on the hit line it happened, 0 at the left edge and 1 at the right.
  final double across;

  /// How many notes sounded together, which is what colours it.
  final int voices;

  /// How well timed the touch was, 1 for dead on and 0 at the edge of the
  /// window. A clean hit throws more light than a scraped one.
  final double quality;

  /// How far through its life it is, 0 at the moment of the hit and 1 when
  /// it is gone.
  double age = 0;

  bool get spent => age >= 1;
}

/// The sparks currently on screen.
///
/// Capped, and the oldest go first: a dense passage can throw a dozen a
/// second, and an uncapped list is a way to make the game stutter exactly
/// where it should feel best.
class SparkField {
  SparkField({this.lifeMs = 260, this.limit = 16});

  /// How long a spark lasts.
  final double lifeMs;

  /// The most that may be alive at once.
  ///
  /// Short-lived and few. The first version lasted 420 ms and allowed
  /// twenty-four, and in a dense passage the line was never not covered in
  /// them — which reads as noise rather than as anything the player did.
  final int limit;

  final List<Spark> _sparks = [];

  List<Spark> get sparks => List.unmodifiable(_sparks);
  bool get isEmpty => _sparks.isEmpty;

  void add(Spark spark) {
    _sparks.add(spark);
    if (_sparks.length > limit) _sparks.removeRange(0, _sparks.length - limit);
  }

  /// Age everything by [elapsedMs] and drop what has burned out.
  void advance(double elapsedMs) {
    if (_sparks.isEmpty) return;
    final step = elapsedMs / lifeMs;
    for (final spark in _sparks) {
      spark.age += step;
    }
    _sparks.removeWhere((spark) => spark.spent);
  }

  void clear() => _sparks.clear();
}

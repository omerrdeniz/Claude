/// Works out how far behind the player's ear is, by having them tap along.
///
/// Everything between asking for a sound and a finger coming back down is in
/// here: the audio path, whatever the headphones add, and the player's own
/// reaction, which is a real and personal number. No device can report the
/// last two, which is why this is measured rather than looked up.
///
/// Deliberately free of Flutter and of any clock. It is handed the times a
/// click actually sounded and the times a finger actually landed, both in
/// milliseconds on the same arbitrary scale, and does the arithmetic. That
/// makes the part worth getting right testable without an audio device.
class LatencyTally {
  LatencyTally({
    this.windowMs = 300,
    this.minimumTaps = 8,
    this.wantedTaps = 16,
  })  : assert(windowMs > 0),
        assert(minimumTaps > 0),
        assert(wantedTaps >= minimumTaps);

  /// How far from a click a tap may be and still be counted as aimed at it.
  ///
  /// Wide, because a badly calibrated device is exactly the case being
  /// measured — but under half the gap between clicks, or a tap could be
  /// claimed by the wrong one.
  final double windowMs;

  /// Below this there is not enough to take a middle of.
  final int minimumTaps;

  /// Enough to stop asking for more.
  final int wantedTaps;

  final List<double> _clicks = [];
  final Set<int> _answered = {};
  final List<double> _errors = [];

  /// A click sounded. Pass the moment it actually went out, not the moment it
  /// was meant to: the difference is a frame or so of jitter that would
  /// otherwise land in the measurement.
  void addClick(double atMs) => _clicks.add(atMs);

  /// A finger landed. Returns whether it counted towards the measurement.
  ///
  /// A tap with no click near it is ignored rather than counted as a wild
  /// error — someone finding the rhythm taps early, and those attempts should
  /// not drag the answer around.
  bool addTap(double atMs) {
    if (isDone) return false;

    var best = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _clicks.length; i++) {
      if (_answered.contains(i)) continue; // one tap per click
      final distance = (atMs - _clicks[i]).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }

    if (best == -1 || bestDistance > windowMs) return false;
    _answered.add(best);
    _errors.add(atMs - _clicks[best]);
    return true;
  }

  int get taps => _errors.length;
  bool get isDone => _errors.length >= wantedTaps;
  bool get hasEnough => _errors.length >= minimumTaps;

  /// How far behind the ear is, in milliseconds, or null while there is not
  /// yet enough to say.
  ///
  /// The middle value, not the average. One tap missed and caught late would
  /// drag an average by tens of milliseconds; the middle does not notice it.
  double? get measuredMs {
    if (!hasEnough) return null;
    final sorted = [..._errors]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// How much the taps disagree with each other: the middle of how far each
  /// one sits from the middle.
  ///
  /// Shown to the player because a tight spread means the number is worth
  /// keeping and a loose one means they were not really in time.
  double? get spreadMs {
    final centre = measuredMs;
    if (centre == null) return null;
    final distances = [for (final e in _errors) (e - centre).abs()]..sort();
    return distances[distances.length ~/ 2];
  }

  /// What to store as the manual calibration, given what the device already
  /// admits to.
  ///
  /// The game adds the device's own figure by itself, so only the part it
  /// does not know about belongs here — otherwise the delay would be counted
  /// twice.
  double? offsetAgainst(double deviceLatencyMs) {
    final measured = measuredMs;
    return measured == null ? null : measured - deviceLatencyMs;
  }

  void reset() {
    _clicks.clear();
    _answered.clear();
    _errors.clear();
  }
}

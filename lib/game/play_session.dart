import '../audio/piano_audio.dart';
import '../music/note.dart';
import 'chart.dart';
import 'judgement.dart';

/// The outcome of one tap, for the screen to show.
class TapOutcome {
  const TapOutcome({
    required this.verdict,
    required this.beam,
    required this.errorMs,
    required this.notes,
    this.scored = true,
  });

  final Verdict verdict;
  final int beam;

  /// How early (negative) or late (positive) the tap was.
  final double errorMs;

  final List<Note> notes;

  /// False for a tap that found a note but was too far off to count. It costs
  /// nothing; it exists so the player is told *why* nothing sounded instead of
  /// being met with silence.
  final bool scored;
}

/// Runs one performance: keeps the clock, matches taps to notes, plays the
/// sound, and keeps score.
///
/// The rule that shapes everything here is the one borrowed from the game this
/// takes after — a tap always plays the *right* note. The player cannot play a
/// wrong pitch, only a wrong moment. That is what lets someone who has never
/// touched a piano sound like they can play, and it means this class owns the
/// pitch decision entirely.
class PlaySession {
  PlaySession({
    required Chart chart,
    required this.audio,
    this.judge = const Judge(),
    this.latencyOffsetMs = 0,
    this.approachSeconds = 1.9,
    this.speed = 1.0,
  })  : assert(speed > 0),
        _chart = chart;

  Chart _chart;
  Chart get chart => _chart;
  final PianoAudio audio;
  final Judge judge;

  /// Manual calibration for the delay between a tap and the sound reaching the
  /// ear. A positive value treats the player's taps as that much earlier.
  ///
  /// The device's own reported latency is added to this automatically; this is
  /// only for what the device does not know about — the player's own hand, and
  /// whatever the headphones add.
  final double latencyOffsetMs;

  /// Everything the player's ear is behind by: what the audio path reports,
  /// plus the manual calibration.
  double get _totalLatencyMs => latencyOffsetMs + audio.latencyMs;

  /// How long a note takes to travel down the screen.
  final double approachSeconds;

  /// Fraction of the written tempo to play at.
  ///
  /// Slowing a piece down is how anyone learns one, and it is the honest fix
  /// for notes arriving faster than a beginner's hand: the music stays itself,
  /// there is just more room between its notes.
  final double speed;

  final Scoreboard scoreboard = Scoreboard();

  /// Notes already played or gone by, keyed by when and what they are.
  ///
  /// Held per note rather than per tap on purpose: how many taps a passage
  /// breaks into depends on how many beams the screen has, so turning the
  /// device sideways re-groups them. A note, though, is the same note however
  /// it is grouped — which is what lets the layout change mid-song without
  /// losing track of what has already been played.
  final Set<(double, int)> _resolved = {};

  static (double, int) _keyOf(Note note) => (note.beat, note.midi);

  bool _isPending(Tap tap) =>
      tap.notes.any((note) => !_resolved.contains(_keyOf(note)));

  void _resolve(Tap tap) {
    for (final note in tap.notes) {
      _resolved.add(_keyOf(note));
    }
  }

  /// Notes that have just gone by unplayed, kept only long enough to explain a
  /// late tap. Without this a tap that arrives moments after the note would
  /// find nothing at all and read as a dead control rather than a late hand.
  final List<({double beat, int beam})> _justMissed = [];

  /// The song clock starts before the first note, so it arrives travelling.
  late double _beat = -leadInBeats;
  late double _lastBeat = _beat;
  bool _running = false;

  /// The screen hands over its own running clock, which never stops. These
  /// keep song time separate from wall time, so pausing costs the performance
  /// nothing and restarting does not inherit a clock that is already minutes
  /// old.
  Duration _origin = Duration.zero;
  Duration _wallClock = Duration.zero;
  Duration? _pausedAt;

  double get beat => _beat;
  bool get isRunning => _running;
  double get beatsPerSecond => chart.song.bpm / 60 * speed;

  /// Empty stage before the first note, so it arrives travelling rather than
  /// appearing on the line.
  double get leadInBeats => approachSeconds * beatsPerSecond;

  double get windowInBeats => approachSeconds * beatsPerSecond;

  bool get isFinished => _beat > chart.lengthInBeats + 2;

  /// Begin, or pick up from a pause without losing the time spent paused.
  void start() {
    if (_running) return;
    if (_pausedAt != null) {
      _origin += _wallClock - _pausedAt!;
      _pausedAt = null;
    }
    _running = true;
  }

  void pause() {
    if (!_running) return;
    _running = false;
    _pausedAt = _wallClock;
  }

  /// Advance to [elapsed] since the performance began.
  ///
  /// Everything time-driven happens here — missed notes, and the accompaniment
  /// the game plays on the player's behalf — so the screen only has to hand
  /// over the clock.
  void update(Duration elapsed) {
    // Recorded even while paused: it is how much the paused clock has to be
    // discounted by when play resumes.
    _wallClock = elapsed;
    if (!_running) return;
    _lastBeat = _beat;
    _beat = (elapsed - _origin).inMicroseconds / 1e6 * beatsPerSecond -
        leadInBeats;

    _playAccompaniment();
    _expireMissedTaps();
    _releaseFinishedNotes();
  }

  void _playAccompaniment() {
    for (final note in chart.accompanimentBetween(_lastBeat, _beat)) {
      audio.noteOn(note.midi, velocity: note.velocity);
      _scheduleRelease(note.midi, note.endBeat);
    }
  }

  /// A note the player never tapped is a miss once it is too late to hit.
  void _expireMissedTaps() {
    final deadline = _beat - judge.windowMs / 1000 * beatsPerSecond;
    for (final tap in chart.taps) {
      if (tap.beat >= deadline) break; // taps are in time order
      if (!_isPending(tap)) continue;
      _resolve(tap);
      _justMissed.add((beat: tap.beat, beam: tap.beam));
      scoreboard.register(Verdict.miss);
      onMiss?.call(tap);
    }
    // Forget the ones too old to be what any tap was aiming at.
    final forgetBefore = _beat - _reachBeats;
    _justMissed.removeWhere((m) => m.beat < forgetBefore);
  }

  /// Notes are released by the clock rather than by lifting a finger: the
  /// player is tapping a moment, not holding a key, so the song's own written
  /// lengths decide how long each note rings.
  final Map<int, double> _releaseAt = {};

  void _scheduleRelease(int midi, double atBeat) => _releaseAt[midi] = atBeat;

  void _releaseFinishedNotes() {
    _releaseAt.removeWhere((midi, releaseBeat) {
      if (_beat < releaseBeat) return false;
      audio.noteOff(midi);
      return true;
    });
  }

  /// The player tapped [beam]. Returns what happened, or null if there was no
  /// note there to play.
  ///
  /// A tap with nothing under it is ignored rather than punished: this game
  /// invites people who cannot play, and charging them for a stray finger
  /// would teach exactly the wrong lesson.
  TapOutcome? tap(int beam) {
    if (!_running) return null;

    final index = _nearestPending(beam);
    if (index == null) {
      final near = _nearMiss(beam);
      if (near == null) return null;
      return TapOutcome(
        verdict: Verdict.miss,
        beam: beam,
        errorMs: near,
        notes: const [],
        scored: false,
      );
    }

    final tapTarget = chart.taps[index];
    final errorMs =
        (_beat - tapTarget.beat) / beatsPerSecond * 1000 - _totalLatencyMs;
    final verdict = judge.verdictFor(errorMs);
    if (verdict == Verdict.miss) return null; // too far away to belong to it

    _resolve(tapTarget);
    scoreboard.register(verdict);

    // Tighter timing is played a little firmer, so a clean run sounds clean
    // as well as scoring well.
    final firmness = 0.85 + judge.quality(errorMs) * 0.3;
    for (final note in tapTarget.notes) {
      audio.noteOn(note.midi, velocity: (note.velocity * firmness).clamp(0.05, 1.0));
      _scheduleRelease(note.midi, tapTarget.beat + note.duration);
    }

    return TapOutcome(
      verdict: verdict,
      beam: beam,
      errorMs: errorMs,
      notes: tapTarget.notes,
    );
  }

  /// The pending tap this touch should count as.
  ///
  /// Timing decides it, not aim. A beam says what pitch a note is, and that is
  /// worth showing — but making the player also land on the right one turns a
  /// game about *when* into a game about hand-eye coordination, and a run of
  /// fast notes across four beams becomes a race the hand cannot win. So a tap
  /// anywhere takes the note that is due.
  ///
  /// Where several notes fall together — a chord — the tapped beam breaks the
  /// tie, so several fingers land on several notes instead of all taking the
  /// same one.
  int? _nearestPending(int beam) {
    final windowBeats = judge.windowMs / 1000 * beatsPerSecond;
    const simultaneous = 0.001;

    int? best;
    var bestDistance = double.infinity;
    var bestBeamGap = 1 << 20;

    for (var i = 0; i < chart.taps.length; i++) {
      final tap = chart.taps[i];
      if (tap.beat - _beat > windowBeats) break; // taps are in time order
      if (!_isPending(tap)) continue;

      final distance = (tap.beat - _beat).abs();
      if (distance > windowBeats) continue;

      final beamGap = (tap.beam - beam).abs();
      final closerInTime = distance < bestDistance - simultaneous;
      final sameMoment = (distance - bestDistance).abs() <= simultaneous;

      if (closerInTime || (sameMoment && beamGap < bestBeamGap)) {
        best = i;
        bestDistance = distance;
        bestBeamGap = beamGap;
      }
    }
    return best;
  }

  /// How far off a tap was from the nearest note it could plausibly have been
  /// aimed at, or null if there was nothing anywhere near.
  double? _nearMiss(int beam) {
    double? closest;
    void consider(double beat, int tapBeam) {
      final delta = beat - _beat;
      if (delta.abs() > _reachBeats) return;
      if (closest == null || delta.abs() < closest!.abs()) closest = delta;
    }

    // Notes still to come — the player was early.
    for (final tap in chart.taps) {
      if (tap.beat - _beat > _reachBeats) break;
      if (_isPending(tap)) consider(tap.beat, tap.beam);
    }
    // Notes just gone — the player was late.
    for (final missed in _justMissed) {
      consider(missed.beat, missed.beam);
    }

    return closest == null ? null : -closest! / beatsPerSecond * 1000;
  }

  /// How far a tap is allowed to be from a note and still be read as aimed at
  /// it — for explaining the miss, never for counting it.
  double get _reachBeats => 0.55 * beatsPerSecond;

  /// Lay the same performance out over a different number of beams.
  ///
  /// Rotating the device mid-song changes how many beams fit, and with them
  /// how the notes group into taps — a chord spread over six beams is not the
  /// same set of taps as over four. The music is unchanged, though, and since
  /// what has been played is tracked per note rather than per tap, the score,
  /// the streak and every already-played note survive the change.
  void rebindChart(Chart replacement) {
    assert(replacement.song.id == _chart.song.id,
        'a rebind must describe the same song');
    _chart = replacement;
  }

  /// Told when a note goes by unplayed, so the screen can react.
  void Function(Tap tap)? onMiss;

  /// Stop everything sounding — when leaving the screen, or restarting.
  void stop() {
    _running = false;
    _releaseAt.clear();
    _justMissed.clear();
    audio.engine.allNotesOff();
  }

  void restart() {
    stop();
    _origin = _wallClock;
    _pausedAt = null;
    _beat = -leadInBeats;
    _lastBeat = _beat;
    scoreboard.reset();
    _resolved.clear();
    _running = true;
  }
}

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
  });

  final Verdict verdict;
  final int beam;

  /// How early (negative) or late (positive) the tap was.
  final double errorMs;

  final List<Note> notes;
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
    required this.chart,
    required this.audio,
    this.judge = const Judge(),
    this.latencyOffsetMs = 0,
    this.approachSeconds = 1.9,
  }) : _pending = List.filled(chart.taps.length, true);

  final Chart chart;
  final PianoAudio audio;
  final Judge judge;

  /// Calibration for the delay between a tap and the sound reaching the ear.
  /// A positive value means the player's taps are treated as that much earlier.
  final double latencyOffsetMs;

  /// How long a note takes to travel down the screen.
  final double approachSeconds;

  final Scoreboard scoreboard = Scoreboard();

  /// Whether each tap in the chart is still waiting to be played.
  final List<bool> _pending;

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
  double get beatsPerSecond => chart.song.bpm / 60;

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
    for (var i = 0; i < chart.taps.length; i++) {
      if (!_pending[i]) continue;
      if (chart.taps[i].beat >= deadline) break; // taps are in time order
      _pending[i] = false;
      scoreboard.register(Verdict.miss);
      onMiss?.call(chart.taps[i]);
    }
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
    if (index == null) return null;

    final tapTarget = chart.taps[index];
    final errorMs =
        (_beat - tapTarget.beat) / beatsPerSecond * 1000 - latencyOffsetMs;
    final verdict = judge.verdictFor(errorMs);
    if (verdict == Verdict.miss) return null; // too far away to belong to it

    _pending[index] = false;
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

  /// The pending tap on [beam] closest to now, within the judging window.
  int? _nearestPending(int beam) {
    final windowBeats = judge.windowMs / 1000 * beatsPerSecond;
    int? best;
    var bestDistance = double.infinity;

    for (var i = 0; i < chart.taps.length; i++) {
      if (!_pending[i] || chart.taps[i].beam != beam) continue;
      final distance = (chart.taps[i].beat - _beat).abs();
      if (distance > windowBeats) {
        if (chart.taps[i].beat > _beat) break; // gone past the window ahead
        continue;
      }
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }

  /// Told when a note goes by unplayed, so the screen can react.
  void Function(Tap tap)? onMiss;

  /// Stop everything sounding — when leaving the screen, or restarting.
  void stop() {
    _running = false;
    _releaseAt.clear();
    audio.engine.allNotesOff();
  }

  void restart() {
    stop();
    _origin = _wallClock;
    _pausedAt = null;
    _beat = -leadInBeats;
    _lastBeat = _beat;
    scoreboard.reset();
    for (var i = 0; i < _pending.length; i++) {
      _pending[i] = true;
    }
    _running = true;
  }
}

import '../audio/piano_audio.dart';
import '../music/note.dart';
import 'chart.dart';
import 'judgement.dart';

/// The outcome of one tap, for the screen to show.
class TapOutcome {
  const TapOutcome({
    required this.verdict,
    required this.hand,
    required this.errorMs,
    required this.notes,
    this.scored = true,
    this.holdId,
    this.dragId,
  });

  final Verdict verdict;
  final Hand hand;

  /// Set when this touch began a note the finger is expected to keep down.
  /// Hand it back to [PlaySession.releaseHold] when the finger lifts.
  final int? holdId;

  /// Set when this touch landed on a run the finger can slide through. Hand
  /// it to [PlaySession.drag] as the finger moves, and to
  /// [PlaySession.endDrag] when it lifts.
  final int? dragId;

  /// How early (negative) or late (positive) the tap was.
  final double errorMs;

  final List<Note> notes;

  /// False for a tap that found a note but was too far off to count. It costs
  /// nothing; it exists so the player is told *why* nothing sounded instead of
  /// being met with silence.
  final bool scored;
}

/// A note being held down.
class _Hold {
  _Hold({required this.beat, required this.midis, required this.endBeat});

  /// Which moment in the song this is, so the screen can tell which drawn
  /// note the finger is on.
  final double beat;
  final List<int> midis;
  final double endBeat;
}

/// A finger sliding through a run.
class _Drag {
  _Drag({required this.runId, required this.index, required this.across});

  final int runId;

  /// The last note of the run that has been dealt with.
  int index;

  /// Where the finger was when this was last looked at.
  double across;

  /// How far it has moved since the last note sounded. Direction does not
  /// matter — a slide back the other way is still a slide.
  double travelled = 0;
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
    this.quantize = true,
    this.fillMissed = false,
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

  /// Whether a note sounds at the moment the song says, rather than the moment
  /// the finger landed.
  ///
  /// This is the difference between a game that reports your mistakes and one
  /// that makes you sound good. A tap that comes early waits for its beat; the
  /// score still says how close you were, but the music comes out in time. A
  /// late tap can only sound at once — there is no going back — so lateness is
  /// the one error that is still heard.
  final bool quantize;

  /// Whether a note nobody played sounds anyway, quietly.
  ///
  /// **Off by default, and that is a decision, not an oversight.**
  ///
  /// It was added because missing a note leaves a hole, and in Normal both
  /// hands belong to the player — two thirds of Chopin's nocturne is the left
  /// one, so answering only the melody left most of the piece silent. But
  /// turning it on has a cost the player put plainly: sit still and the game
  /// plays the song to you. Filling every hole and leaving every note to the
  /// player are the same dial from opposite ends; there is no setting that is
  /// both.
  ///
  /// So it is offered rather than assumed. It never softens the score: a
  /// filled note is still a miss.
  final bool fillMissed;

  /// Notes already sounded on the player's behalf.
  final Set<(double, int)> _filled = {};

  /// How long after its moment a note is given up on and filled in.
  ///
  /// The judging window is the wrong length for this: at its widest a note
  /// would arrive nearly four hundred milliseconds late, which in a piece
  /// whose eighths are four hundred and fifty apart is not a filled hole but
  /// a wrong note. The perfect window is the right length — anyone playing
  /// in time gets there first, and the fill only covers what they truly
  /// missed.
  double get _fillDelayBeats => judge.perfectMs / 1000 * beatsPerSecond;

  /// How loud a filled note is against a played one. Present, not competing.
  static const double _fillVelocity = 0.45;

  /// Notes tapped early, waiting for their moment.
  final List<({double beat, int midi, double velocity, double duration})>
      _waiting = [];

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
  final List<({double beat, Hand hand})> _justMissed = [];

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

  /// Song time as the player's hand meets it.
  ///
  /// Everything they hear is [_totalLatencyMs] behind the clock, so a finger
  /// that feels on the beat arrives that much after it. Matching a touch to a
  /// note, judging how close it was, and giving up on a note nobody played all
  /// have to agree on this.
  ///
  /// They did not. Only the judging compensated, so there was a band of taps
  /// as wide as the latency that got matched to a note and then judged too far
  /// from it to count — and a tap judged a miss returned nothing at all. The
  /// game answered a real touch with silence, which is exactly what a dead
  /// control feels like.
  double get _judgedBeat => _beat - _totalLatencyMs / 1000 * beatsPerSecond;

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
    _playWaitingNotes();
    _fillMissedNotes();
    _expireMissedTaps();
    _releaseFinishedNotes();
  }

  void _playAccompaniment() {
    for (final note in chart.accompanimentBetween(_lastBeat, _beat)) {
      audio.noteOn(note.midi, velocity: note.velocity);
      _scheduleRelease(note.midi, note.endBeat);
    }
  }

  /// Sound the notes whose moment has now come.
  void _playWaitingNotes() {
    _waiting.removeWhere((note) {
      if (_beat < note.beat) return false;
      audio.noteOn(note.midi, velocity: note.velocity);
      _scheduleRelease(note.midi, note.beat + note.duration);
      return true;
    });
  }

  /// Sound what the player has not, so the piece keeps its shape.
  ///
  /// Deliberately does not resolve the note. The window stays open, so a late
  /// hand still finds it, still scores, and still hears its own touch play it
  /// — lateness remains the one error that is heard. And the miss is still
  /// registered later, by [_expireMissedTaps], if nobody comes.
  void _fillMissedNotes() {
    if (!fillMissed) return;
    final due = _judgedBeat - _fillDelayBeats;
    for (final tap in chart.taps) {
      if (tap.beat > due) break; // taps are in time order
      if (!_isPending(tap)) continue;
      for (final note in tap.notes) {
        if (!_filled.add(_keyOf(note))) continue;
        audio.noteOn(note.midi,
            velocity: (note.velocity * _fillVelocity).clamp(0.05, 1.0));
        _scheduleRelease(note.midi, note.endBeat);
      }
    }
  }

  /// A note the player never tapped is a miss once it is too late to hit.
  void _expireMissedTaps() {
    final deadline = _judgedBeat - judge.windowMs / 1000 * beatsPerSecond;
    for (final tap in chart.taps) {
      if (tap.beat >= deadline) break; // taps are in time order
      if (!_isPending(tap)) continue;
      _resolve(tap);
      _justMissed.add((beat: tap.beat, hand: tap.hand));
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

  /// The player touched the screen at [across], 0 at the left edge and 1 at
  /// the right. Returns what happened, or null if there was no note there.
  ///
  /// A touch with nothing under it is ignored rather than punished: this game
  /// invites people who cannot play, and charging them for a stray finger
  /// would teach exactly the wrong lesson.
  TapOutcome? tap(double across) {
    if (!_running) return null;
    final hand = Chart.handAt(across);

    final index = _nearestPending(across, hand);
    if (index == null) {
      final near = _nearMiss(across, hand);
      if (near == null) return null;
      return TapOutcome(
        verdict: Verdict.miss,
        hand: hand,
        errorMs: near,
        notes: const [],
        scored: false,
      );
    }

    final tapTarget = chart.taps[index];
    final errorMs = (_judgedBeat - tapTarget.beat) / beatsPerSecond * 1000;
    // Matching and judging measure from the same moment against the same
    // window, so anything matched here is inside it — and a matched touch
    // always sounds. It used to be able to come back a miss and return
    // nothing, which is how a real touch got answered with silence.
    final verdict = judge.verdictFor(errorMs);

    _resolve(tapTarget);
    scoreboard.register(verdict);

    _sound(tapTarget, errorMs);

    int? holdId;
    if (tapTarget.isHold) {
      holdId = _nextHoldId++;
      _holds[holdId] = _Hold(
        beat: tapTarget.beat,
        midis: tapTarget.notes.map((n) => n.midi).toList(),
        endBeat: tapTarget.endBeat,
      );
    }

    return TapOutcome(
      verdict: verdict,
      hand: tapTarget.hand,
      errorMs: errorMs,
      notes: tapTarget.notes,
      holdId: holdId,
      dragId: _beginDrag(tapTarget, across),
    );
  }

  /// Sound a touch's notes, [errorMs] deciding how firmly.
  ///
  /// Tighter timing is played a little firmer, so a clean run sounds clean as
  /// well as scoring well.
  void _sound(Tap target, double errorMs) {
    final firmness = 0.85 + judge.quality(errorMs) * 0.3;
    final early = quantize && _beat < target.beat;

    for (final note in target.notes) {
      final velocity = (note.velocity * firmness).clamp(0.05, 1.0);
      if (early) {
        // Hold it back to its written moment, so the piece comes out in time
        // however jumpy the hand was.
        _waiting.add((
          beat: target.beat,
          midi: note.midi,
          velocity: velocity,
          duration: note.duration,
        ));
      } else {
        audio.noteOn(note.midi, velocity: velocity);
        _scheduleRelease(note.midi, target.beat + note.duration);
      }
    }
  }

  /// Fingers sliding through a run.
  final Map<int, _Drag> _drags = {};
  int _nextDragId = 1;

  /// How far the finger has to slide to earn the next note of a run, as a
  /// fraction of the screen's width.
  ///
  /// Small, and it has to be: the fastest run in the library gives it
  /// seventy-six milliseconds, four or five frames. What this is really
  /// asking is whether the finger is still moving — a hand that stops gets
  /// nothing, which is what keeps the slide a gesture rather than a rest.
  static const double dragStep = 0.012;

  /// A touch that landed on a run leaves the finger able to slide through it.
  /// Returns the token the screen hands back to [drag].
  int? _beginDrag(Tap target, double across) {
    final runId = target.runId;
    if (runId == null) return null;
    final run = chart.runs[runId];
    if (run == null || target.runIndex + 1 >= run.length) return null;

    final id = _nextDragId++;
    _drags[id] = _Drag(runId: runId, index: target.runIndex, across: across);
    return id;
  }

  /// The finger that entered a run has moved to [across].
  ///
  /// This is the answer to a passage no hand can tap: press the first note,
  /// then keep sliding and the rest of the run comes to the finger. The song
  /// still decides *when* each note sounds — a slide never runs ahead of the
  /// music, and never drags behind it — so what the gesture is being asked
  /// for is that it keep going. Stop moving and the run goes on without you,
  /// note by note, as misses.
  ///
  /// Returns what the note that just sounded was worth, or null if this move
  /// did not reach one.
  TapOutcome? drag(int dragId, double across) {
    if (!_running) return null;
    final drag = _drags[dragId];
    if (drag == null) return null;

    drag.travelled += (across - drag.across).abs();
    drag.across = across;

    final run = chart.runs[drag.runId]!;
    while (drag.index + 1 < run.length) {
      final next = run[drag.index + 1];
      final errorMs = (_judgedBeat - next.beat) / beatsPerSecond * 1000;

      // Not its moment yet. The travel already banked is kept, so a finger
      // that is moving catches the note the instant it comes due.
      if (errorMs < 0) return null;

      // Gone: expired as a miss while the finger was still, taken by another
      // finger, or simply too late now. Step over it without spending the
      // slide — it is already someone else's business.
      if (errorMs > judge.windowMs || !_isPending(next)) {
        drag.index++;
        continue;
      }

      if (drag.travelled < dragStep) return null;
      drag.index++;
      drag.travelled = 0;

      final verdict = judge.verdictFor(errorMs);
      _resolve(next);
      scoreboard.register(verdict);
      _sound(next, errorMs);

      return TapOutcome(
        verdict: verdict,
        hand: next.hand,
        errorMs: errorMs,
        notes: next.notes,
        dragId: dragId,
      );
    }

    // The run is over; the finger is just a finger again.
    _drags.remove(dragId);
    return null;
  }

  /// The finger came off, or the run is over.
  void endDrag(int dragId) => _drags.remove(dragId);

  /// Notes the finger is currently keeping down.
  final Map<int, _Hold> _holds = {};
  int _nextHoldId = 1;

  /// Whether a long note is being held right now — for the screen to show.
  bool get isHolding => _holds.isNotEmpty;

  /// The notes a finger is on at this moment, keyed the same way as
  /// everything else here: which beat, which pitch.
  ///
  /// The screen needs this to know which long notes to stop at the line. One
  /// that nobody caught is not being held, and should carry on down and leave
  /// like any other missed note rather than sitting on the line pretending.
  Set<(double, int)> get heldNotes => {
        for (final hold in _holds.values)
          for (final midi in hold.midis) (hold.beat, midi),
      };

  /// The finger came off a long note.
  ///
  /// Letting go before the note is written to end cuts it short. Nothing is
  /// deducted for it: the music itself is the correction, which is a better
  /// teacher than a number going down.
  ///
  /// Returns true if the note was cut short.
  bool releaseHold(int holdId) {
    final hold = _holds.remove(holdId);
    if (hold == null) return false;
    if (_beat >= hold.endBeat - 0.05) return false; // held to the end

    for (final midi in hold.midis) {
      audio.noteOff(midi);
      _releaseAt.remove(midi);
      _waiting.removeWhere((n) => n.midi == midi);
    }
    return true;
  }

  /// The pending touch this one should count as.
  ///
  /// Timing decides it, not aim. Position says which pitch a note is, and —
  /// once the hands are separated — which hand it belongs to; but making the
  /// player land on the note itself would turn a game about *when* into one
  /// about hand-eye coordination.
  ///
  /// Where several notes fall together, the touched position breaks the tie,
  /// so several fingers land on several notes instead of all taking the same
  /// one.
  int? _nearestPending(double across, Hand hand) {
    final windowBeats = judge.windowMs / 1000 * beatsPerSecond;
    const simultaneous = 0.001;

    int? best;
    var bestDistance = double.infinity;
    var bestGap = double.infinity;

    final now = _judgedBeat;
    for (var i = 0; i < chart.taps.length; i++) {
      final tap = chart.taps[i];
      if (tap.beat - now > windowBeats) break; // taps are in time order
      if (!_isPending(tap)) continue;
      if (chart.separatesHands && tap.hand != hand) continue;

      final distance = (tap.beat - now).abs();
      if (distance > windowBeats) continue;

      final gap = (tap.across - across).abs();
      final closerInTime = distance < bestDistance - simultaneous;
      final sameMoment = (distance - bestDistance).abs() <= simultaneous;

      if (closerInTime || (sameMoment && gap < bestGap)) {
        best = i;
        bestDistance = distance;
        bestGap = gap;
      }
    }
    return best;
  }

  /// How far off a tap was from the nearest note it could plausibly have been
  /// aimed at, or null if there was nothing anywhere near.
  double? _nearMiss(double across, Hand hand) {
    final now = _judgedBeat;
    double? closest;
    void consider(double beat, Hand tapHand) {
      if (chart.separatesHands && tapHand != hand) return;
      final delta = beat - now;
      if (delta.abs() > _reachBeats) return;
      if (closest == null || delta.abs() < closest!.abs()) closest = delta;
    }

    // Notes still to come — the player was early.
    for (final tap in chart.taps) {
      if (tap.beat - now > _reachBeats) break;
      if (_isPending(tap)) consider(tap.beat, tap.hand);
    }
    // Notes just gone — the player was late.
    for (final missed in _justMissed) {
      consider(missed.beat, missed.hand);
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
    _waiting.clear();
    _holds.clear();
    _drags.clear();
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
    _filled.clear();
    _running = true;
  }
}

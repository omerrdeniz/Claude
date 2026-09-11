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
    this.places = const [],
    this.voices = 1,
    this.scored = true,
    this.holdId,
    this.crushId,
    this.crushLean = 0,
  });

  final Verdict verdict;
  final Hand hand;

  /// Set when this touch began a note the finger is expected to keep down.
  /// Hand it back to [PlaySession.releaseHold] when the finger lifts.
  final int? holdId;

  /// Set when this touch carried an ornament, which the finger may still
  /// flick. Hand it to [PlaySession.flick] while the finger moves.
  final int? crushId;

  /// Which way that flick has to go: 1 for right, -1 for left.
  final int crushLean;

  /// How early (negative) or late (positive) the tap was.
  final double errorMs;

  final List<Note> notes;

  /// Where each of those notes sits across the screen, so a hit can be lit
  /// where it happened rather than somewhere in the middle of the hand.
  final List<double> places;

  /// How many notes sounded together, which is what colours the hit.
  final int voices;

  /// False for a tap that found a note but was too far off to count. It costs
  /// nothing; it exists so the player is told *why* nothing sounded instead of
  /// being met with silence.
  final bool scored;
}

/// An ornament just sounded, waiting to see whether the hand flicked.
class _Crush {
  _Crush({required this.from, required this.lean, required this.until});

  /// Where across the screen the finger landed.
  final double from;

  /// Which way it has to move: 1 right, -1 left.
  final int lean;

  /// The beat after which nobody is flicking any more.
  final double until;
}

/// A note being held down.
class _Hold {
  _Hold({
    required this.beat,
    required this.midis,
    required this.endBeat,
    required this.sustained,
  });

  /// Which moment in the song this is, so the screen can tell which drawn
  /// note the finger is on.
  final double beat;
  final List<int> midis;
  final double endBeat;

  /// Whether this note goes on sounding once the finger leaves it.
  ///
  /// True where the same hand is asked for another note before this one
  /// ends — see [Tap.sustains]. The finger has to leave; the note does not.
  final bool sustained;

  /// Whether a finger is on it right now.
  ///
  /// A sustained note keeps sounding after this goes false, but it stops
  /// being drawn on the line: a screen full of notes pinned there while the
  /// hand is somewhere else is unreadable, and it is not true either — the
  /// finger has moved on.
  bool underFinger = true;
}

/// A finger down on the playfield, following whatever run its hand has.
///
/// Deliberately not bound to one run. The canon's runs come eight in a row,
/// eight hundred milliseconds apart; binding a finger to a single run meant
/// lifting and pressing again between each of them, inside that gap, eight
/// times. A finger that is down is following the passage, not a numbered
/// piece of it.
class _Drag {
  _Drag({required this.hand, required this.across});

  final Hand hand;

  /// Where the finger is now, as a fraction across the screen.
  double across;
}

/// The bead a run is currently on: the note due now, sitting on the hit line.
///
/// It is what the finger follows. Without something to follow, a slide is a
/// finger waved at a screen and the notes arriving on their own — which is
/// exactly how the first version of this felt.
class RunBead {
  const RunBead({
    required this.runId,
    required this.hand,
    required this.across,
    required this.tracked,
  });

  final int runId;
  final Hand hand;

  /// Where on the hit line it sits, 0 at the left edge and 1 at the right.
  final double across;

  /// Whether a finger is on it. A bead nobody is following still moves; it
  /// just plays nothing.
  final bool tracked;
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

  /// The notes already dealt with, as (beat, pitch).
  ///
  /// The screen uses it to stop drawing a note that has been played: a hit
  /// ends at the line, in a burst of light, and only what nobody caught goes
  /// on falling past it. Drawn the same either way, the picture said nothing
  /// about whether the player had done anything.
  Set<(double, int)> get playedNotes => _resolved;

  bool _isPending(Tap tap) =>
      tap.notes.any((note) => !_resolved.contains(_keyOf(note)));

  void _resolve(Tap tap) {
    for (final note in [...tap.notes, ...tap.grace]) {
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

    _endFinishedHolds();
    _playAccompaniment();
    _playRuns();
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

  /// Let a pitch go at [atBeat] — or later, if it is already owed more time.
  ///
  /// Releases are kept per pitch, because a piano has one string per pitch.
  /// That means a short note can take the release of a long one still
  /// sounding underneath it, and a sixty-millisecond ornament sharing a pitch
  /// with a note written to ring for two seconds damped it after sixty
  /// milliseconds — the other half of "birinci sesten sonra ikinci ses
  /// gelmiyor". This repertoire is written for the pedal: where two claims on
  /// a string disagree, the longer one is the one the music meant.
  void _scheduleRelease(int midi, double atBeat) {
    final owed = _releaseAt[midi];
    if (owed == null || atBeat > owed) _releaseAt[midi] = atBeat;
  }

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
      final booked = _bookAhead(hand);
      if (booked != null) return _book(chart.taps[booked]);

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
        sustained: tapTarget.sustains,
      );
    }

    int? crushId;
    if (tapTarget.hasGrace) {
      crushId = _nextCrushId++;
      _crushes[crushId] = _Crush(
        from: across,
        lean: tapTarget.graceLean,
        until: _flickUntil(tapTarget),
      );
    }

    return TapOutcome(
      verdict: verdict,
      hand: tapTarget.hand,
      errorMs: errorMs,
      notes: tapTarget.notes,
      places: tapTarget.noteAcross,
      voices: tapTarget.voices,
      holdId: holdId,
      crushId: crushId,
      crushLean: tapTarget.graceLean,
    );
  }

  /// Sound a touch's notes, [errorMs] deciding how firmly.
  ///
  /// Tighter timing is played a little firmer, so a clean run sounds clean as
  /// well as scoring well.
  void _sound(Tap target, double errorMs) {
    final firmness = 0.85 + judge.quality(errorMs) * 0.3;
    final early = quantize && _beat < target.beat;

    // The gap an ornament leans across. It is the game's to give, not the
    // hand's: sixty milliseconds is less than the time between two touches
    // anybody can make, so one touch sounds both — as one movement of the
    // hand does at a piano.
    final crush = target.hasGrace ? target.beat - target.grace.first.beat : 0.0;

    // And it is never squeezed. A touch a little early used to sound the
    // ornament at once while its note was still held back to its written
    // beat, leaving whatever was left of the gap between them — a single
    // frame at thirty milliseconds early, which is not an ornament but a
    // stumble. The player heard it: "iki ses çok arka arkaya çalıyor".
    //
    // So the pair may land up to one crush late, and never closer together
    // than a crush. Of the two ways to be wrong, a lean that arrives a
    // sixteenth of a second late still sounds like the music; one that
    // arrives as two notes at once does not.
    final wanted = early ? target.beat : _beat + crush;
    final mainBeat = wanted > _beat + crush ? wanted : _beat + crush;

    void sound(Note note, double at, double end, double weight) {
      final velocity = (note.velocity * firmness * weight).clamp(0.05, 1.0);
      if (at > _beat) {
        // Hold it back to its moment, so the piece comes out in time however
        // jumpy the hand was.
        _waiting.add((
          beat: at,
          midi: note.midi,
          velocity: velocity,
          duration: end - at,
        ));
      } else {
        audio.noteOn(note.midi, velocity: velocity);
        _scheduleRelease(note.midi, end);
      }
    }

    for (final note in target.grace) {
      final at = mainBeat - crush;
      sound(note, at, at + note.duration, _graceWeight);
    }
    for (final note in target.notes) {
      sound(note, mainBeat, target.beat + note.duration, 1);
    }
  }

  /// How much lighter an ornament is struck than the note it leans into.
  ///
  /// The weight of an acciaccatura belongs to the main note; the small one is
  /// a scrape on the way in, not a note of its own. Played at equal force it
  /// reads as two notes played sloppily rather than one played with a flick.
  static const double _graceWeight = 0.8;

  /// Ornaments sounded and not yet flicked.
  final Map<int, _Crush> _crushes = {};
  int _nextCrushId = 1;

  /// How far the finger has to move to have flicked, as a fraction of the
  /// screen's width.
  ///
  /// Smaller than [dragReach], which asks a finger to stay *with* something
  /// moving; this only asks which way the hand went. Big enough that holding
  /// still is not a flick, small enough to be one movement of a thumb.
  static const double flickReach = 0.04;

  /// How long after the touch a flick still counts, in seconds — and only on
  /// the hardest level. Below it the finger has as long as it stays down.
  ///
  /// The player asked for this and was right: on the middle level, doing the
  /// gesture *is* the gesture. A window there would mean a hand that flicked
  /// plainly and correctly was told no, for being a tenth of a second late at
  /// something that has already sounded. Timing is what the rest of the game
  /// is about; this is about the shape of the movement. Only the hardest
  /// level asks for both at once.
  static const double flickSeconds = 0.3;

  /// When this touch's flick stops counting.
  ///
  /// The hardest level gives it a stopwatch. Below that the chance lasts
  /// until the hand is wanted again, which is the musical answer rather than
  /// a number: there is no hurry, but a movement made long after the moment
  /// has passed is not this ornament's.
  double _flickUntil(Tap target) {
    if (chart.difficulty == Difficulty.hard) {
      return _beat + flickSeconds * beatsPerSecond;
    }
    for (final tap in chart.taps) {
      if (tap.beat <= target.beat) continue;
      if (chart.separatesHands && tap.hand != target.hand) continue;
      return tap.beat;
    }
    return double.infinity;
  }

  /// What a flick is worth, before the combo multiplier.
  ///
  /// Deliberately not part of [Scoreboard.accuracy]: accuracy is about
  /// timing, and this is not a timing question. A flourish adds to the score
  /// without moving the grade — nobody is marked down for playing it plain.
  static const int flickPoints = 50;

  /// The finger that took an ornament has moved to [across].
  ///
  /// Returns true the moment it has gone far enough the right way, once.
  bool flick(int crushId, double across) {
    final crush = _crushes[crushId];
    if (crush == null) return false;
    if (_beat > crush.until) {
      _crushes.remove(crushId);
      return false;
    }
    final moved = (across - crush.from) * crush.lean;

    // Going the other way spends the chance. Without this the hand could
    // wander off the wrong way and still be paid when it happened to come
    // back — which is not the gesture, and the player saw it: "diğer yöne
    // kaydırsam da çarpma efekti yine de çalışıyor".
    if (moved <= -flickReach) {
      _crushes.remove(crushId);
      return false;
    }
    if (moved < flickReach) return false;

    _crushes.remove(crushId);
    scoreboard.score += flickPoints * scoreboard.multiplier;
    return true;
  }

  /// The finger that took an ornament has left without flicking.
  void endCrush(int crushId) => _crushes.remove(crushId);

  /// Fingers following a run.
  final Map<int, _Drag> _drags = {};
  int _nextDragId = 1;

  /// How far from the note it is playing a finger may be and still be
  /// following the run, as a fraction of the screen's width.
  ///
  /// About a finger's width either side on a phone. Generous on purpose: the
  /// skill being asked for is staying with a passage, not hitting a target.
  /// It is also what stops a parked finger from collecting a whole run —
  /// the beads of a real run travel most of the hand's zone, so a hand that
  /// does not travel with them falls off.
  static const double dragReach = 0.15;

  /// Told when a run plays a note under a finger, so the screen can react.
  void Function(TapOutcome outcome)? onDragNote;

  /// How long before its first note a run puts its bead on the line, in the
  /// song's own time.
  ///
  /// Far longer than the judging window, and for a different reason. The
  /// window is how late a touch may be; this is how long a hand has to get
  /// itself into position, and a person needs a quarter of a second just to
  /// react to the ring appearing.
  ///
  /// In the song's time rather than the player's, so that **slowing a piece
  /// down gives more of it**. It used to be in real milliseconds, which
  /// meant the practice speed — the one thing a player reaches for when
  /// something is too fast to catch — did not help at all.
  static const double dragLeadMs = 900;

  /// Where each run on screen has got to, for the finger and the eye alike.
  ///
  /// The bead keeps its place a judging window past the run's last note, so
  /// it does not vanish from under a finger that is still on it.
  List<RunBead> get runBeads {
    if (chart.runs.isEmpty) return const [];
    final lead = dragLeadMs / 1000 * chart.song.bpm / 60;
    final tail = judge.windowMs / 1000 * beatsPerSecond;
    final now = _judgedBeat;

    // One bead to a hand, never two. The canon's runs overlap once the lead
    // is counted — the next one's ring was appearing before the current one
    // had finished, so two hollow circles sat on the line and a finger going
    // down could be given the wrong one.
    final chosen = <Hand, MapEntry<int, List<Tap>>>{};
    for (final entry in chart.runs.entries) {
      final run = entry.value;
      if (now < run.first.beat - lead) continue;
      if (now > run.last.beat + tail) continue;

      final hand = run.first.hand;
      final rival = chosen[hand];
      if (rival == null) {
        chosen[hand] = entry;
        continue;
      }
      // The one being played beats the one still coming; between two that
      // have started, the later. A ring should never point ahead of the
      // notes actually arriving.
      final mine = run.first.beat <= now;
      final theirs = rival.value.first.beat <= now;
      if (mine && !theirs) chosen[hand] = entry;
      if (mine == theirs &&
          (mine
              ? run.first.beat > rival.value.first.beat
              : run.first.beat < rival.value.first.beat)) {
        chosen[hand] = entry;
      }
    }

    return [
      for (final entry in chosen.entries)
        () {
          final across = _beadAcross(entry.value.value, now);
          return RunBead(
            runId: entry.value.key,
            hand: entry.key,
            across: across,
            tracked: _drags.values.any((drag) =>
                drag.hand == entry.key &&
                (drag.across - across).abs() <= dragReach),
          );
        }(),
    ];
  }

  /// The bead slides between one note's place and the next rather than
  /// jumping, so what the finger is chasing moves the way the music does.
  static double _beadAcross(List<Tap> run, double beat) {
    if (beat <= run.first.beat) return run.first.across;
    if (beat >= run.last.beat) return run.last.across;
    for (var i = 1; i < run.length; i++) {
      if (beat >= run[i].beat) continue;
      final span = run[i].beat - run[i - 1].beat;
      final t = span <= 0 ? 0.0 : (beat - run[i - 1].beat) / span;
      return run[i - 1].across + (run[i].across - run[i - 1].across) * t;
    }
    return run.last.across;
  }

  /// A finger went down at [across]. Returns the token the screen hands back
  /// to [drag] while it moves and to [endDrag] when it lifts.
  ///
  /// **A finger is not given a run; it is given a hand.** Whatever run that
  /// hand has, now or in a moment, this finger follows — which is what a
  /// person expects of a finger they have not lifted. Binding it to one run
  /// meant the canon, whose runs come eight in a row eight hundred
  /// milliseconds apart, asked for a fresh press between each of them.
  ///
  /// Nor is entry aimed: anywhere in the hand will do. There is nothing to
  /// protect by making it hard — following a run only ever adds notes you
  /// could otherwise not play, and the skill the mechanic is about is
  /// *staying* with the bead, which [dragReach] still asks for.
  int? beginDrag(double across) {
    if (!_running) return null;
    final id = _nextDragId++;
    _drags[id] = _Drag(hand: Chart.handAt(across), across: across);
    return id;
  }

  /// The finger following a run has moved to [across].
  ///
  /// Only its position is recorded. Nothing sounds here: the notes of a run
  /// are played by the clock, in [_playRuns], so a finger that is in the
  /// right place keeps playing whether it is moving fast, moving slowly or
  /// turning around. The first version fired a note per move event and
  /// charged a distance for each one, which meant every direction change —
  /// the moment a finger is briefly still — dropped a note.
  void drag(int dragId, double across) => _drags[dragId]?.across = across;

  /// The finger came off.
  void endDrag(int dragId) => _drags.remove(dragId);

  /// How far each run has been carried, so two runs in a row each keep their
  /// own place and a finger can be handed from one to the next.
  final Map<int, int> _runReached = {};

  /// Play the notes of every run a finger is following.
  ///
  /// The song still decides *when*; what the finger decides is *whether*, by
  /// being near the note that is due. Position rather than motion is the
  /// whole of it: it is what makes the bead worth following, and what lets a
  /// hand that drifts off hear itself drift off.
  void _playRuns() {
    if (_drags.isEmpty) return;
    final beads = runBeads;
    if (beads.isEmpty) return;

    for (final drag in _drags.values) {
      final bead = beads.where((b) => b.hand == drag.hand).firstOrNull;
      if (bead == null) continue;

      final run = chart.runs[bead.runId]!;
      var index = _runReached[bead.runId] ?? -1;
      while (index + 1 < run.length) {
        final next = run[index + 1];
        final errorMs = (_judgedBeat - next.beat) / beatsPerSecond * 1000;
        if (errorMs < 0) break; // not due yet
        index++;

        // Gone: already played, or expired while nobody was on it.
        if (!_isPending(next) || errorMs > judge.windowMs) continue;
        // The finger has drifted off the bead. The note is left to expire,
        // which is how a run tells you that you have lost it.
        if ((next.across - drag.across).abs() > dragReach) continue;

        final verdict = judge.verdictFor(errorMs);
        _resolve(next);
        scoreboard.register(verdict);
        _sound(next, errorMs);
        onDragNote?.call(TapOutcome(
          verdict: verdict,
          hand: next.hand,
          errorMs: errorMs,
          notes: next.notes,
          places: next.noteAcross,
          voices: next.voices,
        ));
      }
      _runReached[bead.runId] = index;
    }
  }

  /// Notes the finger is currently keeping down.
  final Map<int, _Hold> _holds = {};
  int _nextHoldId = 1;

  /// Whether a long note is being held right now — for the screen to show.
  bool get isHolding => _holds.values.any((hold) => hold.underFinger);

  /// The long notes with a finger on them, keyed the same way as everything
  /// else here: which beat, which pitch.
  ///
  /// The screen needs this to know which ones to stop at the line. One that
  /// nobody caught was never held, and carries on down and leaves like any
  /// other missed note. One the player had to let go of — because the same
  /// hand was needed elsewhere — goes on *sounding*, but stops being drawn
  /// there: the finger is not on it any more, and a line full of notes
  /// pinned under a hand that has moved away is unreadable.
  Set<(double, int)> get heldNotes => {
        for (final hold in _holds.values)
          if (hold.underFinger)
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
    final hold = _holds[holdId];
    if (hold == null) return false;

    // A note the same hand has to leave in order to play the next one is not
    // let go of; it rings on, pinned on the line, until it is written to end.
    // Otherwise every one of Bach's bass notes would be cut off by the very
    // touch the piece asks for next, and the player would be punished for
    // having one finger to a hand.
    if (hold.sustained) {
      hold.underFinger = false;
      return false;
    }

    _holds.remove(holdId);
    if (_beat >= hold.endBeat - 0.05) return false; // held to the end

    for (final midi in hold.midis) {
      audio.noteOff(midi);
      _releaseAt.remove(midi);
      _waiting.removeWhere((n) => n.midi == midi);
    }
    return true;
  }

  /// A note that rings on after the finger has gone is finished by the clock.
  void _endFinishedHolds() =>
      _holds.removeWhere((_, hold) => _beat >= hold.endBeat);

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

  /// The next thing this hand has coming, for a touch that found nothing in
  /// its window.
  ///
  /// Gnossienne No. 1 is why. Its left hand does not play with the melody: at
  /// twenty-three places it comes a full six hundred milliseconds later, and
  /// somebody who does not know the piece cannot hear that coming. They press
  /// both hands together, the left one lands outside every window there is,
  /// and the game answers it with **nothing at all** — no sound, not even a
  /// miss. That is the dead control this game keeps having to design its way
  /// out of.
  ///
  /// So the touch books the note instead, and the note sounds **on its own
  /// beat**, never early. The hand said "play the bass"; the game says when.
  ///
  /// Deliberately tied to [quantize], which already means *early presses are
  /// held to their written moment* — this only widens its reach for a hand
  /// with nothing in front of it. With quantize off the player has asked to
  /// hear their own timing, and gets it. The hardest level does not book at
  /// all: there, when is the whole question.
  ///
  /// **Only where the music is already doing something.** The other hand has
  /// to have a note here, and that is what separates the beginner playing
  /// both hands on the beat from a finger that went off on its own. An early
  /// touch into silence still costs nothing and still says so; the moment
  /// before a run, where the bead is out but nothing is playable, still
  /// plays nothing. Without that condition this booked the first note of
  /// every run before it began, and told a stray finger it had scored.
  int? _bookAhead(Hand hand) {
    if (!quantize || chart.difficulty == Difficulty.hard) return null;
    if (!_otherHandIsHere(hand)) return null;
    final reach = bookAheadSeconds * beatsPerSecond;
    for (var i = 0; i < chart.taps.length; i++) {
      final tap = chart.taps[i];
      final ahead = tap.beat - _judgedBeat;
      if (ahead > reach) break; // taps are in time order
      if (ahead <= 0 || !_isPending(tap)) continue;
      if (chart.separatesHands && tap.hand != hand) continue;
      return i;
    }
    return null;
  }

  /// Whether the other hand has a note at this moment — the sign that the
  /// player pressed with the music rather than into it.
  bool _otherHandIsHere(Hand hand) {
    if (!chart.separatesHands) return false;
    final windowBeats = judge.windowMs / 1000 * beatsPerSecond;
    for (final tap in chart.taps) {
      final distance = tap.beat - _judgedBeat;
      if (distance > windowBeats) break; // taps are in time order
      if (distance.abs() <= windowBeats && tap.hand != hand) return true;
    }
    return false;
  }

  /// How far ahead a touch may book, in seconds.
  ///
  /// Longer than the six hundred milliseconds Satie leaves between the hands,
  /// and short enough that it reaches the *next* thing rather than the one
  /// after it.
  static const double bookAheadSeconds = 0.8;

  /// What a booked note is worth.
  ///
  /// It counts and it keeps the streak: the player did play the note, and
  /// nobody should lose a run of fifty for not feeling a gap they have never
  /// heard. It is not a perfect, either — the timing was the game's, not
  /// theirs, and the difference is the whole reason to learn the piece.
  static const Verdict bookedVerdict = Verdict.good;

  /// Take a note the hand asked for before its moment came.
  TapOutcome _book(Tap target) {
    _resolve(target);
    scoreboard.register(bookedVerdict);
    // Nought, and truthfully: the note is about to be sounded exactly on its
    // beat, so there is no error in what will be heard.
    _sound(target, 0);
    return TapOutcome(
      verdict: bookedVerdict,
      hand: target.hand,
      errorMs: 0,
      notes: target.notes,
      places: target.noteAcross,
      voices: target.voices,
    );
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
    _runReached.clear();
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

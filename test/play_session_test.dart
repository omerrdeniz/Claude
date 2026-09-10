import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/audio/piano_audio.dart';
import 'package:piano_flow/audio/synth_engine.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/game/judgement.dart';
import 'package:piano_flow/game/play_session.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';

/// A synth that records what it was asked to play, so tests can check the
/// music rather than the plumbing.
class RecordingEngine extends SynthEngine {
  final List<(int midi, double velocity)> struck = [];
  final List<int> released = [];

  @override
  void noteOn(int midi, {double velocity = 0.8}) {
    struck.add((midi, velocity));
    super.noteOn(midi, velocity: velocity);
  }

  @override
  void noteOff(int midi) {
    released.add(midi);
    super.noteOff(midi);
  }
}

const bpm = 120.0; // one beat is exactly half a second

Song songOf(List<Note> notes) =>
    Song(id: 't', title: 'T', composer: '', bpm: bpm, notes: notes);

Note note(double beat, int midi,
        {double duration = 0.5, Hand hand = Hand.right}) =>
    Note(beat: beat, midi: midi, duration: duration, hand: hand);

/// Somewhere on the right-hand side of the screen.
const double right = 0.75;

/// Somewhere on the left-hand side.
const double left = 0.25;

void main() {
  late RecordingEngine engine;

  PlaySession sessionFor(
    Song song, {
    Difficulty difficulty = Difficulty.easy,
    bool quantize = true,
    bool fillMissed = false,
    Judge judge = const Judge(),
  }) {
    engine = RecordingEngine();
    final session = PlaySession(
      chart: Chart.build(song, difficulty: difficulty),
      audio: PianoAudio(engine: engine),
      judge: judge,
      quantize: quantize,
      fillMissed: fillMissed,
    );
    session.start();
    return session;
  }

  void wall(PlaySession session, double seconds) =>
      session.update(Duration(microseconds: (seconds * 1e6).round()));

  double wallTimeOf(PlaySession session, double beat) =>
      (beat + session.leadInBeats) / session.beatsPerSecond;

  void seek(PlaySession session, double beat) =>
      wall(session, wallTimeOf(session, beat));

  group('the clock', () {
    test('starts before the first note so it arrives travelling', () {
      final session = sessionFor(songOf([note(0, 60)]));
      session.update(Duration.zero);
      expect(session.beat, -session.leadInBeats);
    });

    test('runs at the song tempo', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 4);
      expect(session.beat, closeTo(4, 0.001));
    });

    test('picks up where it left off after a pause', () {
      final session = sessionFor(songOf([note(0, 60), note(8, 62)]));
      seek(session, 2);
      session.pause();
      seek(session, 6); // four beats of wall time pass while paused
      session.start();
      seek(session, 7);
      expect(session.beat, closeTo(3, 0.001));
    });
  });

  group('touching', () {
    test('plays the right note, which the player never chooses', () {
      final session = sessionFor(songOf([note(0, 67)]));
      seek(session, 0);
      final outcome = session.tap(right);
      expect(outcome!.verdict, Verdict.perfect);
      expect(engine.struck.single.$1, 67);
    });

    test('a touch anywhere counts when the hands are not separated', () {
      for (final across in [0.05, 0.3, 0.5, 0.95]) {
        final session = sessionFor(songOf([note(0, 60)]));
        seek(session, 0);
        expect(session.tap(across)?.scored, isTrue, reason: 'at $across');
      }
    });

    test('a touch far from any note does nothing at all', () {
      final session = sessionFor(songOf([note(8, 60)]));
      seek(session, 0);
      expect(session.tap(right), isNull);
      expect(session.scoreboard.notesPlayed, 0,
          reason: 'a stray finger must not be punished');
    });

    test('one note cannot be played twice', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0);
      expect(session.tap(right), isNotNull);
      expect(session.tap(right)?.scored ?? false, isFalse);
      expect(engine.struck, hasLength(1));
    });

    test('nothing happens while paused', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0);
      session.pause();
      expect(session.tap(right), isNull);
    });
  });

  group('the two hands', () {
    final duet = songOf([
      note(0, 84),
      note(0, 40, hand: Hand.left),
    ]);

    test('a hand only answers its own notes', () {
      final session = sessionFor(duet, difficulty: Difficulty.normal);
      seek(session, 0);
      session.tap(left);
      expect(engine.struck.single.$1, 40, reason: 'the left hand note');
      session.tap(right);
      expect(engine.struck.map((s) => s.$1), [40, 84]);
    });

    test('one hand cannot cover for the other', () {
      final session = sessionFor(duet, difficulty: Difficulty.normal);
      seek(session, 0);
      session.tap(left);
      // The right hand's note is still waiting; the left hand must not take it.
      expect(session.tap(left)?.scored ?? false, isFalse);
      expect(engine.struck, hasLength(1));
    });

    test('on easy either side answers anything', () {
      final session = sessionFor(duet, difficulty: Difficulty.easy);
      seek(session, 0);
      // Easy folds the moment into one touch, so one finger takes both notes.
      session.tap(left);
      expect(engine.struck.map((s) => s.$1).toList()..sort(), [40, 84]);
    });

    test('on hard each note of a chord needs its own finger', () {
      final chord = songOf([
        note(0, 48, hand: Hand.left),
        note(0, 52, hand: Hand.left),
        note(0, 55, hand: Hand.left),
      ]);
      final session = sessionFor(chord, difficulty: Difficulty.hard);
      seek(session, 0);
      session.tap(0.1);
      expect(engine.struck, hasLength(1), reason: 'one finger, one note');
      session.tap(0.2);
      session.tap(0.3);
      expect(engine.struck.map((s) => s.$1).toList()..sort(), [48, 52, 55]);
    });

    test('a finger takes the note nearest where it landed', () {
      final chord = songOf([
        note(0, 40, hand: Hand.left),
        note(0, 60, hand: Hand.left),
      ]);
      final session = sessionFor(chord, difficulty: Difficulty.hard);
      seek(session, 0);
      session.tap(0.05); // far left: the lower note
      expect(engine.struck.single.$1, 40);
    });
  });

  group('holding a long note', () {
    Song heldNote() => songOf([note(0, 60, duration: 2)]);

    test('a long note hands back something to let go of', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      final outcome = session.tap(right);
      expect(outcome!.holdId, isNotNull);
      expect(session.isHolding, isTrue);
    });

    test('the screen is told which notes a finger is on', () {
      // Only a note actually caught stops at the line; one nobody held has
      // to carry on down and leave like any other missed note.
      final session = sessionFor(heldNote());
      expect(session.heldNotes, isEmpty, reason: 'nothing touched yet');

      seek(session, 0);
      final id = session.tap(right)!.holdId!;
      expect(session.heldNotes, contains((0.0, 60)));

      session.releaseHold(id);
      expect(session.heldNotes, isEmpty);
    });

    test('a long note nobody catches is never reported as held', () {
      final session = sessionFor(heldNote());
      // Let it go by untouched.
      seek(session, 3);
      expect(session.heldNotes, isEmpty);
    });

    test('a chord under one finger reports all of its notes', () {
      final session = sessionFor(songOf([
        note(0, 60, duration: 2),
        note(0, 64, duration: 2),
        note(0, 67, duration: 2),
      ]));
      seek(session, 0);
      session.tap(right);
      expect(session.heldNotes, containsAll([(0.0, 60), (0.0, 64), (0.0, 67)]));
    });

    test('a short note does not', () {
      final session = sessionFor(songOf([note(0, 60, duration: 0.5)]));
      seek(session, 0);
      expect(session.tap(right)!.holdId, isNull);
      expect(session.isHolding, isFalse);
    });

    test('letting go early cuts the note short', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      final outcome = session.tap(right);
      seek(session, 0.5);
      expect(session.releaseHold(outcome!.holdId!), isTrue,
          reason: 'the note was still meant to be sounding');
      expect(engine.released, contains(60));
    });

    test('holding to the end lets the note ring out on its own', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      final outcome = session.tap(right);
      seek(session, 2.1);
      expect(session.releaseHold(outcome!.holdId!), isFalse,
          reason: 'nothing to cut short — it had finished');
    });

    test('letting go costs no points', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      final outcome = session.tap(right);
      final score = session.scoreboard.score;
      seek(session, 0.5);
      session.releaseHold(outcome!.holdId!);
      expect(session.scoreboard.score, score);
      expect(session.scoreboard.combo, 1, reason: 'the streak survives');
    });

    test('releasing something already released is harmless', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      final id = session.tap(right)!.holdId!;
      seek(session, 0.5);
      session.releaseHold(id);
      expect(session.releaseHold(id), isFalse);
    });

    test('restarting forgets what was being held', () {
      final session = sessionFor(heldNote());
      seek(session, 0);
      session.tap(right);
      session.restart();
      expect(session.isHolding, isFalse);
    });
  });

  group('keeping the music in time', () {
    test('a note touched early waits for its beat', () {
      final session = sessionFor(songOf([note(1, 60)]));
      seek(session, 0.67);
      expect(session.tap(right)?.scored, isTrue);
      expect(engine.struck, isEmpty, reason: 'it must not sound yet');
      seek(session, 1.0);
      expect(engine.struck.map((s) => s.$1), [60]);
    });

    test('the score still reports how early it was', () {
      final session = sessionFor(songOf([note(1, 60)]));
      seek(session, 0.8);
      final outcome = session.tap(right);
      expect(outcome!.errorMs, lessThan(0));
      expect(outcome.verdict, isNot(Verdict.perfect),
          reason: 'flattering the ear must not flatter the score');
    });

    test('a late touch sounds at once, since there is no going back', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0.2);
      session.tap(right);
      expect(engine.struck.map((s) => s.$1), [60]);
    });

    test('switched off, a note sounds under the finger', () {
      final session = sessionFor(songOf([note(1, 60)]), quantize: false);
      seek(session, 0.67);
      session.tap(right);
      expect(engine.struck.map((s) => s.$1), [60]);
    });
  });

  group('tolerance', () {
    double? errorAt(TimingTolerance tolerance) {
      final session = sessionFor(songOf([note(0, 60)]),
          judge: Judge.forTolerance(tolerance));
      seek(session, 0.55); // 275ms late
      final outcome = session.tap(right);
      return outcome != null && outcome.scored ? outcome.errorMs : null;
    }

    test('a wider setting accepts a touch a stricter one refuses', () {
      expect(errorAt(TimingTolerance.tight), isNull);
      expect(errorAt(TimingTolerance.normal), isNull);
      expect(errorAt(TimingTolerance.wide), isNotNull);
    });

    test('every tolerance treats early and late alike', () {
      for (final tolerance in TimingTolerance.values) {
        final judge = Judge.forTolerance(tolerance);
        expect(judge.verdictFor(80), judge.verdictFor(-80));
      }
    });
  });

  group('missing', () {
    test('a note nobody plays is still a miss', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 2);
      expect(session.scoreboard.counts[Verdict.miss], 1);
    });

    test('and stays silent, which is the default', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 2);
      expect(engine.struck, isEmpty,
          reason: 'nothing plays itself unless the player asks it to');
    });

    test('switched on, it sounds anyway, quietly', () {
      // In Normal both hands are the player's, and two thirds of Chopin's
      // nocturne is the left one. Without this, someone answering only the
      // melody hears a piece full of holes.
      final session =
          sessionFor(songOf([note(0, 60, duration: 1)]), fillMissed: true);
      seek(session, 1);
      expect(engine.struck.map((s) => s.$1), [60]);
      expect(engine.struck.single.$2, lessThan(0.5),
          reason: 'present, not competing with a note actually played');
    });

    test('a filled note is not sounded twice', () {
      final session =
          sessionFor(songOf([note(0, 60, duration: 1)]), fillMissed: true);
      seek(session, 1);
      seek(session, 1.5);
      seek(session, 2);
      expect(engine.struck, hasLength(1));
    });

    test('filling does not close the window on a late hand', () {
      // The note is filled at the perfect window, but the player can still
      // reach it, still scores, and still hears their own touch play it.
      final session = sessionFor(songOf([note(0, 60, duration: 1)]),
          quantize: false, fillMissed: true);
      seek(session, 0.2); // past the fill, inside the judging window
      expect(engine.struck, hasLength(1), reason: 'the fill has happened');

      final outcome = session.tap(right);
      expect(outcome?.scored, isTrue);
      expect(engine.struck, hasLength(2), reason: 'and the touch plays it too');
      expect(engine.struck.last.$2, greaterThan(engine.struck.first.$2),
          reason: 'the played one is the louder');
    });

    test('a note played in time is never filled', () {
      final session = sessionFor(songOf([note(0, 60, duration: 1)]),
          quantize: false, fillMissed: true);
      seek(session, 0);
      session.tap(right);
      seek(session, 2);
      expect(engine.struck, hasLength(1),
          reason: 'nothing was missed, so nothing was filled');
    });

    test('the miss is reported once, not every frame', () {
      final session = sessionFor(songOf([note(0, 60)]));
      var misses = 0;
      session.onMiss = (_) => misses++;
      seek(session, 2);
      seek(session, 3);
      expect(misses, 1);
    });

    test('touching too early says so, and costs nothing', () {
      final session = sessionFor(songOf([note(2, 60)]));
      seek(session, 1.3);
      final outcome = session.tap(right);
      expect(outcome, isNotNull, reason: 'silence reads as a broken control');
      expect(outcome!.scored, isFalse);
      expect(outcome.errorMs, lessThan(0));
      expect(session.scoreboard.notesPlayed, 0);
    });

    test('touching just after a note has gone says that too', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0.7);
      final outcome = session.tap(right);
      expect(outcome!.scored, isFalse);
      expect(outcome.errorMs, greaterThan(0));
      expect(session.scoreboard.counts[Verdict.miss], 1,
          reason: 'not counted a second time');
    });
  });

  group('the accompaniment', () {
    test('plays itself on easy, without the player', () {
      final session = sessionFor(
        songOf([for (var i = 0; i < 8; i++) note(i * 0.25, 60 + i)]),
        difficulty: Difficulty.easy,
      );
      seek(session, 2);
      expect(engine.struck, isNotEmpty);
    });

    test('each of its notes sounds once', () {
      final session = sessionFor(
        songOf([note(0, 60), note(0.25, 62)]),
        difficulty: Difficulty.easy,
      );
      seek(session, 1);
      seek(session, 2);
      expect(engine.struck.where((s) => s.$1 == 62), hasLength(1));
    });
  });

  group('finishing and restarting', () {
    test('the song ends once the last note has gone by', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 1);
      expect(session.isFinished, isFalse);
      seek(session, 10);
      expect(session.isFinished, isTrue);
    });

    test('restarting clears the score and makes every note playable again', () {
      final session = sessionFor(songOf([note(0, 60)]));
      final firstNoteAt = wallTimeOf(session, 0);
      wall(session, firstNoteAt);
      session.tap(right);
      expect(session.scoreboard.score, greaterThan(0));

      session.restart();
      expect(session.scoreboard.score, 0);
      wall(session, firstNoteAt + wallTimeOf(session, 0));
      expect(session.tap(right)?.scored, isTrue);
    });
  });

  test('calibration shifts what counts as on time', () {
    final recorder = RecordingEngine();
    final session = PlaySession(
      chart: Chart.build(songOf([note(0, 60)]), difficulty: Difficulty.easy),
      audio: PianoAudio(engine: recorder),
      latencyOffsetMs: 100,
    )..start();
    final seconds = (0.2 + session.leadInBeats) / session.beatsPerSecond;
    session.update(Duration(microseconds: (seconds * 1e6).round()));
    expect(session.tap(right)!.verdict, Verdict.perfect);
  });

  group('with a latency to compensate for', () {
    /// A session that thinks the player's ear is [latencyMs] behind.
    ///
    /// Quantizing is off so that a touch sounds the moment it lands: with it
    /// on, an early one waits for its beat and the test could not tell a note
    /// held back from a note lost.
    (PlaySession, RecordingEngine) calibrated(double latencyMs,
        {double noteAtBeat = 0}) {
      final recorder = RecordingEngine();
      final session = PlaySession(
        chart: Chart.build(songOf([note(noteAtBeat, 60)]),
            difficulty: Difficulty.easy),
        audio: PianoAudio(engine: recorder),
        latencyOffsetMs: latencyMs,
        quantize: false,
      )..start();
      return (session, recorder);
    }

    /// Move to [beat] of song time.
    void at(PlaySession session, double beat) => session.update(Duration(
        microseconds:
            ((beat + session.leadInBeats) / session.beatsPerSecond * 1e6)
                .round()));

    // The bug this pins down: matching a touch to a note used one clock and
    // judging it used another, a whole latency apart. Between the two there
    // was a band of taps that found a note and were then judged too far from
    // it to count — and the game returned nothing at all, no sound and no
    // verdict, for a touch the player had every reason to expect to work.
    test('a touch anywhere in the window is answered, never swallowed', () {
      const latency = 150.0;
      // The judge counts anything inside goodMs; stop just short of the edge
      // so the sweep is not testing rounding.
      const reach = 200.0;
      for (var offsetMs = -reach; offsetMs <= reach; offsetMs += 10) {
        final (session, recorder) = calibrated(latency);
        // Where the hand has to be, in song time, for the player to feel
        // they were offsetMs off the beat.
        at(session, (offsetMs + latency) / 1000 * session.beatsPerSecond);

        final outcome = session.tap(right);
        final off = offsetMs.round();
        expect(outcome, isNotNull,
            reason: 'a touch $off ms off the beat did nothing at all');
        expect(outcome!.verdict, isNot(Verdict.miss),
            reason: 'a touch $off ms off was inside the window and still '
                'judged a miss');
        expect(outcome.scored, isTrue, reason: 'a touch $off ms off went '
            'unscored');
        expect(recorder.struck.map((s) => s.$1), contains(60),
            reason: 'a touch $off ms off was silent');
      }
    });

    test('a note stays available as long as the player window is open', () {
      // Expiry ran on the raw clock, so with a latency the note was written
      // off while the hand still had time to reach it.
      const latency = 150.0;
      final (session, recorder) = calibrated(latency);
      // Just inside the far edge of the window, as the player experiences it.
      at(session, (200 + latency) / 1000 * session.beatsPerSecond);
      final outcome = session.tap(right);
      expect(outcome?.scored, isTrue, reason: 'the note was expired too early');
      expect(recorder.struck.map((s) => s.$1), contains(60));
    });
  });

  group('following a run', () {
    // Four notes an eighth of a second apart, rising: too fast to tap one at
    // a time, and spread across the hand's zone so following them is real
    // movement rather than holding still.
    Song fastRun() =>
        songOf([for (var i = 0; i < 4; i++) note(i * 0.25, 72 + i)]);

    /// Where each note of the run sits across the screen.
    List<double> placesOf(PlaySession session) =>
        [for (final tap in session.chart.taps) tap.across];

    /// Put a finger on the bead, the way a player does.
    (PlaySession, int) joined({double atBeat = 0}) {
      final session = sessionFor(fastRun(), difficulty: Difficulty.normal);
      seek(session, atBeat);
      final bead = session.runBeads.single;
      final id = session.beginDrag(bead.across);
      expect(id, isNotNull, reason: 'there was no bead to take');
      return (session, id!);
    }

    test('a run puts a bead on the line before its first note', () {
      final session = sessionFor(fastRun(), difficulty: Difficulty.normal);
      seek(session, -0.2);
      expect(session.runBeads, hasLength(1),
          reason: 'nothing to aim at before the run starts');
      expect(session.runBeads.single.tracked, isFalse);
      expect(session.runBeads.single.across,
          closeTo(session.chart.taps.first.across, 1e-9));
    });

    test('the bead travels with the pitches, between them as well as on them',
        () {
      final session = sessionFor(fastRun(), difficulty: Difficulty.normal);
      final places = placesOf(session);
      seek(session, 0.125); // halfway between the first two notes
      expect(session.runBeads.single.across,
          closeTo((places[0] + places[1]) / 2, 1e-6));
    });

    test('the bead arrives before the run does, to be got hold of', () {
      // Half a second of lead, against a judging window of a fifth. There is
      // a moment where the ring is on the line and nothing is playable yet:
      // that is the moment to put a finger down.
      final session = sessionFor(fastRun(), difficulty: Difficulty.normal);
      seek(session, -0.6); // 300 ms early: past the window, inside the lead
      expect(session.runBeads, hasLength(1));
      expect(session.tap(session.runBeads.single.across)?.scored ?? false,
          isFalse, reason: 'nothing is playable yet');
      expect(session.beginDrag(session.runBeads.single.across), isNotNull,
          reason: 'but the run can be got hold of');
    });

    test('a finger far from the bead takes nothing', () {
      final session = sessionFor(fastRun(), difficulty: Difficulty.normal);
      seek(session, 0);
      final away = session.runBeads.single.across + PlaySession.dragReach + 0.02;
      expect(session.beginDrag(away.clamp(0.0, 1.0)), isNull);
    });

    test('following the bead plays the run', () {
      final (session, drag) = joined();
      final places = placesOf(session);
      for (var i = 0; i < places.length; i++) {
        session.drag(drag, places[i]);
        seek(session, i * 0.25 + 0.05);
      }
      expect(engine.struck.map((s) => s.$1), [72, 73, 74, 75]);
      expect(session.scoreboard.counts[Verdict.miss], 0);
    });

    test('a finger that holds still on the bead keeps playing', () {
      // The point of the rewrite. The first version charged a distance for
      // every note, so the instant a finger paused — which it does at every
      // change of direction — the run dropped a note.
      final (session, drag) = joined();
      final places = placesOf(session);
      session.drag(drag, places[1]); // within reach of the first three
      for (var i = 0; i < 3; i++) {
        seek(session, i * 0.25 + 0.05);
      }
      expect(engine.struck.map((s) => s.$1), [72, 73, 74],
          reason: 'a still finger in the right place still plays');
    });

    test('a finger that stays behind loses the far end of the run', () {
      // And the balance: staying put is only worth the notes within reach.
      final (session, drag) = joined();
      session.drag(drag, placesOf(session).first);
      for (var i = 0; i < 4; i++) {
        seek(session, i * 0.25 + 0.05);
      }
      seek(session, 3);
      expect(engine.struck.map((s) => s.$1), isNot(contains(75)),
          reason: 'the run walked away from the finger');
      expect(session.scoreboard.counts[Verdict.miss], greaterThan(0));
    });

    test('a run can be joined halfway through', () {
      // Missing the opening note used to cost the whole passage, with no way
      // back in.
      final (session, drag) = joined(atBeat: 0.5);
      session.drag(drag, placesOf(session)[3]);
      seek(session, 0.8);
      expect(engine.struck.map((s) => s.$1), [74, 75],
          reason: 'the notes already gone are gone; the rest is playable');
    });

    test('a run never runs ahead of the music', () {
      final (session, drag) = joined();
      session.drag(drag, placesOf(session)[3]); // finger already at the end
      seek(session, 0.05);
      expect(engine.struck, isEmpty,
          reason: 'the later notes are not due yet');
    });

    test('lifting the finger ends it', () {
      final (session, drag) = joined();
      session.drag(drag, placesOf(session)[1]);
      session.endDrag(drag);
      seek(session, 0.3);
      expect(engine.struck, isEmpty);
      expect(session.runBeads.single.tracked, isFalse);
    });

    test('the bead says whether a finger is on it', () {
      final (session, drag) = joined();
      expect(session.runBeads.single.tracked, isTrue);
      session.drag(drag, 0.0); // right off the edge
      expect(session.runBeads.single.tracked, isFalse);
    });

    test('nothing is taken twice, by a second finger or by a tap', () {
      final (session, drag) = joined();
      expect(session.beginDrag(session.runBeads.single.across), isNull,
          reason: 'one run, one finger');
      session.drag(drag, placesOf(session).first);
      seek(session, 0.05);
      expect(engine.struck.map((s) => s.$1), [72]);
      // A tap now finds the *next* note, never the one the run just played.
      session.tap(placesOf(session).first);
      expect(engine.struck.where((s) => s.$1 == 72), hasLength(1),
          reason: 'the note the run played sounded twice');
    });

    test('a still session ignores a finger', () {
      final (session, drag) = joined();
      session.pause();
      expect(session.beginDrag(0.6), isNull);
      session.drag(drag, 0.7); // harmless
    });
  });
}

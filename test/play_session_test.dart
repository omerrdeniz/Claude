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

void main() {
  late RecordingEngine engine;
  late PianoAudio audio;

  /// Most of these tests are about the session rather than the chart, so they
  /// use the level that keeps one tap per moment.
  PlaySession sessionFor(Song song,
      {double approachSeconds = 2.0,
      int beamCount = 4,
      Difficulty difficulty = Difficulty.easy}) {
    engine = RecordingEngine();
    audio = PianoAudio(engine: engine);
    final session = PlaySession(
      chart: Chart.build(song, beamCount: beamCount, difficulty: difficulty),
      audio: audio,
      approachSeconds: approachSeconds,
    );
    session.start();
    return session;
  }

  /// Advance the screen's clock to [seconds] of wall time.
  void wall(PlaySession session, double seconds) =>
      session.update(Duration(microseconds: (seconds * 1e6).round()));

  /// Wall time at which a fresh session reaches a given beat of the song.
  double wallTimeOf(PlaySession session, double beat) =>
      (beat + session.leadInBeats) / session.beatsPerSecond;

  /// Move a fresh session's clock to a given beat of the song.
  void seek(PlaySession session, double beat) =>
      wall(session, wallTimeOf(session, beat));

  group('the clock', () {
    test('starts before the first note so it arrives travelling', () {
      final session = sessionFor(songOf([note(0, 60)]));
      session.update(Duration.zero);
      expect(session.beat, -session.leadInBeats);
      expect(session.beat, lessThan(0));
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
      // Four beats of wall time pass while the game is paused.
      seek(session, 6);
      session.start();
      seek(session, 7);
      // One beat of play has happened since, not five.
      expect(session.beat, closeTo(3, 0.001));
    });

    test('stands still while paused', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 2);
      session.pause();
      seek(session, 6);
      expect(session.beat, closeTo(2, 0.001));
    });
  });

  group('tapping', () {
    test('plays the right note, which the player never chooses', () {
      final session = sessionFor(songOf([note(0, 67)]));
      seek(session, 0);
      final outcome = session.tap(session.chart.taps.first.beam);
      expect(outcome!.verdict, Verdict.perfect);
      expect(engine.struck.single.$1, 67, reason: 'the note the song asked for');
    });

    test('plays every note of a chord under one finger', () {
      final session =
          sessionFor(songOf([note(0, 60), note(0, 64), note(0, 67)]));
      seek(session, 0);
      session.tap(session.chart.taps.first.beam);
      expect(engine.struck.map((s) => s.$1), [60, 64, 67]);
    });

    test('being early or late still sounds the note, just scores less', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0.36); // 180ms late at this tempo
      final outcome = session.tap(session.chart.taps.first.beam);
      expect(outcome!.verdict, Verdict.good);
      expect(engine.struck, hasLength(1), reason: 'the music must not break');
    });

    test('tighter timing is played a little firmer', () {
      final onTime = sessionFor(songOf([note(0, 60)]));
      seek(onTime, 0);
      onTime.tap(onTime.chart.taps.first.beam);
      final firm = engine.struck.single.$2;

      final late = sessionFor(songOf([note(0, 60)]));
      seek(late, 0.36);
      late.tap(late.chart.taps.first.beam);
      expect(engine.struck.single.$2, lessThan(firm));
    });

    test('a tap far from any note does nothing at all', () {
      final session = sessionFor(songOf([note(8, 60)]));
      seek(session, 0);
      expect(session.tap(session.chart.taps.first.beam), isNull);
      expect(engine.struck, isEmpty);
      expect(session.scoreboard.notesPlayed, 0,
          reason: 'a stray finger must not be punished');
    });

    test('a tap anywhere plays the note that is due', () {
      // Aim is not the skill being tested here — timing is. A note on one beam
      // must answer to a tap on any of them.
      final session = sessionFor(songOf([note(0, 84), note(4, 40)]));
      final rightBeam = session.chart.taps.first.beam;
      for (var beam = 0; beam < 4; beam++) {
        if (beam == rightBeam) continue;
        final fresh = sessionFor(songOf([note(0, 84), note(4, 40)]));
        seek(fresh, 0);
        final outcome = fresh.tap(beam);
        expect(outcome?.scored, isTrue, reason: 'tapped beam $beam');
        expect(engine.struck.single.$1, 84);
      }
    });

    test('a run across the beams can be played without chasing it', () {
      // Four quick notes sweeping from the bottom of the range to the top:
      // a hand cannot cross the screen this fast, and should not have to.
      final session = sessionFor(
        songOf([note(0, 48), note(0.25, 60), note(0.5, 72), note(0.75, 84)]),
      );
      for (final beat in [0.0, 0.25, 0.5, 0.75]) {
        seek(session, beat);
        expect(session.tap(0)?.scored, isTrue, reason: 'at beat $beat');
      }
      expect(engine.struck.map((s) => s.$1), [48, 60, 72, 84]);
      expect(session.scoreboard.combo, 4);
    });

    test('one note cannot be played twice', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0);
      expect(session.tap(session.chart.taps.first.beam), isNotNull);
      expect(session.tap(session.chart.taps.first.beam), isNull);
      expect(engine.struck, hasLength(1));
    });

    test('the nearest note is the one that sounds', () {
      // One beam, so both notes are reachable by the same tap.
      final session =
          sessionFor(songOf([note(0, 60), note(0.5, 62)]), beamCount: 1);
      seek(session, 0.45);
      session.tap(0);
      // Both are inside the window; the closer one must win.
      expect(engine.struck.single.$1, 62);
    });

    test('nothing happens while paused', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0);
      session.pause();
      expect(session.tap(session.chart.taps.first.beam), isNull);
    });
  });

  group('missing', () {
    test('a note that goes by unplayed is a miss', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 2);
      expect(session.scoreboard.counts[Verdict.miss], 1);
      expect(engine.struck, isEmpty, reason: 'a missed note must not sound');
    });

    test('the miss is reported once, not every frame', () {
      final session = sessionFor(songOf([note(0, 60)]));
      var misses = 0;
      session.onMiss = (_) => misses++;
      seek(session, 2);
      seek(session, 3);
      seek(session, 4);
      expect(misses, 1);
    });

    test('a note is not missed while it is still playable', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0.2); // still inside the window
      expect(session.scoreboard.counts[Verdict.miss], 0);
      expect(session.tap(session.chart.taps.first.beam), isNotNull);
    });

    test('missing breaks the streak', () {
      final session = sessionFor(songOf([
        note(0, 60), note(1, 62), note(2, 64),
      ]));
      final beam = session.chart.taps.first.beam;
      seek(session, 0);
      session.tap(beam);
      seek(session, 1);
      session.tap(session.chart.taps[1].beam);
      expect(session.scoreboard.combo, 2);
      seek(session, 4); // let the third go by
      expect(session.scoreboard.combo, 0);
    });
  });

  group('the accompaniment', () {
    test('plays itself, without the player', () {
      final session = sessionFor(songOf([
        note(0, 72),
        note(0, 40, hand: Hand.left),
        note(1, 43, hand: Hand.left),
      ]));
      seek(session, 1.5);
      expect(engine.struck.map((s) => s.$1), containsAll([40, 43]));
    });

    test('each of its notes sounds once', () {
      final session = sessionFor(songOf([
        note(0, 72),
        note(0, 40, hand: Hand.left),
      ]));
      seek(session, 0.5);
      seek(session, 1.0);
      seek(session, 1.5);
      expect(engine.struck.where((s) => s.$1 == 40), hasLength(1));
    });

    test('does not sound before its moment', () {
      final session = sessionFor(songOf([
        note(0, 72),
        note(8, 40, hand: Hand.left),
      ]));
      seek(session, 2);
      expect(engine.struck.where((s) => s.$1 == 40), isEmpty);
    });
  });

  group('note lengths', () {
    test('a note is released when the song says it ends, not on lift', () {
      final session = sessionFor(songOf([note(0, 60, duration: 1.0)]));
      seek(session, 0);
      session.tap(session.chart.taps.first.beam);
      seek(session, 0.5);
      expect(engine.released, isEmpty, reason: 'still ringing');
      seek(session, 1.2);
      expect(engine.released, contains(60));
    });
  });

  group('turning the device', () {
    test('re-laying the song out keeps the score and the streak', () {
      final session = sessionFor(songOf([note(0, 60), note(1, 64)]),
          difficulty: Difficulty.normal);
      seek(session, 0);
      session.tap(session.chart.taps.first.beam);
      final scoreBefore = session.scoreboard.score;

      // Sideways: more beams, so the notes group differently.
      session.rebindChart(Chart.build(session.chart.song,
          beamCount: 6, difficulty: Difficulty.normal));

      expect(session.scoreboard.score, scoreBefore);
      expect(session.scoreboard.combo, 1);
      expect(session.chart.beamCount, 6);
    });

    test('a note already played cannot be played again after re-laying', () {
      final session = sessionFor(songOf([note(0, 60)]),
          difficulty: Difficulty.normal);
      seek(session, 0);
      expect(session.tap(session.chart.taps.first.beam), isNotNull);

      session.rebindChart(Chart.build(session.chart.song,
          beamCount: 6, difficulty: Difficulty.normal));
      for (final tap in session.chart.taps) {
        expect(session.tap(tap.beam)?.scored ?? false, isFalse,
            reason: 'the note was already played');
      }
      expect(engine.struck, hasLength(1));
    });

    test('a chord regroups when the beam count changes', () {
      // Three notes far enough apart to sit on separate beams either way.
      final song = songOf([note(0, 48), note(0, 60), note(0, 72)]);
      final narrow = Chart.build(song, beamCount: 3, difficulty: Difficulty.normal);
      final wide = Chart.build(song, beamCount: 6, difficulty: Difficulty.normal);
      expect(narrow.taps.length, 3);
      expect(wide.taps.length, 3);
      expect(narrow.taps.map((t) => t.beam).toList(),
          isNot(wide.taps.map((t) => t.beam).toList()));
    });
  });

  group('reaching for a note', () {
    test('tapping too early says so, and costs nothing', () {
      final session = sessionFor(songOf([note(2, 60)]));
      // Half a beat before the note is due: past the window, but plainly
      // aimed at it.
      seek(session, 1.3);
      final outcome = session.tap(session.chart.taps.first.beam);
      expect(outcome, isNotNull, reason: 'silence reads as a broken control');
      expect(outcome!.scored, isFalse);
      expect(outcome.errorMs, lessThan(0), reason: 'early');
      expect(session.scoreboard.notesPlayed, 0, reason: 'no penalty');
      expect(engine.struck, isEmpty);
    });

    test('tapping just after a note has gone says that too', () {
      final session = sessionFor(songOf([note(0, 60)]));
      seek(session, 0.7); // the note has been missed by now
      expect(session.scoreboard.counts[Verdict.miss], 1);

      final outcome = session.tap(session.chart.taps.first.beam);
      expect(outcome, isNotNull);
      expect(outcome!.scored, isFalse);
      expect(outcome.errorMs, greaterThan(0), reason: 'late');
      // The miss was already counted when the note went by; the late tap must
      // not be counted a second time.
      expect(session.scoreboard.counts[Verdict.miss], 1);
    });

    test('a tap in empty space is ignored entirely', () {
      final session = sessionFor(songOf([note(20, 60)]));
      seek(session, 0);
      expect(session.tap(0), isNull);
      expect(session.tap(1), isNull);
    });

    test('playing slower gives the hand more time between notes', () {
      double beatsAfterOneSecond(double speed) {
        final session = PlaySession(
          chart: Chart.build(songOf([note(0, 60), note(1, 62)]),
              difficulty: Difficulty.easy),
          audio: PianoAudio(engine: RecordingEngine()),
          speed: speed,
        )..start();
        final start = session.leadInBeats / session.beatsPerSecond;
        session.update(
            Duration(microseconds: ((start + 1.0) * 1e6).round()));
        return session.beat;
      }

      // The same second of the player's time covers half as much music.
      expect(beatsAfterOneSecond(0.5),
          closeTo(beatsAfterOneSecond(1.0) / 2, 0.001));
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
      session.tap(session.chart.taps.first.beam);
      expect(session.scoreboard.score, greaterThan(0));

      session.restart();
      expect(session.scoreboard.score, 0);
      expect(session.beat, closeTo(-session.leadInBeats, 0.001));

      // The screen's clock keeps running across a restart; the song's does not.
      wall(session, firstNoteAt + wallTimeOf(session, 0));
      expect(session.beat, closeTo(0, 0.001));
      expect(session.tap(session.chart.taps.first.beam), isNotNull,
          reason: 'the note should be playable a second time');
    });
  });

  test('calibration shifts what counts as on time', () {
    final engine = RecordingEngine();
    final session = PlaySession(
      chart: Chart.build(songOf([note(0, 60)])),
      audio: PianoAudio(engine: engine),
      // The player's taps land 100ms late through the device's own delay.
      latencyOffsetMs: 100,
    )..start();

    final seconds = (0.2 + session.leadInBeats) / session.beatsPerSecond;
    session.update(Duration(microseconds: (seconds * 1e6).round()));
    // 100ms late by the clock, but on time once calibration is applied.
    expect(session.tap(session.chart.taps.first.beam)!.verdict, Verdict.perfect);
  });
}
